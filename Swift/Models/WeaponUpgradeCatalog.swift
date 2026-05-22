//
//  WeaponUpgradeCatalog.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 06.05.2026.
//
//  Phase 5.2.2: per-weapon tier progression. The three class starter weapons
//  cannot be replaced — only upgraded — so each one carries its own
//  5-tier ladder of (stats, materials) pairs. The player's current tier
//  lives on the `InventoryEntry.tier` column; everything else (display
//  name, gear bonuses, upgrade cost) is derived from this catalog.
//
//  Estate level gates progression: tier N needs estate level >= N. The
//  derivation `User.estateLevel` (every 3 player levels = +1 tier — Phase
//  5.3a) paces the upgrade ladder against natural play time.
//
//  T1 stats are intentionally identical to the pre-existing
//  `Item.gearStats` for each weapon, so existing players see no numeric
//  change until they spend materials at the Workshop.
//

import Foundation

// MARK: - Step model

public struct WeaponUpgradeInput: Sendable {
    public let itemId: String
    public let quantity: Int

    public init(_ itemId: String, _ quantity: Int) {
        self.itemId = itemId
        self.quantity = quantity
    }
}

public struct WeaponUpgradeStep: Sendable {
    /// Effective gear stats applied while the weapon is at this tier.
    public let stats: GearStats
    /// Materials consumed from the combined inventory + warehouse pool to
    /// REACH this tier (i.e. the cost of upgrading from tier-1 to this tier).
    /// Empty for T1 — that's the starter weapon, granted by the King.
    public let inputs: [WeaponUpgradeInput]
}

// MARK: - Catalog

public enum WeaponUpgradeCatalog {

