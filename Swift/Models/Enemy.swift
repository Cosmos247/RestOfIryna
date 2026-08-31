//
//  Enemy.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 21.04.2026.
//
//  Static bestiary, code-based like `ItemCatalog`. Enemies aren't persisted
//  per-instance anywhere — they're rolled on demand during exploration events
//  and resolved in a single autobattle pass. Real combat UI (Attack / Defend /
//  Auto) arrives in Phase 4; until then enemies die to the stub resolver in
//  `ExplorationService.resolveAutobattle`.
//
//  Since Phase 5 every stat below is GENERATED at design time from the enemy's
//  level and archetype, never hand-written: an enemy scaled to the player at
//  runtime would make each gear upgrade evaporate as it was equipped.
//
//  Roster (2026-04-27): 7 animals across 6 tiers.
//   - Wild family (🐗 🫎 🦬 🐻): killable + cookable; drop raw meat + hide.
//   - Rabid family (🐈‍⬛ 🐺 🐻‍❄️): dangerous; meat is spoiled by the plague,
//     loot tables only yield hide.
//
//  Deep wilderness (km 21+) currently has only wild_bear at 21–30 and
//  rabid_bear at 25–40, so everything past km 30 is a single elite. That is a
//  content gap Phase 10 fills, not a bug: the roster is honest about its edges
//  now that `pickFor` returns nil past coverage instead of quietly handing back
//  the first enemy in the file. No boss archetype has a member yet.
//

import Foundation

// MARK: - Loot drop

public struct EnemyLootDrop: Sendable {
    public let itemId: String
    public let chance: Double   // 0.0 ... 1.0
    public let quantity: Int

    public init(itemId: String, chance: Double, quantity: Int = 1) {
        self.itemId = itemId
        self.chance = chance
        self.quantity = quantity
    }
}

// MARK: - Archetype

/// The six design archetypes every enemy is generated from.
///
/// Stays in Swift rather than being a free string, for the same reason
/// `PlotType` does: the game branches on it, so an unrepresentable value has to
/// fail at load rather than at the first encounter. Unlike `PlotType` it is NOT
/// a database contract — nothing persists it — so renaming one is a content
/// migration, not a schema migration.
public enum EnemyArchetype: String, CaseIterable, Sendable {
    case trash
    case normal
    case skirmisher
    case brute
    case elite
    case boss
}

/// The design-time spec for an archetype. See `EnemyArchetypeDTO` for why
/// danger is stated per encounter and the three percentages are targets rather
/// than ratings.
public struct EnemyArchetypeSpec: Sendable {
    public let archetype: EnemyArchetype
    public let rounds: Double
    public let hpLossPercent: Double
    public let mitigationPercent: Double
    public let dodgePercent: Double
    public let critPercent: Double
    public let xpMultiplier: Double
    public let lootMultiplier: Double
    public let spawnWeight: Double
    /// Lowest monster level this archetype may be authored at. Enforced by the
    /// validator, not here: enemy stats are frozen at design time, so the only
    /// way to break the floor is to write the row.
    public let minLevel: Int

    public init(archetype: EnemyArchetype, rounds: Double, hpLossPercent: Double,
                mitigationPercent: Double, dodgePercent: Double, critPercent: Double,
                xpMultiplier: Double, lootMultiplier: Double,
                spawnWeight: Double, minLevel: Int) {
        self.archetype = archetype
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
}

// MARK: - Enemy

public struct Enemy: Sendable {
    public let id: String
    public let nameKey: String
    public let tier: Int
    public let hp: Int
    public let attack: Int
    public let defense: Int
    /// Combat ratings, fed through the same diminishing-returns curves as the
    /// player's. Before Phase 5 the enemy side of every roll passed literal
    /// `0/0/0`, which is why enemies never dodged, never crit and never missed.
    public let crit: Int
    public let dodge: Int
    public let accuracy: Int
    /// Monster level. Drives `levelDiff` on both damage and XP, so it is what
    /// makes out-levelling a zone feel like out-levelling a zone.
    public let level: Int
    public let archetype: EnemyArchetype
    /// Relative chance of being picked inside its depth band. Resolved at load
    /// from the archetype's default when the enemy does not state its own.
    public let spawnWeight: Double
    /// km range at which this enemy can appear during exploration rolls.
    public let depthRange: ClosedRange<Int>
    public let lootTable: [EnemyLootDrop]
    public let icon: String
    /// XP awarded to the player on victory, BEFORE the level-gap scaling in
    /// `User.xpFromKill`. Generated at design time from
    /// `round(mobXP.coefficient · level^mobXP.exponent · archetype.xpMultiplier)`,
    /// which is solved as a pair with the level curve — see `MobXPDTO`.
    /// The training dummy and the scripted registration dog award 0.
    public let xpReward: Int

