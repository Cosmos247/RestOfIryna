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

/// Façade over the live content snapshot. Ladders now live in
/// `content/data/weapon_upgrades.json`.
public enum WeaponUpgradeCatalog {
    public static var progression: [String: [WeaponUpgradeStep]] { Catalogs.current.weaponLadders }

    public static func step(for itemId: String, tier: Int) -> WeaponUpgradeStep? {
        guard let steps = progression[itemId], tier >= 1, tier <= steps.count else { return nil }
        return steps[tier - 1]
    }

    public static func stats(for itemId: String, tier: Int) -> GearStats? {
        return step(for: itemId, tier: tier)?.stats
    }

    public static func maxTier(for itemId: String) -> Int? {
        return progression[itemId]?.count
    }

    public static var durabilityByTier: [Int] { Catalogs.current.weaponDurabilityByTier }

    public static func durability(forTier tier: Int) -> Int {
        let table = durabilityByTier
        let idx = max(1, min(tier, table.count)) - 1
        return table[idx]
    }

    public static func isUpgradable(_ itemId: String) -> Bool {
        return progression[itemId] != nil
    }
}
