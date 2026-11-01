//
//  MealMathTests.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 01.11.2026.
//
//  The bag card's many-portion button, pinned on the sample the owner picked
//  it from (2026-11-01): a level-5 mage, a pool of 125, forest berries at +4
//  and the Governor's Feast at +72.
//

import XCTest
@testable import ROISim

final class MealMathTests: XCTestCase {

    private func berries(vigor: Int, held: Int) -> MealMath.Bulk? {
        MealMath.bulk(vigor: vigor, maxVigor: 125, vigorPerPortion: 4, held: held)
    }

    /// 105 missing takes 27 berries; four cannot fill it, so the button eats them all.
    func testFewerThanNeededEatsThemAll() {
        XCTAssertEqual(berries(vigor: 20, held: 4), .all(4))
    }

    func testEnoughFillsThePoolAndNoMore() {
        XCTAssertEqual(berries(vigor: 20, held: 30), .toFull(27))
        XCTAssertEqual(berries(vigor: 117, held: 30), .toFull(2))
    }

    /// The count rounds up: the last portion tops the pool out and loses the rest.
    func testTheLastPortionMayOverflow() {
        XCTAssertEqual(MealMath.bulk(vigor: 20, maxVigor: 125, vigorPerPortion: 72, held: 5), .toFull(2))
    }

    /// One portion is the plain «Зʼїсти»; a full pool and a lone unit get nothing.
    func testNoButtonWhenItWouldBeTheSingleTap() {
        XCTAssertNil(berries(vigor: 122, held: 30))
        XCTAssertNil(berries(vigor: 125, held: 30))
        XCTAssertNil(berries(vigor: 20, held: 1))
    }

    /// A food that restores no Vigor (a potion's HP, a raw ingredient) has no such button.
    func testNothingToFillWithoutVigor() {
        XCTAssertNil(MealMath.bulk(vigor: 20, maxVigor: 125, vigorPerPortion: 0, held: 6))
    }

    func testTheCountIsWhatTheButtonEats() {
        XCTAssertEqual(MealMath.Bulk.toFull(27).count, 27)
        XCTAssertEqual(MealMath.Bulk.all(4).count, 4)
    }
}
