//
//  GuildController.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 16.06.2026.
//
//  Phase 7.1 — the capital Guildhall. Reached from CapitalController's
//  `🏰 Гільдія` button, which flips `routerName` to "guild" (this controller
//  then owns the reply keyboard, mirroring how CombatController takes over).
//
//  Top-level navigation is a reply keyboard that branches on membership:
//    • guildless → [➕ Found] [📜 List] / [🔙 Capital]
//    • in guild  → [👥 Members] [⚙️ Manage] / [🔙 Capital]
//  Drill-downs (found-name prompt, manage actions) use inline buttons + a
//  text-prompt via `EphemeralChatState.PendingGuildInput`.
//
//  v1 scope: found / leave / disband / roster / browse. Invites (how others
//  join) + the shared vault land in the next increments.
//

import Foundation
import Lingo
import SwiftTelegramBot
import Fluent

final class GuildController: TGControllerBase, @unchecked Sendable {

    // MARK: - Lifecycle

    override public func attachHandlers(to bot: TGBot, lingo: Lingo) async {
        let router = Router(bot: bot) { router in
            router[Commands.start.command()] = onStart

            for locale in SupportedLocale.allCases {
                router[lingo.localize("guild.button.back",   locale: locale)] = onBackToCapital
                router[lingo.localize("guild.button.found",  locale: locale)] = onFoundTapped
                router[lingo.localize("guild.button.list",   locale: locale)] = onListTapped
                router[lingo.localize("guild.button.roster", locale: locale)] = onRosterTapped
                router[lingo.localize("guild.button.manage",   locale: locale)] = onManageTapped
                router[lingo.localize("guild.button.vault",    locale: locale)] = onVaultTapped
                router[lingo.localize("guild.button.treasury", locale: locale)] = onTreasuryTapped
            }

            router[.callback_query(data: nil)] = GuildController.onCallbackQuery
            router.unmatched = unmatched
        }
        await processRouterForEachName(router)
    }

    override public func generateControllerKB(session: User, lingo: Lingo) -> TGReplyMarkup? {
        let loc = session.locale
        let back = TGKeyboardButton(text: lingo.localize("guild.button.back", locale: loc))
        let rows: [[TGKeyboardButton]]
        if session.$guild.id == nil {
            rows = [[
                TGKeyboardButton(text: lingo.localize("guild.button.found", locale: loc)),
                TGKeyboardButton(text: lingo.localize("guild.button.list",  locale: loc))
            ], [back]]
        } else {
            rows = [[
                TGKeyboardButton(text: lingo.localize("guild.button.roster", locale: loc)),
                TGKeyboardButton(text: lingo.localize("guild.button.vault",  locale: loc))
            ], [
                TGKeyboardButton(text: lingo.localize("guild.button.treasury", locale: loc)),
                TGKeyboardButton(text: lingo.localize("guild.button.manage",   locale: loc))
            ], [back]]
        }
        return .replyKeyboardMarkup(TGReplyKeyboardMarkup(keyboard: rows, resizeKeyboard: true))
    }

    override func unmatched(context: Context) async throws -> Bool {
        guard try await super.unmatched(context: context) else { return false }

        // A guild text prompt is open — route the typed text by its kind
        // (guild name on found, or nickname/@username on invite).
        if let text = context.update.message?.text,
           let pending = await EphemeralChatState.shared.peekPendingGuildInput(telegramId: context.session.telegramId) {
            switch pending.kind {
            case .foundName:  try await handleFoundNameInput(text: text, pending: pending, context: context)
            case .inviteName: try await handleInviteNameInput(text: text, pending: pending, context: context)
            case .vaultDeposit(let itemId):  try await handleVaultQtyInput(text: text, itemId: itemId, deposit: true, pending: pending, context: context)
            case .vaultWithdraw(let itemId): try await handleVaultQtyInput(text: text, itemId: itemId, deposit: false, pending: pending, context: context)
            case .treasuryDeposit:  try await handleTreasuryInput(text: text, deposit: true, pending: pending, context: context)
            case .treasuryWithdraw: try await handleTreasuryInput(text: text, deposit: false, pending: pending, context: context)
            }
            return true
        }

        // Anything else re-renders the guild home so the player isn't stuck.
        try await showGuildHome(context: context)
        return true
    }

    // MARK: - Top-level handlers

    public func onStart(context: Context) async throws -> Bool {
        try await Controllers.mainController.showMainMenu(context: context)
        context.session.routerName = Controllers.mainController.routerName
        try await context.session.saveAndCache(in: context.db)
        return true
    }

    private func onBackToCapital(context: Context) async throws -> Bool {
        // showCapital re-asserts routerName = "capital" and restores the capital
        // reply keyboard.
        try await Controllers.capitalController.showCapital(context: context)
        return true
    }

    // MARK: - Home

    /// Entry point from CapitalController (after it flips routerName to "guild").
    /// Renders the guildless splash or the in-guild dashboard, carrying the
    /// matching reply keyboard.
    func showGuildHome(context: Context) async throws {
        let lingo = context.lingo, locale = context.session.locale
        let kb = generateControllerKB(session: context.session, lingo: lingo)
        let text: String
        if let guildId = context.session.$guild.id, let guild = try await Guild.find(id: guildId, on: context.db) {
            text = try await dashboardText(guild: guild, viewer: context.session, context: context)
        } else {
            text = "<b>\(lingo.localize("guild.home.guildless_title", locale: locale))</b>"
                + "\n\n\(lingo.localize("guild.home.guildless_body", locale: locale))"
        }
        try await context.bot.sendMessage(session: context.session, text: text, parseMode: .html, replyMarkup: kb)
        if context.session.$guild.id == nil { try await sendPendingInvites(context: context) }
    }

