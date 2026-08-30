//
//  ContentMapping.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 29.08.2026.
//
//  DTO → domain mapping for the content pipeline. `DomainContent` calls these
//  once at boot to build the snapshot every catalog façade reads.
//
//  Lives in the main target because the domain types (`Item`, `Enemy`,
//  `Recipe`, `FortuneCard`, `QuestDef` …) live in `Swift/Models/`, so
//  `ROIContent` can only hold their DTOs.
//
//  **This file used to run both ways.** The domain → DTO direction existed for
//  `ContentExporter`, which dumped the still-compiled Swift catalogs to JSON so
//  each migration started from a provably neutral baseline; the export proof
//  needed `domain → DTO → JSON → DTO → domain → DTO → JSON` to be byte-stable,
//  which is only meaningful if a DTO can actually rebuild the domain value.
//  Phase 3 ended, the last Swift array went away, the exporter was deleted, and
//  those 21 initialisers became unreachable — removed 2026-08-29. Recover them
//  from git if content ever has to move from code to data again.
//
//  Locale keys are DERIVED, never carried: `item.<id>`, `<nameKey>.desc`, the
//  enemy's own id, `plot.type.<type>.name`, `fortune.card.<id>.*`,
//  `quest.<id>.title`. The DTOs compute them on decode and `ContentValidator`
//  demands each one exists in both locales, so a renamed id is caught rather
//  than rendered to the player as a raw key stem.
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
    case unknownEnemyArchetype(String, id: String)
    case unknownCharacterClass(String, table: String)
    case unknownTechniqueKind(String)
    case tuningRowMissing(String, table: String)

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
        case .unknownEnemyArchetype(let v, let id): return "\(id): unknown enemy archetype \"\(v)\""
        case .unknownCharacterClass(let v, let table):
            return "tuning/\(table): unknown character class \"\(v)\""
        case .unknownTechniqueKind(let v): return "tuning/combat.json: unknown technique kind \"\(v)\""
        case .tuningRowMissing(let what, let table):
            return "tuning/\(table): no row for \(what)"
        }
    }
}

// MARK: - Item

extension ItemEffectDTO {
    var domain: ItemEffect {
        switch kind {
        case .restoreVigor: return .restoreVigor(amount)
        case .restoreHP:    return .restoreHP(amount)
        }
    }
}

extension GearStatsDTO {
    var domain: GearStats {
        GearStats(attack: attack, defense: defense, crit: crit, dodge: dodge, accuracy: accuracy)
    }
}

extension ItemDTO {
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
    /// `defaultSpawnWeight` is the archetype's, supplied by the caller because
    /// the DTO cannot see the archetype table. An enemy that states its own
    /// weight overrides it; that is the whole meaning of the field being
    /// optional.
    func toDomain(defaultSpawnWeight: Double) throws -> Enemy {
        guard let depth, let range = depth.closedRange else {
            throw ContentMappingError.invalidDepthRange(
                min: depth?.min ?? 0, max: depth?.max ?? 0, id: id)
        }
        guard let kind = EnemyArchetype(rawValue: archetype) else {
            throw ContentMappingError.unknownEnemyArchetype(archetype, id: id)
        }
        return Enemy(
            id: id,
            nameKey: nameKey,
            tier: tier,
            hp: stats.hp,
            attack: stats.attack,
            defense: stats.defense,
            crit: stats.crit,
            dodge: stats.dodge,
            accuracy: stats.accuracy,
            level: level,
            archetype: kind,
            silverReward: silverReward ?? 0,
            spawnWeight: spawnWeight ?? defaultSpawnWeight,
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
    var domain: WeaponUpgradeStep {
        WeaponUpgradeStep(
            stats: stats.domain,
            inputs: inputs.map { WeaponUpgradeInput($0.itemId, $0.quantity) }
        )
    }
}

extension WeaponLadderDTO {
    var domainSteps: [WeaponUpgradeStep] { tiers.map(\.domain) }
}

// MARK: - Bag ladder

extension BagUpgradeStepDTO {
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
    var domain: TavernFoodListing {
        TavernFoodListing(itemId: itemId, priceSilver: priceSilver)
    }
}

// MARK: - Master

extension MasterArmorListingDTO {
    var domain: MasterCatalog.ArmorListing { MasterCatalog.ArmorListing(itemId, priceSilver) }
}

extension EnchantStepDTO {
    var domain: MasterCatalog.EnchantStep {
        MasterCatalog.EnchantStep(level, silver, materialId, materialQty)
    }
}

// MARK: - Plot

extension PlotBonusOutputDTO {
    var domain: PlotBonusOutput {
        PlotBonusOutput(producedItemId: producedItemId,
                        ratePerInterval: ratePerInterval, capacity: capacity)
    }
}

extension PlotTuningDTO {
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
    /// `FortuneCard.init` derives all three locale keys from the id, so the
    /// file carries none of them and they cannot drift from the convention.
    var domain: FortuneCard { FortuneCard(id: id, effect: effect.domain) }
}

// MARK: - Quest

extension QuestObjectiveDTO {
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
    var domain: QuestReward { QuestReward(silver: silver, xp: xp, vigor: vigor) }
}

extension QuestDefDTO {
    /// The NPC comes from the pool this row sits in, not from the row.
    func toDomain(npc: QuestNPC) throws -> QuestDef {
        QuestDef(id: id, npc: npc,
                 objective: try objective.toDomain(questId: id),
                 reward: reward.domain)
    }
}

extension QuestPoolDTO {
    func toNPC() throws -> QuestNPC {
        guard let parsed = QuestNPC(rawValue: npc) else {
            throw ContentMappingError.unknownQuestNPC(npc)
        }
        return parsed
    }
}
