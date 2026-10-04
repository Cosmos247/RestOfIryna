//
//  WeaponUpgradeCatalog.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 06.05.2026.
//
//  Phase 5.2.2: per-weapon tier progression. The three class starter weapons
//  cannot be replaced — only upgraded — so each one carries its own ladder of
//  (stats, materials) rungs: nine since 2026-10-04. The player's current tier
//  lives on the `InventoryEntry.tier` column; everything else (display name,
//  gear bonuses, upgrade cost) is derived from this catalog.
//
//  The PLAYER level gates progression since 2026-10-04 (`spec-items.md` §9):
//  each rung carries the level it opens at, one every five levels. The estate
//  used to open tier N at T N, which put the item-level-40 sword in hand at
//  level 13. The first reforge is the Master's lesson in the capital; every
//  later one is the workshop's (`WeaponUpgradeService`).
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
    /// Item level this rung is budgeted at. Carried into the domain rather than
    /// left as validator-only input so the value is visible to anything that
    /// prices or describes the weapon — and so the migration digest can see it
    /// at all, which a DTO-only field cannot be.
    public let itemLevel: Int
    /// The player level this rung opens at — tier 1 always at 1.
    public let requiredPlayerLevel: Int
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

    /// The player level `tier` of `itemId` opens at, or nil past the ladder.
    public static func requiredLevel(for itemId: String, tier: Int) -> Int? {
        step(for: itemId, tier: tier)?.requiredPlayerLevel
    }

    /// The highest tier of `itemId` a player of `level` may hold — what the
    /// workshop sells up to and what the 2026-10-04 clamp walked the testers'
    /// weapons back to. One rule, `WeaponLadderRules.highestTier`.
    public static func highestTier(for itemId: String, atLevel level: Int) -> Int {
        let gates = (progression[itemId] ?? []).map(\.requiredPlayerLevel)
        return WeaponLadderRules.highestTier(gates: gates, atLevel: level)
    }
}
