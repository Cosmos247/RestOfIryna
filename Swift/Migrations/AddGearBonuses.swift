//
//  AddGearBonuses.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 21.04.2026.
//
//  Cached aggregate of all equipped gear's stat bonuses. Recomputed whenever
//  the player equips/unequips something (see EquipmentService in Phase 2.3.3),
//  so that combat and profile rendering can read effective stats synchronously
//  without re-querying the inventory every time.
//

import Fluent

struct AddGearBonuses: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("users")
            .field("gear_attack_bonus",   .int, .required, .sql(.default(0)))
            .field("gear_defense_bonus",  .int, .required, .sql(.default(0)))
            .field("gear_crit_bonus",     .int, .required, .sql(.default(0)))
            .field("gear_dodge_bonus",    .int, .required, .sql(.default(0)))
            .field("gear_accuracy_bonus", .int, .required, .sql(.default(0)))
            .update()
    }

    func revert(on database: any Database) async throws {
        try await database.schema("users")
            .deleteField("gear_attack_bonus")
            .deleteField("gear_defense_bonus")
            .deleteField("gear_crit_bonus")
            .deleteField("gear_dodge_bonus")
            .deleteField("gear_accuracy_bonus")
            .update()
    }
}
