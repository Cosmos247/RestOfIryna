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
    /// Takes the Explore slot for as long as the player is on the road between
    /// the estate and the capital. Explore is refused during a trip anyway
    /// (`MainController.guardedByTravel`), so the swap costs nothing and puts a
    /// live key where a dead one was — the same move the combat keyboard makes
    /// with Flee → Exit in training.
    case turnBack = "commands.turn_back"
    
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
