//
//  TuningTests.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 30.08.2026.
//
//  Phase 4. Two things are under test, and they fail in different ways:
//
//  1. **Decoding is REQUIRED everywhere.** A tuning table that forgets a field
//     must throw, not default. The optional-with-default pattern is right for a
//     record whose sub-field is genuinely absent and catastrophic for a
//     constant — a missing `baseHitChance` quietly becoming 0 is the exact
//     class of silent balance drift the pipeline exists to prevent.
//
//  2. **Every validator rule actually fires.** A rule that cannot be provoked
//     is worse than no rule, because it reads like coverage. Each test below
//     perturbs ONE field of an otherwise-valid bundle and asserts the specific
//     rule id — not merely that "some error" appeared, which would pass even if
//     an unrelated rule caught it for an unrelated reason.
//

import XCTest
@testable import ROIContent

final class TuningTests: XCTestCase {

    // MARK: - Fixtures (the shipped values)

    private func combat(
        hitBase: Int = 70, hitMin: Int = 10, hitMax: Int = 95,
        critMultiplier: Double = 1.5,
        varianceMin: Double = 0.9, varianceMax: Double = 1.1,
        defendChip: Double = 0.3,
        dummyId: String = "enemy.training_dummy",
        techniques: [TechniqueTuningDTO]? = nil,
        stanceDuration: Int = 3,
        stances: [StanceTuningDTO]? = nil,
        specialAttack: [SpecialAttackTuningDTO]? = nil,
        specialDefenseVigor: [SpecialDefenseClassDTO]? = nil,
        ironBulwarkChip: Double = 0.5,
        shadowVeilDodge: Double = 2.0,
        mirrorWardReflect: Double = 0.5,
        persistRounds: Int = 1,
        flee: [FleeTuningDTO]? = nil,
        archerChip: Double = 0.5, archerDodge: Double = 1.5, mageBarrier: Double = 0.4
    ) -> CombatTuningDTO {
        CombatTuningDTO(
            hitChance: HitChanceDTO(base: hitBase, min: hitMin, max: hitMax),
            curves: CombatCurvesDTO(
                mitigation: MitigationCurveDTO(cap: 0.70, kBase: 46.65, kPerLevel: 8.017),
                dodge: RatingCurveDTO(scale: 55, kBase: 43.32, kPerLevel: 3.682),
                crit: RatingCurveDTO(scale: 50, kBase: 51.89, kPerLevel: 3.213),
                accuracy: RatingCurveDTO(scale: 30, kBase: 33.38, kPerLevel: 1.457)),
            levelDiff: LevelDiffDTO(perLevel: 0.06, min: 0.25, max: 2.5),
            critMultiplier: critMultiplier,
            variance: VarianceDTO(min: varianceMin, max: varianceMax),
            defendChipFraction: defendChip,
            trainingDummyEnemyId: dummyId,
            techniques: techniques ?? [
                TechniqueTuningDTO(kind: "special_atk", requiredLevel: 8, secondUseAtLevel: 17),
                TechniqueTuningDTO(kind: "special_def", requiredLevel: 11, secondUseAtLevel: 20),
                TechniqueTuningDTO(kind: "super", requiredLevel: 14, secondUseAtLevel: 21)
            ],
            stances: StanceSectionDTO(
                durationRounds: stanceDuration, defaultActivationVigor: 4,
                byId: stances ?? [
                    StanceTuningDTO(id: "bloodlust", characterClass: "warrior", activationVigor: 4,
                                    attackMultiplier: 1.35, defenseMultiplier: 1.15,
                                    vigorMultiplier: 1.5),
                    StanceTuningDTO(id: "hawks_eye", characterClass: "archer", activationVigor: 4,
                                    critMultiplier: 1.6, accuracyMultiplier: 1.15,
                                    dodgeMultiplier: 1.15),
                    StanceTuningDTO(id: "arcane_resonance", characterClass: "mage", activationVigor: 5,
                                    attackMultiplier: 1.5, defenseMultiplier: 1.15)
                ]),
            specialAttack: specialAttack ?? [
                SpecialAttackTuningDTO(characterClass: "warrior", vigor: 4, hitChanceModifier: -10,
                                       cannotMiss: false, zeroesDodge: false,
                                       effect: .armourBreak(rounds: 3)),
                SpecialAttackTuningDTO(characterClass: "archer", vigor: 4, hitChanceModifier: 0,
                                       cannotMiss: true, zeroesDodge: true,
                                       effect: .guaranteedCrit(critMultiplier: 2.0)),
                SpecialAttackTuningDTO(characterClass: "mage", vigor: 5, hitChanceModifier: 0,
                                       cannotMiss: true, zeroesDodge: false,
                                       effect: .burn(rounds: 3, fractionOfAttack: 0.35))
            ],
            specialDefense: SpecialDefenseSectionDTO(
                effectPersistRounds: persistRounds,
                ironBulwarkChipFraction: ironBulwarkChip,
                shadowVeilDodgeMultiplier: shadowVeilDodge,
                mirrorWardReflectFraction: mirrorWardReflect,
                byClass: specialDefenseVigor ?? [
                    SpecialDefenseClassDTO(characterClass: "warrior", vigor: 3),
                    SpecialDefenseClassDTO(characterClass: "archer", vigor: 3),
                    SpecialDefenseClassDTO(characterClass: "mage", vigor: 4)
                ]),
            flee: flee ?? [
                FleeTuningDTO(characterClass: "warrior", chance: 40, extraVigor: 0),
                FleeTuningDTO(characterClass: "archer", chance: 70, extraVigor: 0),
                FleeTuningDTO(characterClass: "mage", chance: 90, extraVigor: 2)
            ],
            defend: DefendTuningDTO(archerChipMultiplier: archerChip,
                                    archerDodgeMultiplier: archerDodge,
                                    mageBarrierDamageFraction: mageBarrier))
    }

