//
//  KingChainTests.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 21.09.2026.
//
//  Every rule in `validateKingChain` gets its failing case here, in the same
//  commit as the rule. A checker nobody has watched fail is a checker that
//  cannot fail — the reachability rule proved a scroll existed rather than
//  that a player could hold one, and it took months to notice.
//
//  Two of these were live defects before they were tests: `plot_type_unknown`
//  caught `"training"` where the game says `"training_ground"` on the very
//  first run against the shipped file, and `vigor_over_pool` is the rule the
//  2026-09-20 design draft broke three times.
//

import XCTest
@testable import ROIContent

final class KingChainTests: XCTestCase {

    // MARK: - Fixtures

    private func roast() -> ItemDTO {
        ItemDTO(id: "food.roasted_meat", type: "food", tier: 1, stackable: true,
                effects: [ItemEffectDTO(kind: .restoreVigor, amount: 14)], icon: "🍗")
    }

    private func lumber() -> ItemDTO {
        ItemDTO(id: "mat.pine_lumber", type: "material", tier: 1, stackable: true, icon: "🪵")
    }

    private func decree(
        _ id: String = "king.x",
        level: Int = 4,
        conditions: [KingConditionDTO] = [KingConditionDTO(kind: .reachKm, target: 3)],
        reward: KingRewardDTO = KingRewardDTO(vigor: 25)
    ) -> KingDecreeDTO {
        KingDecreeDTO(id: id, level: level, conditions: conditions, reward: reward)
    }

    private func bundle(_ decrees: [KingDecreeDTO], withTuning: Bool = true) -> ContentBundle {
        ContentBundle(
            manifest: ManifestDTO(schemaVersion: ContentSchema.current),
            items: [roast(), lumber()],
            enemies: [], recipes: [], starterRecipeIds: [],
            weaponLadders: [WeaponLadderDTO(
                itemId: "gear.rusty_sword",
                tiers: [WeaponUpgradeStepDTO(tier: 2, stats: GearStatsDTO(attack: 5), inputs: [])])],
            bags: BagFileDTO(maxTier: 3, capacities: [25, 35, 45],
                             progression: []),
            estateUpgrades: EstateUpgradeFileDTO(
                maxTier: 3, plotSlotsByTier: [0, 1, 2],
                progression: [EstateUpgradeStepDTO(toTier: 2, requiredPlayerLevel: 4),
                              EstateUpgradeStepDTO(toTier: 3, requiredPlayerLevel: 7)]),
            plots: PlotFileDTO(types: [PlotTypeDTO(type: "farm", icon: "🌾")]),
            king: KingFileDTO(decrees: decrees),
            tuning: withTuning ? tuning() : nil,
            contentHash: "test")
    }

    private func report(_ decrees: [KingDecreeDTO], withTuning: Bool = true) -> ContentReport {
        ContentValidator.validate(bundle(decrees, withTuning: withTuning))
    }

    /// Only the chain's own rules. The fixture bundle has no classes, no
    /// technique table and one plot type, so it legitimately trips a dozen
    /// unrelated rules — asserting on `hasErrors` would test those instead.
    private func kingIssues(_ decrees: [KingDecreeDTO]) -> [ContentIssue] {
        report(decrees).issues.filter { $0.rule.hasPrefix("king.") }
    }

    private func assertRule(_ rule: String, _ decrees: [KingDecreeDTO],
                            file: StaticString = #filePath, line: UInt = #line) {
        let found = report(decrees)
        XCTAssertTrue(found.errors.contains { $0.rule == rule },
                      "expected \(rule), got \(found.errors.map(\.rule))", file: file, line: line)
    }

    // MARK: - The shape holds

    func testAWellFormedChainIsClean() {
        let chain = [
            decree("king.a", level: 1, conditions: [KingConditionDTO(kind: .reachKm, target: 3)],
                   reward: KingRewardDTO(vigor: 25)),
            decree("king.b", level: 4, conditions: [KingConditionDTO(kind: .playerLevel, target: 4)],
                   reward: KingRewardDTO(vigor: 30,
                                         food: KingFoodRewardDTO(itemId: "food.roasted_meat", quantity: 2))),
            decree("king.c", level: 4, conditions: [KingConditionDTO(kind: .estateTier, target: 2)],
                   reward: KingRewardDTO(vigor: 60)),
        ]
        let found = kingIssues(chain)
        XCTAssertTrue(found.isEmpty, "clean chain produced: \(found.map(\.rule))")
    }

