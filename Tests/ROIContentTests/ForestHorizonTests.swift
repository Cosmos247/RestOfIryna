//
//  ForestHorizonTests.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 20.10.2026.
//
//  On 2026-10-12 a level-10 archer fled from the rabid bear at km 49 on 11 HP
//  and walked on to km 70: twenty steps of «Лише тиша» and a root. Nothing
//  lived past the deepest band, and the validator's gap walk stopped at the
//  level cap, so nothing said so. Since 2026-10-20 what is marked
//  `beyondHorizon` answers there — the rabid bear, the rabid pack and the deep
//  wood — and the pack's own band stays 36–40, so km 41–49 is still the bear's.
//
//  The rule is `ForestHorizon.covers`, the one the game's two catalogs ask.
//  Each validator rule is tested on the case that must FAIL it, not only on
//  the shipped content that passes.
//

import XCTest
@testable import ROIContent

final class ForestHorizonTests: XCTestCase {

    private static let contentRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("content/data")

    // MARK: - The rule

    func testTheHorizonIsTheDeepestBand() {
        XCTAssertEqual(ForestHorizon.km(of: [1...4, 39...49, 36...40]), 49)
        XCTAssertNil(ForestHorizon.km(of: []))
    }

    func testABandAnswersInsideItselfWhetherMarkedOrNot() {
        XCTAssertTrue(ForestHorizon.covers(39...49, beyondHorizon: false, km: 44, horizon: 49))
        XCTAssertTrue(ForestHorizon.covers(36...40, beyondHorizon: true, km: 36, horizon: 49))
    }

    /// The silence of 2026-10-12: an unmarked band answers nothing past the
    /// horizon, and a marked one answers every km of it, however far.
    func testPastTheHorizonOnlyTheMarkedAnswer() {
        XCTAssertFalse(ForestHorizon.covers(39...49, beyondHorizon: false, km: 50, horizon: 49))
        XCTAssertTrue(ForestHorizon.covers(39...49, beyondHorizon: true, km: 50, horizon: 49))
        XCTAssertTrue(ForestHorizon.covers(36...40, beyondHorizon: true, km: 500, horizon: 49))
    }

    /// The mark opens the forest PAST the horizon, not the gap between a band
    /// and it: the pack (36–40) stays out of km 41–49, where the bear walks
    /// alone, and out of the horizon's own km.
    func testTheMarkDoesNotFillTheStretchBeforeTheHorizon() {
        XCTAssertFalse(ForestHorizon.covers(36...40, beyondHorizon: true, km: 44, horizon: 49))
        XCTAssertFalse(ForestHorizon.covers(36...40, beyondHorizon: true, km: 49, horizon: 49))
    }

    func testWithoutAHorizonOnlyTheBandAnswers() {
        XCTAssertFalse(ForestHorizon.covers(1...4, beyondHorizon: true, km: 5, horizon: nil))
    }

    // MARK: - The shipped forest

    /// The owner's picture, read off `content/data` through the same rule the
    /// game asks: the bear alone at km 44, the bear and the pack at km 50 and
    /// at km 70, where the archer walked, and the deep wood foraged past 49.
    func testTheShippedForestPastTheHorizon() throws {
        let s = try ContentLoader.load(from: Self.contentRoot)
        let spawning = s.enemies.compactMap { e in e.depth?.closedRange.flatMap { $0 == 0...0 ? nil : (e, $0) } }
        let horizon = ForestHorizon.km(of: spawning.map(\.1))
        XCTAssertEqual(horizon, 49)

        func creatures(at km: Int) -> Set<String> {
            Set(spawning.filter {
                ForestHorizon.covers($0.1, beyondHorizon: $0.0.beyondHorizon, km: km, horizon: horizon)
            }.map(\.0.id))
        }
        XCTAssertEqual(creatures(at: 44), ["enemy.rabid_bear"])
        XCTAssertEqual(creatures(at: 50), ["enemy.rabid_bear", "enemy.rabid_pack"])
        XCTAssertEqual(creatures(at: 70), ["enemy.rabid_bear", "enemy.rabid_pack"])

        let zones = try XCTUnwrap(s.zones?.zones)
        func zone(at km: Int) -> String? {
            zones.first {
                ForestHorizon.covers($0.depth.closedRange ?? 0...0, beyondHorizon: $0.beyondHorizon,
                                     km: km, horizon: horizon)
            }?.id
        }
        XCTAssertEqual(zone(at: 49), "zone.deepwood")
        XCTAssertEqual(zone(at: 50), "zone.deepwood")
        XCTAssertEqual(zone(at: 70), "zone.deepwood")
    }

