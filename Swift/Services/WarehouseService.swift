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
    public static func capForLevel(_ estateLevel: Int) -> Int {
        let capTable = Catalogs.current.tuningProgression.warehouseCapByEstateLevel
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

    /// What a bulk deposit actually did.
    ///
    /// `moved == 0` used to be the whole answer, and it reads as two opposite
    /// situations: the bag holds nothing of this category, or it holds plenty
    /// and the warehouse has no room. The player was told the first while
    /// looking at the second (reported 2026-09-10), so the reason travels with
    /// the count now.
    public struct DepositAllResult: Sendable {
        public let moved: Int
        /// The cap is what stopped it: something eligible was still in the bag
        /// with nowhere to go. True on a partial move as well as on a refusal.
        public let cappedOut: Bool
        /// A tiered weapon was passed over. It shows on the category screen as
        /// a bag-side row, so a refusal that blamed the bag for being empty
        /// would contradict what the player is looking at.
        public let skippedUntransferable: Bool
        public let used: Int
        public let cap: Int
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

    /// Outcome of a bulk-withdraw. Carries the limiting value so the UI can
    /// surface specific messaging ("Not enough. You have N", "Won't fit —
    /// room for K"). Symmetric: both failure cases tell the player exactly
    /// what's blocking the transfer without a follow-up query.
    public enum WithdrawNResult: Sendable {
        case success
        case notEnoughInWarehouse(available: Int)
        case inventoryFull(free: Int)
    }

    /// Outcome of a bulk-deposit. Mirrors `WithdrawNResult` but flipped —
    /// source is the bag, destination is the warehouse.
    public enum DepositNResult: Sendable {
        case success
        case notEnoughInBag(available: Int)
        case warehouseFull(free: Int)
        /// Item lives in `WeaponUpgradeCatalog` (per-instance tier) and can't
        /// be warehoused — same restriction the single-unit `deposit` returns
        /// as `notTransferable`. The `[✏️ N]` flow only renders for stackable
        /// items so this case is defensive; surface as a modal alert if hit.
        case notTransferable
    }

    /// Move one unit of the item from the player's backpack to the warehouse.
    /// Returns `.nothingToDeposit` if there's no unequipped row to take from,
    /// `.warehouseFull` if the warehouse is at unit cap — with no exemption for
    /// developer accounts since 2026-09-09, as the code below says.
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
        // free pass — every deposited unit eats one slot. The developer
        // account is NOT exempt (2026-09-09): an unlimited warehouse on the
        // one account that plays the game most is how a ceiling stops being
        // tested by the person who owns it.
        let used = try await slotsUsed(for: user, on: db)
        if used >= capForLevel(user.estateLevel) {
            return .warehouseFull
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
    /// player must unequip it first. Returns what moved AND why it stopped, so
    /// a refusal can name the cap instead of blaming the bag.
    @discardableResult
    public static func depositAll(category: ItemType, for user: User, on db: any Database) async throws -> DepositAllResult {
        let cap = capForLevel(user.estateLevel)
        guard let userId = user.id else {
            return DepositAllResult(moved: 0, cappedOut: false, skippedUntransferable: false, used: 0, cap: cap)
        }

        let rows = try await InventoryEntry.query(on: db)
            .filter(\.$user.$id, .equal, userId)
            .all()

        // Per-unit usage tracker (2026-05-12). The last allowed stack is
        // partially filled rather than skipped, so a 10-unit hide row hitting
        // a 6-unit free cap dumps 6 and leaves 4 behind. No developer
        // exemption since 2026-09-09.
        var used = try await slotsUsed(for: user, on: db)

        var movedUnits = 0
        var cappedOut = false
        var skippedUntransferable = false
        for row in rows {
            guard let item = ItemCatalog.find(row.itemId), item.type == category else { continue }
            guard row.equippedSlot == nil else { continue }
            // Tiered weapons stay with the player — see `deposit` for the why.
            // Recorded rather than merely skipped: an unequipped one is listed
            // on the screen the player just tapped, so the refusal has to name
            // this reason instead of falling through to "your bag has none".
            if WeaponUpgradeCatalog.isUpgradable(row.itemId) {
                skippedUntransferable = true
                continue
            }

            let qty = row.quantity
            let canMove = min(qty, max(0, cap - used))
            // Anything eligible that does not fit — wholly or partly — is the
            // cap talking, and the caller has to be able to say so.
            if canMove < qty { cappedOut = true }
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
        return DepositAllResult(moved: movedUnits, cappedOut: cappedOut,
                                skippedUntransferable: skippedUntransferable, used: used, cap: cap)
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

    /// Move `quantity` units of the item from the warehouse to the backpack
    /// in one shot. Fails atomically if the warehouse doesn't have enough or
    /// the backpack can't fit — both failure cases carry the limiting number
    /// so the caller can render a precise message. Caller is responsible for
    /// ensuring `quantity > 0`; the function treats `<= 0` as a no-op success.
    @discardableResult
    public static func withdrawN(itemId: String, quantity: Int, for user: User, on db: any Database) async throws -> WithdrawNResult {
        guard quantity > 0 else { return .success }
        guard ItemCatalog.find(itemId) != nil, let userId = user.id else {
            return .notEnoughInWarehouse(available: 0)
        }

        // Source preflight — refuse if warehouse can't cover the request.
        let available = try await WarehouseEntry.totalQuantity(of: itemId, for: userId, on: db)
        guard available >= quantity else {
            return .notEnoughInWarehouse(available: available)
        }

        // Destination preflight — refuse if backpack can't fit. Dev accounts
        // bypass the cap, mirroring `InventoryEntry.add` semantics.
        let cap = InventoryEntry.slotCap(for: user)
        let used = try await InventoryEntry.slotsUsed(for: user, on: db)
        let free = user.isDeveloper ? Int.max : max(0, cap - used)
        guard free >= quantity else {
            return .inventoryFull(free: free)
        }

        // Both sides cleared — perform the transfer. `remove` already returns
        // `false` only when the available count drops below the request, but
        // we've already preflighted so a `false` here would be a race we can't
        // realistically resolve; treat it as the same insufficiency.
        let removed = try await WarehouseEntry.remove(itemId, quantity: quantity, from: user, on: db)
        guard removed else {
            let afterRace = try await WarehouseEntry.totalQuantity(of: itemId, for: userId, on: db)
            return .notEnoughInWarehouse(available: afterRace)
        }
        try await InventoryEntry.add(itemId, quantity: quantity, to: user, on: db)
        return .success
    }

    /// Move `quantity` units of the item from the backpack to the warehouse
    /// in one shot. Mirror of `withdrawN`. Atomic preflight: bag has at least
    /// `quantity` (counting only unequipped rows — equipped gear is "on the
    /// body" and not transferable, same rule as single-unit `deposit`), and
    /// warehouse has free slots for `quantity` units — with no developer
    /// exemption since 2026-09-09, as the code below says.
    @discardableResult
    public static func depositN(itemId: String, quantity: Int, for user: User, on db: any Database) async throws -> DepositNResult {
        guard quantity > 0 else { return .success }
        guard ItemCatalog.find(itemId) != nil, let userId = user.id else {
            return .notEnoughInBag(available: 0)
        }

        // Tiered weapons can't ride the warehouse table (no tier column).
        // The N-flow button only renders on stackable items so this is a
        // defensive guard — keeps the service honest if a stale callback
        // ever reaches it.
        if WeaponUpgradeCatalog.isUpgradable(itemId) {
            return .notTransferable
        }

        // Source preflight — count only unequipped rows (gear that's worn
        // can't be deposited even if stackable in theory; safer to scope to
        // unequipped, matching single-unit `deposit` behaviour).
        let bagRows = try await InventoryEntry.query(on: db)
            .filter(\.$user.$id, .equal, userId)
            .filter(\.$itemId, .equal, itemId)
            .all()
        let available = bagRows.filter { $0.equippedSlot == nil }.reduce(0) { $0 + $1.quantity }
        guard available >= quantity else {
            return .notEnoughInBag(available: available)
        }

        // Destination preflight — refuse if the warehouse would overflow its
        // per-tier cap. No developer exemption (2026-09-09).
        let cap = capForLevel(user.estateLevel)
        let used = try await slotsUsed(for: user, on: db)
        let free = max(0, cap - used)
        guard free >= quantity else {
            return .warehouseFull(free: free)
        }

        // Both sides cleared — drain the bag, fill the warehouse. Same race
        // caveat as `withdrawN`: if a parallel update drains the bag between
        // preflight and `remove`, we report the post-race count.
        let removed = try await InventoryEntry.remove(itemId, quantity: quantity, from: user, on: db)
        guard removed else {
            let afterRace = try await InventoryEntry.totalQuantity(of: itemId, for: userId, on: db)
            return .notEnoughInBag(available: afterRace)
        }
        try await WarehouseEntry.add(itemId, quantity: quantity, to: user, on: db)
        return .success
    }
}
