//
//  ExplorationController.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 19.04.2026.
//
//  Active-mode exploration (Phase 3.1 MVP, 3.2 with per-room visit decay).
//
//  Flow:
//    Entry       — `showExploration` resumes existing ExplorationState or
//                  begins a fresh one at km 0. Sends a narrative + status card
//                  and sets the expedition reply keyboard:
//                    [🚶 Step fwd]  [🔙 Step back]
//                    [🎒 Bag]
//    Step fwd    — stepsDeep += 1. Roll an event at the new km with the room's
//                  prior visit count (tier 0 fresh → 1 reduced → 2+ bare).
//                  Record the visit. Save, render.
//    Step back   — stepsDeep -= 1. At km 0 pre-step: end expedition (never
//                  even entered). At km 1 pre-step: clean arrival home, no
//                  event roll. At km >= 2 pre-step: decrement, roll at the new
//                  km with prior visits, record the visit, render.
//    Bag         — inline consumables list (food + potion only). One-tap
//                  eat/use refreshes the message in place.
//    Death       — wipe non-equipped inventory, respawn at HP = 1 (hunger
//                  kept), end state, drop back to main with a death screen.
//    /start      — force-end without walking back (dev escape hatch).
//

import Fluent
import Foundation
@preconcurrency import Lingo
import SwiftTelegramBot

// MARK: - Exploration Controller Logic

final class ExplorationController: TGControllerBase, @unchecked Sendable {
    typealias T = ExplorationController

    // Localization keys for the expedition reply keyboard.
    private static let stepKey     = "exploration.button.step"
    private static let stepBackKey = "exploration.button.step_back"
    private static let bagKey      = "exploration.button.bag"

    // MARK: - Controller Lifecycle

    override public func attachHandlers(to bot: TGBot, lingo: Lingo) async {
        let router = Router(bot: bot) { router in
            router[Commands.start.command()]    = onStart
            router[Commands.settings.command()] = onSettings
            router[Commands.profile.command()]  = onProfile
            router[Commands.explore.command()]  = onRefresh

            // Expedition keyboard buttons — register every supported locale text.
            for locale in SupportedLocale.allCases {
                let loc = locale.rawValue
                router[lingo.localize(Self.stepKey,     locale: loc)] = onStepForward
                router[lingo.localize(Self.stepBackKey, locale: loc)] = onStepBack
                router[lingo.localize(Self.bagKey,      locale: loc)] = onBag
            }

            // A stray Cancel press (from another controller's keyboard) is a
            // hard exit — force-end the expedition rather than taking a step.
            let cancelLocales = Commands.cancel.buttonsForAllLocales(lingo: lingo)
            for button in cancelLocales { router[button.text] = onForceEnd }

            router.unmatched = unmatched
            router[.callback_query(data: nil)] = ExplorationController.onCallbackQuery
        }
        await processRouterForEachName(router)
    }

    public func onStart(context: Context) async throws -> Bool {
        // /start force-exits the expedition and returns to the manor. It does
        // NOT walk back — it's an escape hatch for dev / stuck-player cases.
        return try await onForceEnd(context: context)
    }

    private func onSettings(context: Context) async throws -> Bool {
        let ctrl = Controllers.settingsController
        try await ctrl.showSettingsMenu(context: context)
        context.session.routerName = ctrl.routerName
        try await context.session.saveAndCache(in: context.db)
        return true
    }

    private func onProfile(context: Context) async throws -> Bool {
        let ctrl = Controllers.mainController
        try await ctrl.showProfile(context: context)
        return true
    }

    private func onRefresh(context: Context) async throws -> Bool {
        try await showExploration(context: context)
        return true
    }

    override func unmatched(context: Context) async throws -> Bool {
        guard try await super.unmatched(context: context) else { return false }
        try await showExploration(context: context)
        return true
    }

    // MARK: - Public entry

