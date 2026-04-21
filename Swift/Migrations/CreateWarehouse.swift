//
//  CreateWarehouse.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 21.04.2026.
//
//  Creates the `warehouse` table — per-user estate storage. Mirrors the shape
//  of the `inventory` table but represents a separate pile of items kept in
//  the manor, rather than the backpack carried on the road.
//

import Fluent

struct CreateWarehouse: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("warehouse")
            .id()
            .field("user_id", .uuid, .required, .references("users", "id", onDelete: .cascade))
            .field("item_id", .string, .required)
            .field("quantity", .int, .required)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .create()
    }

    func revert(on database: any Database) async throws {
        try await database.schema("warehouse").delete()
    }
}
