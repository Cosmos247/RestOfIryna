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

    /// The durability a fresh piece of `itemId` starts at — the one question
    /// every reader of it asks: the row a purchase or a grant creates
    /// (`GearState.fresh(for:)`), the Master's repair price, and what the
    /// workshop gives back for a piece taken apart.
    ///  • A laddered weapon → its ladder's tier-1 durability
    ///    (`durabilityByTier`); an upgrade moves it from there.
    ///  • Any other piece a fight wears → its own `maxDurability` in
    ///    `items.json`, which the validator demands.
    ///  • Anything else → 0: nothing wears it, so it has no durability.
    ///
    /// Until 2026-10-05 this was one number for every row,
    /// `economy.gear.maxDurabilityStart` = 30, and the class weapon was stamped
    /// with it too — right only because its tier 1 was also 30. Raising the
    /// Forester set to 50 would have handed a new player a 50/50 sword that
    /// dropped to 40/40 at its first reforge.
    public static func startingDurability(for itemId: String) -> Int {
        if WeaponUpgradeCatalog.isUpgradable(itemId) {
            return WeaponUpgradeCatalog.durability(forTier: 1)
        }
        return ItemCatalog.find(itemId)?.maxDurability ?? 0
    }

    /// Each repair permanently shaves this off an armour piece's max, so armor
    /// eventually wears out and must be rebought from the Master.
    public static var repairMaxShave: Int { Catalogs.current.tuningEconomy.gear.repairMaxShave }
    /// Share of the recipe a piece at full max returns when taken apart at the
    /// workshop — see `SalvageMath` for how wear scales it down.
    public static var salvageFraction: Double { Catalogs.current.tuningEconomy.gear.salvageFraction }

    /// Equipment slots that carry durability. Armor (4 slots) plus the main-hand
    /// weapon. `durableSlots` is the full set that wears in a fight; `armorSlots`
    /// stays separate because armor and weapons differ at 0 (broken vs −50%) and
    /// in repair rules (max shave vs none). Read off `EquipmentSlot` since
    /// 2026-10-05, because the validator now asks the same question.
    public static let armorSlots: Set<String> = Set(EquipmentSlot.allCases.filter(\.isArmor).map(\.rawValue))
    public static let weaponSlots: Set<String> = [EquipmentSlot.mainHand.rawValue]
    public static let durableSlots: Set<String> = Set(EquipmentSlot.allCases.filter(\.isDurable).map(\.rawValue))

    /// A single fight's wear *budget* (model C — distributed across equipped
    /// armor point-by-point, not charged per piece). Victory < defeat < flee —
    /// running away drags the gear through the brush hardest.
    public enum WearEvent: String, CaseIterable, Sendable {
        case victory
        case defeat
        case flee

        public var amount: Int {
            let budget = Catalogs.current.tuningEconomy.gear.wearBudget
            switch self {
            case .victory: return budget.victory
            case .defeat:  return budget.defeat
            case .flee:    return budget.flee
            }
        }
    }

    /// A piece that reached zero in one call: its id AND the tier of the ROW
    /// that broke. The tier is half the name — a T3 sword announced from the
    /// catalog reads «Іржавий меч» to a player holding «Очищений меч», which is
    /// the defect the equip banner had on 2026-09-17. An id alone cannot name
    /// a row, so the id alone does not leave this service.
    public struct BrokenPiece: Sendable, Equatable {
        public let itemId: String
        public let tier: Int
        public init(itemId: String, tier: Int) {
            self.itemId = itemId
            self.tier = tier
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
    ///
    /// Returns the pieces that reached 0 IN THIS CALL — a piece going broken
    /// is a stat cliff (armour contributes nothing, a weapon halves), and the
    /// screens that spend the wear are the only ones positioned to say so.
    /// Already-broken pieces are not reported again: they are not news.
    @discardableResult
    public static func drainEquippedGear(amount: Int, for user: User, on db: any Database) async throws -> [BrokenPiece] {
        guard amount > 0, let userId = user.id else { return [] }

        let rows = try await InventoryEntry.query(on: db)
            .filter(\.$user.$id, .equal, userId)
            .all()
        // Armor + weapon share one wear pool, so the per-fight budget is split
        // across everything equipped (predictable silver sink regardless of how
        // many durable pieces are worn).
        let gear = rows.filter { $0.equippedSlot.map { durableSlots.contains($0) } == true }
        guard !gear.isEmpty else { return [] }

        // What was still whole when the fight started — the difference is what
        // this call broke.
        let wasIntact = Set(gear.filter { $0.durability > 0 }.compactMap { $0.id })

        var touched: Set<UUID> = []
        for _ in 0..<amount {
            // Only pieces with durability left are eligible; once everything
            // worn is at 0, the remaining budget is simply lost.
            let eligible = gear.indices.filter { gear[$0].durability > 0 }
            guard let pick = eligible.randomElement() else { break }
            gear[pick].durability -= 1
            if let id = gear[pick].id { touched.insert(id) }
        }

        guard !touched.isEmpty else { return [] }
        for row in gear where row.id.map({ touched.contains($0) }) == true {
            try await row.save(on: db)
        }
        try await EquipmentService.recomputeBonuses(for: user, on: db)
        try await user.saveAndCache(in: db)

        return gear.filter { $0.durability <= 0 && $0.id.map({ wasIntact.contains($0) }) == true }
                   .map { BrokenPiece(itemId: $0.itemId, tier: $0.tier) }
    }

    /// Convenience for a single fight outcome. Carries the broken-this-fight
    /// list out to the caller for the same reason `drainEquippedGear` does.
    @discardableResult
    public static func wear(_ event: WearEvent, for user: User, on db: any Database) async throws -> [BrokenPiece] {
        try await drainEquippedGear(amount: event.amount, for: user, on: db)
    }

    /// One-shot, idempotent startup backfill: weapon rows created before the
    /// per-tier durability table existed carry the generic `max = 30` that
    /// `InventoryEntry.init` stamped on every row then (a fresh weapon reads its
    /// ladder since 2026-10-05). Raise any under-provisioned weapon's max to its
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
