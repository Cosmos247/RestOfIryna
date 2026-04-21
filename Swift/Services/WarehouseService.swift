//
//  WarehouseService.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 21.04.2026.
//
//  Move items between the backpack (`InventoryEntry`) and the estate warehouse
//  (`WarehouseEntry`). Each call transfers exactly one unit — the UI triggers
//  the service on every tap of the deposit/withdraw button.
//
//  For gear, deposits pick the first UNEQUIPPED row — you can't move worn armor
//  to storage without unequipping it first.
//

import Fluent
import Foundation

public enum WarehouseService {

    /// Move one unit of the item from the player's backpack to the warehouse.
    /// Returns `true` on success, `false` if nothing depositable was available
    /// (e.g. zero in inventory, or every row of a gear item is currently equipped).
    @discardableResult
    public static func deposit(itemId: String, for user: User, on db: any Database) async throws -> Bool {
        guard let item = ItemCatalog.find(itemId), let userId = user.id else { return false }

        let rows = try await InventoryEntry.query(on: db)
            .filter(\.$user.$id, .equal, userId)
            .filter(\.$itemId, .equal, itemId)
            .all()

        // Pick the first unequipped row — equipped gear is not transferable.
        guard let source = rows.first(where: { $0.equippedSlot == nil }) else { return false }

        if item.stackable {
            if source.quantity <= 1 {
                try await source.delete(on: db)
            } else {
                source.quantity -= 1
                try await source.save(on: db)
            }
        } else {
            try await source.delete(on: db)
        }

        try await WarehouseEntry.add(itemId, quantity: 1, to: user, on: db)
        return true
    }

    /// Move one unit of the item from the warehouse back to the player's backpack.
    /// Returns `false` if the warehouse has zero of that item.
    @discardableResult
    public static func withdraw(itemId: String, for user: User, on db: any Database) async throws -> Bool {
        guard let item = ItemCatalog.find(itemId), let userId = user.id else { return false }

        let rows = try await WarehouseEntry.query(on: db)
            .filter(\.$user.$id, .equal, userId)
            .filter(\.$itemId, .equal, itemId)
            .all()

        guard let source = rows.first else { return false }

        if item.stackable {
            if source.quantity <= 1 {
                try await source.delete(on: db)
            } else {
                source.quantity -= 1
                try await source.save(on: db)
            }
        } else {
            try await source.delete(on: db)
        }

        // Withdrawn items land in the backpack unequipped — player must go equip them.
        try await InventoryEntry.add(itemId, quantity: 1, to: user, on: db)
        return true
    }
}
