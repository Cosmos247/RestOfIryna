//
//  FoodBudgetTests.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 31.08.2026.
//
//  Phase 8E. With Vigor no longer regenerating, `FoodBudget` decides the pace
//  number the whole report ends on — so the parts of it that could be quietly
//  wrong are pinned here.
//
//  The load-bearing one is `testTheEstateOptimiserPrefersTheBetterMix`: the
//  model claims to find the BEST estate rather than assume a layout, and if
//  that search is wrong the day count is fiction in the same way a wrong enemy
//  generator would make every fight fiction.
//

import XCTest
@testable import ROIContent
@testable import ROISim

final class FoodBudgetTests: XCTestCase {

    // MARK: - Fixtures

    private func plots() -> PlotFileDTO {
        PlotFileDTO(types: [
            PlotTypeDTO(type: "farm", icon: "🌾",
                        tuning: PlotTuningDTO(producedItemId: "food.potato",
                                              ratePerInterval: 4, capacity: 20)),
            PlotTypeDTO(type: "forest", icon: "🪚",
                        tuning: PlotTuningDTO(producedItemId: "mat.lumber",
                                              ratePerInterval: 6, capacity: 30)),
            PlotTypeDTO(type: "coop", icon: "🐔",
                        tuning: PlotTuningDTO(producedItemId: "food.egg",
                                              ratePerInterval: 2, capacity: 12)),
            // Produces nothing — the training ground. Must never be picked.
            PlotTypeDTO(type: "training_ground", icon: "🥋")
        ])
    }

    private func item(_ id: String, vigor: Int = 0) -> ItemDTO {
        ItemDTO(id: id, type: vigor > 0 ? "food" : "material", tier: 1, stackable: true,
                effects: vigor > 0 ? [ItemEffectDTO(kind: .restoreVigor, amount: vigor)] : [])
    }

    private func content(harvestInterval: Double = 3600) -> GameContent {
        let bundle = ContentBundle(
            manifest: ManifestDTO(schemaVersion: ContentSchema.current),
            items: [item("food.potato"),              // raw potato feeds nobody
                    item("mat.lumber"),
                    item("food.egg", vigor: 7),       // edible as it comes
                    item("food.baked_potato", vigor: 9)],
            enemies: [], enemyArchetypes: [],
            recipes: [RecipeDTO(id: "recipe.baked_potato", category: "kitchen",
                                inputs: [RecipeIngredientDTO(itemId: "food.potato", quantity: 1),
                                         RecipeIngredientDTO(itemId: "mat.lumber", quantity: 1)],
                                output: RecipeIngredientDTO(itemId: "food.baked_potato", quantity: 1))],
            starterRecipeIds: [],
            estateUpgrades: EstateUpgradeFileDTO(
                maxTier: 3, plotSlotsByTier: [0, 1, 2],
                progression: [EstateUpgradeStepDTO(toTier: 2, requiredPlayerLevel: 4),
                              EstateUpgradeStepDTO(toTier: 3, requiredPlayerLevel: 7)]),
            plots: plots(),
            tuning: tuning(plotIntervalSeconds: harvestInterval),
            contentHash: "test")
        return GameContent(bundle)
    }

