//
//  AddReadyNotifiedFlags.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 04.10.2026.
//
//  Two guards for the watchman's fourth question — "has a task become ready
//  that the player has not been told about?" (`RestNotificationService`):
//
//    • `quest_progress.ready_notified` — a taken NPC job announced as ready
//      to hand in. A bool, because a job row is one job.
//    • `king_progress.ready_notified_index` — the decree position announced
//      as complete. A position, because the row outlives every decree it
//      walks through, and an advance then needs no reset.
//
//  Existing rows start unannounced, so a task already ready when this ships
//  is announced once by the first sweep after the restart.
//
//  Verify the TABLES after the restart:
//    SELECT count(*) FROM quest_progress WHERE ready_notified IS NULL;   -- 0
//    SELECT column_name FROM information_schema.columns
//     WHERE table_name = 'king_progress' AND column_name = 'ready_notified_index';
//

import Fluent

struct AddReadyNotifiedFlags: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("quest_progress")
            .field("ready_notified", .bool, .required, .sql(.default(false)))
            .update()
        try await database.schema("king_progress")
            .field("ready_notified_index", .int)
            .update()
    }

    func revert(on database: any Database) async throws {
        try await database.schema("quest_progress")
            .deleteField("ready_notified")
            .update()
        try await database.schema("king_progress")
            .deleteField("ready_notified_index")
            .update()
    }
}
