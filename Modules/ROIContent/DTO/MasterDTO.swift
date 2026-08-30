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
//  `MasterCatalog.repairCost`: a full repair from zero costs half the buy
//  price. The rest of that formula stays in Swift, because it reads
//  `GearConditionService.maxDurabilityStart` — a runtime constant, not content.
//  `weaponRepairCost` keeps its implicit ×1 in code as well; there is no magic
//  number in `max(0, missing)` to lift out, and inventing one would mean
//  writing new logic during a migration.
//

import Foundation

/// One ready-made armor piece the Master sells. Buying is the convenience path
/// (≈4× the crafted material value); the repair price derives from this number,
/// so the premium carries through.
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

/// Cost to raise one piece from `level - 1` to `level`. Silver plus material,
/// escalating so the last point is the deepest sink in the game.
public struct EnchantStepDTO: Codable, Sendable, Equatable {
    public let level: Int
    public let silver: Int
    public let materialId: String
    public let materialQty: Int

    public init(level: Int, silver: Int, materialId: String, materialQty: Int) {
        self.level = level
        self.silver = silver
        self.materialId = materialId
        self.materialQty = materialQty
    }

    private enum CodingKeys: String, CodingKey { case level, silver, materialId, materialQty }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        level       = try c.decode(Int.self, forKey: .level)
        silver      = try c.decode(Int.self, forKey: .silver)
        materialId  = try c.decode(String.self, forKey: .materialId)
        materialQty = try c.decode(Int.self, forKey: .materialQty)
    }
}

/// Top-level shape of `master.json`.
public struct MasterFileDTO: Codable, Sendable {
    /// Shop order, preserved verbatim — ascending by price.
    public let armorForSale: [MasterArmorListingDTO]
    /// Fraction of the buy price a full repair from zero durability costs.
    public let repairCostFraction: Double
    /// Hard cap on the permanent enchant bonus one piece can hold.
    public let enchantCap: Int
    /// Fraction of the item's OWN budget added per enchant level.
    ///
    /// Never flat points. A flat bonus has no size that works: +32 DEF is 267%
    /// of a level-1 chest piece's own defence and 14% of a level-40 one, so the
    /// same number is game-breaking early and invisible late. A percentage of
    /// the item scales with the item by construction, which is also what keeps
    /// the absorption cap out of reach — a fully enchanted legendary reaches
    /// 49% against a ceiling of 70%.
    public let enchantBudgetFractionPerLevel: Double
    /// One step per level, ordered by `level`.
    public let enchantSteps: [EnchantStepDTO]

    public init(armorForSale: [MasterArmorListingDTO], repairCostFraction: Double,
                enchantCap: Int, enchantBudgetFractionPerLevel: Double,
                enchantSteps: [EnchantStepDTO]) {
        self.armorForSale = armorForSale
        self.repairCostFraction = repairCostFraction
        self.enchantCap = enchantCap
        self.enchantBudgetFractionPerLevel = enchantBudgetFractionPerLevel
        self.enchantSteps = enchantSteps
    }

    private enum CodingKeys: String, CodingKey {
        case armorForSale, repairCostFraction, enchantCap
        case enchantBudgetFractionPerLevel, enchantSteps
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        armorForSale          = try c.decode([MasterArmorListingDTO].self, forKey: .armorForSale)
        repairCostFraction    = try c.decode(Double.self, forKey: .repairCostFraction)
        enchantCap            = try c.decode(Int.self, forKey: .enchantCap)
        enchantBudgetFractionPerLevel = try c.decode(Double.self, forKey: .enchantBudgetFractionPerLevel)
        enchantSteps          = try c.decode([EnchantStepDTO].self, forKey: .enchantSteps)
    }
}
