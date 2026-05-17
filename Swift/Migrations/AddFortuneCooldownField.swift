//
//  AddFortuneCooldownField.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 17.05.2026.
//
//  Phase 6.4 fix: split the fortune cooldown from the buff duration.
//  `active_fortune_expires_at` (added in AddFortuneFields) was doing
//  double duty — both the 6h buff window AND the next-draw gate. Per
//  design correction, draws cooldown for 24h while the buff lasts only
//  6h. `last_fortune_draw_at` is now the cooldown stamp.
//

import Fluent

struct AddFortuneCooldownField: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("users")
            .field("last_fortune_draw_at", .datetime)
            .update()
    }

    func revert(on database: any Database) async throws {
        try await database.schema("users")
            .deleteField("last_fortune_draw_at")
            .update()
    }
}
