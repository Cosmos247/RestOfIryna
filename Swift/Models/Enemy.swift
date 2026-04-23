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
//  Roster (2026-04-23): 5 animals across 4 tiers.
//   - Wild family (🐗 🫎 🦬): killable + cookable; drop raw meat + hide.
//   - Rabid family (🐈‍⬛ 🐺): dangerous; meat is spoiled by the plague,
//     loot tables only yield hide.
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

    public init(
        id: String,
        nameKey: String,
        tier: Int,
        hp: Int,
        attack: Int,
        defense: Int,
        depthRange: ClosedRange<Int>,
        lootTable: [EnemyLootDrop],
        icon: String
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
    }
}

// MARK: - Catalog

public enum EnemyCatalog {
    // Tiers map to 5-km depth bands:
    //   T1 = km 1–5  · T2 = km 6–10 · T3 = km 11–15 · T4 = km 16–20
    // Each animal spans 1–2 consecutive tiers via `depthRange`.
    //
    // Two families:
    //   - Wild (🐗 🫎 🦬): killable + cookable; drop raw meat + hide.
    //   - Rabid (🐈‍⬛ 🐺): dangerous; meat is poisoned by disease, so
    //     loot tables only include hide.
    //
    // Stats scale weakest → strongest in this order:
    //   wild_boar → wild_moose → wild_buffalo → rabid_lynx → rabid_wolf.
    public static let all: [Enemy] = [
        // Wild Boar — first big game (T1–T2). Reliable meat + hide source.
        Enemy(
            id: "enemy.wild_boar",
            nameKey: "enemy.wild_boar",
            tier: 1, hp: 18, attack: 5, defense: 1,
            depthRange: 1...10,
            lootTable: [
                EnemyLootDrop(itemId: "food.raw_meat", chance: 0.7, quantity: 1),
                EnemyLootDrop(itemId: "mat.hide",      chance: 0.8, quantity: 1)
            ],
            icon: "🐗"
        ),
        // Wild Moose — tier 2–3 forest mid-game.
        Enemy(
            id: "enemy.wild_moose",
            nameKey: "enemy.wild_moose",
            tier: 2, hp: 32, attack: 8, defense: 2,
            depthRange: 6...15,
            lootTable: [
                EnemyLootDrop(itemId: "food.raw_meat", chance: 0.8, quantity: 2),
                EnemyLootDrop(itemId: "mat.hide",      chance: 0.7, quantity: 1)
            ],
            icon: "🫎"
        ),
        // Wild Buffalo — tier 3–4 heavy game, high defense.
        Enemy(
            id: "enemy.wild_buffalo",
            nameKey: "enemy.wild_buffalo",
            tier: 3, hp: 55, attack: 11, defense: 4,
            depthRange: 11...20,
            lootTable: [
                EnemyLootDrop(itemId: "food.raw_meat", chance: 0.8, quantity: 2),
                EnemyLootDrop(itemId: "mat.hide",      chance: 0.9, quantity: 1)
            ],
            icon: "🦬"
        ),
        // Rabid Lynx — tier 3–4 fast predator. Meat inedible (rabies).
        Enemy(
            id: "enemy.rabid_lynx",
            nameKey: "enemy.rabid_lynx",
            tier: 3, hp: 45, attack: 13, defense: 2,
            depthRange: 11...20,
            lootTable: [
                EnemyLootDrop(itemId: "mat.hide", chance: 0.7, quantity: 1)
            ],
            icon: "🐈‍⬛"
        ),
        // Rabid Wolf — tier 4 top hostile. Meat inedible (rabies).
        Enemy(
            id: "enemy.rabid_wolf",
            nameKey: "enemy.rabid_wolf",
            tier: 4, hp: 70, attack: 15, defense: 4,
            depthRange: 16...20,
            lootTable: [
                EnemyLootDrop(itemId: "mat.hide", chance: 0.8, quantity: 1)
            ],
            icon: "🐺"
        ),
    ]

    public static func pickFor(kmDepth: Int) -> Enemy? {
        let eligible = all.filter { $0.depthRange.contains(max(1, kmDepth)) }
        return eligible.randomElement() ?? all.first
    }
}
