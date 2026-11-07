//
//  AddSleepWard.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 07.11.2026.
//
//  Adds `users.sleep_ward` — Сонна настоянка is working: the next death leaves
//  the bag. One column with a default and no row rewritten: nobody has drunk
//  one yet, so `false` is the truth for every live row.
//

import Fluent

struct AddSleepWard: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("users")
            .field("sleep_ward", .bool, .required, .sql(.default(false)))
            .update()
    }

    func revert(on database: any Database) async throws {
        try await database.schema("users")
            .deleteField("sleep_ward")
            .update()
    }
}
