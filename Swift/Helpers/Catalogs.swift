//
//  Catalogs.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 29.08.2026.
//
//  Live domain-side catalog snapshot. `ItemCatalog` / `EnemyCatalog` /
//  `RecipeCatalog` are thin façades over this; it is built once from the
//  validated `GameContent` (DTOs) at boot.
//
//  Why a SECOND snapshot next to `GameData`:
//  the domain types (`Item`, `Enemy`, `Recipe`) still live in the main target,
//  so `ROIContent` cannot hold them — it holds DTOs. Mapping DTO → domain on
//  every `ItemCatalog.find` would allocate on a path that runs inside combat
//  loops, so the mapping happens once here and the result is what the ~315 call
//  sites read. `GameData` keeps the DTO snapshot for the validator, `/content`
//  and (Phase 7) hot reload.
//
//  The two must never drift: `ContentBootstrap.load` is the ONLY place that
//  installs either, and it installs both from the same bundle in one call.
//
//  Same holder shape as `GameData`: `nonisolated(unsafe)` + `NSLock`, because
//  the façade accessors have to stay synchronous, non-throwing and nonisolated
//  for call sites like `EquipmentService.contributedStats`.
//

import Foundation

final class DomainContent: Sendable {
    let items: [Item]
    let itemsById: [String: Item]
    let itemsByType: [ItemType: [Item]]

    let enemies: [Enemy]
    let enemiesById: [String: Enemy]

    let recipes: [Recipe]
    let recipesById: [String: Recipe]
    let starterRecipeIds: Set<String>

    let weaponLadders: [String: [WeaponUpgradeStep]]
    let weaponDurabilityByTier: [Int]

    let bagMaxTier: Int
    let bagCapacities: [Int]
    let bagProgression: [BagUpgradeStep]

    let estateMaxTier: Int
    let estateProgression: [EstateUpgradeStep]

    // The capital institutions. Trader and tavern get mapped to their domain
    // types because controllers iterate them; market / guild / arena are flat
    // tuning constants with no parsing to do, so the DTO IS the domain shape
    // and a mirror struct would only copy fields across.
    let traderListings: [TraderListing]
    let traderListingsById: [String: TraderListing]
    let tavernFood: [TavernFoodListing]
    let tavernFoodById: [String: TavernFoodListing]
    let tavernWagerTiers: [Int]
    let market: MarketFileDTO
    let guild: GuildFileDTO
    let arena: ArenaFileDTO

    // Batch C. The two lookup dictionaries replace what used to be a linear
    // `first(where:)` and a `Dictionary(uniqueKeysWithValues:)` that TRAPPED on
    // a duplicate id; duplicates are now a validator error instead, so a
    // copy-pasted id reports rather than crashing the bot at first draw.
    let masterArmor: [MasterCatalog.ArmorListing]
    let masterArmorById: [String: MasterCatalog.ArmorListing]
    let masterRepairCostFraction: Double
    let masterEnchantCap: Int
    let masterEnchantPerLevelPoints: [Int]
    let masterEnchantSteps: [MasterCatalog.EnchantStep]

    let plotTestMode: Bool
    let plotIcons: [PlotType: String]
    let plotTunings: [PlotType: PlotTuning]

    let fortuneDrawPrice: Int
    let fortuneBuffDurationSeconds: TimeInterval
    let fortuneCooldownSeconds: TimeInterval
    let fortuneCards: [FortuneCard]
    let fortuneCardsById: [String: FortuneCard]

    let questPools: [QuestNPC: [QuestDef]]
    /// `QuestCatalog.find` used to scan an unordered dictionary of pools, so on
    /// a duplicate id its answer was whichever pool the hasher happened to
    /// visit first. Ids are unique, so no behaviour changes — but the lookup is
    /// now deterministic by construction rather than by luck.
    let questsById: [String: QuestDef]

