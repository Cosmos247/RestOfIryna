//
//  AddCombatStanceFields.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 27.04.2026.
//
//  Phase 4.2: extend `exploration_state` with a "stance" — a class-specific
//  Super technique buff that lasts a small number of rounds and modifies
//  damage / vigor / accuracy / dodge. Both columns are nullable; non-null on
//  both = a stance is currently active and `combat_stance_rounds_left` ticks
//  down at the end of each player action. When the counter reaches zero the
//  controller nulls the columns and emits an "expire" narrative.
//
//  Lives on the same row as the active combat (combat_enemy_id / _hp) since
//  stances only matter inside a fight; ending combat clears stance fields too.
//

import Fluent

struct AddCombatStanceFields: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("exploration_state")
            .field("combat_stance", .string)
            .field("combat_stance_rounds_left", .int)
            .update()
    }

    func revert(on database: any Database) async throws {
        try await database.schema("exploration_state")
            .deleteField("combat_stance")
            .deleteField("combat_stance_rounds_left")
            .update()
    }
}
