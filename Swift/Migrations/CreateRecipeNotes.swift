//
//  CreateRecipeNotes.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 10.10.2026.
//
//  The recipe_notes table: the price cards a player pinned to the journal
//  (`RecipeNote`). A new table and nothing else — no row is backfilled, because
//  nobody had pinned anything before the button existed.
//
//  Cascades with the player, like every per-player table. One row per
//  (player, kind, ref, target): pinning the same card twice is an unpin, never a
//  second row, and the index holds that even if two taps ever raced.
//

import Fluent

struct CreateRecipeNotes: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("recipe_notes")
            .id()
            .field("user_id", .uuid, .required, .references("users", "id", onDelete: .cascade))
            .field("kind", .string, .required)
            .field("ref", .string, .required)
            .field("target", .int, .required)
            .field("created_at", .datetime)
            .unique(on: "user_id", "kind", "ref", "target")
            .create()
    }

    func revert(on database: any Database) async throws {
        try await database.schema("recipe_notes").delete()
    }
}
