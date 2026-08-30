//
//  CombatMath.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 30.08.2026.
//
//  The combat model, as pure functions over a seedable generator.
//
//  Phase 8 moved the bodies here out of `CombatService`; the service keeps its
//  whole public API and now delegates every roll. That direction matters: a
//  simulator that reimplements the maths measures the simulator, so the game
//  and the balance report have to execute the SAME lines. `CombatService`
//  supplies `Catalogs.current.tuningCombat` and a `SystemRandomNumberGenerator`,
//  `roi-content simulate` supplies the same tuning and a `SplitMix64`, and
//  nothing else differs between them.
//
//  Damage is ABSORBED, not subtracted (Phase 5C). `max(1, ATK − DEF)` was
//  scale-free: one point of DEF was 7% of a hit at level 1 and 3% at 21, so a
//  geared warrior took literally 1 damage from the strongest beast in the game
//  while a fresh mage took 28 from a boar. A ratio has no such cliff.
//

import Foundation
import ROIContent

// MARK: - Rules

/// The scalars one swing needs, lifted out of `CombatTuningDTO` once.
///
/// Not the tuning DTO itself: that carries five arrays (techniques, stances,
/// special attacks, flee, defend rows) which a roll never touches, and passing
/// it per swing would retain and release all five on a path the simulator runs
/// millions of times. Everything here is `Int`/`Double`, so a copy is free.
public struct CombatRules: Sendable {
    public let hitChance: HitChanceDTO
    public let curves: CombatCurvesDTO
    public let levelDiff: LevelDiffDTO
    public let critMultiplier: Double
    public let variance: VarianceDTO
    public let defendChipFraction: Double

    public init(_ tuning: CombatTuningDTO) {
        self.hitChance = tuning.hitChance
        self.curves = tuning.curves
        self.levelDiff = tuning.levelDiff
        self.critMultiplier = tuning.critMultiplier
        self.variance = tuning.variance
        self.defendChipFraction = tuning.defendChipFraction
    }

    /// ±10% on every landed hit. `ClosedRange` TRAPS when built with min > max,
    /// so the validator rejects an inverted pair before install rather than
    /// letting the first attack of the session crash the bot.
    public var varianceRange: ClosedRange<Double> { variance.min...variance.max }
}

// MARK: - Math

public enum CombatMath {

    // MARK: Outcome and per-swing modifiers

    public enum AttackOutcome: Sendable, Equatable {
        case miss
        case hit(damage: Int)
        case crit(damage: Int)

        /// Damage dealt — zero on a miss. Saves every caller a `switch` whose
        /// two live arms are identical.
        public var damage: Int {
            switch self {
            case .miss: return 0
            case .hit(let d), .crit(let d): return d
            }
        }
    }

    /// Per-attack modifiers used by special techniques to bend the standard
    /// roll without writing a new function. Defaults are no-ops so existing
    /// callers keep working unchanged.
    ///
    /// - `hitChanceModifier`: added to the clamped hit-chance roll (Cleave: −10)
    /// - `critBonus`: PERCENTAGE POINTS added after the curve (Vital Shot: +100)
    /// - `cannotMiss`: bypasses the hit-chance roll entirely
    /// - `flatDamageBonus`: added AFTER absorption, so armour cannot eat it
    public struct AttackModifiers: Sendable {
        public var hitChanceModifier: Int = 0
        public var critBonus: Int = 0
        public var cannotMiss: Bool = false
        public var flatDamageBonus: Int = 0
        /// Replaces `critMultiplier` for this swing only. Lets a technique buy
        /// a bigger crit rather than a more frequent one, which is the shape
        /// that survives an absorption model: a multiplier applies to the
        /// number that is left AFTER armour, so armour cannot erode it.
        public var critMultiplierOverride: Double?

        public init() {}
    }

    /// Per-round modifiers applied while a Super-technique stance is active.
    ///
    /// **All five lifts are multipliers of the character's own stat.** They were
    /// flat additions until Phase 8C, which is how two of the three Supers came
    /// to rot across a lifetime while the third held — the same defect Phase 6
    /// removed from items and never checked for here.
    ///
    /// Composed on top of the character's effective stats. The attacker roll
    /// reads attack / crit / accuracy and the defender roll reads defense /
    /// dodge, so the five are disjoint by which side consumes them — which is
    /// why `buffed(_:with:)` can apply all of them to one value and still match
    /// a controller that composes them at two separate call sites.
    public struct StanceModifiers: Sendable {
        public var attackMultiplier: Double = 1.0
        public var defenseMultiplier: Double = 1.0
        public var critMultiplier: Double = 1.0
        public var accuracyMultiplier: Double = 1.0
        public var dodgeMultiplier: Double = 1.0
        /// Scales the vigor drain on each combat action while the stance holds.
        public var vigorMultiplier: Double = 1.0

