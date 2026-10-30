//
//  CreateEventNotices.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 29.10.2026.
//
//  The event_notices table: one row per holiday notice sent to a player
//  (`EventNoticeLog`), written BEFORE the push, so the watchman sends each
//  notice once — the shape of the other notices' markers. A new table and
//  nothing else. Cascades with the player and is listed in
//  `WipeForRebalance.playerTables`.
//

import Fluent

struct CreateEventNotices: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("event_notices")
            .id()
            .field("user_id", .uuid, .required, .references("users", "id", onDelete: .cascade))
            .field("event_id", .string, .required)
            .field("notice_id", .string, .required)
            .field("created_at", .datetime)
            .unique(on: "user_id", "event_id", "notice_id")
            .create()
    }

    func revert(on database: any Database) async throws {
        try await database.schema("event_notices").delete()
    }
}
