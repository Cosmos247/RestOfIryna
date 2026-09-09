//
//  ItemCard.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 09.09.2026.
//
//  The "what am I actually buying" card the capital's four shops show between
//  the listing row and the purchase question — Trader, Master, Tavern and the
//  player Market.
//
//  Only the top half lives here: name, lore, and what the item grants. The
//  price line belongs to the shop, because each one prices differently (a
//  trader packet, a Master's flat price, a dish, another player's lot), and
//  folding four price shapes into one helper would make it a switch over its
//  own callers.
//
//  What an item grants is READ, never restated: a consumable's numbers come
//  from its own `effects`, a piece of gear's from the ladder rung or its
//  `gearStats`, so a rebalanced item changes this card by itself. Stat labels
//  and icons are the profile's, so a stat is named the same wherever the
//  player meets it.
//

import Foundation
import Lingo

enum ItemCard {

    /// Name + lore + grants, ready for a shop to append its own price line.
    /// `tier` matters only for the three upgradable weapons, whose name, lore
    /// and stats all move with the rung.
    static func body(item: Item, tier: Int = 1, lingo: Lingo, locale: String) -> String {
        var lines: [String] = []

        let icon = item.icon.map { "\($0) " } ?? ""
        let name = lingo.localize(ItemDisplay.nameKey(for: item, tier: tier), locale: locale)
        lines.append("\(icon)<b>\(ItemDisplay.rarityPrefix(for: item))\(name)</b>")

        if let descKey = ItemDisplay.descriptionKey(for: item, tier: tier) {
            lines.append("")
            lines.append("<i>\(lingo.localize(descKey, locale: locale))</i>")
        }

        if let grants = grantsLine(item: item, tier: tier, lingo: lingo, locale: locale) {
            lines.append("")
            lines.append(grants)
        }
        return lines.joined(separator: "\n")
    }

    /// `Grants: 🍖 +5 vigor` for a consumable, `Grants: ⚔️ Attack: +7 · …` for
    /// gear, nil for a raw material — which has no effect of its own and would
    /// otherwise get an empty label promising something.
    private static func grantsLine(item: Item, tier: Int, lingo: Lingo, locale: String) -> String? {
        var parts: [String] = []

        for effect in item.effects {
            switch effect {
            case .restoreVigor(let amount):
                parts.append("🍖 " + lingo.localize("item.card.vigor_gain", locale: locale, interpolations: [
                    "amount": "\(amount)"
                ]))
            case .restoreHP(let amount):
                parts.append("❤️ " + lingo.localize("item.card.hp_gain", locale: locale, interpolations: [
                    "amount": "\(amount)"
                ]))
            }
        }

        // Gear: the rung's stats for a laddered weapon, the item's own for
        // everything else — the same order `EquipmentService.nominalStats`
        // resolves them in, minus the enchant, which belongs to a row a shop
        // copy does not have yet.
        if let stats = WeaponUpgradeCatalog.stats(for: item.id, tier: tier) ?? item.gearStats {
            func stat(_ value: Int, _ icon: String, _ key: String) {
                guard value != 0 else { return }
                parts.append("\(icon) \(lingo.localize(key, locale: locale)): +\(value)")
            }
            stat(stats.attack,   "⚔️", "profile.attack")
            stat(stats.defense,  "🛡",  "profile.defense")
            stat(stats.hp,       "❤️", "profile.health")
            stat(stats.crit,     "💥", "profile.crit")
            stat(stats.dodge,    "💨", "profile.dodge")
            stat(stats.accuracy, "🎯", "profile.accuracy")
        }

        guard parts.isEmpty == false else { return nil }
        return lingo.localize("item.card.grants", locale: locale) + ": " + parts.joined(separator: " · ")
    }

    /// The slot a piece of gear occupies, as its own line — a shop lists four
    /// armour pieces that differ mainly by where they go.
    static func slotLine(item: Item, lingo: Lingo, locale: String) -> String? {
        guard let slot = item.slot else { return nil }
        return "🎽 " + lingo.localize("profile.equipped.\(slot.rawValue)", locale: locale)
    }
}
