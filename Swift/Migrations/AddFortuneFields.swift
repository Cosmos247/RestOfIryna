//
//  AddFortuneFields.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 17.05.2026.
//
//  Phase 6.4 (Fortune Teller): per-user state for the daily-ish tarot draw
//  at the capital's Ворожка. One timestamp does double duty — it's both the
//  effect's expiry AND the cooldown gate (player can't draw again until the
//  previous card expires). 4-hour duration means up to ~6 draws/day.
//

import Fluent

struct AddFortuneFields: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("users")
            .field("active_fortune_card_id",     .string)
            .field("active_fortune_expires_at",  .datetime)
            .update()
    }

    func revert(on database: any Database) async throws {
        try await database.schema("users")
            .deleteField("active_fortune_card_id")
            .deleteField("active_fortune_expires_at")
            .update()
    }
}
