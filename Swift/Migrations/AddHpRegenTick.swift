//
//  AddHpRegenTick.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 22.04.2026.
//
//  Phase 3.2 polish: per-user timestamp of the last passive HP regeneration
//  tick. Fluent sets it to nil for existing rows on first access — the regen
//  service primes it to `now` the first time it sees a damaged, non-exploring
//  user, so no back-dated healing is ever banked.
//

import Fluent

struct AddHpRegenTick: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("users")
            .field("last_hp_tick_at", .datetime)
            .update()
    }

    func revert(on database: any Database) async throws {
        try await database.schema("users")
            .deleteField("last_hp_tick_at")
            .update()
    }
}
