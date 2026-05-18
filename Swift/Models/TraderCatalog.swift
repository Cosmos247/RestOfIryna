//
//  TraderCatalog.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 16.05.2026.
//
//  Phase 6.1 — static catalogue of what the capital trader handles. One
//  `TraderListing` per item carries two asymmetric packets: the price the
//  trader pays the player (sell side) and the price the trader charges the
//  player (buy side). Packets are integer (qty, silver) tuples to avoid the
//  rounding mess that per-unit fractional silver would create — cheap items
//  trade in packs of 5, rare items trade one at a time.
//
//  Pricing v2 (2026-05-17 economy rebase — pebble anchored at 1 unit = 1s
//  instead of the original 5 units = 1s). Variant B "clear ladder": each
//  tier doubles its sell price, iron sits at 10× pebble to reward rarity.
//  All packets = 1 unit now that silver-per-unit is integer everywhere — one
//  tap = one transaction.
//
//    1s sell / 2s buy  : 🪨 pebble · 🫐 berries · 🌰 nuts            (T1 baseline)
//    2s sell / 4s buy  : 🌲 lumber · 🧱 clay                          (T2 craft-essential)
//    3s sell / 6s buy  : 🥔 potato · 🥚 duck_egg · 🦴 hide            (T3 recipe / armor)
//    5s sell / 10s buy : 🥩 raw_meat                                   (T4 wild-only beast drop)
//    10s sell / 20s buy: 🔩 iron                                       (T5 rare, weight 2 of medium pool)
//    100s sell / 200s buy: 🔳 iron_ingot                               (10 iron → 1 ingot via the forge)
//
//  Sell:buy spread stays at flat 2× across the catalogue. Smelting 10 raw
//  iron at the forge yields 1 ingot, sell value of which (100s) matches
//  10 × iron sell (10 × 10s = 100s) — selling raw vs selling ingot is
//  neutral, but the ingot saves bag slots (1 vs 10).
//

import Foundation

public struct TraderListing: Sendable {
    public let itemId: String

    /// The trader BUYS this many units from the player per packet, paying
    /// `sellPacketSilver` silvers for the bundle. From the player's POV: "sell N
    /// units, receive Y silvers".
    public let sellPacketQty: Int
    public let sellPacketSilver: Int

    /// The trader SELLS this many units to the player per packet, charging
    /// `buyPacketSilver` silvers for the bundle. From the player's POV: "buy N
    /// units, pay Y silvers".
    public let buyPacketQty: Int
    public let buyPacketSilver: Int

    public init(itemId: String,
                sellPacketQty: Int, sellPacketSilver: Int,
                buyPacketQty: Int,  buyPacketSilver: Int) {
        self.itemId = itemId
        self.sellPacketQty = sellPacketQty
        self.sellPacketSilver = sellPacketSilver
        self.buyPacketQty = buyPacketQty
        self.buyPacketSilver = buyPacketSilver
    }
}

public enum TraderCatalog {
    /// Display order is materials first, then food. Within each block the
    /// shallow-zone staples come ahead of the medium-zone ones, and the rare
    /// items (iron / iron_ingot) sit at the end of their block.
    public static let all: [TraderListing] = [
        // Tier 1 — pebble baseline + simple foods. 1g sell / 2g buy per unit.
        TraderListing(itemId: "mat.river_pebble",    sellPacketQty: 1, sellPacketSilver: 1, buyPacketQty: 1, buyPacketSilver: 2),
        TraderListing(itemId: "food.forest_berries", sellPacketQty: 1, sellPacketSilver: 1, buyPacketQty: 1, buyPacketSilver: 2),
        TraderListing(itemId: "food.forest_nuts",    sellPacketQty: 1, sellPacketSilver: 1, buyPacketQty: 1, buyPacketSilver: 2),
        // Tier 2 — craft-essential staples (every kitchen recipe needs lumber).
        TraderListing(itemId: "mat.pine_lumber",     sellPacketQty: 1, sellPacketSilver: 2, buyPacketQty: 1, buyPacketSilver: 4),
        TraderListing(itemId: "mat.clay",            sellPacketQty: 1, sellPacketSilver: 2, buyPacketQty: 1, buyPacketSilver: 4),
        // Tier 3 — recipe ingredients + armor material.
        TraderListing(itemId: "food.potato",         sellPacketQty: 1, sellPacketSilver: 3, buyPacketQty: 1, buyPacketSilver: 6),
        TraderListing(itemId: "food.duck_egg",       sellPacketQty: 1, sellPacketSilver: 3, buyPacketQty: 1, buyPacketSilver: 6),
        TraderListing(itemId: "mat.hide",            sellPacketQty: 1, sellPacketSilver: 3, buyPacketQty: 1, buyPacketSilver: 6),
        // Tier 4 — wild-only beast drop (~half the supply of hide).
        TraderListing(itemId: "food.raw_meat",       sellPacketQty: 1, sellPacketSilver: 5, buyPacketQty: 1, buyPacketSilver: 10),
        // Tier 5 — rare. Iron weight 2 in medium pool → ~10× pebble value.
        TraderListing(itemId: "mat.iron",            sellPacketQty: 1, sellPacketSilver: 10, buyPacketQty: 1, buyPacketSilver: 20),
        // Crafted — 10 raw iron → 1 ingot via the forge. Sell-value matches
        // 10 × iron so smelting-then-selling is neutral; buying the ingot
        // directly saves 9 bag slots vs hauling 10 lumps.
        TraderListing(itemId: "mat.iron_ingot",      sellPacketQty: 1, sellPacketSilver: 100, buyPacketQty: 1, buyPacketSilver: 200),
    ]

    public static func find(_ itemId: String) -> TraderListing? {
        return all.first { $0.itemId == itemId }
    }
}
