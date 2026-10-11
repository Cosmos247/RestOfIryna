//
//  PlayerNameRulesTests.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 11.10.2026.
//
//  A nickname or an estate name may carry an apostrophe inside a word
//  (2026-10-11, the owner's call): all three keyboard forms are accepted and
//  stored as U+0027, and everything the rule refused before is still refused.
//

import XCTest
@testable import ROIContent

final class PlayerNameRulesTests: XCTestCase {

    private func check(_ text: String, _ length: ClosedRange<Int> = PlayerNameRules.estateNameLength) -> PlayerNameRules.Violation? {
        PlayerNameRules.violation(of: PlayerNameRules.normalized(text), length: length)
    }

    /// The names that were refused before the change, in every apostrophe form.
    func testAnApostropheInsideAWordIsAccepted() {
        for apostrophe in ["'", "\u{02BC}", "\u{2019}"] {
            XCTAssertNil(check("Дар\(apostrophe)я", PlayerNameRules.nicknameLength), apostrophe)
            XCTAssertNil(check("Солов\(apostrophe)їний гай"), apostrophe)
            XCTAssertNil(check("O\(apostrophe)Brien", PlayerNameRules.nicknameLength), apostrophe)
            // Unnormalized too: the rule itself knows every form.
            XCTAssertNil(PlayerNameRules.violation(of: "Мар\(apostrophe)яна", length: PlayerNameRules.nicknameLength), apostrophe)
        }
    }

    /// Every form is stored as U+0027, and nothing else in the name changes.
    func testEveryApostropheFormIsStoredAsOne() {
        XCTAssertEqual(PlayerNameRules.normalized("Дар'я"), "Дар'я")
        XCTAssertEqual(PlayerNameRules.normalized("Дар\u{02BC}я"), "Дар'я")
        XCTAssertEqual(PlayerNameRules.normalized("Дар\u{2019}я"), "Дар'я")
        XCTAssertEqual(PlayerNameRules.normalized("Солов\u{02BC}їний гай 7"), "Солов'їний гай 7")
        XCTAssertEqual(PlayerNameRules.normalized("Вишневий сад"), "Вишневий сад")
    }

    /// An apostrophe stands between two letters — never at an edge, beside a
    /// space or a digit, or twice in a row.
    func testAnApostropheMustSitBetweenTwoLetters() {
        for text in ["'Дарья", "Дарья'", "Дар''я", "Дар' я", "Дар 'я", "5'я", "Дар'5", "''"] {
            XCTAssertEqual(check(text), .invalidCharacters, text)
        }
        XCTAssertEqual(check("Дар\u{02BC}\u{2019}я"), .invalidCharacters, "two forms side by side are still two")
    }

    /// Everything refused before the apostrophe was allowed is still refused,
    /// for the same reason and in the same order.
    func testTheOtherRulesStillHold() {
        XCTAssertEqual(check(" Сад"), .edgeSpace)
        XCTAssertEqual(check("Сад "), .edgeSpace)
        XCTAssertEqual(check("Вишневий  сад"), .consecutiveSpaces)
        XCTAssertEqual(check("Я"), .tooShort)
        XCTAssertEqual(check(String(repeating: "я", count: 31)), .tooLong)
        XCTAssertEqual(check(String(repeating: "я", count: 21), PlayerNameRules.nicknameLength), .tooLong)
        for text in ["Дар'я!", "Dark-Wood", "Сад🌳", "Сад.", "Сад_1", "Ыгрок", "<b>Сад</b>", "Сад&Co"] {
            XCTAssertEqual(check(text), .invalidCharacters, text)
        }
        XCTAssertNil(check("Вишневий сад 2"))
    }

    /// An apostrophe is one character of the length, whichever form was typed.
    func testAnApostropheCountsAsOneCharacter() {
        let twenty = "Мар\u{2019}" + String(repeating: "я", count: 16)
        XCTAssertEqual(twenty.count, 20)
        XCTAssertNil(check(twenty, PlayerNameRules.nicknameLength))
        XCTAssertEqual(check(twenty + "я", PlayerNameRules.nicknameLength), .tooLong)
        XCTAssertNil(check("Б'я", PlayerNameRules.nicknameLength))
    }

    /// The registration's lengths, as the refusal copy quotes them («мінімум 2
    /// символи», «максимум 20 / 30 символів»).
    func testTheRegistrationLengths() {
        XCTAssertEqual(PlayerNameRules.nicknameLength, 2...20)
        XCTAssertEqual(PlayerNameRules.estateNameLength, 2...30)
    }
}
