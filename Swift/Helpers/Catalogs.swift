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
//  sites read. `GameData` keeps the DTO snapshot beside it.
//
//  NOTE — `GameData.current` (the DTO snapshot) and `Catalogs.current` (the
//  domain one) are installed together, from one bundle, in one call, because
//  that is the only thing that stops them drifting. Phase 7 gave the DTO
//  snapshot its first real reader: `/content` reports what is actually loaded,
//  and `ContentBootstrap.reload` swaps both or neither.
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
    let enemyArchetypes: [EnemyArchetype: EnemyArchetypeSpec]

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
    let masterEnchantBudgetFraction: Double
    let masterEnchantSteps: [MasterCatalog.EnchantStep]

    let plotIcons: [PlotType: String]
    let plotTunings: [PlotType: PlotTuning]

    let fortuneDrawPrice: Int
    let fortuneBuffDurationSeconds: TimeInterval
    let fortuneCooldownSeconds: TimeInterval
    let fortuneCards: [FortuneCard]
    let fortuneCardsById: [String: FortuneCard]

    // Phase 4 — the six balance tables.
    //
    // The flat scalar sections are kept as their DTOs (the DTO IS the domain
    // shape; a mirror struct would only copy fields across, as with market /
    // guild / arena). The per-class and per-kind rows get parsed into
    // dictionaries keyed by the domain enums, because that parse is where an
    // unknown class string becomes a thrown error instead of a silently absent
    // row — and because doing it once here keeps the accessors on the combat
    // hot path free of string comparison.
    let tuningCombat: CombatTuningDTO
    let tuningVigor: VigorTuningDTO
    let tuningExploration: ExplorationTuningDTO
    let tuningProgression: ProgressionTuningDTO
    let tuningEconomy: EconomyTuningDTO
    let tuningTime: TimeTuningDTO
    /// How many times faster than real life the game runs. Every `gameTime`
    /// duration is divided by it; nothing in `realTime` ever is.
    var timeScale: Double { tuningTime.scale }

    let techniqueTuning: [CombatService.TechniqueKind: TechniqueTuningDTO]
    let stanceById: [String: StanceTuningDTO]
    let stanceIdByClass: [CharacterClass: String]
    let specialAttackByClass: [CharacterClass: SpecialAttackTuningDTO]
    let specialDefenseVigorByClass: [CharacterClass: Int]
    let fleeByClass: [CharacterClass: FleeTuningDTO]
    let classStarts: [CharacterClass: ClassStartDTO]

    /// Phase 6. The DTOs ARE the domain shape here — a set is a list of
    /// thresholds and a rarity is four scalars, so a mirror type would only
    /// copy fields across (same reasoning as market / guild / arena).
    let rarities: [RarityDTO]
    let raritiesById: [String: RarityDTO]
    let gearSets: [GearSetDTO]
    let budget: BudgetTuningDTO
    let slotWeights: [String: Double]
    /// Keyed by class raw value. `referenceGear` scanned `classProfiles` with a
    /// linear `first(where:)`; the simulator asks for a profile once per cell
    /// of its sweep, so the scan became a lookup rather than staying a scan.
    let classBudgetProfiles: [String: ClassBudgetProfileDTO]

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
              let quests = content.quests, let tuning = content.tuning,
              let budget = content.budget else {
            throw ContentMappingError.incompleteBundle(missing: [
                content.trader  == nil ? "trader.json"  : nil,
                content.tavern  == nil ? "tavern.json"  : nil,
                content.market  == nil ? "market.json"  : nil,
                content.guild   == nil ? "guild.json"   : nil,
                content.arena   == nil ? "arena.json"   : nil,
                content.master  == nil ? "master.json"  : nil,
                content.plots   == nil ? "plots.json"   : nil,
                content.fortune == nil ? "fortune.json" : nil,
                content.quests  == nil ? "quests.json"  : nil,
                content.tuning  == nil ? "tuning/*.json" : nil,
                content.budget  == nil ? "tuning/budget.json" : nil
            ].compactMap { $0 })
        }

        // Declaration order is preserved end to end: `EnemyCatalog.pickFor`
        // selects with `filter().randomElement()`, so the order of `enemies`
        // decides which enemy a given roll returns.
        self.items = try content.items.map { try $0.toDomain() }
        // The archetype table is built FIRST: each enemy resolves its default
        // spawn weight from it, so a roster row that omits the field inherits
        // its archetype's rarity rather than a hardcoded 1.
        var archetypes: [EnemyArchetype: EnemyArchetypeSpec] = [:]
        for row in content.enemyArchetypes {
            guard let kind = EnemyArchetype(rawValue: row.id) else {
                throw ContentMappingError.unknownEnemyArchetype(row.id, id: "archetypes")
            }
            archetypes[kind] = EnemyArchetypeSpec(
                archetype: kind, rounds: row.rounds, hpLossPercent: row.hpLossPercent,
                mitigationPercent: row.mitigationPercent, dodgePercent: row.dodgePercent,
                critPercent: row.critPercent, xpMultiplier: row.xpMultiplier,
                lootMultiplier: row.lootMultiplier, spawnWeight: row.spawnWeight)
        }
        for kind in EnemyArchetype.allCases where archetypes[kind] == nil {
            throw ContentMappingError.tuningRowMissing("archetype \(kind.rawValue)", table: "enemies.json")
        }
        self.enemyArchetypes = archetypes

        self.enemies = try content.enemies.map { dto in
            let kind = EnemyArchetype(rawValue: dto.archetype)
            let fallback = kind.flatMap { archetypes[$0]?.spawnWeight } ?? 1
            return try dto.toDomain(defaultSpawnWeight: fallback)
        }
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
        self.masterEnchantBudgetFraction = master.enchantBudgetFractionPerLevel
        self.masterEnchantSteps = master.enchantSteps.map(\.domain)

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

        // MARK: Phase 6 — budget, rarity, sets
        self.rarities = content.rarities
        self.raritiesById = Dictionary(content.rarities.map { ($0.id, $0) },
                                       uniquingKeysWith: { first, _ in first })
        self.gearSets = content.gearSets
        self.budget = budget
        self.slotWeights = Dictionary(budget.slotWeights.map { ($0.slot, $0.weight) },
                                      uniquingKeysWith: { first, _ in first })
        // First-wins, matching the `first(where:)` this replaces. The validator
        // rejects a duplicated class profile, so it only decides behaviour on a
        // bundle that never reaches install.
        self.classBudgetProfiles = Dictionary(budget.classProfiles.map { ($0.characterClass, $0) },
                                              uniquingKeysWith: { first, _ in first })
        // Every item's rarity must resolve. `Item.rarity` is non-optional and
        // the glyph lookup is non-throwing, so an unknown id would have to be
        // papered over at the point it is drawn.
        for item in items where raritiesById[item.rarity] == nil {
            throw ContentMappingError.tuningRowMissing("rarity \(item.rarity) for \(item.id)",
                                                       table: "rarities.json")
        }

        // MARK: Phase 4 tuning
        self.tuningCombat      = tuning.combat
        self.tuningVigor       = tuning.vigor
        self.tuningExploration = tuning.exploration
        self.tuningProgression = tuning.progression
        self.tuningEconomy     = tuning.economy
        self.tuningTime        = tuning.time

        var techniques: [CombatService.TechniqueKind: TechniqueTuningDTO] = [:]
        for row in tuning.combat.techniques {
            guard let kind = CombatService.TechniqueKind(rawValue: row.kind) else {
                throw ContentMappingError.unknownTechniqueKind(row.kind)
            }
            techniques[kind] = row
        }
        self.techniqueTuning = techniques

        var stances: [String: StanceTuningDTO] = [:]
        var stanceIds: [CharacterClass: String] = [:]
        for row in tuning.combat.stances.byId {
            guard let cls = CharacterClass(rawValue: row.characterClass) else {
                throw ContentMappingError.unknownCharacterClass(row.characterClass, table: "combat.json")
            }
            stances[row.id] = row
            stanceIds[cls] = row.id
        }
        self.stanceById = stances
        self.stanceIdByClass = stanceIds

        var attacks: [CharacterClass: SpecialAttackTuningDTO] = [:]
        for row in tuning.combat.specialAttack {
            guard let cls = CharacterClass(rawValue: row.characterClass) else {
                throw ContentMappingError.unknownCharacterClass(row.characterClass, table: "combat.json")
            }
            attacks[cls] = row
        }
        self.specialAttackByClass = attacks

        var defenses: [CharacterClass: Int] = [:]
        for row in tuning.combat.specialDefense.byClass {
            guard let cls = CharacterClass(rawValue: row.characterClass) else {
                throw ContentMappingError.unknownCharacterClass(row.characterClass, table: "combat.json")
            }
            defenses[cls] = row.vigor
        }
        self.specialDefenseVigorByClass = defenses

        var flees: [CharacterClass: FleeTuningDTO] = [:]
        for row in tuning.combat.flee {
            guard let cls = CharacterClass(rawValue: row.characterClass) else {
                throw ContentMappingError.unknownCharacterClass(row.characterClass, table: "combat.json")
            }
            flees[cls] = row
        }
        self.fleeByClass = flees

        var starts: [CharacterClass: ClassStartDTO] = [:]
        for row in tuning.progression.classes {
            guard let cls = CharacterClass(rawValue: row.characterClass) else {
                throw ContentMappingError.unknownCharacterClass(row.characterClass, table: "progression.json")
            }
            starts[cls] = row
        }
        self.classStarts = starts

        // Every class must have a row in all five per-class tables. Checked
        // HERE and not only in the validator because these accessors are
        // non-optional and non-throwing at the call site — `fleeChance(forClass:)`
        // has nowhere to report a missing row, so it would have to invent a
        // number, and inventing one is how a balance hole ships unnoticed.
        for cls in CharacterClass.allCases {
            if stanceIds[cls] == nil {
                throw ContentMappingError.tuningRowMissing("stance for \(cls.rawValue)", table: "combat.json")
            }
            if attacks[cls] == nil {
                throw ContentMappingError.tuningRowMissing("specialAttack for \(cls.rawValue)", table: "combat.json")
            }
            if defenses[cls] == nil {
                throw ContentMappingError.tuningRowMissing("specialDefense for \(cls.rawValue)", table: "combat.json")
            }
            if flees[cls] == nil {
                throw ContentMappingError.tuningRowMissing("flee for \(cls.rawValue)", table: "combat.json")
            }
            if starts[cls] == nil {
                throw ContentMappingError.tuningRowMissing("class start for \(cls.rawValue)", table: "progression.json")
            }
        }
        for kind in CombatService.TechniqueKind.allCases where techniques[kind] == nil {
            throw ContentMappingError.tuningRowMissing("technique \(kind.rawValue)", table: "combat.json")
        }
    }
}

extension DomainContent {
    /// Non-optional read of a tuning row that `DomainContent.init` already
    /// proved present.
    ///
    /// Unreachable by construction — but a named trap beats a bare `!`, and it
    /// beats a `?? 0` by much more than that: the accessors this backs are
    /// non-throwing, so a defaulted zero would not report anywhere. A missing
    /// technique row silently unlocking every technique at level 0 is a worse
    /// outcome than a crash on a bundle that should never have installed.
    func required<T>(_ value: T?, _ what: @autoclosure () -> String) -> T {
        guard let value else {
            fatalError("tuning row missing after install: \(what()) — DomainContent.init should have refused this bundle")
        }
        return value
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
