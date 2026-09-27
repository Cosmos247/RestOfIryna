//
//  SalvageMathTests.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 27.09.2026.
//
//  The workshop's «Розібрати» pays out what `SalvageMath` says, so the shapes
//  a player can hold are pinned here: a fresh piece, a half-worn one, one worn
//  to 1/1, and the rounding edge where an exact product must not lose a unit.
//  The recipe is the shipped Forester jerkin (15 hide + 4 iron) at the shipped
//  share of 0.5 against a starting max of 30.
//

import XCTest
@testable import ROISim

final class SalvageMathTests: XCTestCase {

    private let jerkin = [SalvageMath.Line(itemId: "mat.hide", quantity: 15),
                          SalvageMath.Line(itemId: "mat.iron", quantity: 4)]

    private func yield(_ inputs: [SalvageMath.Line], max: Int, fraction: Double = 0.5,
                       outputQuantity: Int = 1) -> [SalvageMath.Line] {
        SalvageMath.yield(recipeInputs: inputs, recipeOutputQuantity: outputQuantity,
                          fraction: fraction, maxDurability: max, maxDurabilityStart: 30)
    }

    func testFreshPieceReturnsTheShare() {
        XCTAssertEqual(yield(jerkin, max: 30),
                       [.init(itemId: "mat.hide", quantity: 7), .init(itemId: "mat.iron", quantity: 2)])
    }

    /// The owner's own example: a jerkin at 15/15 gives three hides and one iron.
    func testWearScalesTheShareDown() {
        XCTAssertEqual(yield(jerkin, max: 15),
                       [.init(itemId: "mat.hide", quantity: 3), .init(itemId: "mat.iron", quantity: 1)])
    }

    /// The case the feature exists for: nothing comes back, and the caller
    /// still removes the piece.
    func testPieceWornToOneReturnsNothing() {
        XCTAssertEqual(yield(jerkin, max: 1), [])
    }

    func testLinesThatRoundToZeroAreDropped() {
        // 4 iron × 0.5 × 7/30 = 0.47 → gone; 15 hide × 0.5 × 7/30 = 1.75 → 1.
        XCTAssertEqual(yield(jerkin, max: 7), [.init(itemId: "mat.hide", quantity: 1)])
    }

    /// 5 × 0.5 × 24/30 is exactly 2 — it must not floor to 1 on a
    /// floating-point representation of 0.8.
    func testAnExactProductKeepsItsUnit() {
        XCTAssertEqual(yield([.init(itemId: "mat.hide", quantity: 5)], max: 24),
                       [.init(itemId: "mat.hide", quantity: 2)])
    }

    func testMaxAboveStartCountsAsFresh() {
        XCTAssertEqual(yield(jerkin, max: 40), yield(jerkin, max: 30))
    }

    func testZeroShareReturnsNothing() {
        XCTAssertEqual(yield(jerkin, max: 30, fraction: 0), [])
    }

    /// A recipe that makes two pieces pays each piece half of its inputs.
    func testARecipeMakingSeveralIsSplitPerPiece() {
        XCTAssertEqual(yield([.init(itemId: "mat.hide", quantity: 10)], max: 30, outputQuantity: 2),
                       [.init(itemId: "mat.hide", quantity: 2)])
    }
}
