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

    /// Branching entry into the exploration flow:
    ///   - Passive state with a ready report → deliver + delete state, player
    ///     lands back at main with the report message above them.
    ///   - Passive state still in flight → countdown status in the chat;
    ///     routerName stays at main so regen + nav keep working normally.
    ///   - Active state → resume with the expedition reply keyboard.
    ///   - No state → show the mode picker (active vs passive).
    public func showExploration(context: Context) async throws {
        if let state = try await ExplorationState.current(for: context.session, on: context.db) {
            if state.isPassive {
                if state.hasReadyReport {
                    try await deliverPassiveReport(context: context, state: state)
                } else {
                    try await showPassiveCountdown(context: context, state: state)
                }
                return
            }
            try await resumeActive(context: context, state: state)
            return
        }

        try await showModePicker(context: context)
    }

    /// Send the expedition reply keyboard and a status card for an existing
    /// active expedition. Used when the player re-enters exploration after
    /// checking the bag, opening the estate, etc.
    private func resumeActive(context: Context, state: ExplorationState) async throws {
        context.session.routerName = routerName
        try await context.session.saveAndCache(in: context.db)

        let lingo = context.lingo
        let locale = context.session.locale
        let intro = lingo.localize("exploration.resumed", locale: locale)
        let body = "\(intro)\n\n\(renderStatusCard(user: context.session, state: state, lingo: lingo, locale: locale))"
        let markup = generateControllerKB(session: context.session, lingo: lingo)
        try await context.bot.sendMessage(session: context.session, text: body, parseMode: .html, replyMarkup: markup)
    }

    /// Start a fresh active expedition at km 0. Called from the mode picker
    /// when the player chooses reconnaissance.
    private func beginActive(context: Context) async throws {
        let state = try await ExplorationState.begin(for: context.session, on: context.db)
        context.session.routerName = routerName
        try await context.session.saveAndCache(in: context.db)

        let lingo = context.lingo
        let locale = context.session.locale
        let intro = lingo.localize("exploration.started", locale: locale)
        let body = "\(intro)\n\n\(renderStatusCard(user: context.session, state: state, lingo: lingo, locale: locale))"
        let markup = generateControllerKB(session: context.session, lingo: lingo)
        try await context.bot.sendMessage(session: context.session, text: body, parseMode: .html, replyMarkup: markup)
    }

    /// Mode picker: inline keyboard with [Reconnaissance] / [Expedition].
    /// Reply keyboard stays whatever the player had (usually main's) so they
    /// can still navigate away. Callbacks land on this controller because we
    /// set routerName = "exploration".
    fileprivate func showModePicker(context: Context) async throws {
        context.session.routerName = routerName
        try await context.session.saveAndCache(in: context.db)

        let lingo = context.lingo
        let locale = context.session.locale
        let prompt = lingo.localize("exploration.mode.prompt", locale: locale)
        let activeLabel  = lingo.localize("exploration.mode.active",  locale: locale)
        let passiveLabel = lingo.localize("exploration.mode.passive", locale: locale)
        let inline = TGInlineKeyboardMarkup(inlineKeyboard: [
            [TGInlineKeyboardButton(text: activeLabel,  callbackData: "explore:mode:active")],
            [TGInlineKeyboardButton(text: passiveLabel, callbackData: "explore:mode:passive")]
        ])
        try await context.bot.sendMessage(
            session: context.session,
            text: prompt,
            parseMode: .html,
            replyMarkup: .inlineKeyboardMarkup(inline)
        )
    }

    /// Duration picker edits the mode-picker message in place (same inline
    /// message, keyboard swapped). Three choices plus a Back that returns
    /// to the mode picker.
    fileprivate func editToDurationPicker(chatId: TGChatId, messageId: Int, bot: TGBot, session: User, lingo: Lingo) async throws {
        let locale = session.locale
        let prompt = lingo.localize("exploration.duration.prompt", locale: locale)

        var rows: [[TGInlineKeyboardButton]] = []
        for duration in PassiveDuration.allCases {
            let label = lingo.localize(duration.localeKey, locale: locale)
            rows.append([TGInlineKeyboardButton(text: label, callbackData: "explore:dur:\(duration.rawValue)")])
        }
        let backLabel = lingo.localize("exploration.duration.back", locale: locale)
        rows.append([TGInlineKeyboardButton(text: backLabel, callbackData: "explore:mode:pick")])

        let params = TGEditMessageTextParams(
            chatId: chatId,
            messageId: messageId,
            text: prompt,
            parseMode: .html,
            replyMarkup: TGInlineKeyboardMarkup(inlineKeyboard: rows)
        )
        _ = try? await bot.editMessageText(params: params)
    }

    fileprivate func editToModePicker(chatId: TGChatId, messageId: Int, bot: TGBot, session: User, lingo: Lingo) async throws {
        let locale = session.locale
        let prompt = lingo.localize("exploration.mode.prompt", locale: locale)
        let activeLabel  = lingo.localize("exploration.mode.active",  locale: locale)
        let passiveLabel = lingo.localize("exploration.mode.passive", locale: locale)
        let inline = TGInlineKeyboardMarkup(inlineKeyboard: [
            [TGInlineKeyboardButton(text: activeLabel,  callbackData: "explore:mode:active")],
            [TGInlineKeyboardButton(text: passiveLabel, callbackData: "explore:mode:passive")]
        ])
        let params = TGEditMessageTextParams(
            chatId: chatId,
            messageId: messageId,
            text: prompt,
            parseMode: .html,
            replyMarkup: inline
        )
        _ = try? await bot.editMessageText(params: params)
    }

    /// Countdown status shown when the player re-opens exploration while a
    /// passive expedition is still running. Routername stays at whatever the
    /// player is currently at — the bot will push a report when the timer
    /// fires regardless of where the player is.
    fileprivate func showPassiveCountdown(context: Context, state: ExplorationState) async throws {
        let lingo = context.lingo
        let locale = context.session.locale
        let remaining = state.secondsRemaining() ?? 0
        let time = PassiveExpeditionService.formatCountdown(remaining)
        let text = lingo.localize("exploration.passive.inflight", locale: locale, interpolations: ["time": time])
        try await context.bot.sendMessage(
            session: context.session,
            text: text,
            parseMode: .html,
            replyMarkup: nil
        )
    }

    /// Send the stored `PassiveReport` text, delete the state row, and drop
    /// back to main. Used when the player opens exploration *after* the
    /// scheduler finished the simulation.
    fileprivate func deliverPassiveReport(context: Context, state: ExplorationState) async throws {
        let lingo = context.lingo
        let locale = context.session.locale

        if let json = state.reportJSON,
           let data = json.data(using: .utf8),
           let report = try? JSONDecoder().decode(PassiveReport.self, from: data) {
            let text = PassiveExpeditionService.renderReport(report, lingo: lingo, locale: locale)
            let closeLabel = lingo.localize("exploration.passive.report.close", locale: locale)
            let markup = TGInlineKeyboardMarkup(inlineKeyboard: [[
                TGInlineKeyboardButton(text: closeLabel, callbackData: "explore:passive:close")
            ]])
            try await context.bot.sendMessage(
                session: context.session,
                text: text,
                parseMode: .html,
                replyMarkup: .inlineKeyboardMarkup(markup)
            )
        }

        try await state.delete(on: context.db)

        // Drop back to main — active reply keyboard wasn't shown during
        // passive, but make sure routerName is sane.
        context.session.routerName = Controllers.mainController.routerName
        try await context.session.saveAndCache(in: context.db)
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

        // Close-report button on the delivered passive expedition message.
        if data == "explore:passive:close" {
            let deleteParams = TGDeleteMessageParams(chatId: chatId, messageId: message.messageId)
            _ = try? await context.bot.deleteMessage(params: deleteParams)
            _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id))
            return true
        }

        // Mode picker → Active reconnaissance: begin a fresh active expedition.
        if data == "explore:mode:active" {
            let deleteParams = TGDeleteMessageParams(chatId: chatId, messageId: message.messageId)
            _ = try? await context.bot.deleteMessage(params: deleteParams)
            _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id))
            try await ctrl.beginActive(context: context)
            return true
        }

        // Mode picker → Passive expedition: edit message in place to show
        // the duration picker.
        if data == "explore:mode:passive" {
            _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id))
            try await ctrl.editToDurationPicker(chatId: chatId, messageId: message.messageId, bot: context.bot, session: context.session, lingo: context.lingo)
            return true
        }

        // Duration picker Back button → edit message back to mode picker.
        if data == "explore:mode:pick" {
            _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id))
            try await ctrl.editToModePicker(chatId: chatId, messageId: message.messageId, bot: context.bot, session: context.session, lingo: context.lingo)
            return true
        }

        // Duration pick → start passive expedition.
        if data.hasPrefix("explore:dur:") {
            let raw = String(data.dropFirst("explore:dur:".count))
            guard let rawInt = Int(raw), let duration = PassiveDuration(rawValue: rawInt) else {
                _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id))
                return true
            }
            _ = try await PassiveExpeditionService.start(
                for: context.session,
                duration: duration,
                on: context.db,
                bot: context.bot,
                lingo: context.lingo
            )

            // Player stays at the estate while the expedition runs; routerName
            // flips to main so the main reply keyboard is authoritative again.
            context.session.routerName = Controllers.mainController.routerName
            try await context.session.saveAndCache(in: context.db)

            let timeText = PassiveExpeditionService.formatDuration(duration)
            let confirmation = context.lingo.localize("exploration.passive.started", locale: locale, interpolations: ["time": timeText])
            let editParams = TGEditMessageTextParams(
                chatId: chatId,
                messageId: message.messageId,
                text: confirmation,
                parseMode: .html,
                replyMarkup: nil
            )
            _ = try? await context.bot.editMessageText(params: editParams)
            _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id))

            // Send a fresh main-menu message so the reply keyboard is restored
            // (the previous one was expedition's step/back/bag if the player
            // just finished an active run).
            let mainCtrl = Controllers.mainController
            let replyKb = mainCtrl.generateControllerKB(session: context.session, lingo: context.lingo)
            try await context.bot.sendMessage(
                session: context.session,
                text: "🏰",
                parseMode: .html,
                replyMarkup: replyKb
            )
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
