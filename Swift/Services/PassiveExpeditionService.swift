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
//  HP/hunger mutate on the real user model so resting-at-estate regen before
//  the timer expires is naturally reflected in the simulated pool.
//

import Fluent
import Foundation
@preconcurrency import Lingo
import SwiftTelegramBot

// MARK: - Duration catalogue

/// Three duration choices shown in the picker. Values are "units" — either
/// minutes (production) or seconds (test mode), depending on `testMode`.
public enum PassiveDuration: Int, CaseIterable, Sendable {
    case short = 30   // 30 min  → 30 s in test mode
    case medium = 60  // 1 h     → 60 s
    case long = 90    // 1.5 h   → 90 s

    public var localeKey: String {
        switch self {
        case .short:  return "exploration.duration.30m"
        case .medium: return "exploration.duration.1h"
        case .long:   return "exploration.duration.1h30m"
        }
    }

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
    public let hungerBefore: Int
    public let hungerAfter: Int
    public let died: Bool
    public let deathDepth: Int?
    public let outcomeCounts: [String: Int]
    public let loot: [LootEntry]

    public struct LootEntry: Codable, Sendable {
        public let itemId: String
        public let pickedQuantity: Int
        public let droppedQuantity: Int
    }
}

// MARK: - Service

public enum PassiveExpeditionService {

    /// Flip to `false` to use real minutes. In test mode every duration unit
    /// becomes a second — the whole expedition cycle fits inside ~2 min.
    public static let testMode: Bool = true

    /// How many real seconds a single "duration unit" represents.
    private static var secondsPerUnit: TimeInterval {
        return testMode ? 1 : 60
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

        let state = try await ExplorationState.beginPassive(for: user, endsAt: endsAt, on: db)
        scheduleCompletion(stateId: state.id, endsAt: endsAt, db: db, bot: bot, lingo: lingo)
        return state
    }

    // MARK: Scheduler

    /// Spawn a detached task that sleeps until `endsAt` and then runs
    /// `completeIfDue`. `stateId` lets us re-fetch the state fresh at
    /// completion time (and confirm the expedition wasn't cancelled or
    /// force-ended out from under us).
    public static func scheduleCompletion(
        stateId: UUID?,
        endsAt: Date,
        db: any Database,
        bot: TGBot,
        lingo: Lingo
    ) {
        guard let stateId = stateId else { return }
        let delay = max(0, endsAt.timeIntervalSinceNow)

        Task.detached {
            if delay > 0 {
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
            do {
                try await completeIfDue(stateId: stateId, on: db, bot: bot, lingo: lingo)
            } catch {
                // Background task — log via global logger if available, else swallow.
                // Don't rethrow; the scheduler has nowhere to propagate to.
                appState?.logger.error("Passive expedition completion failed for \(stateId): \(error)")
            }
        }
    }

    /// Startup-time sweep: for every in-flight passive state, either deliver
    /// the report immediately (if the endsAt already passed during downtime)
    /// or re-arm a Task.sleep for whatever's left.
    public static func rescheduleInflight(
        on db: any Database,
        bot: TGBot,
        lingo: Lingo
    ) async throws {
        let passive = try await ExplorationState.allPassive(on: db)
        for state in passive {
            guard let stateId = state.id, let endsAt = state.endsAt else { continue }
            if state.reportJSON != nil {
                // Already-completed passive whose player hasn't opened the report
                // yet. Leave it alone — the controller delivers on next open.
                continue
            }
            scheduleCompletion(stateId: stateId, endsAt: endsAt, db: db, bot: bot, lingo: lingo)
        }
    }

    // MARK: Completion

    /// Run simulation + push report, but only if the state still exists, is
    /// still passive, and hasn't already been completed. Idempotent — safe
    /// to invoke from multiple scheduled tasks (e.g. rescheduler + original).
    public static func completeIfDue(
        stateId: UUID,
        on db: any Database,
        bot: TGBot,
        lingo: Lingo
    ) async throws {
        guard let state = try await ExplorationState.query(on: db).filter(\.$id, .equal, stateId).first() else {
            return
        }
        guard state.isPassive, state.reportJSON == nil else { return }

        // Load the user so we can mutate hp/hunger and add loot.
        try await state.$user.load(on: db)
        let user = state.user

        let report = try await simulate(state: state, user: user, on: db)

        // Encode report and persist on the state row.
        let data = try JSONEncoder().encode(report)
        state.reportJSON = String(data: data, encoding: .utf8)

        // Persist user changes (hp / hunger delta from simulation + inventory
        // was already written step-by-step by rollStep).
        try await user.saveAndCache(in: db)
        try await state.save(on: db)

        // Push notification to the player.
        try await pushReportNotification(state: state, user: user, bot: bot, lingo: lingo)
    }

    // MARK: Simulation

    /// Run `duration.stepCount` `rollStep` calls at increasing depths. Each
    /// step uses `priorVisits: 0` (passive treks fresh ground). Mutates the
    /// user's hp/hunger directly; loot is added to inventory on pickup.
    /// Breaks early if hp hits 0 (governor died mid-expedition).
    public static func simulate(state: ExplorationState, user: User, on db: any Database) async throws -> PassiveReport {
        // Derive step count from elapsed timer so time-stretched runs (e.g. a
        // 30-min expedition finalized after a 40-min downtime) still produce
        // the right number of rolls.
        let stepCount = derivedStepCount(for: state)

        let hpBefore = user.hp
        let hungerBefore = user.hunger

        var outcomeCounts: [String: Int] = [:]
        var lootPicked: [String: Int] = [:]
        var lootDropped: [String: Int] = [:]
        var died = false
        var deathDepth: Int? = nil
        var finalDepth = 0
        var stepsTaken = 0

        for i in 1...max(1, stepCount) {
            stepsTaken += 1
            finalDepth = i

            let outcome: StepOutcome
            do {
                outcome = try await ExplorationService.rollStep(
                    for: user,
                    kmDepth: i,
                    priorVisits: 0,
                    on: db
                )
            } catch {
                // Surface through the report but don't cascade.
                appState?.logger.warning("Passive simulation step \(i) threw: \(error)")
                break
            }

            recordOutcome(outcome, counts: &outcomeCounts, picked: &lootPicked, dropped: &lootDropped)

            if user.hp <= 0 {
                died = true
                deathDepth = i
                break
            }
        }

        if died {
            try await applyDeath(to: user, on: db)
        }

        // If the governor died, the bag stays with the corpse — the report
        // must not claim "brought back" anything. `applyDeath` already wiped
        // the non-equipped inventory rows in the DB; zero the report's loot
        // list to match so the player sees the honest outcome.
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

        return PassiveReport(
            stepsTaken: stepsTaken,
            finalDepth: finalDepth,
            hpBefore: hpBefore,
            hpAfter: user.hp,
            hungerBefore: hungerBefore,
            hungerAfter: user.hunger,
            died: died,
            deathDepth: deathDepth,
            outcomeCounts: outcomeCounts,
            loot: loot
        )
    }

    private static func derivedStepCount(for state: ExplorationState) -> Int {
        guard let endsAt = state.endsAt, let createdAt = state.createdAt else { return 6 }
        let seconds = max(0, endsAt.timeIntervalSince(createdAt))
        let units = seconds / secondsPerUnit
        // 1 step per 5 units — same ratio as PassiveDuration.stepCount.
        return max(1, Int(units / 5.0))
    }

    private static func recordOutcome(
        _ outcome: StepOutcome,
        counts: inout [String: Int],
        picked: inout [String: Int],
        dropped: inout [String: Int]
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
        case .encounterWon(_, _, _, _, let drops):
            counts["encounter_won", default: 0] += 1
            for drop in drops {
                if drop.picked {
                    picked[drop.itemId, default: 0] += drop.quantity
                } else {
                    dropped[drop.itemId, default: 0] += drop.quantity
                }
            }
        case .encounterLost:
            counts["encounter_lost", default: 0] += 1
        }
    }

