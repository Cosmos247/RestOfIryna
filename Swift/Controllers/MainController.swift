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
        await dismissPendingPicker(context: context)
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
        await dismissPendingPicker(context: context)
        let settingsController = Controllers.settingsController
        try await settingsController.showSettingsMenu(context: context)
        context.session.routerName = settingsController.routerName
        try await context.session.saveAndCache(in: context.db)
        return true
    }

    private func onProfile(context: Context) async throws -> Bool {
        await dismissPendingPicker(context: context)
        try await showProfile(context: context)
        return true
    }

    private func onExplore(context: Context) async throws -> Bool {
        if try await guardedByTravel(context: context) { return true }
        let controller = Controllers.explorationController
        try await controller.showExploration(context: context)
        return true
    }

    private func onEstate(context: Context) async throws -> Bool {
        // showEstate owns the routerName transition so it can bail out with
        // a "governor away" notice without leaving routerName in the wrong
        // state.
        await dismissPendingPicker(context: context)
        if try await guardedByTravel(context: context) { return true }
        try await Controllers.estateController.showEstate(context: context)
        return true
    }

    private func onCapital(context: Context) async throws -> Bool {
        // showCapital owns the routerName transition so it can bail out with
        // a "governor away" notice without leaving routerName in the wrong
        // state.
        await dismissPendingPicker(context: context)
        if try await guardedByTravel(context: context) { return true }
        try await Controllers.capitalController.showCapital(context: context)
        return true
    }

    /// Returns `true` and posts the countdown banner if the player is
    /// currently on the road between estate and capital. Callers should
    /// short-circuit their own logic when this returns true — the player
    /// can't enter Estate / Capital / Explore while traveling.
    private func guardedByTravel(context: Context) async throws -> Bool {
        guard let trip = try await TravelState.current(for: context.session, on: context.db) else { return false }
        try await CapitalController.showTravelInProgress(context: context, trip: trip)
        return true
    }

    private func onInventory(context: Context) async throws -> Bool {
        await dismissPendingPicker(context: context)
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
        // The Explore button label is static. When tapped during an
        // expedition, `ExplorationController.showExploration` branches into
        // a countdown or report view — no need to mutate the keyboard.
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
        let equipped = try await EquipmentService.equipped(for: context.session, on: context.db)
        let text = renderProfile(session: context.session, equipped: equipped, lingo: context.lingo, style: style)
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

    private func renderProfile(session: User, equipped: [EquipmentSlot: InventoryEntry], lingo: Lingo, style: Int) -> String {
        let nickname = session.nickname ?? session.name
        let cls = CharacterClass(rawValue: session.characterClass ?? "") ?? .warrior
        let className = lingo.localize("registration.class.\(cls.rawValue)", locale: session.locale)
        let estate = session.estateName ?? "?"
        let level = session.level
        let xp = session.xp
        let xpMax = session.xpToNextLevel
        let isMaxLevel = level >= User.maxLevel
        let hp = session.hp, maxHp = session.maxHp
        let vigor = session.vigor, maxVigor = session.maxVigor
        let atk = session.effectiveAttack, def = session.effectiveDefense
        let crit = session.effectiveCrit, dodge = session.effectiveDodge, acc = session.effectiveAccuracy
        let gold = session.gold
        let starvingSuffix = VigorService.isStarving(session) ? " · " + lingo.localize("vigor.starving", locale: session.locale) : ""

        // Phase 5.3a — compact XP fragment shown in every profile style. At max
        // level the progress numbers are replaced with a "max" label.
        let xpFragment: String = isMaxLevel
            ? lingo.localize("profile.xp.max", locale: session.locale)
            : "\(xp)/\(xpMax)"

        // Main-hand line — shown on every style. Empty string if nothing equipped.
        let mainHandLabel = lingo.localize("profile.equipped.main_hand", locale: session.locale)
        let mainHandName: String
        if let entry = equipped[.mainHand], let item = ItemCatalog.find(entry.itemId) {
            // Tiered weapons resolve through ItemDisplay so the profile shows
            // "Sharpened Sword" etc. once the player upgrades.
            mainHandName = lingo.localize(ItemDisplay.nameKey(for: item, tier: entry.tier), locale: session.locale)
        } else {
            mainHandName = lingo.localize("profile.equipped.empty", locale: session.locale)
        }
        let mainHandLine = "🗡 \(mainHandLabel): \(mainHandName)"

        switch style {
        case 2:
            let xpBar = isMaxLevel ? "" : bar(xp, xpMax)
            let xpLine = isMaxLevel
                ? "📊 \(lingo.localize("profile.xp.max", locale: session.locale))"
                : "📊 \(xpBar) \(xpFragment)"
            return """
            \(cls.icon()) \(className)  «<b>\(nickname)</b>»  Lv.\(level)
            ━━━━━━━━━━━━━━━━

            ❤️ \(bar(hp, maxHp)) \(hp)/\(maxHp)
            🍖 \(bar(vigor, maxVigor)) \(vigor)/\(maxVigor)\(starvingSuffix)
            \(xpLine)

            ⚔️ \(atk)  🛡 \(def)  💥 \(crit)%
            🎯 \(acc)  💨 \(dodge)

            \(mainHandLine)
            💰 \(gold)
            🏰 \(estate)
            """
        case 3:
            let l = lingo
            let loc = session.locale
            let xpBlock: String
            if isMaxLevel {
                xpBlock = "📊 \(l.localize("profile.xp", locale: loc)): \(l.localize("profile.xp.max", locale: loc))"
            } else {
                xpBlock = """
                📊 \(l.localize("profile.xp", locale: loc)): \(xp)/\(xpMax)
                \(emojiBar(xp, xpMax, fill: "🟦"))
                """
            }
            return """
            \(cls.icon()) <b>\(nickname)</b> — \(className)
            ✨ \(l.localize("profile.level", locale: loc)) \(level)

            \(xpBlock)

            ❤️ \(l.localize("profile.health", locale: loc)): \(hp)/\(maxHp)
            \(emojiBar(hp, maxHp, fill: "🟥"))

            🍖 \(l.localize("profile.vigor", locale: loc)): \(vigor)/\(maxVigor)\(starvingSuffix)
            \(emojiBar(vigor, maxVigor, fill: "🟧"))

            ⚔️ \(l.localize("profile.attack", locale: loc)): \(atk)    🛡 \(l.localize("profile.defense", locale: loc)): \(def)
            🎯 \(l.localize("profile.accuracy", locale: loc)): \(acc)    💨 \(l.localize("profile.dodge", locale: loc)): \(dodge)
            💥 \(l.localize("profile.crit", locale: loc)): \(crit)%

            \(mainHandLine)
            💰 \(gold) \(l.localize("profile.gold", locale: loc))
            🏰 \(l.localize("profile.estate", locale: loc)) «\(estate)»
            """
        default: // Style 1
            return """
            \(cls.icon()) <b>\(nickname)</b> · Lv.\(level)
            \(className)

            ❤️ \(hp)/\(maxHp)  🍖 \(vigor)/\(maxVigor)\(starvingSuffix)
            📊 XP \(xpFragment)

            ⚔️\(atk)  🛡\(def)  🎯\(acc)
            💨\(dodge)  💥\(crit)%

            \(mainHandLine)
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

        // Exploration-related callbacks can land in main's router when the
        // passive-expedition scheduler pushes a report while the player is
        // viewing the main menu (routerName = "main" at that point). Forward
        // them to the exploration controller so its full cleanup runs —
        // otherwise the default below would just nuke the inline message and
        // leave the state row behind, causing a duplicate delivery on the
        // next Explore tap.
        if data.hasPrefix("explore:") {
            return try await ExplorationController.onCallbackQuery(context: context)
        }
        // Phase 5.1: training mode keeps routerName at whatever the player
        // was in (typically "main" or "estate") so reply-keyboard nav stays
        // unblocked. The combat inline buttons fire `combat:*` callbacks that
        // need to reach `CombatController.onCallbackQuery` from any router.
        if data.hasPrefix("combat:") {
            return try await CombatController.onCallbackQuery(context: context)
        }

        // Default: delete inline message
        let chatId = TGChatId.chat(message.chat.id)
        let deleteParams = TGDeleteMessageParams(chatId: chatId, messageId: message.messageId)
        try await context.bot.deleteMessage(params: deleteParams)
        return true
    }
}
