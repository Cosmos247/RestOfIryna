//
//  ArenaController.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 20.07.2026.
//
//  Phase 8.3 — the capital Arena ("Ристалище"). Reached from CapitalController's
//  «⚔️ Ристалище» button, which flips `routerName` to "arena" (this controller
//  then owns the reply keyboard, mirroring GuildController / CombatController).
//
//  Two surfaces share the same reply keyboard, guarded by whether the player is
//  currently in a live duel:
//    • hub  → [⚔️ Виклик] [🏆 Честь] / [🔙 Столиця]   (browse + challenge)
//    • duel → [⚔️ Атака] [🛡 Оборона] / [🏳 Здатися]   (alternating live герць)
//  The live fight is a two-party in-memory object in `ArenaStore`; `ArenaService`
//  does the DB work (stake transfer, Honor/ELO, HP carry-over). Turn timeouts +
//  challenge expiry are driven by ArenaService's background sweeper, which reuses
//  the static `push*` render helpers at the bottom of this file.
//

import Foundation
import Lingo
import SwiftTelegramBot
import Fluent

final class ArenaController: TGControllerBase, @unchecked Sendable {

    // MARK: - Lifecycle

    override public func attachHandlers(to bot: TGBot, lingo: Lingo) async {
        let router = Router(bot: bot) { router in
            router[Commands.start.command()] = onStart

            for locale in SupportedLocale.allCases {
                router[lingo.localize("arena.button.back",      locale: locale)] = onBackToCapital
                router[lingo.localize("arena.button.challenge",  locale: locale)] = onChallengeTapped
                router[lingo.localize("arena.button.honor",      locale: locale)] = onHonorTapped
                router[lingo.localize("arena.button.attack",     locale: locale)] = onAttackTapped
                router[lingo.localize("arena.button.defend",     locale: locale)] = onDefendTapped
                router[lingo.localize("arena.button.surrender",  locale: locale)] = onSurrenderTapped
            }

            router[.callback_query(data: nil)] = ArenaController.onCallbackQuery
            router.unmatched = unmatched
        }
        await processRouterForEachName(router)
    }

    /// Hub keyboard. During a live duel the fight keyboard (pushed on every
    /// round) takes over; this is what a non-dueling player sees.
    override public func generateControllerKB(session: User, lingo: Lingo) -> TGReplyMarkup? {
        Self.hubKeyboard(locale: session.locale, lingo: lingo)
    }

    override func unmatched(context: Context) async throws -> Bool {
        guard try await super.unmatched(context: context) else { return false }
        try await showArenaHome(context: context)
        return true
    }

    // MARK: - Top-level handlers

    public func onStart(context: Context) async throws -> Bool {
        await forfeitIfDueling(context: context)
        await ArenaStore.shared.leaveLobby(telegramId: context.session.telegramId)
        try await Controllers.mainController.showMainMenu(context: context)
        context.session.routerName = Controllers.mainController.routerName
        try await context.session.saveAndCache(in: context.db)
        return true
    }

    private func onBackToCapital(context: Context) async throws -> Bool {
        await forfeitIfDueling(context: context)
        await ArenaStore.shared.leaveLobby(telegramId: context.session.telegramId)
        try await Controllers.capitalController.showCapital(context: context)
        return true
    }

    /// Leaving mid-duel counts as a surrender. Settles + notifies the winner.
    /// Also cancels any still-pending challenge this player is part of so a stale
    /// invite can't be answered after they've gone.
    private func forfeitIfDueling(context: Context) async {
        let tg = context.session.telegramId
        if let ended = await ArenaStore.shared.surrender(tg: tg) {
            if let settlement = try? await ArenaService.settle(ended, on: context.db) {
                await Self.pushDuelResult(settlement, finalLog: ["forfeit|0"], bot: context.bot, lingo: context.lingo)
            }
            return
        }
        if let pc = await ArenaStore.shared.cancelPendingInvolving(tg) {
            // Tell whichever party is NOT the leaver that the challenge is off.
            let otherTg = pc.challenger.telegramId == tg ? pc.opponentTelegramId : pc.challenger.telegramId
            let otherLocale = pc.challenger.telegramId == tg ? pc.opponentLocale : pc.challenger.locale
            _ = try? await context.bot.sendMessage(params: TGSendMessageParams(
                chatId: .chat(otherTg),
                text: "🚫 " + context.lingo.localize("arena.invite.aborted", locale: otherLocale.isEmpty ? "uk" : otherLocale),
                parseMode: .html
            ))
        }
    }

