//
//  ContentMapping.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 29.08.2026.
//
//  Domain ⇄ DTO mapping for the content pipeline.
//
//  Lives in the main target because the domain types (`Item`, `Enemy`,
//  `Recipe`) still live in `Swift/Models/`. Both directions are written now,
//  not just the export direction: the migration proof requires
//  `domain → DTO → JSON → DTO → domain → DTO → JSON` to be byte-stable, which
//  is only meaningful if the DTO can actually rebuild the domain value. Phase 2
//  then reuses `toDomain()` verbatim when the catalogs become façades.
//
//  Locale keys are deliberately NOT written when they equal what the DTO would
//  derive (`item.<id>` / `item.<id>.desc` / the enemy's own id). All 33 items
//  and all 9 enemies match today — verified — so the export carries none of
//  them and stays free of 66 fields of duplication. An item whose key ever
//  diverges gets an explicit override written instead.
//

import Foundation

// MARK: - Errors

enum ContentMappingError: Error, CustomStringConvertible {
    case unknownItemType(String, id: String)
    case unknownSlot(String, id: String)
    case unknownRecipeCategory(String, id: String)
    case invalidDepthRange(min: Int, max: Int, id: String)
    case incompleteBundle(missing: [String])
    case unknownPlotType(String)
    case unknownQuestNPC(String)
    case unknownQuestCounter(String, id: String)

    var description: String {
        switch self {
        case .unknownItemType(let value, let id): return "\(id): unknown item type \"\(value)\""
        case .unknownSlot(let value, let id):     return "\(id): unknown equipment slot \"\(value)\""
        case .unknownRecipeCategory(let v, let id): return "\(id): unknown recipe category \"\(v)\""
        case .invalidDepthRange(let lo, let hi, let id): return "\(id): depth min \(lo) > max \(hi)"
        case .incompleteBundle(let missing):
            return "content bundle is missing: \(missing.joined(separator: ", "))"
        case .unknownPlotType(let value):   return "unknown plot type \"\(value)\""
        case .unknownQuestNPC(let value):   return "unknown quest NPC \"\(value)\""
        case .unknownQuestCounter(let v, let id): return "\(id): unknown quest counter \"\(v)\""
        }
    }
}

// MARK: - Item

extension ItemEffectDTO {
    init(_ effect: ItemEffect) {
        switch effect {
        case .restoreVigor(let amount): self.init(kind: .restoreVigor, amount: amount)
        case .restoreHP(let amount):    self.init(kind: .restoreHP, amount: amount)
        }
    }

    var domain: ItemEffect {
        switch kind {
        case .restoreVigor: return .restoreVigor(amount)
        case .restoreHP:    return .restoreHP(amount)
        }
    }
}

extension GearStatsDTO {
    init(_ stats: GearStats) {
        self.init(attack: stats.attack, defense: stats.defense,
                  crit: stats.crit, dodge: stats.dodge, accuracy: stats.accuracy)
    }

    var domain: GearStats {
        GearStats(attack: attack, defense: defense, crit: crit, dodge: dodge, accuracy: accuracy)
    }
}

extension ItemDTO {
    init(_ item: Item) {
        let derivedName = "item.\(item.id)"
        let nameOverride = item.nameKey == derivedName ? nil : item.nameKey

        // Three shipped items carry `descriptionKey: nil` on purpose
        // (potion.heal_small, potion.heal_medium, artifact.shrine_coin) —
        // `ItemDisplay.descriptionKey` returns nil and the UI shows a
        // placeholder. That has to survive the round-trip as an explicit null.
        let effectiveName = nameOverride ?? derivedName
        let derivedDesc = "\(effectiveName).desc"
        let suppresses = item.descriptionKey == nil
        let descOverride = (item.descriptionKey == derivedDesc) ? nil : item.descriptionKey

        self.init(
            id: item.id,
            type: item.type.rawValue,
            tier: item.tier,
            stackable: item.stackable,
            effects: item.effects.map(ItemEffectDTO.init),
            slot: item.slot?.rawValue,
            gearStats: item.gearStats.map(GearStatsDTO.init),
            icon: item.icon,
            teachesRecipe: item.teachesRecipe,
            nameKeyOverride: nameOverride,
            descriptionKeyOverride: descOverride,
            suppressesDescription: suppresses
        )
    }

