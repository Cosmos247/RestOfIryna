//
//  PlotBuildCostTests.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 24.10.2026.
//
//  What building a plot costs (2026-10-24): the player's Nth plot pays N of
//  its type's recipe, and the first leaves out clay and iron. The arithmetic,
//  then the owner's pick as shipped.
//

import XCTest
@testable import ROIContent

final class PlotBuildCostTests: XCTestCase {

    private static let contentRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("content/data")

    private let rule = PlotBuildRuleDTO(firstPlotLeavesOut: ["mat.clay", "mat.iron"],
                                        multiplierByPlotNumber: [1, 2, 3, 4, 5, 6])

    private func recipe(_ pairs: [(String, Int)]) -> [MaterialCostDTO] {
        pairs.map { MaterialCostDTO(itemId: $0.0, quantity: $0.1) }
    }

    private func line(_ inputs: [MaterialCostDTO]) -> String {
        inputs.map { "\($0.quantity) \($0.itemId)" }.joined(separator: ", ")
    }

    private var mine: [MaterialCostDTO] {
        recipe([("mat.pine_lumber", 12), ("mat.hide", 3), ("mat.iron", 2), ("mat.clay", 1)])
    }

    // MARK: - The rule

    /// The approved sample, the mine of the fuller recipe: 66 → 260 → … → 780
    /// at the trader's prices, the first without clay and iron.
    func testTheApprovedMineLadder() {
        XCTAssertEqual(line(PlotBuildCost.inputs(recipe: mine, plotNumber: 1, rule: rule)),
                       "12 mat.pine_lumber, 3 mat.hide")
        XCTAssertEqual(line(PlotBuildCost.inputs(recipe: mine, plotNumber: 2, rule: rule)),
                       "24 mat.pine_lumber, 6 mat.hide, 4 mat.iron, 2 mat.clay")
        XCTAssertEqual(line(PlotBuildCost.inputs(recipe: mine, plotNumber: 6, rule: rule)),
                       "72 mat.pine_lumber, 18 mat.hide, 12 mat.iron, 6 mat.clay")
    }

    /// Only the first plot leaves anything out.
    func testOnlyTheFirstPlotLeavesOutClayAndIron() {
        for number in 2...6 {
            let ids = PlotBuildCost.inputs(recipe: mine, plotNumber: number, rule: rule).map(\.itemId)
            XCTAssertEqual(ids, mine.map(\.itemId), "plot \(number)")
        }
    }

    /// Past the table the last multiplier holds, as `plotSlotsByTier` does;
    /// a number below 1 is the first plot.
    func testTheTableEdges() {
        XCTAssertEqual(PlotBuildCost.inputs(recipe: mine, plotNumber: 9, rule: rule),
                       PlotBuildCost.inputs(recipe: mine, plotNumber: 6, rule: rule))
        XCTAssertEqual(PlotBuildCost.inputs(recipe: mine, plotNumber: 0, rule: rule),
                       PlotBuildCost.inputs(recipe: mine, plotNumber: 1, rule: rule))
        XCTAssertEqual(PlotBuildCost.inputs(recipe: mine, plotNumber: -3, rule: rule),
                       PlotBuildCost.inputs(recipe: mine, plotNumber: 1, rule: rule))
    }

    /// The file's reading finds the row by type, and refuses to guess without
    /// a row or a rule.
    func testTheFileReading() {
        let file = PlotFileDTO(types: [PlotTypeDTO(type: "mine", icon: "⛏", buildCost: mine)], build: rule)
        XCTAssertEqual(file.buildCost(for: "mine", plotNumber: 3),
                       PlotBuildCost.inputs(recipe: mine, plotNumber: 3, rule: rule))
        XCTAssertNil(file.buildCost(for: "coop", plotNumber: 1))
        XCTAssertNil(PlotFileDTO(types: file.types).buildCost(for: "mine", plotNumber: 1))
    }

    // MARK: - The owner's pick, as shipped

    /// «Кожна своя, повніше» × N with the first plot leaving out clay and iron
    /// (2026-10-24). Any change to the shipped recipes is a decision, and this
    /// is where it shows.
    func testTheShippedRecipesAreTheOwnersPick() throws {
        let plots = try XCTUnwrap(ContentLoader.load(from: Self.contentRoot).plots)
        let rule = try XCTUnwrap(plots.build)
        XCTAssertEqual(rule.firstPlotLeavesOut, ["mat.clay", "mat.iron"])
        XCTAssertEqual(rule.multiplierByPlotNumber, [1, 2, 3, 4, 5, 6])
        let recipes = Dictionary(uniqueKeysWithValues: plots.buildableTypes.map { ($0.type, line($0.buildCost)) })
        XCTAssertEqual(recipes, [
            "farm":   "10 mat.pine_lumber, 2 mat.hide, 1 mat.iron, 3 food.potato",
            "forest": "8 mat.pine_lumber, 10 mat.river_pebble, 2 mat.iron, 1 mat.clay",
            "mine":   "12 mat.pine_lumber, 3 mat.hide, 2 mat.iron, 1 mat.clay",
            "coop":   "8 mat.pine_lumber, 5 mat.river_pebble, 1 mat.clay, 3 food.duck_egg"
        ])
    }

