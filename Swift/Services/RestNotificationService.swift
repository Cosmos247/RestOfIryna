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
//  teller's next card and the 12:00 job rollover: both are moments that pass
//  with the app closed.
//
//  So this is one `Task.detached` that wakes every `restSweepInterval`
//  seconds and asks four questions of the players it loads. The fourth
//  (2026-10-04) is a task that became ready — a decree complete, a taken job
//  ready to hand in — which a player asked to be told about: nothing said so
//  except the journal they had to think of opening. The pattern is
//  `PlotProductionService`'s, for its reason: one query plus a few row
//  updates per tick, rather than one sleeping task per player, which would
//  multiply with the roster.
//
//  Each notification needs to fire ONCE. Three of them carry a flag for it —
//  `fortuneReadyNotified`, `questRolloverStamp`, and the ready markers on the
//  progress rows (`QuestProgress.readyNotified`,
//  `KingProgress.readyNotifiedIndex`) — and HP carries an in-memory mark
//  instead (`RestedToFull`): the tick that makes a fill notes it, and the
//  sweep that announces it takes it.
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
        // Same shape for the road. Resting is a place (2026-09-10), and the
        // sweep has to apply the same rule the dispatcher does or it would
        // heal — and then announce — the players it is meant to leave alone.
        let onTheRoad = Set(try await TravelState.query(on: db).all().compactMap { $0.$user.id })
        // Every rest that topped out since the last sweep, the players' own
        // taps included. Taken once, here, so a fill this sweep does not visit
        // (an account still in registration) is dropped, not announced later.
        let restedSinceLastSweep = await RestedToFull.shared.takeAll()

        for row in users {
            // Mutate the instance the dispatcher is holding, if there is one:
            // this sweep writes whole rows, and a stale copy would undo the
            // tap the player made a second ago.
            let user = await sessionCache.peek(telegramId: row.telegramId) ?? row
            guard let userId = user.id else { continue }
            let canRest = HealingService.canRest(user,
                                                 inExpedition: onTheTrail.contains(userId),
                                                 onTheRoad: onTheRoad.contains(userId))
            await notifyFullHp(user: user, canRest: canRest,
                               filledSinceLastSweep: restedSinceLastSweep.contains(userId),
                               db: db, bot: bot, lingo: lingo)
            // The cards and the new day can fall on the same minute: a card
            // drawn between noon and 06:00 is ready again at the next 12:00,
            // the rollover's own minute. Then they are ONE message, cards first
            // (the owner's pick, 2026-10-09) — one push, not two in a row.
            let fortune = await fortuneReadyLine(user: user, db: db, lingo: lingo, now: now)
            let rollover = await questRolloverLine(user: user, db: db, lingo: lingo, now: now)
            let news = [fortune, rollover].compactMap { $0 }
            if news.isEmpty == false {
                await push(news.joined(separator: "\n"), to: user, bot: bot)
            }
            await notifyTasksReady(user: user, db: db, bot: bot, lingo: lingo)
        }
    }

    // MARK: - Full HP

    /// Advance the rest clock, and announce a rest that topped out — once,
    /// within a sweep of the fill, whichever call made it.
    ///
    /// The regen itself goes through `HealingService.tick`, never a second
    /// copy of the arithmetic — so the watchman and the player's next tap can
    /// only ever agree. Until 2026-10-08 only a fill this sweep made was
    /// announced, on the theory that a player who fills up while tapping is
    /// looking at the number; most estate screens show no HP, and a new player
    /// waiting to heal taps around exactly there. `filledSinceLastSweep` is the
    /// tick's own record of the fills it made between sweeps (`RestedToFull`).
    ///
    /// Only while the player can still rest: one who topped out and walked
    /// straight out of the gate is not told about a rest already left behind.
    private static func notifyFullHp(user: User, canRest: Bool, filledSinceLastSweep: Bool,
                                     db: any Database, bot: TGBot, lingo: Lingo) async {
        var filled = filledSinceLastSweep
        if canRest, user.hp < user.effectiveMaxHp,
           (try? await HealingService.tick(user, canRest: canRest, on: db)) != nil,
           user.hp >= user.effectiveMaxHp {
            // This sweep's own fill. The tick noted it too, and that mark is
            // this same notice — taken now, or the next sweep repeats it.
            if let userId = user.id { _ = await RestedToFull.shared.take(userId) }
            filled = true
        }
        guard filled, canRest, user.hp >= user.effectiveMaxHp else { return }

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

    /// «Карти знову готові», once per draw, the moment the next card may be
    /// drawn (`User.fortuneAvailableAt`) — or nil. Returns the line rather
    /// than sending it: the caller joins it with the 12:00 rollover's when
    /// both fall in one sweep. The flag is written either way, as before: the
    /// push is best-effort and a blocked chat must not repeat it every minute.
    private static func fortuneReadyLine(user: User, db: any Database, lingo: Lingo, now: Date) async -> String? {
        guard user.lastFortuneDrawAt != nil, user.fortuneReadyNotified == false else { return nil }
        guard user.fortuneCooldownRemaining(now: now) == nil else { return nil }

        user.fortuneReadyNotified = true
        try? await user.saveAndCache(in: db)
        return "🔮 " + lingo.localize("fortune.ready.notification", locale: user.locale)
    }

    // MARK: - The board turned over

    /// The day rolls at 12:00 Kyiv and the three boards get new offers. Worth
    /// saying out loud since 2026-09-07, when a job stopped being handed out
    /// and started having to be TAKEN at the NPC: a player who never walks
    /// into town now loses the day rather than merely the trip.
    ///
    /// The stamp is the guard. A brand-new account is stamped without a
    /// message — it has not missed anything yet. Returns the line, like the
    /// cards' (see the caller), or nil.
    private static func questRolloverLine(user: User, db: any Database, lingo: Lingo, now: Date) async -> String? {
        let stamp = GameDay.stamp(now)
        guard user.questRolloverStamp != stamp else { return nil }
        let firstEverStamp = user.questRolloverStamp == nil

        user.questRolloverStamp = stamp
        try? await user.saveAndCache(in: db)
        guard firstEverStamp == false else { return nil }

        var body = lingo.localize("quest.rollover.notification", locale: user.locale)
        // Since 2026-09-19 a taken job survives the rollover and holds that
        // NPC's new offer back, so "new jobs on every board" needs qualifying
        // for a player who has one.
        if (try? await QuestService.hasCarriedJob(for: user, on: db, now: now)) == true {
            body += " " + lingo.localize("quest.rollover.locked", locale: user.locale)
        }
        return "📜 \(body)"
    }

    // MARK: - A task is ready

    /// A decree complete or a taken job ready to hand in, not announced yet.
    /// One message for however many turned ready since the last sweep, and it
    /// names none of them — the owner's pick (2026-10-04): it sends the player
    /// to the journal, which says what is ready and where to take it.
    ///
    /// Anywhere, the forest included: a delivery usually completes out there,
    /// and that is when knowing helps. Readiness is each board's own test
    /// (`KingService.standing`, `QuestService.liveDone`), so the notice cannot
    /// announce what the palace or the NPC would then refuse.
    ///
    /// The markers are written BEFORE the push and the push waits on them: a
    /// notice the sweep could not record would repeat every minute.
    private static func notifyTasksReady(user: User, db: any Database, bot: TGBot, lingo: Lingo) async {
        let decree = try? await KingService.readyUnannounced(for: user, on: db)
        let jobs = (try? await QuestService.readyUnannounced(for: user, on: db)) ?? []
        let count = (decree == nil ? 0 : 1) + jobs.count
        guard count > 0 else { return }

        do {
            if let decree { try await KingService.markAnnounced(decree, on: db) }
            try await QuestService.markAnnounced(jobs, on: db)
        } catch {
            return
        }
        let key = count == 1 ? "journal.ready.single" : "journal.ready.several"
        await push("📓 " + lingo.localize(key, locale: user.locale), to: user, bot: bot)
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