    /// Tier-indexed progression for every upgradable weapon. Index = tier − 1
    /// (so `progression[id][0]` is T1, `[4]` is T5).
    public static let progression: [String: [WeaponUpgradeStep]] = [

        // ⚔️ Warrior — Rusty Sword → Knight's Sword.
        // Crit kicks in at T2 and accelerates each tier (3 / 6 / 10 / 15).
        // Defense joins at T4 — a master-tempered blade also parries cleaner.
        "gear.rusty_sword": [
            WeaponUpgradeStep(
                stats: GearStats(attack: 3),
                inputs: []
            ),
            WeaponUpgradeStep(
                stats: GearStats(attack: 5, crit: 3),
                inputs: [WeaponUpgradeInput("mat.river_pebble", 3)]
            ),
            WeaponUpgradeStep(
                stats: GearStats(attack: 8, crit: 6),
                inputs: [
                    WeaponUpgradeInput("mat.river_pebble", 5),
                    WeaponUpgradeInput("mat.iron", 2)
                ]
            ),
            WeaponUpgradeStep(
                stats: GearStats(attack: 12, defense: 1, crit: 10),
                inputs: [
                    WeaponUpgradeInput("mat.iron_ingot", 1),
                    WeaponUpgradeInput("mat.iron", 5),
                    WeaponUpgradeInput("mat.pine_lumber", 3)
                ]
            ),
            WeaponUpgradeStep(
                stats: GearStats(attack: 16, defense: 3, crit: 15),
                inputs: [
                    WeaponUpgradeInput("mat.iron_ingot", 3),
                    WeaponUpgradeInput("mat.iron", 10),
                    WeaponUpgradeInput("mat.pine_lumber", 5)
                ]
            )
        ],

        // 🏹 Archer — Simple Bow → Hunter's Longbow.
        // Accuracy + crit ramp; ATK keeps pace. Hide stands in for sinew.
        "gear.simple_bow": [
            WeaponUpgradeStep(
                stats: GearStats(attack: 2, accuracy: 1),
                inputs: []
            ),
            WeaponUpgradeStep(
                stats: GearStats(attack: 4, accuracy: 3),
                inputs: [
                    WeaponUpgradeInput("mat.pine_lumber", 5),
                    WeaponUpgradeInput("mat.hide", 1)
                ]
            ),
            WeaponUpgradeStep(
                stats: GearStats(attack: 6, crit: 3, accuracy: 5),
                inputs: [
                    WeaponUpgradeInput("mat.pine_lumber", 5),
                    WeaponUpgradeInput("mat.hide", 3)
                ]
            ),
            WeaponUpgradeStep(
                stats: GearStats(attack: 9, crit: 6, accuracy: 7),
                inputs: [
                    WeaponUpgradeInput("mat.pine_lumber", 10),
                    WeaponUpgradeInput("mat.hide", 5),
                    WeaponUpgradeInput("mat.iron_ingot", 1)
                ]
            ),
            WeaponUpgradeStep(
                stats: GearStats(attack: 12, crit: 10, accuracy: 10),
                inputs: [
                    WeaponUpgradeInput("mat.pine_lumber", 15),
                    WeaponUpgradeInput("mat.hide", 8),
                    WeaponUpgradeInput("mat.iron_ingot", 3)
                ]
            )
        ],

        // 🪄 Mage — Wooden Staff → Archmage's Scepter.
        // Crit + ATK climb together; accuracy joins at T3 as the crystal
        // tightens spell aim.
        "gear.wooden_staff": [
            WeaponUpgradeStep(
                stats: GearStats(attack: 2, crit: 1),
                inputs: []
            ),
            WeaponUpgradeStep(
                stats: GearStats(attack: 4, crit: 3),
                inputs: [
                    WeaponUpgradeInput("mat.pine_lumber", 5),
                    WeaponUpgradeInput("mat.river_pebble", 3)
                ]
            ),
            WeaponUpgradeStep(
                stats: GearStats(attack: 6, crit: 6, accuracy: 2),
                inputs: [
                    WeaponUpgradeInput("mat.pine_lumber", 5),
                    WeaponUpgradeInput("mat.river_pebble", 5),
                    WeaponUpgradeInput("mat.clay", 3)
                ]
            ),
            WeaponUpgradeStep(
                stats: GearStats(attack: 9, crit: 10, accuracy: 4),
                inputs: [
                    WeaponUpgradeInput("mat.pine_lumber", 5),
                    WeaponUpgradeInput("mat.river_pebble", 8),
                    WeaponUpgradeInput("mat.iron_ingot", 1)
                ]
            ),
            WeaponUpgradeStep(
                stats: GearStats(attack: 12, crit: 14, accuracy: 6),
                inputs: [
                    WeaponUpgradeInput("mat.pine_lumber", 8),
                    WeaponUpgradeInput("mat.river_pebble", 10),
                    WeaponUpgradeInput("mat.iron_ingot", 3),
                    WeaponUpgradeInput("mat.hide", 5)
                ]
            )
        ]
    ]

    // MARK: - Queries

    /// Step at the given tier for the given weapon, or nil if the weapon
    /// is not in the catalog or the tier is out of range.
    public static func step(for itemId: String, tier: Int) -> WeaponUpgradeStep? {
        guard let steps = progression[itemId], tier >= 1, tier <= steps.count else { return nil }
        return steps[tier - 1]
    }

    /// Stats currently applied for the given weapon at the given tier.
    /// Falls back to nil for non-tiered items so the caller can use the
    /// original `Item.gearStats`.
    public static func stats(for itemId: String, tier: Int) -> GearStats? {
        return step(for: itemId, tier: tier)?.stats
    }

    /// Highest tier defined for this weapon, or nil if the weapon is not
    /// upgradable.
    public static func maxTier(for itemId: String) -> Int? {
        return progression[itemId]?.count
    }

    /// Durability a weapon of the given tier starts (and is repaired back) to.
    /// Climbs with tier — a higher-tier weapon endures far longer. Unlike armor,
    /// weapon repair never shaves this max (lore: the King's weapon can't break),
    /// and a weapon worn to 0 keeps half its stats rather than going dead.
    public static let durabilityByTier = [30, 40, 50, 70, 100]
    public static func durability(forTier tier: Int) -> Int {
        let idx = max(1, min(tier, durabilityByTier.count)) - 1
        return durabilityByTier[idx]
    }

    /// True if this item participates in the tier-upgrade ladder.
    public static func isUpgradable(_ itemId: String) -> Bool {
        return progression[itemId] != nil
    }
}
