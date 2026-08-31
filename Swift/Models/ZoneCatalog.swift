//
//  ZoneCatalog.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 31.08.2026.
//
//  Façade over `content/data/zones.json` (Phase 8E — was two Swift arrays and a
//  nested ternary inside `ExplorationService.rollLoot`). They were the last
//  content left in code after Phase 3 emptied every catalog, and Phase 8E is
//  what forced them out: with Vigor no longer regenerating, what the trail
//  hands out is part of the food economy rather than flavour between fights.
//
//  Selection is a weighted walk in DECLARATION ORDER, exactly as the shipped
//  `pickWeighted` did, so a seeded replay of the old arrays and the new file
//  agree draw for draw. The loader never sorts and neither does this.
//

import Foundation

/// One entry in a zone's foraging pool.
public struct ForageEntry: Sendable {
    public let itemId: String
    public let weight: Int

    public init(itemId: String, weight: Int) {
        self.itemId = itemId
        self.weight = weight
    }
}

/// A depth band and what can be found in it.
public struct Zone: Sendable {
    public let id: String
    public let depthRange: ClosedRange<Int>
    public let forage: [ForageEntry]

    public init(id: String, depthRange: ClosedRange<Int>, forage: [ForageEntry]) {
        self.id = id
        self.depthRange = depthRange
        self.forage = forage
    }
}

public enum ZoneCatalog {
    public static var all: [Zone] { Catalogs.current.zones }

    /// The zone covering `kmDepth`, or nil where nothing does.
    ///
    /// Declaration order decides an overlap, matching the shipped ternary:
    /// `kmDepth <= 2 ? shallow : (kmDepth <= 5 ? mixed : deep)` picked the
    /// FIRST matching band, so a file that overlaps behaves the way the code
    /// did rather than the way a `last` would.
    public static func zone(forDepth kmDepth: Int) -> Zone? {
        let km = max(1, kmDepth)
        return all.first { $0.depthRange.contains(km) }
    }

    /// Weighted forage roll for a depth. Nil when no zone covers it or the
    /// pool is empty — the caller reports the gap rather than substituting a
    /// default, which is the lesson `pickFor`'s `?? all.first` taught: a silent
    /// fallback turns missing content into a wrong item forever.
    public static func rollForage(atDepth kmDepth: Int) -> String? {
        var generator = SystemRandomNumberGenerator()
        return rollForage(atDepth: kmDepth, using: &generator)
    }

    /// Seedable variant — the digest replays this, so the game and the replay
    /// cannot execute different selection logic.
    public static func rollForage<G: RandomNumberGenerator>(atDepth kmDepth: Int,
                                                            using generator: inout G) -> String? {
        guard let pool = zone(forDepth: kmDepth)?.forage, !pool.isEmpty else { return nil }
        let total = pool.reduce(0) { $0 + max(0, $1.weight) }
        guard total > 0 else { return nil }
        var roll = Int.random(in: 1...total, using: &generator)
        for entry in pool {
            let w = max(0, entry.weight)
            if roll <= w { return entry.itemId }
            roll -= w
        }
        return pool.last?.itemId
    }
}