        public static let none = StanceModifiers()

        public init() {}

        public init(_ row: StanceTuningDTO) {
            attackMultiplier = row.attackMultiplier
            defenseMultiplier = row.defenseMultiplier
            critMultiplier = row.critMultiplier
            accuracyMultiplier = row.accuracyMultiplier
            dodgeMultiplier = row.dodgeMultiplier
            vigorMultiplier = row.vigorMultiplier
        }
    }

    /// The character as the round sees them with a stance up.
    ///
    /// Each stat rounds independently, exactly as `GearStats.scaled(by:)` does
    /// for an enchant — the two are the same operation on the same principle.
    public static func buffed(_ stats: CombatantStats, with m: StanceModifiers) -> CombatantStats {
        var out = stats
        out.attack = Int((Double(stats.attack) * m.attackMultiplier).rounded())
        out.defense = Int((Double(stats.defense) * m.defenseMultiplier).rounded())
        out.crit = Int((Double(stats.crit) * m.critMultiplier).rounded())
        out.accuracy = Int((Double(stats.accuracy) * m.accuracyMultiplier).rounded())
        out.dodge = Int((Double(stats.dodge) * m.dodgeMultiplier).rounded())
        return out
    }

    /// Roll modifiers for a class's Special Attack.
    ///
    /// There is no "ignore armour" knob any more. All three techniques used to
    /// zero the defender's DEF, which an absorption model turns into a
    /// 0.44–0.59× trade: +11% damage against trash for +150% Vigor. The
    /// armour-piercing fantasy lives in `armourBreak`, whose worth RISES with
    /// the target's absorption instead of falling with it.
    public static func modifiers(forSpecialAttack row: SpecialAttackTuningDTO) -> AttackModifiers {
        var m = AttackModifiers()
        m.hitChanceModifier = row.hitChanceModifier
        m.cannotMiss = row.cannotMiss
        if case .guaranteedCrit(let multiplier) = row.effect {
            m.critBonus = 100          // percentage points — always crits
            m.critMultiplierOverride = multiplier
        }
        return m
    }

    // MARK: Curves

    /// Fraction of an incoming hit the defender absorbs.
    ///
    /// The denominator uses the DEFENDER's level: `K` is derived from the item
    /// budget curve of the character wearing that DEF, so it has to be read at
    /// their level, not the attacker's.
    public static func mitigation(defenderDEF: Int, defenderLevel: Int,
                                  curve: MitigationCurveDTO) -> Double {
        let def = Swift.max(0.0, Double(defenderDEF))
        let k = curve.kBase + curve.kPerLevel * Double(Swift.max(1, defenderLevel))
        guard def + k > 0 else { return 0 }
        return Swift.min(curve.cap, def / (def + k))
    }

    /// Rating → percentage, on the shared diminishing-returns shape. The
    /// denominators are DERIVED from the item budget curve, not hand-picked:
    /// a hand-picked one lets a stat rot, and archer dodge would have fallen
    /// below its level-1 value by level 40.
    public static func percent(_ curve: RatingCurveDTO, rating: Int, level: Int) -> Double {
        let r = Swift.max(0.0, Double(rating))
        let k = curve.kBase + curve.kPerLevel * Double(Swift.max(1, level))
        guard r + k > 0 else { return 0 }
        return curve.scale * r / (r + k)
    }

    /// Chance to evade, as a percentage. Read at the DODGER's level.
    public static func dodgePercent(rating: Int, level: Int, curves: CombatCurvesDTO) -> Double {
        percent(curves.dodge, rating: rating, level: level)
    }

    /// Chance to crit, as a percentage. Read at the ATTACKER's level.
    public static func critPercent(rating: Int, level: Int, curves: CombatCurvesDTO) -> Double {
        percent(curves.crit, rating: rating, level: level)
    }

