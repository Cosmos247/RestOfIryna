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

    // MARK: - Phase 5.3c — capacity by estate tier

    /// How many TOTAL UNITS the warehouse can hold at the given estate level
    /// (per-unit accounting since 2026-05-12 — was per-row before, which
    /// turned the warehouse into an infinite buffer per item id). Scaled
    /// ×4 from the original [50,100,…,500] table because the old numbers
    /// only made sense when one entry was an arbitrary stack. Estates past
    /// the table cap at the top tier (T7=2000). Existing rows beyond the
    /// new cap stay readable; only deposits refuse until space is freed.
    private static let capTable: [Int] = [200, 400, 600, 800, 1200, 1600, 2000]

    public static func capForLevel(_ estateLevel: Int) -> Int {
        let idx = max(0, estateLevel - 1)
        return capTable[min(idx, capTable.count - 1)]
    }

    /// Total units in the warehouse (sum of `quantity` across all rows).
    /// Per-unit accounting symmetric with `InventoryEntry.slotsUsed`.
    public static func slotsUsed(for user: User, on db: any Database) async throws -> Int {
        guard let userId = user.id else { return 0 }
        let rows = try await WarehouseEntry.query(on: db).filter(\.$user.$id, .equal, userId).all()
        return rows.reduce(0) { $0 + $1.quantity }
    }

    public enum DepositResult: Sendable {
        case success
        case nothingToDeposit
        /// Item is in `WeaponUpgradeCatalog` — depositing it would lose the
        /// per-instance tier (warehouse rows don't track tier). Returned so
        /// the UI can surface a clean "weapons stay with you" alert instead
        /// of silently downgrading the player's progress.
        case notTransferable
        /// Phase 5.3c — warehouse is at its `capForLevel(estateLevel)` and the
        /// deposit would create a new row. Stackable items merging into an
        /// existing row do NOT trigger this — only new rows do. Withdraw
        /// something or upgrade the estate to make room.
        case warehouseFull
    }

    public enum WithdrawResult: Sendable {
        case success
        case nothingToWithdraw
        case inventoryFull
    }

    /// Move one unit of the item from the player's backpack to the warehouse.
    /// Returns `.nothingToDeposit` if there's no unequipped row to take from,
    /// `.warehouseFull` if the warehouse is at unit cap. Developer accounts
    /// bypass the cap entirely (still recorded — UI just shows overflow).
    @discardableResult
    public static func deposit(itemId: String, for user: User, on db: any Database) async throws -> DepositResult {
        guard ItemCatalog.find(itemId) != nil, let userId = user.id else { return .nothingToDeposit }

        // Tiered weapons can't be warehoused — `WarehouseEntry` doesn't carry
        // the tier column, so storing one would silently demote a T5 sword to
        // T1 on withdraw. By design these weapons stay with the player anyway.
        if WeaponUpgradeCatalog.isUpgradable(itemId) {
            return .notTransferable
        }

        let rows = try await InventoryEntry.query(on: db)
            .filter(\.$user.$id, .equal, userId)
            .filter(\.$itemId, .equal, itemId)
            .all()

        // Pick the first unequipped row — equipped gear is not transferable.
        guard let source = rows.first(where: { $0.equippedSlot == nil }) else { return .nothingToDeposit }

        // Per-unit cap check (2026-05-12). Stackable merges no longer get a
        // free pass — every deposited unit eats one slot. Devs bypass.
        if !user.isDeveloper {
            let used = try await slotsUsed(for: user, on: db)
            if used >= capForLevel(user.estateLevel) {
                return .warehouseFull
            }
        }

        let item = ItemCatalog.find(itemId)!
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

    /// Move every unequipped unit of the given category from the backpack to the
    /// warehouse in one shot. Equipped gear is skipped — to dump worn armor the
    /// player must unequip it first. Returns the total number of units moved
    /// (sum of stack quantities), so the caller can render
    /// "✅ Moved N items to warehouse".
    @discardableResult
    public static func depositAll(category: ItemType, for user: User, on db: any Database) async throws -> Int {
        guard let userId = user.id else { return 0 }

        let rows = try await InventoryEntry.query(on: db)
            .filter(\.$user.$id, .equal, userId)
            .all()

        // Per-unit usage tracker (2026-05-12). On a non-dev account we
        // partially fill the last allowed stack instead of skipping it,
        // so a 10-unit hide row hitting a 6-unit free cap dumps 6 and
        // leaves 4 behind. Devs deposit everything.
        var used = try await slotsUsed(for: user, on: db)
        let cap = capForLevel(user.estateLevel)
        let bypass = user.isDeveloper

        var movedUnits = 0
        for row in rows {
            guard let item = ItemCatalog.find(row.itemId), item.type == category else { continue }
            guard row.equippedSlot == nil else { continue }
            // Tiered weapons stay with the player — see `deposit` for the why.
            if WeaponUpgradeCatalog.isUpgradable(row.itemId) { continue }

            let qty = row.quantity
            let canMove: Int
            if bypass {
                canMove = qty
            } else {
                let headroom = max(0, cap - used)
                canMove = min(qty, headroom)
            }
            guard canMove > 0 else { continue }

            // Drain the source row by canMove (delete if fully drained).
            if canMove >= qty {
                try await row.delete(on: db)
            } else {
                row.quantity = qty - canMove
                try await row.save(on: db)
            }

            // Non-stackable categories (gear) ALWAYS produce one warehouse
            // row per unit through `WarehouseEntry.add` (it's already
            // stackable-aware). We just pass the moved count.
            try await WarehouseEntry.add(row.itemId, quantity: canMove, to: user, on: db)
            used += canMove
            movedUnits += canMove
        }
        return movedUnits
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
