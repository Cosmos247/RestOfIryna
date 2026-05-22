//
//  GearConditionService.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 21.05.2026.
//
//  Phase 6.5 — armor durability runtime. Equipped armor wears down with every
//  fight (more on a loss, most on a flee) and is restored at the Master for
//  silver (see `MasterService` + `MasterCatalog`). At 0 durability a piece is
//  "broken" and contributes no stats until repaired — that check + the
//  permanent enchant bonus both live in `EquipmentService.recomputeBonuses`.
//
//  Both armor and the main-hand weapon wear here. Armor at 0 goes "broken"
//  (0 stats); the weapon at 0 keeps HALF its stats (lore: the King's weapon
//  can't truly break) — both behaviours live in `EquipmentService`. Off-hand /
//  accessories never drain.
//

import Fluent
import Foundation

public enum GearConditionService {

    /// Durability a fresh piece starts (and is repaired back) to. Each repair
    /// permanently shaves `repairMaxShave` off the piece's max, so armor
    /// eventually wears out and must be rebought from the Master.
    /// (30 for now — tuned for a felt repair cadence vs the −1/−3/−5 drain.)
    public static let maxDurabilityStart = 30
    public static let repairMaxShave = 1

    /// Equipment slots that carry durability. Armor (4 slots) plus the main-hand
    /// weapon. `durableSlots` is the full set that wears in a fight; `armorSlots`
    /// stays separate because armor and weapons differ at 0 (broken vs −50%) and
    /// in repair rules (max shave vs none).
    public static let armorSlots: Set<String> = ["helmet", "chest", "legs", "boots"]
    public static let weaponSlots: Set<String> = [EquipmentSlot.mainHand.rawValue]
    public static let durableSlots: Set<String> = armorSlots.union(weaponSlots)

    /// A single fight's wear *budget* (model C — distributed across equipped
    /// armor point-by-point, not charged per piece). Victory < defeat < flee —
    /// running away drags the gear through the brush hardest.
    public enum WearEvent: Sendable {
        case victory
        case defeat
        case flee

        public var amount: Int {
            switch self {
            case .victory: return 1
            case .defeat:  return 3
            case .flee:    return 5
            }
        }
    }

    /// Spend a fight's wear budget across equipped armor. Model C: `amount` is
    /// a fixed per-fight budget (not per-piece), distributed one point at a time
    /// to a randomly-chosen equipped piece that still has durability left. This
    /// keeps the silver sink predictable (independent of how many pieces are
    /// worn), wears the set down gradually (no synchronized "whole set breaks at
    /// once" cliff), and a piece hitting 0 goes "broken" (0 stats) until repaired.
    /// No-op when amount ≤ 0 or nothing armored is worn. We recompute bonuses +
    /// persist here so the durability rows and recomputed stats land together.
    public static func drainEquippedGear(amount: Int, for user: User, on db: any Database) async throws {
        guard amount > 0, let userId = user.id else { return }

        let rows = try await InventoryEntry.query(on: db)
            .filter(\.$user.$id, .equal, userId)
            .all()
        // Armor + weapon share one wear pool, so the per-fight budget is split
        // across everything equipped (predictable silver sink regardless of how
        // many durable pieces are worn).
        let gear = rows.filter { $0.equippedSlot.map { durableSlots.contains($0) } == true }
        guard !gear.isEmpty else { return }

        var touched: Set<UUID> = []
        for _ in 0..<amount {
            // Only pieces with durability left are eligible; once everything
            // worn is at 0, the remaining budget is simply lost.
            let eligible = gear.indices.filter { gear[$0].durability > 0 }
            guard let pick = eligible.randomElement() else { break }
            gear[pick].durability -= 1
            if let id = gear[pick].id { touched.insert(id) }
        }

        guard !touched.isEmpty else { return }
        for row in gear where row.id.map({ touched.contains($0) }) == true {
            try await row.save(on: db)
        }
        try await EquipmentService.recomputeBonuses(for: user, on: db)
        try await user.saveAndCache(in: db)
    }

    /// Convenience for a single fight outcome.
    public static func wear(_ event: WearEvent, for user: User, on db: any Database) async throws {
        try await drainEquippedGear(amount: event.amount, for: user, on: db)
    }

    /// One-shot, idempotent startup backfill: weapon rows created before the
    /// per-tier durability table existed carry the generic `max = 30` from
    /// `InventoryEntry.init`. Raise any under-provisioned weapon's max to its
    /// tier value, preserving the missing amount (a full 30/30 T5 becomes
    /// 100/100; a worn 20/30 becomes 90/100). Acts only when `max < tier value`,
    /// so re-running never refills a legitimately worn weapon. Bonuses depend on
    /// `durability > 0`, not max, so no recompute is needed here.
    public static func backfillWeaponDurability(on db: any Database) async throws {
        let weaponIds = Array(WeaponUpgradeCatalog.progression.keys)
        guard !weaponIds.isEmpty else { return }
        let rows = try await InventoryEntry.query(on: db)
            .filter(\.$itemId ~~ weaponIds)
            .all()
        for row in rows {
            let target = WeaponUpgradeCatalog.durability(forTier: row.tier)
            guard row.maxDurability < target else { continue }
            let gap = target - row.maxDurability
            row.maxDurability = target
            row.durability = min(target, row.durability + gap)
            try await row.save(on: db)
        }
    }
}