    private func vigor(walkRoom: Int = 2, idle: Int = 0,
                       statPenalty: Double = 0.25, hpDrain: Double = 0.05,
                       regen: Double = 0.05, maxIdleMinutes: Double = 1440) -> VigorTuningDTO {
        VigorTuningDTO(
            drain: VigorDrainDTO(walkRoom: walkRoom, walkRoomDoubleSpeed: 4, combatRound: 1,
                                 combatAttack: 2, combatDefend: 1, combatFlee: 3, idle: idle),
            starvation: StarvationDTO(statPenalty: statPenalty, hpDrainPercent: hpDrain),
            healing: HealingTuningDTO(regenPerMinute: regen, maxIdleMinutes: maxIdleMinutes))
    }

    private func exploration(total: Int = 100, tripDamage: Double = 0.05,
                             passiveXP: Double = 0.7,
                             tiers: [EventWeightTierDTO]? = nil,
                             passiveWeights: EventWeightsDTO? = nil) -> ExplorationTuningDTO {
        ExplorationTuningDTO(
            eventWeightTotal: total, tripDamagePercent: tripDamage,
            weightTiers: tiers ?? [
                EventWeightTierDTO(priorVisits: 0, nothing: 10, loot: 50, encounter: 30, trip: 10),
                EventWeightTierDTO(priorVisits: 1, nothing: 20, loot: 50, encounter: 20, trip: 10),
                EventWeightTierDTO(priorVisits: 2, nothing: 80, loot: 20, encounter: 0, trip: 0)
            ],
            passive: PassiveExpeditionTuningDTO(xpMultiplier: passiveXP,
                                                lootMultiplier: 1.0, freshStepCount: 1,
                                                weights: passiveWeights
                                                    ?? EventWeightsDTO(nothing: 25, loot: 45, encounter: 20, trip: 10)))
    }

    private func progression(maxLevel: Int = 40, coefficient: Double = 11.4,
                             exponent: Double = 3.30, floorPerLevel: Int = 120,
                             mobExponent: Double = 1.55, xpGapPerLevel: Double = 0.08,
                             hpRate: Double = 0.056, atkRate: Double = 0.100,
                             ratingRate: Double = 0.085,
                             vigorBase: Int = 100, vigorPerLevel: Int = 5,
                             classes: [ClassStartDTO]? = nil,
                             warehouse: [Int]? = nil) -> ProgressionTuningDTO {
        ProgressionTuningDTO(
            maxLevel: maxLevel,
            xpCurve: XPCurveDTO(coefficient: coefficient, exponent: exponent,
                                floorPerLevel: floorPerLevel),
            mobXP: MobXPDTO(coefficient: 26, exponent: mobExponent),
            xpLevelDiff: XPLevelDiffDTO(perLevel: xpGapPerLevel, min: 0.10, max: 1.00),
            statGrowth: StatGrowthDTO(hpPerLevel: hpRate, attackPerLevel: atkRate,
                                      ratingPerLevel: ratingRate),
            vigorPool: VigorPoolDTO(base: vigorBase, perLevel: vigorPerLevel),
            classes: classes ?? [
                ClassStartDTO(characterClass: "warrior", hp: 120, attack: 10, defense: 12,
                              crit: 5, dodge: 5, accuracy: 10, starterWeaponId: "gear.rusty_sword"),
                ClassStartDTO(characterClass: "archer", hp: 90, attack: 14, defense: 8,
                              crit: 10, dodge: 8, accuracy: 14, starterWeaponId: "gear.simple_bow"),
                ClassStartDTO(characterClass: "mage", hp: 80, attack: 15, defense: 6,
                              crit: 12, dodge: 6, accuracy: 10, starterWeaponId: "gear.wooden_staff")
            ],
            warehouseCapByEstateLevel: warehouse ?? [200, 400, 600, 800, 1200, 1600, 2000])
    }

