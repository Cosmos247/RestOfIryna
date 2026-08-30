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
    /// The six design archetypes from `enemies.json`. Empty only in a
    /// hand-built fixture; `DomainContent` refuses a bundle missing any of them.
    public let enemyArchetypes: [EnemyArchetypeDTO]
    public let recipes: [RecipeDTO]
    public let starterRecipeIds: [String]
    public let weaponLadders: [WeaponLadderDTO]
    public let weaponDurabilityByTier: [Int]
    public let bags: BagFileDTO
    public let estateUpgrades: EstateUpgradeFileDTO
    // The five capital institutions. Optional, unlike the ladders above, which
    // use an empty-array sentinel: `market.json` and `guild.json` are nothing
    // but scalars, so there is no array whose emptiness could mean "this test
    // fixture omitted the file" — and a zero `maxActiveLots` has to stay a
    // validation ERROR rather than double as an absence marker. `ContentLoader`
    // always supplies all five; nil only ever appears in a hand-built fixture.
    public let trader: TraderFileDTO?
    public let tavern: TavernFileDTO?
    public let market: MarketFileDTO?
    public let guild: GuildFileDTO?
    public let arena: ArenaFileDTO?
    // Batch C. Optional for the same reason as the five above.
    public let master: MasterFileDTO?
    public let plots: PlotFileDTO?
    public let fortune: FortuneFileDTO?
    public let quests: QuestFileDTO?
    /// Phase 4's six balance tables. Optional for the same reason as the files
    /// above — `ContentLoader` always supplies it, and `DomainContent` turns a
    /// nil into a thrown error rather than a game whose hit chance is zero.
    public let tuning: TuningBundleDTO?
    /// FNV-1a over the concatenated raw bytes of every file, in load order.
    /// Printed at boot and by `/content` so a running bot can be matched to a
    /// checkout without guessing.
    public let contentHash: String

    public init(
        manifest: ManifestDTO,
        items: [ItemDTO],
        enemies: [EnemyDTO],
        enemyArchetypes: [EnemyArchetypeDTO] = [],
        recipes: [RecipeDTO],
        starterRecipeIds: [String],
        weaponLadders: [WeaponLadderDTO] = [],
        weaponDurabilityByTier: [Int] = [],
        bags: BagFileDTO = BagFileDTO(maxTier: 0, capacities: [], progression: []),
        estateUpgrades: EstateUpgradeFileDTO = EstateUpgradeFileDTO(maxTier: 0, progression: []),
        trader: TraderFileDTO? = nil,
        tavern: TavernFileDTO? = nil,
        market: MarketFileDTO? = nil,
        guild: GuildFileDTO? = nil,
        arena: ArenaFileDTO? = nil,
        master: MasterFileDTO? = nil,
        plots: PlotFileDTO? = nil,
        fortune: FortuneFileDTO? = nil,
        quests: QuestFileDTO? = nil,
        tuning: TuningBundleDTO? = nil,
        contentHash: String
    ) {
        self.manifest = manifest
        self.items = items
        self.enemies = enemies
        self.enemyArchetypes = enemyArchetypes
        self.recipes = recipes
        self.starterRecipeIds = starterRecipeIds
        self.weaponLadders = weaponLadders
        self.weaponDurabilityByTier = weaponDurabilityByTier
        self.bags = bags
        self.estateUpgrades = estateUpgrades
        self.trader = trader
        self.tavern = tavern
        self.market = market
        self.guild = guild
        self.arena = arena
        self.master = master
        self.plots = plots
        self.fortune = fortune
        self.quests = quests
        self.tuning = tuning
        self.contentHash = contentHash
    }

    public var summaryLine: String {
        let version = manifest.contentVersion.map { " · \($0)" } ?? ""
        return "schema v\(manifest.schemaVersion)\(version) · hash \(contentHash) · "
            + "\(items.count) items · \(enemies.count) enemies · \(recipes.count) recipes · "
            + "\(weaponLadders.count) ladders · \(bags.progression.count) bag steps · "
            + "\(estateUpgrades.progression.count) estate steps · "
            + "\(trader?.listings.count ?? 0) trader rows · \(tavern?.food.count ?? 0) dishes · "
            + "\(arena?.leagues.count ?? 0) leagues · \(fortune?.cards.count ?? 0) cards · "
            + "\(quests?.pools.reduce(0) { $0 + $1.quests.count } ?? 0) quests · "
            + "timeScale \(tuning?.time.scale ?? 1.0)"
    }
}
