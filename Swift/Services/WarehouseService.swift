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

    /// How many distinct rows the warehouse can hold at the given estate
    /// level. Stackable items count as one slot per item id; non-stackable
    /// gear counts as one slot per physical row. Estates past the table cap
    /// at the maximum (500) — keeps the function total even if the tier
    /// ladder ever extends past T7. Existing rows beyond the new cap stay
    /// readable; only deposits refuse until the player frees up space.
    private static let capTable: [Int] = [50, 100, 150, 200, 300, 400, 500]

    public static func capForLevel(_ estateLevel: Int) -> Int {
        let idx = max(0, estateLevel - 1)
        return capTable[min(idx, capTable.count - 1)]
    }

    /// Distinct-row count, used to enforce the cap. Counts both stackable
    /// items (one row per item id) and non-stackable gear (one row each).
    public static func slotsUsed(for user: User, on db: any Database) async throws -> Int {
        guard let userId = user.id else { return 0 }
        return try await WarehouseEntry.query(on: db).filter(\.$user.$id, .equal, userId).count()
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
    /// `.warehouseFull` if the deposit would create a new row past the
    /// estate-tier cap (stackable merges into an existing row are unaffected).
    @discardableResult
    public static func deposit(itemId: String, for user: User, on db: any Database) async throws -> DepositResult {
        guard let item = ItemCatalog.find(itemId), let userId = user.id else { return .nothingToDeposit }

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

        // Phase 5.3c — capacity check. Only enforced when the deposit would
        // CREATE a new warehouse row: stackable items merging into an
        // existing row don't bump the slot count, so they stay legal even
        // at cap. Non-stackable gear always creates a new row.
        let needsNewRow: Bool
        if item.stackable {
            let existing = try await WarehouseEntry.query(on: db)
                .filter(\.$user.$id, .equal, userId)
                .filter(\.$itemId, .equal, itemId)
                .first()
            needsNewRow = (existing == nil)
        } else {
            needsNewRow = true
        }
        if needsNewRow {
            let used = try await slotsUsed(for: user, on: db)
            if used >= capForLevel(user.estateLevel) {
                return .warehouseFull
            }
        }

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

        // Phase 5.3c — track slot usage as we go so we don't blow past the
        // estate cap when many items would each create a new warehouse row.
        // Items that can merge into an existing stack are exempt.
        var used = try await slotsUsed(for: user, on: db)
        let cap = capForLevel(user.estateLevel)

        var movedUnits = 0
        for row in rows {
            guard let item = ItemCatalog.find(row.itemId), item.type == category else { continue }
            guard row.equippedSlot == nil else { continue }
            // Tiered weapons stay with the player — see `deposit` for the why.
            if WeaponUpgradeCatalog.isUpgradable(row.itemId) { continue }

            let needsNewRow: Bool
            if item.stackable {
                let existing = try await WarehouseEntry.query(on: db)
                    .filter(\.$user.$id, .equal, userId)
                    .filter(\.$itemId, .equal, row.itemId)
                    .first()
                needsNewRow = (existing == nil)
            } else {
                needsNewRow = true
            }
            if needsNewRow, used >= cap { continue }
            if needsNewRow { used += 1 }

            let qty = row.quantity
            try await row.delete(on: db)
            try await WarehouseEntry.add(row.itemId, quantity: qty, to: user, on: db)
            movedUnits += qty
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