    func toDomain() throws -> Item {
        guard let type = ItemType(rawValue: type) else {
            throw ContentMappingError.unknownItemType(self.type, id: id)
        }
        var equipSlot: EquipmentSlot?
        if let slot {
            guard let parsed = EquipmentSlot(rawValue: slot) else {
                throw ContentMappingError.unknownSlot(slot, id: id)
            }
            equipSlot = parsed
        }
        return Item(
            id: id,
            nameKey: nameKey,
            type: type,
            tier: tier,
            stackable: stackable,
            effects: effects.map(\.domain),
            slot: equipSlot,
            gearStats: gearStats?.domain,
            icon: icon,
            descriptionKey: descriptionKey,
            teachesRecipe: teachesRecipe
        )
    }
}

// MARK: - Enemy

extension EnemyDTO {
    init(_ enemy: Enemy) {
        // `depthRange` is exported verbatim, including the `0...0` sentinel on
        // the training dummy and the tutorial dog. `pickFor` calls
        // `max(1, km)`, so `0...0` can never match and `null` would be
        // behaviour-identical — but Phase 1 normalizes nothing, so that
        // cleanup gets its own visible commit later.
        self.init(
            id: enemy.id,
            tier: enemy.tier,
            icon: enemy.icon,
            xpReward: enemy.xpReward,
            stats: EnemyStatsDTO(hp: enemy.hp, attack: enemy.attack, defense: enemy.defense),
            depth: IntRangeDTO(min: enemy.depthRange.lowerBound, max: enemy.depthRange.upperBound),
            loot: enemy.lootTable.map {
                EnemyLootDropDTO(itemId: $0.itemId, chance: $0.chance, quantity: $0.quantity)
            },
            nameKeyOverride: enemy.nameKey == enemy.id ? nil : enemy.nameKey
        )
    }

    func toDomain() throws -> Enemy {
        guard let depth, let range = depth.closedRange else {
            throw ContentMappingError.invalidDepthRange(
                min: depth?.min ?? 0, max: depth?.max ?? 0, id: id)
        }
        return Enemy(
            id: id,
            nameKey: nameKey,
            tier: tier,
            hp: stats.hp,
            attack: stats.attack,
            defense: stats.defense,
            depthRange: range,
            lootTable: loot.map {
                EnemyLootDrop(itemId: $0.itemId, chance: $0.chance, quantity: $0.quantity)
            },
            icon: icon,
            xpReward: xpReward
        )
    }
}

// MARK: - Recipe

extension RecipeDTO {
    init(_ recipe: Recipe) {
        self.init(
            id: recipe.id,
            category: recipe.category.rawValue,
            inputs: recipe.inputs.map { RecipeIngredientDTO(itemId: $0.itemId, quantity: $0.quantity) },
            output: RecipeIngredientDTO(itemId: recipe.output.itemId, quantity: recipe.output.quantity)
        )
    }

    func toDomain() throws -> Recipe {
        guard let category = RecipeCategory(rawValue: category) else {
            throw ContentMappingError.unknownRecipeCategory(self.category, id: id)
        }
        return Recipe(
            id: id,
            category: category,
            inputs: inputs.map { RecipeIngredient($0.itemId, $0.quantity) },
            output: RecipeOutput(output.itemId, output.quantity)
        )
    }
}

// MARK: - Weapon ladders

extension WeaponUpgradeStepDTO {
    /// `tier` is derived from array position on export — the shipped catalog
    /// carries it nowhere else — and then checked against position on import,
    /// which is the whole point of writing it down.
    init(_ step: WeaponUpgradeStep, tier: Int) {
        self.init(
            tier: tier,
            stats: GearStatsDTO(step.stats),
            inputs: step.inputs.map { WeaponUpgradeInputDTO(itemId: $0.itemId, quantity: $0.quantity) }
        )
    }

    var domain: WeaponUpgradeStep {
        WeaponUpgradeStep(
            stats: stats.domain,
            inputs: inputs.map { WeaponUpgradeInput($0.itemId, $0.quantity) }
        )
    }
}

extension WeaponLadderDTO {
    init(itemId: String, steps: [WeaponUpgradeStep]) {
        self.init(
            itemId: itemId,
            tiers: steps.enumerated().map { WeaponUpgradeStepDTO($0.element, tier: $0.offset + 1) }
        )
    }

    var domainSteps: [WeaponUpgradeStep] { tiers.map(\.domain) }
}

// MARK: - Bag ladder

