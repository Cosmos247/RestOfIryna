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

public enum RecipeCatalog {
    public static let all: [Recipe] = [
        // 🔥 Forge — smelting.
        Recipe(
            id: "recipe.iron_ingot",
            category: .forge,
            inputs: [RecipeIngredient("mat.iron", 10)],
            output: RecipeOutput("mat.iron_ingot", 1)
        ),

        // 🧵 Tannery — Forester's leather set. Costs scale by piece size and now
        // require a little iron (smallest piece, the hood, stays hide-only). A
        // full suit costs 40 hide + 8 iron and grants +7 DEF / +1 dodge. The
        // iron makes the basic set a soft gate into the medium zone; the cost in
        // trader-material value (~200–400🪙) keeps crafting clearly cheaper than
        // buying ready-made from the Master (485🪙) while no longer near-free.
        Recipe(
            id: "recipe.forester_hood",
            category: .tannery,
            inputs: [RecipeIngredient("mat.hide", 5)],
            output: RecipeOutput("gear.forester_hood", 1)
        ),
        Recipe(
            id: "recipe.forester_jerkin",
            category: .tannery,
            inputs: [RecipeIngredient("mat.hide", 15), RecipeIngredient("mat.iron", 4)],
            output: RecipeOutput("gear.forester_jerkin", 1)
        ),
        Recipe(
            id: "recipe.forester_breeches",
            category: .tannery,
            inputs: [RecipeIngredient("mat.hide", 12), RecipeIngredient("mat.iron", 2)],
            output: RecipeOutput("gear.forester_breeches", 1)
        ),
        Recipe(
            id: "recipe.forester_boots",
            category: .tannery,
            inputs: [RecipeIngredient("mat.hide", 8), RecipeIngredient("mat.iron", 2)],
            output: RecipeOutput("gear.forester_boots", 1)
        ),

        // 🍳 Kitchen — cooked food. Costs and effects scale with the
        // ingredient count: 1-ingredient dishes restore vigor only, 3+
        // ingredient dishes also restore some HP. Every kitchen recipe
        // also burns 1× 🪵 pine_lumber for the cooking fire — adds
        // authenticity (cooking on flame needs firewood) and prevents
        // trivial farming of cooked food without lumberyard investment.
        // Players unlock the four richer recipes through scrolls
        // (artifact.recipe.<dish_id>); the two starter dishes
        // (baked_potato, roasted_meat) are always-available via
        // RecipeCatalog.starterRecipeIds so a fresh player has something
        // to cook on day one.
        Recipe(
            id: "recipe.baked_potato",
            category: .kitchen,
            inputs: [
                RecipeIngredient("food.potato", 1),
                RecipeIngredient("mat.pine_lumber", 1)
            ],
            output: RecipeOutput("food.baked_potato", 1)
        ),
        Recipe(
            id: "recipe.roasted_meat",
            category: .kitchen,
            inputs: [
                RecipeIngredient("food.raw_meat", 1),
                RecipeIngredient("mat.pine_lumber", 1)
            ],
            output: RecipeOutput("food.roasted_meat", 1)
        ),
        Recipe(
            id: "recipe.foragers_omelette",
            category: .kitchen,
            inputs: [
                RecipeIngredient("food.duck_egg", 2),
                RecipeIngredient("food.forest_nuts", 2),
                RecipeIngredient("food.forest_berries", 1),
                RecipeIngredient("mat.pine_lumber", 1)
            ],
            output: RecipeOutput("food.foragers_omelette", 1)
        ),
        Recipe(
            id: "recipe.hunters_stew",
            category: .kitchen,
            inputs: [
                RecipeIngredient("food.raw_meat", 2),
                RecipeIngredient("food.potato", 2),
                RecipeIngredient("food.duck_egg", 1),
                RecipeIngredient("mat.pine_lumber", 1)
            ],
            output: RecipeOutput("food.hunters_stew", 1)
        ),
        Recipe(
            id: "recipe.meat_ragout",
            category: .kitchen,
            inputs: [
                RecipeIngredient("food.raw_meat", 2),
                RecipeIngredient("food.potato", 2),
                RecipeIngredient("food.forest_nuts", 1),
                RecipeIngredient("mat.pine_lumber", 1)
            ],
            output: RecipeOutput("food.meat_ragout", 1)
        ),
        Recipe(
            id: "recipe.berry_tart",
            category: .kitchen,
            inputs: [
                RecipeIngredient("food.forest_berries", 4),
                RecipeIngredient("food.forest_nuts", 2),
                RecipeIngredient("food.duck_egg", 1),
                RecipeIngredient("mat.pine_lumber", 1)
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
                RecipeIngredient("food.forest_nuts", 2),
                RecipeIngredient("mat.pine_lumber", 1)
            ],
            output: RecipeOutput("food.governors_feast", 1)
        )
    ]

    /// Kitchen recipes that are **always available** — no scroll, no learning,
    /// no `LearnedRecipe` row required. Every player can cook these from day
    /// one. The kitchen UI unions this set with the player's learned recipes
    /// when deciding which dishes to show.
    public static let starterRecipeIds: Set<String> = [
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
