//
//  MasterCatalog.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 21.05.2026.
//
//  Phase 6.5 — the Master (Майстер) capital location: armor shop + repair +
//  enchant. Pure data + cost formulas, no DB writes — the actions themselves
//  run through `MasterService`. The Master is the game's first real silver
//  sink (buy markup, repair fees, enchant fees all drain `User.silver`).
//
//  Durability is armor-only for now (weapons keep their tier ladder and will
//  gain gem inlay in a later phase). Gear-condition runtime (drain on combat,
//  "broken at 0") lives in `GearConditionService`; this catalog owns the shop
//  economics so all tunable numbers sit in one place.
//

import Foundation

public enum MasterCatalog {

    // MARK: - Buyable armor

    /// Armor the Master sells ready-made for silver — a premium "convenience
    /// tax" over crafting it at the estate. Ready-made costs ≈ 4× the crafted
    /// material value (no hides, no iron, no zone travel, instant), so the shop
    /// is the lazy/no-stock path while crafting stays the economical one. Pieces
    /// arrive at full durability, enchant level 0. Repair cost derives from this
    /// price (full repair = ½ buy price), so it scales with the premium too.
    public struct ArmorListing: Sendable {
        public let itemId: String
        public let priceSilver: Int
        public init(_ itemId: String, _ priceSilver: Int) {
            self.itemId = itemId
            self.priceSilver = priceSilver
        }
    }

    public static let armorForSale: [ArmorListing] = [
        ArmorListing("gear.forester_hood",      60),  // craft  5🦴       → repair 30
        ArmorListing("gear.forester_boots",     95),  // craft  8🦴 + 2⛓ → repair 48
        ArmorListing("gear.forester_breeches", 150),  // craft 12🦴 + 2⛓ → repair 75
        ArmorListing("gear.forester_jerkin",   180),  // craft 15🦴 + 4⛓ → repair 90
    ]

    public static func buyPrice(for itemId: String) -> Int? {
        armorForSale.first(where: { $0.itemId == itemId })?.priceSilver
    }

    // MARK: - Repair

    /// Silver cost to fully repair a piece from its current durability back to
    /// max. Scales with how worn it is and the piece's value — a full repair
    /// from 0 costs ≈ half the buy price. Every repair also permanently shaves
    /// 1 off `maxDurability` (see `GearConditionService.repairMaxShave`), so an
    /// often-repaired piece eventually wears out and must be rebought.
    public static func repairCost(itemId: String, missing: Int) -> Int {
        guard missing > 0 else { return 0 }
        let value = buyPrice(for: itemId) ?? 30
        let cost = Double(value) * 0.5 * Double(missing) / Double(GearConditionService.maxDurabilityStart)
        return max(1, Int(cost.rounded()))
    }

    /// Weapon repair cost: a flat 1🪙 per missing durability point. Weapons have
    /// no buy price (they're upgraded, never sold), so the cost is keyed to the
    /// tier's durability ceiling instead — a full repair runs 30🪙 (T1) → 100🪙
    /// (T5). No max shave: the King's weapon is mended, not worn out.
    public static func weaponRepairCost(missing: Int) -> Int {
        return max(0, missing)
    }

    // MARK: - Enchant

    /// Hard cap on the permanent enchant bonus a single piece can hold.
    public static let enchantCap = 5

    /// Cumulative stat points an enchant of `level` (0…cap) grants per affected
    /// stat. Non-linear — the per-level weights are +1 +1 +1 +2 +3, so the top
    /// two levels are worth more than the early ones and the last point is the
    /// real prize. Drives BOTH the flat +ЗАХ every class gets and the
    /// class-identity bonus (which mirrors these points): see
    /// `EquipmentService.recomputeBonuses`.
    public static let enchantPerLevelPoints = [1, 1, 1, 2, 3]
    public static func enchantBonusPoints(level: Int) -> Int {
        guard level > 0 else { return 0 }
        return enchantPerLevelPoints.prefix(min(level, enchantPerLevelPoints.count)).reduce(0, +)
    }

    /// Cost to raise a piece from `(level-1)` → `level` (1-based). Silver +
    /// material. Escalates so the last point is the deepest sink.
    public struct EnchantStep: Sendable {
        public let level: Int
        public let silver: Int
        public let materialId: String
        public let materialQty: Int
        public init(_ level: Int, _ silver: Int, _ materialId: String, _ materialQty: Int) {
            self.level = level
            self.silver = silver
            self.materialId = materialId
            self.materialQty = materialQty
        }
    }

    public static let enchantSteps: [EnchantStep] = [
        EnchantStep(1, 40,  "mat.hide", 4),
        EnchantStep(2, 100, "mat.hide", 8),
        EnchantStep(3, 220, "mat.hide", 15),
        EnchantStep(4, 450, "mat.hide", 26),
        EnchantStep(5, 850, "mat.hide", 42),
    ]

    /// The step that takes a piece from its current `level` to `level + 1`,
    /// or nil if already at `enchantCap`.
    public static func enchantStep(currentLevel: Int) -> EnchantStep? {
        let next = currentLevel + 1
        guard next <= enchantCap else { return nil }
        return enchantSteps.first(where: { $0.level == next })
    }
}
