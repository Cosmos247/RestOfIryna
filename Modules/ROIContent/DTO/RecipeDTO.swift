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

/// Top-level shape of `recipes.json`.
public struct RecipeFileDTO: Codable, Sendable {
    public let recipes: [RecipeDTO]
    public let starterRecipeIds: [String]

    public init(recipes: [RecipeDTO], starterRecipeIds: [String] = []) {
        self.recipes = recipes
        self.starterRecipeIds = starterRecipeIds
    }

    private enum CodingKeys: String, CodingKey { case recipes, starterRecipeIds }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        recipes = try c.decode([RecipeDTO].self, forKey: .recipes)
        starterRecipeIds = try c.decodeIfPresent([String].self, forKey: .starterRecipeIds) ?? []
    }
}
