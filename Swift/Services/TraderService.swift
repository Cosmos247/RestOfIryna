//
//  TraderService.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 16.05.2026.
//
//  Phase 6.1 — pure orchestrator for capital-trader transactions.
//  `sell(qty)` / `buy(qty)` are the quantity-aware primitives (used by
//  ×1, custom-N prompt, and Sell-All flows alike); `sellAll` is a
//  convenience wrapper. Atomic preflight on both silver AND slot space so
//  a failed buy never half-applies.
//
//  The hired wagon (2026-11-08, `spec-wagon.md` §3.4) is the bag's second
//  store here: a sale takes from the bag first and the wagon for the rest, a
//  purchase fills the bag first and the wagon with the rest — all or nothing,
//  through `WagonService`, and only while the wagon is in town with the player.
//
//  Post-v2-economy (2026-05-17) all `TraderListing.*PacketQty` values
//  are 1, so per-unit silver = listing.sellPacketSilver (or buyPacketSilver).
//  The math here multiplies through for arbitrary N — silver-per-unit ×
//  quantity. If we ever bring back multi-unit packets, callers should
//  ensure quantity is a multiple of `packetQty`.
//

import Fluent
import Foundation

public enum TraderService {

    // MARK: - Result types

    public enum SellResult: Sendable {
        case success(itemId: String, soldQty: Int, silverGained: Int)
        case notEnoughInBag(have: Int, need: Int)
        case unknownListing
    }

    public enum BuyResult: Sendable {
        case success(itemId: String, boughtQty: Int, silverSpent: Int)
        case notEnoughSilver(have: Int, need: Int)
        case inventoryFull(free: Int, need: Int)
        case unknownListing
    }

    // MARK: - Sell

    /// Sell `quantity` units of `itemId` at the trader's listed per-unit
    /// price. Atomic — drain only happens after the in-bag check, silver
    /// credited only after the drain succeeds.
    public static func sell(itemId: String, quantity: Int, for user: User, on db: any Database) async throws -> SellResult {
        guard quantity > 0 else { return .notEnoughInBag(have: 0, need: max(1, quantity)) }
        guard let listing = TraderCatalog.find(itemId) else { return .unknownListing }
        guard user.id != nil else { return .unknownListing }

        let wagonInTown = try await WagonService.inTown(for: user, on: db)
        let stock = try await WagonService.townStock(of: itemId, for: user, on: db)
        let have = stock.bag + stock.wagon
        if have < quantity {
            return .notEnoughInBag(have: have, need: quantity)
        }

        let removed = try await db.transaction { tx in
            try await WagonService.take(itemId, quantity: quantity, from: user, wagonInTown: wagonInTown, on: tx)
        }
        guard removed else {
            return .notEnoughInBag(have: have, need: quantity)
        }

        let totalSilver = quantity * listing.sellPacketSilver
        user.silver += totalSilver
        try await user.saveAndCache(in: db)
        // Phase 9.2 — feeds the trader's "Оптовий день" job (sell 300🪙 worth in
        // a day). Best-effort: a quest hiccup must never fail a sale.
        try? await QuestService.record(.traderSilver, amount: totalSilver, for: user, on: db)
        try? await KingService.record(.traderSale, for: user, on: db)
        return .success(itemId: itemId, soldQty: quantity, silverGained: totalSilver)
    }

    // MARK: - Buy

    /// Buy `quantity` units at the trader's listed per-unit price.
    /// Validates silver AND bag space up front, then drains silver + adds
    /// to inventory. Failure modes never partially apply.
    public static func buy(itemId: String, quantity: Int, for user: User, on db: any Database) async throws -> BuyResult {
        guard quantity > 0 else { return .notEnoughSilver(have: user.silver, need: 1) }
        guard let listing = TraderCatalog.find(itemId) else { return .unknownListing }

        let totalSilver = quantity * listing.buyPacketSilver
        if user.silver < totalSilver {
            return .notEnoughSilver(have: user.silver, need: totalSilver)
        }

        // The bag first, the wagon for the rest when it is in town (2026-11-08):
        // the same arithmetic `WagonService.put` writes with, so the refusal and
        // the write cannot disagree.
        let wagonInTown = try await WagonService.inTown(for: user, on: db)
        guard try await WagonService.plan(put: itemId, quantity: quantity, to: user, wagonInTown: wagonInTown, on: db) != nil else {
            // The number «(у 🎒 вільно N)» quoted in the question (2026-11-04),
            // and the wagon's free places beside it while it carries the item.
            let room = try await WagonService.room(for: itemId, user: user, wagonInTown: wagonInTown, on: db)
            return .inventoryFull(free: room.bagFree + room.wagonFree, need: quantity)
        }

        user.silver -= totalSilver
        try await user.saveAndCache(in: db)
        try await db.transaction { tx in
            _ = try await WagonService.put(listing.itemId, quantity: quantity, to: user, wagonInTown: wagonInTown, on: tx)
        }
        return .success(itemId: itemId, boughtQty: quantity, silverSpent: totalSilver)
    }
}
