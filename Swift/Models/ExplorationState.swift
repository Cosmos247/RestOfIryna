//
//  ExplorationState.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 21.04.2026.
//
//  Presence of a row = the player is currently out exploring. Absent row =
//  at the estate. `stepsDeep` is the current km distance from the manor.
//  Loot collected during the expedition lives in the regular `inventory`
//  table (per design — inventory IS the expedition bag). On death the caller
//  wipes non-equipped inventory rows directly.
//
//  Phase 3.2 additions:
//    - `visited_rooms` — JSON dict of km → visit count. Rolled events pick
//      their weight table from the prior count at that km: tier 0 fresh,
//      tier 1 reduced, tier 2+ bare. Cleared with the row on return / death.
//    - `returning` column exists on the schema (from an earlier 3.2 design
//      pass) but is no longer used — the Step Back button is the canonical
//      reverse action. Column stays dormant; no data migration needed.
//
//  Phase 3.3 additions:
//    - `mode` — "active" / "passive". Nil = active (back-compat).
//    - `ends_at` — when the passive expedition's timer finishes. Nil for active.
//    - `report_json` — serialized `PassiveReport` written by the scheduler
//      when it completes the simulation, read by the controller when the
//      player next opens the exploration screen. Nil for active or in-flight
//      passive.
//

import Fluent
import Foundation

final public class ExplorationState: Model, @unchecked Sendable {
    public static let schema = "exploration_state"

    @ID(key: .id)
    public var id: UUID?

    @Parent(key: "user_id")
    public var user: User

    @Field(key: "steps_deep")
    public var stepsDeep: Int

    /// Added in Phase 3.2. JSON-encoded map of km → visit count. Each entry
    /// into a room increments its count; the rolled event's weight table
    /// uses the *prior* count (0 = fresh, 1 = reduced, 2+ = bare).
    /// Nullable for forward compatibility with 3.1 rows; nil = empty map.
    @OptionalField(key: "visited_rooms")
    public var visitedRoomsJSON: String?

    // MARK: - Phase 3.3 passive expedition fields

    /// "active" / "passive". Nil (legacy) is interpreted as active.
    @OptionalField(key: "mode")
    public var modeRaw: String?

    /// For passive mode: the wall-clock time at which the scheduler should
    /// run the simulation and deliver the report. Nil for active rows.
    @OptionalField(key: "ends_at")
    public var endsAt: Date?

    /// JSON-encoded `PassiveReport` written by the scheduler once the
    /// simulation finishes. Its presence means "report is ready to show".
    @OptionalField(key: "report_json")
    public var reportJSON: String?

    /// JSON-encoded `RunningPassiveReport` snapshot updated after every
    /// simulated step. Holds the running outcome counters, loot totals, and
    /// HP/vigor at expedition start. Restored by `runLive` after a bot
    /// restart so the final report is complete even when the simulation
    /// was interrupted mid-way. Nil for active rows and for legacy passive
    /// rows created before the AddPassiveRunningReport migration.
    @OptionalField(key: "running_report_json")
    public var runningReportJSON: String?

    // MARK: - Phase 4.1 combat fields

    /// ID of the enemy the player is currently fighting. Non-null on both
    /// `combatEnemyId` AND `combatEnemyHP` = active combat. Both null = no
    /// combat (the expedition row itself stays put across combats).
    @OptionalField(key: "combat_enemy_id")
    public var combatEnemyId: String?

    /// Remaining HP of the enemy currently being fought. See `combatEnemyId`
    /// for the live-combat invariant.
    @OptionalField(key: "combat_enemy_hp")
    public var combatEnemyHP: Int?

    // MARK: - Phase 4.2 stance fields

    /// Active Super-technique stance ID (`bloodlust` / `hawks_eye` /
    /// `arcane_resonance`). Non-null on both `combatStance` AND
    /// `combatStanceRoundsLeft` = stance currently buffing the player.
    @OptionalField(key: "combat_stance")
    public var combatStance: String?

