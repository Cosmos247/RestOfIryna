//
//  KingCatalog.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 21.09.2026.
//
//  Façade over `content/data/king.json` — the King's decree chain, as it sits
//  in the validated snapshot. Same shape as `MarketCatalog` and friends: the
//  DTO is the domain type here, because a decree is data end to end and a
//  mirror struct would only copy fields across.
//
//  **`chain` is never sorted and never filtered.** The array's order is the
//  order the player walks it, and `KingProgress.decreeIndex` is a position in
//  exactly this array — so a reader that reordered it would move every player
//  in the game to a different decree without changing a single id.
//

import Foundation

enum KingCatalog {
    /// Every decree, in walk order.
    static var chain: [KingDecreeDTO] { Catalogs.current.kingDecrees }

    /// How many steps the chain has. `KingProgress.decreeIndex >= count` is
    /// the one and only meaning of "the King has fallen silent".
    static var count: Int { chain.count }

    static func decree(at index: Int) -> KingDecreeDTO? {
        guard index >= 0, index < chain.count else { return nil }
        return chain[index]
    }

    static func find(_ id: String) -> KingDecreeDTO? {
        GameData.current.kingDecreesById[id]
    }

    /// `king.<id>.name` / `.desc`, derived from the id the same way every
    /// other content type derives its keys.
    static func nameKey(_ decree: KingDecreeDTO) -> String { "\(decree.id).name" }
    static func descKey(_ decree: KingDecreeDTO) -> String { "\(decree.id).desc" }
}
