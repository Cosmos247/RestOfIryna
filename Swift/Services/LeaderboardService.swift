//
//  LeaderboardService.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 12.09.2026.
//
//  The five boards behind the journal's 🏆 screen: level, arena honor, the
//  deepest km ever reached, every km ever walked, and (2026-10-17) the silver
//  in the purse.
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
//  the all-time board in order to build the seasonal one. The wealth board is
//  the one exception: it reads the balance as it stands — spending drops a
//  player — so it is a reading of NOW, and a season never touches it.
//
//  RANK — how many players are strictly better on the board's OWN metric, plus
//  one, so ties share a place: two players on 31 km are both 🥇 and the next is
//  3rd. The secondary sort only ORDERS the display and never splits a rank —
//  a board headed «Рівень» that puts two level-24 players at 1st and 2nd shows
//  the same number twice with nothing on screen to explain the gap.
//
//  PAGES (2026-10-17) — a board is read ten rows at a time, and a page's first
//  rank is COUNTED (strictly better + 1), never its offset + 1, because a tie
//  can straddle the page edge. The arithmetic is `LeaderboardPaging`'s. Every
//  sort ends on the row id, so equal rows keep one order between two taps and
//  a player cannot turn up on two pages, or on none.
//
//  COST — a COUNT of the board (for the page count) and the page itself,
//  whatever the player count: the rest of the page's ranks derive from its
//  first, since a rank only advances where the value changes. A third query —
//  the first row's rank — runs only past page 1, and a fourth only when the
//  viewer is not on the page shown: a viewer on it is read from the row already
//  loaded, which also guarantees their line and their listing cannot disagree.
//  The honor board needs one more when it misses, to find the viewer's arena
//  profile first. It once spent one COUNT per listed row; at a tap per screen
//  that is a round-trip budget worth not spending.
//

import Fluent
import Foundation

// MARK: - Boards

public enum LeaderboardBoard: String, CaseIterable, Sendable {
    case level
    case honor
    case depth
    case distance
    case wealth

    /// Short, stable callback token. Kept separate from `rawValue` so a board
    /// can be renamed without invalidating every button already on a player's
    /// screen, and short because `callback_data` caps at 64 bytes.
    public var slug: String {
        switch self {
        case .level:    return "lvl"
        case .honor:    return "hon"
        case .depth:    return "dep"
        case .distance: return "dst"
        case .wealth:   return "wlt"
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
        // Silver's own sign; 💰 is what a player GETS (a reward, a claim).
        case .wealth:   return "🪙"
        }
    }

    public var titleKey: String    { "leaderboard.board.\(rawValue)" }
    public var subtitleKey: String { "leaderboard.board.\(rawValue).sub" }

    /// Unit suffix appended to a value, or nil when the number speaks for
    /// itself (a level, an honor score).
    public var unitKey: String? {
        switch self {
        case .depth, .distance: return "leaderboard.unit.km"
        case .wealth:           return "leaderboard.unit.silver"
        case .level, .honor:    return nil
        }
    }

    /// Whether a row shows another player's number. The wealth board shows
    /// only places (the owner's pick, 2026-10-17): a purse on public display
    /// would be read at the market. The viewer's own row keeps its number —
    /// it tells nobody anything they could not see in their own profile.
    public var showsOthersValues: Bool { self != .wealth }
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

/// What one board render needs: one page of rows, where that page sits, and
/// the viewer's own standing. `viewer` is nil when the viewer has no entry at
/// all — level 1 is a standing, but a player who has never walked has no depth
/// and no distance, and saying "0 km, last place" about someone who has not
/// started is worse than saying nothing.
public struct LeaderboardView: Sendable {
    public let rows: [LeaderboardEntry]
    public let viewer: LeaderboardEntry?
    /// The page shown, 1-based — the one asked for, clamped into the board.
    public let page: Int
    /// At least 1: an empty board is the one page that says so.
    public let pageCount: Int
    /// True when the viewer is one of the shown `rows`, so the caller knows
    /// not to print them a second time under the separator.
    public var viewerOnPage: Bool { rows.contains { $0.isViewer } }
}

public enum LeaderboardService {

    // MARK: - Public entry point

    /// One page of `board`. `page` is 1-based and clamped into the board, so a
    /// stale button naming a page that no longer exists shows the last one.
    public static func view(_ board: LeaderboardBoard, page: Int = 1,
                            for user: User, on db: any Database) async throws -> LeaderboardView {
        switch board {
        case .level:    return try await levelView(page: page, for: user, on: db)
        case .honor:    return try await honorView(page: page, for: user, on: db)
        case .depth:    return try await userMetricView(page: page, for: user, on: db, metric: \.$deepestKm, tiebreak: \.$totalKmWalked)
        case .distance: return try await userMetricView(page: page, for: user, on: db, metric: \.$totalKmWalked, tiebreak: \.$deepestKm)
        // An empty purse has no standing, like a walk never taken: 11 of 37
        // finished registrations held 0 on 2026-10-17, nearly all level 1.
        case .wealth:   return try await userMetricView(page: page, for: user, on: db, metric: \.$silver, tiebreak: \.$level)
        }
    }

    // MARK: - Ranking a sorted page

    /// Where a requested page lands on a board of `entries` rows.
    private static func place(_ requested: Int, entries: Int) -> (page: Int, pageCount: Int, offset: Int) {
        let pageCount = LeaderboardPaging.pageCount(entries: entries)
        let page = LeaderboardPaging.clamp(requested, pageCount: pageCount)
        return (page, pageCount, LeaderboardPaging.offset(ofPage: page))
    }