    // MARK: - Home

    /// Entry point from CapitalController (after it flips routerName to "arena").
    func showArenaHome(context: Context) async throws {
        let tg = context.session.telegramId
        // Reconnect: if a duel is somehow still live, re-render its state.
        if let duel = await ArenaStore.shared.activeDuel(for: tg) {
            await Self.pushDuelState(duel, log: [], actorTelegramId: nil, bot: context.bot, lingo: context.lingo)
            return
        }
        await ArenaStore.shared.touchLobby(telegramId: tg, nickname: context.session.nickname ?? "—")

        let lingo = context.lingo, locale = context.session.locale
        guard let userId = context.session.id else { return }
        let profile = try await ArenaProfile.forUser(userId, on: context.db)
        let text = Self.hubBody(profile: profile, lingo: lingo, locale: locale)
        try await context.bot.sendMessage(session: context.session, text: text, parseMode: .html, replyMarkup: generateControllerKB(session: context.session, lingo: lingo))
    }

    // MARK: - Challenge (browse lobby → pick opponent → pick stake)

    private func onChallengeTapped(context: Context) async throws -> Bool {
        let lingo = context.lingo, locale = context.session.locale
        let tg = context.session.telegramId
        if await ArenaStore.shared.activeDuel(for: tg) != nil { try await showArenaHome(context: context); return true }
        await ArenaStore.shared.touchLobby(telegramId: tg, nickname: context.session.nickname ?? "—")

        let members = await ArenaStore.shared.lobbyMembers(excluding: tg)
        var body = "<b>\(lingo.localize("arena.challenge.title", locale: locale))</b>"
        if members.isEmpty {
            body += "\n\n<i>\(lingo.localize("arena.challenge.empty", locale: locale))</i>"
            try await context.bot.sendMessage(session: context.session, text: body, parseMode: .html, replyMarkup: nil)
            return true
        }
        var rows: [[TGInlineKeyboardButton]] = []
        for m in members.prefix(20) {
            rows.append([TGInlineKeyboardButton(text: "🗡 \(m.nickname)", callbackData: "arena:chal:\(m.telegramId)")])
        }
        try await context.bot.sendMessage(session: context.session, text: body, parseMode: .html, replyMarkup: .inlineKeyboardMarkup(TGInlineKeyboardMarkup(inlineKeyboard: rows)))
        return true
    }

    /// Opponent picked — offer the stake tiers.
    func showStakePicker(opponentTg: Int64, context: Context) async throws {
        let lingo = context.lingo, locale = context.session.locale
        let members = await ArenaStore.shared.lobbyMembers(excluding: context.session.telegramId)
        guard let opp = members.first(where: { $0.telegramId == opponentTg }) else {
            await postStatusBanner("❌ \(lingo.localize("arena.challenge.gone", locale: locale))", context: context)
            return
        }
        var rows: [[TGInlineKeyboardButton]] = ArenaCatalog.stakeTiers.map { tier in
            [TGInlineKeyboardButton(text: "🪙 \(tier)", callbackData: "arena:stake:\(opponentTg):\(tier)")]
        }
        rows.append([TGInlineKeyboardButton(text: lingo.localize("arena.challenge.cancel", locale: locale), callbackData: "arena:chalcancel")])
        let body = lingo.localize("arena.challenge.pick_stake", locale: locale, interpolations: ["nick": opp.nickname])
        try await context.bot.sendMessage(session: context.session, text: body, parseMode: .html, replyMarkup: .inlineKeyboardMarkup(TGInlineKeyboardMarkup(inlineKeyboard: rows)))
    }

