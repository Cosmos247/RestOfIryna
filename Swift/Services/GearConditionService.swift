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
//  Armor-only for now: weapons keep their tier ladder and will gain gem inlay
//  + their own wear in a later phase. The four armor slots are helmet / chest /
//  legs / boots; main-hand / off-hand / accessories never drain here.
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

    /// Equipment slots that carry durability today (armor only).
    public static let armorSlots: Set<String> = ["helmet", "chest", "legs", "boots"]

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
    public static func drainEquippedArmor(amount: Int, for user: User, on db: any Database) async throws {
        guard amount > 0, let userId = user.id else { return }

        let rows = try await InventoryEntry.query(on: db)
            .filter(\.$user.$id, .equal, userId)
            .all()
        let armor = rows.filter { $0.equippedSlot.map { armorSlots.contains($0) } == true }
        guard !armor.isEmpty else { return }

        var touched: Set<UUID> = []
        for _ in 0..<amount {
            // Only pieces with durability left are eligible; once everything
            // worn is broken, the remaining budget is simply lost.
            let eligible = armor.indices.filter { armor[$0].durability > 0 }
            guard let pick = eligible.randomElement() else { break }
            armor[pick].durability -= 1
            if let id = armor[pick].id { touched.insert(id) }
        }

        guard !touched.isEmpty else { return }
        for row in armor where row.id.map({ touched.contains($0) }) == true {
            try await row.save(on: db)
        }
        try await EquipmentService.recomputeBonuses(for: user, on: db)
        try await user.saveAndCache(in: db)
    }

    /// Convenience for a single fight outcome.
    public static func wear(_ event: WearEvent, for user: User, on db: any Database) async throws {
        try await drainEquippedArmor(amount: event.amount, for: user, on: db)
    }
}