    /// Resume the active expedition (if an ExplorationState row exists) or begin a
    /// fresh one at km 0. Caller handles routerName transition — this method sets
    /// it to `exploration` itself so main/inventory pass-throughs can just call it.
    public func showExploration(context: Context) async throws {
        let lingo = context.lingo
        let locale = context.session.locale

        let introKey: String
        let state: ExplorationState
        if let existing = try await ExplorationState.current(for: context.session, on: context.db) {
            state = existing
            introKey = "exploration.resumed"
        } else {
            state = try await ExplorationState.begin(for: context.session, on: context.db)
            introKey = "exploration.started"
        }

        context.session.routerName = routerName
        try await context.session.saveAndCache(in: context.db)

        let intro = lingo.localize(introKey, locale: locale)
        let body = "\(intro)\n\n\(renderStatusCard(user: context.session, state: state, lingo: lingo, locale: locale))"
        let markup = generateControllerKB(session: context.session, lingo: lingo)
        try await context.bot.sendMessage(session: context.session, text: body, parseMode: .html, replyMarkup: markup)
    }

    override public func generateControllerKB(session: User, lingo: Lingo) -> TGReplyMarkup? {
        let locale = session.locale
        let forward  = TGKeyboardButton(text: lingo.localize(Self.stepKey,     locale: locale))
        let backward = TGKeyboardButton(text: lingo.localize(Self.stepBackKey, locale: locale))
        let bag      = TGKeyboardButton(text: lingo.localize(Self.bagKey,      locale: locale))
        let markup = TGReplyKeyboardMarkup(
            keyboard: [[forward, backward], [bag]],
            resizeKeyboard: true
        )
        return .replyKeyboardMarkup(markup)
    }

    // MARK: - Step Forward

    private func onStepForward(context: Context) async throws -> Bool {
        guard let state = try await ExplorationState.current(for: context.session, on: context.db) else {
            // Shouldn't happen — expedition ended out-of-band. Re-enter.
            try await showExploration(context: context)
            return true
        }

        state.stepsDeep += 1
        let priorVisits = state.visitCount(state.stepsDeep)

        let outcome = try await ExplorationService.rollStep(
            for: context.session,
            kmDepth: state.stepsDeep,
            priorVisits: priorVisits,
            on: context.db
        )
        state.recordVisit(state.stepsDeep)
        try await state.save(on: context.db)
        try await context.session.saveAndCache(in: context.db)

        if context.session.hp <= 0 {
            try await handleDeath(context: context, outcome: outcome)
            return true
        }

        try await renderOutcome(context: context, outcome: outcome, state: state, priorVisits: priorVisits)
        return true
    }

    // MARK: - Step Back

    /// Step Back:
    /// - km 0 → never left the estate: end expedition immediately (no roll).
    /// - km 1 → arrival at the estate door: end expedition, no roll.
    /// - km ≥ 2 → decrement and roll at the new km with prior visit count.
    private func onStepBack(context: Context) async throws -> Bool {
        guard let state = try await ExplorationState.current(for: context.session, on: context.db) else {
            try await showExploration(context: context)
            return true
        }

        if state.stepsDeep <= 1 {
            try await handleHomeReached(context: context, state: state)
            return true
        }

        state.stepsDeep -= 1
        let priorVisits = state.visitCount(state.stepsDeep)

        let outcome = try await ExplorationService.rollStep(
            for: context.session,
            kmDepth: state.stepsDeep,
            priorVisits: priorVisits,
            on: context.db
        )
        state.recordVisit(state.stepsDeep)
        try await state.save(on: context.db)
        try await context.session.saveAndCache(in: context.db)

        if context.session.hp <= 0 {
            try await handleDeath(context: context, outcome: outcome)
            return true
        }

        try await renderOutcome(context: context, outcome: outcome, state: state, priorVisits: priorVisits)
        return true
    }

    // MARK: - Outcome rendering

