//
//  CombatController.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 25.04.2026.
//
//  Phase 4.1 interactive PvE combat ("Standoff" duel). Triggered when an
//  active-mode `rollStep` returns `.encounterStarted(enemy)` —
//  ExplorationController stamps the combat fields on the expedition row,
//  flips `routerName = "combat"`, then calls `showCombat`.
//
//  Round flow:
//    Player taps Attack / Defend / Flee → drain hunger for the action,
//    resolve via CombatService.applyAttack (or chipDamage / direct hit for
//    Defend / failed Flee respectively), update enemy HP on the state row
//    and player HP on the User, render narrative + status + same keyboard.
//
//  End conditions:
//    - Enemy HP ≤ 0 → award loot via ExplorationService.awardEncounterDrops,
//      send victory narrative, clear combat fields, hand player back to
//      ExplorationController at the same km (encounter consumed).
//    - Player HP ≤ 0 → ExplorationController.handleDeath (wipe non-equipped
//      inventory, hp = 1, back to estate).
//    - Successful flee → clear combat fields, decrement stepsDeep by 1,
//      hand player back to ExplorationController one room shallower.
//    - Failed flee → enemy lands a forced hit (no dodge, no crit), combat
//      continues. If that forced hit kills the player, treat as defeat.
//
//  Class identity (Phase 4.1) lives entirely in the button labels — the
//  mechanics are identical across classes, but the existing stat differences
//  (warrior tank / archer crit-acc / mage crit) already make the same fight
//  feel different. Class-specific Defend / Flee techniques are deferred to 4.2.
//

import Fluent
import Foundation
@preconcurrency import Lingo
import SwiftTelegramBot

final class CombatController: TGControllerBase, @unchecked Sendable {
    typealias T = CombatController

    // Locale key prefixes — combined with `<class>` to get the actual key.
    private static let attackKeyPrefix = "combat.button.attack."
    private static let defendKeyPrefix = "combat.button.defend."
    private static let fleeKeyPrefix   = "combat.button.flee."

    // MARK: - Lifecycle

    override public func attachHandlers(to bot: TGBot, lingo: Lingo) async {
        let router = Router(bot: bot) { router in
            router[Commands.start.command()] = onStart
            // Combat actions are inline buttons attached to each round message
            // so the player's existing reply keyboard (exploration's
            // [Step fwd][Step back]/[Bag], or nothing during registration)
            // stays in place but cannot drive the fight.
            router[.callback_query(data: nil)] = T.onCallbackQuery
            router.unmatched = unmatched
        }
        await processRouterForEachName(router)
    }

    /// /start force-ends the fight. During registration this drops the
    /// player back to the wolves prompt (the registration-bound retry path);
    /// otherwise it exits to the main menu and clears the expedition row.
    public func onStart(context: Context) async throws -> Bool {
        if let state = try await ExplorationState.current(for: context.session, on: context.db) {
            try await state.delete(on: context.db)
        }
        if context.session.registrationStep < 6 {
            try await Registration.handleCombatEnd(context: context, won: false)
            return true
        }
        let mainCtrl = Controllers.mainController
        context.session.routerName = mainCtrl.routerName
        try await context.session.saveAndCache(in: context.db)
        try await mainCtrl.showMainMenu(context: context, text: nil)
        return true
    }

    override func unmatched(context: Context) async throws -> Bool {
        guard try await super.unmatched(context: context) else { return false }
        // Anything that isn't a combat callback or global command (incl. the
        // player's old reply-keyboard buttons) gets the in-combat notice.
        try await sendInCombatNotice(context: context)
        return true
    }

    /// Combat does not own a reply keyboard — actions are inline buttons on
    /// the round message. Returning nil keeps whatever reply keyboard was
    /// visible before combat started (exploration's, or none for registration)
    /// so the player can see they're "trapped" in the fight at the UI level.
    override public func generateControllerKB(session: User, lingo: Lingo) -> TGReplyMarkup? {
        return nil
    }

    /// Inline keyboard with class-flavoured Attack / Defend / Flee buttons.
    /// Same handler fires regardless of which class label was tapped; class
    /// is inferred from session at render time.
    private func combatInlineKeyboard(session: User, lingo: Lingo) -> TGReplyMarkup {
        let cls = CharacterClass(rawValue: session.characterClass ?? "") ?? .warrior
        let locale = session.locale
        let attack = TGInlineKeyboardButton(text: lingo.localize(Self.attackKeyPrefix + cls.rawValue, locale: locale), callbackData: "combat:attack")
        let defend = TGInlineKeyboardButton(text: lingo.localize(Self.defendKeyPrefix + cls.rawValue, locale: locale), callbackData: "combat:defend")
        let flee   = TGInlineKeyboardButton(text: lingo.localize(Self.fleeKeyPrefix   + cls.rawValue, locale: locale), callbackData: "combat:flee")
        return .inlineKeyboardMarkup(TGInlineKeyboardMarkup(inlineKeyboard: [[attack, defend], [flee]]))
    }

