//
//  TavernCatalog.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 17.05.2026.
//
//  Phase 6.2 — static configuration for the capital tavern. The menu sells
//  ready-cooked dishes that the player would otherwise have to find a
//  recipe scroll for and craft in the kitchen — the tavern is the
//  convenience-for-gold trade. Pricing follows the v2 economy rebase
//  (pebble = 1g/unit) and lands between "5× old prices" and "DIY × ~2.5
//  markup", whichever produced rounder numbers per dish.
//
//  Wager tiers feed both gambling games (dice + darts) — same three
//  amounts for both so the player builds one mental model.
//

import Foundation

public struct TavernFoodListing: Sendable {
    public let itemId: String
    /// Gold the player pays to receive one of this dish into their bag.
    public let priceGold: Int

    public init(itemId: String, priceGold: Int) {
        self.itemId = itemId
        self.priceGold = priceGold
    }
}

public enum TavernCatalog {
    /// Display order ascends by price so the menu naturally reads
    /// cheap → premium.
    public static let food: [TavernFoodListing] = [
        TavernFoodListing(itemId: "food.baked_potato",      priceGold: 20),
        TavernFoodListing(itemId: "food.roasted_meat",      priceGold: 30),
        TavernFoodListing(itemId: "food.foragers_omelette", priceGold: 50),
        TavernFoodListing(itemId: "food.berry_tart",        priceGold: 60),
        TavernFoodListing(itemId: "food.meat_ragout",       priceGold: 80),
        TavernFoodListing(itemId: "food.hunters_stew",      priceGold: 100),
        TavernFoodListing(itemId: "food.governors_feast",   priceGold: 200),
    ]

    /// Shared wager tiers across dice and darts. Tuned for the v2 economy
    /// where shallow foraging already yields tens of gold per expedition —
    /// 10g is "warm up", 50g is "feeling brave".
    public static let wagerTiers: [Int] = [10, 25, 50]

    public static func price(for itemId: String) -> Int? {
        return food.first { $0.itemId == itemId }?.priceGold
    }

    public static func listing(for itemId: String) -> TavernFoodListing? {
        return food.first { $0.itemId == itemId }
    }
}
