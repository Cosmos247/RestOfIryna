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
    public static let all: [Enemy] = [
        // Tier 1 — shallow forest (km 1–3)
        Enemy(
            id: "enemy.rabid_hare",
            nameKey: "enemy.rabid_hare",
            tier: 1, hp: 15, attack: 4, defense: 1,
            depthRange: 1...3,
            lootTable: [
                EnemyLootDrop(itemId: "mat.hide",   chance: 0.5),
                EnemyLootDrop(itemId: "food.berry", chance: 0.3)
            ],
            icon: "🐇"
        ),
        Enemy(
            id: "enemy.rabid_fox",
            nameKey: "enemy.rabid_fox",
            tier: 1, hp: 22, attack: 6, defense: 2,
            depthRange: 1...3,
            lootTable: [
                EnemyLootDrop(itemId: "mat.hide", chance: 0.7)
            ],
            icon: "🦊"
        ),
        // Tier 2 — deeper forest (km 3–6)
        Enemy(
            id: "enemy.rabid_wolf",
            nameKey: "enemy.rabid_wolf",
            tier: 2, hp: 35, attack: 10, defense: 3,
            depthRange: 3...6,
            lootTable: [
                EnemyLootDrop(itemId: "mat.hide",     chance: 0.8),
                EnemyLootDrop(itemId: "mat.iron_ore", chance: 0.2)
            ],
            icon: "🐺"
        ),
    ]

    public static func pickFor(kmDepth: Int) -> Enemy? {
        let eligible = all.filter { $0.depthRange.contains(max(1, kmDepth)) }
        return eligible.randomElement() ?? all.first
    }
}