    private func economy(durability: Int = 30, shave: Int = 1,
                         victory: Int = 1, defeat: Int = 3, flee: Int = 3) -> EconomyTuningDTO {
        EconomyTuningDTO(gear: GearEconomyDTO(
            maxDurabilityStart: durability, repairMaxShave: shave,
            wearBudget: WearBudgetDTO(victory: victory, defeat: defeat, flee: flee)), questRewards: QuestRewardTuningDTO(silverPerLevel: 0.015))
    }

    private func time(scale: Double = 1.0,
                      travelMinutes: Int = 2, unitsPerStep: Int = 5, secondsPerUnit: Double = 60,
                      plotInterval: Double = 3600, divisor: Int = 12, minSeconds: Double = 60,
                      tavernDeletable: Double = 86460, rolloverHour: Int = 12,
                      timeZone: String = "Europe/Kyiv") -> TimeTuningDTO {
        TimeTuningDTO(
            scale: scale,
            gameTime: GameTimeDTO(
                travelMinutes: travelMinutes,
                passiveExpedition: PassiveExpeditionTimeDTO(unitsPerStep: unitsPerStep,
                                                            secondsPerUnit: secondsPerUnit),
                plotIntervalSeconds: plotInterval,
                plotSweeper: PlotSweeperDTO(intervalDivisor: divisor, minSeconds: minSeconds)),
            realTime: RealTimeDTO(tradeLobbyTTL: 180, tradeSessionTTL: 300, tradeSweepInterval: 30,
                                  tavernDeletableAfter: tavernDeletable, tavernSweepInterval: 1800,
                                  dayRolloverHour: rolloverHour, dayTimeZoneId: timeZone))
    }

    /// The six shipped archetypes, values from the design table.
    private func archetypeTable() -> [EnemyArchetypeDTO] {
        [("trash", 3.0, 10.0, 10.0, 0.0, 0.0, 0.40, 0.5, 0.40, 100.0),
         ("normal", 5.0, 24.0, 20.0, 3.0, 5.0, 1.00, 1.0, 1.00, 60.0),
         ("skirmisher", 4.0, 28.0, 12.0, 15.0, 12.0, 1.30, 1.2, 1.30, 40.0),
         ("brute", 7.0, 42.0, 32.0, 0.0, 5.0, 1.90, 1.7, 1.90, 25.0),
         ("elite", 8.0, 62.0, 25.0, 8.0, 15.0, 3.20, 3.0, 3.20, 8.0),
         ("boss", 12.0, 130.0, 30.0, 5.0, 20.0, 9.00, 8.0, 9.00, 1.0)
        ].map {
            EnemyArchetypeDTO(id: $0.0, rounds: $0.1, hpLossPercent: $0.2,
                              mitigationPercent: $0.3, dodgePercent: $0.4, critPercent: $0.5,
                              xpMultiplier: $0.6, lootMultiplier: $0.7, spawnWeight: $0.9,
                              minLevel: ["elite", "boss"].contains($0.0) ? 14 : 1)
        }
    }

    private func weapon(_ id: String) -> ItemDTO {
        ItemDTO(id: id, type: "gear", tier: 1, stackable: false, slot: "main_hand",
                gearStats: GearStatsDTO(attack: 3), icon: "⚔️")
    }

    private func bundle(combat: CombatTuningDTO? = nil, vigor: VigorTuningDTO? = nil,
                        exploration: ExplorationTuningDTO? = nil,
                        progression: ProgressionTuningDTO? = nil,
                        economy: EconomyTuningDTO? = nil,
                        time: TimeTuningDTO? = nil) -> ContentBundle {
        ContentBundle(
            manifest: ManifestDTO(schemaVersion: ContentSchema.current),
            items: [weapon("gear.rusty_sword"), weapon("gear.simple_bow"), weapon("gear.wooden_staff")],
            enemies: [EnemyDTO(id: "enemy.training_dummy", tier: 1, icon: "🎯", xpReward: 0,
                               stats: EnemyStatsDTO(hp: 50, attack: 5, defense: 1),
                               depth: IntRangeDTO(min: 0, max: 0),
                               level: 1, archetype: "trash")],
            // A bundle that carries enemies must carry the archetype table, so
            // these fixtures do too — otherwise every tuning test would trip
            // `enemy.archetype_missing` and mask what it is actually asserting.
            enemyArchetypes: archetypeTable(),
            recipes: [], starterRecipeIds: [],
            tuning: TuningBundleDTO(
                combat: combat ?? self.combat(),
                vigor: vigor ?? self.vigor(),
                exploration: exploration ?? self.exploration(),
                progression: progression ?? self.progression(),
                economy: economy ?? self.economy(),
                time: time ?? self.time()),
            contentHash: "test")
    }

