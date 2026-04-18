//
//  AddProfileStyle.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 18.04.2026.
//

import Fluent

struct AddProfileStyle: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("users")
            .field("profile_style", .int, .required, .sql(.default(1)))
            .update()
    }

    func revert(on database: any Database) async throws {
        try await database.schema("users")
            .deleteField("profile_style")
            .update()
    }
}
