//
//  BagCatalog.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 11.05.2026.
//
//  Phase 5.3d: backpack tier progression. 6 tiers from a 25-slot linen sack
//  to an 85-slot grandmaster's pack. Player's current bag tier lives on
//  `User.bagTier`; the cap is read through `BagCatalog.capForTier(_)` and
//  drives `InventoryEntry.slotCap(for:)`. As of 2026-05-12 inventory uses
//  per-unit slot accounting (each item unit is one slot), so these capacities
//  represent total carried units, not stack rows.
//
//  Mirrors the `WeaponUpgradeCatalog` pattern — pure data, no DB writes. The
//  upgrade itself is performed by `BagUpgradeService` from the Workshop.
//  Each step also carries an estate-tier gate so progression stays paced
//  against the estate ladder (T2 bag needs Workshop access, i.e. estate T3).
//

import Foundation

// MARK: - Step model

public struct BagUpgradeInput: Sendable {
    public let itemId: String
    public let quantity: Int

    public init(_ itemId: String, _ quantity: Int) {
        self.itemId = itemId
        self.quantity = quantity
    }
}

public struct BagUpgradeStep: Sendable {
    /// Tier the player REACHES by spending these inputs. T1 has no step
    /// (it's the starter sack — no upgrade needed to reach it).
    public let toTier: Int
    /// Slot cap at this tier — the value `User.bagTier` ultimately resolves
    /// to via `BagCatalog.capForTier(_)`.
    public let capacity: Int
    /// Estate tier required to attempt this bag upgrade. T2 needs estate T3
    /// (Workshop must be unlocked anyway); later tiers gate at T4/T5/T6.
    public let requiredEstateLevel: Int
    /// Materials drained from the combined inventory + warehouse pool.
    public let inputs: [BagUpgradeInput]

    public init(toTier: Int, capacity: Int, requiredEstateLevel: Int, inputs: [BagUpgradeInput]) {
        self.toTier = toTier
        self.capacity = capacity
        self.requiredEstateLevel = requiredEstateLevel
        self.inputs = inputs
    }
}

// MARK: - Catalog

/// Façade over the live content snapshot. Bag tiers now live in
/// `content/data/bags.json`.
public enum BagCatalog {
    public static var maxTier: Int { Catalogs.current.bagMaxTier }
    public static var capacities: [Int] { Catalogs.current.bagCapacities }

    public static func capForTier(_ tier: Int) -> Int {
        let table = capacities
        let idx = max(0, tier - 1)
        return table[min(idx, table.count - 1)]
    }

    public static var progression: [BagUpgradeStep] { Catalogs.current.bagProgression }

    /// Indexes by position, so the snapshot keeps `progression` sorted by
    /// `toTier` and the validator rejects a non-contiguous ladder.
    public static func nextStep(from currentTier: Int) -> BagUpgradeStep? {
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
