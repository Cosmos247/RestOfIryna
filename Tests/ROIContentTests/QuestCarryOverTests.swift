//
//  QuestCarryOverTests.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 19.09.2026.
//
//  A taken job no longer burns at noon, so the rows the old rule left marked
//  `accepted` have to be closed once — all but the newest per player and NPC,
//  and that one only if it is from today or yesterday. These tests pin which
//  rows survive, and the date arithmetic that decides what "yesterday" is.
//

import XCTest
@testable import ROIContent

final class QuestCarryOverTests: XCTestCase {

    // MARK: - The day before

    func testPreviousStampCrossesMonthYearAndLeapDay() {
        XCTAssertEqual(QuestCarryOver.previousStamp("2026-09-19"), "2026-09-18")
        XCTAssertEqual(QuestCarryOver.previousStamp("2026-03-01"), "2026-02-28")
        XCTAssertEqual(QuestCarryOver.previousStamp("2028-03-01"), "2028-02-29")
        XCTAssertEqual(QuestCarryOver.previousStamp("2027-01-01"), "2026-12-31")
    }

    /// Kyiv changes clocks on these two Sundays in 2026. A game day that is 23
    /// or 25 hours long must still step back exactly one date.
    func testPreviousStampIgnoresDaylightSaving() {
        XCTAssertEqual(QuestCarryOver.previousStamp("2026-03-29"), "2026-03-28")
        XCTAssertEqual(QuestCarryOver.previousStamp("2026-03-30"), "2026-03-29")
        XCTAssertEqual(QuestCarryOver.previousStamp("2026-10-25"), "2026-10-24")
        XCTAssertEqual(QuestCarryOver.previousStamp("2026-10-26"), "2026-10-25")
    }

    func testPreviousStampRefusesWhatIsNotADate() {
        XCTAssertNil(QuestCarryOver.previousStamp("yesterday"))
        XCTAssertNil(QuestCarryOver.previousStamp(""))
    }

    // MARK: - The one-time cleanup

    private let alice = UUID()
    private let bob = UUID()

    private func job(_ user: UUID, _ npc: String, _ day: String) -> QuestCarryOver.OpenJob {
        .init(id: UUID(), userId: user, npc: npc, dayStamp: day)
    }

    func testYesterdaysJobSurvivesAndOlderOnesBurn() {
        let old = job(alice, "trader", "2026-09-13")
        let older = job(alice, "trader", "2026-09-11")
        let yesterday = job(alice, "trader", "2026-09-18")
        let closed = QuestCarryOver.burned([old, older, yesterday], today: "2026-09-19")
        XCTAssertEqual(closed, [old.id, older.id])
    }

    func testTodaysJobWinsOverYesterdays() {
        let yesterday = job(alice, "tavern", "2026-09-18")
        let today = job(alice, "tavern", "2026-09-19")
        let closed = QuestCarryOver.burned([yesterday, today], today: "2026-09-19")
        XCTAssertEqual(closed, [yesterday.id], "the job the player took most recently is the one kept")
    }

    /// The negative case: the newest job being "the newest" is not enough. If
    /// it is older than yesterday it burned under the old rule, and keeping it
    /// would resurrect a week-old job the player has long forgotten.
    func testNewestJobStillBurnsWhenOlderThanYesterday() {
        let a = job(alice, "master", "2026-09-17")
        let b = job(alice, "master", "2026-09-15")
        let closed = QuestCarryOver.burned([a, b], today: "2026-09-19")
        XCTAssertEqual(closed, [a.id, b.id])
    }

    func testPlayersAndNPCsAreJudgedSeparately() {
        let aliceTrader = job(alice, "trader", "2026-09-18")
        let aliceTavern = job(alice, "tavern", "2026-09-19")
        let bobTrader = job(bob, "trader", "2026-09-19")
        let bobOld = job(bob, "master", "2026-09-10")
        let closed = QuestCarryOver.burned([aliceTrader, aliceTavern, bobTrader, bobOld], today: "2026-09-19")
        XCTAssertEqual(closed, [bobOld.id])
    }

    func testNothingOpenMeansNothingClosed() {
        XCTAssertTrue(QuestCarryOver.burned([], today: "2026-09-19").isEmpty)
    }
}
