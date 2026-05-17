//
//  TraderCatalog.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 16.05.2026.
//
//  Phase 6.1 — static catalogue of what the capital trader handles. One
//  `TraderListing` per item carries two asymmetric packets: the price the
//  trader pays the player (sell side) and the price the trader charges the
//  player (buy side). Packets are integer (qty, gold) tuples to avoid the
//  rounding mess that per-unit fractional gold would create — cheap items
//  trade in packs of 5, rare items trade one at a time.
//
//  Pricing v2 (2026-05-17 economy rebase — pebble anchored at 1 unit = 1g
//  instead of the original 5 units = 1g). Variant B "clear ladder": each
//  tier doubles its sell price, iron sits at 10× pebble to reward rarity.
//  All packets = 1 unit now that gold-per-unit is integer everywhere — one
//  tap = one transaction.
//
//    1g sell / 2g buy  : 🪨 pebble · 🫐 berries · 🌰 nuts            (T1 baseline)
//    2g sell / 4g buy  : 🌲 lumber · 🧱 clay                          (T2 craft-essential)
//    3g sell / 6g buy  : 🥔 potato · 🥚 duck_egg · 🦴 hide            (T3 recipe / armor)
//    5g sell / 10g buy : 🥩 raw_meat                                   (T4 wild-only beast drop)
//    10g sell / 20g buy: 🔩 iron                                       (T5 rare, weight 2 of medium pool)
//    100g sell / 200g buy: 🔳 iron_ingot                               (10 iron → 1 ingot via the forge)
//
//  Sell:buy spread stays at flat 2× across the catalogue. Smelting 10 raw
//  iron at the forge yields 1 ingot, sell value of which (100g) matches
//  10 × iron sell (10 × 10g = 100g) — selling raw vs selling ingot is
//  neutral, but the ingot saves bag slots (1 vs 10).
//

import Foundation

public struct TraderListing: Sendable {
    public let itemId: String

    /// The trader BUYS this many units from the player per packet, paying
    /// `sellPacketGold` gold for the bundle. From the player's POV: "sell N
    /// units, receive Y gold".
    public let sellPacketQty: Int
    public let sellPacketGold: Int

    /// The trader SELLS this many units to the player per packet, charging
    /// `buyPacketGold` gold for the bundle. From the player's POV: "buy N
    /// units, pay Y gold".
    public let buyPacketQty: Int
    public let buyPacketGold: Int

    public init(itemId: String,
                sellPacketQty: Int, sellPacketGold: Int,
                buyPacketQty: Int,  buyPacketGold: Int) {
        self.itemId = itemId
        self.sellPacketQty = sellPacketQty
        self.sellPacketGold = sellPacketGold
        self.buyPacketQty = buyPacketQty
        self.buyPacketGold = buyPacketGold
    }
}

public enum TraderCatalog {
    /// Display order is materials first, then food. Within each block the
    /// shallow-zone staples come ahead of the medium-zone ones, and the rare
    /// items (iron / iron_ingot) sit at the end of their block.
    public static let all: [TraderListing] = [
        // Tier 1 — pebble baseline + simple foods. 1g sell / 2g buy per unit.
        TraderListing(itemId: "mat.river_pebble",    sellPacketQty: 1, sellPacketGold: 1, buyPacketQty: 1, buyPacketGold: 2),
        TraderListing(itemId: "food.forest_berries", sellPacketQty: 1, sellPacketGold: 1, buyPacketQty: 1, buyPacketGold: 2),
        TraderListing(itemId: "food.forest_nuts",    sellPacketQty: 1, sellPacketGold: 1, buyPacketQty: 1, buyPacketGold: 2),
        // Tier 2 — craft-essential staples (every kitchen recipe needs lumber).
        TraderListing(itemId: "mat.pine_lumber",     sellPacketQty: 1, sellPacketGold: 2, buyPacketQty: 1, buyPacketGold: 4),
        TraderListing(itemId: "mat.clay",            sellPacketQty: 1, sellPacketGold: 2, buyPacketQty: 1, buyPacketGold: 4),
        // Tier 3 — recipe ingredients + armor material.
        TraderListing(itemId: "food.potato",         sellPacketQty: 1, sellPacketGold: 3, buyPacketQty: 1, buyPacketGold: 6),
        TraderListing(itemId: "food.duck_egg",       sellPacketQty: 1, sellPacketGold: 3, buyPacketQty: 1, buyPacketGold: 6),
        TraderListing(itemId: "mat.hide",            sellPacketQty: 1, sellPacketGold: 3, buyPacketQty: 1, buyPacketGold: 6),
        // Tier 4 — wild-only beast drop (~half the supply of hide).
        TraderListing(itemId: "food.raw_meat",       sellPacketQty: 1, sellPacketGold: 5, buyPacketQty: 1, buyPacketGold: 10),
        // Tier 5 — rare. Iron weight 2 in medium pool → ~10× pebble value.
        TraderListing(itemId: "mat.iron",            sellPacketQty: 1, sellPacketGold: 10, buyPacketQty: 1, buyPacketGold: 20),
        // Crafted — 10 raw iron → 1 ingot via the forge. Sell-value matches
        // 10 × iron so smelting-then-selling is neutral; buying the ingot
        // directly saves 9 bag slots vs hauling 10 lumps.
        TraderListing(itemId: "mat.iron_ingot",      sellPacketQty: 1, sellPacketGold: 100, buyPacketQty: 1, buyPacketGold: 200),
    ]

    public static func find(_ itemId: String) -> TraderListing? {
        return all.first { $0.itemId == itemId }
    }
}