    /// Derived from the conditions, never authored — a second discriminator
    /// beside them is a field that can disagree with them.
    func testLevelDecreeIsDerivedFromItsConditions() {
        XCTAssertTrue(decree(conditions: [KingConditionDTO(kind: .playerLevel, target: 4)]).isLevelDecree)
        XCTAssertFalse(decree(conditions: [KingConditionDTO(kind: .estateTier, target: 2)]).isLevelDecree)
        // The finale asks for two things; one of them is a level, so it counts.
        XCTAssertTrue(decree(level: 25, conditions: [KingConditionDTO(kind: .playerLevel, target: 25),
                                                     KingConditionDTO(kind: .bagTier, target: 3)]).isLevelDecree)
    }

    // MARK: - Every rule's failing case

    /// The one the shipped file actually broke on its first run.
    func testUnknownPlotTypeIsAnError() {
        assertRule("king.plot_type_unknown",
                   [decree(conditions: [KingConditionDTO(kind: .claimPlot, plotType: "training")])])
    }

    /// The grant clamps to the pool, so anything above it is a number the
    /// player is shown and never receives.
    func testVigorAboveThePoolIsAnError() {
        // Level 4 pool is 100 + 5×4 = 120.
        assertRule("king.vigor_over_pool", [decree(level: 4, reward: KingRewardDTO(vigor: 300))])
    }

    func testVigorNearThePoolIsAWarning() {
        let found = kingIssues([decree(level: 4, reward: KingRewardDTO(vigor: 100))])
        XCTAssertEqual(found.map(\.rule), ["king.vigor_near_pool"])
        XCTAssertEqual(found.first?.severity, .warning)
    }

    /// 2026-09-21, the owner's call: an unpaid step is a screen the player taps
    /// through for nothing, so the chain does not carry one.
    func testADecreeThatPaysNothingIsAnError() {
        assertRule("king.empty_reward", [decree(reward: KingRewardDTO())])
    }

    func testADecreeWithNoConditionIsAnError() {
        assertRule("king.no_conditions", [decree(conditions: [])])
    }

    /// The array order is the order the player walks it.
    func testAChainThatStepsBackwardsIsAnError() {
        assertRule("king.chain_out_of_order",
                   [decree("king.a", level: 7), decree("king.b", level: 4)])
    }

    func testALevelDecreeMustAgreeWithItsOwnLevel() {
        assertRule("king.level_decree_disagrees",
                   [decree(level: 4, conditions: [KingConditionDTO(kind: .playerLevel, target: 7)])])
    }

    /// Filed below the level the estate tier itself requires, the decree could
    /// never be completed where it sits.
    func testAnEstateTierBeforeItsOwnGateIsAnError() {
        assertRule("king.estate_tier_before_its_gate",
                   [decree(level: 2, conditions: [KingConditionDTO(kind: .estateTier, target: 2)])])
    }

    func testTiersOutsideTheirLaddersAreErrors() {
        assertRule("king.estate_tier_out_of_range",
                   [decree(level: 9, conditions: [KingConditionDTO(kind: .estateTier, target: 9)])])
        assertRule("king.weapon_tier_out_of_range",
                   [decree(conditions: [KingConditionDTO(kind: .weaponTier, target: 5)])])
        assertRule("king.bag_tier_out_of_range",
                   [decree(conditions: [KingConditionDTO(kind: .bagTier, target: 6)])])
    }

    func testUnknownMaterialAndEmptyMaterialsAreErrors() {
        assertRule("king.material_unknown",
                   [decree(conditions: [KingConditionDTO(
                       kind: .warehouseMaterials,
                       materials: [MaterialCostDTO(itemId: "mat.ghost", quantity: 5)])])])
        assertRule("king.materials_empty",
                   [decree(conditions: [KingConditionDTO(kind: .warehouseMaterials)])])
    }

    func testFoodRewardMustBeFood() {
        assertRule("king.reward_food_unknown",
                   [decree(reward: KingRewardDTO(food: KingFoodRewardDTO(itemId: "food.ghost", quantity: 1)))])
        assertRule("king.reward_food_not_food",
                   [decree(reward: KingRewardDTO(food: KingFoodRewardDTO(itemId: "mat.pine_lumber", quantity: 1)))])
    }

    /// A counted kind without its target would complete on the first tick; a
    /// one-shot kind carrying one reads as a threshold nothing enforces.
    func testTargetPresenceMustMatchTheKind() {
        assertRule("king.condition_target_missing",
                   [decree(conditions: [KingConditionDTO(kind: .reachKm)])])
        assertRule("king.condition_target_unused",
                   [decree(conditions: [KingConditionDTO(kind: .cookDish, target: 3)])])
    }

    func testFieldsThatBelongToAnotherKindAreErrors() {
        assertRule("king.plot_type_unused",
                   [decree(conditions: [KingConditionDTO(kind: .cookDish, plotType: "farm")])])
        assertRule("king.materials_unused",
                   [decree(conditions: [KingConditionDTO(
                       kind: .cookDish,
                       materials: [MaterialCostDTO(itemId: "mat.pine_lumber", quantity: 1)])])])
    }

