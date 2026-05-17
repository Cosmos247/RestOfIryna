//
//  AddUserLocation.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 16.05.2026.
//
//  Phase 6.0: where the player physically is right now. "estate" = at their
//  manor (the default), "capital" = inside the city. Travel between the two
//  is gated by `TravelState`; `location` flips only when the trip completes.
//

import Fluent

struct AddUserLocation: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("users")
            .field("location", .string, .required, .sql(.default("estate")))
            .update()
    }

    func revert(on database: any Database) async throws {
        try await database.schema("users")
            .deleteField("location")
            .update()
    }
}
