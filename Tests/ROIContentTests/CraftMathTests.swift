//
//  CraftMathTests.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 04.11.2026.
//
//  The kitchen's batches (2026-11-04, the owner's pick: «🍳 ×5» and «🍳 Усі
//  (N)», no ×10), pinned on the sample they were shown: a baked potato — one
//  🥔 and one 🪵 — with seven potatoes and twelve beams in hand. And the single
//  craft, which is a batch of one and must keep the rule it always had.
//

import XCTest
@testable import ROISim

final class CraftMathTests: XCTestCase {

    /// A roomy bag (25 of 40) and an empty warehouse.
    private let roomy = CraftMath.Room(bagUsed: 25, bagCap: 40, bagUnbounded: false,
                                       warehouseUsed: 0, warehouseCap: 100)

    private func potato(_ potatoes: (bag: Int, warehouse: Int),
                        _ beams: (bag: Int, warehouse: Int)) -> [CraftMath.Input] {
        [CraftMath.Input(need: 1, bag: potatoes.bag, warehouse: potatoes.warehouse),
         CraftMath.Input(need: 1, bag: beams.bag, warehouse: beams.warehouse)]
    }

    private func plan(_ times: Int, _ inputs: [CraftMath.Input], _ room: CraftMath.Room) -> CraftMath.Plan? {
        if case .success(let plan) = CraftMath.plan(times: times, inputs: inputs, outputQuantity: 1, room: room) {
            return plan
        }
        return nil
    }

    // MARK: - The buttons

    /// The sample: seven fit, so the card offers «×5» and «Усі (7)».
    func testTheSampleOffersFiveAndAll() {
        let inputs = potato((7, 0), (12, 0))
        XCTAssertEqual(CraftMath.limit(inputs: inputs, outputQuantity: 1, room: roomy), 7)
        XCTAssertEqual(CraftMath.offer(inputs: inputs, outputQuantity: 1, room: roomy),
                       CraftMath.Offer(preset: 5, all: 7))
    }

    /// The scarcest input sets the count — here the beams, which every dish needs.
    func testTheScarcestInputBinds() {
        let inputs = potato((10, 0), (3, 0))
        XCTAssertEqual(CraftMath.offer(inputs: inputs, outputQuantity: 1, room: roomy),
                       CraftMath.Offer(preset: nil, all: 3))
    }

    /// Exactly five: «×5» would do what «Усі (5)» does, so only «Усі» is offered.
    func testFiveIsNeverOfferedTwice() {
        XCTAssertEqual(CraftMath.offer(inputs: potato((5, 0), (9, 0)), outputQuantity: 1, room: roomy),
                       CraftMath.Offer(preset: nil, all: 5))
    }

    /// One dish is the plain «🍳 Готувати»; none is nothing at all.
    func testOneOrNoneOffersNoBatch() {
        XCTAssertEqual(CraftMath.offer(inputs: potato((1, 0), (9, 0)), outputQuantity: 1, room: roomy), .none)
        XCTAssertEqual(CraftMath.offer(inputs: potato((0, 0), (9, 0)), outputQuantity: 1, room: roomy), .none)
        XCTAssertEqual(CraftMath.limit(inputs: potato((0, 0), (9, 0)), outputQuantity: 1, room: roomy), 0)
    }

    /// The Governor's Feast: three meat, three potatoes, two eggs, two berries,
    /// two nuts and a beam — the eggs run out first.
    func testAManyInputDishCountsEveryInput() {
        let feast = [CraftMath.Input(need: 3, bag: 9, warehouse: 4),   // meat: 4
                     CraftMath.Input(need: 3, bag: 12, warehouse: 0),  // potatoes: 4
                     CraftMath.Input(need: 2, bag: 5, warehouse: 0),   // eggs: 2
                     CraftMath.Input(need: 2, bag: 8, warehouse: 0),   // berries: 4
                     CraftMath.Input(need: 2, bag: 6, warehouse: 4),   // nuts: 5
                     CraftMath.Input(need: 1, bag: 7, warehouse: 0)]   // beams: 7
        XCTAssertEqual(CraftMath.offer(inputs: feast, outputQuantity: 1, room: roomy),
                       CraftMath.Offer(preset: nil, all: 2))
    }

