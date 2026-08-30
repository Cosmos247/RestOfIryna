//
//  SimulatorTests.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 30.08.2026.
//
//  Phase 8. The simulator's job is to be believed, so the parts of it that
//  could be quietly wrong are pinned here.
//
//  The load-bearing test is `testInversionsReproduceTheShippedRoster`. The
//  enemy generator claims the shipped bestiary's DEF, crit and dodge came off
//  the archetype targets rather than off somebody's spreadsheet — and if that
//  claim is false, every generated enemy the report measures is fiction. It is
//  checked against literal numbers copied out of `enemies.json`, so a drift in
//  either the curves or the inversion breaks it.
//

import XCTest
@testable import ROIContent
@testable import ROISim

final class SimulatorTests: XCTestCase {

    // The shipped curves, as `tuning/combat.json` carries them.
    private let mitigation = MitigationCurveDTO(cap: 0.70, kBase: 46.65, kPerLevel: 8.017)
    private let dodge = RatingCurveDTO(scale: 55.0, kBase: 43.32, kPerLevel: 3.682)
    private let crit = RatingCurveDTO(scale: 50.0, kBase: 51.89, kPerLevel: 3.213)
    private let accuracy = RatingCurveDTO(scale: 30.0, kBase: 33.38, kPerLevel: 1.457)

    private func curves() -> CombatCurvesDTO {
        CombatCurvesDTO(mitigation: mitigation, dodge: dodge, crit: crit, accuracy: accuracy)
    }

    private func combat() -> CombatTuningDTO {
        CombatTuningDTO(
            hitChance: HitChanceDTO(base: 85, min: 40, max: 95),
            curves: curves(),
            levelDiff: LevelDiffDTO(perLevel: 0.06, min: 0.25, max: 2.5),
            critMultiplier: 1.5,
            variance: VarianceDTO(min: 0.9, max: 1.1),
            defendChipFraction: 0.3,
            trainingDummyEnemyId: "enemy.training_dummy",
            techniques: [TechniqueTuningDTO(kind: "special_atk", requiredLevel: 8, secondUseAtLevel: 17),
                         TechniqueTuningDTO(kind: "special_def", requiredLevel: 11, secondUseAtLevel: 20),
                         TechniqueTuningDTO(kind: "super", requiredLevel: 14, secondUseAtLevel: 21)],
            stances: StanceSectionDTO(durationRounds: 3, defaultActivationVigor: 4, byId: [
                StanceTuningDTO(id: "bloodlust", characterClass: "warrior", activationVigor: 4,
                                attackMultiplier: 1.35, defenseMultiplier: 1.15,
                                vigorMultiplier: 1.5)]),
            specialAttack: [SpecialAttackTuningDTO(
                characterClass: "warrior", vigor: 4, hitChanceModifier: -10, cannotMiss: false,
                zeroesDodge: false, effect: .armourBreak(rounds: 3))],
            specialDefense: SpecialDefenseSectionDTO(
                effectPersistRounds: 1, ironBulwarkChipFraction: 0.5, shadowVeilDodgeBonus: 50,
                mirrorWardReflectFraction: 0.5,
                byClass: [SpecialDefenseClassDTO(characterClass: "warrior", vigor: 3)]),
            flee: [FleeTuningDTO(characterClass: "warrior", chance: 40, extraVigor: 0)],
            defend: DefendTuningDTO(archerChipMultiplier: 0.5, archerDodgeBonus: 30,
                                     mageBarrierDamageFraction: 0.4))
    }

    private func vigor() -> VigorTuningDTO {
        VigorTuningDTO(
            drain: VigorDrainDTO(walkRoom: 2, walkRoomDoubleSpeed: 4, combatRound: 2,
                                 combatAttack: 2, combatDefend: 1, combatFlee: 3, idle: 0),
            starvation: StarvationDTO(statPenalty: 0.25, hpDrainPercent: 0.05),
            healing: HealingTuningDTO(regenPerMinute: 0.05, maxIdleMinutes: 1440))
    }

    // MARK: - The generator's claim

