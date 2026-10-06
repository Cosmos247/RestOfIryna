//
//  MasterDTO.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 29.08.2026.
//
//  Wire format for `content/data/master.json` — the Master's (Майстер) armor
//  shop, repair desk and enchant bench.
//
//  Mixed shape, so both decoding rules from batch B apply side by side:
//  the two ordered arrays are RECORDS (sub-fields may default), while
//  `repairCostFraction` and `enchantCap` are TUNING SCALARS and decode as
//  required — a missing enchant cap must fail the boot, not quietly become 0
//  and lock every player out of the bench.
//
//  `repairCostFraction` is the 0.5 that used to sit inside
//  `MasterCatalog.repairCost`: a full repair of a fresh piece from zero costs
//  that share of its buy price. The rest of that formula stays in Swift: it
//  divides by the piece's own starting durability
//  (`GearConditionService.startingDurability`, the item's `maxDurability` since
//  2026-10-05), and the price fallback and the 1-silver floor are behaviour,
//  not tuning.
//  `weaponRepairCost` keeps its implicit ×1 in code as well; there is no magic
//  number in `max(0, missing)` to lift out, and inventing one would mean
//  writing new logic during a migration.
//
//  The enchant bench is the ARMOUR'S LADDER since 2026-10-06 (`spec-items.md`
//  §11): each `enchantSteps` row carries the item level the piece is budgeted
//  at, and `enchantGrowthShare` is the share of the curve's growth a level
//  carries. The lift itself is `EnchantLadderRules.scale` — derived from
//  `tuning/budget.json`, never typed. Nothing but the step's price gates it.
//

import Foundation

/// One ready-made armor piece the Master sells — the only source of armour
/// since 2026-09-28, when the workshop stopped making it. The repair price
/// derives from this number: a full repair of a fresh piece from zero costs
/// `repairCostFraction` of it. The Forester prices went ×5/3 on 2026-10-05
/// with the set's durability 30 → 50, which kept a repaired point at its old
/// price (`spec-items.md` §10).
public struct MasterArmorListingDTO: Codable, Sendable, Equatable {
    public let itemId: String
    public let priceSilver: Int

    public init(itemId: String, priceSilver: Int) {
        self.itemId = itemId
        self.priceSilver = priceSilver
    }

    private enum CodingKeys: String, CodingKey { case itemId, priceSilver }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        itemId      = try c.decode(String.self, forKey: .itemId)
        priceSilver = try c.decode(Int.self, forKey: .priceSilver)
    }
}

/// One level of the armour ladder: what raising a piece from `level - 1` to
/// `level` costs, and the item level the piece is budgeted at once it is there
/// (`spec-items.md` §11).
///
/// Silver plus material, escalating so the last level is the deepest sink —
/// and since 2026-10-06 the price is the level's ONLY gate. A player-level gate
/// was built first and taken out the same day, on the owner's word: what
/// holds an enchant back is what it costs. So the price ladder is a balance
/// number in its own right, not a fee.
public struct EnchantStepDTO: Codable, Sendable, Equatable {
    public let level: Int
    public let silver: Int
    public let materialId: String
    public let materialQty: Int
    /// The item level the piece is budgeted at on this level.
    public let itemLevel: Int

    public init(level: Int, silver: Int, materialId: String, materialQty: Int, itemLevel: Int) {
        self.level = level
        self.silver = silver
        self.materialId = materialId
        self.materialQty = materialQty
        self.itemLevel = itemLevel
    }

    private enum CodingKeys: String, CodingKey {
        case level, silver, materialId, materialQty, itemLevel
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        level       = try c.decode(Int.self, forKey: .level)
        silver      = try c.decode(Int.self, forKey: .silver)
        materialId  = try c.decode(String.self, forKey: .materialId)
        materialQty = try c.decode(Int.self, forKey: .materialQty)
        itemLevel   = try c.decode(Int.self, forKey: .itemLevel)
    }
}

/// Top-level shape of `master.json`.
public struct MasterFileDTO: Codable, Sendable {
    /// Shop order, preserved verbatim — ascending by price.
    public let armorForSale: [MasterArmorListingDTO]
    /// Fraction of the buy price a full repair from zero durability costs.
    public let repairCostFraction: Double
    /// The highest enchant level a piece can hold — the ladder's length.
    public let enchantCap: Int
    /// Share of the budget curve's growth an enchant level carries — the
    /// weapon ladder's rule (`spec-items.md` §9.2, §11.2).
    ///
    /// Level N budgets the piece at its step's `itemLevel`: the piece's own
    /// budget plus this share of what the curve adds between the two item
    /// levels. At 0.75 a level-1 piece budgeted at item level 25 is ×4.6 its
    /// own stats and still 79% of the on-curve item of that level.
    ///
    /// Never flat points, and never a fixed percentage of the piece either.
    /// A flat +32 DEF is 267% of a level-1 chest and 14% of a level-40 one;
    /// the +4% a level this replaced was smaller than one point of any stat on
    /// a level-1 piece, so most levels changed nothing. An item level is the
    /// size the rest of the game is measured in.
    public let enchantGrowthShare: Double
    /// One step per level, ordered by `level`.
    public let enchantSteps: [EnchantStepDTO]
    /// The Master's fee for the weapon lesson — the first re-forge, tier 1 → 2,
    /// on top of that rung's own materials (`spec-items.md` §9.4). A TUNING
    /// SCALAR beside `repairCostFraction`, hashed by the digest.
    public let weaponLessonSilver: Int

    public init(armorForSale: [MasterArmorListingDTO], repairCostFraction: Double,
                enchantCap: Int, enchantGrowthShare: Double,
                enchantSteps: [EnchantStepDTO], weaponLessonSilver: Int = 30) {
        self.armorForSale = armorForSale
        self.repairCostFraction = repairCostFraction
        self.enchantCap = enchantCap
        self.enchantGrowthShare = enchantGrowthShare
        self.enchantSteps = enchantSteps
        self.weaponLessonSilver = weaponLessonSilver
    }

    private enum CodingKeys: String, CodingKey {
        case armorForSale, repairCostFraction, enchantCap
        case enchantGrowthShare, enchantSteps, weaponLessonSilver
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        armorForSale          = try c.decode([MasterArmorListingDTO].self, forKey: .armorForSale)
        repairCostFraction    = try c.decode(Double.self, forKey: .repairCostFraction)
        enchantCap            = try c.decode(Int.self, forKey: .enchantCap)
        enchantGrowthShare    = try c.decode(Double.self, forKey: .enchantGrowthShare)
        enchantSteps          = try c.decode([EnchantStepDTO].self, forKey: .enchantSteps)
        weaponLessonSilver    = try c.decode(Int.self, forKey: .weaponLessonSilver)
    }
}
