//
//  AddEstateLevel.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 11.05.2026.
//
//  Phase 5.3c: estate level becomes a stored field instead of being derived
//  from `User.level`. Existing players default to T1 (the value their old
//  computed `estateLevel` returned at L1) and have to spend materials at
//  the Estate root to upgrade — `EstateUpgradeService` handles the gate.
//

import Fluent

struct AddEstateLevel: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("users")
            .field("estate_level", .int, .required, .sql(.default(1)))
            .update()
    }

    func revert(on database: any Database) async throws {
        try await database.schema("users")
            .deleteField("estate_level")
            .update()
    }
}
