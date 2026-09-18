//
//  RecipeUnlockTests.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 18.09.2026.
//
//  The ladder an NPC teaches recipes along: the resolver both the quest board
//  and the payout read, and the rules that keep a rung authorable.
//
//  The reachability test at the bottom is the one that matters most. Its rule
//  existed before this file and reported every kitchen recipe as reachable for
//  months, because five scrolls sat in `items.json` that no drop, listing or
//  recipe ever produced — it proved the scroll EXISTED, not that a player could
//  hold one. A checker that cannot fail is not a checker, so this negative test
//  is the point of the pair.
//

import XCTest
@testable import ROIContent

final class RecipeUnlockTests: XCTestCase {

    // MARK: - The resolver

    private let ladder = [
        RecipeUnlockDTO(recipeId: "recipe.pancakes", npc: "tavern", minEstateTier: 2),
        RecipeUnlockDTO(recipeId: "recipe.pie",      npc: "tavern", minEstateTier: 3),
        RecipeUnlockDTO(recipeId: "recipe.stew",     npc: "tavern", minEstateTier: 5),
        RecipeUnlockDTO(recipeId: "recipe.ingot",    npc: "master", minEstateTier: 2),
    ]

    private func next(tier: Int, known: Set<String> = [], npc: String = "tavern") -> String? {
        RecipeUnlockDTO.next(in: ladder, npc: npc, estateTier: tier, known: known)?.recipeId
    }

    func testLowestEarnedRungComesFirst() {
        XCTAssertEqual(next(tier: 5), "recipe.pancakes")
    }

    func testKnownRungsAreSkippedInOrder() {
        XCTAssertEqual(next(tier: 5, known: ["recipe.pancakes"]), "recipe.pie")
        XCTAssertEqual(next(tier: 5, known: ["recipe.pancakes", "recipe.pie"]), "recipe.stew")
    }

    /// The ladder pays one rung per finished job, so a player who built to T5
    /// without ever visiting the innkeeper owes three visits, not one payout.
    func testFinishedLadderOwesNothing() {
        XCTAssertNil(next(tier: 5, known: ["recipe.pancakes", "recipe.pie", "recipe.stew"]))
    }

    func testTierGateHoldsTheRestBack() {
        XCTAssertNil(next(tier: 1))
        XCTAssertEqual(next(tier: 2, known: ["recipe.pancakes"]), nil)
        XCTAssertEqual(next(tier: 3, known: ["recipe.pancakes"]), "recipe.pie")
    }

    /// `npc` is a filter, not decoration: the Master's rung must never answer
    /// the innkeeper's board.
    func testEachNPCOwesOnlyItsOwnRungs() {
        XCTAssertEqual(next(tier: 7, npc: "master"), "recipe.ingot")
        XCTAssertEqual(next(tier: 7, known: ["recipe.pancakes", "recipe.pie", "recipe.stew"], npc: "tavern"), nil)
    }

    func testEmptyLadderIsNotACrash() {
        XCTAssertNil(RecipeUnlockDTO.next(in: [], npc: "tavern", estateTier: 7, known: []))
    }

    // MARK: - Authoring rules

    private func bundle(items: [ItemDTO] = [], recipes: [RecipeDTO] = [],
                        starters: [String] = [], unlocks: [RecipeUnlockDTO] = []) -> ContentBundle {
        ContentBundle(
            manifest: ManifestDTO(schemaVersion: ContentSchema.current),
            items: items, enemies: [], recipes: recipes,
            starterRecipeIds: starters, recipeUnlocks: unlocks, contentHash: "test"
        )
    }

    private func dish() -> ItemDTO {
        ItemDTO(id: "food.pie", type: "food", tier: 1, stackable: true, icon: "🥧")
    }

    private func pieRecipe() -> RecipeDTO {
        RecipeDTO(id: "recipe.pie", category: "kitchen", inputs: [],
                  output: RecipeIngredientDTO(itemId: "food.pie", quantity: 1))
    }

    private func report(_ unlocks: [RecipeUnlockDTO], starters: [String] = []) -> ContentReport {
        ContentValidator.validate(bundle(items: [dish()], recipes: [pieRecipe()],
                                        starters: starters, unlocks: unlocks))
    }

