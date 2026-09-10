//
//  OpeningLedgerTests.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 02.09.2026.
//
//  The opening ledger answers one question — can the levels below the estate
//  be completed, and at what depth — and it answers it by combining four
//  things that can each be quietly wrong: where the stretch ends, what the
//  player has to spend, what the trail pays back, and which of a kill's drops
//  is actually food. Every one of those is pinned here.
//
//  The load-bearing one is `testKillsUseTheLevelGapScalingRatherThanTheFlatReward`.
//  Dividing the XP ladder by a monster's printed reward is the obvious way to
//  count the opening, it is the way an approved spec counted it, and it is
//  wrong by 17% because a level-3 player does not earn the level-1 reward.
//

import XCTest
@testable import ROIContent
@testable import ROISim

final class OpeningLedgerTests: XCTestCase {

    // MARK: - Fixtures

    private func item(_ id: String, vigor: Int = 0) -> ItemDTO {
        ItemDTO(id: id, type: vigor > 0 ? "food" : "material", tier: 1, stackable: true,
                effects: vigor > 0 ? [ItemEffectDTO(kind: .restoreVigor, amount: vigor)] : [])
    }

    private func archetype(_ id: String, xp: Double, weight: Double) -> EnemyArchetypeDTO {
        EnemyArchetypeDTO(id: id, rounds: 4, hpLossPercent: 20, mitigationPercent: 0.2,
                          dodgePercent: 2, critPercent: 2, xpMultiplier: xp,
                          lootMultiplier: 1, spawnWeight: weight, minLevel: 1)
    }

    /// A two-creature wilderness: a level-1 mob from km 1 that drops meat, and
    /// a level-4 one from km 4 that drops nothing. Their bands overlap at km
    /// 4–10, which is what gives the row-per-spawn-set rule something to do.
    private func content(estateGate: Int = 4, bigRecipeVigor: Int = 20,
                         shallowXP: Int = 10, dropsBerries: Bool = false,
                         abyss: Bool = false) -> GameContent {
        let bundle = ContentBundle(
            manifest: ManifestDTO(schemaVersion: ContentSchema.current),
            items: [item("food.berries", vigor: 4),
                    item("mat.lumber"),
                    item("food.raw_meat"),                  // inedible as found
                    item("food.small_dish", vigor: 12),
                    item("food.big_dish", vigor: bigRecipeVigor)],
            enemies: [
                EnemyDTO(id: "enemy.shallow", tier: 1, icon: "🐗", xpReward: shallowXP,
                         stats: EnemyStatsDTO(hp: 30, attack: 5, defense: 5),
                         depth: IntRangeDTO(min: 1, max: 10),
                         loot: [EnemyLootDropDTO(itemId: "food.raw_meat", chance: 1.0, quantity: 1)]
                             + (dropsBerries
                                ? [EnemyLootDropDTO(itemId: "food.berries", chance: 1.0, quantity: 1)]
                                : []),
                         level: 1, archetype: "trash"),
                EnemyDTO(id: "enemy.deep", tier: 1, icon: "🦌", xpReward: 200,
                         stats: EnemyStatsDTO(hp: 60, attack: 8, defense: 10),
                         depth: IntRangeDTO(min: 4, max: 13),
                         level: 4, archetype: "normal")
            ] + (abyss
                 ? [EnemyDTO(id: "enemy.abyss", tier: 1, icon: "🐻", xpReward: 9000,
                             stats: EnemyStatsDTO(hp: 400, attack: 40, defense: 40),
                             depth: IntRangeDTO(min: 30, max: 40),
                             level: 30, archetype: "normal")]
                 : []),
            enemyArchetypes: [archetype("trash", xp: 0.4, weight: 3),
                              archetype("normal", xp: 1.0, weight: 2)],
            recipes: [
                // 1 meat → 12 vigor is the better RATE; 2 meat → 20 is the
                // bigger dish. The ledger has to price the rate.
                RecipeDTO(id: "recipe.small", category: "kitchen",
                          inputs: [RecipeIngredientDTO(itemId: "food.raw_meat", quantity: 1),
                                   RecipeIngredientDTO(itemId: "mat.lumber", quantity: 1)],
                          output: RecipeIngredientDTO(itemId: "food.small_dish", quantity: 1)),
                RecipeDTO(id: "recipe.big", category: "kitchen",
                          inputs: [RecipeIngredientDTO(itemId: "food.raw_meat", quantity: 2)],
                          output: RecipeIngredientDTO(itemId: "food.big_dish", quantity: 1))
            ],
            rarities: [RarityDTO(id: "common", budgetMultiplier: 1.0,
                                 valueMultiplier: 1.0, glyph: "·")],
            budget: budget(),
            starterRecipeIds: [],
            estateUpgrades: EstateUpgradeFileDTO(
                maxTier: 3, plotSlotsByTier: [0, 1, 2],
                progression: [EstateUpgradeStepDTO(toTier: 2, requiredPlayerLevel: estateGate),
                              EstateUpgradeStepDTO(toTier: 3, requiredPlayerLevel: estateGate + 3)]),
            zones: ZoneFileDTO(zones: [
                // Half the pool is edible as found, half is a crafting input —
                // so a wrong "everything forageable is food" would double the
                // trail income and show up immediately.
                ZoneDTO(id: "zone.test", depth: IntRangeDTO(min: 1, max: 20),
                        forage: [ForageEntryDTO(itemId: "food.berries", weight: 10),
                                 ForageEntryDTO(itemId: "mat.lumber", weight: 10)])
            ]),
            tuning: tuning(),
            contentHash: "test")
        return GameContent(bundle)
    }

