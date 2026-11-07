//
//  TrophyTests.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 05.11.2026.
//
//  The kill trophies (`spec-bestiary.md` §15, the owner's picks of 2026-11-05):
//  five shared kinds — venom, feather, fang, horn, claw — each dropped by every
//  creature of its kind, never one item per creature. What is pinned here is
//  what a later content edit could undo without noticing:
//
//  - every creature the forest spawns drops exactly one trophy, as the LAST row
//    of its loot table: drops are taken in table order as far as the bag has
//    room (`ExplorationService.awardEncounterDrops`), so a full bag leaves the
//    trophy on the ground, never the meat or the hide;
//  - a creature whose band starts deeper never drops its trophy less often than
//    one whose band starts shallower: the four nearest creatures were 81.5% of
//    all fights in the week to 2026-10-30, and the owner turned down 30%
//    everywhere because venom and feathers would pile up;
//  - the trader lists none of them: until a trophy has a use, selling it is the
//    only thing to do with it, which is silver paid for a kill — the faucet
//    Phase 8C removed.
//

import XCTest
@testable import ROIContent

final class TrophyTests: XCTestCase {

    private static let contentRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("content/data")

    /// The ids share a prefix, so the five sit together in every list sorted
    /// by id — the bag's materials and the warehouse's.
    private static let prefix = "mat.trophy_"

    private func shipped() throws -> ContentBundle {
        try ContentLoader.load(from: Self.contentRoot)
    }

    // MARK: - The rules, as one function

    /// Every trophy rule broken, in words — empty when all hold. One function
    /// for the shipped files and for the copies built below to break them, so
    /// each rule is shown able to fail.
    private static func problems(items: [ItemDTO], enemies: [EnemyDTO],
                                 trader: [TraderListingDTO]) -> [String] {
        var out: [String] = []
        let trophies = items.filter { $0.id.hasPrefix(prefix) }
        if trophies.isEmpty { out.append("no trophy items") }
        for item in trophies where item.type != "material" || !item.stackable {
            out.append("\(item.id) is not a stackable material")
        }

        let spawnable = enemies.filter { ($0.depth?.max ?? 0) > 0 }
        for enemy in spawnable {
            let rows = enemy.loot.filter { $0.itemId.hasPrefix(prefix) }
            if rows.count != 1 {
                out.append("\(enemy.id) drops \(rows.count) trophies")
            } else if enemy.loot.last?.itemId != rows[0].itemId {
                out.append("\(enemy.id): the trophy is not the last loot row")
            }
            for row in rows where !trophies.contains(where: { $0.id == row.itemId }) {
                out.append("\(enemy.id) drops \(row.itemId), which is no trophy item")
            }
        }

        func expected(_ enemy: EnemyDTO) -> Double {
            enemy.loot.filter { $0.itemId.hasPrefix(prefix) }
                .reduce(0) { $0 + $1.chance * Double($1.quantity) }
        }
        for deep in spawnable {
            let deepMin = deep.depth?.min ?? 0
            if let shallow = spawnable.first(where: { ($0.depth?.min ?? 0) < deepMin
                                                      && expected($0) > expected(deep) }) {
                out.append("\(deep.id) drops its trophy less often than the shallower \(shallow.id)")
            }
        }

        for listing in trader where listing.itemId.hasPrefix(prefix) {
            out.append("the trader lists \(listing.itemId)")
        }
        return out
    }

    private static func problems(_ bundle: ContentBundle) -> [String] {
        problems(items: bundle.items, enemies: bundle.enemies, trader: bundle.trader?.listings ?? [])
    }

    // MARK: - The shipped content

    func testTheShippedContentKeepsEveryTrophyRule() throws {
        XCTAssertEqual(Self.problems(try shipped()), [])
    }

    /// The owner's five, and no per-creature item beside them.
    func testTheTrophiesAreTheOwnersFiveKinds() throws {
        let ids = Set(try shipped().items.map(\.id).filter { $0.hasPrefix(Self.prefix) })
        XCTAssertEqual(ids, ["mat.trophy_venom", "mat.trophy_feather", "mat.trophy_fang",
                             "mat.trophy_horn", "mat.trophy_claw"])
    }

    // MARK: - Each rule can fail

    private func copy(_ enemy: EnemyDTO, loot: [EnemyLootDropDTO]) -> EnemyDTO {
        EnemyDTO(id: enemy.id, tier: enemy.tier, icon: enemy.icon, xpReward: enemy.xpReward,
                 stats: enemy.stats, depth: enemy.depth, loot: loot,
                 level: enemy.level, archetype: enemy.archetype)
    }

    /// The shipped enemies with one creature's loot replaced.
    private func enemies(_ bundle: ContentBundle, replacing id: String,
                         with loot: (EnemyDTO) -> [EnemyLootDropDTO]) -> [EnemyDTO] {
        bundle.enemies.map { $0.id == id ? copy($0, loot: loot($0)) : $0 }
    }

    private func assertFails(_ problems: [String], mentioning phrase: String,
                             file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(problems.contains { $0.contains(phrase) },
                      "expected a problem mentioning «\(phrase)», got \(problems)", file: file, line: line)
    }

    func testATrophyAheadOfTheHideFails() throws {
        let s = try shipped()
        let moved = enemies(s, replacing: "enemy.wild_boar") { Array($0.loot.suffix(1) + $0.loot.dropLast()) }
        assertFails(Self.problems(items: s.items, enemies: moved, trader: s.trader?.listings ?? []),
                    mentioning: "enemy.wild_boar: the trophy is not the last loot row")
    }

    func testACreatureWithoutATrophyFails() throws {
        let s = try shipped()
        let bare = enemies(s, replacing: "enemy.wild_viper") { _ in [] }
        assertFails(Self.problems(items: s.items, enemies: bare, trader: s.trader?.listings ?? []),
                    mentioning: "enemy.wild_viper drops 0 trophies")
    }

    func testAShallowCreatureDroppingMoreThanADeeperOneFails() throws {
        let s = try shipped()
        let generous = enemies(s, replacing: "enemy.wild_eagle") { _ in
            [EnemyLootDropDTO(itemId: "mat.trophy_feather", chance: 0.3, quantity: 1)]
        }
        assertFails(Self.problems(items: s.items, enemies: generous, trader: s.trader?.listings ?? []),
                    mentioning: "less often than the shallower enemy.wild_eagle")
    }

    func testATraderListingFails() throws {
        let s = try shipped()
        let listed = (s.trader?.listings ?? []) + [
            TraderListingDTO(itemId: "mat.trophy_fang", sellPacketQty: 1, sellPacketSilver: 3,
                             buyPacketQty: 1, buyPacketSilver: 6)
        ]
        assertFails(Self.problems(items: s.items, enemies: s.enemies, trader: listed),
                    mentioning: "the trader lists mat.trophy_fang")
    }

    func testATrophyThatIsNotAStackableMaterialFails() throws {
        let s = try shipped()
        let items = s.items.map {
            $0.id == "mat.trophy_horn" ? ItemDTO(id: $0.id, type: "material", tier: 2, stackable: false) : $0
        }
        assertFails(Self.problems(items: items, enemies: s.enemies, trader: s.trader?.listings ?? []),
                    mentioning: "mat.trophy_horn is not a stackable material")
    }
}