    func testUnlockOfUnknownRecipeIsAnError() {
        let r = report([RecipeUnlockDTO(recipeId: "recipe.ghost", npc: "tavern", minEstateTier: 2)])
        XCTAssertTrue(r.errors.contains { $0.rule == "reference.recipe.unknown" })
    }

    func testUnlockByUnknownNPCIsAnError() {
        let r = report([RecipeUnlockDTO(recipeId: "recipe.pie", npc: "blacksmith", minEstateTier: 2)])
        XCTAssertTrue(r.errors.contains { $0.rule == "reference.npc.unknown" })
    }

    /// Tier 1 has no kitchen, so a rung there hands over a recipe before the
    /// room that cooks it exists.
    func testUnlockBelowTierTwoIsAnError() {
        let r = report([RecipeUnlockDTO(recipeId: "recipe.pie", npc: "tavern", minEstateTier: 1)])
        XCTAssertTrue(r.errors.contains { $0.rule == "range.unlock.estate_tier" })
    }

    /// `RecipeUnlockDTO.next` deliberately does not re-check the starter set —
    /// this is the guard that makes that safe, so it must be an error and not
    /// a warning.
    func testUnlockOfAStarterIsAnError() {
        let r = report([RecipeUnlockDTO(recipeId: "recipe.pie", npc: "tavern", minEstateTier: 2)],
                       starters: ["recipe.pie"])
        XCTAssertTrue(r.errors.contains { $0.rule == "conflict.unlock.starter" })
    }

    func testTheSameRungTwiceIsAWarning() {
        let rung = RecipeUnlockDTO(recipeId: "recipe.pie", npc: "tavern", minEstateTier: 2)
        let r = report([rung, rung])
        // Asserting the SEVERITY, not the absence of errors: the minimal fixture
        // trips unrelated rules (it has no rarity ladder), and a duplicate rung
        // is authoring noise rather than something that must refuse to install.
        XCTAssertEqual(r.issues.first { $0.rule == "duplicate.unlock" }?.severity, .warning)
    }

    // MARK: - Reachability, and the hole it used to have

    func testAnUnlockMakesAKitchenRecipeReachable() {
        let r = report([RecipeUnlockDTO(recipeId: "recipe.pie", npc: "tavern", minEstateTier: 3)])
        XCTAssertFalse(r.issues.contains { $0.rule == "reachability.recipe.unreachable" })
    }

    func testAKitchenRecipeWithNoSourceIsFlagged() {
        let r = report([])
        XCTAssertTrue(r.issues.contains { $0.rule == "reachability.recipe.unreachable" })
    }

    /// THE regression test. A scroll that teaches the recipe but that nothing in
    /// the bundle produces — no drop, no forage, no plot, no listing, not even a
    /// recipe of its own — must NOT count as a source. This is exactly the shape
    /// that shipped unreachable for months.
    func testAScrollNothingGrantsDoesNotCountAsASource() {
        let scroll = ItemDTO(id: "artifact.recipe.pie", type: "artifact", tier: 1,
                             stackable: false, icon: "📜", teachesRecipe: "recipe.pie")
        let r = ContentValidator.validate(bundle(items: [dish(), scroll], recipes: [pieRecipe()]))
        XCTAssertTrue(r.issues.contains { $0.rule == "reachability.recipe.unreachable" },
                      "an unobtainable scroll must not make a recipe reachable")
    }

    /// And the other half: once something does grant the scroll, it counts.
    func testAScrollOnAShopShelfDoesCountAsASource() {
        let scroll = ItemDTO(id: "artifact.recipe.pie", type: "artifact", tier: 1,
                             stackable: false, icon: "📜", teachesRecipe: "recipe.pie")
        var b = bundle(items: [dish(), scroll], recipes: [pieRecipe()])
        b = ContentBundle(
            manifest: b.manifest, items: b.items, enemies: [], recipes: b.recipes,
            starterRecipeIds: [], recipeUnlocks: [],
            tavern: TavernFileDTO(food: [TavernFoodDTO(itemId: "artifact.recipe.pie", priceSilver: 50)],
                                  wagerTiers: [10]),
            contentHash: "test")
        let r = ContentValidator.validate(b)
        XCTAssertFalse(r.issues.contains { $0.rule == "reachability.recipe.unreachable" })
    }
}
