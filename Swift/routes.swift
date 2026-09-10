//
//  routes.swift
//  RestOfIryna
//
//  Created by Maxim Lanskoy on 13.06.2025.
//  Maintained by Dmytro Ihnatyuhin from 17.04.2026.
//

import Fluent
@preconcurrency import Lingo
import SwiftTelegramBot

// MARK: - Setting up Telegram Routes.
actor RouterStore {
    private var backStore: [String: Router] = [:]
    // Serialize updates per Telegram user. Each new dispatch is chained behind
    // the previous task's completion, so spam-taps (e.g. on Step Forward)
    // can't race on the cached User instance or the ExplorationState row —
    // tap N+1 only starts after tap N has fully written its mutations.
    private var nextDispatchToken: UInt64 = 0
    private var inflightByUser: [Int64: (token: UInt64, task: Task<Void, any Error>)] = [:]

    func set(_ router: Router, forKey key: String) {
        backStore[key] = router
    }

    func get(_ key: String) -> Router? {
        backStore[key]
    }

    func process(key: String, update: TGUpdate, properties: [String: Int64], db: any Database, lingo: Lingo) async throws {
        guard let userId = properties["session"] else {
            try await dispatch(requestedKey: key, properties: properties, update: update, db: db, lingo: lingo)
            return
        }

        let previousTask = inflightByUser[userId]?.task
        nextDispatchToken &+= 1
        let myToken = nextDispatchToken
        let task = Task<Void, any Error> {
            _ = try? await previousTask?.value
            try await self.dispatch(requestedKey: key, properties: properties, update: update, db: db, lingo: lingo)
        }
        inflightByUser[userId] = (myToken, task)
        defer {
            if inflightByUser[userId]?.token == myToken { inflightByUser[userId] = nil }
        }
        try await task.value
    }

    private func dispatch(requestedKey: String, properties: [String: Int64], update: TGUpdate, db: any Database, lingo: Lingo) async throws {
        // Rehydrate Users from IDs inside actor to avoid passing non-Sendable models across actor boundary
        var hydrated: [String: User] = [:]
        var wereInExpedition: [User] = []
        for (k, v) in properties {
            let user = try await sessionCache.getOrFetch(tgId: v, db: db)
            // Query expedition presence once — HealingService decides whether
            // to pause HP regen, the Estate/Capital guards re-read it later in
            // their own flows. Cheap lookup: user_id is indexed on
            // exploration_state. There is no Vigor tick to run beside it since
            // Phase 8E: Vigor comes back from food, never from the clock.
            let inExpedition = try await ExplorationState.current(for: user, on: db) != nil
            // The road is the one "not at the estate" that `location` cannot
            // answer — it stays at the origin until arrival — so it costs a
            // second lookup, asked only while the answer could still be yes.
            let couldRest = inExpedition == false
                && user.location != TravelDestination.capital.rawValue
            let onTheRoad = couldRest
                ? try await TravelState.current(for: user, on: db) != nil
                : false
            _ = try await HealingService.tick(
                user,
                canRest: HealingService.canRest(user, inExpedition: inExpedition, onTheRoad: onTheRoad),
                on: db
            )
            if inExpedition { wereInExpedition.append(user) }
            hydrated[k] = user
        }

        // Route on the routerName as it stands NOW, not as it stood when the
        // update was pulled off the queue. The SDK hands every update to its
        // own detached task, so two quick taps are both read before either has
        // transitioned — and the second would otherwise be delivered to the
        // controller the first one has just left: a step taken mid-fight, a
        // capital tap answered by the estate, and in both cases a screen that
        // re-sends the keyboard the player is no longer standing in. The
        // per-user chain above is what makes this second read safe — it runs
        // after the previous tap has committed its transition.
        let liveKey = hydrated["session"]?.routerName ?? requestedKey
        if liveKey != requestedKey {
            appState?.logger.warning("""
                [ROUTE] update arrived for router '\(requestedKey)' but the player \
                is on '\(liveKey)' — dispatching to the live one
                """)
        }
        guard let router = backStore[liveKey] else { return }
        try await router.process(update: update, properties: hydrated, db: db, lingo: lingo)

        // This dispatch may have been the one that ended the expedition —
        // walking home, dying, closing a passive report. The tick above ran
        // while the row still existed, so it cleared the rest clock; start it
        // here instead of leaving the player unhealed until their next tap.
        // Only users who were out get the second lookup, so an ordinary
        // estate interaction still costs one query.
        for user in wereInExpedition {
            guard try await ExplorationState.current(for: user, on: db) == nil else { continue }
            try await HealingService.beginResting(user, on: db)
        }
    }
}

// MARK: - Concurrency Safety Fixes.
// Allow passing Router instances across actors safely
extension Router: @unchecked Sendable {}
