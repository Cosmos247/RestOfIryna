//
//  TravelState.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 16.05.2026.
//
//  Phase 6.0 — the player is on the road between estate and capital.
//  Presence of a row = en route. Single direction per row, flipping
//  `User.location` to `destination` on arrival. `TravelService` owns the
//  background timer; this file only carries the model and basic helpers.
//

import Fluent
import Foundation

/// Where the traveller is heading. `User.location` flips to this value when
/// the timer elapses.
public enum TravelDestination: String, Sendable {
    case capital
    case estate
}

final public class TravelState: Model, @unchecked Sendable {
    public static let schema = "travel_state"

    @ID(key: .id)
    public var id: UUID?

    @Parent(key: "user_id")
    public var user: User

    @Field(key: "destination")
    public var destinationRaw: String

    @Field(key: "ends_at")
    public var endsAt: Date

    /// The whole crossing this trip was set out on, in wall-clock seconds —
    /// 2 min on the road's own, 3 with a hired wagon (2026-11-08). Stamped at
    /// the start and carried by every turn-back leg, so a hire that ends on the
    /// way or a `/reload` never reshapes a trip in flight, and a turn-back is
    /// measured against the road the player is actually on. Nil on a row from
    /// before the stamp: the road's own crossing.
    @OptionalField(key: "crossing_seconds")
    public var crossingSeconds: Double?

    @Timestamp(key: "created_at", on: .create)
    public var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    public var updatedAt: Date?

    public init() {}

    public init(userID: UUID, destination: TravelDestination, endsAt: Date, crossingSeconds: Double? = nil) {
        self.$user.id = userID
        self.destinationRaw = destination.rawValue
        self.endsAt = endsAt
        self.crossingSeconds = crossingSeconds
    }
}

extension TravelState {
    public var destination: TravelDestination {
        get { TravelDestination(rawValue: destinationRaw) ?? .capital }
        set { destinationRaw = newValue.rawValue }
    }

    /// Seconds remaining until arrival. Clamped to 0 once past due.
    public func secondsRemaining(now: Date = Date()) -> Int {
        return max(0, Int(endsAt.timeIntervalSince(now).rounded()))
    }
}

extension TravelState {
    /// Fetch the user's in-flight travel, or nil if they're stationary.
    public static func current(for user: User, on db: any Database) async throws -> TravelState? {
        guard let userId = user.id else { return nil }
        return try await TravelState.query(on: db)
            .filter(\.$user.$id, .equal, userId)
            .first()
    }

    /// Create and persist a fresh trip. Replaces any stale row (shouldn't
    /// exist, but stays defensive — same idiom as `ExplorationState.begin`).
    @discardableResult
    public static func begin(
        for user: User,
        destination: TravelDestination,
        endsAt: Date,
        crossingSeconds: Double? = nil,
        on db: any Database
    ) async throws -> TravelState {
        guard let userId = user.id else { throw FluentError.idRequired }
        if let existing = try await current(for: user, on: db) {
            try await existing.delete(on: db)
        }
        let state = TravelState(userID: userId, destination: destination, endsAt: endsAt, crossingSeconds: crossingSeconds)
        try await state.save(on: db)
        return state
    }

    /// End the user's trip. No-op if no row.
    public static func end(for user: User, on db: any Database) async throws {
        if let state = try await current(for: user, on: db) {
            try await state.delete(on: db)
        }
    }

    /// Every in-flight trip — used by the startup rescheduler to re-arm
    /// timers across bot restarts.
    public static func allInflight(on db: any Database) async throws -> [TravelState] {
        return try await TravelState.query(on: db).all()
    }
}
