//
//  DuelMathTests.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 03.10.2026.
//
//  One round of the Arena duel, both fighters at once (2026-10-03). The bot
//  reaches `DuelMath.resolveRound` through `CombatService.resolveDuelRound`,
//  so what is pinned here is the round the bot plays.
//
//  Chips carry the knockout cases: a Defend's chip always lands and is never
//  below 1, so a fighter on 1 HP falls to it whatever the generator draws —
//  the only way to make "both fall" deterministic without reaching into the
//  dice.
//

import XCTest
@testable import ROIContent
@testable import ROISim

final class DuelMathTests: XCTestCase {

    /// The repository's own content directory, found from this file.
    private static let contentRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("content/data")

    private func shippedContent() throws -> GameContent {
        GameContent(try ContentLoader.load(from: Self.contentRoot))
    }

    private func shippedRules() throws -> CombatRules {
        CombatRules(try XCTUnwrap(try shippedContent().tuning).combat)
    }

    private func fighter(hp: Int, attack: Int, defense: Int = 0, dodge: Int = 0) -> CombatantStats {
        CombatantStats(level: 10, maxHP: hp, hp: hp, attack: attack, defense: defense, dodge: dodge)
    }

    // MARK: - Both blows at once

    /// Each blow lands on the other fighter's HP as the round found it, and a
    /// round nobody falls in goes on.
    func testBothBlowsLandAgainstTheRoundsStartingHP() throws {
        let rules = try shippedRules()
        let a = fighter(hp: 1_000, attack: 40), b = fighter(hp: 900, attack: 30)
        for seed in UInt64(1)...200 {
            var rng = SplitMix64(seed: seed)
            let round = DuelMath.resolveRound(a: a, aAction: .attack, b: b, bAction: .attack,
                                              rules: rules, using: &rng)
            XCTAssertEqual(round.aHP, a.hp - round.b.damage, "seed \(seed)")
            XCTAssertEqual(round.bHP, b.hp - round.a.damage, "seed \(seed)")
            XCTAssertEqual(round.verdict, .continues, "seed \(seed)")
            XCTAssertFalse(round.bothFell)
        }
    }

    /// A Defend braces against the attack of the SAME round: with the same
    /// draws, the attack that meets a brace does less. `a` rolls first, so
    /// swapping `b`'s action leaves `a`'s draws untouched.
    func testABraceBluntsTheSameRoundsAttack() throws {
        let rules = try shippedRules()
        let a = fighter(hp: 1_000, attack: 100), b = fighter(hp: 1_000, attack: 10, defense: 60)
        var compared = 0
        for seed in UInt64(1)...200 {
            var open = SplitMix64(seed: seed), braced = SplitMix64(seed: seed)
            let plain = DuelMath.resolveRound(a: a, aAction: .attack, b: b, bAction: .attack,
                                              rules: rules, using: &open)
            let guarded = DuelMath.resolveRound(a: a, aAction: .attack, b: b, bAction: .defend,
                                                rules: rules, using: &braced)
            XCTAssertEqual(plain.a.outcome == .miss, guarded.a.outcome == .miss, "seed \(seed)")
            guard plain.a.damage > 0 else {
                XCTAssertFalse(guarded.a.throughBrace, "a miss went through nothing")
                continue
            }
            XCTAssertLessThan(guarded.a.damage, plain.a.damage, "seed \(seed)")
            XCTAssertTrue(guarded.a.throughBrace)
            XCTAssertFalse(plain.a.throughBrace)
            compared += 1
        }
        XCTAssertGreaterThan(compared, 100, "most seeds should land a hit")
    }

    /// A brace guards against attacks, not against another chip: when both
    /// defend, each chip is read against the other's DEF as it stands.
    func testABraceDoesNotBluntAChip() throws {
        let rules = try shippedRules()
        let a = fighter(hp: 1_000, attack: 100), b = fighter(hp: 1_000, attack: 10, defense: 60)
        for seed in UInt64(1)...50 {
            var oneBraces = SplitMix64(seed: seed), bothBrace = SplitMix64(seed: seed)
            let open = DuelMath.resolveRound(a: a, aAction: .defend, b: b, bAction: .attack,
                                             rules: rules, using: &oneBraces)
            let braced = DuelMath.resolveRound(a: a, aAction: .defend, b: b, bAction: .defend,
                                               rules: rules, using: &bothBrace)
            XCTAssertEqual(open.a.damage, braced.a.damage, "seed \(seed)")
            XCTAssertNil(braced.a.outcome, "a Defend has no roll to show")
            XCTAssertFalse(braced.a.throughBrace)
        }
    }