    /// Assert that exactly the expected rule fires — not merely that something
    /// did. A perturbation that trips a DIFFERENT rule is a failing test, not a
    /// passing one, because it means the rule under test never ran.
    private func assertRule(_ rule: String, _ bundle: ContentBundle,
                            severity: ContentIssue.Severity = .error,
                            file: StaticString = #filePath, line: UInt = #line) {
        let report = ContentValidator.validate(bundle)
        let matching = (severity == .error ? report.errors : report.warnings)
        XCTAssertTrue(matching.contains { $0.rule == rule },
                      "expected rule \"\(rule)\", got \(matching.map(\.rule))",
                      file: file, line: line)
    }

    // MARK: - The shipped values are clean

    func testShippedTuningHasNoErrors() {
        let report = ContentValidator.validate(bundle())
        XCTAssertFalse(report.hasErrors, "shipped tuning produced: \(report.errors.map(\.rule))")
    }

    /// The audit's finding, asserted rather than described: with the shipped
    /// 5-vs-3 budget, running away wears gear harder than dying. Phase 5 fixes
    /// the numbers; until then the validator must keep saying so.
    func testFleeCostlierThanDefeatWarns() {
        assertRule("tuning.economy.flee_costlier_than_defeat",
                   bundle(economy: economy(defeat: 3, flee: 5)), severity: .warning)
    }

    // MARK: - Decoding is required, never defaulted

    func testMissingCombatFieldThrows() {
        // Everything but `defendChipFraction`.
        let json = """
        {"hitChance":{"base":70,"min":10,"max":95},"critMultiplier":1.5,
         "variance":{"min":0.9,"max":1.1},"trainingDummyEnemyId":"enemy.training_dummy",
         "techniques":[],"stances":{"durationRounds":3,"defaultActivationVigor":4,"byId":[]},
         "specialAttack":[],"specialDefense":{"effectPersistRounds":1,"ironBulwarkChipFraction":0.5,
         "shadowVeilDodgeMultiplier":2.0,"mirrorWardReflectFraction":0.5,"byClass":[]},
         "flee":[],"defend":{"archerChipMultiplier":0.5,"archerDodgeMultiplier":1.5,
         "mageBarrierDamageFraction":0.4}}
        """
        XCTAssertThrowsError(try JSONDecoder().decode(CombatTuningDTO.self, from: Data(json.utf8)),
                             "a missing tuning constant must fail the boot, not default to 0")
    }

    func testMissingVigorDrainFieldThrows() {
        let json = """
        {"drain":{"walkRoom":2,"walkRoomDoubleSpeed":4,"combatRound":1,"combatAttack":2,
         "combatDefend":1,"combatFlee":3},
         "starvation":{"statPenalty":0.25,"hpDrainPercent":0.05},
         "healing":{"regenPerMinute":0.05,"maxIdleMinutes":1440}}
        """
        // `idle` is absent. Its value is 0, which is exactly why it must be
        // stated: an absent key and a deliberate zero are indistinguishable
        // once you allow the default.
        XCTAssertThrowsError(try JSONDecoder().decode(VigorTuningDTO.self, from: Data(json.utf8)))
    }

    func testCombatRoundTripsThroughJSON() throws {
        let encoded = try ContentLoader.makeEncoder().encode(combat())
        let decoded = try JSONDecoder().decode(CombatTuningDTO.self, from: encoded)
        XCTAssertEqual(decoded.hitChance, combat().hitChance)
        XCTAssertEqual(decoded.stances.byId, combat().stances.byId)
        XCTAssertEqual(decoded.specialAttack, combat().specialAttack)
        XCTAssertEqual(decoded.flee, combat().flee)
    }

    // MARK: - combat.json rules

    func testHitChanceOrderIsAnError() {
        assertRule("tuning.combat.hit_chance_order", bundle(combat: combat(hitBase: 99)))
    }

    func testHitChanceOutsidePercentIsAnError() {
        assertRule("tuning.combat.hit_chance_range", bundle(combat: combat(hitMax: 120)))
    }

