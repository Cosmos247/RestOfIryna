//
//  CreateEventBlood.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 29.10.2026.
//
//  The event_blood table: one row per player per holiday, the blood they have
//  carried out of its manor (`EventBlood`). Outside the bag on purpose — a
//  death empties the bag and must leave the flask alone. A new table and
//  nothing else. Cascades with the player, like every per-player table, and is
//  listed in `WipeForRebalance.playerTables`.
//

import Fluent

struct CreateEventBlood: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("event_blood")
            .id()
            .field("user_id", .uuid, .required, .references("users", "id", onDelete: .cascade))
            .field("event_id", .string, .required)
            .field("total", .int, .required)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .unique(on: "user_id", "event_id")
            .create()
    }

    func revert(on database: any Database) async throws {
        try await database.schema("event_blood").delete()
    }
}
