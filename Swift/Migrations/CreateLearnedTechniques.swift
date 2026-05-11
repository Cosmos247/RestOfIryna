//
//  CreateLearnedTechniques.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 11.05.2026.
//
//  Phase 5.3e: per-user known-technique set. One row per (user, kind)
//  pair. Used by the combat submenu to gate the three technique kinds
//  (special_atk / special_def / super) — unknown kinds render with a 🔒
//  prefix and route to a "learn at Training Ground" alert.
//

import Fluent

struct CreateLearnedTechniques: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("learned_techniques")
            .id()
            .field("user_id", .uuid, .required, .references("users", "id", onDelete: .cascade))
            .field("technique_id", .string, .required)
            .field("learned_at", .datetime)
            .unique(on: "user_id", "technique_id")
            .create()
    }

    func revert(on database: any Database) async throws {
        try await database.schema("learned_techniques").delete()
    }
}
