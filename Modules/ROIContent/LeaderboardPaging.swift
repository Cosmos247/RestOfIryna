//
//  LeaderboardPaging.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 17.10.2026.
//
//  The arithmetic of a paged leaderboard (2026-10-17, the owner's picks: ten a
//  page, the arrows wrap round, the middle button only says where you are).
//  `LeaderboardService` reads the pages and the journal's 🏆 screen draws the
//  arrows; both ask here, and the tests can reach it — the reason
//  `FortuneStage` lives in this module too.
//
//  THE TRAP — a page's first rank is COUNTED, never `offset + 1`. Ranks are
//  competition ranks on the board's own metric, so a tie can straddle the page
//  edge: on 2026-10-17 two level-8 players shared 10th place, one the last row
//  of page 1 and the other the first of page 2. Numbered from its offset, page
//  2 would open «11.»; numbered from itself, as every board was while it had
//  one page, «🥇». The first row takes "how many are strictly better, plus one",
//  which the caller asks the database, and the rest follow from the page.
//

import Foundation

public enum LeaderboardPaging {

    /// Rows on one page — the board's top ten, now on every page.
    public static let pageSize: Int = 10

    /// How many pages `entries` rows fill. Never 0: an empty board is still
    /// one page, the one that says it is empty.
    public static func pageCount(entries: Int) -> Int {
        max(1, (entries + pageSize - 1) / pageSize)
    }

    /// The page actually shown for a requested one. A button left in chat can
    /// name a page the board no longer has (it shrank) or a nonsense number;
    /// either lands inside the board rather than on an empty page.
    public static func clamp(_ requested: Int, pageCount: Int) -> Int {
        min(max(1, requested), max(1, pageCount))
    }

    /// Rows before `page` — the query's OFFSET.
    public static func offset(ofPage page: Int) -> Int {
        (max(1, page) - 1) * pageSize
    }

    /// ◀️ — the page before, the last one from the first.
    public static func previous(_ page: Int, pageCount: Int) -> Int {
        page <= 1 ? max(1, pageCount) : page - 1
    }

    /// ▶️ — the page after, the first one from the last.
    public static func next(_ page: Int, pageCount: Int) -> Int {
        page >= pageCount ? 1 : page + 1
    }

    /// Competition ranks for one sorted page. `firstRank` is the first row's
    /// rank as counted by the caller (strictly better + 1, or 1 on the first
    /// page, which starts at the maximum); every later row inherits the rank
    /// above it while the value is unchanged and otherwise takes its own
    /// position on the board, `offset + index + 1`. That is what makes two
    /// 31 km players both 🥇 and the next one 3rd — across a page edge too.
    public static func ranks(of values: [Int], firstRank: Int, offset: Int) -> [Int] {
        var out: [Int] = []
        out.reserveCapacity(values.count)
        for (index, value) in values.enumerated() {
            if index == 0 {
                out.append(firstRank)
            } else if value == values[index - 1] {
                out.append(out[index - 1])
            } else {
                out.append(offset + index + 1)
            }
        }
        return out
    }
}
