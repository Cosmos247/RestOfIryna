//
//  CreateMarketListings.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 28.05.2026.
//
//  Phase 6.5 — the capital Market. One row per active player-to-player lot:
//  a seller posts `quantity` units of a stackable item for a fixed total
//  `price` in silver. Listing escrows the units (removed from the seller's
//  bag, held on the row); buying transfers them to the buyer and the silver
//  to the seller; cancelling returns the units. Presence of a row = a live
//  offer. Cascade-deletes with the seller.
//

import Fluent

struct CreateMarketListings: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("market_listings")
            .id()
            .field("seller_id", .uuid, .required, .references("users", "id", onDelete: .cascade))
            .field("item_id", .string, .required)
            .field("quantity", .int, .required)
            .field("price", .int, .required)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .create()
    }

    func revert(on database: any Database) async throws {
        try await database.schema("market_listings").delete()
    }
}
