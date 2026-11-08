//
//  AddWagonCargoGear.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 08.11.2026.
//
//  The wagon carries anything the warehouse takes (the owner, 2026-11-08), so its
//  cargo rows gain the four `GearState` columns the warehouse's rows carry — a
//  piece's tier, wear and enchant ride with it — and lose the one-row-per-item
//  constraint, since two hoods are two rows. Defaults match `GearState.fresh`
//  for a stackable (tier 1, no wear, no enchant), so no row is rewritten.
//

import Fluent

struct AddWagonCargoGear: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("wagon_cargo")
            .field("tier", .int, .required, .sql(.default(1)))
            .field("durability", .int, .required, .sql(.default(0)))
            .field("max_durability", .int, .required, .sql(.default(0)))
            .field("enchant_level", .int, .required, .sql(.default(0)))
            .deleteUnique(on: "user_id", "item_id")
            .update()
    }

    func revert(on database: any Database) async throws {
        try await database.schema("wagon_cargo")
            .deleteField("tier")
            .deleteField("durability")
            .deleteField("max_durability")
            .deleteField("enchant_level")
            .unique(on: "user_id", "item_id")
            .update()
    }
}
