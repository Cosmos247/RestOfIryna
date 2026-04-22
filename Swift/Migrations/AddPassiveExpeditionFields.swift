//
//  AddPassiveExpeditionFields.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 22.04.2026.
//
//  Phase 3.3: extend `exploration_state` to cover passive expeditions.
//
//  All three columns are nullable. For active-mode rows they stay nil; for
//  passive-mode rows:
//    - `mode = "passive"`
//    - `ends_at` = scheduled completion time
//    - `report_json` = serialized PassiveReport once the simulation has run
//
//  Legacy rows from 3.1/3.2 implicitly behave as active (the model reads nil
//  `mode` as .active).
//

import Fluent

struct AddPassiveExpeditionFields: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("exploration_state")
            .field("mode", .string)
            .field("ends_at", .datetime)
            .field("report_json", .string)
            .update()
    }

    func revert(on database: any Database) async throws {
        try await database.schema("exploration_state")
            .deleteField("mode")
            .deleteField("ends_at")
            .deleteField("report_json")
            .update()
    }
}
