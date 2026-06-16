//
//  CreateGuildInvites.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 16.06.2026.
//
//  Phase 7.1 — pending guild invitations. One row per (guild, invitee) offer;
//  deleted on accept/decline and cascade-deleted with the guild or either user.
//

import Fluent

struct CreateGuildInvites: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("guild_invites")
            .id()
            .field("guild_id", .uuid, .required, .references("guilds", "id", onDelete: .cascade))
            .field("invitee_id", .uuid, .required, .references("users", "id", onDelete: .cascade))
            .field("inviter_id", .uuid, .required, .references("users", "id", onDelete: .cascade))
            .field("created_at", .datetime)
            .create()
    }

    func revert(on database: any Database) async throws {
        try await database.schema("guild_invites").delete()
    }
}
