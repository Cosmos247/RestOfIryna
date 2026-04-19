//
//  RemoveCrownsField.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 19.04.2026.
//
//  Drops the `crowns` column from `users`. The concept of a premium currency
//  is on hold until a name is chosen — at that point a new AddX migration
//  will introduce the replacement field.
//

import Fluent

struct RemoveCrownsField: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("users")
            .deleteField("crowns")
            .update()
    }

    func revert(on database: any Database) async throws {
        try await database.schema("users")
            .field("crowns", .int, .required, .sql(.default(0)))
            .update()
    }
}
