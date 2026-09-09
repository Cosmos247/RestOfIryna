//
//  AddPassiveDailyBudget.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 09.09.2026.
//
//  `passive_minutes_today` + `passive_day_stamp` — the daily ceiling on
//  passive expeditions (`tuning/exploration.json` → `passive.dailyBudgetMinutes`).
//
//  A counter plus the game-day key it belongs to, never a counter alone: the
//  day rolls at 12:00 Kyiv, and comparing a stored stamp against
//  `GameDay.stamp` detects that rollover on the next read instead of needing a
//  job awake at noon. Same shape as `ArenaProfile.fightsSpentToday` and
//  `QuestProgress.dayStamp`.
//
//  A null stamp reads as "no day recorded yet", which is exactly right for
//  every existing row: nobody has spent budget on a day that had no budget.
//

import Fluent

struct AddPassiveDailyBudget: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("users")
            .field("passive_minutes_today", .int, .sql(.default(0)))
            .field("passive_day_stamp", .string)
            .update()
    }

    func revert(on database: any Database) async throws {
        try await database.schema("users")
            .deleteField("passive_minutes_today")
            .deleteField("passive_day_stamp")
            .update()
    }
}
