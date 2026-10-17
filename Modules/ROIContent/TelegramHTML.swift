//
//  TelegramHTML.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 17.10.2026.
//
//  Text that nobody curated, made safe for a `parseMode: .html` message.
//
//  Telegram refuses the WHOLE message when its HTML does not parse, and a send
//  that throws can take the rest of its handler with it. On 2026-10-13 an
//  account named «<🌷RILENX🌷>» came through the open door: the registration
//  welcome printed that first name raw, Telegram answered `can't parse
//  entities: Unsupported start tag`, the throw skipped the language picker
//  sent after it, and the player sat on registration step 0 through nine
//  `/start`s over two days.
//
//  Locale copy and the game's own names never need this — a nickname and an
//  estate name are held to `PlayerNameRules`, whose characters are all plain
//  text. A Telegram name, validator prose, anything typed and stored as typed
//  does. `&` goes first, so an escape is never escaped twice.
//

import Foundation

public enum TelegramHTML {

    /// `text` with the three characters Telegram's HTML parser reads as markup
    /// replaced by their entities. Shows exactly as typed.
    public static func escaped(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }
}
