//
//  MoveTrainingGroundOffPlots.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 27.09.2026.
//
//  Data migration: every `training_ground` plot is deleted, which frees its
//  slot for a production plot. The type no longer exists in `plots.json`, so a
//  row left behind would name nothing. Learned techniques are untouched — they
//  live in `learned_techniques`, not on the plot — and the building starts at
//  level 0 for everyone; building it later catches its level up to what the
//  player already knows. Verify the TABLE after the deploy, not the log line:
//  `SELECT count(*) FROM plots WHERE plot_type = 'training_ground'` must be 0.
//

import Fluent

struct MoveTrainingGroundOffPlots: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await Plot.query(on: database)
            .filter(\.$plotType, .equal, "training_ground")
            .delete()
    }

    /// The deleted plots carried nothing but their slot and type; there is
    /// nothing to put back that the player would recognise.
    func revert(on database: any Database) async throws {}
}
