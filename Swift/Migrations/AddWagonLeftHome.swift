//
//  AddWagonLeftHome.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 08.11.2026.
//
//  `wagons.left_home` (2026-11-08, `spec-wagon.md` §2.11): the player rode off
//  from the estate without the wagon. One column with a default, no rows
//  touched: every wagon that exists rides with its player, which is what false
//  says.
//

import Fluent
import SQLKit

struct AddWagonLeftHome: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("wagons")
            .field("left_home", .bool, .required, .sql(.default(false)))
            .update()
    }

    func revert(on database: any Database) async throws {
        try await database.schema("wagons")
            .deleteField("left_home")
            .update()
    }
}
