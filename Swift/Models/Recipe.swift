//
//  Recipe.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 01.05.2026.
//
//  Static crafting catalog used by the Workshop (Phase 5.2). Recipes live in
//  code, not the DB — same convention as `ItemCatalog` and `EnemyCatalog`.
//
//  v1 ships three categories:
//    🔥 Forge   — smelting / metalwork (Iron Lump → Iron Ingot)
//    🧵 Tannery — leather armor (Forester's Hood / Jerkin / Breeches / Boots)
//    🍳 Kitchen — cooked food (Phase 5.2.1, gated by per-user learned set)
//
//  All recipes pull inputs from the player's inventory + warehouse pool
//  (inventory drained first to free slots) and deposit the output into the
//  inventory. See `CraftingService`.
//
//  Forge + Tannery recipes are always available. Kitchen recipes are gated
//  by `LearnedRecipe` — players unlock them by using a recipe-scroll artifact
//  found in the world (or auto-learn the two starter dishes at registration).
//

import Foundation

// MARK: - Recipe Category

public enum RecipeCategory: String, Codable, CaseIterable, Sendable {
    case forge      // Smelting and metalwork
    case tannery    // Leather and hide
    case kitchen    // Cooked food (Phase 5.2.1, gated by LearnedRecipe)

    public var icon: String {
        switch self {
        case .forge:   return "🔥"
        case .tannery: return "🧵"
        case .kitchen: return "🍳"
        }
    }

    /// Localization key for the section header in the workshop view.
    public var nameKey: String {
        return "workshop.category.\(rawValue)"
    }

    /// Recipes in this category require the player to learn them first
    /// (via a recipe-scroll artifact) before they show up in the cooking UI.
    public var requiresLearning: Bool {
        switch self {
        case .forge, .tannery: return false
        case .kitchen:         return true
        }
    }

    /// Callback data for the "Back" button on a recipe-detail screen — sends
    /// the player back to the list view of the right room (Workshop or Kitchen).
    public var backCallbackData: String {
        switch self {
        case .forge, .tannery: return "estate:home:workshop"
        case .kitchen:         return "estate:home:kitchen"
        }
    }

    /// Locale key for the action verb on the detail screen's primary button —
    /// "Craft" in the Workshop, "Cook" in the Kitchen.
    public var actionButtonKey: String {
        switch self {
        case .forge, .tannery: return "workshop.detail.button.craft"
        case .kitchen:         return "kitchen.detail.button.cook"
        }
    }

    /// Locale key for the success status banner shown after a successful
    /// craft. "Crafted ..." for Workshop, "Cooked ..." for Kitchen — "forged"
    /// reads strangely for a kitchen pot, so the verb tracks the room.
    public var craftedAlertKey: String {
        switch self {
        case .forge, .tannery: return "workshop.alert.crafted"
        case .kitchen:         return "kitchen.alert.cooked"
        }
    }
}

// MARK: - Ingredient / Output

public struct RecipeIngredient: Sendable {
    public let itemId: String
    public let quantity: Int

    public init(_ itemId: String, _ quantity: Int) {
        self.itemId = itemId
        self.quantity = quantity
    }
}

public struct RecipeOutput: Sendable {
    public let itemId: String
    public let quantity: Int

    public init(_ itemId: String, _ quantity: Int = 1) {
        self.itemId = itemId
        self.quantity = quantity
    }
}

// MARK: - Recipe

public struct Recipe: Sendable {
    public let id: String
    public let category: RecipeCategory
    public let inputs: [RecipeIngredient]
    public let output: RecipeOutput

    public init(id: String, category: RecipeCategory, inputs: [RecipeIngredient], output: RecipeOutput) {
        self.id = id
        self.category = category
        self.inputs = inputs
        self.output = output
    }
}

// MARK: - Catalog

/// Façade over the live content snapshot. Recipes and the starter set now live
/// in `content/data/recipes.json`.
public enum RecipeCatalog {
    public static var all: [Recipe] { Catalogs.current.recipes }

    /// Recipes a fresh player can cook without finding a scroll first.
    public static var starterRecipeIds: Set<String> { Catalogs.current.starterRecipeIds }

    public static func find(_ id: String) -> Recipe? {
        return Catalogs.current.recipesById[id]
    }

    public static func recipes(in category: RecipeCategory) -> [Recipe] {
        return all.filter { $0.category == category }
    }
}
