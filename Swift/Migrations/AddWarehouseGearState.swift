//
//  AddWarehouseGearState.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 15.09.2026.
//
//  Adds the four per-instance gear columns to `warehouse`, mirroring the ones
//  `inventory` has carried since Phase 6.5:
//    • tier            INT NOT NULL DEFAULT 1
//    • durability      INT NOT NULL DEFAULT 30  (current condition)
//    • max_durability  INT NOT NULL DEFAULT 30  (shaved -1 per armor repair)
//    • enchant_level   INT NOT NULL DEFAULT 0
//  Without them a deposit/withdraw round-trip reset a stored piece to factory
//  condition — a free full repair that also undid the max shave (the only
//  thing that makes gear wear out) and erased the enchant without a word.
//  Existing rows land on the defaults, which is exactly what a withdraw was
//  already handing back, so nothing a player is holding changes value.
//

import Fluent

struct AddWarehouseGearState: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("warehouse")
            .field("tier",           .int, .required, .sql(.default(1)))
            .field("durability",     .int, .required, .sql(.default(30)))
            .field("max_durability", .int, .required, .sql(.default(30)))
            .field("enchant_level",  .int, .required, .sql(.default(0)))
            .update()
    }

    func revert(on database: any Database) async throws {
        try await database.schema("warehouse")
            .deleteField("tier")
            .deleteField("durability")
            .deleteField("max_durability")
            .deleteField("enchant_level")
            .update()
    }
}
