//
//  LeaderboardService.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 12.09.2026.
//
//  The four boards behind the journal's 🏆 screen: level, arena honor, the
//  deepest km ever reached, and every km ever walked.
//
//  NAMING — these are LEADERBOARDS, never "ratings". `rating` is already taken
//  in this codebase for crit / dodge / accuracy, which are converted through a
//  level curve and have a display rule of their own. The Ukrainian UI word is
//  «Рейтинги»; the code word is Leaderboard, so the two concepts cannot end up
//  sharing an identifier.
//
//  PERIOD — every board here is ALL-TIME, and that is the first period rather
//  than the only one: seasons are a decided future direction. A seasonal board
//  will be a second READING of the same metric with its own storage, never a
//  reset of `deepestKm` / `totalKmWalked`, because zeroing those would destroy
//  the all-time board in order to build the seasonal one.
//
//  RANK — how many players are strictly better on the board's OWN metric, plus
//  one, so ties share a place: two players on 31 km are both 🥇 and the next is
//  3rd. The secondary sort only ORDERS the display and never splits a rank —
//  a board headed «Рівень» that puts two level-24 players at 1st and 2nd shows
//  the same number twice with nothing on screen to explain the gap.
//
//  COST — one query for the page, whatever the player count, because the listed
//  rows' ranks are derived from the page itself: it starts at the maximum, and a
//  rank only advances where the value changes. A second query, a COUNT, runs
//  ONLY when the viewer is not already on the page — a player in the top ten is
//  read from the row already loaded, which also guarantees their line and their
//  listing cannot disagree. The honor board needs a third when it misses, to
//  find the viewer's arena profile first. It used to spend one COUNT per listed
//  row; at a tap per screen that is a round-trip budget worth not spending.
//

import Fluent
import Foundation

// MARK: - Boards

public enum LeaderboardBoard: String, CaseIterable, Sendable {
    case level
    case honor
    case depth
    case distance

    /// Short, stable callback token. Kept separate from `rawValue` so a board
    /// can be renamed without invalidating every button already on a player's
    /// screen, and short because `callback_data` caps at 64 bytes.
    public var slug: String {
        switch self {
        case .level:    return "lvl"
        case .honor:    return "hon"
        case .depth:    return "dep"
        case .distance: return "dst"
        }
    }

    public static func from(slug: String) -> LeaderboardBoard? {
        LeaderboardBoard.allCases.first { $0.slug == slug }
    }

    public var icon: String {
        switch self {
        case .level:    return "⚔️"
        case .honor:    return "🎖"
        case .depth:    return "🌲"
        case .distance: return "🚶"
        }
    }

    public var titleKey: String    { "leaderboard.board.\(rawValue)" }
    public var subtitleKey: String { "leaderboard.board.\(rawValue).sub" }

    /// Unit suffix appended to a value, or nil when the number speaks for
    /// itself (a level, an honor score).
    public var unitKey: String? {
        switch self {
        case .depth, .distance: return "leaderboard.unit.km"
        case .level, .honor:    return nil
        }
    }
}

// MARK: - Rows

public struct LeaderboardEntry: Sendable {
    public let rank: Int
    /// The name the player chose at registration. Never the Telegram one —
    /// the profile screen has the same rule.
    public let name: String
    public let value: Int
    public let isViewer: Bool
}

/// What one board render needs: the top rows, and the viewer's own standing.
/// `viewer` is nil when the viewer has no entry at all — level 1 is a standing,
/// but a player who has never walked has no depth and no distance, and saying
/// "0 km, last place" about someone who has not started is worse than saying
/// nothing.
public struct LeaderboardView: Sendable {
    public let top: [LeaderboardEntry]
    public let viewer: LeaderboardEntry?
    /// True when the viewer is already one of the `top` rows, so the caller
    /// knows not to print them a second time under the separator.
    public var viewerInTop: Bool { top.contains { $0.isViewer } }
}

public enum LeaderboardService {

    /// How many places a board shows before the separator.
    public static let topCount: Int = 10

    // MARK: - Public entry point

    public static func view(_ board: LeaderboardBoard, for user: User, on db: any Database) async throws -> LeaderboardView {
        switch board {
        case .level:    return try await levelView(for: user, on: db)
        case .honor:    return try await honorView(for: user, on: db)
        case .depth:    return try await userMetricView(board, for: user, on: db, metric: \.$deepestKm, tiebreak: \.$totalKmWalked)
        case .distance: return try await userMetricView(board, for: user, on: db, metric: \.$totalKmWalked, tiebreak: \.$deepestKm)
        }
    }

    // MARK: - Ranking a sorted page

