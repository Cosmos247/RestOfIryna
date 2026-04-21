//
//  InventoryEntry.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 19.04.2026.
//
//  One row per item stack per user. Stackable items are merged into a single
//  row by the `add` helper; non-stackable items (gear) occupy a row each.
//

import Fluent
import Foundation

final public class InventoryEntry: Model, @unchecked Sendable {
    public static let schema = "inventory"

    @ID(key: .id)
    public var id: UUID?

    @Parent(key: "user_id")
    public var user: User

    @Field(key: "item_id")
    public var itemId: String

    @Field(key: "quantity")
    public var quantity: Int

    /// When non-nil, this stack is equipped to the named EquipmentSlot (raw value).
    /// Nil means the item is just carried in the backpack.
    @Field(key: "equipped_slot")
    public var equippedSlot: String?

    @Timestamp(key: "created_at", on: .create)
    public var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    public var updatedAt: Date?

    public init() {}

    public init(userID: UUID, itemId: String, quantity: Int) {
        self.$user.id = userID
        self.itemId = itemId
        self.quantity = quantity
    }
}

// MARK: - Errors

public enum InventoryError: Error, Sendable {
    case unknownItem(String)
    case userNotPersisted
    case inventoryFull
}

// MARK: - Helpers (add / remove / has / list)

extension InventoryEntry {
    /// Fixed backpack slot cap. One inventory row = one slot, regardless of the stack's
    /// quantity (so `bread × 50` is 1 slot). Equipped gear rows don't count — they're
    /// "on the body" rather than in the bag. Raised later by Workshop upgrades (5.3).
    public static let slotCap = 50

    /// Count of non-equipped rows the user currently carries in their backpack.
    public static func slotsUsed(for user: User, on db: any Database) async throws -> Int {
        guard let userId = user.id else { return 0 }
        let rows = try await InventoryEntry.query(on: db)
            .filter(\.$user.$id, .equal, userId)
            .all()
        return rows.filter { $0.equippedSlot == nil }.count
    }

    /// True if adding `quantity` units of the item would fit. Stackable items merge into
    /// an existing row when present (no new slot); non-stackable always take N new slots.
    public static func canAccept(_ itemId: String, quantity: Int = 1, for user: User, on db: any Database) async throws -> Bool {
        guard quantity > 0 else { return true }
        guard let item = ItemCatalog.find(itemId), let userId = user.id else { return false }

        let used = try await slotsUsed(for: user, on: db)

        if item.stackable {
            let existing = try await InventoryEntry.query(on: db)
                .filter(\.$user.$id, .equal, userId)
                .filter(\.$itemId, .equal, itemId)
                .first()
            if existing != nil { return true }
            return used + 1 <= slotCap
        } else {
            return used + quantity <= slotCap
        }
    }

    /// Add an item to a user's inventory. Stackable items merge into an existing row;
    /// non-stackable items create a new row per unit. Throws `InventoryError.inventoryFull`
    /// if the slot cap would be exceeded — caller must surface that to the UI.
    public static func add(_ itemId: String, quantity: Int = 1, to user: User, on db: any Database) async throws {
        guard quantity > 0 else { return }
        guard let item = ItemCatalog.find(itemId) else {
            throw InventoryError.unknownItem(itemId)
        }
        guard let userId = user.id else {
            throw InventoryError.userNotPersisted
        }

        let used = try await slotsUsed(for: user, on: db)

        if item.stackable {
            if let existing = try await InventoryEntry.query(on: db)
                .filter(\.$user.$id, .equal, userId)
                .filter(\.$itemId, .equal, itemId)
                .first() {
                existing.quantity += quantity
                try await existing.save(on: db)
                return
            }
            // New stackable row — needs 1 fresh slot.
            guard used + 1 <= slotCap else { throw InventoryError.inventoryFull }
            try await InventoryEntry(userID: userId, itemId: itemId, quantity: quantity).save(on: db)
        } else {
            // Non-stackable — each unit is its own row.
            guard used + quantity <= slotCap else { throw InventoryError.inventoryFull }
            for _ in 0..<quantity {
                try await InventoryEntry(userID: userId, itemId: itemId, quantity: 1).save(on: db)
            }
        }
    }

    /// Remove `quantity` of an item from inventory. Returns `false` if the user
    /// doesn't have enough — in that case nothing is changed.
    @discardableResult
    public static func remove(_ itemId: String, quantity: Int = 1, from user: User, on db: any Database) async throws -> Bool {
        guard quantity > 0 else { return true }
        guard let userId = user.id else { return false }

        let available = try await totalQuantity(of: itemId, for: userId, on: db)
        guard available >= quantity else { return false }

        var remaining = quantity
        let rows = try await InventoryEntry.query(on: db)
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

    /// True if the user has at least `quantity` of the item.
    public static func has(_ itemId: String, quantity: Int = 1, user: User, on db: any Database) async throws -> Bool {
        guard let userId = user.id else { return false }
        let total = try await totalQuantity(of: itemId, for: userId, on: db)
        return total >= quantity
    }

    /// Total quantity of a specific item across all rows for a user.
    public static func totalQuantity(of itemId: String, for userId: UUID, on db: any Database) async throws -> Int {
        let rows = try await InventoryEntry.query(on: db)
            .filter(\.$user.$id, .equal, userId)
            .filter(\.$itemId, .equal, itemId)
            .all()
        return rows.reduce(0) { $0 + $1.quantity }
    }

    /// All inventory rows for a user (unordered).
    public static func list(for user: User, on db: any Database) async throws -> [InventoryEntry] {
        guard let userId = user.id else { return [] }
        return try await InventoryEntry.query(on: db)
            .filter(\.$user.$id, .equal, userId)
            .all()
    }
}
