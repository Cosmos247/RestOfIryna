//
//  EquipmentService.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 21.04.2026.
//
//  Pure service for equip / unequip flows. Unlike VigorService, this one does
//  touch the DB — an equip operation spans multiple rows (unequip the previous
//  occupant of a slot, flip the new one, recompute cached bonuses on User) —
//  so the service owns those writes atomically per-step. Callers still drive
//  UI updates and session cache refresh themselves.
//

import Fluent
import Foundation

public enum EquipmentService {

    // MARK: - Read

    /// All currently equipped inventory rows for the user, keyed by slot. Rows
    /// referencing a catalog entry that no longer exists, or rows with an invalid
    /// slot string, are silently skipped.
    public static func equipped(for user: User, on db: any Database) async throws -> [EquipmentSlot: InventoryEntry] {
        guard let userId = user.id else { return [:] }
        let rows = try await InventoryEntry.query(on: db)
            .filter(\.$user.$id, .equal, userId)
            .all()
        var result: [EquipmentSlot: InventoryEntry] = [:]
        for row in rows {
            guard let slotRaw = row.equippedSlot,
                  let slot = EquipmentSlot(rawValue: slotRaw) else { continue }
            result[slot] = row
        }
        return result
    }

    // MARK: - Equip / Unequip

    /// Equip an inventory row. If another row already occupies the target slot
    /// it is unequipped first. Recomputes `user.gear*Bonus` and saves the user
    /// (via `saveAndCache`) and all touched inventory rows.
    public static func equip(_ entry: InventoryEntry, for user: User, on db: any Database) async throws {
        guard let userId = user.id else { return }
        guard let item = ItemCatalog.find(entry.itemId), let slot = item.slot else { return }

        let allRows = try await InventoryEntry.query(on: db)
            .filter(\.$user.$id, .equal, userId)
            .all()

        // Clear any previous occupants of this slot (covers the normal "swap" case
        // and also any stray duplicates that shouldn't exist but might).
        for row in allRows where row.equippedSlot == slot.rawValue && row.id != entry.id {
            row.equippedSlot = nil
            try await row.save(on: db)
        }

        entry.equippedSlot = slot.rawValue
        try await entry.save(on: db)

        try await recomputeBonuses(for: user, on: db)
        try await user.saveAndCache(in: db)
    }

    /// Unequip a specific inventory row. No-op if the row isn't currently equipped.
    public static func unequip(_ entry: InventoryEntry, for user: User, on db: any Database) async throws {
        guard entry.equippedSlot != nil else { return }
        entry.equippedSlot = nil
        try await entry.save(on: db)

        try await recomputeBonuses(for: user, on: db)
        try await user.saveAndCache(in: db)
    }

    // MARK: - Bonus Aggregation

    /// Sum the GearStats of every currently-equipped item into the user's cached
    /// `gear*Bonus` fields. Mutates `user` in place; caller is responsible for
    /// persisting (the equip/unequip helpers above already do).
    public static func recomputeBonuses(for user: User, on db: any Database) async throws {
        guard let userId = user.id else { return }
        let rows = try await InventoryEntry.query(on: db)
            .filter(\.$user.$id, .equal, userId)
            .all()

        var atk = 0, def = 0, crit = 0, dodge = 0, acc = 0
        for row in rows where row.equippedSlot != nil {
            let s = contributedStats(of: row, for: user)
            atk += s.attack; def += s.defense; crit += s.crit; dodge += s.dodge; acc += s.accuracy
        }
        user.gearAttackBonus   = atk
        user.gearDefenseBonus  = def
        user.gearCritBonus     = crit
        user.gearDodgeBonus    = dodge
        user.gearAccuracyBonus = acc
    }

    /// Full-condition stats of a gear row: its tier/base `GearStats` plus the
    /// armor enchant bonus — a flat +DEF scaled by the non-linear
    /// `MasterCatalog.enchantBonusPoints` curve, PLUS a class-identity stat
    /// (⚔️ warrior +DEF, 🏹 archer +dodge, 🔮 mage +crit). No durability penalty
    /// applied — this is what the piece grants at full condition (used by the
    /// inventory detail card). Tiered weapons read the per-tier table; T1 equals
    /// the legacy `Item.gearStats`. Returns zeroes for non-gear / unknown items.
    public static func nominalStats(of row: InventoryEntry, for user: User) -> GearStats {
        guard let item = ItemCatalog.find(row.itemId) else { return GearStats() }
        let base: GearStats
        if let tierStats = WeaponUpgradeCatalog.stats(for: item.id, tier: row.tier) {
            base = tierStats
        } else if let s = item.gearStats {
            base = s
        } else {
            return GearStats()
        }
        let isArmor = item.slot.map { GearConditionService.armorSlots.contains($0.rawValue) } == true
        let points = MasterCatalog.enchantBonusPoints(level: row.enchantLevel)
        guard isArmor, points > 0 else { return base }
        var def = base.defense + points, crit = base.crit, dodge = base.dodge
        switch CharacterClass(rawValue: user.characterClass ?? "") {
        case .warrior: def   += points
        case .archer:  dodge += points
        case .mage:    crit  += points
        case nil:      break
        }
        return GearStats(attack: base.attack, defense: def, crit: crit, dodge: dodge, accuracy: base.accuracy)
    }

    /// What a row actually contributes right now, after durability:
    ///  • armor worn to 0 is "broken" → zero.
    ///  • the weapon at 0 keeps HALF its stats (floored). Lore: the King's
    ///    weapon can't truly break, only dull/slacken until honed.
    /// The single source of truth summed by `recomputeBonuses`.
    public static func contributedStats(of row: InventoryEntry, for user: User) -> GearStats {
        guard let slot = ItemCatalog.find(row.itemId)?.slot else { return GearStats() }
        let isArmor  = GearConditionService.armorSlots.contains(slot.rawValue)
        let isWeapon = GearConditionService.weaponSlots.contains(slot.rawValue)
        if isArmor && row.durability <= 0 { return GearStats() }
        let n = nominalStats(of: row, for: user)
        guard isWeapon && row.durability <= 0 else { return n }
        return GearStats(attack: n.attack / 2, defense: n.defense / 2, crit: n.crit / 2, dodge: n.dodge / 2, accuracy: n.accuracy / 2)
    }
}
