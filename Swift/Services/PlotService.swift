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
//  `slotsForLevel(_:)` reads the ladder from `estate_upgrades.json` — 1 slot
//  at T1, then one more per tier to 7 at T7; slot 1 is the hazel every estate
//  starts with since 2026-11-01, so the slots a player builds on are still
//  0 … 6 (it read 0 … 6 itself until then). (This header described a
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
    /// T1 has one, and it is not the player's: the wooden hut has cleared no
    /// land yet, but the hazel that grew there before it (2026-11-01) stands in
    /// slot 1 of every estate. The first slot a player builds on opens at T2
    /// (player level 4), one more per tier to 7 slots — 6 built — at T7. The
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
        /// Warehouse was the destination and the estate's per-unit cap would
        /// have been exceeded. Same contract as `bagFull`: nothing moved, the
        /// plot's timestamp untouched, so the whole yield keeps standing where
        /// it grew.
        case warehouseFull(primary: HarvestYield, bonus: HarvestYield?, free: Int, need: Int)
    }

    /// Move accumulated yield into the player's chosen destination. BOTH are
    /// capped: the bag by `InventoryEntry.slotCap`, the warehouse by
    /// `WarehouseService.capForLevel`. The warehouse branch used to write
    /// straight through with no check at all — the estate cap was real
    /// everywhere a player could deposit BY HAND and absent on the one path
    /// that fills the warehouse by itself. On success resets `lastHarvestedAt
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
            // Same atomic preflight the bag has had since Phase 5.1, and for
            // the same reason: a partial haul would leave the player with a
            // half-emptied plot and a full warehouse. The plot keeps the whole
            // yield instead — it goes on accumulating up to its own cap, and
            // nothing is destroyed by a store that had no room.
            //
            // Two streams share one `lastHarvestedAt` (the Mine's pebble and
            // iron), which is the other reason this is all-or-nothing: a
            // partial take cannot be expressed in one timestamp without
            // over- or under-crediting the stream that was not taken.
            let totalToAdd = primaryAmount + bonusAmount
            let used = try await WarehouseService.slotsUsed(for: user, on: db)
            let free = max(0, WarehouseService.capForLevel(user.estateLevel) - used)
            if free < totalToAdd {
                return .warehouseFull(primary: primaryYield, bonus: bonusYield, free: free, need: totalToAdd)
            }
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
        // A harvest leaves nothing behind that can be read later —
        // `lastHarvestedAt` starts at the moment the plot was claimed and is
        // reset by every harvest — so the King's decree has to be told here or
        // never.
        try? await KingService.record(.plotHarvested, for: user, on: db)
        return .success(primary: primaryYield, bonus: bonusYield, destination: destination)
    }

    // MARK: - The plot the estate grants (2026-11-01)

    /// True for the slot the granted plot stands in, while the content grants
    /// one. The claim refuses it whatever stands there: a built plot in it
    /// would leave the hazel with nowhere to stand.
    public static func isReserved(slot: Int) -> Bool {
        slot == GrantedPlot.slotIndex && PlotCatalog.grantedType != nil
    }

    /// Plant the granted plot in its slot if the slot is empty — the hazel every
    /// estate starts with, `spec-progression.md` §8. It is planted RIPE: its
    /// harvest clock is one full fill back, and `notifiedFull` is set, so the
    /// gift waits for the player instead of sending a push. Returns the plot it
    /// planted, or nil when there was nothing to plant (no granted type, a slot
    /// already standing, an account still registering).
    ///
    /// Idempotent, and called from two places: `completeRegistration`, where
    /// the estate is named, and `estatePlots`, which repairs an estate that
    /// lost it. `PlantHazel` planted every estate that existed on 2026-11-01.
    @discardableResult
    public static func plantGranted(for user: User, on db: any Database) async throws -> Plot? {
        guard let type = PlotCatalog.grantedType, let userId = user.id,
              user.registrationStep >= User.registrationDoneStep else { return nil }
        if try await Plot.find(slot: GrantedPlot.slotIndex, for: user, on: db) != nil { return nil }
        let ripeSince = Date().addingTimeInterval(-(PlotCatalog.secondsToFill(type) ?? 0))
        let plot = Plot(userID: userId, slotIndex: GrantedPlot.slotIndex, plotType: type.rawValue,
                        tier: 1, lastHarvestedAt: ripeSince)
        plot.notifiedFull = true
        try await plot.save(on: db)
        return plot
    }

    /// The estate's plots for a screen that lists them, the granted plot planted
    /// first if its slot is empty — so a player never meets a «➕ Слот 1» the
    /// claim refuses. The planting is best-effort: a failure leaves the list as
    /// it stands rather than throwing out of a callback, which would spin it.
    public static func estatePlots(for user: User, on db: any Database) async throws -> [Plot] {
        _ = try? await plantGranted(for: user, on: db)
        return try await Plot.list(for: user, on: db)
    }

    // MARK: - Claim

    public enum ClaimResult: Sendable {
        case slotOutOfRange    // slot >= slotsForLevel(user.estateLevel)
        case slotTaken         // user already has a plot at that slot
        /// The slot the granted plot stands in (`isReserved`) — never built on.
        case slotReserved
        /// A granted type — never built. No screen offers one; only a forged or
        /// stale callback can ask.
        case typeNotBuildable
        /// The bag and the warehouse together hold less than the plot costs —
        /// every short input named, for `RequirementLine.shortageModal`.
        case missingMaterials(shortages: [CraftingService.Shortage])
        case success(Plot)
    }

    /// What the player's NEXT plot of `type` costs (2026-10-24). Its number is
    /// the plots they BUILT plus one (`PlotBuildCost.nextPlotNumber`) — never
    /// the slot index, since a slot can be claimed out of order, and never the
    /// granted hazel, which they did not build. The build card and `claim` both
    /// ask here, so the card cannot quote a price the claim then disagrees with.
    public static func buildCost(of type: PlotType, for user: User, on db: any Database) async throws -> [MaterialCostDTO] {
        let owned = try await Plot.list(for: user, on: db).map(\.plotType)
        let number = PlotBuildCost.nextPlotNumber(ownedTypes: owned, granted: PlotCatalog.grantedRawValues)
        return PlotCatalog.buildCost(for: type, plotNumber: number)
    }

    /// Claim an empty slot for `type`, paying its build cost from the bag first
    /// and the warehouse for the rest — the estate's policy, read from the same
    /// `CraftingService.stock` the card quotes. Slot index must be within the
    /// user's estate-level allowance (`slotsForLevel`) and not the granted
    /// plot's; the type must be one a player builds. Tier defaults to 1.
    @discardableResult
    public static func claim(slot: Int, type: PlotType, for user: User, on db: any Database) async throws -> ClaimResult {
        let allowance = slotsForLevel(user.estateLevel)
        guard slot >= 0, slot < allowance else { return .slotOutOfRange }
        guard let userId = user.id else { return .slotOutOfRange }
        guard !PlotCatalog.isGranted(type) else { return .typeNotBuildable }
        guard !isReserved(slot: slot) else { return .slotReserved }
        if let _ = try await Plot.find(slot: slot, for: user, on: db) {
            return .slotTaken
        }

        let inputs = try await buildCost(of: type, for: user, on: db)
        let snapshot = try await CraftingService.stock(for: user, on: db)
        let shortages: [CraftingService.Shortage] = inputs.compactMap { input in
            let have = snapshot[input.itemId]?.total ?? 0
            guard have < input.quantity else { return nil }
            return CraftingService.Shortage(itemId: input.itemId, need: input.quantity, have: have)
        }
        if !shortages.isEmpty {
            return .missingMaterials(shortages: shortages)
        }

        // One transaction, unlike the upgrades beside it: a plot can never be
        // rebuilt, so it is paid in full or not built at all — a drain that
        // outlived a failed insert would take the materials for land the player
        // does not get, and a store that no longer holds what the snapshot saw
        // would build the plot underpaid.
        let plot = Plot(userID: userId, slotIndex: slot, plotType: type.rawValue, tier: 1, lastHarvestedAt: Date())
        try await db.transaction { tx in
            for input in inputs {
                let fromInv = min(input.quantity, snapshot[input.itemId]?.bag ?? 0)
                if fromInv > 0, try await !InventoryEntry.remove(input.itemId, quantity: fromInv, from: user, on: tx) {
                    throw ClaimError.stockMoved(input.itemId)
                }
                let fromWH = input.quantity - fromInv
                if fromWH > 0, try await !WarehouseEntry.remove(input.itemId, quantity: fromWH, from: user, on: tx) {
                    throw ClaimError.stockMoved(input.itemId)
                }
            }
            try await plot.save(on: tx)
        }
        return .success(plot)
    }

    /// Thrown inside the claim's transaction, which rolls it back. Nothing but
    /// the player's own serialized taps moves their stock, so it should never
    /// fire; if it does, the tap is answered and logged and the next one reads
    /// a fresh snapshot.
    public enum ClaimError: Error {
        case stockMoved(String)
    }

}
