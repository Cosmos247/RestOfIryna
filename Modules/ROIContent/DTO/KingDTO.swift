//
//  KingDTO.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 21.09.2026.
//
//  Wire format for `content/data/king.json` — the King's decree chain, the
//  linear tutorial spine that runs from registration to level 25.
//
//  **Array order is gameplay.** The chain is walked one decree at a time: the
//  player always has exactly one open, and turning it in opens the next. So
//  the position of a row IS the order the player meets it, the same way a
//  quest pool's order decides who is handed which job. Reordering the array
//  reorders the game while leaving every id byte-identical, which is why the
//  `king` digest replays the chain rather than hashing a set.
//
//  **There is no `kind` field.** A decree is a "level" decree when one of its
//  conditions is `player_level`, and a "task" decree otherwise — derived,
//  never authored, because a redundant discriminator is a field that can
//  disagree with the conditions beside it. `level` is NOT redundant in the
//  same way: it is the level the decree is EXPECTED at, which drives the pool
//  ceiling and the spec table, and for a `player_level` decree the validator
//  requires the two to agree.
//
//  **Conditions are an array and all of them must hold.** Exactly one decree
//  in the shipped chain is compound (`king.pillar_of_the_crown` wants level 25
//  AND a tier-6 bag), and an array says that without a nested `all` union that
//  every other row would pay for.
//
//  `KingConditionDTO` is a tagged union on the wire, the same shape as
//  `QuestObjectiveDTO` and `ItemEffectDTO`: a `kind` discriminator plus the
//  fields that kind uses. Decoding an unknown kind FAILS rather than
//  defaulting, because a silently dropped condition would turn a decree into
//  one that completes itself.
//
//  Name and description keys derive from the id (`king.<id>.name` / `.desc`),
//  so they are not written into the file — and they are NOT required by the
//  validator yet: nothing renders them until the palace screen lands. The
//  `requireKey` call belongs in the same commit as the screen that reads it.
//

import Foundation

/// One thing a decree asks for. `kind` discriminates; the other fields belong
/// to it.
public struct KingConditionDTO: Codable, Sendable, Equatable {
    public enum Kind: String, Codable, Sendable, CaseIterable {
        /// Deepest kilometre reached on a single expedition, banked on arrival.
        case reachKm = "reach_km"
        /// Beasts defeated, counted from the moment the decree opens — the
        /// prologue dog does not backfill it.
        case beastKills = "beast_kills"
        /// Player level. `target` must equal the decree's own `level`.
        case playerLevel = "player_level"
        /// Estate tier reached (2…7).
        case estateTier = "estate_tier"
        /// Tier of the equipped class weapon (2…5).
        case weaponTier = "weapon_tier"
        /// Bag tier (2…6).
        case bagTier = "bag_tier"
        /// Units held IN THE WAREHOUSE, not the bag. Deliberately not the
        /// combined pool every upgrade service reads: the first of these sits
        /// at level 3 and its job is to teach that the warehouse exists.
        case warehouseMaterials = "warehouse_materials"
        /// Arrived in the capital at least once.
        case arriveCapital = "arrive_capital"
        /// Sold anything to the Trader.
        case sellToTrader = "sell_to_trader"
        /// Turned in any NPC's daily job.
        case finishNpcQuest = "finish_npc_quest"
        /// Cooked any dish.
        case cookDish = "cook_dish"
        /// Crafted anything in the workshop.
        case craftAny = "craft_any"
        /// Sent a passive expedition.
        case sendPassive = "send_passive"
        /// Claimed a plot. `plotType` narrows it to one kind when set.
        case claimPlot = "claim_plot"
        /// Harvested a plot.
        case harvestPlot = "harvest_plot"
        /// Learned any combat technique.
        case learnTechnique = "learn_technique"
        /// Won an arena duel.
        case winDuel = "win_duel"
    }

    public let kind: Kind
    /// Counted kinds only — km, kills, level, tier.
    public let target: Int?
    /// `warehouse_materials` only.
    public let materials: [MaterialCostDTO]
    /// `claim_plot` only; nil means any plot type.
    public let plotType: String?

    public init(kind: Kind, target: Int? = nil,
                materials: [MaterialCostDTO] = [], plotType: String? = nil) {
        self.kind = kind
        self.target = target
        self.materials = materials
        self.plotType = plotType
    }

    /// The kinds that carry a `target`; everything else is a one-shot event.
    public static let countedKinds: Set<Kind> = [
        .reachKm, .beastKills, .playerLevel, .estateTier, .weaponTier, .bagTier
    ]

