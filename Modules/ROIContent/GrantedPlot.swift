//
//  GrantedPlot.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 01.11.2026.
//
//  The plot every estate starts with (2026-11-01, `spec-progression.md` §8).
//  The owner's idea: a plot that opens together with the estate and that the
//  player never chooses — the hazel, in slot 1, yielding forest nuts — so the
//  first explorations have a little food at home and the plot loop is on the
//  screen before the player builds a plot of their own.
//
//  `plots.json` marks such a type `"granted" : true`. What follows from it,
//  each read here or beside the rule it bends:
//  - it stands in slot index 0, and the claim refuses that slot whatever
//    stands there (`PlotService`);
//  - the picker never offers it and the claim refuses it;
//  - it is planted RIPE when the estate is named, its harvest clock one full
//    fill back (`intervalsToFill`), with the ready push already marked sent;
//  - it never counts as a plot the player built — not for the price's N
//    (`PlotBuildCost.nextPlotNumber`) and not for the King's `claim_plot`;
//  - `estate_upgrades.json` → `plotSlotsByTier` counts its slot, so every tier
//    lists one more slot than a player builds on, and `FoodBudget` adds its
//    yield to every estate instead of enumerating it as a choice.
//

import Foundation

public enum GrantedPlot {

    /// The slot a granted plot stands in — «Ділянка 1» on every screen.
    public static let slotIndex = 0

    /// Intervals a plot takes to fill from empty, rounded UP to a whole one —
    /// how far back a ripe plot's harvest clock is set. Rounding up can only
    /// overshoot, and the yield is capped at the capacity, so a plot planted
    /// this far back always reads full. Zero for a rate that grows nothing.
    public static func intervalsToFill(capacity: Int, ratePerInterval: Int) -> Int {
        guard ratePerInterval > 0, capacity > 0 else { return 0 }
        return (capacity + ratePerInterval - 1) / ratePerInterval
    }
}

extension PlotFileDTO {
    /// The types the estate grants, in file order. The validator holds a
    /// bundle to at most one, since there is one slot to stand in.
    public var grantedTypes: [String] { types.filter(\.granted).map(\.type) }

    /// The rows a player can build, in file order — the picker's list, the
    /// build-price tables and `FoodBudget`'s choices.
    public var buildableTypes: [PlotTypeDTO] { types.filter { !$0.granted } }
}
