//
//  AddQuestAccepted.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 07.09.2026.
//
//  Adds `accepted` to quest_progress. Daily jobs are no longer live the moment
//  the day rolls over — the player takes them at the NPC in the capital, and a
//  counter only ticks for a row that was taken.
//
//  Defaults to false, which is the correct reading for any row that predates
//  the column: a job nobody took cannot have been running.
//

import Fluent

struct AddQuestAccepted: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("quest_progress")
            .field("accepted", .bool, .required, .sql(.default(false)))
            .update()
    }

    func revert(on database: any Database) async throws {
        try await database.schema("quest_progress")
            .deleteField("accepted")
            .update()
    }
}
