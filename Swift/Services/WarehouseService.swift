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

    public enum DepositResult: Sendable {
        case success
        case nothingToDeposit
    }

    public enum WithdrawResult: Sendable {
        case success
        case nothingToWithdraw
        case inventoryFull
    }

    /// Move one unit of the item from the player's backpack to the warehouse.
    /// Returns `.nothingToDeposit` if there's no unequipped row to take from.
    /// Warehouse has no slot cap, so it can never refuse.
    @discardableResult
    public static func deposit(itemId: String, for user: User, on db: any Database) async throws -> DepositResult {
        guard let item = ItemCatalog.find(itemId), let userId = user.id else { return .nothingToDeposit }

        let rows = try await InventoryEntry.query(on: db)
            .filter(\.$user.$id, .equal, userId)
            .filter(\.$itemId, .equal, itemId)
            .all()

        // Pick the first unequipped row — equipped gear is not transferable.
        guard let source = rows.first(where: { $0.equippedSlot == nil }) else { return .nothingToDeposit }

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
        return .success
    }

    /// Move one unit of the item from the warehouse to the player's backpack.
    /// `.nothingToWithdraw` if the warehouse has zero of it; `.inventoryFull` if
    /// the backpack can't fit another row. Both failure modes leave state unchanged —
    /// the source row is only touched after the inventory side is pre-flighted.
    @discardableResult
    public static func withdraw(itemId: String, for user: User, on db: any Database) async throws -> WithdrawResult {
        guard let item = ItemCatalog.find(itemId), let userId = user.id else { return .nothingToWithdraw }

        // Preflight: make sure the backpack can accept one more.
        guard try await InventoryEntry.canAccept(itemId, quantity: 1, for: user, on: db) else {
            return .inventoryFull
        }

        let rows = try await WarehouseEntry.query(on: db)
            .filter(\.$user.$id, .equal, userId)
            .filter(\.$itemId, .equal, itemId)
            .all()

        guard let source = rows.first else { return .nothingToWithdraw }

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
        return .success
    }
}