    /// Assign competition ranks to an already-sorted page, using each row's own
    /// board value. Page 1 starts at the maximum, so its first row is 1st;
    /// any later page asks `better` how many rows beat its first value, because
    /// a tie can straddle the edge (`LeaderboardPaging.ranks` has the rest).
    private static func ranked<T>(_ page: [T], offset: Int, value: (T) -> Int,
                                  better: (Int) async throws -> Int) async throws -> [(rank: Int, item: T)] {
        guard let first = page.first else { return [] }
        let firstRank = offset == 0 ? 1 : try await better(value(first)) + 1
        let ranks = LeaderboardPaging.ranks(of: page.map(value), firstRank: firstRank, offset: offset)
        return Array(zip(ranks, page)).map { (rank: $0.0, item: $0.1) }
    }

    // MARK: - Level

    private static func levelView(page requested: Int, for user: User, on db: any Database) async throws -> LeaderboardView {
        let at = place(requested, entries: try await registered(on: db).count())
        let page = try await registered(on: db)
            .sort(\.$level, .descending)
            .sort(\.$xp, .descending)
            .sort(\.$id)
            .offset(at.offset)
            .limit(LeaderboardPaging.pageSize)
            .all()

        let better: (Int) async throws -> Int = { level in
            try await registered(on: db).filter(\.$level > level).count()
        }
        let rows = try await ranked(page, offset: at.offset, value: \.level, better: better).map {
            LeaderboardEntry(rank: $0.rank, name: displayName($0.item),
                             value: $0.item.level, isViewer: $0.item.id == user.id)
        }

        // Every finished registration has a level, so the viewer always ranks —
        // which is why there is no `leaderboard.unranked.level` string.
        let mine: LeaderboardEntry
        if let listed = rows.first(where: { $0.isViewer }) {
            mine = listed
        } else {
            mine = LeaderboardEntry(rank: try await better(user.level) + 1, name: displayName(user),
                                    value: user.level, isViewer: true)
        }
        return LeaderboardView(rows: rows, viewer: mine, page: at.page, pageCount: at.pageCount)
    }

    // MARK: - Honor

    private static func honorView(page requested: Int, for user: User, on db: any Database) async throws -> LeaderboardView {
        // The board reads arena_profiles rather than users: a profile is created
        // the first time a player opens the Ристалище, so its presence IS the
        // "has fought" filter. `.with` loads the owner for the name.
        let at = place(requested, entries: try await ArenaProfile.query(on: db).count())
        let page = try await ArenaProfile.query(on: db)
            .with(\.$user)
            .sort(\.$honor, .descending)
            .sort(\.$wins, .descending)
            .sort(\.$id)
            .offset(at.offset)
            .limit(LeaderboardPaging.pageSize)
            .all()

        let better: (Int) async throws -> Int = { honor in
            try await ArenaProfile.query(on: db).filter(\.$honor > honor).count()
        }
        let rows = try await ranked(page, offset: at.offset, value: \.honor, better: better).map {
            LeaderboardEntry(rank: $0.rank, name: displayName($0.item.user),
                             value: $0.item.honor, isViewer: $0.item.$user.id == user.id)
        }

        var mine = rows.first(where: { $0.isViewer })
        if mine == nil,
           let userId = user.id,
           let profile = try await ArenaProfile.query(on: db).filter(\.$user.$id == userId).first() {
            mine = LeaderboardEntry(rank: try await better(profile.honor) + 1, name: displayName(user),
                                    value: profile.honor, isViewer: true)
        }
        return LeaderboardView(rows: rows, viewer: mine, page: at.page, pageCount: at.pageCount)
    }

    // MARK: - The plain-column boards (the two walking boards, wealth)

    /// Shared body for the boards that read a plain `User` column. A zero is
    /// excluded rather than listed last: a player who has never walked has no
    /// standing on a walking board, and a page of "0 km" from every account that
    /// ever registered would bury the players who did walk. An empty purse is
    /// left out the same way.
    private static func userMetricView(
        page requested: Int,
        for user: User,
        on db: any Database,
        metric: KeyPath<User, FieldProperty<User, Int>>,
        tiebreak: KeyPath<User, FieldProperty<User, Int>>
    ) async throws -> LeaderboardView {
        let at = place(requested, entries: try await registered(on: db).filter(metric > 0).count())
        let page = try await registered(on: db)
            .filter(metric > 0)
            .sort(metric, .descending)
            .sort(tiebreak, .descending)
            .sort(\.$id)
            .offset(at.offset)
            .limit(LeaderboardPaging.pageSize)
            .all()

        // No `metric > 0` here: every value this is asked about is above zero.
        let better: (Int) async throws -> Int = { value in
            try await registered(on: db).filter(metric > value).count()
        }
        let rows = try await ranked(page, offset: at.offset, value: { $0[keyPath: metric].wrappedValue },
                                    better: better).map {
            LeaderboardEntry(rank: $0.rank, name: displayName($0.item),
                             value: $0.item[keyPath: metric].wrappedValue,
                             isViewer: $0.item.id == user.id)
        }

        let myValue = user[keyPath: metric].wrappedValue
        var mine = rows.first(where: { $0.isViewer })
        if mine == nil, myValue > 0 {
            mine = LeaderboardEntry(rank: try await better(myValue) + 1, name: displayName(user),
                                    value: myValue, isViewer: true)
        }
        return LeaderboardView(rows: rows, viewer: mine, page: at.page, pageCount: at.pageCount)
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