    private func renderOutcome(context: Context, outcome: StepOutcome, state: ExplorationState, priorVisits: Int) async throws {
        let lingo = context.lingo
        let locale = context.session.locale
        let narrative = narrateOutcome(outcome, priorVisits: priorVisits, lingo: lingo, locale: locale)
        let status = renderStatusCard(user: context.session, state: state, lingo: lingo, locale: locale)
        let text = "\(narrative)\n\n\(status)"
        let markup = generateControllerKB(session: context.session, lingo: lingo)
        try await context.bot.sendMessage(session: context.session, text: text, parseMode: .html, replyMarkup: markup)
    }

    // MARK: - Bag

    private func onBag(context: Context) async throws -> Bool {
        let (text, inline) = try await renderBag(context: context)
        try await context.bot.sendMessage(
            session: context.session,
            text: text,
            parseMode: .html,
            replyMarkup: .inlineKeyboardMarkup(inline)
        )
        return true
    }

    /// Build the "scoped consumables" view shown during an expedition. Only food and
    /// potions are listed — other categories are managed back at the estate.
    fileprivate func renderBag(context: Context) async throws -> (text: String, markup: TGInlineKeyboardMarkup) {
        let lingo = context.lingo
        let locale = context.session.locale
        let entries = try await InventoryEntry.list(for: context.session, on: context.db)

        var byId: [String: (item: Item, quantity: Int)] = [:]
        for entry in entries {
            guard let item = ItemCatalog.find(entry.itemId),
                  item.type == .food || item.type == .potion else { continue }
            if let existing = byId[item.id] {
                byId[item.id] = (existing.item, existing.quantity + entry.quantity)
            } else {
                byId[item.id] = (item, entry.quantity)
            }
        }
        let sorted = byId.values.sorted { $0.item.id < $1.item.id }

        let title = lingo.localize("exploration.bag.title", locale: locale)
        let backLabel = lingo.localize("exploration.bag.back", locale: locale)

        if sorted.isEmpty {
            let empty = lingo.localize("exploration.bag.empty", locale: locale)
            let text = "🎒 <b>\(title)</b>\n\n\(empty)"
            let markup = TGInlineKeyboardMarkup(inlineKeyboard: [[
                TGInlineKeyboardButton(text: backLabel, callbackData: "explore:back")
            ]])
            return (text, markup)
        }

        var rows: [[TGInlineKeyboardButton]] = []
        for row in sorted {
            let name = lingo.localize(row.item.nameKey, locale: locale)
            let actionKey = row.item.type == .food ? "inventory.action.food" : "inventory.action.potion"
            let actionLabel = lingo.localize(actionKey, locale: locale)
            rows.append([
                TGInlineKeyboardButton(text: "\(name) × \(row.quantity)", callbackData: "explore:info:\(row.item.id)"),
                TGInlineKeyboardButton(text: actionLabel, callbackData: "explore:eat:\(row.item.id)")
            ])
        }
        rows.append([TGInlineKeyboardButton(text: backLabel, callbackData: "explore:back")])

        return ("🎒 <b>\(title)</b>", TGInlineKeyboardMarkup(inlineKeyboard: rows))
    }

    // MARK: - End / Death

    /// Force-end the expedition without walking back (e.g. /start or a stray
    /// Cancel button press from another controller's keyboard).
    private func onForceEnd(context: Context) async throws -> Bool {
        try await ExplorationState.end(for: context.session, on: context.db)
        try await goToMainMenu(context: context, text: context.lingo.localize("exploration.returned", locale: context.session.locale))
        return true
    }

    /// Clean arrival at the estate after Step Back from km 0 or km 1.
    /// Deletes the ExplorationState row and drops to main menu.
    private func handleHomeReached(context: Context, state: ExplorationState) async throws {
        try await state.delete(on: context.db)
        try await goToMainMenu(context: context, text: context.lingo.localize("exploration.returned", locale: context.session.locale))
    }

