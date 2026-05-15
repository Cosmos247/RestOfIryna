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

public enum EnemyCatalog {
    // Tiers map to 5-km depth bands:
    //   T1 = km 1–5  · T2 = km 6–10 · T3 = km 11–15 · T4 = km 16–20 ·
    //   T5 = km 21–30 · T6 = km 26–35
    // Each animal spans 1–2 consecutive bands via `depthRange`. Three deep
    // overlaps stack: rabid_wolf (16–25) ↔ wild_bear (21–30) ↔ rabid_bear
    // (25–35), giving each transition zone a mix of two species.
    //
    // Two families:
    //   - Wild (🐗 🫎 🦬 🐻): killable + cookable; drop raw meat + hide.
    //   - Rabid (🐈‍⬛ 🐺 🐻‍❄️): dangerous; meat is poisoned by disease, so
    //     loot tables only include hide.
    //
    // Stats scale weakest → strongest in this order:
    //   wild_boar → wild_moose → wild_buffalo → rabid_lynx → rabid_wolf →
    //   wild_bear → rabid_bear.
    public static let all: [Enemy] = [
        // Wild Boar — first big game (T1–T2). Reliable meat + hide source.
        Enemy(
            id: "enemy.wild_boar",
            nameKey: "enemy.wild_boar",
            tier: 1, hp: 18, attack: 14, defense: 1,
            depthRange: 1...10,
            lootTable: [
                EnemyLootDrop(itemId: "food.raw_meat", chance: 0.7, quantity: 1),
                EnemyLootDrop(itemId: "mat.hide",      chance: 0.8, quantity: 1)
            ],
            icon: "🐗",
            xpReward: 5
        ),
        // Wild Moose — tier 2–3 forest mid-game.
        Enemy(
            id: "enemy.wild_moose",
            nameKey: "enemy.wild_moose",
            tier: 2, hp: 32, attack: 18, defense: 2,
            depthRange: 6...15,
            lootTable: [
                EnemyLootDrop(itemId: "food.raw_meat", chance: 0.8, quantity: 2),
                EnemyLootDrop(itemId: "mat.hide",      chance: 0.7, quantity: 1)
            ],
            icon: "🫎",
            xpReward: 12
        ),
        // Wild Buffalo — tier 3–4 heavy game, high defense.
        Enemy(
            id: "enemy.wild_buffalo",
            nameKey: "enemy.wild_buffalo",
            tier: 3, hp: 55, attack: 23, defense: 4,
            depthRange: 11...20,
            lootTable: [
                EnemyLootDrop(itemId: "food.raw_meat", chance: 0.8, quantity: 2),
                EnemyLootDrop(itemId: "mat.hide",      chance: 0.9, quantity: 1)
            ],
            icon: "🦬",
            xpReward: 25
        ),
        // Rabid Lynx — tier 3–4 fast predator. Meat inedible (rabies).
        Enemy(
            id: "enemy.rabid_lynx",
            nameKey: "enemy.rabid_lynx",
            tier: 3, hp: 45, attack: 25, defense: 2,
            depthRange: 11...20,
            lootTable: [
                EnemyLootDrop(itemId: "mat.hide", chance: 0.7, quantity: 1)
            ],
            icon: "🐈‍⬛",
            xpReward: 25
        ),
        // Rabid Wolf — tier 4 top hostile. Meat inedible (rabies).
        // Range extended to km 16–25 so the rabid family bleeds into the T5
        // band, overlapping with wild_bear at 21–25.
        Enemy(
            id: "enemy.rabid_wolf",
            nameKey: "enemy.rabid_wolf",
            tier: 4, hp: 70, attack: 28, defense: 4,
            depthRange: 16...25,
            lootTable: [
                EnemyLootDrop(itemId: "mat.hide", chance: 0.8, quantity: 1)
            ],
            icon: "🐺",
            xpReward: 50
        ),
        // Wild Bear — tier 5 deep-wilderness mob. Master of the forest:
        // huge HP pool, hard-hitting, but a wild animal — drops meat + hide.
        // Range km 21–30; the first 5 km (21–25) overlap with rabid_wolf,
        // the deeper 5 km (26–30) overlap with rabid_bear. The dedicated
        // boss for the deep wilderness is reserved for Phase 3.5 once the
        // boss-fight mechanics are designed.
        Enemy(
            id: "enemy.wild_bear",
            nameKey: "enemy.wild_bear",
            tier: 5, hp: 95, attack: 32, defense: 5,
            depthRange: 21...30,
            lootTable: [
                EnemyLootDrop(itemId: "food.raw_meat", chance: 0.85, quantity: 2),
                EnemyLootDrop(itemId: "mat.hide",      chance: 0.9,  quantity: 1)
            ],
            icon: "🐻",
            xpReward: 100
        ),
        // Training Dummy — Phase 5.1 estate-side training plot. ATK = 0 so
        // it never deals damage in return; DEF = 1 so the player sees a
        // non-trivial damage number (vs. exactly the raw ATK). HP is set
        // generously and CombatController auto-revives the dummy when it
        // hits 0 — training is meant to be open-ended, not a fight to win.
        // No depthRange (this enemy is never rolled by exploration), no loot.
        Enemy(
            id: "enemy.training_dummy",
            nameKey: "enemy.training_dummy",
            tier: 0, hp: 200, attack: 0, defense: 1,
            depthRange: 0...0,
            lootTable: [],
            icon: "🥋",
            xpReward: 0
        ),
        // Rabid Bear — tier 6 deepest hostile. Beastfever has bleached the
        // fur and stripped the discipline; what's left is a hard-hitting
        // monster that follows the rabid family pattern (high ATK, lower
        // DEF, hide-only loot since the meat is plague-tainted). Range
        // km 25–35: overlaps with wild_bear at 25–30 and reigns alone at
        // 31–35.
        Enemy(
            id: "enemy.rabid_bear",
            nameKey: "enemy.rabid_bear",
            tier: 6, hp: 120, attack: 38, defense: 4,
            depthRange: 25...35,
            lootTable: [
                EnemyLootDrop(itemId: "mat.hide", chance: 0.9, quantity: 2)
            ],
            icon: "🐻‍❄️",
            xpReward: 175
        ),
    ]

    public static func pickFor(kmDepth: Int) -> Enemy? {
        let eligible = all.filter { $0.depthRange.contains(max(1, kmDepth)) }
        return eligible.randomElement() ?? all.first
    }

    /// Look up an enemy by id. Used by CombatController to rehydrate the
    /// fight from the persisted `combat_enemy_id` between taps.
    public static func find(_ id: String) -> Enemy? {
        return all.first(where: { $0.id == id })
    }
}
