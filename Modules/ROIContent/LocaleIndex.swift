//
//  LocaleIndex.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 29.08.2026.
//
//  Read-only view over `Localizations/{en,uk}.json` for the validator.
//
//  Deliberately NOT Lingo: the `roi-content` CLI does not link Lingo, and
//  `lingo.localize` returns the key itself on a miss, which makes it useless as
//  an existence test.
//
//  Ukrainian gendered keys are the subtlety. 21 keys exist in `en.json` with no
//  plain form in `uk.json` because uk supplies `key.m` + `key.f` instead (the
//  `lingo.localize(_:gender:locale:)` convention in CLAUDE.md). A naive parity
//  check reports all 21 as missing on day one, so `has(_:locale:)` accepts
//  either shape.
//

import Foundation

public struct LocaleIndex: Sendable {
    public static let locales = ["en", "uk"]

    private let tables: [String: [String: String]]

    public init(rootPath: String) throws {
        var loaded: [String: [String: String]] = [:]
        for locale in Self.locales {
            let url = URL(fileURLWithPath: rootPath).appendingPathComponent("\(locale).json")
            guard let data = FileManager.default.contents(atPath: url.path) else {
                throw ContentError.missingFile("\(locale).json")
            }
            let decoded = try JSONDecoder().decode([String: String].self, from: data)
            loaded[locale] = decoded
        }
        self.tables = loaded
    }

    /// Test-only seam.
    public init(tables: [String: [String: String]]) {
        self.tables = tables
    }

    public func count(_ locale: String) -> Int { tables[locale]?.count ?? 0 }

    /// A key counts as present when the plain form exists, OR when both
    /// gendered variants do. Only `uk` uses the gendered shape, but accepting
    /// it for every locale keeps the rule in one place.
    public func has(_ key: String, locale: String) -> Bool {
        guard let table = tables[locale] else { return false }
        if table[key] != nil { return true }
        return table["\(key).m"] != nil && table["\(key).f"] != nil
    }

    /// Locales in which `key` is absent.
    public func missing(_ key: String) -> [String] {
        Self.locales.filter { !has(key, locale: $0) }
    }

    /// The string behind a key, or nil when the locale has no plain form for
    /// it. Gendered keys are deliberately NOT resolved here: a caller that
    /// wants text has to decide which variant it means.
    public func value(_ key: String, locale: String) -> String? {
        tables[locale]?[key]
    }

    /// Every value that trips the Lingo interpolation bug.
    ///
    /// The rule (`.memory/localization.md`): any character wider than one
    /// UTF-16 code unit placed BEFORE a `%{…}` placeholder breaks that
    /// interpolation and every one after it. Two shapes qualify —
    /// supplementary-plane scalars (🪙 🏕 🍖, U+10000+) and a BMP character
    /// followed by VS16 (❤️ ⚔️ ⚠️, U+FE0F). Single-UTF-16 BMP emoji (✅ ⚡ ⭐)
    /// are safe and must not be flagged.
    ///
    /// Scanning stops at the LAST placeholder, not the first: the 2026-05-18
    /// amendment records `🪙 %{silver}` breaking while sitting *after* an
    /// earlier placeholder, so anything before the final `%{` is in scope.
    /// Text after the last placeholder is safe ("placeholder before emoji").
    public func emojiBeforePlaceholderKeys(locale: String) -> [String] {
        guard let table = tables[locale] else { return [] }
        return table.compactMap { key, value in
            guard let last = value.range(of: "%{", options: .backwards) else { return nil }
            let scanned = value[value.startIndex..<last.lowerBound]
            let trips = scanned.unicodeScalars.contains { $0.value > 0xFFFF || $0.value == 0xFE0F }
            return trips ? key : nil
        }.sorted()
    }

}
