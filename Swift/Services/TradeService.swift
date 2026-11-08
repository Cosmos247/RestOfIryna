//
//  TradeService.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 10.06.2026.
//
//  Phase 6.5 — the database side of the player-to-player trade. `TradeStore`
//  holds the live negotiation in memory; this enum does the two DB jobs:
//
//    • `tradeableBagItems` — what a player may offer: every NON-equipped bag
//      row except the bound class starter weapon (`WeaponUpgradeCatalog`).
//      Stackables are summed; gear is returned as individual rows so the UI can
//      show each piece's enchant / durability.
//
//    • `commit` — the atomic swap. There is no Fluent transaction wrapper used
//      anywhere in this codebase (the Market buy/sell flows also do sequential
//      saves), so we VALIDATE EVERYTHING FIRST and only then mutate, in an order
//      that makes a mid-swap capacity throw impossible:
//        1. remove both sides' stacks (frees slots on both bags)
//        2. reassign gear rows to the other owner (no cap check — preserves the
//           exact instance: enchant / durability / tier)
//        3. add each side's stacks to the other (capacity already proven)
//        4. swap silver, save both users
//

import Fluent
import Foundation

public enum TradeService {

    // MARK: - Offerable items

    /// Non-equipped, non-bound bag contents. Stackables grouped by id; gear as
    /// individual `InventoryEntry` rows (so labels can show enchant/durability).
    public static func tradeableBagItems(for user: User, on db: any Database) async throws
        -> (stacks: [(itemId: String, qty: Int)], gear: [InventoryEntry]) {
        let rows = try await InventoryEntry.list(for: user, on: db)
        var stackTotals: [String: Int] = [:]
        var gear: [InventoryEntry] = []
        for row in rows where row.equippedSlot == nil {
            guard let item = ItemCatalog.find(row.itemId) else { continue }
            if WeaponUpgradeCatalog.isUpgradable(row.itemId) { continue }   // bound starter weapon
            if item.stackable {
                stackTotals[row.itemId, default: 0] += row.quantity
            } else {
                gear.append(row)
            }
        }
        // The hired wagon in town is the bag's second store (2026-11-08): its
        // materials are offered beside the bag's, and the swap takes them after
        // the bag's.
        if let userId = user.id, try await WagonService.inTown(for: user, on: db) {
            for pile in try await WagonService.cargo(for: userId, on: db) {
                stackTotals[pile.itemId, default: 0] += pile.quantity
            }
        }
        let stacks = stackTotals
            .filter { $0.value > 0 }
            .map { (itemId: $0.key, qty: $0.value) }
            .sorted { $0.itemId < $1.itemId }
        let sortedGear = gear.sorted { ($0.itemId, $0.id?.uuidString ?? "") < ($1.itemId, $1.id?.uuidString ?? "") }
        return (stacks, sortedGear)
    }

    // MARK: - Commit

    public enum Reason: Sendable {
        case itemGone(nickname: String)
        case noSilver(nickname: String)
        case bagFull(nickname: String)
    }

    public enum CommitResult: Sendable {
        case success
        case failed(Reason)
    }

