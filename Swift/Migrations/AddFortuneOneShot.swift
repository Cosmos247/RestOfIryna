//
//  AddFortuneOneShot.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 09.09.2026.
//
//  Adds the four columns that remember what a draw's one-shot half actually
//  did: `last_fortune_silver_delta`, `last_fortune_xp_gain`,
//  `last_fortune_hp_restored`, `last_fortune_vigor_restored`.
//
//  The fortune screen renders from `User` hours after the draw, and the card
//  id alone cannot say what happened. The Wheel of Fortune rolls 50/50
//  between +30 and −15 silver, and every loss is clamped to what the player
//  holds — so a screen that describes the CARD would tell a player who owned
//  7 silver that the Tower took 25. `FortuneService.draw` writes these on
//  every draw (zeroes for a pure duration card), so the record always
//  describes the card currently named on screen.
//
//  Defaults of 0/false mean a row drawn before this migration reads as "no
//  record", which renders as the plain "one-time effect, already received"
//  note rather than an invented number.
//

import Fluent

struct AddFortuneOneShot: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("users")
            .field("last_fortune_silver_delta", .int, .sql(.default(0)))
            .field("last_fortune_xp_gain", .int, .sql(.default(0)))
            .field("last_fortune_hp_restored", .bool, .sql(.default(false)))
            .field("last_fortune_vigor_restored", .bool, .sql(.default(false)))
            .update()
    }

    func revert(on database: any Database) async throws {
        try await database.schema("users")
            .deleteField("last_fortune_silver_delta")
            .deleteField("last_fortune_xp_gain")
            .deleteField("last_fortune_hp_restored")
            .deleteField("last_fortune_vigor_restored")
            .update()
    }
}
