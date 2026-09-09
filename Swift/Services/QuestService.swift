//
//  QuestService.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 23.08.2026.
//
//  Phase 9.2 — the whole daily-quest loop: read today's job, take it at the
//  NPC, tick counters from gameplay events, hand items in, pay out.
//
//  **A job has to be taken before it runs** (2026-09-07). The day still decides
//  WHICH job each NPC offers — `QuestCatalog.daily`, a stable hash — but the
//  offer sits on the board until the player accepts it in the capital, and
//  `record` ticks nothing before that. Taking a job starts the count; it never
//  backfills what happened earlier in the day.
//
//  Two objective shapes, two very different progress stories:
//    • `deliver` — progress is READ LIVE from the bag, never stored. Nothing to
//      keep in sync, and the player can gather in any order, anywhere. The
//      items are consumed at turn-in, which also pays the reward in one step.
//    • `counter` — progress is accumulated by `record(...)` from hook sites in
//      combat / crafting / the trader / the tavern, and only for a row the
//      player accepted. Once it hits the target the reward is claimed at the NPC.
//
//  Every payout goes through `payOut`, so silver / XP / Vigor accounting (and
//  the level-up banner data) lives in exactly one place.
//

import Fluent
import Foundation

public enum QuestService {

    // MARK: - Types

    /// Everything the quest-board screen needs to render, in one read.
    public struct Status: Sendable {
        public let def: QuestDef
        /// Units done: live bag count for `deliver`, stored progress for `counter`.
        public let done: Int
        public let target: Int
        /// What this job pays THIS player — the authored reward scaled to their
        /// level. The board and the journal must quote this, not `def.reward`,
        /// or the screen promises one number and the payout hands over another.
        public let reward: QuestReward
        /// The player took the job at the NPC. False = the board is showing an
        /// offer, not a job in progress.
        public let accepted: Bool
        public let claimed: Bool

        /// Show the action button — the job is finishable right now.
        public var isActionable: Bool { accepted && !claimed && done >= target }
    }

    /// What a payout actually moved. `xpResult` carries the level-up / estate-up
    /// data so the banner can echo the same lines combat victories use.
    public struct Payout: Sendable {
        public let silver: Int
        public let xp: Int
        public let vigor: Int
        public let xpResult: User.XPGrantResult?
    }

    /// Outcome of taking a job at the NPC.
    public enum AcceptResult: Sendable {
        case taken(def: QuestDef)
        case alreadyTaken(def: QuestDef)
        case alreadyClaimed
    }

    public enum FinishResult: Sendable {
        case paid(def: QuestDef, payout: Payout)
        /// The job was never taken — nothing to hand in.
        case notTaken
        /// Deliver job, bag is short. `have`/`need` drive the toast.
        case notEnough(have: Int, need: Int)
        /// Counter job that hasn't reached its target yet.
        case notComplete(done: Int, need: Int)
        case alreadyClaimed
    }

    // MARK: - Reading today's job

    /// The job `npc` offers this player today. Prefers the id stored on today's
    /// row (if one exists) over a fresh derivation, so a catalog edit mid-day
    /// can't move the goalposts on a player who already started.
    public static func activeQuest(
        for user: User,
        npc: QuestNPC,
        on db: any Database,
        now: Date = Date()
    ) async throws -> QuestDef {
        let stamp = GameDay.stamp(now)
        guard let userId = user.id else {
            return QuestCatalog.daily(npc: npc, userId: UUID(), stamp: stamp, level: user.level)
        }
        if let row = try await QuestProgress.find(userId: userId, npc: npc, stamp: stamp, on: db),
           let stored = QuestCatalog.find(row.questId) {
            return stored
        }
        return QuestCatalog.daily(npc: npc, userId: userId, stamp: stamp, level: user.level)
    }

    /// Today's row, created on demand.
    private static func rowForToday(
        user: User,
        npc: QuestNPC,
        on db: any Database,
        now: Date = Date()
    ) async throws -> QuestProgress? {
        guard let userId = user.id else { return nil }
        let stamp = GameDay.stamp(now)
        if let existing = try await QuestProgress.find(userId: userId, npc: npc, stamp: stamp, on: db) {
            return existing
        }
        let def = QuestCatalog.daily(npc: npc, userId: userId, stamp: stamp, level: user.level)
        let fresh = QuestProgress(userID: userId, npc: npc, questId: def.id, dayStamp: stamp)
        try await fresh.save(on: db)
        return fresh
    }