    /// If the guildless player has pending invites, list them with accept/decline
    /// inline buttons under the home splash.
    private func sendPendingInvites(context: Context) async throws {
        guard let userId = context.session.id else { return }
        let invites = try await GuildInvite.forInvitee(userId, on: context.db)
        guard !invites.isEmpty else { return }
        let lingo = context.lingo, locale = context.session.locale
        var rows: [[TGInlineKeyboardButton]] = []
        for inv in invites {
            guard let invId = inv.id, let guild = try await Guild.find(id: inv.$guild.id, on: context.db) else { continue }
            let label = "\(guild.name)\(tagSuffix(guild.tag))"
            rows.append([
                TGInlineKeyboardButton(text: lingo.localize("guild.invites.accept", locale: locale, interpolations: ["name": label]), callbackData: "guild:acceptinv:\(invId.uuidString)"),
                TGInlineKeyboardButton(text: lingo.localize("guild.invites.decline", locale: locale, interpolations: ["name": label]), callbackData: "guild:declineinv:\(invId.uuidString)")
            ])
        }
        guard !rows.isEmpty else { return }
        let body = "<b>\(lingo.localize("guild.invites.title", locale: locale))</b>"
        try await context.bot.sendMessage(session: context.session, text: body, parseMode: .html, replyMarkup: .inlineKeyboardMarkup(TGInlineKeyboardMarkup(inlineKeyboard: rows)))
    }

    private func dashboardText(guild: Guild, viewer: User, context: Context) async throws -> String {
        let lingo = context.lingo, locale = viewer.locale
        let count = try await guild.memberCount(on: context.db)
        var body = "🏰 \(guild.emblem) <b>\(guild.name)</b>\(tagSuffix(guild.tag))"
        body += "\n\n👥 " + lingo.localize("guild.home.members_line", locale: locale, interpolations: [
            "count": "\(count)", "cap": "\(GuildCatalog.memberCap)"
        ])
        body += "\n🪙 " + lingo.localize("guild.home.treasury_line", locale: locale, interpolations: ["silver": "\(guild.treasury)"])
        body += "\n" + lingo.localize("guild.home.your_role", locale: locale, interpolations: [
            "role": roleDisplay(viewer.guildRole, lingo: lingo, locale: locale)
        ])
        if let motto = guild.motto, !motto.isEmpty { body += "\n\n<i>\(motto)</i>" }
        return body
    }

    // MARK: - Found

    private func onFoundTapped(context: Context) async throws -> Bool {
        let lingo = context.lingo, locale = context.session.locale
        // Pre-checks surfaced before the prompt so the player doesn't type a
        // name only to be rejected.
        if context.session.$guild.id != nil {
            await postStatusBanner("❌ \(lingo.localize("guild.err.already_in", locale: locale))", context: context)
            return true
        }
        if context.session.level < GuildCatalog.foundLevelGate {
            await postStatusBanner("❌ \(lingo.localize("guild.err.level_too_low", locale: locale, interpolations: ["need": "\(GuildCatalog.foundLevelGate)"]))", context: context)
            return true
        }
        if context.session.silver < GuildCatalog.foundCost {
            await postStatusBanner("❌ \(lingo.localize("guild.err.not_enough_silver", locale: locale, interpolations: ["need": "\(GuildCatalog.foundCost)", "have": "\(context.session.silver)"]))", context: context)
            return true
        }

        let prompt = lingo.localize("guild.found.name_prompt", locale: locale, interpolations: [
            "min": "\(GuildCatalog.nameMinLength)", "max": "\(GuildCatalog.nameMaxLength)", "cost": "🪙 \(GuildCatalog.foundCost)"
        ])
        let cancel = lingo.localize("guild.found.cancel", locale: locale)
        let kb = TGInlineKeyboardMarkup(inlineKeyboard: [[TGInlineKeyboardButton(text: cancel, callbackData: "guild:cancelfound")]])
        let sent = try await context.bot.sendMessage(params: TGSendMessageParams(
            chatId: .chat(context.session.telegramId), text: prompt, parseMode: .html, replyMarkup: .inlineKeyboardMarkup(kb)
        ))
        await EphemeralChatState.shared.setPendingGuildInput(
            telegramId: context.session.telegramId,
            input: EphemeralChatState.PendingGuildInput(kind: .foundName, promptMessageId: sent.messageId)
        )
        return true
    }

    func cancelFoundPrompt(context: Context) async throws {
        guard let pending = await EphemeralChatState.shared.takePendingGuildInput(telegramId: context.session.telegramId) else { return }
        _ = try? await context.bot.deleteMessage(params: TGDeleteMessageParams(
            chatId: .chat(context.session.telegramId), messageId: pending.promptMessageId
        ))
    }

    private func handleFoundNameInput(text: String, pending: EphemeralChatState.PendingGuildInput, context: Context) async throws {
        let lingo = context.lingo, locale = context.session.locale
        let telegramId = context.session.telegramId
        let name = text.trimmingCharacters(in: .whitespacesAndNewlines)

        guard name.count >= GuildCatalog.nameMinLength, name.count <= GuildCatalog.nameMaxLength else {
            // Re-show the prompt in place with an error; keep pending for retry.
            let err = lingo.localize("guild.found.invalid", locale: locale, interpolations: [
                "min": "\(GuildCatalog.nameMinLength)", "max": "\(GuildCatalog.nameMaxLength)"
            ])
            let base = lingo.localize("guild.found.name_prompt", locale: locale, interpolations: [
                "min": "\(GuildCatalog.nameMinLength)", "max": "\(GuildCatalog.nameMaxLength)", "cost": "🪙 \(GuildCatalog.foundCost)"
            ])
            let cancel = lingo.localize("guild.found.cancel", locale: locale)
            let kb = TGInlineKeyboardMarkup(inlineKeyboard: [[TGInlineKeyboardButton(text: cancel, callbackData: "guild:cancelfound")]])
            await editScreen(
                chatId: .chat(telegramId),
                messageId: pending.promptMessageId,
                isPhoto: false,
                text: "\(base)\n\n❌ \(err)",
                replyMarkup: kb,
                bot: context.bot
            )
            return
        }

        _ = await EphemeralChatState.shared.takePendingGuildInput(telegramId: telegramId)
        _ = try? await context.bot.deleteMessage(params: TGDeleteMessageParams(chatId: .chat(telegramId), messageId: pending.promptMessageId))

        let result = try await GuildService.found(name: name, for: context.session, on: context.db)
        switch result {
        case .success(_, let gname, let tag):
            await postStatusBanner("✅ \(lingo.localize("guild.found.success", locale: locale, interpolations: ["name": gname, "tag": tagSuffix(tag)]))", context: context)
            try await showGuildHome(context: context)
        case .alreadyInGuild:
            await postStatusBanner("❌ \(lingo.localize("guild.err.already_in", locale: locale))", context: context)
        case .levelTooLow(let need):
            await postStatusBanner("❌ \(lingo.localize("guild.err.level_too_low", locale: locale, interpolations: ["need": "\(need)"]))", context: context)
        case .notEnoughSilver(let have, let need):
            await postStatusBanner("❌ \(lingo.localize("guild.err.not_enough_silver", locale: locale, interpolations: ["need": "\(need)", "have": "\(have)"]))", context: context)
        case .nameTaken:
            await postStatusBanner("❌ \(lingo.localize("guild.err.name_taken", locale: locale))", context: context)
        }
    }

