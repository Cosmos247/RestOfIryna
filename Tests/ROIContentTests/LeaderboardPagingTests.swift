//
//  LeaderboardPagingTests.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 17.10.2026.
//
//  The paged leaderboard (2026-10-17): ten rows a page, arrows that wrap round,
//  and ranks that carry across a page edge. The board used below is the live
//  level board of that day, 37 players — the one whose two level-8 players
//  shared 10th place on either side of the first page break.
//

import XCTest
@testable import ROIContent

final class LeaderboardPagingTests: XCTestCase {

    /// The level board read off the Pi on 2026-10-17, sorted as the service
    /// sorts it (level, then xp, then id).
    private static let liveLevels = [
        26, 22, 18, 16, 11, 10, 10, 10, 9, 8,
        8, 7, 7, 7, 6, 6, 5, 5, 4, 3,
        3, 2, 2, 2, 2, 2, 1, 1, 1, 1,
        1, 1, 1, 1, 1, 1, 1
    ]

    /// The rank every row should carry, counted the way the service counts the
    /// viewer's own: how many are strictly better, plus one.
    private static func boardRank(of value: Int, in board: [Int]) -> Int {
        board.filter { $0 > value }.count + 1
    }

    /// Pages the way the service reads them: the first rank counted on page 2
    /// onwards, 1 on page 1.
    private static func pagedRanks(_ board: [Int]) -> [Int] {
        let pages = LeaderboardPaging.pageCount(entries: board.count)
        var out: [Int] = []
        for page in 1...pages {
            let offset = LeaderboardPaging.offset(ofPage: page)
            let slice = Array(board[offset..<min(board.count, offset + LeaderboardPaging.pageSize)])
            let first = offset == 0 ? 1 : boardRank(of: slice[0], in: board)
            out += LeaderboardPaging.ranks(of: slice, firstRank: first, offset: offset)
        }
        return out
    }

    func testPageCountNeverReachesZero() {
        XCTAssertEqual(LeaderboardPaging.pageCount(entries: 0), 1)
        XCTAssertEqual(LeaderboardPaging.pageCount(entries: 1), 1)
        XCTAssertEqual(LeaderboardPaging.pageCount(entries: 10), 1)
        XCTAssertEqual(LeaderboardPaging.pageCount(entries: 11), 2)
        XCTAssertEqual(LeaderboardPaging.pageCount(entries: 37), 4)
    }

    /// A stale button can name a page the board no longer has, or nonsense;
    /// both land inside the board.
    func testARequestedPageLandsInsideTheBoard() {
        XCTAssertEqual(LeaderboardPaging.clamp(0, pageCount: 4), 1)
        XCTAssertEqual(LeaderboardPaging.clamp(-3, pageCount: 4), 1)
        XCTAssertEqual(LeaderboardPaging.clamp(3, pageCount: 4), 3)
        XCTAssertEqual(LeaderboardPaging.clamp(9, pageCount: 4), 4)
        XCTAssertEqual(LeaderboardPaging.clamp(2, pageCount: 0), 1)
        XCTAssertEqual(LeaderboardPaging.offset(ofPage: 1), 0)
        XCTAssertEqual(LeaderboardPaging.offset(ofPage: 4), 30)
    }

    /// The owner's pick: ▶️ on the last page opens the first, ◀️ on the first
    /// opens the last, so every tap of the row does something.
    func testTheArrowsWrapRound() {
        XCTAssertEqual(LeaderboardPaging.next(1, pageCount: 4), 2)
        XCTAssertEqual(LeaderboardPaging.next(4, pageCount: 4), 1)
        XCTAssertEqual(LeaderboardPaging.previous(4, pageCount: 4), 3)
        XCTAssertEqual(LeaderboardPaging.previous(1, pageCount: 4), 4)
        XCTAssertEqual(LeaderboardPaging.next(1, pageCount: 1), 1)
        XCTAssertEqual(LeaderboardPaging.previous(1, pageCount: 1), 1)
    }

    /// Page 2 of the live board opens on the second of the two level-8 players,
    /// who shares 10th — not «11.», and not «🥇».
    func testATieAcrossThePageEdgeKeepsItsPlace() {
        let page2 = Array(Self.liveLevels[10..<20])
        let ranks = LeaderboardPaging.ranks(of: page2, firstRank: Self.boardRank(of: page2[0], in: Self.liveLevels),
                                            offset: 10)
        XCTAssertEqual(ranks, [10, 12, 12, 12, 15, 15, 17, 17, 19, 20])
    }

    /// Every row on every page carries the rank the board gives it — the same
    /// number the viewer's own line would show for that value.
    func testEveryPagedRankMatchesTheBoardRank() {
        let expected = Self.liveLevels.map { Self.boardRank(of: $0, in: Self.liveLevels) }
        XCTAssertEqual(Self.pagedRanks(Self.liveLevels), expected)

        // A board whose ties straddle every edge, and one that is a single tie.
        let ties = [9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 2]
        XCTAssertEqual(Self.pagedRanks(ties), ties.map { Self.boardRank(of: $0, in: ties) })
        let flat = Array(repeating: 3, count: 25)
        XCTAssertEqual(Self.pagedRanks(flat), Array(repeating: 1, count: 25))
    }

    /// The check above must be able to fail: numbering a page from its offset —
    /// the trap `LeaderboardPaging` exists to avoid — gives page 2 an «11.».
    func testNumberingFromTheOffsetWouldBeCaught() {
        let page2 = Array(Self.liveLevels[10..<20])
        let naive = LeaderboardPaging.ranks(of: page2, firstRank: 11, offset: 10)
        XCTAssertNotEqual(naive, Array(Self.pagedRanks(Self.liveLevels)[10..<20]))
    }
}
