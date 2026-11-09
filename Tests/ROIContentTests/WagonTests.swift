//
//  WagonTests.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 08.11.2026.
//
//  The wagon (`content/spec/spec-wagon.md`): the shipped `stable.json` is the
//  owner's row and passes; every validator rule fails on the one mistake it
//  exists for; and `WagonMath` — the arithmetic behind every fit check, take and
//  end-of-hire delivery — splits the way §3 says, all or nothing.
//

import XCTest
@testable import ROIContent
@testable import ROISim

final class WagonTests: XCTestCase {

    private static let contentRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("content/data")

    private func shipped() throws -> ContentBundle {
        try ContentLoader.load(from: Self.contentRoot)
    }

    /// The shipped bundle with only the wagon swapped.
    private func bundle(_ wagon: WagonDTO) throws -> ContentBundle {
        let s = try shipped()
        return ContentBundle(
            manifest: s.manifest, items: s.items, enemies: s.enemies, recipes: s.recipes,
            starterRecipeIds: s.starterRecipeIds, weaponLadders: s.weaponLadders,
            bags: s.bags, estateUpgrades: s.estateUpgrades, plots: s.plots,
            stable: StableFileDTO(horse: try XCTUnwrap(s.stable?.horse), wagon: wagon),
            tuning: s.tuning, contentHash: "test")
    }

    private func rules(_ wagon: WagonDTO) throws -> [String] {
        ContentValidator.validate(try bundle(wagon)).issues.map(\.rule).filter { $0.hasPrefix("stable.") }
    }

    private func length(_ minutes: Int, _ silver: Int) -> WagonLengthDTO {
        WagonLengthDTO(minutes: minutes, silver: silver)
    }

    // MARK: - The shipped wagon

    /// The owner's row (2026-11-08): 200 places; 1 h 100, 3 h 190, 1 day 670,
    /// 7 days 2,160; a crossing of 3 minutes with it — and it passes every rule.
    func testShippedWagonIsTheOwnersRow() throws {
        let wagon = try XCTUnwrap(try shipped().stable?.wagon)
        XCTAssertEqual(wagon.capacity, 200)
        XCTAssertEqual(wagon.travelMinutes, 3)
        XCTAssertEqual(wagon.lengths.map(\.minutes), [60, 180, 1440, 10080])
        XCTAssertEqual(wagon.lengths.map(\.silver), [100, 190, 670, 2160])
        XCTAssertEqual(try rules(wagon), [])
    }

    // MARK: - Every rule fails on its own mistake

    func testWagonNotAboveTheLargestBagFails() throws {
        let lengths = [length(60, 100)]
        let largest = try XCTUnwrap(try shipped().bags.capacities.max())
        XCTAssertEqual(try rules(WagonDTO(capacity: largest, travelMinutes: 3, lengths: lengths)), ["stable.wagon_not_above_bag"])
        XCTAssertEqual(try rules(WagonDTO(capacity: largest + 1, travelMinutes: 3, lengths: lengths)), [])
    }

    /// The owner: three minutes with the wagon, not two — never fewer than the
    /// road's own.
    func testWagonFasterThanTheRoadFails() throws {
        let lengths = [length(60, 100)]
        let road = try XCTUnwrap(try shipped().tuning?.time.gameTime.travelMinutes)
        XCTAssertEqual(try rules(WagonDTO(capacity: 200, travelMinutes: road - 1, lengths: lengths)),
                       ["stable.wagon_faster_than_road"])
        XCTAssertEqual(try rules(WagonDTO(capacity: 200, travelMinutes: road, lengths: lengths)), [])
    }

    func testNoLengthFails() throws {
        XCTAssertEqual(try rules(WagonDTO(capacity: 200, travelMinutes: 3, lengths: [])), ["stable.wagon_no_lengths"])
    }

    func testNonPositiveLengthFails() throws {
        XCTAssertEqual(try rules(WagonDTO(capacity: 200, travelMinutes: 3, lengths: [length(0, 100)])), ["stable.wagon_length_not_positive"])
        XCTAssertEqual(try rules(WagonDTO(capacity: 200, travelMinutes: 3, lengths: [length(60, 0)])), ["stable.wagon_length_not_positive"])
    }

    func testLengthsMustGrow() throws {
        XCTAssertEqual(try rules(WagonDTO(capacity: 200, travelMinutes: 3, lengths: [length(180, 190), length(60, 200)])),
                       ["stable.wagon_length_not_longer"])
    }

    /// A longer length at the same total would leave the shorter one unbought.
    func testLongerMustCostMore() throws {
        XCTAssertEqual(try rules(WagonDTO(capacity: 200, travelMinutes: 3, lengths: [length(60, 100), length(180, 100)])),
                       ["stable.wagon_longer_not_pricier"])
    }

