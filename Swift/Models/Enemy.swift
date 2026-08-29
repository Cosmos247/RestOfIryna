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
//  Roster (2026-04-27): 7 animals across 6 tiers.
//   - Wild family (🐗 🫎 🦬 🐻): killable + cookable; drop raw meat + hide.
//   - Rabid family (🐈‍⬛ 🐺 🐻‍❄️): dangerous; meat is spoiled by the plague,
//     loot tables only yield hide.
//
//  Deep wilderness (km 21+) currently has only regular mobs — wild_bear at
//  21–30 and rabid_bear at 25–35. The dedicated boss encounter is reserved
//  for Phase 3.5 once the boss-fight mechanics are designed.
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

// MARK: - Enemy

public struct Enemy: Sendable {
    public let id: String
    public let nameKey: String
    public let tier: Int
    public let hp: Int
    public let attack: Int
    public let defense: Int
    /// km range at which this enemy can appear during exploration rolls.
    public let depthRange: ClosedRange<Int>
    public let lootTable: [EnemyLootDrop]
    public let icon: String
    /// XP awarded to the player on victory. Phase 5.3a tuning per tier:
    /// T1=5, T2=12, T3=25, T4=50, T5=100, T6=175. Training dummy = 0 (no
    /// progression from sparring).
    public let xpReward: Int

    public init(
        id: String,
        nameKey: String,
        tier: Int,
        hp: Int,
        attack: Int,
        defense: Int,
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
    public static func pickFor<G: RandomNumberGenerator>(kmDepth: Int, using generator: inout G) -> Enemy? {
        let eligible = all.filter { $0.depthRange.contains(max(1, kmDepth)) }
        return eligible.randomElement(using: &generator) ?? all.first
    }

    public static func find(_ id: String) -> Enemy? {
        return Catalogs.current.enemiesById[id]
    }
}
