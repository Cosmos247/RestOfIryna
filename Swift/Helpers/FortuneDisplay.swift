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
//  the number to forget. (The card's authored `buff_desc` is prose and stays
//  prose: it belongs to the reveal, where the flavour is the point.)
//
//  Both surfaces that name an active card call this, so the fortune screen
//  and the profile cannot describe the same card differently.
//

import Foundation
import Lingo

enum FortuneDisplay {

    /// Every stat an active card moves, as `⚔️ Attack: +10 · 🎁 Loot: −15%`.
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
        multiplier(effect.xpMultiplier,         "📊", "profile.xp")
        multiplier(effect.lootChanceMultiplier, "🎁", "fortune.effect.loot")
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

    /// What the last draw's one-shot half actually handed over, as
    /// `received: 🪙 +30 · 📊 +75 XP`, read off the record `FortuneService.draw`
    /// stamped on the user.
    ///
    /// Not derived from the card: the Wheel rolls 50/50 and every silver loss
    /// is clamped to what the player holds, so the card says what COULD have
    /// happened and only the stamped record says what did. A row with nothing
    /// recorded — drawn before the record existed, or a loss clamped to zero —
    /// falls back to the plain note, which is still true.
    static func oneShotLine(for user: User, lingo: Lingo, locale: String) -> String {
        var parts: [String] = []

        if user.lastFortuneSilverDelta != 0 {
            parts.append("🪙 \(signed(user.lastFortuneSilverDelta))")
        }
        if user.lastFortuneXpGain > 0 {
            // The reveal's own phrasing ("+75 XP" / "+75 досвіду"), so the two
            // screens name the same gift the same way.
            parts.append("📊 " + lingo.localize("capital.fortune.applied.xp_gain", locale: locale, interpolations: [
                "xp": "\(user.lastFortuneXpGain)"
            ]))
        }
        if user.lastFortuneHpRestored {
            parts.append("❤️ " + lingo.localize("fortune.effect.hp_full", locale: locale))
        }
        if user.lastFortuneVigorRestored {
            parts.append("🍖 " + lingo.localize("fortune.effect.vigor_full", locale: locale))
        }

        guard parts.isEmpty == false else {
            return lingo.localize("fortune.effect.one_shot_done", locale: locale)
        }
        return lingo.localize("fortune.effect.received", locale: locale) + ": " + parts.joined(separator: " · ")
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
