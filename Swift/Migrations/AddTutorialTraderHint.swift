//
//  AddTutorialTraderHint.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 18.05.2026.
//
//  Adds `tutorial_trader_hint_shown` (bool, default false) to users so the
//  one-shot "there's a Trader in the Capital, sell him your loot" tutorial
//  hint fires exactly once per player — on the first return from an active
//  expedition.
//

import Fluent

struct AddTutorialTraderHint: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("users")
            .field("tutorial_trader_hint_shown", .bool, .required, .sql(.default(false)))
            .update()
    }

    func revert(on database: any Database) async throws {
        try await database.schema("users")
            .deleteField("tutorial_trader_hint_shown")
            .update()
    }
}
