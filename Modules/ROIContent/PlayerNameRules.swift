//
//  PlayerNameRules.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 11.10.2026.
//
//  What a player may call themselves (registration step 2) and their estate
//  (step 6): Latin or Ukrainian letters, digits, single spaces — and, since
//  2026-10-11 (the owner's call), an apostrophe INSIDE a word. Ukrainian spells
//  with it, so «Дар'я» and «Солов'їний гай» were refused as "symbols" until
//  then, under a message that told the player to use letters only.
//
//  An apostrophe stands between two letters, never at an edge, beside a space
//  or a digit, or twice in a row. Keyboards send three different characters
//  for it — ' (U+0027), ʼ (U+02BC, the orthographic one) and ’ (U+2019, iOS
//  smart punctuation) — so all three are accepted and every name is STORED
//  with U+0027, the form the game's own Ukrainian copy uses. The guild
//  invite's lookup compares strings, so it normalizes what the player typed
//  the same way: «Дар’я» typed finds «Дар'я» stored.
//
//  Every allowed character is plain text inside Telegram's HTML parse mode
//  (only `<`, `>` and `&` need escaping there), so a name is still safe in an
//  `.html` message unescaped.
//
//  The rule lives here, in pure Foundation, so registration and the guild
//  lookup ask one function each and the tests can reach it — the reason
//  `FortuneStage` lives in this module too.
//

import Foundation

public enum PlayerNameRules {
    /// Why a name was refused. The checks run in this order, so a name with
    /// two faults is refused for the first.
    public enum Violation: Sendable, Equatable {
        case edgeSpace
        case consecutiveSpaces
        case tooShort
        case tooLong
        case invalidCharacters
    }

    /// Registration step 2.
    public static let nicknameLength = 2...20
    /// Registration step 6.
    public static let estateNameLength = 2...30

    /// The one apostrophe a stored name carries.
    public static let storedApostrophe: Character = "'"
    /// Every apostrophe a keyboard sends for it.
    public static let apostrophes: Set<Character> = ["'", "\u{02BC}", "\u{2019}"]

    private static let digits: Set<Character> = Set("0123456789")
    private static let latin: Set<Character> = Set("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ")
    private static let ukrainian: Set<Character> = Set("АБВГҐДЕЄЖЗИІЇЙКЛМНОПРСТУФХЦЧШЩЬЮЯабвгґдеєжзиіїйклмнопрстуфхцчшщьюя")

    /// The name as it is stored and as it is looked up: every apostrophe form
    /// becomes U+0027. Nothing else changes.
    public static func normalized(_ text: String) -> String {
        String(text.map { apostrophes.contains($0) ? storedApostrophe : $0 })
    }

    /// Nil when `text` is a valid name of a length in `length`.
    public static func violation(of text: String, length: ClosedRange<Int>) -> Violation? {
        if text.first?.isWhitespace == true || text.last?.isWhitespace == true { return .edgeSpace }
        if text.contains("  ") { return .consecutiveSpaces }
        if text.count < length.lowerBound { return .tooShort }
        if text.count > length.upperBound { return .tooLong }
        let characters = Array(text)
        for (index, character) in characters.enumerated() {
            if character == " " || digits.contains(character) || isLetter(character) { continue }
            if apostrophes.contains(character),
               index > 0, index < characters.count - 1,
               isLetter(characters[index - 1]), isLetter(characters[index + 1]) { continue }
            return .invalidCharacters
        }
        return nil
    }

    private static func isLetter(_ character: Character) -> Bool {
        latin.contains(character) || ukrainian.contains(character)
    }
}