    /// On simulated death: wipe non-equipped inventory, respawn at HP = 1
    /// (same rules as active-mode death). Hunger is preserved per design.
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
    private static func pushReportNotification(
        state: ExplorationState,
        user: User,
        bot: TGBot,
        lingo: Lingo
    ) async throws {
        guard let reportJSON = state.reportJSON,
              let data = reportJSON.data(using: .utf8),
              let report = try? JSONDecoder().decode(PassiveReport.self, from: data) else {
            return
        }
        let locale = user.locale
        let text = renderReport(report, lingo: lingo, locale: locale)

        let closeLabel = lingo.localize("exploration.passive.report.close", locale: locale)
        let markup = TGInlineKeyboardMarkup(inlineKeyboard: [[
            TGInlineKeyboardButton(text: closeLabel, callbackData: "explore:passive:close")
        ]])

        let params = TGSendMessageParams(
            chatId: .chat(user.telegramId),
            text: text,
            parseMode: .html,
            replyMarkup: .inlineKeyboardMarkup(markup)
        )
        _ = try? await bot.sendMessage(params: params)
    }

    // MARK: Report rendering

    /// Build the multi-line report text shown when the passive expedition
    /// finishes. Called from both the background push and the
    /// `showExploration` controller entry (when a report is waiting).
    public static func renderReport(_ report: PassiveReport, lingo: Lingo, locale: String) -> String {
        var lines: [String] = []
        lines.append(lingo.localize("exploration.passive.report.title", locale: locale))
        lines.append("")

        if report.died, let deathKm = report.deathDepth {
            lines.append(lingo.localize("exploration.passive.report.death", locale: locale, interpolations: ["km": "\(deathKm)"]))
            lines.append("")
        }

        lines.append(lingo.localize("exploration.passive.report.depth", locale: locale, interpolations: ["km": "\(report.finalDepth)"]))
        lines.append(lingo.localize("exploration.passive.report.hp", locale: locale, interpolations: [
            "before": "\(report.hpBefore)",
            "after": "\(report.hpAfter)"
        ]))
        lines.append(lingo.localize("exploration.passive.report.hunger", locale: locale, interpolations: [
            "before": "\(report.hungerBefore)",
            "after": "\(report.hungerAfter)"
        ]))

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
                    let itemName = ItemCatalog.find(entry.itemId)
                        .map { lingo.localize($0.nameKey, locale: locale) } ?? entry.itemId
                    var line = "• \(itemName) × \(entry.pickedQuantity)"
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

    /// Format a seconds-remaining countdown as `MM:SS`. Used both by the
    /// "started" line and by the periodic in-flight status.
    public static func formatCountdown(_ seconds: Int) -> String {
        let clamped = max(0, seconds)
        let m = clamped / 60
        let s = clamped % 60
        return String(format: "%02d:%02d", m, s)
    }

    /// Format the total duration a player is committing to. Uses the same
    /// MM:SS format as the countdown for consistency.
    public static func formatDuration(_ duration: PassiveDuration) -> String {
        let seconds = Int(Double(duration.rawValue) * secondsPerUnit)
        return formatCountdown(seconds)
    }
}
