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

public enum BagCatalog {

    /// Hard cap on bag tier.
    public static let maxTier: Int = 6

    /// Slot capacity by tier. Index = tier - 1. T1 starts at 25 slots
    /// (deliberate downgrade from the legacy flat 50 so the bag actually
    /// pressures choice in the early game, but +5 over the original 20
    /// once per-unit accounting landed). T6 is the post-endgame craft
    /// added 2026-05-12 — symbolic +5 capstone over the master tier.
    public static let capacities: [Int] = [25, 35, 45, 60, 80, 85]

    /// Returns the slot cap for the given tier. Tiers outside the table
    /// clamp to the nearest endpoint so the function stays total even if a
    /// future migration adds a row at tier 6.
    public static func capForTier(_ tier: Int) -> Int {
        let idx = max(0, tier - 1)
        return capacities[min(idx, capacities.count - 1)]
    }

    /// Tier-indexed progression. Index = tier of the step's TARGET minus 2,
    /// since T1 is the starting state (no upgrade needed). T1→T2 lives at
    /// `progression[0]`, T4→T5 at `progression[3]`.
    public static let progression: [BagUpgradeStep] = [

        // T1 → T2 (Шкіряна торба): basic leatherwork — first real upgrade
        // unlocks alongside the Workshop itself at estate T3.
        BagUpgradeStep(
            toTier: 2,
            capacity: 35,
            requiredEstateLevel: 3,
            inputs: [
                BagUpgradeInput("mat.hide", 5),
                BagUpgradeInput("mat.iron", 2)
            ]
        ),

        // T2 → T3 (Підшитий рюкзак): reinforced with iron buckles and
        // tighter stitching. Tannery is also live at this tier (estate T4),
        // which fits the "leather guild's workshop" feel.
        BagUpgradeStep(
            toTier: 3,
            capacity: 45,
            requiredEstateLevel: 4,
            inputs: [
                BagUpgradeInput("mat.hide", 10),
                BagUpgradeInput("mat.iron_ingot", 3)
            ]
        ),

        // T3 → T4 (Мисливський наплічник): the hunter's pack — deeper main
        // compartment, dedicated side pouches. Needs the knight's-manor
        // workshop floor (estate T5) to lay out the cuts.
        BagUpgradeStep(
            toTier: 4,
            capacity: 60,
            requiredEstateLevel: 5,
            inputs: [
                BagUpgradeInput("mat.hide", 15),
                BagUpgradeInput("mat.iron_ingot", 5)
            ]
        ),

        // T4 → T5 (Майстерський заплічник): the baron's craft. Reflects the
        // endgame estate where the workshop is at its largest; T6 is the
        // grand-master capstone added later.
        BagUpgradeStep(
            toTier: 5,
            capacity: 80,
            requiredEstateLevel: 6,
            inputs: [
                BagUpgradeInput("mat.hide", 20),
                BagUpgradeInput("mat.iron_ingot", 8)
            ]
        ),

        // T5 → T6 (Грандмайстерський сак): the final +5 capstone (2026-05-12).
        // Requires the lord's-holdings workshop at estate T7 — the ceiling.
        // Materials scale to match the prestige of being the only player in
        // Artania carrying the grand-master pack.
        BagUpgradeStep(
            toTier: 6,
            capacity: 85,
            requiredEstateLevel: 7,
            inputs: [
                BagUpgradeInput("mat.hide", 25),
                BagUpgradeInput("mat.iron_ingot", 12)
            ]
        )
    ]

    // MARK: - Queries

    /// Step that takes the player FROM `currentTier` to `currentTier + 1`,
    /// or nil if `currentTier` is already at `maxTier`.
    public static func nextStep(from currentTier: Int) -> BagUpgradeStep? {
        let nextTier = currentTier + 1
        guard nextTier >= 2, nextTier <= maxTier else { return nil }
        return progression[nextTier - 2]
    }

    /// True if the player has not yet reached the highest bag tier.
    public static func canUpgrade(from currentTier: Int) -> Bool {
        return currentTier < maxTier
    }
}
