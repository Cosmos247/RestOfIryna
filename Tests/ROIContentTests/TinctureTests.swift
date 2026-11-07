//
//  TinctureTests.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 07.11.2026.
//
//  The fortune teller's tinctures (`content/spec/spec-tinctures.md`, the owner's
//  picks of 2026-11-07): five recipes of plants and a trophy, her fee, a share of
//  the drinker's own pool or a ward on the bag.
//
//  Pinned here: the owner's numbers on the shipped bundle; the share's rounding;
//  the rules that keep a tincture a tincture, each shown failing on a copy of the
//  bundle broken on purpose (written to a temporary directory and read back
//  through the real loader); and the copy: both locales name all four, and the
//  word the owner retired stays gone.
//
//  What this suite cannot reach: the brew, the drink and the wipe live in the bot
//  target, which needs Fluent. `TODO.md` → the walk block carries them.
//

import XCTest
@testable import ROIContent
import ROISim

final class TinctureTests: XCTestCase {

    private static let repoRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    private static let contentRoot = repoRoot.appendingPathComponent("content/data")
    private static let localeRoot = repoRoot.appendingPathComponent("Localizations")

    private func shipped() throws -> ContentBundle {
        try ContentLoader.load(from: Self.contentRoot)
    }

    private func tinctures(_ bundle: ContentBundle) -> [RecipeDTO] {
        bundle.recipes.filter { $0.category == "tincture" }
    }

    /// The shipped content copied to a temporary directory, its items and
    /// recipes edited as JSON, and loaded back: the real loader, every other
    /// field as shipped.
    private func broken(items: (inout [[String: Any]]) -> Void = { _ in },
                        recipes: (inout [[String: Any]]) -> Void = { _ in }) throws -> ContentBundle {
        let fm = FileManager.default
        let dir = fm.temporaryDirectory.appendingPathComponent("TinctureTests-\(UUID().uuidString)")
        try fm.copyItem(at: Self.contentRoot, to: dir)
        addTeardownBlock { try? fm.removeItem(at: dir) }
        func edit(_ file: String, _ key: String, _ change: (inout [[String: Any]]) -> Void) throws {
            let url = dir.appendingPathComponent(file)
            var object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
            var rows = try XCTUnwrap(object[key] as? [[String: Any]])
            change(&rows)
            object[key] = rows
            try JSONSerialization.data(withJSONObject: object).write(to: url)
        }
        try edit("items.json", "items", items)
        try edit("recipes.json", "recipes", recipes)
        return try ContentLoader.load(from: dir)
    }

    private func rules(_ bundle: ContentBundle) -> [String] {
        ContentValidator.validate(bundle, localizations: nil).issues.map(\.rule)
    }

    // MARK: - The owner's numbers

    func testTheShippedListIsTheOwnersFourInHerOrder() throws {
        let list = tinctures(try shipped())
        XCTAssertEqual(list.map(\.output.itemId), ["potion.heal_small", "potion.heal_medium", "potion.thyme",
                                                   "potion.thyme_strong", "potion.sleep"])
        XCTAssertEqual(list.map(\.silverFee), [10, 30, 15, 30, 40])
    }

    func testTheRecipesAreTheOwners() throws {
        func inputs(_ id: String) throws -> [String] {
            let recipe = try XCTUnwrap(try shipped().recipes.first { $0.id == id })
            return recipe.inputs.map { "\($0.quantity)×\($0.itemId)" }
        }
        XCTAssertEqual(try inputs("recipe.tincture_small"), ["1×mat.herb_st_johns_wort", "1×mat.trophy_venom"])
        XCTAssertEqual(try inputs("recipe.tincture_medium"), ["2×mat.herb_st_johns_wort", "1×mat.trophy_venom"])
        XCTAssertEqual(try inputs("recipe.tincture_thyme"), ["2×mat.herb_thyme", "1×mat.trophy_fang"])
        XCTAssertEqual(try inputs("recipe.tincture_thyme_strong"),
                       ["3×mat.herb_thyme", "1×mat.herb_wormwood", "1×mat.trophy_feather"])
        XCTAssertEqual(try inputs("recipe.tincture_sleep"), ["1×mat.herb_pasque_flower", "1×mat.trophy_horn"])
    }

    /// «зробити їх більш схожими по рецепту, на середню просто треба більше».
    func testTheMediumHealIsTheSmallOneWithMoreOfTheSameThings() throws {
        let list = tinctures(try shipped())
        let small = try XCTUnwrap(list.first { $0.output.itemId == "potion.heal_small" })
        let medium = try XCTUnwrap(list.first { $0.output.itemId == "potion.heal_medium" })
        XCTAssertEqual(small.inputs.map(\.itemId), medium.inputs.map(\.itemId))
        XCTAssertGreaterThan(medium.inputs.map(\.quantity).reduce(0, +), small.inputs.map(\.quantity).reduce(0, +))
    }

