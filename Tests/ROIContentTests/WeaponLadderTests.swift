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

// MARK: - Bag / estate ladders

final class UpgradeLadderTests: XCTestCase {

    private func bundle(bags: BagFileDTO, estate: EstateUpgradeFileDTO = EstateUpgradeFileDTO(maxTier: 0, plotSlotsByTier: [], progression: [])) -> ContentBundle {
        ContentBundle(
            manifest: ManifestDTO(schemaVersion: ContentSchema.current),
            items: [ItemDTO(id: "mat.hide", type: "material", tier: 1, stackable: true)],
            enemies: [], recipes: [], starterRecipeIds: [],
            bags: bags, estateUpgrades: estate, contentHash: "test")
    }

    private func bagStep(_ tier: Int, cap: Int) -> BagUpgradeStepDTO {
        BagUpgradeStepDTO(toTier: tier, capacity: cap, requiredEstateLevel: tier,
                          inputs: [MaterialCostDTO(itemId: "mat.hide", quantity: 5)])
    }

    /// `nextStep` indexes `progression[toTier - 2]`, so a gap hands the player
    /// the wrong upgrade entirely.
    func testGapInTierSequenceIsAnError() {
        let bags = BagFileDTO(maxTier: 4, capacities: [25, 35, 45, 60],
                              progression: [bagStep(2, cap: 35), bagStep(4, cap: 60)])
        let report = ContentValidator.validate(bundle(bags: bags))
        XCTAssertTrue(report.errors.contains { $0.rule == "ladder.tiers_not_contiguous" })
    }

    /// Two sources for one number — the ladder step and the flat table read by
    /// `capForTier` — must agree.
    func testCapacityTableDisagreementIsAnError() {
        let bags = BagFileDTO(maxTier: 2, capacities: [25, 99],
                              progression: [bagStep(2, cap: 35)])
        let report = ContentValidator.validate(bundle(bags: bags))
        XCTAssertTrue(report.errors.contains { $0.rule == "ladder.capacity_disagrees" })
    }

    func testShrinkingCapacityIsAnError() {
        let bags = BagFileDTO(maxTier: 3, capacities: [25, 40, 30],
                              progression: [bagStep(2, cap: 40), bagStep(3, cap: 30)])
        let report = ContentValidator.validate(bundle(bags: bags))
        XCTAssertTrue(report.errors.contains { $0.rule == "ladder.capacity_regression" })
    }

    func testEstateGateGoingBackwardsIsAnError() {
        let estate = EstateUpgradeFileDTO(maxTier: 3, plotSlotsByTier: [0, 1, 2], progression: [
            EstateUpgradeStepDTO(toTier: 2, requiredPlayerLevel: 10),
            EstateUpgradeStepDTO(toTier: 3, requiredPlayerLevel: 4)
        ])
        let bags = BagFileDTO(maxTier: 0, capacities: [], progression: [])
        let report = ContentValidator.validate(bundle(bags: bags, estate: estate))
        XCTAssertTrue(report.errors.contains { $0.rule == "ladder.gate_regression" })
    }

    // MARK: - Plot slots by tier (Phase 8E)
    //
    // The ladder became content when Vigor stopped regenerating: these slots
    // are the player's whole daily budget now, so a table that is short, or
    // that goes backwards, is a balance change wearing a typo's clothes.

    func testShortSlotTableIsAnError() {
        let estate = EstateUpgradeFileDTO(maxTier: 3, plotSlotsByTier: [0, 1], progression: [
            EstateUpgradeStepDTO(toTier: 2, requiredPlayerLevel: 4),
            EstateUpgradeStepDTO(toTier: 3, requiredPlayerLevel: 7)
        ])
        let bags = BagFileDTO(maxTier: 0, capacities: [], progression: [])
        let report = ContentValidator.validate(bundle(bags: bags, estate: estate))
        XCTAssertTrue(report.errors.contains { $0.rule == "estate.slot_table_length" })
    }

    func testNegativeSlotCountIsAnError() {
        let estate = EstateUpgradeFileDTO(maxTier: 3, plotSlotsByTier: [0, -1, 2], progression: [
            EstateUpgradeStepDTO(toTier: 2, requiredPlayerLevel: 4),
            EstateUpgradeStepDTO(toTier: 3, requiredPlayerLevel: 7)
        ])
        let bags = BagFileDTO(maxTier: 0, capacities: [], progression: [])
        let report = ContentValidator.validate(bundle(bags: bags, estate: estate))
        XCTAssertTrue(report.errors.contains { $0.rule == "estate.slot_count_negative" })
    }

    /// An upgrade that takes plots away strands the ones already claimed:
    /// `Plot.list` keeps returning them while `claim` refuses to add more.
    func testSlotCountGoingBackwardsIsAnError() {
        let estate = EstateUpgradeFileDTO(maxTier: 3, plotSlotsByTier: [0, 2, 1], progression: [
            EstateUpgradeStepDTO(toTier: 2, requiredPlayerLevel: 4),
            EstateUpgradeStepDTO(toTier: 3, requiredPlayerLevel: 7)
        ])
        let bags = BagFileDTO(maxTier: 0, capacities: [], progression: [])
        let report = ContentValidator.validate(bundle(bags: bags, estate: estate))
        XCTAssertTrue(report.errors.contains { $0.rule == "estate.slot_count_regression" })
    }

    func testWellFormedLaddersAreClean() {
        let bags = BagFileDTO(maxTier: 3, capacities: [25, 35, 45],
                              progression: [bagStep(2, cap: 35), bagStep(3, cap: 45)])
        let estate = EstateUpgradeFileDTO(maxTier: 3, plotSlotsByTier: [0, 1, 2], progression: [
            EstateUpgradeStepDTO(toTier: 2, requiredPlayerLevel: 4,
                                 inputs: [MaterialCostDTO(itemId: "mat.hide", quantity: 3)]),
            EstateUpgradeStepDTO(toTier: 3, requiredPlayerLevel: 7, silverCost: 50)
        ])
        let report = ContentValidator.validate(bundle(bags: bags, estate: estate))
        XCTAssertTrue(report.issues.isEmpty, "unexpected: \(report.issues)")
    }
}
