//
//  AddExplorationHaul.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 23.10.2026.
//
//  Adds `haul` (nullable text) to `exploration_state`: what an active walk has
//  put in the bag so far, as JSON (`ExpeditionHaul`), named at the manor door
//  as «Принесено:». `ExplorationState.begin` sets it empty.
//
//  Nullable with no default: a passive run never has one, and a walk already
//  in flight when this ships reads nil and comes home without the list — its
//  finds before the restart were never counted, and a partial list would lie.
//

import Fluent

struct AddExplorationHaul: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("exploration_state")
            .field("haul", .string)
            .update()
    }

    func revert(on database: any Database) async throws {
        try await database.schema("exploration_state")
            .deleteField("haul")
            .update()
    }
}
