//
//  ContentDTOTests.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 29.08.2026.
//
//  Locks the DTO contract. These are the assertions the migration leans on:
//  omitted fields must fall back to their documented defaults, and the
//  domain → DTO → JSON → DTO → JSON round-trip must be byte-stable, because
//  that is how Phase 1 proves the JSON export is behaviour-neutral.
//

import XCTest
@testable import ROIContent

final class ContentDTOTests: XCTestCase {

    // MARK: - Defaults

    /// Swift does NOT apply a property's default value for a missing key in a
    /// synthesized decoder, which is why every DTO writes `init(from:)` by
    /// hand. This test fails loudly if someone deletes one of those.
    func testGearStatsOmittedFieldsDefaultToZero() throws {
        let json = Data(#"{"defense": 3}"#.utf8)
        let stats = try JSONDecoder().decode(GearStatsDTO.self, from: json)
        XCTAssertEqual(stats.defense, 3)
        XCTAssertEqual(stats.attack, 0)
        XCTAssertEqual(stats.crit, 0)
        XCTAssertEqual(stats.dodge, 0)
        XCTAssertEqual(stats.accuracy, 0)
    }

    func testItemDefaultsAndDerivedLocaleKeys() throws {
        let json = Data(#"{"id": "mat.hide", "type": "material"}"#.utf8)
        let item = try JSONDecoder().decode(ItemDTO.self, from: json)
        XCTAssertEqual(item.tier, 1)
        XCTAssertTrue(item.stackable)
        XCTAssertTrue(item.effects.isEmpty)
        XCTAssertEqual(item.nameKey, "item.mat.hide")
        XCTAssertEqual(item.descriptionKey, "item.mat.hide.desc")
    }

    /// Three shipped items (`potion.heal_small`, `potion.heal_medium`,
    /// `artifact.shrine_coin`) carry `descriptionKey: nil` in the domain. An
    /// explicit JSON null must survive the round-trip, or the export invents a
    /// key and the validator demands three locale strings that are absent on
    /// purpose.
    func testExplicitNullDescriptionKeySurvivesRoundTrip() throws {
        let json = Data(#"{"id": "potion.heal_small", "type": "potion", "descriptionKey": null}"#.utf8)
        let item = try JSONDecoder().decode(ItemDTO.self, from: json)
        XCTAssertTrue(item.suppressesDescription)
        XCTAssertNil(item.descriptionKey)

        let encoded = try ContentLoader.makeEncoder().encode(item)
        let again = try JSONDecoder().decode(ItemDTO.self, from: encoded)
        XCTAssertNil(again.descriptionKey)
        XCTAssertEqual(try ContentLoader.makeEncoder().encode(again), encoded)
    }

    /// An ABSENT key derives; only an explicit null suppresses.
    func testAbsentDescriptionKeyDerivesRatherThanSuppresses() throws {
        let json = Data(#"{"id": "mat.hide", "type": "material"}"#.utf8)
        let item = try JSONDecoder().decode(ItemDTO.self, from: json)
        XCTAssertFalse(item.suppressesDescription)
        XCTAssertEqual(item.descriptionKey, "item.mat.hide.desc")
    }

    func testExplicitLocaleKeyOverrideWins() throws {
        let json = Data(#"{"id": "mat.hide", "type": "material", "nameKey": "custom.key"}"#.utf8)
        let item = try JSONDecoder().decode(ItemDTO.self, from: json)
        XCTAssertEqual(item.nameKey, "custom.key")
        XCTAssertEqual(item.descriptionKey, "custom.key.desc")
    }

    // MARK: - Tagged union

    func testItemEffectTaggedUnionRoundTrips() throws {
        let json = Data(#"[{"kind":"restore_vigor","amount":16},{"kind":"restore_hp","amount":3}]"#.utf8)
        let effects = try JSONDecoder().decode([ItemEffectDTO].self, from: json)
        XCTAssertEqual(effects, [
            ItemEffectDTO(kind: .restoreVigor, amount: 16),
            ItemEffectDTO(kind: .restoreHP, amount: 3)
        ])
    }

    func testUnknownEffectKindFailsDecoding() {
        let json = Data(#"{"kind":"teleport","amount":1}"#.utf8)
        XCTAssertThrowsError(try JSONDecoder().decode(ItemEffectDTO.self, from: json))
    }

    // MARK: - Ranges

    /// `ClosedRange` traps when upperBound < lowerBound. The DTO must surface
    /// the inversion as data, never construct the range.
    func testInvertedRangeReportsRatherThanTraps() {
        XCTAssertNil(IntRangeDTO(min: 30, max: 21).closedRange)
        XCTAssertEqual(IntRangeDTO(min: 21, max: 30).closedRange, 21...30)
    }

    /// All 9 shipped enemies use their id as their locale key, verified against
    /// `EnemyCatalog`. The derivation must be the identity, not prefix surgery.
    func testEnemyNameKeyIsTheId() throws {
        let json = Data(#"{"id":"enemy.wild_boar","icon":"🐗","stats":{"hp":18,"attack":14,"defense":1}}"#.utf8)
        let enemy = try JSONDecoder().decode(EnemyDTO.self, from: json)
        XCTAssertEqual(enemy.nameKey, "enemy.wild_boar")
    }

    // MARK: - Canonical round-trip

    func testCanonicalEncodingIsStableAcrossRoundTrip() throws {
        let original = ItemFileDTO(items: [
            ItemDTO(id: "food.forest_berries", type: "food", tier: 1, stackable: true,
                    effects: [ItemEffectDTO(kind: .restoreVigor, amount: 4)], icon: "🫐"),
            ItemDTO(id: "gear.forester_jerkin", type: "gear", tier: 1, stackable: false,
                    slot: "chest", gearStats: GearStatsDTO(defense: 3), icon: "🦺"),
            ItemDTO(id: "enemy.free.artifact", type: "artifact", tier: 3, stackable: false,
                    teachesRecipe: "recipe.berry_tart")
        ])

        let encoder = ContentLoader.makeEncoder()
        let first = try encoder.encode(original)
        let decoded = try JSONDecoder().decode(ItemFileDTO.self, from: first)
        let second = try encoder.encode(decoded)

        XCTAssertEqual(first, second, "DTO mapping is lossy — the export/import equivalence proof depends on this")
    }

    func testEncoderOmitsZeroGearStats() throws {
        let encoded = try ContentLoader.makeEncoder().encode(GearStatsDTO(defense: 3))
        let text = String(decoding: encoded, as: UTF8.self)
        XCTAssertTrue(text.contains("defense"))
        XCTAssertFalse(text.contains("attack"), "zero stats must not be written — generated files have to diff cleanly")
    }
}
