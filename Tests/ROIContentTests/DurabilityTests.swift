//
//  DurabilityTests.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 05.10.2026.
//
//  Durability is the item's own since 2026-10-05 (`spec-items.md` §10): every
//  piece a fight wears declares a `maxDurability` — except a laddered weapon,
//  whose ladder owns it — and nothing else does. Each rule is shown failing on
//  a bundle built to trip it, beside the case that must stay clean, because a
//  rule nobody has seen fire is a rule nobody knows works. The bundles are the
//  shipped content plus one piece, so the ladders and the repair shave the
//  rules read are the real ones.
//

import XCTest
@testable import ROIContent

final class DurabilityTests: XCTestCase {

    private static let contentRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("content/data")

    /// The shipped bundle with `extra` appended and, optionally, one shipped
    /// item swapped for a copy.
    private func shipped(adding extra: [ItemDTO] = [], replacing swap: ItemDTO? = nil) throws -> ContentBundle {
        let s = try ContentLoader.load(from: Self.contentRoot)
        let items = s.items.map { item in swap.flatMap { $0.id == item.id ? $0 : nil } ?? item } + extra
        return ContentBundle(
            manifest: s.manifest, items: items, enemies: s.enemies, recipes: s.recipes,
            starterRecipeIds: s.starterRecipeIds, weaponLadders: s.weaponLadders,
            weaponDurabilityByTier: s.weaponDurabilityByTier,
            bags: s.bags, estateUpgrades: s.estateUpgrades, plots: s.plots,
            tuning: s.tuning, contentHash: "test")
    }

    private func piece(_ id: String, slot: String?, durability: Int?) -> ItemDTO {
        ItemDTO(id: id, type: "gear", tier: 1, stackable: false, slot: slot,
                gearStats: GearStatsDTO(defense: 1), maxDurability: durability)
    }

    private func durability(_ bundle: ContentBundle) -> [ContentIssue] {
        ContentValidator.validate(bundle).issues.filter { $0.rule.hasPrefix("durability.") }
    }

    private func assertOnly(_ rule: String, _ severity: ContentIssue.Severity, on id: String,
                            in bundle: ContentBundle, file: StaticString = #filePath, line: UInt = #line) {
        let issues = durability(bundle)
        XCTAssertEqual(issues.map(\.rule), [rule], "\(issues)", file: file, line: line)
        XCTAssertEqual(issues.first?.severity, severity, file: file, line: line)
        XCTAssertEqual(issues.first?.id, id, file: file, line: line)
    }

    // MARK: - The shipped content

    func testShippedContentIsClean() throws {
        XCTAssertEqual(durability(try shipped()).map(\.rule), [])
    }

    // MARK: - A piece that wears needs a number

    /// The defect this whole check exists for: an armour piece with nothing
    /// declared would be minted 0/0 — broken before its first fight.
    func testArmourWithoutDurabilityIsAnError() throws {
        let helm = piece("gear.test_helm", slot: "helmet", durability: nil)
        assertOnly("durability.missing", .error, on: helm.id, in: try shipped(adding: [helm]))
    }

    /// A weapon off the ladders wears like any other main-hand piece, so it
    /// needs a number of its own too.
    func testWeaponOffTheLaddersWithoutDurabilityIsAnError() throws {
        let axe = piece("gear.test_axe", slot: "main_hand", durability: nil)
        assertOnly("durability.missing", .error, on: axe.id, in: try shipped(adding: [axe]))
    }

    func testArmourWithDurabilityIsClean() throws {
        let helm = piece("gear.test_helm", slot: "helmet", durability: 40)
        XCTAssertEqual(durability(try shipped(adding: [helm])).map(\.rule), [])
    }

    func testZeroDurabilityIsAnError() throws {
        let helm = piece("gear.test_helm", slot: "helmet", durability: 0)
        assertOnly("durability.non_positive", .error, on: helm.id, in: try shipped(adding: [helm]))
    }

    // MARK: - The shave against the piece's own number

    /// The shipped shave is 1, so a 1-durability helmet would be destroyed by
    /// its first repair; 2 survives it.
    func testShaveThatDestroysArmourIsAnError() throws {
        let helm = piece("gear.test_helm", slot: "helmet", durability: 1)
        assertOnly("durability.shave_destroys_gear", .error, on: helm.id, in: try shipped(adding: [helm]))
        let sturdier = piece("gear.test_helm", slot: "helmet", durability: 2)
        XCTAssertEqual(durability(try shipped(adding: [sturdier])).map(\.rule), [])
    }

    /// The Master mends a weapon without shaving it, so the rule is armour's.
    func testAWeaponIsNeverShaved() throws {
        let axe = piece("gear.test_axe", slot: "main_hand", durability: 1)
        XCTAssertEqual(durability(try shipped(adding: [axe])).map(\.rule), [])
    }

    // MARK: - One source, and only where something reads it

    /// A laddered weapon's durability is `durabilityByTier`; a number on the
    /// item would be a second source that nothing reads.
    func testDurabilityOnALadderedWeaponIsAWarning() throws {
        let sword = ItemDTO(id: "gear.rusty_sword", type: "gear", tier: 1, stackable: false,
                            slot: "main_hand", gearStats: GearStatsDTO(attack: 7), maxDurability: 30)
        assertOnly("durability.on_ladder", .warning, on: sword.id, in: try shipped(replacing: sword))
    }

    func testDurabilityWhereNothingWearsIsAWarning() throws {
        let ring = piece("gear.test_ring", slot: "accessory_1", durability: 20)
        assertOnly("durability.not_worn", .warning, on: ring.id, in: try shipped(adding: [ring]))
        let ore = ItemDTO(id: "mat.test_ore", type: "material", tier: 1, stackable: true, maxDurability: 20)
        assertOnly("durability.not_worn", .warning, on: ore.id, in: try shipped(adding: [ore]))
    }

    // MARK: - The vocabulary both sides read

    /// `GearConditionService` builds its slot sets from these two properties
    /// and the validator asks the same ones, so they are pinned here.
    func testWhichSlotsWear() {
        XCTAssertEqual(EquipmentSlot.allCases.filter(\.isArmor), [.helmet, .chest, .legs, .boots])
        XCTAssertEqual(EquipmentSlot.allCases.filter(\.isDurable), [.helmet, .chest, .legs, .boots, .mainHand])
    }

    func testMaxDurabilityRoundTrips() throws {
        let json = #"{"id":"gear.x","type":"gear","stackable":false,"slot":"helmet","maxDurability":50}"#
        let item = try JSONDecoder().decode(ItemDTO.self, from: Data(json.utf8))
        XCTAssertEqual(item.maxDurability, 50)
        let again = try JSONDecoder().decode(ItemDTO.self, from: try JSONEncoder().encode(item))
        XCTAssertEqual(again, item)
        let bare = try JSONDecoder().decode(ItemDTO.self, from: Data(#"{"id":"mat.x","type":"material"}"#.utf8))
        XCTAssertNil(bare.maxDurability)
    }
}
