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
//  Later the same day the round became a CYCLE: Attack beats a technique,
//  a technique breaks a Defend, a Defend turns an Attack. With two blind
//  choices one of them always dominates, whatever the numbers — measured on
//  every brace tried (DEF ×2, blocks of 50/65/80%, a block with a riposte, a
//  block that charges the next blow): Defend was either never worth choosing
//  or always worth it, and then the duel tripled in length. Only a third
//  choice that beats Defend and loses to Attack makes the guess real; the
//  class special attack is that choice, and the measured equilibrium plays
//  roughly 47% Attack / 37% Defend / 15% technique on every class and level.
//  The numbers are the arena's own (`arena.json` → `duel`).
//
//  It lives here rather than in `ArenaStore` for the reason `CombatMath` does:
//  the bot and the tests have to execute the same lines.
//

import Foundation
import ROIContent

public enum DuelMath {

    /// What a fighter does with a round. A missed timer is not a fourth
    /// action: the caller resolves it as `.defend` and passes `forced`, because
    /// a forced Defend blocks like a chosen one but answers nothing — silence
    /// must never be worth more than a choice.
    public enum Action: Sendable, Equatable {
        case attack
        case defend
        /// The class special attack. Free and unlimited in the arena: its
        /// only price is the risk of meeting an Attack, and a use limit would
        /// break the cycle the moment it ran out.
        case technique
    }

    /// The arena's numbers for a round — `arena.json` → `duel`.
    public struct Rules: Sendable, Equatable {
        public let blockFraction: Double
        public let riposteFraction: Double
        public let chipFraction: Double
        public let techniqueMultiplier: Double

        public init(blockFraction: Double, riposteFraction: Double, chipFraction: Double,
                    techniqueMultiplier: Double) {
            self.blockFraction = blockFraction
            self.riposteFraction = riposteFraction
            self.chipFraction = chipFraction
            self.techniqueMultiplier = techniqueMultiplier
        }

        public init(_ dto: ArenaDuelDTO) {
            self.init(blockFraction: dto.blockFraction, riposteFraction: dto.riposteFraction,
                      chipFraction: dto.chipFraction, techniqueMultiplier: dto.techniqueMultiplier)
        }
    }

    /// One fighter's half of a round, as the screen needs it.
    public struct Blow: Sendable, Equatable {
        /// What happened to this fighter's choice — the screen has one line
        /// per kind.
        public enum Kind: Sendable, Equatable {
            /// An Attack; `outcome` has the roll.
            case strike
            /// A chosen Defend answering an Attack.
            case riposte
            /// A chosen Defend meeting a Defend.
            case chip
            /// A forced Defend: it blocked what came, and answered nothing.
            case braced
            /// A Defend — chosen or forced — that a technique went through.
            case guardBroken
            /// A technique through a Defend; `outcome` has the roll.
            case technique
            /// A technique cut off by an Attack.
            case interrupted
            /// Two techniques: both wind-ups meet and neither lands.
            case clashed
        }

        public let action: Action
        public let kind: Kind
        /// The roll of a strike or a technique, its damage after the block;
        /// nil for every kind that does not roll to hit.
        public let outcome: CombatMath.AttackOutcome?
        /// What this blow took off the other fighter.
        public let damage: Int
        /// An Attack that landed on a fighter who defended this round — said
        /// on the screen, because it is the only reason a hit comes out
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
    /// can see the other: both read the HP and the choices the round started
    /// with. `aForced` / `bForced` mean the clock chose `.defend` for that
    /// side; they are ignored for any other action.
    public static func resolveRound<G: RandomNumberGenerator>(
        a: CombatantStats, aAction: Action, aForced: Bool = false,
        b: CombatantStats, bAction: Action, bForced: Bool = false,
        rules: CombatRules, duel: Rules,
        using rng: inout G
    ) -> Round {
        let blowA = blow(by: a, action: aAction, forced: aForced, on: b, facing: bAction,
                         rules: rules, duel: duel, using: &rng)
        let blowB = blow(by: b, action: bAction, forced: bForced, on: a, facing: aAction,
                         rules: rules, duel: duel, using: &rng)
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

    /// The cycle, from one side. A block applies to an Attack whether the
    /// Defend was chosen or forced; only a chosen Defend answers. A chip always
    /// lands and never crits, read against the other fighter's DEF as it
    /// stands — a block guards against attacks, not against another chip.
    private static func blow<G: RandomNumberGenerator>(
        by attacker: CombatantStats, action: Action, forced: Bool,
        on defender: CombatantStats, facing other: Action,
        rules: CombatRules, duel: Rules,
        using rng: inout G
    ) -> Blow {
        func chip(_ fraction: Double) -> Int {
            CombatMath.chipDamage(attackerATK: attacker.attack, defenderDEF: defender.defense,
                                  defenderLevel: defender.level, fraction: fraction,
                                  rules: rules, using: &rng)
        }
        func quiet(_ kind: Blow.Kind) -> Blow {
            Blow(action: action, kind: kind, outcome: nil, damage: 0, throughBrace: false)
        }

        switch (action, other) {
        case (.attack, .defend):
            let rolled = CombatMath.applyAttack(attacker: attacker, defender: defender,
                                                rules: rules, using: &rng)
            let outcome = scaled(rolled, by: 1 - duel.blockFraction)
            return Blow(action: .attack, kind: .strike, outcome: outcome, damage: outcome.damage,
                        throughBrace: outcome.damage > 0)
        case (.attack, _):
            let outcome = CombatMath.applyAttack(attacker: attacker, defender: defender,
                                                 rules: rules, using: &rng)
            return Blow(action: .attack, kind: .strike, outcome: outcome, damage: outcome.damage,
                        throughBrace: false)

        case (.defend, .attack):
            if forced { return quiet(.braced) }
            let damage = chip(duel.riposteFraction)
            return Blow(action: .defend, kind: .riposte, outcome: nil, damage: damage, throughBrace: false)
        case (.defend, .defend):
            if forced { return quiet(.braced) }
            let damage = chip(duel.chipFraction)
            return Blow(action: .defend, kind: .chip, outcome: nil, damage: damage, throughBrace: false)
        case (.defend, .technique):
            return quiet(.guardBroken)

        case (.technique, .defend):
            // A correct guess is not taken back by the dice: the defender is
            // standing still, so the technique cannot miss. It can still crit.
            var sure = CombatMath.AttackModifiers()
            sure.cannotMiss = true
            let rolled = CombatMath.applyAttack(attacker: attacker, defender: defender,
                                                modifiers: sure, rules: rules, using: &rng)
            let outcome = scaled(rolled, by: duel.techniqueMultiplier)
            return Blow(action: .technique, kind: .technique, outcome: outcome, damage: outcome.damage,
                        throughBrace: false)
        case (.technique, .attack):
            return quiet(.interrupted)
        case (.technique, .technique):
            return quiet(.clashed)
        }
    }

    /// A roll with its damage multiplied, kind kept. A landed blow never
    /// rounds down to nothing — a hit that connects takes at least 1.
    private static func scaled(_ outcome: CombatMath.AttackOutcome, by factor: Double) -> CombatMath.AttackOutcome {
        func apply(_ d: Int) -> Int { Swift.max(1, Int((Double(d) * factor).rounded())) }
        switch outcome {
        case .miss:         return .miss
        case .hit(let d):   return factor == 1 ? outcome : .hit(damage: apply(d))
        case .crit(let d):  return factor == 1 ? outcome : .crit(damage: apply(d))
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
