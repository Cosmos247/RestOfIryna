//
//  PassiveExpeditionService.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 22.04.2026.
//
//  Phase 3.3 — passive expedition mode. The player picks a duration, the bot
//  sits on a `Task.sleep`, and when the timer elapses the service rolls the
//  full expedition in one pass, persists a JSON report on `ExplorationState`,
//  and pushes a completion message to the player's chat.
//
//  This is the first real background-running code in the project. The
//  scheduler is deliberately simple: each `start` spawns a `Task.detached`
//  that sleeps the duration and then runs the simulation. On bot restart the
//  sleeps are lost, so `rescheduleInflight` is called from `configure.swift`
//  to pick up every in-flight passive expedition and either re-arm or deliver
//  its report immediately (if the endsAt already passed during downtime).
//
//  Since 2026-10-12 the run is there and back in the same time (`PassiveRoute`):
//  half the strides out, half home, the last stride the manor door. It used to
//  walk only deeper and land home the moment its last step ended — the road
//  back free, and the depth it never walked back from banked on the board. The
//  governor turns early below a share of his HP, or when his Vigor only covers
//  the road home and nothing is left to eat; he eats from the bag only when he
//  must, the smallest portion first. While he is out the bag is his: the player
//  can look into it and change nothing (`InventoryController`).
//
//  Each stride reuses `ExplorationService.rollStep`. Loot lands in the
//  player's inventory as it would in active mode (with full-bag fallback);
//  HP/vigor mutate on the real user model.
//

import Fluent
import Foundation
@preconcurrency import Lingo
import SwiftTelegramBot

// MARK: - Duration catalogue

/// Three duration choices shown in the picker. Values are "units"; one unit is
/// `tuning/time.json` → `gameTime.passiveExpedition.secondsPerUnit` divided by
/// `time.scale` — a minute at release pacing. How many strides each buys, and
/// so how deep the governor goes, is `PassiveRoute` over `unitsPerStep`.
public enum PassiveDuration: Int, CaseIterable, Sendable {
    case short = 30
    case medium = 60
    case long = 90
}

// MARK: - Report model (JSON-persisted)

public struct PassiveReport: Codable, Sendable {
    /// Strides walked, out and home. Nothing in this binary reads it; it is
    /// written for the binaries before `fac8d5f`, which decode it as REQUIRED
    /// and skip a report they cannot read without deleting its row — so a
    /// rollback past this build would strand every report not yet read.
    public let stepsTaken: Int
    public let finalDepth: Int
    public let hpBefore: Int
    public let hpAfter: Int
    public let vigorBefore: Int
    public let vigorAfter: Int
    public let died: Bool
    public let deathDepth: Int?
    public let outcomeCounts: [String: Int]
    public let loot: [LootEntry]
    /// Phase 5.3a — XP awarded at expedition end (sum of every win's
    /// `enemy.xpReward`). Levels gained / new level captured separately so
    /// renderer can show "📖 +N XP (Lv. M → M+L)" without re-deriving.
    /// Optional in storage for backwards compat with pre-5.3a reports.
    public let xpEarned: Int
    /// Coins picked up along the way. Unlike `xpEarned` this was already
    /// credited to `user.silver` step by step — it is carried here only so the
    /// report can say so. A run that ends in death keeps it: `applyDeath`
    /// empties the bag, and silver was never in the bag.
    public let silverFound: Int
    public let levelsGained: Int
    public let newLevel: Int
    /// Stat growth totals from the XP grant — all zeroes unless the
    /// expedition levelled the player. Printed by `LevelUpBanner`.
    public let growth: User.StatGrowth
    /// Steps on which hunger bit, and the HP it took across all of them.
    /// NOT an `outcomeCounts` bucket: hunger can land on any step, so counting
    /// it there would hide the event that step actually rolled and stop the
    /// buckets summing to the step count. Zero on reports written before this
    /// pair existed.
    public let starvationSteps: Int
    public let starvationHpLost: Int
    /// What the governor ate on the road (2026-10-12), item id → units. He eats
    /// only when he must, but it is the player's food, so the report names it.
    /// `loot` is net of it: a berry found and then eaten was not brought back.
    public let eaten: [String: Int]
    /// Where he turned for home short of the planned depth, and why —
    /// `TurnReason`'s raw value. Both nil when he walked the whole route.
    public let turnKm: Int?
    public let turnReason: String?
    /// What the forest took when he fell: the bag as `wipeOnDeath` emptied it.
    public let lost: [LostEntry]
    /// He fell on the road home rather than on the way out.
    public let diedOnWayBack: Bool

    public struct LootEntry: Codable, Sendable {
        public let itemId: String
        public let pickedQuantity: Int
        public let droppedQuantity: Int
    }

    /// One line of a death's loss. The tier rides along because an item id
    /// alone cannot name a row of a weapon ladder.
    public struct LostEntry: Codable, Sendable {
        public let itemId: String
        public let tier: Int
        public let quantity: Int
    }

    /// Why the governor turned early.
    public enum TurnReason: String, Sendable {
        case wounds
        case hunger
    }

    public init(
        stepsTaken: Int, finalDepth: Int,
        hpBefore: Int, hpAfter: Int,
        vigorBefore: Int, vigorAfter: Int,
        died: Bool, deathDepth: Int?,
        outcomeCounts: [String: Int],
        loot: [LootEntry],
        xpEarned: Int = 0,
        silverFound: Int = 0,
        levelsGained: Int = 0,
        newLevel: Int = 1,
        growth: User.StatGrowth = User.StatGrowth(),
        starvationSteps: Int = 0,
        starvationHpLost: Int = 0,
        eaten: [String: Int] = [:],
        turnKm: Int? = nil,
        turnReason: String? = nil,
        lost: [LostEntry] = [],
        diedOnWayBack: Bool = false
    ) {
        self.stepsTaken = stepsTaken
        self.finalDepth = finalDepth
        self.hpBefore = hpBefore
        self.hpAfter = hpAfter
        self.vigorBefore = vigorBefore
        self.vigorAfter = vigorAfter
        self.died = died
        self.deathDepth = deathDepth
        self.outcomeCounts = outcomeCounts
        self.loot = loot
        self.xpEarned = xpEarned
        self.silverFound = silverFound
        self.levelsGained = levelsGained
        self.newLevel = newLevel
        self.growth = growth
        self.starvationSteps = starvationSteps
        self.starvationHpLost = starvationHpLost
        self.eaten = eaten
        self.turnKm = turnKm
        self.turnReason = turnReason
        self.lost = lost
        self.diedOnWayBack = diedOnWayBack
    }

