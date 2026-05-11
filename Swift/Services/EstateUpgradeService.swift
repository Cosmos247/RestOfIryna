//
//  EstateUpgradeService.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 11.05.2026.
//
//  Phase 5.3c: estate-tier upgrade flow. The player taps `[🏠 Upgrade
//  estate]` at the Estate root; this service validates the request, drains
//  materials from the combined inventory + warehouse pool (inventory first,
//  warehouse second — same policy as CraftingService / WeaponUpgradeService),
//  and bumps `User.estateLevel`.
//
//  No new InventoryEntry / WarehouseEntry rows are created. Order of
//  operations mirrors `WeaponUpgradeService.upgrade` to keep both
//  upgrade flows mentally interchangeable for the player.
//

import Fluent
import Foundation

public enum EstateUpgradeService {

    public enum UpgradeResult: Sendable {
        case success(newTier: Int)
        /// Estate is already at `EstateUpgradeCatalog.maxTier`.
        case maxTierReached(tier: Int)
        /// Player hasn't hit the player-level requirement for the next tier
        /// yet — go fight more before pouring lumber into walls.
        case playerLevelTooLow(required: Int, current: Int)
        /// `User.gold` is below the step's `goldCost`. Gold isn't an inventory
        /// item (lives on the User row), so it's reported separately rather
        /// than folded into `missingMaterials`.
        case insufficientGold(required: Int, current: Int)
        /// Combined inventory + warehouse pool can't cover the next tier's
        /// cost. Each missing input is reported individually so the UI can
        /// surface a precise shortage list.
        case missingMaterials(shortages: [CraftingService.Shortage])
    }

    /// Attempt one upgrade step on the player's estate.
    ///   1. Look up the next-tier step in `EstateUpgradeCatalog`. If the
    ///      estate is already at max, return `.maxTierReached`.
    ///   2. Check `user.level >= requiredPlayerLevel`. If not, return
    ///      `.playerLevelTooLow`.
    ///   3. Snapshot inventory + warehouse availability for every input.
    ///      Any shortage → `.missingMaterials`.
    ///   4. Drain inputs (inventory first, warehouse second).
    ///   5. Bump `user.estateLevel`, `saveAndCache`.
    @discardableResult
    public static func upgrade(for user: User, on db: any Database) async throws -> UpgradeResult {
        guard let userId = user.id else { return .maxTierReached(tier: user.estateLevel) }

        // 1. Catalog lookup.
        guard let nextStep = EstateUpgradeCatalog.nextStep(from: user.estateLevel) else {
            return .maxTierReached(tier: user.estateLevel)
        }

        // 2. Player-level gate.
        if user.level < nextStep.requiredPlayerLevel {
            return .playerLevelTooLow(required: nextStep.requiredPlayerLevel, current: user.level)
        }

        // 3. Gold gate. Checked before material snapshot so a player who's
        // short on cash gets the cleaner "💰 not enough gold" alert instead
        // of a noisy materials breakdown that might also look fine.
        if nextStep.goldCost > 0, user.gold < nextStep.goldCost {
            return .insufficientGold(required: nextStep.goldCost, current: user.gold)
        }

        // 4. Material availability snapshot.
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

        // 5. Drain materials — inventory first, warehouse for the shortfall.
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

        // 6. Drain gold and bump the tier in the same persist call.
        if nextStep.goldCost > 0 {
            user.gold -= nextStep.goldCost
        }
        user.estateLevel = nextStep.toTier
        try await user.saveAndCache(in: db)

        return .success(newTier: nextStep.toTier)
    }
}
