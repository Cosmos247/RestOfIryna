//
//  CreateHorses.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 09.11.2026.
//
//  The Rysak (`content/spec/spec-horse.md`): `horses`, one row a player who has
//  hired one. One new table and nothing else — no horse existed before. It
//  cascades with the player and is listed in `WipeForRebalance.playerTables`.
//  It stores no content id, so `LiveReferenceQuery` has nothing to read in it.
//

import Fluent

struct CreateHorses: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("horses")
            .id()
            .field("user_id", .uuid, .required, .references("users", "id", onDelete: .cascade))
            .field("ends_at", .datetime, .required)
            .field("announced_end", .datetime)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .unique(on: "user_id")
            .create()
    }

    func revert(on database: any Database) async throws {
        try await database.schema("horses").delete()
    }
}