    enum CodingKeys: String, CodingKey {
        case stepsTaken, finalDepth, hpBefore, hpAfter, vigorBefore, vigorAfter
        case died, deathDepth, outcomeCounts, loot, xpEarned, levelsGained, newLevel
        case growth, starvationSteps, starvationHpLost, silverFound
        case eaten, turnKm, turnReason, lost, diedOnWayBack
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        stepsTaken = try c.decode(Int.self, forKey: .stepsTaken)
        finalDepth = try c.decode(Int.self, forKey: .finalDepth)
        hpBefore = try c.decode(Int.self, forKey: .hpBefore)
        hpAfter = try c.decode(Int.self, forKey: .hpAfter)
        vigorBefore = try c.decode(Int.self, forKey: .vigorBefore)
        vigorAfter = try c.decode(Int.self, forKey: .vigorAfter)
        died = try c.decode(Bool.self, forKey: .died)
        deathDepth = try c.decodeIfPresent(Int.self, forKey: .deathDepth)
        outcomeCounts = try c.decode([String: Int].self, forKey: .outcomeCounts)
        loot = try c.decode([LootEntry].self, forKey: .loot)
        xpEarned = (try? c.decode(Int.self, forKey: .xpEarned)) ?? 0
        silverFound = (try? c.decode(Int.self, forKey: .silverFound)) ?? 0
        levelsGained = (try? c.decode(Int.self, forKey: .levelsGained)) ?? 0
        newLevel = (try? c.decode(Int.self, forKey: .newLevel)) ?? 1
        growth = (try? c.decode(User.StatGrowth.self, forKey: .growth)) ?? User.StatGrowth()
        starvationSteps = (try? c.decode(Int.self, forKey: .starvationSteps)) ?? 0
        starvationHpLost = (try? c.decode(Int.self, forKey: .starvationHpLost)) ?? 0
        eaten = (try? c.decode([String: Int].self, forKey: .eaten)) ?? [:]
        turnKm = try? c.decodeIfPresent(Int.self, forKey: .turnKm)
        turnReason = try? c.decodeIfPresent(String.self, forKey: .turnReason)
        lost = (try? c.decode([LostEntry].self, forKey: .lost)) ?? []
        diedOnWayBack = (try? c.decode(Bool.self, forKey: .diedOnWayBack)) ?? false
    }
}

/// Per-step running snapshot persisted on `ExplorationState.runningReportJSON`
/// so a bot restart resumes with the full event history. Updated alongside
/// `stepsDeep` after every simulated step in `runLive`. The two HP/vigor
/// fields are captured in `start()` from the user model — that's the moment
/// the player committed to the expedition, so the report's "started with X"
/// reads naturally even if the bot crashes before the first step fires.
public struct RunningPassiveReport: Codable, Sendable {
    public var hpBefore: Int
    public var vigorBefore: Int
    public var outcomeCounts: [String: Int]
    public var lootPicked: [String: Int]
    public var lootDropped: [String: Int]
    /// Phase 5.3a — accumulator for XP earned across the expedition. Granted
    /// in one call at finalize time. Optional in storage for backwards
    /// compatibility with pre-5.3a in-flight rows.
    public var xpEarned: Int
    /// Coins found so far. Persisted for the same reason the hunger totals are:
    /// a bot restart mid-run must resume the count, not report a poorer walk
    /// than the player actually had. The silver itself is already in their
    /// purse either way.
    public var silverFound: Int
    /// Hunger's running totals. Persisted with the rest so a bot restart
    /// mid-run resumes the count instead of reporting a shorter famine than
    /// the player actually walked through.
    public var starvationSteps: Int
    public var starvationHpLost: Int
    /// The route, stamped when the run starts (2026-10-12) so that a `/reload`
    /// of the stride cannot reshape a run already walking: the seconds a stride
    /// takes and the planned turnaround. Nil on a row started before the
    /// rework, which `PassiveExpeditionService.route` derives once.
    public var strideSeconds: Double?
    public var plannedDepth: Int?
    /// Strides walked so far, the door's included. `stepsDeep` is only where
    /// he stands, and it falls again on the road home.
    public var strides: Int
    public var returning: Bool
    /// Where and why he turned short of `plannedDepth` (`PassiveReport`).
    public var turnKm: Int?
    public var turnReason: String?
    /// What he has eaten so far, item id → units.
    public var eaten: [String: Int]
    /// He fell on the road home.
    public var diedOnWayBack: Bool

    public init(
        hpBefore: Int, vigorBefore: Int,
        outcomeCounts: [String: Int],
        lootPicked: [String: Int], lootDropped: [String: Int],
        xpEarned: Int = 0,
        silverFound: Int = 0,
        starvationSteps: Int = 0,
        starvationHpLost: Int = 0,
        strideSeconds: Double? = nil,
        plannedDepth: Int? = nil,
        strides: Int = 0,
        returning: Bool = false,
        turnKm: Int? = nil,
        turnReason: String? = nil,
        eaten: [String: Int] = [:],
        diedOnWayBack: Bool = false
    ) {
        self.hpBefore = hpBefore
        self.vigorBefore = vigorBefore
        self.outcomeCounts = outcomeCounts
        self.lootPicked = lootPicked
        self.lootDropped = lootDropped
        self.xpEarned = xpEarned
        self.silverFound = silverFound
        self.starvationSteps = starvationSteps
        self.starvationHpLost = starvationHpLost
        self.strideSeconds = strideSeconds
        self.plannedDepth = plannedDepth
        self.strides = strides
        self.returning = returning
        self.turnKm = turnKm
        self.turnReason = turnReason
        self.eaten = eaten
        self.diedOnWayBack = diedOnWayBack
    }

