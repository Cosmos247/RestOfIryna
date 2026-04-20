//
//  MainController.swift
//  RestOfIryna
//
//  Created by Maxim Lanskoy on 13.06.2025.
//  Maintained by Dmytro Ihnatyuhin from 17.04.2026.
//

import Foundation
@preconcurrency import Lingo
import SwiftTelegramBot

// MARK: - Main Controller Logic
final class MainController: TGControllerBase, @unchecked Sendable {
    typealias T = MainController

    // MARK: - Controller Lifecycle
    override public func attachHandlers(to bot: TGBot, lingo: Lingo) async {
        let router = Router(bot: bot) { router in
            router[Commands.start.command()]     = onStart
            router[Commands.settings.command()]  = onSettings
            router[Commands.profile.command()]   = onProfile
            router[Commands.explore.command()]   = onExplore
            router[Commands.estate.command()]    = onEstate
            router[Commands.capital.command()]   = onCapital
            router[Commands.inventory.command()] = onInventory

            let cancelLocales = Commands.cancel.buttonsForAllLocales(lingo: lingo)
            for button in cancelLocales { router[button.text] = onCancel }

            let settingsLocales = Commands.settings.buttonsForAllLocales(lingo: lingo)
            for button in settingsLocales { router[button.text] = onSettings }

            let profileLocales = Commands.profile.buttonsForAllLocales(lingo: lingo)
            for button in profileLocales { router[button.text] = onProfile }

            let exploreLocales = Commands.explore.buttonsForAllLocales(lingo: lingo)
            for button in exploreLocales { router[button.text] = onExplore }

            let estateLocales = Commands.estate.buttonsForAllLocales(lingo: lingo)
            for button in estateLocales { router[button.text] = onEstate }

            let capitalLocales = Commands.capital.buttonsForAllLocales(lingo: lingo)
            for button in capitalLocales { router[button.text] = onCapital }

            let inventoryLocales = Commands.inventory.buttonsForAllLocales(lingo: lingo)
            for button in inventoryLocales { router[button.text] = onInventory }

            router.unmatched                     = unmatched
            router[.callback_query(data: nil)]   = MainController.onCallbackQuery
        }
        await processRouterForEachName(router)
    }

    public func onStart(context: Context) async throws -> Bool {
        try await showMainMenu(context: context)
        return true
    }

    private func onCancel(context: Context) async throws -> Bool {
        return try await onStart(context: context)
    }

    override func unmatched(context: Context) async throws -> Bool {
        guard try await super.unmatched(context: context) else { return false }
        return try await onStart(context: context)
    }

    private func onSettings(context: Context) async throws -> Bool {
        let settingsController = Controllers.settingsController
        try await settingsController.showSettingsMenu(context: context)
        context.session.routerName = settingsController.routerName
        try await context.session.saveAndCache(in: context.db)
        return true
    }

    private func onProfile(context: Context) async throws -> Bool {
        try await showProfile(context: context)
        return true
    }

    private func onExplore(context: Context) async throws -> Bool {
        let controller = Controllers.explorationController
        try await controller.showStub(context: context)
        context.session.routerName = controller.routerName
        try await context.session.saveAndCache(in: context.db)
        return true
    }

    private func onEstate(context: Context) async throws -> Bool {
        let controller = Controllers.estateController
        try await controller.showStub(context: context)
        context.session.routerName = controller.routerName
        try await context.session.saveAndCache(in: context.db)
        return true
    }

    private func onCapital(context: Context) async throws -> Bool {
        let controller = Controllers.capitalController
        try await controller.showStub(context: context)
        context.session.routerName = controller.routerName
        try await context.session.saveAndCache(in: context.db)
        return true
    }

    private func onInventory(context: Context) async throws -> Bool {
        let controller = Controllers.inventoryController
        try await controller.showInventory(context: context)
        context.session.routerName = controller.routerName
        try await context.session.saveAndCache(in: context.db)
        return true
    }

    public func showMainMenu(context: Context, text: String? = nil) async throws {
        let displayName = context.session.firstName ?? context.session.name
        let greeting = context.lingo.localize("greeting.message", locale: context.session.locale, interpolations: [
            "full-name": displayName
        ])
        let text = text ?? "👋 \(greeting)!"
        let markup = generateControllerKB(session: context.session, lingo: context.lingo)
        try await context.bot.sendMessage(session: context.session, text: text, parseMode: .html, replyMarkup: markup)
    }

    override public func generateControllerKB(session: User, lingo: Lingo) -> TGReplyMarkup? {
        let markup = TGReplyKeyboardMarkup(keyboard: [
            [ Commands.explore.button(for: session, lingo),
              Commands.inventory.button(for: session, lingo) ],
            [ Commands.estate.button(for: session, lingo),
              Commands.capital.button(for: session, lingo) ],
            [ Commands.profile.button(for: session, lingo),
              Commands.settings.button(for: session, lingo) ]
        ], resizeKeyboard: true)
        return TGReplyMarkup.replyKeyboardMarkup(markup)
    }

    // MARK: - Profile Display

    func showProfile(context: Context, editMessageId: Int? = nil) async throws {
        let style = context.session.profileStyle
        let text = renderProfile(session: context.session, lingo: context.lingo, style: style)
        let keyboard = profileStyleKeyboard(currentStyle: style)

        if let msgId = editMessageId {
            let params = TGEditMessageTextParams(
                chatId: .chat(context.session.telegramId),
                messageId: msgId,
                text: text,
                parseMode: .html,
                replyMarkup: keyboard
            )
            try await context.bot.editMessageText(params: params)
        } else {
            let markup = TGReplyMarkup.inlineKeyboardMarkup(keyboard)
            try await context.bot.sendMessage(session: context.session, text: text, parseMode: .html, replyMarkup: markup)
        }
    }

