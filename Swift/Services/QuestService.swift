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
//  **A taken job does not burn at noon** (2026-09-19). It stays open until it
//  is turned in, and while it is open the NPC offers nothing new — ONE open
//  job per NPC, so the board, the counters and the Turn in button never have
//  to choose between two. A job carried over from an earlier day is the only
//  kind that can be dropped (`abandon`). `QuestCarryOver` holds the one-time
//  cleanup of the rows the old noon rule left marked as taken.
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
        /// Taken on an EARLIER game day and not turned in. A taken job no longer
        /// burns at noon (2026-09-19): it stays the NPC's one open job, today's
        /// offer waits behind it, and it is the only kind that can be abandoned.
        public let carried: Bool

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
        /// Set when this payout also taught a recipe. Nil covers both "nothing
        /// was owed" and "already known", which the banner treats the same.
        public let learnedRecipeId: String?
    }

    /// Outcome of taking a job at the NPC.
    public enum AcceptResult: Sendable {
        case taken(def: QuestDef)
        case alreadyTaken(def: QuestDef)
        case alreadyClaimed
        /// A job from an earlier day is still open at this NPC. Only a stale
        /// button gets here — the board shows no Take while one is.
        case blockedByCarried(def: QuestDef)
    }

    /// Outcome of dropping a carried job.
    public enum AbandonResult: Sendable {
        case abandoned(def: QuestDef)
        /// Nothing carried at this NPC — already turned in, already dropped, or
        /// a job taken today, which cannot be dropped.
        case nothingToAbandon
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
        // A job carried over from an earlier day IS the board until it is
        // turned in or dropped; today's offer waits behind it.
        if let open = try await carriedRow(for: user, npc: npc, on: db, now: now),
           let def = QuestCatalog.find(open.questId) {
            let done: Int
            switch def.objective {
            case .deliver(let itemIds, _): done = try await carried(itemIds, user: user, on: db)
            case .counter:                 done = open.progress
            }
            return Status(def: def, done: done, target: def.objective.target,
                          reward: scaledReward(def.reward, level: user.level),
                          accepted: true, claimed: false, carried: true)
        }

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
                      accepted: accepted, claimed: claimed, carried: false)
    }

    /// Accepted, unpaid delivery jobs that want `itemId`, with how many units
    /// the player carries against the target. Any day's: a job carried over
    /// from yesterday wants its items exactly as much as today's does.
    ///
    /// Reads existing rows ONLY — deliberately not `status`, which lazily
    /// creates the day's row. A trade screen is not the job board, and a row
    /// written from here would turn "the player looked at selling hides" into
    /// a day whose job is already on the books.
    public static func acceptedDeliveries(
        of itemId: String,
        for user: User,
        on db: any Database
    ) async throws -> [(def: QuestDef, done: Int, target: Int)] {
        let rows = try await openRows(for: user, on: db)

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
    /// counter event count. Refused while a job from an earlier day is still
    /// open here: one open job per NPC is what lets every other reader assume
    /// there is only one.
    @discardableResult
    public static func accept(
        npc: QuestNPC,
        for user: User,
        on db: any Database,
        now: Date = Date()
    ) async throws -> AcceptResult {
        if let open = try await carriedRow(for: user, npc: npc, on: db, now: now),
           let def = QuestCatalog.find(open.questId) {
            return .blockedByCarried(def: def)
        }
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

    /// The recipe `npc` will teach on this payout, or nil. `finish` is the only
    /// caller: no screen quotes the recipe in advance (`CapitalController.rewardPhrase`).
    ///
    /// Reads the learned set ONLY when that NPC has rungs at all, so the Trader's
    /// and the Master's payouts cost exactly what they cost before this existed.
    /// The estate tier comes off the live row, not the row the job was taken on:
    /// building the kitchen mid-job should pay out today, not tomorrow.
    private static func pendingUnlock(for user: User, npc: QuestNPC, on db: any Database) async throws -> String? {
        guard RecipeCatalog.unlocks.contains(where: { $0.npc == npc.rawValue }) else { return nil }
        let known = try await LearnedRecipe.allIds(for: user, on: db)
        return RecipeCatalog.nextUnlock(npc: npc, estateTier: user.estateLevel, known: known)?.recipeId
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

    // MARK: - Open jobs

    /// Every job this player has taken and not turned in, whatever day it was
    /// taken on — at most one per NPC, which `accept` guarantees and the
    /// one-time `CloseBurnedQuestJobs` established for the rows the old rule
    /// left behind.
    private static func openRows(for user: User, on db: any Database) async throws -> [QuestProgress] {
        guard let userId = user.id else { return [] }
        return try await QuestProgress.query(on: db)
            .filter(\.$user.$id, .equal, userId)
            .filter(\.$accepted, .equal, true)
            .filter(\.$claimed, .equal, false)
            .all()
    }

    /// The open job at `npc` if it was taken on an EARLIER game day. A
    /// `yyyy-MM-dd` stamp compares as a string exactly as it does as a date.
    private static func carriedRow(for user: User, npc: QuestNPC, on db: any Database, now: Date) async throws -> QuestProgress? {
        guard let userId = user.id else { return nil }
        return try await QuestProgress.query(on: db)
            .filter(\.$user.$id, .equal, userId)
            .filter(\.$npc, .equal, npc.rawValue)
            .filter(\.$accepted, .equal, true)
            .filter(\.$claimed, .equal, false)
            .filter(\.$dayStamp, .lessThan, GameDay.stamp(now))
            .sort(\.$dayStamp, .descending)
            .first()
    }

    /// Whether any NPC is holding today's offer back behind an older job — the
    /// 12:00 notice says so when one is. Only a job the board can show counts,
    /// which is the same test `status` applies before it shows one.
    public static func hasCarriedJob(for user: User, on db: any Database, now: Date = Date()) async throws -> Bool {
        let today = GameDay.stamp(now)
        return try await openRows(for: user, on: db).contains {
            $0.dayStamp < today && QuestCatalog.find($0.questId) != nil
        }
    }

    // MARK: - Counter events

    /// Tick a counter objective. Called from gameplay hook sites (combat kills,
    /// forge output, trader sales, tavern wins).
    ///
    /// One read of the player's open jobs — whatever day each was taken on,
    /// since a carried job counts exactly like today's — and a write only for
    /// the one this event counts toward. Hook sites should call it best-effort
    /// (`try?`) — a quest counter must never be able to break a fight, a craft
    /// or a sale.
    public static func record(
        _ counter: QuestCounter,
        amount: Int = 1,
        for user: User,
        on db: any Database
    ) async throws {
        guard amount > 0 else { return }

        // Only a job the player took can tick, and taking it starts the clock —
        // an event fired before the job was taken is simply not counted.
        for row in try await openRows(for: user, on: db) {
            guard let def = QuestCatalog.find(row.questId),
                  case .counter(let wanted, let target) = def.objective, wanted == counter,
                  row.progress < target else { continue }
            row.progress = min(target, row.progress + amount)
            try await row.save(on: db)
        }
    }

    // MARK: - Finishing

    /// Hand in a deliver job (consumes the items) or claim a finished counter
    /// job. One entry point for both — the objective decides which path runs,
    /// and the caller just renders the result.
    ///
    /// The job is the NPC's ONE open job: a carried one if there is one, else
    /// today's. So the Turn in button needs no day of its own, and one tapped
    /// on yesterday's board after noon still hands in yesterday's job.
    public static func finish(
        npc: QuestNPC,
        for user: User,
        on db: any Database,
        now: Date = Date()
    ) async throws -> FinishResult {
        let row: QuestProgress
        if let open = try await carriedRow(for: user, npc: npc, on: db, now: now) {
            row = open
        } else if let today = try await rowForToday(user: user, npc: npc, on: db, now: now) {
            row = today
        } else {
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

        let payout = try await payOut(scaledReward(def.reward, level: user.level),
                                      teaching: try await pendingUnlock(for: user, npc: npc, on: db),
                                      to: user, on: db)
        row.claimed = true
        try await row.save(on: db)
        try? await KingService.record(.questTurnedIn, for: user, on: db)
        return .paid(def: def, payout: payout)
    }

    // MARK: - Dropping

    /// Drop the job carried over from an earlier day: no reward, the progress
    /// is gone, and today's offer opens. Only a CARRIED job (the owner's call,
    /// 2026-09-19) — one taken today still has its day ahead of it. The row
    /// goes back to being an offer nobody took, the state the old noon rule
    /// left every unfinished job in; `accept` only ever acts on today's row,
    /// so nothing can take it again.
    public static func abandon(
        npc: QuestNPC,
        for user: User,
        on db: any Database,
        now: Date = Date()
    ) async throws -> AbandonResult {
        guard let row = try await carriedRow(for: user, npc: npc, on: db, now: now),
              let def = QuestCatalog.find(row.questId) else {
            return .nothingToAbandon
        }
        row.accepted = false
        row.progress = 0
        try await row.save(on: db)
        return .abandoned(def: def)
    }

    // MARK: - Payout

    /// Apply a reward and persist the player. Vigor is clamped to the cap, so
    /// the reported amount is what actually landed, not what was offered — and
    /// the same is true of the recipe: `teaching` is what was OWED, and the
    /// Payout reports what was actually written, so a second claim on a recipe
    /// already held announces nothing.
    private static func payOut(_ reward: QuestReward, teaching recipeId: String?,
                               to user: User, on db: any Database) async throws -> Payout {
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

        // The recipe row goes in BEFORE the silver, and the order is the whole
        // safety here. `finish` marks the job claimed only after this returns, so
        // anything that throws in between leaves the job re-claimable — and if
        // the throw came after the player was paid, the second claim pays again.
        // Written this way the worst case is a recipe granted without its silver,
        // which the next claim settles and `add`'s idempotence absorbs.
        var taught: String?
        if let recipeId, try await LearnedRecipe.add(recipeId, for: user, on: db) {
            taught = recipeId
        }

        try await user.saveAndCache(in: db)

        return Payout(
            silver: reward.silver,
            xp: xpResult?.xpAwarded ?? 0,
            vigor: vigorRestored,
            xpResult: xpResult,
            learnedRecipeId: taught
        )
    }
}
