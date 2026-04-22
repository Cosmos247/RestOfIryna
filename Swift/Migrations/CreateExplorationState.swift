//
//  CreateExplorationState.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 21.04.2026.
//
//  Per-user row that exists only while the player is actively exploring.
//  Tracks how deep into the forest they've stepped. Deleted when they return
//  home (or die) so that "no row = not exploring" is the canonical state.
//

import Fluent

struct CreateExplorationState: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("exploration_state")
            .id()
            .field("user_id", .uuid, .required, .references("users", "id", onDelete: .cascade))
            .field("steps_deep", .int, .required)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .unique(on: "user_id")
            .create()
    }

    func revert(on database: any Database) async throws {
        try await database.schema("exploration_state").delete()
    }
}