    // MARK: - Browse / roster

    private func onListTapped(context: Context) async throws -> Bool {
        let lingo = context.lingo, locale = context.session.locale
        let guilds = try await Guild.all(on: context.db)
        var body = "<b>\(lingo.localize("guild.list.title", locale: locale))</b>"
        if guilds.isEmpty {
            body += "\n\n<i>\(lingo.localize("guild.list.empty", locale: locale))</i>"
        } else {
            for g in guilds.prefix(30) {
                let count = try await g.memberCount(on: context.db)
                let row = lingo.localize("guild.list.row", locale: locale, interpolations: [
                    "name": g.name, "tag": tagSuffix(g.tag), "members": "👥 \(count)"
                ])
                body += "\n\(g.emblem) \(row)"
            }
        }
        try await context.bot.sendMessage(session: context.session, text: body, parseMode: .html, replyMarkup: nil)
        return true
    }

    private func onRosterTapped(context: Context) async throws -> Bool {
        let lingo = context.lingo, locale = context.session.locale
        guard let guildId = context.session.$guild.id, let guild = try await Guild.find(id: guildId, on: context.db) else {
            await postStatusBanner("❌ \(lingo.localize("guild.err.not_in_guild", locale: locale))", context: context)
            return true
        }
        let members = try await guild.members(on: context.db)
        let ordered = members.sorted { roleRank($0.guildRole) < roleRank($1.guildRole) }
        var body = "<b>👥 \(lingo.localize("guild.roster.title", locale: locale, interpolations: ["name": guild.name]))</b>\n"
        for m in ordered {
            body += "\n" + lingo.localize("guild.roster.row", locale: locale, interpolations: [
                "badge": roleBadge(m.guildRole), "nick": m.nickname ?? "—"
            ])
        }
        try await context.bot.sendMessage(session: context.session, text: body, parseMode: .html, replyMarkup: nil)
        return true
    }

    // MARK: - Manage (leave / disband)

    private func onManageTapped(context: Context) async throws -> Bool {
        let lingo = context.lingo, locale = context.session.locale
        guard context.session.$guild.id != nil else {
            await postStatusBanner("❌ \(lingo.localize("guild.err.not_in_guild", locale: locale))", context: context)
            return true
        }
        let role = context.session.guildRole.flatMap { GuildRole(rawValue: $0) } ?? .member
        var rows: [[TGInlineKeyboardButton]] = []
        if role.canManageMembers {
            rows.append([TGInlineKeyboardButton(text: lingo.localize("guild.manage.invite_btn", locale: locale), callbackData: "guild:invite")])
            rows.append([TGInlineKeyboardButton(text: lingo.localize("guild.manage.members_btn", locale: locale), callbackData: "guild:managemembers")])
        }
        if role == .leader {
            rows.append([TGInlineKeyboardButton(text: lingo.localize("guild.manage.disband_btn", locale: locale), callbackData: "guild:disband")])
        } else {
            rows.append([TGInlineKeyboardButton(text: lingo.localize("guild.manage.leave_btn", locale: locale), callbackData: "guild:leave")])
        }
        let body = "<b>\(lingo.localize("guild.manage.title", locale: locale))</b>"
        try await context.bot.sendMessage(session: context.session, text: body, parseMode: .html, replyMarkup: .inlineKeyboardMarkup(TGInlineKeyboardMarkup(inlineKeyboard: rows)))
        return true
    }

    func handleLeave(context: Context) async throws {
        let lingo = context.lingo, locale = context.session.locale
        switch try await GuildService.leave(user: context.session, on: context.db) {
        case .left(let name):
            await postStatusBanner("🚪 \(lingo.localize("guild.left", locale: locale, interpolations: ["name": name]))", context: context)
            try await showGuildHome(context: context)
        case .notInGuild:
            await postStatusBanner("❌ \(lingo.localize("guild.err.not_in_guild", locale: locale))", context: context)
        case .leaderMustDisband:
            await postStatusBanner("❌ \(lingo.localize("guild.err.leader_must_disband", locale: locale))", context: context)
        }
    }

    func handleDisband(context: Context) async throws {
        let lingo = context.lingo, locale = context.session.locale
        switch try await GuildService.disband(user: context.session, on: context.db) {
        case .disbanded(let name, let count):
            await postStatusBanner("💥 \(lingo.localize("guild.disbanded", locale: locale, interpolations: ["name": name, "count": "\(count)"]))", context: context)
            try await showGuildHome(context: context)
        case .notInGuild:
            await postStatusBanner("❌ \(lingo.localize("guild.err.not_in_guild", locale: locale))", context: context)
        case .notLeader:
            await postStatusBanner("❌ \(lingo.localize("guild.err.not_leader", locale: locale))", context: context)
        }
    }

    // MARK: - Invite

    func startInvitePrompt(context: Context) async throws {
        let lingo = context.lingo, locale = context.session.locale
        let role = context.session.guildRole.flatMap { GuildRole(rawValue: $0) } ?? .member
        guard role.canManageMembers else {
            await postStatusBanner("❌ \(lingo.localize("guild.err.not_permitted", locale: locale))", context: context)
            return
        }
        let prompt = lingo.localize("guild.invite.prompt", locale: locale)
        let cancel = lingo.localize("guild.found.cancel", locale: locale)
        let kb = TGInlineKeyboardMarkup(inlineKeyboard: [[TGInlineKeyboardButton(text: cancel, callbackData: "guild:cancelfound")]])
        let sent = try await context.bot.sendMessage(params: TGSendMessageParams(
            chatId: .chat(context.session.telegramId), text: prompt, parseMode: .html, replyMarkup: .inlineKeyboardMarkup(kb)
        ))
        await EphemeralChatState.shared.setPendingGuildInput(
            telegramId: context.session.telegramId,
            input: EphemeralChatState.PendingGuildInput(kind: .inviteName, promptMessageId: sent.messageId)
        )
    }

