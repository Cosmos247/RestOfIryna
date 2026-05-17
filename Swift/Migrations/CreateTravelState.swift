//
//  CreateTravelState.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 16.05.2026.
//
//  Phase 6.0: presence of a row = the player is on the road between estate
//  and capital. Unique per user (you can't be on two roads at once). Mirrors
//  the passive-expedition shape (ends_at + Task.sleep scheduler) but lighter
//  — no per-step rolls, just a one-shot timer that flips `User.location`
//  on arrival.
//

import Fluent

struct CreateTravelState: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("travel_state")
            .id()
            .field("user_id", .uuid, .required, .references("users", "id", onDelete: .cascade))
            .field("destination", .string, .required)
            .field("ends_at", .datetime, .required)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .unique(on: "user_id")
            .create()
    }

    func revert(on database: any Database) async throws {
        try await database.schema("travel_state").delete()
    }
}
