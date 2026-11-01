//
//  ExpeditionHaulTests.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 23.10.2026.
//
//  What an active walk brings home (2026-10-23): what went into the bag, less
//  what was eaten of it, in item-id order; silver apart; what the bag refused
//  never counted.
//

import XCTest
@testable import ROIContent

final class ExpeditionHaulTests: XCTestCase {

    private func pairs(_ haul: ExpeditionHaul) -> [String] {
        haul.brought.map { "\($0.itemId)×\($0.quantity)" }
    }

    /// The approved sample: two berries found and one eaten, two nuts, a
    /// boar's meat and hide, a pine beam; the pebbles did not fit.
    func testTheApprovedSample() {
        var haul = ExpeditionHaul()
        haul.take("food.forest_berries", quantity: 2)
        haul.take("mat.pine_lumber", quantity: 1)
        haul.take("food.forest_nuts", quantity: 2)
        haul.eat("food.forest_berries")
        haul.take("food.raw_meat", quantity: 1)
        haul.take("mat.hide", quantity: 1)
        haul.take("mat.river_pebble", quantity: 0)
        haul.findSilver(5)

        XCTAssertEqual(pairs(haul), ["food.forest_berries×1", "food.forest_nuts×2", "food.raw_meat×1",
                                     "mat.hide×1", "mat.pine_lumber×1"])
        XCTAssertEqual(haul.silver, 5)
        XCTAssertFalse(haul.isEmptyHanded)
    }

    /// Food from home eaten on the road nets against the same item found, and
    /// eating more than was found never prints a negative or a zero.
    func testEatingMoreThanWasFoundLeavesTheItemOut() {
        var haul = ExpeditionHaul()
        haul.take("food.forest_berries", quantity: 1)
        haul.eat("food.forest_berries")
        haul.eat("food.forest_berries")
        haul.eat("food.duck_egg")
        XCTAssertEqual(pairs(haul), [])
        XCTAssertTrue(haul.isEmptyHanded)
    }

    /// Silver alone is not empty-handed.
    func testSilverAloneIsNotEmptyHanded() {
        var haul = ExpeditionHaul()
        haul.findSilver(2)
        XCTAssertEqual(pairs(haul), [])
        XCTAssertFalse(haul.isEmptyHanded)
    }

    /// A refused find and a zero coin roll leave the haul as it was — the case
    /// that must fail if `take` counted what was found rather than taken.
    func testWhatTheBagRefusedIsNeverCounted() {
        var haul = ExpeditionHaul()
        haul.take("mat.river_pebble", quantity: 0)
        haul.take("mat.river_pebble", quantity: -1)
        haul.findSilver(0)
        XCTAssertEqual(haul, ExpeditionHaul())
        XCTAssertTrue(haul.isEmptyHanded)
    }

    /// The row stores it as JSON; a round trip keeps every count.
    func testItSurvivesTheRow() throws {
        var haul = ExpeditionHaul()
        haul.take("food.forest_nuts", quantity: 2)
        haul.eat("food.forest_nuts")
        haul.drop("mat.river_pebble", quantity: 3)
        haul.findSilver(10)
        let data = try JSONEncoder().encode(haul)
        XCTAssertEqual(try JSONDecoder().decode(ExpeditionHaul.self, from: data), haul)
    }

    /// Thrown away on the walk is not brought home (2026-11-01): it nets out by
    /// item, like a meal — a pebble carried from home thrown away against a
    /// pebble found included.
    func testThrownAwayIsNotBroughtHome() {
        var haul = ExpeditionHaul()
        haul.take("mat.river_pebble", quantity: 5)
        haul.take("mat.iron", quantity: 1)
        haul.drop("mat.river_pebble", quantity: 3)
        haul.drop("mat.clay", quantity: 2)
        XCTAssertEqual(pairs(haul), ["mat.iron×1", "mat.river_pebble×2"])
        haul.drop("mat.river_pebble", quantity: 4)
        XCTAssertEqual(pairs(haul), ["mat.iron×1"])
    }

    /// The card's «До повної снаги (N)» eats N at once and nets out N.
    func testSeveralEatenAtOnce() {
        var haul = ExpeditionHaul()
        haul.take("food.forest_berries", quantity: 9)
        haul.eat("food.forest_berries", quantity: 5)
        haul.eat("food.forest_berries", quantity: 0)
        XCTAssertEqual(pairs(haul), ["food.forest_berries×4"])
    }

    /// A haul written before `dropped` existed — a walk in progress across the
    /// restart that ships it — still decodes, with nothing thrown away.
    func testAHaulFromBeforeTheDiscardStillDecodes() throws {
        let old = #"{"taken":{"food.forest_nuts":2},"eaten":{"food.forest_nuts":1},"silver":4}"#
        let haul = try JSONDecoder().decode(ExpeditionHaul.self, from: Data(old.utf8))
        XCTAssertEqual(pairs(haul), ["food.forest_nuts×1"])
        XCTAssertEqual(haul.silver, 4)
        XCTAssertEqual(haul.dropped, [:])
    }
}
