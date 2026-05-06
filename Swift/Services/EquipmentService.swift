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
            guard let item = ItemCatalog.find(row.itemId) else { continue }
            // Tiered weapons (the three class starters in WeaponUpgradeCatalog)
            // pull stats from the per-tier table; everything else falls back
            // to the static `Item.gearStats`. T1 stats match the legacy values
            // exactly, so existing equipped weapons see no numeric change
            // until the player upgrades.
            let stats: GearStats?
            if let tierStats = WeaponUpgradeCatalog.stats(for: item.id, tier: row.tier) {
                stats = tierStats
            } else {
                stats = item.gearStats
            }
            guard let s = stats else { continue }
            atk   += s.attack
            def   += s.defense
            crit  += s.crit
            dodge += s.dodge
            acc   += s.accuracy
        }
        user.gearAttackBonus   = atk
        user.gearDefenseBonus  = def
        user.gearCritBonus     = crit
        user.gearDodgeBonus    = dodge
        user.gearAccuracyBonus = acc
    }
}