    /// Every roster enemy's DEF, crit and dodge, rebuilt from its archetype's
    /// target percentages and its level. Values copied from `enemies.json`.
    func testInversionsReproduceTheShippedRoster() {
        // (level, mitigation%, dodge%, crit%, shipped DEF, dodge, crit)
        let roster: [(String, Int, Double, Double, Double, Int, Int, Int)] = [
            ("wild_boar",     1, 10, 0,  0,   6,  0,  0),
            ("wild_moose",    6, 20, 3,  5,  24,  4,  8),
            ("wild_buffalo", 11, 32, 0,  5,  63,  0, 10),
            ("rabid_lynx",   11, 12, 15, 12, 18, 31, 28),
            ("rabid_wolf",   16, 20, 3,  5,  44,  6, 11),
            ("wild_bear",    21, 32, 0,  5, 101,  0, 13),
            ("rabid_bear",   25, 25, 8,  15, 82, 23, 57),
        ]
        for (id, level, mit, dod, cri, wantDEF, wantDodge, wantCrit) in roster {
            XCTAssertEqual(EnemyGenerator.defense(forMitigationPercent: mit, level: level,
                                                  curve: mitigation), wantDEF,
                           "\(id): DEF off the mitigation inversion")
            XCTAssertEqual(EnemyGenerator.rating(forPercent: dod, level: level, curve: dodge),
                           wantDodge, "\(id): dodge off the rating inversion")
            XCTAssertEqual(EnemyGenerator.rating(forPercent: cri, level: level, curve: crit),
                           wantCrit, "\(id): crit off the rating inversion")
        }
    }

    /// The inversions must be the exact left inverse of the curves they undo —
    /// checked as a round trip, so neither side can drift alone.
    func testInversionsRoundTripThroughTheCurves() {
        for level in [1, 7, 20, 40] {
            for target in [3.0, 8.0, 15.0, 25.0] {
                let rating = EnemyGenerator.rating(forPercent: target, level: level, curve: dodge)
                let back = CombatMath.percent(dodge, rating: rating, level: level)
                XCTAssertEqual(back, target, accuracy: 0.6,
                               "dodge \(target)% at L\(level) came back as \(back)%")
            }
            for target in [10.0, 25.0, 40.0] {
                let def = EnemyGenerator.defense(forMitigationPercent: target, level: level,
                                                 curve: mitigation)
                let back = CombatMath.mitigation(defenderDEF: def, defenderLevel: level,
                                                 curve: mitigation) * 100
                XCTAssertEqual(back, target, accuracy: 0.6,
                               "mitigation \(target)% at L\(level) came back as \(back)%")
            }
        }
    }

    /// Nobody becomes untouchable however extreme the target, and an
    /// unreachable one saturates instead of dividing by zero.
    func testInversionsRefuseTheImpossible() {
        XCTAssertEqual(EnemyGenerator.defense(forMitigationPercent: 0, level: 10, curve: mitigation), 0)
        XCTAssertEqual(EnemyGenerator.rating(forPercent: 0, level: 10, curve: dodge), 0)
        // A dodge target at or above the curve's own scale cannot be bought.
        XCTAssertGreaterThan(EnemyGenerator.rating(forPercent: dodge.scale, level: 10, curve: dodge),
                             1_000_000)
        // …and past the mitigation cap, absorption still stops at the cap.
        let absurd = EnemyGenerator.defense(forMitigationPercent: 99, level: 10, curve: mitigation)
        XCTAssertLessThanOrEqual(
            CombatMath.mitigation(defenderDEF: absurd, defenderLevel: 10, curve: mitigation),
            mitigation.cap)
    }

    // MARK: - Determinism

    /// The same seed must roll the same fight, or nothing in the report is
    /// reproducible and "the numbers moved" stops being evidence.
    func testSameSeedSameFight() {
        let simulator = FightSimulator(combat: combat(), vigor: vigor())
        let player = CombatantStats(level: 10, maxHP: 200, attack: 30, defense: 40,
                                    crit: 10, dodge: 8, accuracy: 15)
        let enemy = CombatantStats(level: 10, maxHP: 160, attack: 22, defense: 30,
                                   crit: 6, dodge: 4)
        func run(_ seed: UInt64) -> [String] {
            var rng = SplitMix64(seed: seed)
            return (0..<50).map { _ in
                let o = simulator.fight(player: player, characterClass: "warrior",
                                        enemy: enemy, profile: .basic, using: &rng)
                return "\(o.won)/\(o.rounds)/\(o.hpLost)/\(o.vigorSpent)"
            }
        }
        XCTAssertEqual(run(99), run(99))
        XCTAssertNotEqual(run(99), run(100))
    }