    /// Only the two fields this model reads matter — the plot interval and the
    /// Vigor pool — but `TuningBundleDTO` is all-or-nothing, so the rest is
    /// filled with the shipped values and never consulted.
    private func tuning(plotIntervalSeconds: Double) -> TuningBundleDTO {
        TuningBundleDTO(
            combat: CombatTuningDTO(
                hitChance: HitChanceDTO(base: 85, min: 40, max: 95),
                curves: CombatCurvesDTO(
                    mitigation: MitigationCurveDTO(cap: 0.70, kBase: 46.65, kPerLevel: 8.017),
                    dodge: RatingCurveDTO(scale: 55, kBase: 43.32, kPerLevel: 3.682),
                    crit: RatingCurveDTO(scale: 50, kBase: 51.89, kPerLevel: 3.213),
                    accuracy: RatingCurveDTO(scale: 30, kBase: 33.38, kPerLevel: 1.457)),
                levelDiff: LevelDiffDTO(perLevel: 0.06, min: 0.25, max: 2.5),
                critMultiplier: 1.5, variance: VarianceDTO(min: 0.9, max: 1.1),
                defendChipFraction: 0.3, trainingDummyEnemyId: "enemy.x", techniques: [],
                stances: StanceSectionDTO(durationRounds: 3, defaultActivationVigor: 4, byId: []),
                specialAttack: [],
                specialDefense: SpecialDefenseSectionDTO(
                    effectPersistRounds: 1, ironBulwarkChipFraction: 0.5,
                    shadowVeilDodgeMultiplier: 2.0, mirrorWardReflectFraction: 0.5, byClass: []),
                flee: [],
                defend: DefendTuningDTO(archerChipMultiplier: 0.5, archerDodgeMultiplier: 1.5,
                                        mageBarrierDamageFraction: 0.4)),
            vigor: VigorTuningDTO(
                drain: VigorDrainDTO(walkRoom: 2, walkRoomDoubleSpeed: 4, combatRound: 2,
                                     combatAttack: 2, combatDefend: 1, combatFlee: 3, idle: 0),
                starvation: StarvationDTO(statPenalty: 0.25, hpDrainPercent: 0.05),
                healing: HealingTuningDTO(regenPerMinute: 0.05, maxIdleMinutes: 1440)),
            exploration: ExplorationTuningDTO(
                eventWeightTotal: 100, tripDamagePercent: 0.05,
                weightTiers: [EventWeightTierDTO(priorVisits: 0, nothing: 5, loot: 45,
                                                 encounter: 40, trip: 10)],
                passive: PassiveExpeditionTuningDTO(xpMultiplier: 0.7, lootMultiplier: 1.0,
                                                    freshStepCount: 1)),
            progression: ProgressionTuningDTO(
                maxLevel: 40,
                xpCurve: XPCurveDTO(coefficient: 11.4, exponent: 3.30, floorPerLevel: 120),
                mobXP: MobXPDTO(coefficient: 26, exponent: 1.55),
                xpLevelDiff: XPLevelDiffDTO(perLevel: 0.08, min: 0.10, max: 1.00),
                statGrowth: StatGrowthDTO(hpPerLevel: 0.056, attackPerLevel: 0.1,
                                          ratingPerLevel: 0.085),
                vigorPool: VigorPoolDTO(base: 100, perLevel: 5),
                classes: [], warehouseCapByEstateLevel: [200]),
            economy: EconomyTuningDTO(gear: GearEconomyDTO(
                maxDurabilityStart: 30, repairMaxShave: 1,
                wearBudget: WearBudgetDTO(victory: 1, defeat: 3, flee: 2)), questRewards: QuestRewardTuningDTO(silverPerLevel: 0.015)),
            time: TimeTuningDTO(
                scale: 1,
                gameTime: GameTimeDTO(
                    travelMinutes: 2,
                    passiveExpedition: PassiveExpeditionTimeDTO(unitsPerStep: 5, secondsPerUnit: 60),
                    plotIntervalSeconds: plotIntervalSeconds,
                    plotSweeper: PlotSweeperDTO(intervalDivisor: 12, minSeconds: 60)),
                realTime: RealTimeDTO(tradeLobbyTTL: 180, tradeSessionTTL: 300,
                                      tradeSweepInterval: 30, tavernDeletableAfter: 86460,
                                      tavernSweepInterval: 1800, dayRolloverHour: 12,
                                      dayTimeZoneId: "Europe/Kyiv")))
    }

    // MARK: - Per-plot production

    /// Which ceiling binds is the mechanic: a plot fills to capacity and stops,
    /// so a rare visitor is capped by the harvest and a frequent one by the rate.
    func testProductionIsBoundedByWhicheverCeilingIsLower() {
        // 4/hour for 24 hours = 96, but two visits can only carry 2 × 20.
        XCTAssertEqual(FoodBudget.unitsPerDay(rate: 4, capacity: 20, harvestsPerDay: 2,
                                              intervalHours: 1), 40)
        // Ten visits cannot beat what the plot can grow.
        XCTAssertEqual(FoodBudget.unitsPerDay(rate: 4, capacity: 20, harvestsPerDay: 10,
                                              intervalHours: 1), 96)
    }

