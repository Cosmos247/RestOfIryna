//
//  WearMathTests.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 24.10.2026.
//
//  A fight wears less since 2026-10-24: a win ½, a flee 1, a death 2 (it was
//  1 / 2 / 3). A fraction is a chance per fight (`WearMath`). The arithmetic,
//  the per-fight roll a passive run depends on, then the owner's pick as
//  shipped.
//

import XCTest
@testable import ROIContent
@testable import ROISim

final class WearMathTests: XCTestCase {

    private static let contentRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("content/data")

    /// A whole budget never rolls: the flee's 1 and the death's 2 are exact.
    func testAWholeBudgetIsExact() {
        var rng = SplitMix64(seed: 1)
        for _ in 0..<1_000 {
            XCTAssertEqual(WearMath.points(budget: 1, using: &rng), 1)
            XCTAssertEqual(WearMath.points(budget: 2, using: &rng), 2)
        }
        XCTAssertEqual(WearMath.points(budget: 2, fights: 7, using: &rng), 14)
    }

    func testNothingTakesNothing() {
        var rng = SplitMix64(seed: 2)
        XCTAssertEqual(WearMath.points(budget: 0, using: &rng), 0)
        XCTAssertEqual(WearMath.points(budget: -1, using: &rng), 0)
        XCTAssertEqual(WearMath.points(budget: 0.5, fights: 0, using: &rng), 0)
        XCTAssertEqual(WearMath.points(budget: 0.5, fights: -3, using: &rng), 0)
    }

    /// ½ takes one point or none, and one in about half the fights.
    func testAHalfTakesAPointInHalfTheFights() {
        var rng = SplitMix64(seed: 3)
        var seen: Set<Int> = []
        var total = 0
        for _ in 0..<10_000 {
            let points = WearMath.points(budget: 0.5, using: &rng)
            seen.insert(points)
            total += points
        }
        XCTAssertEqual(seen, [0, 1])
        XCTAssertEqual(Double(total), 5_000, accuracy: 200)
    }

    /// 1.5 always takes the whole point and the half on top of it.
    func testTheWholePartAlwaysLands() {
        var rng = SplitMix64(seed: 4)
        var seen: Set<Int> = []
        for _ in 0..<1_000 { seen.insert(WearMath.points(budget: 1.5, using: &rng)) }
        XCTAssertEqual(seen, [1, 2])
    }

    /// A passive run that won once must sometimes take a point and sometimes
    /// not — `Int(0.5 × 1)` would never take one, rounding the product always.
    func testEachFightOfARunRollsOnItsOwn() {
        var rng = SplitMix64(seed: 5)
        var seen: Set<Int> = []
        for _ in 0..<200 { seen.insert(WearMath.points(budget: 0.5, fights: 1, using: &rng)) }
        XCTAssertEqual(seen, [0, 1])
        var spread: Set<Int> = []
        for _ in 0..<200 { spread.insert(WearMath.points(budget: 0.5, fights: 4, using: &rng)) }
        XCTAssertTrue(spread.isSuperset(of: [1, 2, 3]), "\(spread.sorted())")
        XCTAssertTrue(spread.isSubset(of: [0, 1, 2, 3, 4]), "\(spread.sorted())")
    }

    /// What the gear sheet prints («перемога — 1 очко з шансом 50%»): the
    /// points that always land and the chance of one more, the split `points`
    /// rolls.
    func testTheShapeASheetPrints() {
        XCTAssertTrue(WearMath.shape(of: 0.5) == (0, 50))
        XCTAssertTrue(WearMath.shape(of: 1) == (1, 0))
        XCTAssertTrue(WearMath.shape(of: 2) == (2, 0))
        XCTAssertTrue(WearMath.shape(of: 1.5) == (1, 50))
        XCTAssertTrue(WearMath.shape(of: 0.25) == (0, 25))
        XCTAssertTrue(WearMath.shape(of: 0) == (0, 0))
        XCTAssertTrue(WearMath.shape(of: -1) == (0, 0))
    }

    // MARK: - The owner's pick, as shipped

    /// «А. ½ / 1 / 2» (2026-10-24), over ½ / 2 / 3, 1 / 1 / 2 and a win that
    /// wears only when it cost 10% of HP.
    func testTheShippedBudgetIsTheOwnersPick() throws {
        let economy = try XCTUnwrap(ContentLoader.load(from: Self.contentRoot).tuning?.economy)
        XCTAssertEqual(economy.gear.wearBudget, WearBudgetDTO(victory: 0.5, defeat: 2, flee: 1))
    }
}
