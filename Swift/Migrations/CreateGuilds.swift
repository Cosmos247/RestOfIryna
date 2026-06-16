//
//  CreateGuilds.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 16.06.2026.
//
//  Phase 7.1 — the guilds table. One row per player guild founded at the
//  capital Guildhall. `leader_id` cascade-deletes the guild if the leader's
//  account is removed (leadership transfer is a future concern).
//

import Fluent

struct CreateGuilds: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("guilds")
            .id()
            .field("name", .string, .required)
            .field("tag", .string, .required)
            .field("emblem", .string, .required)
            .field("leader_id", .uuid, .required, .references("users", "id", onDelete: .cascade))
            .field("treasury", .int, .required)
            .field("motto", .string)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .unique(on: "name")
            .create()
    }

    func revert(on database: any Database) async throws {
        try await database.schema("guilds").delete()
    }
}
