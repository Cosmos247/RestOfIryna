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

    @Timestamp(key: "created_at", on: .create)
    public var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    public var updatedAt: Date?

    public init() {}

    public init(userID: UUID, stepsDeep: Int = 0) {
        self.$user.id = userID
        self.stepsDeep = stepsDeep
        self.visitedRoomsJSON = nil
    }
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
    /// Fetch the user's active exploration state, or nil if they're at the estate.
    public static func current(for user: User, on db: any Database) async throws -> ExplorationState? {
        guard let userId = user.id else { return nil }
        return try await ExplorationState.query(on: db)
            .filter(\.$user.$id, .equal, userId)
            .first()
    }

    /// Create and persist a fresh expedition at km 0.
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
        try await state.save(on: db)
        return state
    }

    /// End the user's expedition. No-op if no active row.
    public static func end(for user: User, on db: any Database) async throws {
        if let state = try await current(for: user, on: db) {
            try await state.delete(on: db)
        }
    }
}
