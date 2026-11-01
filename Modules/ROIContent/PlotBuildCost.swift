//
//  PlotBuildCost.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 24.10.2026.
//
//  What building a plot costs (2026-10-24). Until then a plot was free: pick a
//  type, read the card, «✅ Будувати». Players asked for it to take resources,
//  and the owner picked the shape over two rounds — the first proposal (one
//  frame of 🪵 + 🪨 for every type plus one item of its own) was sent back as
//  too uniform, "add clay and iron":
//  - every type has a recipe of its own, four materials each — the farm the
//    only one without clay, the coop the only one without iron
//    (`plots.json` → `buildCost`);
//  - the player's Nth plot costs N recipes (`build.multiplierByPlotNumber`),
//    so the sixth still costs something at estate T7;
//  - the player's FIRST plot leaves out clay and iron
//    (`build.firstPlotLeavesOut`): a newcomer at estate T2 has no mine yet and
//    forages less than a clay a day.
//
//  N counts the plot being built — the plots the player built, plus one — never
//  the slot index: a slot can be claimed out of order, and the price is about
//  how much land the player has already put to work. The plot the estate
//  grants (2026-11-01, the hazel in slot 1) is not one of them. The plots built
//  before the rule stay as they are; nobody is charged for them.
//
//  The one reading of the rule, for the build card, `PlotService.claim`, the
//  validator and `roi-content spec`, so the card cannot quote a price the
//  claim then disagrees with.
//

import Foundation

public enum PlotBuildCost {

    /// N for the plot about to be built: the plots the player BUILT, plus one.
    /// `ownedTypes` is every plot row the player owns, by type. A granted plot
    /// (2026-11-01, `spec-progression.md` §8) is not one the player built, so
    /// it never makes the next plot dearer — the first plot a player builds
    /// stays the light one that leaves out clay and iron.
    public static func nextPlotNumber(ownedTypes: [String], granted: Set<String>) -> Int {
        ownedTypes.filter { !granted.contains($0) }.count + 1
    }

    /// What the player's `plotNumber`-th plot of a type with this `recipe`
    /// costs. A number below 1 is the first plot; past the multiplier table the
    /// last multiplier holds.
    public static func inputs(recipe: [MaterialCostDTO], plotNumber: Int,
                              rule: PlotBuildRuleDTO) -> [MaterialCostDTO] {
        let index = max(1, plotNumber) - 1
        let table = rule.multiplierByPlotNumber
        let multiplier = index < table.count ? table[index] : (table.last ?? 1)
        let leftOut: Set<String> = index == 0 ? Set(rule.firstPlotLeavesOut) : []
        return recipe
            .filter { !leftOut.contains($0.itemId) }
            .map { MaterialCostDTO(itemId: $0.itemId, quantity: $0.quantity * multiplier) }
    }
}

extension PlotFileDTO {
    /// `PlotBuildCost.inputs` for the row of `type`, or nil when the file has
    /// no such row or no `build` rule — both validator errors.
    public func buildCost(for type: String, plotNumber: Int) -> [MaterialCostDTO]? {
        guard let rule = build, let row = types.first(where: { $0.type == type }) else { return nil }
        return PlotBuildCost.inputs(recipe: row.buildCost, plotNumber: plotNumber, rule: rule)
    }
}
