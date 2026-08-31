//
//  PlotService.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 29.04.2026.
//
//  Phase 5.1 plot helpers. Pure functions: production accumulation is
//  computed lazily from `Plot.lastHarvestedAt + ratePerSecond × elapsed`,
//  capped at the type's capacity. Harvest moves the accumulated amount into
//  the player's inventory, resets the timestamp, and clears the
//  `notifiedFull` flag so the background ticker can pick the plot up again.
//
//  `slotsForLevel(_:)` reads the ladder from `estate_upgrades.json` — 0 slots
//  at T1, then one more per tier to 6 at T7. (This header described a
//  pre-5.3c design of "2 / 3 / 4 / 5 / 5 / 6 / 6, +1 every 4 levels" and a
//  "flat 5 override" for three phases after the code stopped doing any of
//  that; it was corrected in 8E, when the ladder became the daily Vigor
//  budget and therefore worth reading twice.)
//

import Fluent
import Foundation

public enum PlotService {

    // MARK: - Slot count

    /// How many plot slots are unlocked at the given estate level.
    ///
    /// T1 has zero plots — the wooden hut has cleared no land yet — and the
    /// first opens at T2 (player level 4), one more per tier to 6 at T7. The
    /// table lives in `estate_upgrades.json` since Phase 8E: with Vigor no
    /// longer regenerating these slots are the player's daily budget, and a
    /// balance number that important cannot sit in a Swift literal the
    /// simulator has no way to read.
    ///
    /// Estates past the table's last entry get its final value, so the
    /// function stays total if the tier ladder ever extends. Existing players
    /// who have claimed plots beyond their current allowance keep them: the
    /// allowance only gates *new* claims via `claim(...)`, not the list
    /// returned by `Plot.list(...)`.
    public static func slotsForLevel(_ estateLevel: Int) -> Int {
        let table = EstateUpgradeCatalog.plotSlotsByTier
        guard let last = table.last else { return 0 }
        let idx = max(0, estateLevel - 1)
        return idx < table.count ? table[idx] : last
    }

    // MARK: - Production math

    /// Accumulated yield since `lastHarvestedAt`, capped at the type's capacity.
    /// Pure function — no DB writes. Returns 0 for unknown types.
    public static func accumulated(for plot: Plot, at now: Date = Date()) -> Int {
        guard let tuning = PlotCatalog.tuning(forRaw: plot.plotType, tier: plot.tier) else { return 0 }
        return accumulated(rate: tuning.ratePerInterval, capacity: tuning.capacity, since: plot.lastHarvestedAt, at: now)
    }

    /// Accumulated bonus yield since `lastHarvestedAt`, capped at the bonus
    /// capacity. Returns 0 if the plot type has no `bonusOutput`. Same time
    /// math as the primary — both share `lastHarvestedAt`.
    public static func bonusAccumulated(for plot: Plot, at now: Date = Date()) -> Int {
        guard let tuning = PlotCatalog.tuning(forRaw: plot.plotType, tier: plot.tier),
              let bonus = tuning.bonusOutput else { return 0 }
        return accumulated(rate: bonus.ratePerInterval, capacity: bonus.capacity, since: plot.lastHarvestedAt, at: now)
    }

    private static func accumulated(rate: Int, capacity: Int, since: Date, at now: Date) -> Int {
        let elapsed = max(0, now.timeIntervalSince(since))
        let perSecond = Double(rate) / PlotCatalog.intervalSeconds
        let raw = Int((elapsed * perSecond).rounded(.down))
        return min(capacity, raw)
    }

    /// True when the plot has reached its cap.
    public static func isFull(_ plot: Plot, at now: Date = Date()) -> Bool {
        guard let tuning = PlotCatalog.tuning(forRaw: plot.plotType, tier: plot.tier) else { return false }
        return accumulated(for: plot, at: now) >= tuning.capacity
    }

    // MARK: - Harvest

    /// One harvest yields a primary item and (optionally) a bonus item.
    /// Both are surfaced in the success case so UI can render a combined
    /// status line like "✅ Slot 3 — +35 🪨, +3 🔩".
    public struct HarvestYield: Sendable {
        public let itemId: String
        public let amount: Int
    }

    /// Where the controller wants this harvest to land. Warehouse is
    /// uncapped; bag has slot-cap enforcement (with the usual dev bypass).
    public enum HarvestDestination: Sendable {
        case bag
        case warehouse
    }

