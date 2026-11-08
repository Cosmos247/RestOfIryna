//
//  CreateWagons.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 08.11.2026.
//
//  The wagon (`content/spec/spec-wagon.md`): `wagons`, one row a player who has
//  hired one, and `wagon_cargo`, one row per item on it — materials only when
//  this was written; the same day `AddWagonCargoGear` let gear ride, one row a
//  copy. Two new tables and nothing else — no wagon existed before. Both
//  cascade with the player, both are listed in `WipeForRebalance.playerTables`,
//  and `wagon_cargo.item_id` is read by `LiveReferenceQuery`.
//

import Fluent

struct CreateWagons: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("wagons")
            .id()
            .field("user_id", .uuid, .required, .references("users", "id", onDelete: .cascade))
            .field("ends_at", .datetime, .required)
            .field("settled_end", .datetime)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .unique(on: "user_id")
            .create()
        try await database.schema("wagon_cargo")
            .id()
            .field("user_id", .uuid, .required, .references("users", "id", onDelete: .cascade))
            .field("item_id", .string, .required)
            .field("quantity", .int, .required)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .unique(on: "user_id", "item_id")
            .create()
    }

    func revert(on database: any Database) async throws {
        try await database.schema("wagon_cargo").delete()
        try await database.schema("wagons").delete()
    }
}
