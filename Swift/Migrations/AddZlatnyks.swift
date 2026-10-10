//
//  AddZlatnyks.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 11.10.2026.
//
//  Adds the premium currency, the zlatnyk («златник»), as two columns on
//  `users`:
//  - `zlatnyks` — the balance. The owner credits it by hand in DBeaver, so it
//    is deliberately NOT a field of `User` (`ZlatnykService` says why). The
//    CHECK makes a typed minus a refused edit rather than a negative purse.
//  - `zlatnyks_announced` — the balance the player has been told about. The
//    watchman announces the difference once (`RestNotificationService`).
//
//  Both start at 0 on every row, so the first sweep has nothing to announce.
//  Fluent writes the two columns and the CHECK as ONE `ALTER TABLE`, so there
//  is no half-applied state for a second boot to trip over.
//

import Fluent
import SQLKit

struct AddZlatnyks: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("users")
            .field("zlatnyks", .int, .required, .sql(.default(0)),
                   .sql(.check(SQLRaw("zlatnyks >= 0"))))
            .field("zlatnyks_announced", .int, .required, .sql(.default(0)))
            .update()
    }

    func revert(on database: any Database) async throws {
        try await database.schema("users")
            .deleteField("zlatnyks")
            .deleteField("zlatnyks_announced")
            .update()
    }
}