    /// `CombatService.varianceRange` builds `min...max`, which TRAPS when
    /// inverted — this rule is what stands between a typo and a crash on the
    /// first landed hit of the session.
    func testInvertedVarianceIsAnError() {
        assertRule("tuning.combat.variance_inverted",
                   bundle(combat: combat(varianceMin: 1.2, varianceMax: 0.8)))
    }

    func testNonPositiveVarianceFloorIsAnError() {
        assertRule("tuning.combat.variance_non_positive",
                   bundle(combat: combat(varianceMin: 0.0)))
    }

    func testCritWeakerThanHitIsAnError() {
        assertRule("tuning.combat.crit_weaker_than_hit", bundle(combat: combat(critMultiplier: 0.8)))
    }

    /// Both dodge techniques became multipliers of the archer's own rating in
    /// Phase 8D. Below 1.0 they are not a weaker buff, they are a DEBUFF on a
    /// defensive move — the same shape of mistake the stance rule catches one
    /// section over, and unreachable through any UI, so only this rule can.
    func testShadowVeilDodgeMultiplierBelowOneIsAnError() {
        assertRule("tuning.combat.dodge_multiplier",
                   bundle(combat: combat(shadowVeilDodge: 0.5)))
    }

    func testArcherDefendDodgeMultiplierBelowOneIsAnError() {
        assertRule("tuning.combat.dodge_multiplier",
                   bundle(combat: combat(archerDodge: 0.9)))
    }

    func testUnknownTrainingDummyIsAnError() {
        assertRule("tuning.combat.dummy_unknown", bundle(combat: combat(dummyId: "enemy.ghost")))
    }

    func testMissingTechniqueIsAnError() {
        assertRule("tuning.combat.technique_missing", bundle(combat: combat(techniques: [
            TechniqueTuningDTO(kind: "special_atk", requiredLevel: 8, secondUseAtLevel: 17)
        ])))
    }

    func testSecondUseBeforeUnlockIsAnError() {
        assertRule("tuning.combat.second_use_before_unlock", bundle(combat: combat(techniques: [
            TechniqueTuningDTO(kind: "special_atk", requiredLevel: 8, secondUseAtLevel: 5),
            TechniqueTuningDTO(kind: "special_def", requiredLevel: 11, secondUseAtLevel: 20),
            TechniqueTuningDTO(kind: "super", requiredLevel: 14, secondUseAtLevel: 21)
        ])))
    }

    func testTechniqueAboveMaxLevelIsAnError() {
        assertRule("tuning.combat.technique_unreachable", bundle(combat: combat(techniques: [
            TechniqueTuningDTO(kind: "special_atk", requiredLevel: 99, secondUseAtLevel: 99),
            TechniqueTuningDTO(kind: "special_def", requiredLevel: 11, secondUseAtLevel: 20),
            TechniqueTuningDTO(kind: "super", requiredLevel: 14, secondUseAtLevel: 21)
        ])))
    }

    func testMissingStanceForAClassIsAnError() {
        assertRule("tuning.class_missing", bundle(combat: combat(stances: [
            StanceTuningDTO(id: "bloodlust", characterClass: "warrior", activationVigor: 4,
                            attackMultiplier: 1.35, defenseMultiplier: 1.15, vigorMultiplier: 1.5)
        ])))
    }

    func testDuplicateStanceIdIsAnError() {
        assertRule("identity.duplicate_id", bundle(combat: combat(stances: [
            StanceTuningDTO(id: "bloodlust", characterClass: "warrior", activationVigor: 4,
                            attackMultiplier: 1.35, defenseMultiplier: 1.15, vigorMultiplier: 1.5),
            StanceTuningDTO(id: "bloodlust", characterClass: "archer", activationVigor: 4,
                            critMultiplier: 1.6, accuracyMultiplier: 1.15, dodgeMultiplier: 1.15),
            StanceTuningDTO(id: "arcane_resonance", characterClass: "mage", activationVigor: 5,
                            attackMultiplier: 1.5, defenseMultiplier: 1.15)
        ])))
    }

