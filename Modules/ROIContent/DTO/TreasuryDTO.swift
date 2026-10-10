//
//  TreasuryDTO.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 11.10.2026.
//
//  `treasury.json` — what the palace's Treasury sells for zlatnyks
//  (2026-10-11). An entry is a `kind` the binary knows how to carry out and a
//  price: the list and the prices are data, the kinds are code. The first
//  version sells one thing, the class change, on the owner's pick.
//

import Foundation

public struct TreasuryFileDTO: Codable, Sendable, Equatable {
    /// In the order the Treasury lists them.
    public let items: [TreasuryItemDTO]

    public init(items: [TreasuryItemDTO]) {
        self.items = items
    }
}

public struct TreasuryItemDTO: Codable, Sendable, Equatable {
    /// Stable: the purchase log stores it, a button carries it
    /// (`treasury:item:<id>`), and `treasury.item.<id>` names it.
    public let id: String
    /// A `TreasuryKind` raw value — what buying it does.
    public let kind: String
    /// In zlatnyks.
    public let price: Int

    public init(id: String, kind: String, price: Int) {
        self.id = id
        self.kind = kind
        self.price = price
    }
}

/// What a Treasury entry can do. A kind is code: a new one needs its handler
/// before the validator lets a file name it.
public enum TreasuryKind: String, CaseIterable, Sendable {
    /// Rewrites the player's class: the class weapon is reforged at its tier
    /// and wear, and the stat line is recomputed (`ClassChangeService`).
    case classChange = "class_change"
}
