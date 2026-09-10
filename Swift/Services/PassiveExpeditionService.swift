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
//  The simulation reuses `ExplorationService.rollStep` with `priorVisits: 0`
//  — passive expeditions always head into fresh territory. Loot lands in the
//  player's inventory as it would in active mode (with full-bag fallback);
//  HP/vigor mutate on the real user model so resting-at-estate regen before
//  the timer expires is naturally reflected in the simulated pool.
//

import Fluent
import Foundation
@preconcurrency import Lingo
import SwiftTelegramBot

// MARK: - Duration catalogue

/// Three duration choices shown in the picker. Values are "units"; one unit is
/// `tuning/time.json` → `gameTime.passiveExpedition.secondsPerUnit` divided by
/// `time.scale` — a minute at release pacing, a second in the dev bundle.
public enum PassiveDuration: Int, CaseIterable, Sendable {
    case short = 30   // 30 min  → 30 s at scale 60
    case medium = 60  // 1 h     → 60 s
    case long = 90    // 1.5 h   → 90 s

    /// Number of simulated step rolls this duration buys. One "step" per 5
    /// units of duration — same count in test and prod modes, only the wall
    /// clock changes.
    public var stepCount: Int {
        return rawValue / 5
    }
}

// MARK: - Report model (JSON-persisted)

public struct PassiveReport: Codable, Sendable {
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
    /// renderer can show "📊 +N XP (Lv. M → M+L)" without re-deriving.
    /// Optional in storage for backwards compat with pre-5.3a reports.
    public let xpEarned: Int
    public let levelsGained: Int
    public let newLevel: Int
    /// Stat growth totals from the XP grant — all zeroes unless the
    /// expedition levelled the player. Printed by `LevelUpBanner`.
    public let growth: User.StatGrowth

    public struct LootEntry: Codable, Sendable {
        public let itemId: String
        public let pickedQuantity: Int
        public let droppedQuantity: Int
    }

    public init(
        stepsTaken: Int, finalDepth: Int,
        hpBefore: Int, hpAfter: Int,
        vigorBefore: Int, vigorAfter: Int,
        died: Bool, deathDepth: Int?,
        outcomeCounts: [String: Int],
        loot: [LootEntry],
        xpEarned: Int = 0,
        levelsGained: Int = 0,
        newLevel: Int = 1,
        growth: User.StatGrowth = User.StatGrowth()
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
        self.levelsGained = levelsGained
        self.newLevel = newLevel
        self.growth = growth
    }

    enum CodingKeys: String, CodingKey {
        case stepsTaken, finalDepth, hpBefore, hpAfter, vigorBefore, vigorAfter
        case died, deathDepth, outcomeCounts, loot, xpEarned, levelsGained, newLevel
        case growth
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
        levelsGained = (try? c.decode(Int.self, forKey: .levelsGained)) ?? 0
        newLevel = (try? c.decode(Int.self, forKey: .newLevel)) ?? 1
        growth = (try? c.decode(User.StatGrowth.self, forKey: .growth)) ?? User.StatGrowth()
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

    public init(
        hpBefore: Int, vigorBefore: Int,
        outcomeCounts: [String: Int],
        lootPicked: [String: Int], lootDropped: [String: Int],
        xpEarned: Int = 0
    ) {
        self.hpBefore = hpBefore
        self.vigorBefore = vigorBefore
        self.outcomeCounts = outcomeCounts
        self.lootPicked = lootPicked
        self.lootDropped = lootDropped
        self.xpEarned = xpEarned
    }

    enum CodingKeys: String, CodingKey {
        case hpBefore, vigorBefore, outcomeCounts, lootPicked, lootDropped, xpEarned
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        hpBefore = try c.decode(Int.self, forKey: .hpBefore)
        vigorBefore = try c.decode(Int.self, forKey: .vigorBefore)
        outcomeCounts = try c.decode([String: Int].self, forKey: .outcomeCounts)
        lootPicked = try c.decode([String: Int].self, forKey: .lootPicked)
        lootDropped = try c.decode([String: Int].self, forKey: .lootDropped)
        xpEarned = (try? c.decode(Int.self, forKey: .xpEarned)) ?? 0
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

