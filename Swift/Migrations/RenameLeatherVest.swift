//
//  RenameLeatherVest.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 01.05.2026.
//
//  Phase 5.2: the placeholder `gear.leather_vest` is reborn as
//  `gear.forester_jerkin` — first piece of the Forester's leather set crafted
//  in the Workshop's Tannery. Same chest slot; +3 DEF instead of +2.
//
//  Renames inventory + warehouse rows in place so any existing piece (worn,
//  in the bag, or stored) carries over without loss. Pure data migration —
//  no schema change.
//

import Fluent

struct RenameLeatherVest: AsyncMigration {

    private static let oldId = "gear.leather_vest"
    private static let newId = "gear.forester_jerkin"

    func prepare(on database: any Database) async throws {
        try await InventoryEntry.query(on: database)
            .filter(\.$itemId, .equal, Self.oldId)
            .set(\.$itemId, to: Self.newId)
            .update()
        try await WarehouseEntry.query(on: database)
            .filter(\.$itemId, .equal, Self.oldId)
            .set(\.$itemId, to: Self.newId)
            .update()
    }

    func revert(on database: any Database) async throws {
        try await InventoryEntry.query(on: database)
            .filter(\.$itemId, .equal, Self.newId)
            .set(\.$itemId, to: Self.oldId)
            .update()
        try await WarehouseEntry.query(on: database)
            .filter(\.$itemId, .equal, Self.newId)
            .set(\.$itemId, to: Self.oldId)
            .update()
    }
}
