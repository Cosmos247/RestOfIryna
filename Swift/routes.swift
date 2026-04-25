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
        guard let router = backStore[key] else { return }

        guard let userId = properties["session"] else {
            try await dispatch(router: router, properties: properties, update: update, db: db, lingo: lingo)
            return
        }

        let previousTask = inflightByUser[userId]?.task
        nextDispatchToken &+= 1
        let myToken = nextDispatchToken
        let task = Task<Void, any Error> { [router] in
            _ = try? await previousTask?.value
            try await self.dispatch(router: router, properties: properties, update: update, db: db, lingo: lingo)
        }
        inflightByUser[userId] = (myToken, task)
        defer {
            if inflightByUser[userId]?.token == myToken { inflightByUser[userId] = nil }
        }
        try await task.value
    }

    private func dispatch(router: Router, properties: [String: Int64], update: TGUpdate, db: any Database, lingo: Lingo) async throws {
        // Rehydrate Users from IDs inside actor to avoid passing non-Sendable models across actor boundary
        var hydrated: [String: User] = [:]
        for (k, v) in properties {
            let user = try await sessionCache.getOrFetch(tgId: v, db: db)
            // Query expedition presence once — HealingService decides whether
            // to pause regen, the Estate/Capital guards re-read it later in
            // their own flows. Cheap lookup: user_id is indexed on
            // exploration_state.
            let inExpedition = try await ExplorationState.current(for: user, on: db) != nil
            _ = try await HealingService.tick(user, inExpedition: inExpedition, on: db)
            hydrated[k] = user
        }
        try await router.process(update: update, properties: hydrated, db: db, lingo: lingo)
    }
}

// MARK: - Concurrency Safety Fixes.
// Allow passing Router instances across actors safely
extension Router: @unchecked Sendable {}