    enum CodingKeys: String, CodingKey {
        case hpBefore, vigorBefore, outcomeCounts, lootPicked, lootDropped, xpEarned, silverFound
        case starvationSteps, starvationHpLost
        case strideSeconds, plannedDepth, strides, returning, turnKm, turnReason, eaten, diedOnWayBack
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        hpBefore = try c.decode(Int.self, forKey: .hpBefore)
        vigorBefore = try c.decode(Int.self, forKey: .vigorBefore)
        outcomeCounts = try c.decode([String: Int].self, forKey: .outcomeCounts)
        lootPicked = try c.decode([String: Int].self, forKey: .lootPicked)
        lootDropped = try c.decode([String: Int].self, forKey: .lootDropped)
        xpEarned = (try? c.decode(Int.self, forKey: .xpEarned)) ?? 0
        silverFound = (try? c.decode(Int.self, forKey: .silverFound)) ?? 0
        starvationSteps = (try? c.decode(Int.self, forKey: .starvationSteps)) ?? 0
        starvationHpLost = (try? c.decode(Int.self, forKey: .starvationHpLost)) ?? 0
        strideSeconds = try? c.decodeIfPresent(Double.self, forKey: .strideSeconds)
        plannedDepth = try? c.decodeIfPresent(Int.self, forKey: .plannedDepth)
        // A row from before the rework walked outward only, one km a stride,
        // so its stride count is its depth: `route` fills it in from there.
        strides = (try? c.decode(Int.self, forKey: .strides)) ?? 0
        returning = (try? c.decode(Bool.self, forKey: .returning)) ?? false
        turnKm = try? c.decodeIfPresent(Int.self, forKey: .turnKm)
        turnReason = try? c.decodeIfPresent(String.self, forKey: .turnReason)
        eaten = (try? c.decode([String: Int].self, forKey: .eaten)) ?? [:]
        diedOnWayBack = (try? c.decode(Bool.self, forKey: .diedOnWayBack)) ?? false
    }
}

// MARK: - Service

public enum PassiveExpeditionService {

    /// How many real seconds a single "duration unit" represents, compressed
    /// by `time.scale`.
    static var secondsPerUnit: TimeInterval {
        let content = Catalogs.current
        return content.tuningTime.gameTime.passiveExpedition.secondsPerUnit / content.timeScale
    }

    // MARK: Start

    /// How deep a run of this duration turns for home — the number its picker
    /// button shows, from the same rule the run walks by. At least one km, so
    /// a stride retuned past half the run still walks out and back.
    public static func depth(of duration: PassiveDuration) -> Int {
        max(1, PassiveRoute.depth(strides: PassiveRoute.strides(minutes: duration.rawValue, unitsPerStep: unitsPerStep)))
    }

    /// Begin a passive expedition. Creates the `ExplorationState` row with
    /// `mode = .passive` and `endsAt` at the end of its route, then arms a
    /// detached task that walks it stride by stride and pushes the report at
    /// the manor door.
    @discardableResult
    public static func start(
        for user: User,
        duration: PassiveDuration,
        on db: any Database,
        bot: TGBot,
        lingo: Lingo
    ) async throws -> ExplorationState {
        let now = Date()
        // The route is planned now and stamped on the row below: there and
        // back over the strides this duration buys, so it ends when it says.
        let strideSeconds = stepDurationSeconds
        let depth = depth(of: duration)
        let endsAt = now.addingTimeInterval(Double(depth + PassiveRoute.stridesHome(fromKm: depth)) * strideSeconds)

        // The expedition row first, the budget after it: if `beginPassive`
        // throws, the player must not be left having paid for a run that does
        // not exist. The reverse order costs at worst a free run, which is the
        // cheaper way to be wrong.
        let state = try await ExplorationState.beginPassive(for: user, endsAt: endsAt, on: db)
        try? await KingService.record(.passiveSent, for: user, on: db)

        // Committed here, at the one place every passive run starts — the
        // controller checks the ceiling first so the player gets a reason
        // rather than a silent refusal, but this is what makes it real.
        // Persisted explicitly rather than left to `suspendResting` below,
        // which saves only when it actually stopped a running clock: a player
        // who departs with no clock running would otherwise spend nothing.
        spend(duration, for: user, now: now)
        try await user.saveAndCache(in: db)
        // The whole point of a passive run is that the player taps nothing
        // while it lasts, so the clock has to be stopped here rather than by
        // the next tick — otherwise the pre-departure stamp survives the run
        // and refunds its damage the moment they come back.
        try await HealingService.suspendResting(user, on: db)

        // Snapshot HP / vigor at expedition start so the final report reads
        // "started with X HP, Y vigor" regardless of when the simulation
        // actually finalizes (could be moments after start, could be after a
        // bot restart catches up). Empty counters/loot — the per-step writes
        // in `runLive` fill them in.
        let initialReport = RunningPassiveReport(
            hpBefore: user.hp,
            vigorBefore: user.vigor,
            outcomeCounts: [:],
            lootPicked: [:],
            lootDropped: [:],
            strideSeconds: strideSeconds,
            plannedDepth: depth
        )
        if let blob = encodeRunningReport(initialReport) {
            state.runningReportJSON = blob
            try? await state.save(on: db)
        }

        scheduleCompletion(stateId: state.id, endsAt: endsAt, db: db, bot: bot, lingo: lingo)
        return state
    }

