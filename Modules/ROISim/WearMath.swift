//
//  WearMath.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 24.10.2026.
//
//  How many durability points one fight's end takes from the worn kit.
//
//  The budget per outcome is `tuning/economy.json` → `gear.wearBudget`, and
//  since 2026-10-24 it may be a fraction: a win ½, a flee 1, a death 2 (it was
//  1 / 2 / 3, and players complained the repair ate a day's silver — on the Pi
//  a win was 84% of all wear). A point cannot be split, so the fraction is a
//  CHANCE: a budget of 0.5 takes one point in half the fights and none in the
//  other half, and 1.5 takes one point always and a second half the time.
//  Whole budgets never roll.
//
//  The roll is per FIGHT, which is why `points(budget:fights:using:)` exists:
//  a passive run that won one fight must take a point half the time, where
//  `Int(0.5 × 1)` would never take one and rounding the product would always
//  take it.
//

import Foundation

public enum WearMath {

    /// The points one fight with this `budget` takes. A budget at or below 0
    /// takes nothing.
    public static func points<G: RandomNumberGenerator>(budget: Double, using rng: inout G) -> Int {
        guard budget > 0, budget.isFinite else { return 0 }
        let whole = budget.rounded(.down)
        let fraction = budget - whole
        let extra = fraction > 0 && Double.random(in: 0..<1, using: &rng) < fraction ? 1 : 0
        return Int(whole) + extra
    }

    /// The points `fights` fights with the same `budget` take, each rolled on
    /// its own.
    public static func points<G: RandomNumberGenerator>(budget: Double, fights: Int, using rng: inout G) -> Int {
        guard fights > 0 else { return 0 }
        return (0..<fights).reduce(0) { total, _ in total + points(budget: budget, using: &rng) }
    }

    /// What a budget reads as on a screen (2026-10-24, the gear sheet's «🔧 Як
    /// зношується»): the points that always land, and the chance in whole
    /// percent of one more — 0.5 is (0, 50), 2 is (2, 0), 1.5 is (1, 50). The
    /// same split `points` rolls, so the sheet cannot describe another rule.
    public static func shape(of budget: Double) -> (always: Int, chancePercent: Int) {
        guard budget > 0, budget.isFinite else { return (0, 0) }
        let whole = budget.rounded(.down)
        return (Int(whole), Int(((budget - whole) * 100).rounded()))
    }
}
