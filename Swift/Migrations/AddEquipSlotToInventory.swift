//
//  AddEquipSlotToInventory.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 21.04.2026.
//
//  Adds an optional `equipped_slot` column to the `inventory` table. When set,
//  this inventory row is currently equipped to that EquipmentSlot. When nil,
//  the item is simply carried.
//

import Fluent

struct AddEquipSlotToInventory: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("inventory")
            .field("equipped_slot", .string)
            .update()
    }

    func revert(on database: any Database) async throws {
        try await database.schema("inventory")
            .deleteField("equipped_slot")
            .update()
    }
}

