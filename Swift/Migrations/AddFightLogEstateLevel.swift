//
//  AddFightLogEstateLevel.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 03.10.2026.
//
//  Adds `estate_level` (nullable int) to `fight_log`: the player's estate tier
//  when the fight happened. Since 2026-10-03 a creature's HP and ATK grow with
//  that tier (`spec-bestiary.md` §11), and nothing else remembers it once the
//  player upgrades — so the first live fights can only be grouped by tier if
//  the log writes it down.
//
//  Nullable with no default, and nothing is backfilled: a fight logged before
//  this shipped was unscaled whatever the tier was, so null is the honest
//  answer and any number would be a guess.
//

import Fluent

struct AddFightLogEstateLevel: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("fight_log")
            .field("estate_level", .int)
            .update()
    }

    func revert(on database: any Database) async throws {
        try await database.schema("fight_log")
            .deleteField("estate_level")
            .update()
    }
}
