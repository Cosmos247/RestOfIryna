//
//  BestiaryTests.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 30.08.2026.
//
//  Phase 5A. The archetype table is design input for the bestiary generator
//  AND runtime data — its multipliers price XP and loot on every kill, and its
//  five target percentages are what `EnemyGenerator` inverts into an enemy's
//  stats — so it is validated as strictly as a tuning table. (The silver
//  multiplier went with the monster-coin mechanic in Phase 8C.)
//
//  The depth-coverage rules are the ones worth the most. `pickFor` used to
//  answer an uncovered km with `all.first`, which read as "every encounter past
//  km 35 is a wild boar" rather than as missing content: the deepest zone in
//  the game was also its easiest, silently. The roll now returns nil and the
//  gap is a finding here instead.
//

import XCTest
@testable import ROIContent

final class BestiaryTests: XCTestCase {

    private func archetype(_ id: String, rounds: Double = 5, hpLoss: Double = 24,
                           mitigation: Double = 20, dodge: Double = 3, crit: Double = 5,
                           xp: Double = 1, loot: Double = 1,
                           weight: Double = 60, floor: Int = 1) -> EnemyArchetypeDTO {
        EnemyArchetypeDTO(id: id, rounds: rounds, hpLossPercent: hpLoss,
                          mitigationPercent: mitigation, dodgePercent: dodge,
                          critPercent: crit, xpMultiplier: xp, lootMultiplier: loot,
                          spawnWeight: weight, minLevel: floor)
    }

    /// The shipped floors: an elite (and a boss) may not be authored below
    /// level 14. Used by the floor tests so they read against the real table
    /// rather than a number invented in the fixture.
    private func archetypesWithShippedFloors() -> [EnemyArchetypeDTO] {
        ["trash", "normal", "skirmisher", "brute"].map { archetype($0) }
            + ["elite", "boss"].map { archetype($0, floor: 14) }
    }

    private func allArchetypes() -> [EnemyArchetypeDTO] {
        ["trash", "normal", "skirmisher", "brute", "elite", "boss"].map { archetype($0) }
    }

    private func enemy(_ id: String = "enemy.x", level: Int = 1, archetype: String = "trash",
                       depth: IntRangeDTO? = IntRangeDTO(min: 1, max: 40),
                       weight: Double? = nil) -> EnemyDTO {
        EnemyDTO(id: id, tier: 1, icon: "🐗", xpReward: 5,
                 stats: EnemyStatsDTO(hp: 10, attack: 3, defense: 1),
                 depth: depth, level: level, archetype: archetype,
                 spawnWeight: weight)
    }