    private func handleInviteNameInput(text: String, pending: EphemeralChatState.PendingGuildInput, context: Context) async throws {
        let lingo = context.lingo, locale = context.session.locale
        let telegramId = context.session.telegramId
        let identifier = text.trimmingCharacters(in: .whitespacesAndNewlines)
        _ = await EphemeralChatState.shared.takePendingGuildInput(telegramId: telegramId)
        _ = try? await context.bot.deleteMessage(params: TGDeleteMessageParams(chatId: .chat(telegramId), messageId: pending.promptMessageId))
        guard !identifier.isEmpty else { return }

        switch try await GuildService.invite(targetIdentifier: identifier, by: context.session, on: context.db) {
        case .invited(let tg, let loc, let nick, let gname, let gtag, let inviter):
            let notice = "🏰 " + lingo.localize("guild.invite.push", locale: loc, interpolations: ["inviter": inviter, "name": gname, "tag": tagSuffix(gtag)])
            await push(notice, toTelegramId: tg, context: context)
            await postStatusBanner("✅ \(lingo.localize("guild.invite.sent", locale: locale, interpolations: ["nick": nick]))", context: context)
        case .notPermitted:  await postStatusBanner("❌ \(lingo.localize("guild.err.not_permitted", locale: locale))", context: context)
        case .notInGuild:    await postStatusBanner("❌ \(lingo.localize("guild.err.not_in_guild", locale: locale))", context: context)
        case .targetNotFound: await postStatusBanner("❌ \(lingo.localize("guild.err.target_not_found", locale: locale))", context: context)
        case .targetSelf:    await postStatusBanner("❌ \(lingo.localize("guild.err.target_self", locale: locale))", context: context)
        case .targetInGuild: await postStatusBanner("❌ \(lingo.localize("guild.err.target_in_guild", locale: locale))", context: context)
        case .guildFull(let cap): await postStatusBanner("❌ \(lingo.localize("guild.err.guild_full", locale: locale, interpolations: ["cap": "\(cap)"]))", context: context)
        case .alreadyInvited: await postStatusBanner("❌ \(lingo.localize("guild.err.already_invited", locale: locale))", context: context)
        }
    }

    func handleAcceptInvite(inviteId: UUID, context: Context) async throws {
        let lingo = context.lingo, locale = context.session.locale
        switch try await GuildService.acceptInvite(inviteId: inviteId, user: context.session, on: context.db) {
        case .joined(let name, let tag):
            await postStatusBanner("✅ \(lingo.localize("guild.invite.accepted", locale: locale, interpolations: ["name": name, "tag": tagSuffix(tag)]))", context: context)
            try await showGuildHome(context: context)
        case .inviteGone:
            await postStatusBanner("❌ \(lingo.localize("guild.err.invite_gone", locale: locale))", context: context)
            try await showGuildHome(context: context)
        case .alreadyInGuild:
            await postStatusBanner("❌ \(lingo.localize("guild.err.already_in", locale: locale))", context: context)
        case .guildFull(let cap):
            await postStatusBanner("❌ \(lingo.localize("guild.err.guild_full", locale: locale, interpolations: ["cap": "\(cap)"]))", context: context)
        }
    }

    func handleDeclineInvite(inviteId: UUID, context: Context) async throws {
        try await GuildService.declineInvite(inviteId: inviteId, user: context.session, on: context.db)
        await postStatusBanner(context.lingo.localize("guild.invite.declined", locale: context.session.locale), context: context)
        try await showGuildHome(context: context)
    }

    // MARK: - Member management (kick / promote / demote)

    func sendMemberManagement(context: Context) async throws {
        let lingo = context.lingo, locale = context.session.locale
        guard let guildId = context.session.$guild.id, let guild = try await Guild.find(id: guildId, on: context.db) else {
            await postStatusBanner("❌ \(lingo.localize("guild.err.not_in_guild", locale: locale))", context: context)
            return
        }
        let actorRole = context.session.guildRole.flatMap { GuildRole(rawValue: $0) } ?? .member
        guard actorRole.canManageMembers else {
            await postStatusBanner("❌ \(lingo.localize("guild.err.not_permitted", locale: locale))", context: context)
            return
        }
        let members = try await guild.members(on: context.db).sorted { roleRank($0.guildRole) < roleRank($1.guildRole) }
        let officerCount = try await guild.officerCount(on: context.db)

        var rows: [[TGInlineKeyboardButton]] = []
        for m in members {
            guard let mid = m.id, mid != context.session.id else { continue }
            let mRole = m.guildRole.flatMap { GuildRole(rawValue: $0) } ?? .member
            if mRole == .leader { continue }   // the leader is untouchable
            let nick = m.nickname ?? "—"
            var row: [TGInlineKeyboardButton] = []
            if actorRole == .leader {
                if mRole == .member, officerCount < GuildCatalog.maxOfficers {
                    row.append(TGInlineKeyboardButton(text: "🎖 \(nick)", callbackData: "guild:promote:\(mid.uuidString)"))
                } else if mRole == .officer {
                    row.append(TGInlineKeyboardButton(text: "⬇️ \(nick)", callbackData: "guild:demote:\(mid.uuidString)"))
                }
                row.append(TGInlineKeyboardButton(text: "👢 \(nick)", callbackData: "guild:kick:\(mid.uuidString)"))
            } else if mRole == .member {   // officer can only kick plain members
                row.append(TGInlineKeyboardButton(text: "👢 \(nick)", callbackData: "guild:kick:\(mid.uuidString)"))
            }
            if !row.isEmpty { rows.append(row) }
        }

        if rows.isEmpty {
            let body = "<b>\(lingo.localize("guild.members.title", locale: locale))</b>\n\n<i>\(lingo.localize("guild.members.empty", locale: locale))</i>"
            try await context.bot.sendMessage(session: context.session, text: body, parseMode: .html, replyMarkup: nil)
        } else {
            let body = "<b>\(lingo.localize("guild.members.title", locale: locale))</b>"
            try await context.bot.sendMessage(session: context.session, text: body, parseMode: .html, replyMarkup: .inlineKeyboardMarkup(TGInlineKeyboardMarkup(inlineKeyboard: rows)))
        }
    }