    // MARK: - Public entry

    /// Render the combat screen. `intro=true` for the first message of a
    /// fresh fight (sends the encounter narrative line); `intro=false` for
    /// re-renders that just want to re-display the keyboard + status.
    public func showCombat(context: Context, state: ExplorationState, enemy: Enemy, intro: Bool) async throws {
        let lingo = context.lingo
        let locale = context.session.locale
        let enemyName = "\(enemy.icon) " + lingo.localize(enemy.nameKey, locale: locale)
        let enemyHP = state.combatEnemyHP ?? enemy.hp

        var lines: [String] = []
        if intro {
            lines.append("⚔️ " + lingo.localize("combat.encounter.intro", locale: locale, interpolations: [
                "enemy": enemyName
            ]))
        }
        lines.append(renderStatusCard(user: context.session, enemy: enemy, enemyHP: enemyHP, lingo: lingo, locale: locale))
        let text = lines.joined(separator: "\n\n")

        let markup = combatInlineKeyboard(session: context.session, lingo: lingo)
        try await context.bot.sendMessage(session: context.session, text: text, parseMode: .html, replyMarkup: markup)
    }

    // MARK: - Callback dispatch

    /// All combat callbacks come through here. Unknown / stale callbacks
    /// (e.g. an old Estate inline button that lingered before combat started)
    /// fall through to the in-combat notice.
    static func onCallbackQuery(context: Context) async throws -> Bool {
        guard let data = context.update.callbackQuery?.data else { return false }
        let ctrl = Controllers.combatController
        switch data {
        case "combat:attack": return try await ctrl.onAttack(context: context)
        case "combat:defend": return try await ctrl.onDefend(context: context)
        case "combat:flee":   return try await ctrl.onFlee(context: context)
        default:
            try await ctrl.sendInCombatNotice(context: context)
            return true
        }
    }

    /// Sent in response to anything that isn't a valid combat action while
    /// combat is in progress: pre-combat reply-keyboard taps, stale inline
    /// buttons, free-form text. Just a one-line nudge — the previous combat
    /// message above still carries the inline action buttons, so duplicating
    /// the status card + buttons here would only spam the chat.
    private func sendInCombatNotice(context: Context) async throws {
        guard let state = try await ExplorationState.current(for: context.session, on: context.db),
              state.isInCombat,
              let enemyId = state.combatEnemyId,
              let enemy = EnemyCatalog.find(enemyId) else {
            // Combat state vanished — bail back to exploration entry.
            context.session.routerName = Controllers.explorationController.routerName
            try await context.session.saveAndCache(in: context.db)
            try await Controllers.explorationController.showExploration(context: context)
            return
        }
        let lingo = context.lingo
        let locale = context.session.locale
        let enemyName = "\(enemy.icon) " + lingo.localize(enemy.nameKey, locale: locale)
        let text = "⚔️ " + lingo.localize("combat.in_progress", locale: locale, interpolations: ["enemy": enemyName])
        try await context.bot.sendMessage(session: context.session, text: text, parseMode: .html)
    }

    // MARK: - Action handlers

    private func onAttack(context: Context) async throws -> Bool {
        guard let (state, enemy) = try await loadCombat(context: context) else { return true }

        _ = HungerService.drain(context.session, action: .combatAttack)

        // Player strikes.
        let player = context.session
        let playerHit = CombatService.applyAttack(
            attackerATK: player.effectiveAttack,
            attackerCrit: player.effectiveCrit,
            attackerAcc: player.effectiveAccuracy,
            defenderDEF: enemy.defense,
            defenderDodge: 0
        )
        var enemyHP = state.combatEnemyHP ?? enemy.hp
        let playerLine = renderPlayerHit(playerHit, enemy: enemy, lingo: context.lingo, locale: context.session.locale, enemyHPAfter: { d in
            enemyHP = max(0, enemyHP - d)
            return enemyHP
        })

        if enemyHP <= 0 {
            try await finishVictory(context: context, state: state, enemy: enemy, headerLines: [playerLine])
            return true
        }

        // Enemy counter — no crit/accuracy stats on enemies yet, so 0/0.
        let enemyHit = CombatService.applyAttack(
            attackerATK: enemy.attack, attackerCrit: 0, attackerAcc: 0,
            defenderDEF: player.effectiveDefense,
            defenderDodge: player.effectiveDodge
        )
        let enemyLine = renderEnemyHit(enemyHit, enemy: enemy, lingo: context.lingo, locale: context.session.locale)
        switch enemyHit {
        case .miss: break
        case .hit(let d), .crit(let d): player.hp = max(0, player.hp - d)
        }

        try await finishRound(context: context, state: state, enemy: enemy, enemyHP: enemyHP, lines: [playerLine, enemyLine])
        return true
    }

