//
//  PlantHazel.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 01.11.2026.
//
//  2026-11-01, `spec-progression.md` §8: every estate starts with the hazel — a
//  plot of nuts in slot 1 that the player never chooses. An estate named from
//  now on is planted there and then (`PlotService.plantGranted`); this plants
//  every estate that existed before.
//
//  Slot 1 belongs to a built plot on most of them, so every plot moves down one
//  first: a farm in «Ділянка 1» reads «Ділянка 2» (the screens said «Слот» until
//  2026-11-04). The content's `plotSlotsByTier`
//  gained the same one slot at every tier (1…7), so no estate loses a slot it
//  builds on. Two statements, because `unique(user_id, slot_index)` is checked
//  row by row as a row moves and a plain `+ 1` collides with the neighbour that
//  has not moved yet: up by 1000, then down by 999.
//
//  Then every account past registration gets a ripe hazel in slot index 0: its
//  harvest clock one full fill back (`PlotCatalog.secondsToFill`, read from the
//  content this boot loaded), `notified_full` set so the gift sends no push —
//  the same row `plantGranted` writes. An account still registering is planted
//  when it finishes.
//
//  One transaction, because neither step is idempotent: Fluent records a
//  migration only after `prepare` returns and wraps nothing in a transaction,
//  so a throw between the steps would leave every plot moved, the migration
//  unrecorded — and the next boot would move them again.
//
//  Verify the TABLE, not the log line, before the restart and after it:
//  `SELECT slot_index, plot_type, count(*) FROM plots GROUP BY 1, 2 ORDER BY 1, 2`
//  — before, no `hazel` and slot 0 holding first plots; after, slot 0 is
//  `hazel` alone, one per account past registration
//  (`SELECT count(*) FROM users WHERE registration_step >= 7`), and every
//  built plot one slot higher than it was.
//

import Fluent
import Foundation
import SQLKit

struct PlantHazel: AsyncMigration {
    enum PlantError: Error { case notSQL(driver: String) }

    private struct Row: Decodable { let id: UUID }

    func prepare(on database: any Database) async throws {
        let ripeSince = Date().addingTimeInterval(-(PlotCatalog.secondsToFill(.hazel) ?? 0))
        try await database.transaction { tx in
            // `throw`, not `return`, for `ResetDeepestKm`'s reason: skipping this
            // records it as done while the estates it exists for stay unplanted.
            guard let sql = tx as? any SQLDatabase else {
                throw PlantError.notSQL(driver: "\(type(of: tx))")
            }
            let moved = try await sql.raw("UPDATE plots SET slot_index = slot_index + 1000 RETURNING id")
                .all(decoding: Row.self)
            try await sql.raw("UPDATE plots SET slot_index = slot_index - 999").run()

            // The ids alone, never `User` models: decoding a whole account trips on
            // any column the model holds non-optional and an old row left NULL,
            // and a migration that throws stops the boot. Found in the rehearsal
            // (2026-11-01) on a row with no `locale`.
            let accounts = try await sql.raw("""
                SELECT id FROM users WHERE registration_step >= \(bind: User.registrationDoneStep)
                """).all(decoding: Row.self)
            for account in accounts {
                let hazel = Plot(userID: account.id, slotIndex: GrantedPlot.slotIndex,
                                 plotType: PlotType.hazel.rawValue, tier: 1, lastHarvestedAt: ripeSince)
                hazel.notifiedFull = true
                try await hazel.create(on: tx)
            }
            tx.logger.info("PlantHazel: \(moved.count) plot(s) moved down a slot, \(accounts.count) hazel(s) planted")
        }
    }

    /// Takes the hazels out and moves every plot back up a slot — for a
    /// rollback to a binary that cannot read the hazel's rows at all (it would
    /// draw slot 1 as free and refuse to build on it).
    func revert(on database: any Database) async throws {
        try await database.transaction { tx in
            guard let sql = tx as? any SQLDatabase else {
                throw PlantError.notSQL(driver: "\(type(of: tx))")
            }
            try await sql.raw("DELETE FROM plots WHERE plot_type = \(bind: PlotType.hazel.rawValue)").run()
            try await sql.raw("UPDATE plots SET slot_index = slot_index + 999").run()
            try await sql.raw("UPDATE plots SET slot_index = slot_index - 1000").run()
        }
    }
}
