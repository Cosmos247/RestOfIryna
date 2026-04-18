//
//  AddGameStats.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 18.04.2026.
//

import Fluent

struct AddGameStats: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("users")
            .field("level", .int, .required, .sql(.default(1)))
            .field("xp", .int, .required, .sql(.default(0)))
            .field("hp", .int, .required, .sql(.default(100)))
            .field("max_hp", .int, .required, .sql(.default(100)))
            .field("hunger", .int, .required, .sql(.default(100)))
            .field("max_hunger", .int, .required, .sql(.default(100)))
            .field("attack", .int, .required, .sql(.default(10)))
            .field("defense", .int, .required, .sql(.default(10)))
            .field("crit", .int, .required, .sql(.default(5)))
            .field("dodge", .int, .required, .sql(.default(5)))
            .field("accuracy", .int, .required, .sql(.default(10)))
            .field("gold", .int, .required, .sql(.default(0)))
            .field("crowns", .int, .required, .sql(.default(0)))
            .update()
    }

    func revert(on database: any Database) async throws {
        try await database.schema("users")
            .deleteField("level")
            .deleteField("xp")
            .deleteField("hp")
            .deleteField("max_hp")
            .deleteField("hunger")
            .deleteField("max_hunger")
            .deleteField("attack")
            .deleteField("defense")
            .deleteField("crit")
            .deleteField("dodge")
            .deleteField("accuracy")
            .deleteField("gold")
            .deleteField("crowns")
            .update()
    }
}
