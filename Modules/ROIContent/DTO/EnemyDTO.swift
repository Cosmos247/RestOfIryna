//
//  EnemyDTO.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 29.08.2026.
//
//  Wire format for `content/data/enemies.json`.
//
//  Two shape decisions worth knowing:
//
//  1. `depth` is `{min, max}` and OPTIONAL. `ClosedRange` traps when
//     upperBound < lowerBound, so the range is validated as a pair and only
//     turned into a real range after it passes. `null` means "never rolled by
//     exploration" — self-documenting where the shipped roster used a `0...0`
//     sentinel for the training dummy and the tutorial dog.
//
//  2. `level` / `archetype` / `crit` / `dodge` / `accuracy` / `silverReward`
//     are the fields the shipped `Enemy` struct lacks. They are optional here
//     so the Phase 1 export of the current bestiary round-trips unchanged,
//     and become required once the generated table lands.
//

import Foundation

// MARK: - Int range

public struct IntRangeDTO: Codable, Sendable, Equatable {
    public let min: Int
    public let max: Int

    public init(min: Int, max: Int) {
        self.min = min
        self.max = max
    }

    /// `nil` when the pair is inverted. Callers must report rather than force.
    public var closedRange: ClosedRange<Int>? {
        min <= max ? min...max : nil
    }
}

// MARK: - Loot drop

public struct EnemyLootDropDTO: Codable, Sendable, Equatable {
    public let itemId: String
    public let chance: Double
    public let quantity: Int

    public init(itemId: String, chance: Double, quantity: Int = 1) {
        self.itemId = itemId
        self.chance = chance
        self.quantity = quantity
    }

    private enum CodingKeys: String, CodingKey { case itemId, chance, quantity }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        itemId   = try c.decode(String.self, forKey: .itemId)
        chance   = try c.decode(Double.self, forKey: .chance)
        quantity = try c.decodeIfPresent(Int.self, forKey: .quantity) ?? 1
    }
}

// MARK: - Combat stat block

public struct EnemyStatsDTO: Codable, Sendable, Equatable {
    public let hp: Int
    public let attack: Int
    public let defense: Int
    public let crit: Int
    public let dodge: Int
    public let accuracy: Int

    public init(hp: Int, attack: Int, defense: Int, crit: Int = 0, dodge: Int = 0, accuracy: Int = 0) {
        self.hp = hp
        self.attack = attack
        self.defense = defense
        self.crit = crit
        self.dodge = dodge
        self.accuracy = accuracy
    }

    private enum CodingKeys: String, CodingKey { case hp, attack, defense, crit, dodge, accuracy }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        hp       = try c.decode(Int.self, forKey: .hp)
        attack   = try c.decode(Int.self, forKey: .attack)
        defense  = try c.decode(Int.self, forKey: .defense)
        crit     = try c.decodeIfPresent(Int.self, forKey: .crit)     ?? 0
        dodge    = try c.decodeIfPresent(Int.self, forKey: .dodge)    ?? 0
        accuracy = try c.decodeIfPresent(Int.self, forKey: .accuracy) ?? 0
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(hp, forKey: .hp)
        try c.encode(attack, forKey: .attack)
        try c.encode(defense, forKey: .defense)
        if crit     != 0 { try c.encode(crit,     forKey: .crit) }
        if dodge    != 0 { try c.encode(dodge,    forKey: .dodge) }
        if accuracy != 0 { try c.encode(accuracy, forKey: .accuracy) }
    }
}

// MARK: - Enemy

public struct EnemyDTO: Codable, Sendable, Equatable {
    public let id: String
    public let tier: Int
    public let icon: String
    public let xpReward: Int
    public let stats: EnemyStatsDTO
    public let depth: IntRangeDTO?
    public let loot: [EnemyLootDropDTO]

    /// Phase 5 fields. Optional until the generated bestiary replaces the
    /// hand-authored roster.
    public let level: Int?
    public let archetype: String?
    public let family: String?
    public let silverReward: Int?
    public let spawnWeight: Double?

    public let nameKeyOverride: String?

    /// Every shipped enemy uses its own id as its locale key
    /// (`enemy.wild_boar` → `enemy.wild_boar`), verified across all 9 entries,
    /// so the id IS the key. No prefix surgery — string-stripping here would be
    /// a latent bug for any id containing the prefix twice.
    public var nameKey: String { nameKeyOverride ?? id }

    public init(
        id: String,
        tier: Int,
        icon: String,
        xpReward: Int,
        stats: EnemyStatsDTO,
        depth: IntRangeDTO? = nil,
        loot: [EnemyLootDropDTO] = [],
        level: Int? = nil,
        archetype: String? = nil,
        family: String? = nil,
        silverReward: Int? = nil,
        spawnWeight: Double? = nil,
        nameKeyOverride: String? = nil
    ) {
        self.id = id
        self.tier = tier
        self.icon = icon
        self.xpReward = xpReward
        self.stats = stats
        self.depth = depth
        self.loot = loot
        self.level = level
        self.archetype = archetype
        self.family = family
        self.silverReward = silverReward
        self.spawnWeight = spawnWeight
        self.nameKeyOverride = nameKeyOverride
    }

    private enum CodingKeys: String, CodingKey {
        case id, tier, icon, xpReward, stats, depth, loot
        case level, archetype, family, silverReward, spawnWeight
        case nameKeyOverride = "nameKey"
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id           = try c.decode(String.self, forKey: .id)
        tier         = try c.decodeIfPresent(Int.self, forKey: .tier) ?? 1
        icon         = try c.decode(String.self, forKey: .icon)
        xpReward     = try c.decodeIfPresent(Int.self, forKey: .xpReward) ?? 0
        stats        = try c.decode(EnemyStatsDTO.self, forKey: .stats)
        depth        = try c.decodeIfPresent(IntRangeDTO.self, forKey: .depth)
        loot         = try c.decodeIfPresent([EnemyLootDropDTO].self, forKey: .loot) ?? []
        level        = try c.decodeIfPresent(Int.self, forKey: .level)
        archetype    = try c.decodeIfPresent(String.self, forKey: .archetype)
        family       = try c.decodeIfPresent(String.self, forKey: .family)
        silverReward = try c.decodeIfPresent(Int.self, forKey: .silverReward)
        spawnWeight  = try c.decodeIfPresent(Double.self, forKey: .spawnWeight)
        nameKeyOverride = try c.decodeIfPresent(String.self, forKey: .nameKeyOverride)
    }
}

/// Top-level shape of `enemies.json`.
public struct EnemyFileDTO: Codable, Sendable {
    public let enemies: [EnemyDTO]
    public init(enemies: [EnemyDTO]) { self.enemies = enemies }
}
