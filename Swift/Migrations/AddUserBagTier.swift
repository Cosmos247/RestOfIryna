//
//  AddUserBagTier.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 11.05.2026.
//
//  Phase 5.3d: starter backpack drops to 20 slots, growing via crafted
//  upgrades at the Workshop. Adds a `bag_tier` Int column to users with
//  default 1 — existing players land at T1 (20 slots) on first save. Bag
//  rows already in their backpack stay; the cap only blocks NEW inserts
//  past the limit, same policy used for the warehouse cap.
//

import Fluent

struct AddUserBagTier: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("users")
            .field("bag_tier", .int, .required, .sql(.default(1)))
            .update()
    }

    func revert(on database: any Database) async throws {
        try await database.schema("users")
            .deleteField("bag_tier")
            .update()
    }
}
