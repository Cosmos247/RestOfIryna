//
//  GlobalCommandsController.swift
//  RestOfIryna
//
//  Created by Maxim Lanskoy on 13.06.2025.
//  Maintained by Dmytro Ihnatyuhin from 17.04.2026.
//

import Fluent
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

        await dispatcher.add(TGCommandHandler(commands: ["/grant"]) { [weak self] update in
            try await self?.handleGrant(update: update)
        })

        await dispatcher.add(TGCommandHandler(commands: ["/drain"]) { [weak self] update in
            try await self?.handleDrain(update: update)
        })

        await dispatcher.add(TGCommandHandler(commands: ["/revoke"]) { [weak self] update in
            try await self?.handleRevoke(update: update)
        })
    }

    // MARK: - Command Handlers

    private func handleHelp(update: TGUpdate) async throws {
        guard let fromId = update.message?.from ?? update.editedMessage?.from else { return }

        // AUTH: Comment out this block to disable authorization
        guard allowedUsers.contains(fromId.id) else { return }

        let session = try await User.cachedSession(for: fromId, db: db)

        let helpText = generateHelpText(lingo: lingo, session: session)
        try await bot.sendMessage(session: session, text: helpText, parseMode: .html)
    }

    private func handleSettings(update: TGUpdate) async throws {
        guard let fromId = update.message?.from ?? update.editedMessage?.from else { return }

        // AUTH: Comment out this block to disable authorization
        guard allowedUsers.contains(fromId.id) else { return }

        let session = try await User.cachedSession(for: fromId, db: db)

        let settingsController = Controllers.settingsController
        try await settingsController.showSettingsMenuLogic(bot: bot, session: session, lingo: lingo)

        // Use partial update for better performance
        try await session.saveAndCache(in: db)
    }

    private func handleButtons(update: TGUpdate) async throws {
        guard let fromId = update.message?.from ?? update.editedMessage?.from else { return }

        // AUTH: Comment out this block to disable authorization
        guard allowedUsers.contains(fromId.id) else { return }

        let session = try await User.cachedSession(for: fromId, db: db)

        if let controller = Controllers.all.first(where: { $0.routerName == session.routerName }),
           let markup = controller.generateControllerKB(session: session, lingo: lingo) {
            let keyboardRestored = lingo.localize("keyboard.restored", locale: session.locale)
            try await bot.sendMessage(session: session, text: "⌨️ \(keyboardRestored).", replyMarkup: markup)
        }
    }

    /// Dev-only `/grant <item_id> <quantity>` — gives items to the caller.
    /// Restricted to the mitya account (test profile).
    private func handleGrant(update: TGUpdate) async throws {
        guard let fromId = update.message?.from ?? update.editedMessage?.from else { return }
        guard fromId.id == mitya else { return }
        guard allowedUsers.contains(fromId.id) else { return }

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
        guard allowedUsers.contains(fromId.id) else { return }

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
        guard allowedUsers.contains(fromId.id) else { return }

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
