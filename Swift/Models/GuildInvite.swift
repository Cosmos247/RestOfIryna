//
//  GuildInvite.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 16.06.2026.
//
//  Phase 7.1 — a pending invitation for one player to join one guild. Created by
//  a leader/officer, consumed when the invitee accepts (→ joins) or declines
//  (→ row deleted). Cascade-deletes with either the guild or the invitee.
//

import Fluent
import Foundation

final public class GuildInvite: Model, @unchecked Sendable {
    public static let schema = "guild_invites"

    @ID(key: .id)
    public var id: UUID?

    @Parent(key: "guild_id")
    public var guild: Guild

    @Parent(key: "invitee_id")
    public var invitee: User

    @Parent(key: "inviter_id")
    public var inviter: User

    @Timestamp(key: "created_at", on: .create)
    public var createdAt: Date?

    public init() {}

    public init(guildID: UUID, inviteeID: UUID, inviterID: UUID) {
        self.$guild.id = guildID
        self.$invitee.id = inviteeID
        self.$inviter.id = inviterID
    }
}

// MARK: - Read helpers

extension GuildInvite {
    public static func find(id: UUID, on db: any Database) async throws -> GuildInvite? {
        try await GuildInvite.query(on: db).filter(\.$id, .equal, id).first()
    }

    /// All invites waiting for one player, newest first.
    public static func forInvitee(_ userId: UUID, on db: any Database) async throws -> [GuildInvite] {
        try await GuildInvite.query(on: db)
            .filter(\.$invitee.$id, .equal, userId)
            .sort(\.$createdAt, .descending)
            .all()
    }

    /// Whether a pending invite already exists for this guild+invitee pair.
    public static func exists(guildID: UUID, inviteeID: UUID, on db: any Database) async throws -> Bool {
        try await GuildInvite.query(on: db)
            .filter(\.$guild.$id, .equal, guildID)
            .filter(\.$invitee.$id, .equal, inviteeID)
            .count() > 0
    }

    /// Drop every invite for a player (called once they join any guild).
    public static func clearAll(forInvitee userId: UUID, on db: any Database) async throws {
        try await GuildInvite.query(on: db)
            .filter(\.$invitee.$id, .equal, userId)
            .delete()
    }
}
