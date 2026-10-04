//
//  WeaponUpgradeService.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 06.05.2026.
//
//  Phase 5.2.2: weapon-upgrade flow. The player's class starter weapon is
//  permanent — only its `InventoryEntry.tier` ever changes. The workshop
//  drains the next-tier materials from the combined inventory + warehouse
//  pool (mirroring CraftingService); the Master's lesson, in the capital,
//  from the bag alone. Either way the tier bumps on the same row and the
//  cached gear bonuses on the User are recomputed.
//
//  No new InventoryEntry / WarehouseEntry rows are created. The weapon
//  stays equipped (or in-bag) on the same row throughout — visually the
//  player keeps the same item, it just "grows up".
//
//  The PLAYER level gates progression since 2026-10-04 (`spec-items.md` §9):
//  tier N opens at its rung's `requiredPlayerLevel`, one every five levels. The
//  estate used to open tier N at T N, which put the item-level-40 sword in hand
//  at level 13. Skip-ahead is still forbidden — one rung per tap.
//
//  Two doors, one reforge. The FIRST rung, tier 1 → 2, is only ever sold by the
//  Master in the capital as a lesson (`lesson(for:on:)`): the rung's materials
//  from the bag (the capital has no warehouse) plus `MasterCatalog.
//  weaponLessonSilver`. Every later rung is the workshop's (`upgrade(for:on:)`),
//  which refuses a tier-1 weapon as `.notLearned` instead of selling it. "Has
//  learned" is derived — the weapon is tier 2 or more — so no column records it.
//

import Fluent
import Foundation

public enum WeaponUpgradeService {

    public enum UpgradeResult: Sendable {
        case success(newTier: Int, outputItemId: String)
        /// Weapon is already at the highest tier defined in `WeaponUpgradeCatalog`.
        case maxTierReached(tier: Int)
        /// The next tier opens at a player level the player has not reached.
        case levelTooLow(required: Int, current: Int)
        /// The workshop met a tier-1 weapon: the first reforge is the Master's
        /// lesson, never the workshop's.
        case notLearned
        /// The Master met a weapon past tier 1: the lesson is given once.
        case alreadyLearned
        /// Player has no equipped weapon to upgrade. Shouldn't happen in normal
        /// play (registration grants one), but the service stays defensive.
        case noWeaponEquipped
        /// The stores this door draws on can't cover the next tier's cost —
        /// bag + warehouse in the workshop, the bag alone at the Master. Each
        /// missing input is reported individually.
        case missingMaterials(shortages: [CraftingService.Shortage])
        /// The lesson's fee is more than the player carries.
        case notEnoughSilver(have: Int, need: Int)
    }

    /// One reforge in the estate's workshop, for tier 2 → 3 and up.
    @discardableResult
    public static func upgrade(for user: User, on db: any Database) async throws -> UpgradeResult {
        try await reforge(for: user, atMaster: false, on: db)
    }

    /// The Master's lesson: the first reforge, tier 1 → 2, paid with that
    /// rung's materials from the bag plus the lesson's fee.
    @discardableResult
    public static func lesson(for user: User, on db: any Database) async throws -> UpgradeResult {
        try await reforge(for: user, atMaster: true, on: db)
    }

    /// The player's equipped main-hand row — the only weapon either door works
    /// on. Public so the Master's menu can ask whether to offer the lesson
    /// without re-implementing the lookup.
    public static func equippedWeapon(for user: User, on db: any Database) async throws -> InventoryEntry? {
        guard let userId = user.id else { return nil }
        return try await InventoryEntry.query(on: db)
            .filter(\.$user.$id, .equal, userId)
            .filter(\.$equippedSlot, .equal, EquipmentSlot.mainHand.rawValue)
            .first()
    }

    /// True when the Master should offer the lesson: the equipped class weapon
    /// is still tier 1 and its second rung is open at the player's level.
    /// Locked buttons are absent in this game, so a player below the gate sees
    /// no button at all — the King's decree is what tells them when.
    public static func lessonAvailable(for user: User, on db: any Database) async throws -> Bool {
        guard let weapon = try await equippedWeapon(for: user, on: db),
              weapon.tier == 1,
              let gate = WeaponUpgradeCatalog.requiredLevel(for: weapon.itemId, tier: 2) else { return false }
        return user.level >= gate
    }

    /// Order of operations, shared by both doors:
    ///   1. Find the equipped weapon (InventoryEntry with `equipped_slot = mainHand`).
    ///   2. Look up its current tier in the catalog. If it's already at max,
    ///      return `.maxTierReached`.
    ///   3. The door: the Master sells only tier 1 → 2, the workshop only from
    ///      tier 2 up.
    ///   4. Check the next rung's player-level gate.
    ///   5. Snapshot what this door may draw on for every input (and the fee at
    ///      the Master). Any shortfall returns without touching anything.
    ///   6. Drain the inputs — inventory first, warehouse second in the
    ///      workshop, the same policy as CraftingService — and the fee.
    ///   7. Increment the weapon row's `tier`, renew its durability, save it.
    ///   8. EquipmentService.recomputeBonuses + saveAndCache the user.
    private static func reforge(for user: User, atMaster: Bool, on db: any Database) async throws -> UpgradeResult {
        guard let userId = user.id else { return .noWeaponEquipped }

        // 1. Equipped weapon = main-hand row.
        guard let weapon = try await equippedWeapon(for: user, on: db) else { return .noWeaponEquipped }

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

        // 3. The door.
        if atMaster && weapon.tier != 1 { return .alreadyLearned }
        if !atMaster && weapon.tier == 1 { return .notLearned }

        // 4. Player-level gate.
        if user.level < nextStep.requiredPlayerLevel {
            return .levelTooLow(required: nextStep.requiredPlayerLevel, current: user.level)
        }

        // 5. Availability snapshot. The capital has no warehouse, so the Master
        // counts the bag alone — the same number his card shows.
        var shortages: [CraftingService.Shortage] = []
        var snapshot: [String: (inv: Int, wh: Int)] = [:]
        for input in nextStep.inputs {
            let invQty = try await InventoryEntry.totalQuantity(of: input.itemId, for: userId, on: db)
            let whQty  = atMaster ? 0 : try await WarehouseEntry.totalQuantity(of: input.itemId, for: userId, on: db)
            snapshot[input.itemId] = (invQty, whQty)
            let total = invQty + whQty
            if total < input.quantity {
                shortages.append(CraftingService.Shortage(itemId: input.itemId, need: input.quantity, have: total))
            }
        }
        if !shortages.isEmpty {
            return .missingMaterials(shortages: shortages)
        }
        let fee = atMaster ? MasterCatalog.weaponLessonSilver : 0
        if user.silver < fee {
            return .notEnoughSilver(have: user.silver, need: fee)
        }

        // 6. Drain — inventory first, warehouse for the shortfall — and the fee.
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
        user.silver -= fee

        // 7. Bump the tier on the same row — this is the entire "the weapon
        // grew up" mutation. Item id never changes. Reforging to a higher tier
        // raises its durability ceiling and renews it to full (a freshly
        // tempered weapon is pristine).
        weapon.tier = nextTier
        weapon.maxDurability = WeaponUpgradeCatalog.durability(forTier: nextTier)
        weapon.durability = weapon.maxDurability
        try await weapon.save(on: db)

        // 8. Recompute cached gear bonuses so combat / profile pick up the
        // new stats on the next read; the save carries the fee with it.
        try await EquipmentService.recomputeBonuses(for: user, on: db)
        try await user.saveAndCache(in: db)

        return .success(newTier: nextTier, outputItemId: weapon.itemId)
    }
}
