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

/// Façade over the live content snapshot. Estate tiers now live in
/// `content/data/estate_upgrades.json`.
public enum EstateUpgradeCatalog {
    public static var maxTier: Int { Catalogs.current.estateMaxTier }
    public static var progression: [EstateUpgradeStep] { Catalogs.current.estateProgression }

    /// Indexes by position, so the snapshot keeps `progression` sorted by
    /// `toTier` and the validator rejects a non-contiguous ladder.
    public static func nextStep(from currentTier: Int) -> EstateUpgradeStep? {
        let nextTier = currentTier + 1
        guard nextTier >= 2, nextTier <= maxTier else { return nil }
        let steps = progression
        let index = nextTier - 2
        guard index >= 0, index < steps.count else { return nil }
        return steps[index]
    }

    public static func canUpgrade(from currentTier: Int) -> Bool {
        return currentTier < maxTier
    }
}