    /// Begin a passive expedition. Creates the `ExplorationState` row with
    /// `mode = .passive` and `endsAt = now + duration`, then arms a detached
    /// `Task.sleep` that will run the simulation and push the report when
    /// the timer elapses.
    @discardableResult
    public static func start(
        for user: User,
        duration: PassiveDuration,
        on db: any Database,
        bot: TGBot,
        lingo: Lingo
    ) async throws -> ExplorationState {
        let now = Date()
        let seconds = Double(duration.rawValue) * secondsPerUnit
        let endsAt = now.addingTimeInterval(seconds)

        // The expedition row first, the budget after it: if `beginPassive`
        // throws, the player must not be left having paid for a run that does
        // not exist. The reverse order costs at worst a free run, which is the
        // cheaper way to be wrong.
        let state = try await ExplorationState.beginPassive(for: user, endsAt: endsAt, on: db)

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
            lootDropped: [:]
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

    /// How many "duration units" a single simulated step costs. A 30-unit
    /// expedition therefore resolves in 6 steps — same count in test mode
    /// (secondsPerUnit = 1 → 5 s/step) and prod (secondsPerUnit = 60 →
    /// 300 s/step).
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

    /// Real-world wall-clock seconds per simulated step.
    static var stepDurationSeconds: TimeInterval {
        return Double(unitsPerStep) * secondsPerUnit
    }

    /// Spawn a detached background task that runs the expedition step by
    /// step. Each step rolls one event, persists progress via `stepsDeep`,
    /// and either sleeps until the next step's scheduled fire time or
    /// finalizes early if the governor died mid-walk.
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
    /// passive state. Each task reads `stepsDeep` to know how many steps
    /// already completed before the last bot shutdown and resumes from
    /// there — any scheduled step times that fell during downtime are
    /// executed back-to-back without sleeping (catch-up).
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
    /// the bot — nav, the capital, the market all stay open. Fluent saves whole
    /// rows and `saveAndCache` installs what it saved as the next tap's
    /// session, so a loop writing its own copy every step would publish a
    /// pre-tap snapshot over whatever the player did in between. Requires
    /// `state.$user` to be loaded already (for the telegram id).
    private static func liveUser(for state: ExplorationState) async -> User {
        return await sessionCache.peek(telegramId: state.user.telegramId) ?? state.user
    }

    /// Per-step runner. Exits early on death (pushes the report immediately
    /// instead of waiting out the remaining timer), on expedition cancellation
    /// by the player (state row gone), or on error.
    ///
    /// Progress is tracked in `state.stepsDeep` so a bot restart mid-run
    /// resumes from the right step. The accumulated outcome counters, loot
    /// totals, and HP/vigor-at-start values are persisted on
    /// `state.runningReportJSON` after every step in the same save as
    /// `stepsDeep`, so the final report stays complete across restarts.
    /// Legacy passive rows (created before AddPassiveRunningReport) fall
    /// back to lazy capture on the first step iteration.
    private static func runLive(
        stateId: UUID,
        db: any Database,
        bot: TGBot,
        lingo: Lingo
    ) async {
        var outcomeCounts: [String: Int] = [:]
        var lootPicked: [String: Int] = [:]
        var lootDropped: [String: Int] = [:]
        var hpBefore: Int = 0
        var vigorBefore: Int = 0
        var xpEarned: Int = 0
        var hasCapturedBefore = false

        while true {
            // Reload fresh at the start of each iteration — state may have
            // been deleted (cancel), or user may have mutated hp/vigor (eat
            // food, regen, etc. — regen is paused during expedition, but
            // we stay defensive).
            guard let state = try? await ExplorationState.query(on: db).filter(\.$id, .equal, stateId).first() else { return }
            guard state.isPassive, state.reportJSON == nil else { return }

            // Restore running totals from DB if the column carries a snapshot.
            // Legacy rows skip this and fall through to lazy-capture below.
            if !hasCapturedBefore, let restored = decodeRunningReport(state.runningReportJSON) {
                outcomeCounts = restored.outcomeCounts
                lootPicked    = restored.lootPicked
                lootDropped   = restored.lootDropped
                hpBefore      = restored.hpBefore
                vigorBefore   = restored.vigorBefore
                xpEarned      = restored.xpEarned
                hasCapturedBefore = true
            }

            let totalSteps = derivedStepCount(for: state)
            let completed = state.stepsDeep

            if completed >= totalSteps {
                // All steps done — finalize normally. `liveUser` rather than the
                // freshly-loaded relation: see the note at the step loop below.
                try? await state.$user.load(on: db)
                let finalUser = await liveUser(for: state)
                await finalizeAndPush(
                    state: state, user: finalUser,
                    outcomeCounts: outcomeCounts,
                    lootPicked: lootPicked, lootDropped: lootDropped,
                    hpBefore: hasCapturedBefore ? hpBefore : finalUser.hp,
                    vigorBefore: hasCapturedBefore ? vigorBefore : finalUser.vigor,
                    xpEarned: xpEarned,
                    died: false, deathDepth: nil,
                    on: db, bot: bot, lingo: lingo
                )
                return
            }

            let nextStep = completed + 1
            guard let createdAt = state.createdAt else { return }
            let stepFireAt = createdAt.addingTimeInterval(Double(nextStep) * stepDurationSeconds)
            let waitSeconds = max(0, stepFireAt.timeIntervalSinceNow)

            if waitSeconds > 0 {
                try? await Task.sleep(nanoseconds: UInt64(waitSeconds * 1_000_000_000))
            }

            // Reload state + user after the wait (state may have been deleted
            // via cancel, player may have interacted in ways that affect user
            // fields).
            guard let state = try? await ExplorationState.query(on: db).filter(\.$id, .equal, stateId).first() else { return }
            guard state.isPassive, state.reportJSON == nil else { return }
            try? await state.$user.load(on: db)
            let user = await liveUser(for: state)

            // Legacy fallback: if no persisted snapshot existed (pre-migration
            // row that started before this code shipped), lazy-capture the
            // before values now from the live user. Post-migration rows have
            // already been seeded by `start()` and the restore branch above.
            if !hasCapturedBefore {
                hpBefore = user.hp
                vigorBefore = user.vigor
                hasCapturedBefore = true
            }

            // Roll one step.
            let outcome: StepOutcome
            do {
                outcome = try await ExplorationService.rollStep(
                    for: user,
                    kmDepth: nextStep,
                    // Past the first step an unattended walk rolls the DECAYED
                    // tier. Rolling fresh odds on every step is half of why the
                    // mode that needs no attention out-earned the one that does.
                    priorVisits: nextStep <= ExplorationService.passiveTuning.freshStepCount ? 0 : 1,
                    mode: .passive,
                    on: db
                )
            } catch {
                appState?.logger.warning("Passive live step \(nextStep) threw: \(error)")
                return
            }

            recordOutcome(outcome, counts: &outcomeCounts, picked: &lootPicked, dropped: &lootDropped,
                          xpEarned: &xpEarned, playerLevel: user.level)

            // Persist the post-step running totals on the state row alongside
            // `stepsDeep` — single save, both fields together. Survives any
            // restart from this point onward.
            let snapshot = RunningPassiveReport(
                hpBefore: hpBefore,
                vigorBefore: vigorBefore,
                outcomeCounts: outcomeCounts,
                lootPicked: lootPicked,
                lootDropped: lootDropped,
                xpEarned: xpEarned
            )
            state.runningReportJSON = encodeRunningReport(snapshot)
            state.stepsDeep = nextStep
            try? await state.save(on: db)
            try? await user.saveAndCache(in: db)

            if user.hp <= 0 {
                // Early death — finalize immediately, don't wait out the rest.
                do {
                    try await applyDeath(to: user, on: db)
                    try await user.saveAndCache(in: db)
                } catch {
                    appState?.logger.warning("applyDeath threw: \(error)")
                }
                await finalizeAndPush(
                    state: state, user: user,
                    outcomeCounts: outcomeCounts,
                    lootPicked: lootPicked, lootDropped: lootDropped,
                    hpBefore: hpBefore, vigorBefore: vigorBefore,
                    xpEarned: xpEarned,
                    died: true, deathDepth: nextStep,
                    on: db, bot: bot, lingo: lingo
                )
                return
            }
        }
    }

    /// Build the report, persist it on the state row, and push the
    /// completion message. Both the end-of-run (success) and early-death
    /// paths share this tail.
    private static func finalizeAndPush(
        state: ExplorationState,
        user: User,
        outcomeCounts: [String: Int],
        lootPicked: [String: Int],
        lootDropped: [String: Int],
        hpBefore: Int,
        vigorBefore: Int,
        xpEarned: Int,
        died: Bool,
        deathDepth: Int?,
        on db: any Database,
        bot: TGBot,
        lingo: Lingo
    ) async {
        // If the governor died, the bag stays with the corpse — the report
        // must not claim "brought back" anything. `applyDeath` already wiped
        // the non-equipped inventory rows in the DB; zero the report's loot
        // list to match.
        let loot: [PassiveReport.LootEntry]
        if died {
            loot = []
        } else {
            loot = Set(lootPicked.keys).union(lootDropped.keys).sorted().map { id in
                PassiveReport.LootEntry(
                    itemId: id,
                    pickedQuantity: lootPicked[id, default: 0],
                    droppedQuantity: lootDropped[id, default: 0]
                )
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
        let xpResult = user.grantXP(Int((Double(xpEarned) * passive.xpMultiplier).rounded()))
        if xpResult.xpAwarded > 0 {
            try? await user.saveAndCache(in: db)
        }

        // Phase 6.5 — wear equipped gear (armor + weapon) for the whole run: each
        // won fight costs a little, each lost fight more (no flee in passive autobattle).
        let gearWear = outcomeCounts["encounter_won", default: 0] * GearConditionService.WearEvent.victory.amount
                     + outcomeCounts["encounter_lost", default: 0] * GearConditionService.WearEvent.defeat.amount
        let brokeOnRun = (try? await GearConditionService.drainEquippedGear(amount: gearWear, for: user, on: db)) ?? []

        // Phase 9.2 — autobattle kills count toward the Master's beast-slaying
        // job, banked in one go for the whole run (same as the XP grant above).
        // Kills made before a death still count; the run is over either way.
        let killsThisRun = outcomeCounts["encounter_won", default: 0]
        if killsThisRun > 0 {
            try? await QuestService.record(.beastKill, amount: killsThisRun, for: user, on: db)
        }

        let report = PassiveReport(
            stepsTaken: state.stepsDeep,
            finalDepth: state.stepsDeep,
            hpBefore: hpBefore,
            hpAfter: user.hp,
            vigorBefore: vigorBefore,
            vigorAfter: user.vigor,
            died: died,
            deathDepth: deathDepth,
            outcomeCounts: outcomeCounts,
            loot: loot,
            xpEarned: xpResult.xpAwarded,
            levelsGained: xpResult.levelsGained,
            newLevel: xpResult.newLevel,
            growth: xpResult.growth
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
            for itemId in brokeOnRun {
                guard let item = ItemCatalog.find(itemId) else { continue }
                let name = lingo.localize(item.nameKey, locale: user.locale)
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

    /// Total number of steps this expedition covers. Derived from the
    /// configured duration (endsAt − createdAt), so the same helper works
    /// for freshly-started and in-flight rows.
    private static func derivedStepCount(for state: ExplorationState) -> Int {
        guard let endsAt = state.endsAt, let createdAt = state.createdAt else { return 6 }
        let seconds = max(0, endsAt.timeIntervalSince(createdAt))
        let units = seconds / secondsPerUnit
        return max(1, Int(units) / unitsPerStep)
    }

    private static func recordOutcome(
        _ outcome: StepOutcome,
        counts: inout [String: Int],
        picked: inout [String: Int],
        dropped: inout [String: Int],
        xpEarned: inout Int,
        playerLevel: Int
    ) {
        switch outcome {
        case .nothing:
            counts["nothing", default: 0] += 1
        case .starvationOnly:
            counts["starvation", default: 0] += 1
        case .trip:
            counts["trip", default: 0] += 1
        case .loot(let itemId, let quantity, let pickedUp):
            counts["loot", default: 0] += 1
            if pickedUp {
                picked[itemId, default: 0] += quantity
            } else {
                dropped[itemId, default: 0] += quantity
            }
        case .encounterWon(let enemy, _, _, _, let drops):
            counts["encounter_won", default: 0] += 1
            xpEarned += User.xpFromKill(enemy, playerLevel: playerLevel)
            for drop in drops {
                if drop.picked {
                    picked[drop.itemId, default: 0] += drop.quantity
                } else {
                    dropped[drop.itemId, default: 0] += drop.quantity
                }
            }
        case .encounterLost:
            counts["encounter_lost", default: 0] += 1
        case .encounterStarted:
            // Passive simulation never receives this — `rollStep` only emits
            // it for `mode: .active`. Listed here only for switch exhaustiveness.
            break
        }
    }

    /// On simulated death: wipe non-equipped inventory, respawn at HP = 1
    /// (same rules as active-mode death). Vigor is preserved per design.
    private static func applyDeath(to user: User, on db: any Database) async throws {
        guard let userId = user.id else { return }
        let rows = try await InventoryEntry.query(on: db)
            .filter(\.$user.$id, .equal, userId)
            .all()
        for row in rows where row.equippedSlot == nil {
            try await row.delete(on: db)
        }
        user.hp = 1
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
            lines.append(lingo.localize("exploration.passive.report.death", gender: gender, locale: locale, interpolations: ["km": "\(deathKm)"]))
            lines.append("")
        }

        lines.append(lingo.localize("exploration.passive.report.depth", locale: locale, interpolations: ["km": "\(report.finalDepth)"]))
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
            // 📊 / 🎉 / 💪 prepended in Swift — leading supplementary-plane
            // emoji breaks Lingo's `%{var}` parser (see .memory/localization.md).
            let xpLine = "📊 " + lingo.localize("exploration.passive.report.xp", locale: locale, interpolations: [
                "xp": "\(report.xpEarned)"
            ])
            lines.append(xpLine)
        }
        let totalEvents = report.outcomeCounts.values.reduce(0, +)
        if totalEvents > 0 {
            lines.append("")
            lines.append(lingo.localize("exploration.passive.report.events_header", locale: locale, interpolations: ["total": "\(totalEvents)"]))
            let outcomeOrder = ["nothing", "loot", "encounter_won", "encounter_lost", "trip", "starvation"]
            var parts: [String] = []
            for key in outcomeOrder {
                let count = report.outcomeCounts[key, default: 0]
                if count == 0 { continue }
                let label = lingo.localize("exploration.passive.outcome.\(key)", locale: locale)
                parts.append("\(label) × \(count)")
            }
            lines.append(parts.joined(separator: " · "))
        }

        // Loot section is skipped entirely when the governor died — the
        // death line at the top already communicates that everything was
        // lost, and repeating "empty-handed" below would be noise.
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
