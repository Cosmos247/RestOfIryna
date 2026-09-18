//
//  LearnedRecipe.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 02.05.2026.
//
//  Phase 5.2.1: per-user known-recipe set. One row per (user, recipe) pair.
//  Forge and Tannery recipes are always available; Kitchen recipes only
//  appear in the cooking UI if the player has a row in this table.
//
//  A row gets here one way only: an NPC taught the recipe, paid out with that
//  NPC's daily job (`recipes.json` → `unlocks`, resolved by
//  `RecipeUnlockDTO.next`, written by `QuestService.payOut`). The starter
//  recipes are NOT rows — they live in `RecipeCatalog.starterRecipeIds` and the
//  Kitchen unions the two sets, which is why a fresh account needs no seeding.
//
//  Until 2026-09-18 the one way in was a recipe-scroll artifact, and no drop,
//  listing or recipe ever produced one — so five of the seven dishes could not
//  be learned at all. The scrolls are gone; `Item.teachesRecipe` and the
//  inventory's "📖 Learn" branch survive unused, logged for a cleanup.
//

import Fluent
import Foundation

public final class LearnedRecipe: Model, @unchecked Sendable {
    public static let schema = "learned_recipes"

    @ID(key: .id)
    public var id: UUID?

    @Parent(key: "user_id")
    public var user: User

    /// Maps to a `Recipe.id` from `RecipeCatalog`.
    @Field(key: "recipe_id")
    public var recipeId: String

    @Timestamp(key: "learned_at", on: .create)
    public var learnedAt: Date?

    public init() {}

    public init(userID: UUID, recipeId: String) {
        self.$user.id = userID
        self.recipeId = recipeId
    }
}

// MARK: - Helpers

extension LearnedRecipe {
    /// True if the user already knows this recipe.
    public static func has(_ recipeId: String, for user: User, on db: any Database) async throws -> Bool {
        guard let userId = user.id else { return false }
        let count = try await LearnedRecipe.query(on: db)
            .filter(\.$user.$id, .equal, userId)
            .filter(\.$recipeId, .equal, recipeId)
            .count()
        return count > 0
    }

    /// Add a recipe to the user's known set. Idempotent — returns `false` if
    /// the recipe was already learned (no row created), `true` on a fresh add.
    @discardableResult
    public static func add(_ recipeId: String, for user: User, on db: any Database) async throws -> Bool {
        guard let userId = user.id else { return false }
        if try await has(recipeId, for: user, on: db) { return false }
        try await LearnedRecipe(userID: userId, recipeId: recipeId).save(on: db)
        return true
    }

    /// Set of all recipe ids the user has learned. Used by the Kitchen UI to
    /// gate the recipe list (combined with `RecipeCatalog.starterRecipeIds`,
    /// which are always available regardless of what's in this table).
    public static func allIds(for user: User, on db: any Database) async throws -> Set<String> {
        guard let userId = user.id else { return [] }
        let rows = try await LearnedRecipe.query(on: db)
            .filter(\.$user.$id, .equal, userId)
            .all()
        return Set(rows.map { $0.recipeId })
    }
}
