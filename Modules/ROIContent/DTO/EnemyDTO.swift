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
//  2. `level` / `archetype` / `crit` / `dodge` / `accuracy` are the fields the
//     shipped `Enemy` struct lacked before Phase 5. `silverReward` was a third:
//     it was removed in Phase 8C along with the whole monster-coin mechanic,
//     so the only silver faucets are quests, the trader, the tavern, the
//     market and the arena — all of them player-facing systems with a sink
//     attached, which is what the mid-game economy needed and a coin drop
//     quietly worked against.
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

    /// Monster level. REQUIRED as of Phase 5: it feeds `levelDiff`, the XP
    /// multiplier and every generated stat, so a missing one cannot be allowed
    /// to fall back to `tier` — that fallback would look right and quietly
    /// misprice the whole encounter.
    public let level: Int
    /// One of the six design archetypes. REQUIRED for the same reason: it
    /// decides rounds-to-kill, danger per hit and all three reward multipliers.
    public let archetype: String
    /// Reserved for Phase 10's generated bestiary (wolf / undead / …), where it
    /// drives shared resistances and loot families. Nothing reads it yet.
    public let family: String?
    /// Relative spawn chance inside the depth band. Absent means "inherit the
    /// archetype's default", which is the common case: an enemy only carries
    /// its own weight when it is deliberately rarer or more common than its
    /// archetype.
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
        level: Int = 1,
        archetype: String = "normal",
        family: String? = nil,
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
        self.spawnWeight = spawnWeight
        self.nameKeyOverride = nameKeyOverride
    }

    private enum CodingKeys: String, CodingKey {
        case id, tier, icon, xpReward, stats, depth, loot
        case level, archetype, family, spawnWeight
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
        level        = try c.decode(Int.self, forKey: .level)
        archetype    = try c.decode(String.self, forKey: .archetype)
        family       = try c.decodeIfPresent(String.self, forKey: .family)
        spawnWeight  = try c.decodeIfPresent(Double.self, forKey: .spawnWeight)
        nameKeyOverride = try c.decodeIfPresent(String.self, forKey: .nameKeyOverride)
    }
}

/// One row of the archetype table — the design-time spec every enemy of that
/// archetype is generated from.
///
/// `rounds` and `hpLossPercent` are the two DANGER dials, and they are stated
/// rather than derived because the drafted spec got this backwards: fixing the
/// HP loss and letting rounds rise makes damage PER HIT fall, so the boss hit
/// softer than trash (4.5% vs 6.6% of max HP). Stating danger per encounter and
/// solving for stats keeps the per-hit ladder monotonic.
///
/// The three percentages are TARGETS, not ratings. The generator inverts the
/// diminishing-returns curve at the enemy's level to get the rating that yields
/// them, which is why an enemy's stored crit/dodge rating differs by level
/// while the archetype's feel does not.
public struct EnemyArchetypeDTO: Codable, Sendable, Equatable {
    public let id: String
    /// Target rounds-to-kill against a reference character of the same level.
    public let rounds: Double
    /// Share of the player's max HP the encounter is meant to cost. Above 100
    /// for a boss on purpose — that is what makes consumables a mechanic
    /// rather than a fallback.
    public let hpLossPercent: Double
    public let mitigationPercent: Double
    public let dodgePercent: Double
    public let critPercent: Double
    public let xpMultiplier: Double
    public let lootMultiplier: Double
    /// Default relative spawn chance for enemies of this archetype.
    public let spawnWeight: Double
    /// Lowest monster level an enemy of this archetype may be authored at.
    ///
    /// The plan calls for it on the elite: measured against an on-curve
    /// reference character, an elite is a 93–95% win for the mage with a p99
    /// HP loss of 100% — a death one fight in twenty, and a death here wipes
    /// the whole unequipped backpack. Below level 14 the player has no
    /// techniques at all (special attack unlocks at 8, defence at 11, the
    /// Super at 14), so the fight is the `basic` row with nothing to spend.
    ///
    /// Enemy stats are frozen at design time, so this is the only place the
    /// floor can be broken and the validator is the only thing that can catch
    /// it. It bites in Phase 10, when the generator fills the table.
    public let minLevel: Int

    public init(id: String, rounds: Double, hpLossPercent: Double,
                mitigationPercent: Double, dodgePercent: Double, critPercent: Double,
                xpMultiplier: Double, lootMultiplier: Double,
                spawnWeight: Double, minLevel: Int) {
        self.id = id
        self.rounds = rounds
        self.hpLossPercent = hpLossPercent
        self.mitigationPercent = mitigationPercent
        self.dodgePercent = dodgePercent
        self.critPercent = critPercent
        self.xpMultiplier = xpMultiplier
        self.lootMultiplier = lootMultiplier
        self.spawnWeight = spawnWeight
        self.minLevel = minLevel
    }

    private enum CodingKeys: String, CodingKey {
        case id, rounds, hpLossPercent, mitigationPercent, dodgePercent, critPercent
        case xpMultiplier, lootMultiplier, spawnWeight, minLevel
    }

    /// Every field required — this is a tuning row, not a record with optional
    /// trimmings, and a defaulted multiplier is a silent balance hole. That
    /// goes for `minLevel` too: defaulting it to 1 would quietly re-open the
    /// hole it exists to close.
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id                = try c.decode(String.self, forKey: .id)
        rounds            = try c.decode(Double.self, forKey: .rounds)
        hpLossPercent     = try c.decode(Double.self, forKey: .hpLossPercent)
        mitigationPercent = try c.decode(Double.self, forKey: .mitigationPercent)
        dodgePercent      = try c.decode(Double.self, forKey: .dodgePercent)
        critPercent       = try c.decode(Double.self, forKey: .critPercent)
        xpMultiplier      = try c.decode(Double.self, forKey: .xpMultiplier)
        lootMultiplier    = try c.decode(Double.self, forKey: .lootMultiplier)
        spawnWeight       = try c.decode(Double.self, forKey: .spawnWeight)
        minLevel          = try c.decode(Int.self, forKey: .minLevel)
    }
}

/// Top-level shape of `enemies.json`.
public struct EnemyFileDTO: Codable, Sendable {
    public let enemies: [EnemyDTO]
    /// The six archetypes. Lives beside the roster rather than in `tuning/`
    /// because it is bestiary DESIGN — the table the generator reads to emit
    /// these very enemies — not a knob the combat formula consumes.
    public let archetypes: [EnemyArchetypeDTO]

    public init(enemies: [EnemyDTO], archetypes: [EnemyArchetypeDTO] = []) {
        self.enemies = enemies
        self.archetypes = archetypes
    }

    private enum CodingKeys: String, CodingKey { case enemies, archetypes }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        enemies    = try c.decode([EnemyDTO].self, forKey: .enemies)
        archetypes = try c.decode([EnemyArchetypeDTO].self, forKey: .archetypes)
    }
}
