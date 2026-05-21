//
//  MasterService.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 21.05.2026.
//
//  Phase 6.5 — the Master's three actions: buy ready-made armor, repair worn
//  armor, and enchant armor (+DEF). All three drain `User.silver` (the first
//  real silver sink); enchant + repair also touch materials / durability.
//  Pure-ish: owns its DB writes per action and recomputes gear bonuses, mirrors
//  TraderService / WeaponUpgradeService shape. Armor-only for now.
//

import Fluent
import Foundation

public enum MasterService {

    // MARK: - Result enums

    public enum BuyResult: Sendable {
        case success(itemId: String, price: Int)
        case notEnoughSilver(have: Int, need: Int)
        case inventoryFull(free: Int)
        case unknownItem
    }

    public enum RepairResult: Sendable {
        case success(itemId: String, cost: Int, newMax: Int)
        case alreadyFull
        case notEnoughSilver(have: Int, need: Int)
        case notArmor
    }

    public enum EnchantResult: Sendable {
        case success(itemId: String, newLevel: Int)
        case maxLevel
        case notEnoughSilver(have: Int, need: Int)
        case missingMaterials(itemId: String, have: Int, need: Int)
        case notArmor
    }

    // MARK: - Helpers

    /// True when an item id is an armor piece (occupies an armor slot).
    private static func isArmor(_ itemId: String) -> Bool {
        guard let slot = ItemCatalog.find(itemId)?.slot else { return false }
        return GearConditionService.armorSlots.contains(slot.rawValue)
    }

    private static func ownedRow(_ entryId: UUID, for user: User, on db: any Database) async throws -> InventoryEntry? {
        guard let userId = user.id else { return nil }
        return try await InventoryEntry.query(on: db)
            .filter(\.$user.$id, .equal, userId)
            .filter(\.$id, .equal, entryId)
            .first()
    }

    // MARK: - Buy

    public static func buy(itemId: String, for user: User, on db: any Database) async throws -> BuyResult {
        guard let price = MasterCatalog.buyPrice(for: itemId) else { return .unknownItem }
        if user.silver < price { return .notEnoughSilver(have: user.silver, need: price) }

        let canFit = try await InventoryEntry.canAccept(itemId, quantity: 1, for: user, on: db)
        if !canFit {
            let used = try await InventoryEntry.slotsUsed(for: user, on: db)
            let free = max(0, InventoryEntry.slotCap(for: user) - used)
            return .inventoryFull(free: free)
        }

        user.silver -= price
        try await user.saveAndCache(in: db)
        // `InventoryEntry.add` stamps full durability + enchant 0 via its init.
        try await InventoryEntry.add(itemId, quantity: 1, to: user, on: db)
        return .success(itemId: itemId, price: price)
    }

    // MARK: - Repair

    /// Restore a worn armor piece to full, then permanently shave its max
    /// durability (mechanic B). Repairs to the *new* reduced max so the piece
    /// slowly wears out toward a rebuy.
    public static func repair(entryId: UUID, for user: User, on db: any Database) async throws -> RepairResult {
        guard let row = try await ownedRow(entryId, for: user, on: db), isArmor(row.itemId) else {
            return .notArmor
        }
        let missing = row.maxDurability - row.durability
        guard missing > 0 else { return .alreadyFull }

        let cost = MasterCatalog.repairCost(itemId: row.itemId, missing: missing)
        if user.silver < cost { return .notEnoughSilver(have: user.silver, need: cost) }

        let newMax = max(1, row.maxDurability - GearConditionService.repairMaxShave)
        user.silver -= cost
        row.maxDurability = newMax
        row.durability = newMax
        try await row.save(on: db)
        try await EquipmentService.recomputeBonuses(for: user, on: db)
        try await user.saveAndCache(in: db)
        return .success(itemId: row.itemId, cost: cost, newMax: newMax)
    }

    // MARK: - Enchant

    /// Raise an armor piece's permanent +DEF enchant by one level for silver +
    /// material, drained from the combined inventory + warehouse pool.
    public static func enchant(entryId: UUID, for user: User, on db: any Database) async throws -> EnchantResult {
        guard let userId = user.id else { return .notArmor }
        guard let row = try await ownedRow(entryId, for: user, on: db), isArmor(row.itemId) else {
            return .notArmor
        }
        guard let step = MasterCatalog.enchantStep(currentLevel: row.enchantLevel) else {
            return .maxLevel
        }
        if user.silver < step.silver { return .notEnoughSilver(have: user.silver, need: step.silver) }

        let invQty = try await InventoryEntry.totalQuantity(of: step.materialId, for: userId, on: db)
        let whQty  = try await WarehouseEntry.totalQuantity(of: step.materialId, for: userId, on: db)
        if invQty + whQty < step.materialQty {
            return .missingMaterials(itemId: step.materialId, have: invQty + whQty, need: step.materialQty)
        }

        // Drain material — inventory first, warehouse for the shortfall.
        let fromInv = min(step.materialQty, invQty)
        if fromInv > 0 { _ = try await InventoryEntry.remove(step.materialId, quantity: fromInv, from: user, on: db) }
        let fromWH = step.materialQty - fromInv
        if fromWH > 0 { _ = try await WarehouseEntry.remove(step.materialId, quantity: fromWH, from: user, on: db) }

        user.silver -= step.silver
        row.enchantLevel += 1
        try await row.save(on: db)
        try await EquipmentService.recomputeBonuses(for: user, on: db)
        try await user.saveAndCache(in: db)
        return .success(itemId: row.itemId, newLevel: row.enchantLevel)
    }
}