    // MARK: - The validator

    private func enemy(_ id: String, _ depth: ClosedRange<Int>, beyond: Bool = false) -> EnemyDTO {
        EnemyDTO(id: id, tier: 1, icon: "🐻", xpReward: 1,
                 stats: EnemyStatsDTO(hp: 10, attack: 1, defense: 1),
                 depth: IntRangeDTO(min: depth.lowerBound, max: depth.upperBound),
                 level: 1, archetype: "trash", beyondHorizon: beyond)
    }

    private func zone(_ id: String, _ depth: ClosedRange<Int>, beyond: Bool = false) -> ZoneDTO {
        ZoneDTO(id: id, depth: IntRangeDTO(min: depth.lowerBound, max: depth.upperBound),
                forage: [ForageEntryDTO(itemId: "mat.clay", weight: 10)], beyondHorizon: beyond)
    }

    private func report(enemies: [EnemyDTO], zones: [ZoneDTO]) -> ContentReport {
        ContentValidator.validate(ContentBundle(
            manifest: ManifestDTO(schemaVersion: ContentSchema.current),
            items: [ItemDTO(id: "mat.clay", type: "material", tier: 1, stackable: true)],
            enemies: enemies, enemyArchetypes: [],
            recipes: [], starterRecipeIds: [],
            zones: ZoneFileDTO(zones: zones),
            contentHash: "test"))
    }

    private func rules(_ issues: [ContentIssue]) -> Set<String> { Set(issues.map(\.rule)) }

    /// The forest as it shipped until 2026-10-20 — nobody marked — must warn on
    /// both tables, and the marked forest must not.
    func testAnUnmarkedForestWarnsOnBothTables() {
        let silent = report(enemies: [enemy("enemy.bear", 1...49)], zones: [zone("zone.deep", 1...49)])
        XCTAssertTrue(rules(silent.warnings).isSuperset(of: ["enemy.horizon_empty", "zone.horizon_empty"]),
                      "got \(rules(silent.warnings))")

        let marked = report(enemies: [enemy("enemy.bear", 1...49, beyond: true)],
                            zones: [zone("zone.deep", 1...49, beyond: true)])
        XCTAssertTrue(rules(marked.warnings).isDisjoint(with: ["enemy.horizon_empty", "zone.horizon_empty"]),
                      "got \(rules(marked.warnings))")
    }

    /// Two marked zones: only the first in the file is ever read past the
    /// horizon, so the second is marked for nothing.
    func testTwoMarkedZonesWarn() {
        let r = report(enemies: [enemy("enemy.bear", 1...49, beyond: true)],
                       zones: [zone("zone.a", 1...20, beyond: true), zone("zone.b", 21...49, beyond: true)])
        XCTAssertTrue(rules(r.warnings).contains("zone.horizon_ambiguous"), "got \(rules(r.warnings))")
    }

    /// A creature that never spawns, marked by mistake, would step out of the
    /// trees past the horizon — the training dummy at km 50. Refused, and it
    /// does not count as the forest's roamer either.
    func testAMarkedCreatureThatNeverSpawnsIsAnError() {
        let r = report(enemies: [enemy("enemy.bear", 1...49), enemy("enemy.dummy", 0...0, beyond: true)],
                       zones: [zone("zone.deep", 1...49, beyond: true)])
        XCTAssertTrue(rules(r.errors).contains("enemy.beyond_never_spawns"), "got \(rules(r.errors))")
        XCTAssertTrue(rules(r.warnings).contains("enemy.horizon_empty"), "got \(rules(r.warnings))")
    }
}
