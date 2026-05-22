//
//  WeaponUpgradeService.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 06.05.2026.
//
//  Phase 5.2.2: weapon-upgrade flow. The player's class starter weapon is
//  permanent — only its `InventoryEntry.tier` ever changes. Upgrade drains
//  the next-tier materials from the combined inventory + warehouse pool
//  (mirroring CraftingService) and bumps the tier on the same row, then
//  recomputes the cached gear bonuses on the User.
//
//  No new InventoryEntry / WarehouseEntry rows are created. The weapon
//  stays equipped (or in-bag) on the same row throughout — visually the
//  player keeps the same item, it just "grows up".
//
//  Estate level gates progression: tier N requires `user.estateLevel >= N`.
//  Skip-ahead is forbidden by design — to reach T5 the player has to walk
//  through T2, T3, T4 in order.
//

import Fluent
import Foundation

public enum WeaponUpgradeService {

    public enum UpgradeResult: Sendable {
        case success(newTier: Int, outputItemId: String)
        /// Weapon is already at the highest tier defined in `WeaponUpgradeCatalog`.
        case maxTierReached(tier: Int)
        /// Player's estate level is below the required floor for the next tier.
        case estateLevelTooLow(required: Int, current: Int)
        /// Player has no equipped weapon to upgrade. Shouldn't happen in normal
        /// play (registration grants one), but the service stays defensive.
        case noWeaponEquipped
        /// Combined inventory + warehouse pool can't cover the next tier's cost.
        /// Each missing input is reported individually.
        case missingMaterials(shortages: [CraftingService.Shortage])
    }

    /// Attempt one upgrade step on the player's currently-equipped main-hand
    /// weapon. Order of operations:
    ///   1. Find the equipped weapon (InventoryEntry with `equipped_slot = mainHand`).
    ///   2. Look up its current tier in the catalog. If it's already at max,
    ///      return `.maxTierReached`.
    ///   3. Check `user.estateLevel >= nextTier`. If not, return
    ///      `.estateLevelTooLow`.
    ///   4. Snapshot inventory + warehouse availability for every input. If
    ///      any input is short, return `.missingMaterials`.
    ///   5. Drain the inputs (inventory first, warehouse second — same policy
    ///      as CraftingService).
    ///   6. Increment the weapon row's `tier`, save it.
    ///   7. EquipmentService.recomputeBonuses + saveAndCache the user.
    @discardableResult
    public static func upgrade(for user: User, on db: any Database) async throws -> UpgradeResult {
        guard let userId = user.id else { return .noWeaponEquipped }

        // 1. Equipped weapon = main-hand row.
        let equippedRows = try await InventoryEntry.query(on: db)
            .filter(\.$user.$id, .equal, userId)
            .filter(\.$equippedSlot, .equal, EquipmentSlot.mainHand.rawValue)
            .all()
        guard let weapon = equippedRows.first else { return .noWeaponEquipped }

        // 2. Catalog lookup.
        guard let maxTier = WeaponUpgradeCatalog.maxTier(for: weapon.itemId) else {
            // Item isn't in the upgrade catalog at all — treat as max-reached so
            // the UI can surface a clean "fully upgraded" message instead of a
            // confusing error.
            return .maxTierReached(tier: weapon.tier)
        }
        if weapon.tier >= maxTier {
            return .maxTierReached(tier: weapon.tier)
        }
        let nextTier = weapon.tier + 1
        guard let nextStep = WeaponUpgradeCatalog.step(for: weapon.itemId, tier: nextTier) else {
            return .maxTierReached(tier: weapon.tier)
        }

        // 3. Estate-level gate. Tier N requires estate level >= N.
        let estateLevel = user.estateLevel
        if estateLevel < nextTier {
            return .estateLevelTooLow(required: nextTier, current: estateLevel)
        }

        // 4. Availability snapshot.
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

        // 5. Drain — inventory first, warehouse for the shortfall.
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

        // 6. Bump the tier on the same row — this is the entire "the weapon
        // grew up" mutation. Item id never changes. Reforging to a higher tier
        // raises its durability ceiling and renews it to full (a freshly
        // tempered weapon is pristine).
        weapon.tier = nextTier
        weapon.maxDurability = WeaponUpgradeCatalog.durability(forTier: nextTier)
        weapon.durability = weapon.maxDurability
        try await weapon.save(on: db)

        // 7. Recompute cached gear bonuses so combat / profile pick up the
        // new stats on the next read.
        try await EquipmentService.recomputeBonuses(for: user, on: db)
        try await user.saveAndCache(in: db)

        return .success(newTier: nextTier, outputItemId: weapon.itemId)
    }
}
