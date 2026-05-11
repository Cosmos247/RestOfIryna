//
//  BagUpgradeService.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 11.05.2026.
//
//  Phase 5.3d: bag-tier upgrade flow. Workshop's second universal button
//  (`[🎒 Upgrade bag]`) opens the detail screen; on confirm this service
//  validates the request, drains materials from the combined inventory +
//  warehouse pool (inventory first, same policy as the other upgrade
//  services), and bumps `User.bagTier`.
//
//  No items are added or removed beyond the input materials; the bag is a
//  pure capacity field on `User`. Item rows already at the player's
//  capacity stay — the cap only blocks new inserts above the limit.
//

import Fluent
import Foundation

public enum BagUpgradeService {

    public enum UpgradeResult: Sendable {
        case success(newTier: Int, newCapacity: Int)
        /// Bag is already at `BagCatalog.maxTier`.
        case maxTierReached(tier: Int)
        /// Player's estate level is below the step's `requiredEstateLevel`
        /// floor. Same shape as `WeaponUpgradeService.UpgradeResult`.
        case estateLevelTooLow(required: Int, current: Int)
        /// Combined inventory + warehouse pool can't cover the next tier's
        /// material cost.
        case missingMaterials(shortages: [CraftingService.Shortage])
    }

    @discardableResult
    public static func upgrade(for user: User, on db: any Database) async throws -> UpgradeResult {
        guard let userId = user.id else { return .maxTierReached(tier: user.bagTier) }

        // 1. Catalog lookup.
        guard let nextStep = BagCatalog.nextStep(from: user.bagTier) else {
            return .maxTierReached(tier: user.bagTier)
        }

        // 2. Estate-tier gate.
        if user.estateLevel < nextStep.requiredEstateLevel {
            return .estateLevelTooLow(required: nextStep.requiredEstateLevel, current: user.estateLevel)
        }

        // 3. Material availability snapshot.
        var shortages: [CraftingService.Shortage] = []
        var snapshot: [String: (inv: Int, wh: Int)] = [:]
        for input in nextStep.inputs {
            let invQty = try await InventoryEntry.totalQuantity(of: input.itemId, for: userId, on: db)
            let whQty  = try await WarehouseEntry.totalQuantity(of: input.itemId, for: userId, on: db)
            snapshot[input.itemId] = (invQty, whQty)
            let total = invQty + whQty
            if total < input.quantity {
                shortages.append(CraftingService.Shortage(itemId: input.itemId, need: input.quantity, have: total))
            }
        }
        if !shortages.isEmpty {
            return .missingMaterials(shortages: shortages)
        }

        // 4. Drain — inventory first, warehouse for the shortfall.
        for input in nextStep.inputs {
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

        // 5. Bump the tier and persist.
        user.bagTier = nextStep.toTier
        try await user.saveAndCache(in: db)

        return .success(newTier: nextStep.toTier, newCapacity: nextStep.capacity)
    }
}
