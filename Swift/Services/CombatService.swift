//
//  CombatService.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 25.04.2026.
//
//  Phase 4.1: shared damage primitives for the interactive PvE controller AND
//  the passive-mode autobattle. The active controller calls `applyAttack` once
//  per round per direction (player→enemy, enemy→player); `resolveAutobattle`
//  loops the same primitives until one side falls.
//
//  Single source of truth for hit / miss / crit math — keeps active and
//  passive expeditions in numerical sync (no surprise where the same fight
//  resolves differently depending on mode).
//

import Foundation

public enum AttackOutcome: Sendable {
    case miss
    case hit(damage: Int)
    case crit(damage: Int)
}

public enum CombatService {
    /// Base hit chance before accuracy/dodge modifiers (percent).
    public static let baseHitChance: Int = 70
    /// Floor and ceiling on hit chance so even a heavily out-statted side can
    /// land or miss occasionally (no 100/0 lock-ins).
    public static let minHitChance: Int = 10
    public static let maxHitChance: Int = 95
    /// Crit damage multiplier on a successful crit roll.
    public static let critMultiplier: Double = 1.5
    /// ±10% variance on every landed hit.
    public static let varianceRange: ClosedRange<Double> = 0.9...1.1
    /// Defend's parry/counter chip damage as a fraction of a clean hit. Always
    /// lands, never crits — flavour is "you mostly hold the line but tag it".
    public static let defendChipFraction: Double = 0.3

    /// Roll a single attack. Damage variance, crit chance, and accuracy/dodge
    /// are baked in. Defender stats are passed in raw so the caller can boost
    /// them ad-hoc (e.g. doubling player's effective DEF on a Defend round).
    public static func applyAttack(
        attackerATK: Int,
        attackerCrit: Int,
        attackerAcc: Int,
        defenderDEF: Int,
        defenderDodge: Int
    ) -> AttackOutcome {
        let hitChance = max(minHitChance, min(maxHitChance, baseHitChance + attackerAcc - defenderDodge))
        if Int.random(in: 1...100) > hitChance {
            return .miss
        }

        let raw = Double(max(1, attackerATK - defenderDEF))
        let varied = raw * Double.random(in: varianceRange)

        let isCrit = Int.random(in: 1...100) <= max(0, attackerCrit)
        if isCrit {
            let damage = max(1, Int((varied * critMultiplier).rounded()))
            return .crit(damage: damage)
        }

        let damage = max(1, Int(varied.rounded()))
        return .hit(damage: damage)
    }

    /// Defend-mode chip damage. Always lands, never crits, scaled to
    /// `defendChipFraction` of a clean hit. Variance still applies so the
    /// number isn't pure deterministic.
    public static func chipDamage(attackerATK: Int, defenderDEF: Int) -> Int {
        let raw = Double(max(1, attackerATK - defenderDEF))
        let varied = raw * Double.random(in: varianceRange) * defendChipFraction
        return max(1, Int(varied.rounded()))
    }
}
