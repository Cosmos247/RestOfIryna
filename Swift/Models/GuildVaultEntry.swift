//
//  GuildVaultEntry.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 16.06.2026.
//
//  Phase 7.1 — the shared guild storage. Mirrors `WarehouseEntry` but keyed by
//  `guild_id` instead of `user_id`: any member may deposit, only leader +
//  officers may withdraw (enforced in GuildService, not the schema). Reuses
//  `ItemCatalog` so names / icons render exactly like the bag and warehouse.
//

import Fluent
import Foundation

final public class GuildVaultEntry: Model, @unchecked Sendable {
    public static let schema = "guild_vault"

    @ID(key: .id)
    public var id: UUID?

    @Parent(key: "guild_id")
    public var guild: Guild

    @Field(key: "item_id")
    public var itemId: String

    @Field(key: "quantity")
    public var quantity: Int

    @Timestamp(key: "created_at", on: .create)
    public var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    public var updatedAt: Date?

    public init() {}

    public init(guildID: UUID, itemId: String, quantity: Int) {
        self.$guild.id = guildID
        self.itemId = itemId
        self.quantity = quantity
    }
}

// MARK: - Helpers

extension GuildVaultEntry {
    /// Add `quantity` of an item to a guild's vault. Stackables merge into an
    /// existing row; non-stackables create one row per unit (same as warehouse).
    public static func add(_ itemId: String, quantity: Int = 1, to guildID: UUID, on db: any Database) async throws {
        guard quantity > 0 else { return }
        guard let item = ItemCatalog.find(itemId) else { return }

        if item.stackable {
            if let existing = try await GuildVaultEntry.query(on: db)
                .filter(\.$guild.$id, .equal, guildID)
                .filter(\.$itemId, .equal, itemId)
                .first() {
                existing.quantity += quantity
                try await existing.save(on: db)
                return
            }
            try await GuildVaultEntry(guildID: guildID, itemId: itemId, quantity: quantity).save(on: db)
        } else {
            for _ in 0..<quantity {
                try await GuildVaultEntry(guildID: guildID, itemId: itemId, quantity: 1).save(on: db)
            }
        }
    }

    /// All vault rows for a guild (unordered).
    public static func list(for guildID: UUID, on db: any Database) async throws -> [GuildVaultEntry] {
        try await GuildVaultEntry.query(on: db).filter(\.$guild.$id, .equal, guildID).all()
    }

    /// Total quantity of one item in a guild's vault.
    public static func totalQuantity(of itemId: String, for guildID: UUID, on db: any Database) async throws -> Int {
        let rows = try await GuildVaultEntry.query(on: db)
            .filter(\.$guild.$id, .equal, guildID)
            .filter(\.$itemId, .equal, itemId)
            .all()
        return rows.reduce(0) { $0 + $1.quantity }
    }

    /// Total units stored across all rows — gates `GuildCatalog.vaultUnitCap`.
    public static func totalUnits(for guildID: UUID, on db: any Database) async throws -> Int {
        let rows = try await GuildVaultEntry.query(on: db).filter(\.$guild.$id, .equal, guildID).all()
        return rows.reduce(0) { $0 + $1.quantity }
    }

    /// Remove `quantity` of an item from the vault. Returns `false` (no change)
    /// if the guild doesn't hold that many. Mirrors `WarehouseEntry.remove`.
    @discardableResult
    public static func remove(_ itemId: String, quantity: Int = 1, from guildID: UUID, on db: any Database) async throws -> Bool {
        guard quantity > 0 else { return true }
        let available = try await totalQuantity(of: itemId, for: guildID, on: db)
        guard available >= quantity else { return false }

        var remaining = quantity
        let rows = try await GuildVaultEntry.query(on: db)
            .filter(\.$guild.$id, .equal, guildID)
            .filter(\.$itemId, .equal, itemId)
            .sort(\.$createdAt, .ascending)
            .all()

        for row in rows {
            if remaining == 0 { break }
            if row.quantity <= remaining {
                remaining -= row.quantity
                try await row.delete(on: db)
            } else {
                row.quantity -= remaining
                remaining = 0
                try await row.save(on: db)
            }
        }
        return true
    }
}
