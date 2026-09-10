//
//  Countdown.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 09.09.2026.
//
//  One format for every "time left" the player sees — travel, expeditions,
//  the fortune windows, the daily-job rollover.
//
//  The old `MM:SS` / `HH:MM` pair could not be read without knowing which one
//  a screen used: `05:30` was five and a half minutes on the trail and five
//  and a half HOURS at the fortune teller. Naming the unit removes the
//  question.
//
//  The rule is the TWO most significant units that carry a value. Minutes used
//  to print alone, which made "1хв" mean anything from 1:00 to 1:59 — a whole
//  crossing of doubt on a two-minute road, and reported from play as simply
//  hard to read. Hours had shown two units from the start; the pair below now
//  does the same thing for the same reason.
//
//  Unit words come from Lingo so uk stays inside the glossary («год · хв ·
//  сек»), and every screen shares this one implementation — a second copy is
//  how two screens end up disagreeing about the same clock.
//

import Foundation
import Lingo

enum Countdown {

    /// `2год 5хв` · `1хв 22сек` · `5хв` · `42сек`. The two most significant
    /// units that carry a value, and an exact one drops its tail rather than
    /// printing `5хв 0сек` — which is what keeps the whole-minute callers (the
    /// five-minute invite window, the passive daily budget) clean. No leading
    /// zero anywhere: this is a sentence the player reads ("arrival in 1хв
    /// 22сек"), not a clock face they scan.
    static func format(_ seconds: Int, lingo: Lingo, locale: String) -> String {
        let clamped = max(0, seconds)
        let hours = clamped / 3600
        let minutes = (clamped % 3600) / 60

        if hours > 0 {
            // A whole hour drops the minutes rather than printing "1год 0хв",
            // which is what unpadded parts do to an exact value.
            guard minutes > 0 else { return "\(hours)\(unit("hours", lingo, locale))" }
            return "\(hours)\(unit("hours", lingo, locale)) \(minutes)\(unit("minutes", lingo, locale))"
        }
        if minutes > 0 {
            // Mirrors the hours branch above, including the exact-value drop.
            let seconds = clamped % 60
            guard seconds > 0 else { return "\(minutes)\(unit("minutes", lingo, locale))" }
            return "\(minutes)\(unit("minutes", lingo, locale)) \(seconds)\(unit("seconds", lingo, locale))"
        }
        return "\(clamped % 60)\(unit("seconds", lingo, locale))"
    }

    private static func unit(_ name: String, _ lingo: Lingo, _ locale: String) -> String {
        return lingo.localize("time.short.\(name)", locale: locale)
    }
}
