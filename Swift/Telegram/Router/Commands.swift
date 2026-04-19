//
//  Commands.swift
//  RestOfIryna
//
//  Created by Maxim Lanskoy on 13.06.2025.
//  Maintained by Dmytro Ihnatyuhin from 17.04.2026.
//

import Foundation
import Lingo
import SwiftTelegramBot

enum Commands: String, Codable, CaseIterable {
    
    case start = "commands.start"
    case cancel = "commands.cancel"
    case exit = "commands.exit"
    case settings = "commands.settings"
    case language = "commands.language"
    case profile = "commands.profile"
    case explore = "commands.explore"
    case estate = "commands.estate"
    case capital = "commands.capital"
    case inventory = "commands.inventory"
    
    func button(for session: User, _ lingo: Lingo) -> TGKeyboardButton {
        let startText = lingo.localize(self.rawValue, locale: session.locale)
        return TGKeyboardButton(text: "\(startText)")
    }
    
    func buttonsForAllLocales(lingo: Lingo) -> [TGKeyboardButton] {
        var buttons: [TGKeyboardButton] = []
        for locale in SupportedLocale.allCases {
            let localizedText = lingo.localize(self.rawValue, locale: locale)
            buttons.append(TGKeyboardButton(text: localizedText))
        }
        return buttons
    }
    
    func command() -> String {
        return self.rawValue.replacingOccurrences(of: "commands.", with: "")
    }
    
    func defaultButton(lingo: Lingo) -> TGKeyboardButton {
        let localizedText = lingo.localize(self.rawValue, locale: "en")
        return TGKeyboardButton(text: localizedText)
    }
}
