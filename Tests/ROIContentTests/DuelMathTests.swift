//
//  DuelMathTests.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 03.10.2026.
//
//  One round of the Arena duel, both fighters at once (2026-10-03). The bot
//  reaches `DuelMath.resolveRound` through `CombatService.resolveDuelRound`,
//  so what is pinned here is the round the bot plays — since the same day a
//  cycle of three: Attack beats a technique, a technique breaks a Defend, a
//  Defend turns an Attack.
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

    private func shippedDuel() throws -> DuelMath.Rules {
        DuelMath.Rules(try XCTUnwrap(try shippedContent().arena).duel)
    }

    private func fighter(hp: Int, attack: Int, defense: Int = 0, dodge: Int = 0) -> CombatantStats {
        CombatantStats(level: 10, maxHP: hp, hp: hp, attack: attack, defense: defense, dodge: dodge)
    }

    // MARK: - Both blows at once

    /// Each blow lands on the other fighter's HP as the round found it, and a
    /// round nobody falls in goes on.
    func testBothBlowsLandAgainstTheRoundsStartingHP() throws {
        let rules = try shippedRules(), duel = try shippedDuel()
        let a = fighter(hp: 1_000, attack: 40), b = fighter(hp: 900, attack: 30)
        for seed in UInt64(1)...200 {
            var rng = SplitMix64(seed: seed)
            let round = DuelMath.resolveRound(a: a, aAction: .attack, b: b, bAction: .attack,
                                              rules: rules, duel: duel, using: &rng)
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
        let rules = try shippedRules(), duel = try shippedDuel()
        let a = fighter(hp: 1_000, attack: 100), b = fighter(hp: 1_000, attack: 10, defense: 60)
        var compared = 0
        for seed in UInt64(1)...200 {
            var open = SplitMix64(seed: seed), braced = SplitMix64(seed: seed)
            let plain = DuelMath.resolveRound(a: a, aAction: .attack, b: b, bAction: .attack,
                                              rules: rules, duel: duel, using: &open)
            let guarded = DuelMath.resolveRound(a: a, aAction: .attack, b: b, bAction: .defend,
                                                rules: rules, duel: duel, using: &braced)
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

    /// A block guards against attacks, not against another chip: when both
    /// defend, each chip is read against the other's DEF as it stands — the
    /// same number `CombatMath` gives at the arena's chip fraction.
    func testABlockDoesNotBluntAChip() throws {
        let rules = try shippedRules(), duel = try shippedDuel()
        let a = fighter(hp: 1_000, attack: 100), b = fighter(hp: 1_000, attack: 10, defense: 60)
        for seed in UInt64(1)...50 {
            var round = SplitMix64(seed: seed), bare = SplitMix64(seed: seed)
            let braced = DuelMath.resolveRound(a: a, aAction: .defend, b: b, bAction: .defend,
                                               rules: rules, duel: duel, using: &round)
            let chip = CombatMath.chipDamage(attackerATK: a.attack, defenderDEF: b.defense,
                                             defenderLevel: b.level, fraction: duel.chipFraction,
                                             rules: rules, using: &bare)
            XCTAssertEqual(braced.a.damage, chip, "seed \(seed)")
            XCTAssertEqual(braced.a.kind, .chip)
            XCTAssertNil(braced.a.outcome, "a Defend has no roll to show")
            XCTAssertFalse(braced.a.throughBrace)
        }
    }

    // MARK: - The cycle

    /// Each edge of the cycle, one round at a time.
    func testEachPairingPlaysItsEdgeOfTheCycle() throws {
        let rules = try shippedRules(), duel = try shippedDuel()
        let a = fighter(hp: 1_000, attack: 60, defense: 20), b = fighter(hp: 1_000, attack: 60, defense: 20)
        for seed in UInt64(1)...100 {
            var rng = SplitMix64(seed: seed)
            // Attack beats a technique: the wind-up is cut off.
            let cut = DuelMath.resolveRound(a: a, aAction: .attack, b: b, bAction: .technique,
                                            rules: rules, duel: duel, using: &rng)
            XCTAssertEqual(cut.a.kind, .strike)
            XCTAssertEqual(cut.b.kind, .interrupted)
            XCTAssertEqual(cut.b.damage, 0)

            // A technique breaks a Defend: it lands, the guard answers nothing.
            let broke = DuelMath.resolveRound(a: a, aAction: .technique, b: b, bAction: .defend,
                                              rules: rules, duel: duel, using: &rng)
            XCTAssertEqual(broke.a.kind, .technique)
            XCTAssertGreaterThan(broke.a.damage, 0, "a technique cannot miss a defender")
            XCTAssertEqual(broke.b.kind, .guardBroken)
            XCTAssertEqual(broke.b.damage, 0)

            // A Defend turns an Attack: blocked, and answered.
            let turned = DuelMath.resolveRound(a: a, aAction: .defend, b: b, bAction: .attack,
                                               rules: rules, duel: duel, using: &rng)
            XCTAssertEqual(turned.a.kind, .riposte)
            XCTAssertGreaterThan(turned.a.damage, 0)
            XCTAssertEqual(turned.b.throughBrace, turned.b.damage > 0)

            // Two techniques meet and neither lands.
            let clash = DuelMath.resolveRound(a: a, aAction: .technique, b: b, bAction: .technique,
                                              rules: rules, duel: duel, using: &rng)
            XCTAssertEqual(clash.a.kind, .clashed)
            XCTAssertEqual(clash.b.kind, .clashed)
            XCTAssertEqual(clash.a.damage + clash.b.damage, 0)
        }
    }

    /// The defender is standing still, so a correct guess is never taken back
    /// by the dice — not even against a dodge no attack could beat.
    func testATechniqueNeverMissesADefender() throws {
        let rules = try shippedRules(), duel = try shippedDuel()
        let a = fighter(hp: 1_000, attack: 40), elusive = fighter(hp: 1_000, attack: 40, dodge: 10_000)
        for seed in UInt64(1)...200 {
            var rng = SplitMix64(seed: seed)
            let round = DuelMath.resolveRound(a: a, aAction: .technique, b: elusive, bAction: .defend,
                                              rules: rules, duel: duel, using: &rng)
            XCTAssertGreaterThan(round.a.damage, 0, "seed \(seed)")
        }
    }

    /// The clock's Defend blocks like a chosen one and answers nothing, so
    /// silence is never worth more than a choice. `a` rolls first, so the
    /// attack's draws are the same against either Defend.
    func testAForcedDefendBlocksButNeverAnswers() throws {
        let rules = try shippedRules(), duel = try shippedDuel()
        let a = fighter(hp: 1_000, attack: 80), b = fighter(hp: 1_000, attack: 80, defense: 10)
        for seed in UInt64(1)...100 {
            var chosen = SplitMix64(seed: seed), silent = SplitMix64(seed: seed)
            let vsChosen = DuelMath.resolveRound(a: a, aAction: .attack, b: b, bAction: .defend,
                                                 rules: rules, duel: duel, using: &chosen)
            let vsSilent = DuelMath.resolveRound(a: a, aAction: .attack, b: b, bAction: .defend, bForced: true,
                                                 rules: rules, duel: duel, using: &silent)
            XCTAssertEqual(vsSilent.a.damage, vsChosen.a.damage, "the block is the same, seed \(seed)")
            XCTAssertEqual(vsSilent.b.kind, .braced)
            XCTAssertEqual(vsSilent.b.damage, 0)

            var rng = SplitMix64(seed: seed)
            let bothDefend = DuelMath.resolveRound(a: a, aAction: .defend, b: b, bAction: .defend, bForced: true,
                                                   rules: rules, duel: duel, using: &rng)
            XCTAssertEqual(bothDefend.a.kind, .chip, "a chosen Defend still chips the silent one")
            XCTAssertEqual(bothDefend.b.kind, .braced)
            XCTAssertEqual(bothDefend.b.damage, 0)

            let broken = DuelMath.resolveRound(a: a, aAction: .technique, b: b, bAction: .defend, bForced: true,
                                               rules: rules, duel: duel, using: &rng)
            XCTAssertEqual(broken.b.kind, .guardBroken)
            XCTAssertGreaterThan(broken.a.damage, 0)
        }
    }

    /// The whole point: with the shipped numbers no single choice is safe.
    /// Played out on the reference archer, each pure choice loses most duels
    /// to the one that beats it — Defend to a technique, the technique to
    /// Attack, Attack to Defend. A dominated edge would make the duel two
    /// choices again, which is what every two-choice brace measured as.
    func testTheShippedNumbersCloseTheCycle() throws {
        let content = try shippedContent()
        let tuning = try XCTUnwrap(content.tuning)
        let budget = try XCTUnwrap(content.budget)
        let rules = CombatRules(tuning.combat), duel = try shippedDuel()
        let archer = try XCTUnwrap(ReferenceCharacter.build(
            characterClass: "archer", level: 10, gearOffset: -ReferenceCharacter.staleGearOffset,
            progression: tuning.progression, budget: budget, rarities: content.rarities)).stats

        func share(_ x: DuelMath.Action, beats y: DuelMath.Action) -> Double {
            var rng = SplitMix64(seed: 20261003)
            var wins = 0.0
            let duels = 2_000
            for _ in 0..<duels {
                var a = archer, b = archer
                for _ in 0..<300 {
                    let round = DuelMath.resolveRound(a: a, aAction: x, b: b, bAction: y,
                                                      rules: rules, duel: duel, using: &rng)
                    a.hp = round.aHP
                    b.hp = round.bHP
                    if round.verdict == .aWins { wins += 1; break }
                    if round.verdict == .bWins { break }
                    if round.verdict == .draw { wins += 0.5; break }
                }
            }
            return wins / Double(duels)
        }
        XCTAssertGreaterThan(share(.technique, beats: .defend), 0.9)
        XCTAssertGreaterThan(share(.attack, beats: .technique), 0.9)
        XCTAssertGreaterThan(share(.defend, beats: .attack), 0.9)
    }

    // MARK: - Who wins

    /// One fighter falls, the other stands: a plain knockout.
    func testAKnockoutGoesToTheOneStillStanding() throws {
        let rules = try shippedRules(), duel = try shippedDuel()
        var rng = SplitMix64(seed: 7)
        let round = DuelMath.resolveRound(a: fighter(hp: 1_000, attack: 50), aAction: .defend,
                                          b: fighter(hp: 1, attack: 50), bAction: .defend,
                                          rules: rules, duel: duel, using: &rng)
        XCTAssertEqual(round.verdict, .aWins)
        XCTAssertFalse(round.bothFell)
        XCTAssertEqual(round.bHP, 0)
    }

    /// Both fall in the same round: the heavier blow wins it, whichever side
    /// threw it (the owner's call, 2026-10-03).
    func testTheHeavierBlowWinsWhenBothFall() throws {
        let rules = try shippedRules(), duel = try shippedDuel()
        let heavy = fighter(hp: 1, attack: 200), light = fighter(hp: 1, attack: 1)

        var rng = SplitMix64(seed: 11)
        let aHeavier = DuelMath.resolveRound(a: heavy, aAction: .defend, b: light, bAction: .defend,
                                             rules: rules, duel: duel, using: &rng)
        XCTAssertTrue(aHeavier.bothFell)
        XCTAssertGreaterThan(aHeavier.a.damage, aHeavier.b.damage)
        XCTAssertEqual(aHeavier.verdict, .aWins)

        let bHeavier = DuelMath.resolveRound(a: light, aAction: .defend, b: heavy, bAction: .defend,
                                             rules: rules, duel: duel, using: &rng)
        XCTAssertTrue(bHeavier.bothFell)
        XCTAssertEqual(bHeavier.verdict, .bWins)
    }

    /// Blows of the same size when both fall are a draw — a 1-ATK chip is
    /// floored to exactly 1 on either side.
    func testEqualBlowsWhenBothFallAreADraw() throws {
        let rules = try shippedRules(), duel = try shippedDuel()
        var rng = SplitMix64(seed: 3)
        let round = DuelMath.resolveRound(a: fighter(hp: 1, attack: 1), aAction: .defend,
                                          b: fighter(hp: 1, attack: 1), bAction: .defend,
                                          rules: rules, duel: duel, using: &rng)
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
        let rules = CombatRules(tuning.combat), duel = try shippedDuel()
        let archer = try XCTUnwrap(ReferenceCharacter.build(
            characterClass: "archer", level: 10, gearOffset: -ReferenceCharacter.staleGearOffset,
            progression: tuning.progression, budget: budget, rarities: content.rarities)).stats

        var rng = SplitMix64(seed: 20261003)
        var aWins = 0, bWins = 0
        let duels = 20_000
        for _ in 0..<duels {
            var a = archer, b = archer
            while true {
                let round = DuelMath.resolveRound(a: a, aAction: .attack, b: b, bAction: .attack,
                                                  rules: rules, duel: duel, using: &rng)
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
