//
//  BudgetCurve.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 31.08.2026.
//
//  The inverse of the budget spend: given a stat line, what did it cost?
//
//  `BudgetMath.spend` turns points into stats; this turns stats back into
//  points. It lives in ROIContent rather than beside `spend` in ROISim because
//  the validator needs it too and cannot import ROISim — and a second copy of
//  an exchange rate is exactly the kind of duplicate the item budget exists to
//  prevent.
//

import Foundation

extension GearStatsDTO {

    /// Budget points this stat line cost at the given exchange rates.
    ///
    /// `spend` computes `stat = points · share · rate` and the shares sum to
    /// one, so summing `stat / rate` over the six stats recovers the points.
    /// Stats at zero and rates at zero are skipped: an unpriced stat has no
    /// cost rather than an infinite one.
    public func pointsSpent(at rate: StatPerPointDTO) -> Double {
        var points = 0.0
        for (value, per) in [(attack, rate.attack), (defense, rate.defense),
                             (hp, rate.hp), (crit, rate.crit),
                             (dodge, rate.dodge), (accuracy, rate.accuracy)]
        where value != 0 && per > 0 {
            points += Double(value) / per
        }
        return points
    }
}
