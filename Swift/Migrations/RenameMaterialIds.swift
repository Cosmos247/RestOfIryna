//
//  RenameMaterialIds.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 22.04.2026.
//
//  Material catalog rename pass:
//    mat.wood      → mat.pine_lumber
//    mat.stone     → mat.river_pebble
//    mat.iron_ore  → mat.old_iron
//
//  Renames in-place so any existing stockpile in `inventory` and `warehouse`
//  survives. Runs once per DB. Orphan cleanup in `configure.swift`'s dev
//  seed handles the post-rename state automatically.
//

import Fluent

struct RenameMaterialIds: AsyncMigration {

    private static let renames: [(old: String, new: String)] = [
        ("mat.wood", "mat.pine_lumber"),
        ("mat.stone", "mat.river_pebble"),
        ("mat.iron_ore", "mat.old_iron"),
    ]

    func prepare(on database: any Database) async throws {
        for (old, new) in Self.renames {
            try await InventoryEntry.query(on: database)
                .filter(\.$itemId, .equal, old)
                .set(\.$itemId, to: new)
                .update()
            try await WarehouseEntry.query(on: database)
                .filter(\.$itemId, .equal, old)
                .set(\.$itemId, to: new)
                .update()
        }
    }

    func revert(on database: any Database) async throws {
        for (old, new) in Self.renames {
            try await InventoryEntry.query(on: database)
                .filter(\.$itemId, .equal, new)
                .set(\.$itemId, to: old)
                .update()
            try await WarehouseEntry.query(on: database)
                .filter(\.$itemId, .equal, new)
                .set(\.$itemId, to: old)
                .update()
        }
    }
}