    /// Stake chosen — validate + issue the challenge, push the invite to the target.
    func issueChallenge(opponentTg: Int64, stake: Int, context: Context) async throws {
        let lingo = context.lingo, locale = context.session.locale
        guard let opponent = try await User.query(on: context.db).filter(\.$telegramId, .equal, opponentTg).first() else {
            await postStatusBanner("❌ \(lingo.localize("arena.challenge.gone", locale: locale))", context: context)
            return
        }
        switch try await ArenaService.validateMatch(challenger: context.session, opponent: opponent, stake: stake, on: context.db) {
        case .failed(let problem):
            await postStatusBanner("❌ \(Self.matchProblemText(problem, lingo: lingo, locale: locale))", context: context)
            return
        case .ok(let challengerHonor, _):
            let challenger = ArenaService.snapshot(for: context.session, stake: stake, honor: challengerHonor)
            switch await ArenaStore.shared.challenge(challenger: challenger, stake: stake, targetTelegramId: opponentTg) {
            case .created(let pc):
                // Push the invite to the opponent's chat.
                let text = "⚔️ " + lingo.localize("arena.invite.push", locale: opponent.locale, interpolations: [
                    "nick": context.session.nickname ?? "—", "stake": "🪙 \(stake)"
                ])
                let kb = TGInlineKeyboardMarkup(inlineKeyboard: [[
                    TGInlineKeyboardButton(text: lingo.localize("arena.invite.accept", locale: opponent.locale), callbackData: "arena:acc:\(pc.id.uuidString)"),
                    TGInlineKeyboardButton(text: lingo.localize("arena.invite.decline", locale: opponent.locale), callbackData: "arena:dec:\(pc.id.uuidString)")
                ]])
                _ = try? await context.bot.sendMessage(params: TGSendMessageParams(chatId: .chat(opponentTg), text: text, parseMode: .html, replyMarkup: .inlineKeyboardMarkup(kb)))
                await postStatusBanner("✅ \(lingo.localize("arena.challenge.sent", locale: locale, interpolations: ["nick": opponent.nickname ?? "—"]))", context: context)
            case .selfBusy:
                await postStatusBanner("❌ \(lingo.localize("arena.challenge.self_busy", locale: locale))", context: context)
            case .targetBusy:
                await postStatusBanner("❌ \(lingo.localize("arena.challenge.busy", locale: locale))", context: context)
            case .targetGone:
                await postStatusBanner("❌ \(lingo.localize("arena.challenge.gone", locale: locale))", context: context)
            }
        }
    }

    // MARK: - Accept / decline

    func acceptChallenge(pendingId: UUID, context: Context) async throws {
        let lingo = context.lingo, locale = context.session.locale
        guard let pc = await ArenaStore.shared.pendingChallenge(pendingId), pc.opponentTelegramId == context.session.telegramId else {
            await postStatusBanner("❌ \(lingo.localize("arena.invite.expired", locale: locale))", context: context)
            return
        }
        guard let challengerUser = try await User.find(pc.challenger.userId, on: context.db) else {
            _ = await ArenaStore.shared.cancelPending(pendingId)
            await postStatusBanner("❌ \(lingo.localize("arena.invite.expired", locale: locale))", context: context)
            return
        }
        // Re-validate at accept-time (silver / HP may have moved).
        switch try await ArenaService.validateMatch(challenger: challengerUser, opponent: context.session, stake: pc.stake, on: context.db) {
        case .failed(let problem):
            _ = await ArenaStore.shared.cancelPending(pendingId)
            await postStatusBanner("❌ \(Self.matchProblemText(problem, lingo: lingo, locale: locale))", context: context)
            _ = try? await context.bot.sendMessage(params: TGSendMessageParams(chatId: .chat(challengerUser.telegramId), text: "❌ " + lingo.localize("arena.invite.aborted", locale: challengerUser.locale), parseMode: .html))
        case .ok(let challengerHonor, let opponentHonor):
            let a = ArenaService.snapshot(for: challengerUser, stake: pc.stake, honor: challengerHonor)
            let b = ArenaService.snapshot(for: context.session, stake: pc.stake, honor: opponentHonor)
            guard let duel = await ArenaStore.shared.startDuel(pendingId: pendingId, challenger: a, opponent: b) else {
                await postStatusBanner("❌ \(lingo.localize("arena.invite.expired", locale: locale))", context: context)
                return
            }
            // Both fighters get the opening scoreboard + fight keyboard.
            await Self.pushDuelState(duel, log: [], actorTelegramId: nil, bot: context.bot, lingo: context.lingo)
        }
    }

