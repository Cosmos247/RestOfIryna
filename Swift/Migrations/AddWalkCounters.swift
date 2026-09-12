//
//  AddWalkCounters.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 12.09.2026.
//
//  Adds the two lifetime walking counters the leaderboards read:
//  `deepest_km` (the furthest km ever reached) and `total_km_walked`
//  (every km ever stepped, outward and homeward alike).
//
//  Nothing in the game stored either one before. A player's depth record lived
//  only in `exploration_state.steps_deep`, which is DELETED when the expedition
//  ends — so the record could never survive the walk that set it, and there is
//  nothing to backfill from. Both columns start at 0 for everyone, including
//  accounts that have already played: the boards begin measuring on the day
//  they ship.
//
//  The four indexes are insurance rather than need. At the few thousand rows
//  this game targets Postgres will sequential-scan a leaderboard query in a
//  fraction of a millisecond; they are here because adding an index to a busy
//  table later is a worse evening than adding it to an empty one now.
//

import Fluent
import SQLKit

struct AddWalkCounters: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("users")
            .field("deepest_km", .int, .sql(.default(0)))
            .field("total_km_walked", .int, .sql(.default(0)))
            .update()

        // Fluent's schema builder has no plain-index verb, so the four board
        // orderings go in as raw SQL — the same escape hatch RenameGoldToSilver
        // and WipeForRebalance use. IF NOT EXISTS so a re-run is harmless.
        //
        // `return`, not `throw` — the opposite of what WipeForRebalance does on
        // the same check, and deliberately: skipping a wipe records it as done
        // while every pre-rebalance row survives, whereas skipping an index
        // costs a sequential scan on a table with a few thousand rows. The
        // columns above are the part that matters, and they are already in.
        guard let sql = database as? any SQLDatabase else { return }
        try await sql.raw("CREATE INDEX IF NOT EXISTS idx_users_deepest_km ON users (deepest_km DESC)").run()
        try await sql.raw("CREATE INDEX IF NOT EXISTS idx_users_total_km ON users (total_km_walked DESC)").run()
        // Level and honor are ordered by a pair, so the index carries the
        // tiebreaker too — a single-column index would leave the sort to do the
        // second half anyway.
        try await sql.raw("CREATE INDEX IF NOT EXISTS idx_users_level_xp ON users (level DESC, xp DESC)").run()
        try await sql.raw("CREATE INDEX IF NOT EXISTS idx_arena_honor ON arena_profiles (honor DESC)").run()
    }

    func revert(on database: any Database) async throws {
        if let sql = database as? any SQLDatabase {
            try await sql.raw("DROP INDEX IF EXISTS idx_users_deepest_km").run()
            try await sql.raw("DROP INDEX IF EXISTS idx_users_total_km").run()
            try await sql.raw("DROP INDEX IF EXISTS idx_users_level_xp").run()
            try await sql.raw("DROP INDEX IF EXISTS idx_arena_honor").run()
        }
        try await database.schema("users")
            .deleteField("deepest_km")
            .deleteField("total_km_walked")
            .update()
    }
}