    /// What the pick was FOR, so a rebalance that keeps it passes: every type
    /// its own recipe, clay and iron in it — the farm alone without clay, the
    /// coop alone without iron — and every first plot built without either.
    func testTheShippedRecipesAreDiverseAndTheFirstPlotIsLight() throws {
        let plots = try XCTUnwrap(ContentLoader.load(from: Self.contentRoot).plots)
        let rule = try XCTUnwrap(plots.build)
        let built = plots.buildableTypes
        let sets = built.map { Set($0.buildCost.map(\.itemId)) }
        XCTAssertEqual(Set(sets).count, built.count, "every type has a recipe of its own")
        XCTAssertEqual(built.filter { !$0.buildCost.contains { $0.itemId == "mat.clay" } }.map(\.type), ["farm"])
        XCTAssertEqual(built.filter { !$0.buildCost.contains { $0.itemId == "mat.iron" } }.map(\.type), ["coop"])
        for row in built {
            let first = Set(PlotBuildCost.inputs(recipe: row.buildCost, plotNumber: 1, rule: rule).map(\.itemId))
            XCTAssertTrue(first.isDisjoint(with: ["mat.clay", "mat.iron"]), row.type)
            XCTAssertFalse(first.isEmpty, row.type)
        }
    }

    // MARK: - The plot the estate grants (2026-11-01)

    /// N counts the plots the player BUILT: the hazel every estate starts with
    /// never makes the next plot dearer, so the first plot a player builds is
    /// still the light one.
    func testTheNextPlotNumberCountsOnlyBuiltPlots() {
        let granted: Set<String> = ["hazel"]
        XCTAssertEqual(PlotBuildCost.nextPlotNumber(ownedTypes: [], granted: granted), 1)
        XCTAssertEqual(PlotBuildCost.nextPlotNumber(ownedTypes: ["hazel"], granted: granted), 1)
        XCTAssertEqual(PlotBuildCost.nextPlotNumber(ownedTypes: ["hazel", "farm"], granted: granted), 2)
        XCTAssertEqual(PlotBuildCost.nextPlotNumber(ownedTypes: ["hazel", "farm", "coop", "farm"], granted: granted), 4)
        // Without a granted type every plot counts, as before 2026-11-01.
        XCTAssertEqual(PlotBuildCost.nextPlotNumber(ownedTypes: ["farm", "coop"], granted: []), 3)
    }

    /// Ripe means a full fill back, rounded up to a whole interval — it can only
    /// overshoot, and the yield is capped at the capacity.
    func testARipePlotIsAFullFillBack() {
        XCTAssertEqual(GrantedPlot.intervalsToFill(capacity: 5, ratePerInterval: 1), 5)
        XCTAssertEqual(GrantedPlot.intervalsToFill(capacity: 5, ratePerInterval: 2), 3)
        XCTAssertEqual(GrantedPlot.intervalsToFill(capacity: 10, ratePerInterval: 2), 5)
        XCTAssertEqual(GrantedPlot.intervalsToFill(capacity: 5, ratePerInterval: 0), 0)
    }

    /// The owner's picks (`spec-progression.md` §8): one granted type, the hazel,
    /// one nut an hour holding five, nothing to build — and a slot for it at
    /// every tier on top of the 0…6 a player builds on.
    func testTheShippedHazelIsTheOwnersPick() throws {
        let bundle = try ContentLoader.load(from: Self.contentRoot)
        let plots = try XCTUnwrap(bundle.plots)
        XCTAssertEqual(plots.grantedTypes, ["hazel"])
        let hazel = try XCTUnwrap(plots.types.first { $0.type == "hazel" })
        XCTAssertEqual(hazel.tuning?.producedItemId, "food.forest_nuts")
        XCTAssertEqual(hazel.tuning?.ratePerInterval, 1)
        XCTAssertEqual(hazel.tuning?.capacity, 5)
        XCTAssertNil(hazel.tuning?.bonusOutput)
        XCTAssertTrue(hazel.buildCost.isEmpty)
        XCTAssertEqual(bundle.estateUpgrades.plotSlotsByTier, [1, 2, 3, 4, 5, 6, 7])
        XCTAssertFalse(plots.buildableTypes.contains { $0.type == "hazel" })
    }
}