    func declineChallenge(pendingId: UUID, context: Context) async throws {
        let lingo = context.lingo, locale = context.session.locale
        guard let pc = await ArenaStore.shared.cancelPending(pendingId) else { return }
        await postStatusBanner(lingo.localize("arena.invite.you_declined", locale: locale), context: context)
        _ = try? await context.bot.sendMessage(params: TGSendMessageParams(
            chatId: .chat(pc.challenger.telegramId),
            text: "🚫 " + lingo.localize("arena.invite.declined_push", locale: pc.challenger.locale, interpolations: ["nick": context.session.nickname ?? "—"]),
            parseMode: .html
        ))
    }

    // MARK: - Fight actions

    private func onAttackTapped(context: Context) async throws -> Bool { try await handleAction(.attack, context: context); return true }
    private func onDefendTapped(context: Context) async throws -> Bool { try await handleAction(.defend, context: context); return true }

    private func handleAction(_ action: ArenaStore.FighterAction, context: Context) async throws {
        let lingo = context.lingo, locale = context.session.locale
        let tg = context.session.telegramId
        switch await ArenaStore.shared.resolve(action: action, tg: tg) {
        case .continued(let duel, let log):
            await Self.pushDuelState(duel, log: log, actorTelegramId: tg, bot: context.bot, lingo: context.lingo)
        case .ended(let ended, let log):
            if let settlement = try? await ArenaService.settle(ended, on: context.db) {
                await Self.pushDuelResult(settlement, finalLog: log, bot: context.bot, lingo: context.lingo)
            }
        case .notYourTurn:
            await postStatusBanner("⏳ \(lingo.localize("arena.duel.not_your_turn", locale: locale))", context: context)
        case .noDuel:
            try await showArenaHome(context: context)
        }
    }

    private func onSurrenderTapped(context: Context) async throws -> Bool {
        let tg = context.session.telegramId
        guard let ended = await ArenaStore.shared.surrender(tg: tg) else {
            try await showArenaHome(context: context)
            return true
        }
        if let settlement = try? await ArenaService.settle(ended, on: context.db) {
            await Self.pushDuelResult(settlement, finalLog: ["surrender|0"], bot: context.bot, lingo: context.lingo)
        }
        return true
    }

    // MARK: - Honor / leaderboard

    private func onHonorTapped(context: Context) async throws -> Bool {
        let lingo = context.lingo, locale = context.session.locale
        if await ArenaStore.shared.activeDuel(for: context.session.telegramId) != nil { try await showArenaHome(context: context); return true }
        guard let userId = context.session.id else { return true }
        let profile = try await ArenaProfile.forUser(userId, on: context.db)
        let league = lingo.localize(ArenaCatalog.leagueKey(forHonor: profile.honor), locale: locale)
        var body = "<b>\(lingo.localize("arena.honor.title", locale: locale))</b>\n\n"
        body += lingo.localize("arena.honor.body", locale: locale, interpolations: [
            "honor": "\(profile.honor)", "league": league,
            "wins": "\(profile.wins)", "losses": "\(profile.losses)",
            "today": "\(profile.fightsSpentToday())", "cap": "\(ArenaCatalog.dailyFightCap)"
        ])

        // Top of the ladder.
        let top = try await ArenaProfile.leaderboard(limit: 10, on: context.db)
        body += "\n\n<b>\(lingo.localize("arena.leaderboard.title", locale: locale))</b>"
        if top.isEmpty {
            body += "\n<i>\(lingo.localize("arena.leaderboard.empty", locale: locale))</i>"
        } else {
            var rank = 1
            for p in top {
                let owner = try await User.find(p.$user.id, on: context.db)
                let nick = owner?.nickname ?? "—"
                body += "\n" + lingo.localize("arena.leaderboard.row", locale: locale, interpolations: [
                    "rank": "\(rank)", "nick": nick, "honor": "\(p.honor)"
                ])
                rank += 1
            }
        }
        try await context.bot.sendMessage(session: context.session, text: body, parseMode: .html, replyMarkup: nil)
        return true
    }

    // MARK: - Callback dispatch