extension BagUpgradeStepDTO {
    init(_ step: BagUpgradeStep) {
        self.init(
            toTier: step.toTier,
            capacity: step.capacity,
            requiredEstateLevel: step.requiredEstateLevel,
            inputs: step.inputs.map { MaterialCostDTO(itemId: $0.itemId, quantity: $0.quantity) }
        )
    }

    var domain: BagUpgradeStep {
        BagUpgradeStep(
            toTier: toTier,
            capacity: capacity,
            requiredEstateLevel: requiredEstateLevel,
            inputs: inputs.map { BagUpgradeInput($0.itemId, $0.quantity) }
        )
    }
}

// MARK: - Estate ladder

extension EstateUpgradeStepDTO {
    init(_ step: EstateUpgradeStep) {
        self.init(
            toTier: step.toTier,
            requiredPlayerLevel: step.requiredPlayerLevel,
            silverCost: step.silverCost,
            inputs: step.inputs.map { MaterialCostDTO(itemId: $0.itemId, quantity: $0.quantity) }
        )
    }

    var domain: EstateUpgradeStep {
        EstateUpgradeStep(
            toTier: toTier,
            requiredPlayerLevel: requiredPlayerLevel,
            inputs: inputs.map { EstateUpgradeInput($0.itemId, $0.quantity) },
            silverCost: silverCost
        )
    }
}

// MARK: - Capital institutions
//
// Only the two RECORD catalogs need a mapper. `MarketCatalog`, `GuildCatalog`
// and the scalar half of `ArenaCatalog` are flat constants with no domain type
// of their own — nothing to parse, no range to build — so the exporter writes
// their DTOs directly and `DomainContent` stores those DTOs verbatim rather
// than inventing a mirror struct that would only ever copy fields across.

extension TraderListingDTO {
    init(_ listing: TraderListing) {
        self.init(
            itemId: listing.itemId,
            sellPacketQty: listing.sellPacketQty,
            sellPacketSilver: listing.sellPacketSilver,
            buyPacketQty: listing.buyPacketQty,
            buyPacketSilver: listing.buyPacketSilver
        )
    }

    var domain: TraderListing {
        TraderListing(
            itemId: itemId,
            sellPacketQty: sellPacketQty,
            sellPacketSilver: sellPacketSilver,
            buyPacketQty: buyPacketQty,
            buyPacketSilver: buyPacketSilver
        )
    }
}

extension TavernFoodDTO {
    init(_ listing: TavernFoodListing) {
        self.init(itemId: listing.itemId, priceSilver: listing.priceSilver)
    }

    var domain: TavernFoodListing {
        TavernFoodListing(itemId: itemId, priceSilver: priceSilver)
    }
}

// MARK: - Master

extension MasterArmorListingDTO {
    init(_ listing: MasterCatalog.ArmorListing) {
        self.init(itemId: listing.itemId, priceSilver: listing.priceSilver)
    }

    var domain: MasterCatalog.ArmorListing { MasterCatalog.ArmorListing(itemId, priceSilver) }
}

extension EnchantStepDTO {
    init(_ step: MasterCatalog.EnchantStep) {
        self.init(level: step.level, silver: step.silver,
                  materialId: step.materialId, materialQty: step.materialQty)
    }

    var domain: MasterCatalog.EnchantStep {
        MasterCatalog.EnchantStep(level, silver, materialId, materialQty)
    }
}

// MARK: - Plot

extension PlotBonusOutputDTO {
    init(_ bonus: PlotBonusOutput) {
        self.init(producedItemId: bonus.producedItemId,
                  ratePerInterval: bonus.ratePerInterval, capacity: bonus.capacity)
    }

    var domain: PlotBonusOutput {
        PlotBonusOutput(producedItemId: producedItemId,
                        ratePerInterval: ratePerInterval, capacity: capacity)
    }
}

extension PlotTuningDTO {
    init(_ tuning: PlotTuning) {
        self.init(producedItemId: tuning.producedItemId,
                  ratePerInterval: tuning.ratePerInterval,
                  capacity: tuning.capacity,
                  bonusOutput: tuning.bonusOutput.map(PlotBonusOutputDTO.init))
    }

    var domain: PlotTuning {
        PlotTuning(producedItemId: producedItemId,
                   ratePerInterval: ratePerInterval,
                   capacity: capacity,
                   bonusOutput: bonusOutput?.domain)
    }
}

