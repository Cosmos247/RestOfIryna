//
//  GuildService.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 16.06.2026.
//
//  Phase 7.1 — the database side of guilds. Membership lives on the `User` row
//  (`guild_id` + `guild_role`), so these transactions mutate both the `Guild`
//  record and the affected users. No Fluent transaction wrapper (consistent with
//  Market/Trade): validate first, then mutate. Bot I/O stays in the controller.
//
//  v1 scope: found / leave / disband. Invites + vault land in later increments.
//

import Fluent
import Foundation

public enum GuildService {

    // MARK: - Found

    public enum FoundResult: Sendable {
        case success(guildId: UUID, name: String, tag: String)
        case alreadyInGuild
        case levelTooLow(need: Int)
        case notEnoughSilver(have: Int, need: Int)
        case nameTaken
    }

    /// Found a new guild led by `user`. Charges `GuildCatalog.foundCost` (burned,
    /// not seeded into the treasury), creates the `Guild`, and stamps the leader's
    /// membership. The name is assumed pre-trimmed/validated by the caller; the
    /// tag is auto-derived from it (player tag-editing is a later concern).
    public static func found(name: String, for user: User, on db: any Database) async throws -> FoundResult {
        guard user.$guild.id == nil else { return .alreadyInGuild }
        guard let userId = user.id else { return .alreadyInGuild }
        if user.level < GuildCatalog.foundLevelGate {
            return .levelTooLow(need: GuildCatalog.foundLevelGate)
        }
        if user.silver < GuildCatalog.foundCost {
            return .notEnoughSilver(have: user.silver, need: GuildCatalog.foundCost)
        }
        if try await Guild.named(name, on: db) != nil {
            return .nameTaken
        }

        // The tag is left empty on creation — the game creator assigns it
        // manually (via DB) to avoid bad/abusive abbreviations. Display code
        // omits the `[TAG]` suffix while the tag is empty.
        let guild = Guild(name: name, tag: "", leaderID: userId)
        try await guild.save(on: db)
        guard let guildId = guild.id else { return .alreadyInGuild }

        user.silver -= GuildCatalog.foundCost
        user.$guild.id = guildId
        user.guildRole = GuildRole.leader.rawValue
        try await user.saveAndCache(in: db)

        return .success(guildId: guildId, name: name, tag: "")
    }

    // MARK: - Leave

    public enum LeaveResult: Sendable {
        case left(guildName: String)
        case notInGuild
        case leaderMustDisband
    }

    /// A non-leader leaves their guild. The leader can't simply leave — they must
    /// disband (leadership transfer is a future feature).
    public static func leave(user: User, on db: any Database) async throws -> LeaveResult {
        guard let guildId = user.$guild.id else { return .notInGuild }
        if user.guildRole == GuildRole.leader.rawValue { return .leaderMustDisband }

        let name = (try await Guild.find(id: guildId, on: db))?.name ?? "—"
        user.$guild.id = nil
        user.guildRole = nil
        try await user.saveAndCache(in: db)
        return .left(guildName: name)
    }

    // MARK: - Disband

    public enum DisbandResult: Sendable {
        case disbanded(guildName: String, memberCount: Int)
        case notInGuild
        case notLeader
    }

    /// The leader dissolves the guild: every member's membership is cleared, then
    /// the guild row is deleted (cascading its invites + vault rows away).
    public static func disband(user: User, on db: any Database) async throws -> DisbandResult {
        guard let guildId = user.$guild.id else { return .notInGuild }
        if user.guildRole != GuildRole.leader.rawValue { return .notLeader }
        guard let guild = try await Guild.find(id: guildId, on: db) else {
            // Row already gone — just clear the stale membership.
            user.$guild.id = nil
            user.guildRole = nil
            try await user.saveAndCache(in: db)
            return .notInGuild
        }

        let members = try await guild.members(on: db)
        for member in members {
            member.$guild.id = nil
            member.guildRole = nil
            try await member.saveAndCache(in: db)
        }
        try await guild.delete(on: db)
        return .disbanded(guildName: guild.name, memberCount: members.count)
    }

    // MARK: - Invite