    static func onCallbackQuery(context: Context) async throws -> Bool {
        guard let query = context.update.callbackQuery, let data = query.data else { return false }
        let ctrl = Controllers.arenaController
        func ack() async { _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id)) }

        switch true {
        case data == "arena:chalcancel":
            await ack(); return true
        case data.hasPrefix("arena:chal:"):
            await ack()
            if let tg = Int64(String(data.dropFirst("arena:chal:".count))) { try await ctrl.showStakePicker(opponentTg: tg, context: context) }
            return true
        case data.hasPrefix("arena:stake:"):
            await ack()
            let parts = data.dropFirst("arena:stake:".count).split(separator: ":")
            if parts.count == 2, let tg = Int64(parts[0]), let stake = Int(parts[1]) {
                try await ctrl.issueChallenge(opponentTg: tg, stake: stake, context: context)
            }
            return true
        case data.hasPrefix("arena:acc:"):
            await ack()
            if let id = UUID(uuidString: String(data.dropFirst("arena:acc:".count))) { try await ctrl.acceptChallenge(pendingId: id, context: context) }
            return true
        case data.hasPrefix("arena:dec:"):
            await ack()
            if let id = UUID(uuidString: String(data.dropFirst("arena:dec:".count))) { try await ctrl.declineChallenge(pendingId: id, context: context) }
            return true
        default:
            return try await MainController.onCallbackQuery(context: context)
        }
    }

    // MARK: - Keyboards

    static func hubKeyboard(locale: String, lingo: Lingo) -> TGReplyMarkup {
        .replyKeyboardMarkup(TGReplyKeyboardMarkup(keyboard: [
            [TGKeyboardButton(text: lingo.localize("arena.button.challenge", locale: locale)),
             TGKeyboardButton(text: lingo.localize("arena.button.honor", locale: locale))],
            [TGKeyboardButton(text: lingo.localize("arena.button.back", locale: locale))]
        ], resizeKeyboard: true))
    }

    static func fightKeyboard(locale: String, lingo: Lingo) -> TGReplyMarkup {
        .replyKeyboardMarkup(TGReplyKeyboardMarkup(keyboard: [
            [TGKeyboardButton(text: lingo.localize("arena.button.attack", locale: locale)),
             TGKeyboardButton(text: lingo.localize("arena.button.defend", locale: locale))],
            [TGKeyboardButton(text: lingo.localize("arena.button.surrender", locale: locale))]
        ], resizeKeyboard: true))
    }

    // MARK: - Render helpers (shared with the sweeper)

    static func hubBody(profile: ArenaProfile, lingo: Lingo, locale: String) -> String {
        let league = lingo.localize(ArenaCatalog.leagueKey(forHonor: profile.honor), locale: locale)
        var body = "<b>\(lingo.localize("arena.hub.title", locale: locale))</b>\n\n"
        body += lingo.localize("arena.hub.body", locale: locale, interpolations: [
            "honor": "\(profile.honor)", "league": league,
            "today": "\(profile.fightsSpentToday())", "cap": "\(ArenaCatalog.dailyFightCap)"
        ])
        return body
    }

    /// Localized one-line summary of a combat-log token, prefixed with the actor.
    private static func logLine(_ token: String, actorNick: String, lingo: Lingo, locale: String) -> String? {
        let parts = token.split(separator: "|")
        guard let kind = parts.first else { return nil }
        let amount = parts.count > 1 ? String(parts[1]) : "0"
        let line: String
        switch kind {
        case "hit":        line = lingo.localize("arena.log.hit", locale: locale, interpolations: ["dmg": amount])
        case "crit":       line = lingo.localize("arena.log.crit", locale: locale, interpolations: ["dmg": amount])
        case "miss":       line = lingo.localize("arena.log.miss", locale: locale)
        case "🛡":          line = lingo.localize("arena.log.defend", locale: locale, interpolations: ["dmg": amount])
        case "timeout":    line = lingo.localize("arena.log.timeout", locale: locale, interpolations: ["dmg": amount])
        default:           return nil
        }
        return "\(actorNick): \(line)"
    }

    /// Push the current scoreboard + whose-turn line + fight keyboard to BOTH
    /// fighters. `actorTelegramId` is who just acted (nil for the opening frame).
    static func pushDuelState(_ duel: ArenaStore.Duel, log: [String], actorTelegramId: Int64?, bot: TGBot, lingo: Lingo) async {
        let actorNick = actorTelegramId.map { duel.me($0).nickname } ?? ""
        for fighter in [duel.a, duel.b] {
            let locale = fighter.locale
            var body = "<b>\(lingo.localize("arena.duel.header", locale: locale, interpolations: ["round": "\(duel.round)"]))</b>\n"
            body += "\n" + scoreLine(duel.a, lingo: lingo, locale: locale)
            body += "\n" + scoreLine(duel.b, lingo: lingo, locale: locale)
            if let token = log.last, let line = logLine(token, actorNick: actorNick, lingo: lingo, locale: locale) {
                body += "\n\n\(line)"
            }
            body += "\n\n" + (duel.turn == fighter.telegramId
                ? "🗡 " + lingo.localize("arena.duel.your_turn", locale: locale)
                : "⏳ " + lingo.localize("arena.duel.their_turn", locale: locale, interpolations: ["nick": duel.opp(fighter.telegramId).nickname]))
            _ = try? await bot.sendMessage(params: TGSendMessageParams(
                chatId: .chat(fighter.telegramId), text: body, parseMode: .html,
                replyMarkup: fightKeyboard(locale: locale, lingo: lingo)
            ))
        }
    }

    private static func scoreLine(_ c: ArenaStore.Combatant, lingo: Lingo, locale: String) -> String {
        lingo.localize("arena.duel.scoreline", locale: locale, interpolations: [
            "nick": c.nickname, "hp": "\(c.hp)", "max": "\(c.maxHp)"
        ])
    }

    /// Push the final result to both fighters and restore the hub keyboard.
    static func pushDuelResult(_ s: ArenaService.Settlement, finalLog: [String], bot: TGBot, lingo: Lingo) async {
        // Winner.
        let wLocale = s.winnerLocale
        var wBody = "🏆 <b>\(lingo.localize("arena.result.win_title", locale: wLocale))</b>\n\n"
        wBody += lingo.localize("arena.result.win_body", locale: wLocale, interpolations: [
            "nick": s.loserNickname, "payout": "🪙 \(s.payout)", "tithe": "🪙 \(s.tithe)",
            "hb": "\(s.winnerHonorBefore)", "ha": "\(s.winnerHonorAfter)",
            "hp": "\(s.winnerHp)", "max": "\(s.winnerMaxHp)"
        ])
        _ = try? await bot.sendMessage(params: TGSendMessageParams(
            chatId: .chat(s.winnerTelegramId), text: wBody, parseMode: .html,
            replyMarkup: hubKeyboard(locale: wLocale, lingo: lingo)
        ))

        // Loser.
        let lLocale = s.loserLocale
        var lBody = "💀 <b>\(lingo.localize("arena.result.loss_title", locale: lLocale))</b>\n\n"
        lBody += lingo.localize("arena.result.loss_body", locale: lLocale, interpolations: [
            "nick": s.winnerNickname, "stake": "🪙 \(s.stake)",
            "hb": "\(s.loserHonorBefore)", "ha": "\(s.loserHonorAfter)",
            "hp": "\(s.loserHp)", "max": "\(s.loserMaxHp)"
        ])
        _ = try? await bot.sendMessage(params: TGSendMessageParams(
            chatId: .chat(s.loserTelegramId), text: lBody, parseMode: .html,
            replyMarkup: hubKeyboard(locale: lLocale, lingo: lingo)
        ))
    }

    /// A challenge went unanswered — tell the challenger and free both.
    static func pushChallengeExpired(_ pc: ArenaStore.PendingChallenge, bot: TGBot, lingo: Lingo) async {
        let locale = pc.challenger.locale
        _ = try? await bot.sendMessage(params: TGSendMessageParams(
            chatId: .chat(pc.challenger.telegramId),
            text: "⌛ " + lingo.localize("arena.invite.expired_push", locale: locale, interpolations: ["nick": pc.opponentNickname]),
            parseMode: .html,
            replyMarkup: hubKeyboard(locale: locale, lingo: lingo)
        ))
    }

    // MARK: - Error copy

    private static func matchProblemText(_ p: ArenaService.MatchProblem, lingo: Lingo, locale: String) -> String {
        switch p {
        case .challengerBroke(let have, let need):
            return lingo.localize("arena.err.broke", locale: locale, interpolations: ["need": "🪙 \(need)", "have": "🪙 \(have)"])
        case .opponentBroke:
            return lingo.localize("arena.err.opponent_broke", locale: locale)
        case .challengerDead:   return lingo.localize("arena.err.dead", locale: locale)
        case .opponentDead:     return lingo.localize("arena.err.opponent_dead", locale: locale)
        case .challengerDailyCap: return lingo.localize("arena.err.daily_cap", locale: locale)
        case .opponentDailyCap:   return lingo.localize("arena.err.opponent_daily_cap", locale: locale)
        }
    }
}
