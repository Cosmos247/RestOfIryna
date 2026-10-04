//
//  ReseatDecreesById.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 04.10.2026.
//
//  2026-10-04, `spec-items.md` §9.5: the four weapon decrees moved to the level
//  their rung now opens at. «Гострий край» went from 4 to 5, «Гартована
//  сталь» from 8 to 10, «Ковані грані» from 11 to 15 and «Королівська криця»
//  from 14 to 20.
//
//  `KingProgress` stores a POSITION, and this reorder spans positions 10–37.
//  `RewalkReorderedDecrees` sent a window back to its start, which was safe
//  only because its window held nothing but live state reads. This one holds
//  events (cook, claim, harvest, send, craft, win a duel), and a re-walk would
//  make players do them again. So each row is re-seated BY DECREE
//  (`KingChainReseat.position`): the decrees before its old position are done,
//  and it moves to the first decree of the new order that is not.
//  - Measured on this reorder: nobody skips a decree, and no row moves back by
//    more than two places.
//  - At most two passed weapon decrees come up again. They are live state
//    reads, so they close at once when the (clamped) weapon still qualifies.
//
//  `oldOrder` is a fact about the chain as it stood before this commit, which
//  is why it is a literal. The new order is the chain loaded on this boot, so
//  boot the Pi with the new `king.json` first.
//
//  Verify the TABLE afterwards, not the log line. `SELECT decree_index,
//  count(*) FROM king_progress GROUP BY 1 ORDER BY 1` against the same query
//  run before the restart: rows at 11–15, 20–22, 27–30 and 33–37 sit one place
//  lower, rows at 31–32 two lower, and every other row where it was.
//

import Fluent
import Foundation
import SQLKit

struct ReseatDecreesById: AsyncMigration {
    enum ReseatError: Error { case notSQL(driver: String) }

    /// The chain as it stood before 2026-10-04, position by position.
    static let oldOrder = [
        "king.step_out", "king.first_blood", "king.present_yourself", "king.honest_scales",
        "king.work_will_be_found", "king.deeper_in", "king.catch_by_weight", "king.forest_feeds",
        "king.worthy_steward", "king.own_home", "king.sharp_edge", "king.fire_in_the_hearth",
        "king.first_ground", "king.harvest", "king.while_youre_away", "king.stone_and_iron",
        "king.full_storeroom", "king.strength_of_a_steward", "king.second_step", "king.tempered_steel",
        "king.more_on_the_shoulders", "king.hands_of_a_master", "king.maturity", "king.third_step",
        "king.science_of_battle", "king.first_technique", "king.forged_facets", "king.travelling_sack",
        "king.tempered_will", "king.fourth_step", "king.royal_steel", "king.stewards_train",
        "king.the_lists", "king.seasoned_steward", "king.fifth_step", "king.the_wildwood",
        "king.right_hand_of_the_crown", "king.sixth_step", "king.pillar_of_the_crown"
    ]

    private struct Row: Decodable {
        let id: UUID
        let decree_index: Int
    }

    func prepare(on database: any Database) async throws {
        // `throw`, not `return`, for `ResetDeepestKm`'s reason: skipping this
        // records it as done while the rows it exists for stay misplaced.
        guard let sql = database as? any SQLDatabase else {
            throw ReseatError.notSQL(driver: "\(type(of: database))")
        }
        let newOrder = KingCatalog.chain.map(\.id)
        let rows = try await sql.raw("SELECT id, decree_index FROM king_progress").all(decoding: Row.self)
        var moved = 0
        for row in rows {
            let seat = KingChainReseat.position(row.decree_index, oldOrder: Self.oldOrder, newOrder: newOrder)
            guard seat != row.decree_index else { continue }
            // The counter belongs to the decree it was counting for; on a
            // different decree it starts again, as `KingService` does on a
            // turn-in.
            let oldId = row.decree_index < Self.oldOrder.count ? Self.oldOrder[row.decree_index] : nil
            let newId = seat < newOrder.count ? newOrder[seat] : nil
            if oldId == newId {
                try await sql.raw("UPDATE king_progress SET decree_index = \(bind: seat) WHERE id = \(bind: row.id)").run()
            } else {
                try await sql.raw("UPDATE king_progress SET decree_index = \(bind: seat), counter = 0 WHERE id = \(bind: row.id)").run()
            }
            moved += 1
            let again = KingChainReseat.askedAgain(row.decree_index, oldOrder: Self.oldOrder, newOrder: newOrder)
            database.logger.info("ReseatDecreesById: \(row.decree_index) → \(seat)\(again.isEmpty ? "" : ", asked again: \(again.joined(separator: ", "))")")
        }
        database.logger.info("ReseatDecreesById: \(moved) of \(rows.count) player(s) re-seated")
    }

    func revert(on database: any Database) async throws {
        // Nothing to restore — the old positions are not kept, and the decrees
        // a re-seat asks again close on their own.
    }
}