    public enum InviteResult: Sendable {
        case invited(inviteeTelegramId: Int64, inviteeLocale: String, inviteeNick: String, guildName: String, guildTag: String, inviterNick: String)
        case notPermitted
        case notInGuild
        case targetNotFound
        case targetSelf
        case targetInGuild
        case guildFull(cap: Int)
        case alreadyInvited
    }

    /// A leader/officer invites the player identified by `targetIdentifier`
    /// (a nickname or @username, case-insensitive). Writes a `GuildInvite`; the
    /// controller pushes the notice. The target accepts later from the Guildhall.
    public static func invite(targetIdentifier: String, by actor: User, on db: any Database) async throws -> InviteResult {
        guard let guildId = actor.$guild.id, let actorId = actor.id else { return .notInGuild }
        let actorRole = actor.guildRole.flatMap { GuildRole(rawValue: $0) } ?? .member
        guard actorRole.canManageMembers else { return .notPermitted }
        guard let guild = try await Guild.find(id: guildId, on: db) else { return .notInGuild }
        guard let target = try await findTarget(targetIdentifier, on: db), let targetId = target.id else { return .targetNotFound }
        if targetId == actorId { return .targetSelf }
        if target.$guild.id != nil { return .targetInGuild }
        if try await guild.memberCount(on: db) >= GuildCatalog.memberCap { return .guildFull(cap: GuildCatalog.memberCap) }
        if try await GuildInvite.exists(guildID: guildId, inviteeID: targetId, on: db) { return .alreadyInvited }

        try await GuildInvite(guildID: guildId, inviteeID: targetId, inviterID: actorId).save(on: db)
        return .invited(
            inviteeTelegramId: target.telegramId, inviteeLocale: target.locale, inviteeNick: target.nickname ?? "—",
            guildName: guild.name, guildTag: guild.tag, inviterNick: actor.nickname ?? "—"
        )
    }

    /// Resolve a target by @username first (more unique), then nickname.
    /// Case-insensitive; first match wins (nicknames aren't guaranteed unique —
    /// a known v1 limitation).
    static func findTarget(_ identifier: String, on db: any Database) async throws -> User? {
        let id = identifier.hasPrefix("@") ? String(identifier.dropFirst()) : identifier
        guard !id.isEmpty else { return nil }
        if let byName = try await User.query(on: db).filter(\.$userName, .custom("ILIKE"), id).first() { return byName }
        return try await User.query(on: db).filter(\.$nickname, .custom("ILIKE"), id).first()
    }

    // MARK: - Accept / decline invite

    public enum AcceptResult: Sendable {
        case joined(guildName: String, guildTag: String)
        case inviteGone
        case alreadyInGuild
        case guildFull(cap: Int)
    }

    public static func acceptInvite(inviteId: UUID, user: User, on db: any Database) async throws -> AcceptResult {
        guard user.$guild.id == nil, let userId = user.id else { return .alreadyInGuild }
        guard let invite = try await GuildInvite.find(id: inviteId, on: db), invite.$invitee.id == userId else { return .inviteGone }
        let guildId = invite.$guild.id
        guard let guild = try await Guild.find(id: guildId, on: db) else {
            try await invite.delete(on: db)
            return .inviteGone
        }
        if try await guild.memberCount(on: db) >= GuildCatalog.memberCap { return .guildFull(cap: GuildCatalog.memberCap) }

        user.$guild.id = guildId
        user.guildRole = GuildRole.member.rawValue
        try await user.saveAndCache(in: db)
        try await GuildInvite.clearAll(forInvitee: userId, on: db)   // drop their other invites too
        return .joined(guildName: guild.name, guildTag: guild.tag)
    }

    public static func declineInvite(inviteId: UUID, user: User, on db: any Database) async throws {
        guard let userId = user.id else { return }
        if let invite = try await GuildInvite.find(id: inviteId, on: db), invite.$invitee.id == userId {
            try await invite.delete(on: db)
        }
    }

    // MARK: - Kick

    public enum KickResult: Sendable {
        case kicked(nick: String, telegramId: Int64, locale: String, guildName: String)
        case notPermitted
        case targetNotInGuild
        case cannotKickRank
    }