    /// Full board state for one NPC. Read-only apart from lazily creating the
    /// day's row.
    public static func status(
        for user: User,
        npc: QuestNPC,
        on db: any Database,
        now: Date = Date()
    ) async throws -> Status {
        let row = try await rowForToday(user: user, npc: npc, on: db, now: now)
        let def: QuestDef
        if let stored = row.flatMap({ QuestCatalog.find($0.questId) }) {
            def = stored
        } else {
            def = try await activeQuest(for: user, npc: npc, on: db, now: now)
        }
        let claimed = row?.claimed ?? false
        let accepted = row?.accepted ?? false

        let done: Int
        switch def.objective {
        case .deliver(let itemIds, let count):
            // Once paid, freeze the readout at the target — the items are gone
            // from the bag and a live count would read as "0/10 done".
            done = claimed ? count : (try await carried(itemIds, user: user, on: db))
        case .counter:
            done = row?.progress ?? 0
        }
        return Status(def: def, done: done, target: def.objective.target,
                      reward: scaledReward(def.reward, level: user.level),
                      accepted: accepted, claimed: claimed)
    }

    /// Accepted, unpaid delivery jobs that want `itemId` today, with how many
    /// units the player carries against the target.
    ///
    /// Reads existing rows ONLY — deliberately not `status`, which lazily
    /// creates the day's row. A trade screen is not the job board, and a row
    /// written from here would turn "the player looked at selling hides" into
    /// a day whose job is already on the books.
    public static func acceptedDeliveries(
        of itemId: String,
        for user: User,
        on db: any Database,
        now: Date = Date()
    ) async throws -> [(def: QuestDef, done: Int, target: Int)] {
        guard let userId = user.id else { return [] }
        let rows = try await QuestProgress.query(on: db)
            .filter(\.$user.$id, .equal, userId)
            .filter(\.$dayStamp, .equal, GameDay.stamp(now))
            .filter(\.$accepted, .equal, true)
            .filter(\.$claimed, .equal, false)
            .all()

        var out: [(def: QuestDef, done: Int, target: Int)] = []
        for row in rows {
            guard let def = QuestCatalog.find(row.questId),
                  case .deliver(let itemIds, let count) = def.objective,
                  itemIds.contains(itemId) else { continue }
            out.append((def, try await carried(itemIds, user: user, on: db), count))
        }
        return out
    }

    // MARK: - Taking the job

    /// Take today's job at `npc`. The offer itself is still decided by
    /// `QuestCatalog.daily` — this only starts it, which is what makes a
    /// counter event count.
    @discardableResult
    public static func accept(
        npc: QuestNPC,
        for user: User,
        on db: any Database,
        now: Date = Date()
    ) async throws -> AcceptResult {
        guard let row = try await rowForToday(user: user, npc: npc, on: db, now: now) else {
            return .alreadyClaimed
        }
        let def: QuestDef
        if let stored = QuestCatalog.find(row.questId) {
            def = stored
        } else {
            def = try await activeQuest(for: user, npc: npc, on: db, now: now)
        }
        guard !row.claimed else { return .alreadyClaimed }
        guard !row.accepted else { return .alreadyTaken(def: def) }
        row.accepted = true
        try await row.save(on: db)
        return .taken(def: def)
    }

    // MARK: - Reward scaling

    /// The authored level-1 reward, grown to `level`. One function so the board,
    /// the journal and the payout can never disagree; the curves themselves live
    /// in `ProgressionMath` beside the ones they ride.
    public static func scaledReward(_ base: QuestReward, level: Int) -> QuestReward {
        let progression = Catalogs.current.tuningProgression
        let scaled = ProgressionMath.questReward(
            silver: base.silver, xp: base.xp, vigor: base.vigor,
            level: level,
            silverPerLevel: Catalogs.current.tuningEconomy.questRewards.silverPerLevel,
            mobXP: progression.mobXP,
            pool: progression.vigorPool
        )
        return QuestReward(silver: scaled.silver, xp: scaled.xp, vigor: scaled.vigor)
    }

    /// Units of any of `itemIds` currently in the player's bag.
    private static func carried(_ itemIds: [String], user: User, on db: any Database) async throws -> Int {
        guard let userId = user.id else { return 0 }
        var total = 0
        for itemId in itemIds {
            total += try await InventoryEntry.totalQuantity(of: itemId, for: userId, on: db)
        }
        return total
    }

