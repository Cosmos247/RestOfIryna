//
//  SetDTO.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 30.08.2026.
//
//  Wire format for `content/data/sets.json` — equipment sets and the bonuses
//  they grant at 2 / 4 / 6 equipped pieces.
//
//  A set bonus is EXTRA budget, granted for the cost of giving up slot freedom.
//  That makes it a third power axis beside item level and rarity, so it is
//  bounded the same way they are: the validator caps a set's total bonus
//  against the combined budget of its own members. Unbounded, "wear all four"
//  quietly becomes the only correct answer to every slot decision.
//

import Foundation

/// What a threshold grants.
///
/// A closed enum rather than a bag of optional fields, so the v1 vocabulary —
/// flat stats and a multiplier on the wearer's gear — can grow to "chance on
/// hit", "technique discount" or "loot multiplier" by adding a case that every
/// consumer is then forced to handle.
public enum SetBonusEffectDTO: Codable, Sendable, Equatable {
    /// Straight addition to the wearer's gear totals.
    case flatStats(GearStatsDTO)
    /// Scales the wearer's whole gear contribution. Applied in the second pass,
    /// AFTER every flat bonus, so two sets cannot multiply each other's flats
    /// in whichever order the rows happened to be written.
    case gearMultiplier(Double)

    public enum Kind: String, Codable, Sendable {
        case flatStats = "flat_stats"
        case gearMultiplier = "gear_multiplier"
    }

    public var kind: Kind {
        switch self {
        case .flatStats: return .flatStats
        case .gearMultiplier: return .gearMultiplier
        }
    }

    private enum CodingKeys: String, CodingKey { case kind, stats, multiplier }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        switch try c.decode(Kind.self, forKey: .kind) {
        case .flatStats:
            self = .flatStats(try c.decode(GearStatsDTO.self, forKey: .stats))
        case .gearMultiplier:
            self = .gearMultiplier(try c.decode(Double.self, forKey: .multiplier))
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(kind, forKey: .kind)
        switch self {
        case .flatStats(let stats): try c.encode(stats, forKey: .stats)
        case .gearMultiplier(let m): try c.encode(m, forKey: .multiplier)
        }
    }
}

/// One threshold: "at N equipped pieces, this."
public struct SetBonusDTO: Codable, Sendable, Equatable {
    public let pieces: Int
    public let effect: SetBonusEffectDTO

    public init(pieces: Int, effect: SetBonusEffectDTO) {
        self.pieces = pieces
        self.effect = effect
    }

    private enum CodingKeys: String, CodingKey { case pieces, effect }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        pieces = try c.decode(Int.self, forKey: .pieces)
        effect = try c.decode(SetBonusEffectDTO.self, forKey: .effect)
    }
}

public struct GearSetDTO: Codable, Sendable, Equatable {
    public let id: String
    /// Thresholds, ascending. Every threshold at or below the equipped count
    /// applies, so a 4-piece wearer gets the 2-piece bonus as well.
    public let bonuses: [SetBonusDTO]
    public let nameKeyOverride: String?

    /// Ids are already namespaced (`set.forester`), so the id IS the locale key
    /// — the same derivation enemies use.
    public var nameKey: String { nameKeyOverride ?? id }

    public init(id: String, bonuses: [SetBonusDTO], nameKeyOverride: String? = nil) {
        self.id = id
        self.bonuses = bonuses
        self.nameKeyOverride = nameKeyOverride
    }

    private enum CodingKeys: String, CodingKey {
        case id, bonuses
        case nameKeyOverride = "nameKey"
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id              = try c.decode(String.self, forKey: .id)
        bonuses         = try c.decode([SetBonusDTO].self, forKey: .bonuses)
        nameKeyOverride = try c.decodeIfPresent(String.self, forKey: .nameKeyOverride)
    }
}

/// Top-level shape of `sets.json`.
public struct SetFileDTO: Codable, Sendable {
    public let sets: [GearSetDTO]

    public init(sets: [GearSetDTO]) { self.sets = sets }

    private enum CodingKeys: String, CodingKey { case sets }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        sets = try c.decode([GearSetDTO].self, forKey: .sets)
    }
}
