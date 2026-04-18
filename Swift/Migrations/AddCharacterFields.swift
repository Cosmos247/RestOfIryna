//
//  AddCharacterFields.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 18.04.2026.
//

import Fluent

struct AddCharacterFields: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("users")
            .field("nickname", .string)
            .field("character_class", .string)
            .field("estate_name", .string)
            .field("registration_step", .int, .required, .sql(.default(0)))
            .update()
    }

    func revert(on database: any Database) async throws {
        try await database.schema("users")
            .deleteField("nickname")
            .deleteField("character_class")
            .deleteField("estate_name")
            .deleteField("registration_step")
            .update()
    }
}