    /// `maxLevel` comes from the tuning bundle, and the coverage + level-cap
    /// rules need it, so every fixture carries a minimal one.
    private func bundle(enemies: [EnemyDTO], archetypes: [EnemyArchetypeDTO]? = nil,
                        maxLevel: Int = 40) -> ContentBundle {
        ContentBundle(
            manifest: ManifestDTO(schemaVersion: ContentSchema.current),
            items: [], enemies: enemies, enemyArchetypes: archetypes ?? allArchetypes(),
            recipes: [], starterRecipeIds: [],
            tuning: TuningBundleDTO(
                combat: CombatTuningDTO(
                    hitChance: HitChanceDTO(base: 85, min: 40, max: 95),
                    curves: CombatCurvesDTO(
                        mitigation: MitigationCurveDTO(cap: 0.70, kBase: 46.65, kPerLevel: 8.017),
                        dodge: RatingCurveDTO(scale: 55, kBase: 43.32, kPerLevel: 3.682),
                        crit: RatingCurveDTO(scale: 50, kBase: 51.89, kPerLevel: 3.213),
                        accuracy: RatingCurveDTO(scale: 30, kBase: 33.38, kPerLevel: 1.457)),
                    levelDiff: LevelDiffDTO(perLevel: 0.06, min: 0.25, max: 2.5),
                    critMultiplier: 1.5,
                    variance: VarianceDTO(min: 0.9, max: 1.1), defendChipFraction: 0.3,
                    trainingDummyEnemyId: "enemy.x", techniques: [], 
                    stances: StanceSectionDTO(durationRounds: 3, defaultActivationVigor: 4, byId: []),
                    specialAttack: [],
                    specialDefense: SpecialDefenseSectionDTO(
                        effectPersistRounds: 1, ironBulwarkChipFraction: 0.5,
                        shadowVeilDodgeMultiplier: 2.0, mirrorWardReflectFraction: 0.5, byClass: []),
                    flee: [],
                    defend: DefendTuningDTO(archerChipMultiplier: 0.5, archerDodgeMultiplier: 1.5,
                                            mageBarrierDamageFraction: 0.4)),
                vigor: VigorTuningDTO(
                    drain: VigorDrainDTO(walkRoom: 2, walkRoomDoubleSpeed: 4, combatRound: 1,
                                         combatAttack: 2, combatDefend: 1, combatFlee: 3, idle: 0),
                    starvation: StarvationDTO(statPenalty: 0.25, hpDrainPercent: 0.05),
                    healing: HealingTuningDTO(regenPerMinute: 0.05, maxIdleMinutes: 1440)),
                exploration: ExplorationTuningDTO(
                    eventWeightTotal: 100, tripDamagePercent: 0.05,
                    weightTiers: [EventWeightTierDTO(priorVisits: 0, nothing: 10, loot: 50,
                                                     encounter: 30, trip: 10)],
                    passive: PassiveExpeditionTuningDTO(xpMultiplier: 0.7,
                                                        lootMultiplier: 1.0, freshStepCount: 1,
                                                        weights: EventWeightsDTO(nothing: 25, loot: 45, encounter: 20, trip: 10))),
                progression: ProgressionTuningDTO(
                    maxLevel: maxLevel,
                    xpCurve: XPCurveDTO(coefficient: 11.4, exponent: 3.30, floorPerLevel: 120),
                    mobXP: MobXPDTO(coefficient: 26, exponent: 1.55),
                    xpLevelDiff: XPLevelDiffDTO(perLevel: 0.08, min: 0.10, max: 1.00),
                    statGrowth: StatGrowthDTO(hpPerLevel: 0.056, attackPerLevel: 0.1,
                                              ratingPerLevel: 0.085),
                    vigorPool: VigorPoolDTO(base: 100, perLevel: 5),
                    classes: [], warehouseCapByEstateLevel: [200]),
                economy: EconomyTuningDTO(gear: GearEconomyDTO(
                    maxDurabilityStart: 30, repairMaxShave: 1,
                    wearBudget: WearBudgetDTO(victory: 1, defeat: 3, flee: 3)), questRewards: QuestRewardTuningDTO(silverPerLevel: 0.015)),
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
                                          dayTimeZoneId: "Europe/Kyiv"))),
            contentHash: "test")
    }

    private func assertRule(_ rule: String, _ bundle: ContentBundle,
                            severity: ContentIssue.Severity = .error,
                            file: StaticString = #filePath, line: UInt = #line) {
        let report = ContentValidator.validate(bundle)
        let matching = (severity == .error ? report.errors : report.warnings)
        XCTAssertTrue(matching.contains { $0.rule == rule },
                      "expected \"\(rule)\", got \(matching.map(\.rule))", file: file, line: line)
    }

    // MARK: - The fixture itself is clean

    /// Scoped to the `enemy.` rules on purpose: the fixture's tuning sections
    /// are deliberately minimal (empty class and technique tables), so asserting
    /// "no errors at all" would be asserting things this file does not test.
    func testWellFormedBestiaryHasNoBestiaryErrors() {
        let report = ContentValidator.validate(bundle(enemies: [enemy()]))
        let bestiary = report.errors.filter { $0.rule.hasPrefix("enemy.") }
        XCTAssertTrue(bestiary.isEmpty, "clean bestiary produced: \(bestiary.map(\.rule))")
    }

    // MARK: - Archetype table

    func testMissingArchetypeRowIsAnError() {
        assertRule("enemy.archetype_missing",
                   bundle(enemies: [enemy()], archetypes: [archetype("trash")]))
    }

    func testUnknownArchetypeInTableIsAnError() {
        assertRule("enemy.archetype_unknown",
                   bundle(enemies: [enemy()], archetypes: allArchetypes() + [archetype("dragon")]))
    }

    func testDuplicateArchetypeRowIsAnError() {
        assertRule("identity.duplicate_id",
                   bundle(enemies: [enemy()], archetypes: allArchetypes() + [archetype("trash")]))
    }

    // MARK: - The archetype level floor
    //
    // Phase 8D. An elite costs 62% of a bar by contract and its p99 is a death;
    // below level 14 the player has no technique unlocked at all, so the fight
    // is the `basic` row with nothing to spend. Enemy stats are frozen at
    // design time, which makes this file the only place the floor can break —
    // and the generator that fills the table in Phase 10 is why it is checked
    // now rather than then.

    func testEliteBelowItsArchetypeFloorIsAnError() {
        assertRule("enemy.below_archetype_floor",
                   bundle(enemies: [enemy("enemy.cub", level: 13, archetype: "elite")],
                          archetypes: archetypesWithShippedFloors()))
    }

    func testEliteAtItsArchetypeFloorIsClean() {
        let report = ContentValidator.validate(
            bundle(enemies: [enemy("enemy.cub", level: 14, archetype: "elite")],
                   archetypes: archetypesWithShippedFloors()))
        XCTAssertFalse(report.errors.contains { $0.rule == "enemy.below_archetype_floor" },
                       "level 14 is the floor itself and must pass")
    }

    /// Deliberately no exception for the `0...0` sentinel. A row that never
    /// spawns from the wilderness is still reachable through training and
    /// scripted hooks, and a rule with an "unless it is unreachable" clause
    /// is a rule nobody can check.
    func testArchetypeFloorAppliesToNonSpawningRowsToo() {
        assertRule("enemy.below_archetype_floor",
                   bundle(enemies: [enemy("enemy.cub", level: 5, archetype: "elite",
                                          depth: IntRangeDTO(min: 0, max: 0))],
                          archetypes: archetypesWithShippedFloors()))
    }

    func testArchetypeFloorAboveTheLevelCapIsAnError() {
        var table = allArchetypes()
        table[4] = archetype("elite", floor: 41)
        assertRule("enemy.archetype_floor_above_cap",
                   bundle(enemies: [enemy()], archetypes: table, maxLevel: 40))
    }

    func testArchetypeFloorBelowOneIsAnError() {
        var table = allArchetypes()
        table[0] = archetype("trash", floor: 0)
        assertRule("enemy.archetype_floor_range", bundle(enemies: [enemy()], archetypes: table))
    }

    func testNonPositiveRoundsIsAnError() {
        var table = allArchetypes()
        table[0] = archetype("trash", rounds: 0)
        assertRule("enemy.archetype_rounds", bundle(enemies: [enemy()], archetypes: table))
    }

    /// An archetype that costs no HP is not a difficulty setting, it is an
    /// encounter the player cannot lose — and the generator divides by it.
    func testZeroDangerIsAnError() {
        var table = allArchetypes()
        table[0] = archetype("trash", hpLoss: 0)
        assertRule("enemy.archetype_danger", bundle(enemies: [enemy()], archetypes: table))
    }

    func testPercentOutOfRangeIsAnError() {
        var table = allArchetypes()
        table[0] = archetype("trash", dodge: 140)
        assertRule("enemy.archetype_percent_range", bundle(enemies: [enemy()], archetypes: table))
    }

    /// A zero XP multiplier silently makes an entire archetype worthless to
    /// fight; it must be stated as an error rather than read as "no reward".
    func testZeroMultiplierIsAnError() {
        var table = allArchetypes()
        table[0] = archetype("trash", xp: 0)
        assertRule("enemy.archetype_multiplier", bundle(enemies: [enemy()], archetypes: table))
    }

    // MARK: - Per-enemy design fields

    func testUnknownArchetypeOnAnEnemyIsAnError() {
        assertRule("enemy.archetype_unknown", bundle(enemies: [enemy(archetype: "dragon")]))
    }

    func testLevelBelowOneIsAnError() {
        assertRule("enemy.level_range", bundle(enemies: [enemy(level: 0)]))
    }

    func testLevelAboveThePlayerCapWarns() {
        assertRule("enemy.level_above_cap", bundle(enemies: [enemy(level: 99)]), severity: .warning)
    }

    func testNegativeSpawnWeightIsAnError() {
        assertRule("enemy.negative_weight", bundle(enemies: [enemy(weight: -1)]))
    }

    // MARK: - Depth coverage

    /// The rule that replaces the `?? all.first` lie. A roster covering 1...10
    /// leaves 11...40 with no encounter at all, and that has to be visible.
    func testUncoveredDepthWarns() {
        assertRule("enemy.depth_gap",
                   bundle(enemies: [enemy(depth: IntRangeDTO(min: 1, max: 10))]),
                   severity: .warning)
    }

    /// The `0...0` sentinel means "never spawns" (the training dummy, the
    /// scripted registration dog). Counting those as coverage would hide every
    /// real gap behind two enemies the player can never meet in the wild.
    func testSentinelDepthDoesNotCountAsCoverage() {
        assertRule("enemy.depth_gap",
                   bundle(enemies: [enemy(depth: IntRangeDTO(min: 0, max: 0))]),
                   severity: .warning)
    }

    /// All-zero weights would make the weighted roll fall back to a uniform
    /// draw — the weights would be silently ignored rather than obeyed.
    func testBandWhereEveryCandidateIsWeightedZeroIsAnError() {
        assertRule("enemy.band_all_zero_weight", bundle(enemies: [enemy(weight: 0)]))
    }
}