    /// The three effects that replaced "ignore armour". Each is checked in its
    /// own envelope, because a zero means something different in each: no
    /// rounds is a debuff that never applies, a crit multiplier at or below the
    /// standard one is a normal hit at double the Vigor, and a zero burn
    /// fraction is a technique with no effect at all.
    private func withEffect(_ effect: SpecialAttackEffectDTO,
                            for cls: String = "warrior") -> [SpecialAttackTuningDTO] {
        [SpecialAttackTuningDTO(characterClass: "warrior", vigor: 4, hitChanceModifier: -10,
                                cannotMiss: false, zeroesDodge: false,
                                effect: cls == "warrior" ? effect : .armourBreak(rounds: 3)),
         SpecialAttackTuningDTO(characterClass: "archer", vigor: 4, hitChanceModifier: 0,
                                cannotMiss: true, zeroesDodge: true,
                                effect: cls == "archer" ? effect : .guaranteedCrit(critMultiplier: 2.0)),
         SpecialAttackTuningDTO(characterClass: "mage", vigor: 5, hitChanceModifier: 0,
                                cannotMiss: true, zeroesDodge: false,
                                effect: cls == "mage" ? effect : .burn(rounds: 3, fractionOfAttack: 0.35))]
    }

    func testZeroRoundEffectIsAnError() {
        assertRule("tuning.combat.effect_rounds",
                   bundle(combat: combat(specialAttack: withEffect(.armourBreak(rounds: 0)))))
    }

    /// A "guaranteed crit" no bigger than the crit the player already rolls for
    /// free is a normal hit that costs twice the Vigor.
    func testGuaranteedCritNoBetterThanStandardIsAnError() {
        assertRule("tuning.combat.effect_crit_not_special",
                   bundle(combat: combat(specialAttack:
                       withEffect(.guaranteedCrit(critMultiplier: 1.5), for: "archer"))))
    }

    func testZeroBurnIsAnError() {
        assertRule("tuning.combat.effect_burn_zero",
                   bundle(combat: combat(specialAttack:
                       withEffect(.burn(rounds: 3, fractionOfAttack: 0), for: "mage"))))
    }

    /// The union must survive JSON: a new effect kind that forgets its encoder
    /// would silently lose its parameters.
    func testSpecialAttackEffectsRoundTrip() throws {
        for effect in [SpecialAttackEffectDTO.armourBreak(rounds: 3),
                       .guaranteedCrit(critMultiplier: 2.0),
                       .burn(rounds: 3, fractionOfAttack: 0.35)] {
            let data = try ContentLoader.makeEncoder().encode(effect)
            XCTAssertEqual(try JSONDecoder().decode(SpecialAttackEffectDTO.self, from: data), effect)
        }
    }

    func testFleeChanceOutOfRangeIsAnError() {
        assertRule("tuning.combat.flee_chance_range", bundle(combat: combat(flee: [
            FleeTuningDTO(characterClass: "warrior", chance: 0, extraVigor: 0),
            FleeTuningDTO(characterClass: "archer", chance: 70, extraVigor: 0),
            FleeTuningDTO(characterClass: "mage", chance: 90, extraVigor: 2)
        ])))
    }

    func testNegativeVigorCostIsAnError() {
        assertRule("tuning.combat.negative_vigor", bundle(combat: combat(specialDefenseVigor: [
            SpecialDefenseClassDTO(characterClass: "warrior", vigor: -1),
            SpecialDefenseClassDTO(characterClass: "archer", vigor: 3),
            SpecialDefenseClassDTO(characterClass: "mage", vigor: 4)
        ])))
    }

    func testBarrierFractionAboveOneIsAnError() {
        assertRule("tuning.combat.barrier_fraction_range", bundle(combat: combat(mageBarrier: 1.5)))
    }

    // MARK: - vigor.json rules

    func testFreeStepIsAnError() {
        assertRule("tuning.vigor.free_step", bundle(vigor: vigor(walkRoom: 0)))
    }

    func testNegativeDrainIsAnError() {
        assertRule("tuning.vigor.negative_drain", bundle(vigor: vigor(idle: -1)))
    }

    func testStarvationOutOfRangeIsAnError() {
        assertRule("tuning.vigor.starvation_range", bundle(vigor: vigor(statPenalty: 1.5)))
    }

    func testNonPositiveIdleWindowIsAnError() {
        assertRule("tuning.vigor.regen_window", bundle(vigor: vigor(maxIdleMinutes: 0)))
    }

    // MARK: - exploration.json rules

    /// `Int.random(in: 0..<total)` traps on a non-positive bound.
    func testNonPositiveWeightTotalIsAnError() {
        assertRule("tuning.exploration.total_non_positive",
                   bundle(exploration: exploration(total: 0, tiers: [
                       EventWeightTierDTO(priorVisits: 0, nothing: 0, loot: 0, encounter: 0, trip: 0)
                   ])))
    }

    func testEmptyWeightTableIsAnError() {
        assertRule("tuning.exploration.tiers_empty", bundle(exploration: exploration(tiers: [])))
    }

