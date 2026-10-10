//
//  TreasuryCatalog.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 11.10.2026.
//
//  Façade over `treasury.json`: what the palace's Treasury sells for zlatnyks,
//  in the order it lists them. The prices are data (`/reload` moves them); what
//  an entry DOES is its `TreasuryKind`, which is code.
//

import Foundation

public enum TreasuryCatalog {
    public static var items: [TreasuryItemDTO] { Catalogs.current.treasuryItems }

    public static func find(_ id: String) -> TreasuryItemDTO? {
        items.first { $0.id == id }
    }

    /// The `treasury.item.<id>` key the list's button and the card's title print.
    public static func nameKey(_ item: TreasuryItemDTO) -> String {
        "treasury.item.\(item.id)"
    }
}
