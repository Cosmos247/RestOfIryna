//
//  PassiveRouteTests.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 12.10.2026.
//
//  The governor's walk (`PassiveRoute`), as the owner chose it on 2026-10-12:
//  there and back in the same time on a 3-minute stride, turning below half
//  his HP or when his Vigor only covers the road home, eating only when he
//  must, the smallest portion first and what a taken job waits for last. The
//  foods are the shipped ones: 🥚 3, 🫐 4, 🌰 5, the pancakes 16 Vigor + 4 HP.
//

import XCTest
@testable import ROISim

final class PassiveRouteTests: XCTestCase {

    private let egg = PassiveRoute.Ration(itemId: "food.duck_egg", vigor: 3, hp: 0, wanted: false)
    private let berries = PassiveRoute.Ration(itemId: "food.forest_berries", vigor: 4, hp: 0, wanted: false)
    private let nuts = PassiveRoute.Ration(itemId: "food.forest_nuts", vigor: 5, hp: 0, wanted: false)
    private let pancakes = PassiveRoute.Ration(itemId: "food.potato_pancakes", vigor: 16, hp: 4, wanted: false)

    // MARK: - The route

    func testThreeMinuteStridesSplitTheThreeChoicesEvenly() {
        let strides = [30, 60, 90].map { PassiveRoute.strides(minutes: $0, unitsPerStep: 3) }
        XCTAssertEqual(strides, [10, 20, 30])
        XCTAssertEqual(strides.map(PassiveRoute.depth(strides:)), [5, 10, 15])
    }

    /// The 2026-10-11 off-by-one: 90 minutes at 5 a stride is 18 strides, and
    /// the run used to make 17 of them out of two timestamps.
    func testStridesComeFromTheAuthoredMinutes() {
        XCTAssertEqual(PassiveRoute.strides(minutes: 90, unitsPerStep: 5), 18)
        XCTAssertEqual(PassiveRoute.strides(minutes: 90, unitsPerStep: 0), 0)
    }

    /// Out to the depth, home through `depth − 1` kilometres, then the door:
    /// exactly the strides the run bought, so it lands when it said it would.
    func testThereAndBackFillsTheRun() {
        for strides in [10, 20, 30] {
            let depth = PassiveRoute.depth(strides: strides)
            XCTAssertEqual(depth + PassiveRoute.stridesHome(fromKm: depth), strides)
        }
        XCTAssertEqual(PassiveRoute.stridesHome(fromKm: 1), 1, "from km 1 the next stride is the door")
    }

    // MARK: - When he turns

    func testOnlyTheRoadHomeLeftTurnsHim() {
        XCTAssertTrue(PassiveRoute.onlyRoadHomeLeft(vigor: 20, km: 10, walkCost: 2))
        XCTAssertFalse(PassiveRoute.onlyRoadHomeLeft(vigor: 21, km: 10, walkCost: 2))
    }

    /// DIABLO's real line: 147 max HP turns below 73.5 — at 73, not at 74.
    func testWoundsBelowTheShareTurnHim() {
        XCTAssertTrue(PassiveRoute.woundedEnough(hp: 73, maxHP: 147, share: 0.5))
        XCTAssertFalse(PassiveRoute.woundedEnough(hp: 74, maxHP: 147, share: 0.5))
    }

    // MARK: - When and what he eats

    /// A step costs 2: at 2 he would end it at 0 and fight at the starvation
    /// penalty, so he eats first; at 3 he walks on.
    func testHeEatsBeforeAStepThatWouldLeaveHimAtZero() {
        XCTAssertTrue(PassiveRoute.mustEatBeforeStep(vigor: 2, walkCost: 2))
        XCTAssertTrue(PassiveRoute.mustEatBeforeStep(vigor: 0, walkCost: 2))
        XCTAssertFalse(PassiveRoute.mustEatBeforeStep(vigor: 3, walkCost: 2))
    }

    func testTheSmallestPortionGoesFirst() {
        XCTAssertEqual(PassiveRoute.nextRation([pancakes, nuts, berries, egg]), egg)
        XCTAssertEqual(PassiveRoute.nextRation([pancakes, nuts]), nuts)
    }

    /// Berries a taken job waits for are eaten after everything else, the
    /// pancakes included — and still eaten when nothing else is left, since
    /// the owner's rule is that he eats any food before he turns.
    func testWhatATakenJobWaitsForGoesLast() {
        let wanted = PassiveRoute.Ration(itemId: berries.itemId, vigor: 4, hp: 0, wanted: true)
        XCTAssertEqual(PassiveRoute.nextRation([wanted, nuts]), nuts)
        XCTAssertEqual(PassiveRoute.nextRation([wanted, pancakes]), pancakes)
        XCTAssertEqual(PassiveRoute.nextRation([wanted]), wanted)
    }

    /// Equal Vigor: the one that heals less goes first, then the id — so the
    /// choice never depends on the order the bag was read in.
    func testTiesBreakOnHealingThenTheId() {
        let potato = PassiveRoute.Ration(itemId: "food.baked_potato", vigor: 10, hp: 0, wanted: false)
        let omelette = PassiveRoute.Ration(itemId: "food.foragers_omelette", vigor: 10, hp: 0, wanted: false)
        let healing = PassiveRoute.Ration(itemId: "food.a_healing_dish", vigor: 10, hp: 3, wanted: false)
        XCTAssertEqual(PassiveRoute.nextRation([omelette, potato]), potato)
        XCTAssertEqual(PassiveRoute.nextRation([potato, omelette]), potato)
        XCTAssertEqual(PassiveRoute.nextRation([healing, omelette]), omelette)
    }

    /// A potion heals but feeds nobody, and an empty bag has no ration.
    func testNothingThatRestoresNoVigorIsARation() {
        let potion = PassiveRoute.Ration(itemId: "potion.heal_small", vigor: 0, hp: 30, wanted: false)
        XCTAssertNil(PassiveRoute.nextRation([potion]))
        XCTAssertNil(PassiveRoute.nextRation([]))
    }
}
