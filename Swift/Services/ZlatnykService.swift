//
//  ZlatnykService.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 11.10.2026.
//
//  The premium currency's balance, `users.zlatnyks` — read here, and never
//  through `User`.
//
//  The owner credits zlatnyks by hand, editing the cell in DBeaver (2026-10-11).
//  A field on `User` would ride in the session cache: the dispatcher keeps a
//  playing player's row in memory and re-reads it only after five idle minutes.
//  The player would not see the credit, and the first spend, computed from the
//  cached number, would write it back over the owner's. Read here, from the
//  database on every screen, the balance cannot go stale.
//
//  A spend is ONE statement that takes from both columns (`spend`) — never a
//  read followed by a write. The marker moves too because the watchman
//  announces `zlatnyks − zlatnyks_announced`: a spend that left it behind would
//  swallow the next credit's notice.
//

import Fluent
import Foundation
import SQLKit

public enum ZlatnykService {

    /// What the database holds now — 0 for a missing row or a non-SQL driver.
    public static func balance(of userId: UUID, on db: any Database) async throws -> Int {
        guard let sql = db as? any SQLDatabase else { return 0 }
        let row = try await sql.raw("SELECT zlatnyks FROM users WHERE id = \(bind: userId)").first()
        return try row?.decode(column: "zlatnyks", as: Int.self) ?? 0
    }

    /// Takes `amount` in ONE statement, from both columns (see the header), and
    /// only when the balance covers it. Returns the balance left, or nil when
    /// it did not — and then nothing was taken. Run it inside the transaction
    /// of whatever the zlatnyks buy, so a failed purchase gives them back.
    public static func spend(_ amount: Int, from userId: UUID, on db: any Database) async throws -> Int? {
        guard amount > 0, let sql = db as? any SQLDatabase else { return nil }
        let row = try await sql.raw("""
            UPDATE users SET zlatnyks = zlatnyks - \(bind: amount),
                             zlatnyks_announced = zlatnyks_announced - \(bind: amount)
            WHERE id = \(bind: userId) AND zlatnyks >= \(bind: amount)
            RETURNING zlatnyks
            """).first()
        return try row?.decode(column: "zlatnyks", as: Int.self)
    }

    /// A balance that moved since the player was last told about it.
    public struct Change: Sendable {
        public let userId: UUID
        public let telegramId: Int64
        public let locale: String
        public let balance: Int
        public let announced: Int

        /// Positive for a credit the player has not heard about; negative for
        /// a correction downward, which is not news.
        public var credited: Int { balance - announced }
    }

    /// Every player whose balance and marker disagree. Usually no rows at all:
    /// it changes only when the owner edits a balance.
    ///
    /// An account still in registration is left for later, as the watchman's
    /// other notices leave it: its marker stays, so the credit is announced
    /// once the account is through.
    public static func unannounced(on db: any Database) async throws -> [Change] {
        guard let sql = db as? any SQLDatabase else { return [] }
        let rows = try await sql.raw("""
            SELECT id, telegram_id, locale, zlatnyks, zlatnyks_announced FROM users
            WHERE zlatnyks <> zlatnyks_announced
              AND router_name <> \(bind: Controllers.registration.routerName)
            """).all()
        return try rows.map { row in
            Change(
                userId: try row.decode(column: "id", as: UUID.self),
                telegramId: try row.decode(column: "telegram_id", as: Int64.self),
                locale: try row.decode(column: "locale", as: String.self),
                balance: try row.decode(column: "zlatnyks", as: Int.self),
                announced: try row.decode(column: "zlatnyks_announced", as: Int.self)
            )
        }
    }

    /// Records a change as told. The marker moves BY the difference that was
    /// read, not TO the balance: a credit that lands between the read and this
    /// write is still owed afterwards, and a spend there, which moves both
    /// columns, changes nothing.
    public static func markAnnounced(_ change: Change, on db: any Database) async throws {
        guard let sql = db as? any SQLDatabase else { return }
        try await sql.raw("""
            UPDATE users SET zlatnyks_announced = zlatnyks_announced + \(bind: change.credited)
            WHERE id = \(bind: change.userId)
            """).run()
    }
}