    private func goToMainMenu(context: Context, text: String) async throws {
        let mainCtrl = Controllers.mainController
        try await mainCtrl.showMainMenu(context: context, text: text)
        context.session.routerName = mainCtrl.routerName
        try await context.session.saveAndCache(in: context.db)
    }

    /// Hard respawn: wipe every non-equipped inventory row (equipped gear survives),
    /// set HP to 1 (hunger stays — per design), end the exploration state, and send
    /// a death screen as the main-menu text override.
    private func handleDeath(context: Context, outcome: StepOutcome) async throws {
        let lingo = context.lingo
        let locale = context.session.locale
        let cause = narrateOutcome(outcome, priorVisits: 0, lingo: lingo, locale: locale)

        if let userId = context.session.id {
            let rows = try await InventoryEntry.query(on: context.db)
                .filter(\.$user.$id, .equal, userId)
                .all()
            for row in rows where row.equippedSlot == nil {
                try await row.delete(on: context.db)
            }
        }

        context.session.hp = 1
        try await ExplorationState.end(for: context.session, on: context.db)

        let deathText = lingo.localize("exploration.death", locale: locale, interpolations: ["cause": cause])
        let mainCtrl = Controllers.mainController
        try await mainCtrl.showMainMenu(context: context, text: deathText)
        context.session.routerName = mainCtrl.routerName
        try await context.session.saveAndCache(in: context.db)
    }

    // MARK: - Rendering helpers

    fileprivate func renderStatusCard(user: User, state: ExplorationState, lingo: Lingo, locale: String) -> String {
        let depthLabel = lingo.localize("exploration.depth_label", locale: locale)
        let starving = HungerService.isStarving(user)
            ? " · " + lingo.localize("hunger.starving", locale: locale)
            : ""
        return """
        🌲 <b>\(depthLabel): \(state.stepsDeep) km</b>
        ❤️ \(user.hp)/\(user.maxHp)  🍖 \(user.hunger)/\(user.maxHunger)\(starving)
        """
    }

    /// Render the narrative for a rolled outcome. `.nothing` picks between
    /// three flavor variants based on the room's prior visit count (fresh /
    /// thinned / bare). Every other outcome uses a single narrative.
    fileprivate func narrateOutcome(_ outcome: StepOutcome, priorVisits: Int, lingo: Lingo, locale: String) -> String {
        switch outcome {
        case .nothing:
            let key: String
            switch priorVisits {
            case 0:  key = "exploration.outcome.nothing"
            case 1:  key = "exploration.outcome.nothing.revisited"
            default: key = "exploration.outcome.nothing.bare"
            }
            return lingo.localize(key, locale: locale)

        case .loot(let itemId, let quantity, let picked):
            let itemName = itemNameOrId(itemId, lingo: lingo, locale: locale)
            let key = picked ? "exploration.outcome.loot.picked" : "exploration.outcome.loot.full"
            return lingo.localize(key, locale: locale, interpolations: [
                "item": itemName,
                "qty": "\(quantity)"
            ])

        case .trip(let hpLost):
            return lingo.localize("exploration.outcome.trip", locale: locale, interpolations: [
                "hp": "\(hpLost)"
            ])

        case .encounterWon(let enemy, let rounds, let hpLost, let hungerLost, let loot):
            let enemyName = "\(enemy.icon) " + lingo.localize(enemy.nameKey, locale: locale)
            var parts = [lingo.localize("exploration.outcome.encounter.won", locale: locale, interpolations: [
                "enemy": enemyName,
                "rounds": "\(rounds)",
                "hp": "\(hpLost)",
                "hunger": "\(hungerLost)"
            ])]
            for drop in loot {
                let itemName = itemNameOrId(drop.itemId, lingo: lingo, locale: locale)
                let key = drop.picked ? "exploration.outcome.loot.picked" : "exploration.outcome.loot.full"
                parts.append(lingo.localize(key, locale: locale, interpolations: [
                    "item": itemName,
                    "qty": "\(drop.quantity)"
                ]))
            }
            return parts.joined(separator: "\n")

        case .encounterLost(let enemy, let rounds, _, _):
            let enemyName = "\(enemy.icon) " + lingo.localize(enemy.nameKey, locale: locale)
            return lingo.localize("exploration.outcome.encounter.lost", locale: locale, interpolations: [
                "enemy": enemyName,
                "rounds": "\(rounds)"
            ])

        case .starvationOnly(let hpLost):
            return lingo.localize("exploration.outcome.starvation", locale: locale, interpolations: [
                "hp": "\(hpLost)"
            ])
        }
    }