    /// A fight the player cannot lose still ends, and one nobody can win is
    /// reported as a stalemate rather than as a win for the side that survived.
    func testStalemateIsNeitherAWinNorALoss() {
        let simulator = FightSimulator(combat: combat(), vigor: vigor(), maxRounds: 12)
        var rng = SplitMix64(seed: 7)
        let wall = CombatantStats(level: 10, maxHP: 100_000, attack: 0, defense: 400)
        let player = CombatantStats(level: 10, maxHP: 500, attack: 5, defense: 200)
        let outcome = simulator.fight(player: player, characterClass: "warrior",
                                      enemy: wall, profile: .basic, using: &rng)
        XCTAssertTrue(outcome.stalemate)
        XCTAssertFalse(outcome.won)
        XCTAssertEqual(outcome.rounds, 12)
    }

    // MARK: - Percentiles

    func testNearestRankPercentiles() {
        let d = Distribution((1...100).map(Double.init))
        XCTAssertEqual(d.p50, 50, accuracy: 0.001)
        XCTAssertEqual(d.p90, 90, accuracy: 0.001)
        XCTAssertEqual(d.p99, 99, accuracy: 0.001)
        XCTAssertEqual(d.mean, 50.5, accuracy: 0.001)
        // A percentile is always a value that actually occurred.
        XCTAssertEqual(Distribution([5, 5, 5, 100]).p90, 100, accuracy: 0.001)
        XCTAssertEqual(Distribution([]).count, 0)
    }

    // MARK: - Progression

    /// The design's published XP costs. Same anchors `--content-digest` checks,
    /// pinned here so they survive without a database.
    func testXPCurveHitsTheDesignAnchors() {
        let curve = XPCurveDTO(coefficient: 11.4, exponent: 3.30, floorPerLevel: 120)
        for (level, want) in [(2, 120.0), (6, 2309.0), (11, 22746.0), (21, 224029.0)] {
            let got = Double(ProgressionMath.xpRequiredToReach(level, curve: curve, maxLevel: 40))
            XCTAssertEqual(got / want, 1.0, accuracy: 0.005, "xpToNext(L\(level - 1))")
        }
        XCTAssertEqual(ProgressionMath.xpRequiredToReach(1, curve: curve, maxLevel: 40), Int.max)
        XCTAssertEqual(ProgressionMath.xpRequiredToReach(41, curve: curve, maxLevel: 40), Int.max)
        // The total is the number that decides months-to-cap, and it is the sum
        // of exactly the levels that are payable.
        let total = ProgressionMath.totalXP(toReach: 40, curve: curve, maxLevel: 40)
        let byHand = (2...40).map { ProgressionMath.xpRequiredToReach($0, curve: curve, maxLevel: 40) }
            .reduce(0, +)
        XCTAssertEqual(total, byHand)
    }

    /// Proportional growth: a rating must keep pace with its own denominator,
    /// which is what the flat +1/level model failed to do.
    func testStatGrowthIsProportional() {
        let start = ClassStartDTO(characterClass: "warrior", hp: 120, attack: 10, defense: 12,
                                  crit: 5, dodge: 5, accuracy: 10, starterWeaponId: "gear.sword")
        let growth = StatGrowthDTO(hpPerLevel: 0.056, attackPerLevel: 0.1, ratingPerLevel: 0.085)
        let one = ProgressionMath.baseStats(start: start, growth: growth, level: 1)
        XCTAssertEqual(one.maxHp, 120)
        XCTAssertEqual(one.attack, 10)
        XCTAssertEqual(one.dodge, 5)
        let forty = ProgressionMath.baseStats(start: start, growth: growth, level: 40)
        XCTAssertEqual(forty.maxHp, 382)
        XCTAssertEqual(forty.attack, 49)
        XCTAssertEqual(forty.dodge, 22)
        // Below level 1 clamps rather than shrinking the character.
        XCTAssertEqual(ProgressionMath.baseStats(start: start, growth: growth, level: 0).maxHp, 120)
    }
}