    private enum CodingKeys: String, CodingKey { case kind, target, materials, plotType }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        kind      = try c.decode(Kind.self, forKey: .kind)
        target    = try c.decodeIfPresent(Int.self, forKey: .target)
        materials = try c.decodeIfPresent([MaterialCostDTO].self, forKey: .materials) ?? []
        plotType  = try c.decodeIfPresent(String.self, forKey: .plotType)
    }

    /// Writes only the half that belongs to `kind`, so an `arrive_capital` row
    /// carries no null target and a `reach_km` row no empty materials array.
    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(kind, forKey: .kind)
        if Self.countedKinds.contains(kind) { try c.encodeIfPresent(target, forKey: .target) }
        if kind == .warehouseMaterials { try c.encode(materials, forKey: .materials) }
        if kind == .claimPlot { try c.encodeIfPresent(plotType, forKey: .plotType) }
    }
}

/// What the King hands over. Food is a named item and a count rather than an
/// abstract "portions" number: a dish is worth anywhere from 10 to 72 Vigor,
/// so an unnamed portion cannot be added up — which is exactly how the design
/// draft ended up with a total nobody could measure.
public struct KingFoodRewardDTO: Codable, Sendable, Equatable {
    public let itemId: String
    public let quantity: Int

    public init(itemId: String, quantity: Int) {
        self.itemId = itemId
        self.quantity = quantity
    }
}

public struct KingRewardDTO: Codable, Sendable, Equatable {
    /// Paid at the decree's own level and CLAMPED to the pool by whoever grants
    /// it (`min(maxVigor, vigor + reward)`), which is why the validator refuses
    /// a decree paying more Vigor than the pool at its level can hold.
    public let vigor: Int
    public let silver: Int
    public let xp: Int
    public let food: KingFoodRewardDTO?

    public init(vigor: Int = 0, silver: Int = 0, xp: Int = 0, food: KingFoodRewardDTO? = nil) {
        self.vigor = vigor
        self.silver = silver
        self.xp = xp
        self.food = food
    }

    /// Every decree pays something — the owner's call on 2026-09-21, after the
    /// reward-less level steps turned out to be screens the player would have
    /// to tap through for nothing. Enforced by the validator, not by hope.
    public var isEmpty: Bool { vigor == 0 && silver == 0 && xp == 0 && (food?.quantity ?? 0) == 0 }

    private enum CodingKeys: String, CodingKey { case vigor, silver, xp, food }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        vigor  = try c.decodeIfPresent(Int.self, forKey: .vigor)  ?? 0
        silver = try c.decodeIfPresent(Int.self, forKey: .silver) ?? 0
        xp     = try c.decodeIfPresent(Int.self, forKey: .xp)     ?? 0
        food   = try c.decodeIfPresent(KingFoodRewardDTO.self, forKey: .food)
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        if vigor  != 0 { try c.encode(vigor,  forKey: .vigor) }
        if silver != 0 { try c.encode(silver, forKey: .silver) }
        if xp     != 0 { try c.encode(xp,     forKey: .xp) }
        try c.encodeIfPresent(food, forKey: .food)
    }
}

public struct KingDecreeDTO: Codable, Sendable, Equatable {
    public let id: String
    /// The level the decree is expected at. Drives the Vigor ceiling and the
    /// spec table; for a `player_level` decree it must equal that target.
    public let level: Int
    /// ALL must hold. See the file header for why this is an array.
    public let conditions: [KingConditionDTO]
    public let reward: KingRewardDTO

    public init(id: String, level: Int, conditions: [KingConditionDTO], reward: KingRewardDTO) {
        self.id = id
        self.level = level
        self.conditions = conditions
        self.reward = reward
    }

    /// Derived, never authored — see the file header.
    public var isLevelDecree: Bool { conditions.contains { $0.kind == .playerLevel } }

    private enum CodingKeys: String, CodingKey { case id, level, conditions, reward }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id         = try c.decode(String.self, forKey: .id)
        level      = try c.decode(Int.self, forKey: .level)
        conditions = try c.decode([KingConditionDTO].self, forKey: .conditions)
        reward     = try c.decode(KingRewardDTO.self, forKey: .reward)
    }
}

/// Top-level shape of `king.json`.
public struct KingFileDTO: Codable, Sendable {
    /// ORDER IS GAMEPLAY — see the file header.
    public let decrees: [KingDecreeDTO]

    public init(decrees: [KingDecreeDTO]) {
        self.decrees = decrees
    }

    private enum CodingKeys: String, CodingKey { case decrees }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        decrees = try c.decode([KingDecreeDTO].self, forKey: .decrees)
    }
}
