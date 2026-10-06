//
//  MasterService.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 21.05.2026.
//
//  Phase 6.5 — the Master's three actions: buy ready-made armor, repair worn
//  gear (armor or the main-hand weapon), and enchant armor — since 2026-10-06
//  the armour's ladder, gated by its price alone (`spec-items.md` §11).
//  All three drain `User.silver` (the first real silver sink); enchant + repair
//  also touch materials / durability. Pure-ish: owns its DB writes per action
//  and recomputes gear bonuses, mirrors TraderService / WeaponUpgradeService.
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
        /// `tier` travels with the id because the banner names the item, and
        /// for the three upgradable weapons the name is the tier.
        case success(itemId: String, tier: Int, cost: Int, newMax: Int)
        case alreadyFull
        case notEnoughSilver(have: Int, need: Int)
        case notArmor
    }

    public enum EnchantResult: Sendable {
        /// `before` and `after` are the piece's full-condition stats on either
        /// side of the level, so the banner names what the silver bought
        /// without asking the ladder a second time.
        case success(itemId: String, newLevel: Int, before: GearStats, after: GearStats)
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

    /// True when an item id is a main-hand weapon.
    private static func isWeapon(_ itemId: String) -> Bool {
        guard let slot = ItemCatalog.find(itemId)?.slot else { return false }
        return GearConditionService.weaponSlots.contains(slot.rawValue)
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

    /// Repair a worn piece back to full.
    ///   • Armor — permanently shaves 1 off its max (mechanic B), so it slowly
    ///     wears out toward a rebuy; cost scales with the buy price.
    ///   • Weapon — restores to the *same* max (lore: the King's weapon can't
    ///     break, no shave); cost is a flat 1🪙 per durability point, so a full
    ///     repair runs from 30🪙 (T1) up to 180🪙 (T9).
    public static func repair(entryId: UUID, for user: User, on db: any Database) async throws -> RepairResult {
        guard let row = try await ownedRow(entryId, for: user, on: db) else { return .notArmor }
        let weapon = isWeapon(row.itemId)
        guard weapon || isArmor(row.itemId) else { return .notArmor }

        let missing = row.maxDurability - row.durability
        guard missing > 0 else { return .alreadyFull }

        let cost = weapon
            ? MasterCatalog.weaponRepairCost(missing: missing)
            : MasterCatalog.repairCost(itemId: row.itemId, missing: missing)
        if user.silver < cost { return .notEnoughSilver(have: user.silver, need: cost) }

        // Armor sheds 1 max per repair; the weapon keeps its full ceiling.
        let newMax = weapon ? row.maxDurability : max(1, row.maxDurability - GearConditionService.repairMaxShave)
        user.silver -= cost
        row.maxDurability = newMax
        row.durability = newMax
        try await row.save(on: db)
        try await EquipmentService.recomputeBonuses(for: user, on: db)
        try await user.saveAndCache(in: db)
        return .success(itemId: row.itemId, tier: row.tier, cost: cost, newMax: newMax)
    }

    // MARK: - Enchant

    /// Raise an armour piece one level up the enchant ladder for silver +
    /// material, from the BAG alone.
    ///
    /// The enchant is the armour's ladder since 2026-10-06 (`spec-items.md`
    /// §11), and its price is its only gate: there is no player-level check
    /// here on purpose.
    ///
    /// The capital has no warehouse — the rule the Master's weapon lesson was
    /// written on (`WeaponUpgradeService.reforge`). Until 2026-10-05 this counted
    /// the estate's warehouse too and drew from it remotely, so a player with
    /// 0 hides in the bag was told «маєте 14» and could not tell where they were.
    public static func enchant(entryId: UUID, for user: User, on db: any Database) async throws -> EnchantResult {
        guard let userId = user.id else { return .notArmor }
        guard let row = try await ownedRow(entryId, for: user, on: db), isArmor(row.itemId) else {
            return .notArmor
        }
        guard let step = MasterCatalog.enchantStep(currentLevel: row.enchantLevel) else {
            return .maxLevel
        }
        if user.silver < step.silver { return .notEnoughSilver(have: user.silver, need: step.silver) }

        let inBag = try await InventoryEntry.totalQuantity(of: step.materialId, for: userId, on: db)
        if inBag < step.materialQty {
            return .missingMaterials(itemId: step.materialId, have: inBag, need: step.materialQty)
        }
        _ = try await InventoryEntry.remove(step.materialId, quantity: step.materialQty, from: user, on: db)

        let before = EquipmentService.stats(ofItem: row.itemId, tier: row.tier, enchantLevel: row.enchantLevel)
        user.silver -= step.silver
        row.enchantLevel += 1
        try await row.save(on: db)
        try await EquipmentService.recomputeBonuses(for: user, on: db)
        try await user.saveAndCache(in: db)
        let after = EquipmentService.stats(ofItem: row.itemId, tier: row.tier, enchantLevel: row.enchantLevel)
        return .success(itemId: row.itemId, newLevel: row.enchantLevel, before: before, after: after)
    }
}