    func testTheEffectsAreTheOwners() throws {
        let items = Dictionary(uniqueKeysWithValues: try shipped().items.map { ($0.id, $0) })
        XCTAssertEqual(items["potion.heal_small"]?.effects, [ItemEffectDTO(kind: .restoreHPPercent, amount: 25)])
        XCTAssertEqual(items["potion.heal_medium"]?.effects, [ItemEffectDTO(kind: .restoreHPPercent, amount: 50)])
        XCTAssertEqual(items["potion.thyme"]?.effects, [ItemEffectDTO(kind: .restoreVigorPercent, amount: 30)])
        XCTAssertEqual(items["potion.thyme_strong"]?.effects,
                       [ItemEffectDTO(kind: .restoreVigorPercent, amount: 30),
                        ItemEffectDTO(kind: .vigorThrift, amount: 50, seconds: 3600)])
        XCTAssertEqual(items["potion.sleep"]?.effects.map(\.kind), [.sleepWard])
    }

    func testEveryTinctureIsAStackablePotionAndTheTraderListsNone() throws {
        let bundle = try shipped()
        let ids = Set(tinctures(bundle).map(\.output.itemId))
        for item in bundle.items where ids.contains(item.id) {
            XCTAssertEqual(item.type, "potion", item.id)
            XCTAssertTrue(item.stackable, item.id)
        }
        let listed = Set(try XCTUnwrap(bundle.trader).listings.map(\.itemId))
        XCTAssertTrue(listed.isDisjoint(with: ids))
    }

    /// The owner, 2026-11-07: «🧪🌸» — the category's 🧪, then the plant it is
    /// brewed from, so four bottles can be told apart at a glance.
    func testATincturesIconIsTheFlaskAndItsPlant() throws {
        let bundle = try shipped()
        let items = Dictionary(uniqueKeysWithValues: bundle.items.map { ($0.id, $0) })
        for recipe in tinctures(bundle) {
            let plant = try XCTUnwrap(items[try XCTUnwrap(recipe.inputs.first?.itemId)])
            XCTAssertTrue(plant.id.hasPrefix("mat.herb_"), "the plant leads the recipe: \(recipe.id)")
            XCTAssertEqual(items[recipe.output.itemId]?.icon, "🧪" + (plant.icon ?? ""), recipe.id)
        }
    }

    func testTheShippedBundleRaisesNoTinctureRule() throws {
        XCTAssertTrue(rules(try shipped()).filter { $0.hasPrefix("tincture.") }.isEmpty)
    }

    // MARK: - The share

    func testAShareIsThePercentOfThePoolRoundedHalfUp() {
        XCTAssertEqual(MealMath.share(percent: 25, of: 164), 41)
        XCTAssertEqual(MealMath.share(percent: 50, of: 164), 82)
        XCTAssertEqual(MealMath.share(percent: 50, of: 165), 83, "82.5 rounds up")
        XCTAssertEqual(MealMath.share(percent: 30, of: 125), 38, "37.5 rounds up")
        XCTAssertEqual(MealMath.share(percent: 30, of: 150), 45)
    }

    func testAShareIsNeverLessThanAPointAndNothingOfNothing() {
        XCTAssertEqual(MealMath.share(percent: 1, of: 10), 1)
        XCTAssertEqual(MealMath.share(percent: 25, of: 0), 0)
        XCTAssertEqual(MealMath.share(percent: 0, of: 100), 0)
    }

    // MARK: - The thrift

    /// The table the owner was shown: only half moves a step and a blow.
    func testHalfOffEveryCostTheGameCharges() {
        XCTAssertEqual(MealMath.thriftedCost(2, percent: 50), 1, "a step, a blow")
        XCTAssertEqual(MealMath.thriftedCost(1, percent: 50), 1, "a Defend")
        XCTAssertEqual(MealMath.thriftedCost(3, percent: 50), 2, "a flee")
        XCTAssertEqual(MealMath.thriftedCost(4, percent: 50), 2)
        XCTAssertEqual(MealMath.thriftedCost(5, percent: 50), 3)
    }

    /// The Chariot's ×0.5 reaches here as 0.5 on a Defend. It must not go free.
    func testACostNeverRoundsToNothingAndNothingStaysNothing() {
        XCTAssertEqual(MealMath.thriftedCost(0.5, percent: 50), 1)
        XCTAssertEqual(MealMath.thriftedCost(1, percent: 50), 1, "the Chariot's step adds nothing further")
        XCTAssertEqual(MealMath.thriftedCost(0, percent: 50), 0, "a free action stays free")
    }

    // MARK: - The rules, each shown failing

    func testATinctureWithNoFeeIsRefused() throws {
        let bundle = try broken(recipes: { rows in
            let index = rows.firstIndex { $0["id"] as? String == "recipe.tincture_thyme" }!
            rows[index].removeValue(forKey: "silverFee")
        })
        XCTAssertTrue(rules(bundle).contains("tincture.fee_missing"))
    }

