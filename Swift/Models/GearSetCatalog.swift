//
//  GearSetCatalog.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 30.08.2026.
//
//  Façades over the Phase 6 snapshot: the rarity ladder, the equipment sets,
//  and the item stat budget the validator enforces.
//
//  `budget(itemLevel:slot:rarity:)` lives here rather than in the validator
//  because the game reads it too — the Master prices a repair from it, and an
//  inventory card can show how much of its allowance a piece actually spends.
//  One implementation means the number the player is shown is the number the
//  validator checked.
//

import Foundation

public enum RarityCatalog {
    /// The ladder, lowest first.
    public static var all: [RarityDTO] { Catalogs.current.rarities }

    public static func find(_ id: String) -> RarityDTO? {
        Catalogs.current.raritiesById[id]
    }
}

public enum GearSetCatalog {
    public static var all: [GearSetDTO] { Catalogs.current.gearSets }

    public static func find(_ id: String) -> GearSetDTO? {
        Catalogs.current.gearSets.first { $0.id == id }
    }
}

public enum ItemBudget {
    /// Stat points an item of this level, slot and rarity is allowed to spend.
    ///
    /// Returns nil for a slot with no weight — an unweighted slot has no budget
    /// rather than an infinite one, and the caller has to say what that means.
    public static func points(itemLevel: Int, slot: EquipmentSlot, rarity: String) -> Double? {
        let content = Catalogs.current
        guard let weight = content.slotWeights[slot.rawValue] else { return nil }
        let multiplier = content.raritiesById[rarity]?.budgetMultiplier ?? 1.0
        return BudgetMath.points(itemLevel: itemLevel, slotWeight: weight,
                                 rarityMultiplier: multiplier, curve: content.budget)
    }

    /// Stats produced by spending `points` according to `shares`, at the
    /// exchange rates. This is the generator's core operation, and it lives
    /// beside `points` so the number the validator checks and the number the
    /// generator emits come from the same place.
    public static func spend(points: Double, shares: StatSharesDTO) -> GearStats {
        BudgetMath.spend(points: points, shares: shares,
                         rate: Catalogs.current.budget.statPerPoint).domain
    }

    /// The reference character's full kit at `itemLevel`: common gear of that
    /// level in every weighted slot, spent through the class profile.
    ///
    /// This is what the design's reference table describes, and having it in
    /// code is what lets `--content-digest` check the published numbers rather
    /// than take them on faith.
    public static func referenceGear(for characterClass: CharacterClass, itemLevel: Int) -> GearStats {
        let content = Catalogs.current
        guard let profile = content.classBudgetProfiles[characterClass.rawValue] else { return GearStats() }
        // The two accessory slots are deliberately left unspent: no accessory
        // exists yet, and their 1.0 of slot weight is exactly the gap between
        // this kit and the design's published reference numbers.
        return BudgetMath.referenceGear(
            profile: profile, itemLevel: itemLevel, budget: content.budget,
            rarityMultiplier: content.raritiesById["common"]?.budgetMultiplier ?? 1.0).domain
    }

}
