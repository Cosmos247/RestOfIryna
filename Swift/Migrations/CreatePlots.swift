//
//  CreatePlots.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 29.04.2026.
//
//  Phase 5.1: per-user estate plot slots. Production accumulates from
//  `last_harvested_at` at a code-based rate (per plot_type × tier) and is
//  capped — no need to store the accumulator, lazy-compute on visit. The
//  `notified_full` flag is flipped by the background ticker once a plot
//  reaches its cap; harvest resets it.
//
//  Spatial layout (the 30×30 estate grid) is deferred to Phase 7 territorial
//  PvP design; for the MVP plots are just an indexed list per user.
//

import Fluent

struct CreatePlots: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("plots")
            .id()
            .field("user_id", .uuid, .required, .references("users", "id", onDelete: .cascade))
            .field("slot_index", .int, .required)
            .field("plot_type", .string, .required)
            .field("tier", .int, .required)
            .field("last_harvested_at", .datetime, .required)
            .field("notified_full", .bool, .required, .sql(.default(false)))
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .unique(on: "user_id", "slot_index")
            .create()
    }

    func revert(on database: any Database) async throws {
        try await database.schema("plots").delete()
    }
}
