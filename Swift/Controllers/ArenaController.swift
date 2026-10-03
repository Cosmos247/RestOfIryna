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
//    • duel → [⚔️ Атака] [🛡 Оборона] / [🪓 прийом] [🏳 Здатися]   (simultaneous rounds)
//  The third button is the fighter's class special attack — the duel is a cycle
//  of three (Attack beats it, it breaks Defend, Defend turns Attack), so the
//  arena admits only those who have learned it (`ArenaCatalog.admissionTechnique`).
//  The live fight is a two-party in-memory object in `ArenaStore`; `ArenaService`
//  does the DB work (stake transfer, Honor/ELO, HP carry-over). Round clocks +
//  challenge expiry are driven by ArenaService's background sweeper, which reuses
//  the static `push*` render helpers at the bottom of this file.
//
//  Every line of a round is written from the viewer's side — «⚔️ Ви: удар —
//  26 ОЗ» over «🩸 Petro: удар — 32 ОЗ» — and the result screen opens with the
//  round that ended the duel, the way a forest death screen carries the
//  killing blow (2026-09-27). It used to end on «Перемога!» with the blow
//  nowhere in the chat.
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
                // Every class's label: the router is shared, and the label is
                // only ever on the keyboard of the class it names.
                for cls in CharacterClass.allCases {
                    router[Self.techniqueLabel(cls, lingo: lingo, locale: locale.rawValue)] = onTechniqueTapped
                }
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
            await Self.finish(ended, db: context.db, bot: context.bot, lingo: context.lingo)
            return
        }
        if let pc = await ArenaStore.shared.cancelPendingInvolving(tg) {
            // Whoever leaves, the bubble in the opponent's chat still holds live
            // buttons — strip them. When the LEAVER is the opponent it is their
            // own bubble being closed, which is right either way.
            await Self.closeInvite(pc, key: "arena.invite.closed_aborted", icon: "🚫", bot: context.bot, lingo: context.lingo)
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
        // Reconnect: if a duel is still live, re-draw its round for this
        // fighter alone.
        if let duel = await ArenaStore.shared.activeDuel(for: tg) {
            await Self.pushDuelFrame(duel, to: tg, bot: context.bot, lingo: context.lingo)
            return
        }
        // The capital refuses the door already; this catches a player whose
        // routerName was left on "arena" from before the arena needed a
        // technique — they go back to the square with the reason.
        guard try await ArenaService.isAdmitted(context.session, on: context.db) else {
            context.session.routerName = Controllers.capitalController.routerName
            try await context.session.saveAndCache(in: context.db)
            try await Controllers.capitalController.showCapital(context: context)
            await postStatusBanner(Self.lockedText(lingo: context.lingo, locale: context.session.locale), context: context)
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
        // The hub keyboard can outlive the door: a player left on "arena"
        // without the technique must not reach the lobby through «Виклик».
        // The home screen sends them back to the capital with the reason.
        guard try await ArenaService.isAdmitted(context.session, on: context.db) else {
            try await showArenaHome(context: context)
            return true
        }
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
            switch await ArenaStore.shared.challenge(challenger: challenger, stake: stake, targetTelegramId: opponentTg,
                                                     opponentLocale: opponent.locale) {
            case .created(let pc):
                // Push the invite to the opponent's chat.
                let text = "⚔️ " + lingo.localize("arena.invite.push", locale: opponent.locale, interpolations: [
                    "nick": context.session.nickname ?? "—", "stake": "🪙 \(stake)"
                ])
                let kb = TGInlineKeyboardMarkup(inlineKeyboard: [[
                    TGInlineKeyboardButton(text: lingo.localize("arena.invite.accept", locale: opponent.locale), callbackData: "arena:acc:\(pc.id.uuidString)"),
                    TGInlineKeyboardButton(text: lingo.localize("arena.invite.decline", locale: opponent.locale), callbackData: "arena:dec:\(pc.id.uuidString)")
                ]])
                // Keep the message id: it is the only handle on the bubble that
                // carries the buttons, and every path that closes this challenge
                // has to strip them. Discarding it is why an answered invite
                // stayed tappable forever.
                if let sent = try? await context.bot.sendMessage(params: TGSendMessageParams(chatId: .chat(opponentTg), text: text, parseMode: .html, replyMarkup: .inlineKeyboardMarkup(kb))) {
                    await ArenaStore.shared.attachInvite(pc.id, messageId: sent.messageId)
                }
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

    // MARK: - Closing the invite bubble

    /// Strip the buttons off the invite in the opponent's chat and replace the
    /// question with what actually happened. Edited rather than deleted: this
    /// bot keeps chat history, and a duel someone was invited to is a record,
    /// not a transient prompt.
    ///
    /// Silent when there is no message id — a send that failed leaves nothing
    /// to close — and best-effort otherwise, because a bubble the player has
    /// deleted themselves must not take a decline down with it.
    static func closeInvite(_ pc: ArenaStore.PendingChallenge, key: String, icon: String,
                            bot: TGBot, lingo: Lingo) async {
        guard let messageId = pc.inviteMessageId else { return }
        let locale = pc.opponentLocale.isEmpty ? "uk" : pc.opponentLocale
        let text = icon + " " + lingo.localize(key, locale: locale, interpolations: [
            "nick": pc.challenger.nickname, "stake": "🪙 \(pc.stake)"
        ])
        _ = await editScreen(
            chatId: .chat(pc.opponentTelegramId),
            messageId: messageId,
            isPhoto: false,
            text: text,
            replyMarkup: nil,
            bot: bot
        )
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
            await Self.closeInvite(pc, key: "arena.invite.closed_aborted", icon: "🚫", bot: context.bot, lingo: lingo)
            await postStatusBanner("❌ \(lingo.localize("arena.invite.expired", locale: locale))", context: context)
            return
        }
        // Re-validate at accept-time (silver / HP may have moved).
        switch try await ArenaService.validateMatch(challenger: challengerUser, opponent: context.session, stake: pc.stake, on: context.db) {
        case .failed(let problem):
            _ = await ArenaStore.shared.cancelPending(pendingId)
            await Self.closeInvite(pc, key: "arena.invite.closed_aborted", icon: "🚫", bot: context.bot, lingo: lingo)
            await postStatusBanner("❌ \(Self.matchProblemText(problem, lingo: lingo, locale: locale))", context: context)
            _ = try? await context.bot.sendMessage(params: TGSendMessageParams(chatId: .chat(challengerUser.telegramId), text: "❌ " + lingo.localize("arena.invite.aborted", locale: challengerUser.locale), parseMode: .html))
        case .ok(let challengerHonor, let opponentHonor):
            let a = ArenaService.snapshot(for: challengerUser, stake: pc.stake, honor: challengerHonor)
            let b = ArenaService.snapshot(for: context.session, stake: pc.stake, honor: opponentHonor)
            guard let duel = await ArenaStore.shared.startDuel(pendingId: pendingId, challenger: a, opponent: b) else {
                await postStatusBanner("❌ \(lingo.localize("arena.invite.expired", locale: locale))", context: context)
                return
            }
            // The answer can come from the main hub or the capital — both
            // forward `arena:` callbacks here — while the fight keyboard's
            // buttons are registered on this router alone. Without the switch
            // every tap of the duel would land on the controller the player
            // answered from, and the clock would forfeit them. Best-effort: the
            // in-memory session already carries it, and a failed write must
            // not stop the duel from opening.
            if context.session.routerName != routerName {
                context.session.routerName = routerName
                try? await context.session.saveAndCache(in: context.db)
            }
            // Close the invite BEFORE the scoreboard so the duel screen is the
            // last thing in the chat, not a question the player already answered.
            await Self.closeInvite(pc, key: "arena.invite.closed_accepted", icon: "⚔️", bot: context.bot, lingo: lingo)
            // Both fighters get the opening frame + fight keyboard.
            await Self.pushDuelOpening(duel, bot: context.bot, lingo: lingo)
        }
    }

    func declineChallenge(pendingId: UUID, context: Context) async throws {
        let lingo = context.lingo, locale = context.session.locale
        // A dead invite used to return in silence — the player tapped and
        // nothing whatsoever happened, which reads worse than a refusal. It is
        // reachable whenever the bubble outlives the challenge.
        guard let pc = await ArenaStore.shared.cancelPending(pendingId) else {
            await postStatusBanner("❌ \(lingo.localize("arena.invite.expired", locale: locale))", context: context)
            return
        }
        await Self.closeInvite(pc, key: "arena.invite.closed_declined", icon: "🏳", bot: context.bot, lingo: lingo)
        await postStatusBanner(lingo.localize("arena.invite.you_declined", locale: locale), context: context)
        _ = try? await context.bot.sendMessage(params: TGSendMessageParams(
            chatId: .chat(pc.challenger.telegramId),
            text: "🚫 " + lingo.localize("arena.invite.declined_push", locale: pc.challenger.locale, interpolations: ["nick": context.session.nickname ?? "—"]),
            parseMode: .html
        ))
    }

    // MARK: - Fight actions

    private func onAttackTapped(context: Context) async throws -> Bool { try await handleChoice(.attack, context: context); return true }
    private func onDefendTapped(context: Context) async throws -> Bool { try await handleChoice(.defend, context: context); return true }
    private func onTechniqueTapped(context: Context) async throws -> Bool { try await handleChoice(.technique, context: context); return true }

    /// Lock in this round's choice. The round is played the moment the
    /// second choice arrives, so the tap that completes it draws the round
    /// for both fighters; the first tap only gets its confirmation.
    private func handleChoice(_ action: DuelMath.Action, context: Context) async throws {
        let lingo = context.lingo, locale = context.session.locale
        switch await ArenaStore.shared.choose(action, tg: context.session.telegramId) {
        case .waiting(let round):
            let cls = CharacterClass(rawValue: context.session.characterClass ?? "") ?? .warrior
            await postStatusBanner("✅ " + Self.chosenLine(action, of: cls, round: round, lingo: lingo, locale: locale), context: context)
        case .alreadyChosen(let round):
            await postStatusBanner("⏳ " + lingo.localize("arena.duel.already_chosen", locale: locale,
                                                          interpolations: ["round": "\(round)"]), context: context)
        case .played(let report, let next):
            await Self.pushRound(report, next: next, bot: context.bot, lingo: lingo)
        case .ended(let ended):
            await Self.finish(ended, db: context.db, bot: context.bot, lingo: lingo)
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
        await Self.finish(ended, db: context.db, bot: context.bot, lingo: context.lingo)
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

        // Top of the ladder — the SAME rows the journal's 🎖 board renders, from
        // `LeaderboardService`, not a second query with a second idea of what a
        // rank is. This screen used to walk the page with `var rank = 1`, so two
        // fighters on equal honor showed as 1st and 2nd here and shared 🥇
        // there: one ladder, two screens, two answers. It also did a
        // `User.find` per row; the service loads the owners with the page.
        let view = try await LeaderboardService.view(.honor, for: context.session, on: context.db)
        body += "\n\n<b>\(lingo.localize("arena.leaderboard.title", locale: locale))</b>"
        if view.top.isEmpty {
            body += "\n<i>\(lingo.localize("arena.leaderboard.empty", locale: locale))</i>"
        } else {
            for entry in view.top {
                body += "\n" + lingo.localize("arena.leaderboard.row", locale: locale, interpolations: [
                    "rank": "\(entry.rank)", "nick": entry.name, "honor": "\(entry.value)"
                ])
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

    static func fightKeyboard(_ cls: CharacterClass, locale: String, lingo: Lingo) -> TGReplyMarkup {
        .replyKeyboardMarkup(TGReplyKeyboardMarkup(keyboard: [
            [TGKeyboardButton(text: lingo.localize("arena.button.attack", locale: locale)),
             TGKeyboardButton(text: lingo.localize("arena.button.defend", locale: locale))],
            [TGKeyboardButton(text: techniqueLabel(cls, lingo: lingo, locale: locale)),
             TGKeyboardButton(text: lingo.localize("arena.button.surrender", locale: locale))]
        ], resizeKeyboard: true))
    }

    // MARK: - The technique

    /// «🪓 Розкол» — the forest's own button, so a technique has one name
    /// wherever it is used.
    static func techniqueLabel(_ cls: CharacterClass, lingo: Lingo, locale: String) -> String {
        lingo.localize("combat.button.special_atk." + cls.rawValue, locale: locale)
    }

    /// The label split into its icon and its name, for the round's lines:
    /// the icon leads the line (an emoji may not sit before a `%{}` in a
    /// template) and the name goes into the sentence. Split here rather than
    /// stored twice, so the lines cannot drift from the button.
    private static func technique(_ cls: CharacterClass, lingo: Lingo, locale: String) -> (icon: String, name: String) {
        let label = techniqueLabel(cls, lingo: lingo, locale: locale)
        guard let first = label.first, first.unicodeScalars.contains(where: { $0.properties.isEmojiPresentation }) else {
            return ("⚡", label)
        }
        return (String(first), label.dropFirst().trimmingCharacters(in: .whitespaces))
    }

    /// «🏟 Ристалище пускає лише тих, хто опанував перший прийом…» — the floor
    /// is printed from the technique's own `requiredLevel`.
    static func lockedText(lingo: Lingo, locale: String) -> String {
        "🏟 " + lingo.localize("arena.locked", locale: locale, interpolations: [
            "level": "\(CombatService.requiredLevel(for: ArenaCatalog.admissionTechnique))"
        ])
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

    /// «❤️ Ви 118/150 · Petro 124/150» — the viewer first, as in every line
    /// of the round.
    private static func board(me: ArenaStore.Combatant, opp: ArenaStore.Combatant,
                              lingo: Lingo, locale: String) -> String {
        "❤️ " + lingo.localize("arena.duel.board", locale: locale, interpolations: [
            "me": "\(me.hp)/\(me.maxHp)", "nick": opp.nickname, "them": "\(opp.hp)/\(opp.maxHp)"
        ])
    }

    /// «🗡 Раунд 4: оберіть дію — 15сек.» The time is printed from the value
    /// that owns it, through `Countdown`, like every duration a player sees.
    private static func prompt(round: Int, secondsLeft: Int, lingo: Lingo, locale: String) -> String {
        "🗡 " + lingo.localize("arena.duel.prompt", locale: locale, interpolations: [
            "round": "\(round)", "time": Countdown.format(secondsLeft, lingo: lingo, locale: locale)
        ])
    }

    private static func header(round: Int, lingo: Lingo, locale: String) -> String {
        "<b>\(lingo.localize("arena.duel.header", locale: locale, interpolations: ["round": "\(round)"]))</b>"
    }

    /// «Раунд 4: ви обрали ⚔️ Атаку — чекаємо на суперника.» It names the
    /// round because a tap that arrives just after the clock played one lands
    /// in the next. A technique is named by its button: all three names read
    /// the same in the accusative.
    private static func chosenLine(_ action: DuelMath.Action, of cls: CharacterClass, round: Int,
                                   lingo: Lingo, locale: String) -> String {
        let label: String
        switch action {
        case .attack:    label = "⚔️ " + lingo.localize("arena.duel.chosen.attack", locale: locale)
        case .defend:    label = "🛡 " + lingo.localize("arena.duel.chosen.defend", locale: locale)
        case .technique: label = techniqueLabel(cls, lingo: lingo, locale: locale)
        }
        return lingo.localize("arena.duel.chosen", locale: locale, interpolations: [
            "round": "\(round)", "action": label
        ])
    }

    /// A played round's two lines, the viewer's own first. The number is
    /// always what landed on the OTHER fighter, so a line never needs a
    /// second name, and the nick is always the subject — a nick cannot be
    /// declined, the same rule as an enemy's name.
    static func roundLines(_ report: ArenaStore.RoundReport, seenBy tg: Int64,
                           lingo: Lingo, locale: String) -> [String] {
        let blows = report.blows(seenBy: tg)
        let me = tg == report.a.telegramId ? report.a : report.b
        let opp = report.opp(tg)
        return [
            blowLine(blows.mine, forced: blows.mineForced, mine: true, cls: me.characterClass,
                     who: lingo.localize("arena.duel.you", locale: locale), lingo: lingo, locale: locale),
            blowLine(blows.theirs, forced: blows.theirsForced, mine: false, cls: opp.characterClass,
                     who: opp.nickname, lingo: lingo, locale: locale)
        ]
    }

    /// ⚔️ is the viewer's own hit and 🩸 a hit on them, as in a forest fight;
    /// a crit is 💥 and a miss 💨 whoever threw it, so the name carries the
    /// side. A technique leads with its own icon, 💢 when it came to nothing.
    private static func blowLine(_ blow: DuelMath.Blow, forced: Bool, mine: Bool, cls: CharacterClass,
                                 who: String, lingo: Lingo, locale: String) -> String {
        let tech = technique(cls, lingo: lingo, locale: locale)
        func line(_ key: String) -> String {
            lingo.localize(key, locale: locale, interpolations: [
                "who": who, "dmg": "\(blow.damage)", "technique": tech.name
            ])
        }
        switch blow.kind {
        case .strike:
            switch blow.outcome {
            case .miss?, nil:
                return "💨 " + line("arena.round.miss")
            case .hit?:
                return (mine ? "⚔️ " : "🩸 ") + line(blow.throughBrace ? "arena.round.hit_braced" : "arena.round.hit")
            case .crit?:
                return "💥 " + line(blow.throughBrace ? "arena.round.crit_braced" : "arena.round.crit")
            }
        case .riposte:
            return "🛡 " + line("arena.round.riposte")
        case .chip:
            return "🛡 " + line("arena.round.defend")
        case .braced:
            return "⌛ " + line("arena.round.timeout")
        case .guardBroken:
            return forced ? "⌛ " + line("arena.round.timeout_broken") : "🛡 " + line("arena.round.guard_broken")
        case .technique:
            if case .crit? = blow.outcome { return "💥 " + line("arena.round.technique_crit") }
            return tech.icon + " " + line("arena.round.technique")
        case .interrupted:
            return "💢 " + line("arena.round.interrupted")
        case .clashed:
            return "💢 " + line("arena.round.clashed")
        }
    }

    private static func send(_ text: String, to tg: Int64, keyboard: TGReplyMarkup, bot: TGBot) async {
        _ = try? await bot.sendMessage(params: TGSendMessageParams(
            chatId: .chat(tg), text: text, parseMode: .html, replyMarkup: keyboard
        ))
    }

    /// The duel's first frame, to both fighters: the opponent and the stake,
    /// the board, round 1 open.
    static func pushDuelOpening(_ duel: ArenaStore.Duel, bot: TGBot, lingo: Lingo) async {
        for fighter in [duel.a, duel.b] {
            let locale = fighter.locale
            let opp = duel.opp(fighter.telegramId)
            let body = [
                "⚔️ " + lingo.localize("arena.duel.opening", locale: locale, interpolations: [
                    "nick": opp.nickname, "stake": "🪙 \(fighter.stake)"
                ]) + "\n" + lingo.localize("arena.duel.cycle", locale: locale),
                board(me: fighter, opp: opp, lingo: lingo, locale: locale),
                prompt(round: duel.round, secondsLeft: Int(ArenaCatalog.turnSeconds), lingo: lingo, locale: locale)
            ].joined(separator: "\n\n")
            await send(body, to: fighter.telegramId,
                       keyboard: fightKeyboard(fighter.characterClass, locale: locale, lingo: lingo), bot: bot)
        }
    }

    /// A played round, to both fighters, each from their own side: the two
    /// blows, the board, the next round open.
    static func pushRound(_ report: ArenaStore.RoundReport, next: ArenaStore.Duel, bot: TGBot, lingo: Lingo) async {
        for fighter in [next.a, next.b] {
            let locale = fighter.locale
            let tg = fighter.telegramId
            let body = [
                header(round: report.round, lingo: lingo, locale: locale),
                roundLines(report, seenBy: tg, lingo: lingo, locale: locale).joined(separator: "\n"),
                board(me: next.me(tg), opp: next.opp(tg), lingo: lingo, locale: locale),
                prompt(round: next.round, secondsLeft: Int(ArenaCatalog.turnSeconds), lingo: lingo, locale: locale)
            ].joined(separator: "\n\n")
            await send(body, to: tg, keyboard: fightKeyboard(fighter.characterClass, locale: locale, lingo: lingo), bot: bot)
        }
    }

    /// The round in progress, re-drawn for ONE fighter who lost the screen —
    /// a stray message, a hub button tapped mid-duel. The other chat is left
    /// alone: nothing happened on that side.
    static func pushDuelFrame(_ duel: ArenaStore.Duel, to tg: Int64, now: Date = Date(),
                              bot: TGBot, lingo: Lingo) async {
        let me = duel.me(tg)
        let locale = me.locale
        var parts = [board(me: me, opp: duel.opp(tg), lingo: lingo, locale: locale)]
        if let chosen = duel.choice(of: tg) {
            parts.append("✅ " + chosenLine(chosen, of: me.characterClass, round: duel.round, lingo: lingo, locale: locale))
        } else {
            let left = max(0, Int(duel.roundDeadline.timeIntervalSince(now).rounded(.up)))
            parts.append(prompt(round: duel.round, secondsLeft: left, lingo: lingo, locale: locale))
        }
        await send(parts.joined(separator: "\n\n"), to: tg,
                   keyboard: fightKeyboard(me.characterClass, locale: locale, lingo: lingo), bot: bot)
    }

    /// Settle a finished duel and tell both fighters — the one exit every
    /// ending takes, from a tap or from the sweeper. An abandoned duel is not
    /// settled at all; it only says so.
    static func finish(_ ended: ArenaStore.Ended, db: any Database, bot: TGBot, lingo: Lingo) async {
        if ended.ending == .abandoned {
            await pushAbandoned(ended, bot: bot, lingo: lingo)
            return
        }
        do {
            guard let settlement = try await ArenaService.settle(ended, on: db) else { return }
            await pushDuelResult(settlement, bot: bot, lingo: lingo)
        } catch {
            appState?.logger.warning("Arena: settling \(ended.a.telegramId) vs \(ended.b.telegramId) failed: \(error)")
        }
    }

    /// The result, to both fighters, and the hub keyboard back: the round
    /// that ended the duel, how it ended, what it paid or cost.
    static func pushDuelResult(_ s: ArenaService.Settlement, bot: TGBot, lingo: Lingo) async {
        for me in [s.a, s.b] {
            let locale = me.locale
            let opp = s.other(me.telegramId)
            let winner = s.ending.winnerAndLoser?.winner
            var parts: [String] = []

            if let round = s.finalRound {
                var lines = roundLines(round, seenBy: me.telegramId, lingo: lingo, locale: locale)
                if round.bothFell {
                    let key = winner == nil ? "arena.result.both_fell.even"
                        : (winner == me.telegramId ? "arena.result.both_fell.yours" : "arena.result.both_fell.theirs")
                    lines.append("⚖️ " + lingo.localize(key, locale: locale))
                }
                parts.append(header(round: round.round, lingo: lingo, locale: locale)
                             + "\n\n" + lines.joined(separator: "\n"))
            }

            switch s.ending {
            case .surrender(_, let loser):
                parts.append("🏳 " + (loser == me.telegramId
                    ? lingo.localize("arena.result.surrender.you", locale: locale)
                    : lingo.localize("arena.result.surrender.them", locale: locale,
                                     interpolations: ["nick": opp.nickname])))
            case .forfeit(_, let loser):
                let limit = ArenaCatalog.maxMissedTurns
                parts.append("⌛ " + (loser == me.telegramId
                    ? lingo.localize("arena.result.forfeit.you", count: limit, locale: locale,
                                     interpolations: ["count": "\(limit)"])
                    : lingo.localize("arena.result.forfeit.them", count: limit, locale: locale,
                                     interpolations: ["count": "\(limit)", "nick": opp.nickname])))
            case .knockout, .draw, .abandoned:
                break
            }

            let hpLine = lingo.localize("arena.result.hp", locale: locale, interpolations: [
                "hp": "\(me.hp)", "max": "\(me.maxHp)"
            ])
            if winner == me.telegramId {
                var title = "🏆 <b>\(lingo.localize("arena.result.win_title", locale: locale))</b>"
                if case .knockout = s.ending {
                    title += " " + lingo.localize("arena.result.win_fall", locale: locale,
                                                  interpolations: ["nick": opp.nickname])
                }
                parts.append(title)
                parts.append(lingo.localize("arena.result.win_body", locale: locale, interpolations: [
                    "payout": "🪙 \(s.payout)", "tithe": "🪙 \(s.tithe)",
                    "hb": "\(me.honorBefore)", "ha": "\(me.honorAfter)"
                ]) + "\n" + hpLine)
            } else if winner != nil {
                var title = "💀 <b>\(lingo.localize("arena.result.loss_title", locale: locale))</b>"
                // A knockout the loser could see coming says how close it was,
                // as the forest's death screen does. When both fell, the ⚖️
                // line above already said it.
                if case .knockout = s.ending, s.finalRound?.bothFell == false {
                    title += " " + lingo.localize("arena.result.loss_left", locale: locale,
                                                  interpolations: ["hp": "❤️ \(opp.hp)/\(opp.maxHp)"])
                }
                parts.append(title)
                parts.append(lingo.localize("arena.result.loss_body", locale: locale, interpolations: [
                    "stake": "🪙 \(s.payout + s.tithe)",
                    "hb": "\(me.honorBefore)", "ha": "\(me.honorAfter)"
                ]) + "\n" + hpLine)
            } else {
                // A draw — the one settled ending without a winner.
                parts.append("🤝 <b>\(lingo.localize("arena.result.draw_title", locale: locale))</b> "
                             + lingo.localize("arena.result.draw_body", locale: locale))
                parts.append(hpLine)
            }

            await send(parts.joined(separator: "\n\n"), to: me.telegramId,
                       keyboard: hubKeyboard(locale: locale, lingo: lingo), bot: bot)
        }
    }

    /// Both fighters let the clock run out to the limit in the same round.
    /// Nothing was written, so there is nothing to report but that.
    static func pushAbandoned(_ ended: ArenaStore.Ended, bot: TGBot, lingo: Lingo) async {
        let limit = ArenaCatalog.maxMissedTurns
        for fighter in [ended.a, ended.b] {
            let text = "⌛ " + lingo.localize("arena.result.abandoned", count: limit, locale: fighter.locale,
                                             interpolations: ["count": "\(limit)"])
            await send(text, to: fighter.telegramId,
                       keyboard: hubKeyboard(locale: fighter.locale, lingo: lingo), bot: bot)
        }
    }

    /// A challenge went unanswered — tell the challenger and free both.
    static func pushChallengeExpired(_ pc: ArenaStore.PendingChallenge, bot: TGBot, lingo: Lingo) async {
        // The challenged player is told by their own bubble turning into the
        // outcome — no second message. One event, one trace each side.
        await closeInvite(pc, key: "arena.invite.closed_expired", icon: "⌛", bot: bot, lingo: lingo)
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
