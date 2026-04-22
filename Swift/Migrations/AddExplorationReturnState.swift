//
//  AddExplorationReturnState.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 22.04.2026.
//
//  Phase 3.2: extend `exploration_state` with direction + visited-room tracking
//  so the return path can roll with "already explored" decay weights.
//
//  Both columns are nullable — existing rows created under 3.1 keep working
//  (nil returning = outward, nil visited_rooms = empty set, resolved in the
//  ExplorationState model).
//

import Fluent

struct AddExplorationReturnState: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("exploration_state")
            .field("returning", .bool)
            .field("visited_rooms", .string)
            .update()
    }

    func revert(on database: any Database) async throws {
        try await database.schema("exploration_state")
            .deleteField("returning")
            .deleteField("visited_rooms")
            .update()
    }
}
