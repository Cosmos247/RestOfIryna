//
//  GameDay.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 28.07.2026.
//
//  The in-game "day" — the shared boundary every daily reset counts against
//  (Arena fight budget now; quests and other daily systems later). It rolls at
//  12:00 (noon) Kyiv time, NOT at midnight. Starting the day at noon gives
//  players an evening-plus-next-morning window to spend a daily budget instead
//  of a hard cut in the middle of the night — one late session can span two
//  in-game days. Everything daily should key off `GameDay.stamp(...)` so the
//  systems never drift apart.
//

import Foundation

public enum GameDay {

    // `tuning/time.json` → `realTime`. A wall-clock hour in a named zone: the
    // rollover is anchored to when players are awake, so `time.scale` leaves it
    // alone the same way it leaves the Telegram delete window alone.

    /// Hour (Kyiv local) the game day rolls over. Noon.
    public static var rolloverHour: Int { Catalogs.current.tuningTime.realTime.dayRolloverHour }

    /// Wall-clock timezone the boundary is measured in.
    public static var timeZoneID: String { Catalogs.current.tuningTime.realTime.dayTimeZoneId }

    /// The `yyyy-MM-dd` key of the game day `date` falls in. Two instants share
    /// a key iff they sit between the same pair of consecutive 12:00-Kyiv
    /// boundaries. Implemented by shifting the instant back by `rolloverHour`
    /// hours and taking its Kyiv calendar date, so the label is the date the
    /// game day *began* on (e.g. the key "2026-07-28" runs 28 Jul 12:00 →
    /// 29 Jul 12:00 Kyiv).
    /// Seconds from `date` until the next rollover (the next 12:00 Kyiv).
    /// Used by screens that show "new jobs in Xh Ym" — the quest journal today,
    /// anything else daily later. DST-safe: the boundary is found by calendar
    /// search in the Kyiv zone, not by arithmetic on a fixed 24 h period.
    public static func secondsUntilNextRollover(from date: Date = Date()) -> Int {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: timeZoneID) ?? TimeZone(identifier: "UTC")!
        let next = calendar.nextDate(
            after: date,
            matching: DateComponents(hour: rolloverHour, minute: 0, second: 0),
            matchingPolicy: .nextTime
        )
        guard let next else { return 0 }
        return max(0, Int(next.timeIntervalSince(date)))
    }

    public static func stamp(_ date: Date = Date()) -> String {
        let shifted = date.addingTimeInterval(-Double(rolloverHour) * 3600)
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.calendar = Calendar(identifier: .gregorian)
        fmt.timeZone = TimeZone(identifier: timeZoneID) ?? TimeZone(identifier: "UTC")!
        fmt.dateFormat = "yyyy-MM-dd"
        return fmt.string(from: shifted)
    }
}
