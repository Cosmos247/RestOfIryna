//
//  AddUserGuildFields.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 16.06.2026.
//
//  Phase 7.1 — adds guild membership to users: `guild_id` (nullable FK → guilds,
//  set NULL if the guild is disbanded) + `guild_role` (nullable string, the raw
//  GuildRole value). Both nil for players not in a guild. Must run AFTER
//  CreateGuilds so the FK target exists.
//

import Fluent

struct AddUserGuildFields: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("users")
            .field("guild_id", .uuid, .references("guilds", "id", onDelete: .setNull))
            .field("guild_role", .string)
            .update()
    }

    func revert(on database: any Database) async throws {
        try await database.schema("users")
            .deleteField("guild_id")
            .deleteField("guild_role")
            .update()
    }
}
