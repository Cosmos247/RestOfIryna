//
//  PlotProductionService.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 29.04.2026.
//
//  Phase 5.1 — plot-production background ticker. One `Task.detached` runs
//  for the bot's lifetime, waking every `tickInterval` seconds. On each tick
//  it scans `Plot.allUnfull(on:)` (cheap as a query — already filtered by
//  the persisted `notified_full` flag), and for any plot whose accumulated
//  yield has reached the cap it pushes a "🌾 ready to harvest" message to
//  the owner's chat and flips `notified_full = true` so the same plot won't
//  be re-notified on the next tick.
//
//  Production amount itself is computed lazily by `PlotService.accumulated`
//  — the ticker only handles notifications. Player taps Estate → Plot list
//  → see live amounts independent of the ticker's cadence.
//
//  On harvest (`PlotService.harvest`) `notified_full` is reset to false so
//  the plot re-enters the ticker's "watch list" once it fills again.
//
//  The single-task pattern scales cheaply: one query + N row-updates per
//  tick, vs. one sleeping task per plot which would explode at scale.
//

import Fluent
import Foundation
@preconcurrency import Lingo
import SwiftTelegramBot

public enum PlotProductionService {

    /// How often the ticker wakes. 60s in test mode (where production rates
    /// are per-minute) keeps the "ready" notification within a minute of
    /// actually filling. In prod the rate is per-hour, so 5-minute ticks are
    /// plenty fast and easier on the DB.
    public static var tickInterval: TimeInterval {
        return PlotCatalog.testMode ? 60.0 : 300.0
    }

    /// Spawn the long-running ticker. Called from `configure.swift` after
    /// `bot.start()`. Fire-and-forget — the task lives until process exit.
    public static func startTicker(on db: any Database, bot: TGBot, lingo: Lingo) {
        Task.detached {
            await runLoop(db: db, bot: bot, lingo: lingo)
        }
    }

    /// Long-running loop. Catches errors per-iteration so a transient DB
    /// blip doesn't kill the ticker.
    private static func runLoop(db: any Database, bot: TGBot, lingo: Lingo) async {
        while true {
            do {
                try await tick(on: db, bot: bot, lingo: lingo)
            } catch {
                // Swallow — ticker keeps going. Future: structured logging.
            }
            try? await Task.sleep(nanoseconds: UInt64(tickInterval * 1_000_000_000))
        }
    }

    /// One pass: find unfull plots, see which just crossed their cap, push
    /// notifications, mark them notified.
    public static func tick(on db: any Database, bot: TGBot, lingo: Lingo) async throws {
        let now = Date()
        let plots = try await Plot.allUnfull(on: db)
        for plot in plots {
            guard PlotService.isFull(plot, at: now) else { continue }
            try await sendReadyNotification(plot: plot, bot: bot, lingo: lingo)
            plot.notifiedFull = true
            try? await plot.save(on: db)
        }
    }

    /// Push a single "your plot is full" message to the owner's chat. Best-
    /// effort; failures are swallowed so the ticker stays robust against a
    /// closed chat / blocked bot / etc.
    private static func sendReadyNotification(plot: Plot, bot: TGBot, lingo: Lingo) async throws {
        guard let type = PlotType(rawValue: plot.plotType),
              let tuning = PlotCatalog.tuning(for: type, tier: plot.tier) else { return }
        let user = plot.user  // eager-loaded by `allUnfull`
        let locale = user.locale
        let icon = PlotCatalog.icon(for: type)
        let plotName = lingo.localize(PlotCatalog.nameKey(for: type), locale: locale)
        let itemName = ItemCatalog.find(tuning.producedItemId).map { lingo.localize($0.nameKey, locale: locale) } ?? tuning.producedItemId
        let body = lingo.localize("plot.ready.notification", locale: locale, interpolations: [
            "plot":   plotName,
            "slot":   "\(plot.slotIndex + 1)",
            "amount": "\(tuning.capacity)",
            "item":   itemName
        ])
        let text = "\(icon) \(body)"
        let params = TGSendMessageParams(
            chatId: .chat(user.telegramId),
            text: text,
            parseMode: .html,
            disableNotification: false
        )
        _ = try? await bot.sendMessage(params: params)
    }
}
