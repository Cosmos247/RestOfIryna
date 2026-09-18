//
//  RecipeDTO.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 29.08.2026.
//
//  Wire format for `content/data/recipes.json`.
//
//  `starterRecipeIds` rides along in the same file because it is meaningless
//  without the recipe list it references, and the validator checks the two
//  together.
//

import Foundation

public struct RecipeIngredientDTO: Codable, Sendable, Equatable {
    public let itemId: String
    public let quantity: Int

    public init(itemId: String, quantity: Int) {
        self.itemId = itemId
        self.quantity = quantity
    }
}

public struct RecipeDTO: Codable, Sendable, Equatable {
    public let id: String
    public let category: String
    public let inputs: [RecipeIngredientDTO]
    public let output: RecipeIngredientDTO

    public init(id: String, category: String, inputs: [RecipeIngredientDTO], output: RecipeIngredientDTO) {
        self.id = id
        self.category = category
        self.inputs = inputs
        self.output = output
    }
}

/// One rung of the ladder an NPC teaches recipes along.
///
/// A kitchen recipe reaches a player one of two ways: it is a starter, or an
/// NPC hands it over. This is the second, and it rides on that NPC's DAILY JOB
/// — finishing one pays the lowest rung the player has earned and does not
/// already know, on top of the silver and Vigor the job itself pays. Taking a
/// job is what starts it, so a recipe is earned, not granted by the calendar.
///
/// `npc` is here rather than implied so the Master can one day teach a forge
/// recipe without a second mechanism; `minEstateTier` rather than a player
/// level because the kitchen is a room of the estate, and a recipe you cannot
/// cook is not a reward.
public struct RecipeUnlockDTO: Codable, Sendable, Equatable {
    public let recipeId: String
    /// Matches a `QuestNPC` raw value.
    public let npc: String
    /// Estate tier from which this rung is on offer. Never below 2 — tier 1 has
    /// no kitchen, so the recipe would arrive before the room that cooks it.
    public let minEstateTier: Int

    public init(recipeId: String, npc: String, minEstateTier: Int) {
        self.recipeId = recipeId
        self.npc = npc
        self.minEstateTier = minEstateTier
    }
}

extension RecipeUnlockDTO {
    /// What `npc` owes this player next: the lowest rung earned and not known.
    /// Nil when the ladder is finished or nothing is earned yet.
    ///
    /// ONE implementation on purpose. The board quotes this before the player
    /// commits and the payout acts on it afterwards; two readings of the same
    /// fact is exactly the shape that ends up disagreeing. Ties inside a tier
    /// fall to file order, so the ladder's order is content, like a quest pool's.
    public static func next(in ladder: [RecipeUnlockDTO], npc: String,
                           estateTier: Int, known: Set<String>) -> RecipeUnlockDTO? {
        ladder
            .filter { $0.npc == npc && $0.minEstateTier <= estateTier && !known.contains($0.recipeId) }
            .min { $0.minEstateTier < $1.minEstateTier }
    }
}

/// Top-level shape of `recipes.json`.
public struct RecipeFileDTO: Codable, Sendable {
    public let recipes: [RecipeDTO]
    public let starterRecipeIds: [String]
    /// ORDER IS GAMEPLAY for ties — see `RecipeUnlockDTO.next`.
    public let unlocks: [RecipeUnlockDTO]

    public init(recipes: [RecipeDTO], starterRecipeIds: [String] = [], unlocks: [RecipeUnlockDTO] = []) {
        self.recipes = recipes
        self.starterRecipeIds = starterRecipeIds
        self.unlocks = unlocks
    }

    private enum CodingKeys: String, CodingKey { case recipes, starterRecipeIds, unlocks }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        recipes = try c.decode([RecipeDTO].self, forKey: .recipes)
        starterRecipeIds = try c.decodeIfPresent([String].self, forKey: .starterRecipeIds) ?? []
        unlocks = try c.decodeIfPresent([RecipeUnlockDTO].self, forKey: .unlocks) ?? []
    }
}
