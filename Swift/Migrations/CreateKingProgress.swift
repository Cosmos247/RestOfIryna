//
//  CreateKingProgress.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 21.09.2026.
//
//  The king_progress table. One row per player — the unique constraint is what
//  makes "one open decree" a database guarantee rather than a convention, the
//  same way `quest_progress` guarantees one job per NPC per day.
//
//  No backfill: a row is created lazily the first time a player is asked where
//  they stand, starting at decree 0. Existing players therefore begin the chain
//  at the top and walk it one decree at a time, which is what the owner chose
//  on 2026-09-21 over settling the whole backlog in one screen — the early
//  decrees they already satisfy turn in immediately, and Vigor spent between
//  taps makes the payouts land rather than clamp.
//

import Fluent

struct CreateKingProgress: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("king_progress")
            .id()
            .field("user_id", .uuid, .required, .references("users", "id", onDelete: .cascade))
            .field("decree_index", .int, .required)
            .field("counter", .int, .required)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .unique(on: "user_id")
            .create()
    }

    func revert(on database: any Database) async throws {
        try await database.schema("king_progress").delete()
    }
}
