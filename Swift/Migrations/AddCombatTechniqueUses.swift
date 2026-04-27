//
//  AddCombatTechniqueUses.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 27.04.2026.
//
//  Phase 4.2 polish: per-fight technique budget. Each combat starts with a
//  fixed pool of Special Attack / Special Defense / Super uses (2 / 2 / 1
//  respectively). Counters live on `exploration_state` alongside the other
//  combat fields so they're reset on every `beginCombat` and cleared on
//  `endCombat`. Buttons hide from the Techniques submenu when the matching
//  counter reaches 0.
//

import Fluent

struct AddCombatTechniqueUses: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("exploration_state")
            .field("combat_special_atk_uses", .int)
            .field("combat_special_def_uses", .int)
            .field("combat_super_uses", .int)
            .update()
    }

    func revert(on database: any Database) async throws {
        try await database.schema("exploration_state")
            .deleteField("combat_special_atk_uses")
            .deleteField("combat_special_def_uses")
            .deleteField("combat_super_uses")
            .update()
    }
}
