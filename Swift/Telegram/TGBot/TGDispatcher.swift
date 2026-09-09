//
//  TGDispatcher.swift
//  RestOfIryna
//
//  Created by Maxim Lanskoy on 13.06.2025.
//  Maintained by Dmytro Ihnatyuhin from 17.04.2026.
//

import Foundation
import Logging
import Fluent
@preconcurrency import Lingo
import SwiftTelegramBot

// MARK: - Main Unified Dispatcher

final class TGDispatcher: TGDefaultDispatcher, @unchecked Sendable {

    private let db: any Database
    let lingo: Lingo

    init(bot: TGBot, appState: AppState) {
        self.db = appState.db
        self.lingo = appState.lingo
        super.init(bot: bot, logger: appState.logger)
    }

    override func handle() async {
        // Register global commands controller
        let globalCommands = GlobalCommandsController(
            bot: bot,
            db: db,
            lingo: lingo
        )
        await globalCommands.registerHandlers(dispatcher: self)

        // Register catch-all router handler
        await addRouterHandler()
    }

    // MARK: - Router Handler (Lowest Priority - Catch-all)

    private func addRouterHandler() async {
        await add(TGBaseHandler({ [weak self] update in
            guard let self = self else { return }

            let unsafeMessage = update.editedMessage?.from ?? update.message?.from
            guard let entity = unsafeMessage ?? update.callbackQuery?.from else { return }

            // Check authorization. Someone who is not on the list gets exactly
            // one way in: a `/start` carrying a live invite token. Everything
            // else — a bare `/start`, a stale link, any other message — stops
            // here, before a `User` row is created, so a stranger tapping the
            // bot leaves nothing behind in the database.
            if !(await accessControl.isAllowed(entity.id, on: self.db)) {
                guard await self.redeemInvite(update: update, entity: entity) else { return }
            }

            // Get user session with caching
            let session = try await User.cachedSession(for: entity, db: self.db)

            // Route to appropriate controller
            let props: [String: Int64] = ["session": session.telegramId]
            let key = session.routerName

            try await store.process(
                key: key,
                update: update,
                properties: props,
                db: self.db,
                lingo: self.lingo
            )
        }))
    }

    // MARK: - Invite Redemption

    /// Try to admit an unlisted account on the strength of a `/start` payload.
    ///
    /// - Returns: `true` when the account is now allowed and the update should
    ///   continue into normal routing (which lands them in registration),
    ///   `false` when it was refused and already told why.
    private func redeemInvite(update: TGUpdate, entity: TGUser) async -> Bool {
        let locale = Self.locale(for: entity)

        guard let payload = Self.invitePayload(in: update) else {
            await refuse(entity, locale: locale, key: "access.invite.required",
                         icon: "\u{26D4}", reason: "no start payload")
            return false
        }

        switch InviteToken.verify(payload, secret: appState.inviteSecret) {
        case .valid(let issuedAt):
            do {
                let added = try await accessControl.grant(entity.id,
                                                          username: entity.username,
                                                          source: .invite,
                                                          on: self.db)
                let age = Int(Date().timeIntervalSince(issuedAt).rounded())
                log.info("""
                    [ACCESS] granted \(entity.id) (@\(entity.username ?? "no username")) \
                    via invite \(age)s old\(added ? "" : " — already on the list")
                    """)
                await send("\u{2705} " + lingo.localize("access.invite.granted", locale: locale),
                           to: entity.id)
                await notifyOwner("""
                    [ACCESS] \(entity.id) (@\(entity.username ?? "no username")) \
                    redeemed an invite and may now register.
                    """)
                return true
            } catch {
                log.error("[ACCESS] failed to grant \(entity.id): \(error)")
                await send("\u{274C} " + lingo.localize("access.invite.failed", locale: locale),
                           to: entity.id)
                return false
            }

        case .expired(let age):
            await refuse(entity, locale: locale, key: "access.invite.expired",
                         icon: "\u{23F3}", reason: "invite \(Int(age.rounded()))s old")
            return false

        case .invalid:
            await refuse(entity, locale: locale, key: "access.invite.required",
                         icon: "\u{26D4}", reason: "invite did not verify")
            return false
        }
    }

    /// Turn someone away: tell them, log it, and tell the owner.
    ///
    /// `icon` is prepended in Swift rather than written into the template,
    /// because both refusal strings interpolate `%{id}` and Lingo drops every
    /// placeholder that follows a multi-UTF-16 character in the template (see
    /// `.memory/localization.md`).
    private func refuse(_ entity: TGUser, locale: String, key: String, icon: String, reason: String) async {
        let concern = """
            [D20] Unauthorized user tried to access: \(entity.id), \
            @\(entity.username ?? "\"No Username\"") — \(reason).
            """
        log.warning("\(concern)")
        let body = lingo.localize(key, locale: locale, interpolations: [
            "id": entity.id,
            "validity": Countdown.format(Int(InviteToken.validity.rounded()), lingo: lingo, locale: locale),
        ])
        await send("\(icon) \(body)", to: entity.id)
        await notifyOwner(concern)
    }

    private func send(_ text: String, to telegramId: Int64) async {
        let params = TGSendMessageParams(chatId: .chat(telegramId), text: text, parseMode: .html)
        _ = try? await bot.sendMessage(params: params)
    }

    private func notifyOwner(_ text: String) async {
        let params = TGSendMessageParams(chatId: .chat(mitya), text: text, disableNotification: true)
        _ = try? await bot.sendMessage(params: params)
    }

    // MARK: - Update parsing

    /// An invite token offered by this update — either as the payload of a
    /// `/start` deep link, or pasted into the chat on its own.
    ///
    /// **The pasted form is not a convenience.** A deep link only delivers its
    /// payload when the client actually sends `/start <token>`, and it does not
    /// always: a player who already has the chat open, or who simply types to
    /// the bot instead of tapping the link, arrives with no payload at all —
    /// observed live on 2026-09-08 as `no start payload`, with the invite
    /// unredeemable and the player stuck. The token is 16 letters precisely so
    /// it can survive being copied, forwarded and pasted by hand, so the gate
    /// accepts it that way too.
    ///
    /// Read straight off the raw text rather than through `Router`, because the
    /// router only runs for accounts that are already allowed — this is the
    /// check standing in front of it. Case is preserved deliberately: the
    /// command is matched case-insensitively, the token never is.
    static func invitePayload(in update: TGUpdate) -> String? {
        let raw = update.message?.text ?? update.editedMessage?.text
        guard let text = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else {
            return nil
        }
        let parts = text.split(separator: " ", omittingEmptySubsequences: true)
        guard let command = parts.first?.lowercased() else { return nil }

        if command == "/start" || command.hasPrefix("/start@") {
            return parts.count >= 2 ? String(parts[1]) : nil
        }

        // A bare paste: one word, exactly a token's length. `verify` rejects
        // anything outside the alphabet or failing the tag, so this cannot
        // admit an accident — it only decides what is worth checking.
        guard parts.count == 1, text.count == InviteToken.tokenLength else { return nil }
        return text
    }

    /// Best guess at what language to refuse someone in. They have no `User`
    /// row yet — creating one for an account we are about to turn away is
    /// exactly what the gate is there to prevent — so the only signal is the
    /// client language Telegram reports.
    static func locale(for entity: TGUser) -> String {
        let code = entity.languageCode?.lowercased() ?? ""
        if code.hasPrefix("uk") || code.hasPrefix("ru") { return SupportedLocale.ua.rawValue }
        return SupportedLocale.en.rawValue
    }
}
