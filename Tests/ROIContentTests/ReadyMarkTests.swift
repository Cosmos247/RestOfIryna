//
//  ReadyMarkTests.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 09.11.2026.
//
//  «✅» after a button's name: it goes after the name and only when every cost
//  is covered.
//

import XCTest
@testable import ROISim

final class ReadyMarkTests: XCTestCase {

    func testTheMarkGoesAfterTheName() {
        XCTAssertEqual(ReadyMark.label("🌼 Мала настоянка зцілення", ready: true), "🌼 Мала настоянка зцілення ✅")
    }

    func testNothingIsShownWhenSomethingIsShort() {
        XCTAssertEqual(ReadyMark.label("🌼 Мала настоянка зцілення", ready: false), "🌼 Мала настоянка зцілення")
    }

    func testExactlyEnoughCovers() {
        XCTAssertTrue(ReadyMark.covers([("a", 2), ("b", 1)], held: ["a": 2, "b": 1]))
    }

    func testOneUnitShortDoesNot() {
        XCTAssertFalse(ReadyMark.covers([("a", 2), ("b", 1)], held: ["a": 1, "b": 9]))
    }

    func testAnItemNeverHeldDoesNot() {
        XCTAssertFalse(ReadyMark.covers([("a", 1)], held: ["b": 9]))
    }

    /// A cost listed twice is what the writers drain, the sum.
    func testACostListedTwiceCountsAsTheSum() {
        XCTAssertFalse(ReadyMark.covers([("a", 2), ("a", 2)], held: ["a": 3]))
        XCTAssertTrue(ReadyMark.covers([("a", 2), ("a", 2)], held: ["a": 4]))
    }

    func testNoCostIsCovered() {
        XCTAssertTrue(ReadyMark.covers([], held: [:]))
    }
}
