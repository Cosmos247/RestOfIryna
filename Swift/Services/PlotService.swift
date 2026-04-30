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
//  The `slotsForLevel(_:)` table is logarithmic: 2 / 3 / 4 / 5 / 5 / 6 / 6 …
//  with +1 every 4 levels past the explicit table. Estate level itself is
//  derived from `User.estateLevel` (`User.level / 5`) at MVP; will switch to
//  the new XP-to-Estate model once Phase 5.x lands.
//

import Fluent
import Foundation

public enum PlotService {

    // MARK: - Slot count

    /// Hardcoded logarithmic slot table: index = estate level - 1.
    /// Past the table's last entry, +1 slot every 4 estate levels.
    /// Currently OVERRIDDEN below to a flat 5 slots while estate-progression
    /// design is in flux — restore the table once the level system lands.
    private static let slotTable: [Int] = [2, 3, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9, 9, 10, 10, 11]

    /// How many plot slots are unlocked at the given estate level.
    /// **Temporary:** every player has 5 slots open from estate level 1 so
    /// the full plot roster (incl. Training Ground) is reachable for testing.
    /// Final formula will follow `slotTable` once XP-to-Estate progression
    /// lands in Phase 5.x.
    public static func slotsForLevel(_ estateLevel: Int) -> Int {
        return 5
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

    public enum HarvestResult: Sendable {
        case empty                                                      // nothing to take
        case success(primary: HarvestYield, bonus: HarvestYield?)
    }

    /// Move accumulated yield into the player's WAREHOUSE (not the
    /// backpack). On success resets `lastHarvestedAt = now` and
    /// `notifiedFull = false`. Caller doesn't need to do extra saves —
    /// this method persists the warehouse rows + the plot row at its own
    /// level. Returns a typed result so the controller can branch on empty
    /// vs success. If the plot type carries a `bonusOutput` (Mine → iron),
    /// the bonus is also transferred when its accumulator is non-zero.
    /// **Why warehouse, not inventory?** Plot output piles up over hours;
    /// landing it in the 50-slot bag would constantly fill it. The
    /// warehouse has no slot cap, so no `.bagFull` branch is needed.
    @discardableResult
    public static func harvest(_ plot: Plot, for user: User, on db: any Database) async throws -> HarvestResult {
        guard let tuning = PlotCatalog.tuning(forRaw: plot.plotType, tier: plot.tier) else { return .empty }
        let primaryAmount = accumulated(for: plot)
        let bonusAmount = bonusAccumulated(for: plot)
        guard primaryAmount > 0 || bonusAmount > 0 else { return .empty }

        if primaryAmount > 0 {
            try await WarehouseEntry.add(tuning.producedItemId, quantity: primaryAmount, to: user, on: db)
        }
        var bonusYield: HarvestYield? = nil
        if let bonus = tuning.bonusOutput, bonusAmount > 0 {
            try await WarehouseEntry.add(bonus.producedItemId, quantity: bonusAmount, to: user, on: db)
            bonusYield = HarvestYield(itemId: bonus.producedItemId, amount: bonusAmount)
        }

        plot.lastHarvestedAt = Date()
        plot.notifiedFull = false
        try await plot.save(on: db)
        let primaryYield = HarvestYield(itemId: tuning.producedItemId, amount: primaryAmount)
        return .success(primary: primaryYield, bonus: bonusYield)
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

    /// Convenience — does the user have any plots? Used by the registration
    /// flow to decide whether to auto-grant a starter farm.
    public static func hasAnyPlot(for user: User, on db: any Database) async throws -> Bool {
        guard let userId = user.id else { return false }
        let count = try await Plot.query(on: db).filter(\.$user.$id, .equal, userId).count()
        return count > 0
    }
}
