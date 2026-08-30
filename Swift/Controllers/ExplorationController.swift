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
//    Death       — wipe non-equipped inventory, respawn at HP = 1 (vigor
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
        // Phase 6.0: travel + capital guards. The wilderness only borders the
        // estate — the player can't head out from the capital without
        // returning home first. Travel countdown takes precedence so the
        // banner explains why the action is blocked.
        if let trip = try await TravelState.current(for: context.session, on: context.db) {
            try await CapitalController.showTravelInProgress(context: context, trip: trip)
            return
        }
        if context.session.location == "capital" {
            let notice = context.lingo.localize("exploration.blocked_in_capital", locale: context.session.locale)
            try await context.bot.sendMessage(
                session: context.session,
                text: notice,
                parseMode: .html,
                replyMarkup: nil
            )
            return
        }

        if let state = try await ExplorationState.current(for: context.session, on: context.db) {
            if state.isPassive {
                if state.hasReadyReport {
                    // Snapshot the report payload and wipe the state row FIRST.
                    // If we render before deleting and the delete then fails or
                    // is skipped, the player would see a duplicate report on
                    // the next Explore tap.
                    let reportJSON = state.reportJSON
                    try await state.delete(on: context.db)
                    try await deliverPassiveReport(context: context, reportJSON: reportJSON)
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
    /// Player stays in MainController's routerName so tapping any main-menu
    /// button (Profile, Estate, Capital, Inventory, Settings) works
    /// natively — those handlers call `dismissPendingPicker` at the top,
    /// which deletes this message from chat. The picker's `explore:mode:*`
    /// inline callbacks still land here because MainController.onCallbackQuery
    /// forwards every `explore:*`-prefixed callback to ExplorationController.
    fileprivate func showModePicker(context: Context) async throws {
        // Clean up any previously shown picker (user re-tapped Explore
        // without committing to a mode) so we never have two pickers live.
        await dismissPendingPicker(context: context)

        context.session.routerName = Controllers.mainController.routerName
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
        let params = TGSendMessageParams(
            chatId: .chat(context.session.telegramId),
            text: prompt,
            parseMode: .html,
            replyMarkup: .inlineKeyboardMarkup(inline)
        )
        let sent = try await context.bot.sendMessage(params: params)
        await EphemeralChatState.shared.setPicker(
            telegramId: context.session.telegramId,
            messageId: sent.messageId
        )
    }

    /// Duration picker edits the mode-picker message in place (same inline
    /// message, keyboard swapped). Three choices plus a Back that returns
    /// to the mode picker.
    fileprivate func editToDurationPicker(chatId: TGChatId, messageId: Int, bot: TGBot, session: User, lingo: Lingo) async throws {
        let locale = session.locale
        let prompt = lingo.localize("exploration.duration.prompt", gender: session.gender, locale: locale)

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

    /// Send the stored `PassiveReport` text and drop back to main. Takes
    /// the raw report JSON rather than the state row — the caller is
    /// responsible for having already deleted the state so even if this
    /// method throws, the state doesn't linger and cause a duplicate
    /// delivery on the next Explore tap.
    ///
    /// Rendered as a single combined message (home-again line + report body)
    /// with the main reply keyboard so Estate / Capital etc. are usable
    /// right away. Same shape as the scheduler push.
    fileprivate func deliverPassiveReport(context: Context, reportJSON: String?) async throws {
        let lingo = context.lingo
        let locale = context.session.locale

        context.session.routerName = Controllers.mainController.routerName
        try await context.session.saveAndCache(in: context.db)

        let homeText = lingo.localize("exploration.passive.closed_home", gender: context.session.gender, locale: locale)
        let text: String
        if let json = reportJSON,
           let data = json.data(using: .utf8),
           let report = try? JSONDecoder().decode(PassiveReport.self, from: data) {
            let reportText = PassiveExpeditionService.renderReport(report, gender: context.session.gender, lingo: lingo, locale: locale)
            text = "\(homeText)\n\n\(reportText)"
        } else {
            text = homeText
        }
        try await Controllers.mainController.showMainMenu(context: context, text: text)
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
            mode: .active,
            on: context.db
        )
        state.recordVisit(state.stepsDeep)
        try await state.save(on: context.db)
        try await context.session.saveAndCache(in: context.db)

        if context.session.hp <= 0 {
            try await handleDeath(context: context, outcome: outcome)
            return true
        }

        if case .encounterStarted(let enemy) = outcome {
            try await handOffToCombat(context: context, state: state, enemy: enemy)
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
            mode: .active,
            on: context.db
        )
        state.recordVisit(state.stepsDeep)
        try await state.save(on: context.db)
        try await context.session.saveAndCache(in: context.db)

        if context.session.hp <= 0 {
            try await handleDeath(context: context, outcome: outcome)
            return true
        }

        if case .encounterStarted(let enemy) = outcome {
            try await handOffToCombat(context: context, state: state, enemy: enemy)
            return true
        }

        try await renderOutcome(context: context, outcome: outcome, state: state, priorVisits: priorVisits)
        return true
    }

    /// Stamp combat fields on the expedition row, transition the player into
    /// CombatController, and send the intro screen with the class-flavoured
    /// keyboard. Called from the step handlers when `rollStep` rolls an
    /// encounter in active mode.
    private func handOffToCombat(context: Context, state: ExplorationState, enemy: Enemy) async throws {
        let uses = CombatService.initialUsesForUser(context.session)
        state.beginCombat(enemyId: enemy.id, hp: enemy.hp, specialAtkUses: uses.atk, specialDefUses: uses.def, superUses: uses.sup)
        try await state.save(on: context.db)

        let combatCtrl = Controllers.combatController
        context.session.routerName = combatCtrl.routerName
        try await context.session.saveAndCache(in: context.db)

        try await combatCtrl.showCombat(context: context, state: state, enemy: enemy, intro: true)
    }

    // MARK: - Outcome rendering

    private func renderOutcome(context: Context, outcome: StepOutcome, state: ExplorationState, priorVisits: Int) async throws {
        let lingo = context.lingo
        let locale = context.session.locale
        let narrative = narrateOutcome(outcome, priorVisits: priorVisits, gender: context.session.gender, lingo: lingo, locale: locale)
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
            let iconPrefix = row.item.icon.map { "\($0) " } ?? ""
            let actionKey = row.item.type == .food ? "inventory.action.food" : "inventory.action.potion"
            let actionLabel = lingo.localize(actionKey, locale: locale)
            rows.append([
                TGInlineKeyboardButton(text: "\(iconPrefix)\(name) × \(row.quantity)", callbackData: "explore:info:\(row.item.id)"),
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
    /// Deletes the ExplorationState row and drops to main menu. On the very
    /// first successful return, also fires a one-shot tutorial hint pointing
    /// the player at the capital trader (gated by `tutorialTraderHintShown`).
    private func handleHomeReached(context: Context, state: ExplorationState) async throws {
        try await state.delete(on: context.db)
        try await goToMainMenu(context: context, text: context.lingo.localize("exploration.returned", locale: context.session.locale))

        if !context.session.tutorialTraderHintShown {
            let hint = context.lingo.localize("tutorial.trader_hint", locale: context.session.locale)
            try await context.bot.sendMessage(session: context.session, text: hint, parseMode: .html, replyMarkup: nil)
            context.session.tutorialTraderHintShown = true
            try await context.session.saveAndCache(in: context.db)
        }
    }

    private func goToMainMenu(context: Context, text: String) async throws {
        let mainCtrl = Controllers.mainController
        try await mainCtrl.showMainMenu(context: context, text: text)
        context.session.routerName = mainCtrl.routerName
        try await context.session.saveAndCache(in: context.db)
    }

    /// Hard respawn: wipe every non-equipped inventory row (equipped gear survives),
    /// set HP to 1 (vigor stays — per design), end the exploration state, and send
    /// a death screen as the main-menu text override.
    private func handleDeath(context: Context, outcome: StepOutcome) async throws {
        let cause = narrateOutcome(outcome, priorVisits: 0, gender: context.session.gender, lingo: context.lingo, locale: context.session.locale)
        try await Self.handleDeath(context: context, causeNarrative: cause)
    }

    /// Static death helper so CombatController can reuse the wipe + respawn
    /// flow without duplicating the inventory query / HP reset.
    static func handleDeath(context: Context, causeNarrative: String) async throws {
        let lingo = context.lingo
        let locale = context.session.locale

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

        let deathText = "💀 " + lingo.localize("exploration.death", gender: context.session.gender, locale: locale, interpolations: ["cause": causeNarrative])
        let mainCtrl = Controllers.mainController
        try await mainCtrl.showMainMenu(context: context, text: deathText)
        context.session.routerName = mainCtrl.routerName
        try await context.session.saveAndCache(in: context.db)
    }

    // MARK: - Rendering helpers

    fileprivate func renderStatusCard(user: User, state: ExplorationState, lingo: Lingo, locale: String) -> String {
        let depthLabel = lingo.localize("exploration.depth_label", locale: locale)
        let starving = VigorService.isStarving(user)
            ? " · " + lingo.localize("vigor.starving", locale: locale)
            : ""
        return """
        🌲 <b>\(depthLabel): \(state.stepsDeep) km</b>
        ❤️ \(user.hp)/\(user.effectiveMaxHp)  🍖 \(user.vigor)/\(user.maxVigor)\(starving)
        """
    }

    /// Render the narrative for a rolled outcome. `.nothing` picks between
    /// three flavor variants based on the room's prior visit count (fresh /
    /// thinned / bare). Every other outcome uses a single narrative.
    fileprivate func narrateOutcome(_ outcome: StepOutcome, priorVisits: Int, gender: String?, lingo: Lingo, locale: String) -> String {
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
            let label = itemLabelWithIcon(itemId, lingo: lingo, locale: locale)
            // Per-item foraging flavor text if one exists; Lingo returns the
            // key verbatim when no translation is registered, which we
            // detect and fall back to the generic loot.picked/full template.
            let findKey = "exploration.find.\(itemId)"
            let flavor = lingo.localize(findKey, locale: locale)
            if flavor != findKey {
                let qtyLine = "<b>+\(quantity) \(label)</b>"
                if picked {
                    return "\(flavor)\n\(qtyLine)"
                } else {
                    let bagFull = lingo.localize("exploration.outcome.loot.bag_full", locale: locale)
                    return "\(flavor)\n\(qtyLine)\n<i>\(bagFull)</i>"
                }
            } else {
                let fallbackKey = picked ? "exploration.outcome.loot.picked" : "exploration.outcome.loot.full"
                return lingo.localize(fallbackKey, locale: locale, interpolations: [
                    "item": label,
                    "qty": "\(quantity)"
                ])
            }

        case .trip(let hpLost):
            // Leading 🦵 is prepended here (post-interpolation) because Lingo
            // drops interpolations after a multi-UTF-16 emoji in the template.
            // ❤️ rides inside the `hp` interpolation value for the same reason.
            return "🦵 " + lingo.localize("exploration.outcome.trip", gender: gender, locale: locale, interpolations: [
                "hp": "❤️ −\(hpLost)"
            ])

        case .encounterWon(let enemy, let rounds, let hpLost, let vigorLost, let loot):
            let enemyName = "\(enemy.icon) " + lingo.localize(enemy.nameKey, locale: locale)
            // ❤️ / 🍖 are passed as interpolation values rather than placed in
            // the template — Lingo drops `%{}` placeholders that follow a
            // multi-UTF-16 emoji in the template itself.
            let header = "⚔️ " + lingo.localize("exploration.outcome.encounter.won", gender: gender, locale: locale, interpolations: [
                "enemy": enemyName,
                "rounds": "\(rounds)",
                "hp": "❤️ −\(hpLost)",
                "vigor": "🍖 −\(vigorLost)"
            ])
            var parts = [header]
            for drop in loot {
                let label = itemLabelWithIcon(drop.itemId, lingo: lingo, locale: locale)
                let key = drop.picked ? "exploration.outcome.loot.picked" : "exploration.outcome.loot.full"
                parts.append(lingo.localize(key, locale: locale, interpolations: [
                    "item": label,
                    "qty": "\(drop.quantity)"
                ]))
            }
            return parts.joined(separator: "\n")

        case .encounterLost(let enemy, let rounds, _, _):
            let enemyName = "\(enemy.icon) " + lingo.localize(enemy.nameKey, locale: locale)
            return "💀 " + lingo.localize("exploration.outcome.encounter.lost", locale: locale, interpolations: [
                "enemy": enemyName,
                "rounds": "\(rounds)"
            ])

        case .starvationOnly(let hpLost):
            return "🥀 " + lingo.localize("exploration.outcome.starvation", locale: locale, interpolations: [
                "hp": "❤️ −\(hpLost)"
            ])

        case .encounterStarted(let enemy):
            // Step handlers transition to CombatController before reaching
            // narrateOutcome, so this branch is only used when the encounter
            // is rendered as a generic line (e.g. in a future activity log).
            let enemyName = "\(enemy.icon) " + lingo.localize(enemy.nameKey, locale: locale)
            return "⚔️ " + lingo.localize("combat.encounter.intro", locale: locale, interpolations: [
                "enemy": enemyName
            ])
        }
    }

    private func itemNameOrId(_ itemId: String, lingo: Lingo, locale: String) -> String {
        if let item = ItemCatalog.find(itemId) {
            return lingo.localize(item.nameKey, locale: locale)
        }
        return itemId
    }

    /// Prepend the item's glyph (e.g. 🪵 for pine lumber) to its localized
    /// name so loot lines read as "+2 🪵 Pine Lumber". Returns the bare
    /// name if the item has no icon or isn't in the catalog.
    private func itemLabelWithIcon(_ itemId: String, lingo: Lingo, locale: String) -> String {
        guard let item = ItemCatalog.find(itemId) else { return itemId }
        let name = lingo.localize(item.nameKey, locale: locale)
        if let icon = item.icon {
            return "\(icon) \(name)"
        }
        return name
    }
}

// MARK: - Callback Queries

extension ExplorationController {
    static func onCallbackQuery(context: Context) async throws -> Bool {
        guard let query = context.update.callbackQuery else { return false }
        guard let message = query.message else { return false }
        guard let data = query.data else { return false }

        // Stale `combat:*` buttons (e.g. the inline keyboard left on the
        // last round's message after combat ended) land here once routerName
        // flips back to "exploration". Forward to CombatController so it can
        // surface a clean "combat is over" toast instead of the generic
        // router fallback.
        if data.hasPrefix("combat:") {
            return try await CombatController.onCallbackQuery(context: context)
        }

        guard data.hasPrefix("explore:") else { return false }

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
        // Removes the inline report, drops any lingering state row (the
        // scheduler push leaves the row in place so we can re-deliver on
        // failure), and sends a "back at the estate" main menu so the
        // player knows the expedition cycle is closed.
        if data == "explore:passive:close" {
            let deleteParams = TGDeleteMessageParams(chatId: chatId, messageId: message.messageId)
            _ = try? await context.bot.deleteMessage(params: deleteParams)
            _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id))

            // Unconditional wipe — `.end` is a no-op if there's no row.
            try await ExplorationState.end(for: context.session, on: context.db)

            context.session.routerName = Controllers.mainController.routerName
            try await context.session.saveAndCache(in: context.db)

            let homeText = context.lingo.localize("exploration.passive.closed_home", gender: context.session.gender, locale: locale)
            try await Controllers.mainController.showMainMenu(context: context, text: homeText)
            return true
        }

        // Mode picker → Active reconnaissance: begin a fresh active expedition.
        if data == "explore:mode:active" {
            // Idempotency guard — if an expedition row already exists (stale
            // picker tap, or a race with the passive scheduler), bail out to
            // showExploration so we never silently delete active progress.
            if try await ExplorationState.current(for: context.session, on: context.db) != nil {
                _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id))
                let deleteParams = TGDeleteMessageParams(chatId: chatId, messageId: message.messageId)
                _ = try? await context.bot.deleteMessage(params: deleteParams)
                try await ctrl.showExploration(context: context)
                return true
            }
            let deleteParams = TGDeleteMessageParams(chatId: chatId, messageId: message.messageId)
            _ = try? await context.bot.deleteMessage(params: deleteParams)
            _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id))
            try await ctrl.beginActive(context: context)
            return true
        }

        // Mode picker → Passive expedition: edit message in place to show
        // the duration picker.
        if data == "explore:mode:passive" {
            // Idempotency guard — see note on explore:mode:active above.
            if try await ExplorationState.current(for: context.session, on: context.db) != nil {
                _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id))
                let deleteParams = TGDeleteMessageParams(chatId: chatId, messageId: message.messageId)
                _ = try? await context.bot.deleteMessage(params: deleteParams)
                try await ctrl.showExploration(context: context)
                return true
            }
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
            // Idempotency guard — stale picker tap after an expedition
            // already started (e.g. via a concurrent dispatch).
            if try await ExplorationState.current(for: context.session, on: context.db) != nil {
                _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id))
                let deleteParams = TGDeleteMessageParams(chatId: chatId, messageId: message.messageId)
                _ = try? await context.bot.deleteMessage(params: deleteParams)
                try await ctrl.showExploration(context: context)
                return true
            }
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
            let confirmation = context.lingo.localize("exploration.passive.started", gender: context.session.gender, locale: locale, interpolations: ["time": timeText])
            let editParams = TGEditMessageTextParams(
                chatId: chatId,
                messageId: message.messageId,
                text: confirmation,
                parseMode: .html,
                replyMarkup: nil
            )
            _ = try? await context.bot.editMessageText(params: editParams)
            _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id))
            // No extra keyboard-restoring message: the player came from the
            // main menu (picker never swapped the reply keyboard) so the
            // main keyboard is still in place.
            return true
        }

        // Item info — lore modal if the item has a description, placeholder
        // toast otherwise. Same convention as InventoryController.
        if data.hasPrefix("explore:info:") {
            let itemId = String(data.dropFirst("explore:info:".count))
            guard let item = ItemCatalog.find(itemId) else {
                _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id))
                return true
            }
            let answer: TGAnswerCallbackQueryParams
            if let descKey = item.descriptionKey {
                let description = context.lingo.localize(descKey, locale: locale)
                answer = TGAnswerCallbackQueryParams(callbackQueryId: query.id, text: description, showAlert: true)
            } else {
                let itemName = context.lingo.localize(item.nameKey, locale: locale)
                let toast = context.lingo.localize("inventory.info.placeholder", locale: locale, interpolations: ["name": itemName])
                answer = TGAnswerCallbackQueryParams(callbackQueryId: query.id, text: toast, showAlert: true)
            }
            _ = try? await context.bot.answerCallbackQuery(params: answer)
            return true
        }

        // Consume one food/potion and refresh the bag view in place.
        if data.hasPrefix("explore:eat:") {
            let itemId = String(data.dropFirst("explore:eat:".count))
            guard let item = ItemCatalog.find(itemId), VigorService.isConsumable(item) else {
                _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id))
                return true
            }
            // Raw-only ingredient (e.g. potato) — consumable type but no
            // vigor/HP effects until cooked. Surface a clearer toast than
            // the generic "no effect" fallback below.
            if item.effects.isEmpty {
                let itemName = context.lingo.localize(item.nameKey, locale: locale)
                let toast = context.lingo.localize("consume.not_raw_edible", locale: locale, interpolations: ["name": itemName])
                _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id, text: toast, showAlert: true))
                return true
            }
            guard try await InventoryEntry.has(itemId, user: context.session, on: context.db) else {
                _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id))
                return true
            }
            guard let result = VigorService.consume(item, user: context.session) else {
                let toast = context.lingo.localize("consume.no_effect", locale: locale)
                _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id, text: toast, showAlert: true))
                return true
            }
            try await InventoryEntry.remove(itemId, quantity: 1, from: context.session, on: context.db)
            try await context.session.saveAndCache(in: context.db)

            _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id))

            // Build the inline status line shown atop the refreshed bag.
            // Each restored stat shows the new (current/max) total in parens
            // so the player sees both the gain and the pool state at a glance.
            let itemName = context.lingo.localize(item.nameKey, locale: locale)
            var parts: [String] = []
            if result.vigorRestored > 0 {
                parts.append(context.lingo.localize("vigor.restored", locale: locale, interpolations: [
                    "amount":  "\(result.vigorRestored)",
                    "current": "\(context.session.vigor)",
                    "max":     "\(context.session.maxVigor)"
                ]))
            }
            if result.hpRestored > 0 {
                parts.append(context.lingo.localize("hp.restored", locale: locale, interpolations: [
                    "amount":  "\(result.hpRestored)",
                    "current": "\(context.session.hp)",
                    "max":     "\(context.session.effectiveMaxHp)"
                ]))
            }
            let statusLine = "✅ \(itemName) — " + parts.joined(separator: ", ")

            let (body, inline) = try await ctrl.renderBag(context: context)
            let editParams = TGEditMessageTextParams(
                chatId: chatId,
                messageId: message.messageId,
                text: body,
                parseMode: .html,
                replyMarkup: inline
            )
            _ = try? await context.bot.editMessageText(params: editParams)
            await ctrl.postStatusBanner(statusLine, context: context)
            return true
        }

        return false
    }
}
