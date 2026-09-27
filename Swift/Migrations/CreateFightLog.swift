//
//  CreateFightLog.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 27.09.2026.
//
//  The fight_log table: one row per finished fight in the forest, written by
//  `FightLog.record` from the fight's running tally. Nothing is backfilled —
//  no fight before this shipped left anything to backfill from, which is the
//  reason the table exists.
//
//  Cascades with the player, like every per-player table. `enemy_id` carries no
//  foreign key and is not a live reference: see `FightLog`.
//

import Fluent

struct CreateFightLog: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("fight_log")
            .id()
            .field("user_id", .uuid, .required, .references("users", "id", onDelete: .cascade))
            .field("nickname", .string)
            .field("character_class", .string, .required)
            .field("player_level", .int, .required)
            .field("depth_km", .int, .required)
            .field("enemy_id", .string, .required)
            .field("enemy_level", .int, .required)
            .field("outcome", .string, .required)
            .field("rounds", .int, .required)
            .field("vigor_spent", .int, .required)
            .field("hp_start", .int, .required)
            .field("hp_end", .int, .required)
            .field("damage_dealt", .int, .required)
            .field("max_blow", .int, .required)
            .field("max_blow_source", .string)
            .field("killing_blow", .string)
            .field("special_atk_uses", .int, .required)
            .field("special_atk_damage", .int, .required)
            .field("special_def_uses", .int, .required)
            .field("special_def_damage", .int, .required)
            .field("stance_uses", .int, .required)
            .field("stance_damage", .int, .required)
            .field("burn_damage", .int, .required)
            .field("created_at", .datetime)
            .create()
    }

    func revert(on database: any Database) async throws {
        try await database.schema("fight_log").delete()
    }
}
