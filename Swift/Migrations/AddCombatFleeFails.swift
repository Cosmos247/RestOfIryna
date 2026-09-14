//
//  AddCombatFleeFails.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 15.09.2026.
//
//  Adds `combat_flee_fails` (nullable Int) to `exploration_state`. Counts the
//  failed escape attempts of the CURRENT fight — `beginCombat` initialises to
//  0, a failed Flee bumps it, `endCombat` clears it. Once it reaches
//  `combat.json` → `flee.maxFailures` the next attempt is granted without a
//  roll.
//
//  Nullable with no default rather than `.sql(.default(0))`: the column is only
//  ever read inside a live fight, and the handful of rows that are mid-fight
//  when this ships would read 0 from either shape. A default would additionally
//  suggest the column means something outside combat, and it does not — the
//  three other per-fight counters beside it (`combat_round`,
//  `combat_special_atk_uses`, `combat_super_uses`) are all nullable for the
//  same reason.
//

import Fluent

struct AddCombatFleeFails: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("exploration_state")
            .field("combat_flee_fails", .int)
            .update()
    }

    func revert(on database: any Database) async throws {
        try await database.schema("exploration_state")
            .deleteField("combat_flee_fails")
            .update()
    }
}
