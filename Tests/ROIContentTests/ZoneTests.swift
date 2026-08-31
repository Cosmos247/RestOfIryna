//
//  ZoneTests.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 31.08.2026.
//
//  Phase 8E moved the foraging pools out of `ExplorationService` and into
//  `zones.json`, which made them the last content to leave Swift — and made
//  them checkable. The rules here are the ones that would otherwise fail
//  silently: a pool nobody can roll, an item that does not exist, a band the
//  file forgot.
//
//  The migration's equivalence was proved separately, by replaying the shipped
//  arrays out of git against the new file for km 1–40 (identical, including
//  weight and ORDER — the roll walks the array, so order is behaviour).
//

import XCTest
@testable import ROIContent

final class ZoneTests: XCTestCase {

    private func item(_ id: String) -> ItemDTO {
        ItemDTO(id: id, type: "material", tier: 1, stackable: true)
    }

    private func zone(_ id: String, _ min: Int, _ max: Int,
                      _ forage: [(String, Int)]) -> ZoneDTO {
        ZoneDTO(id: id, depth: IntRangeDTO(min: min, max: max),
                forage: forage.map { ForageEntryDTO(itemId: $0.0, weight: $0.1) })
    }

    private func bundle(_ zones: [ZoneDTO], items: [ItemDTO]? = nil,
                        enemies: [EnemyDTO] = []) -> ContentBundle {
        ContentBundle(
            manifest: ManifestDTO(schemaVersion: ContentSchema.current),
            items: items ?? [item("mat.pine_lumber"), item("food.forest_berries")],
            enemies: enemies, enemyArchetypes: [],
            recipes: [], starterRecipeIds: [],
            zones: ZoneFileDTO(zones: zones),
            contentHash: "test")
    }

    private func assertRule(_ rule: String, _ bundle: ContentBundle,
                            severity: ContentIssue.Severity = .error,
                            file: StaticString = #filePath, line: UInt = #line) {
        let report = ContentValidator.validate(bundle)
        let matching = (severity == .error ? report.errors : report.warnings)
        XCTAssertTrue(matching.contains { $0.rule == rule },
                      "expected \"\(rule)\", got \(matching.map(\.rule))", file: file, line: line)
    }

    // MARK: - The fixture is clean

    func testWellFormedZonesProduceNoZoneErrors() {
        let report = ContentValidator.validate(
            bundle([zone("zone.thicket", 1, 5, [("mat.pine_lumber", 10), ("food.forest_berries", 4)])]))
        let zoneErrors = report.errors.filter { $0.rule.hasPrefix("zone.") }
        XCTAssertTrue(zoneErrors.isEmpty, "clean zones produced: \(zoneErrors.map(\.rule))")
    }

    // MARK: - Pools

    func testUnknownForageItemIsAnError() {
        assertRule("zone.unknown_item",
                   bundle([zone("zone.thicket", 1, 5, [("mat.unobtanium", 10)])]))
    }

    /// A zero weight is not "rare", it is unreachable — the roll subtracts
    /// weights and can never land on it. Content nobody will ever see.
    func testZeroWeightIsAnError() {
        assertRule("zone.weight_range",
                   bundle([zone("zone.thicket", 1, 5, [("mat.pine_lumber", 10),
                                                       ("food.forest_berries", 0)])]))
    }

    func testEmptyPoolIsAnError() {
        assertRule("zone.pool_empty", bundle([zone("zone.thicket", 1, 5, [])]))
    }

    func testDuplicateForageEntryIsAnError() {
        assertRule("identity.duplicate_id",
                   bundle([zone("zone.thicket", 1, 5, [("mat.pine_lumber", 10),
                                                       ("mat.pine_lumber", 5)])]))
    }

    func testDuplicateZoneIdIsAnError() {
        assertRule("identity.duplicate_id",
                   bundle([zone("zone.a", 1, 2, [("mat.pine_lumber", 10)]),
                           zone("zone.a", 3, 4, [("mat.pine_lumber", 10)])]))
    }

    // MARK: - Depth

    func testInvertedDepthIsAnError() {
        assertRule("zone.depth_inverted",
                   bundle([zone("zone.thicket", 9, 2, [("mat.pine_lumber", 10)])]))
    }

    func testDepthStartingBelowKmOneIsAnError() {
        assertRule("zone.depth_range",
                   bundle([zone("zone.thicket", 0, 5, [("mat.pine_lumber", 10)])]))
    }

    /// The gap is a WARNING, not an error: the roll honestly returns nothing
    /// there, which is a content hole rather than a broken file. It is walked
    /// to the deepest km an enemy can spawn at, because the two tables describe
    /// the same wilderness.
    func testAGapBelowTheEnemyHorizonWarns() {
        let deepEnemy = EnemyDTO(id: "enemy.x", tier: 1, icon: "🐗", xpReward: 1,
                                 stats: EnemyStatsDTO(hp: 10, attack: 1, defense: 1),
                                 depth: IntRangeDTO(min: 1, max: 12), level: 1,
                                 archetype: "trash")
        assertRule("zone.depth_gap",
                   bundle([zone("zone.thicket", 1, 5, [("mat.pine_lumber", 10)])],
                          enemies: [deepEnemy]),
                   severity: .warning)
    }

    func testFullCoverageDoesNotWarn() {
        let enemy = EnemyDTO(id: "enemy.x", tier: 1, icon: "🐗", xpReward: 1,
                             stats: EnemyStatsDTO(hp: 10, attack: 1, defense: 1),
                             depth: IntRangeDTO(min: 1, max: 6), level: 1, archetype: "trash")
        let report = ContentValidator.validate(
            bundle([zone("zone.thicket", 1, 3, [("mat.pine_lumber", 10)]),
                    zone("zone.deepwood", 4, 6, [("mat.pine_lumber", 10)])],
                   enemies: [enemy]))
        XCTAssertFalse(report.warnings.contains { $0.rule == "zone.depth_gap" })
    }
}
