//
//  EnchantLadderRules.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 06.10.2026.
//
//  The Master's enchant is the armour's ladder since 2026-10-06
//  (`spec-items.md` §11): enchant level N budgets the piece at an item level,
//  the way a weapon rung does. Until then a level added 4% of the piece's own
//  stats, and on item-level-1 armour that rounded away — thirteen of the
//  twenty purchases on the Forester set changed no number at all.
//
//  Unlike a weapon rung, an enchant level has NO player-level gate. One was
//  built with the ladder and removed the same day, on the owner's word: the
//  price is what holds a level back (`master.json` → `enchantSteps`).
//
//  Three readers ask the same question of the ladder:
//  - the game, through `MasterCatalog` and `EquipmentService`;
//  - the validator, which refuses a level that changes nothing;
//  - `roi-content spec gates`, which prints it.
//
//  So the answers live here, once, in pure Foundation where the tests can reach
//  them — the reason `WeaponLadderRules` lives in this module too.
//

import Foundation

/// How far a ladder level lifts a stat line: `value × numerator ÷ denominator`.
///
/// Kept as the two numbers rather than their quotient, and applied multiply
/// first, divide last. Level 3 of the shipped ladder is ×3.1, and 5 × 3.1 is
/// 15.5 only when it is computed as 5 × 23.25 ÷ 7.5. As 5 × (23.25 ÷ 7.5) it
/// can land a hair under and round the other way, so one HP would hang on a
/// representation error.
public struct LadderScale: Sendable, Equatable {
    public let numerator: Double
    public let denominator: Double

    public init(numerator: Double, denominator: Double) {
        self.numerator = numerator
        self.denominator = denominator
    }

    /// Leaves a stat line as it is.
    public static let identity = LadderScale(numerator: 1, denominator: 1)

    /// One stat through the scale, rounded half away from zero — the rounding
    /// every other stat scaling in the game uses.
    public func apply(_ value: Int) -> Int {
        guard denominator > 0 else { return value }
        return Int((Double(value) * numerator / denominator).rounded())
    }

    /// The same lift as one number, for a table or a log line. Never for the
    /// arithmetic itself — see the type's note.
    public var factor: Double { denominator > 0 ? numerator / denominator : 1 }
}

public enum EnchantLadderRules {

    /// Budget points one unit of slot weight is allowed at `itemLevel` — the
    /// curve `BudgetMath.points` multiplies by the slot weight and the rarity.
    /// Both cancel out of a ladder's lift, so neither is asked for here.
    static func points(atItemLevel itemLevel: Int, curve: BudgetTuningDTO) -> Double {
        curve.base + curve.perItemLevel * Double(Swift.max(1, itemLevel))
    }

    /// The lift of a piece authored at `fromItemLevel` once the ladder budgets
    /// it at `toItemLevel`: its own budget plus `growthShare` of what the curve
    /// adds between the two levels, measured against its own budget.
    ///
    /// `growthShare` is the weapon ladder's rule (`spec-items.md` §9.2): a rung
    /// carries a share of the growth, so with a share of 1 or less a laddered
    /// piece never outgrows the on-curve item of its level. A ladder level at
    /// or below the piece's own item level lifts nothing — the ladder never
    /// lowers a stat.
    public static func scale(fromItemLevel: Int, toItemLevel: Int, growthShare: Double,
                             curve: BudgetTuningDTO) -> LadderScale {
        let own = points(atItemLevel: fromItemLevel, curve: curve)
        let target = points(atItemLevel: toItemLevel, curve: curve)
        guard own > 0, target > own, growthShare > 0 else { return .identity }
        return LadderScale(numerator: own + growthShare * (target - own), denominator: own)
    }
}

extension GearStatsDTO {
    /// Every stat through a ladder's lift, each rounded on its own.
    public func scaled(by scale: LadderScale) -> GearStatsDTO {
        GearStatsDTO(attack: scale.apply(attack), defense: scale.apply(defense),
                     hp: scale.apply(hp), crit: scale.apply(crit),
                     dodge: scale.apply(dodge), accuracy: scale.apply(accuracy))
    }
}
