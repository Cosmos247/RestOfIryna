//
//  WeaponLadderTests.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 29.08.2026.
//
//  The ladder rules exist because the shipped `WeaponUpgradeCatalog.progression`
//  encodes tier as nothing but array position. Writing the tier down is what
//  turns a silently-shifted ladder into a caught error.
//

import XCTest
@testable import ROIContent

final class WeaponLadderTests: XCTestCase {

    private func sword(_ tiers: [WeaponUpgradeStepDTO]) -> ContentBundle {
        let item = ItemDTO(id: "gear.rusty_sword", type: "gear", tier: 1, stackable: false,
                           slot: "main_hand", gearStats: GearStatsDTO(attack: 3))
        let pebble = ItemDTO(id: "mat.river_pebble", type: "material", tier: 1, stackable: true)
        return ContentBundle(
            manifest: ManifestDTO(schemaVersion: ContentSchema.current),
            items: [item, pebble], enemies: [], recipes: [], starterRecipeIds: [],
            weaponLadders: [WeaponLadderDTO(itemId: "gear.rusty_sword", tiers: tiers)],
            weaponDurabilityByTier: [30, 40, 50, 70, 100],
            contentHash: "test"
        )
    }

    private func step(_ tier: Int, attack: Int, crit: Int = 0, inputs: [WeaponUpgradeInputDTO] = []) -> WeaponUpgradeStepDTO {
        WeaponUpgradeStepDTO(tier: tier, stats: GearStatsDTO(attack: attack, crit: crit), inputs: inputs)
    }

    func testWellFormedLadderIsClean() {
        let bundle = sword([
            step(1, attack: 3),
            step(2, attack: 5, crit: 3, inputs: [WeaponUpgradeInputDTO(itemId: "mat.river_pebble", quantity: 3)])
        ])
        let report = ContentValidator.validate(bundle)
        XCTAssertTrue(report.issues.isEmpty, "unexpected: \(report.issues)")
    }

    /// The whole reason `tier` is a written field rather than an array index.
    func testTierOutOfOrderIsAnError() {
        let bundle = sword([step(1, attack: 3), step(3, attack: 5)])
        let report = ContentValidator.validate(bundle)
        XCTAssertTrue(report.errors.contains { $0.rule == "ladder.tier_out_of_order" })
    }

    /// Spending materials to get a weaker weapon is always a data slip.
    func testStatRegressionAcrossTiersIsAnError() {
        let bundle = sword([step(1, attack: 8), step(2, attack: 5)])
        let report = ContentValidator.validate(bundle)
        XCTAssertTrue(report.errors.contains { $0.rule == "ladder.stat_regression" })
    }

    func testLadderOnNonWeaponIsAnError() {
        let boots = ItemDTO(id: "gear.boots", type: "gear", tier: 1, stackable: false, slot: "boots")
        let bundle = ContentBundle(
            manifest: ManifestDTO(schemaVersion: ContentSchema.current),
            items: [boots], enemies: [], recipes: [], starterRecipeIds: [],
            weaponLadders: [WeaponLadderDTO(itemId: "gear.boots", tiers: [step(1, attack: 1)])],
            weaponDurabilityByTier: [30], contentHash: "test")
        let report = ContentValidator.validate(bundle)
        XCTAssertTrue(report.errors.contains { $0.rule == "ladder.not_a_weapon" })
    }

    func testDurabilityTableShorterThanLadderIsAnError() {
        let item = ItemDTO(id: "gear.rusty_sword", type: "gear", tier: 1, stackable: false, slot: "main_hand")
        let bundle = ContentBundle(
            manifest: ManifestDTO(schemaVersion: ContentSchema.current),
            items: [item], enemies: [], recipes: [], starterRecipeIds: [],
            weaponLadders: [WeaponLadderDTO(itemId: "gear.rusty_sword",
                                            tiers: [step(1, attack: 1), step(2, attack: 2), step(3, attack: 3)])],
            weaponDurabilityByTier: [30, 40], contentHash: "test")
        let report = ContentValidator.validate(bundle)
        XCTAssertTrue(report.errors.contains { $0.rule == "ladder.durability_short" })
    }

    // MARK: - Tier-aware localization

    /// `ItemDisplay` appends `.t<tier>` for anything with a ladder, so the base
    /// `.desc` key is never resolved. All three shipped weapons legitimately
    /// lack it — demanding it produced six false warnings on the real bundle.
    func testTieredItemNeedsPerTierKeysAndNotABaseDescription() {
        let locales = LocaleIndex(tables: [
            "en": [
                "item.gear.rusty_sword": "Rusty Sword",
                "item.gear.rusty_sword.t1": "Rusty Sword",
                "item.gear.rusty_sword.t2": "Cleaned Sword",
                "item.gear.rusty_sword.desc.t1": "A corroded blade.",
                "item.gear.rusty_sword.desc.t2": "The steel returns.",
                "item.mat.river_pebble": "River Pebble",
                "item.mat.river_pebble.desc": "A smooth stone."
            ],
            "uk": [
                "item.gear.rusty_sword": "Іржавий меч",
                "item.gear.rusty_sword.t1": "Іржавий меч",
                "item.gear.rusty_sword.t2": "Очищений меч",
                "item.gear.rusty_sword.desc.t1": "Роз'їдене лезо.",
                "item.gear.rusty_sword.desc.t2": "Сталь повертається.",
                "item.mat.river_pebble": "Річкова галька",
                "item.mat.river_pebble.desc": "Гладкий камінь."
            ]
        ])
        let bundle = sword([step(1, attack: 3), step(2, attack: 5)])
        let report = ContentValidator.validate(bundle, localizations: locales)
        XCTAssertTrue(report.issues.isEmpty, "unexpected: \(report.issues)")
    }

    func testTieredItemMissingATierKeyIsAnError() {
        let locales = LocaleIndex(tables: [
            "en": ["item.gear.rusty_sword": "Rusty Sword", "item.gear.rusty_sword.t1": "Rusty Sword",
                   "item.mat.river_pebble": "River Pebble", "item.mat.river_pebble.desc": "x"],
            "uk": ["item.gear.rusty_sword": "Іржавий меч", "item.gear.rusty_sword.t1": "Іржавий меч",
                   "item.mat.river_pebble": "Річкова галька", "item.mat.river_pebble.desc": "x"]
        ])
        let bundle = sword([step(1, attack: 3), step(2, attack: 5)])
        let report = ContentValidator.validate(bundle, localizations: locales)
        XCTAssertTrue(report.errors.contains {
            $0.rule == "locale.key.missing" && $0.message.contains("item.gear.rusty_sword.t2")
        })
    }

    // MARK: - DTO shape

    func testStepInputsDefaultToEmpty() throws {
        let json = Data(#"{"tier":1,"stats":{"attack":3}}"#.utf8)
        let step = try JSONDecoder().decode(WeaponUpgradeStepDTO.self, from: json)
        XCTAssertTrue(step.inputs.isEmpty)
        XCTAssertEqual(step.stats.attack, 3)
    }
}
