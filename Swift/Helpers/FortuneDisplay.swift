//
//  FortuneDisplay.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 09.09.2026.
//
//  What the drawn tarot card is doing to the player, in one line.
//
//  The line is GENERATED from the card's own `FortuneEffect` — the same
//  struct `effectiveAttack`, `grantXP`, `ExplorationService.rollStep` and
//  `VigorService.drain` read — rather than written out beside it. Retune a
//  card in `fortune.json` and the line follows; there is no second copy of
//  the number to forget.
//
//  All three surfaces that name a card call this — the reveal, the fortune
//  screen and the profile — so a card cannot read one way on one screen and
//  another on the next. Until 2026-10-04 the reveal printed a hand-typed
//  `buff_desc` per card instead: the same numbers in a second phrasing
//  («×1.5» there, «+50%» here) that no retune could reach.
//

import Foundation
import Lingo

enum FortuneDisplay {

    /// Every stat an active card moves, as `⚔️ Attack: +10 · 💰 Loot: −15%`.
    ///
    /// A pure one-shot (Lovers, Wheel, Tower, Judgement, World) moves none of
    /// them and gets the "already received" note instead. The draw stamps an
    /// expiry for those cards too — so both screens showed a ticking
    /// countdown for an effect `User.activeFortuneEffect` had already stopped
    /// returning, which is the one thing this line must not repeat.
    ///
    /// Icons and labels are the profile's own, so a stat is named the same
    /// wherever the player meets it.
    static func effectLine(for effect: FortuneEffect, lingo: Lingo, locale: String) -> String {
        var parts: [String] = []

        func stat(_ value: Int, _ icon: String, _ key: String) {
            guard value != 0 else { return }
            parts.append("\(icon) \(lingo.localize(key, locale: locale)): \(signed(value))")
        }
        stat(effect.attackBonus,   "⚔️", "profile.attack")
        stat(effect.defenseBonus,  "🛡",  "profile.defense")
        stat(effect.critBonus,     "💥", "profile.crit")
        stat(effect.dodgeBonus,    "💨", "profile.dodge")
        stat(effect.accuracyBonus, "🎯", "profile.accuracy")

        func multiplier(_ value: Double, _ icon: String, _ key: String) {
            guard value != 1.0 else { return }
            parts.append("\(icon) \(lingo.localize(key, locale: locale)): \(signedPercent(value))")
        }
        multiplier(effect.xpMultiplier,         "📖", "profile.xp")
        // 💰, the game's one mark for what a player gets — the journal's
        // rewards, the King's, the claim button (2026-10-04).
        multiplier(effect.lootChanceMultiplier, "💰", "fortune.effect.loot")
        // Vigor's own glyph: the number is a change to how fast the pool
        // drains, so "🍖 Vigor drain: −50%" reads as the good news it is.
        multiplier(effect.vigorDrainMultiplier, "🍖", "fortune.effect.vigor_drain")

        // Empty is exactly `hasDurationEffect == false` — the two are the same
        // question asked of the same fields.
        guard parts.isEmpty == false else {
            return lingo.localize("fortune.effect.one_shot_done", locale: locale)
        }
        return parts.joined(separator: " · ")
    }

    /// The Wheel's two outcomes, `50/50: +🪙 30 or −🪙 15`, read off the card —
    /// nil for every card that is not a wheel. The test is
    /// `FortuneService.draw`'s own, so the line appears exactly when the draw
    /// rolls.
    static func wheelLine(for effect: FortuneEffect, lingo: Lingo, locale: String) -> String? {
        guard effect.randomSilverPositive > 0 || effect.randomSilverNegative > 0 else { return nil }
        return lingo.localize("fortune.effect.wheel", locale: locale, interpolations: [
            "win": silver(effect.randomSilverPositive),
            "loss": silver(-effect.randomSilverNegative)
        ])
    }

    /// What a draw's one-shot half handed over, as
    /// `[+🪙 30, 📖 +75 XP, ❤️ full health]` — empty when nothing landed.
    ///
    /// Built from the RECEIPT, never from the card: the Wheel rolls 50/50 and
    /// every silver loss is clamped to what the player holds, so the card says
    /// what COULD have happened and only the receipt says what did. The reveal
    /// passes the receipt `FortuneService.draw` returned; the later screens
    /// pass the copy it stamped on the user (`oneShotLine`).
    static func oneShotParts(_ applied: FortuneService.OneShotApplied, lingo: Lingo, locale: String) -> [String] {
        var parts: [String] = []

        if applied.silverDelta != 0 {
            parts.append(silver(applied.silverDelta))
        }
        if applied.xpGained > 0 {
            parts.append("📖 " + lingo.localize("capital.fortune.applied.xp_gain", locale: locale, interpolations: [
                "xp": "\(applied.xpGained)"
            ]))
        }
        if applied.hpRestored {
            parts.append("❤️ " + lingo.localize("fortune.effect.hp_full", locale: locale))
        }
        if applied.vigorRestored {
            parts.append("🍖 " + lingo.localize("fortune.effect.vigor_full", locale: locale))
        }
        return parts
    }

    /// The last draw's one-shot half as `received: +🪙 30 · 📖 +75 XP`, read
    /// off the record `FortuneService.draw` stamped on the user. A row with
    /// nothing recorded — drawn before the record existed, or a loss clamped
    /// to zero — falls back to the plain note, which is still true.
    static func oneShotLine(for user: User, lingo: Lingo, locale: String) -> String {
        let receipt = FortuneService.OneShotApplied(
            silverDelta: user.lastFortuneSilverDelta,
            xpGained: user.lastFortuneXpGain,
            hpRestored: user.lastFortuneHpRestored,
            vigorRestored: user.lastFortuneVigorRestored
        )
        let parts = oneShotParts(receipt, lingo: lingo, locale: locale)
        guard parts.isEmpty == false else {
            return lingo.localize("fortune.effect.one_shot_done", locale: locale)
        }
        return lingo.localize("fortune.effect.received", locale: locale) + ": " + parts.joined(separator: " · ")
    }

    /// `+🪙 30` / `−🪙 15` — the sign BEFORE the coin, the way the tavern
    /// prints its wins and losses and the reveal always printed the draw.
    /// This file used to print `🪙 +30`, so one card read two ways.
    static func silver(_ delta: Int) -> String {
        return delta > 0 ? "+🪙 \(delta)" : "−🪙 \(abs(delta))"
    }

    /// `+5` / `−5`, with the typographic minus the rest of the copy uses.
    private static func signed(_ value: Int) -> String {
        return value > 0 ? "+\(value)" : "−\(abs(value))"
    }

    /// A multiplier as the percentage it moves: 1.25 → `+25%`, 0.85 → `−15%`.
    private static func signedPercent(_ value: Double) -> String {
        let delta = Int(((value - 1.0) * 100).rounded())
        return delta > 0 ? "+\(delta)%" : "−\(abs(delta))%"
    }
}