    func testDuplicateDecreeIdIsAnError() {
        assertRule("identity.duplicate_id", [decree("king.a"), decree("king.a")])
    }

    // MARK: - Wire format

    /// An unknown kind FAILS rather than defaulting: a silently dropped
    /// condition turns a decree into one that completes itself.
    func testUnknownConditionKindFailsToDecode() {
        let json = Data("""
        {"decrees":[{"id":"king.x","level":1,
          "conditions":[{"kind":"solve_a_riddle"}],"reward":{"vigor":10}}]}
        """.utf8)
        XCTAssertThrowsError(try JSONDecoder().decode(KingFileDTO.self, from: json))
    }

    /// Encoding writes only the half that belongs to the kind, so a decree file
    /// round-trips without growing null fields on every row.
    func testEncodingOmitsFieldsTheKindDoesNotUse() throws {
        let encoder = ContentLoader.makeEncoder()
        let oneShot = try encoder.encode(KingConditionDTO(kind: .cookDish))
        XCTAssertFalse(String(decoding: oneShot, as: UTF8.self).contains("target"))
        let counted = try encoder.encode(KingConditionDTO(kind: .reachKm, target: 3))
        XCTAssertFalse(String(decoding: counted, as: UTF8.self).contains("materials"))
        let reward = try encoder.encode(KingRewardDTO(vigor: 25))
        let text = String(decoding: reward, as: UTF8.self)
        XCTAssertFalse(text.contains("silver"))
        XCTAssertFalse(text.contains("food"))
    }

    /// The pool curve has ONE implementation, and the validator reads it rather
    /// than keeping a second copy of `100 + 5 × level`.
    func testPoolCurveIsSharedWithProgression() {
        let pool = VigorPoolDTO(base: 100, perLevel: 5)
        XCTAssertEqual(pool.maxVigor(at: 1), 105)
        XCTAssertEqual(pool.maxVigor(at: 25), 225)
        XCTAssertEqual(pool.maxVigor(at: 0), 100)
    }

    // MARK: - Tuning fixture

    /// Only `progression.vigorPool` is read by these rules, but
    /// `TuningBundleDTO` is all-or-nothing, so the rest is filled with the
    /// shipped values and never consulted.
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
                flee: FleeSectionDTO(maxFailures: 4, byClass: []),
                defend: DefendTuningDTO(archerChipMultiplier: 0.5, archerDodgeMultiplier: 1.5,
                                        mageBarrierDamageFraction: 0.4)),
            vigor: VigorTuningDTO(
                drain: VigorDrainDTO(walkRoom: 2, walkRoomDoubleSpeed: 4, combatRound: 2,
                                     combatAttack: 2, combatDefend: 1, combatFlee: 3, idle: 0),
                starvation: StarvationDTO(statPenalty: 0.25, hpDrainPercent: 0.05),
                healing: HealingTuningDTO(regenPerMinute: 0.1, maxIdleMinutes: 1440)),
            exploration: ExplorationTuningDTO(
                eventWeightTotal: 100, tripDamagePercent: 0.05,
                weightTiers: [EventWeightTierDTO(priorVisits: 0, nothing: 5, loot: 45,
                                                 encounter: 40, trip: 10)],
                passive: PassiveExpeditionTuningDTO(xpMultiplier: 0.7, lootMultiplier: 1.0,
                                                    freshStepCount: 1,
                                                    weights: EventWeightsDTO(nothing: 25, loot: 45,
                                                                             encounter: 20, trip: 10))),
            progression: ProgressionTuningDTO(
                maxLevel: 40,
                xpCurve: XPCurveDTO(coefficient: 11.4, exponent: 3.30, floorPerLevel: 120),
                mobXP: MobXPDTO(coefficient: 13, exponent: 1.55),
                xpLevelDiff: XPLevelDiffDTO(perLevel: 0.08, min: 0.10, max: 1.00),
                statGrowth: StatGrowthDTO(hpPerLevel: 0.056, attackPerLevel: 0.1,
                                          ratingPerLevel: 0.085),
                vigorPool: VigorPoolDTO(base: 100, perLevel: 5),
                classes: [], warehouseCapByEstateLevel: [200]),
            economy: EconomyTuningDTO(
                gear: GearEconomyDTO(maxDurabilityStart: 30, repairMaxShave: 1,
                                     wearBudget: WearBudgetDTO(victory: 1, defeat: 3, flee: 2)),
                questRewards: QuestRewardTuningDTO(silverPerLevel: 0.015)),
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
}
