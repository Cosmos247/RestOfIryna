//
//  RewalkReorderedDecrees.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 27.09.2026.
//
//  2026-09-27, on the owner's call: the King's chain was reordered so it asks
//  for the estate before the Training Ground. Positions 22–25 (0-based) went
//  from «Наука бою», «Перший прийом», «Зрілість», «Третя сходинка» to
//  «Зрілість», «Третя сходинка», «Наука бою», «Перший прийом» — the ground
//  needs estate T4 and player level 10, which the old order asked for after it.
//
//  `KingProgress` stores a POSITION, not the decrees done, so anyone standing
//  inside that window when the new order lands would open a different decree
//  than the one they were on — and a player at 25 would skip «Третя сходинка»
//  and its 150 silver outright. This sends every row at 23…25 back to 22, the
//  start of the window: all four are live state reads, so what the player has
//  already done closes again at once. The cost is paying those again — at worst
//  60 + 45 Vigor, two portions of meat and three of stew — which is the right
//  way round: skipping a decree loses it for good, and nobody stood in the
//  window when this was written (read off the machine; the rows here were at
//  1, 3, 14, 14, 31 and 39). A row at 22 needs nothing: nothing inside the
//  window is behind it.
//
//  The indexes are facts about the chain as it stood before this commit, which
//  is why they are literals. Verify the TABLE afterwards, not the log line:
//  `SELECT count(*) FROM king_progress WHERE decree_index BETWEEN 23 AND 25`
//  reads 0 right after the restart.
//
//  It is only right on the boot that also loads the reordered `king.json`, so
//  boot it on the Pi first: the Mac reaches the same database through the
//  tunnel, and a Mac run would spend this migration while the Pi still walks
//  the old order.
//

import Fluent
import SQLKit

struct RewalkReorderedDecrees: AsyncMigration {
    enum RewalkError: Error { case notSQL(driver: String) }

    func prepare(on database: any Database) async throws {
        // `throw`, not `return`, for `ResetDeepestKm`'s reason: skipping this
        // records it as done while the rows it exists for stay misplaced.
        guard let sql = database as? any SQLDatabase else {
            throw RewalkError.notSQL(driver: "\(type(of: database))")
        }
        let moved = try await sql.raw("""
            UPDATE king_progress SET decree_index = 22, counter = 0
            WHERE decree_index BETWEEN 23 AND 25
            RETURNING id
            """).all()
        database.logger.info("RewalkReorderedDecrees: \(moved.count) player(s) sent back to the start of the reordered window")
    }

    func revert(on database: any Database) async throws {
        // Nothing to restore — where each moved row stood is not kept, and the
        // decrees it re-opens close again on their own.
    }
}
