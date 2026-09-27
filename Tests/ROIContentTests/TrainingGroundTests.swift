//
//  TrainingGroundTests.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 27.09.2026.
//
//  `training_ground.json` against the shipped content: the ladder itself is
//  clean, every validator rule fails on the one mistake it exists for, and the
//  catch-up rule — a player who already knows techniques never pays for them —
//  stops exactly where their knowledge does.
//

import XCTest
@testable import ROIContent

final class TrainingGroundTests: XCTestCase {

    /// The repository's own content directory, found from this file.
    private static let contentRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("content/data")

    private func shipped() throws -> ContentBundle {
        try ContentLoader.load(from: Self.contentRoot)
    }

    /// The shipped bundle with only the ladder swapped, filtered to the
    /// ladder's own rules.
    private func issues(_ levels: [TrainingGroundLevelDTO]) throws -> [String] {
        let s = try shipped()
        let bundle = ContentBundle(
            manifest: s.manifest, items: s.items, enemies: s.enemies, recipes: s.recipes,
            starterRecipeIds: s.starterRecipeIds, weaponLadders: s.weaponLadders,
            bags: s.bags, estateUpgrades: s.estateUpgrades, plots: s.plots,
            trainingGround: TrainingGroundFileDTO(levels: levels),
            tuning: s.tuning, contentHash: "test")
        return ContentValidator.validate(bundle).issues.map(\.rule).filter { $0.hasPrefix("training.") }
    }

    private func level(_ level: Int, _ technique: String, silver: Int = 100,
                       inputs: [MaterialCostDTO] = [MaterialCostDTO(itemId: "mat.hide", quantity: 5)]) -> TrainingGroundLevelDTO {
        TrainingGroundLevelDTO(level: level, technique: technique, silverCost: silver, inputs: inputs)
    }

    private var ladder: [TrainingGroundLevelDTO] {
        [level(1, "special_atk"), level(2, "special_def"), level(3, "super")]
    }

    // MARK: - The shipped ladder

    func testShippedLadderIsClean() throws {
        let s = try shipped()
        XCTAssertEqual(s.trainingGround?.levels.map(\.technique), ["special_atk", "special_def", "super"])
        XCTAssertEqual(try issues(s.trainingGround?.levels ?? []), [])
    }

    // MARK: - Every rule, failing on purpose

    func testEmptyLadderIsAnError() throws {
        XCTAssertTrue(try issues([]).contains("training.no_levels"))
    }

    func testLevelsMustRunFromOne() throws {
        XCTAssertTrue(try issues([level(2, "special_atk"), level(3, "special_def"), level(4, "super")])
            .contains("training.level_sequence"))
    }

    func testUnknownTechniqueIsAnError() throws {
        XCTAssertTrue(try issues(ladder + [level(4, "kick")]).contains("training.technique_unknown"))
    }

    func testTechniqueTaughtTwiceIsAnError() throws {
        XCTAssertTrue(try issues(ladder + [level(4, "super")]).contains("training.technique_twice"))
    }

    /// `super` opens at player level 14 and `special_atk` at 10: a ladder that
    /// sells the super first would open its second level earlier than its first.
    func testALevelOpeningBeforeTheOneBelowIsAnError() throws {
        XCTAssertTrue(try issues([level(1, "super"), level(2, "special_atk"), level(3, "special_def")])
            .contains("training.floor_order"))
    }

    func testATechniqueNoLevelTeachesIsAnError() throws {
        XCTAssertTrue(try issues([level(1, "special_atk"), level(2, "special_def")])
            .contains("training.technique_unreachable"))
    }

    func testUnknownItemAndEmptyQuantityAreErrors() throws {
        let rules = try issues([level(1, "special_atk", inputs: [MaterialCostDTO(itemId: "mat.nope", quantity: 0)]),
                                level(2, "special_def"), level(3, "super")])
        XCTAssertTrue(rules.contains("training.unknown_item"))
        XCTAssertTrue(rules.contains("training.input_quantity"))
    }

    func testNegativeSilverIsAnError() throws {
        XCTAssertTrue(try issues([level(1, "special_atk", silver: -1), level(2, "special_def"), level(3, "super")])
            .contains("training.negative_silver"))
    }

    // MARK: - Catch-up

    /// Nerif knew all three on the old plot-based ground: paying for the
    /// building lands on level 3, and nothing else is ever charged.
    func testCatchUpClimbsThroughEverythingAlreadyKnown() {
        let all: Set<String> = ["special_atk", "special_def", "super"]
        XCTAssertEqual(TrainingGroundLevelDTO.levelAfterCatchUp(paid: 1, in: ladder, known: all), 3)
        XCTAssertEqual(TrainingGroundLevelDTO.levelAfterCatchUp(paid: 1, in: ladder, known: ["special_atk", "special_def"]), 2)
        XCTAssertEqual(TrainingGroundLevelDTO.levelAfterCatchUp(paid: 1, in: ladder, known: ["special_atk"]), 1)
    }

    /// A new player: the paid level stands, since its technique is what the
    /// payment teaches.
    func testCatchUpLeavesThePaidLevelForANewPlayer() {
        XCTAssertEqual(TrainingGroundLevelDTO.levelAfterCatchUp(paid: 1, in: ladder, known: []), 1)
    }

    /// Knowing the super but not the defence stops at the gap: the defence is
    /// still something to buy.
    func testCatchUpStopsAtTheFirstUnknownLevel() {
        XCTAssertEqual(TrainingGroundLevelDTO.levelAfterCatchUp(paid: 1, in: ladder, known: ["special_atk", "super"]), 1)
        XCTAssertEqual(TrainingGroundLevelDTO.levelAfterCatchUp(paid: 2, in: ladder, known: ["special_atk", "special_def", "super"]), 3)
    }

    func testCatchUpNeverClimbsPastTheTop() {
        XCTAssertEqual(TrainingGroundLevelDTO.levelAfterCatchUp(paid: 3, in: ladder, known: ["special_atk", "special_def", "super"]), 3)
    }
}
