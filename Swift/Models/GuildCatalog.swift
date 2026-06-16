//
//  GuildCatalog.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 16.06.2026.
//
//  Phase 7.1 — tuning constants + the role model for the capital Guildhall.
//  Pure data, no I/O. Numbers are deliberately conservative for v1 and live
//  here so balance passes touch one file.
//

import Foundation

public enum GuildCatalog {
    /// Max members in a guild (leader + officers + members), GDD suggested 20–50.
    public static let memberCap = 20
    /// Max officers (the leader's deputies). The leader is separate and never
    /// counted here. User-chosen: 2.
    public static let maxOfficers = 2
    /// Flat silver cost to found a guild — a silver sink, paid from the leader's
    /// balance and seeded into the guild treasury is NOT done (it's burned).
    public static let foundCost = 500
    /// Minimum player level required to found a guild.
    public static let foundLevelGate = 5
    /// Default cosmetic emblem when the founder doesn't pick one.
    public static let defaultEmblem = "🛡"

    /// Guild-name validation bounds (mirrors the registration nickname rules).
    public static let nameMinLength = 3
    public static let nameMaxLength = 24

    /// Total units the shared vault can hold across all item rows (per-unit
    /// counting, same policy as the personal warehouse/bag).
    public static let vaultUnitCap = 3000
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
