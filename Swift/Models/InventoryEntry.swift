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
}

// MARK: - Helpers (add / remove / has / list)

extension InventoryEntry {
    /// Add an item to a user's inventory. Stackable items merge into an existing row;
    /// non-stackable items create a new row per unit.
    public static func add(_ itemId: String, quantity: Int = 1, to user: User, on db: any Database) async throws {
        guard quantity > 0 else { return }
        guard let item = ItemCatalog.find(itemId) else {
            throw InventoryError.unknownItem(itemId)
        }
        guard let userId = user.id else {
            throw InventoryError.userNotPersisted
        }

        if item.stackable {
            if let existing = try await InventoryEntry.query(on: db)
                .filter(\.$user.$id, .equal, userId)
                .filter(\.$itemId, .equal, itemId)
                .first() {
                existing.quantity += quantity
                try await existing.save(on: db)
                return
            }
            try await InventoryEntry(userID: userId, itemId: itemId, quantity: quantity).save(on: db)
        } else {
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
