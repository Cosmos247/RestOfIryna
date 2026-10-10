//
//  FortuneStageTests.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 10.10.2026.
//
//  The fortune teller's dispel and second card (2026-10-10): the dispel takes
//  only the free card's running effect, the second card follows only a dispel,
//  and the chain ends there — no dispel on the second card, so no third. The
//  shipped prices are the owner's numbers and pinned here.
//

import XCTest
@testable import ROIContent

final class FortuneStageTests: XCTestCase {

    /// The repository's own content directory, found from this file.
    private static let contentRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("content/data")

    /// Every combination: only `free` + a duration card + still running sells.
    func testOnlyTheFreeCardsRunningEffectCanBeDispelled() {
        for stage in FortuneStage.allCases {
            for hasDuration in [false, true] {
                for running in [false, true] {
                    let expected = stage == .free && hasDuration && running
                    XCTAssertEqual(stage.mayDispel(cardHasDurationEffect: hasDuration, effectRunning: running),
                                   expected, "\(stage) duration:\(hasDuration) running:\(running)")
                }
            }
        }
    }

    /// The second card is the replacement for a dispelled one — never after a
    /// card that ran out or a one-shot (both stay `free`), and not once the
    /// free card is ready again.
    func testTheSecondCardFollowsOnlyADispel() {
        for stage in FortuneStage.allCases {
            for ready in [false, true] {
                XCTAssertEqual(stage.mayDrawSecond(freeCardReady: ready), stage == .dispelled && !ready,
                               "\(stage) freeCardReady:\(ready)")
            }
        }
    }

    /// Walked in order: once the second card is drawn nothing more is on offer
    /// — it cannot be dispelled, so there is no road to a third card.
    func testTheChainEndsAtTheSecondCard() {
        XCTAssertTrue(FortuneStage.free.mayDispel(cardHasDurationEffect: true, effectRunning: true))
        XCTAssertFalse(FortuneStage.free.mayDrawSecond(freeCardReady: false))

        XCTAssertFalse(FortuneStage.dispelled.mayDispel(cardHasDurationEffect: true, effectRunning: true))
        XCTAssertTrue(FortuneStage.dispelled.mayDrawSecond(freeCardReady: false))

        XCTAssertFalse(FortuneStage.second.mayDispel(cardHasDurationEffect: true, effectRunning: true))
        XCTAssertFalse(FortuneStage.second.mayDrawSecond(freeCardReady: false))
    }

    /// The raw values are what `users.fortune_stage` stores — renaming a case
    /// would strand every row written under the old name.
    func testStoredNamesAreStable() {
        XCTAssertEqual(FortuneStage.allCases.map(\.rawValue), ["free", "dispelled", "second"])
    }

    /// The owner's prices: a draw 10, a dispel 30, the second card 20.
    func testShippedPrices() throws {
        let fortune = try XCTUnwrap(ContentLoader.load(from: Self.contentRoot).fortune)
        XCTAssertEqual(fortune.drawPrice, 10)
        XCTAssertEqual(fortune.dispelPrice, 30)
        XCTAssertEqual(fortune.secondDrawPrice, 20)
    }
}