extension PlotTypeDTO {
    /// Domain side of a plot type is the enum itself; the row carries what
    /// hangs off it. Throws on a raw value `PlotType` cannot represent —
    /// a validator error too, so unreachable in a bundle that installs.
    func toPlotType() throws -> PlotType {
        guard let parsed = PlotType(rawValue: type) else {
            throw ContentMappingError.unknownPlotType(type)
        }
        return parsed
    }
}

// MARK: - Fortune

extension FortuneEffectDTO {
    init(_ effect: FortuneEffect) {
        self.init(
            attackBonus: effect.attackBonus,
            defenseBonus: effect.defenseBonus,
            critBonus: effect.critBonus,
            dodgeBonus: effect.dodgeBonus,
            accuracyBonus: effect.accuracyBonus,
            xpMultiplier: effect.xpMultiplier,
            lootChanceMultiplier: effect.lootChanceMultiplier,
            vigorDrainMultiplier: effect.vigorDrainMultiplier,
            oneShotSilver: effect.oneShotSilver,
            oneShotXpGain: effect.oneShotXpGain,
            oneShotHpRestore: effect.oneShotHpRestore,
            oneShotVigorRestore: effect.oneShotVigorRestore,
            randomSilverPositive: effect.randomSilverPositive,
            randomSilverNegative: effect.randomSilverNegative
        )
    }

    var domain: FortuneEffect {
        FortuneEffect(
            attackBonus: attackBonus,
            defenseBonus: defenseBonus,
            critBonus: critBonus,
            dodgeBonus: dodgeBonus,
            accuracyBonus: accuracyBonus,
            xpMultiplier: xpMultiplier,
            lootChanceMultiplier: lootChanceMultiplier,
            vigorDrainMultiplier: vigorDrainMultiplier,
            oneShotSilver: oneShotSilver,
            oneShotXpGain: oneShotXpGain,
            oneShotHpRestore: oneShotHpRestore,
            oneShotVigorRestore: oneShotVigorRestore,
            randomSilverPositive: randomSilverPositive,
            randomSilverNegative: randomSilverNegative
        )
    }
}

extension FortuneCardDTO {
    init(_ card: FortuneCard) {
        self.init(id: card.id, effect: FortuneEffectDTO(card.effect))
    }

    /// `FortuneCard.init` derives all three locale keys from the id, so the
    /// file carries none of them and they cannot drift from the convention.
    var domain: FortuneCard { FortuneCard(id: id, effect: effect.domain) }
}

// MARK: - Quest

extension QuestObjectiveDTO {
    init(_ objective: QuestObjective) {
        switch objective {
        case .deliver(let itemIds, let count):
            self.init(kind: .deliver, itemIds: itemIds, target: count)
        case .counter(let counter, let target):
            self.init(kind: .counter, counter: counter.rawValue, target: target)
        }
    }

    /// `questId` is only used to name the row in the error — the objective
    /// itself carries no id.
    func toDomain(questId: String) throws -> QuestObjective {
        switch kind {
        case .deliver:
            return .deliver(itemIds: itemIds, count: target)
        case .counter:
            guard let raw = counter, let parsed = QuestCounter(rawValue: raw) else {
                throw ContentMappingError.unknownQuestCounter(counter ?? "<missing>", id: questId)
            }
            return .counter(parsed, target: target)
        }
    }
}

extension QuestRewardDTO {
    init(_ reward: QuestReward) {
        self.init(silver: reward.silver, xp: reward.xp, vigor: reward.vigor)
    }

    var domain: QuestReward { QuestReward(silver: silver, xp: xp, vigor: vigor) }
}

extension QuestDefDTO {
    init(_ def: QuestDef) {
        self.init(id: def.id,
                  objective: QuestObjectiveDTO(def.objective),
                  reward: QuestRewardDTO(def.reward))
    }

    /// The NPC comes from the pool this row sits in, not from the row.
    func toDomain(npc: QuestNPC) throws -> QuestDef {
        QuestDef(id: id, npc: npc,
                 objective: try objective.toDomain(questId: id),
                 reward: reward.domain)
    }
}

extension QuestPoolDTO {
    init(npc: QuestNPC, quests: [QuestDef]) {
        self.init(npc: npc.rawValue, quests: quests.map(QuestDefDTO.init))
    }

    func toNPC() throws -> QuestNPC {
        guard let parsed = QuestNPC(rawValue: npc) else {
            throw ContentMappingError.unknownQuestNPC(npc)
        }
        return parsed
    }
}