    func handleKick(targetId: UUID, context: Context) async throws {
        let lingo = context.lingo, locale = context.session.locale
        switch try await GuildService.kick(targetUserId: targetId, by: context.session, on: context.db) {
        case .kicked(let nick, let tg, let loc, let gname):
            await push("👢 " + lingo.localize("guild.kick.push", locale: loc, interpolations: ["name": gname]), toTelegramId: tg, context: context)
            await postStatusBanner("👢 \(lingo.localize("guild.kicked", locale: locale, interpolations: ["nick": nick]))", context: context)
            try await sendMemberManagement(context: context)
        case .notPermitted:     await postStatusBanner("❌ \(lingo.localize("guild.err.not_permitted", locale: locale))", context: context)
        case .targetNotInGuild: await postStatusBanner("❌ \(lingo.localize("guild.err.target_not_in_guild", locale: locale))", context: context)
        case .cannotKickRank:   await postStatusBanner("❌ \(lingo.localize("guild.err.cannot_kick_rank", locale: locale))", context: context)
        }
    }

    func handleSetOfficer(targetId: UUID, makeOfficer: Bool, context: Context) async throws {
        let lingo = context.lingo, locale = context.session.locale
        switch try await GuildService.setOfficer(targetUserId: targetId, makeOfficer: makeOfficer, by: context.session, on: context.db) {
        case .promoted(let nick, let tg, let loc, let gname):
            await push(lingo.localize("guild.promoted.push", locale: loc, interpolations: ["name": gname]), toTelegramId: tg, context: context)
            await postStatusBanner("🎖 \(lingo.localize("guild.promoted", locale: locale, interpolations: ["nick": nick]))", context: context)
            try await sendMemberManagement(context: context)
        case .demoted(let nick, let tg, let loc, let gname):
            await push(lingo.localize("guild.demoted.push", locale: loc, interpolations: ["name": gname]), toTelegramId: tg, context: context)
            await postStatusBanner("⬇️ \(lingo.localize("guild.demoted", locale: locale, interpolations: ["nick": nick]))", context: context)
            try await sendMemberManagement(context: context)
        case .notLeader:         await postStatusBanner("❌ \(lingo.localize("guild.err.not_permitted", locale: locale))", context: context)
        case .targetNotInGuild:  await postStatusBanner("❌ \(lingo.localize("guild.err.target_not_in_guild", locale: locale))", context: context)
        case .officerCapReached(let max): await postStatusBanner("❌ \(lingo.localize("guild.err.officer_cap", locale: locale, interpolations: ["max": "\(max)"]))", context: context)
        case .invalidTransition: await postStatusBanner("❌ \(lingo.localize("guild.err.not_permitted", locale: locale))", context: context)
        }
    }

    /// Fire-and-forget push to another player's chat (invite / kick / role notices).
    private func push(_ text: String, toTelegramId tg: Int64, context: Context) async {
        _ = try? await context.bot.sendMessage(params: TGSendMessageParams(chatId: .chat(tg), text: text, parseMode: .html))
    }

    // MARK: - Vault (stackables only)

    private func onVaultTapped(context: Context) async throws -> Bool {
        try await showVault(context: context)
        return true
    }

    func showVault(context: Context) async throws {
        let lingo = context.lingo, locale = context.session.locale
        guard let guildId = context.session.$guild.id else {
            await postStatusBanner("❌ \(lingo.localize("guild.err.not_in_guild", locale: locale))", context: context)
            return
        }
        let rows = try await GuildVaultEntry.list(for: guildId, on: context.db)
            .filter { $0.quantity > 0 }
            .sorted { $0.itemId < $1.itemId }
        let used = rows.reduce(0) { $0 + $1.quantity }

        var body = "<b>\(lingo.localize("guild.vault.title", locale: locale))</b>"
        body += "\n" + lingo.localize("guild.vault.cap_line", locale: locale, interpolations: ["used": "\(used)", "cap": "\(GuildCatalog.vaultUnitCap)"])
        if rows.isEmpty {
            body += "\n\n<i>\(lingo.localize("guild.vault.empty", locale: locale))</i>"
        } else {
            body += "\n"
            for r in rows { body += "\n\(itemLabel(r.itemId, qty: r.quantity, lingo: lingo, locale: locale))" }
        }

        let role = context.session.guildRole.flatMap { GuildRole(rawValue: $0) } ?? .member
        var actionRow = [TGInlineKeyboardButton(text: lingo.localize("guild.vault.deposit_btn", locale: locale), callbackData: "guild:vaultdeposit")]
        if role.canWithdrawVault {
            actionRow.append(TGInlineKeyboardButton(text: lingo.localize("guild.vault.withdraw_btn", locale: locale), callbackData: "guild:vaultwithdraw"))
        }
        try await context.bot.sendMessage(session: context.session, text: body, parseMode: .html, replyMarkup: .inlineKeyboardMarkup(TGInlineKeyboardMarkup(inlineKeyboard: [actionRow])))
    }

    func showVaultDepositPicker(context: Context) async throws {
        let lingo = context.lingo, locale = context.session.locale
        guard context.session.$guild.id != nil else {
            await postStatusBanner("❌ \(lingo.localize("guild.err.not_in_guild", locale: locale))", context: context)
            return
        }
        let stacks = try await stackableBagItems(context: context)
        guard !stacks.isEmpty else {
            await postStatusBanner("❌ \(lingo.localize("guild.vault.empty_bag", locale: locale))", context: context)
            return
        }
        var kb: [[TGInlineKeyboardButton]] = []
        for s in stacks {
            kb.append([TGInlineKeyboardButton(text: itemLabel(s.itemId, qty: s.qty, lingo: lingo, locale: locale), callbackData: "guild:vdep:\(s.itemId)")])
        }
        let body = "<b>\(lingo.localize("guild.vault.deposit_pick", locale: locale))</b>"
        try await context.bot.sendMessage(session: context.session, text: body, parseMode: .html, replyMarkup: .inlineKeyboardMarkup(TGInlineKeyboardMarkup(inlineKeyboard: kb)))
    }

