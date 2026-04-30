//
//  RemoveOldIron.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 30.04.2026.
//
//  Phase 5.1 cleanup: `mat.old_iron` is retired — its role (medium-tier
//  iron found by foraging) is now filled by the new `mat.iron` (Iron Lump),
//  which also drops as a Mine plot bonus and feeds the Workshop's planned
//  ingot recipe.
//
//  This data migration deletes any inventory or warehouse rows still
//  pointing at `mat.old_iron`, otherwise the orphaned `item_id` would fail
//  to resolve in `ItemCatalog.find` and the player would see broken slots
//  in their bag/warehouse views.
//
//  Schema is unchanged — only data deletes. Revert is a no-op since we
//  can't (and shouldn't) reconstruct deleted rows.
//

import Fluent
import SQLKit

struct RemoveOldIron: AsyncMigration {
    func prepare(on database: any Database) async throws {
        guard let sql = database as? any SQLDatabase else { return }
        try await sql.raw("DELETE FROM inventory WHERE item_id = 'mat.old_iron'").run()
        try await sql.raw("DELETE FROM warehouse WHERE item_id = 'mat.old_iron'").run()
    }

    func revert(on database: any Database) async throws {
        // No-op: rows can't (and shouldn't) be resurrected.
    }
}
