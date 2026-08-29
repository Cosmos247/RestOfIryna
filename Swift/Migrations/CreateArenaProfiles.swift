//
//  CreateArenaProfiles.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 20.07.2026.
//
//  Phase 8.3 — the arena_profiles table. One row per fighter, holding the
//  persistent Honor rating + win/loss tally + daily fight counter. Cascade-
//  deletes with the owning user. `user_id` is unique (one profile per player).
//

import Fluent

struct CreateArenaProfiles: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("arena_profiles")
            .id()
            .field("user_id", .uuid, .required, .references("users", "id", onDelete: .cascade))
            .field("honor", .int, .required)
            .field("wins", .int, .required)
            .field("losses", .int, .required)
            .field("fights_today", .int, .required)
            .field("fights_day_stamp", .string, .required)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .unique(on: "user_id")
            .create()
    }

    func revert(on database: any Database) async throws {
        try await database.schema("arena_profiles").delete()
    }
}
