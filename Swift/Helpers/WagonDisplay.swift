//
//  WagonDisplay.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 08.11.2026.
//
//  How the wagon («🫏 Віз», `content/spec/spec-wagon.md` §4) is phrased on
//  every screen that names it — the stable, the warehouse, the bag, the road
//  card and the profile — so «🫏 Віз: 150/200 · ще 2год 41хв» reads the same
//  everywhere. The time left goes through `Countdown`, like every other.
//
//  🫏 is prepended here, never typed ahead of a placeholder in a template:
//  Lingo drops a `%{var}` that follows a supplementary-plane emoji.
//

import Foundation
@preconcurrency import Lingo

enum WagonDisplay {
    static let icon = "🫏"

    /// A rental length as the stable names it: «1 год», «1 день», «7 днів».
    /// Whole days count in days, whole hours in hours, anything else in
    /// minutes — printed from the data, never typed into copy.
    static func lengthLabel(minutes: Int, lingo: Lingo, locale: String) -> String {
        if minutes > 0, minutes % 1440 == 0 {
            let days = minutes / 1440
            return lingo.localize("wagon.length.days", count: days, locale: locale, interpolations: ["n": "\(days)"])
        }
        if minutes > 0, minutes % 60 == 0 {
            return lingo.localize("wagon.length.hours", locale: locale, interpolations: ["n": "\(minutes / 60)"])
        }
        return lingo.localize("wagon.length.minutes", locale: locale, interpolations: ["n": "\(minutes)"])
    }

    /// «🫏 Віз: 150/200 · ще 2год 41хв», with «· чекає вдома» while the player
    /// is away without it, or «· оренда скінчилась» once the hire has run out
    /// with cargo still on it.
    static func statusLine(_ status: WagonService.Status, lingo: Lingo, locale: String, now: Date = Date()) -> String {
        let load = lingo.localize("wagon.status.line", locale: locale, interpolations: [
            "used": "\(status.used)", "cap": "\(status.capacity)"
        ])
        var tail = status.running
            ? lingo.localize("wagon.status.left", locale: locale, interpolations: [
                "time": Countdown.format(status.secondsLeft(now: now), lingo: lingo, locale: locale)
            ])
            : lingo.localize("wagon.status.ended", locale: locale)
        if status.running, status.leftHome {
            tail += " · " + lingo.localize("wagon.status.left_home", locale: locale)
        }
        return "\(icon) \(load) · \(tail)"
    }

    /// The button that opens the wagon: «🫏 Віз (150/200)».
    static func button(_ status: WagonService.Status, lingo: Lingo, locale: String) -> String {
        "\(icon) \(lingo.localize("wagon.name", locale: locale)) (\(status.used)/\(status.capacity))"
    }
}
