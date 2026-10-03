//
//  EstateScalingTests.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 03.10.2026.
//
//  The forest's strength by estate tier (`spec-bestiary.md` §11): a spawnable
//  creature fights with HP and ATK × `1 + perTier·(tier − 1)`. One formula and
//  one rounding live in `CombatMath`; the bot reaches them through
//  `Enemy.scaled(forEstateTier:)` and `simulate` calls them directly, so what
//  is pinned here is what both of them run.
//
//  The validator's half — a negative step refused, zero legal, the key
//  required — is in `TuningTests`, beside every other tuning rule.
//

import XCTest
@testable import ROIContent
@testable import ROISim

final class EstateScalingTests: XCTestCase {

    /// The repository's own content directory, found from this file.
    private static let contentRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("content/data")

    /// The step the owner decided on 2026-10-02.
    private let decided = EstateScalingDTO(perTier: 0.1)

    /// The viper's authored line — small enough that the rounding shows.
    private let viper = CombatantStats(level: 1, maxHP: 55, attack: 5, defense: 6)

    /// The rabid bear's authored line, ratings and all.
    private let rabidBear = CombatantStats(level: 14, maxHP: 225, attack: 23, defense: 53,
                                           crit: 42, dodge: 16, accuracy: 0)

    // MARK: - The line

    /// ×1.0 at T1 by construction, then +0.1 a tier to ×1.6 at T7.
    func testTheDecidedLine() {
        for tier in 1...7 {
            XCTAssertEqual(CombatMath.estateScale(tier: tier, spec: decided),
                           1 + 0.1 * Double(tier - 1), accuracy: 1e-12, "T\(tier)")
        }
        XCTAssertEqual(CombatMath.estateScale(tier: 7, spec: decided), 1.6, accuracy: 1e-12)
    }

    /// T1 is every player in levels 1–3, so the opening must not move by a
    /// single point.
    func testT1IsTheIdentity() {
        XCTAssertEqual(CombatMath.scaled(viper, forEstateTier: 1, spec: decided), viper)
        XCTAssertEqual(CombatMath.scaled(rabidBear, forEstateTier: 1, spec: decided), rabidBear)
    }

    /// A tier below T1 cannot exist, but if one ever arrived it must not make
    /// the forest weaker than it was authored.
    func testBelowT1NeverWeakensTheForest() {
        for tier in [0, -1, -10] {
            XCTAssertEqual(CombatMath.estateScale(tier: tier, spec: decided), 1.0, "T\(tier)")
            XCTAssertEqual(CombatMath.scaled(viper, forEstateTier: tier, spec: decided), viper)
        }
    }

    /// Zero is the off switch: every tier fights the authored line.
    func testAZeroStepIsOffAtEveryTier() {
        let off = EstateScalingDTO(perTier: 0)
        for tier in 1...9 {
            XCTAssertEqual(CombatMath.scaled(rabidBear, forEstateTier: tier, spec: off), rabidBear,
                           "T\(tier)")
        }
    }

    // MARK: - What moves

    /// HP and ATK move; DEF, the three ratings and the level do not. The level
    /// staying is what keeps `levelDiff` and the XP of a kill untouched.
    func testOnlyHPAndAttackMove() {
        let top = CombatMath.scaled(rabidBear, forEstateTier: 7, spec: decided)
        XCTAssertEqual(top.maxHP, 360)
        XCTAssertEqual(top.attack, 37)
        XCTAssertEqual(top.defense, rabidBear.defense)
        XCTAssertEqual(top.crit, rabidBear.crit)
        XCTAssertEqual(top.dodge, rabidBear.dodge)
        XCTAssertEqual(top.accuracy, rabidBear.accuracy)
        XCTAssertEqual(top.level, rabidBear.level)
    }

    /// A fresh creature is still at full health after scaling — the fight
    /// starts from the HP the status card prints as its maximum.
    func testAFreshCreatureStaysAtFullHealth() {
        for tier in 1...7 {
            let line = CombatMath.scaled(viper, forEstateTier: tier, spec: decided)
            XCTAssertEqual(line.hp, line.maxHP, "T\(tier)")
        }
    }

    /// Half away from zero, which is the rounding the 2026-10-02 measurement
    /// used: 55 × 1.1 = 60.5 → 61, and the viper's 5 × 1.1 = 5.5 → 6, the
    /// +20% at T2 that `spec-bestiary.md` §11.5 names. The boar's 8 × 1.3 =
    /// 10.4 rounds the other way, to 10.
    func testRoundingIsHalfAwayFromZero() {
        let t2 = CombatMath.scaled(viper, forEstateTier: 2, spec: decided)
        XCTAssertEqual(t2.maxHP, 61)
        XCTAssertEqual(t2.attack, 6)
        let boar = CombatantStats(level: 3, maxHP: 101, attack: 8, defense: 18)
        XCTAssertEqual(CombatMath.scaled(boar, forEstateTier: 4, spec: decided).attack, 10)
    }

    /// The same multiplier for every creature at a tier keeps the depth
    /// ladder in order: the deeper creature is still the stronger one.
    func testTheLadderKeepsItsOrder() {
        for tier in 1...7 {
            let shallow = CombatMath.scaled(viper, forEstateTier: tier, spec: decided)
            let deep = CombatMath.scaled(rabidBear, forEstateTier: tier, spec: decided)
            XCTAssertGreaterThan(deep.maxHP, shallow.maxHP, "T\(tier)")
            XCTAssertGreaterThan(deep.attack, shallow.attack, "T\(tier)")
        }
    }

    // MARK: - What ships

    /// The bundle in the repository carries the decided step, and is clean.
    func testTheShippedBundleCarriesTheDecidedStep() throws {
        let bundle = try ContentLoader.load(from: Self.contentRoot)
        let tuning = try XCTUnwrap(bundle.tuning)
        XCTAssertEqual(tuning.combat.estateScaling, decided)
        let report = ContentValidator.validate(bundle)
        XCTAssertFalse(report.errors.contains { $0.rule == "tuning.combat.estate_scaling_negative" })
    }
}
