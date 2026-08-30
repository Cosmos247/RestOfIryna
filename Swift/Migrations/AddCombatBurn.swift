//
//  AddCombatBurn.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 30.08.2026.
//
//  Adds the burn counters to `exploration_state` — the Phase 5D rebuild of the
//  mage's Soulfire.
//
//  Two columns rather than one because the damage is fixed WHEN THE TECHNIQUE
//  LANDS, from the attacker's ATK at that moment. Recomputing it per tick would
//  let a stance expiring mid-burn retroactively weaken a fire already burning.
//
//  Both nullable: nil is "not burning", which keeps the `hasEnemyBurn` query as
//  sharp as the existing debuff counters next to them.
//

import Fluent

struct AddCombatBurn: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("exploration_state")
            .field("combat_enemy_burn_rounds", .int)
            .field("combat_enemy_burn_damage", .int)
            .update()
    }

    func revert(on database: any Database) async throws {
        try await database.schema("exploration_state")
            .deleteField("combat_enemy_burn_rounds")
            .deleteField("combat_enemy_burn_damage")
            .update()
    }
}