    func testAFeeOnAnEstateRecipeIsANumberNothingReads() throws {
        let bundle = try broken(recipes: { rows in
            let index = rows.firstIndex { $0["id"] as? String == "recipe.baked_potato" }!
            rows[index]["silverFee"] = 5
        })
        XCTAssertTrue(rules(bundle).contains("tincture.fee_unread"))
    }

    func testATinctureThatBrewsAFoodIsRefused() throws {
        let bundle = try broken(recipes: { rows in
            let index = rows.firstIndex { $0["id"] as? String == "recipe.tincture_thyme" }!
            rows[index]["output"] = ["itemId": "food.baked_potato", "quantity": 1]
        })
        XCTAssertTrue(rules(bundle).contains("tincture.output_not_a_tincture"))
    }

    func testAShareOnAFoodIsRefused() throws {
        let bundle = try broken(items: { rows in
            let index = rows.firstIndex { $0["id"] as? String == "food.baked_potato" }!
            rows[index]["effects"] = [["amount": 30, "kind": "restore_vigor_percent"]]
        })
        XCTAssertTrue(rules(bundle).contains("tincture.effect_off_a_tincture"))
    }

    func testAWardOnAFoodIsRefused() throws {
        let bundle = try broken(items: { rows in
            let index = rows.firstIndex { $0["id"] as? String == "food.baked_potato" }!
            rows[index]["effects"] = [["amount": 1, "kind": "sleep_ward"]]
        })
        XCTAssertTrue(rules(bundle).contains("tincture.effect_off_a_tincture"))
    }

    func testAShareAboveTheWholePoolIsRefused() throws {
        let bundle = try broken(items: { rows in
            let index = rows.firstIndex { $0["id"] as? String == "potion.heal_small" }!
            rows[index]["effects"] = [["amount": 125, "kind": "restore_hp_percent"]]
        })
        XCTAssertTrue(rules(bundle).contains("tincture.percent_range"))
    }

    func testAThriftThatRoundsAStepBackIsRefused() throws {
        let bundle = try broken(items: { rows in
            let index = rows.firstIndex { $0["id"] as? String == "potion.thyme_strong" }!
            rows[index]["effects"] = [["amount": 25, "kind": "vigor_thrift", "seconds": 3600]]
        })
        XCTAssertTrue(rules(bundle).contains("tincture.thrift_moves_nothing"))
    }

    func testAThriftWithNoDurationIsRefused() throws {
        let bundle = try broken(items: { rows in
            let index = rows.firstIndex { $0["id"] as? String == "potion.thyme_strong" }!
            rows[index]["effects"] = [["amount": 50, "kind": "vigor_thrift"]]
        })
        XCTAssertTrue(rules(bundle).contains("tincture.thrift_no_duration"))
    }

    func testAThriftOnAFoodIsRefused() throws {
        let bundle = try broken(items: { rows in
            let index = rows.firstIndex { $0["id"] as? String == "food.baked_potato" }!
            rows[index]["effects"] = [["amount": 50, "kind": "vigor_thrift", "seconds": 3600]]
        })
        XCTAssertTrue(rules(bundle).contains("tincture.effect_off_a_tincture"))
    }

    // MARK: - The copy

    private func locale(_ name: String) throws -> [String: String] {
        let url = Self.localeRoot.appendingPathComponent("\(name).json")
        return try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: String])
    }

    func testBothLocalesNameAndDescribeEveryTincture() throws {
        let uk = try locale("uk"), en = try locale("en")
        for recipe in tinctures(try shipped()) {
            let key = "item.\(recipe.output.itemId)"
            for table in [uk, en] {
                XCTAssertNotNil(table[key], key)
                XCTAssertNotNil(table["\(key).desc"], "\(key).desc")
            }
            XCTAssertEqual(uk["\(key).gender"], "f", "«настоянка» is feminine: \(key)")
        }
    }

    /// «В грі це називаються "настоянки"» (2026-11-07). Can fail: this exact sweep
    /// found three values in `uk.json` the day it was written.
    func testTheWordTheOwnerRetiredStaysGone() throws {
        for (key, value) in try locale("uk") {
            XCTAssertFalse(value.lowercased().contains("зілл"), key)
        }
    }

    func testThePlaceNamesTheTincturesWhereTheCopyMentionsHer() throws {
        let uk = try locale("uk")
        XCTAssertTrue(try XCTUnwrap(uk["capital.street.lower.body"]).contains("настоянк"))
        XCTAssertTrue(try XCTUnwrap(uk["capital.fortune.intro.m"]).contains("настоянки"))
        XCTAssertTrue(try XCTUnwrap(uk["capital.fortune.intro.f"]).contains("настоянки"))
        XCTAssertNil(uk["tincture.cold"], "the cold cauldron was an announcement, and recipes exist")
    }

    func testThymesCardNoLongerPromisesWhatTheTinctureDoesNotDo() throws {
        XCTAssertFalse(try XCTUnwrap(try locale("uk")["item.mat.herb_thyme.desc"]).contains("захист"))
    }
}
