//
//  CreateTavernGameMessages.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 20.05.2026.
//
//  Backing table for the 24 h tavern-message cleanup (see
//  `TavernGameMessage` / `TavernCleanupService`). One row per chat message a
//  dice/darts round leaves behind; the sweep deletes rows (and their
//  Telegram messages) once `created_at` is older than 24 h.
//

import Fluent

struct CreateTavernGameMessages: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("tavern_game_messages")
            .id()
            .field("telegram_id", .int64, .required)
            .field("message_id", .int, .required)
            .field("created_at", .datetime)
            .create()
    }

    func revert(on database: any Database) async throws {
        try await database.schema("tavern_game_messages").delete()
    }
}
