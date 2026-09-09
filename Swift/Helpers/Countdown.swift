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
//  question, and dropping to seconds inside the last minute is where a
//  countdown starts being watched rather than glanced at.
//
//  Unit words come from Lingo so uk stays inside the glossary («год · хв ·
//  сек»), and every screen shares this one implementation — a second copy is
//  how two screens end up disagreeing about the same clock.
//

import Foundation
import Lingo

enum Countdown {

    /// `2год 5хв` · `5хв` · `42сек`. Hours appear only when there are any;
    /// seconds only in the last minute, where they are the whole point. No
    /// leading zero anywhere — this is a sentence the player reads ("arrival
    /// in 2 min"), not a clock face they scan.
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
            return "\(minutes)\(unit("minutes", lingo, locale))"
        }
        return "\(clamped % 60)\(unit("seconds", lingo, locale))"
    }

    private static func unit(_ name: String, _ lingo: Lingo, _ locale: String) -> String {
        return lingo.localize("time.short.\(name)", locale: locale)
    }
}
