//
//  GlobalCommandsController.swift
//  RestOfIryna
//
//  Created by Maxim Lanskoy on 13.06.2025.
//  Maintained by Dmytro Ihnatyuhin from 17.04.2026.
//

import Fluent
import Foundation      // Date / DateFormatter — the /link deadline
@preconcurrency import Lingo
import SwiftTelegramBot

/// Controller for global commands (/help, /settings, /buttons)
final class GlobalCommandsController: @unchecked Sendable {

    let bot: TGBot
    let db: any Database
    let lingo: Lingo

    init(bot: TGBot, db: any Database, lingo: Lingo) {
        self.bot = bot
        self.db = db
        self.lingo = lingo
    }

    // MARK: - Registration

    /// Register all global command handlers with the dispatcher
    func registerHandlers(dispatcher: TGDefaultDispatcher) async {
        await dispatcher.add(TGCommandHandler(commands: ["/help"]) { update in
            try await self.handleHelp(update: update)
        })

        await dispatcher.add(TGCommandHandler(commands: ["/settings"]) { [weak self] update in
            try await self?.handleSettings(update: update)
        })

        await dispatcher.add(TGCommandHandler(commands: ["/buttons"]) { [weak self] update in
            try await self?.handleButtons(update: update)
        })

        // `/menu` is the player-facing alias for `/buttons`. Surfaced via
        // `setMyCommands` in the Telegram hamburger menu so the player has a
        // discoverable escape hatch if the reply keyboard ever collapses or a
        // second device opens the chat with a stale keyboard from another
        // routerName.
        await dispatcher.add(TGCommandHandler(commands: ["/menu"]) { [weak self] update in
            try await self?.handleButtons(update: update)
        })

        await dispatcher.add(TGCommandHandler(commands: ["/grant"]) { [weak self] update in
            try await self?.handleGrant(update: update)
        })

        await dispatcher.add(TGCommandHandler(commands: ["/drain"]) { [weak self] update in
            try await self?.handleDrain(update: update)
        })

        await dispatcher.add(TGCommandHandler(commands: ["/revoke"]) { [weak self] update in
            try await self?.handleRevoke(update: update)
        })

        await dispatcher.add(TGCommandHandler(commands: ["/content"]) { [weak self] update in
            try await self?.handleContent(update: update)
        })

        await dispatcher.add(TGCommandHandler(commands: ["/reload"]) { [weak self] update in
            try await self?.handleReload(update: update)
        })

        await dispatcher.add(TGCommandHandler(commands: ["/link"]) { [weak self] update in
            try await self?.handleLink(update: update)
        })
    }

    // MARK: - Command Handlers

    private func handleHelp(update: TGUpdate) async throws {
        guard let fromId = update.message?.from ?? update.editedMessage?.from else { return }

        // AUTH: Comment out this block to disable authorization
        guard await accessControl.isAllowed(fromId.id, on: db) else { return }

        let session = try await User.cachedSession(for: fromId, db: db)

        let helpText = generateHelpText(lingo: lingo, session: session)
        try await bot.sendMessage(session: session, text: helpText, parseMode: .html)
    }

    private func handleSettings(update: TGUpdate) async throws {
        guard let fromId = update.message?.from ?? update.editedMessage?.from else { return }

        // AUTH: Comment out this block to disable authorization
        guard await accessControl.isAllowed(fromId.id, on: db) else { return }

        let session = try await User.cachedSession(for: fromId, db: db)

        let settingsController = Controllers.settingsController
        try await settingsController.showSettingsMenuLogic(bot: bot, session: session, lingo: lingo)

        // Use partial update for better performance
        try await session.saveAndCache(in: db)
    }

    private func handleButtons(update: TGUpdate) async throws {
        guard let fromId = update.message?.from ?? update.editedMessage?.from else { return }

        // AUTH: Comment out this block to disable authorization
        guard await accessControl.isAllowed(fromId.id, on: db) else { return }

        let session = try await User.cachedSession(for: fromId, db: db)

        if let controller = Controllers.all.first(where: { $0.routerName == session.routerName }),
           let markup = controller.generateControllerKB(session: session, lingo: lingo) {
            let keyboardRestored = lingo.localize("keyboard.restored", locale: session.locale)
            try await bot.sendMessage(session: session, text: "⌨️ \(keyboardRestored).", replyMarkup: markup)
        }
    }

