//
//  CreateQuestProgress.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 23.08.2026.
//
//  Phase 9.2 — the quest_progress table. One row per (player, NPC, game day);
//  the unique constraint is what makes "one job per NPC per day" a database
//  guarantee rather than a convention. Cascade-deletes with the owning user.
//

import Fluent

struct CreateQuestProgress: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("quest_progress")
            .id()
            .field("user_id", .uuid, .required, .references("users", "id", onDelete: .cascade))
            .field("npc", .string, .required)
            .field("quest_id", .string, .required)
            .field("day_stamp", .string, .required)
            .field("progress", .int, .required)
            .field("claimed", .bool, .required)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .unique(on: "user_id", "npc", "day_stamp")
            .create()
    }

    func revert(on database: any Database) async throws {
        try await database.schema("quest_progress").delete()
    }
}