    /// Leader kicks officers + members; officers kick members only; nobody kicks
    /// the leader or themselves.
    public static func kick(targetUserId: UUID, by actor: User, on db: any Database) async throws -> KickResult {
        guard let guildId = actor.$guild.id, let actorId = actor.id else { return .notPermitted }
        let actorRole = actor.guildRole.flatMap { GuildRole(rawValue: $0) } ?? .member
        guard actorRole.canManageMembers else { return .notPermitted }
        if targetUserId == actorId { return .cannotKickRank }
        guard let target = try await User.find(targetUserId, on: db), target.$guild.id == guildId else { return .targetNotInGuild }

        let targetRole = target.guildRole.flatMap { GuildRole(rawValue: $0) } ?? .member
        if targetRole == .leader { return .cannotKickRank }
        if actorRole == .officer && targetRole == .officer { return .cannotKickRank }

        let guildName = (try await Guild.find(id: guildId, on: db))?.name ?? "—"
        let nick = target.nickname ?? "—"
        let tg = target.telegramId, loc = target.locale
        target.$guild.id = nil
        target.guildRole = nil
        try await target.saveAndCache(in: db)
        return .kicked(nick: nick, telegramId: tg, locale: loc, guildName: guildName)
    }

    // MARK: - Promote / demote (leader only)

    public enum RoleChangeResult: Sendable {
        case promoted(nick: String, telegramId: Int64, locale: String, guildName: String)
        case demoted(nick: String, telegramId: Int64, locale: String, guildName: String)
        case notLeader
        case targetNotInGuild
        case officerCapReached(max: Int)
        case invalidTransition
    }

    public static func setOfficer(targetUserId: UUID, makeOfficer: Bool, by leader: User, on db: any Database) async throws -> RoleChangeResult {
        guard let guildId = leader.$guild.id, leader.guildRole == GuildRole.leader.rawValue else { return .notLeader }
        if targetUserId == leader.id { return .invalidTransition }
        guard let target = try await User.find(targetUserId, on: db), target.$guild.id == guildId else { return .targetNotInGuild }
        let targetRole = target.guildRole.flatMap { GuildRole(rawValue: $0) } ?? .member
        let guild = try await Guild.find(id: guildId, on: db)
        let guildName = guild?.name ?? "—"

        if makeOfficer {
            guard targetRole == .member else { return .invalidTransition }
            let officers = try await guild?.officerCount(on: db) ?? 0
            if officers >= GuildCatalog.maxOfficers { return .officerCapReached(max: GuildCatalog.maxOfficers) }
            target.guildRole = GuildRole.officer.rawValue
            try await target.saveAndCache(in: db)
            return .promoted(nick: target.nickname ?? "—", telegramId: target.telegramId, locale: target.locale, guildName: guildName)
        } else {
            guard targetRole == .officer else { return .invalidTransition }
            target.guildRole = GuildRole.member.rawValue
            try await target.saveAndCache(in: db)
            return .demoted(nick: target.nickname ?? "—", telegramId: target.telegramId, locale: target.locale, guildName: guildName)
        }
    }

    // MARK: - Vault (stackables only)

    public enum DepositResult: Sendable {
        case deposited(itemId: String, quantity: Int)
        case notInGuild
        case notStackable
        case notEnoughInBag(have: Int)
        case vaultFull(free: Int)
    }

    /// Move `quantity` of a stackable item from the depositor's bag into the
    /// shared vault. Any member may deposit. Validate (stackable, owned, cap),
    /// then mutate. Gear is excluded — the vault row carries no enchant/durability.
    public static func depositToVault(itemId: String, quantity: Int, by user: User, on db: any Database) async throws -> DepositResult {
        guard let guildId = user.$guild.id, let userId = user.id else { return .notInGuild }
        guard quantity > 0, let item = ItemCatalog.find(itemId), item.stackable else { return .notStackable }

        let inBag = try await InventoryEntry.totalQuantity(of: itemId, for: userId, on: db)
        if inBag < quantity { return .notEnoughInBag(have: inBag) }

        let free = GuildCatalog.vaultUnitCap - (try await GuildVaultEntry.totalUnits(for: guildId, on: db))
        if quantity > free { return .vaultFull(free: max(0, free)) }

        let removed = try await InventoryEntry.remove(itemId, quantity: quantity, from: user, on: db)
        guard removed else { return .notEnoughInBag(have: inBag) }
        try await GuildVaultEntry.add(itemId, quantity: quantity, to: guildId, on: db)
        return .deposited(itemId: itemId, quantity: quantity)
    }

