//
//  WeaponUpgradeDTO.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 29.08.2026.
//
//  Wire format for `content/data/weapon_upgrades.json`.
//
//  Modelled as an array of ladders with an EXPLICIT `tier` field on every step,
//  not a dictionary and not a bare array. The shipped
//  `WeaponUpgradeCatalog.progression` relies on "index 0 == T1" as a naked
//  convention; an inserted or dropped step would shift the whole ladder
//  silently. With the tier written down, the validator catches it.
//
//  Loaded in Phase 1 rather than Phase 3 because the localization rules cannot
//  be correct without it: `ItemDisplay.nameKey(for:tier:)` appends `.t<tier>`
//  for any item with a ladder, so the base `.desc` key of an upgradable weapon
//  is never resolved and must not be demanded.
//

import Foundation

/// Every ladder in the game costs materials in the same `{itemId, quantity}`
/// shape, so they share one record. The alias keeps the weapon call sites
/// reading naturally; the JSON is unchanged either way.
public typealias WeaponUpgradeInputDTO = MaterialCostDTO

public struct WeaponUpgradeStepDTO: Codable, Sendable, Equatable {
    public let tier: Int
    public let stats: GearStatsDTO
    /// Materials consumed to REACH this tier. Empty for T1 — the starter
    /// weapon is granted at registration.
    public let inputs: [WeaponUpgradeInputDTO]

    public init(tier: Int, stats: GearStatsDTO, inputs: [WeaponUpgradeInputDTO] = []) {
        self.tier = tier
        self.stats = stats
        self.inputs = inputs
    }

    private enum CodingKeys: String, CodingKey { case tier, stats, inputs }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        tier   = try c.decode(Int.self, forKey: .tier)
        stats  = try c.decode(GearStatsDTO.self, forKey: .stats)
        inputs = try c.decodeIfPresent([WeaponUpgradeInputDTO].self, forKey: .inputs) ?? []
    }
}

public struct WeaponLadderDTO: Codable, Sendable, Equatable {
    public let itemId: String
    public let tiers: [WeaponUpgradeStepDTO]

    public init(itemId: String, tiers: [WeaponUpgradeStepDTO]) {
        self.itemId = itemId
        self.tiers = tiers
    }
}

/// Top-level shape of `weapon_upgrades.json`.
public struct WeaponUpgradeFileDTO: Codable, Sendable {
    public let ladders: [WeaponLadderDTO]
    public let durabilityByTier: [Int]

    public init(ladders: [WeaponLadderDTO], durabilityByTier: [Int]) {
        self.ladders = ladders
        self.durabilityByTier = durabilityByTier
    }
}