    private func profileStyleKeyboard(currentStyle: Int) -> TGInlineKeyboardMarkup {
        let buttons = (1...3).map { style in
            let label = style == currentStyle ? "· \(style) ·" : "\(style)"
            return TGInlineKeyboardButton(text: label, callbackData: "pstyle:\(style)")
        }
        return TGInlineKeyboardMarkup(inlineKeyboard: [buttons])
    }

    // MARK: - Profile Rendering

    private func renderProfile(session: User, lingo: Lingo, style: Int) -> String {
        let nickname = session.nickname ?? session.name
        let cls = CharacterClass(rawValue: session.characterClass ?? "") ?? .warrior
        let className = lingo.localize("registration.class.\(cls.rawValue)", locale: session.locale)
        let estate = session.estateName ?? "?"
        let level = session.level
        let xp = session.xp, xpMax = xpForNextLevel(level)
        let hp = session.hp, maxHp = session.maxHp
        let hunger = session.hunger, maxHunger = session.maxHunger
        let atk = session.effectiveAttack, def = session.effectiveDefense
        let crit = session.crit, dodge = session.dodge, acc = session.accuracy
        let gold = session.gold
        let starvingSuffix = HungerService.isStarving(session) ? " · " + lingo.localize("hunger.starving", locale: session.locale) : ""

        switch style {
        case 2:
            return """
            \(cls.icon()) \(className)  «<b>\(nickname)</b>»  Lv.\(level)
            ━━━━━━━━━━━━━━━━

            ❤️ \(bar(hp, maxHp)) \(hp)/\(maxHp)
            🍖 \(bar(hunger, maxHunger)) \(hunger)/\(maxHunger)\(starvingSuffix)

            ⚔️ \(atk)  🛡 \(def)  💥 \(crit)%
            🎯 \(acc)  💨 \(dodge)

            💰 \(gold)  
            🏰 \(estate)
            """
        case 3:
            let l = lingo
            let loc = session.locale
            return """
            \(cls.icon()) <b>\(nickname)</b> — \(className)
            ✨ \(l.localize("profile.level", locale: loc)) \(level) (\(xp)/\(xpMax) \(l.localize("profile.xp", locale: loc)))

            ❤️ \(l.localize("profile.health", locale: loc)): \(hp)/\(maxHp)
            \(emojiBar(hp, maxHp, fill: "🟥"))
            
            🍖 \(l.localize("profile.hunger", locale: loc)): \(hunger)/\(maxHunger)\(starvingSuffix)
            \(emojiBar(hunger, maxHunger, fill: "🟧"))

            ⚔️ \(l.localize("profile.attack", locale: loc)): \(atk)    🛡 \(l.localize("profile.defense", locale: loc)): \(def)
            🎯 \(l.localize("profile.accuracy", locale: loc)): \(acc)    💨 \(l.localize("profile.dodge", locale: loc)): \(dodge)
            💥 \(l.localize("profile.crit", locale: loc)): \(crit)%

            💰 \(gold) \(l.localize("profile.gold", locale: loc))
            🏰 \(l.localize("profile.estate", locale: loc)) «\(estate)»
            """
        default: // Style 1
            return """
            \(cls.icon()) <b>\(nickname)</b> · Lv.\(level)
            \(className)

            ❤️ \(hp)/\(maxHp)  🍖 \(hunger)/\(maxHunger)\(starvingSuffix)

            ⚔️\(atk)  🛡\(def)  🎯\(acc)
            💨\(dodge)  💥\(crit)%

            💰 \(gold) 
            🏰 \(estate)
            """
        }
    }

    // MARK: - Bar Helpers

    private func bar(_ current: Int, _ max: Int, length: Int = 10) -> String {
        let filled = max > 0 ? Int(Double(current) / Double(max) * Double(length)) : 0
        return String(repeating: "█", count: filled) + String(repeating: "░", count: length - filled)
    }

    private func emojiBar(_ current: Int, _ max: Int, length: Int = 10, fill: String = "🟩", empty: String = "⬛") -> String {
        let filled = max > 0 ? Int(Double(current) / Double(max) * Double(length)) : 0
        return String(repeating: fill, count: filled) + String(repeating: empty, count: length - filled)
    }

    /// XP required to reach next level (simple curve: level * 100)
    private func xpForNextLevel(_ level: Int) -> Int {
        return level * 100
    }
}

// MARK: - Callback Queries Processing
extension MainController {
    static func onCallbackQuery(context: Context) async throws -> Bool {
        guard let query = context.update.callbackQuery else { return false }
        guard let message = query.message else { return false }
        guard let data = query.data else { return false }

        // Profile style switch — edit message in place
        if data.starts(with: "pstyle:") {
            let styleStr = data.replacingOccurrences(of: "pstyle:", with: "")
            guard let style = Int(styleStr), (1...3).contains(style) else { return false }

            context.session.profileStyle = style
            try await context.session.saveAndCache(in: context.db)

            try await Controllers.mainController.showProfile(
                context: context,
                editMessageId: message.messageId
            )

            let answerParams = TGAnswerCallbackQueryParams(callbackQueryId: query.id)
            try await context.bot.answerCallbackQuery(params: answerParams)
            return true
        }

        // Default: delete inline message
        let chatId = TGChatId.chat(message.chat.id)
        let deleteParams = TGDeleteMessageParams(chatId: chatId, messageId: message.messageId)
        try await context.bot.deleteMessage(params: deleteParams)
        return true
    }
}
