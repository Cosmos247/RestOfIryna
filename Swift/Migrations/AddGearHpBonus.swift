//
//  AddGearHpBonus.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 30.08.2026.
//
//  Adds `gear_hp_bonus` to users — the sixth cached equipment bonus, alongside
//  attack / defense / crit / dodge / accuracy.
//
//  Phase 6 gives gear an HP stat because the item stat budget cannot express
//  the class armour profiles without one: cloth spends 0.26 of its allowance on
//  bulk, mail 0.20, a shield 0.30. Faking that as DEF would put it on a
//  different curve with a different cap, so it has to be its own axis.
//
//  Defaults to 0, and `EquipmentService.recomputeBonuses` fills it on the next
//  equip — plus a startup backfill, since a player who never touches their gear
//  would otherwise carry a stale zero forever.
//

import Fluent

struct AddGearHpBonus: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("users")
            .field("gear_hp_bonus", .int, .sql(.default(0)))
            .update()
    }

    func revert(on database: any Database) async throws {
        try await database.schema("users")
            .deleteField("gear_hp_bonus")
            .update()
    }
}
