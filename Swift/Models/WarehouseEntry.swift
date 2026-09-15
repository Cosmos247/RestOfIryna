//
//  WarehouseEntry.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 21.04.2026.
//
//  Per-user estate storage. Parallels `InventoryEntry` but represents resources
//  kept in the manor warehouse rather than the player's carried backpack — a
//  separate pile with different intended semantics: no equipping, no in-place
//  consumption, just storage (deposit/withdraw flows to be added later).
//
//  Sharing the same ItemCatalog lets the warehouse display reuse all existing
//  item names, icons, and category emojis.
//
//  A stored row carries the same `GearState` an `InventoryEntry` does (tier,
//  wear, enchant). Before 2026-09-15 it did not, and since a deposit DELETES
//  the backpack row and a withdraw CREATES a new one, storing a piece and
//  taking it back was a free full repair that also restored the shaved max —
//  and silently burned the enchant. Anything per-instance added to
//  `InventoryEntry` from here on belongs in `GearState`, not beside it.
//

import Fluent
import Foundation

final public class WarehouseEntry: Model, @unchecked Sendable {
    public static let schema = "warehouse"

    @ID(key: .id)
    public var id: UUID?

    @Parent(key: "user_id")
    public var user: User

    @Field(key: "item_id")
    public var itemId: String

    @Field(key: "quantity")
    public var quantity: Int

    /// Per-instance gear state, mirroring `InventoryEntry`'s four columns.
    /// Stackable rows keep the defaults and ignore them; a stored gear row is
    /// always one unit, so the state has exactly one owner.
    @Field(key: "tier")
    public var tier: Int

    @Field(key: "durability")
    public var durability: Int

    @Field(key: "max_durability")
    public var maxDurability: Int

    @Field(key: "enchant_level")
    public var enchantLevel: Int

    @Timestamp(key: "created_at", on: .create)
    public var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    public var updatedAt: Date?

    public init() {}

    public init(userID: UUID, itemId: String, quantity: Int, carrying state: GearState = .fresh) {
        self.$user.id = userID
        self.itemId = itemId
        self.quantity = quantity
        self.tier = state.tier
        self.durability = state.durability
        self.maxDurability = state.maxDurability
        self.enchantLevel = state.enchantLevel
    }

    /// The stored state as a value, to hand back to the backpack on withdraw.
    public var gearState: GearState {
        get { GearState(tier: tier, durability: durability, maxDurability: maxDurability, enchantLevel: enchantLevel) }
        set {
            tier = newValue.tier
            durability = newValue.durability
            maxDurability = newValue.maxDurability
            enchantLevel = newValue.enchantLevel
        }
    }
}

// MARK: - Errors

public enum WarehouseError: Error, Sendable {
    case unknownItem(String)
    case userNotPersisted
}

// MARK: - Helpers

extension WarehouseEntry {
    /// Add `quantity` of an item to the user's warehouse. Stackable items merge
    /// into an existing row; non-stackable create a new row per unit.
    ///
    /// `carrying` stamps the per-instance state onto every row this call
    /// CREATES (a stackable merge has no new row to stamp) — pass the source
    /// row's `gearState` on a deposit so wear and enchant survive storage.
    public static func add(_ itemId: String, quantity: Int = 1, to user: User, on db: any Database,
                           carrying state: GearState = .fresh) async throws {
        guard quantity > 0 else { return }
        guard let item = ItemCatalog.find(itemId) else {
            throw WarehouseError.unknownItem(itemId)
        }
        guard let userId = user.id else {
            throw WarehouseError.userNotPersisted
        }

        if item.stackable {
            if let existing = try await WarehouseEntry.query(on: db)
                .filter(\.$user.$id, .equal, userId)
                .filter(\.$itemId, .equal, itemId)
                .first() {
                existing.quantity += quantity
                try await existing.save(on: db)
                return
            }
            try await WarehouseEntry(userID: userId, itemId: itemId, quantity: quantity, carrying: state).save(on: db)
        } else {
            for _ in 0..<quantity {
                try await WarehouseEntry(userID: userId, itemId: itemId, quantity: 1, carrying: state).save(on: db)
            }
        }
    }

    /// All warehouse rows for a user (unordered).
    public static func list(for user: User, on db: any Database) async throws -> [WarehouseEntry] {
        guard let userId = user.id else { return [] }
        return try await WarehouseEntry.query(on: db)
            .filter(\.$user.$id, .equal, userId)
            .all()
    }

    /// Total quantity of a specific item across all rows for a user.
    public static func totalQuantity(of itemId: String, for userId: UUID, on db: any Database) async throws -> Int {
        let rows = try await WarehouseEntry.query(on: db)
            .filter(\.$user.$id, .equal, userId)
            .filter(\.$itemId, .equal, itemId)
            .all()
        return rows.reduce(0) { $0 + $1.quantity }
    }

    /// Remove `quantity` of an item from the warehouse. Returns `false` if the user
    /// doesn't have enough — in that case nothing is changed. Mirrors the
    /// `InventoryEntry.remove` semantics for the crafting service.
    @discardableResult
    public static func remove(_ itemId: String, quantity: Int = 1, from user: User, on db: any Database) async throws -> Bool {
        guard quantity > 0 else { return true }
        guard let userId = user.id else { return false }

        let available = try await totalQuantity(of: itemId, for: userId, on: db)
        guard available >= quantity else { return false }

        var remaining = quantity
        let rows = try await WarehouseEntry.query(on: db)
            .filter(\.$user.$id, .equal, userId)
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
