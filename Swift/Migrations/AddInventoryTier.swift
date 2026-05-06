//
//  AddInventoryTier.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 06.05.2026.
//
//  Phase 5.2.2: weapon upgrade. Adds a `tier` Int column to the `inventory`
//  table with default 1. Only weapons in `WeaponUpgradeCatalog` actually
//  consume the column — every other item type ignores it. Tier-1 stats for
//  the three starter weapons are identical to the pre-existing
//  `Item.gearStats`, so existing players keep the exact same numbers until
//  they upgrade.
//

import Fluent

struct AddInventoryTier: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("inventory")
            .field("tier", .int, .required, .sql(.default(1)))
            .update()
    }

    func revert(on database: any Database) async throws {
        try await database.schema("inventory")
            .deleteField("tier")
            .update()
    }
}
