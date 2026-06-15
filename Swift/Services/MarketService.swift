//
//  MarketService.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 28.05.2026.
//
//  Phase 6.5 — pure orchestrator for the capital Market (player-to-player).
//  DB-only: no bot I/O. The controller renders results and pushes the
//  seller-sold notification. Mirrors `TraderService`'s typed-result style.
//
//  Three transactions:
//    • createListing — escrows units from the seller's bag, debits the flat
//      listing fee (silver sink), writes the lot row.
//    • buyListing    — debits the buyer, credits the seller, hands the escrowed
//      units to the buyer, deletes the lot.
//    • cancelListing — returns the escrowed units to the seller, deletes the
//      lot. The listing fee is NOT refunded.
//
//  Only stackable items are listable (gear is non-stackable and excluded), so
//  `quantity` and per-unit math are always exact.
//

import Fluent
import Foundation

public enum MarketService {

    // MARK: - Result types

    public enum CreateResult: Sendable {
        case success(itemId: String, quantity: Int, price: Int)
        case notSellable
        case tooManyLots(max: Int)
        case notEnoughInBag(have: Int, need: Int)
        case notEnoughSilver(have: Int, fee: Int)
    }

    public enum BuyResult: Sendable {
        case success(itemId: String, quantity: Int, price: Int, sellerTelegramId: Int64, sellerLocale: String, sellerGender: String?)
        case notFound
        case ownListing
        case notEnoughSilver(have: Int, need: Int)
        case inventoryFull(free: Int, need: Int)
    }

    public enum CancelResult: Sendable {
        case success(itemId: String, quantity: Int)
        case notFound
        case notOwner
        case inventoryFull(free: Int, need: Int)
    }

    // MARK: - Create

    /// List `quantity` units of `itemId` for a fixed total `price`. Escrows the
    /// units off the seller's bag and debits the flat listing fee. Atomic — the
    /// fee and escrow only apply after every check passes.
    public static func createListing(itemId: String, quantity: Int, price: Int, for user: User, on db: any Database) async throws -> CreateResult {
        guard quantity > 0, price > 0 else { return .notSellable }
        guard let item = ItemCatalog.find(itemId), item.stackable else { return .notSellable }
        guard let userId = user.id else { return .notSellable }

        let activeLots = try await MarketListing.activeCount(for: user, on: db)
        if activeLots >= MarketCatalog.maxActiveLots {
            return .tooManyLots(max: MarketCatalog.maxActiveLots)
        }

        let inBag = try await InventoryEntry.totalQuantity(of: itemId, for: userId, on: db)
        if inBag < quantity {
            return .notEnoughInBag(have: inBag, need: quantity)
        }

        if user.silver < MarketCatalog.listingFee {
            return .notEnoughSilver(have: user.silver, fee: MarketCatalog.listingFee)
        }

        // Escrow the units, debit the fee, write the lot — order so a failed
        // drain never leaves the fee charged.
        let removed = try await InventoryEntry.remove(itemId, quantity: quantity, from: user, on: db)
        guard removed else { return .notEnoughInBag(have: inBag, need: quantity) }

        user.silver -= MarketCatalog.listingFee
        try await user.saveAndCache(in: db)

        let lot = MarketListing(sellerID: userId, itemId: itemId, quantity: quantity, price: price)
        try await lot.save(on: db)
        return .success(itemId: itemId, quantity: quantity, price: price)
    }

    // MARK: - Buy

    /// Buy the whole lot. Validates ownership, silver, and bag space up front;
    /// then debits the buyer, credits the seller, hands over the escrowed
    /// units, and deletes the lot. Re-reads the row so a lot already bought by
    /// someone else surfaces as `.notFound` rather than double-selling.
    public static func buyListing(id: UUID, buyer: User, on db: any Database) async throws -> BuyResult {
        guard let lot = try await MarketListing.find(id: id, on: db) else { return .notFound }
        guard let buyerId = buyer.id else { return .notFound }

        let sellerId = lot.$seller.id
        if sellerId == buyerId { return .ownListing }

        if buyer.silver < lot.price {
            return .notEnoughSilver(have: buyer.silver, need: lot.price)
        }

        let canFit = try await InventoryEntry.canAccept(lot.itemId, quantity: lot.quantity, for: buyer, on: db)
        if !canFit {
            let used = try await InventoryEntry.slotsUsed(for: buyer, on: db)
            let cap = InventoryEntry.slotCap(for: buyer)
            return .inventoryFull(free: max(0, cap - used), need: lot.quantity)
        }

        guard let seller = try await User.find(sellerId, on: db) else { return .notFound }

        // Commit: debit buyer, credit seller, deliver items, drop the lot.
        buyer.silver -= lot.price
        try await buyer.saveAndCache(in: db)

        seller.silver += lot.price
        try await seller.saveAndCache(in: db)

        try await InventoryEntry.add(lot.itemId, quantity: lot.quantity, to: buyer, on: db)

        let itemId = lot.itemId
        let quantity = lot.quantity
        let price = lot.price
        try await lot.delete(on: db)

        return .success(
            itemId: itemId,
            quantity: quantity,
            price: price,
            sellerTelegramId: seller.telegramId,
            sellerLocale: seller.locale,
            sellerGender: seller.gender
        )
    }

    // MARK: - Cancel

    /// Pull a lot the seller posted, returning the escrowed units to their bag.
    /// The listing fee is gone for good. If the bag can't hold the units back
    /// (bag shrank since listing — rare), keep the lot and report the shortfall.
    public static func cancelListing(id: UUID, seller: User, on db: any Database) async throws -> CancelResult {
        guard let lot = try await MarketListing.find(id: id, on: db) else { return .notFound }
        guard let sellerId = seller.id, lot.$seller.id == sellerId else { return .notOwner }

        let canFit = try await InventoryEntry.canAccept(lot.itemId, quantity: lot.quantity, for: seller, on: db)
        if !canFit {
            let used = try await InventoryEntry.slotsUsed(for: seller, on: db)
            let cap = InventoryEntry.slotCap(for: seller)
            return .inventoryFull(free: max(0, cap - used), need: lot.quantity)
        }

        try await InventoryEntry.add(lot.itemId, quantity: lot.quantity, to: seller, on: db)

        let itemId = lot.itemId
        let quantity = lot.quantity
        try await lot.delete(on: db)
        return .success(itemId: itemId, quantity: quantity)
    }
}
