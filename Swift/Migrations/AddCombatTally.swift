//
//  AddCombatTally.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 27.09.2026.
//
//  Adds `combat_tally` (nullable text) to `exploration_state`: the running
//  numbers of the CURRENT fight as JSON (`CombatTally`), turned into a
//  `fight_log` row when the fight ends. `beginCombat` sets it, `endCombat`
//  clears it.
//
//  Nullable with no default, like the per-fight counters beside it: it means
//  nothing outside a fight, and a fight already in flight when this ships reads
//  nil and simply leaves no log row.
//

import Fluent

struct AddCombatTally: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("exploration_state")
            .field("combat_tally", .string)
            .update()
    }

    func revert(on database: any Database) async throws {
        try await database.schema("exploration_state")
            .deleteField("combat_tally")
            .update()
    }
}