    public static func commit(session: TradeStore.TradeSession, on db: any Database) async throws -> CommitResult {
        let a = session.a
        let b = session.b
        guard let userA = try await User.find(a.userId, on: db),
              let userB = try await User.find(b.userId, on: db) else {
            return .failed(.itemGone(nickname: a.nickname))
        }

        // ---- PHASE 1: validate (zero writes) ----

        // Offered stacks still present (stackables are never equipped, so
        // totalQuantity == non-equipped count) — in the bag and, while it is in
        // town, the hired wagon (2026-11-08).
        let aWagon = try await WagonService.inTown(for: userA, on: db)
        let bWagon = try await WagonService.inTown(for: userB, on: db)
        for (itemId, qty) in a.offeredStacks where try await WagonService.townTotal(of: itemId, for: userA, on: db) < qty {
            return .failed(.itemGone(nickname: a.nickname))
        }
        for (itemId, qty) in b.offeredStacks where try await WagonService.townTotal(of: itemId, for: userB, on: db) < qty {
            return .failed(.itemGone(nickname: b.nickname))
        }

        // Offered gear rows still exist, still owned, unequipped, not bound.
        let aGear = try await resolveGear(ids: a.offeredGear, owner: a.userId, on: db)
        guard aGear.count == a.offeredGear.count else { return .failed(.itemGone(nickname: a.nickname)) }
        let bGear = try await resolveGear(ids: b.offeredGear, owner: b.userId, on: db)
        guard bGear.count == b.offeredGear.count else { return .failed(.itemGone(nickname: b.nickname)) }

        // Silver.
        if userA.silver < a.silver { return .failed(.noSilver(nickname: a.nickname)) }
        if userB.silver < b.silver { return .failed(.noSilver(nickname: b.nickname)) }

        // Capacity: each receiver frees its own outgoing units first, then must
        // fit the incoming set. Gear counts as 1 unit per row. With a wagon in
        // town (2026-11-08) the outgoing come off the bag first and the wagon
        // for the rest, and the incoming fill the bag first — what only the bag
        // can carry before anything the wagon carries — and spill onto the wagon.
        guard try await fits(receiver: userA, wagonInTown: aWagon, outgoing: a.offeredStacks, gearOut: a.offeredGear.count,
                             incoming: b.offeredStacks, gearIn: b.offeredGear.count, on: db) else {
            return .failed(.bagFull(nickname: a.nickname))
        }
        guard try await fits(receiver: userB, wagonInTown: bWagon, outgoing: b.offeredStacks, gearOut: b.offeredGear.count,
                             incoming: a.offeredStacks, gearIn: a.offeredGear.count, on: db) else {
            return .failed(.bagFull(nickname: b.nickname))
        }

        // ---- PHASE 2: mutate (every check passed) ----
        do {
            // 1. Remove both sides' stacks — frees slots on both bags (and wagons).
            for (itemId, qty) in a.offeredStacks {
                _ = try await WagonService.take(itemId, quantity: qty, from: userA, wagonInTown: aWagon, on: db)
            }
            for (itemId, qty) in b.offeredStacks {
                _ = try await WagonService.take(itemId, quantity: qty, from: userB, wagonInTown: bWagon, on: db)
            }
            // 2. Reassign gear rows to the new owner (no cap check; preserves the
            //    exact instance — enchant / durability / tier all travel with it).
            for row in aGear { row.$user.id = b.userId; row.equippedSlot = nil; try await row.save(on: db) }
            for row in bGear { row.$user.id = a.userId; row.equippedSlot = nil; try await row.save(on: db) }
            // 3. Add each side's stacks to the other (capacity proven above):
            //    what only the bag can carry first, then the materials, which
            //    may spill onto a wagon in town.
            for (itemId, qty) in deliveryOrder(a.offeredStacks) {
                try await WagonService.put(itemId, quantity: qty, to: userB, wagonInTown: bWagon, on: db)
            }
            for (itemId, qty) in deliveryOrder(b.offeredStacks) {
                try await WagonService.put(itemId, quantity: qty, to: userA, wagonInTown: aWagon, on: db)
            }
            // 4. Swap silver.
            userA.silver += b.silver - a.silver
            userB.silver += a.silver - b.silver
            try await userA.saveAndCache(in: db)
            try await userB.saveAndCache(in: db)
        } catch {
            // Capacity was proven, so this should be unreachable; surface as a
            // generic bag-full rather than crash the handler.
            return .failed(.bagFull(nickname: a.nickname))
        }
        return .success
    }

    /// Whether `receiver` can hold the swap: its outgoing stacks leave the bag
    /// first and the wagon for the rest, its outgoing gear the bag; then the
    /// incoming gear (a trade moves bag rows) needs the bag, and the incoming
    /// stacks the wagon carries fill what the bag has left and spill onto the
    /// wagon. The arithmetic the write performs, in units; a developer's bag
    /// has no ceiling.
    private static func fits(receiver: User, wagonInTown: Bool, outgoing: [String: Int], gearOut: Int,
                             incoming: [String: Int], gearIn: Int, on db: any Database) async throws -> Bool {
        guard !receiver.isDeveloper else { return true }
        let userId = try receiver.requireID()
        var bagUsed = try await InventoryEntry.slotsUsed(for: receiver, on: db) - gearOut
        var wagonUsed = wagonInTown ? try await WagonService.used(for: userId, on: db) : 0
        for (itemId, qty) in outgoing {
            let bag = try await InventoryEntry.totalQuantity(of: itemId, for: userId, on: db)
            let onWagon = wagonInTown && WagonService.carries(itemId)
                ? try await WagonService.quantity(of: itemId, for: userId, on: db) : 0
            guard let split = WagonMath.take(qty, bag: bag, wagon: onWagon) else { return false }
            bagUsed -= split.fromBag
            wagonUsed -= split.fromWagon
        }
        let spillable = incoming.filter { WagonService.carries($0.key) }.values.reduce(0, +)
        let bagOnly = incoming.filter { !WagonService.carries($0.key) }.values.reduce(0, +) + gearIn
        let bagRoom = InventoryEntry.slotCap(for: receiver) - bagUsed
        guard bagOnly <= bagRoom else { return false }
        let wagonFree = wagonInTown ? max(0, WagonCatalog.capacity - wagonUsed) : 0
        return WagonMath.put(spillable, bagFree: bagRoom - bagOnly, bagUnbounded: false, wagonFree: wagonFree) != nil
    }

    /// Incoming stacks in the order the receiver can take them: whatever only
    /// the bag carries first, then what the wagon carries, which may spill onto it.
    private static func deliveryOrder(_ stacks: [String: Int]) -> [(String, Int)] {
        stacks.sorted { lhs, rhs in
            let l = WagonService.carries(lhs.key), r = WagonService.carries(rhs.key)
            return l == r ? lhs.key < rhs.key : !l
        }.map { ($0.key, $0.value) }
    }

    /// Load the offered gear rows that are still genuinely tradeable by `owner`.
    private static func resolveGear(ids: [UUID], owner: UUID, on db: any Database) async throws -> [InventoryEntry] {
        guard !ids.isEmpty else { return [] }
        let rows = try await InventoryEntry.query(on: db)
            .filter(\.$id ~~ ids)
            .all()
        return rows.filter {
            $0.$user.id == owner
            && $0.equippedSlot == nil
            && !WeaponUpgradeCatalog.isUpgradable($0.itemId)
        }
    }
}
