//
//  HorseDisplay.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 09.11.2026.
//
//  How the Rysak («🐴 Рисак», `content/spec/spec-horse.md` §4) is phrased where
//  more than one screen names it. The time left goes through `Countdown`, like
//  every other.
//
//  🐴 is prepended here, never typed ahead of a placeholder in a template:
//  Lingo drops a `%{var}` that follows a supplementary-plane emoji.
//

import Foundation
@preconcurrency import Lingo

enum HorseDisplay {
    static let icon = "🐴"

    /// «🐴 Рисак: ще 2год 58хв» — the profile's line.
    static func statusLine(_ status: HorseService.Status, lingo: Lingo, locale: String, now: Date = Date()) -> String {
        "\(icon) " + lingo.localize("horse.status.line", locale: locale, interpolations: [
            "time": Countdown.format(status.secondsLeft(now: now), lingo: lingo, locale: locale)
        ])
    }
}