    public init(
        id: String,
        nameKey: String,
        tier: Int,
        hp: Int,
        attack: Int,
        defense: Int,
        crit: Int = 0,
        dodge: Int = 0,
        accuracy: Int = 0,
        level: Int = 1,
        archetype: EnemyArchetype = .normal,
        spawnWeight: Double = 1,
        depthRange: ClosedRange<Int>,
        lootTable: [EnemyLootDrop],
        icon: String,
        xpReward: Int
    ) {
        self.id = id
        self.nameKey = nameKey
        self.tier = tier
        self.hp = hp
        self.attack = attack
        self.defense = defense
        self.crit = crit
        self.dodge = dodge
        self.accuracy = accuracy
        self.level = level
        self.archetype = archetype
        self.spawnWeight = spawnWeight
        self.depthRange = depthRange
        self.lootTable = lootTable
        self.icon = icon
        self.xpReward = xpReward
    }
}

// MARK: - Catalog

/// Façade over the live content snapshot. The bestiary now lives in
/// `content/data/enemies.json`.
public enum EnemyCatalog {
    public static var all: [Enemy] { Catalogs.current.enemies }

    /// Design spec for an archetype. Non-optional in practice — `DomainContent`
    /// refuses a bundle missing any of the six — but returned as an Optional so
    /// the digest can print a gap rather than trap on one.
    public static func archetype(_ kind: EnemyArchetype) -> EnemyArchetypeSpec? {
        Catalogs.current.enemyArchetypes[kind]
    }

    /// Roll an enemy for the given depth. Delegates to the seedable overload so
    /// there is exactly one selection implementation — a second copy would be
    /// free to drift from the one the migration digest and the simulator
    /// replay.
    public static func pickFor(kmDepth: Int) -> Enemy? {
        var generator = SystemRandomNumberGenerator()
        return pickFor(kmDepth: kmDepth, using: &generator)
    }

    /// Seedable variant used by the migration digest and, later, the balance
    /// simulator. Selection is `filter().randomElement(using:)`, so the
    /// DECLARATION ORDER of `all` decides which enemy a given roll returns — a
    /// reordered roster changes every encounter in the game even when every
    /// record stays byte-identical. That is why the loader never sorts.
    ///
    /// The `?? all.first` fallback is preserved deliberately: past km 35 no
    /// `depthRange` matches and every encounter becomes a wild boar. A real
    /// bug, listed for the Phase 5 combat rework — changing it here would make
    /// the migration non-neutral.
    /// Weighted roll among the enemies whose band covers `kmDepth`.
    ///
    /// Two changes from the shipped implementation, both deliberate:
    ///
    /// 1. **Weighted, not uniform.** `randomElement()` made an elite exactly as
    ///    common as trash inside the same band, so rarity could only be
    ///    expressed by not writing the enemy down.
    /// 2. **`nil` on a gap, not `all.first`.** The old tail returned the FIRST
    ///    enemy in the file whenever no band matched — so every encounter past
    ///    km 35 was a wild boar, forever, and the deepest content in the game
    ///    was also its easiest. `rollEncounter` already treats nil as "no
    ///    encounter", so the call site was written for the honest answer all
    ///    along. A gap in coverage is now a validator finding instead of a
    ///    silently wrong monster.
    public static func pickFor<G: RandomNumberGenerator>(kmDepth: Int, using generator: inout G) -> Enemy? {
        let eligible = all.filter { $0.depthRange.contains(max(1, kmDepth)) }
        guard !eligible.isEmpty else { return nil }
        let total = eligible.reduce(0.0) { $0 + max(0, $1.spawnWeight) }
        // Every candidate weighted 0 is a content error the validator reports;
        // falling back to a uniform draw keeps the band alive in the meantime
        // rather than silently emptying it.
        guard total > 0 else { return eligible.randomElement(using: &generator) }
        var roll = Double.random(in: 0..<total, using: &generator)
        for enemy in eligible {
            roll -= max(0, enemy.spawnWeight)
            if roll < 0 { return enemy }
        }
        // Unreachable except through floating-point drift at the very top of
        // the range; the last eligible enemy is the correct answer there.
        return eligible.last
    }

    public static func find(_ id: String) -> Enemy? {
        return Catalogs.current.enemiesById[id]
    }
}
