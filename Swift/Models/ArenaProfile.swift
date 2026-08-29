//
//  ArenaProfile.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 20.07.2026.
//
//  Phase 8.3 — a player's Arena standing. One row per fighter, created lazily
//  the first time they open the Ристалище. Holds the persistent rating (Честь),
//  the win/loss tally, and a per-day fight counter (stamp + count) that gates the
//  daily budget. The live duel itself lives entirely in memory (`ArenaStore`);
//  only the settled outcome touches this row.
//

import Fluent
import Foundation

final public class ArenaProfile: Model, @unchecked Sendable {
    public static let schema = "arena_profiles"

    @ID(key: .id)
    public var id: UUID?

    /// Owner. Unique — one profile per player.
    @Parent(key: "user_id")
    public var user: User

    /// Honor rating (Честь). ELO-style; starts at `ArenaCatalog.startingHonor`.
    @Field(key: "honor")
    public var honor: Int

    @Field(key: "wins")
    public var wins: Int

    @Field(key: "losses")
    public var losses: Int

    /// Number of duels fought today (resets when `fightsDayStamp` rolls over).
    @Field(key: "fights_today")
    public var fightsToday: Int

    /// `yyyy-MM-dd` game-day stamp (rolls at 12:00 Kyiv — see `GameDay`) the
    /// `fightsToday` counter belongs to.
    @Field(key: "fights_day_stamp")
    public var fightsDayStamp: String

    @Timestamp(key: "created_at", on: .create)
    public var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    public var updatedAt: Date?

    public init() {}

    public init(userID: UUID, honor: Int = ArenaCatalog.startingHonor) {
        self.$user.id = userID
        self.honor = honor
        self.wins = 0
        self.losses = 0
        self.fightsToday = 0
        self.fightsDayStamp = ""
    }
}

// MARK: - Read / lifecycle helpers

extension ArenaProfile {
    /// Game-day key used for the daily counter (rolls at 12:00 Kyiv — `GameDay`).
    public static func dayStamp(_ date: Date = Date()) -> String {
        GameDay.stamp(date)
    }

    /// Load (or lazily create) the profile for a user.
    public static func forUser(_ userId: UUID, on db: any Database) async throws -> ArenaProfile {
        if let found = try await ArenaProfile.query(on: db).filter(\.$user.$id, .equal, userId).first() {
            return found
        }
        let fresh = ArenaProfile(userID: userId)
        try await fresh.save(on: db)
        return fresh
    }

    /// Fights already spent today, rolling the counter over on a new day.
    public func fightsSpentToday(now: Date = Date()) -> Int {
        fightsDayStamp == Self.dayStamp(now) ? fightsToday : 0
    }

    /// Record one more completed fight against today's budget.
    public func bumpDailyCounter(now: Date = Date()) {
        let stamp = Self.dayStamp(now)
        if fightsDayStamp == stamp {
            fightsToday += 1
        } else {
            fightsDayStamp = stamp
            fightsToday = 1
        }
    }

    /// The top of the leaderboard, highest Honor first.
    public static func leaderboard(limit: Int, on db: any Database) async throws -> [ArenaProfile] {
        try await ArenaProfile.query(on: db)
            .sort(\.$honor, .descending)
            .range(..<limit)
            .all()
    }
}
