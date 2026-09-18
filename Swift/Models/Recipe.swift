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
//  Forge + Tannery recipes are always available. Kitchen recipes are gated by
//  `LearnedRecipe`, and a player comes by one of two ways: it is in
//  `starterRecipeIds` (cookable from day one, no DB row), or an NPC teaches it
//  — the `unlocks` ladder below, paid out by that NPC's daily job. The
//  recipe-scroll artifacts this used to run on were deleted on 2026-09-18:
//  nothing ever granted one, so five dishes were unreachable for months.
//

import Foundation

// MARK: - Recipe Category

public enum RecipeCategory: String, Codable, CaseIterable, Sendable {
    case forge      // Smelting and metalwork
    case tannery    // Leather and hide
    case kitchen    // Cooked food: starter set ∪ what an NPC has taught

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

    /// Recipes in this category require the player to learn them first — from
    /// the starter set or from an NPC — before they show up in the cooking UI.
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

    /// Same banner for a craft that landed in the WAREHOUSE because the bag had
    /// no room. A sibling key rather than an interpolated destination: both
    /// templates already end in the place the item went, and a player reads the
    /// whole line, not a variable inside it.
    public var craftedToWarehouseAlertKey: String {
        switch self {
        case .forge, .tannery: return "workshop.alert.crafted_warehouse"
        case .kitchen:         return "kitchen.alert.cooked_warehouse"
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

    /// Recipes a fresh player can cook without being taught them.
    public static var starterRecipeIds: Set<String> { Catalogs.current.starterRecipeIds }

    /// The rungs NPCs teach recipes along, in file order.
    public static var unlocks: [RecipeUnlockDTO] { Catalogs.current.recipeUnlocks }

    /// The recipe `npc` owes this player next, or nil when nothing is pending.
    ///
    /// Delegates to `RecipeUnlockDTO.next` rather than filtering here: the quest
    /// board quotes this before the player takes the job and the payout acts on
    /// it afterwards, so there is one implementation and no second reading.
    ///
    /// `known` is the player's `LearnedRecipe` set, which does NOT contain the
    /// starters — and does not need to. A starter on the ladder is a validator
    /// error, so a bundle carrying one never installs.
    public static func nextUnlock(npc: QuestNPC, estateTier: Int, known: Set<String>) -> RecipeUnlockDTO? {
        RecipeUnlockDTO.next(in: unlocks, npc: npc.rawValue, estateTier: estateTier, known: known)
    }

    public static func find(_ id: String) -> Recipe? {
        return Catalogs.current.recipesById[id]
    }

    public static func recipes(in category: RecipeCategory) -> [Recipe] {
        return all.filter { $0.category == category }
    }
}
