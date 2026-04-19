//
//  CreateInventory.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 19.04.2026.
//

import Fluent

struct CreateInventory: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("inventory")
            .id()
            .field("user_id", .uuid, .required, .references("users", "id", onDelete: .cascade))
            .field("item_id", .string, .required)
            .field("quantity", .int, .required)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .create()
    }

    func revert(on database: any Database) async throws {
        try await database.schema("inventory").delete()
    }
}
