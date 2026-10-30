//
//  ManorService.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 29.10.2026.
//
//  A holiday's manor (`content/spec/event-veles-night.md`): a place at the
//  entrance km of an active walk that is left only by dying, where every step
//  deeper is a fight — or, one step in ten, a find that puts strength back
//  (2026-10-30, the pumpkin) — and every kill pours blood into a flask a death
//  does not take (`EventBlood`).
//
//  The manor lives on the walk's own row (`ExplorationState.manorEventId`), so
//  the walk's keyboard, its bag and every guard of the forest carry over: the
//  fight is the forest's fight, its creature read back through the same funnel
//  (`ExplorationState.combatEnemy(for:)`). What differs is here — the entrance,
//  the step, the blood, the close — and the screens that say so are in the
//  walk's and the fight's controllers.
//

import Fluent
import Foundation

public enum ManorService {

    /// The holiday whose entrance the walk should be shown now, or nil: an
    /// active walk standing at the entrance km while the manor is open, out of
    /// a fight and out of the manor, that has not been shown it yet. With the
    /// flask the entrance carries its button; without it, the way to the
    /// palace (the caller asks `EventBlood.hasFlask`).
    public static func entranceDue(for state: ExplorationState, now: Date = Date()) -> GameEvent? {
        guard !state.isPassive, !state.isInCombat, !state.isInManor,
              let event = EventCatalog.open(at: now),
              state.stepsDeep == event.dto.entranceKm,
              state.manorOffered != event.id else { return nil }
        return event
    }

    /// Why a tap on the entrance cannot step in, or nil when it can.
    public enum Refusal: Sendable {
        /// The manor is closed (or not open yet); the button is stale.
        case closed
        /// No walk at the entrance km — the forest, the estate, the road or a
        /// passive run. The manor waits where it stands.
        case elsewhere
        /// Already inside, or a fight stands on the row.
        case busy
        /// The scribe's flask has not been taken (2026-10-30): the blood would
        /// have nowhere to go. The palace hands it over.
        case noFlask
    }

    /// `hasFlask` is `EventBlood.hasFlask`, asked by the caller — the rule
    /// stays a pure function of what it is given, like `HealingService.canRest`.
    public static func refusal(event: GameEvent, state: ExplorationState?, hasFlask: Bool,
                               now: Date = Date()) -> Refusal? {
        guard event.isOpen(at: now) else { return .closed }
        guard let state, !state.isPassive, state.stepsDeep == event.dto.entranceKm else { return .elsewhere }
        if state.isInManor || state.isInCombat { return .busy }
        if !hasFlask { return .noFlask }
        return nil
    }

    /// Through the gate: depth 0, an empty run. Caller saves.
    public static func enter(_ state: ExplorationState, event: GameEvent) {
        state.enterManor(event.id)
        state.manorOffered = event.id
    }

    /// One step deeper, and what stands there.
    public struct Step: Sendable {
        public enum Encounter: Sendable {
            case creature(Enemy, creatureId: String)
            /// A find in the creature's place (2026-10-30): what it put back,
            /// after the pools' caps — the receipt the screen prints.
            case find(EventFindDTO, hpRestored: Int, vigorRestored: Int)
        }
        public let encounter: Encounter
        public let depth: Int
        public let roomId: String
        /// The hunger tick, on its own line like the forest's (`StepResult`).
        public let starvationHpLost: Int
    }

    /// Walk one depth deeper: the walk's Vigor for the stride, hunger on a step
    /// that BEGINS at 0 Vigor (the forest's rule, `ExplorationService.rollStep`),
    /// then a find by its chance (2026-10-30: the pumpkin, one step in ten) or
    /// else a creature by weight at its level. A find stands at its depth like
    /// a creature would, so the next creature is one deeper. Hunger that kills
    /// comes first: a dead player finds nothing, and the caller reads the death
    /// off the HP. The depth is not a km, so the lifetime km tally is left
    /// alone. Caller saves the row and the user.
    public static func step(_ user: User, state: ExplorationState, event: GameEvent) -> Step? {
        let beganStarving = VigorService.isStarving(user)
        _ = VigorService.drain(user, action: .walkRoom)
        let starvation = beganStarving ? VigorService.applyStarvationHPLoss(user) : 0

        let depth = (state.manorDepth ?? 0) + 1
        guard let room = event.dto.room(forDepth: depth) else { return nil }
        if user.hp > 0, let find = EventMath.pickFind(event.dto.findList, roll: Double.random(in: 0..<1)) {
            let hp = EventMath.restore(share: find.hpShare, maximum: user.effectiveMaxHp, current: user.hp)
            let vigor = EventMath.restore(share: find.vigorShare, maximum: user.maxVigor, current: user.vigor)
            user.hp += hp
            user.vigor += vigor
            state.manorDepth = depth
            return Step(encounter: .find(find, hpRestored: hp, vigorRestored: vigor), depth: depth, roomId: room.id,
                        starvationHpLost: starvation)
        }
        let total = EventMath.totalWeight(event.dto.creatures)
        guard total > 0,
              let creature = EventMath.pick(event.dto.creatures, roll: Int.random(in: 0..<total)) else { return nil }
        let level = event.creatureLevel(playerLevel: user.level, depth: depth)
        let ref = EventCreatureRef(eventId: event.id, creatureId: creature.id, level: level)
        guard let enemy = event.enemy(for: ref) else { return nil }
        state.manorDepth = depth
        return Step(encounter: .creature(enemy, creatureId: creature.id), depth: depth, roomId: room.id,
                    starvationHpLost: starvation)
    }

    /// A kill in the manor: its blood into the flask and onto the run. Returns
    /// the drops poured and the flask's new total.
    public static func pourKill(_ user: User, state: ExplorationState, event: GameEvent,
                                creatureId: String, on db: any Database) async throws -> (blood: Int, total: Int) {
        let blood = event.blood(creatureId: creatureId, depth: state.manorDepth ?? 1)
        let total = try await EventBlood.pour(blood, for: user, eventId: event.id, on: db)
        state.manorRunBlood = (state.manorRunBlood ?? 0) + blood
        return (blood, total)
    }

    /// The close: the player is walked out to the entrance km, the walk goes
    /// on. Caller saves.
    public static func release(_ state: ExplorationState) {
        state.leaveManor()
    }
}
