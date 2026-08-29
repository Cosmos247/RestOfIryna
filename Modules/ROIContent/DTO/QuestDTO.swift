//
//  QuestDTO.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 29.08.2026.
//
//  Wire format for `content/data/quests.json` — the daily NPC job pools.
//
//  **Pool order is gameplay.** `QuestCatalog.daily` resolves to
//  `pool[stableHash("<uuid>:<npc>:<day>") % pool.count]`, so the position of a
//  job inside its pool decides which player is handed it on which day.
//  Reordering a pool silently reassigns the entire playerbase while leaving
//  every record byte-identical — which is why the pools are written as an
//  ordered ARRAY of `{npc, quests}` rather than a JSON object, and why the
//  migration digest replays `daily` over 200 seeded users × 4 days.
//
//  `QuestObjective` is a tagged union on the wire, the same shape as
//  `ItemEffectDTO`: a `kind` discriminator plus the fields that kind uses.
//  Decoding an unknown kind FAILS rather than defaulting, because a silently
//  dropped objective would turn a job into one that can never be completed.
//
//  `QuestNPC` and `QuestCounter` stay in Swift. The first is a callback-data
//  token and a locale-key infix; the second names the four hook sites that tick
//  progress (combat victory, forge output, trader sale, tavern win). Both are
//  wired to code, not authored as content — the validator checks the strings
//  here against them.
//
//  Title and description keys derive from the id (`quest.<id>.title` / `.desc`),
//  so they are not written into the file.
//

import Foundation

/// One job's objective. `kind` discriminates; the other fields belong to it.
public struct QuestObjectiveDTO: Codable, Sendable, Equatable {
    public enum Kind: String, Codable, Sendable {
        /// Hand over `count` units, any mix of `itemIds`. Progress is read live
        /// from the bag and the items are consumed at turn-in.
        case deliver
        /// Accumulated by gameplay events; progress lives in the DB row.
        case counter
    }

    public let kind: Kind
    /// `deliver` only.
    public let itemIds: [String]
    /// `counter` only — matches a `QuestCounter` raw value.
    public let counter: String?
    /// Units needed to complete, whichever kind.
    public let target: Int

    public init(kind: Kind, itemIds: [String] = [], counter: String? = nil, target: Int) {
        self.kind = kind
        self.itemIds = itemIds
        self.counter = counter
        self.target = target
    }

    private enum CodingKeys: String, CodingKey { case kind, itemIds, counter, target }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        kind    = try c.decode(Kind.self, forKey: .kind)
        itemIds = try c.decodeIfPresent([String].self, forKey: .itemIds) ?? []
        counter = try c.decodeIfPresent(String.self, forKey: .counter)
        target  = try c.decode(Int.self, forKey: .target)
    }

    /// Writes only the half that belongs to `kind`, so a `deliver` row carries
    /// no null `counter` and vice versa.
    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(kind, forKey: .kind)
        switch kind {
        case .deliver: try c.encode(itemIds, forKey: .itemIds)
        case .counter: try c.encodeIfPresent(counter, forKey: .counter)
        }
        try c.encode(target, forKey: .target)
    }
}

/// Every job pays silver; each NPC layers its own accent on top — the Trader
/// pays more silver, the Master adds XP, the Innkeeper adds Vigor.
public struct QuestRewardDTO: Codable, Sendable, Equatable {
    public let silver: Int
    public let xp: Int
    public let vigor: Int

    public init(silver: Int, xp: Int = 0, vigor: Int = 0) {
        self.silver = silver
        self.xp = xp
        self.vigor = vigor
    }

    private enum CodingKeys: String, CodingKey { case silver, xp, vigor }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        silver = try c.decode(Int.self, forKey: .silver)
        xp     = try c.decodeIfPresent(Int.self, forKey: .xp)    ?? 0
        vigor  = try c.decodeIfPresent(Int.self, forKey: .vigor) ?? 0
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(silver, forKey: .silver)
        if xp    != 0 { try c.encode(xp,    forKey: .xp) }
        if vigor != 0 { try c.encode(vigor, forKey: .vigor) }
    }
}

public struct QuestDefDTO: Codable, Sendable, Equatable {
    public let id: String
    public let objective: QuestObjectiveDTO
    public let reward: QuestRewardDTO

    public init(id: String, objective: QuestObjectiveDTO, reward: QuestRewardDTO) {
        self.id = id
        self.objective = objective
        self.reward = reward
    }

    private enum CodingKeys: String, CodingKey { case id, objective, reward }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id        = try c.decode(String.self, forKey: .id)
        objective = try c.decode(QuestObjectiveDTO.self, forKey: .objective)
        reward    = try c.decode(QuestRewardDTO.self, forKey: .reward)
    }
}

/// One NPC's pool. The `npc` field is redundant on each job, so it lives here
/// once — a job's NPC is the pool it sits in.
public struct QuestPoolDTO: Codable, Sendable, Equatable {
    /// Matches a `QuestNPC` raw value.
    public let npc: String
    /// ORDER IS GAMEPLAY — see the file header.
    public let quests: [QuestDefDTO]

    public init(npc: String, quests: [QuestDefDTO]) {
        self.npc = npc
        self.quests = quests
    }

    private enum CodingKeys: String, CodingKey { case npc, quests }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        npc    = try c.decode(String.self, forKey: .npc)
        quests = try c.decode([QuestDefDTO].self, forKey: .quests)
    }
}

/// Top-level shape of `quests.json`.
public struct QuestFileDTO: Codable, Sendable {
    public let pools: [QuestPoolDTO]

    public init(pools: [QuestPoolDTO]) {
        self.pools = pools
    }

    private enum CodingKeys: String, CodingKey { case pools }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        pools = try c.decode([QuestPoolDTO].self, forKey: .pools)
    }
}
