//
//  RaiseArmorDurability.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 05.10.2026.
//
//  2026-10-05, `spec-items.md` §10: durability moved onto the item, and the
//  Forester set went from 30 to 50. Every armour row that exists was minted at
//  30 — `economy.gear.maxDurabilityStart`, unchanged from 2026-05-21 until this
//  change — so on the owner's call each one is moved as if it had been bought
//  at its item's new durability and then lived the same life: the maximum AND
//  the current durability both rise by the difference (+20 for the Forester).
//  - A piece repaired 18 times keeps its 18 shaves: 6/12 becomes 26/32.
//  - A piece worn to 0 comes back at 20. Its stats return, which the cached
//    `User.gear*Bonus` cannot see; `EquipmentService.backfillGearBonuses` runs
//    after the migrations on every boot and re-derives them.
//  - The enchant and the tier are not touched.
//
//  It reads the content loaded on this boot — the new durability is each
//  item's `maxDurability` — so boot the Pi with the new `content/data`. A
//  laddered weapon is skipped: its durability is the ladder's and did not move.
//  Rows of an item whose durability is still 30 do not move either.
//
//  Verify the TABLES, not the log line. Run this before the restart and after
//  it; every row should read exactly +20 in both columns:
//  `SELECT u.nickname, 'inv', i.item_id, i.durability, i.max_durability FROM
//  inventory i JOIN users u ON u.id = i.user_id WHERE i.item_id LIKE
//  'gear.forester%' UNION ALL SELECT u.nickname, 'wh', w.item_id, w.durability,
//  w.max_durability FROM warehouse w JOIN users u ON u.id = w.user_id WHERE
//  w.item_id LIKE 'gear.forester%' ORDER BY 1, 2, 3, 5, 4`
//  On 2026-10-05 the Pi held 24 such rows across six players, the lowest
//  maximum 12 and four pieces at 0.
//

import Fluent
import Foundation
import SQLKit

struct RaiseArmorDurability: AsyncMigration {
    enum RaiseError: Error { case notSQL(driver: String) }

    /// What every row this migration touches was minted at — the one
    /// starting durability all armour shared until 2026-10-05.
    static let previousStart = 30

    private struct Moved: Decodable { let id: UUID }

    func prepare(on database: any Database) async throws {
        // `throw`, not `return`, for `ResetDeepestKm`'s reason: skipping this
        // records it as done while the rows it exists for keep the old numbers.
        guard let sql = database as? any SQLDatabase else {
            throw RaiseError.notSQL(driver: "\(type(of: database))")
        }
        // Every piece a fight wears that carries its own durability.
        let shifts: [(itemId: String, by: Int)] = ItemCatalog.all.compactMap { item in
            guard let slot = item.slot, slot.isDurable, let target = item.maxDurability,
                  !WeaponUpgradeCatalog.isUpgradable(item.id) else { return nil }
            let by = target - Self.previousStart
            return by == 0 ? nil : (item.id, by)
        }.sorted { $0.itemId < $1.itemId }

        var total = 0
        for table in ["inventory", "warehouse"] {
            for shift in shifts {
                // Postgres evaluates every SET expression against the OLD row,
                // so `durability` is capped by the new maximum, not the old one.
                // The clamps matter only for a shift below zero, which today's
                // content does not make.
                let moved = try await sql.raw("""
                    UPDATE \(unsafeRaw: table)
                    SET max_durability = GREATEST(1, max_durability + \(bind: shift.by)),
                        durability = LEAST(GREATEST(1, max_durability + \(bind: shift.by)),
                                           GREATEST(0, durability + \(bind: shift.by)))
                    WHERE item_id = \(bind: shift.itemId)
                    RETURNING id
                    """).all(decoding: Moved.self)
                total += moved.count
                if !moved.isEmpty {
                    database.logger.info("RaiseArmorDurability: \(table) \(shift.itemId) \(shift.by > 0 ? "+" : "")\(shift.by) on \(moved.count) row(s)")
                }
            }
        }
        database.logger.info("RaiseArmorDurability: \(total) row(s) moved")
    }

    func revert(on database: any Database) async throws {
        // Nothing to restore — `ClampWeaponTiersToLevel`'s reason: a revert
        // would have to know which pieces were at 0 before, and that is gone.
    }
}