    // MARK: - Where it comes from

    /// Every input is drawn from the bag first and the warehouse for the rest.
    func testTheBagIsDrawnFirst() {
        let made = plan(7, potato((4, 3), (7, 5)), roomy)
        XCTAssertEqual(made?.fromBag, [4, 7])
        XCTAssertEqual(made?.fromWarehouse, [3, 0])
    }

    /// A batch short of one input names it, and nothing is planned.
    func testAShortBatchNamesTheInput() {
        XCTAssertEqual(CraftMath.plan(times: 5, inputs: potato((4, 0), (10, 0)), outputQuantity: 1, room: roomy),
                       .failure(.short([0])))
    }

    // MARK: - Where it goes

    /// One dish keeps the rule it had: a full bag that the drain frees takes it…
    func testOneDishGoesToTheBagTheDrainFreed() {
        let full = CraftMath.Room(bagUsed: 25, bagCap: 25, bagUnbounded: false, warehouseUsed: 0, warehouseCap: 20)
        let made = plan(1, potato((1, 0), (1, 0)), full)
        XCTAssertEqual(made?.toBag, 1)
        XCTAssertEqual(made?.toWarehouse, 0)
    }

    /// …a full bag the inputs never touched sends it to the warehouse…
    func testOneDishGoesToTheWarehouseWhenTheBagStaysFull() {
        let full = CraftMath.Room(bagUsed: 25, bagCap: 25, bagUnbounded: false, warehouseUsed: 10, warehouseCap: 20)
        let made = plan(1, potato((0, 1), (0, 1)), full)
        XCTAssertEqual(made?.toBag, 0)
        XCTAssertEqual(made?.toWarehouse, 1)
    }

    /// …and two stores past their ceilings (a tier that shrank under them) refuse it.
    func testNoRoomWhenNeitherStoreCanTakeIt() {
        let over = CraftMath.Room(bagUsed: 30, bagCap: 25, bagUnbounded: false, warehouseUsed: 22, warehouseCap: 20)
        XCTAssertEqual(CraftMath.plan(times: 1, inputs: potato((0, 1), (0, 1)), outputQuantity: 1, room: over),
                       .failure(.noRoom))
    }

    /// A batch fills the bag and puts the rest on the warehouse, whole dishes each.
    func testABatchSplitsWhenTheBagFills() {
        let tight = CraftMath.Room(bagUsed: 24, bagCap: 25, bagUnbounded: false, warehouseUsed: 14, warehouseCap: 100)
        let made = plan(7, potato((0, 7), (0, 7)), tight)
        XCTAssertEqual(made?.toBag, 1)
        XCTAssertEqual(made?.toWarehouse, 6)
    }

    /// A developer's bag has no ceiling, as `InventoryEntry.add` has none.
    func testADevelopersBagTakesTheWholeBatch() {
        let dev = CraftMath.Room(bagUsed: 90, bagCap: 25, bagUnbounded: true, warehouseUsed: 0, warehouseCap: 0)
        let made = plan(7, potato((0, 7), (0, 7)), dev)
        XCTAssertEqual(made?.toBag, 7)
        XCTAssertEqual(made?.toWarehouse, 0)
    }

    /// Over-full stores are helped by every input a batch drains, so seven can
    /// fit where five do not: «×5» is planned on its own, never assumed.
    func testFiveIsPlannedNotAssumed() {
        let over = CraftMath.Room(bagUsed: 30, bagCap: 25, bagUnbounded: false, warehouseUsed: 26, warehouseCap: 20)
        let inputs = potato((0, 7), (0, 7))
        XCTAssertNotNil(plan(7, inputs, over))
        XCTAssertNil(plan(5, inputs, over))
        XCTAssertEqual(CraftMath.offer(inputs: inputs, outputQuantity: 1, room: over),
                       CraftMath.Offer(preset: nil, all: 7))
    }
}
