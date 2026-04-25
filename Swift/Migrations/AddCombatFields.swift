//
//  AddCombatFields.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 25.04.2026.
//
//  Phase 4.1: extend `exploration_state` so the active-mode encounter flow can
//  persist a live combat across taps. Both columns are nullable; non-null on
//  both = player is currently fighting `combat_enemy_id` whose remaining HP is
//  `combat_enemy_hp`. When combat ends (victory / defeat / successful flee) the
//  controller nulls them out — the expedition row itself stays put.
//
//  Combat is embedded in the expedition row by design: combat in v1 only
//  happens during exploration, and `exploration_state` already has a unique
//  index on user_id, so embedding gives us the "no concurrent fights per
//  player" invariant for free.
//

import Fluent

struct AddCombatFields: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("exploration_state")
            .field("combat_enemy_id", .string)
            .field("combat_enemy_hp", .int)
            .update()
    }

    func revert(on database: any Database) async throws {
        try await database.schema("exploration_state")
            .deleteField("combat_enemy_id")
            .deleteField("combat_enemy_hp")
            .update()
    }
}
