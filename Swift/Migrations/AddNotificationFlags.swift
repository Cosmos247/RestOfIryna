//
//  AddNotificationFlags.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 09.09.2026.
//
//  Two guards for `RestNotificationService`, which announces things that
//  finish while the player is away:
//
//    • `fortune_ready_notified` — the 24 h draw cooldown, once it elapses,
//      stays elapsed forever. Without a flag the watchman would say "the
//      cards are ready" every time it wakes. Cleared on every draw.
//    • `quest_rollover_stamp` — the `GameDay` key of the last day this player
//      was told the boards turned over. A stamp rather than a bool, because
//      the event repeats daily at 12:00 Kyiv and the question is always
//      "which day did they last hear about".
//
//  Full HP needs neither: a player at full HP is not a player about to reach
//  it, so the condition guards itself.
//

import Fluent

struct AddNotificationFlags: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("users")
            .field("fortune_ready_notified", .bool, .sql(.default(false)))
            .field("quest_rollover_stamp", .string)
            .update()
    }

    func revert(on database: any Database) async throws {
        try await database.schema("users")
            .deleteField("fortune_ready_notified")
            .deleteField("quest_rollover_stamp")
            .update()
    }
}
