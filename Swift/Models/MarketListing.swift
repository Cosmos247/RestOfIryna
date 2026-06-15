//
//  MarketListing.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 28.05.2026.
//
//  Phase 6.5 — a single live offer on the capital Market. The seller's units
//  are escrowed (already removed from their bag) the moment the row exists, so
//  a lot can never promise items the seller no longer holds. `MarketService`
//  owns the create / buy / cancel transactions; this file is just the model
//  plus read helpers. Only stackable items are ever listed (enforced in the
//  service), so `quantity` is always meaningful and per-unit price is exact.
//

import Fluent
import Foundation

final public class MarketListing: Model, @unchecked Sendable {
    public static let schema = "market_listings"

    @ID(key: .id)
    public var id: UUID?

    @Parent(key: "seller_id")
    public var seller: User

    @Field(key: "item_id")
    public var itemId: String

    @Field(key: "quantity")
    public var quantity: Int

    /// Total silver for the whole lot (not per-unit). Per-unit is derived for
    /// display / sorting only.
    @Field(key: "price")
    public var price: Int

    @Timestamp(key: "created_at", on: .create)
    public var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    public var updatedAt: Date?

    public init() {}

    public init(sellerID: UUID, itemId: String, quantity: Int, price: Int) {
        self.$seller.id = sellerID
        self.itemId = itemId
        self.quantity = quantity
        self.price = price
    }
}

extension MarketListing {
    /// Per-unit price, rounded down. Display / sort only — the buyer always
    /// pays the whole-lot `price`.
    public var unitPrice: Int {
        guard quantity > 0 else { return price }
        return price / quantity
    }
}

// MARK: - Read helpers

extension MarketListing {
    /// Every active lot, newest first.
    public static func allActive(on db: any Database) async throws -> [MarketListing] {
        try await MarketListing.query(on: db)
            .sort(\.$createdAt, .descending)
            .all()
    }

    /// All lots posted by one seller, newest first.
    public static func forSeller(_ user: User, on db: any Database) async throws -> [MarketListing] {
        guard let userId = user.id else { return [] }
        return try await MarketListing.query(on: db)
            .filter(\.$seller.$id, .equal, userId)
            .sort(\.$createdAt, .descending)
            .all()
    }

    /// All lots of one item, cheapest per-unit first (best deal on top).
    public static func forItem(_ itemId: String, on db: any Database) async throws -> [MarketListing] {
        let rows = try await MarketListing.query(on: db)
            .filter(\.$itemId, .equal, itemId)
            .all()
        return rows.sorted { $0.unitPrice < $1.unitPrice }
    }

    public static func find(id: UUID, on db: any Database) async throws -> MarketListing? {
        try await MarketListing.query(on: db)
            .filter(\.$id, .equal, id)
            .first()
    }

    /// Count of a seller's active lots — gates `MarketCatalog.maxActiveLots`.
    public static func activeCount(for user: User, on db: any Database) async throws -> Int {
        guard let userId = user.id else { return 0 }
        return try await MarketListing.query(on: db)
            .filter(\.$seller.$id, .equal, userId)
            .count()
    }

    /// One summary row per distinct item on the market, excluding the viewer's
    /// own lots, sorted by cheapest per-unit price ascending. Powers the
    /// Level-1 buy board (item-grouped). Each tuple is `(itemId, lotCount,
    /// minUnitPrice)`.
    public static func itemSummaries(excludingSeller viewerId: UUID?, on db: any Database) async throws -> [(itemId: String, lotCount: Int, minUnitPrice: Int)] {
        let rows = try await MarketListing.query(on: db).all()
        let visible = rows.filter { $0.$seller.id != viewerId }

        var grouped: [String: (count: Int, minUnit: Int)] = [:]
        for row in visible {
            if let current = grouped[row.itemId] {
                grouped[row.itemId] = (current.count + 1, min(current.minUnit, row.unitPrice))
            } else {
                grouped[row.itemId] = (1, row.unitPrice)
            }
        }

        return grouped
            .map { (itemId: $0.key, lotCount: $0.value.count, minUnitPrice: $0.value.minUnit) }
            .sorted { $0.minUnitPrice < $1.minUnitPrice }
    }
}
