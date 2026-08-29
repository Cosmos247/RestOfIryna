//
//  GameContent.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 29.08.2026.
//
//  The immutable, validated content snapshot every catalog façade reads.
//
//  A `final class` rather than a struct on purpose: installing a new snapshot
//  is then a single reference store, and a read copies a pointer instead of a
//  dozen arrays. Every lookup dictionary is built once here — never rebuilt
//  per call inside a lock.
//
//  Duplicate ids are tolerated at construction (last wins) because
//  `Dictionary(uniqueKeysWithValues:)` TRAPS on a duplicate, and once ids come
//  from JSON a copy-pasted id would crash the bot on first catalog access.
//  `ContentValidator` reports duplicates as errors, so a bundle carrying one
//  never reaches `install`.
//

import Foundation

public final class GameContent: Sendable {
    public let manifest: ManifestDTO
    public let contentHash: String
    public let summaryLine: String

    public let items: [ItemDTO]
    public let itemsById: [String: ItemDTO]
    public let itemsByType: [String: [ItemDTO]]

    public let enemies: [EnemyDTO]
    public let enemiesById: [String: EnemyDTO]

    public let recipes: [RecipeDTO]
    public let recipesById: [String: RecipeDTO]
    public let starterRecipeIds: Set<String>

    public init(_ bundle: ContentBundle) {
        self.manifest = bundle.manifest
        self.contentHash = bundle.contentHash
        self.summaryLine = bundle.summaryLine

        self.items = bundle.items
        self.itemsById = Dictionary(bundle.items.map { ($0.id, $0) }, uniquingKeysWith: { _, last in last })
        self.itemsByType = Dictionary(grouping: bundle.items, by: { $0.type })

        self.enemies = bundle.enemies
        self.enemiesById = Dictionary(bundle.enemies.map { ($0.id, $0) }, uniquingKeysWith: { _, last in last })

        self.recipes = bundle.recipes
        self.recipesById = Dictionary(bundle.recipes.map { ($0.id, $0) }, uniquingKeysWith: { _, last in last })
        self.starterRecipeIds = Set(bundle.starterRecipeIds)
    }
}
