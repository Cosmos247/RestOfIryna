//
//  Lingo+Locales.swift.swift
//  RestOfIryna
//
//  Created by Maxim Lanskoy on 27.12.2025.
//  Maintained by Dmytro Ihnatyuhin from 17.04.2026.
//

import Lingo

extension Lingo {
    public func localize(_ key: LocalizationKey, locale: SupportedLocale, interpolations: [String: Any]? = nil) -> String {
        self.localize(key, locale: locale.rawValue, interpolations: interpolations)
    }

    /// Gender-aware localization. Ukrainian declines past-tense verbs,
    /// adjectives and the "намісник/намісниця" noun by gender, so every key
    /// routed through this helper MUST have `<key>.m` and `<key>.f` variants
    /// in `uk.json`. Other locales (English) keep a single neutral `<key>` and
    /// short-circuit to the plain lookup — no per-locale duplication. `gender`
    /// is the raw `User.gender` ("m"/"f"); nil is treated as male.
    public func localize(_ key: LocalizationKey, gender: String?, locale: LocaleIdentifier, interpolations: [String: Any]? = nil) -> String {
        guard locale == SupportedLocale.ua.rawValue else {
            return self.localize(key, locale: locale, interpolations: interpolations)
        }
        let suffix = (gender == CharacterGender.female.rawValue)
            ? CharacterGender.female.rawValue
            : CharacterGender.male.rawValue
        return self.localize("\(key).\(suffix)", locale: locale, interpolations: interpolations)
    }
}
