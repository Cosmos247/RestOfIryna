//
//  CreateLearnedRecipes.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 02.05.2026.
//
//  Phase 5.2.1: per-user known-recipe set. One row per (user, recipe) pair.
//  Used by the Kitchen UI to gate the cooking recipe list — Forge and
//  Tannery recipes ignore this table, Kitchen recipes consult it.
//

import Fluent

struct CreateLearnedRecipes: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("learned_recipes")
            .id()
            .field("user_id", .uuid, .required, .references("users", "id", onDelete: .cascade))
            .field("recipe_id", .string, .required)
            .field("learned_at", .datetime)
            .unique(on: "user_id", "recipe_id")
            .create()
    }

    func revert(on database: any Database) async throws {
        try await database.schema("learned_recipes").delete()
    }
}
