//
//  RenameGoldToSilver.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 18.05.2026.
//
//  Phase 6.4 follow-up: the in-game currency is renamed from "gold" to
//  "silvers" (Ukrainian: срібники). The Swift identifier on `User` was
//  changed from `gold` to `silver`, and the `@Field(key:)` was bumped to
//  match — this migration brings the PostgreSQL column in sync with a
//  schema-level rename.
//
//  Uses raw SQL because Fluent's schema builder has no first-class rename
//  helper. Existing balances survive untouched (PostgreSQL keeps row data
//  through a RENAME COLUMN).
//

import Fluent
import SQLKit

struct RenameGoldToSilver: AsyncMigration {
    func prepare(on database: any Database) async throws {
        guard let sql = database as? any SQLDatabase else { return }
        try await sql.raw("ALTER TABLE users RENAME COLUMN gold TO silver").run()
    }

    func revert(on database: any Database) async throws {
        guard let sql = database as? any SQLDatabase else { return }
        try await sql.raw("ALTER TABLE users RENAME COLUMN silver TO gold").run()
    }
}
