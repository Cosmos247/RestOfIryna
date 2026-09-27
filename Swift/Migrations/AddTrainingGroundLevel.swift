//
//  AddTrainingGroundLevel.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 27.09.2026.
//
//  The Training Ground became a building of the house: `users` gains its
//  level, 0 for everyone. Nobody starts built — the owner's call was that the
//  building is bought anew, while the techniques already learned stay
//  (`MoveTrainingGroundOffPlots`).
//

import Fluent

struct AddTrainingGroundLevel: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("users")
            .field("training_ground_level", .int, .required, .sql(.default(0)))
            .update()
    }

    func revert(on database: any Database) async throws {
        try await database.schema("users")
            .deleteField("training_ground_level")
            .update()
    }
}
