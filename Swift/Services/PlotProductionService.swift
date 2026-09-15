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

    /// How often the ticker wakes.
    ///
    /// DERIVED from the production interval rather than stored, because the one
    /// property that actually matters is "never slower than the thing it
    /// sweeps" — a filled plot announced a whole cycle late is the failure
    /// mode. Deriving it makes that hold by construction instead of by a rule
    /// someone has to remember when they change the interval.
    ///
    /// It is deliberately NOT a function of `time.scale`: this is a database
    /// polling cadence, not a game-time gate, and scaling it would make DB load
    /// a function of game balance.
    ///
    /// The divisor and floor in `tuning/time.json` are calibrated to reproduce
    /// both shipped values exactly — 3600/12 = 300 s in production, and 60 s
    /// under test mode where 60/12 = 5 is lifted by the floor. Checked on every
    /// `--content-digest` run, not merely asserted here.
    public static var tickInterval: TimeInterval {
        return tickInterval(forPlotInterval: PlotCatalog.intervalSeconds)
    }

    /// The derivation, exposed for the digest's two-point check. A running
    /// process has exactly one `time.scale`, so `PlotCatalog.intervalSeconds`
    /// only ever yields one cadence — and at the dev bundle's scale of 60 the
    /// floor swallows the divisor entirely, making it invisible to the digest
    /// hash. Only a parameterised call exercises the release branch.
    static func tickInterval(forPlotInterval interval: TimeInterval) -> TimeInterval {
        let sweeper = Catalogs.current.tuningTime.gameTime.plotSweeper
        return max(sweeper.minSeconds, interval / Double(sweeper.intervalDivisor))
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
            try await sendReadyNotification(plot: plot, at: now, bot: bot, lingo: lingo)
            plot.notifiedFull = true
            try? await plot.save(on: db)
        }
    }

    /// Push a single "your plot is full" message to the owner's chat. Best-
    /// effort; failures are swallowed so the ticker stays robust against a
    /// closed chat / blocked bot / etc.
    private static func sendReadyNotification(plot: Plot, at now: Date, bot: TGBot, lingo: Lingo) async throws {
        guard let type = PlotType(rawValue: plot.plotType),
              let tuning = PlotCatalog.tuning(for: type, tier: plot.tier) else { return }
        let user = plot.user  // eager-loaded by `allUnfull`
        let locale = user.locale
        let icon = PlotCatalog.icon(for: type)
        let plotName = lingo.localize(PlotCatalog.nameKey(for: type), locale: locale)
        // Both streams, in the order the harvest screen lists them, so the
        // player reads the same pair twice. The Mine used to announce 40 pebble
        // and say nothing of the iron waiting beside it; since 2026-09-15 the
        // two caps are reached at the same minute, which is what makes one
        // sentence honest. The bonus amount is the LIVE accumulator, not its
        // cap: the notification fires on the primary being full, and a future
        // plot whose bonus fills slower must not be over-reported.
        //
        // Icons are Optional — unwrap, never interpolate raw.
        func line(_ itemId: String, _ amount: Int) -> String {
            let item = ItemCatalog.find(itemId)
            let itemIcon = item?.icon.map { "\($0) " } ?? ""
            let name = item.map { lingo.localize($0.nameKey, locale: locale) } ?? itemId
            return "<b>\(amount)</b> \(itemIcon)\(name)"
        }
        var yields = [line(tuning.producedItemId, tuning.capacity)]
        if let bonus = tuning.bonusOutput {
            let bonusAmount = PlotService.bonusAccumulated(for: plot, at: now)
            if bonusAmount > 0 { yields.append(line(bonus.producedItemId, bonusAmount)) }
        }
        // The sentence agrees with the PLOT's noun — «Шахта заповнена» but
        // «Курник заповнений». It read «заповнена» for every type until
        // 2026-09-15, which was right for three of the four producing plots.
        // A missing declaration echoes the key back and falls through to
        // masculine, exactly as it does for items.
        let plotGender = lingo.localize(PlotCatalog.genderKey(for: type), locale: locale)
        let body = lingo.localize("plot.ready.notification", agreeingWith: plotGender, locale: locale, interpolations: [
            "plot":   plotName,
            "slot":   "\(plot.slotIndex + 1)",
            "yields": yields.joined(separator: ", ")
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