    func testAZeroIntervalProducesNothingRatherThanDividingByIt() {
        XCTAssertEqual(FoodBudget.unitsPerDay(rate: 4, capacity: 20, harvestsPerDay: 3,
                                              intervalHours: 0), 0)
    }

    // MARK: - The estate ladder

    func testEstateTierFollowsTheLevelGates() {
        let up = content().estateUpgrades
        XCTAssertEqual(FoodBudget.estateTier(playerLevel: 1, upgrades: up), 1)
        XCTAssertEqual(FoodBudget.estateTier(playerLevel: 3, upgrades: up), 1)
        XCTAssertEqual(FoodBudget.estateTier(playerLevel: 4, upgrades: up), 2)
        XCTAssertEqual(FoodBudget.estateTier(playerLevel: 40, upgrades: up), 3)
    }

    /// Tier 1 clears no land, and the report divides by this — a wrong zero and
    /// a wrong one are both silent, so both ends are pinned.
    func testSlotsClampAtBothEndsOfTheTable() {
        let up = content().estateUpgrades
        XCTAssertEqual(FoodBudget.slots(tier: 1, upgrades: up), 0)
        XCTAssertEqual(FoodBudget.slots(tier: 3, upgrades: up), 2)
        XCTAssertEqual(FoodBudget.slots(tier: 99, upgrades: up), 2)
        XCTAssertEqual(FoodBudget.slots(tier: -5, upgrades: up), 0)
    }

    // MARK: - The search

    func testMultisetsAreOrderInsensitiveAndComplete() {
        let mixes = FoodBudget.multisets(of: ["a", "b", "c"], size: 2)
        // C(3 + 2 - 1, 2) = 6 combinations with repetition.
        XCTAssertEqual(mixes.count, 6)
        XCTAssertTrue(mixes.contains(["a", "a"]))
        XCTAssertTrue(mixes.contains(["a", "b"]))
        XCTAssertFalse(mixes.contains(["b", "a"]), "an estate is the same estate whichever slot a plot sits in")
    }

    func testNoSlotsFeedsNobody() {
        XCTAssertEqual(FoodBudget.best(slots: 0, harvestsPerDay: 3, content: content()).vigor, 0)
    }

    /// One slot cannot cook — the recipe needs both a farm and a forest — so the
    /// coop's raw egg wins. Two slots can, and the cooked pair must beat two
    /// coops, or the optimiser is not searching.
    func testTheEstateOptimiserPrefersTheBetterMix() {
        let c = content()
        let one = FoodBudget.best(slots: 1, harvestsPerDay: 3, content: c)
        XCTAssertEqual(one.mix, ["coop"])
        XCTAssertEqual(one.vigor, 36 * 7, accuracy: 0.001)   // 3 × 12 eggs × 7

        let two = FoodBudget.best(slots: 2, harvestsPerDay: 3, content: c)
        XCTAssertEqual(two.mix.sorted(), ["farm", "forest"])
        // 60 potatoes meet 90 lumber → 60 dishes × 9.
        XCTAssertEqual(two.vigor, 60 * 9, accuracy: 0.001)
        XCTAssertGreaterThan(two.vigor, 2 * one.vigor, "cooking must beat eating raw, or nobody would build a kitchen")
    }

    /// A plot with no `tuning` produces nothing and must never be chosen — it is
    /// the training ground, and picking it would silently starve the estate.
    func testTheNonProducingPlotIsNeverChosen() {
        let best = FoodBudget.best(slots: 2, harvestsPerDay: 3, content: content())
        XCTAssertFalse(best.mix.contains("training_ground"))
    }

    /// Portions are the tap cost of the food loop, so they are counted, not
    /// inferred: 60 cooked dishes are 60 portions even though they are worth
    /// 540 Vigor.
    func testPortionsCountBitesRatherThanVigor() {
        let two = FoodBudget.best(slots: 2, harvestsPerDay: 3, content: content())
        XCTAssertEqual(two.portions, 60, accuracy: 0.001)
    }
}
