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

    @Timestamp(key: "created_at", on: .create)
    public var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    public var updatedAt: Date?

    public init() {}

    public init(userID: UUID, stepsDeep: Int = 0) {
        self.$user.id = userID
        self.stepsDeep = stepsDeep
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