    private func budget() -> BudgetTuningDTO {
        BudgetTuningDTO(
            base: 6.0, perItemLevel: 1.5,
            slotWeights: [SlotWeightDTO(slot: "main_hand", weight: 3.0),
                          SlotWeightDTO(slot: "chest", weight: 1.6)],
            statPerPoint: StatPerPointDTO(attack: 0.42, defense: 0.55, hp: 2.2,
                                          crit: 1.0, dodge: 1.0, accuracy: 0.8),
            classProfiles: [ClassBudgetProfileDTO(
                characterClass: "warrior",
                weapon: StatSharesDTO(attack: 1.0),
                armour: StatSharesDTO(defense: 0.6, hp: 0.4),
                offHand: StatSharesDTO(defense: 1.0))])
    }

    private func tuning() -> TuningBundleDTO {
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
                                                    freshStepCount: 1,
                                                    weights: EventWeightsDTO(nothing: 25, loot: 45, encounter: 20, trip: 10))),
            progression: ProgressionTuningDTO(
                maxLevel: 40,
                xpCurve: XPCurveDTO(coefficient: 11.4, exponent: 3.30, floorPerLevel: 120),
                mobXP: MobXPDTO(coefficient: 26, exponent: 1.55),
                xpLevelDiff: XPLevelDiffDTO(perLevel: 0.08, min: 0.10, max: 1.00),
                statGrowth: StatGrowthDTO(hpPerLevel: 0.056, attackPerLevel: 0.1,
                                          ratingPerLevel: 0.085),
                vigorPool: VigorPoolDTO(base: 100, perLevel: 5),
                classes: [ClassStartDTO(characterClass: "warrior", hp: 120, attack: 14,
                                        defense: 10, crit: 5, dodge: 5, accuracy: 5,
                                        starterWeaponId: "item.sword")],
                warehouseCapByEstateLevel: [200]),
            economy: EconomyTuningDTO(gear: GearEconomyDTO(
                maxDurabilityStart: 30, repairMaxShave: 1,
                wearBudget: WearBudgetDTO(victory: 1, defeat: 3, flee: 2)), questRewards: QuestRewardTuningDTO(silverPerLevel: 0.015)),
            time: TimeTuningDTO(
                scale: 1,
                gameTime: GameTimeDTO(
                    travelMinutes: 2,
                    passiveExpedition: PassiveExpeditionTimeDTO(unitsPerStep: 5, secondsPerUnit: 60),
                    plotIntervalSeconds: 3600,
                    plotSweeper: PlotSweeperDTO(intervalDivisor: 12, minSeconds: 60)),
                realTime: RealTimeDTO(tradeLobbyTTL: 180, tradeSessionTTL: 300,
                                      tradeSweepInterval: 30, tavernDeletableAfter: 86460,
                                      tavernSweepInterval: 1800, dayRolloverHour: 12,
                                      dayTimeZoneId: "Europe/Kyiv")))
    }

    private func measure(_ content: GameContent) -> OpeningLedger.Result? {
        OpeningLedger.measure(content: content, runs: 8, seed: 99)
    }

    // MARK: - Where the stretch begins and ends

    /// The opening is not "levels 1–3", it is "every level below the estate's
    /// first upgrade" — written as a lookup so the section follows the gate.
    func testTheOpeningEndsWhereTheEstateLadderSaysItDoes() {
        guard let four = measure(content(estateGate: 4)),
              let seven = measure(content(estateGate: 7)) else { return XCTFail("no ledger") }
        XCTAssertEqual(four.endsAtLevel, 4)
        XCTAssertEqual(seven.endsAtLevel, 7)
        XCTAssertGreaterThan(seven.xpNeeded, four.xpNeeded)
    }

    /// A level-up adds its delta to the pool the player is holding, and nothing
    /// else refills it — so the whole opening is one budget, and that budget is
    /// the ceiling at its LAST level, not the level-1 pool.
    func testTheStockIsThePoolCeilingAtTheLastOpeningLevel() {
        guard let four = measure(content(estateGate: 4)),
              let seven = measure(content(estateGate: 7)) else { return XCTFail("no ledger") }
        XCTAssertEqual(four.stock, 115)          // 100 + 5×3
        XCTAssertEqual(seven.stock, 130)         // 100 + 5×6
    }

    // MARK: - What the trail pays

    /// Half the forage pool is a crafting input, so a ledger that counted
    /// everything forageable as food would pay exactly double.
    func testOnlyForageThatIsEdibleAsFoundCounts() {
        guard let result = measure(content()), let shallow = result.depths.first
        else { return XCTFail("no ledger") }
        // 1.5 items per event × 45/40 events per encounter × (½ × 4 vigor).
        let perEncounter = OpeningLedger.itemsPerForageEvent * (45.0 / 40.0) * 2.0
        XCTAssertEqual(shallow.foraged, shallow.kills * perEncounter, accuracy: 0.01)
    }

    /// Raw meat is not income during the opening — it restores nothing as found
    /// and the kitchen belongs to the estate this stretch ends by unlocking. It
    /// is reported as what the gate holds back and kept out of the net.
    func testRawMeatIsReportedAsLockedRatherThanEarned() {
        guard let result = measure(content()), let shallow = result.depths.first
        else { return XCTFail("no ledger") }
        XCTAssertGreaterThan(shallow.meatLocked, 0)
        XCTAssertEqual(shallow.net, shallow.stock + shallow.trailFood - shallow.spent - shallow.approach,
                       accuracy: 0.01)
        XCTAssertEqual(shallow.netIfCooked, shallow.net + shallow.meatLocked, accuracy: 0.01)
    }

    /// The other half of the same rule, and the one no shipped enemy exercises:
    /// a drop that CAN be eaten as it falls is income now, not potential later.
    /// Nothing drops food today, so the branch would have sat silently wrong —
    /// a drop counting towards neither column — until the first one was authored.
    func testAKillDropEdibleAsFoundIsIncomeAndNotLockedAway() {
        guard let plain = measure(content())?.depths.first,
              let fed = measure(content(dropsBerries: true))?.depths.first
        else { return XCTFail("no ledger") }
        XCTAssertEqual(plain.killFood, 0)
        XCTAssertEqual(fed.killFood, fed.kills * 4, accuracy: 0.01)      // berries = 4 vigor
        XCTAssertEqual(fed.trailFood, fed.foraged + fed.killFood, accuracy: 0.01)
        // It moves the NET, and it does not move the locked column: berries are
        // not waiting on a kitchen the way the meat is.
        XCTAssertEqual(fed.meatLocked, plain.meatLocked, accuracy: 0.01)
        XCTAssertGreaterThan(fed.net, plain.net)
    }

    /// The conversion is a RATE — vigor per unit consumed — so the dish that
    /// restores more but eats two of them is worth less per kill. Getting this
    /// backwards silently inflates every meat number by the recipe's input
    /// quantity.
    func testMeatIsPricedAtTheBestRatePerUnitConsumed() {
        // small: 1 meat → 12 vigor (rate 12). big: 2 meat → 20 (rate 10).
        guard let modest = measure(content(bigRecipeVigor: 20))?.depths.first
        else { return XCTFail("no ledger") }
        XCTAssertEqual(modest.meatLocked, modest.kills * 12, accuracy: 0.01)

        // Raise the big dish past 24 and its rate (15) wins on merit.
        guard let rich = measure(content(bigRecipeVigor: 30))?.depths.first
        else { return XCTFail("no ledger") }
        XCTAssertEqual(rich.meatLocked, rich.kills * 15, accuracy: 0.01)
    }

    // MARK: - What the walk costs

    /// Charged once per kilometre, because nothing refills the pool out there:
    /// the opening is a single budget and the approach happens once inside it.
    func testTheApproachIsChargedOncePerKilometre() {
        guard let result = measure(content()) else { return XCTFail("no ledger") }
        for depth in result.depths {
            XCTAssertEqual(depth.approach, Double(depth.km) * 2, accuracy: 0.001)
        }
    }

    /// One row per distinct encounter table, at the shallowest km that has it —
    /// every km inside a band rolls the same enemies, so the rest would be the
    /// same row with a longer walk in front of it.
    func testOneRowPerSpawnSetAtItsShallowestKilometre() {
        guard let result = measure(content()) else { return XCTFail("no ledger") }
        XCTAssertEqual(result.depths.map(\.km), [1, 4, 11])
        XCTAssertEqual(result.depths.map(\.mobLevels), [[1], [1, 4], [4]])
    }

    /// How deep to sweep is read off the ROSTER, not written down. A ceiling in
    /// the code truncates the table the day something is authored past it —
    /// silently, and in the one direction ("is there a better depth further
    /// out?") the table exists to answer.
    func testTheSweepReachesAsDeepAsTheRosterDoes() {
        guard let near = measure(content()),
              let far = measure(content(abyss: true)) else { return XCTFail("no ledger") }
        XCTAssertEqual(near.depths.map(\.km).max(), 11)     // deepest band ends at 13
        XCTAssertEqual(far.depths.map(\.km).max(), 30)      // a km-30 band is reached
        XCTAssertEqual(far.depths.last?.mobLevels, [30])
    }

    // MARK: - Counting the kills

    /// The whole reason this ledger exists. Dividing the XP ladder by the
    /// printed reward gives 78.8 kills; the level-gap scaler makes it 92.2,
    /// because a level-3 player earns 8 XP from a level-1 mob and not 10.
    func testKillsUseTheLevelGapScalingRatherThanTheFlatReward() {
        guard let shallow = measure(content())?.depths.first else { return XCTFail("no ledger") }
        // 120/10 + 240/9 + 428/8
        XCTAssertEqual(shallow.kills, 12 + 240.0 / 9 + 428.0 / 8, accuracy: 0.001)
        XCTAssertGreaterThan(shallow.kills, 788.0 / 10)
    }

    /// A band whose creatures are worth nothing is skipped, not divided by.
    func testAWorthlessBandIsSkippedRatherThanDividedBy() {
        var stripped = content(shallowXP: 0)
        stripped = GameContent(ContentBundle(
            manifest: ManifestDTO(schemaVersion: ContentSchema.current),
            items: stripped.items,
            enemies: stripped.enemies.filter { $0.id == "enemy.shallow" },
            enemyArchetypes: stripped.enemyArchetypes,
            recipes: stripped.recipes, rarities: stripped.rarities, budget: stripped.budget,
            starterRecipeIds: [], estateUpgrades: stripped.estateUpgrades,
            zones: stripped.zones, tuning: stripped.tuning, contentHash: "test"))
        XCTAssertNil(OpeningLedger.measure(content: stripped, runs: 8, seed: 99))
    }

    // MARK: - Picking the answer

    /// "At what depth" is not "wherever the ledger nets most" — a depth the
    /// player cannot hold is not a cheaper opening, it is a shorter one. The
    /// richest row here is also the one that kills you.
    func testTheBestDepthIgnoresOnesThePlayerCannotHold() {
        func depth(km: Int, net: Double, win: Double) -> OpeningLedger.Depth {
            // stock carries the net; every other field is inert for this rule.
            OpeningLedger.Depth(km: km, mobLevels: [1], xpPerKill: 10, vigorPerKill: 10,
                                winRate: win, kills: 1, spent: 0, foraged: 0, killFood: 0,
                                approach: 0, meatLocked: 0, stock: net)
        }
        let result = OpeningLedger.Result(
            depths: [depth(km: 1, net: -10, win: 100),
                     depth(km: 3, net: 5, win: 99),
                     depth(km: 5, net: 50, win: 40)],
            endsAtLevel: 4, stock: 115, xpNeeded: 788,
            stepsPerEncounter: 2.5, walkVigor: 5, forageEventsPerEncounter: 1.125)
        XCTAssertEqual(result.best?.km, 3)
        XCTAssertEqual(result.shallowest?.km, 1)

        // And when nothing is holdable there is no answer, rather than the
        // least-bad row dressed up as one.
        let lethal = OpeningLedger.Result(
            depths: [depth(km: 1, net: 50, win: 60)],
            endsAtLevel: 4, stock: 115, xpNeeded: 788,
            stepsPerEncounter: 2.5, walkVigor: 5, forageEventsPerEncounter: 1.125)
        XCTAssertNil(lethal.best)
    }
}
