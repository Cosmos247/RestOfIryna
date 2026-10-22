//
//  DeathWipeTests.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 22.10.2026.
//
//  What a death takes from the bag, and what the forest edge's «🛡 Одягнути»
//  puts on before it can (2026-10-22): the worn and the bound weapon stay,
//  everything else goes; the button fills EMPTY slots only, each with the piece
//  that grants the most right now, and never swaps a spare in.
//

import XCTest
@testable import ROIContent

final class DeathWipeTests: XCTestCase {

    private func piece(_ id: String, _ slot: EquipmentSlot, broken: Bool = false, enchant: Int = 0,
                       durability: Int = 50, max: Int = 50) -> DeathWipe.Piece {
        DeathWipe.Piece(id: id, slot: slot, isBroken: broken, enchantLevel: enchant,
                        durability: durability, maxDurability: max)
    }

    /// Every combination: only a row that is neither worn nor the bound
    /// weapon goes.
    func testADeathTakesOnlyWhatIsNeitherWornNorTheBoundWeapon() {
        for worn in [false, true] {
            for bound in [false, true] {
                XCTAssertEqual(DeathWipe.takes(isWorn: worn, isBoundWeapon: bound), !worn && !bound,
                               "worn:\(worn) bound:\(bound)")
            }
        }
    }

    /// The new player's case: boots bought from the Master, the hood already
    /// on — the boots go on, and the plan is the whole answer.
    func testAPieceForAnEmptySlotGoesOn() {
        let boots = piece("b", .boots)
        XCTAssertEqual(DeathWipe.wearPlan([boots], wornSlots: [.helmet]), [boots])
    }

    /// A spare is named and left: a swap would only put the other piece in the
    /// bag, where the same death takes it. Even a broken piece worn in the slot
    /// is not swapped for a whole one — the owner's pick was the list, nothing
    /// more.
    func testASlotAlreadyWornIsLeftAlone() {
        let spare = piece("j", .chest, enchant: 4)
        XCTAssertEqual(DeathWipe.wearPlan([spare], wornSlots: [.chest]), [])
        XCTAssertEqual(DeathWipe.wearPlan([piece("h", .helmet)], wornSlots: [.helmet]), [])
    }

    /// Two copies for one empty slot: one goes on — whole before broken, then
    /// the higher enchant, then the more wear left.
    func testOfTwoCopiesThePieceThatGrantsMoreGoesOn() {
        let broken = piece("a", .legs, broken: true, enchant: 3, durability: 0, max: 49)
        let whole = piece("b", .legs, durability: 12, max: 49)
        XCTAssertEqual(DeathWipe.wearPlan([broken, whole], wornSlots: []), [whole])

        let plain = piece("c", .legs, durability: 50)
        let enchanted = piece("d", .legs, enchant: 1, durability: 20)
        XCTAssertEqual(DeathWipe.wearPlan([plain, enchanted], wornSlots: []), [enchanted])

        let worn = piece("e", .legs, durability: 10)
        let fresh = piece("f", .legs, durability: 45)
        XCTAssertEqual(DeathWipe.wearPlan([worn, fresh], wornSlots: []), [fresh])
    }

    /// The plan does not depend on the order the rows came back in.
    func testThePlanIsTheSameWhateverTheRowOrder() {
        let pieces = [piece("1", .boots), piece("2", .helmet, enchant: 2), piece("3", .helmet),
                      piece("4", .chest, broken: true, durability: 0), piece("5", .chest, durability: 3)]
        let expected = DeathWipe.wearPlan(pieces, wornSlots: [.legs])
        XCTAssertEqual(DeathWipe.wearPlan(pieces.reversed(), wornSlots: [.legs]), expected)
        XCTAssertEqual(expected.map(\.id), ["2", "5", "1"], "one per empty slot, head to toe")
    }

    /// The edge lists head to toe, and within a slot the piece the button
    /// would put on comes first.
    func testTheListingRunsHeadToToeBestFirst() {
        let pieces = [piece("boots", .boots), piece("old", .helmet, durability: 5),
                      piece("new", .helmet, durability: 50), piece("jerkin", .chest)]
        XCTAssertEqual(DeathWipe.ranked(pieces).map(\.id), ["new", "old", "jerkin", "boots"])
    }
}
