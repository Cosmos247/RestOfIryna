//
//  CreateGuildVault.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 16.06.2026.
//
//  Phase 7.1 — the shared guild item storage. Mirrors the warehouse schema but
//  keyed by `guild_id`. Any member deposits; only leader + officers withdraw
//  (enforced in GuildService). Cascade-deletes with the guild.
//

import Fluent

struct CreateGuildVault: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("guild_vault")
            .id()
            .field("guild_id", .uuid, .required, .references("guilds", "id", onDelete: .cascade))
            .field("item_id", .string, .required)
            .field("quantity", .int, .required)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .create()
    }

    func revert(on database: any Database) async throws {
        try await database.schema("guild_vault").delete()
    }
}