    /// Throws when a DTO carries a value the domain enums can't represent
    /// (unknown item type, slot or recipe category), an inverted depth range, or
    /// a bundle missing one of the five capital files. All three are validator
    /// or loader errors too, so this should be unreachable in practice — but
    /// failing here is still better than trapping later.
    init(_ content: GameContent) throws {
        // `ContentLoader` always supplies all five; a nil here means a bundle
        // was hand-built without them, which must fail loudly rather than boot
        // a game whose guild cap is silently zero.
        guard let trader = content.trader, let tavern = content.tavern,
              let market = content.market, let guild = content.guild,
              let arena = content.arena, let master = content.master,
              let plots = content.plots, let fortune = content.fortune,
              let quests = content.quests else {
            throw ContentMappingError.incompleteBundle(missing: [
                content.trader  == nil ? "trader.json"  : nil,
                content.tavern  == nil ? "tavern.json"  : nil,
                content.market  == nil ? "market.json"  : nil,
                content.guild   == nil ? "guild.json"   : nil,
                content.arena   == nil ? "arena.json"   : nil,
                content.master  == nil ? "master.json"  : nil,
                content.plots   == nil ? "plots.json"   : nil,
                content.fortune == nil ? "fortune.json" : nil,
                content.quests  == nil ? "quests.json"  : nil
            ].compactMap { $0 })
        }

        // Declaration order is preserved end to end: `EnemyCatalog.pickFor`
        // selects with `filter().randomElement()`, so the order of `enemies`
        // decides which enemy a given roll returns.
        self.items = try content.items.map { try $0.toDomain() }
        self.enemies = try content.enemies.map { try $0.toDomain() }
        self.recipes = try content.recipes.map { try $0.toDomain() }

        // `uniquingKeysWith:` rather than `uniqueKeysWithValues:` — the latter
        // TRAPS on a duplicate id, and ids now come from a file. Duplicates are
        // a validator error, so a bundle carrying one never reaches install.
        self.itemsById = Dictionary(items.map { ($0.id, $0) }, uniquingKeysWith: { _, last in last })
        self.itemsByType = Dictionary(grouping: items, by: \.type)
        self.enemiesById = Dictionary(enemies.map { ($0.id, $0) }, uniquingKeysWith: { _, last in last })
        self.recipesById = Dictionary(recipes.map { ($0.id, $0) }, uniquingKeysWith: { _, last in last })
        self.starterRecipeIds = content.starterRecipeIds

        self.weaponLadders = Dictionary(
            content.weaponLaddersByItemId.map { ($0.key, $0.value.domainSteps) },
            uniquingKeysWith: { _, last in last })
        self.weaponDurabilityByTier = content.weaponDurabilityByTier

        self.bagMaxTier = content.bags.maxTier
        self.bagCapacities = content.bags.capacities
        // Sorted by `toTier`: `BagCatalog.nextStep` indexes `progression[tier - 2]`,
        // so a shuffled file would hand out the wrong upgrade. The validator
        // rejects a non-contiguous ladder outright; sorting here means a merge
        // that only reorders cannot break the game in the meantime.
        self.bagProgression = content.bags.progression.sorted { $0.toTier < $1.toTier }.map(\.domain)

        self.estateMaxTier = content.estateUpgrades.maxTier
        self.estateProgression = content.estateUpgrades.progression.sorted { $0.toTier < $1.toTier }.map(\.domain)

        // NOT sorted: both arrays are the order the player scrolls through in
        // the shop and the tavern menu.
        self.traderListings = trader.listings.map(\.domain)
        self.tavernFood = tavern.food.map(\.domain)
        // `uniquingKeysWith: { first, _ in first }`, not `{ _, last in last }`.
        // The shipped lookups were `all.first { $0.itemId == itemId }`, which
        // returns the FIRST match — keeping last would quietly change which row
        // a duplicated id resolves to. Duplicates are a validator error, so this
        // only decides behaviour on a bundle that never reaches install; the
        // point is that the migration changes nothing, not even in the corner.
        self.traderListingsById = Dictionary(traderListings.map { ($0.itemId, $0) },
                                             uniquingKeysWith: { first, _ in first })
        self.tavernFoodById = Dictionary(tavernFood.map { ($0.itemId, $0) },
                                         uniquingKeysWith: { first, _ in first })
        self.tavernWagerTiers = tavern.wagerTiers
        self.market = market
        self.guild = guild
        self.arena = arena

        // Shop order is display order — ascending by price — so no sort here.
        self.masterArmor = master.armorForSale.map(\.domain)
        // First-wins, matching the `armorForSale.first(where:)` it replaces.
        self.masterArmorById = Dictionary(masterArmor.map { ($0.itemId, $0) },
                                          uniquingKeysWith: { first, _ in first })
        self.masterRepairCostFraction = master.repairCostFraction
        self.masterEnchantCap = master.enchantCap
        self.masterEnchantPerLevelPoints = master.enchantPerLevelPoints
        self.masterEnchantSteps = master.enchantSteps.map(\.domain)

        self.plotTestMode = plots.testMode
        // Built by parsing each row's `type`. A raw value the enum cannot
        // represent throws — a validator error too, so unreachable on install.
        var icons: [PlotType: String] = [:]
        var tunings: [PlotType: PlotTuning] = [:]
        for row in plots.types {
            let type = try row.toPlotType()
            icons[type] = row.icon
            // Absent stays absent: `tuning(for:)` returning nil is how the
            // estate controller knows to open a training fight instead of a
            // harvest, so `training_ground` must NOT gain an entry here.
            if let tuning = row.tuning { tunings[type] = tuning.domain }
        }
        self.plotIcons = icons
        self.plotTunings = tunings

        self.fortuneDrawPrice = fortune.drawPrice
        self.fortuneBuffDurationSeconds = fortune.buffDurationSeconds
        self.fortuneCooldownSeconds = fortune.cooldownSeconds
        // Deck order decides which card a given `randomElement()` roll returns.
        self.fortuneCards = fortune.cards.map(\.domain)
        self.fortuneCardsById = Dictionary(fortuneCards.map { ($0.id, $0) },
                                           uniquingKeysWith: { _, last in last })

        // Pool ORDER is the daily assignment (`pool[hash % count]`), so the
        // rows are taken exactly as written.
        var pools: [QuestNPC: [QuestDef]] = [:]
        for pool in quests.pools {
            let npc = try pool.toNPC()
            pools[npc] = try pool.quests.map { try $0.toDomain(npc: npc) }
        }
        self.questPools = pools
        self.questsById = Dictionary(pools.values.flatMap { $0 }.map { ($0.id, $0) },
                                     uniquingKeysWith: { _, last in last })
    }
}

enum Catalogs {
    private nonisolated(unsafe) static var _current: DomainContent?
    private static let lock = NSLock()

    static var current: DomainContent {
        lock.lock()
        defer { lock.unlock() }
        guard let content = _current else {
            fatalError("Catalog read before ContentBootstrap.load — check ordering in configure.swift")
        }
        return content
    }


    static func install(_ content: DomainContent) {
        lock.lock()
        _current = content
        lock.unlock()
    }
}
