//
//  BudgetDTO.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 30.08.2026.
//
//  Wire format for `content/data/tuning/budget.json` and `content/data/rarities.json`
//  — the item stat budget, which is what makes "add items forever" a safe
//  operation instead of a slow power creep.
//
//    budget(itemLevel, slot, rarity) = slotWeight · (base + perItemLevel · itemLevel) · rarityBudget
//
//  Every stat an item carries is that budget SPENT at a fixed exchange rate, so
//  one number bounds the whole piece. It is also the curve the combat
//  denominators were derived from: hold the budget and a stat's percentage
//  cannot drift, whatever gets added later.
//

import Foundation

/// What one budget point buys of each stat. HP is cheap per point and crit
/// dear because they are measured on different scales, not because one is
/// better — the exchange is what makes them comparable at all.
public struct StatPerPointDTO: Codable, Sendable, Equatable {
    public let attack: Double
    public let defense: Double
    public let hp: Double
    public let crit: Double
    public let dodge: Double
    public let accuracy: Double

    public init(attack: Double, defense: Double, hp: Double,
                crit: Double, dodge: Double, accuracy: Double) {
        self.attack = attack
        self.defense = defense
        self.hp = hp
        self.crit = crit
        self.dodge = dodge
        self.accuracy = accuracy
    }

    private enum CodingKeys: String, CodingKey { case attack, defense, hp, crit, dodge, accuracy }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        attack   = try c.decode(Double.self, forKey: .attack)
        defense  = try c.decode(Double.self, forKey: .defense)
        hp       = try c.decode(Double.self, forKey: .hp)
        crit     = try c.decode(Double.self, forKey: .crit)
        dodge    = try c.decode(Double.self, forKey: .dodge)
        accuracy = try c.decode(Double.self, forKey: .accuracy)
    }
}

/// Relative share of a full set's budget each slot carries. Designed to sum to
/// 10 across the eight slots, so "one whole outfit" is a round number and a new
/// slot cannot be added without deciding what it takes from the others.
public struct SlotWeightDTO: Codable, Sendable, Equatable {
    public let slot: String
    public let weight: Double

    public init(slot: String, weight: Double) {
        self.slot = slot
        self.weight = weight
    }

    private enum CodingKeys: String, CodingKey { case slot, weight }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        slot   = try c.decode(String.self, forKey: .slot)
        weight = try c.decode(Double.self, forKey: .weight)
    }
}

/// How a share of budget is split across stats. Shares should sum to 1.0 — the
/// validator says so — because a profile that sums to less silently under-spends
/// the item and one that sums to more silently overspends it.
public struct StatSharesDTO: Codable, Sendable, Equatable {
    public let attack: Double
    public let defense: Double
    public let hp: Double
    public let crit: Double
    public let dodge: Double
    public let accuracy: Double

    public init(attack: Double = 0, defense: Double = 0, hp: Double = 0,
                crit: Double = 0, dodge: Double = 0, accuracy: Double = 0) {
        self.attack = attack
        self.defense = defense
        self.hp = hp
        self.crit = crit
        self.dodge = dodge
        self.accuracy = accuracy
    }

    public var total: Double { attack + defense + hp + crit + dodge + accuracy }

    private enum CodingKeys: String, CodingKey { case attack, defense, hp, crit, dodge, accuracy }

    /// Absent means zero here, unlike everywhere else in the tuning: a profile
    /// names the stats it spends on, and listing four zeroes to say "this piece
    /// has no dodge" would make every profile unreadable.
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        attack   = try c.decodeIfPresent(Double.self, forKey: .attack)   ?? 0
        defense  = try c.decodeIfPresent(Double.self, forKey: .defense)  ?? 0
        hp       = try c.decodeIfPresent(Double.self, forKey: .hp)       ?? 0
        crit     = try c.decodeIfPresent(Double.self, forKey: .crit)     ?? 0
        dodge    = try c.decodeIfPresent(Double.self, forKey: .dodge)    ?? 0
        accuracy = try c.decodeIfPresent(Double.self, forKey: .accuracy) ?? 0
    }
}

