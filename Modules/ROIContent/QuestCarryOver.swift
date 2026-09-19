//
//  QuestCarryOver.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 19.09.2026.
//
//  A daily job the player has TAKEN no longer burns at the 12:00 rollover
//  (2026-09-19, the owner's call). It stays open until it is turned in, and an
//  NPC offers nothing new while one of theirs is open — so there is never more
//  than one open job per NPC, and neither the board, the counters nor the
//  turn-in button ever has to choose between two.
//
//  Under the old rule every taken-but-unfinished job burned at noon, and the
//  database still holds those rows marked `accepted`. Read under the new rule
//  they would all come back at once, so the one-time `CloseBurnedQuestJobs`
//  migration asks `burned(_:today:)` which of them to close. Pure Foundation
//  and here rather than beside the migration so the tests can reach it — the
//  same reason `UkrainianPlural` lives in this module.
//

import Foundation

public enum QuestCarryOver {

    /// One taken-but-unfinished job, as the cleanup sees it.
    public struct OpenJob: Sendable, Equatable {
        public let id: UUID
        public let userId: UUID
        public let npc: String
        public let dayStamp: String

        public init(id: UUID, userId: UUID, npc: String, dayStamp: String) {
            self.id = id
            self.userId = userId
            self.npc = npc
            self.dayStamp = dayStamp
        }
    }

    /// The game day before `stamp` — both are `GameDay.stamp` keys,
    /// `yyyy-MM-dd`. Calendar arithmetic on the DATE, never `now − 24 h`: the
    /// Kyiv game day around a DST switch is 23 or 25 hours long, so an
    /// instant 24 hours back can land two game days away. Nil for a key that
    /// is not a date.
    public static func previousStamp(_ stamp: String) -> String? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: stamp) else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        guard let previous = calendar.date(byAdding: .day, value: -1, to: date) else { return nil }
        return formatter.string(from: previous)
    }

    /// Which open jobs the one-time cleanup closes. Per player and NPC it
    /// keeps the NEWEST open job if it was taken today or yesterday, and closes
    /// every other one: anything older had already burned under the old rule,
    /// and a player holding both yesterday's and today's keeps today's, the
    /// one they took most recently and are working on now.
    public static func burned(_ open: [OpenJob], today: String) -> Set<UUID> {
        let yesterday = previousStamp(today) ?? today
        var closed: Set<UUID> = []
        let byOwner = Dictionary(grouping: open) { "\($0.userId.uuidString)|\($0.npc)" }
        for jobs in byOwner.values {
            // `yyyy-MM-dd` sorts as a string exactly as it does as a date.
            let newestFirst = jobs.sorted { $0.dayStamp > $1.dayStamp }
            for (index, job) in newestFirst.enumerated() {
                let keep = index == 0 && job.dayStamp >= yesterday
                if !keep { closed.insert(job.id) }
            }
        }
        return closed
    }
}