    private func onDefend(context: Context) async throws -> Bool {
        guard let (state, enemy) = try await loadCombat(context: context) else { return true }

        _ = HungerService.drain(context.session, action: .combatDefend)

        // Defend chip damage — always lands, no crit, scaled to 30% of base.
        let player = context.session
        let chip = CombatService.chipDamage(attackerATK: player.effectiveAttack, defenderDEF: enemy.defense)
        let enemyHP = max(0, (state.combatEnemyHP ?? enemy.hp) - chip)
        let playerLine = "🛡 " + context.lingo.localize("combat.defend.absorbed", locale: context.session.locale, interpolations: [
            "enemy": "\(enemy.icon) " + context.lingo.localize(enemy.nameKey, locale: context.session.locale),
            "damage": "\(chip)"
        ])

        if enemyHP <= 0 {
            try await finishVictory(context: context, state: state, enemy: enemy, headerLines: [playerLine])
            return true
        }

        // Enemy strikes against doubled effective DEF for this round only.
        let enemyHit = CombatService.applyAttack(
            attackerATK: enemy.attack, attackerCrit: 0, attackerAcc: 0,
            defenderDEF: player.effectiveDefense * 2,
            defenderDodge: player.effectiveDodge
        )
        let enemyLine = renderEnemyHit(enemyHit, enemy: enemy, lingo: context.lingo, locale: context.session.locale)
        switch enemyHit {
        case .miss: break
        case .hit(let d), .crit(let d): player.hp = max(0, player.hp - d)
        }

        try await finishRound(context: context, state: state, enemy: enemy, enemyHP: enemyHP, lines: [playerLine, enemyLine])
        return true
    }

    private func onFlee(context: Context) async throws -> Bool {
        guard let (state, enemy) = try await loadCombat(context: context) else { return true }

        _ = HungerService.drain(context.session, action: .combatFlee)

        let player = context.session
        let lingo = context.lingo
        let locale = context.session.locale
        let enemyName = "\(enemy.icon) " + lingo.localize(enemy.nameKey, locale: locale)

        let success = Int.random(in: 1...100) <= 50
        if success {
            let line = "💨 " + lingo.localize("combat.flee.success", locale: locale, interpolations: [
                "enemy": enemyName
            ])

            if context.session.registrationStep < 6 {
                // Registration: fleeing the wolves is a soft retry — same as
                // defeat. The state row is deleted by handleCombatEnd's caller
                // path (we wipe it here directly to keep the invariant clean).
                try await state.delete(on: context.db)
                try await player.saveAndCache(in: context.db)
                try await context.bot.sendMessage(session: context.session, text: line, parseMode: .html)
                try await Registration.handleCombatEnd(context: context, won: false)
                return true
            }

            // Step out of the encounter: clear combat fields, walk back one km.
            state.endCombat()
            state.stepsDeep = max(0, state.stepsDeep - 1)
            try await state.save(on: context.db)
            try await player.saveAndCache(in: context.db)

            try await handBackToExploration(context: context, prefix: line)
            return true
        }

        // Failed — enemy lands a forced full-damage hit "in the back" (no
        // dodge, no crit roll), combat continues.
        let damage = max(1, Int((Double(max(1, enemy.attack - player.effectiveDefense)) * Double.random(in: CombatService.varianceRange)).rounded()))
        player.hp = max(0, player.hp - damage)

        let line = "❌ " + lingo.localize("combat.flee.fail", locale: locale, interpolations: [
            "enemy": enemyName,
            "damage": "\(damage)"
        ])

        let enemyHP = state.combatEnemyHP ?? enemy.hp
        try await finishRound(context: context, state: state, enemy: enemy, enemyHP: enemyHP, lines: [line])
        return true
    }

