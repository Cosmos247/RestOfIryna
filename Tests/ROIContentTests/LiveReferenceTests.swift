//
//  LiveReferenceTests.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 30.08.2026.
//
//  Phase 7. `/reload` is safe because of one rule: a bundle may not be
//  installed while live rows still point at ids it does not contain. Every
//  other check asks whether a bundle is internally consistent; only this one
//  asks whether it is consistent with the game already in progress.
//
//  The matching is tested here rather than against a database because the
//  failure worth catching is a category error — checking item ids against the
//  bestiary would report every row as dangling, or none, and either way the
//  rule would look like it was working.
//

import XCTest
@testable import ROIContent

final class LiveReferenceTests: XCTestCase {

    private func bundle() -> ContentBundle {
        ContentBundle(
            manifest: ManifestDTO(schemaVersion: ContentSchema.current),
            items: [ItemDTO(id: "mat.iron", type: "material", tier: 1, stackable: true, icon: "🔩"),
                    ItemDTO(id: "food.potato", type: "food", tier: 1, stackable: true, icon: "🥔")],
            enemies: [EnemyDTO(id: "enemy.wild_boar", tier: 1, icon: "🐗", xpReward: 5,
                               stats: EnemyStatsDTO(hp: 18, attack: 14, defense: 1),
                               depth: IntRangeDTO(min: 1, max: 10),
                               level: 1, archetype: "trash")],
            recipes: [RecipeDTO(id: "recipe.iron_ingot", category: "workshop",
                                inputs: [RecipeIngredientDTO(itemId: "mat.iron", quantity: 3)],
                                output: RecipeIngredientDTO(itemId: "mat.iron", quantity: 1))],
            starterRecipeIds: [],
            plots: PlotFileDTO(types: [PlotTypeDTO(type: "farm", icon: "🌾", tuning: nil)]),
            contentHash: "test")
    }

    private func live(_ table: String, _ column: String,
                      _ kind: LiveReferenceCheck.Kind, _ ids: [String]) -> LiveReferenceCheck.LiveIds {
        LiveReferenceCheck.LiveIds(table: table, column: column, kind: kind, ids: ids)
    }

    // MARK: - The rule holds

    func testEverythingReferencedIsPresent() {
        let result = LiveReferenceCheck.dangling(in: bundle(), live: [
            live("inventory", "item_id", .item, ["mat.iron", "food.potato"]),
            live("exploration_state", "combat_enemy_id", .enemy, ["enemy.wild_boar"]),
            live("learned_recipes", "recipe_id", .recipe, ["recipe.iron_ingot"]),
            live("plots", "plot_type", .plotType, ["farm"])
        ])
        XCTAssertTrue(result.isEmpty, "clean bundle reported: \(result.map(\.description))")
    }

    /// The headline case: a material is deleted from the bundle while players
    /// are carrying it. Every one of those inventory rows becomes an item the
    /// game cannot name, price, equip or sell.
    func testDroppedItemStillHeldIsRefused() {
        let result = LiveReferenceCheck.dangling(in: bundle(), live: [
            live("inventory", "item_id", .item, ["mat.iron", "mat.deleted"])
        ])
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.id, "mat.deleted")
        XCTAssertEqual(result.first?.table, "inventory")
    }

    /// An enemy removed while somebody is mid-fight with it.
    func testDroppedEnemyInAnActiveFightIsRefused() {
        let result = LiveReferenceCheck.dangling(in: bundle(), live: [
            live("exploration_state", "combat_enemy_id", .enemy, ["enemy.gone"])
        ])
        XCTAssertEqual(result.first?.kind, .enemy)
    }

    /// A plot type is a database contract — the row cannot even be described
    /// without it.
    func testDroppedPlotTypeIsRefused() {
        let result = LiveReferenceCheck.dangling(in: bundle(), live: [
            live("plots", "plot_type", .plotType, ["farm", "vineyard"])
        ])
        XCTAssertEqual(result.map(\.id), ["vineyard"])
    }

    /// The category error the split exists to catch: an item id checked against
    /// the bestiary. Nothing about the data changed — only the `kind` — and a
    /// rule that got this wrong would look like it was working right up until
    /// it silently approved a destructive swap.
    func testMismatchedKindIsWhatThisTestExistsFor() {
        let correct = LiveReferenceCheck.dangling(in: bundle(), live: [
            live("inventory", "item_id", .item, ["mat.iron"])
        ])
        XCTAssertTrue(correct.isEmpty)

        let miscategorised = LiveReferenceCheck.dangling(in: bundle(), live: [
            live("inventory", "item_id", .enemy, ["mat.iron"])
        ])
        XCTAssertEqual(miscategorised.count, 1,
                       "an item id checked against the bestiary must not silently pass")
    }

    /// Duplicates in one column are one problem, not many — the report is what
    /// a developer reads at 2am.
    func testRepeatedDanglingIdIsReportedOnce() {
        let result = LiveReferenceCheck.dangling(in: bundle(), live: [
            live("inventory", "item_id", .item, ["mat.gone", "mat.gone", "mat.gone"])
        ])
        XCTAssertEqual(result.count, 1)
    }

    /// Same input, same output, every time: a reload refused twice must say the
    /// same thing twice.
    func testReportIsDeterministic() {
        let column = live("inventory", "item_id", .item, ["z.gone", "a.gone", "m.gone"])
        let first = LiveReferenceCheck.dangling(in: bundle(), live: [column])
        let second = LiveReferenceCheck.dangling(in: bundle(), live: [column])
        XCTAssertEqual(first, second)
        XCTAssertEqual(first.map(\.id), ["a.gone", "m.gone", "z.gone"])
    }

    /// The three columns the original design list missed. All three fail
    /// SILENTLY when their id vanishes — a Super that does nothing, a job that
    /// cannot be rendered, a paid-for buff that evaporates — which is exactly
    /// why they belong in a check that refuses the swap outright.
    func testSilentlyFailingReferencesAreCovered() {
        let withTuning = ContentBundle(
            manifest: ManifestDTO(schemaVersion: ContentSchema.current),
            items: [], enemies: [], recipes: [], starterRecipeIds: [],
            fortune: FortuneFileDTO(drawPrice: 10, buffDurationSeconds: 21600,
                                    cooldownSeconds: 3600,
                                    cards: [FortuneCardDTO(id: "0_fool", effect: FortuneEffectDTO())]),
            quests: QuestFileDTO(pools: []),
            contentHash: "test")
        let result = LiveReferenceCheck.dangling(in: withTuning, live: [
            live("exploration_state", "combat_stance", .stance, ["bloodlust"]),
            live("quest_progress", "quest_id", .quest, ["quest.trader.hides"]),
            live("users", "active_fortune_card_id", .fortuneCard, ["0_fool", "99_missing"])
        ])
        XCTAssertEqual(Set(result.map(\.id)), ["bloodlust", "quest.trader.hides", "99_missing"],
                       "a stance, quest or fortune card that no longer exists must be refused")
    }

    /// An empty column references nothing — nobody is in combat.
    func testEmptyColumnIsClean() {
        XCTAssertTrue(LiveReferenceCheck.dangling(in: bundle(), live: [
            live("exploration_state", "combat_enemy_id", .enemy, [])
        ]).isEmpty)
    }
}