    public enum HarvestResult: Sendable {
        case empty                                                                // nothing to take
        case success(primary: HarvestYield, bonus: HarvestYield?, destination: HarvestDestination)
        /// Bag was the destination but the per-unit slot cap would have been
        /// exceeded. Plot timestamp NOT reset — the yield stays on the plot
        /// so the player can free a slot or retry with warehouse.
        case bagFull(primary: HarvestYield, bonus: HarvestYield?, free: Int, need: Int)
    }

    /// Move accumulated yield into the player's chosen destination — bag
    /// (capped) or warehouse (uncapped). On success resets `lastHarvestedAt
    /// = now` and `notifiedFull = false`. If the bag can't fit the full
    /// haul, returns `.bagFull` without touching the plot or moving any
    /// items (atomic — partial deposits would be confusing). Caller doesn't
    /// need to do extra saves — this method persists rows + the plot row
    /// at its own level. If the plot type carries a `bonusOutput` (Mine →
    /// iron), the bonus is also transferred when its accumulator is non-zero.
    @discardableResult
    public static func harvest(_ plot: Plot, to destination: HarvestDestination, for user: User, on db: any Database) async throws -> HarvestResult {
        guard let tuning = PlotCatalog.tuning(forRaw: plot.plotType, tier: plot.tier) else { return .empty }
        let primaryAmount = accumulated(for: plot)
        let bonusAmount = bonusAccumulated(for: plot)
        guard primaryAmount > 0 || bonusAmount > 0 else { return .empty }

        let primaryYield = HarvestYield(itemId: tuning.producedItemId, amount: primaryAmount)
        var bonusYield: HarvestYield? = nil
        if let bonus = tuning.bonusOutput, bonusAmount > 0 {
            bonusYield = HarvestYield(itemId: bonus.producedItemId, amount: bonusAmount)
        }

        switch destination {
        case .warehouse:
            if primaryAmount > 0 {
                try await WarehouseEntry.add(tuning.producedItemId, quantity: primaryAmount, to: user, on: db)
            }
            if let bonus = tuning.bonusOutput, bonusAmount > 0 {
                try await WarehouseEntry.add(bonus.producedItemId, quantity: bonusAmount, to: user, on: db)
            }
        case .bag:
            // Atomic preflight — bag is per-unit capped, so a partial yield
            // landing would leave the player with a half-harvested plot AND
            // a full bag, which is the worst of both worlds. Better to bail
            // and let them empty a slot or pick warehouse.
            let totalToAdd = primaryAmount + bonusAmount
            let used = try await InventoryEntry.slotsUsed(for: user, on: db)
            let cap = InventoryEntry.slotCap(for: user)
            let free = max(0, cap - used)
            if !user.isDeveloper, free < totalToAdd {
                return .bagFull(primary: primaryYield, bonus: bonusYield, free: free, need: totalToAdd)
            }
            if primaryAmount > 0 {
                try await InventoryEntry.add(tuning.producedItemId, quantity: primaryAmount, to: user, on: db)
            }
            if let bonus = tuning.bonusOutput, bonusAmount > 0 {
                try await InventoryEntry.add(bonus.producedItemId, quantity: bonusAmount, to: user, on: db)
            }
        }

        plot.lastHarvestedAt = Date()
        plot.notifiedFull = false
        try await plot.save(on: db)
        return .success(primary: primaryYield, bonus: bonusYield, destination: destination)
    }

    // MARK: - Claim

    public enum ClaimResult: Sendable {
        case slotOutOfRange    // slot >= slotsForLevel(user.estateLevel)
        case slotTaken         // user already has a plot at that slot
        case success(Plot)
    }

    /// Claim an empty slot for `type`. Slot index must be within the user's
    /// estate-level allowance (`slotsForLevel`). Tier defaults to 1.
    @discardableResult
    public static func claim(slot: Int, type: PlotType, for user: User, on db: any Database) async throws -> ClaimResult {
        let allowance = slotsForLevel(user.estateLevel)
        guard slot >= 0, slot < allowance else { return .slotOutOfRange }
        guard let userId = user.id else { return .slotOutOfRange }
        if let _ = try await Plot.find(slot: slot, for: user, on: db) {
            return .slotTaken
        }
        let plot = Plot(userID: userId, slotIndex: slot, plotType: type.rawValue, tier: 1, lastHarvestedAt: Date())
        try await plot.save(on: db)
        return .success(plot)
    }

}
