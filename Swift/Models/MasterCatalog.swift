//
//  MasterCatalog.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 21.05.2026.
//
//  Façade over `content/data/master.json` (Phase 3C — was Swift arrays and
//  constants). The Master (Майстер) capital location: armor shop + repair +
//  enchant. The actions themselves run through `MasterService`; this owns the
//  shop economics so every tunable number sits in one place. The Master is the
//  game's first real silver sink — buy markup, repair fees and enchant fees all
//  drain `User.silver`.
//
//  Durability is armor-only for now (weapons keep their tier ladder and will
//  gain gem inlay in a later phase). Gear-condition runtime — drain on combat,
//  "broken at 0" — lives in `GearConditionService`.
//

import Foundation

public enum MasterCatalog {

    // MARK: - Buyable armor

    /// Armor the Master sells ready-made for silver — a premium "convenience
    /// tax" over crafting it at the estate. Ready-made costs ≈ 4× the crafted
    /// material value (no hides, no iron, no zone travel, instant), so the shop
    /// is the lazy/no-stock path while crafting stays the economical one. Pieces
    /// arrive at full durability, enchant level 0. Repair cost derives from this
    /// price, so it scales with the premium too.
    public struct ArmorListing: Sendable {
        public let itemId: String
        public let priceSilver: Int
        public init(_ itemId: String, _ priceSilver: Int) {
            self.itemId = itemId
            self.priceSilver = priceSilver
        }
    }

    /// Display order, ascending by price. Computed, never a `static let` — the
    /// snapshot is installed at boot and a type-level constant would read it
    /// too early.
    public static var armorForSale: [ArmorListing] { Catalogs.current.masterArmor }

    public static func buyPrice(for itemId: String) -> Int? {
        Catalogs.current.masterArmorById[itemId]?.priceSilver
    }

    // MARK: - Repair

    /// Silver cost to fully repair a piece from its current durability back to
    /// max. Scales with how worn it is and the piece's value — a full repair
    /// from 0 costs `repairCostFraction` of the buy price. Every repair also
    /// permanently shaves 1 off `maxDurability` (see
    /// `GearConditionService.repairMaxShave`), so an often-repaired piece
    /// eventually wears out and must be rebought.
    ///
    /// Only the fraction is data. The rest stays here because it reads
    /// `GearConditionService.maxDurabilityStart`, a runtime constant rather than
    /// content, and because the `?? 30` fallback and the `max(1, …)` floor are
    /// behaviour, not tuning.
    public static func repairCost(itemId: String, missing: Int) -> Int {
        guard missing > 0 else { return 0 }
        let value = buyPrice(for: itemId) ?? 30
        let fraction = Catalogs.current.masterRepairCostFraction
        let cost = Double(value) * fraction * Double(missing) / Double(GearConditionService.maxDurabilityStart)
        return max(1, Int(cost.rounded()))
    }

    /// Weapon repair cost: a flat 1🪙 per missing durability point. Weapons have
    /// no buy price (they're upgraded, never sold), so the cost is keyed to the
    /// tier's durability ceiling instead — a full repair runs 30🪙 (T1) → 100🪙
    /// (T5). No max shave: the King's weapon is mended, not worn out.
    ///
    /// Deliberately NOT data-driven yet: there is no magic number in
    /// `max(0, missing)` to lift into JSON, and inventing a `×1` rate would mean
    /// writing new logic during a migration. Phase 4 owns it.
    public static func weaponRepairCost(missing: Int) -> Int {
        return max(0, missing)
    }

    // MARK: - Enchant

    /// Hard cap on the permanent enchant bonus a single piece can hold.
    public static var enchantCap: Int { Catalogs.current.masterEnchantCap }

    /// Points granted per level. Non-linear — +1 +1 +1 +2 +3 — so the top two
    /// levels are worth more than the early ones and the last point is the real
    /// prize. Drives BOTH the flat +ЗАХ every class gets and the class-identity
    /// bonus that mirrors it: see `EquipmentService.recomputeBonuses`.
    public static var enchantPerLevelPoints: [Int] { Catalogs.current.masterEnchantPerLevelPoints }

    /// Cumulative points an enchant of `level` (0…cap) grants per affected stat.
    public static func enchantBonusPoints(level: Int) -> Int {
        guard level > 0 else { return 0 }
        let points = enchantPerLevelPoints
        return points.prefix(min(level, points.count)).reduce(0, +)
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

    public static var enchantSteps: [EnchantStep] { Catalogs.current.masterEnchantSteps }

    /// The step that takes a piece from its current `level` to `level + 1`,
    /// or nil if already at `enchantCap`.
    public static func enchantStep(currentLevel: Int) -> EnchantStep? {
        let next = currentLevel + 1
        guard next <= enchantCap else { return nil }
        return enchantSteps.first(where: { $0.level == next })
    }
}
