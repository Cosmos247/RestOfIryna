//
//  LocaleIndexTests.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 29.08.2026.
//

import XCTest
@testable import ROIContent

final class LocaleIndexTests: XCTestCase {

    /// 21 keys ship in en.json with no plain uk form because uk supplies
    /// `.m`/`.f` instead. A naive parity check reports all 21 as missing.
    func testGenderedUkrainianKeyCountsAsPresent() {
        let index = LocaleIndex(tables: [
            "en": ["greeting": "You arrived"],
            "uk": ["greeting.m": "Ти прибув", "greeting.f": "Ти прибула"]
        ])
        XCTAssertTrue(index.has("greeting", locale: "uk"))
        XCTAssertTrue(index.missing("greeting").isEmpty)
    }

    func testOnlyOneGenderedHalfIsStillMissing() {
        let index = LocaleIndex(tables: [
            "en": ["greeting": "You arrived"],
            "uk": ["greeting.m": "Ти прибув"]
        ])
        XCTAssertFalse(index.has("greeting", locale: "uk"))
        XCTAssertEqual(index.missing("greeting"), ["uk"])
    }

    /// A supplementary-plane emoji before `%{…}` breaks Lingo interpolation
    /// (see .memory/localization.md). Encoded as a rule, not tribal knowledge.
    func testEmojiBeforePlaceholderIsFlagged() {
        let index = LocaleIndex(tables: [
            "en": [
                "bad":       "🫐 you found %{name}",
                "bad_vs16":  "❤️ %{name}",
                "safe_after": "you found %{name} 🫐",
                "safe_bmp":  "→ %{name}",
                "no_placeholder": "🫐 plain text"
            ],
            "uk": [:]
        ])
        let flagged = index.emojiBeforePlaceholderKeys(locale: "en")
        XCTAssertEqual(flagged, ["bad", "bad_vs16"])
    }

    /// The 2026-05-18 amendment: the bug fires for a multi-UTF-16 emoji sitting
    /// before ANY placeholder, not only a leading one. `🪙 %{silver}` broke even
    /// though an earlier placeholder preceded it.
    func testEmojiBetweenTwoPlaceholdersIsFlagged() {
        let index = LocaleIndex(tables: [
            "en": [
                "mid": "You earned %{amount} and 🪙 %{silver}",
                "trailing_only": "%{before} → %{after} ❤️"
            ],
            "uk": [:]
        ])
        XCTAssertEqual(index.emojiBeforePlaceholderKeys(locale: "en"), ["mid"],
                       "an emoji after the LAST placeholder is safe; one before it is not")
    }

    /// Single-UTF-16 BMP emoji are explicitly documented as safe before a
    /// placeholder — flagging them would train people to ignore the rule.
    func testSingleUTF16BmpEmojiIsNotFlagged() {
        let index = LocaleIndex(tables: [
            "en": ["safe": "✅ %{name}", "safe2": "⚡ %{name}"],
            "uk": [:]
        ])
        XCTAssertTrue(index.emojiBeforePlaceholderKeys(locale: "en").isEmpty)
    }

    /// Guards the real files: today there are zero genuinely missing keys and
    /// the gendered convention is the only reason for the en/uk count gap.
    func testShippedLocaleFilesLoadWhenAvailable() throws {
        let root = ProcessInfo.processInfo.environment["ROI_PROJECT_PATH"] ?? FileManager.default.currentDirectoryPath
        let path = "\(root)/Localizations"
        guard FileManager.default.fileExists(atPath: "\(path)/en.json") else {
            throw XCTSkip("Localizations not reachable from \(path)")
        }
        let index = try LocaleIndex(rootPath: path)
        XCTAssertGreaterThan(index.count("en"), 900)
        XCTAssertGreaterThan(index.count("uk"), 900)
    }
}