    /// Rounds remaining on the active stance — decremented at the end of each
    /// player action. When it reaches zero the controller clears both stance
    /// fields and emits an "expire" narrative.
    @OptionalField(key: "combat_stance_rounds_left")
    public var combatStanceRoundsLeft: Int?

    // MARK: - Phase 4.2.3 special defense effects

    /// Rounds remaining where the player's swings treat enemy DEF as 0.
    /// Set by warrior's Iron Bulwark to "split armor" for the next attack.
    /// Decremented at the end of each player action via tickDefenseEffects.
    @OptionalField(key: "combat_enemy_def_debuff")
    public var combatEnemyDefDebuff: Int?

    /// Rounds remaining where the player gets a flat +50 dodge against
    /// incoming hits. Set by archer's Shadow Veil. Decremented at end of
    /// each player action.
    @OptionalField(key: "combat_player_dodge_buff")
    public var combatPlayerDodgeBuff: Int?

    // MARK: - Phase 4.2 per-fight technique budget

    /// Special Attack uses left in this fight (max 2; set on beginCombat,
    /// decremented on each tap, hides the button at 0).
    @OptionalField(key: "combat_special_atk_uses")
    public var combatSpecialAtkUses: Int?

    /// Special Defense uses left (max 2).
    @OptionalField(key: "combat_special_def_uses")
    public var combatSpecialDefUses: Int?

    /// Super uses left (max 1). Independent of stance lifecycle — once spent,
    /// the player can't activate another Super even if the previous stance has
    /// already expired.
    @OptionalField(key: "combat_super_uses")
    public var combatSuperUses: Int?

    /// Player action counter for the current fight. Starts at 0 on
    /// `beginCombat`, incremented at the top of `finishRound` so the very
    /// first action displays "Раунд 1" in the status card. Cleared in
    /// `endCombat`. Nil for fights started before the AddCombatRound
    /// migration shipped (read defensively as 0).
    @OptionalField(key: "combat_round")
    public var combatRound: Int?

    @Timestamp(key: "created_at", on: .create)
    public var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    public var updatedAt: Date?

    public init() {}

    public init(userID: UUID, stepsDeep: Int = 0) {
        self.$user.id = userID
        self.stepsDeep = stepsDeep
        self.visitedRoomsJSON = nil
        self.modeRaw = ExplorationMode.active.rawValue
        self.endsAt = nil
        self.reportJSON = nil
        self.runningReportJSON = nil
        self.combatEnemyId = nil
        self.combatEnemyHP = nil
        self.combatStance = nil
        self.combatStanceRoundsLeft = nil
        self.combatEnemyDefDebuff = nil
        self.combatPlayerDodgeBuff = nil
        self.combatSpecialAtkUses = nil
        self.combatSpecialDefUses = nil
        self.combatSuperUses = nil
    }
}

/// Two exploration flavors that share the same state row.
public enum ExplorationMode: String, Sendable {
    case active
    case passive
}

extension ExplorationState {
    /// Map of km depth → number of times the player has entered that room.
    /// Persisted as a JSON object with string-coerced keys (JSON doesn't
    /// support integer keys). Callers should use `recordVisit` / `visitCount`
    /// rather than touching the map directly.
    public var visitedRooms: [Int: Int] {
        get {
            guard let raw = visitedRoomsJSON,
                  let data = raw.data(using: .utf8),
                  let stringMap = try? JSONDecoder().decode([String: Int].self, from: data)
            else { return [:] }
            var out: [Int: Int] = [:]
            for (k, v) in stringMap {
                if let km = Int(k) { out[km] = v }
            }
            return out
        }
        set {
            var stringMap: [String: Int] = [:]
            for (km, count) in newValue { stringMap[String(km)] = count }
            guard let data = try? JSONEncoder().encode(stringMap),
                  let raw = String(data: data, encoding: .utf8)
            else {
                visitedRoomsJSON = nil
                return
            }
            visitedRoomsJSON = raw
        }
    }

    /// Increment the visit counter at the given km. Call once per room entry.
    public func recordVisit(_ km: Int) {
        var rooms = visitedRooms
        rooms[km, default: 0] += 1
        visitedRooms = rooms
    }

