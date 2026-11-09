//
//  HorseTests.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 09.11.2026.
//
//  The Rysak (`content/spec/spec-horse.md`): the shipped `stable.json` is the
//  owner's row and passes; every validator rule fails on the one mistake it
//  exists for; and `WagonMath.crossing`, the one reading of a road, takes its
//  three branches in the order §3.2 says.
//

import XCTest
@testable import ROIContent
@testable import ROISim

final class HorseTests: XCTestCase {

    private static let contentRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("content/data")

    private func shipped() throws -> ContentBundle {
        try ContentLoader.load(from: Self.contentRoot)
    }

    /// The shipped bundle with only the horse swapped.
    private func bundle(_ horse: HorseDTO) throws -> ContentBundle {
        let s = try shipped()
        return ContentBundle(
            manifest: s.manifest, items: s.items, enemies: s.enemies, recipes: s.recipes,
            starterRecipeIds: s.starterRecipeIds, weaponLadders: s.weaponLadders,
            bags: s.bags, estateUpgrades: s.estateUpgrades, plots: s.plots,
            stable: StableFileDTO(horse: horse, wagon: try XCTUnwrap(s.stable?.wagon)),
            tuning: s.tuning, contentHash: "test")
    }

    private func rules(_ horse: HorseDTO) throws -> [String] {
        ContentValidator.validate(try bundle(horse)).issues.map(\.rule).filter { $0.hasPrefix("stable.") }
    }

    private func length(_ minutes: Int, _ silver: Int) -> WagonLengthDTO {
        WagonLengthDTO(minutes: minutes, silver: silver)
    }

    // MARK: - The shipped horse

    /// The owner's row (2026-11-09): 1 min 30 s; 1 h 50, 3 h 100, 1 day 340,
    /// 7 days 1,080 — and it passes every rule.
    func testShippedHorseIsTheOwnersRow() throws {
        let horse = try XCTUnwrap(try shipped().stable?.horse)
        XCTAssertEqual(horse.travelSeconds, 90)
        XCTAssertEqual(horse.lengths.map(\.minutes), [60, 180, 1440, 10080])
        XCTAssertEqual(horse.lengths.map(\.silver), [50, 100, 340, 1080])
        XCTAssertEqual(try rules(horse), [])
    }

    // MARK: - Every rule fails on its own mistake

    /// A horse hired to be faster has to be; equal to the road is not faster.
    func testHorseNotFasterThanTheRoadFails() throws {
        let lengths = [length(60, 50)]
        let road = try XCTUnwrap(try shipped().tuning?.time.gameTime.travelMinutes) * 60
        XCTAssertEqual(try rules(HorseDTO(travelSeconds: road, lengths: lengths)), ["stable.horse_not_faster_than_road"])
        XCTAssertEqual(try rules(HorseDTO(travelSeconds: road + 1, lengths: lengths)), ["stable.horse_not_faster_than_road"])
        XCTAssertEqual(try rules(HorseDTO(travelSeconds: road - 1, lengths: lengths)), [])
    }

    func testNonPositiveCrossingFails() throws {
        XCTAssertEqual(try rules(HorseDTO(travelSeconds: 0, lengths: [length(60, 50)])), ["stable.horse_crossing_not_positive"])
    }

    func testNoLengthFails() throws {
        XCTAssertEqual(try rules(HorseDTO(travelSeconds: 90, lengths: [])), ["stable.horse_no_lengths"])
    }

    func testNonPositiveLengthFails() throws {
        XCTAssertEqual(try rules(HorseDTO(travelSeconds: 90, lengths: [length(0, 50)])), ["stable.horse_length_not_positive"])
        XCTAssertEqual(try rules(HorseDTO(travelSeconds: 90, lengths: [length(60, 0)])), ["stable.horse_length_not_positive"])
    }

    func testLengthsMustGrow() throws {
        XCTAssertEqual(try rules(HorseDTO(travelSeconds: 90, lengths: [length(180, 100), length(60, 110)])),
                       ["stable.horse_length_not_longer"])
    }

    func testLongerMustCostMore() throws {
        XCTAssertEqual(try rules(HorseDTO(travelSeconds: 90, lengths: [length(60, 50), length(180, 50)])),
                       ["stable.horse_longer_not_pricier"])
    }

    /// The owner's rule for the wagon, on the Rysak too: equal per minute fails.
    func testLongerMustBeCheaperPerMinute() throws {
        XCTAssertEqual(try rules(HorseDTO(travelSeconds: 90, lengths: [length(60, 50), length(180, 150)])),
                       ["stable.horse_longer_not_cheaper_per_minute"])
        XCTAssertEqual(try rules(HorseDTO(travelSeconds: 90, lengths: [length(60, 50), length(180, 149)])), [])
    }

    // MARK: - The crossing

    func testTheRysakShortensTheRoad() {
        XCTAssertEqual(WagonMath.crossing(road: 120, wagon: 180, ridesAlong: false, horse: 90), 90)
    }

    /// The owner, 2026-11-09: the wagon sets the pace, hired horse or not.
    func testTheWagonSetsThePaceOverTheRysak() {
        XCTAssertEqual(WagonMath.crossing(road: 120, wagon: 180, ridesAlong: true, horse: 90), 180)
    }

    func testNoHireIsTheRoad() {
        XCTAssertEqual(WagonMath.crossing(road: 120, wagon: 180, ridesAlong: false, horse: nil), 120)
    }

    // MARK: - What a question saw

    /// A double tap pays once because the yes names the hire it saw: 0 with
    /// nothing running, the end while one runs, and a different number the
    /// moment a hire is bought or grows.
    func testHireStampNamesTheHireTheQuestionSaw() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        XCTAssertEqual(WagonMath.hireStamp(end: nil, now: now), 0, "never hired")
        XCTAssertEqual(WagonMath.hireStamp(end: now.addingTimeInterval(-60), now: now), 0, "a hire that ran out")
        XCTAssertEqual(WagonMath.hireStamp(end: now, now: now), 0, "a hire ending this instant has run out")
        XCTAssertEqual(WagonMath.hireStamp(end: now.addingTimeInterval(3600), now: now), 1_800_003_600)
        XCTAssertNotEqual(WagonMath.hireStamp(end: now.addingTimeInterval(3600), now: now),
                          WagonMath.hireStamp(end: now.addingTimeInterval(7200), now: now), "a hire that grew")
    }

    /// A hired horse is never the slower way, whatever a fixture says.
    func testTheRysakIsNeverSlowerThanTheRoad() {
        XCTAssertEqual(WagonMath.crossing(road: 120, wagon: 180, ridesAlong: false, horse: 150), 120)
    }
}
