//
//  RestNotificationService.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 09.09.2026.
//
//  The watchman for the things that finish while nobody is looking.
//
//  HP regeneration is computed LAZILY, on interaction (`HealingService.tick`
//  runs before every dispatch), which means the instant a player reaches full
//  HP has no observer: the arithmetic that discovers it only runs when they
//  come back — by which time the news is stale. Same shape for the fortune
//  teller's 24 h cooldown and the 12:00 job rollover: both are moments that
//  pass with the app closed.
//
//  So this is one `Task.detached` that wakes every `restSweepInterval`
//  seconds and asks three questions of the players it loads. The pattern is
//  `PlotProductionService`'s, for its reason: one query plus a few row
//  updates per tick, rather than one sleeping task per player, which would
//  multiply with the roster.
//
//  Each notification needs to fire ONCE. Two of them carry a flag for it —
//  `fortuneReadyNotified`, `questRolloverStamp` — and HP needs none, because
//  the condition it announces is its own guard: a player at full HP is not a
//  player who is about to reach it.
//

import Fluent
import Foundation
@preconcurrency import Lingo
import SwiftTelegramBot

public enum RestNotificationService {

    /// How often the watchman wakes. `tuning/time.json` → `realTime`, next to
    /// the tavern and trade sweeps: a polling cadence, never scaled by
    /// `time.scale`.
    public static var sweepInterval: TimeInterval {
        Catalogs.current.tuningTime.realTime.restSweepInterval
    }

    public static func startSweeper(on db: any Database, bot: TGBot, lingo: Lingo) {
        Task.detached {
            while true {
                do {
                    try await tick(on: db, bot: bot, lingo: lingo)
                } catch {
                    // Swallow — a transient DB blip must not kill the watchman.
                }
                try? await Task.sleep(nanoseconds: UInt64(sweepInterval * 1_000_000_000))
            }
        }
    }

    /// One pass over the players a notification could be owed to.
    public static func tick(on db: any Database, bot: TGBot, lingo: Lingo, now: Date = Date()) async throws {
        // Registration is not a state to be notified in: the account has no
        // nickname, no estate and nothing to come back to yet.
        let users = try await User.query(on: db)
            .filter(\.$routerName, .notEqual, Controllers.registration.routerName)
            .all()
        guard users.isEmpty == false else { return }

        // One query for everyone out on the trail, rather than one per player:
        // an expedition suspends resting, and the watchman must not undo that.
        let onTheTrail = Set(try await ExplorationState.query(on: db).all().compactMap { $0.$user.id })

        for row in users {
            // Mutate the instance the dispatcher is holding, if there is one:
            // this sweep writes whole rows, and a stale copy would undo the
            // tap the player made a second ago.
            let user = await sessionCache.peek(telegramId: row.telegramId) ?? row
            guard let userId = user.id else { continue }
            await notifyFullHp(user: user, inExpedition: onTheTrail.contains(userId), db: db, bot: bot, lingo: lingo)
            await notifyFortuneReady(user: user, db: db, bot: bot, lingo: lingo, now: now)
            await notifyQuestRollover(user: user, db: db, bot: bot, lingo: lingo, now: now)
        }
    }

    // MARK: - Full HP

    /// Advance the rest clock and announce the moment it tops out.
    ///
    /// The regen itself goes through `HealingService.tick`, never a second
    /// copy of the arithmetic — so the watchman and the player's next tap can
    /// only ever agree. A player who fills up WHILE tapping gets no message,
    /// and should not: they are looking at the number.
    private static func notifyFullHp(user: User, inExpedition: Bool, db: any Database, bot: TGBot, lingo: Lingo) async {
        guard user.hp < user.effectiveMaxHp, inExpedition == false else { return }
        guard (try? await HealingService.tick(user, inExpedition: false, on: db)) != nil else { return }
        guard user.hp >= user.effectiveMaxHp else { return }

        let locale = user.locale
        let body = lingo.localize("rest.full.notification", locale: locale, interpolations: [
            "hp": "\(user.hp)/\(user.effectiveMaxHp)"
        ])
        let vigor = lingo.localize("rest.full.vigor", locale: locale, interpolations: [
            "vigor": "\(user.vigor)/\(user.maxVigor)"
        ])
        await push("❤️ \(body)\n🍖 \(vigor)", to: user, bot: bot)
    }

    // MARK: - The cards are ready

    private static func notifyFortuneReady(user: User, db: any Database, bot: TGBot, lingo: Lingo, now: Date) async {
        guard user.lastFortuneDrawAt != nil, user.fortuneReadyNotified == false else { return }
        guard user.fortuneCooldownRemaining(now: now) == nil else { return }

        let body = lingo.localize("fortune.ready.notification", locale: user.locale)
        await push("🔮 \(body)", to: user, bot: bot)
        user.fortuneReadyNotified = true
        try? await user.saveAndCache(in: db)
    }

    // MARK: - The board turned over

    /// The day rolls at 12:00 Kyiv and the three boards get new offers. Worth
    /// saying out loud since 2026-09-07, when a job stopped being handed out
    /// and started having to be TAKEN at the NPC: a player who never walks
    /// into town now loses the day rather than merely the trip.
    ///
    /// The stamp is the guard. A brand-new account is stamped without a
    /// message — it has not missed anything yet.
    private static func notifyQuestRollover(user: User, db: any Database, bot: TGBot, lingo: Lingo, now: Date) async {
        let stamp = GameDay.stamp(now)
        guard user.questRolloverStamp != stamp else { return }
        let firstEverStamp = user.questRolloverStamp == nil

        user.questRolloverStamp = stamp
        try? await user.saveAndCache(in: db)
        guard firstEverStamp == false else { return }

        let body = lingo.localize("quest.rollover.notification", locale: user.locale)
        await push("📜 \(body)", to: user, bot: bot)
    }

    // MARK: - Sending

    /// Best-effort: a blocked bot or a closed chat must not stop the sweep for
    /// everyone behind this player in the loop.
    private static func push(_ text: String, to user: User, bot: TGBot) async {
        _ = try? await bot.sendMessage(params: TGSendMessageParams(
            chatId: .chat(user.telegramId),
            text: text,
            parseMode: .html
        ))
    }
}
