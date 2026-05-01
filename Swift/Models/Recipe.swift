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

public enum RecipeCatalog {
    public static let all: [Recipe] = [
        // 🔥 Forge — smelting.
        Recipe(
            id: "recipe.iron_ingot",
            category: .forge,
            inputs: [RecipeIngredient("mat.iron", 10)],
            output: RecipeOutput("mat.iron_ingot", 1)
        ),

        // 🧵 Tannery — Forester's leather set. Costs scale by piece size:
        // hood (2) < boots (3) < breeches (5) < jerkin (6). Total 16 hide for
        // a full suit grants +7 DEF / +1 dodge.
        Recipe(
            id: "recipe.forester_hood",
            category: .tannery,
            inputs: [RecipeIngredient("mat.hide", 2)],
            output: RecipeOutput("gear.forester_hood", 1)
        ),
        Recipe(
            id: "recipe.forester_jerkin",
            category: .tannery,
            inputs: [RecipeIngredient("mat.hide", 6)],
            output: RecipeOutput("gear.forester_jerkin", 1)
        ),
        Recipe(
            id: "recipe.forester_breeches",
            category: .tannery,
            inputs: [RecipeIngredient("mat.hide", 5)],
            output: RecipeOutput("gear.forester_breeches", 1)
        ),
        Recipe(
            id: "recipe.forester_boots",
            category: .tannery,
            inputs: [RecipeIngredient("mat.hide", 3)],
            output: RecipeOutput("gear.forester_boots", 1)
        ),

        // 🍳 Kitchen — cooked food. Costs and effects scale with the
        // ingredient count: 1-ingredient dishes restore hunger only, 3+
        // ingredient dishes also restore some HP. Players unlock recipes
        // through scrolls (artifact.recipe.<dish_id>); the two starter
        // dishes (baked_potato, roasted_meat) are auto-learned at
        // registration so a fresh player has something to cook on day one.
        Recipe(
            id: "recipe.baked_potato",
            category: .kitchen,
            inputs: [RecipeIngredient("food.potato", 2)],
            output: RecipeOutput("food.baked_potato", 1)
        ),
        Recipe(
            id: "recipe.roasted_meat",
            category: .kitchen,
            inputs: [RecipeIngredient("food.raw_meat", 2)],
            output: RecipeOutput("food.roasted_meat", 1)
        ),
        Recipe(
            id: "recipe.foragers_omelette",
            category: .kitchen,
            inputs: [
                RecipeIngredient("food.duck_egg", 2),
                RecipeIngredient("food.forest_nuts", 2),
                RecipeIngredient("food.forest_berries", 1)
            ],
            output: RecipeOutput("food.foragers_omelette", 1)
        ),
        Recipe(
            id: "recipe.hunters_stew",
            category: .kitchen,
            inputs: [
                RecipeIngredient("food.raw_meat", 2),
                RecipeIngredient("food.potato", 2),
                RecipeIngredient("food.duck_egg", 1)
            ],
            output: RecipeOutput("food.hunters_stew", 1)
        ),
        Recipe(
            id: "recipe.berry_tart",
            category: .kitchen,
            inputs: [
                RecipeIngredient("food.forest_berries", 4),
                RecipeIngredient("food.forest_nuts", 2),
                RecipeIngredient("food.duck_egg", 1)
            ],
            output: RecipeOutput("food.berry_tart", 1)
        ),
        Recipe(
            id: "recipe.governors_feast",
            category: .kitchen,
            inputs: [
                RecipeIngredient("food.raw_meat", 3),
                RecipeIngredient("food.potato", 3),
                RecipeIngredient("food.duck_egg", 2),
                RecipeIngredient("food.forest_berries", 2),
                RecipeIngredient("food.forest_nuts", 2)
            ],
            output: RecipeOutput("food.governors_feast", 1)
        )
    ]

    /// Recipe ids auto-granted to every player at registration so the Kitchen
    /// is never empty on day one. Kept in sync with the Kitchen category.
    public static let starterRecipeIds: [String] = [
        "recipe.baked_potato",
        "recipe.roasted_meat"
    ]

    private static let lookup: [String: Recipe] = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })

    public static func find(_ id: String) -> Recipe? {
        return lookup[id]
    }

    /// Recipes belonging to a single category, in declaration order.
    public static func recipes(in category: RecipeCategory) -> [Recipe] {
        return all.filter { $0.category == category }
    }
}
