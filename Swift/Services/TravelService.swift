//
//  TravelService.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 16.05.2026.
//
//  Phase 6.0 — the road between estate and capital. Once started, the player
//  is locked in until the timer elapses (no cancel — see plan-mode design
//  discussion). On arrival the service flips `User.location`, deletes the
//  `TravelState` row, and pushes a notification to the user's chat.
//
//  Mirrors the `PassiveExpeditionService` pattern (Task.detached + sleep,
//  `rescheduleInflight` on bot restart) but lighter — a single shot, no
//  per-step rolls, no inventory simulation. The body never blocks the
//  dispatcher: every wait happens off the request thread.
//

import Fluent
import Foundation
@preconcurrency import Lingo
import SwiftTelegramBot

public enum TravelService {

    /// How many minutes a single one-way trip takes.
    /// `tuning/time.json` → `gameTime.travelMinutes`.
    public static var travelMinutes: Int { Catalogs.current.tuningTime.gameTime.travelMinutes }

    /// Wall-clock seconds per one-way trip, compressed by `time.scale`.
    /// At scale 1 a "minute" is a minute; at the dev bundle's 60 it is a second.
    public static var travelSeconds: TimeInterval {
        return Double(travelMinutes) * 60.0 / Catalogs.current.timeScale
    }

    // MARK: - Start

    public enum StartFailure: Error, Sendable {
        case alreadyTraveling
        case dead
        case starving
        case onExpedition
        case alreadyAtDestination
    }

    /// Begin a trip in the given direction. Validates guards (HP > 0, vigor > 0,
    /// not already traveling, not on expedition, not already at destination),
    /// persists the `TravelState`, and arms a background task that flips
    /// `User.location` + pushes an arrival notification when the timer expires.
    @discardableResult
    public static func start(
        for user: User,
        destination: TravelDestination,
        on db: any Database,
        bot: TGBot,
        lingo: Lingo
    ) async throws -> TravelState {
        // Guards
        if try await TravelState.current(for: user, on: db) != nil {
            throw StartFailure.alreadyTraveling
        }
        if try await ExplorationState.current(for: user, on: db) != nil {
            throw StartFailure.onExpedition
        }
        if user.hp <= 0 { throw StartFailure.dead }
        if user.vigor <= 0 { throw StartFailure.starving }
        if user.location == destination.rawValue { throw StartFailure.alreadyAtDestination }

        let now = Date()
        let endsAt = now.addingTimeInterval(travelSeconds)
        let state = try await TravelState.begin(for: user, destination: destination, endsAt: endsAt, on: db)
        scheduleArrival(stateId: state.id, endsAt: endsAt, db: db, bot: bot, lingo: lingo)
        return state
    }

    // MARK: - Scheduler

    /// Spawn a detached task that sleeps until `endsAt` and then runs the
    /// arrival flow. Safe to invoke from request handlers — never blocks.
    public static func scheduleArrival(
        stateId: UUID?,
        endsAt: Date,
        db: any Database,
        bot: TGBot,
        lingo: Lingo
    ) {
        guard let stateId = stateId else { return }
        Task.detached {
            let waitSeconds = max(0, endsAt.timeIntervalSinceNow)
            if waitSeconds > 0 {
                try? await Task.sleep(nanoseconds: UInt64(waitSeconds * 1_000_000_000))
            }
            await arriveIfStillScheduled(stateId: stateId, db: db, bot: bot, lingo: lingo)
        }
    }

    /// Startup sweep: every in-flight trip gets a fresh background task. Any
    /// trips whose `endsAt` has already passed during downtime fire
    /// immediately (the sleep becomes 0).
    public static func rescheduleInflight(
        on db: any Database,
        bot: TGBot,
        lingo: Lingo
    ) async throws {
        let trips = try await TravelState.allInflight(on: db)
        for trip in trips {
            scheduleArrival(stateId: trip.id, endsAt: trip.endsAt, db: db, bot: bot, lingo: lingo)
        }
    }

    // MARK: - Arrival

    /// Re-read the trip from the DB (it may have been deleted in the meantime,
    /// e.g. via dev tooling), flip the user's location, delete the trip row,
    /// and push the arrival message. Idempotent — re-running is a no-op once
    /// the trip is gone.
    private static func arriveIfStillScheduled(
        stateId: UUID,
        db: any Database,
        bot: TGBot,
        lingo: Lingo
    ) async {
        guard let state = try? await TravelState.query(on: db).filter(\.$id, .equal, stateId).first() else { return }
        do {
            try await state.$user.load(on: db)
        } catch {
            appState?.logger.warning("Travel arrival: failed to load user for state \(stateId): \(error)")
            return
        }
        let user = state.user
        let destination = state.destination

        user.location = destination.rawValue
        // Player is back in town — set routerName so the next interaction
        // lands them in the right reply-keyboard automatically. For capital
        // arrivals, drop into the capital controller; for estate arrivals,
        // back to the main hub.
        user.routerName = destination == .capital
            ? Controllers.capitalController.routerName
            : Controllers.mainController.routerName

        do {
            try await user.saveAndCache(in: db)
            try await state.delete(on: db)
        } catch {
            appState?.logger.warning("Travel arrival: failed to commit user/state for \(stateId): \(error)")
            return
        }

        // Home again — start the rest clock at the arrival, not at the next
        // tap. No-op when it is already running, so the walk itself keeps
        // whatever it accrued.
        if destination == .estate {
            _ = try? await HealingService.beginResting(user, on: db)
        }

        // Push the arrival notification — single user-facing message that
        // includes the reply-keyboard for wherever they just landed.
        do {
            try await pushArrival(user: user, destination: destination, bot: bot, lingo: lingo)
        } catch {
            appState?.logger.warning("Travel arrival push failed: \(error)")
        }
    }

    private static func pushArrival(
        user: User,
        destination: TravelDestination,
        bot: TGBot,
        lingo: Lingo
    ) async throws {
        switch destination {
        case .capital:
            // Phase 6.1: capital arrival shows the full welcome screen
            // (photo + atmospheric caption + capital reply-keyboard) — the
            // arrival is implied by the screen showing up, no separate
            // "you've arrived" line needed. `travel.arrived.capital`
            // remains in the locales for forward compatibility.
            try await CapitalController.sendWelcome(toUser: user, bot: bot, lingo: lingo)
        case .estate:
            let text = lingo.localize("travel.arrived.estate", locale: user.locale)
            let kb = Controllers.mainController.generateControllerKB(session: user, lingo: lingo)
            _ = try await bot.sendMessage(params: TGSendMessageParams(
                chatId: .chat(user.telegramId),
                text: text,
                parseMode: .html,
                replyMarkup: kb
            ))
        }
    }

    // MARK: - Status / formatting

    /// Time left on the road, on the one countdown format every screen uses.
    public static func formatCountdown(_ seconds: Int, lingo: Lingo, locale: String) -> String {
        return Countdown.format(seconds, lingo: lingo, locale: locale)
    }
}
