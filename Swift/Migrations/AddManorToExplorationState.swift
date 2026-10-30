//
//  AddManorToExplorationState.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 29.10.2026.
//
//  Adds four nullable columns to `exploration_state` for a holiday's manor
//  (`content/spec/event-veles-night.md`):
//  - `manor_event_id` — set while the walk is inside that holiday's manor;
//  - `manor_depth` — the depth reached in it;
//  - `manor_run_blood` — the blood this descent has put in the flask;
//  - `manor_offered` — the holiday whose entrance this walk was already shown,
//    so the walk is not shown it on every pass of the entrance km.
//
//  Nullable with no default: a walk in flight when this ships has seen no
//  manor and is in none, which is exactly what nil says.
//

import Fluent

struct AddManorToExplorationState: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("exploration_state")
            .field("manor_event_id", .string)
            .field("manor_depth", .int)
            .field("manor_run_blood", .int)
            .field("manor_offered", .string)
            .update()
    }

    func revert(on database: any Database) async throws {
        try await database.schema("exploration_state")
            .deleteField("manor_event_id")
            .deleteField("manor_depth")
            .deleteField("manor_run_blood")
            .deleteField("manor_offered")
            .update()
    }
}
