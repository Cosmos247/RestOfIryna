//
//  QuestProgress.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 23.08.2026.
//
//  Phase 9.2 — one row per (player, NPC, game day). Created lazily, either when
//  the player opens that NPC's quest board or when a gameplay event first ticks
//  the counter. Which job the row belongs to is decided by `QuestCatalog.daily`
//  and copied into `questId` at creation, so a mid-day catalog edit can't swap
//  the job out from under a player who already made progress.
//
//  A row existing does NOT mean the job is running: `accepted` is what starts
//  it, and the player sets that by taking the job at the NPC. Opening the board
//  creates the row so the offer is stable for the day; nothing counts until the
//  job is taken.
//
//  Rows are never deleted — yesterday's row simply stops matching today's
//  stamp. That leaves a cheap, permanent record of completed dailies (useful
//  later for streaks and stats).
//

import Fluent
import Foundation

final public class QuestProgress: Model, @unchecked Sendable {
    public static let schema = "quest_progress"

    @ID(key: .id)
    public var id: UUID?

    @Parent(key: "user_id")
    public var user: User

    /// `QuestNPC` raw value — trader / master / tavern.
    @Field(key: "npc")
    public var npc: String

    /// `QuestDef.id` of the job assigned for this day.
    @Field(key: "quest_id")
    public var questId: String

    /// `yyyy-MM-dd` game-day stamp (rolls at 12:00 Kyiv — see `GameDay`).
    @Field(key: "day_stamp")
    public var dayStamp: String

    /// Units accumulated so far. Counter jobs tick this from gameplay events;
    /// deliver jobs leave it at 0 (their progress is read live from the bag)
    /// and jump straight to the target on turn-in.
    @Field(key: "progress")
    public var progress: Int

    /// The player took the job at the NPC. Nothing counts before this: the
    /// row can exist merely because the board was opened, and a counter event
    /// only ticks a row that was accepted.
    @Field(key: "accepted")
    public var accepted: Bool

    /// Reward taken. Terminal — one payout per NPC per day.
    @Field(key: "claimed")
    public var claimed: Bool

    @Timestamp(key: "created_at", on: .create)
    public var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    public var updatedAt: Date?

    public init() {}

    public init(userID: UUID, npc: QuestNPC, questId: String, dayStamp: String) {
        self.$user.id = userID
        self.npc = npc.rawValue
        self.questId = questId
        self.dayStamp = dayStamp
        self.progress = 0
        self.accepted = false
        self.claimed = false
    }
}

// MARK: - Lookup

extension QuestProgress {
    /// Today's row for this player + NPC, or nil if nothing has touched it yet.
    public static func find(
        userId: UUID,
        npc: QuestNPC,
        stamp: String,
        on db: any Database
    ) async throws -> QuestProgress? {
        try await QuestProgress.query(on: db)
            .filter(\.$user.$id, .equal, userId)
            .filter(\.$npc, .equal, npc.rawValue)
            .filter(\.$dayStamp, .equal, stamp)
            .first()
    }
}