/// How each class spends the SAME budget differently.
///
/// This is the answer to the T5 weapon asymmetry: the three top-tier weapons
/// were written independently, so the warrior's ended up carrying about 15%
/// more total budget than the mage's for no stated reason. One budget and three
/// distribution profiles makes that impossible to repeat.
///
/// Design input for the generator rather than something the running game reads,
/// but it lives in the bundle so the generator and the validator share one copy.
public struct ClassBudgetProfileDTO: Codable, Sendable, Equatable {
    public let characterClass: String
    public let weapon: StatSharesDTO
    public let armour: StatSharesDTO
    public let offHand: StatSharesDTO

    public init(characterClass: String, weapon: StatSharesDTO,
                armour: StatSharesDTO, offHand: StatSharesDTO) {
        self.characterClass = characterClass
        self.weapon = weapon
        self.armour = armour
        self.offHand = offHand
    }

    private enum CodingKeys: String, CodingKey {
        case characterClass = "class"
        case weapon, armour, offHand
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        characterClass = try c.decode(String.self, forKey: .characterClass)
        weapon         = try c.decode(StatSharesDTO.self, forKey: .weapon)
        armour         = try c.decode(StatSharesDTO.self, forKey: .armour)
        offHand        = try c.decode(StatSharesDTO.self, forKey: .offHand)
    }
}

public struct BudgetTuningDTO: Codable, Sendable {
    /// The non-zero intercept matters: it means a budget MULTIPLIER is
    /// equivalent to a jump in item level. At level 30 a ×1.95 multiplier is
    /// worth +32 item levels — which is how the drafted rarity table ended up
    /// giving legendaries 4.15× the power of a common of the same level, a
    /// second progression axis outweighing all forty levels of the first.
    public let base: Double
    public let perItemLevel: Double
    public let slotWeights: [SlotWeightDTO]
    public let statPerPoint: StatPerPointDTO
    public let classProfiles: [ClassBudgetProfileDTO]

    public init(base: Double, perItemLevel: Double, slotWeights: [SlotWeightDTO],
                statPerPoint: StatPerPointDTO, classProfiles: [ClassBudgetProfileDTO] = []) {
        self.base = base
        self.perItemLevel = perItemLevel
        self.slotWeights = slotWeights
        self.statPerPoint = statPerPoint
        self.classProfiles = classProfiles
    }

    private enum CodingKeys: String, CodingKey {
        case base, perItemLevel, slotWeights, statPerPoint, classProfiles
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        base         = try c.decode(Double.self, forKey: .base)
        perItemLevel = try c.decode(Double.self, forKey: .perItemLevel)
        slotWeights  = try c.decode([SlotWeightDTO].self, forKey: .slotWeights)
        statPerPoint  = try c.decode(StatPerPointDTO.self, forKey: .statPerPoint)
        classProfiles = try c.decode([ClassBudgetProfileDTO].self, forKey: .classProfiles)
    }
}

/// One rarity tier.
///
/// `budgetMultiplier` and `valueMultiplier` are deliberately DECOUPLED. Tying
/// price to power gives 1/2.2/5/14/40, and against an unlimited vendor that
/// makes *selling a legendary* the largest silver faucet in the game. Power
/// climbs gently (×1.45 at the top) while price climbs steeply (×16), so rarity
/// reads as valuable without becoming a second stat ladder.
public struct RarityDTO: Codable, Sendable, Equatable {
    public let id: String
    public let budgetMultiplier: Double
    public let valueMultiplier: Double
    /// Shown beside the item name. One grapheme; the id is not player-facing.
    public let glyph: String

    public init(id: String, budgetMultiplier: Double, valueMultiplier: Double, glyph: String) {
        self.id = id
        self.budgetMultiplier = budgetMultiplier
        self.valueMultiplier = valueMultiplier
        self.glyph = glyph
    }

    private enum CodingKeys: String, CodingKey { case id, budgetMultiplier, valueMultiplier, glyph }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id               = try c.decode(String.self, forKey: .id)
        budgetMultiplier = try c.decode(Double.self, forKey: .budgetMultiplier)
        valueMultiplier  = try c.decode(Double.self, forKey: .valueMultiplier)
        glyph            = try c.decode(String.self, forKey: .glyph)
    }
}

/// Top-level shape of `rarities.json`. Order is the ladder, lowest first.
public struct RarityFileDTO: Codable, Sendable {
    public let rarities: [RarityDTO]

    public init(rarities: [RarityDTO]) { self.rarities = rarities }

    private enum CodingKeys: String, CodingKey { case rarities }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        rarities = try c.decode([RarityDTO].self, forKey: .rarities)
    }
}
