//
//  ResetDeepestKm.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 15.09.2026.
//
//  2026-09-15, on the user's call: `users.deepest_km = 0` for everyone, once.
//
//  Not a season and not a cleanup. The column started measuring something
//  else: until today it was raised on every step, so it recorded the deepest
//  km REACHED, fatal expeditions included, while the board it feeds has always
//  promised «і поверталися». From this migration on it is banked only at the
//  manor door, so the old values and the new ones are not the same quantity
//  and cannot share a ladder.
//
//  `total_km_walked` is deliberately NOT reset — its own board («Скільки
//  кілометрів лягло вам під ноги») was honest about a fatal walk all along,
//  and zeroing a counter that is still measuring what it always measured is
//  what `project-leaderboards-will-go-seasonal` forbids.
//
//  Irreversible: the pre-reset values are not stored anywhere, so `revert`
//  can only say so.
//

import Fluent
import SQLKit

struct ResetDeepestKm: AsyncMigration {
    enum ResetError: Error { case notSQL(driver: String) }

    func prepare(on database: any Database) async throws {
        // `throw`, not `return` — the opposite of `AddWalkCounters`' guard and
        // for `WipeForRebalance`'s reason: skipping an index costs a scan, but
        // skipping THIS records the migration as done while every old record
        // survives, and nothing would ever run it again.
        guard let sql = database as? any SQLDatabase else {
            throw ResetError.notSQL(driver: "\(type(of: database))")
        }
        try await sql.raw("UPDATE users SET deepest_km = 0").run()
        database.logger.info("ResetDeepestKm: depth board zeroed — the column now measures returns, not steps")
    }

    func revert(on database: any Database) async throws {
        // Nothing to restore — the old records were not kept.
    }
}
