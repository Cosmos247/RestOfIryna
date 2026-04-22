//
//  RenameFoodIds.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 22.04.2026.
//
//  Food catalog rework:
//    food.berry → food.forest_berries  (rename preserved)
//    food.bread, food.stew, food.roast → DELETED (no 1:1 replacement;
//                                       cooked variants come back via the
//                                       Kitchen in Phase 5.3)
//
//  Drops rows from `inventory` and `warehouse` so catalog lookups don't
//  silently produce orphan entries in the UI.
//

import Fluent

struct RenameFoodIds: AsyncMigration {

    private static let renames: [(old: String, new: String)] = [
        ("food.berry", "food.forest_berries"),
    ]

    private static let deletions: [String] = [
        "food.bread",
        "food.stew",
        "food.roast",
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
        for oldId in Self.deletions {
            try await InventoryEntry.query(on: database)
                .filter(\.$itemId, .equal, oldId)
                .delete()
            try await WarehouseEntry.query(on: database)
                .filter(\.$itemId, .equal, oldId)
                .delete()
        }
    }

    func revert(on database: any Database) async throws {
        // Renames reverse. Deletions are unrecoverable — revert only puts
        // the renamed IDs back where they were.
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
