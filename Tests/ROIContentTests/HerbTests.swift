//
//  HerbTests.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 05.11.2026.
//
//  A plant in the grass (`spec-bestiary.md` §16, the owner's picks of
//  2026-11-05): a sixth step event, 3 steps of 100 in every weight row, taken
//  from `nothing` so the trail's materials, food and fights are untouched; one
//  pool for the whole forest — thyme, St John's wort, wormwood and pasque
//  flower at 4 : 3 : 2 : 1, most common first.
//
//  Pinned here: the owner's numbers on the shipped bundle; the rules that keep
//  the weight in `tuning/exploration.json` and the pool in `zones.json`
//  together, each shown failing on a copy of the bundle broken on purpose
//  (written to a temporary directory and read back through the real loader);
//  the lines the step and the 🏕 report print; and the decoding that keeps a
//  row written before the event readable.
//

import XCTest
@testable import ROIContent

final class HerbTests: XCTestCase {

    private static let repoRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    private static let contentRoot = repoRoot.appendingPathComponent("content/data")
    private static let localeRoot = repoRoot.appendingPathComponent("Localizations")

    private func shipped() throws -> ContentBundle {
        try ContentLoader.load(from: Self.contentRoot)
    }

    /// The shipped content copied to a temporary directory, its exploration
    /// tuning and zones file edited as JSON, and loaded back — the real loader,
    /// every other field as shipped.
    private func broken(exploration: (inout [String: Any]) -> Void = { _ in },
                        zones: (inout [String: Any]) -> Void = { _ in }) throws -> ContentBundle {
        let fm = FileManager.default
        let dir = fm.temporaryDirectory.appendingPathComponent("HerbTests-\(UUID().uuidString)")
        try fm.copyItem(at: Self.contentRoot, to: dir)
        addTeardownBlock { try? fm.removeItem(at: dir) }
        func edit(_ relative: String, _ change: (inout [String: Any]) -> Void) throws {
            let url = dir.appendingPathComponent(relative)
            var object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
            change(&object)
            try JSONSerialization.data(withJSONObject: object).write(to: url)
        }
        try edit("tuning/exploration.json", exploration)
        try edit("zones.json", zones)
        return try ContentLoader.load(from: dir)
    }

    private func rules(_ bundle: ContentBundle, locales: LocaleIndex? = nil) -> [ContentIssue] {
        ContentValidator.validate(bundle, localizations: locales).issues
    }

    // MARK: - The owner's numbers

    func testTheShippedPoolIsTheOwnersFourAtFourThreeTwoOne() throws {
        let herbs = try XCTUnwrap(try shipped().zones).herbs
        XCTAssertEqual(herbs.map(\.itemId), ["mat.herb_thyme", "mat.herb_st_johns_wort",
                                             "mat.herb_wormwood", "mat.herb_pasque_flower"])
        XCTAssertEqual(herbs.map(\.weight), [4, 3, 2, 1])
    }

    func testEveryWeightRowRollsAPlantThreeStepsInAHundred() throws {
        let exploration = try XCTUnwrap(try shipped().tuning).exploration
        XCTAssertEqual(exploration.eventWeightTotal, 100)
        XCTAssertEqual(exploration.weightTiers.map(\.herb), [3, 3, 3])
        XCTAssertEqual(exploration.passive.weights.herb, 3)
    }

    /// Every plant a stackable material, named in both locales — the item rules
    /// already ask for the name, the description and the uk gender.
    func testTheShippedPlantsAreCleanInBothLocales() throws {
        let bundle = try shipped()
        let ids = Set(try XCTUnwrap(bundle.zones).herbs.map(\.itemId))
        for item in bundle.items where ids.contains(item.id) {
            XCTAssertEqual(item.type, "material", item.id)
            XCTAssertTrue(item.stackable, item.id)
        }
        let locales = try LocaleIndex(rootPath: Self.localeRoot.path)
        let herbIssues = rules(bundle, locales: locales).filter {
            $0.rule.hasPrefix("zone.herb") || $0.message.contains("herb")
        }
        XCTAssertEqual(herbIssues.map(\.message), [])
    }

    // MARK: - Each rule can fail

    func testAWeightWithAnEmptyPoolFails() throws {
        let issues = rules(try broken(zones: { $0["herbs"] = [] as [Any] }))
        XCTAssertTrue(issues.contains { $0.rule == "zone.herb_pool_empty" && $0.severity == .error },
                      "\(issues.map(\.rule))")
    }

