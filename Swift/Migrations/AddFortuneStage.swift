//
//  AddFortuneStage.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 10.10.2026.
//
//  Adds `users.fortune_stage` — where the player stands between two free tarot
//  cards: `free`, `dispelled` after «🕯 Відчарувати», `second` once the one
//  second card is drawn (`FortuneStage`).
//
//  One column with a default and no row rewritten: every live row's last card
//  IS a free card, because nothing else could be drawn before this column
//  existed, so `free` is the truth for all of them rather than a guess.
//

import Fluent

struct AddFortuneStage: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("users")
            .field("fortune_stage", .string, .required, .sql(.default("free")))
            .update()
    }

    func revert(on database: any Database) async throws {
        try await database.schema("users")
            .deleteField("fortune_stage")
            .update()
    }
}
