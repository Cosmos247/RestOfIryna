//
//  QuestCatalog.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 23.08.2026.
//
//  Phase 9.2 — daily NPC quests. Three capital NPCs (Trader / Master /
//  Tavernkeeper) each hold a small pool of daily jobs. Exactly one job per NPC
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
//  the Tavernkeeper adds Vigor.
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
    public let reward: QuestReward

    public var titleKey: String { "quest.\(id).title" }
    public var descKey: String  { "quest.\(id).desc" }
}

// MARK: - Catalog

public enum QuestCatalog {

    /// Every job, grouped by NPC. Sizing intent: a job should pay roughly
    /// 1.5–2× what selling the same materials to the trader would, so the
    /// daily is worth a detour but doesn't dwarf ordinary play.
    ///
    /// `master.smelt` asks for ONE ingot, not the three sketched in the design
    /// pass — one ingot already costs 10 raw iron (≈100🪙 of material), which
    /// is a full expedition's worth. Three would be a week-long job wearing a
    /// daily's clothes.
    public static let pools: [QuestNPC: [QuestDef]] = [
        .trader: [
            QuestDef(id: "trader.hides", npc: .trader,
                     objective: .deliver(itemIds: ["mat.hide"], count: 10),
                     reward: QuestReward(silver: 60)),
            QuestDef(id: "trader.iron", npc: .trader,
                     objective: .deliver(itemIds: ["mat.iron"], count: 5),
                     reward: QuestReward(silver: 100)),
            QuestDef(id: "trader.bulk_day", npc: .trader,
                     objective: .counter(.traderSilver, target: 300),
                     reward: QuestReward(silver: 60)),
        ],
        .master: [
            QuestDef(id: "master.ore", npc: .master,
                     objective: .deliver(itemIds: ["mat.iron"], count: 8),
                     reward: QuestReward(silver: 100, xp: 40)),
            QuestDef(id: "master.smelt", npc: .master,
                     objective: .counter(.ironIngotForged, target: 1),
                     reward: QuestReward(silver: 120, xp: 60)),
            QuestDef(id: "master.blade_trial", npc: .master,
                     objective: .counter(.beastKill, target: 5),
                     reward: QuestReward(silver: 50, xp: 80)),
        ],
        .tavern: [
            QuestDef(id: "tavern.cook", npc: .tavern,
                     objective: .deliver(itemIds: ["food.roasted_meat", "food.hunters_stew"], count: 3),
                     reward: QuestReward(silver: 60, vigor: 25)),
            QuestDef(id: "tavern.supplies", npc: .tavern,
                     objective: .deliver(itemIds: ["food.raw_meat"], count: 6),
                     reward: QuestReward(silver: 60, vigor: 20)),
            QuestDef(id: "tavern.lucky_hand", npc: .tavern,
                     objective: .counter(.gambleWin, target: 3),
                     reward: QuestReward(silver: 50, vigor: 30)),
        ],
    ]

    /// Look a job up by id — used when re-hydrating a stored row, so a pool
    /// edit mid-day can't silently swap the job a player already started.
    public static func find(_ id: String) -> QuestDef? {
        for (_, pool) in pools {
            if let hit = pool.first(where: { $0.id == id }) { return hit }
        }
        return nil
    }

    /// The job `npc` is offering `userId` on the game day `stamp`.
    ///
    /// Deterministic by construction: no RNG, no stored assignment. Note this
    /// deliberately avoids Swift's `Hasher`, which is seeded per process — the
    /// pick has to survive a bot restart mid-day.
    public static func daily(npc: QuestNPC, userId: UUID, stamp: String) -> QuestDef {
        let pool = pools[npc] ?? []
        // Pools are compile-time constants and never empty; the fallback only
        // exists so the signature stays non-optional at every call site.
        guard !pool.isEmpty else {
            return QuestDef(id: "\(npc.rawValue).none", npc: npc,
                            objective: .counter(.beastKill, target: 1),
                            reward: QuestReward(silver: 0))
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
