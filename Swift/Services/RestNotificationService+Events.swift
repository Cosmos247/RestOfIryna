//
//  RestNotificationService+Events.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 29.10.2026.
//
//  The watchman's sixth question (2026-10-29): a holiday notice that is due —
//  a decree, the summons to the palace, the finale (`events.json` → `notices`).
//  Each goes to every registered player once, between its `at` and its
//  `until`, so a player who first turns up after the opening gets the summons
//  and not three decrees the palace has explained. The story itself is told in
//  the palace since 2026-10-30, where the scribe hands the flask over
//  (`CapitalController+Flask`). The marker (`EventNoticeLog`) is written
//  BEFORE the push, like the tasks' markers: a notice the sweep could not
//  record would repeat every minute.
//
//  The finale is the one notice that differs per reader — the podium of the
//  blood board, and the reader's own line under it.
//

import Fluent
import Foundation
@preconcurrency import Lingo
import SwiftTelegramBot

extension RestNotificationService {

    static func notifyEvents(users: [User], db: any Database, bot: TGBot, lingo: Lingo, now: Date) async {
        for event in EventCatalog.all {
            for notice in event.notices where notice.at <= now && now < notice.until {
                await send(notice, of: event, to: users, db: db, bot: bot, lingo: lingo)
            }
        }
    }

    private static func send(_ notice: GameEvent.Notice, of event: GameEvent, to users: [User],
                             db: any Database, bot: TGBot, lingo: Lingo) async {
        guard let sent = try? await EventNoticeLog.query(on: db)
            .filter(\.$eventId == event.id)
            .filter(\.$noticeId == notice.dto.id)
            .all(\.$user.$id) else { return }
        let already = Set(sent)
        let due = users.filter { user in
            guard let id = user.id else { return false }
            return user.registrationStep == User.registrationDoneStep && !already.contains(id)
        }
        guard !due.isEmpty else { return }

        // One read of the board for the whole finale, not one per reader.
        let standings = notice.kind == .finale ? (try? await EventStandings.load(event, on: db)) : nil
        for user in due {
            guard let userId = user.id else { continue }
            do {
                try await EventNoticeLog(userId: userId, eventId: event.id, noticeId: notice.dto.id).save(on: db)
            } catch {
                continue
            }
            let body: String
            switch notice.kind {
            case .plain:
                body = lingo.localize(event.keys.notice(notice.dto.id), locale: user.locale,
                                      interpolations: EventNoticeText.timeValues(event, lingo: lingo, locale: user.locale))
            case .finale:
                body = EventNoticeText.finale(notice, of: event, standings: standings ?? EventStandings(rows: []),
                                              for: user, lingo: lingo)
            }
            await push("\(notice.dto.icon) \(body)", to: user, bot: bot)
        }
    }
}

// MARK: - The blood board as it stands

/// Everyone with blood in a holiday's flask, most first, ranked so that ties
/// share a place — the board's own rule (`LeaderboardService`).
struct EventStandings: Sendable {
    struct Row: Sendable {
        let userId: UUID
        let name: String
        let total: Int
    }

    let rows: [Row]

    static func load(_ event: GameEvent, on db: any Database) async throws -> EventStandings {
        let rows = try await EventBlood.query(on: db)
            .filter(\.$eventId == event.id)
            .filter(\.$total > 0)
            .with(\.$user)
            .sort(\.$total, .descending)
            .sort(\.$id)
            .all()
        return EventStandings(rows: rows.compactMap { row in
            guard let userId = row.user.id else { return nil }
            return Row(userId: userId, name: row.user.nickname ?? "—", total: row.total)
        })
    }

    /// How many brought strictly more, plus one.
    func rank(of total: Int) -> Int {
        rows.filter { $0.total > total }.count + 1
    }

    func total(of userId: UUID) -> Int {
        rows.first { $0.userId == userId }?.total ?? 0
    }

    /// The rows that stand on the podium — every rank up to 3, ties included.
    var podium: [(rank: Int, row: Row)] {
        rows.map { (rank(of: $0.total), $0) }.filter { $0.0 <= 3 }
    }
}

// MARK: - Text

enum EventNoticeText {

    /// The close as the copy prints it, from the data that owns it: «%{close}»
    /// is the hour (`18:00`), «%{deadline}» the day and the hour («неділі,
    /// 18:00»). A `/reload` that moves the close moves the sentence with it.
    static func timeValues(_ event: GameEvent, lingo: Lingo, locale: String) -> [String: Any] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: GameDay.timeZoneID) ?? TimeZone(identifier: "UTC")!
        let parts = calendar.dateComponents([.weekday, .hour, .minute], from: event.ends)
        let close = String(format: "%02d:%02d", parts.hour ?? 0, parts.minute ?? 0)
        let day = lingo.localize("calendar.weekday.genitive.\(parts.weekday ?? 1)", locale: locale)
        let deadline = lingo.localize("event.deadline", locale: locale, interpolations: ["day": day, "time": close])
        return ["close": close, "deadline": deadline]
    }

    /// «%{flask}» of a holiday day's 12:00 notice (2026-10-30): the flask to
    /// fill, or the flask still waiting at the palace for a player who never
    /// came for it. A read that fails says the first — the approved sentence,
    /// never a summons to a flask the player may already carry.
    static func flaskSentence(_ event: GameEvent, for user: User, db: any Database, lingo: Lingo) async -> String {
        let waiting = (try? await EventBlood.hasFlask(user, eventId: event.id, on: db)) == false
        return lingo.localize(waiting ? event.keys.rolloverFlaskWaiting : event.keys.rolloverFlaskTaken,
                              locale: user.locale)
    }

    static func finale(_ notice: GameEvent.Notice, of event: GameEvent, standings: EventStandings,
                       for user: User, lingo: Lingo) -> String {
        let locale = user.locale
        let keys = event.keys
        let podium = standings.podium.map { entry -> String in
            let medal = entry.rank == 1 ? "🥇" : entry.rank == 2 ? "🥈" : "🥉"
            return "\(medal) \(TelegramHTML.escaped(entry.row.name)) — \(entry.row.total) 🩸"
        }
        let mine: String
        if let userId = user.id, standings.total(of: userId) > 0 {
            let total = standings.total(of: userId)
            mine = lingo.localize(keys.finaleMine, locale: locale, interpolations: [
                "blood": "\(total) 🩸",
                "place": ordinal(standings.rank(of: total), locale: locale)
            ])
        } else {
            mine = lingo.localize(keys.finaleNone, locale: locale)
        }
        return lingo.localize(keys.notice(notice.dto.id), locale: locale, interpolations: [
            "podium": podium.isEmpty ? "—" : podium.joined(separator: " · "),
            "mine": mine
        ])
    }

    /// «7-ме» / "7th" (`PlaceOrdinal`).
    static func ordinal(_ n: Int, locale: String) -> String {
        locale == SupportedLocale.ua.rawValue ? PlaceOrdinal.ukrainian(n) : PlaceOrdinal.english(n)
    }
}
