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
