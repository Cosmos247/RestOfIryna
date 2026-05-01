//
//  Recipe.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 01.05.2026.
//
//  Static crafting catalog used by the Workshop (Phase 5.2). Recipes live in
//  code, not the DB — same convention as `ItemCatalog` and `EnemyCatalog`.
//
//  v1 ships two categories:
//    🔥 Forge   — smelting / metalwork (Iron Lump → Iron Ingot)
//    🧵 Tannery — leather armor (Forester's Hood / Jerkin / Breeches / Boots)
//
//  All recipes pull inputs from the player's inventory + warehouse pool
//  (inventory drained first to free slots) and deposit the output into the
//  inventory so the player can equip it immediately. See `CraftingService`.
//

import Foundation

// MARK: - Recipe Category

public enum RecipeCategory: String, Codable, CaseIterable, Sendable {
    case forge      // Smelting and metalwork
    case tannery    // Leather and hide

    public var icon: String {
        switch self {
        case .forge:   return "🔥"
        case .tannery: return "🧵"
        }
    }

    /// Localization key for the section header in the workshop view.
    public var nameKey: String {
        return "workshop.category.\(rawValue)"
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
        )
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
