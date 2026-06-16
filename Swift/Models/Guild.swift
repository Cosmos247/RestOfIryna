//
//  Guild.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 16.06.2026.
//
//  Phase 7.1 — a player guild, founded and managed at the capital Guildhall.
//  Membership lives on the `User` row (`guild_id` + `guild_role`) so "what guild
//  am I in" is a single field read; the roster is a `User` query by `guild_id`.
//  This file is the guild record itself + read helpers. `GuildService` owns the
//  found / join / leave / kick / disband transactions.
//

import Fluent
import Foundation

final public class Guild: Model, @unchecked Sendable {
    public static let schema = "guilds"

    @ID(key: .id)
    public var id: UUID?

    /// Unique display name.
    @Field(key: "name")
    public var name: String

    /// Short tag shown as `[TAG]` next to the name.
    @Field(key: "tag")
    public var tag: String

    /// Cosmetic emblem emoji.
    @Field(key: "emblem")
    public var emblem: String

    /// The founder / current leader. Exactly one per guild.
    @Parent(key: "leader_id")
    public var leader: User

    /// Shared silver pool (deposits + future guild-level costs). Distinct from
    /// the item vault (`GuildVaultEntry`).
    @Field(key: "treasury")
    public var treasury: Int

    @OptionalField(key: "motto")
    public var motto: String?

    @Timestamp(key: "created_at", on: .create)
    public var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    public var updatedAt: Date?

    public init() {}

    public init(name: String, tag: String, emblem: String = GuildCatalog.defaultEmblem, leaderID: UUID, treasury: Int = 0, motto: String? = nil) {
        self.name = name
        self.tag = tag
        self.emblem = emblem
        self.$leader.id = leaderID
        self.treasury = treasury
        self.motto = motto
    }
}

// MARK: - Read helpers

extension Guild {
    public static func find(id: UUID, on db: any Database) async throws -> Guild? {
        try await Guild.query(on: db).filter(\.$id, .equal, id).first()
    }

    /// Case-insensitive name lookup — used to reject duplicate names on found.
    public static func named(_ name: String, on db: any Database) async throws -> Guild? {
        try await Guild.query(on: db)
            .filter(\.$name, .custom("ILIKE"), name)
            .first()
    }

    /// Every guild, newest first — powers the browse/join list.
    public static func all(on db: any Database) async throws -> [Guild] {
        try await Guild.query(on: db).sort(\.$createdAt, .descending).all()
    }

    /// The roster — all users whose `guild_id` points here.
    public func members(on db: any Database) async throws -> [User] {
        guard let id else { return [] }
        return try await User.query(on: db).filter(\.$guild.$id, .equal, id).all()
    }

    public func memberCount(on db: any Database) async throws -> Int {
        guard let id else { return 0 }
        return try await User.query(on: db).filter(\.$guild.$id, .equal, id).count()
    }

    /// Current officer count — gates `GuildCatalog.maxOfficers` on promotion.
    public func officerCount(on db: any Database) async throws -> Int {
        guard let id else { return 0 }
        return try await User.query(on: db)
            .filter(\.$guild.$id, .equal, id)
            .filter(\.$guildRole, .equal, GuildRole.officer.rawValue)
            .count()
    }
}
