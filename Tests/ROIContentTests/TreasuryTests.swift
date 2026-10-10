//
//  TreasuryTests.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 11.10.2026.
//
//  `treasury.json` against the shipped content: the list itself is clean, and
//  every validator rule fails on the one mistake it exists for — a kind no
//  handler carries out, a price that gives the entry away, an id that would
//  break its callback or its locale key, a name nobody wrote.
//

import XCTest
@testable import ROIContent

final class TreasuryTests: XCTestCase {

    /// The repository's own content directory, found from this file.
    private static let contentRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("content/data")

    private func shipped() throws -> ContentBundle {
        try ContentLoader.load(from: Self.contentRoot)
    }

    /// The shipped bundle with only the Treasury swapped.
    private func bundle(_ items: [TreasuryItemDTO]) throws -> ContentBundle {
        let s = try shipped()
        return ContentBundle(
            manifest: s.manifest, items: s.items, enemies: s.enemies, recipes: s.recipes,
            starterRecipeIds: s.starterRecipeIds, weaponLadders: s.weaponLadders,
            bags: s.bags, estateUpgrades: s.estateUpgrades, plots: s.plots,
            treasury: TreasuryFileDTO(items: items),
            tuning: s.tuning, contentHash: "test")
    }

    /// The Treasury's own rules, errors and warnings alike.
    private func rules(_ items: [TreasuryItemDTO], locales: LocaleIndex? = nil) throws -> [String] {
        ContentValidator.validate(try bundle(items), localizations: locales).issues
            .map(\.rule)
            .filter { $0.hasPrefix("treasury.") || $0 == "identity.duplicate_id" || $0 == "locale.key.missing" }
    }

    private let classChange = TreasuryItemDTO(id: "class_change", kind: "class_change", price: 100)

    // MARK: - The shipped list

    func testShippedTreasuryIsClean() throws {
        let s = try shipped()
        XCTAssertEqual(s.treasury?.items.map(\.kind), [TreasuryKind.classChange.rawValue])
        XCTAssertEqual(try rules(s.treasury?.items ?? []), [])
    }

    // MARK: - Every rule, failing on purpose

    func testUnknownKindIsRefused() throws {
        let item = TreasuryItemDTO(id: "rename", kind: "rename_nick", price: 50)
        XCTAssertEqual(try rules([classChange, item]), ["treasury.unknown_kind"])
    }

    func testFreeOrNegativePriceIsRefused() throws {
        XCTAssertEqual(try rules([TreasuryItemDTO(id: "class_change", kind: "class_change", price: 0)]),
                       ["treasury.price_not_positive"])
        XCTAssertEqual(try rules([TreasuryItemDTO(id: "class_change", kind: "class_change", price: -5)]),
                       ["treasury.price_not_positive"])
    }

    func testIdThatWouldBreakItsCallbackIsRefused() throws {
        for bad in ["", "Class_Change", "class:change", "клас", String(repeating: "a", count: 33)] {
            XCTAssertEqual(try rules([TreasuryItemDTO(id: bad, kind: "class_change", price: 100)]),
                           ["treasury.bad_id"], "\"\(bad)\"")
        }
        XCTAssertEqual(try rules([TreasuryItemDTO(id: String(repeating: "a", count: 32), kind: "class_change", price: 100)]),
                       [], "32 characters is the ceiling, not over it")
    }

    func testDuplicateIdIsRefused() throws {
        XCTAssertTrue(try rules([classChange, classChange]).contains("identity.duplicate_id"))
    }

    func testEmptyTreasuryWarns() throws {
        let report = ContentValidator.validate(try bundle([]))
        XCTAssertEqual(report.issues.filter { $0.rule == "treasury.empty" }.map(\.severity), [.warning])
    }

    /// The name the list's button and the card's title print, in both locales.
    /// The tables carry no other key, so every other content name is missing
    /// too — only the Treasury entry's own issues are read.
    func testNameKeyIsRequiredInEveryLocale() throws {
        func missingName(_ locales: LocaleIndex) throws -> [String] {
            ContentValidator.validate(try bundle([classChange]), localizations: locales).issues
                .filter { $0.rule == "locale.key.missing" && $0.id == "class_change" }
                .map(\.file)
        }
        let named = LocaleIndex(tables: [
            "en": ["treasury.item.class_change": "🔄 Change class"],
            "uk": ["treasury.item.class_change": "🔄 Зміна класу"],
        ])
        XCTAssertEqual(try missingName(named), [])

        let ukOnly = LocaleIndex(tables: [
            "en": [:],
            "uk": ["treasury.item.class_change": "🔄 Зміна класу"],
        ])
        XCTAssertEqual(try missingName(ukOnly), ["en.json"])
    }
}