    func showVaultWithdrawPicker(context: Context) async throws {
        let lingo = context.lingo, locale = context.session.locale
        guard let guildId = context.session.$guild.id else {
            await postStatusBanner("❌ \(lingo.localize("guild.err.not_in_guild", locale: locale))", context: context)
            return
        }
        let role = context.session.guildRole.flatMap { GuildRole(rawValue: $0) } ?? .member
        guard role.canWithdrawVault else {
            await postStatusBanner("❌ \(lingo.localize("guild.vault.err.cannot_withdraw", locale: locale))", context: context)
            return
        }
        let rows = try await GuildVaultEntry.list(for: guildId, on: context.db)
            .filter { $0.quantity > 0 }
            .sorted { $0.itemId < $1.itemId }
        guard !rows.isEmpty else {
            await postStatusBanner("❌ \(lingo.localize("guild.vault.empty", locale: locale))", context: context)
            return
        }
        var kb: [[TGInlineKeyboardButton]] = []
        for r in rows {
            kb.append([TGInlineKeyboardButton(text: itemLabel(r.itemId, qty: r.quantity, lingo: lingo, locale: locale), callbackData: "guild:vwd:\(r.itemId)")])
        }
        let body = "<b>\(lingo.localize("guild.vault.withdraw_pick", locale: locale))</b>"
        try await context.bot.sendMessage(session: context.session, text: body, parseMode: .html, replyMarkup: .inlineKeyboardMarkup(TGInlineKeyboardMarkup(inlineKeyboard: kb)))
    }

    func startVaultQtyPrompt(itemId: String, deposit: Bool, context: Context) async throws {
        let prompt = await vaultQtyPromptText(itemId: itemId, deposit: deposit, context: context)
        let cancel = context.lingo.localize("guild.found.cancel", locale: context.session.locale)
        let kb = TGInlineKeyboardMarkup(inlineKeyboard: [[TGInlineKeyboardButton(text: cancel, callbackData: "guild:cancelfound")]])
        let sent = try await context.bot.sendMessage(params: TGSendMessageParams(
            chatId: .chat(context.session.telegramId), text: prompt, parseMode: .html, replyMarkup: .inlineKeyboardMarkup(kb)
        ))
        let kind: EphemeralChatState.PendingGuildInput.Kind = deposit ? .vaultDeposit(itemId: itemId) : .vaultWithdraw(itemId: itemId)
        await EphemeralChatState.shared.setPendingGuildInput(
            telegramId: context.session.telegramId,
            input: EphemeralChatState.PendingGuildInput(kind: kind, promptMessageId: sent.messageId)
        )
    }

    private func vaultQtyPromptText(itemId: String, deposit: Bool, context: Context) async -> String {
        let lingo = context.lingo, locale = context.session.locale
        let itemName = ItemCatalog.find(itemId).map { lingo.localize($0.nameKey, locale: locale) } ?? itemId
        let have: Int
        if deposit {
            have = (try? await InventoryEntry.totalQuantity(of: itemId, for: context.session.id ?? UUID(), on: context.db)) ?? 0
            return lingo.localize("guild.vault.deposit_qty_prompt", locale: locale, interpolations: ["item": itemName, "have": "\(have)"])
        } else {
            let guildId = context.session.$guild.id ?? UUID()
            have = (try? await GuildVaultEntry.totalQuantity(of: itemId, for: guildId, on: context.db)) ?? 0
            return lingo.localize("guild.vault.withdraw_qty_prompt", locale: locale, interpolations: ["item": itemName, "have": "\(have)"])
        }
    }

    private func handleVaultQtyInput(text: String, itemId: String, deposit: Bool, pending: EphemeralChatState.PendingGuildInput, context: Context) async throws {
        let lingo = context.lingo, locale = context.session.locale
        let telegramId = context.session.telegramId
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let n = Int(trimmed), n > 0 else {
            // Re-show the prompt in place with an error; keep pending for retry.
            let base = await vaultQtyPromptText(itemId: itemId, deposit: deposit, context: context)
            let err = lingo.localize("capital.market.invalid_number", locale: locale)
            let cancel = lingo.localize("guild.found.cancel", locale: locale)
            let kb = TGInlineKeyboardMarkup(inlineKeyboard: [[TGInlineKeyboardButton(text: cancel, callbackData: "guild:cancelfound")]])
            await editScreen(
                chatId: .chat(telegramId),
                messageId: pending.promptMessageId,
                isPhoto: false,
                text: "\(base)\n\n❌ \(err)",
                replyMarkup: kb,
                bot: context.bot
            )
            return
        }

        _ = await EphemeralChatState.shared.takePendingGuildInput(telegramId: telegramId)
        _ = try? await context.bot.deleteMessage(params: TGDeleteMessageParams(chatId: .chat(telegramId), messageId: pending.promptMessageId))

        let itemName = ItemCatalog.find(itemId).map { lingo.localize($0.nameKey, locale: locale) } ?? itemId
        if deposit {
            switch try await GuildService.depositToVault(itemId: itemId, quantity: n, by: context.session, on: context.db) {
            case .deposited(_, let qty):
                await postStatusBanner("✅ \(lingo.localize("guild.vault.deposited", locale: locale, interpolations: ["item": itemName, "qty": "\(qty)"]))", context: context)
                try await showVault(context: context)
            case .notInGuild:        await postStatusBanner("❌ \(lingo.localize("guild.err.not_in_guild", locale: locale))", context: context)
            case .notStackable:      await postStatusBanner("❌ \(lingo.localize("guild.vault.err.not_stackable", locale: locale))", context: context)
            case .notEnoughInBag(let have): await postStatusBanner("❌ \(lingo.localize("guild.vault.err.not_enough_bag", locale: locale, interpolations: ["have": "\(have)"]))", context: context)
            case .vaultFull(let free): await postStatusBanner("❌ \(lingo.localize("guild.vault.err.vault_full", locale: locale, interpolations: ["free": "\(free)"]))", context: context)
            }
        } else {
            switch try await GuildService.withdrawFromVault(itemId: itemId, quantity: n, by: context.session, on: context.db) {
            case .withdrawn(_, let qty):
                await postStatusBanner("✅ \(lingo.localize("guild.vault.withdrawn", locale: locale, interpolations: ["item": itemName, "qty": "\(qty)"]))", context: context)
                try await showVault(context: context)
            case .notInGuild:    await postStatusBanner("❌ \(lingo.localize("guild.err.not_in_guild", locale: locale))", context: context)
            case .notPermitted:  await postStatusBanner("❌ \(lingo.localize("guild.vault.err.cannot_withdraw", locale: locale))", context: context)
            case .notEnoughInVault(let have): await postStatusBanner("❌ \(lingo.localize("guild.vault.err.not_enough_vault", locale: locale, interpolations: ["have": "\(have)"]))", context: context)
            case .bagFull(let free, let need): await postStatusBanner("❌ \(lingo.localize("guild.vault.err.bag_full", locale: locale, interpolations: ["free": "\(free)", "need": "\(need)"]))", context: context)
            }
        }
    }

