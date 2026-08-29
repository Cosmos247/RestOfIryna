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
        guard let userId = user.id else { return .unknownListing }

        let inBag = try await InventoryEntry.totalQuantity(of: itemId, for: userId, on: db)
        if inBag < quantity {
            return .notEnoughInBag(have: inBag, need: quantity)
        }

        let removed = try await InventoryEntry.remove(itemId, quantity: quantity, from: user, on: db)
        guard removed else {
            return .notEnoughInBag(have: inBag, need: quantity)
        }

        let totalSilver = quantity * listing.sellPacketSilver
        user.silver += totalSilver
        try await user.saveAndCache(in: db)
        // Phase 9.2 — feeds the trader's "Оптовий день" job (sell 300🪙 worth in
        // a day). Best-effort: a quest hiccup must never fail a sale.
        try? await QuestService.record(.traderSilver, amount: totalSilver, for: user, on: db)
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

        let canFit = try await InventoryEntry.canAccept(itemId, quantity: quantity, for: user, on: db)
        if !canFit {
            let used = try await InventoryEntry.slotsUsed(for: user, on: db)
            let cap = InventoryEntry.slotCap(for: user)
            let free = max(0, cap - used)
            return .inventoryFull(free: free, need: quantity)
        }

        user.silver -= totalSilver
        try await user.saveAndCache(in: db)
        try await InventoryEntry.add(listing.itemId, quantity: quantity, to: user, on: db)
        return .success(itemId: itemId, boughtQty: quantity, silverSpent: totalSilver)
    }
}
