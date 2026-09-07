//
//  QuestCatalog.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 23.08.2026.
//
//  Façade over `content/data/quests.json` (Phase 3C — was a Swift dictionary).
//  Three capital NPCs (Trader / Master / Innkeeper) each hold a small pool of
//  daily jobs. Exactly one job per NPC
//  is live per game day; the player never picks from a list — the system
//  assigns it (see `QuestCatalog.daily`).
//
//  Assignment is *derived*, not stored: a stable FNV-1a hash over
//  "userId:npc:gameDay" indexes into the NPC's pool. Same player + same day
//  always resolves to the same job, every player gets their own roll, and the
//  whole thing survives a restart without a single DB write. Only progress and
//  the claimed flag live in `quest_progress`.
//
//  Reward shape (design call, 2026-08-23): every job pays silver; each NPC
//  layers its own accent on top — Trader pays *more* silver, Master adds XP,
//  the Innkeeper adds Vigor.
//

import Foundation

// MARK: - NPC

/// The three quest-giving capital NPCs of v1. Raw values double as the
/// callback-data token (`quest:<npc>`) and the localization-key infix.
public enum QuestNPC: String, CaseIterable, Sendable {
    case trader
    case master
    case tavern

    /// Screen title of the NPC's quest board.
    public var boardTitleKey: String { "quest.\(rawValue).board_title" }

    /// The `capital:` sub-screen the [🔙 Back] button returns to.
    public var backCallback: String {
        switch self {
        case .trader: return "trader:menu"
        case .master: return "master:menu"
        case .tavern: return "tavern:menu"
        }
    }
}

// MARK: - Objectives

/// Event kinds that feed a `counter` objective. Deliberately concrete rather
/// than a generic (event, itemId) pair — v1 has exactly four counted things,
/// and naming them keeps every hook site unambiguous.
public enum QuestCounter: String, Sendable {
    /// Any beast slain — active combat or a passive-expedition kill.
    case beastKill
    /// `mat.iron_ingot` produced at the forge.
    case ironIngotForged
    /// A tavern dice/darts round won outright (a tie doesn't count).
    case gambleWin
    /// Silver earned selling to the capital trader (accumulates the amount).
    case traderSilver
}

public enum QuestObjective: Sendable {
    /// Hand over `count` units, any mix of `itemIds`. Items are consumed at
    /// turn-in; progress is read live from the bag, never stored.
    case deliver(itemIds: [String], count: Int)
    /// Accumulated by gameplay events. Progress lives in the DB row.
    case counter(QuestCounter, target: Int)

    /// Units needed to complete.
    public var target: Int {
        switch self {
        case .deliver(_, let count):  return count
        case .counter(_, let target): return target
        }
    }
}

// MARK: - Reward

public struct QuestReward: Sendable {
    public let silver: Int
    public let xp: Int
    public let vigor: Int

    public init(silver: Int, xp: Int = 0, vigor: Int = 0) {
        self.silver = silver
        self.xp = xp
        self.vigor = vigor
    }
}

// MARK: - Definition

public struct QuestDef: Sendable {
    public let id: String
    public let npc: QuestNPC
    public let objective: QuestObjective
    /// Authored reward at level 1. What the player is actually paid grows with
    /// their level — see `QuestService.scaledReward`.
    public let reward: QuestReward
    /// Level from which the job is offered. The pool is filtered before the
    /// daily hash, so an unreachable job is never assigned.
    public let minLevel: Int

    public var titleKey: String { "quest.\(id).title" }
    public var descKey: String  { "quest.\(id).desc" }
}

// MARK: - Catalog

public enum QuestCatalog {

    /// Every job, grouped by NPC. Sizing intent: a job should pay roughly
    /// 1.5–2× what selling the same materials to the trader would, so the
    /// daily is worth a detour but doesn't dwarf ordinary play.
    ///
    /// **Pool ORDER is the assignment.** `daily` indexes
    /// `pool[stableHash(...) % pool.count]`, so moving a job within its pool
    /// silently reassigns every player. `quests.json` writes the pools as an
    /// ordered array and nothing sorts them.
    ///
    /// Computed, never a `static let` — the snapshot installs at boot.
    public static var pools: [QuestNPC: [QuestDef]] { Catalogs.current.questPools }

    /// Look a job up by id — used when re-hydrating a stored row, so a pool
    /// edit mid-day can't silently swap the job a player already started.
    public static func find(_ id: String) -> QuestDef? {
        return Catalogs.current.questsById[id]
    }

    /// The job `npc` is offering `userId` on the game day `stamp`, at `level`.
    ///
    /// Deterministic by construction: no RNG, no stored assignment. Note this
    /// deliberately avoids Swift's `Hasher`, which is seeded per process — the
    /// pick has to survive a bot restart mid-day.
    ///
    /// `level` filters the pool BEFORE the hash. Jobs whose materials live at
    /// km 11 (iron) or behind an estate room (the forge, the kitchen) are not
    /// offered to a player who cannot reach them — a daily that cannot be done
    /// is a day with one fewer job, not a challenge. The validator guarantees
    /// every pool keeps at least one level-1 job, so the filtered pool is never
    /// empty for a real player.
    public static func daily(npc: QuestNPC, userId: UUID, stamp: String, level: Int) -> QuestDef {
        let all = pools[npc] ?? []
        let pool = all.filter { $0.minLevel <= level }
        // Pools are content and never empty; both fallbacks only exist so the
        // signature stays non-optional at every call site.
        guard !pool.isEmpty else {
            guard let first = all.first else {
                return QuestDef(id: "\(npc.rawValue).none", npc: npc,
                                objective: .counter(.beastKill, target: 1),
                                reward: QuestReward(silver: 0), minLevel: 1)
            }
            return first
        }
        let key = "\(userId.uuidString):\(npc.rawValue):\(stamp)"
        return pool[Int(stableHash(key) % UInt64(pool.count))]
    }

    /// FNV-1a, 64-bit. Stable across processes, platforms and releases.
    static func stableHash(_ string: String) -> UInt64 {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in string.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01b3
        }
        return hash
    }
}
