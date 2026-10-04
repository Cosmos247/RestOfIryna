//
//  WeaponLadderRules.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 04.10.2026.
//
//  The weapon ladder follows the PLAYER level since 2026-10-04
//  (`spec-items.md` §9): a rung every five levels, each opened by its own
//  `requiredPlayerLevel`. Before, the estate opened tier N at T N, so the
//  item-level-40 sword was in hand at level 13 — and the model behind tier 2
//  of the bestiary had assumed a weapon at `itemLevel <= level` all along.
//
//  Three readers ask the same questions of a ladder:
//  - the workshop and the Master, through `WeaponUpgradeCatalog`;
//  - the clamp migration that walked the testers' weapons back to their level;
//  - the validator's `king.weapon_tier_before_its_gate`.
//
//  So the answers live here, once, in pure Foundation where the tests can reach
//  them — the reason `QuestCarryOver` lives in this module too.
//

import Foundation

public enum WeaponLadderRules {

    /// The highest tier a player of `level` may hold, given each tier's gate
    /// (`gates[0]` is tier 1's). Tier 1 is the starter and always held, so the
    /// answer is never below 1, whatever the table says.
    ///
    /// Walks the table in order and stops at the first closed gate: a ladder
    /// whose gates fall (which the validator refuses) still never hands out a
    /// rung above a closed one.
    public static func highestTier(gates: [Int], atLevel level: Int) -> Int {
        var tier = 1
        for (index, gate) in gates.enumerated() where index > 0 {
            guard gate <= level else { break }
            tier = index + 1
        }
        return tier
    }

    /// The silver the clamp hands back for taking a weapon from `fromTier`
    /// down to `toTier`: what the materials of every removed rung cost at
    /// `price` each. `inputsByTier[0]` is tier 1's (always empty). Nothing is
    /// refunded for a weapon that is not being lowered.
    public static func refundSilver(inputsByTier: [[(itemId: String, quantity: Int)]], fromTier: Int, toTier: Int,
                                    price: (String) -> Int) -> Int {
        guard fromTier > toTier, toTier >= 1 else { return 0 }
        var total = 0
        for tier in (toTier + 1)...fromTier where tier - 1 < inputsByTier.count {
            for input in inputsByTier[tier - 1] {
                total += price(input.itemId) * input.quantity
            }
        }
        return total
    }

    /// The gate of every tier as the King's chain must read it. A decree asks
    /// for "weapon tier N" whatever the player's class, so the gate is the
    /// highest any ladder sets for N. Rungs with no gate are skipped, because
    /// their missing field is an error of its own (`ladder.required_level_missing`).
    public static func gatesByTier(_ ladders: [WeaponLadderDTO]) -> [Int: Int] {
        var gates: [Int: Int] = [:]
        for ladder in ladders {
            for step in ladder.tiers {
                guard let level = step.requiredPlayerLevel else { continue }
                gates[step.tier] = max(gates[step.tier] ?? level, level)
            }
        }
        return gates
    }
}