    /// Number of times the player has already entered this room this
    /// expedition. Feeds the decayed-weights tier in `ExplorationService`.
    public func visitCount(_ km: Int) -> Int {
        return visitedRooms[km] ?? 0
    }
}

extension ExplorationState {
    public var mode: ExplorationMode {
        get { modeRaw.flatMap(ExplorationMode.init(rawValue:)) ?? .active }
        set { modeRaw = newValue.rawValue }
    }

    public var isPassive: Bool { mode == .passive }

    /// True while the passive expedition's timer hasn't elapsed yet.
    public func isPassiveInflight(now: Date = Date()) -> Bool {
        guard isPassive, let endsAt = endsAt else { return false }
        return now < endsAt
    }

    /// True when the passive simulation has produced a report that the
    /// player hasn't seen yet.
    public var hasReadyReport: Bool {
        return isPassive && reportJSON != nil
    }

    /// Seconds remaining until the passive expedition completes. 0 if already
    /// past due, nil if not a passive expedition or missing timestamp.
    public func secondsRemaining(now: Date = Date()) -> Int? {
        guard isPassive, let endsAt = endsAt else { return nil }
        return max(0, Int(endsAt.timeIntervalSince(now).rounded()))
    }
}

extension ExplorationState {
    /// Fetch the user's active exploration state, or nil if they're at the estate.
    public static func current(for user: User, on db: any Database) async throws -> ExplorationState? {
        guard let userId = user.id else { return nil }
        return try await ExplorationState.query(on: db)
            .filter(\.$user.$id, .equal, userId)
            .first()
    }

    /// Create and persist a fresh active expedition at km 0.
    @discardableResult
    public static func begin(for user: User, on db: any Database) async throws -> ExplorationState {
        guard let userId = user.id else {
            throw FluentError.idRequired
        }
        // Clean up any stale row first (shouldn't exist, but be defensive).
        if let existing = try await current(for: user, on: db) {
            try await existing.delete(on: db)
        }
        let state = ExplorationState(userID: userId, stepsDeep: 0)
        state.mode = .active
        try await state.save(on: db)
        return state
    }

    /// Create and persist a passive expedition scheduled to complete at `endsAt`.
    @discardableResult
    public static func beginPassive(for user: User, endsAt: Date, on db: any Database) async throws -> ExplorationState {
        guard let userId = user.id else {
            throw FluentError.idRequired
        }
        if let existing = try await current(for: user, on: db) {
            try await existing.delete(on: db)
        }
        let state = ExplorationState(userID: userId, stepsDeep: 0)
        state.mode = .passive
        state.endsAt = endsAt
        try await state.save(on: db)
        return state
    }

    /// Load every passive expedition regardless of user — used by the startup
    /// rescheduler to pick up in-flight runs across bot restarts.
    public static func allPassive(on db: any Database) async throws -> [ExplorationState] {
        return try await ExplorationState.query(on: db)
            .filter(\.$modeRaw, .equal, ExplorationMode.passive.rawValue)
            .all()
    }

    /// End the user's expedition. No-op if no active row.
    public static func end(for user: User, on db: any Database) async throws {
        if let state = try await current(for: user, on: db) {
            try await state.delete(on: db)
        }
    }
}

// MARK: - Combat helpers

extension ExplorationState {
    /// True when the row encodes a live combat (both combat fields populated).
    public var isInCombat: Bool {
        return combatEnemyId != nil && combatEnemyHP != nil
    }

    /// Stamp the combat fields and initialise the per-fight technique
    /// budget. Phase 5.3e: caller supplies use counts derived from the
    /// player's level via `CombatService.initialUses(for:playerLevel:)`,
    /// so the budget grows organically with progression (1/1/1 early,
    /// 2/2/2 at the L17/L20/L21 thresholds).
    public func beginCombat(enemyId: String, hp: Int, specialAtkUses: Int, specialDefUses: Int, superUses: Int) {
        self.combatEnemyId = enemyId
        self.combatEnemyHP = hp
        self.combatSpecialAtkUses = specialAtkUses
        self.combatSpecialDefUses = specialDefUses
        self.combatSuperUses = superUses
        self.combatRound = 0
    }

