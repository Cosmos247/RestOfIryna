//
//  AddGender.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 21.05.2026.
//
//  Adds `gender` (string, optional) to users. Chosen once during registration
//  (the gender step, ahead of the name prompt) and used to select Ukrainian
//  feminitive text variants and per-gender estate artwork. Nullable so existing
//  rows survive the migration; the gendered localize helper treats nil as male,
//  and a dev-reset / fresh registration fills it in.
//

import Fluent

struct AddGender: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("users")
            .field("gender", .string)
            .update()
    }

    func revert(on database: any Database) async throws {
        try await database.schema("users")
            .deleteField("gender")
            .update()
    }
}