    /// The tail row is the fallback for every higher AND every negative visit
    /// count, so a non-contiguous run silently changes which weights a
    /// re-entered room gets.
    func testNonContiguousTiersAreAnError() {
        assertRule("tuning.exploration.tier_not_contiguous", bundle(exploration: exploration(tiers: [
            EventWeightTierDTO(priorVisits: 0, nothing: 10, loot: 50, encounter: 30, trip: 10),
            EventWeightTierDTO(priorVisits: 2, nothing: 20, loot: 50, encounter: 20, trip: 10)
        ])))
    }

    func testWeightsThatDoNotSumAreAnError() {
        assertRule("tuning.exploration.weights_dont_sum", bundle(exploration: exploration(tiers: [
            EventWeightTierDTO(priorVisits: 0, nothing: 10, loot: 50, encounter: 30, trip: 5)
        ])))
    }

    /// The passive table rolls through the same `Int.random(in: 0..<total)` as
    /// the tier ladder, so it needs the same two checks. The tiers are left
    /// VALID here on purpose — otherwise the rule would fire for them and the
    /// test would pass without the passive row ever being looked at.
    func testPassiveWeightsThatDoNotSumAreAnError() {
        assertRule("tuning.exploration.weights_dont_sum", bundle(exploration: exploration(
            passiveWeights: EventWeightsDTO(nothing: 25, loot: 45, encounter: 20, trip: 5))))
    }

    func testNegativePassiveWeightIsAnError() {
        assertRule("tuning.exploration.negative_weight", bundle(exploration: exploration(
            passiveWeights: EventWeightsDTO(nothing: 25, loot: 55, encounter: 20, trip: -10))))
    }

    // MARK: - progression.json rules

    func testFlatXPCurveIsAnError() {
        assertRule("tuning.progression.xp_curve_flat",
                   bundle(progression: progression(exponent: 1.0)))
    }

    func testZeroCurveCoefficientIsAnError() {
        assertRule("tuning.progression.xp_first_cost",
                   bundle(progression: progression(coefficient: 0)))
    }

    /// The pacing identity: if monster XP grows faster than the curve, kills
    /// per level FALL as the player advances and the whole ladder inverts.
    func testMobXPOutrunningTheCurveIsAnError() {
        assertRule("tuning.progression.mob_xp_outruns_curve",
                   bundle(progression: progression(exponent: 3.3, mobExponent: 4.0)))
    }

    /// Without a level-gap penalty, farming ten levels down stays fully
    /// rewarding and the depth ladder becomes dead content.
    func testAbsentXPLevelDiffIsAnError() {
        assertRule("tuning.progression.xp_level_diff_absent",
                   bundle(progression: progression(xpGapPerLevel: 0)))
    }

    func testNegativeGrowthRateIsAnError() {
        assertRule("tuning.progression.negative_growth",
                   bundle(progression: progression(hpRate: -0.01)))
    }

    /// The structural trap the proportional model exists to avoid, arriving
    /// through the data instead of through the code: at a zero rating rate the
    /// crit/dodge/accuracy PERCENTAGES fall every level while the ratings on the
    /// profile screen stand still.
    func testRatingsThatDoNotScaleIsAnError() {
        assertRule("tuning.progression.ratings_do_not_scale",
                   bundle(progression: progression(ratingRate: 0)))
    }

    /// 0.85 where 0.085 was meant multiplies the stat ~18x by the cap.
    func testMisplacedDecimalInAGrowthRateWarns() {
        assertRule("tuning.progression.growth_runaway",
                   bundle(progression: progression(atkRate: 8.5)), severity: .warning)
    }

    func testNonPositiveVigorPoolIsAnError() {
        assertRule("tuning.progression.vigor_pool",
                   bundle(progression: progression(vigorBase: 0)))
    }

    func testUnknownStarterWeaponIsAnError() {
        assertRule("tuning.progression.starter_weapon_unknown",
                   bundle(progression: progression(classes: [
                       ClassStartDTO(characterClass: "warrior", hp: 120, attack: 10, defense: 12,
                                     crit: 5, dodge: 5, accuracy: 10, starterWeaponId: "gear.ghost"),
                       ClassStartDTO(characterClass: "archer", hp: 90, attack: 14, defense: 8,
                                     crit: 10, dodge: 8, accuracy: 14, starterWeaponId: "gear.simple_bow"),
                       ClassStartDTO(characterClass: "mage", hp: 80, attack: 15, defense: 6,
                                     crit: 12, dodge: 6, accuracy: 10, starterWeaponId: "gear.wooden_staff")
                   ])))
    }

    func testEmptyWarehouseTableIsAnError() {
        assertRule("tuning.progression.warehouse_empty", bundle(progression: progression(warehouse: [])))
    }