    /// Assign competition ranks to an already-sorted page, using each row's own
    /// board value. The page starts at the maximum, so the first row is 1st and
    /// a rank only moves to the row's position when the value actually changes.
    /// Equal values keep the rank they inherited — which is what makes two 31 km
    /// players both 🥇 and the next one 3rd.
    private static func ranked<T>(_ page: [T], value: (T) -> Int) -> [(rank: Int, item: T)] {
        var out: [(rank: Int, item: T)] = []
        var rank = 0
        var previous: Int?
        for (index, item) in page.enumerated() {
            let v = value(item)
            if v != previous { rank = index + 1; previous = v }
            out.append((rank, item))
        }
        return out
    }

    // MARK: - Level

    private static func levelView(for user: User, on db: any Database) async throws -> LeaderboardView {
        let page = try await registered(on: db)
            .sort(\.$level, .descending)
            .sort(\.$xp, .descending)
            .limit(topCount)
            .all()

        let top = ranked(page, value: \.level).map {
            LeaderboardEntry(rank: $0.rank, name: displayName($0.item),
                             value: $0.item.level, isViewer: $0.item.id == user.id)
        }

        // Every finished registration has a level, so the viewer always ranks —
        // which is why there is no `leaderboard.unranked.level` string.
        let mine: LeaderboardEntry
        if let listed = top.first(where: { $0.isViewer }) {
            mine = listed
        } else {
            let better = try await registered(on: db).filter(\.$level > user.level).count()
            mine = LeaderboardEntry(rank: better + 1, name: displayName(user), value: user.level, isViewer: true)
        }
        return LeaderboardView(top: top, viewer: mine)
    }

    // MARK: - Honor

    private static func honorView(for user: User, on db: any Database) async throws -> LeaderboardView {
        // The board reads arena_profiles rather than users: a profile is created
        // the first time a player opens the Ристалище, so its presence IS the
        // "has fought" filter. `.with` loads the owner for the name.
        let page = try await ArenaProfile.query(on: db)
            .with(\.$user)
            .sort(\.$honor, .descending)
            .sort(\.$wins, .descending)
            .limit(topCount)
            .all()

        let top = ranked(page, value: \.honor).map {
            LeaderboardEntry(rank: $0.rank, name: displayName($0.item.user),
                             value: $0.item.honor, isViewer: $0.item.$user.id == user.id)
        }

        var mine = top.first(where: { $0.isViewer })
        if mine == nil,
           let userId = user.id,
           let profile = try await ArenaProfile.query(on: db).filter(\.$user.$id == userId).first() {
            let better = try await ArenaProfile.query(on: db).filter(\.$honor > profile.honor).count()
            mine = LeaderboardEntry(rank: better + 1, name: displayName(user), value: profile.honor, isViewer: true)
        }
        return LeaderboardView(top: top, viewer: mine)
    }

    // MARK: - The two walking boards

    /// Shared body for the boards that read a plain `User` column. A zero is
    /// excluded rather than listed last: a player who has never walked has no
    /// standing on a walking board, and a page of "0 km" from every account that
    /// ever registered would bury the players who did walk.
    private static func userMetricView(
        _ board: LeaderboardBoard,
        for user: User,
        on db: any Database,
        metric: KeyPath<User, FieldProperty<User, Int>>,
        tiebreak: KeyPath<User, FieldProperty<User, Int>>
    ) async throws -> LeaderboardView {
        let page = try await registered(on: db)
            .filter(metric > 0)
            .sort(metric, .descending)
            .sort(tiebreak, .descending)
            .limit(topCount)
            .all()

        let top = ranked(page, value: { $0[keyPath: metric].wrappedValue }).map {
            LeaderboardEntry(rank: $0.rank, name: displayName($0.item),
                             value: $0.item[keyPath: metric].wrappedValue,
                             isViewer: $0.item.id == user.id)
        }

        let myValue = user[keyPath: metric].wrappedValue
        var mine = top.first(where: { $0.isViewer })
        if mine == nil, myValue > 0 {
            let better = try await registered(on: db).filter(metric > myValue).count()
            mine = LeaderboardEntry(rank: better + 1, name: displayName(user), value: myValue, isViewer: true)
        }
        return LeaderboardView(top: top, viewer: mine)
    }

    // MARK: - Helpers

    /// Everyone who finished registration. Half-registered rows hold a default
    /// level and no nickname, and would otherwise pad every board.
    private static func registered(on db: any Database) -> QueryBuilder<User> {
        User.query(on: db).filter(\.$registrationStep == User.registrationDoneStep)
    }

    /// The registration nickname, never the Telegram name — the same rule the
    /// profile greeting follows. A registered row always has one; the fallback
    /// exists so a half-written row can never leak a real name onto a public
    /// screen.
    private static func displayName(_ user: User) -> String {
        user.nickname ?? "—"
    }
}