    /// Clear the combat fields without touching the rest of the row. Also
    /// clears any active stance, short-lived defense effects, and the
    /// per-fight technique budget — they're all scoped to the fight.
    public func endCombat() {
        self.combatEnemyId = nil
        self.combatEnemyHP = nil
        self.combatStance = nil
        self.combatStanceRoundsLeft = nil
        self.combatEnemyDefDebuff = nil
        self.combatPlayerDodgeBuff = nil
        self.combatSpecialAtkUses = nil
        self.combatSpecialDefUses = nil
        self.combatSuperUses = nil
        self.combatRound = nil
    }

    /// True when the row encodes a live Super-technique stance.
    public var hasActiveStance: Bool {
        guard let rounds = combatStanceRoundsLeft else { return false }
        return combatStance != nil && rounds > 0
    }

    /// Stamp the stance fields. Caller saves.
    public func beginStance(_ stanceId: String, rounds: Int) {
        self.combatStance = stanceId
        self.combatStanceRoundsLeft = rounds
    }

    /// Decrement the stance counter. Returns `true` if the stance just expired
    /// on this tick (so the controller can render an expiry narrative). Clears
    /// both fields on expiry.
    public func tickStance() -> Bool {
        guard let rounds = combatStanceRoundsLeft, combatStance != nil else { return false }
        let next = rounds - 1
        if next <= 0 {
            self.combatStance = nil
            self.combatStanceRoundsLeft = nil
            return true
        }
        self.combatStanceRoundsLeft = next
        return false
    }

    /// True when the warrior's Iron Bulwark "armor split" debuff is active —
    /// the player's next swing treats enemy DEF as 0.
    public var hasEnemyDefDebuff: Bool {
        return (combatEnemyDefDebuff ?? 0) > 0
    }

    /// True when the archer's Shadow Veil "lingering shadow" buff is active —
    /// the player gets +50 dodge on the incoming counter this round.
    public var hasPlayerDodgeBuff: Bool {
        return (combatPlayerDodgeBuff ?? 0) > 0
    }

    /// Set the enemy DEF debuff for `rounds` upcoming player actions.
    public func applyEnemyDefDebuff(rounds: Int) {
        self.combatEnemyDefDebuff = max(0, rounds)
    }

    /// Set the player dodge buff for `rounds` upcoming player actions.
    public func applyPlayerDodgeBuff(rounds: Int) {
        self.combatPlayerDodgeBuff = max(0, rounds)
    }

    /// Decrement both defense-effect counters at the end of a player action.
    /// Clears the column when it reaches 0 so `hasX` queries stay sharp.
    public func tickDefenseEffects() {
        if let rounds = combatEnemyDefDebuff {
            let next = rounds - 1
            self.combatEnemyDefDebuff = next > 0 ? next : nil
        }
        if let rounds = combatPlayerDodgeBuff {
            let next = rounds - 1
            self.combatPlayerDodgeBuff = next > 0 ? next : nil
        }
    }

    public var hasSpecialAtkUse: Bool { return (combatSpecialAtkUses ?? 0) > 0 }
    public var hasSpecialDefUse: Bool { return (combatSpecialDefUses ?? 0) > 0 }
    public var hasSuperUse:      Bool { return (combatSuperUses      ?? 0) > 0 }

    /// Decrement the Special Attack counter. Clears the field at 0 so
    /// `hasSpecialAtkUse` queries stay sharp.
    public func consumeSpecialAtk() {
        if let uses = combatSpecialAtkUses {
            let next = uses - 1
            self.combatSpecialAtkUses = next > 0 ? next : nil
        }
    }

    public func consumeSpecialDef() {
        if let uses = combatSpecialDefUses {
            let next = uses - 1
            self.combatSpecialDefUses = next > 0 ? next : nil
        }
    }

    public func consumeSuper() {
        if let uses = combatSuperUses {
            let next = uses - 1
            self.combatSuperUses = next > 0 ? next : nil
        }
    }
}