    public enum WithdrawResult: Sendable {
        case withdrawn(itemId: String, quantity: Int)
        case notInGuild
        case notPermitted
        case notEnoughInVault(have: Int)
        case bagFull(free: Int, need: Int)
    }

    /// Move `quantity` of an item from the vault into the withdrawer's bag.
    /// Leader + officers only. Validate (permission, stock, bag space), then mutate.
    public static func withdrawFromVault(itemId: String, quantity: Int, by user: User, on db: any Database) async throws -> WithdrawResult {
        guard let guildId = user.$guild.id else { return .notInGuild }
        let role = user.guildRole.flatMap { GuildRole(rawValue: $0) } ?? .member
        guard role.canWithdrawVault else { return .notPermitted }
        guard quantity > 0 else { return .notEnoughInVault(have: 0) }

        let inVault = try await GuildVaultEntry.totalQuantity(of: itemId, for: guildId, on: db)
        if inVault < quantity { return .notEnoughInVault(have: inVault) }

        let canFit = try await InventoryEntry.canAccept(itemId, quantity: quantity, for: user, on: db)
        if !canFit {
            let used = try await InventoryEntry.slotsUsed(for: user, on: db)
            let cap = InventoryEntry.slotCap(for: user)
            return .bagFull(free: max(0, cap - used), need: quantity)
        }

        let removed = try await GuildVaultEntry.remove(itemId, quantity: quantity, from: guildId, on: db)
        guard removed else { return .notEnoughInVault(have: inVault) }
        try await InventoryEntry.add(itemId, quantity: quantity, to: user, on: db)
        return .withdrawn(itemId: itemId, quantity: quantity)
    }

    // MARK: - Treasury (shared silver pool)

    public enum TreasuryDepositResult: Sendable {
        case deposited(amount: Int, balance: Int)
        case notInGuild
        case notEnoughSilver(have: Int)
    }

    /// Any member moves silver from their own balance into the guild treasury.
    public static func depositSilver(amount: Int, by user: User, on db: any Database) async throws -> TreasuryDepositResult {
        guard let guildId = user.$guild.id else { return .notInGuild }
        guard amount > 0, user.silver >= amount else { return .notEnoughSilver(have: user.silver) }
        guard let guild = try await Guild.find(id: guildId, on: db) else { return .notInGuild }

        user.silver -= amount
        try await user.saveAndCache(in: db)
        guild.treasury += amount
        try await guild.save(on: db)
        return .deposited(amount: amount, balance: guild.treasury)
    }

    public enum TreasuryWithdrawResult: Sendable {
        case withdrawn(amount: Int, balance: Int)
        case notInGuild
        case notPermitted
        case notEnoughTreasury(have: Int)
    }

    /// Leader + officers move silver from the treasury into their own balance.
    public static func withdrawSilver(amount: Int, by user: User, on db: any Database) async throws -> TreasuryWithdrawResult {
        guard let guildId = user.$guild.id else { return .notInGuild }
        let role = user.guildRole.flatMap { GuildRole(rawValue: $0) } ?? .member
        guard role.canWithdrawVault else { return .notPermitted }
        guard amount > 0 else { return .notEnoughTreasury(have: 0) }
        guard let guild = try await Guild.find(id: guildId, on: db) else { return .notInGuild }
        if guild.treasury < amount { return .notEnoughTreasury(have: guild.treasury) }

        guild.treasury -= amount
        try await guild.save(on: db)
        user.silver += amount
        try await user.saveAndCache(in: db)
        return .withdrawn(amount: amount, balance: guild.treasury)
    }
}
