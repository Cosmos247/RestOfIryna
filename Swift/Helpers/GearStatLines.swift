//
//  GearStatLines.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 04.10.2026.
//
//  The stat lines of a weapon rung, and the "+N → +M" preview of the next one.
//  They lived inside `EstateController` while the workshop was the only place
//  a weapon was reforged. Since 2026-10-04 the Master's lesson sells the first
//  rung too (`spec-items.md` §9.4), so both screens call this rather than each
//  writing its own version of the same sentence. Since 2026-10-06 the armour
//  climbs by the Master's enchant (§11), and its card and banner say it here
//  as well.
//

import Foundation
import Lingo

enum GearStatLines {

    /// Render only the non-zero stat fields of a `GearStats` value as
    /// "+N <icon> <name>" lines. Used for the current-tier block on the
    /// upgrade detail screen.
    ///
    /// All SIX fields, in `GearStats` order. HP was missing until 2026-09-11,
    /// which made the doc comment above a lie by one field. It cannot fire
    /// today — no weapon rung carries HP, and weapons are the only thing with a
    /// ladder — but the planned gear ladder puts the Forester set on these
    /// rungs, and the Forester set is exactly the four items that DO carry HP.
    static func lines(stats: GearStats, lingo: Lingo, locale: String, prefix: String) -> [String] {
        var out: [String] = []
        if stats.attack != 0   { out.append("\(prefix)+\(stats.attack) ⚔️ \(lingo.localize("workshop.stats.attack", locale: locale))") }
        if stats.defense != 0  { out.append("\(prefix)+\(stats.defense) 🛡 \(lingo.localize("workshop.stats.defense", locale: locale))") }
        if stats.hp != 0       { out.append("\(prefix)+\(stats.hp) ❤️ \(lingo.localize("profile.health", locale: locale))") }
        if stats.crit != 0     { out.append("\(prefix)+\(stats.crit) 💥 \(lingo.localize("workshop.stats.crit", locale: locale))") }
        if stats.dodge != 0    { out.append("\(prefix)+\(stats.dodge) 💨 \(lingo.localize("workshop.stats.dodge", locale: locale))") }
        if stats.accuracy != 0 { out.append("\(prefix)+\(stats.accuracy) 🎯 \(lingo.localize("workshop.stats.accuracy", locale: locale))") }
        return out
    }

    /// Render stat deltas from `from` to `to` as "+N → +M (↑+K) <icon> <name>"
    /// lines. Used for the next-tier preview on the upgrade detail screen and
    /// on the Master's lesson card — one reforge, one way of showing it.
    static func deltas(from: GearStats, to: GearStats, lingo: Lingo, locale: String, prefix: String) -> [String] {
        func line(_ a: Int, _ b: Int, _ unit: String, _ iconLabel: String) -> String? {
            guard a != 0 || b != 0 else { return nil }
            let delta = b - a
            let deltaPart = delta == 0 ? "" : (delta > 0 ? "  (↑+\(delta))" : "  (↓\(delta))")
            return "\(prefix)+\(a)\(unit) → +\(b)\(unit)\(deltaPart) \(iconLabel)"
        }
        var out: [String] = []
        if let l = line(from.attack,   to.attack,   "",  "⚔️ \(lingo.localize("workshop.stats.attack",   locale: locale))") { out.append(l) }
        if let l = line(from.defense,  to.defense,  "",  "🛡 \(lingo.localize("workshop.stats.defense",  locale: locale))") { out.append(l) }
        if let l = line(from.hp,       to.hp,       "",  "❤️ \(lingo.localize("profile.health",          locale: locale))") { out.append(l) }
        if let l = line(from.crit,     to.crit,     "",  "💥 \(lingo.localize("workshop.stats.crit",     locale: locale))") { out.append(l) }
        if let l = line(from.dodge,    to.dodge,    "",  "💨 \(lingo.localize("workshop.stats.dodge",    locale: locale))") { out.append(l) }
        if let l = line(from.accuracy, to.accuracy, "",  "🎯 \(lingo.localize("workshop.stats.accuracy", locale: locale))") { out.append(l) }
        return out
    }

    /// What a step ADDED, on one line: `+3 🛡 Захист · +4 ❤️ Здоров'я`. Only
    /// the stats that moved, in `GearStats` order, each in `lines`' own
    /// "+N <icon> <name>" shape — the banner under an enchant names what the
    /// silver bought instead of a percentage the player has to multiply.
    static func gains(from: GearStats, to: GearStats, lingo: Lingo, locale: String) -> String {
        let delta = GearStats(attack: to.attack - from.attack, defense: to.defense - from.defense,
                              hp: to.hp - from.hp, crit: to.crit - from.crit,
                              dodge: to.dodge - from.dodge, accuracy: to.accuracy - from.accuracy)
        return lines(stats: delta, lingo: lingo, locale: locale, prefix: "").joined(separator: " · ")
    }
}