    private func itemNameOrId(_ itemId: String, lingo: Lingo, locale: String) -> String {
        if let item = ItemCatalog.find(itemId) {
            return lingo.localize(item.nameKey, locale: locale)
        }
        return itemId
    }
}

// MARK: - Callback Queries

extension ExplorationController {
    static func onCallbackQuery(context: Context) async throws -> Bool {
        guard let query = context.update.callbackQuery else { return false }
        guard let message = query.message else { return false }
        guard let data = query.data, data.hasPrefix("explore:") else { return false }

        let ctrl = Controllers.explorationController
        let locale = context.session.locale
        let chatId = TGChatId.chat(message.chat.id)

        // Dismiss the bag view.
        if data == "explore:back" {
            let deleteParams = TGDeleteMessageParams(chatId: chatId, messageId: message.messageId)
            _ = try? await context.bot.deleteMessage(params: deleteParams)
            _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id))
            return true
        }

        // Placeholder item info toast (full description view planned later, same as
        // the inventory controller).
        if data.hasPrefix("explore:info:") {
            let itemId = String(data.dropFirst("explore:info:".count))
            if let item = ItemCatalog.find(itemId) {
                let itemName = context.lingo.localize(item.nameKey, locale: locale)
                let toast = context.lingo.localize("inventory.info.placeholder", locale: locale, interpolations: ["name": itemName])
                _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id, text: toast, showAlert: false))
            } else {
                _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id))
            }
            return true
        }

        // Consume one food/potion and refresh the bag view in place.
        if data.hasPrefix("explore:eat:") {
            let itemId = String(data.dropFirst("explore:eat:".count))
            guard let item = ItemCatalog.find(itemId), HungerService.isConsumable(item) else {
                _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id))
                return true
            }
            guard try await InventoryEntry.has(itemId, user: context.session, on: context.db) else {
                _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id))
                return true
            }
            guard let result = HungerService.consume(item, user: context.session) else {
                let toast = context.lingo.localize("consume.no_effect", locale: locale)
                _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id, text: toast, showAlert: false))
                return true
            }
            try await InventoryEntry.remove(itemId, quantity: 1, from: context.session, on: context.db)
            try await context.session.saveAndCache(in: context.db)

            let itemName = context.lingo.localize(item.nameKey, locale: locale)
            var parts: [String] = []
            if result.hungerRestored > 0 {
                parts.append(context.lingo.localize("hunger.restored", locale: locale, interpolations: ["amount": "\(result.hungerRestored)"]))
            }
            if result.hpRestored > 0 {
                parts.append(context.lingo.localize("hp.restored", locale: locale, interpolations: ["amount": "\(result.hpRestored)"]))
            }
            let toast = "\(itemName) — " + parts.joined(separator: ", ")
            _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id, text: toast, showAlert: false))

            let (text, inline) = try await ctrl.renderBag(context: context)
            let editParams = TGEditMessageTextParams(
                chatId: chatId,
                messageId: message.messageId,
                text: text,
                parseMode: .html,
                replyMarkup: inline
            )
            _ = try? await context.bot.editMessageText(params: editParams)
            return true
        }

        return false
    }
}