    func testWarehouseRegressionIsAnError() {
        assertRule("tuning.progression.warehouse_regression",
                   bundle(progression: progression(warehouse: [200, 400, 300])))
    }

    // MARK: - economy.json rules

    /// `MasterCatalog.repairCost` divides by this.
    func testZeroDurabilityIsAnError() {
        assertRule("tuning.economy.durability_non_positive", bundle(economy: economy(durability: 0)))
    }

    func testShaveThatDestroysGearIsAnError() {
        assertRule("tuning.economy.shave_destroys_gear",
                   bundle(economy: economy(durability: 30, shave: 30)))
    }

    // MARK: - time.json rules

    func testNonPositiveDurationIsAnError() {
        assertRule("tuning.time.non_positive", bundle(time: time(travelMinutes: 0)))
    }

    func testSweeperFloorAboveIntervalWarns() {
        assertRule("tuning.time.sweeper_slower_than_interval",
                   bundle(time: time(plotInterval: 30, minSeconds: 60)), severity: .warning)
    }

    /// A protocol floor, not a balance number: below 24 h every delete call
    /// fails and the tavern rows never clear.
    func testTavernBelowTelegramFloorIsAnError() {
        assertRule("tuning.time.tavern_below_telegram_floor",
                   bundle(time: time(tavernDeletable: 3600)))
    }

    func testRolloverHourOutOfRangeIsAnError() {
        assertRule("tuning.time.rollover_hour_range", bundle(time: time(rolloverHour: 25)))
    }

    /// `GameDay` falls back to UTC on an unresolvable id, moving every daily
    /// reset by hours without a single error anywhere.
    func testUnknownTimeZoneIsAnError() {
        assertRule("tuning.time.timezone_unknown", bundle(time: time(timeZone: "Mars/Olympus")))
    }

    // MARK: - time.scale

    /// The knob Phase 4b created by folding three independent `testMode`
    /// booleans into one number. A dev bundle legitimately ships 60; a release
    /// bundle must not, and `--strict` is what enforces it.
    func testNonReleaseScaleWarnsAndStrictPromotesIt() {
        let warning = ContentValidator.validate(bundle(time: time(scale: 60)))
        XCTAssertFalse(warning.hasErrors)
        XCTAssertTrue(warning.warnings.contains { $0.rule == "time.scale_not_one" })

        let strict = ContentValidator.validate(bundle(time: time(scale: 60)), strict: true)
        XCTAssertTrue(strict.hasErrors, "a release build must not be able to ship 60x time compression")
    }

    /// Not a warning: every `gameTime` duration DIVIDES by the scale, so a zero
    /// would trap and a negative would run the clock backwards.
    func testNonPositiveScaleIsAnError() {
        assertRule("time.scale_non_positive", bundle(time: time(scale: 0)))
    }

    /// The base durations in `time.json` are stated at scale 1, so the same
    /// numbers have to produce BOTH pacings by division alone. These are the
    /// pre-4b values the three deleted `testMode` branches used to hardcode —
    /// pinning them here is what keeps a later edit to a base duration from
    /// silently changing what the dev bundle runs at.
    func testBaseDurationsReproduceBothPacings() {
        let game = time().gameTime
        for (scale, travel, unit, interval) in [(1.0, 120.0, 60.0, 3600.0),
                                                (60.0, 2.0, 1.0, 60.0)] {
            XCTAssertEqual(Double(game.travelMinutes) * 60 / scale, travel,
                           "travel at scale \(scale)")
            XCTAssertEqual(game.passiveExpedition.secondsPerUnit / scale, unit,
                           "expedition unit at scale \(scale)")
            XCTAssertEqual(game.plotIntervalSeconds / scale, interval,
                           "plot interval at scale \(scale)")
        }
    }

    // MARK: - The sweeper derivation

    /// The one hand-translation in Phase 4: `tickInterval` was
    /// `testMode ? 60 : 300` and is now `max(minSeconds, interval / divisor)`.
    /// The old function had exactly two reachable outputs, so checking both
    /// against the interval that produces them is a complete equivalence proof.
    /// (The live check runs inside `--content-digest`; this pins the numbers in
    /// the file that feed it.)
    func testSweeperDivisorReproducesBothShippedCadences() {
        let sweeper = time().gameTime.plotSweeper
        let derive: (Double) -> Double = {
            max(sweeper.minSeconds, $0 / Double(sweeper.intervalDivisor))
        }
        XCTAssertEqual(derive(3600), 300, "production cadence must be unchanged")
        XCTAssertEqual(derive(60), 60, "test-mode cadence must be unchanged")
    }
}
