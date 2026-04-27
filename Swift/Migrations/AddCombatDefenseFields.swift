//
//  AddCombatDefenseFields.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 27.04.2026.
//
//  Phase 4.2.3: extend `exploration_state` with two short-lived persistent
//  effects set by class Special Defenses:
//    - `combat_enemy_def_debuff` — rounds remaining where the player's swings
//      ignore enemy DEF (set by warrior's Iron Bulwark for the follow-up
//      attack).
//    - `combat_player_dodge_buff` — rounds remaining where the player gets a
//      flat +50 dodge against incoming hits (set by archer's Shadow Veil).
//
//  Both nullable; non-null + > 0 = effect active. Decremented at the end of
//  each player action via `tickDefenseEffects`. Cleared on `endCombat`.
//

import Fluent

struct AddCombatDefenseFields: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("exploration_state")
            .field("combat_enemy_def_debuff", .int)
            .field("combat_player_dodge_buff", .int)
            .update()
    }

    func revert(on database: any Database) async throws {
        try await database.schema("exploration_state")
            .deleteField("combat_enemy_def_debuff")
            .deleteField("combat_player_dodge_buff")
            .update()
    }
}