    /// Serialize a running report for persistence. Returns nil only on
    /// encoder failure (effectively impossible for `Codable` values built
    /// from primitives, but the call site stays defensive).
    private static func encodeRunningReport(_ report: RunningPassiveReport) -> String? {
        guard let data = try? JSONEncoder().encode(report) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// Decode a running report from persistence. Returns nil for legacy
    /// rows (no JSON yet), corrupt blobs, or active expeditions (no
    /// running report by design).
    private static func decodeRunningReport(_ blob: String?) -> RunningPassiveReport? {
        guard let blob = blob, let data = blob.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(RunningPassiveReport.self, from: data)
    }

    // MARK: Scheduler

    /// How many "duration units" one stride takes — 3 since 2026-10-12, so the
    /// three choices buy 10/20/30 strides and turn at 5/10/15 km
    /// (`PassiveRoute`). A run stamps the value it started with, so a `/reload`
    /// reshapes only the runs after it.
    static var unitsPerStep: Int { Catalogs.current.tuningTime.gameTime.passiveExpedition.unitsPerStep }

    // MARK: - The daily budget

    /// Minutes of passive expedition a player may commit per game day.
    /// `tuning/exploration.json` → `passive.dailyBudgetMinutes`.
    ///
    /// Counted in the authored minutes the three choices are written in
    /// (`PassiveDuration.rawValue`), never in wall-clock seconds: `time.scale`
    /// stretches how long those minutes take to elapse, and a budget measured
    /// in seconds would silently mean a different number of expeditions at
    /// every scale.
    public static var dailyBudgetMinutes: Int {
        Catalogs.current.tuningExploration.passive.dailyBudgetMinutes
    }

    /// Minutes already committed today, reading the stamp rather than trusting
    /// the counter: a stored day key that is not today's means the counter
    /// belongs to a day that has ended, and it reads as zero. Nothing is
    /// written here — a screen that merely asks must not consume a rollover
    /// the player has not acted on.
    public static func minutesSpentToday(by user: User, now: Date = Date()) -> Int {
        return user.passiveDayStamp == GameDay.stamp(now) ? user.passiveMinutesToday : 0
    }

    /// What is left of today's budget.
    public static func minutesLeftToday(for user: User, now: Date = Date()) -> Int {
        return max(0, dailyBudgetMinutes - minutesSpentToday(by: user, now: now))
    }

    /// True when this duration still fits in what is left of the day.
    public static func canAfford(_ duration: PassiveDuration, for user: User, now: Date = Date()) -> Bool {
        return duration.rawValue <= minutesLeftToday(for: user, now: now)
    }

    /// Commit `duration` against today's budget. Called at the moment an
    /// expedition STARTS, not when it ends: the player is buying the time, and
    /// a run abandoned halfway has still spent the day's share of it.
    private static func spend(_ duration: PassiveDuration, for user: User, now: Date = Date()) {
        let stamp = GameDay.stamp(now)
        if user.passiveDayStamp != stamp {
            user.passiveDayStamp = stamp
            user.passiveMinutesToday = 0
        }
        user.passiveMinutesToday += duration.rawValue
    }

    /// Real-world wall-clock seconds per stride.
    static var stepDurationSeconds: TimeInterval {
        return Double(unitsPerStep) * secondsPerUnit
    }

    /// Where the governor stands now and which way he is going — the waiting
    /// screen's «📍». Nil before his first stride and once he is home.
    public static func position(of state: ExplorationState) -> (km: Int, returning: Bool)? {
        guard state.isPassive, state.stepsDeep > 0 else { return nil }
        return (state.stepsDeep, decodeRunningReport(state.runningReportJSON)?.returning ?? false)
    }

    /// Spawn a detached background task that walks the expedition stride by
    /// stride (`runLive`): each stride rolls one event and persists the route,
    /// and the run ends at the manor door or early on a death.
    public static func scheduleCompletion(
        stateId: UUID?,
        endsAt: Date,
        db: any Database,
        bot: TGBot,
        lingo: Lingo
    ) {
        guard let stateId = stateId else { return }
        Task.detached {
            await runLive(stateId: stateId, db: db, bot: bot, lingo: lingo)
        }
    }

    /// Startup-time sweep: spawn a fresh live task for every in-flight
    /// passive state. Each task reads the strides already walked from the
    /// running report and resumes from there — any strides whose time fell
    /// during downtime are walked back-to-back without sleeping (catch-up).
    public static func rescheduleInflight(
        on db: any Database,
        bot: TGBot,
        lingo: Lingo
    ) async throws {
        let passive = try await ExplorationState.allPassive(on: db)
        for state in passive {
            guard let stateId = state.id, let endsAt = state.endsAt else { continue }
            // Already-completed passive whose player hasn't opened the report
            // yet. Leave it alone — the controller delivers on next open.
            if state.reportJSON != nil { continue }
            scheduleCompletion(stateId: stateId, endsAt: endsAt, db: db, bot: bot, lingo: lingo)
        }
    }

    // MARK: Live simulation loop

    /// The `User` object the rest of the process is already mutating, falling
    /// back to the row this loop just loaded.
    ///
    /// A passive run walks for up to 90 minutes while the player keeps using
    /// the bot. Fluent writes only the fields a save changed, but
    /// `saveAndCache` installs what it saved as the next tap's session, so a
    /// loop saving its own copy would publish values read before the player's
    /// last tap. Requires `state.$user` to be loaded already (for the telegram
    /// id).
    private static func liveUser(for state: ExplorationState) async -> User {
        return await sessionCache.peek(telegramId: state.user.telegramId) ?? state.user
    }

    /// The stride every run was planned on before 2026-10-12.
    private static let legacyUnitsPerStep = 5

    /// The route a run walks: the seconds a stride takes and the planned
    /// turnaround, as stamped at departure. A row started before the
    /// 2026-10-12 rework carries neither. It was planned on 5-minute strides
    /// over `endsAt − createdAt` and walked outward only, one km a stride, so
    /// its stride count is its depth; from here on it walks home like any run.
    private static func route(for state: ExplorationState,
                              run: inout RunningPassiveReport) -> (strideSeconds: Double, depth: Int) {
        if let strideSeconds = run.strideSeconds, let depth = run.plannedDepth {
            return (strideSeconds, depth)
        }
        let strideSeconds = Double(legacyUnitsPerStep) * secondsPerUnit
        var planned = 2
        if let endsAt = state.endsAt, let createdAt = state.createdAt, strideSeconds > 0 {
            planned = Int((endsAt.timeIntervalSince(createdAt) / strideSeconds).rounded())
        }
        let depth = max(1, PassiveRoute.depth(strides: planned))
        run.strideSeconds = strideSeconds
        run.plannedDepth = depth
        run.strides = state.stepsDeep
        return (strideSeconds, depth)
    }

    /// Mark the turn for home short of the planned depth.
    private static func turn(_ run: inout RunningPassiveReport, atKm km: Int, reason: PassiveReport.TurnReason) {
        run.returning = true
        run.turnKm = km
        run.turnReason = reason.rawValue
    }

    /// The governor's meals: while `needs()` holds, one portion at a time,
    /// smallest first and what a taken job waits for last
    /// (`PassiveRoute.nextRation`). Stops when nothing in the bag feeds.
    ///
    /// These are the only meals of a run: the player's own taps on the bag are
    /// refused while he is out (`InventoryController`), which is why that lock
    /// sits at the bag's buttons and never in `VigorService` — here it would
    /// starve him too. Saved at once, because the units already left the bag.
    private static func eat(while needs: () -> Bool, user: User,
                            run: inout RunningPassiveReport, on db: any Database) async throws {
        guard needs() else { return }
        let wanted = try await QuestService.acceptedDeliveryItemIds(for: user, on: db)
        var ate = false
        while needs() {
            guard let itemId = try await eatOne(user: user, wanted: wanted, on: db) else { break }
            run.eaten[itemId, default: 0] += 1
            ate = true
        }
        if ate { try await user.saveAndCache(in: db) }
    }

    /// One portion: `consume` for the pools, then the unit out of the bag. The
    /// pools go back if the unit is gone by then. Nil when nothing feeds.
    private static func eatOne(user: User, wanted: Set<String>, on db: any Database) async throws -> String? {
        var held: [String: Int] = [:]
        for entry in try await InventoryEntry.list(for: user, on: db) where entry.equippedSlot == nil {
            held[entry.itemId, default: 0] += entry.quantity
        }
        let rations = held.compactMap { itemId, quantity -> PassiveRoute.Ration? in
            guard quantity > 0, let item = ItemCatalog.find(itemId), VigorService.isConsumable(item) else { return nil }
            var vigor = 0, hp = 0
            for effect in item.effects {
                switch effect {
                case .restoreVigor(let amount): vigor += amount
                case .restoreHP(let amount): hp += amount
                }
            }
            return PassiveRoute.Ration(itemId: itemId, vigor: vigor, hp: hp, wanted: wanted.contains(itemId))
        }
        guard let ration = PassiveRoute.nextRation(rations),
              let item = ItemCatalog.find(ration.itemId) else { return nil }
        let vigorBefore = user.vigor, hpBefore = user.hp
        guard VigorService.consume(item, user: user) != nil else { return nil }
        guard try await InventoryEntry.remove(item.id, quantity: 1, from: user, on: db) else {
            user.vigor = vigorBefore
            user.hp = hpBefore
            return nil
        }
        return item.id
    }

    /// The runner, one stride at a time: out to the planned depth or a turn,
    /// home, and the door. Exits at the door, on death (the report goes out at
    /// once), on the row disappearing, or on error.
    ///
    /// The route — strides walked, the direction, a turn and its reason, the
    /// food eaten — rides in `state.runningReportJSON` beside the outcome
    /// counters and is saved with `stepsDeep` after every stride, so a bot
    /// restart mid-run resumes on the right stride with the report whole.
    /// Strides fire on `createdAt` plus whole strides, so a restart catches up
    /// on the ones it slept through.
    private static func runLive(
        stateId: UUID,
        db: any Database,
        bot: TGBot,
        lingo: Lingo
    ) async {
        var carried: RunningPassiveReport?

        while true {
            guard let state = try? await ExplorationState.query(on: db).filter(\.$id, .equal, stateId).first(),
                  state.isPassive, state.reportJSON == nil,
                  let createdAt = state.createdAt else { return }
            try? await state.$user.load(on: db)

            // The first pass restores what an earlier process walked. A row
            // older than the running report captures its start from the live
            // user instead.
            var run: RunningPassiveReport
            if let carried {
                run = carried
            } else if let restored = decodeRunningReport(state.runningReportJSON) {
                run = restored
            } else {
                let user = await liveUser(for: state)
                run = RunningPassiveReport(hpBefore: user.hp, vigorBefore: user.vigor,
                                           outcomeCounts: [:], lootPicked: [:], lootDropped: [:])
            }
            let (strideSeconds, depth) = route(for: state, run: &run)
            // A pre-rework run resumed at or past its turnaround turns now.
            if !run.returning && state.stepsDeep >= depth {
                run.returning = true
                state.endsAt = createdAt.addingTimeInterval(
                    Double(run.strides + PassiveRoute.stridesHome(fromKm: state.stepsDeep)) * strideSeconds)
                state.runningReportJSON = encodeRunningReport(run)
                try? await state.save(on: db)
            }
            carried = run

            // At the door: the last stride is walked.
            if run.strides > 0 && state.stepsDeep == 0 {
                let user = await liveUser(for: state)
                await finalizeAndPush(state: state, user: user, run: run, died: false, deathDepth: nil,
                                      lost: [], on: db, bot: bot, lingo: lingo)
                return
            }

            let stride = run.strides + 1
            let waitSeconds = createdAt.addingTimeInterval(Double(stride) * strideSeconds).timeIntervalSinceNow
            if waitSeconds > 0 {
                try? await Task.sleep(nanoseconds: UInt64(waitSeconds * 1_000_000_000))
            }

            // Reload after the wait: the row may be gone, and the player may
            // have changed what the user holds.
            guard let state = try? await ExplorationState.query(on: db).filter(\.$id, .equal, stateId).first(),
                  state.isPassive, state.reportJSON == nil else { return }
            try? await state.$user.load(on: db)
            let user = await liveUser(for: state)
            let walkCost = VigorService.cost(of: .walkRoom)

            // The door: from km 1 on the road home the last stride rolls
            // nothing and costs nothing, as the active walk's last step does.
            // The tally still counts it (`User.recordStep`).
            if run.returning && state.stepsDeep <= 1 {
                user.recordStep()
                state.moveTo(km: 0)
                run.strides = stride
                carried = run
                state.runningReportJSON = encodeRunningReport(run)
                try? await state.save(on: db)
                try? await user.saveAndCache(in: db)
                continue
            }

            // He eats before a step that would leave him at 0: a fight that
            // begins at 0 is fought at the starvation penalty.
            do {
                try await eat(while: { PassiveRoute.mustEatBeforeStep(vigor: user.vigor, walkCost: walkCost) },
                              user: user, run: &run, on: db)
            } catch {
                appState?.logger.warning("Passive meal before stride \(stride) threw: \(error)")
            }

            let km = run.returning ? state.stepsDeep - 1 : state.stepsDeep + 1
            let result: StepResult
            do {
                result = try await ExplorationService.rollStep(
                    for: user,
                    kmDepth: km,
                    // The first stride out is fresh ground; every other stride,
                    // the road home included, rolls `passive.weights`. The
                    // walk-home tier is denser in fights, and the mode nobody
                    // watches must not fight more than the one they play.
                    priorVisits: !run.returning && stride <= ExplorationService.passiveTuning.freshStepCount ? 0 : 1,
                    mode: .passive,
                    on: db
                )
            } catch {
                appState?.logger.warning("Passive live stride \(stride) threw: \(error)")
                return
            }
            recordOutcome(result, into: &run, playerLevel: user.level)
            state.moveTo(km: km)
            run.strides = stride

            if user.hp <= 0 {
                // He fell: the report goes out now, not at the end of the time.
                run.diedOnWayBack = run.returning
                state.runningReportJSON = encodeRunningReport(run)
                try? await state.save(on: db)
                var lost: [InventoryEntry.DeathLoss] = []
                do {
                    lost = try await applyDeath(to: user, on: db)
                    try await user.saveAndCache(in: db)
                } catch {
                    appState?.logger.warning("applyDeath threw: \(error)")
                }
                await finalizeAndPush(state: state, user: user, run: run, died: true, deathDepth: km,
                                      lost: lost, on: db, bot: bot, lingo: lingo)
                return
            }

            // On the way out: the planned depth, wounds, or hunger with nothing
            // left to eat turn him. An early turn brings him home sooner, and
            // the waiting screen counts down to that.
            if !run.returning {
                if km >= depth {
                    run.returning = true
                } else if PassiveRoute.woundedEnough(hp: user.hp, maxHP: user.effectiveMaxHp,
                                                     share: ExplorationService.passiveTuning.retreatBelowHpPercent) {
                    turn(&run, atKm: km, reason: .wounds)
                } else {
                    do {
                        try await eat(while: { PassiveRoute.onlyRoadHomeLeft(vigor: user.vigor, km: km, walkCost: walkCost) },
                                      user: user, run: &run, on: db)
                    } catch {
                        appState?.logger.warning("Passive meal at km \(km) threw: \(error)")
                    }
                    if PassiveRoute.onlyRoadHomeLeft(vigor: user.vigor, km: km, walkCost: walkCost) {
                        turn(&run, atKm: km, reason: .hunger)
                    }
                }
                if run.turnKm == km {
                    state.endsAt = createdAt.addingTimeInterval(
                        Double(stride + PassiveRoute.stridesHome(fromKm: km)) * strideSeconds)
                }
            }

            carried = run
            state.runningReportJSON = encodeRunningReport(run)
            try? await state.save(on: db)
            try? await user.saveAndCache(in: db)
        }
    }

    /// Build the report, persist it on the state row, and push the
    /// completion message. The door and an early death share this tail.
    private static func finalizeAndPush(
        state: ExplorationState,
        user: User,
        run: RunningPassiveReport,
        died: Bool,
        deathDepth: Int?,
        lost: [InventoryEntry.DeathLoss],
        on db: any Database,
        bot: TGBot,
        lingo: Lingo
    ) async {
        // A governor who came back banks the run's deepest km; one who did not
        // banks nothing, which is the same rule the active walk applies at the
        // manor door (`ExplorationController.handleHomeReached`). Since
        // 2026-10-12 the depth is one he walked back from — it used to be one
        // he was teleported home from.
        //
        // Persisted right here rather than left to the XP save below, which
        // fires only when `xpAwarded > 0` — a quiet run that killed nothing
        // would bank the record in memory and drop it. Same reasoning as the
        // explicit save in `spend`.
        if !died {
            user.bankDepth(state.maxDepthKm)
            try? await user.saveAndCache(in: db)
        }

        // If the governor died, the bag stays with the corpse — the report
        // must not claim "brought back" anything; it names the losses instead.
        // Otherwise «Принесено» is net of what he ate: a berry found and then
        // eaten was not brought back.
        let loot: [PassiveReport.LootEntry]
        if died {
            loot = []
        } else {
            loot = Set(run.lootPicked.keys).union(run.lootDropped.keys).sorted().compactMap { id in
                let picked = max(0, run.lootPicked[id, default: 0] - run.eaten[id, default: 0])
                let dropped = run.lootDropped[id, default: 0]
                guard picked > 0 || dropped > 0 else { return nil }
                return PassiveReport.LootEntry(itemId: id, pickedQuantity: picked, droppedQuantity: dropped)
            }
        }

        // Phase 5.3a — grant accumulated XP. Even on death the player keeps
        // the XP earned from kills before they fell (XP isn't in inventory,
        // so applyDeath's wipe doesn't touch it). Persist the user separately
        // afterwards so the level-up survives.
        // Passive discounts land HERE, once, rather than per step: applying
        // them inside the loop would let a mid-run restart re-round every
        // partial total and drift the payout.
        let passive = ExplorationService.passiveTuning
        let xpResult = user.grantXP(Int((Double(run.xpEarned) * passive.xpMultiplier).rounded()))
        if xpResult.xpAwarded > 0 {
            try? await user.saveAndCache(in: db)
        }

        // Phase 6.5 — wear equipped gear (armor + weapon) for the whole run: each
        // won fight costs a little, each lost fight more (no flee in passive autobattle).
        let gearWear = run.outcomeCounts["encounter_won", default: 0] * GearConditionService.WearEvent.victory.amount
                     + run.outcomeCounts["encounter_lost", default: 0] * GearConditionService.WearEvent.defeat.amount
        let brokeOnRun = (try? await GearConditionService.drainEquippedGear(amount: gearWear, for: user, on: db)) ?? []

        // Phase 9.2 — autobattle kills count toward the Master's beast-slaying
        // job, banked in one go for the whole run (same as the XP grant above).
        // Kills made before a death still count; the run is over either way.
        let killsThisRun = run.outcomeCounts["encounter_won", default: 0]
        if killsThisRun > 0 {
            try? await QuestService.record(.beastKill, amount: killsThisRun, for: user, on: db)
            try? await KingService.record(.beastKill, amount: killsThisRun, for: user, on: db)
        }

        let report = PassiveReport(
            stepsTaken: run.strides,
            finalDepth: state.maxDepthKm,
            hpBefore: run.hpBefore,
            hpAfter: user.hp,
            vigorBefore: run.vigorBefore,
            vigorAfter: user.vigor,
            died: died,
            deathDepth: deathDepth,
            outcomeCounts: run.outcomeCounts,
            loot: loot,
            xpEarned: xpResult.xpAwarded,
            silverFound: run.silverFound,
            levelsGained: xpResult.levelsGained,
            newLevel: xpResult.newLevel,
            growth: xpResult.growth,
            starvationSteps: run.starvationSteps,
            starvationHpLost: run.starvationHpLost,
            eaten: run.eaten,
            turnKm: run.turnKm,
            turnReason: run.turnReason,
            lost: lost.map { PassiveReport.LostEntry(itemId: $0.itemId, tier: $0.tier, quantity: $0.quantity) },
            diedOnWayBack: died && run.diedOnWayBack
        )

        do {
            let data = try JSONEncoder().encode(report)
            state.reportJSON = String(data: data, encoding: .utf8)
            try await state.save(on: db)
        } catch {
            appState?.logger.warning("Failed to encode/save passive report: \(error)")
            return
        }

        do {
            try await pushReportNotification(state: state, user: user, bot: bot, lingo: lingo, db: db)
            // A piece that broke out there gets its own message: nobody was
            // watching the fight it broke in, and the next thing this player
            // does is decide whether to walk back out.
            for piece in brokeOnRun {
                guard let item = ItemCatalog.find(piece.itemId) else { continue }
                let name = lingo.localize(ItemDisplay.nameKey(for: item, tier: piece.tier), locale: user.locale)
                let text = "⚠️ " + ItemDisplay.localize("gear.broken.notice", agreeingWith: item,
                                                        lingo: lingo, locale: user.locale,
                                                        interpolations: ["item": name])
                _ = try? await bot.sendMessage(params: TGSendMessageParams(
                    chatId: .chat(user.telegramId), text: text, parseMode: .html
                ))
            }
        } catch {
            appState?.logger.warning("Passive report push failed: \(error)")
        }
    }

    private static func recordOutcome(_ result: StepResult, into run: inout RunningPassiveReport, playerLevel: Int) {
        // Hunger is tallied beside the buckets, not as one of them: it can land
        // on ANY step, so a `counts["starvation"]` bump both hid the event that
        // step rolled and made the row's own total wrong.
        if result.starvationHpLost > 0 {
            run.starvationSteps += 1
            run.starvationHpLost += result.starvationHpLost
        }
        switch result.outcome {
        case .nothing:
            run.outcomeCounts["nothing", default: 0] += 1
        case .trip:
            run.outcomeCounts["trip", default: 0] += 1
        case .silver(let amount):
            run.outcomeCounts["silver", default: 0] += 1
            // Counted for the report only — `rollStep` already credited it to
            // `user.silver`. Accumulating and granting at the end is what XP
            // does, and only because `passive.xpMultiplier` must round once;
            // silver has no multiplier, so a second grant here would double it.
            run.silverFound += amount
        case .loot(let itemId, let quantity, let pickedUp):
            run.outcomeCounts["loot", default: 0] += 1
            if pickedUp {
                run.lootPicked[itemId, default: 0] += quantity
            } else {
                run.lootDropped[itemId, default: 0] += quantity
            }
        case .encounterWon(let enemy, _, _, _, let drops):
            run.outcomeCounts["encounter_won", default: 0] += 1
            run.xpEarned += User.xpFromKill(enemy, playerLevel: playerLevel)
            for drop in drops {
                if drop.picked {
                    run.lootPicked[drop.itemId, default: 0] += drop.quantity
                } else {
                    run.lootDropped[drop.itemId, default: 0] += drop.quantity
                }
            }
        case .encounterLost:
            run.outcomeCounts["encounter_lost", default: 0] += 1
        case .encounterStarted:
            // Passive simulation never receives this — `rollStep` only emits
            // it for `mode: .active`. Listed here only for switch exhaustiveness.
            break
        }
    }

    /// On simulated death: wipe the bag (`InventoryEntry.wipeOnDeath` — worn
    /// gear and the bound class weapon survive), respawn at HP = 1, same rules
    /// as active-mode death. Vigor is preserved per design. Returns what the
    /// wipe took, which the report names.
    private static func applyDeath(to user: User, on db: any Database) async throws -> [InventoryEntry.DeathLoss] {
        let lost = try await InventoryEntry.wipeOnDeath(for: user, on: db)
        user.hp = 1
        return lost
    }

    // MARK: Notification push

    /// Send the completion message directly to the user's chat. Called from
    /// the background task, so we don't have a Context — pull the bot from
    /// `appState` and locale from the user row.
    ///
    /// Two messages, in order: a "back at the estate" line (unlocks the
    /// player's perception of being home again) then the report itself as
    /// plain text. No Close button — we delete the state row immediately so
    /// Estate / Capital unblock the instant the expedition ends, without
    /// waiting for a user tap. The report lives in chat history as a
    /// reference.
    private static func pushReportNotification(
        state: ExplorationState,
        user: User,
        bot: TGBot,
        lingo: Lingo,
        db: any Database
    ) async throws {
        guard let reportJSON = state.reportJSON,
              let data = reportJSON.data(using: .utf8),
              let report = try? JSONDecoder().decode(PassiveReport.self, from: data) else {
            return
        }
        let locale = user.locale
        let homeText = lingo.localize("exploration.passive.closed_home", locale: locale)
        let reportText = renderReport(report, gender: user.gender, lingo: lingo, locale: locale)

        // Single combined message — home-again line first, report body below.
        // Let send errors propagate so `finalizeAndPush` logs + skips the
        // state delete below (controller will retry via `deliverPassiveReport`
        // on the next Explore tap).
        _ = try await bot.sendMessage(params: TGSendMessageParams(
            chatId: .chat(user.telegramId),
            text: "\(homeText)\n\n\(reportText)",
            parseMode: .html
        ))

        // Level-up in its own bubble, under the report — same shape a kill or
        // a quest payout produces. Best-effort on purpose: the report send
        // above is what decides whether the state row survives for a retry,
        // and a failed banner must not buy the player a second copy of it.
        if report.levelsGained > 0 {
            _ = try? await bot.sendMessage(params: TGSendMessageParams(
                chatId: .chat(user.telegramId),
                text: LevelUpBanner.text(for: user, newLevel: report.newLevel,
                                         growth: report.growth, lingo: lingo, locale: locale),
                parseMode: .html
            ))
        }

        // First trip home earns the capital nudge — same one-shot flag the
        // active walk-back uses. This is the path that actually runs when the
        // push succeeds, so without it a player who only ever sends the
        // governor out passively would never be told where jobs come from.
        if !user.tutorialTraderHintShown {
            let hint = lingo.localize("tutorial.capital_hint", locale: locale)
            if (try? await bot.sendMessage(params: TGSendMessageParams(
                chatId: .chat(user.telegramId), text: hint, parseMode: .html
            ))) != nil {
                user.tutorialTraderHintShown = true
                try? await user.saveAndCache(in: db)
            }
        }

        // Auto-close the expedition cycle — delete state so the next Explore
        // tap shows a fresh mode picker and nav buttons unlock immediately.
        try? await ExplorationState.end(for: user, on: db)

        // The governor is home the moment this report lands, so resting starts
        // here rather than on the player's next tap — nothing in this flow is
        // an interaction, and `tick` only runs on one.
        _ = try? await HealingService.beginResting(user, on: db)
    }

    // MARK: Report rendering

    /// Build the multi-line report text shown when the passive expedition
    /// finishes. Called from both the background push and the
    /// `showExploration` controller entry (when a report is waiting).
    public static func renderReport(_ report: PassiveReport, gender: String?, lingo: Lingo, locale: String) -> String {
        var lines: [String] = []
        lines.append(lingo.localize("exploration.passive.report.title", locale: locale))
        lines.append("")

        if report.died, let deathKm = report.deathDepth {
            // Four sentences, not one with a fragment interpolated: 💀 sits
            // inside them, and Lingo drops every `%{}` after a two-unit emoji.
            // With losses, the sentence ends in a colon and names them, the way
            // the active death screen does (2026-10-12).
            let key: String
            switch (report.diedOnWayBack, report.lost.isEmpty) {
            case (false, true):  key = "exploration.passive.report.death"
            case (false, false): key = "exploration.passive.report.death.lost"
            case (true, true):   key = "exploration.passive.report.death.back"
            case (true, false):  key = "exploration.passive.report.death.back_lost"
            }
            lines.append(lingo.localize(key, gender: gender, locale: locale, interpolations: ["km": "\(deathKm)"]))
            for loss in report.lost {
                let item = ItemCatalog.find(loss.itemId)
                let icon = item?.icon.map { "\($0) " } ?? ""
                let name = item.map { lingo.localize(ItemDisplay.nameKey(for: $0, tier: loss.tier), locale: locale) } ?? loss.itemId
                lines.append("   \(icon)\(name) ×\(loss.quantity)")
            }
            lines.append("")
        }

        lines.append(lingo.localize("exploration.passive.report.depth", locale: locale, interpolations: ["km": "\(report.finalDepth)"]))
        // He turned short of the planned depth: where, and why. ↩️ is two
        // UTF-16 units, so it is prepended here, never in the template.
        if let turnKm = report.turnKm, let reason = report.turnReason.flatMap(PassiveReport.TurnReason.init(rawValue:)) {
            lines.append("↩️ " + lingo.localize("exploration.passive.report.turn.\(reason.rawValue)", gender: gender,
                                               locale: locale, interpolations: ["km": "\(turnKm)"]))
        }
        lines.append(lingo.localize("exploration.passive.report.hp", locale: locale, interpolations: [
            "before": "\(report.hpBefore)",
            "after": "\(report.hpAfter)"
        ]))
        lines.append(lingo.localize("exploration.passive.report.vigor", locale: locale, interpolations: [
            "before": "\(report.vigorBefore)",
            "after": "\(report.vigorAfter)"
        ]))

        // Phase 5.3a + 5.3b — XP line. Shown whenever the player earned any
        // XP (even on death — kills before falling still count). Built from
        // three composable fragments: base XP, optional level-up segment,
        // optional stat-boost segment. Each fragment is its own locale key
        // so translators can reorder cleanly.
        if report.xpEarned > 0 {
            lines.append("")
            // 📖 / 🎉 / 💪 prepended in Swift — leading supplementary-plane
            // emoji breaks Lingo's `%{var}` parser (see .memory/localization.md).
            let xpLine = "📖 " + lingo.localize("exploration.passive.report.xp", locale: locale, interpolations: [
                "xp": "\(report.xpEarned)"
            ])
            lines.append(xpLine)
        }
        if report.silverFound > 0 {
            // 🪙 prepended here AND passed as a value below, never written into
            // the template: U+1FA99 is two UTF-16 units, and Lingo drops every
            // `%{}` that follows one of those in the template itself.
            let noun = lingo.localize("unit.silver", count: report.silverFound, locale: locale)
            lines.append("🪙 " + lingo.localize("exploration.passive.report.silver",
                                                locale: locale,
                                                interpolations: ["coins": "\(report.silverFound) \(noun)"]))
        }
        let totalEvents = report.outcomeCounts.values.reduce(0, +)
        if totalEvents > 0 {
            lines.append("")
            lines.append(lingo.localize("exploration.passive.report.events_header", locale: locale, interpolations: ["total": "\(totalEvents)"]))
            // "starvation" is a LEGACY bucket, kept only so reports written
            // before hunger got its own totals still render their tally. New
            // runs never write it — see the line below the row.
            let outcomeOrder = ["nothing", "loot", "silver", "encounter_won", "encounter_lost", "trip", "starvation"]
            var parts: [String] = []
            for key in outcomeOrder {
                let count = report.outcomeCounts[key, default: 0]
                if count == 0 { continue }
                let label = lingo.localize("exploration.passive.outcome.\(key)", locale: locale)
                parts.append("\(label) × \(count)")
            }
            lines.append(parts.joined(separator: " · "))
        }

        // Hunger on its own line, with its own two numbers. It rode inside the
        // events row before, which could not say how much HP it had cost —
        // the same fusion that made a root look like it took 22 HP.
        if report.starvationSteps > 0 {
            lines.append("")
            // 🥀 prepended in Swift: a leading supplementary-plane emoji breaks
            // Lingo's `%{var}` parser.
            lines.append("🥀 " + lingo.localize("exploration.passive.report.starvation", locale: locale, interpolations: [
                "steps": "\(report.starvationSteps)",
                "hp": "❤️ −\(report.starvationHpLost)"
            ]))
        }

        // What he ate on the road (2026-10-12): it was the player's food, so it
        // is named — most eaten first. 🍴 rides outside the template.
        if !report.eaten.isEmpty {
            let meals = report.eaten.sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }
                .map { itemId, count -> String in
                    let item = ItemCatalog.find(itemId)
                    let name = item.map { lingo.localize($0.nameKey, locale: locale) } ?? itemId
                    return (item?.icon.map { "\($0) \(name)" } ?? name) + " × \(count)"
                }
            lines.append("")
            lines.append("🍴 " + lingo.localize("exploration.passive.report.eaten", locale: locale,
                                                interpolations: ["items": meals.joined(separator: " · ")]))
        }

        // Loot section is skipped entirely when the governor died — the
        // death line at the top already names what was lost, and repeating
        // "empty-handed" below would be noise.
        if !report.died {
            lines.append("")
            lines.append(lingo.localize("exploration.passive.report.loot_header", locale: locale))
            if report.loot.isEmpty {
                lines.append(lingo.localize("exploration.passive.report.no_loot", locale: locale))
            } else {
                for entry in report.loot {
                    // Icon is prepended in Swift code (not inside the Lingo
                    // template) so surrogate-pair emoji on items like 🥔 🥩 🪨
                    // don't break the `%{dropped}` interpolation on partial
                    // pickups. See `.memory/localization.md`.
                    let item = ItemCatalog.find(entry.itemId)
                    let itemName = item.map { lingo.localize($0.nameKey, locale: locale) } ?? entry.itemId
                    let label = item?.icon.map { "\($0) \(itemName)" } ?? itemName
                    var line = "• \(label) × \(entry.pickedQuantity)"
                    if entry.droppedQuantity > 0 {
                        line += lingo.localize("exploration.passive.report.loot_partial", locale: locale, interpolations: ["dropped": "\(entry.droppedQuantity)"])
                    }
                    lines.append(line)
                }
            }
        }

        return lines.joined(separator: "\n")
    }

    // MARK: Time formatting

    /// Time left on an expedition, on the one countdown format every screen
    /// uses.
    public static func formatCountdown(_ seconds: Int, lingo: Lingo, locale: String) -> String {
        return Countdown.format(seconds, lingo: lingo, locale: locale)
    }

    /// The total duration a player is committing to, in the same words the
    /// countdown will then tick down in.
    public static func formatDuration(_ duration: PassiveDuration, lingo: Lingo, locale: String) -> String {
        let seconds = Int(Double(duration.rawValue) * secondsPerUnit)
        return formatCountdown(seconds, lingo: lingo, locale: locale)
    }
}
