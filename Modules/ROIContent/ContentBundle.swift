//
//  ContentBundle.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 29.08.2026.
//
//  A decoded-but-not-yet-validated content directory. Everything the loader
//  produces lands here first; only after `ContentValidator` passes does it get
//  turned into a `GameContent` snapshot. Keeping the two apart is what lets the
//  validator report on data that the domain types would trap on.
//

import Foundation

public struct ContentBundle: Sendable {
    public let manifest: ManifestDTO
    public let items: [ItemDTO]
    public let enemies: [EnemyDTO]
    public let recipes: [RecipeDTO]
    public let starterRecipeIds: [String]
    public let weaponLadders: [WeaponLadderDTO]
    public let weaponDurabilityByTier: [Int]
    /// FNV-1a over the concatenated raw bytes of every file, in load order.
    /// Printed at boot and by `/content` so a running bot can be matched to a
    /// checkout without guessing.
    public let contentHash: String

    public init(
        manifest: ManifestDTO,
        items: [ItemDTO],
        enemies: [EnemyDTO],
        recipes: [RecipeDTO],
        starterRecipeIds: [String],
        weaponLadders: [WeaponLadderDTO] = [],
        weaponDurabilityByTier: [Int] = [],
        contentHash: String
    ) {
        self.manifest = manifest
        self.items = items
        self.enemies = enemies
        self.recipes = recipes
        self.starterRecipeIds = starterRecipeIds
        self.weaponLadders = weaponLadders
        self.weaponDurabilityByTier = weaponDurabilityByTier
        self.contentHash = contentHash
    }

    public var summaryLine: String {
        let version = manifest.contentVersion.map { " · \($0)" } ?? ""
        return "schema v\(manifest.schemaVersion)\(version) · hash \(contentHash) · "
            + "\(items.count) items · \(enemies.count) enemies · \(recipes.count) recipes · "
            + "\(weaponLadders.count) ladders · "
            + "timeScale \(manifest.timeScale)"
    }
}
