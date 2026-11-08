//
//  AddTravelCrossing.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 08.11.2026.
//
//  `travel_state.crossing_seconds` (2026-11-08, `spec-wagon.md`): the whole
//  crossing a trip set out on — 3 min with a hired wagon, 2 without — stamped at
//  the start so a turn-back is measured against the road the player is on. One
//  nullable column, no rows touched: a trip already in flight reads nil, which
//  is the road's own crossing, exactly what it set out on.
//

import Fluent

struct AddTravelCrossing: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("travel_state")
            .field("crossing_seconds", .double)
            .update()
    }

    func revert(on database: any Database) async throws {
        try await database.schema("travel_state")
            .deleteField("crossing_seconds")
            .update()
    }
}