    // MARK: - Who wins

    /// One fighter falls, the other stands: a plain knockout.
    func testAKnockoutGoesToTheOneStillStanding() throws {
        let rules = try shippedRules()
        var rng = SplitMix64(seed: 7)
        let round = DuelMath.resolveRound(a: fighter(hp: 1_000, attack: 50), aAction: .defend,
                                          b: fighter(hp: 1, attack: 50), bAction: .defend,
                                          rules: rules, using: &rng)
        XCTAssertEqual(round.verdict, .aWins)
        XCTAssertFalse(round.bothFell)
        XCTAssertEqual(round.bHP, 0)
    }

    /// Both fall in the same round: the heavier blow wins it, whichever side
    /// threw it (the owner's call, 2026-10-03).
    func testTheHeavierBlowWinsWhenBothFall() throws {
        let rules = try shippedRules()
        let heavy = fighter(hp: 1, attack: 200), light = fighter(hp: 1, attack: 1)

        var rng = SplitMix64(seed: 11)
        let aHeavier = DuelMath.resolveRound(a: heavy, aAction: .defend, b: light, bAction: .defend,
                                             rules: rules, using: &rng)
        XCTAssertTrue(aHeavier.bothFell)
        XCTAssertGreaterThan(aHeavier.a.damage, aHeavier.b.damage)
        XCTAssertEqual(aHeavier.verdict, .aWins)

        let bHeavier = DuelMath.resolveRound(a: light, aAction: .defend, b: heavy, bAction: .defend,
                                             rules: rules, using: &rng)
        XCTAssertTrue(bHeavier.bothFell)
        XCTAssertEqual(bHeavier.verdict, .bWins)
    }

    /// Blows of the same size when both fall are a draw — a 1-ATK chip is
    /// floored to exactly 1 on either side.
    func testEqualBlowsWhenBothFallAreADraw() throws {
        let rules = try shippedRules()
        var rng = SplitMix64(seed: 3)
        let round = DuelMath.resolveRound(a: fighter(hp: 1, attack: 1), aAction: .defend,
                                          b: fighter(hp: 1, attack: 1), bAction: .defend,
                                          rules: rules, using: &rng)
        XCTAssertEqual(round.a.damage, 1)
        XCTAssertEqual(round.b.damage, 1)
        XCTAssertTrue(round.bothFell)
        XCTAssertEqual(round.verdict, .draw)
    }

    // MARK: - Fairness

    /// The reason the duel went simultaneous: alternating, the challenger won
    /// 60–66% of mirror duels. Played at once, neither side of the pairing
    /// may be worth more than a few points. Seeded, so it cannot flake.
    func testNeitherSideOfAMirrorDuelIsAhead() throws {
        let content = try shippedContent()
        let tuning = try XCTUnwrap(content.tuning)
        let budget = try XCTUnwrap(content.budget)
        let rules = CombatRules(tuning.combat)
        let archer = try XCTUnwrap(ReferenceCharacter.build(
            characterClass: "archer", level: 10, gearOffset: -ReferenceCharacter.ladderRung,
            progression: tuning.progression, budget: budget, rarities: content.rarities)).stats

        var rng = SplitMix64(seed: 20261003)
        var aWins = 0, bWins = 0
        let duels = 20_000
        for _ in 0..<duels {
            var a = archer, b = archer
            while true {
                let round = DuelMath.resolveRound(a: a, aAction: .attack, b: b, bAction: .attack,
                                                  rules: rules, using: &rng)
                a.hp = round.aHP
                b.hp = round.bHP
                if round.verdict == .aWins { aWins += 1; break }
                if round.verdict == .bWins { bWins += 1; break }
                if round.verdict == .draw { break }
            }
        }
        let gap = abs(Double(aWins - bWins)) / Double(duels)
        XCTAssertLessThan(gap, 0.03, "a \(aWins) vs b \(bWins) of \(duels)")
    }

    // MARK: - Missed rounds

    func testWalkover() {
        XCTAssertEqual(DuelMath.walkover(missedA: 2, missedB: 0, limit: 3), .none)
        XCTAssertEqual(DuelMath.walkover(missedA: 3, missedB: 2, limit: 3), .aForfeits)
        XCTAssertEqual(DuelMath.walkover(missedA: 0, missedB: 3, limit: 3), .bForfeits)
        XCTAssertEqual(DuelMath.walkover(missedA: 3, missedB: 3, limit: 3), .abandoned)
    }
}
