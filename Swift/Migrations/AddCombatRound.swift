//
//  AddCombatRound.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 18.05.2026.
//
//  Adds `combat_round` (nullable Int) to `exploration_state`. Counts player
//  actions in the active fight — `beginCombat` initialises to 0, every
//  `finishRound` bumps by 1 before rendering, `endCombat` clears it. The
//  combat status card surfaces "Раунд N" once it crosses 0 (i.e. after the
//  player's first action) so the encounter intro stays clean.
//

import Fluent

struct AddCombatRound: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("exploration_state")
            .field("combat_round", .int)
            .update()
    }

    func revert(on database: any Database) async throws {
        try await database.schema("exploration_state")
            .deleteField("combat_round")
            .update()
    }
}
