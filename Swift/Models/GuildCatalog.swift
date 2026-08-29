//
//  GuildCatalog.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 16.06.2026.
//
//  Façade over `content/data/guild.json` (Phase 3B — was eight Swift constants)
//  plus the role model for the capital Guildhall.
//
//  `GuildRole` deliberately does NOT move to data: it is a raw value persisted
//  in `User.guildRole` and a set of authorization predicates, so it is code that
//  the database schema depends on, not content a balance pass would edit.
//

import Foundation

public enum GuildCatalog {
    /// Max members in a guild (leader + officers + members), GDD suggested 20–50.
    public static var memberCap: Int { Catalogs.current.guild.memberCap }
    /// Max officers (the leader's deputies). The leader is separate and never
    /// counted here. User-chosen: 2.
    public static var maxOfficers: Int { Catalogs.current.guild.maxOfficers }
    /// Flat silver cost to found a guild — a silver sink, paid from the leader's
    /// balance and burned, NOT seeded into the guild treasury.
    public static var foundCost: Int { Catalogs.current.guild.foundCost }
    /// Minimum player level required to found a guild.
    public static var foundLevelGate: Int { Catalogs.current.guild.foundLevelGate }
    /// Default cosmetic emblem when the founder doesn't pick one.
    public static var defaultEmblem: String { Catalogs.current.guild.defaultEmblem }

    /// Guild-name validation bounds (mirrors the registration nickname rules).
    public static var nameMinLength: Int { Catalogs.current.guild.nameMinLength }
    public static var nameMaxLength: Int { Catalogs.current.guild.nameMaxLength }

    /// Total units the shared vault can hold across all item rows (per-unit
    /// counting, same policy as the personal warehouse/bag).
    public static var vaultUnitCap: Int { Catalogs.current.guild.vaultUnitCap }
}

/// A member's standing inside their guild. Stored as the raw value in
/// `User.guildRole`; nil whenever the player isn't in a guild.
public enum GuildRole: String, Sendable, CaseIterable {
    case leader
    case officer
    case member

    /// Leader + officers may invite, kick lower ranks, and withdraw from the vault.
    public var canManageMembers: Bool { self == .leader || self == .officer }
    /// Withdraw permission mirrors management (user rule: only leader + deputies).
    public var canWithdrawVault: Bool { self == .leader || self == .officer }
}
