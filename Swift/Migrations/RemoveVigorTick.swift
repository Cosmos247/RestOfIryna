//
//  RemoveVigorTick.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 31.08.2026.
//
//  Drops `last_vigor_tick_at` from users. Phase 8E removed passive Vigor
//  regeneration entirely, so the clock it kept has nothing left to read it:
//  Vigor now comes only from food, quest rewards and the grant a level-up
//  gives, which is what makes the pool plus the food in the bag the real limit
//  on how deep the wilderness can be walked.
//
//  `revert` puts the nullable column back, exactly as `AddVigorTick` created
//  it — nil there means "needs priming", so a restored column grants nobody
//  banked Vigor. The HP clock beside it (`last_hp_tick_at`) is untouched:
//  health still regenerates, and still pauses out on the trail.
//

import Fluent

struct RemoveVigorTick: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("users")
            .deleteField("last_vigor_tick_at")
            .update()
    }

    func revert(on database: any Database) async throws {
        try await database.schema("users")
            .field("last_vigor_tick_at", .datetime)
            .update()
    }
}
