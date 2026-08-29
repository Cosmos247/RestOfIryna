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

    public let enemies: [EnemyDTO]
    public let enemiesById: [String: EnemyDTO]

    public let recipes: [RecipeDTO]
    public let recipesById: [String: RecipeDTO]
    public let starterRecipeIds: Set<String>

    public let weaponLaddersByItemId: [String: WeaponLadderDTO]
    public let weaponDurabilityByTier: [Int]

    public let bags: BagFileDTO
    public let estateUpgrades: EstateUpgradeFileDTO

    // Carried through as-is from the bundle. Optional for the same reason it is
    // optional there: only a hand-built fixture can omit them, and `DomainContent`
    // is where that becomes a thrown error rather than a silent zero.
    public let trader: TraderFileDTO?
    public let tavern: TavernFileDTO?
    public let market: MarketFileDTO?
    public let guild: GuildFileDTO?
    public let arena: ArenaFileDTO?

    public init(_ bundle: ContentBundle) {
        self.manifest = bundle.manifest
        self.contentHash = bundle.contentHash
        self.summaryLine = bundle.summaryLine

        self.items = bundle.items
        self.itemsById = Dictionary(bundle.items.map { ($0.id, $0) }, uniquingKeysWith: { _, last in last })

        self.enemies = bundle.enemies
        self.enemiesById = Dictionary(bundle.enemies.map { ($0.id, $0) }, uniquingKeysWith: { _, last in last })

        self.recipes = bundle.recipes
        self.recipesById = Dictionary(bundle.recipes.map { ($0.id, $0) }, uniquingKeysWith: { _, last in last })
        self.starterRecipeIds = Set(bundle.starterRecipeIds)
        self.weaponLaddersByItemId = Dictionary(
            bundle.weaponLadders.map { ($0.itemId, $0) }, uniquingKeysWith: { _, last in last })
        self.weaponDurabilityByTier = bundle.weaponDurabilityByTier
        self.bags = bundle.bags
        self.estateUpgrades = bundle.estateUpgrades
        self.trader = bundle.trader
        self.tavern = bundle.tavern
        self.market = bundle.market
        self.guild = bundle.guild
        self.arena = bundle.arena
    }
}
