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
//  The enchant bench is the armour's ladder since 2026-10-06 (`spec-items.md`
//  §11): the weapon climbs by the reforge, gated by the player's level; the
//  armour by the enchant, gated by its price alone. Gear-condition runtime —
//  drain on combat, "broken at 0" — lives in `GearConditionService`.
//

import Foundation

public enum MasterCatalog {

    // MARK: - Buyable armor

    /// Armor the Master sells ready-made for silver — since 2026-09-28 the
    /// ONLY way to get armour: the estate no longer crafts it (the patterns stay
    /// in `recipes.json` for salvage alone). It used to be the premium path
    /// beside crafting; the owner kept the prices when it became the only one,
    /// because silver is over-supplied and this is a sink. Pieces arrive at full
    /// durability, enchant level 0. Repair cost derives from this price.
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
    /// max. Scales with how worn it is and the piece's value — a full repair of
    /// a fresh piece from 0 costs `repairCostFraction` of the buy price. Every
    /// repair also permanently shaves 1 off `maxDurability` (see
    /// `GearConditionService.repairMaxShave`), so an often-repaired piece
    /// eventually wears out and must be rebought.
    ///
    /// The divisor is the piece's OWN starting durability (its item's
    /// `maxDurability` since 2026-10-05). One point therefore costs
    /// price × fraction ÷ durability: the Forester set went 30 → 50 with its
    /// prices ×5/3, so a point costs what it did.
    ///
    /// The prices and the fraction are data. The `?? 30` price fallback (armour
    /// the Master does not sell — none today) and the `max(1, …)` floors are
    /// behaviour, not tuning.
    public static func repairCost(itemId: String, missing: Int) -> Int {
        guard missing > 0 else { return 0 }
        let value = buyPrice(for: itemId) ?? 30
        let fraction = Catalogs.current.masterRepairCostFraction
        let start = max(1, GearConditionService.startingDurability(for: itemId))
        let cost = Double(value) * fraction * Double(missing) / Double(start)
        return max(1, Int(cost.rounded()))
    }

    /// Weapon repair cost: a flat 1🪙 per missing durability point. Weapons have
    /// no buy price (they're upgraded, never sold), so the cost is keyed to the
    /// tier's durability ceiling instead — a full repair runs 30🪙 (T1) → 180🪙
    /// (T9). No max shave: the King's weapon is mended, not worn out.
    ///
    /// Deliberately NOT data-driven yet: there is no magic number in
    /// `max(0, missing)` to lift into JSON, and inventing a `×1` rate would mean
    /// writing new logic during a migration. Phase 4 owns it.
    public static func weaponRepairCost(missing: Int) -> Int {
        return max(0, missing)
    }

    // MARK: - Enchant
    //
    // The enchant is the ARMOUR'S LADDER since 2026-10-06 (`spec-items.md`
    // §11). Level N budgets the piece at an item level, the way a weapon rung
    // does; until then a level added 4% of the piece's own stats, which on
    // item-level-1 armour rounded away. No player level gates it — the owner
    // had the gates taken out the day they were built. The price does.

    /// The highest enchant level a piece can hold — the ladder's length.
    public static var enchantCap: Int { Catalogs.current.masterEnchantCap }

    /// The fee for the weapon lesson, the first reforge (`spec-items.md` §9.4),
    /// paid on top of that rung's own materials.
    public static var weaponLessonSilver: Int { Catalogs.current.masterWeaponLessonSilver }

    /// Share of the budget curve's growth an enchant level carries — the
    /// weapon ladder's rule, so the armour and the weapon climb by one law.
    public static var enchantGrowthShare: Double { Catalogs.current.masterEnchantGrowthShare }

    /// One level of the ladder: what it costs and the item level it budgets a
    /// piece at. The price is the level's only gate (`spec-items.md` §11).
    public struct EnchantStep: Sendable {
        public let level: Int
        public let silver: Int
        public let materialId: String
        public let materialQty: Int
        public let itemLevel: Int
        public init(_ level: Int, _ silver: Int, _ materialId: String, _ materialQty: Int, itemLevel: Int) {
            self.level = level
            self.silver = silver
            self.materialId = materialId
            self.materialQty = materialQty
            self.itemLevel = itemLevel
        }
    }

    /// Ordered by level — `Catalogs` sorts them once at install.
    public static var enchantSteps: [EnchantStep] { Catalogs.current.masterEnchantSteps }

    /// The step that takes a piece from its current `level` to `level + 1`,
    /// or nil if already at `enchantCap`.
    public static func enchantStep(currentLevel: Int) -> EnchantStep? {
        let next = currentLevel + 1
        guard next <= enchantCap else { return nil }
        return enchantSteps.first(where: { $0.level == next })
    }

    /// The lift an enchant of `level` gives `item`'s own stats: the piece
    /// budgeted at that level's item level, by `EnchantLadderRules.scale`.
    ///
    /// Clamped at both ends — nothing below level 1, the cap's lift above the
    /// cap — and identity for a level the table does not carry, so a bad row
    /// can never lower a stat. Every stat the piece has scales together, which
    /// keeps its own profile intact: a mage's cloth stays a crit piece.
    public static func enchantScale(level: Int, for item: Item) -> LadderScale {
        let clamped = Swift.min(level, enchantCap)
        guard clamped >= 1, let step = enchantSteps.first(where: { $0.level == clamped }) else {
            return .identity
        }
        return EnchantLadderRules.scale(fromItemLevel: item.itemLevel, toItemLevel: step.itemLevel,
                                        growthShare: enchantGrowthShare, curve: Catalogs.current.budget)
    }
}