    /// Stackable, non-equipped bag items grouped by id — the deposit candidates.
    private func stackableBagItems(context: Context) async throws -> [(itemId: String, qty: Int)] {
        let rows = try await InventoryEntry.list(for: context.session, on: context.db)
        var totals: [String: Int] = [:]
        for row in rows where row.equippedSlot == nil {
            guard let item = ItemCatalog.find(row.itemId), item.stackable else { continue }
            totals[row.itemId, default: 0] += row.quantity
        }
        return totals.filter { $0.value > 0 }
            .map { (itemId: $0.key, qty: $0.value) }
            .sorted { $0.itemId < $1.itemId }
    }

    /// `<icon> <name> ×<qty>` — shared by the vault list + deposit/withdraw pickers.
    private func itemLabel(_ itemId: String, qty: Int, lingo: Lingo, locale: String) -> String {
        let item = ItemCatalog.find(itemId)
        let icon = item?.icon.map { "\($0) " } ?? ""
        let name = item.map { lingo.localize($0.nameKey, locale: locale) } ?? itemId
        return "\(icon)\(name) ×\(qty)"
    }

    // MARK: - Treasury (shared silver pool)

    private func onTreasuryTapped(context: Context) async throws -> Bool {
        try await showTreasury(context: context)
        return true
    }

    func showTreasury(context: Context) async throws {
        let lingo = context.lingo, locale = context.session.locale
        guard let guildId = context.session.$guild.id, let guild = try await Guild.find(id: guildId, on: context.db) else {
            await postStatusBanner("❌ \(lingo.localize("guild.err.not_in_guild", locale: locale))", context: context)
            return
        }
        var body = "<b>\(lingo.localize("guild.treasury.title", locale: locale))</b>"
        body += "\n" + lingo.localize("guild.treasury.balance", locale: locale, interpolations: ["silver": "🪙 \(guild.treasury)"])

        let role = context.session.guildRole.flatMap { GuildRole(rawValue: $0) } ?? .member
        var actionRow = [TGInlineKeyboardButton(text: lingo.localize("guild.vault.deposit_btn", locale: locale), callbackData: "guild:treasdeposit")]
        if role.canWithdrawVault {
            actionRow.append(TGInlineKeyboardButton(text: lingo.localize("guild.vault.withdraw_btn", locale: locale), callbackData: "guild:treaswithdraw"))
        }
        try await context.bot.sendMessage(session: context.session, text: body, parseMode: .html, replyMarkup: .inlineKeyboardMarkup(TGInlineKeyboardMarkup(inlineKeyboard: [actionRow])))
    }

    func startTreasuryPrompt(deposit: Bool, context: Context) async throws {
        let lingo = context.lingo, locale = context.session.locale
        if !deposit {
            let role = context.session.guildRole.flatMap { GuildRole(rawValue: $0) } ?? .member
            guard role.canWithdrawVault else {
                await postStatusBanner("❌ \(lingo.localize("guild.treasury.err.cannot_withdraw", locale: locale))", context: context)
                return
            }
        }
        let prompt = await treasuryPromptText(deposit: deposit, context: context)
        let cancel = lingo.localize("guild.found.cancel", locale: locale)
        let kb = TGInlineKeyboardMarkup(inlineKeyboard: [[TGInlineKeyboardButton(text: cancel, callbackData: "guild:cancelfound")]])
        let sent = try await context.bot.sendMessage(params: TGSendMessageParams(
            chatId: .chat(context.session.telegramId), text: prompt, parseMode: .html, replyMarkup: .inlineKeyboardMarkup(kb)
        ))
        let kind: EphemeralChatState.PendingGuildInput.Kind = deposit ? .treasuryDeposit : .treasuryWithdraw
        await EphemeralChatState.shared.setPendingGuildInput(
            telegramId: context.session.telegramId,
            input: EphemeralChatState.PendingGuildInput(kind: kind, promptMessageId: sent.messageId)
        )
    }

    private func treasuryPromptText(deposit: Bool, context: Context) async -> String {
        let lingo = context.lingo, locale = context.session.locale
        if deposit {
            return lingo.localize("guild.treasury.deposit_prompt", locale: locale, interpolations: ["have": "🪙 \(context.session.silver)"])
        }
        let guildId = context.session.$guild.id ?? UUID()
        let guild = try? await Guild.find(id: guildId, on: context.db)
        let balance = (guild ?? nil)?.treasury ?? 0
        return lingo.localize("guild.treasury.withdraw_prompt", locale: locale, interpolations: ["have": "🪙 \(balance)"])
    }

