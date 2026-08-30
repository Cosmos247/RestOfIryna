//
//  AddVigorTick.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 30.08.2026.
//
//  Adds `last_vigor_tick_at` to users — the clock behind Phase 5B's vigor
//  regeneration, mirroring `last_hp_tick_at`.
//
//  Nullable, and nil means "needs priming": the first observation sets the
//  clock and grants nothing, so a player who has been away since before the
//  migration cannot bank six months of Vigor on their next hello.
//

import Fluent

struct AddVigorTick: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("users")
            .field("last_vigor_tick_at", .datetime)
            .update()
    }

    func revert(on database: any Database) async throws {
        try await database.schema("users")
            .deleteField("last_vigor_tick_at")
            .update()
    }
}