    /// Percentage points added to the base hit chance. Read at the ATTACKER's level.
    public static func accuracyPercent(rating: Int, level: Int, curves: CombatCurvesDTO) -> Double {
        percent(curves.accuracy, rating: rating, level: level)
    }

    /// Damage multiplier from the level gap.
    ///
    /// This is what sells "I have outgrown this zone", and it is the reason
    /// enemy stats can be frozen at design time. Scaling enemies to the player
    /// at runtime would make every gear upgrade evaporate the moment it is
    /// worn; a level term does the same job without touching the enemy table.
    public static func levelDiffMultiplier(attackerLevel: Int, defenderLevel: Int,
                                           spec: LevelDiffDTO) -> Double {
        let raw = 1 + spec.perLevel * Double(attackerLevel - defenderLevel)
        return Swift.max(spec.min, Swift.min(spec.max, raw))
    }

    // MARK: Rolls

    /// Roll a single attack.
    ///
    /// Crit, dodge and accuracy arrive as RATINGS and are converted through the
    /// curves here; both levels are required because every curve's denominator
    /// grows with the level of whoever owns the stat. Before Phase 5 the enemy
    /// side of every roll passed literal `0/0/0`, so enemies never dodged,
    /// never crit and never missed.
    ///
    /// Three draws, always in this order: hit, variance, crit. The order is
    /// part of the contract — a seeded replay compares streams, so reordering
    /// the draws would move every digest without moving a single probability.
    public static func applyAttack<G: RandomNumberGenerator>(
        attacker: CombatantStats,
        defender: CombatantStats,
        modifiers: AttackModifiers = AttackModifiers(),
        rules: CombatRules,
        using rng: inout G
    ) -> AttackOutcome {
        let hitChance: Double
        if modifiers.cannotMiss {
            hitChance = 100
        } else {
            let accuracy = accuracyPercent(rating: attacker.accuracy, level: attacker.level,
                                           curves: rules.curves)
            let evasion = dodgePercent(rating: defender.dodge, level: defender.level,
                                       curves: rules.curves)
            let raw = Double(rules.hitChance.base) + accuracy - evasion
                + Double(modifiers.hitChanceModifier)
            hitChance = Swift.max(Double(rules.hitChance.min),
                                  Swift.min(Double(rules.hitChance.max), raw))
        }
        if Double.random(in: 0..<100, using: &rng) >= hitChance { return .miss }

        let absorbed = mitigation(defenderDEF: defender.defense, defenderLevel: defender.level,
                                  curve: rules.curves.mitigation)
        let afterArmour = Double(attacker.attack) * (1 - absorbed) + Double(modifiers.flatDamageBonus)
        let scaled = afterArmour * levelDiffMultiplier(attackerLevel: attacker.level,
                                                       defenderLevel: defender.level,
                                                       spec: rules.levelDiff)
        let varied = scaled * Double.random(in: rules.varianceRange, using: &rng)

        let critChance = critPercent(rating: attacker.crit, level: attacker.level,
                                     curves: rules.curves) + Double(modifiers.critBonus)
        if Double.random(in: 0..<100, using: &rng) < critChance {
            let multiplier = modifiers.critMultiplierOverride ?? rules.critMultiplier
            return .crit(damage: Swift.max(1, Int((varied * multiplier).rounded())))
        }
        return .hit(damage: Swift.max(1, Int(varied.rounded())))
    }

    /// Defend-mode chip damage. Always lands, never crits, scaled to
    /// `defendChipFraction × extraMultiplier` of a clean hit. Variance still
    /// applies so the number isn't pure deterministic. `extraMultiplier`
    /// defaults to 1.0 (warrior); the archer's "plinks while hiding" Defend
    /// passes 0.5 to halve the chip.
    public static func chipDamage<G: RandomNumberGenerator>(
        attackerATK: Int,
        defenderDEF: Int,
        defenderLevel: Int,
        extraMultiplier: Double = 1.0,
        rules: CombatRules,
        using rng: inout G
    ) -> Int {
        let absorbed = mitigation(defenderDEF: defenderDEF, defenderLevel: defenderLevel,
                                  curve: rules.curves.mitigation)
        let raw = Double(attackerATK) * (1 - absorbed)
        let varied = raw * Double.random(in: rules.varianceRange, using: &rng)
            * rules.defendChipFraction * extraMultiplier
        return Swift.max(1, Int(varied.rounded()))
    }
}
