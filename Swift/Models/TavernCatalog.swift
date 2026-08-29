//
//  TavernCatalog.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 17.05.2026.
//
//  Façade over `content/data/tavern.json` (Phase 3B — was a Swift array).
//  The menu sells ready-cooked dishes the player would otherwise have to find a
//  recipe scroll for and craft in the kitchen — the tavern is the
//  convenience-for-silver trade. Pricing follows the v2 economy rebase
//  (pebble = 1s/unit) and lands between "5× old prices" and "DIY × ~2.5
//  markup", whichever produced rounder numbers per dish.
//
//  Wager tiers feed both gambling games (dice + darts) — same three amounts for
//  both so the player builds one mental model. Tuned for the v2 economy where
//  shallow foraging already yields tens of silvers per expedition: 10s is "warm
//  up", 50s is "feeling brave".
//
//  Menu order is display order — ascending by price, so it reads cheap →
//  premium — and is preserved verbatim from the file.
//

import Foundation

public struct TavernFoodListing: Sendable {
    public let itemId: String
    /// Silvers the player pays to receive one of this dish into their bag.
    public let priceSilver: Int

    public init(itemId: String, priceSilver: Int) {
        self.itemId = itemId
        self.priceSilver = priceSilver
    }
}

public enum TavernCatalog {
    public static var food: [TavernFoodListing] { Catalogs.current.tavernFood }

    /// Shared wager tiers across dice and darts.
    public static var wagerTiers: [Int] { Catalogs.current.tavernWagerTiers }

    public static func price(for itemId: String) -> Int? {
        listing(for: itemId)?.priceSilver
    }

    public static func listing(for itemId: String) -> TavernFoodListing? {
        Catalogs.current.tavernFoodById[itemId]
    }
}