    // MARK: - Round helpers

    /// Persist round results, check for player death, render the round screen.
    private func finishRound(context: Context, state: ExplorationState, enemy: Enemy, enemyHP: Int, lines: [String]) async throws {
        state.combatEnemyHP = enemyHP
        try await state.save(on: context.db)
        try await context.session.saveAndCache(in: context.db)

        if context.session.hp <= 0 {
            try await handleCombatDeath(context: context, enemy: enemy)
            return
        }

        let lingo = context.lingo
        let locale = context.session.locale
        let status = renderStatusCard(user: context.session, enemy: enemy, enemyHP: enemyHP, lingo: lingo, locale: locale)
        let text = (lines + [status]).joined(separator: "\n\n")
        let markup = combatInlineKeyboard(session: context.session, lingo: lingo)
        try await context.bot.sendMessage(session: context.session, text: text, parseMode: .html, replyMarkup: markup)
    }

    /// Award loot, send the victory message, clear combat fields, hand the
    /// player back to ExplorationController at the same km. The encounter
    /// has been "consumed" — the room's visit count is still recorded so
    /// re-entry uses the visit-decay tier. During registration the same
    /// flow is used but the row is deleted (no expedition follows) and we
    /// hand off to `Registration.handleCombatEnd`.
    private func finishVictory(context: Context, state: ExplorationState, enemy: Enemy, headerLines: [String]) async throws {
        let lingo = context.lingo
        let locale = context.session.locale
        let enemyName = "\(enemy.icon) " + lingo.localize(enemy.nameKey, locale: locale)

        let drops = try await ExplorationService.awardEncounterDrops(for: context.session, enemy: enemy, on: context.db)

        var parts = headerLines
        parts.append("🏆 " + lingo.localize("combat.victory", locale: locale, interpolations: [
            "enemy": enemyName
        ]))
        for drop in drops {
            let label = itemLabelWithIcon(drop.itemId, lingo: lingo, locale: locale)
            let key = drop.picked ? "exploration.outcome.loot.picked" : "exploration.outcome.loot.full"
            parts.append(lingo.localize(key, locale: locale, interpolations: [
                "item": label,
                "qty": "\(drop.quantity)"
            ]))
        }
        let prefix = parts.joined(separator: "\n")

        if context.session.registrationStep < 6 {
            // Registration tutorial fight — delete the row entirely (it's not
            // a real expedition), send the result, then bounce to estate naming.
            try await state.delete(on: context.db)
            try await context.session.saveAndCache(in: context.db)
            try await context.bot.sendMessage(session: context.session, text: prefix, parseMode: .html)
            try await Registration.handleCombatEnd(context: context, won: true)
            return
        }

        state.endCombat()
        try await state.save(on: context.db)
        try await context.session.saveAndCache(in: context.db)

        try await handBackToExploration(context: context, prefix: prefix)
    }

    /// Defeat handler — shares the inventory wipe + HP reset with
    /// ExplorationController.handleDeath. During registration the player
    /// instead gets a soft retry (full HP, re-show the wolves prompt) since
    /// dying mid-tutorial would otherwise leave them at HP=1 and unable to
    /// finish the fight.
    private func handleCombatDeath(context: Context, enemy: Enemy) async throws {
        if context.session.registrationStep < 6 {
            if let state = try await ExplorationState.current(for: context.session, on: context.db) {
                try await state.delete(on: context.db)
            }
            try await Registration.handleCombatEnd(context: context, won: false)
            return
        }

        let lingo = context.lingo
        let locale = context.session.locale
        let enemyName = "\(enemy.icon) " + lingo.localize(enemy.nameKey, locale: locale)
        let cause = "⚔️ " + lingo.localize("combat.defeat", locale: locale, interpolations: ["enemy": enemyName])
        try await ExplorationController.handleDeath(context: context, causeNarrative: cause)
    }

