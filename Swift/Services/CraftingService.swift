//
//  CraftingService.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 01.05.2026.
//
//  Pure crafting service — drains recipe inputs from the player's combined
//  inventory + warehouse pool and deposits the output into the inventory.
//
//  Source-pool order:
//    1. Inventory rows (frees backpack slots that the output may need)
//    2. Warehouse rows (the bulk-storage fallback)
//
//  Output destination: always the inventory, so the player can see and equip
//  the new item immediately. For non-stackable gear, the inventory accept
//  check accounts for slots that *would* be freed by the inventory drain so
//  a craft never refuses spuriously when a 50-slot bag would have made room
//  by consuming the inputs.
//
//  No DB transaction wrapping — same pattern as WarehouseService. The drains
//  are idempotent enough that a partial failure leaves the player's totals
//  consistent (worst case: missing an input row plus its expected output).
//

import Fluent
import Foundation

public enum CraftingService {

    public enum CraftResult: Sendable {
        case success(outputItemId: String, outputQuantity: Int)
        case missingMaterials(shortages: [Shortage])
        case inventoryFull
        case unknownRecipe
        case unknownItem(String)
    }

    /// One missing-input record surfaced to the UI when the player taps Craft
    /// without enough materials in either the bag or the warehouse.
    public struct Shortage: Sendable {
        public let itemId: String
        public let need: Int
        public let have: Int
    }

    /// Attempt to craft `recipe` for `user`. Order of operations:
    ///   1. Validate output item exists in catalog.
    ///   2. Compute combined inventory + warehouse availability per input.
    ///   3. If any input is short → return `.missingMaterials`, no state change.
    ///   4. Compute slots that would be freed by draining inventory inputs and
    ///      verify the output will fit. If not → `.inventoryFull`, no state change.
    ///   5. Drain inputs (inventory first, warehouse second).
    ///   6. Add output to the inventory.
    @discardableResult
    public static func craft(_ recipe: Recipe, for user: User, on db: any Database) async throws -> CraftResult {
        guard let userId = user.id else { return .unknownRecipe }
        guard let outputItem = ItemCatalog.find(recipe.output.itemId) else {
            return .unknownItem(recipe.output.itemId)
        }

        // 1. Availability snapshot.
        var shortages: [Shortage] = []
        var snapshot: [String: (inv: Int, wh: Int)] = [:]
        for input in recipe.inputs {
            let invQty = try await InventoryEntry.totalQuantity(of: input.itemId, for: userId, on: db)
            let whQty  = try await WarehouseEntry.totalQuantity(of: input.itemId, for: userId, on: db)
            snapshot[input.itemId] = (invQty, whQty)
            let total = invQty + whQty
            if total < input.quantity {
                shortages.append(Shortage(itemId: input.itemId, need: input.quantity, have: total))
            }
        }
        if !shortages.isEmpty {
            return .missingMaterials(shortages: shortages)
        }

        // 2. Predict slots freed by inventory drain. For stackable items, the
        // slot only frees if we drain the *whole* row; for non-stackable, every
        // unit is its own slot. Unknown items can't be drained — skip.
        var freedSlots = 0
        for input in recipe.inputs {
            guard let inputItem = ItemCatalog.find(input.itemId) else { continue }
            let (invQty, _) = snapshot[input.itemId] ?? (0, 0)
            let drainedFromInventory = min(input.quantity, invQty)
            if drainedFromInventory == 0 { continue }
            if inputItem.stackable {
                if drainedFromInventory >= invQty { freedSlots += 1 }
            } else {
                freedSlots += drainedFromInventory
            }
        }

        let usedSlots = try await InventoryEntry.slotsUsed(for: user, on: db)
        let postDrainUsed = max(0, usedSlots - freedSlots)
        let outputFits: Bool
        if outputItem.stackable {
            let existing = try await InventoryEntry.query(on: db)
                .filter(\.$user.$id, .equal, userId)
                .filter(\.$itemId, .equal, recipe.output.itemId)
                .first()
            outputFits = (existing != nil) || (postDrainUsed + 1 <= InventoryEntry.slotCap(for: user))
        } else {
            outputFits = (postDrainUsed + recipe.output.quantity) <= InventoryEntry.slotCap(for: user)
        }
        guard outputFits else { return .inventoryFull }

        // 3. Drain — inventory first, warehouse for any shortfall.
        for input in recipe.inputs {
            let (invQty, _) = snapshot[input.itemId] ?? (0, 0)
            let fromInv = min(input.quantity, invQty)
            if fromInv > 0 {
                _ = try await InventoryEntry.remove(input.itemId, quantity: fromInv, from: user, on: db)
            }
            let fromWH = input.quantity - fromInv
            if fromWH > 0 {
                _ = try await WarehouseEntry.remove(input.itemId, quantity: fromWH, from: user, on: db)
            }
        }

        // 4. Output to inventory.
        try await InventoryEntry.add(recipe.output.itemId, quantity: recipe.output.quantity, to: user, on: db)

        // Phase 9.2 — the Master's "Виплавка" job counts forge output. Only the
        // ingot is tracked in v1; best-effort so a quest hiccup can't eat a craft.
        if recipe.output.itemId == "mat.iron_ingot" {
            try? await QuestService.record(.ironIngotForged, amount: recipe.output.quantity, for: user, on: db)
        }

        return .success(outputItemId: recipe.output.itemId, outputQuantity: recipe.output.quantity)
    }
}
