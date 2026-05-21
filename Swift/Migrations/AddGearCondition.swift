//
//  AddGearCondition.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 21.05.2026.
//
//  Phase 6.5 — adds armor durability + enchant columns to `inventory`:
//    • durability      INT NOT NULL DEFAULT 30  (current condition)
//    • max_durability  INT NOT NULL DEFAULT 30  (shaved -1 per repair)
//    • enchant_level   INT NOT NULL DEFAULT 0   (permanent +DEF, cap 3)
//  Existing rows land at full durability / no enchant, so equipped gear sees
//  no change until it starts wearing. Only armor drains/enchants; other rows
//  keep the defaults and ignore them.
//

import Fluent

struct AddGearCondition: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("inventory")
            .field("durability",     .int, .required, .sql(.default(30)))
            .field("max_durability", .int, .required, .sql(.default(30)))
            .field("enchant_level",  .int, .required, .sql(.default(0)))
            .update()
    }

    func revert(on database: any Database) async throws {
        try await database.schema("inventory")
            .deleteField("durability")
            .deleteField("max_durability")
            .deleteField("enchant_level")
            .update()
    }
}
