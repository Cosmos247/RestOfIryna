//
//  AddCapitalStreet.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 20.09.2026.
//
//  The capital's places were split across two streets — Castle Street above
//  and the Lower Town under the wall — to get the reply keyboard back down
//  from six rows. This column holds which street's keyboard the player is
//  looking at; nil is the square. Nullable on purpose: every existing player
//  starts on the square, which is exactly what they had before.
//

import Fluent

struct AddCapitalStreet: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("users")
            .field("capital_street", .string)
            .update()
    }

    func revert(on database: any Database) async throws {
        try await database.schema("users")
            .deleteField("capital_street")
            .update()
    }
}
