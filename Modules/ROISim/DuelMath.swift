//
//  DuelMath.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 03.10.2026.
//
//  One round of the Arena duel (герць), both fighters at once.
//
//  Until 2026-10-03 the duel alternated: the challenger struck first and the
//  turn passed after every action. Rolled on `CombatMath`, the first striker
//  won 60–66% of mirror duels at every level — the race is short and tight,
//  so whoever swings first stays a blow ahead. Now both fighters choose blind
//  and a round is ONE event: both blows are rolled against the state at the
//  start of the round and land together, so neither side can be a blow ahead.
//
//  Simultaneity costs something the alternating duel never paid: both fighters
//  can fall in the same round, which the same rolls put at 20–32% of mirror
//  duels. The heavier blow of that round wins it (the owner's call,
//  2026-10-03), so nearly every duel still has a winner; only blows of the
//  same size draw.
//
//  It lives here rather than in `ArenaStore` for the reason `CombatMath` does:
//  the bot and the tests have to execute the same lines.
//

import Foundation

public enum DuelMath {

    /// What a fighter does with a round. A missed timer is not a third
    /// action: the caller resolves it as `.defend` and remembers that it was
    /// forced, because the dice cannot tell the difference and the screen can.
    public enum Action: Sendable, Equatable {
        case attack
        case defend
    }

    /// A fighter who defends has their DEF multiplied by this against an
    /// attack in the SAME round. It was ×2 against the next incoming hit
    /// while the duel alternated; a round played at once has no "next".
    public static let braceDefenseMultiplier = 2

    /// One fighter's half of a round, as the screen needs it.
    public struct Blow: Sendable, Equatable {
        public let action: Action
        /// The roll of an attack; nil for a Defend, whose chip never rolls
        /// to hit.
        public let outcome: CombatMath.AttackOutcome?
        /// What this blow took off the other fighter, chip included.
        public let damage: Int
        /// An attack that landed on a fighter who defended this round —
        /// said on the screen, because it is the only reason a hit comes out
        /// smaller than the one before it.
        public let throughBrace: Bool
    }

    public enum Verdict: Sendable, Equatable {
        case continues
        case aWins
        case bWins
        /// Both fell to blows of the same size.
        case draw
    }

    public struct Round: Sendable, Equatable {
        /// `a`'s blow, landed on `b`.
        public let a: Blow
        /// `b`'s blow, landed on `a`.
        public let b: Blow
        /// HP after the round, floored at 0.
        public let aHP: Int
        public let bHP: Int
        public let verdict: Verdict
        /// Both fell this round, so the verdict compared the two blows
        /// instead of reading a knockout.
        public let bothFell: Bool
    }

    /// Resolve one round. `a`'s blow is rolled first, then `b`'s — the order
    /// only fixes which draws a seeded replay consumes, since neither blow
    /// can see the other: both read the HP and the brace the round started
    /// with.
    public static func resolveRound<G: RandomNumberGenerator>(
        a: CombatantStats, aAction: Action,
        b: CombatantStats, bAction: Action,
        rules: CombatRules,
        using rng: inout G
    ) -> Round {
        let blowA = blow(by: a, action: aAction, on: b, braced: bAction == .defend,
                         rules: rules, using: &rng)
        let blowB = blow(by: b, action: bAction, on: a, braced: aAction == .defend,
                         rules: rules, using: &rng)
        let aHP = Swift.max(0, a.hp - blowB.damage)
        let bHP = Swift.max(0, b.hp - blowA.damage)

        let bothFell = aHP == 0 && bHP == 0
        let verdict: Verdict
        if bothFell {
            if blowA.damage == blowB.damage {
                verdict = .draw
            } else {
                verdict = blowA.damage > blowB.damage ? .aWins : .bWins
            }
        } else if bHP == 0 {
            verdict = .aWins
        } else if aHP == 0 {
            verdict = .bWins
        } else {
            verdict = .continues
        }
        return Round(a: blowA, b: blowB, aHP: aHP, bHP: bHP, verdict: verdict, bothFell: bothFell)
    }

    /// Defend keeps the arena's Phase 8.3 shape: a chip that always lands and
    /// never crits, read against the other fighter's DEF as it stands — a
    /// brace guards against attacks, not against another chip.
    private static func blow<G: RandomNumberGenerator>(
        by attacker: CombatantStats, action: Action,
        on defender: CombatantStats, braced: Bool,
        rules: CombatRules,
        using rng: inout G
    ) -> Blow {
        switch action {
        case .defend:
            let chip = CombatMath.chipDamage(attackerATK: attacker.attack,
                                             defenderDEF: defender.defense,
                                             defenderLevel: defender.level,
                                             rules: rules, using: &rng)
            return Blow(action: .defend, outcome: nil, damage: chip, throughBrace: false)
        case .attack:
            var target = defender
            if braced { target.defense = defender.defense * braceDefenseMultiplier }
            let outcome = CombatMath.applyAttack(attacker: attacker, defender: target,
                                                 rules: rules, using: &rng)
            return Blow(action: .attack, outcome: outcome, damage: outcome.damage,
                        throughBrace: braced && outcome.damage > 0)
        }
    }

    // MARK: - Missed rounds

    public enum Walkover: Sendable, Equatable {
        case none
        case aForfeits
        case bForfeits
        /// Both reached the limit in the same round: nobody is left to win.
        case abandoned
    }

    /// Who, if anyone, has let `limit` rounds in a row run out. Asked when a
    /// round's clock runs out, after the missed counts are bumped and before
    /// the round is played: a technical defeat is not fought for.
    public static func walkover(missedA: Int, missedB: Int, limit: Int) -> Walkover {
        switch (missedA >= limit, missedB >= limit) {
        case (true, true):  return .abandoned
        case (true, false): return .aForfeits
        case (false, true): return .bForfeits
        case (false, false): return .none
        }
    }
}
