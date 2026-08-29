//
//  TraderCatalog.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 16.05.2026.
//
//  Façade over `content/data/trader.json` (Phase 3B — was a Swift array).
//  One `TraderListing` per item carries two asymmetric packets: the price the
//  trader pays the player (sell side) and the price the trader charges the
//  player (buy side). Packets are integer (qty, silver) tuples to avoid the
//  rounding mess that per-unit fractional silver would create.
//
//  Pricing v2 (2026-05-17 economy rebase — pebble anchored at 1 unit = 1s).
//  Variant B "clear ladder": each tier doubles its sell price, iron sits at 10×
//  pebble to reward rarity. The sell:buy spread is a flat 2× across the book,
//  and `ContentValidator` enforces `sell ≤ buy` per unit so a future edit can
//  never open a buy-low-sell-high silver printer.
//
//    1s sell / 2s buy    : 🪨 pebble · 🫐 berries · 🌰 nuts      (T1 baseline)
//    2s sell / 4s buy    : 🌲 lumber · 🧱 clay                    (T2 craft-essential)
//    3s sell / 6s buy    : 🥔 potato · 🥚 duck_egg · 🦴 hide      (T3 recipe / armor)
//    5s sell / 10s buy   : 🥩 raw_meat                            (T4 wild-only beast drop)
//    10s sell / 20s buy  : 🔩 iron                                (T5 rare)
//    100s sell / 200s buy: 🔳 iron_ingot                          (10 iron → 1 ingot)
//
//  Smelting 10 raw iron yields 1 ingot whose sell value (100s) matches 10 × iron
//  sell — selling raw vs selling ingot is neutral, but the ingot saves bag slots.
//
//  Row order is display order (materials first, then food; rare items at the end
//  of their block) and is preserved verbatim from the file.
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
    /// Computed, never a `static let` — the snapshot is installed by
    /// `ContentBootstrap.load` at boot and a type-level constant would read it
    /// too early.
    public static var all: [TraderListing] { Catalogs.current.traderListings }

    public static func find(_ itemId: String) -> TraderListing? {
        Catalogs.current.traderListingsById[itemId]
    }
}
