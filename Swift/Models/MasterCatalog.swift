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

    /// Armor the Master sells ready-made for silver — a convenience tax over
    /// crafting it from hides at the Workshop. Price ≈ resource value × 2.5
    /// (hide is worth 3🪙 at the Trader), rounded to a tidy number. Pieces
    /// arrive at full durability, enchant level 0.
    public struct ArmorListing: Sendable {
        public let itemId: String
        public let priceSilver: Int
        public init(_ itemId: String, _ priceSilver: Int) {
            self.itemId = itemId
            self.priceSilver = priceSilver
        }
    }

    public static let armorForSale: [ArmorListing] = [
        ArmorListing("gear.forester_hood",     15),  // 2 hide  → 15🪙
        ArmorListing("gear.forester_boots",    23),  // 3 hide  → 23🪙
        ArmorListing("gear.forester_breeches", 38),  // 5 hide  → 38🪙
        ArmorListing("gear.forester_jerkin",   45),  // 6 hide  → 45🪙
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

    // MARK: - Enchant

    /// Hard cap on the permanent enchant bonus a single piece can hold.
    public static let enchantCap = 3

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
        EnchantStep(1, 30,  "mat.hide", 3),
        EnchantStep(2, 70,  "mat.hide", 6),
        EnchantStep(3, 150, "mat.hide", 10),
    ]

    /// The step that takes a piece from its current `level` to `level + 1`,
    /// or nil if already at `enchantCap`.
    public static func enchantStep(currentLevel: Int) -> EnchantStep? {
        let next = currentLevel + 1
        guard next <= enchantCap else { return nil }
        return enchantSteps.first(where: { $0.level == next })
    }
}
