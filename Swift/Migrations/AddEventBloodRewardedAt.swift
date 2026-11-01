//
//  AddEventBloodRewardedAt.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 01.11.2026.
//
//  A holiday's prizes are collected in person at the palace (2026-11-01,
//  `EventRewardService`): `event_blood.rewarded_at` marks a flask whose prize
//  was handed out. One nullable column, no rows touched — every flask starts
//  owed.
//

import Fluent

struct AddEventBloodRewardedAt: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("event_blood")
            .field("rewarded_at", .datetime)
            .update()
    }

    func revert(on database: any Database) async throws {
        try await database.schema("event_blood")
            .deleteField("rewarded_at")
            .update()
    }
}
