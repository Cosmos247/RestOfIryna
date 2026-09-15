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

    /// Count-aware localization for Ukrainian, which has THREE noun forms
    /// where English has two.
    ///
    /// Every key routed through this MUST have `<key>.one`, `<key>.few` and
    /// `<key>.many` in `uk.json`; other locales keep a single `<key>` and
    /// short-circuit, so English is never duplicated — the same shape the
    /// gender helper above uses.
    ///
    /// The rule is the standard one and the exceptions are what make it worth
    /// a function rather than a ternary: **11–14 take the `many` form even
    /// though they end in 1–4**, so `21 срібник` but `11 срібників`. Writing
    /// this as "ends in 1 → one" is the bug every hand-rolled version of this
    /// has, and it only shows on a number nobody tested.
    ///
    /// The alternative already in this file is `раунд(ів)` — the parenthesised
    /// dodge. It is honest about being a dodge; this is what replaces it where
    /// a number is the point of the sentence.
    public func localize(_ key: LocalizationKey, count: Int, locale: LocaleIdentifier,
                         interpolations: [String: Any]? = nil) -> String {
        guard locale == SupportedLocale.ua.rawValue else {
            return self.localize(key, locale: locale, interpolations: interpolations)
        }
        // `.rawValue`, not the enum itself: interpolating the case would give
        // the same three strings today only because the case names and the raw
        // values happen to match, and it would keep giving case names if the
        // raw values were ever changed to something else.
        return self.localize("\(key).\(UkrainianPlural.form(for: count).rawValue)",
                             locale: locale, interpolations: interpolations)
    }

    /// Localize a sentence that must AGREE with the grammatical gender of a
    /// WORD rather than of the player — an item's noun, a plot's noun. `gender`
    /// is `m` · `f` · `n` · `pl`; anything else (including a missing
    /// declaration, which Lingo signals by echoing the key back) falls back to
    /// `m`, so the failure is a wrong ending rather than a missing sentence.
    ///
    /// The core of `ItemDisplay.localize(_:agreeingWith:)`, which now delegates
    /// here: items were the first nouns to need this and are not the last, and
    /// a second copy of the suffix rule is a second place to forget `pl`.
    /// English short-circuits to the plain key — no per-locale duplication.
    public func localize(_ key: LocalizationKey, agreeingWith gender: String,
                         locale: LocaleIdentifier, interpolations: [String: Any]? = nil) -> String {
        guard locale == SupportedLocale.ua.rawValue else {
            return self.localize(key, locale: locale, interpolations: interpolations)
        }
        let suffix = ["m", "f", "n", "pl"].contains(gender) ? gender : "m"
        return self.localize("\(key).\(suffix)", locale: locale, interpolations: interpolations)
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

