//
//  CreateAllowedUsers.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 08.09.2026.
//
//  Backing table for the run-time allow list (see `AllowedUser` /
//  `AccessControl`), plus the seed that carries the four founding accounts
//  over from the hardcoded `allowedUsers` array they used to live in.
//
//  The seed matters more than it looks: without it the first boot after this
//  migration locks every existing player out of a game they are already
//  registered in, including the three who played the September session. It is
//  written as an idempotent upsert-by-query rather than a blind insert so that
//  re-running it against a database where someone was already granted access
//  cannot produce a duplicate row.
//

import Fluent

struct CreateAllowedUsers: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("allowed_users")
            .id()
            .field("telegram_id", .int64, .required)
            .field("username", .string)
            .field("source", .string, .required)
            .field("created_at", .datetime)
            .unique(on: "telegram_id")
            .create()

        for telegramId in foundingUsers {
            let existing = try await AllowedUser.query(on: database)
                .filter(\.$telegramId, .equal, telegramId)
                .first()
            guard existing == nil else { continue }
            try await AllowedUser(telegramId: telegramId, source: .seed).save(on: database)
        }
    }

    func revert(on database: any Database) async throws {
        try await database.schema("allowed_users").delete()
    }
}
