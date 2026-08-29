//
//  ContentValidatorTests.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 29.08.2026.
//

import XCTest
@testable import ROIContent

final class ContentValidatorTests: XCTestCase {

    private func bundle(
        items: [ItemDTO] = [],
        enemies: [EnemyDTO] = [],
        recipes: [RecipeDTO] = [],
        starters: [String] = [],
        timeScale: Double = 1.0
    ) -> ContentBundle {
        ContentBundle(
            manifest: ManifestDTO(schemaVersion: ContentSchema.current, timeScale: timeScale),
            items: items, enemies: enemies, recipes: recipes,
            starterRecipeIds: starters, contentHash: "test"
        )
    }

    private func hide() -> ItemDTO {
        ItemDTO(id: "mat.hide", type: "material", tier: 1, stackable: true, icon: "🟫")
    }

    /// The shipped `Dictionary(uniqueKeysWithValues:)` traps on a duplicate id.
    /// Once ids come from JSON, one copy-paste would crash the bot — so this
    /// must be caught before install.
    func testDuplicateIdIsAnError() {
        let report = ContentValidator.validate(bundle(items: [hide(), hide()]))
        XCTAssertTrue(report.hasErrors)
        XCTAssertEqual(report.errors.first?.rule, "identity.duplicate_id")
    }

    func testUnknownLootItemIsAnError() {
        let enemy = EnemyDTO(id: "enemy.wild_boar", tier: 1, icon: "🐗", xpReward: 5,
                             stats: EnemyStatsDTO(hp: 18, attack: 14, defense: 1),
                             depth: IntRangeDTO(min: 1, max: 10),
                             loot: [EnemyLootDropDTO(itemId: "mat.ghost", chance: 0.8)])
        let report = ContentValidator.validate(bundle(items: [hide()], enemies: [enemy]))
        XCTAssertEqual(report.errors.first?.rule, "reference.item.unknown")
    }

    func testInvertedDepthRangeIsAnError() {
        let enemy = EnemyDTO(id: "enemy.x", tier: 1, icon: "🐗", xpReward: 1,
                             stats: EnemyStatsDTO(hp: 10, attack: 2, defense: 0),
                             depth: IntRangeDTO(min: 30, max: 21))
        let report = ContentValidator.validate(bundle(enemies: [enemy]))
        XCTAssertEqual(report.errors.first?.rule, "identity.range.inverted")
    }

    func testStackableGearIsAnError() {
        let gear = ItemDTO(id: "gear.sword", type: "gear", tier: 1, stackable: true,
                           slot: "main_hand", gearStats: GearStatsDTO(attack: 3))
        let report = ContentValidator.validate(bundle(items: [gear]))
        XCTAssertTrue(report.errors.contains { $0.rule == "identity.gear.stackable" })
    }

    func testGearWithoutSlotIsAnError() {
        let gear = ItemDTO(id: "gear.sword", type: "gear", tier: 1, stackable: false)
        let report = ContentValidator.validate(bundle(items: [gear]))
        XCTAssertTrue(report.errors.contains { $0.rule == "identity.gear.missing_slot" })
    }

    func testTimeScaleWarnsAndStrictPromotesIt() {
        let warning = ContentValidator.validate(bundle(timeScale: 60))
        XCTAssertFalse(warning.hasErrors)
        XCTAssertEqual(warning.warnings.first?.rule, "time.scale_not_one")

        let strict = ContentValidator.validate(bundle(timeScale: 60), strict: true)
        XCTAssertTrue(strict.hasErrors, "a release build must not be able to ship 60x time compression")
    }

    func testValidBundleProducesNoIssues() {
        let iron = ItemDTO(id: "mat.iron", type: "material", tier: 2, stackable: true, icon: "🔩")
        let ingot = ItemDTO(id: "mat.iron_ingot", type: "material", tier: 3, stackable: true, icon: "🔳")
        let recipe = RecipeDTO(id: "recipe.iron_ingot", category: "forge",
                               inputs: [RecipeIngredientDTO(itemId: "mat.iron", quantity: 10)],
                               output: RecipeIngredientDTO(itemId: "mat.iron_ingot", quantity: 1))
        let report = ContentValidator.validate(bundle(items: [iron, ingot], recipes: [recipe]))
        XCTAssertTrue(report.issues.isEmpty, "unexpected: \(report.issues)")
    }
}

// MARK: - Enumerated values

extension ContentValidatorTests {

    func testUnknownEquipmentSlotIsAnError() {
        let gear = ItemDTO(id: "gear.boots", type: "gear", tier: 1, stackable: false, slot: "bootz")
        let report = ContentValidator.validate(bundle(items: [gear]))
        XCTAssertTrue(report.errors.contains { $0.rule == "enum.slot.unknown" })
    }

    func testUnknownItemTypeIsAnError() {
        let item = ItemDTO(id: "mat.hide", type: "materials", tier: 1, stackable: true)
        let report = ContentValidator.validate(bundle(items: [item]))
        XCTAssertTrue(report.errors.contains { $0.rule == "enum.item_type.unknown" })
    }

    func testUnknownRecipeCategoryIsAnError() {
        let recipe = RecipeDTO(id: "recipe.x", category: "smithy",
                               inputs: [RecipeIngredientDTO(itemId: "mat.hide", quantity: 1)],
                               output: RecipeIngredientDTO(itemId: "mat.hide", quantity: 1))
        let report = ContentValidator.validate(bundle(items: [hide()], recipes: [recipe]))
        XCTAssertTrue(report.errors.contains { $0.rule == "enum.recipe_category.unknown" })
    }

    func testIdPrefixDisagreeingWithTypeWarns() {
        let item = ItemDTO(id: "gear.hood", type: "food", tier: 1, stackable: true)
        let report = ContentValidator.validate(bundle(items: [item]))
        XCTAssertTrue(report.warnings.contains { $0.rule == "convention.id_prefix" })
    }

    func testMatPrefixMapsToMaterial() {
        let report = ContentValidator.validate(bundle(items: [hide()]))
        XCTAssertFalse(report.issues.contains { $0.rule == "convention.id_prefix" })
    }
}
