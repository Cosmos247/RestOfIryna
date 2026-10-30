//
//  EventBlood.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 29.10.2026.
//
//  The blood a player has carried out of a holiday's manor — the flask
//  (`content/spec/event-veles-night.md`). One row per player per holiday, made
//  empty when the scribe hands the flask over in the palace (2026-10-30: the
//  flask is collected in person, and the gate refuses a walk without it), so
//  the row IS the flask. Not the bag, so a death leaves it alone; the blood
//  board (`LeaderboardBoard.blood`) and the finale read it, and both skip an
//  empty flask.
//
//  `event_id` is history, like `fight_log.enemy_id`: deliberately NOT in
//  `LiveReferenceQuery`, so a holiday dropped from `events.json` never blocks a
//  `/reload` with its old board.
//

import Fluent
import Foundation

public final class EventBlood: Model, @unchecked Sendable {
    public static let schema = "event_blood"

    @ID(key: .id)
    public var id: UUID?

    @Parent(key: "user_id")
    public var user: User

    @Field(key: "event_id")
    public var eventId: String

    @Field(key: "total")
    public var total: Int

    @Timestamp(key: "created_at", on: .create)
    public var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    public var updatedAt: Date?

    public init() {}

    public init(userId: UUID, eventId: String, total: Int) {
        self.$user.id = userId
        self.eventId = eventId
        self.total = total
    }

    /// The player's flask for `eventId`, 0 when they have none yet.
    public static func total(for user: User, eventId: String, on db: any Database) async throws -> Int {
        guard let userId = user.id else { return 0 }
        return try await EventBlood.query(on: db)
            .filter(\.$user.$id == userId)
            .filter(\.$eventId == eventId)
            .first()?.total ?? 0
    }

    /// Whether the player has taken this holiday's flask from the scribe.
    public static func hasFlask(_ user: User, eventId: String, on db: any Database) async throws -> Bool {
        guard let userId = user.id else { return false }
        return try await EventBlood.query(on: db)
            .filter(\.$user.$id == userId)
            .filter(\.$eventId == eventId)
            .first() != nil
    }

    /// The scribe hands the flask over: an empty row. False when the player
    /// already had it — a second «🩸 Взяти флягу» under a repeated reveal.
    @discardableResult
    public static func issueFlask(to user: User, eventId: String, on db: any Database) async throws -> Bool {
        guard let userId = user.id else { return false }
        if try await hasFlask(user, eventId: eventId, on: db) { return false }
        do {
            try await EventBlood(userId: userId, eventId: eventId, total: 0).save(on: db)
            return true
        } catch {
            // The unique index (`user_id`, `event_id`) refused a row another
            // write made in between: the flask is there, which is the answer.
            if try await hasFlask(user, eventId: eventId, on: db) { return false }
            throw error
        }
    }

    /// Pour `amount` into the player's flask and return the new total. One row
    /// per player per holiday (a unique index); a pour into a flask that was
    /// never issued still makes the row, because a pour must never lose blood.
    @discardableResult
    public static func pour(_ amount: Int, for user: User, eventId: String, on db: any Database) async throws -> Int {
        guard let userId = user.id else { return 0 }
        if let row = try await EventBlood.query(on: db)
            .filter(\.$user.$id == userId)
            .filter(\.$eventId == eventId)
            .first() {
            row.total += amount
            try await row.save(on: db)
            return row.total
        }
        let row = EventBlood(userId: userId, eventId: eventId, total: amount)
        try await row.save(on: db)
        return row.total
    }
}

/// One holiday notice sent to one player (`event_notices`), written before the
/// push so the watchman sends each notice once.
public final class EventNoticeLog: Model, @unchecked Sendable {
    public static let schema = "event_notices"

    @ID(key: .id)
    public var id: UUID?

    @Parent(key: "user_id")
    public var user: User

    @Field(key: "event_id")
    public var eventId: String

    @Field(key: "notice_id")
    public var noticeId: String

    @Timestamp(key: "created_at", on: .create)
    public var createdAt: Date?

    public init() {}

    public init(userId: UUID, eventId: String, noticeId: String) {
        self.$user.id = userId
        self.eventId = eventId
        self.noticeId = noticeId
    }
}
