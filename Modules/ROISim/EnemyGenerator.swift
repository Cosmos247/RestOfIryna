//
//  EnemyGenerator.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 30.08.2026.
//
//  The design-time enemy table, derived by inverting the archetype targets.
//
//  `enemies.json` states what an encounter should FEEL like — how many rounds a
//  trash mob lasts, what share of the player's HP a brute costs, how much it
//  absorbs, dodges and crits. Those are targets, not stats. This turns them
//  into stats, once, at design time.
//
//  Design time is the whole point. `EnemyHP = playerDPR × targetRounds`
//  computed at RUNTIME would make every gear upgrade evaporate the moment it
//  was worn — the monster gets exactly as much tougher as the player got
//  stronger, which is Oblivion's level-scaling failure. Run once against a
//  reference character and frozen into a table, the same formula does the
//  opposite: out-gearing a zone is visible immediately.
//
//  The inversions are not a guess. Fed the shipped roster's levels and
//  archetypes they reproduce every enemy's DEF, crit and dodge to within
//  rounding — `enemy.rabid_bear` wants DEF 82.36 and carries 82, crit 56.66 and
//  carries 57, dodge 23.04 and carries 23 — which is what says the shipped
//  ratings came off this curve and not off a spreadsheet nobody kept.
//

import Foundation
import ROIContent

public struct GeneratedEnemy: Sendable {
    public let archetype: String
    public let level: Int
    public let stats: CombatantStats
    public let xpReward: Int
    /// What the archetype asked for, carried alongside so a report can print
    /// measured-against-target without re-deriving the target.
    public let targetRounds: Double
    public let targetHPLossPercent: Double
}

public enum EnemyGenerator {

    // MARK: Inversions

    /// DEF that produces `percent` absorption at `level`.
    ///
    /// `m = DEF/(DEF+K)` ⇒ `DEF = m·K/(1−m)`. Returns 0 for a non-positive
    /// target and clamps at the curve's cap, past which no DEF is enough.
    public static func defense(forMitigationPercent percent: Double, level: Int,
                               curve: MitigationCurveDTO) -> Int {
        let m = Swift.min(curve.cap - 1e-9, Swift.max(0, percent / 100))
        guard m > 0 else { return 0 }
        let k = curve.kBase + curve.kPerLevel * Double(Swift.max(1, level))
        return Int((m * k / (1 - m)).rounded())
    }

    /// Rating that produces `percent` on a rating curve at `level`.
    ///
    /// `p = scale·r/(r+k)` ⇒ `r = k·p/(scale−p)`. A target at or above the
    /// curve's scale is unreachable at any rating, so it saturates.
    public static func rating(forPercent percent: Double, level: Int,
                              curve: RatingCurveDTO) -> Int {
        let p = Swift.max(0, percent)
        guard p > 0 else { return 0 }
        guard p < curve.scale else { return Int.max / 4 }
        let k = curve.kBase + curve.kPerLevel * Double(Swift.max(1, level))
        return Int((k * p / (curve.scale - p)).rounded())
    }

    // MARK: Expected damage

    /// Mean damage of one swing, over hit chance, absorption, level gap,
    /// variance and crit.
    ///
    /// The `max(1, …)` floor and the per-swing rounding in `applyAttack` are
    /// deliberately NOT modelled: they matter only where a swing is worth less
    /// than one point, which is a fight nobody is balancing. Everything the
    /// generator emits is checked afterwards by actually rolling the fight, so
    /// a bad approximation shows up as a measured miss, not as a silent one.
    public static func expectedDamage(attacker: CombatantStats, defender: CombatantStats,
                                      rules: CombatRules) -> Double {
        let accuracy = CombatMath.accuracyPercent(rating: attacker.accuracy, level: attacker.level,
                                                  curves: rules.curves)
        let evasion = CombatMath.dodgePercent(rating: defender.dodge, level: defender.level,
                                              curves: rules.curves)
        let raw = Double(rules.hitChance.base) + accuracy - evasion
        let hit = Swift.max(Double(rules.hitChance.min),
                            Swift.min(Double(rules.hitChance.max), raw)) / 100
        let absorbed = CombatMath.mitigation(defenderDEF: defender.defense,
                                             defenderLevel: defender.level,
                                             curve: rules.curves.mitigation)
        let gap = CombatMath.levelDiffMultiplier(attackerLevel: attacker.level,
                                                 defenderLevel: defender.level,
                                                 spec: rules.levelDiff)
        let meanVariance = (rules.variance.min + rules.variance.max) / 2
        let crit = CombatMath.critPercent(rating: attacker.crit, level: attacker.level,
                                          curves: rules.curves) / 100
        let landed = Double(attacker.attack) * (1 - absorbed) * gap * meanVariance
        return hit * landed * (1 + crit * (rules.critMultiplier - 1))
    }

    // MARK: Generation

    /// The enemy an archetype asks for at `level`, solved against the mean of
    /// the supplied reference characters.
    ///
    /// The MEAN, not one nominated class: an enemy tuned to the warrior makes
    /// the warrior's row trivially correct and turns the other two into
    /// deviations from a yardstick they never agreed to. Against the mean, all
    /// three rows are measurements, and their spread is the class power index.
    public static func generate(archetype: EnemyArchetypeDTO, level: Int,
                                against references: [CombatantStats],
                                rules: CombatRules, mobXP: MobXPDTO) -> GeneratedEnemy {
        let defense = defense(forMitigationPercent: archetype.mitigationPercent, level: level,
                              curve: rules.curves.mitigation)
        let dodge = rating(forPercent: archetype.dodgePercent, level: level, curve: rules.curves.dodge)
        let crit = rating(forPercent: archetype.critPercent, level: level, curve: rules.curves.crit)

        // Solved with a placeholder HP/ATK: neither feeds the other side's
        // expected damage, so one pass is exact rather than iterative.
        var probe = CombatantStats(level: level, defense: defense, crit: crit, dodge: dodge)

        var hpSolutions: [Double] = []
        var attackSolutions: [Double] = []
        for reference in references {
            // HP: how much the reference chews through in `rounds` rounds.
            hpSolutions.append(archetype.rounds * expectedDamage(attacker: reference,
                                                                 defender: probe, rules: rules))
            // ATK: linear in attack, so solve at 1 and scale.
            probe.attack = 1
            let perPoint = expectedDamage(attacker: probe, defender: reference, rules: rules)
            let wanted = archetype.hpLossPercent / 100 * Double(reference.maxHP)
            attackSolutions.append(perPoint > 0 ? wanted / (archetype.rounds * perPoint) : 0)
        }
        let hp = Swift.max(1, Int((mean(hpSolutions)).rounded()))
        let attack = Swift.max(1, Int((mean(attackSolutions)).rounded()))

        // `xpReward` is baked from the same curve the level ladder was solved
        // against — `round(coefficient · level^exponent · archetype.xpMultiplier)`.
        let xp = Int((mobXP.coefficient * pow(Double(level), mobXP.exponent)
                      * archetype.xpMultiplier).rounded())

        return GeneratedEnemy(
            archetype: archetype.id, level: level,
            stats: CombatantStats(level: level, maxHP: hp, attack: attack, defense: defense,
                                  crit: crit, dodge: dodge, accuracy: 0),
            xpReward: Swift.max(0, xp),
            targetRounds: archetype.rounds,
            targetHPLossPercent: archetype.hpLossPercent)
    }

    private static func mean(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }
}