    private func handleTreasuryInput(text: String, deposit: Bool, pending: EphemeralChatState.PendingGuildInput, context: Context) async throws {
        let lingo = context.lingo, locale = context.session.locale
        let telegramId = context.session.telegramId
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let n = Int(trimmed), n > 0 else {
            let base = await treasuryPromptText(deposit: deposit, context: context)
            let err = lingo.localize("capital.market.invalid_number", locale: locale)
            let cancel = lingo.localize("guild.found.cancel", locale: locale)
            let kb = TGInlineKeyboardMarkup(inlineKeyboard: [[TGInlineKeyboardButton(text: cancel, callbackData: "guild:cancelfound")]])
            await editScreen(
                chatId: .chat(telegramId),
                messageId: pending.promptMessageId,
                isPhoto: false,
                text: "\(base)\n\n❌ \(err)",
                replyMarkup: kb,
                bot: context.bot
            )
            return
        }

        _ = await EphemeralChatState.shared.takePendingGuildInput(telegramId: telegramId)
        _ = try? await context.bot.deleteMessage(params: TGDeleteMessageParams(chatId: .chat(telegramId), messageId: pending.promptMessageId))

        if deposit {
            switch try await GuildService.depositSilver(amount: n, by: context.session, on: context.db) {
            case .deposited(let amount, _):
                await postStatusBanner("✅ \(lingo.localize("guild.treasury.deposited", locale: locale, interpolations: ["silver": "🪙 \(amount)"]))", context: context)
                try await showTreasury(context: context)
            case .notInGuild:        await postStatusBanner("❌ \(lingo.localize("guild.err.not_in_guild", locale: locale))", context: context)
            case .notEnoughSilver(let have): await postStatusBanner("❌ \(lingo.localize("guild.treasury.err.not_enough_silver", locale: locale, interpolations: ["have": "🪙 \(have)"]))", context: context)
            }
        } else {
            switch try await GuildService.withdrawSilver(amount: n, by: context.session, on: context.db) {
            case .withdrawn(let amount, _):
                await postStatusBanner("✅ \(lingo.localize("guild.treasury.withdrawn", locale: locale, interpolations: ["silver": "🪙 \(amount)"]))", context: context)
                try await showTreasury(context: context)
            case .notInGuild:    await postStatusBanner("❌ \(lingo.localize("guild.err.not_in_guild", locale: locale))", context: context)
            case .notPermitted:  await postStatusBanner("❌ \(lingo.localize("guild.treasury.err.cannot_withdraw", locale: locale))", context: context)
            case .notEnoughTreasury(let have): await postStatusBanner("❌ \(lingo.localize("guild.treasury.err.not_enough_treasury", locale: locale, interpolations: ["have": "🪙 \(have)"]))", context: context)
            }
        }
    }

    // MARK: - Callback dispatch

    static func onCallbackQuery(context: Context) async throws -> Bool {
        guard let query = context.update.callbackQuery else { return false }
        guard let data = query.data else { return false }
        let ctrl = Controllers.guildController
        func ack() async { _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id)) }
        func uuid(_ prefix: String) -> UUID? { UUID(uuidString: String(data.dropFirst(prefix.count))) }

        switch true {
        case data == "guild:cancelfound":
            await ack(); try await ctrl.cancelFoundPrompt(context: context); return true
        case data == "guild:leave":
            await ack(); try await ctrl.handleLeave(context: context); return true
        case data == "guild:disband":
            await ack(); try await ctrl.handleDisband(context: context); return true
        case data == "guild:invite":
            await ack(); try await ctrl.startInvitePrompt(context: context); return true
        case data == "guild:managemembers":
            await ack(); try await ctrl.sendMemberManagement(context: context); return true
        case data == "guild:vault":
            await ack(); try await ctrl.showVault(context: context); return true
        case data == "guild:vaultdeposit":
            await ack(); try await ctrl.showVaultDepositPicker(context: context); return true
        case data == "guild:vaultwithdraw":
            await ack(); try await ctrl.showVaultWithdrawPicker(context: context); return true
        case data.hasPrefix("guild:vdep:"):
            await ack(); try await ctrl.startVaultQtyPrompt(itemId: String(data.dropFirst("guild:vdep:".count)), deposit: true, context: context); return true
        case data.hasPrefix("guild:vwd:"):
            await ack(); try await ctrl.startVaultQtyPrompt(itemId: String(data.dropFirst("guild:vwd:".count)), deposit: false, context: context); return true
        case data == "guild:treasury":
            await ack(); try await ctrl.showTreasury(context: context); return true
        case data == "guild:treasdeposit":
            await ack(); try await ctrl.startTreasuryPrompt(deposit: true, context: context); return true
        case data == "guild:treaswithdraw":
            await ack(); try await ctrl.startTreasuryPrompt(deposit: false, context: context); return true
        case data.hasPrefix("guild:acceptinv:"):
            await ack(); if let id = uuid("guild:acceptinv:") { try await ctrl.handleAcceptInvite(inviteId: id, context: context) }; return true
        case data.hasPrefix("guild:declineinv:"):
            await ack(); if let id = uuid("guild:declineinv:") { try await ctrl.handleDeclineInvite(inviteId: id, context: context) }; return true
        case data.hasPrefix("guild:kick:"):
            await ack(); if let id = uuid("guild:kick:") { try await ctrl.handleKick(targetId: id, context: context) }; return true
        case data.hasPrefix("guild:promote:"):
            await ack(); if let id = uuid("guild:promote:") { try await ctrl.handleSetOfficer(targetId: id, makeOfficer: true, context: context) }; return true
        case data.hasPrefix("guild:demote:"):
            await ack(); if let id = uuid("guild:demote:") { try await ctrl.handleSetOfficer(targetId: id, makeOfficer: false, context: context) }; return true
        default:
            // Unknown (e.g. a stale inline button) — hand to MainController, same as
            // CapitalController, instead of shouting "unsupported content".
            return try await MainController.onCallbackQuery(context: context)
        }
    }

    // MARK: - Role display helpers

    /// ` [TAG]` suffix, or empty while the guild has no tag yet (the creator
    /// assigns it manually). Keeps display clean instead of showing `[]`.
    private func tagSuffix(_ tag: String) -> String {
        tag.isEmpty ? "" : " [\(tag)]"
    }

    private func roleBadge(_ raw: String?) -> String {
        switch raw.flatMap({ GuildRole(rawValue: $0) }) ?? .member {
        case .leader:  return "👑"
        case .officer: return "🎖"
        case .member:  return "🧑"
        }
    }

    private func roleDisplay(_ raw: String?, lingo: Lingo, locale: String) -> String {
        let role = raw.flatMap { GuildRole(rawValue: $0) } ?? .member
        return "\(roleBadge(raw)) \(lingo.localize("guild.role.\(role.rawValue)", locale: locale))"
    }

    /// Sort order for the roster: leader, then officers, then members.
    private func roleRank(_ raw: String?) -> Int {
        switch raw.flatMap({ GuildRole(rawValue: $0) }) ?? .member {
        case .leader:  return 0
        case .officer: return 1
        case .member:  return 2
        }
    }
}
