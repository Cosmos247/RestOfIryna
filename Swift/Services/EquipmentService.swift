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

        var atk = 0, def = 0, hp = 0, crit = 0, dodge = 0, acc = 0
        for row in rows where row.equippedSlot != nil {
            let s = contributedStats(of: row, for: user)
            atk += s.attack; def += s.defense; hp += s.hp
            crit += s.crit; dodge += s.dodge; acc += s.accuracy
        }
        // MARK: Second pass — set bonuses (Phase 6)
        //
        // A separate pass because a set bonus is a property of the OUTFIT, not
        // of any one piece: it cannot be known until every equipped row has been
        // counted. Flat bonuses land first and multipliers second, so two sets
        // can never end up multiplying each other's flats in whatever order the
        // rows happened to come back from the database.
        var wornPerSet: [String: Int] = [:]
        for row in rows where row.equippedSlot != nil {
            guard let setId = ItemCatalog.find(row.itemId)?.setId else { continue }
            wornPerSet[setId, default: 0] += 1
        }
        var multiplier = 1.0
        // Sorted: a dictionary iterates in seeded-hash order, and two sets each
        // granting a multiplier would otherwise compose in a different order
        // between processes.
        for setId in wornPerSet.keys.sorted() {
            guard let worn = wornPerSet[setId], let set = GearSetCatalog.find(setId) else { continue }
            for bonus in set.bonuses where bonus.pieces <= worn {
                switch bonus.effect {
                case .flatStats(let stats):
                    atk += stats.attack; def += stats.defense; hp += stats.hp
                    crit += stats.crit; dodge += stats.dodge; acc += stats.accuracy
                case .gearMultiplier(let factor):
                    multiplier *= factor
                }
            }
        }
        if multiplier != 1.0 {
            func scale(_ value: Int) -> Int { Int((Double(value) * multiplier).rounded()) }
            atk = scale(atk); def = scale(def); hp = scale(hp)
            crit = scale(crit); dodge = scale(dodge); acc = scale(acc)
        }

        user.gearHpBonus       = hp
        user.gearAttackBonus   = atk
        user.gearDefenseBonus  = def
        user.gearCritBonus     = crit
        user.gearDodgeBonus    = dodge
        user.gearAccuracyBonus = acc

        // Taking off an HP piece lowers the ceiling, so current HP has to come
        // down with it — otherwise the bar reads 140/120 and every "is the
        // player full?" check answers wrong forever after.
        user.hp = Swift.min(user.hp, user.effectiveMaxHp)
    }

    /// Full-condition stats of a gear row: its tier/base `GearStats` scaled by
    /// the enchant multiplier. No durability penalty applied — this is what the
    /// piece grants at full condition (used by the inventory detail card).
    /// Tiered weapons read the per-tier table; T1 equals `Item.gearStats`.
    /// Returns zeroes for non-gear / unknown items.
    ///
    /// Phase 6 changed what an enchant IS. It used to add flat points to DEF
    /// plus a class-identity stat; it now scales the item's OWN stats by
    /// `1 + 4% × level`. A flat bonus has no workable size — the same +32 DEF
    /// is 267% of a level-1 chest and 14% of a level-40 one — and scaling the
    /// item keeps its profile intact instead of bending every piece toward the
    /// wearer's class.
    ///
    /// The class-identity flavour moves to sets, where it can be expressed
    /// without distorting the budget of the piece it sits on.
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
        guard row.enchantLevel > 0 else { return base }
        return base.scaled(by: MasterCatalog.enchantMultiplier(level: row.enchantLevel))
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
        return n.scaled(by: 0.5)
    }
}
