//
//  ClampWeaponTiersToLevel.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 04.10.2026.
//
//  2026-10-04, `spec-items.md` §9: the weapon ladder follows the PLAYER level.
//  Under the old rule the estate opened tier N at T N, so a tester at level 10
//  and estate T4 could hold tier 4. Under the new ladder level 10 opens tier 3.
//  On the owner's call everyone stands in the same conditions: every row of
//  the three class weapons — worn, in the bag or in the warehouse — comes down
//  to the highest tier its owner's level allows.
//  - Its maximum durability follows the tier, and current durability is capped
//    at it. The enchant stays.
//  - The removed rungs are refunded in silver, at the trader's buy price of
//    their recipes. Those recipes are today's at the same positions, because
//    the ladder kept tiers 2–5 by position.
//
//  The rule is `WeaponUpgradeCatalog.highestTier` and the refund is
//  `WeaponLadderRules.refundSilver` — the same code the workshop and the tests
//  run. Both read the content loaded on this boot, so boot the Pi with the new
//  `content/data` first; a Mac run through the tunnel would spend the
//  migration against whatever the Mac has loaded.
//
//  The class weapon is bound: no trade or market takes it, and the warehouse
//  refuses it (`WarehouseService.deposit`), so in practice every row is worn or
//  in the bag. The warehouse is scanned anyway, because that refusal is a rule
//  that could change and this runs once. Verify the TABLE
//  afterwards, not the log line — this reads 0 rows:
//  `SELECT u.nickname, u.level, i.item_id, i.tier FROM inventory i JOIN users u
//  ON u.id = i.user_id WHERE i.item_id IN ('gear.rusty_sword','gear.simple_bow',
//  'gear.wooden_staff') AND i.tier > LEAST(9, CASE WHEN u.level >= 5 THEN
//  u.level / 5 + 1 ELSE 1 END)` — and the same against `warehouse`.
//

import Fluent
import Foundation
import SQLKit

struct ClampWeaponTiersToLevel: AsyncMigration {
    enum ClampError: Error { case notSQL(driver: String) }

    private struct Row: Decodable {
        let id: UUID
        let user_id: UUID
        let item_id: String
        let tier: Int
        let durability: Int
        let level: Int
    }

    func prepare(on database: any Database) async throws {
        // `throw`, not `return`, for `ResetDeepestKm`'s reason: skipping this
        // records it as done while the rows it exists for stay above their gate.
        guard let sql = database as? any SQLDatabase else {
            throw ClampError.notSQL(driver: "\(type(of: database))")
        }
        let ladderIds = WeaponUpgradeCatalog.progression.keys.sorted()
        guard !ladderIds.isEmpty else { return }
        let idList = ladderIds.map { "'\($0)'" }.joined(separator: ",")
        var refunds: [UUID: Int] = [:]

        for table in ["inventory", "warehouse"] {
            let rows = try await sql.raw("""
                SELECT t.id, t.user_id, t.item_id, t.tier, t.durability, u.level
                FROM \(unsafeRaw: table) t JOIN users u ON u.id = t.user_id
                WHERE t.item_id IN (\(unsafeRaw: idList))
                """).all(decoding: Row.self)
            for row in rows {
                let allowed = WeaponUpgradeCatalog.highestTier(for: row.item_id, atLevel: row.level)
                guard row.tier > allowed else { continue }
                let steps = WeaponUpgradeCatalog.progression[row.item_id] ?? []
                let refund = WeaponLadderRules.refundSilver(
                    inputsByTier: steps.map { $0.inputs.map { (itemId: $0.itemId, quantity: $0.quantity) } },
                    fromTier: row.tier, toTier: allowed,
                    price: { itemId in
                        guard let listing = TraderCatalog.find(itemId), listing.buyPacketQty > 0 else { return 0 }
                        return listing.buyPacketSilver / listing.buyPacketQty
                    })
                let maxDurability = WeaponUpgradeCatalog.durability(forTier: allowed)
                try await sql.raw("""
                    UPDATE \(unsafeRaw: table)
                    SET tier = \(bind: allowed), max_durability = \(bind: maxDurability),
                        durability = \(bind: min(row.durability, maxDurability))
                    WHERE id = \(bind: row.id)
                    """).run()
                refunds[row.user_id, default: 0] += refund
                database.logger.info("ClampWeaponTiersToLevel: \(table) \(row.item_id) of \(row.user_id) at level \(row.level): T\(row.tier) → T\(allowed), refund \(refund) silver")
            }
        }
        for (userId, silver) in refunds where silver > 0 {
            try await sql.raw("UPDATE users SET silver = silver + \(bind: silver) WHERE id = \(bind: userId)").run()
        }
        database.logger.info("ClampWeaponTiersToLevel: \(refunds.count) player(s) clamped, \(refunds.values.reduce(0, +)) silver refunded")
    }

    func revert(on database: any Database) async throws {
        // Nothing to restore — the tiers each row held are not kept, and the
        // refund already paid for them.
    }
}
