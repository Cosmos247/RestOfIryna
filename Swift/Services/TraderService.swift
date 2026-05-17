//
//  TraderService.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 16.05.2026.
//
//  Phase 6.1 — pure orchestrator for capital-trader transactions.
//  `sell(qty)` / `buy(qty)` are the quantity-aware primitives (used by
//  ×1, custom-N prompt, and Sell-All flows alike); `sellAll` is a
//  convenience wrapper. Atomic preflight on both gold AND slot space so
//  a failed buy never half-applies.
//
//  Post-v2-economy (2026-05-17) all `TraderListing.*PacketQty` values
//  are 1, so per-unit gold = listing.sellPacketGold (or buyPacketGold).
//  The math here multiplies through for arbitrary N — gold-per-unit ×
//  quantity. If we ever bring back multi-unit packets, callers should
//  ensure quantity is a multiple of `packetQty`.
//

import Fluent
import Foundation

public enum TraderService {

    // MARK: - Result types

    public enum SellResult: Sendable {
        case success(itemId: String, soldQty: Int, goldGained: Int)
        case notEnoughInBag(have: Int, need: Int)
        case unknownListing
    }

    public enum BuyResult: Sendable {
        case success(itemId: String, boughtQty: Int, goldSpent: Int)
        case notEnoughGold(have: Int, need: Int)
        case inventoryFull(free: Int, need: Int)
        case unknownListing
    }

    // MARK: - Sell

    /// Sell `quantity` units of `itemId` at the trader's listed per-unit
    /// price. Atomic — drain only happens after the in-bag check, gold
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

        let totalGold = quantity * listing.sellPacketGold
        user.gold += totalGold
        try await user.saveAndCache(in: db)
        return .success(itemId: itemId, soldQty: quantity, goldGained: totalGold)
    }

    // MARK: - Buy

    /// Buy `quantity` units at the trader's listed per-unit price.
    /// Validates gold AND bag space up front, then drains gold + adds
    /// to inventory. Failure modes never partially apply.
    public static func buy(itemId: String, quantity: Int, for user: User, on db: any Database) async throws -> BuyResult {
        guard quantity > 0 else { return .notEnoughGold(have: user.gold, need: 1) }
        guard let listing = TraderCatalog.find(itemId) else { return .unknownListing }

        let totalGold = quantity * listing.buyPacketGold
        if user.gold < totalGold {
            return .notEnoughGold(have: user.gold, need: totalGold)
        }

        let canFit = try await InventoryEntry.canAccept(itemId, quantity: quantity, for: user, on: db)
        if !canFit {
            let used = try await InventoryEntry.slotsUsed(for: user, on: db)
            let cap = InventoryEntry.slotCap(for: user)
            let free = max(0, cap - used)
            return .inventoryFull(free: free, need: quantity)
        }

        user.gold -= totalGold
        try await user.saveAndCache(in: db)
        try await InventoryEntry.add(listing.itemId, quantity: quantity, to: user, on: db)
        return .success(itemId: itemId, boughtQty: quantity, goldSpent: totalGold)
    }
}
