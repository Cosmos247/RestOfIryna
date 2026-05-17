//
//  TavernService.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 17.05.2026.
//
//  Phase 6.2 — pure orchestrator for tavern transactions. `buyDish` is the
//  food-purchase path (gold → bag), atomic preflight on both gold AND slot
//  space so a failed buy never half-applies. Dice / darts gambling lives
//  in the controller because it needs to drive bot animation flow; this
//  service only handles the deterministic state mutation (debit, credit,
//  refund) and exposes `resolveWager` as a tiny pure helper for outcome
//  bookkeeping.
//

import Fluent
import Foundation

public enum TavernService {

    // MARK: - Food

    public enum BuyDishResult: Sendable {
        case success(itemId: String, goldSpent: Int)
        case notEnoughGold(have: Int, need: Int)
        case inventoryFull(free: Int, need: Int)
        case unknownListing
    }

    /// Purchase one dish at the tavern's listed price. Mirrors the trader's
    /// buy flow — gold + slot capacity validated up front, then a single
    /// debit + add. No partial states on failure.
    public static func buyDish(itemId: String, for user: User, on db: any Database) async throws -> BuyDishResult {
        guard let listing = TavernCatalog.listing(for: itemId) else { return .unknownListing }

        if user.gold < listing.priceGold {
            return .notEnoughGold(have: user.gold, need: listing.priceGold)
        }
        let canFit = try await InventoryEntry.canAccept(itemId, quantity: 1, for: user, on: db)
        if !canFit {
            let used = try await InventoryEntry.slotsUsed(for: user, on: db)
            let cap = InventoryEntry.slotCap(for: user)
            let free = max(0, cap - used)
            return .inventoryFull(free: free, need: 1)
        }

        user.gold -= listing.priceGold
        try await user.saveAndCache(in: db)
        try await InventoryEntry.add(itemId, quantity: 1, to: user, on: db)
        return .success(itemId: itemId, goldSpent: listing.priceGold)
    }

    // MARK: - Gambling

    public enum WagerOutcome: Sendable {
        case win    // player score > house score; net +wager
        case lose   // player score < house score; net −wager (already debited)
        case tie    // equal scores; wager refunded (net 0)
    }

    /// Pure deterministic wager resolution — given the two scores the caller
    /// already obtained from Telegram's animated dice, returns the outcome
    /// classification. Caller applies the resulting gold delta on the User.
    public static func resolveWager(playerScore: Int, houseScore: Int) -> WagerOutcome {
        if playerScore > houseScore { return .win }
        if playerScore < houseScore { return .lose }
        return .tie
    }
}
