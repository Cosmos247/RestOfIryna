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
}
