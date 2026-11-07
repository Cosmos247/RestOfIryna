//
//  ZoneDTO.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 31.08.2026.
//
//  Foraging by depth band. Until Phase 8E these three pools were Swift arrays
//  inside `ExplorationService.rollLoot` — the last content left in code after
//  Phase 3 emptied every catalog — and the reason they moved is that Vigor
//  stopped regenerating: what the trail hands out is now part of the food
//  economy, not decoration between fights.
//
//  Weights are RELATIVE inside a zone and the order is part of the contract:
//  the roll walks the array subtracting weights, so a reordered pool changes
//  every seeded draw while leaving each entry byte-identical. The loader never
//  sorts, and the digest replays the roll.
//

import Foundation

public struct ForageEntryDTO: Codable, Sendable, Equatable {
    public let itemId: String
    /// Relative chance inside the zone. Higher is commoner; `mat.iron` sits at
    /// a fifth of the staples, which is what makes it read as a find.
    public let weight: Int

    public init(itemId: String, weight: Int) {
        self.itemId = itemId
        self.weight = weight
    }

    private enum CodingKeys: String, CodingKey { case itemId, weight }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        itemId = try c.decode(String.self, forKey: .itemId)
        weight = try c.decode(Int.self, forKey: .weight)
    }
}

public struct ZoneDTO: Codable, Sendable, Equatable {
    public let id: String
    /// Kilometres this zone covers, inclusive at both ends.
    public let depth: IntRangeDTO
    public let forage: [ForageEntryDTO]
    /// This pool also answers for every km past the forest's horizon
    /// (`ForestHorizon`). Absent means false; exactly one zone should carry it.
    public let beyondHorizon: Bool

    public init(id: String, depth: IntRangeDTO, forage: [ForageEntryDTO],
                beyondHorizon: Bool = false) {
        self.id = id
        self.depth = depth
        self.forage = forage
        self.beyondHorizon = beyondHorizon
    }

    private enum CodingKeys: String, CodingKey { case id, depth, forage, beyondHorizon }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id     = try c.decode(String.self, forKey: .id)
        depth  = try c.decode(IntRangeDTO.self, forKey: .depth)
        forage = try c.decode([ForageEntryDTO].self, forKey: .forage)
        beyondHorizon = try c.decodeIfPresent(Bool.self, forKey: .beyondHorizon) ?? false
    }
}

/// Top-level shape of `zones.json`.
public struct ZoneFileDTO: Codable, Sendable {
    public let zones: [ZoneDTO]
    /// The plants a step's herb event picks from (2026-11-05, `spec-bestiary.md`
    /// §16): one pool for the whole forest, weights relative, the order part of
    /// the contract exactly as in a zone's `forage`. Absent means none — and
    /// the validator refuses a bundle whose weights roll the event anyway.
    public let herbs: [ForageEntryDTO]

    public init(zones: [ZoneDTO] = [], herbs: [ForageEntryDTO] = []) {
        self.zones = zones
        self.herbs = herbs
    }

    private enum CodingKeys: String, CodingKey { case zones, herbs }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        zones = try c.decode([ZoneDTO].self, forKey: .zones)
        herbs = try c.decodeIfPresent([ForageEntryDTO].self, forKey: .herbs) ?? []
    }
}
