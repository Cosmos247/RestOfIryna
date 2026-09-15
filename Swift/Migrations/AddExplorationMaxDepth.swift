//
//  AddExplorationMaxDepth.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 15.09.2026.
//
//  2026-09-15: adds `max_depth_km` (Int, default 0) to `exploration_state` —
//  the high-water mark of the CURRENT run. `steps_deep` cannot serve: the walk
//  home counts it back down, so by the time the player reaches the door the
//  deepest km of the run is gone. The depth leaderboard is banked from this
//  column at the door, which is what makes the board's promise — a kilometre you
//  found your way back from — true.
//
//  Required with a default rather than nullable: it means something on every
//  expedition row, from the first step. An expedition in flight across the
//  deploy lands on 0 and re-raises itself on the next step.
//

import Fluent

struct AddExplorationMaxDepth: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("exploration_state")
            .field("max_depth_km", .int, .required, .sql(.default(0)))
            .update()
    }

    func revert(on database: any Database) async throws {
        try await database.schema("exploration_state")
            .deleteField("max_depth_km")
            .update()
    }
}
