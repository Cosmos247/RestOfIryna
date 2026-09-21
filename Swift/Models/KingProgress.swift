//
//  KingProgress.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 21.09.2026.
//
//  Where a player stands in the King's decree chain. ONE row per player, and
//  two numbers in it — which is the whole state the chain needs.
//
//  `decreeIndex` is a position in `KingCatalog.chain`, not an id. The chain is
//  walked in array order and only forwards, so an index says everything: every
//  decree before it is done and paid, the one at it is open, and the ones after
//  have not been seen. Past the end means the King has fallen silent.
//
//  Storing the INDEX rather than the id is deliberate and has a cost worth
//  naming: inserting a decree in the middle of a shipped chain shifts everyone
//  who is past it. That is the right trade for a tutorial spine — the chain is
//  authored once and read in order — and the alternative, a set of completed
//  ids, would have to answer "what is open?" by scanning the chain against that
//  set on every render, and would quietly let two decrees be open at once.
//
//  `counter` belongs to the OPEN decree only and is cleared the moment the
//  index moves. Nothing accumulates ahead of time: "defeat five beasts" counts
//  from when the decree opens, so the prologue dog and everything killed before
//  it do not backfill — the same rule `QuestService.record` already applies to
//  a job nobody has taken.
//

import Fluent
import Foundation

final public class KingProgress: Model, @unchecked Sendable {
    public static let schema = "king_progress"

    @ID(key: .id)
    public var id: UUID?

    @Parent(key: "user_id")
    public var user: User

    /// Position in `KingCatalog.chain`. `>= chain.count` means finished.
    @Field(key: "decree_index")
    public var decreeIndex: Int

    /// Progress on the open decree's counted event, if it has one. Cleared on
    /// every advance — see the file header.
    @Field(key: "counter")
    public var counter: Int

    @Timestamp(key: "created_at", on: .create)
    public var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    public var updatedAt: Date?

    public init() {}

    public init(userID: UUID, decreeIndex: Int = 0, counter: Int = 0) {
        self.$user.id = userID
        self.decreeIndex = decreeIndex
        self.counter = counter
    }

    /// Move to the next decree. The counter belongs to the decree that just
    /// closed, so it goes with it — a single call, because an advance that
    /// forgets to clear leaves the next counted decree pre-filled.
    public func advance() {
        decreeIndex += 1
        counter = 0
    }
}
