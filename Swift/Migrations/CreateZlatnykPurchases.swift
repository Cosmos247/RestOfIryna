//
//  CreateZlatnykPurchases.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 11.10.2026.
//
//  The zlatnyk_purchases table: one row per Treasury purchase
//  (`ZlatnykPurchase`). A new table and nothing else — nothing has been bought
//  before the Treasury existed. Cascades with the player, like every
//  per-player table, and is listed in `WipeForRebalance.playerTables`.
//

import Fluent

struct CreateZlatnykPurchases: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("zlatnyk_purchases")
            .id()
            .field("user_id", .uuid, .required, .references("users", "id", onDelete: .cascade))
            .field("telegram_id", .int64, .required)
            .field("nickname", .string)
            .field("item_id", .string, .required)
            .field("price", .int, .required)
            .field("detail", .string, .required)
            .field("balance_after", .int, .required)
            .field("created_at", .datetime)
            .create()
    }

    func revert(on database: any Database) async throws {
        try await database.schema("zlatnyk_purchases").delete()
    }
}
