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
//    Player taps Attack / Defend / Flee → drain vigor for the action,
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
    private static let attackKeyPrefix     = "combat.button.attack."
    private static let defendKeyPrefix     = "combat.button.defend."
    private static let fleeKeyPrefix       = "combat.button.flee."
    private static let superKeyPrefix      = "combat.button.super."
    private static let specialAtkKeyPrefix = "combat.button.special_atk."
    private static let specialDefKeyPrefix = "combat.button.special_def."

    // MARK: - Class-flavoured emoji prefixes
    //
    // Lingo's `%{var}` parser breaks if the localised string LEADS with an
    // emoji (UTF-16 surrogate pair messes up its index walk), so we keep
    // every interpolated narrative emoji-free and prepend the icon here.

    private static func superEmoji(for cls: CharacterClass) -> String {
        switch cls {
        case .warrior: return "🩸"
        case .archer:  return "🦅"
        case .mage:    return "✨"
        }
    }

    private static func specialAtkHitEmoji(for cls: CharacterClass) -> String {
        switch cls {
        case .warrior: return "🪓"
        case .archer:  return "🎯"
        case .mage:    return "🔥"
        }
    }

    private static func specialDefEmoji(for cls: CharacterClass) -> String {
        switch cls {
        case .warrior: return "🏰"
        case .archer:  return "🌑"
        case .mage:    return "🪞"
        }
    }

    // MARK: - Lifecycle

    override public func attachHandlers(to bot: TGBot, lingo: Lingo) async {
        let router = Router(bot: bot) { router in
            router[Commands.start.command()] = onStart
            // Combat actions are reply-keyboard buttons that REPLACE the main
            // keyboard for the duration of the fight, so we match them by text
            // (per class × locale) just like exploration's [Step]/[Bag] buttons.
            for locale in SupportedLocale.allCases {
                let loc = locale.rawValue
                for cls in CharacterClass.allCases {
                    let c = cls.rawValue
                    router[lingo.localize(Self.attackKeyPrefix     + c, locale: loc)] = onAttack
                    router[lingo.localize(Self.defendKeyPrefix     + c, locale: loc)] = onDefend
                    router[lingo.localize(Self.fleeKeyPrefix       + c, locale: loc)] = onFlee
                    router[lingo.localize(Self.specialAtkKeyPrefix + c, locale: loc)] = onSpecialAttack
                    router[lingo.localize(Self.specialDefKeyPrefix + c, locale: loc)] = onSpecialDefense
                    router[lingo.localize(Self.superKeyPrefix      + c, locale: loc)] = onSuper
                }
                router[lingo.localize("combat.button.techniques",    locale: loc)] = onTechMenu
                router[lingo.localize("combat.tech.back",            locale: loc)] = onTechBack
                router[lingo.localize("combat.button.training_exit", locale: loc)] = onTrainingExit
            }
            // Legacy fallback: inline combat buttons lingering in chat history
            // from before the reply-keyboard switch still emit callbacks.
            router[.callback_query(data: nil)] = T.onCallbackQuery
            router.unmatched = unmatched
        }
        await processRouterForEachName(router)
    }

    /// /start force-ends the fight. During registration this drops the
    /// player back to the rabid-dog prompt (the registration-bound retry path);
    /// otherwise it exits to the main menu and clears the expedition row.
    public func onStart(context: Context) async throws -> Bool {
        if let state = try await ExplorationState.current(for: context.session, on: context.db) {
            try await state.delete(on: context.db)
        }
        if context.session.registrationStep < User.registrationDoneStep {
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
        // Free-form text (or any input that isn't a combat button / global
        // command) gets the in-combat notice — the combat reply keyboard is
        // already in place to drive the fight.
        try await sendInCombatNotice(context: context)
        return true
    }

    /// Combat owns a reply keyboard that replaces the main one for the fight.
    /// State isn't available here (sync, no db), so this returns the default
    /// (non-training) layout — used by `/buttons` and the configure.swift
    /// fallback. The actual round messages build the state-aware keyboard via
    /// `combatReplyKeyboard` so the training-mode Exit button shows correctly.
    override public func generateControllerKB(session: User, lingo: Lingo) -> TGReplyMarkup? {
        return combatReplyKeyboard(session: session, state: nil, lingo: lingo)
    }

    /// True if the active combat is a Training Ground session. Detected by
    /// the persisted enemy id; flipped on by EstateController when the
    /// player taps the training plot.
    static func isTraining(_ state: ExplorationState) -> Bool {
        return state.combatEnemyId == CombatService.trainingDummyEnemyId
    }

    /// Enemy DEF the player's swing should subtract. In training mode this
    /// is forced to 0 so the player sees their raw ATK damage with no
    /// reduction; outside training the regular Iron-Bulwark armor-split
    /// debuff still applies.
    static func playerSwingEnemyDEF(_ enemy: Enemy, state: ExplorationState) -> Int {
        if isTraining(state) { return 0 }
        return state.hasEnemyDefDebuff ? 0 : enemy.defense
    }

    /// Main combat reply keyboard: Attack / Defend on the top row, Techniques +
    /// Flee on the bottom. It REPLACES whatever reply keyboard was visible
    /// before combat (exploration's, or none during registration) and is
    /// restored to the prior controller's keyboard on victory / flee / death.
    /// Attack / Defend / Flee are class-flavoured; Techniques is a static
    /// label that opens a sub-keyboard. In training mode the Flee slot is
    /// replaced with an Exit button that leaves cleanly to the Plot list.
    private func combatReplyKeyboardMarkup(session: User, state: ExplorationState?, lingo: Lingo) -> TGReplyKeyboardMarkup {
        let cls = CharacterClass(rawValue: session.characterClass ?? "") ?? .warrior
        let locale = session.locale
        let attack = TGKeyboardButton(text: lingo.localize(Self.attackKeyPrefix + cls.rawValue, locale: locale))
        let defend = TGKeyboardButton(text: lingo.localize(Self.defendKeyPrefix + cls.rawValue, locale: locale))
        let tech   = TGKeyboardButton(text: lingo.localize("combat.button.techniques", locale: locale))
        let trailing: TGKeyboardButton
        if let state = state, Self.isTraining(state) {
            trailing = TGKeyboardButton(text: lingo.localize("combat.button.training_exit", locale: locale))
        } else {
            trailing = TGKeyboardButton(text: lingo.localize(Self.fleeKeyPrefix + cls.rawValue, locale: locale))
        }
        return TGReplyKeyboardMarkup(keyboard: [[attack, defend], [tech, trailing]], resizeKeyboard: true)
    }

    /// Wrapper for sendMessage callers that want a full TGReplyMarkup.
    /// State threaded through so the training-mode branch can swap Flee for
    /// an Exit button (see `combatReplyKeyboardMarkup`).
    private func combatReplyKeyboard(session: User, state: ExplorationState?, lingo: Lingo) -> TGReplyMarkup {
        return .replyKeyboardMarkup(combatReplyKeyboardMarkup(session: session, state: state, lingo: lingo))
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
        lines.append(renderStatusCard(user: context.session, enemy: enemy, enemyHP: enemyHP, state: state, lingo: lingo, locale: locale))
        let text = lines.joined(separator: "\n\n")

        let markup = combatReplyKeyboard(session: context.session, state: state, lingo: lingo)
        try await context.bot.sendMessage(session: context.session, text: text, parseMode: .html, replyMarkup: markup)
    }

    // MARK: - Callback dispatch

    /// Legacy fallback for inline combat buttons that linger in chat history
    /// from before the reply-keyboard switch. Combat is now driven by the
    /// reply keyboard, so we just dismiss the spinner and re-present the live
    /// fight (with the reply keyboard) — or route the player out if the fight
    /// already ended.
    static func onCallbackQuery(context: Context) async throws -> Bool {
        guard let query = context.update.callbackQuery else { return false }
        let ctrl = Controllers.combatController
        _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id))
        if let state = try await ExplorationState.current(for: context.session, on: context.db),
           state.isInCombat,
           let enemyId = state.combatEnemyId,
           let enemy = EnemyCatalog.find(enemyId) {
            // Could be forwarded from another controller's router (e.g. a
            // pre-switch training session still on routerName "estate") — make
            // sure the player is on the combat router so the reply keyboard's
            // buttons actually reach this controller.
            if context.session.routerName != ctrl.routerName {
                context.session.routerName = ctrl.routerName
                try await context.session.saveAndCache(in: context.db)
            }
            try await ctrl.showCombat(context: context, state: state, enemy: enemy, intro: false)
        } else {
            try await ctrl.sendInCombatNotice(context: context)
        }
        return true
    }

    /// Defensive toast for the case where a stale callback (from an older
    /// message whose submenu still showed a now-spent technique button)
    /// fires after the per-fight budget for that technique is exhausted.
    /// Live submenus rebuild from state so the buttons are hidden — this
    /// only catches stale-message taps.
    private func sendNoUsesLeftToast(context: Context) async throws {
        let text = "🚫 " + context.lingo.localize("combat.tech.no_uses_left", locale: context.session.locale)
        try await context.bot.sendMessage(session: context.session, text: text, parseMode: .html)
    }

    /// Phase 5.3e — if the player hasn't learned the given technique kind,
    /// send a notice pointing them at the Training Ground and return `true`
    /// so the caller bails out before executing. Returns `false` when the
    /// technique is learned (caller continues normally). Normally unreachable
    /// from the submenu (unlearned techniques are hidden), but guards against
    /// a free-typed label matching an unlearned technique.
    private func sendLockedToastIfUnlearned(kind: CombatService.TechniqueKind, context: Context) async throws -> Bool {
        if try await LearnedTechnique.has(kind.rawValue, for: context.session, on: context.db) {
            return false
        }
        let required = CombatService.requiredLevel(for: kind)
        // 🔒 prepended in Swift — leading supplementary-plane emoji breaks
        // Lingo's `%{var}` parser (see .memory/localization.md).
        let text = "🔒 " + context.lingo.localize("combat.tech.locked", locale: context.session.locale, interpolations: [
            "level": "\(required)"
        ])
        try await context.bot.sendMessage(session: context.session, text: text, parseMode: .html)
        return true
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
        let isTraining = Self.isTraining(state)

        let mods = CombatService.stanceModifiers(for: state.combatStance)
        // Training mode is consequence-free: no vigor drain, no enemy counter.
        if !isTraining {
            _ = VigorService.drain(context.session, action: .combatAttack, multiplier: mods.vigorMultiplier)
        }

        // Player strikes — stance modifiers folded into ATK / Crit / Acc.
        // Iron Bulwark's "armor split" debuff (if active) zeroes enemy DEF.
        // Training mode forces a clean hit (no miss, no DEF reduction) so
        // the player can read their raw damage off the dummy.
        let player = context.session
        let buffedATK = Int((Double(player.effectiveAttack) * mods.attackMultiplier).rounded()) + mods.attackBonus
        let effectiveEnemyDEF = Self.playerSwingEnemyDEF(enemy, state: state)
        var swingMods = CombatService.AttackModifiers()
        if isTraining { swingMods.cannotMiss = true }
        let playerHit = CombatService.applyAttack(
            attackerATK: buffedATK,
            attackerCrit: player.effectiveCrit + mods.critBonus,
            attackerAcc: player.effectiveAccuracy + mods.accuracyBonus,
            defenderDEF: effectiveEnemyDEF,
            defenderDodge: 0,
            modifiers: swingMods
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

        if isTraining {
            // Skip the enemy counter entirely — dummy never strikes back.
            try await finishRound(context: context, state: state, enemy: enemy, enemyHP: enemyHP, lines: [playerLine])
            return true
        }

        // Enemy counter — DEF / Dodge get the stance buffs, plus Shadow Veil
        // lingering dodge buff if active.
        let extraDodge = state.hasPlayerDodgeBuff ? CombatService.SpecialDefense.shadowVeilDodgeBonus : 0
        let enemyHit = CombatService.applyAttack(
            attackerATK: enemy.attack, attackerCrit: 0, attackerAcc: 0,
            defenderDEF: player.effectiveDefense + mods.defenseBonus,
            defenderDodge: player.effectiveDodge + mods.dodgeBonus + extraDodge
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
        let isTraining = Self.isTraining(state)

        let mods = CombatService.stanceModifiers(for: state.combatStance)
        if !isTraining {
            _ = VigorService.drain(context.session, action: .combatDefend, multiplier: mods.vigorMultiplier)
        }

        // Per-class basic Defend (2026-05-15):
        //   • Warrior — chip 30% × ATK + 2× DEF for the round (the canonical
        //     parry: tags the enemy with the shield, eats most of the swing).
        //   • Archer  — chip 15% × ATK (knife flick while melting into cover)
        //               + flat +30 dodge for the round; DEF stays single
        //               since the fantasy is evasion, not armor.
        //   • Mage    — no chip (barrier is purely passive); enemy attack
        //               rolls normally through single DEF + dodge, then the
        //               landed damage is multiplied by 0.4 (60% off) before
        //               being applied to HP.
        // Iron Bulwark's armor-split debuff (if active) is consumed by chip;
        // training mode forces enemy DEF to 0 for a clean chip number.
        let player = context.session
        let cls = CharacterClass(rawValue: player.characterClass ?? "") ?? .warrior
        let buffedATK = Int((Double(player.effectiveAttack) * mods.attackMultiplier).rounded()) + mods.attackBonus
        let effectiveEnemyDEF = Self.playerSwingEnemyDEF(enemy, state: state)

        let chip: Int
        switch cls {
        case .warrior:
            chip = CombatService.chipDamage(attackerATK: buffedATK, defenderDEF: effectiveEnemyDEF)
        case .archer:
            chip = CombatService.chipDamage(attackerATK: buffedATK, defenderDEF: effectiveEnemyDEF, extraMultiplier: CombatService.Defend.archerChipMultiplier)
        case .mage:
            chip = 0
        }
        let enemyHP = max(0, (state.combatEnemyHP ?? enemy.hp) - chip)
        let playerLine: String
        if chip > 0 {
            playerLine = "🛡 " + context.lingo.localize("combat.defend.absorbed", locale: context.session.locale, interpolations: [
                "enemy": "\(enemy.icon) " + context.lingo.localize(enemy.nameKey, locale: context.session.locale),
                "damage": "\(chip)"
            ])
        } else {
            // Mage barrier — no chip line, just the brace stance.
            playerLine = "🌀 " + context.lingo.localize("combat.defend.barrier", locale: context.session.locale)
        }

        if enemyHP <= 0 {
            try await finishVictory(context: context, state: state, enemy: enemy, headerLines: [playerLine])
            return true
        }

        if isTraining {
            try await finishRound(context: context, state: state, enemy: enemy, enemyHP: enemyHP, lines: [playerLine])
            return true
        }

        // Enemy strikes back. Per-class mitigation:
        //   • Warrior: defender DEF is doubled this round (existing behavior).
        //   • Archer:  defender DEF stays normal, but dodge gets +30.
        //   • Mage:    defender DEF + dodge stay normal; final landed damage
        //              is multiplied by `Defend.mageBarrierDamageFraction`
        //              after the applyAttack roll.
        let extraDodge = state.hasPlayerDodgeBuff ? CombatService.SpecialDefense.shadowVeilDodgeBonus : 0
        let defenderDEF: Int
        let extraDefendDodge: Int
        switch cls {
        case .warrior:
            defenderDEF = (player.effectiveDefense + mods.defenseBonus) * 2
            extraDefendDodge = 0
        case .archer:
            defenderDEF = player.effectiveDefense + mods.defenseBonus
            extraDefendDodge = CombatService.Defend.archerDodgeBonus
        case .mage:
            defenderDEF = player.effectiveDefense + mods.defenseBonus
            extraDefendDodge = 0
        }
        let enemyHit = CombatService.applyAttack(
            attackerATK: enemy.attack, attackerCrit: 0, attackerAcc: 0,
            defenderDEF: defenderDEF,
            defenderDodge: player.effectiveDodge + mods.dodgeBonus + extraDodge + extraDefendDodge
        )
        let mitigatedHit: AttackOutcome
        if cls == .mage {
            switch enemyHit {
            case .miss:
                mitigatedHit = .miss
            case .hit(let d):
                mitigatedHit = .hit(damage: max(1, Int((Double(d) * CombatService.Defend.mageBarrierDamageFraction).rounded())))
            case .crit(let d):
                mitigatedHit = .crit(damage: max(1, Int((Double(d) * CombatService.Defend.mageBarrierDamageFraction).rounded())))
            }
        } else {
            mitigatedHit = enemyHit
        }
        let enemyLine = renderEnemyHit(mitigatedHit, enemy: enemy, lingo: context.lingo, locale: context.session.locale)
        switch mitigatedHit {
        case .miss: break
        case .hit(let d), .crit(let d): player.hp = max(0, player.hp - d)
        }

        try await finishRound(context: context, state: state, enemy: enemy, enemyHP: enemyHP, lines: [playerLine, enemyLine])
        return true
    }

    private func onFlee(context: Context) async throws -> Bool {
        guard let (state, enemy) = try await loadCombat(context: context) else { return true }
        // Defensive — Flee button is replaced by Back in training mode, so
        // a stale callback is the only way this fires. Bail without effect.
        if Self.isTraining(state) {
            return true
        }

        let player = context.session
        let cls = CharacterClass(rawValue: player.characterClass ?? "") ?? .warrior
        let mods = CombatService.stanceModifiers(for: state.combatStance)
        _ = VigorService.drain(player, action: .combatFlee, multiplier: mods.vigorMultiplier)
        // Per-class extra vigor (mage teleport tax) layers on top, scaled by
        // the same stance multiplier so Arcane Resonance still pays the toll.
        let extra = CombatService.fleeVigorExtra(forClass: cls)
        if extra > 0 {
            VigorService.drain(player, amount: Int((Double(extra) * mods.vigorMultiplier).rounded()))
        }

        let lingo = context.lingo
        let locale = context.session.locale
        let enemyName = "\(enemy.icon) " + lingo.localize(enemy.nameKey, locale: locale)

        let success = Int.random(in: 1...100) <= CombatService.fleeChance(forClass: cls)
        if success {
            let line = "💨 " + lingo.localize("combat.flee.success", locale: locale, interpolations: [
                "enemy": enemyName
            ])

            if context.session.registrationStep < User.registrationDoneStep {
                // Registration: fleeing the rabid dog is a soft retry — same as
                // defeat. The state row is deleted by handleCombatEnd's caller
                // path (we wipe it here directly to keep the invariant clean).
                try await state.delete(on: context.db)
                try await player.saveAndCache(in: context.db)
                try await context.bot.sendMessage(session: context.session, text: line, parseMode: .html)
                try await Registration.handleCombatEnd(context: context, won: false)
                return true
            }

            // Phase 6.5: fleeing wears armor the hardest.
            try await GearConditionService.wear(.flee, for: player, on: context.db)

            // Step out of the encounter: clear combat fields, walk back one km.
            state.endCombat()
            state.stepsDeep = max(0, state.stepsDeep - 1)
            try await state.save(on: context.db)
            try await player.saveAndCache(in: context.db)

            try await handBackToExploration(context: context, prefix: line)
            return true
        }

        // Failed — enemy lands a forced full-damage hit "in the back" (no
        // dodge, no crit roll), combat continues. Stance DEF buff still
        // helps reduce the bite, but the player's own armor is halved —
        // turning to run means dropping your guard, so DEF only counts at
        // 50%. (Shadow Veil's lingering dodge can't save a failed flee —
        // the spec is "guaranteed hit".)
        let halvedDEF = player.effectiveDefense / 2
        let buffedDEF = halvedDEF + mods.defenseBonus
        let damage = max(1, Int((Double(max(1, enemy.attack - buffedDEF)) * Double.random(in: CombatService.varianceRange)).rounded()))
        player.hp = max(0, player.hp - damage)

        let line = "❌ " + lingo.localize("combat.flee.fail", locale: locale, interpolations: [
            "enemy": enemyName,
            "damage": "\(damage)"
        ])

        let enemyHP = state.combatEnemyHP ?? enemy.hp
        try await finishRound(context: context, state: state, enemy: enemy, enemyHP: enemyHP, lines: [line])
        return true
    }

    /// Open the Techniques sub-keyboard. Reply keyboards can't be edited in
    /// place, so this sends a fresh message carrying the technique buttons —
    /// only the ones the player can use RIGHT NOW (learned AND with uses left).
    /// Unlearned / spent techniques are hidden. Remaining uses are shown in the
    /// message body (the buttons stay static-labelled so text routing matches).
    /// When nothing is available, the main combat keyboard is re-sent with a
    /// short note instead of an empty submenu.
    private func onTechMenu(context: Context) async throws -> Bool {
        guard let state = try await ExplorationState.current(for: context.session, on: context.db),
              state.isInCombat else {
            try await sendInCombatNotice(context: context)
            return true
        }
        let learned = try await LearnedTechnique.allIds(for: context.session, on: context.db)
        let cls = CharacterClass(rawValue: context.session.characterClass ?? "") ?? .warrior
        let locale = context.session.locale
        let lingo = context.lingo

        var techRow: [TGKeyboardButton] = []
        var bodyLines: [String] = []
        if learned.contains(CombatService.TechniqueKind.specialAtk.rawValue), let uses = state.combatSpecialAtkUses, uses > 0 {
            let label = lingo.localize(Self.specialAtkKeyPrefix + cls.rawValue, locale: locale)
            techRow.append(TGKeyboardButton(text: label))
            bodyLines.append("\(label) × \(uses)")
        }
        if learned.contains(CombatService.TechniqueKind.specialDef.rawValue), let uses = state.combatSpecialDefUses, uses > 0 {
            let label = lingo.localize(Self.specialDefKeyPrefix + cls.rawValue, locale: locale)
            techRow.append(TGKeyboardButton(text: label))
            bodyLines.append("\(label) × \(uses)")
        }
        var superRow: [TGKeyboardButton] = []
        if learned.contains(CombatService.TechniqueKind.super.rawValue), let uses = state.combatSuperUses, uses > 0 {
            let label = lingo.localize(Self.superKeyPrefix + cls.rawValue, locale: locale)
            superRow.append(TGKeyboardButton(text: label))
            bodyLines.append("\(label) × \(uses)")
        }

        if techRow.isEmpty && superRow.isEmpty {
            // Nothing usable — keep the main keyboard, explain why.
            let text = lingo.localize("combat.tech.none_available", locale: locale)
            let markup = combatReplyKeyboard(session: context.session, state: state, lingo: lingo)
            try await context.bot.sendMessage(session: context.session, text: text, parseMode: .html, replyMarkup: markup)
            return true
        }

        var rows: [[TGKeyboardButton]] = []
        if !techRow.isEmpty { rows.append(techRow) }
        if !superRow.isEmpty { rows.append(superRow) }
        rows.append([TGKeyboardButton(text: lingo.localize("combat.tech.back", locale: locale))])
        let markup = TGReplyKeyboardMarkup(keyboard: rows, resizeKeyboard: true)

        let text = ([lingo.localize("combat.tech.prompt", locale: locale)] + bodyLines).joined(separator: "\n")
        try await context.bot.sendMessage(session: context.session, text: text, parseMode: .html, replyMarkup: .replyKeyboardMarkup(markup))
        return true
    }

    /// Close the Techniques sub-keyboard — re-send the combat status card with
    /// the main combat reply keyboard (state read live so the trailing button
    /// is Flee, or Exit in training mode).
    private func onTechBack(context: Context) async throws -> Bool {
        guard let (state, enemy) = try await loadCombat(context: context) else { return true }
        let lingo = context.lingo
        let locale = context.session.locale
        let status = renderStatusCard(user: context.session, enemy: enemy, enemyHP: state.combatEnemyHP ?? enemy.hp, state: state, lingo: lingo, locale: locale)
        let markup = combatReplyKeyboard(session: context.session, state: state, lingo: lingo)
        try await context.bot.sendMessage(session: context.session, text: status, parseMode: .html, replyMarkup: markup)
        return true
    }

    /// Phase 5.1: clean exit from a Training Ground session. Wipes the
    /// ExplorationState row that was holding the dummy fight, restores the
    /// estate routerName + main reply keyboard (combat replaced it while
    /// sparring), and re-renders the plot list so the Training Ground row is
    /// visible again. No HP / vigor / inventory changes — training is
    /// consequence-free.
    private func onTrainingExit(context: Context) async throws -> Bool {
        if let state = try await ExplorationState.current(for: context.session, on: context.db) {
            try await state.delete(on: context.db)
        }
        let estate = Controllers.estateController
        context.session.routerName = estate.routerName
        try await context.session.saveAndCache(in: context.db)

        let lingo = context.lingo
        let locale = context.session.locale
        let prefix = "🥋 " + lingo.localize("estate.plot.alert.training_exited", locale: locale)
        let plots = try await Plot.list(for: context.session, on: context.db)
        let body = estate.renderPlotList(plots: plots, session: context.session, lingo: lingo, locale: locale)
        let markup = estate.plotListKeyboard(plots: plots, session: context.session, lingo: lingo, locale: locale)
        try await context.bot.sendMessage(session: context.session, text: body, parseMode: .html, replyMarkup: .inlineKeyboardMarkup(markup))
        // The plot list carries inline markup, so the combat reply keyboard
        // would otherwise linger — restore the main keyboard on the banner.
        let mainKB = estate.generateControllerKB(session: context.session, lingo: lingo)
        await estate.postStatusBanner(prefix, context: context, replyMarkup: mainKB)
        return true
    }

    /// Phase 4.2.3 class Special Defense — Iron Bulwark (warrior) / Shadow
    /// Veil (archer) / Mirror Ward (mage). All three skip the regular enemy
    /// counter (full block / dodge / reflect). Iron Bulwark and Shadow Veil
    /// also apply a 1-round persistent effect that the next player action
    /// will consume (armor-split DEF debuff / lingering dodge buff).
    private func onSpecialDefense(context: Context) async throws -> Bool {
        guard let (state, enemy) = try await loadCombat(context: context) else { return true }
        if try await sendLockedToastIfUnlearned(kind: .specialDef, context: context) { return true }
        guard state.hasSpecialDefUse else {
            try await sendNoUsesLeftToast(context: context)
            return true
        }
        state.consumeSpecialDef()
        let isTraining = Self.isTraining(state)

        let player = context.session
        let cls = CharacterClass(rawValue: player.characterClass ?? "") ?? .warrior
        let stanceMods = CombatService.stanceModifiers(for: state.combatStance)

        // Vigor drain — base special-defense cost × stance vigor multiplier.
        // Skipped in training mode.
        if !isTraining {
            let baseVigor = CombatService.specialDefenseVigor(forClass: cls)
            let actualDrain = Int((Double(baseVigor) * stanceMods.vigorMultiplier).rounded())
            VigorService.drain(player, amount: actualDrain)
        }

        let lingo = context.lingo
        let locale = player.locale
        let enemyName = "\(enemy.icon) " + lingo.localize(enemy.nameKey, locale: locale)

        var enemyHP = state.combatEnemyHP ?? enemy.hp
        let activateLine: String

        switch cls {
        case .warrior:
            // Iron Bulwark: 100% block + heavier chip damage to enemy + apply
            // 1-round armor-split debuff for the follow-up swing. Training
            // mode zeroes the dummy's DEF for a clean chip-damage readout.
            let buffedATK = Int((Double(player.effectiveAttack) * stanceMods.attackMultiplier).rounded()) + stanceMods.attackBonus
            let bulwarkEnemyDEF = Self.playerSwingEnemyDEF(enemy, state: state)
            let chip = CombatService.chipDamage(attackerATK: buffedATK, defenderDEF: bulwarkEnemyDEF)
            // The basic chipDamage uses 30% of base — Iron Bulwark scales it
            // up to 50% (defendChipFraction = 0.3, ironBulwarkChipFraction = 0.5).
            let scaledChip = max(1, Int((Double(chip) * (CombatService.SpecialDefense.ironBulwarkChipFraction / CombatService.defendChipFraction)).rounded()))
            enemyHP = max(0, enemyHP - scaledChip)
            // Apply armor-split for the next swing (after the tick).
            state.applyEnemyDefDebuff(rounds: CombatService.SpecialDefense.effectPersistRounds + 1)
            activateLine = "\(Self.specialDefEmoji(for: cls)) " + lingo.localize("combat.special_def.warrior.activate", locale: locale, interpolations: [
                "enemy": enemyName,
                "damage": "\(scaledChip)"
            ])

        case .archer:
            // Shadow Veil: full dodge this round (no enemy counter), apply
            // lingering dodge buff for the next round.
            state.applyPlayerDodgeBuff(rounds: CombatService.SpecialDefense.effectPersistRounds + 1)
            activateLine = "\(Self.specialDefEmoji(for: cls)) " + lingo.localize("combat.special_def.archer.activate", gender: player.gender, locale: locale, interpolations: [
                "enemy": enemyName
            ])

        case .mage:
            // Mirror Ward: roll the would-be enemy hit, reflect a fraction
            // back at them. Player takes 0.
            let wouldBeHit = CombatService.applyAttack(
                attackerATK: enemy.attack, attackerCrit: 0, attackerAcc: 0,
                defenderDEF: player.effectiveDefense + stanceMods.defenseBonus,
                defenderDodge: 0
            )
            let raw: Int
            switch wouldBeHit {
            case .miss:               raw = 0
            case .hit(let d):         raw = d
            case .crit(let d):        raw = d
            }
            if raw > 0 {
                let reflected = max(1, Int((Double(raw) * CombatService.SpecialDefense.mirrorWardReflectFraction).rounded()))
                enemyHP = max(0, enemyHP - reflected)
                activateLine = "\(Self.specialDefEmoji(for: cls)) " + lingo.localize("combat.special_def.mage.activate", locale: locale, interpolations: [
                    "enemy": enemyName,
                    "damage": "\(reflected)"
                ])
            } else {
                activateLine = "\(Self.specialDefEmoji(for: cls)) " + lingo.localize("combat.special_def.mage.no_damage", locale: locale, interpolations: [
                    "enemy": enemyName
                ])
            }
        }

        if enemyHP <= 0 {
            try await finishVictory(context: context, state: state, enemy: enemy, headerLines: [activateLine])
            return true
        }

        // The "rounds" we set above is +1 to compensate for the immediate
        // tick in finishRound. After tick: warrior debuff = 1, archer buff = 1.
        // Next round consumes them; the round after that they're at 0.
        try await finishRound(context: context, state: state, enemy: enemy, enemyHP: enemyHP, lines: [activateLine])
        return true
    }

    /// Phase 4.2.2 class Special Attack — Cleave (warrior) / Vital Shot
    /// (archer) / Soulfire (mage). Resolves a full round (player swing +
    /// enemy counter), composing per-class `AttackModifiers` with the active
    /// stance's `StanceModifiers` so e.g. Bloodlust's +ATK still feeds
    /// Cleave's armor-piercing damage. Vital Shot zeroes the player's dodge
    /// for the counter — long aim leaves them open.
    private func onSpecialAttack(context: Context) async throws -> Bool {
        guard let (state, enemy) = try await loadCombat(context: context) else { return true }
        if try await sendLockedToastIfUnlearned(kind: .specialAtk, context: context) { return true }
        guard state.hasSpecialAtkUse else {
            try await sendNoUsesLeftToast(context: context)
            return true
        }
        state.consumeSpecialAtk()
        let isTraining = Self.isTraining(state)

        let player = context.session
        let cls = CharacterClass(rawValue: player.characterClass ?? "") ?? .warrior
        let stanceMods = CombatService.stanceModifiers(for: state.combatStance)

        // Vigor drain — base special-attack cost × stance vigor multiplier.
        // Skipped in training mode (consequence-free practice).
        if !isTraining {
            let baseVigor = CombatService.specialAttackVigor(forClass: cls)
            let actualDrain = Int((Double(baseVigor) * stanceMods.vigorMultiplier).rounded())
            VigorService.drain(player, amount: actualDrain)
        }

        // Player swing — stance buffs + special-attack modifiers compose.
        // Iron Bulwark's armor-split debuff (if active) zeroes enemy DEF here too.
        // Training mode also forces cannotMiss so even Cleave's −10 hit
        // penalty never produces a miss against the dummy.
        let buffedATK = Int((Double(player.effectiveAttack) * stanceMods.attackMultiplier).rounded()) + stanceMods.attackBonus
        let effectiveEnemyDEF = Self.playerSwingEnemyDEF(enemy, state: state)
        var swingMods = CombatService.specialAttackModifiers(forClass: cls)
        if isTraining {
            swingMods.cannotMiss = true
            swingMods.hitChanceModifier = 0  // override Cleave's penalty
        }
        let playerHit = CombatService.applyAttack(
            attackerATK: buffedATK,
            attackerCrit: player.effectiveCrit + stanceMods.critBonus,
            attackerAcc: player.effectiveAccuracy + stanceMods.accuracyBonus,
            defenderDEF: effectiveEnemyDEF,
            defenderDodge: 0,
            modifiers: swingMods
        )

        let lingo = context.lingo
        let locale = player.locale
        let enemyName = "\(enemy.icon) " + lingo.localize(enemy.nameKey, locale: locale)
        let keyPrefix = "combat.special_atk.\(cls.rawValue)"

        var enemyHP = state.combatEnemyHP ?? enemy.hp
        let playerLine: String
        switch playerHit {
        case .miss:
            playerLine = "💨 " + lingo.localize("\(keyPrefix).miss", locale: locale, interpolations: ["enemy": enemyName])
        case .hit(let d):
            enemyHP = max(0, enemyHP - d)
            playerLine = "\(Self.specialAtkHitEmoji(for: cls)) " + lingo.localize("\(keyPrefix).hit", locale: locale, interpolations: ["enemy": enemyName, "damage": "\(d)"])
        case .crit(let d):
            enemyHP = max(0, enemyHP - d)
            playerLine = "💥 " + lingo.localize("\(keyPrefix).crit", locale: locale, interpolations: ["enemy": enemyName, "damage": "\(d)"])
        }

        if enemyHP <= 0 {
            try await finishVictory(context: context, state: state, enemy: enemy, headerLines: [playerLine])
            return true
        }

        if isTraining {
            try await finishRound(context: context, state: state, enemy: enemy, enemyHP: enemyHP, lines: [playerLine])
            return true
        }

        // Enemy counter — Vital Shot's "long aim" zeroes player dodge.
        // Shadow Veil lingering buff still applies (even Vital Shot benefits
        // from it as a base; the long-aim penalty still wins to 0 if active).
        let extraDodge = state.hasPlayerDodgeBuff ? CombatService.SpecialDefense.shadowVeilDodgeBonus : 0
        let dodgeForCounter = CombatService.specialAttackZeroesDodge(forClass: cls)
            ? 0
            : (player.effectiveDodge + stanceMods.dodgeBonus + extraDodge)
        let enemyHit = CombatService.applyAttack(
            attackerATK: enemy.attack, attackerCrit: 0, attackerAcc: 0,
            defenderDEF: player.effectiveDefense + stanceMods.defenseBonus,
            defenderDodge: dodgeForCounter
        )
        let enemyLine = renderEnemyHit(enemyHit, enemy: enemy, lingo: lingo, locale: locale)
        switch enemyHit {
        case .miss: break
        case .hit(let d), .crit(let d): player.hp = max(0, player.hp - d)
        }

        try await finishRound(context: context, state: state, enemy: enemy, enemyHP: enemyHP, lines: [playerLine, enemyLine])
        return true
    }

    /// Phase 4.2 Super-technique activation. Drains the activation vigor,
    /// stamps the stance fields on the expedition row, and re-renders the
    /// combat screen with the activate narrative + buff status. The enemy
    /// does NOT strike on activation — Super is a free action by design.
    /// Tapping Super while a stance is already active is a no-op + toast.
    private func onSuper(context: Context) async throws -> Bool {
        guard let (state, enemy) = try await loadCombat(context: context) else { return true }
        if try await sendLockedToastIfUnlearned(kind: .super, context: context) { return true }
        guard state.hasSuperUse else {
            try await sendNoUsesLeftToast(context: context)
            return true
        }
        let lingo = context.lingo
        let locale = context.session.locale

        if state.hasActiveStance {
            let text = "🌀 " + lingo.localize("combat.super.already_active", locale: locale)
            try await context.bot.sendMessage(session: context.session, text: text, parseMode: .html)
            return true
        }

        state.consumeSuper()

        let player = context.session
        let cls = CharacterClass(rawValue: player.characterClass ?? "") ?? .warrior
        let stanceId = CombatService.stanceId(forClass: cls)
        // Activation vigor skipped in training mode (consequence-free practice).
        if !Self.isTraining(state) {
            VigorService.drain(player, amount: CombatService.stanceActivationVigor(for: stanceId))
        }
        state.beginStance(stanceId, rounds: CombatService.stanceDurationRounds)
        try await state.save(on: context.db)
        try await player.saveAndCache(in: context.db)

        let activate = "\(Self.superEmoji(for: cls)) " + lingo.localize("combat.super.\(cls.rawValue).activate", locale: locale, interpolations: [
            "rounds": "\(CombatService.stanceDurationRounds)"
        ])
        let status = renderStatusCard(user: player, enemy: enemy, enemyHP: state.combatEnemyHP ?? enemy.hp, state: state, lingo: lingo, locale: locale)
        let text = "\(activate)\n\n\(status)"
        let markup = combatReplyKeyboard(session: player, state: state, lingo: lingo)
        try await context.bot.sendMessage(session: context.session, text: text, parseMode: .html, replyMarkup: markup)
        return true
    }

    // MARK: - Round helpers

    /// Persist round results, tick the active stance + defense effects (if
    /// any), check for player death, render the round screen. Stance ticks
    /// happen AFTER the round resolves with the buff still active — so a
    /// 3-round stance powers exactly 3 actions, with the expire narrative
    /// emitted on the 3rd round's tick. Defense effects (Iron Bulwark armor
    /// split, Shadow Veil dodge) tick the same way: the action that
    /// triggered them is the activation round; the next action consumes
    /// them; the action after that finds them gone.
    private func finishRound(context: Context, state: ExplorationState, enemy: Enemy, enemyHP: Int, lines: [String]) async throws {
        state.combatEnemyHP = enemyHP
        // Bump the per-fight round counter BEFORE rendering so the very
        // first action ends up showing "Раунд 1" in the status card. Reads
        // defensively from nil for pre-AddCombatRound fights mid-flight.
        state.combatRound = (state.combatRound ?? 0) + 1

        var allLines = lines
        let cls = CharacterClass(rawValue: context.session.characterClass ?? "") ?? .warrior
        if state.tickStance() {
            allLines.append("\(Self.superEmoji(for: cls)) " + context.lingo.localize("combat.super.\(cls.rawValue).expire", locale: context.session.locale))
        }
        state.tickDefenseEffects()

        try await state.save(on: context.db)
        try await context.session.saveAndCache(in: context.db)

        if context.session.hp <= 0 {
            try await handleCombatDeath(context: context, enemy: enemy)
            return
        }

        let lingo = context.lingo
        let locale = context.session.locale
        let status = renderStatusCard(user: context.session, enemy: enemy, enemyHP: enemyHP, state: state, lingo: lingo, locale: locale)
        let text = (allLines + [status]).joined(separator: "\n\n")
        let markup = combatReplyKeyboard(session: context.session, state: state, lingo: lingo)
        try await context.bot.sendMessage(session: context.session, text: text, parseMode: .html, replyMarkup: markup)
    }

    /// Award loot, send the victory message, clear combat fields, hand the
    /// player back to ExplorationController at the same km. The encounter
    /// has been "consumed" — the room's visit count is still recorded so
    /// re-entry uses the visit-decay tier. During registration the same
    /// flow is used but the row is deleted (no expedition follows) and we
    /// hand off to `Registration.handleCombatEnd`. In training mode the
    /// dummy auto-revives instead — see `reviveTrainingDummy`.
    private func finishVictory(context: Context, state: ExplorationState, enemy: Enemy, headerLines: [String]) async throws {
        if Self.isTraining(state) {
            try await reviveTrainingDummy(context: context, state: state, enemy: enemy, headerLines: headerLines)
            return
        }
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

        if context.session.registrationStep < User.registrationDoneStep {
            // Registration tutorial fight (rabid dog) — delete the row entirely
            // (it's not a real expedition), send the result, then bounce to
            // estate naming. No XP grant: the tutorial fight is narrative-only.
            try await state.delete(on: context.db)
            try await context.session.saveAndCache(in: context.db)
            try await context.bot.sendMessage(session: context.session, text: prefix, parseMode: .html)
            try await Registration.handleCombatEnd(context: context, won: true)
            return
        }

        // Phase 6.5: equipped armor takes a small durability hit on a win.
        try await GearConditionService.wear(.victory, for: context.session, on: context.db)

        // Phase 5.3a: grant XP from the kill, append level-up + estate-up
        // banners to the victory message. Training dummies have xpReward = 0
        // so they're naturally a no-op (and never reach this branch anyway —
        // training bails at the top of finishVictory).
        let xpResult = context.session.grantXP(enemy.xpReward)
        var withXP = parts
        if xpResult.xpAwarded > 0 {
            withXP.append("📊 " + lingo.localize("combat.victory.xp", locale: locale, interpolations: [
                "xp": "\(xpResult.xpAwarded)"
            ]))
        }
        if xpResult.levelsGained > 0 {
            var line = "🎉 " + lingo.localize("level_up.banner", locale: locale, interpolations: [
                "level": "\(xpResult.newLevel)"
            ])
            if xpResult.maxHpGained > 0 {
                // 💪 prepended in Swift — same Lingo emoji-leading-template bug.
                line += " 💪 " + lingo.localize("level_up.stat_boost", locale: locale, interpolations: [
                    "hp": "\(xpResult.maxHpGained)",
                    "atk": "\(xpResult.attackGained)",
                    "def": "\(xpResult.defenseGained)"
                ])
            }
            withXP.append(line)
        }
        if xpResult.estateLeveledUp {
            withXP.append("🏰 " + lingo.localize("estate_up.banner", locale: locale, interpolations: [
                "tier": "\(xpResult.newEstateLevel)"
            ]))
        }
        let finalPrefix = withXP.joined(separator: "\n")

        state.endCombat()
        try await state.save(on: context.db)
        try await context.session.saveAndCache(in: context.db)

        try await handBackToExploration(context: context, prefix: finalPrefix)
    }

    /// Training Ground branch of `finishVictory`. Resets the dummy's HP to
    /// full and re-renders the combat screen with a "dummy restored" notice
    /// — the player keeps training without any "victory" UX (no loot, no
    /// hand-off back to exploration). Per-fight technique budget is NOT
    /// reset here; the player has to tap Back and re-enter to refresh it.
    private func reviveTrainingDummy(context: Context, state: ExplorationState, enemy: Enemy, headerLines: [String]) async throws {
        state.combatEnemyHP = enemy.hp
        try await state.save(on: context.db)
        try await context.session.saveAndCache(in: context.db)

        let lingo = context.lingo
        let locale = context.session.locale
        let enemyName = "\(enemy.icon) " + lingo.localize(enemy.nameKey, locale: locale)
        var lines = headerLines
        lines.append("🥋 " + lingo.localize("combat.training.dummy_revived", locale: locale, interpolations: [
            "enemy": enemyName
        ]))
        lines.append(renderStatusCard(user: context.session, enemy: enemy, enemyHP: enemy.hp, state: state, lingo: lingo, locale: locale))
        let text = lines.joined(separator: "\n\n")
        let markup = combatReplyKeyboard(session: context.session, state: state, lingo: lingo)
        try await context.bot.sendMessage(session: context.session, text: text, parseMode: .html, replyMarkup: markup)
    }

    /// Defeat handler — shares the inventory wipe + HP reset with
    /// ExplorationController.handleDeath. During registration the player
    /// instead gets a soft retry (full HP, re-show the rabid-dog prompt) since
    /// dying mid-tutorial would otherwise leave them at HP=1 and unable to
    /// finish the fight.
    private func handleCombatDeath(context: Context, enemy: Enemy) async throws {
        if context.session.registrationStep < User.registrationDoneStep {
            if let state = try await ExplorationState.current(for: context.session, on: context.db) {
                try await state.delete(on: context.db)
            }
            try await Registration.handleCombatEnd(context: context, won: false)
            return
        }

        // Phase 6.5: a defeat wears equipped armor (more than a win, less than
        // a flee). Equipped gear survives the death wipe, only its durability drops.
        try await GearConditionService.wear(.defeat, for: context.session, on: context.db)

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
        let starving = VigorService.isStarving(context.session)
            ? " · " + lingo.localize("vigor.starving", locale: locale)
            : ""
        let status = """
        🌲 <b>\(depthLabel): \(state.stepsDeep) km</b>
        ❤️ \(context.session.hp)/\(context.session.maxHp)  🍖 \(context.session.vigor)/\(context.session.maxVigor)\(starving)
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
            // Stale: combat already ended but the router still points here.
            // Tell the player and recover a usable keyboard by routing back to
            // the exploration entry.
            let text = context.lingo.localize("combat.ended", gender: context.session.gender, locale: context.session.locale)
            try await context.bot.sendMessage(session: context.session, text: text, parseMode: .html)
            context.session.routerName = Controllers.explorationController.routerName
            try await context.session.saveAndCache(in: context.db)
            try await Controllers.explorationController.showExploration(context: context)
            return nil
        }
        return (state, enemy)
    }

    // MARK: - Rendering

    private func renderStatusCard(user: User, enemy: Enemy, enemyHP: Int, state: ExplorationState, lingo: Lingo, locale: String) -> String {
        let enemyName = "\(enemy.icon) " + lingo.localize(enemy.nameKey, locale: locale)
        let starving = VigorService.isStarving(user)
            ? " · " + lingo.localize("vigor.starving", locale: locale)
            : ""
        var lines: [String] = []
        // Round counter is shown once the player has taken at least one
        // action — the encounter intro screen (round 0) stays clean. 🌀
        // prepended here in Swift since Lingo's `%{var}` parser breaks on a
        // leading supplementary-plane emoji in the template.
        if let round = state.combatRound, round > 0 {
            lines.append("🌀 " + lingo.localize("combat.round", locale: locale, interpolations: ["n": "\(round)"]))
        }
        lines.append(contentsOf: [
            "\(enemyName) — ❤️ \(enemyHP)/\(enemy.hp)",
            "❤️ \(user.hp)/\(user.maxHp)  🍖 \(user.vigor)/\(user.maxVigor)\(starving)"
        ])
        if let rounds = state.combatStanceRoundsLeft, state.combatStance != nil, rounds > 0 {
            let cls = CharacterClass(rawValue: user.characterClass ?? "") ?? .warrior
            let label = lingo.localize(Self.superKeyPrefix + cls.rawValue, locale: locale)
            lines.append("\(label) — \(rounds)")
        }
        if let rounds = state.combatEnemyDefDebuff, rounds > 0 {
            lines.append("🛡 " + lingo.localize("combat.effect.armor_split", locale: locale, interpolations: ["rounds": "\(rounds)"]))
        }
        if let rounds = state.combatPlayerDodgeBuff, rounds > 0 {
            lines.append("🌑 " + lingo.localize("combat.effect.shadow_veil", locale: locale, interpolations: ["rounds": "\(rounds)"]))
        }
        return lines.joined(separator: "\n")
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