    /// Escape text destined for a `parseMode: .html` message.
    ///
    /// Needed because `/reload` echoes VALIDATOR OUTPUT, which is arbitrary
    /// developer-facing prose rather than curated locale copy — and two rules
    /// legitimately say things like "expected min <= base <= max". Unescaped,
    /// Telegram rejects the whole message, so the one code path whose entire
    /// job is to explain a refusal would silently deliver nothing at all.
    private static func htmlEscaped(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    /// Dev-only `/content` — what bundle is actually loaded right now.
    ///
    /// Reports the CONTENT HASH rather than a version string: a version is what
    /// someone remembered to type, the hash is what the process is really
    /// serving. It is the fastest way to answer "is this bot running the bundle
    /// I just edited".
    private func handleContent(update: TGUpdate) async throws {
        guard let fromId = update.message?.from ?? update.editedMessage?.from else { return }
        guard developerUsers.contains(fromId.id) else { return }

        let session = try await User.cachedSession(for: fromId, db: db)
        let lines = [
            "\u{1F4E6} <b>\(Self.htmlEscaped(GameData.current.summaryLine))</b>",
            "",
            "<code>\(Self.htmlEscaped(ContentBootstrap.contentDirectory))</code>"
        ]
        try await bot.sendMessage(session: session, text: lines.joined(separator: "\n"), parseMode: .html)
    }

    /// Dev-only `/reload` — hot-swap the content bundle from disk.
    ///
    /// The whole safety story is the ORDER: parse → validate → live-check →
    /// build → install. Everything that can fail happens before anything is
    /// touched, and `install` is a reference store that cannot fail. A refused
    /// reload leaves the running game on exactly the snapshot it was serving,
    /// which is what makes this safe to run with players mid-expedition.
    ///
    /// Not reloaded: **Lingo**. `AppState.lingo` is a `let` captured by every
    /// controller, so new locale strings still need a restart — worth saying out
    /// loud, because "I reloaded and my new string is still missing" is the
    /// obvious first confusion.
    private func handleReload(update: TGUpdate) async throws {
        guard let fromId = update.message?.from ?? update.editedMessage?.from else { return }
        guard developerUsers.contains(fromId.id) else { return }

        let session = try await User.cachedSession(for: fromId, db: db)
        do {
            let outcome = try await ContentBootstrap.reload(on: db, logger: appState?.logger ?? Logger(label: "reload"))
            var lines = ["\u{2705} <b>Content reloaded</b>", "",
                         "<code>\(Self.htmlEscaped(outcome.summaryLine))</code>"]
            if !outcome.warnings.isEmpty {
                lines.append("")
                lines.append("\u{26A0}\u{FE0F} \(outcome.warnings.count) warning(s):")
                for warning in outcome.warnings.prefix(5) {
                    lines.append("\u{2022} <code>\(Self.htmlEscaped(warning))</code>")
                }
            }
            lines.append("")
            lines.append("<i>Locale strings are not reloaded — those still need a restart.</i>")
            try await bot.sendMessage(session: session, text: lines.joined(separator: "\n"), parseMode: .html)
        } catch {
            let detail = Self.htmlEscaped(String("\(error)".prefix(1200)))
            let text = "\u{274C} <b>Reload refused — the running bundle is untouched.</b>\n\n<code>\(detail)</code>"
            try await bot.sendMessage(session: session, text: text, parseMode: .html)
        }
    }

    /// Dev-only `/link` — mint a fresh invite deep link.
    ///
    /// The link is the whole access-control surface of the closed test: it
    /// carries an encrypted timestamp (`InviteToken`), it is good for five
    /// minutes, and anyone who opens the bot through it inside that window is
    /// added to `allowed_users` and dropped into registration. It names nobody,
    /// so one link admits everyone the admin forwards it to before it goes
    /// stale — send it to a group, or mint a new one per person; both work.
    ///
    /// Deliberately NOT localized to the caller's Telegram language: this is a
    /// developer command with exactly one caller, and it uses his stored locale
    /// like every other screen he sees.
    private func handleLink(update: TGUpdate) async throws {
        guard let fromId = update.message?.from ?? update.editedMessage?.from else { return }
        guard developerUsers.contains(fromId.id) else { return }

        let session = try await User.cachedSession(for: fromId, db: db)

        guard let username = appState.botUsername, !username.isEmpty else {
            let text = "\u{274C} " + lingo.localize("access.link.unavailable", locale: session.locale)
            try await bot.sendMessage(session: session, text: text, parseMode: .html)
            return
        }

        let issuedAt = Date()
        let token = InviteToken.make(secret: appState.inviteSecret, at: issuedAt)
        let url = "https://t.me/\(username)?start=\(token)"
        let minutes = Int((InviteToken.validity / 60).rounded())

        // The deadline as a wall clock, in the same zone every other daily
        // system uses. "Valid for 5 minutes" is not actionable once the message
        // has been sitting in the chat while you find the player to send it to;
        // "until 22:41" is.
        let clock = DateFormatter()
        clock.dateFormat = "HH:mm"
        clock.timeZone = TimeZone(identifier: GameDay.timeZoneID) ?? TimeZone(identifier: "UTC")!
        let until = clock.string(from: issuedAt.addingTimeInterval(InviteToken.validity))

        // Both forms are wrapped in <code>, which Telegram renders as
        // tap-to-copy — the point of the message is to be FORWARDED, and a
        // rendered hyperlink is the one thing you cannot cleanly copy out of a
        // chat. The bare token is not a duplicate of the link: a deep link
        // delivers its payload only when the client actually sends
        // `/start <token>`, and a player who already has the chat open, or who
        // just types to the bot, arrives with nothing (seen live as
        // `no start payload`). Pasting the code works from any state.
        let text = "\u{1F517} " + lingo.localize(
            "access.link.ready",
            locale: session.locale,
            interpolations: ["url": url, "code": token, "minutes": minutes, "until": until]
        )
        try await bot.sendMessage(session: session, text: text, parseMode: .html)
    }

    /// Dev-only `/grant <item_id> <quantity>` — gives items to the caller.
    /// Restricted to the mitya account (test profile).
    private func handleGrant(update: TGUpdate) async throws {
        guard let fromId = update.message?.from ?? update.editedMessage?.from else { return }
        guard fromId.id == mitya else { return }
        guard await accessControl.isAllowed(fromId.id, on: db) else { return }

        let session = try await User.cachedSession(for: fromId, db: db)
        let locale = session.locale
        let text = update.message?.text ?? ""
        let parts = text.components(separatedBy: " ").filter { !$0.isEmpty }

        guard parts.count >= 3, let quantity = Int(parts[2]), quantity > 0 else {
            let usage = lingo.localize("grant.usage", locale: locale)
            try await bot.sendMessage(session: session, text: usage, parseMode: .html)
            return
        }

        let itemId = parts[1]
        guard let item = ItemCatalog.find(itemId) else {
            let msg = lingo.localize("grant.unknown_item", locale: locale, interpolations: ["id": itemId])
            try await bot.sendMessage(session: session, text: msg, parseMode: .html)
            return
        }

        let itemName = lingo.localize(item.nameKey, locale: locale)
        do {
            try await InventoryEntry.add(itemId, quantity: quantity, to: session, on: db)
            let msg = lingo.localize("grant.success", locale: locale, interpolations: ["item": itemName, "qty": "\(quantity)"])
            try await bot.sendMessage(session: session, text: msg, parseMode: .html)
        } catch InventoryError.inventoryFull {
            let msg = lingo.localize("inventory.full", locale: locale)
            try await bot.sendMessage(session: session, text: msg, parseMode: .html)
        }
    }

    /// Dev-only `/drain <amount>` — drops the caller's vigor by N, clamped to 0.
    /// Restricted to the mitya account (test profile). Does not trigger starvation
    /// HP loss (that is a per-room transition effect, not a raw drain).
    private func handleDrain(update: TGUpdate) async throws {
        guard let fromId = update.message?.from ?? update.editedMessage?.from else { return }
        guard fromId.id == mitya else { return }
        guard await accessControl.isAllowed(fromId.id, on: db) else { return }

        let session = try await User.cachedSession(for: fromId, db: db)
        let locale = session.locale
        let text = update.message?.text ?? ""
        let parts = text.components(separatedBy: " ").filter { !$0.isEmpty }

        guard parts.count >= 2, let amount = Int(parts[1]), amount > 0 else {
            let usage = lingo.localize("drain.usage", locale: locale)
            try await bot.sendMessage(session: session, text: usage, parseMode: .html)
            return
        }

        let drained = VigorService.drain(session, amount: amount)
        try await session.saveAndCache(in: db)

        let msg = lingo.localize("drain.success", locale: locale, interpolations: [
            "amount": "\(drained)",
            "current": "\(session.vigor)",
            "max": "\(session.maxVigor)"
        ])
        try await bot.sendMessage(session: session, text: msg, parseMode: .html)
    }

    /// Dev-only `/revoke <item_id> <quantity>` — removes items from the caller's
    /// inventory. Restricted to the mitya account (test profile). Responds with
    /// "not enough" if the player doesn't have the requested quantity; nothing is
    /// partially removed in that case.
    private func handleRevoke(update: TGUpdate) async throws {
        guard let fromId = update.message?.from ?? update.editedMessage?.from else { return }
        guard fromId.id == mitya else { return }
        guard await accessControl.isAllowed(fromId.id, on: db) else { return }

        let session = try await User.cachedSession(for: fromId, db: db)
        let locale = session.locale
        let text = update.message?.text ?? ""
        let parts = text.components(separatedBy: " ").filter { !$0.isEmpty }

        guard parts.count >= 3, let quantity = Int(parts[2]), quantity > 0 else {
            let usage = lingo.localize("revoke.usage", locale: locale)
            try await bot.sendMessage(session: session, text: usage, parseMode: .html)
            return
        }

        let itemId = parts[1]
        guard let item = ItemCatalog.find(itemId) else {
            let msg = lingo.localize("revoke.unknown_item", locale: locale, interpolations: ["id": itemId])
            try await bot.sendMessage(session: session, text: msg, parseMode: .html)
            return
        }

        let removed = try await InventoryEntry.remove(itemId, quantity: quantity, from: session, on: db)
        let itemName = lingo.localize(item.nameKey, locale: locale)
        guard removed else {
            let msg = lingo.localize("revoke.not_enough", locale: locale, interpolations: ["item": itemName])
            try await bot.sendMessage(session: session, text: msg, parseMode: .html)
            return
        }

        let msg = lingo.localize("revoke.success", locale: locale, interpolations: ["item": itemName, "qty": "\(quantity)"])
        try await bot.sendMessage(session: session, text: msg, parseMode: .html)
    }

    // MARK: - Helper Methods

    private func generateHelpText(lingo: Lingo, session: User) -> String {

        let welcome = lingo.localize("welcome", locale: session.locale)
        let hereAreTheCommands = lingo.localize("here.are.commands", locale: session.locale)
        let helpMainMenu = lingo.localize("help.main.menu", locale: session.locale)
        let helpShowButtons = lingo.localize("help.show.buttons", locale: session.locale)
        let settingsButtons = lingo.localize("settings.title", locale: session.locale)

        let howToUse = lingo.localize("how.to.use", locale: session.locale)
        let howToShowButtons = lingo.localize("how.to.show.buttons", locale: session.locale)
        let howToSettings = lingo.localize("how.to.settings", locale: session.locale)

        let enjoyChatting = lingo.localize("enjoy.chatting", locale: session.locale)

        return """
        <b>RestOfIryna Help</b>

        \(welcome)!

        \(hereAreTheCommands):

        <b>/start</b> – 📟 \(helpMainMenu)
        <b>/buttons</b> – ⌨️ \(settingsButtons)
        <b>/settings</b> – ⚙️ \(helpShowButtons)

        <b>\(howToUse):</b>
        • \(howToShowButtons).
        • \(howToSettings).

        \(enjoyChatting).
        """
    }
}
