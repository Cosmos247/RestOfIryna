//
//  LiveReferenceQuery.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 30.08.2026.
//
//  Database half of `LiveReferenceCheck`: reads the distinct ids the running
//  game still points at, so the matching in `ROIContent` can decide whether a
//  candidate bundle is safe to install.
//
//  This is the ONLY part of the content pipeline that touches the database.
//  Every query is a `SELECT DISTINCT` on one column, so the cost is bounded by
//  the number of distinct ids in play rather than by row count — which matters,
//  because `inventory` is the largest table in the game.
//

import Fluent
import Foundation

public enum LiveReferenceQuery {

    /// Snapshot every column a content id can hide in.
    ///
    /// Adding a table here is what keeps the safety rule honest as the schema
    /// grows: a column that stores a content id and is NOT listed is a column
    /// the hot swap will happily break.
    ///
    /// Derived by walking every `@Field` in `Swift/Models`, not from the design
    /// document — which listed six of these ten. Four columns are deliberately
    /// NOT here, each for a stated reason:
    ///
    /// - `quest_progress.npc` — covered transitively. A row's `quest_id` comes
    ///   from that NPC's own pool, so an emptied pool shows up as a dangling
    ///   quest id before the NPC itself could matter.
    /// - `learned_techniques.technique_id` and `users.character_class` — the
    ///   raw values of Swift enums, and `DomainContent.init` already refuses a
    ///   bundle missing any technique kind or class row. They cannot dangle
    ///   without the install failing first.
    /// - `users.location` / `travel_state.destination` — `TravelState`'s enum
    ///   ("estate" / "capital"), not content at all.
    public static func collect(on db: any Database) async throws -> [LiveReferenceCheck.LiveIds] {
        func ids(_ table: String, _ column: String, _ kind: LiveReferenceCheck.Kind,
                 _ values: [String]) -> LiveReferenceCheck.LiveIds {
            LiveReferenceCheck.LiveIds(table: table, column: column, kind: kind, ids: values)
        }

        var live: [LiveReferenceCheck.LiveIds] = []
        live.append(ids("inventory", "item_id", .item,
                        try await InventoryEntry.query(on: db).unique().all(\.$itemId)))
        live.append(ids("warehouse", "item_id", .item,
                        try await WarehouseEntry.query(on: db).unique().all(\.$itemId)))
        live.append(ids("market_listings", "item_id", .item,
                        try await MarketListing.query(on: db).unique().all(\.$itemId)))
        live.append(ids("guild_vault", "item_id", .item,
                        try await GuildVaultEntry.query(on: db).unique().all(\.$itemId)))
        // A recipe the player has learned but the bundle no longer defines
        // leaves a workshop row that renders nothing and crafts nothing.
        live.append(ids("learned_recipes", "recipe_id", .recipe,
                        try await LearnedRecipe.query(on: db).unique().all(\.$recipeId)))
        live.append(ids("plots", "plot_type", .plotType,
                        try await Plot.query(on: db).unique().all(\.$plotType)))
        live.append(ids("quest_progress", "quest_id", .quest,
                        try await QuestProgress.query(on: db).unique().all(\.$questId)))
        // Nullable columns: null means the reference is simply absent — nobody
        // in combat, no stance held, no fortune active — so it points at
        // nothing and cannot dangle.
        let inFight = try await ExplorationState.query(on: db).unique().all(\.$combatEnemyId)
        live.append(ids("exploration_state", "combat_enemy_id", .enemy, inFight.compactMap { $0 }))
        let stances = try await ExplorationState.query(on: db).unique().all(\.$combatStance)
        live.append(ids("exploration_state", "combat_stance", .stance, stances.compactMap { $0 }))
        let fortunes = try await User.query(on: db).unique().all(\.$activeFortuneCardId)
        live.append(ids("users", "active_fortune_card_id", .fortuneCard, fortunes.compactMap { $0 }))
        return live
    }
}
