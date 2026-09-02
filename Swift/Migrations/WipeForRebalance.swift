//
//  WipeForRebalance.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 02.09.2026.
//
//  Phase 11. The full wipe agreed at the start of the rebalance
//  (`.memory/rebalance.md`, locked decisions: "Existing players → full wipe at
//  release"), and the last thing standing between a live session and a
//  measurement worth trusting.
//
//  **Why a wipe rather than a backfill.** Most of the rebalance does heal
//  itself: `applyLevelDerivedStats` recomputes a stat line rather than
//  accumulating it, and gear stats resolve out of the catalog by `itemId +
//  tier`, so an old row picks up a new number for free. What does NOT heal is
//  everything that is a STORED QUANTITY on a curve that moved —
//
//    • XP totals sit on a different ladder (the cap went 21 → 40 and the climb
//      to it is 19,437,688 XP), so an old total is a number from another game;
//    • Vigor pools changed shape and stopped regenerating in Phase 8E;
//    • silver balances are inflated by a faucet that no longer exists, since
//      monsters dropped coin until Phase 8C deleted the mechanic.
//
//  A session run against those rows measures the hybrid, not the game.
//
//  **On a fresh database this migration does nothing**, because it runs in the
//  same batch as the `Create…` migrations that made the tables — which is also
//  why it must stay LAST in `configure.swift`'s list. It bites exactly once, on
//  a database that predates it.
//
//  **The table list is explicit, and that is the point.** Deleting `users` and
//  leaning on the FK cascades would look tidier and would be wrong:
//  `tavern_game_messages` stores a raw `telegram_id` and carries no foreign key
//  at all, so it would survive a cascade untouched. Rather than trust either the
//  list or the cascade, `prepare` asks the DATABASE what tables exist afterwards
//  and refuses to finish while any of them still holds a row — so a table added
//  later and forgotten here fails the boot instead of quietly surviving the
//  wipe. `TRUNCATE` takes them in one statement, which sidesteps FK ordering
//  between them entirely.
//
//  One thing the wipe deliberately loses: rows in `tavern_game_messages` are
//  the sweeper's only record of dice messages awaiting Telegram's 24 h delete
//  window, so any still pending stay in chat history forever. That is the right
//  trade — they are old rounds from a game that no longer exists.
//

import Fluent
import Foundation      // LocalizedError
import SQLKit

struct WipeForRebalance: AsyncMigration {

    /// Every table holding player state. `_fluent_migrations` is Fluent's own
    /// bookkeeping and is the one table that must survive: truncating it would
    /// make every migration look unapplied and replay the whole history.
    static let playerTables = [
        "users", "inventory", "warehouse",
        "exploration_state", "travel_state", "plots",
        "quest_progress", "arena_profiles",
        "learned_recipes", "learned_techniques",
        "market_listings",
        "guilds", "guild_invites", "guild_vault",
        "tavern_game_messages",
    ]

    /// Tables the wipe must not touch and must not judge.
    static let preserved: Set<String> = ["_fluent_migrations", "_fluent_migrations_lock"]

    enum WipeError: Error, CustomStringConvertible, LocalizedError {
        case notEmpty(table: String, rows: Int64)
        case notSQL(driver: String)

        var description: String {
            switch self {
            case .notEmpty(let table, let rows):
                return """
                WipeForRebalance: `\(table)` still holds \(rows) row(s) after the wipe. \
                It is not in `WipeForRebalance.playerTables` — add it there if it is \
                player state, or to `preserved` if it is not, and boot again.
                """
            case .notSQL(let driver):
                return """
                WipeForRebalance: `\(driver)` is not an SQL database, so the wipe cannot run. \
                Refusing rather than recording itself as applied — a wipe that silently does \
                nothing leaves pre-rebalance rows in place and the next session measures them.
                """
            }
        }

        // Both spellings, because which one a thrown migration error is printed
        // through depends on where it surfaces.
        var errorDescription: String? { description }
    }

    func prepare(on database: any Database) async throws {
        // NOT the `guard … else { return }` the other data migrations use. They
        // delete a retired item id, and skipping that on a non-SQL driver costs
        // a stale row; skipping THIS records the wipe as applied while every
        // pre-rebalance row survives, and nothing ever runs it again. The whole
        // file is built to refuse rather than to under-wipe quietly, and the
        // first line has to hold that too.
        guard let sql = database as? any SQLDatabase else {
            throw WipeError.notSQL(driver: "\(type(of: database))")
        }
        let logger = database.logger

        // Fluent records a migration only after `prepare` returns, and does not
        // wrap it in a transaction — so a throw below leaves the truncate
        // committed and the migration unrecorded. That is the recovery path, not
        // a hazard: the next boot re-runs it against empty tables, and it either
        // passes or fails on the same table for the same reason.

        // Counted BEFORE, because after the truncate there is nothing left to
        // count and a wipe with no record of what it removed is indistinguishable
        // from a wipe that never ran.
        var removed: [(String, Int64)] = []
        for table in Self.playerTables {
            let rows = try await count(of: table, on: sql)
            if rows > 0 { removed.append((table, rows)) }
        }

        // One statement, so FK order between the listed tables does not matter.
        // CASCADE is a safety net rather than the mechanism: every table it
        // could reach is already named above. `idents:` lets the DIALECT quote
        // the names — hand-written quotes are the kind of detail that works
        // until the day it does not.
        try await sql.raw("TRUNCATE TABLE \(idents: Self.playerTables, joinedBy: ", ") CASCADE").run()

        if removed.isEmpty {
            logger.info("WipeForRebalance: nothing to wipe — the database was already empty")
        } else {
            let summary = removed.map { "\($0.0) \($0.1)" }.joined(separator: ", ")
            logger.warning("WipeForRebalance: removed \(summary)")
        }

        // Ask the database rather than the list. This is the check that catches
        // a table added after this file was written: the list can go stale, the
        // schema cannot.
        for table in try await baseTables(on: sql) where !Self.preserved.contains(table) {
            let rows = try await count(of: table, on: sql)
            guard rows == 0 else { throw WipeError.notEmpty(table: table, rows: rows) }
        }
        logger.info("WipeForRebalance: verified empty — every table in the schema holds 0 rows")
    }

    func revert(on database: any Database) async throws {
        // No-op. Nothing here can be resurrected, and pretending otherwise
        // would make `migrator.revertLastBatch` look like an undo.
    }

    // MARK: - Helpers

    private func baseTables(on sql: any SQLDatabase) async throws -> [String] {
        let rows = try await sql.raw("""
            SELECT table_name FROM information_schema.tables
            WHERE table_schema = current_schema() AND table_type = 'BASE TABLE'
            """).all()
        return try rows.map { try $0.decode(column: "table_name", as: String.self) }
    }

    private func count(of table: String, on sql: any SQLDatabase) async throws -> Int64 {
        let row = try await sql.raw("SELECT count(*) AS n FROM \(ident: table)").first()
        return try row?.decode(column: "n", as: Int64.self) ?? 0
    }
}