    func testAPoolNoRowCanReachWarns() throws {
        let issues = rules(try broken(exploration: { exploration in
            func zeroed(_ row: [String: Any]) -> [String: Any] {
                var row = row
                row["nothing"] = (row["nothing"] as? Int ?? 0) + (row["herb"] as? Int ?? 0)
                row["herb"] = 0
                return row
            }
            exploration["weightTiers"] = (exploration["weightTiers"] as? [[String: Any]] ?? []).map(zeroed)
            var passive = exploration["passive"] as? [String: Any] ?? [:]
            passive["weights"] = zeroed(passive["weights"] as? [String: Any] ?? [:])
            exploration["passive"] = passive
        }))
        XCTAssertTrue(issues.contains { $0.rule == "zone.herb_unreachable" && $0.severity == .warning },
                      "\(issues.map(\.rule))")
        XCTAssertFalse(issues.contains { $0.rule == "tuning.exploration.weights_dont_sum" })
    }

    func testAWeightRowThatNoLongerSumsFails() throws {
        let issues = rules(try broken(exploration: { exploration in
            var tiers = exploration["weightTiers"] as? [[String: Any]] ?? []
            tiers[0]["herb"] = 4  // without taking the extra point from anywhere
            exploration["weightTiers"] = tiers
        }))
        XCTAssertTrue(issues.contains { $0.rule == "tuning.exploration.weights_dont_sum" },
                      "\(issues.map(\.rule))")
    }

    func testAnUnknownPlantFails() throws {
        let issues = rules(try broken(zones: { zones in
            var herbs = zones["herbs"] as? [[String: Any]] ?? []
            herbs.append(["itemId": "mat.herb_nightshade", "weight": 1])
            zones["herbs"] = herbs
        }))
        XCTAssertTrue(issues.contains { $0.rule == "zone.herb_unknown_item" }, "\(issues.map(\.rule))")
    }

    func testAZeroWeightPlantFails() throws {
        let issues = rules(try broken(zones: { zones in
            var herbs = zones["herbs"] as? [[String: Any]] ?? []
            herbs[3]["weight"] = 0
            zones["herbs"] = herbs
        }))
        XCTAssertTrue(issues.contains { $0.rule == "zone.herb_weight_range" }, "\(issues.map(\.rule))")
    }

    func testAPlantListedTwiceFails() throws {
        let issues = rules(try broken(zones: { zones in
            var herbs = zones["herbs"] as? [[String: Any]] ?? []
            herbs.append(["itemId": "mat.herb_thyme", "weight": 1])
            zones["herbs"] = herbs
        }))
        XCTAssertTrue(issues.contains { $0.rule == "identity.duplicate_id" && $0.path.hasPrefix("herbs") },
                      "\(issues.map(\.rule))")
    }

    /// The step's line and the 🏕 report's label are required once a plant can
    /// be found — a missing one would print a raw key at the player.
    func testAMissingHerbLineFails() throws {
        let empty = LocaleIndex(tables: ["en": [:], "uk": [:]])
        let missing = rules(try shipped(), locales: empty)
            .filter { $0.rule == "locale.key.missing" && $0.path == "herbs" }
            .map(\.message)
        for key in ["exploration.outcome.herb.picked", "exploration.outcome.herb.full",
                    "exploration.passive.outcome.herb"] {
            XCTAssertTrue(missing.contains { $0.contains(key) }, "\(key) not required")
        }
    }

    // MARK: - A row written before the event

    func testARowWithoutHerbDecodesAsZero() throws {
        let tier = try JSONDecoder().decode(EventWeightTierDTO.self, from: Data(
            #"{"priorVisits": 0, "nothing": 5, "loot": 48, "encounter": 40, "trip": 5, "silver": 2}"#.utf8))
        XCTAssertEqual(tier.herb, 0)
        let passive = try JSONDecoder().decode(EventWeightsDTO.self, from: Data(
            #"{"nothing": 25, "loot": 43, "encounter": 20, "trip": 10, "silver": 2}"#.utf8))
        XCTAssertEqual(passive.herb, 0)
        let zones = try JSONDecoder().decode(ZoneFileDTO.self, from: Data(#"{"zones": []}"#.utf8))
        XCTAssertEqual(zones.herbs, [])
    }
}