    /// After victory or successful flee: switch routerName back to
    /// ExplorationController and re-render the active expedition view so
    /// the player sees `[Step fwd] [Step back] / [Bag]` again.
    private func handBackToExploration(context: Context, prefix: String) async throws {
        let exploration = Controllers.explorationController
        context.session.routerName = exploration.routerName
        try await context.session.saveAndCache(in: context.db)

        // Send the combat result line first with the exploration keyboard
        // restored, then a status card so the player knows their km.
        let lingo = context.lingo
        let locale = context.session.locale
        guard let state = try await ExplorationState.current(for: context.session, on: context.db) else {
            // Expedition row evaporated — drop to main with just the prefix.
            try await Controllers.mainController.showMainMenu(context: context, text: prefix)
            return
        }

        let depthLabel = lingo.localize("exploration.depth_label", locale: locale)
        let starving = HungerService.isStarving(context.session)
            ? " · " + lingo.localize("hunger.starving", locale: locale)
            : ""
        let status = """
        🌲 <b>\(depthLabel): \(state.stepsDeep) km</b>
        ❤️ \(context.session.hp)/\(context.session.maxHp)  🍖 \(context.session.hunger)/\(context.session.maxHunger)\(starving)
        """
        let text = "\(prefix)\n\n\(status)"
        let markup = exploration.generateControllerKB(session: context.session, lingo: lingo)
        try await context.bot.sendMessage(session: context.session, text: text, parseMode: .html, replyMarkup: markup)
    }

    // MARK: - Loaders

    /// Look up the live combat state and resolve the enemy from the catalog.
    /// If the state is missing or stale (combat fields cleared, enemy id no
    /// longer in catalog) we bail back to the exploration entry view.
    private func loadCombat(context: Context) async throws -> (ExplorationState, Enemy)? {
        guard let state = try await ExplorationState.current(for: context.session, on: context.db),
              state.isInCombat,
              let enemyId = state.combatEnemyId,
              let enemy = EnemyCatalog.find(enemyId) else {
            context.session.routerName = Controllers.explorationController.routerName
            try await context.session.saveAndCache(in: context.db)
            try await Controllers.explorationController.showExploration(context: context)
            return nil
        }
        return (state, enemy)
    }

    // MARK: - Rendering

    private func renderStatusCard(user: User, enemy: Enemy, enemyHP: Int, lingo: Lingo, locale: String) -> String {
        let enemyName = "\(enemy.icon) " + lingo.localize(enemy.nameKey, locale: locale)
        let starving = HungerService.isStarving(user)
            ? " · " + lingo.localize("hunger.starving", locale: locale)
            : ""
        return """
        \(enemyName) — ❤️ \(enemyHP)/\(enemy.hp)
        ❤️ \(user.hp)/\(user.maxHp)  🍖 \(user.hunger)/\(user.maxHunger)\(starving)
        """
    }

    /// Convert a player AttackOutcome into a localized round line. The closure
    /// hands the caller the new enemy HP after damage so the caller can check
    /// for victory.
    private func renderPlayerHit(_ outcome: AttackOutcome, enemy: Enemy, lingo: Lingo, locale: String, enemyHPAfter: (Int) -> Int) -> String {
        let enemyName = "\(enemy.icon) " + lingo.localize(enemy.nameKey, locale: locale)
        switch outcome {
        case .miss:
            _ = enemyHPAfter(0)
            return "💨 " + lingo.localize("combat.you.miss", locale: locale, interpolations: ["enemy": enemyName])
        case .hit(let d):
            _ = enemyHPAfter(d)
            return "⚔️ " + lingo.localize("combat.you.hit", locale: locale, interpolations: [
                "enemy": enemyName,
                "damage": "\(d)"
            ])
        case .crit(let d):
            _ = enemyHPAfter(d)
            return "💥 " + lingo.localize("combat.you.crit", locale: locale, interpolations: [
                "enemy": enemyName,
                "damage": "\(d)"
            ])
        }
    }

    private func renderEnemyHit(_ outcome: AttackOutcome, enemy: Enemy, lingo: Lingo, locale: String) -> String {
        let enemyName = "\(enemy.icon) " + lingo.localize(enemy.nameKey, locale: locale)
        switch outcome {
        case .miss:
            return "💨 " + lingo.localize("combat.enemy.miss", locale: locale, interpolations: ["enemy": enemyName])
        case .hit(let d):
            return "🩸 " + lingo.localize("combat.enemy.hit", locale: locale, interpolations: [
                "enemy": enemyName,
                "damage": "\(d)"
            ])
        case .crit(let d):
            return "💥 " + lingo.localize("combat.enemy.crit", locale: locale, interpolations: [
                "enemy": enemyName,
                "damage": "\(d)"
            ])
        }
    }

    private func itemLabelWithIcon(_ itemId: String, lingo: Lingo, locale: String) -> String {
        guard let item = ItemCatalog.find(itemId) else { return itemId }
        let name = lingo.localize(item.nameKey, locale: locale)
        if let icon = item.icon {
            return "\(icon) \(name)"
        }
        return name
    }
}