    // MARK: - Counter events

    /// Tick a counter objective. Called from gameplay hook sites (combat kills,
    /// forge output, trader sales, tavern wins).
    ///
    /// Cheap and self-contained: it derives today's job for each NPC and only
    /// touches the DB when one of them actually counts this event. Hook sites
    /// should call it best-effort (`try?`) — a quest counter must never be able
    /// to break a fight, a craft or a sale.
    public static func record(
        _ counter: QuestCounter,
        amount: Int = 1,
        for user: User,
        on db: any Database,
        now: Date = Date()
    ) async throws {
        guard amount > 0, let userId = user.id else { return }
        let stamp = GameDay.stamp(now)

        for npc in QuestNPC.allCases {
            // Only a job the player took can tick, so an absent row is an early
            // exit rather than something to create. That also means an event
            // fired before the job was taken is simply not counted — taking it
            // starts the clock, it does not backfill.
            guard let row = try await QuestProgress.find(userId: userId, npc: npc, stamp: stamp, on: db),
                  row.accepted else { continue }
            guard let def = QuestCatalog.find(row.questId) else { continue }

            guard case .counter(let wanted, let target) = def.objective, wanted == counter else { continue }
            guard !row.claimed, row.progress < target else { continue }
            row.progress = min(target, row.progress + amount)
            try await row.save(on: db)
        }
    }

    // MARK: - Finishing

    /// Hand in a deliver job (consumes the items) or claim a finished counter
    /// job. One entry point for both — the objective decides which path runs,
    /// and the caller just renders the result.
    public static func finish(
        npc: QuestNPC,
        for user: User,
        on db: any Database,
        now: Date = Date()
    ) async throws -> FinishResult {
        guard let row = try await rowForToday(user: user, npc: npc, on: db, now: now) else {
            return .alreadyClaimed
        }
        guard !row.claimed else { return .alreadyClaimed }
        guard row.accepted else { return .notTaken }
        let def: QuestDef
        if let stored = QuestCatalog.find(row.questId) {
            def = stored
        } else {
            def = try await activeQuest(for: user, npc: npc, on: db, now: now)
        }

        switch def.objective {
        case .deliver(let itemIds, let count):
            let have = try await carried(itemIds, user: user, on: db)
            guard have >= count else { return .notEnough(have: have, need: count) }

            // Drain in catalog order — for the "cooked dish ×3" job that means
            // roasted meat goes before stew, spending the cheaper dish first.
            var remaining = count
            for itemId in itemIds {
                guard remaining > 0, let userId = user.id else { break }
                let onHand = try await InventoryEntry.totalQuantity(of: itemId, for: userId, on: db)
                let take = min(onHand, remaining)
                guard take > 0 else { continue }
                let removed = try await InventoryEntry.remove(itemId, quantity: take, from: user, on: db)
                if removed { remaining -= take }
            }
            guard remaining == 0 else {
                // Bag changed under us mid-drain (concurrent update). Nothing is
                // paid out — re-read the bag so the toast quotes what's actually
                // left rather than the stale pre-drain count.
                let left = try await carried(itemIds, user: user, on: db)
                return .notEnough(have: left, need: count)
            }
            row.progress = count

        case .counter(_, let target):
            guard row.progress >= target else {
                return .notComplete(done: row.progress, need: target)
            }
        }

        let payout = try await payOut(scaledReward(def.reward, level: user.level), to: user, on: db)
        row.claimed = true
        try await row.save(on: db)
        return .paid(def: def, payout: payout)
    }

    // MARK: - Payout

    /// Apply a reward and persist the player. Vigor is clamped to the cap, so
    /// the reported amount is what actually landed, not what was offered.
    private static func payOut(_ reward: QuestReward, to user: User, on db: any Database) async throws -> Payout {
        user.silver += reward.silver

        var xpResult: User.XPGrantResult?
        if reward.xp > 0 {
            xpResult = user.grantXP(reward.xp)
        }

        var vigorRestored = 0
        if reward.vigor > 0 {
            let before = user.vigor
            user.vigor = min(user.maxVigor, user.vigor + reward.vigor)
            vigorRestored = user.vigor - before
        }

        try await user.saveAndCache(in: db)
        return Payout(
            silver: reward.silver,
            xp: xpResult?.xpAwarded ?? 0,
            vigor: vigorRestored,
            xpResult: xpResult
        )
    }
}
