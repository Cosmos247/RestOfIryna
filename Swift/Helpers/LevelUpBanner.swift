//
//  LevelUpBanner.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 07.09.2026.
//
//  The level-up message. It is its own bubble rather than a line appended to
//  whatever granted the XP: a kill, a quest payout and an expedition report
//  all end in a wall of text, and the one event the player was playing for
//  was the easiest line in it to miss.
//
//  It prints the whole stat line, not the three stats the old one-liner
//  showed. `User.applyLevelDerivedStats` recomputes all seven from the class
//  curve, and one of the four it used to hide is the Vigor ceiling — which
//  since Phase 8E is one of only three ways Vigor enters the game at all.
//
//  Labels are the profile screen's own keys, so the banner and the profile
//  can never disagree about what a stat is called. Values are read live off
//  the user (already post-level-up) while the deltas come from the grant, so
//  the numbers here are exactly the ones the profile will show next.
//

import Foundation
@preconcurrency import Lingo

public enum LevelUpBanner {

    /// Render the banner. `user` must already carry the post-level-up stats;
    /// `growth` is what the grant moved.
    public static func text(
        for user: User,
        newLevel: Int,
        growth: User.StatGrowth,
        lingo: Lingo,
        locale: String
    ) -> String {
        // 🎉 prepended in Swift — a leading supplementary-plane emoji breaks
        // Lingo's `%{var}` parser (see .memory/localization.md).
        var lines = ["🎉 " + lingo.localize("level_up.banner", locale: locale, interpolations: [
            "level": "\(newLevel)"
        ]), ""]

        func gain(_ delta: Int) -> String { delta > 0 ? " (+\(delta))" : "" }
        func label(_ key: String) -> String { lingo.localize(key, locale: locale) }

        lines.append("❤️ \(label("profile.health")): \(user.hp)/\(user.effectiveMaxHp)\(gain(growth.maxHp))")
        lines.append("🍖 \(label("profile.vigor")): \(user.vigor)/\(user.maxVigor)\(gain(growth.maxVigor))")
        lines.append("⚔️ \(label("profile.attack")): \(user.effectiveAttack)\(gain(growth.attack))")
        lines.append("🛡 \(label("profile.defense")): \(user.effectiveDefense)\(gain(growth.defense))")
        lines.append("🎯 \(label("profile.accuracy")): \(user.effectiveAccuracy)\(gain(growth.accuracy))")
        lines.append("💨 \(label("profile.dodge")): \(user.effectiveDodge)\(gain(growth.dodge))")
        // Ratings here, NOT the percentages the character sheet shows — and the
        // `%` this line used to carry was simply false, since `effectiveCrit` is
        // a rating. The two screens answer different questions on purpose: this
        // one reports what the level GRANTED, which is always a gain, while the
        // sheet reports what the ratings are currently worth. Converting this
        // line would be worse than inconsistent, it would be wrong-feeling: the
        // rating grows in rounded proportional steps while the curve's
        // denominator grows every level, so **26% of level-ups would announce a
        // DROP** (up to −0.48 points; a warrior's crit falls at nearly every
        // early level). A celebration screen must not report a loss.
        lines.append("💥 \(label("profile.crit")): \(user.effectiveCrit)\(gain(growth.crit))")

        return lines.joined(separator: "\n")
    }
}
