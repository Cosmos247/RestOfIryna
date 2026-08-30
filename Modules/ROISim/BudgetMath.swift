//
//  BudgetMath.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 30.08.2026.
//
//  The item stat budget: how many points a piece may spend, what those points
//  buy, and what a full kit of level-appropriate gear adds up to.
//
//  Moved out of `ItemBudget` in Phase 8. The simulator's first job is to build
//  the character it measures, and that character is defined by its budget —
//  so the number the validator enforces, the number the Master prices from and
//  the number a simulated warrior actually swings with all come from here.
//

import Foundation
import ROIContent

public enum BudgetMath {

    /// Stat points an item of this level and slot is allowed to spend.
    ///
    /// `budget(itemLevel, slot, rarity) = slotWeight · (base + perItemLevel ·
    /// itemLevel) · rarityBudget`. The caller resolves the slot weight and the
    /// rarity multiplier, because a slot with no weight has NO budget rather
    /// than an infinite one, and only the caller can say what that means.
    public static func points(itemLevel: Int, slotWeight: Double,
                              rarityMultiplier: Double, curve: BudgetTuningDTO) -> Double {
        slotWeight * (curve.base + curve.perItemLevel * Double(Swift.max(1, itemLevel)))
            * rarityMultiplier
    }

    /// Stats produced by spending `points` according to `shares`, at the fixed
    /// exchange rates. This is the generator's core operation, and it lives
    /// beside `points` so the number the validator checks and the number the
    /// generator emits come from the same place.
    public static func spend(points: Double, shares: StatSharesDTO,
                             rate: StatPerPointDTO) -> GearStatsDTO {
        func stat(_ share: Double, _ per: Double) -> Int {
            Int((points * share * per).rounded())
        }
        return GearStatsDTO(
            attack:   stat(shares.attack, rate.attack),
            defense:  stat(shares.defense, rate.defense),
            hp:       stat(shares.hp, rate.hp),
            crit:     stat(shares.crit, rate.crit),
            dodge:    stat(shares.dodge, rate.dodge),
            accuracy: stat(shares.accuracy, rate.accuracy))
    }

    /// The reference character's full kit at `itemLevel`: gear of that level in
    /// every weighted slot, spent through the class profile.
    ///
    /// The two accessory slots are deliberately left unspent — no accessory has
    /// been authored — so the kit is short by their 1.0 of slot weight. That
    /// residual is not hidden: it IS the quantified value of the empty slots,
    /// and it closes in Phase 10, not before.
    public static func referenceGear(profile: ClassBudgetProfileDTO, itemLevel: Int,
                                     budget: BudgetTuningDTO,
                                     rarityMultiplier: Double = 1.0) -> GearStatsDTO {
        let weights = Dictionary(budget.slotWeights.map { ($0.slot, $0.weight) },
                                 uniquingKeysWith: { first, _ in first })
        var total = GearStatsDTO()
        func add(_ slot: EquipmentSlot, _ shares: StatSharesDTO) {
            guard let weight = weights[slot.rawValue] else { return }
            let spent = spend(points: points(itemLevel: itemLevel, slotWeight: weight,
                                             rarityMultiplier: rarityMultiplier, curve: budget),
                              shares: shares, rate: budget.statPerPoint)
            total = total.adding(spent)
        }
        add(.mainHand, profile.weapon)
        add(.offHand, profile.offHand)
        for slot in [EquipmentSlot.helmet, .chest, .legs, .boots] { add(slot, profile.armour) }
        return total
    }
}

extension GearStatsDTO {
    /// Stat-wise sum. Kits are accumulated a slot at a time, and six explicit
    /// additions at each call site is where a transposed field hides.
    public func adding(_ other: GearStatsDTO) -> GearStatsDTO {
        GearStatsDTO(attack: attack + other.attack, defense: defense + other.defense,
                     hp: hp + other.hp, crit: crit + other.crit,
                     dodge: dodge + other.dodge, accuracy: accuracy + other.accuracy)
    }
}
