//
//  TelegramHTMLTests.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 17.10.2026.
//
//  The escape for text nobody curated (2026-10-17): the Telegram first name
//  that froze a registration on step 0, and the order that keeps an entity
//  from being escaped twice.
//

import XCTest
@testable import ROIContent

final class TelegramHTMLTests: XCTestCase {

    /// The live name that broke the welcome: what remains has no tag in it.
    func testTheNameThatBrokeTheWelcome() {
        let escaped = TelegramHTML.escaped("<🌷RILENX🌷>")
        XCTAssertEqual(escaped, "&lt;🌷RILENX🌷&gt;")
        XCTAssertFalse(escaped.contains("<") || escaped.contains(">"))
    }

    /// `&` first: done last, it would turn every `&lt;` into `&amp;lt;`.
    func testAnAmpersandIsEscapedOnce() {
        XCTAssertEqual(TelegramHTML.escaped("Tom & <Jerry>"), "Tom &amp; &lt;Jerry&gt;")
        XCTAssertEqual(TelegramHTML.escaped("&lt;"), "&amp;lt;")
    }

    /// Plain text, Cyrillic, an apostrophe and emoji pass through untouched —
    /// every name `PlayerNameRules` allows reads the same after the escape.
    func testPlainTextIsUntouched() {
        for text in ["Дар'я", "Солов'їний гай", "B A S E L", "🌷rilenx🌷", ""] {
            XCTAssertEqual(TelegramHTML.escaped(text), text)
        }
    }
}
