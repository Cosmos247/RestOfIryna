//
//  UkrainianPluralTests.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 15.09.2026.
//
//  The three-form rule behind `unit.silver.one/few/many`.
//
//  Worth a file of its own because the rule has one trap and it is invisible
//  to casual testing: 11 ends in 1 and 12 ends in 2, so a units-only
//  implementation calls them `one` and `few` when Ukrainian wants `many`. The
//  silver find ships denominations 2/5/10/20 — none of which touch the trap —
//  so the bug would have waited for the first quest reward or trade total that
//  happened to be eleven.
//

import XCTest
@testable import ROIContent

final class UkrainianPluralTests: XCTestCase {

    func testSingularEndings() {
        for n in [1, 21, 31, 101, 1001] {
            XCTAssertEqual(UkrainianPlural.form(for: n), .one, "\(n)")
        }
    }

    func testFewEndings() {
        for n in [2, 3, 4, 22, 23, 24, 102, 1004] {
            XCTAssertEqual(UkrainianPlural.form(for: n), .few, "\(n)")
        }
    }

    func testManyEndings() {
        for n in [5, 6, 9, 10, 20, 25, 100, 1000] {
            XCTAssertEqual(UkrainianPlural.form(for: n), .many, "\(n)")
        }
    }

    /// The whole reason this file exists.
    func testTeensAreManyDespiteTheirUnitsDigit() {
        for n in [11, 12, 13, 14, 111, 112, 113, 114, 1011] {
            XCTAssertEqual(UkrainianPlural.form(for: n), .many,
                           "\(n) ends in \(n % 10) but the 11–14 band overrides it")
        }
    }

    /// Zero is `many` — «0 срібників» — and a negative count must not trap or
    /// fall through to a different form than its magnitude.
    func testZeroAndNegatives() {
        XCTAssertEqual(UkrainianPlural.form(for: 0), .many)
        XCTAssertEqual(UkrainianPlural.form(for: -1), .one)
        XCTAssertEqual(UkrainianPlural.form(for: -3), .few)
        XCTAssertEqual(UkrainianPlural.form(for: -11), .many)
    }

    /// The four amounts the silver find actually ships, pinned so a content
    /// edit that adds a denomination has to look at this list.
    func testShippedSilverDenominations() {
        XCTAssertEqual(UkrainianPlural.form(for: 2), .few)    // срібники
        XCTAssertEqual(UkrainianPlural.form(for: 5), .many)   // срібників
        XCTAssertEqual(UkrainianPlural.form(for: 10), .many)
        XCTAssertEqual(UkrainianPlural.form(for: 20), .many)
    }
}
