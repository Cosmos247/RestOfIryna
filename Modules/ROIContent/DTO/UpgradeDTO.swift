//
//  UpgradeDTO.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 29.08.2026.
//
//  Wire format for `content/data/bags.json` and `content/data/estate_upgrades.json`.
//
//  Both ladders share the same shape as the weapon ladder — a list of steps,
//  each naming the tier it leads TO plus its material cost — so they share one
//  cost record. Steps are ordered by `toTier`, and the validator checks that
//  the order is contiguous rather than trusting it.
//

import Foundation

/// A material requirement. Identical shape across every ladder in the game, so
/// one type serves them all; `WeaponUpgradeInputDTO` is an alias kept for
/// readability at the weapon call sites.
public struct MaterialCostDTO: Codable, Sendable, Equatable {
    public let itemId: String
    public let quantity: Int

    public init(itemId: String, quantity: Int) {
        self.itemId = itemId
        self.quantity = quantity
    }
}

// MARK: - Bag

public struct BagUpgradeStepDTO: Codable, Sendable, Equatable {
    public let toTier: Int
    public let capacity: Int
    public let requiredEstateLevel: Int
    public let inputs: [MaterialCostDTO]

    public init(toTier: Int, capacity: Int, requiredEstateLevel: Int, inputs: [MaterialCostDTO] = []) {
        self.toTier = toTier
        self.capacity = capacity
        self.requiredEstateLevel = requiredEstateLevel
        self.inputs = inputs
    }

    private enum CodingKeys: String, CodingKey { case toTier, capacity, requiredEstateLevel, inputs }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        toTier              = try c.decode(Int.self, forKey: .toTier)
        capacity            = try c.decode(Int.self, forKey: .capacity)
        requiredEstateLevel = try c.decode(Int.self, forKey: .requiredEstateLevel)
        inputs              = try c.decodeIfPresent([MaterialCostDTO].self, forKey: .inputs) ?? []
    }
}

/// Top-level shape of `bags.json`.
public struct BagFileDTO: Codable, Sendable {
    public let maxTier: Int
    /// Capacity per tier, index 0 = T1. Kept alongside the ladder because
    /// `BagCatalog.capForTier` reads it directly for the CURRENT tier, while
    /// the ladder only describes upgrades.
    public let capacities: [Int]
    public let progression: [BagUpgradeStepDTO]

    public init(maxTier: Int, capacities: [Int], progression: [BagUpgradeStepDTO]) {
        self.maxTier = maxTier
        self.capacities = capacities
        self.progression = progression
    }
}

// MARK: - Estate

public struct EstateUpgradeStepDTO: Codable, Sendable, Equatable {
    public let toTier: Int
    public let requiredPlayerLevel: Int
    public let silverCost: Int
    public let inputs: [MaterialCostDTO]

    public init(toTier: Int, requiredPlayerLevel: Int, silverCost: Int = 0, inputs: [MaterialCostDTO] = []) {
        self.toTier = toTier
        self.requiredPlayerLevel = requiredPlayerLevel
        self.silverCost = silverCost
        self.inputs = inputs
    }

    private enum CodingKeys: String, CodingKey { case toTier, requiredPlayerLevel, silverCost, inputs }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        toTier              = try c.decode(Int.self, forKey: .toTier)
        requiredPlayerLevel = try c.decode(Int.self, forKey: .requiredPlayerLevel)
        silverCost          = try c.decodeIfPresent(Int.self, forKey: .silverCost) ?? 0
        inputs              = try c.decodeIfPresent([MaterialCostDTO].self, forKey: .inputs) ?? []
    }
}

/// Top-level shape of `estate_upgrades.json`.
public struct EstateUpgradeFileDTO: Codable, Sendable {
    public let maxTier: Int
    /// Plot slots unlocked at each estate tier, indexed by `tier - 1`.
    ///
    /// Data since Phase 8E, and not for tidiness: with Vigor no longer
    /// regenerating, these slots ARE the daily budget, so the balance report
    /// has to read the same ladder the game grants from. Tier 1 has none — the
    /// wooden hut has cleared no land — which is why the first days are lived
    /// off the trail rather than off the estate.
    public let plotSlotsByTier: [Int]
    public let progression: [EstateUpgradeStepDTO]

    public init(maxTier: Int, plotSlotsByTier: [Int], progression: [EstateUpgradeStepDTO]) {
        self.maxTier = maxTier
        self.plotSlotsByTier = plotSlotsByTier
        self.progression = progression
    }

    private enum CodingKeys: String, CodingKey { case maxTier, plotSlotsByTier, progression }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        maxTier         = try c.decode(Int.self, forKey: .maxTier)
        plotSlotsByTier = try c.decode([Int].self, forKey: .plotSlotsByTier)
        progression     = try c.decode([EstateUpgradeStepDTO].self, forKey: .progression)
    }
}