    /// The owner's rule: the longest is the cheapest per minute. Equal per
    /// minute fails too — 1 h at 100 and 3 h at 300.
    func testLongerMustBeCheaperPerMinute() throws {
        XCTAssertEqual(try rules(WagonDTO(capacity: 200, travelMinutes: 3, lengths: [length(60, 100), length(180, 300)])),
                       ["stable.wagon_longer_not_cheaper_per_minute"])
        XCTAssertEqual(try rules(WagonDTO(capacity: 200, travelMinutes: 3, lengths: [length(60, 100), length(180, 301)])),
                       ["stable.wagon_longer_not_cheaper_per_minute"])
        XCTAssertEqual(try rules(WagonDTO(capacity: 200, travelMinutes: 3, lengths: [length(60, 100), length(180, 299)])), [])
    }

    // MARK: - WagonMath

    func testTheWagonRidesAlongOnlyWhileHiredAndBroughtWith() {
        XCTAssertTrue(WagonMath.ridesAlong(running: true, leftHome: false))
        XCTAssertFalse(WagonMath.ridesAlong(running: true, leftHome: true), "on horseback the wagon stays at home")
        XCTAssertFalse(WagonMath.ridesAlong(running: false, leftHome: false), "a finished hire rides nowhere")
        XCTAssertFalse(WagonMath.ridesAlong(running: false, leftHome: true))
    }

    func testOnlyAWagonThatRidesAlongSlowsTheRoad() {
        XCTAssertEqual(WagonMath.crossing(road: 120, wagon: 180, ridesAlong: true), 180)
        XCTAssertEqual(WagonMath.crossing(road: 120, wagon: 180, ridesAlong: false), 120)
        XCTAssertEqual(WagonMath.crossing(road: 180, wagon: 120, ridesAlong: true), 180, "a wagon is never the faster way")
    }

    func testAHireThatRunsGrowsAndOneThatRanOutStartsAgain() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        XCTAssertEqual(WagonMath.end(after: now.addingTimeInterval(600), now: now, adding: 3600),
                       now.addingTimeInterval(4200))
        XCTAssertEqual(WagonMath.end(after: now.addingTimeInterval(-600), now: now, adding: 3600),
                       now.addingTimeInterval(3600))
        XCTAssertEqual(WagonMath.end(after: nil, now: now, adding: 3600), now.addingTimeInterval(3600))
    }

    func testTakeDrawsTheBagFirst() {
        XCTAssertEqual(WagonMath.take(26, bag: 10, wagon: 30).map { [$0.fromBag, $0.fromWagon] }, [10, 16])
        XCTAssertEqual(WagonMath.take(5, bag: 10, wagon: 30).map { [$0.fromBag, $0.fromWagon] }, [5, 0])
        XCTAssertEqual(WagonMath.take(30, bag: 0, wagon: 30).map { [$0.fromBag, $0.fromWagon] }, [0, 30])
        XCTAssertNil(WagonMath.take(41, bag: 10, wagon: 30))
    }

    /// All or nothing: a put the two stores cannot hold writes nothing.
    func testPutFillsTheBagThenTheWagon() {
        XCTAssertEqual(WagonMath.put(150, bagFree: 45, bagUnbounded: false, wagonFree: 200).map { [$0.toBag, $0.toWagon] },
                       [45, 105])
        XCTAssertEqual(WagonMath.put(10, bagFree: 45, bagUnbounded: false, wagonFree: 0).map { [$0.toBag, $0.toWagon] },
                       [10, 0])
        XCTAssertNil(WagonMath.put(246, bagFree: 45, bagUnbounded: false, wagonFree: 200))
        XCTAssertNil(WagonMath.put(46, bagFree: 45, bagUnbounded: false, wagonFree: 0))
        // A developer's bag has no ceiling, as `InventoryEntry.add` has none.
        XCTAssertEqual(WagonMath.put(500, bagFree: 0, bagUnbounded: true, wagonFree: 0).map { [$0.toBag, $0.toWagon] },
                       [500, 0])
    }

    /// The end of a hire: pile by pile until the warehouse is full.
    func testDeliveryStopsAtTheWarehouseCap() {
        XCTAssertEqual(WagonMath.deliver([100, 50, 30], warehouseFree: 120), [100, 20, 0])
        XCTAssertEqual(WagonMath.deliver([100, 50], warehouseFree: 500), [100, 50])
        XCTAssertEqual(WagonMath.deliver([100, 50], warehouseFree: 0), [0, 0])
    }
}
