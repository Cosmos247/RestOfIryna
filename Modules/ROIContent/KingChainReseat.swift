//
//  KingChainReseat.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 04.10.2026.
//
//  `KingProgress` stores a POSITION in the chain, not the decrees done. So a
//  reorder of `king.json` moves everyone standing in or past it onto a decree
//  they were not on. Usually that means skipping one, and a skipped decree is
//  lost for good.
//
//  `RewalkReorderedDecrees` (2026-09-27) solved its case by sending a short
//  window back to its start, which was safe because every decree in that window
//  was a live state read. The 2026-10-04 reorder (the four weapon decrees
//  following the ladder to levels 5/10/15/20, `spec-items.md` §9.5) spans
//  positions 10–37. That window is full of events (cook, claim, harvest, send,
//  craft, win a duel), and a re-walk would make players do them again.
//
//  So this re-seats BY DECREE: the decrees before the old position are done,
//  and the new position is the first decree of the new order that is not.
//  Nobody skips a decree. A decree that moved later after the player had
//  passed it comes up once more, and if it is a live state read — the weapon
//  decrees are — it closes at once. Pure Foundation, so the tests can reach it.
//

import Foundation

public enum KingChainReseat {

    /// Where a player standing at `position` of `oldOrder` stands in `newOrder`
    /// (both lists of decree ids, the chain as it was and as it is). A position
    /// at or past the end of the old chain means the chain was finished. Such a
    /// player stays finished, unless the new order holds a decree they never
    /// had — then they stand on it.
    public static func position(_ position: Int, oldOrder: [String], newOrder: [String]) -> Int {
        let done = Set(oldOrder.prefix(max(0, position)))
        return newOrder.firstIndex { !done.contains($0) } ?? newOrder.count
    }

    /// The decrees a player re-seated from `position` will be asked again —
    /// passed under the old order, still ahead of them under the new one. The
    /// migration logs this. A non-empty answer is the known cost of moving a
    /// decree later, never a skip.
    public static func askedAgain(_ position: Int, oldOrder: [String], newOrder: [String]) -> [String] {
        let done = Set(oldOrder.prefix(max(0, position)))
        let seat = self.position(position, oldOrder: oldOrder, newOrder: newOrder)
        guard seat < newOrder.count else { return [] }
        return newOrder[seat...].filter { done.contains($0) }
    }
}
