//
//  PlotOrdinalTests.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 04.11.2026.
//
//  The plot buttons' number (2026-11-04, the owner): a repeated type counts
//  within itself in place order — «🌾 Ферма (1)», «🌾 Ферма (2)» — and a type
//  that stands once carries none. Pinned on the sample it was asked about.
//

import XCTest
@testable import ROIContent

final class PlotOrdinalTests: XCTestCase {

    /// Hazel, farm, lumberyard, farm and an empty place: «🌳 Ліщина», «🌾 Ферма (1)»,
    /// «🪚 Лісопилка», «🌾 Ферма (2)», «➕ Ділянка 5».
    func testTheOwnersSample() {
        XCTAssertEqual(PlotOrdinal.of(["hazel", "farm", "forest", "farm", nil]), [nil, 1, nil, 2, nil])
    }

    /// The ordinal is the type's own count, not the place number.
    func testEachTypeCountsItself() {
        XCTAssertEqual(PlotOrdinal.of(["farm", "coop", "farm", "coop", "farm"]), [1, 1, 2, 2, 3])
    }

    /// One plot of each type: names alone.
    func testAUniqueTypeCarriesNoNumber() {
        XCTAssertEqual(PlotOrdinal.of(["hazel", "farm", "mine", nil]), [nil, nil, nil, nil])
    }

    /// Empty places never count, nor take a number.
    func testEmptyPlacesAreSkipped() {
        XCTAssertEqual(PlotOrdinal.of([nil, "farm", nil, "farm"]), [nil, 1, nil, 2])
        XCTAssertEqual(PlotOrdinal.of([String?]()), [])
    }
}
