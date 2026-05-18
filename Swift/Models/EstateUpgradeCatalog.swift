//
//  EstateUpgradeCatalog.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 11.05.2026.
//
//  Phase 5.3c: estate-tier progression. Six tier transitions (T1→T2 …
//  T6→T7), each gated by a player-level requirement and a list of materials
//  drained from the combined inventory + warehouse pool. The pool comes
//  out of `CraftingService` policy: inventory first, warehouse second.
//
//  Mirrors the `WeaponUpgradeCatalog` pattern — pure data, no DB writes.
//  Materials scale with tier so late-game upgrades demand the player has
//  been actively gathering through deeper expeditions.
//
//  Player-level gates align with the natural XP curve from Phase 5.3a:
//    T2 needs L4, T3 L7, T4 L10, T5 L13, T6 L16, T7 L19. The player can't
//  upgrade past their player level — keeps estate progression paced
//  against combat / exploration progression.
//

import Foundation

// MARK: - Step model

public struct EstateUpgradeInput: Sendable {
    public let itemId: String
    public let quantity: Int

    public init(_ itemId: String, _ quantity: Int) {
        self.itemId = itemId
        self.quantity = quantity
    }
}

public struct EstateUpgradeStep: Sendable {
    /// Tier the player REACHES by spending these inputs.
    public let toTier: Int
    /// Player level required to attempt this upgrade.
    public let requiredPlayerLevel: Int
    /// Materials drained from the combined inventory + warehouse pool.
    public let inputs: [EstateUpgradeInput]
    /// Silvers drained directly from `User.silver` (NOT an inventory item —
    /// silver lives on the User row, not in a backpack slot). Zero for the
    /// early transitions; T3+ start gating with real money. Source of silvers
    /// is quest rewards (Phase 6 Capital); no mob drops.
    public let silverCost: Int

    public init(toTier: Int, requiredPlayerLevel: Int, inputs: [EstateUpgradeInput], silverCost: Int = 0) {
        self.toTier = toTier
        self.requiredPlayerLevel = requiredPlayerLevel
        self.inputs = inputs
        self.silverCost = silverCost
    }
}

// MARK: - Catalog

public enum EstateUpgradeCatalog {

    /// Hard cap on estate tier — matches the seven-tier unlock map.
    public static let maxTier: Int = 7

    /// Tier-indexed progression. Index = tier of the step's TARGET minus 2,
    /// since tier 1 is the starting state (no upgrade needed). T1→T2 lives
    /// at `progression[0]`, T6→T7 at `progression[5]`.
    public static let progression: [EstateUpgradeStep] = [

        // T1 → T2 (Хата поселенця): basic carpentry — lumber + stone for the
        // expanded walls, a few hides for the door curtain. The first
        // upgrade is intentionally cheap so the player gets a quick taste
        // of the system around L4.
        EstateUpgradeStep(
            toTier: 2,
            requiredPlayerLevel: 4,
            inputs: [
                EstateUpgradeInput("mat.pine_lumber", 20),
                EstateUpgradeInput("mat.river_pebble", 10),
                EstateUpgradeInput("mat.hide", 3)
            ]
        ),

        // T2 → T3 (Лісниче житло): iron joins for hinges + tools. The
        // Workshop unlocks here, so iron starts to matter.
        EstateUpgradeStep(
            toTier: 3,
            requiredPlayerLevel: 7,
            inputs: [
                EstateUpgradeInput("mat.pine_lumber", 40),
                EstateUpgradeInput("mat.river_pebble", 20),
                EstateUpgradeInput("mat.iron", 8),
                EstateUpgradeInput("mat.hide", 5)
            ]
        ),

        // T3 → T4 (Маєток): real masonry — clay for proper plastered walls,
        // first ingots for the front gates. Tannery unlocks at this tier.
        // First tier with a silver sink — proper masonry costs hired labour.
        EstateUpgradeStep(
            toTier: 4,
            requiredPlayerLevel: 10,
            inputs: [
                EstateUpgradeInput("mat.pine_lumber", 60),
                EstateUpgradeInput("mat.river_pebble", 40),
                EstateUpgradeInput("mat.iron", 15),
                EstateUpgradeInput("mat.iron_ingot", 3),
                EstateUpgradeInput("mat.clay", 10)
            ],
            silverCost: 50
        ),

        // T4 → T5 (Лицарський маєток): a defensive tower — heavy stone +
        // ingots dominate; hide for the great hall's tapestries.
        EstateUpgradeStep(
            toTier: 5,
            requiredPlayerLevel: 13,
            inputs: [
                EstateUpgradeInput("mat.pine_lumber", 80),
                EstateUpgradeInput("mat.river_pebble", 60),
                EstateUpgradeInput("mat.iron", 20),
                EstateUpgradeInput("mat.iron_ingot", 8),
                EstateUpgradeInput("mat.hide", 10),
                EstateUpgradeInput("mat.clay", 15)
            ],
            silverCost: 150
        ),

        // T5 → T6 (Баронський маєток): grand expansion — every material
        // doubles down. By this point the player is deep in the rabid family.
        EstateUpgradeStep(
            toTier: 6,
            requiredPlayerLevel: 16,
            inputs: [
                EstateUpgradeInput("mat.pine_lumber", 100),
                EstateUpgradeInput("mat.river_pebble", 80),
                EstateUpgradeInput("mat.iron", 25),
                EstateUpgradeInput("mat.iron_ingot", 12),
                EstateUpgradeInput("mat.hide", 15),
                EstateUpgradeInput("mat.clay", 20)
            ],
            silverCost: 400
        ),

        // T6 → T7 (Володіння лорда): endgame — the player should have a deep
        // material pool from late-game expeditions. Last upgrade is the
        // largest by a clear margin to mark the tier as a milestone.
        EstateUpgradeStep(
            toTier: 7,
            requiredPlayerLevel: 19,
            inputs: [
                EstateUpgradeInput("mat.pine_lumber", 120),
                EstateUpgradeInput("mat.river_pebble", 100),
                EstateUpgradeInput("mat.iron", 30),
                EstateUpgradeInput("mat.iron_ingot", 18),
                EstateUpgradeInput("mat.hide", 20),
                EstateUpgradeInput("mat.clay", 25)
            ],
            silverCost: 1000
        )
    ]

    // MARK: - Queries

    /// Step that takes the player FROM `currentTier` to `currentTier + 1`,
    /// or nil if `currentTier` is already at `maxTier`.
    public static func nextStep(from currentTier: Int) -> EstateUpgradeStep? {
        let nextTier = currentTier + 1
        guard nextTier >= 2, nextTier <= maxTier else { return nil }
        return progression[nextTier - 2]
    }

    /// True if the player has not yet reached the highest tier.
    public static func canUpgrade(from currentTier: Int) -> Bool {
        return currentTier < maxTier
    }
}
