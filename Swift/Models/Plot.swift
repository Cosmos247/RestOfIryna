//
//  Plot.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 29.04.2026.
//
//  Phase 5.1: per-user estate plot. One row per claimed slot. Production is
//  derived lazily from `lastHarvestedAt + ratePerSecond × elapsed` (capped),
//  so we never store an accumulator that could drift. The `notifiedFull`
//  flag stops the background ticker from spamming the same "ready to
//  harvest" push every minute once a plot reaches its cap; it's reset on
//  harvest.
//

import Fluent
import Foundation

public final class Plot: Model, @unchecked Sendable {
    public static let schema = "plots"

    @ID(key: .id)
    public var id: UUID?

    @Parent(key: "user_id")
    public var user: User

    /// Stable per-user index. Slot count is gated on `User.estateLevel` —
    /// see `PlotService.slotsForLevel(_:)`. Slots are addressed 0-based.
    @Field(key: "slot_index")
    public var slotIndex: Int

    /// Maps to a `PlotType` enum raw value (`farm` / `forest` / `mine` / `coop`).
    @Field(key: "plot_type")
    public var plotType: String

    /// 1 at MVP; future tier upgrades will scale rate / cap.
    @Field(key: "tier")
    public var tier: Int

    /// Production accumulates from this timestamp. Reset to "now" on harvest.
    @Field(key: "last_harvested_at")
    public var lastHarvestedAt: Date

    /// Set true by the background ticker when this plot first reaches its
    /// cap; reset to false on harvest. Prevents repeat "ready" notifications.
    @Field(key: "notified_full")
    public var notifiedFull: Bool

    @Timestamp(key: "created_at", on: .create)
    public var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    public var updatedAt: Date?

    public init() {}

    public init(userID: UUID, slotIndex: Int, plotType: String, tier: Int = 1, lastHarvestedAt: Date = Date()) {
        self.$user.id = userID
        self.slotIndex = slotIndex
        self.plotType = plotType
        self.tier = tier
        self.lastHarvestedAt = lastHarvestedAt
        self.notifiedFull = false
    }
}

// MARK: - Queries

extension Plot {
    /// All plots a user owns, sorted by slot index.
    public static func list(for user: User, on db: any Database) async throws -> [Plot] {
        guard let userId = user.id else { return [] }
        return try await Plot.query(on: db)
            .filter(\.$user.$id, .equal, userId)
            .sort(\.$slotIndex, .ascending)
            .all()
    }

    /// Lookup by slot. Used to validate a tap targets an actually-claimed slot.
    public static func find(slot: Int, for user: User, on db: any Database) async throws -> Plot? {
        guard let userId = user.id else { return nil }
        return try await Plot.query(on: db)
            .filter(\.$user.$id, .equal, userId)
            .filter(\.$slotIndex, .equal, slot)
            .first()
    }

    /// Cross-player query used by the background production ticker — returns
    /// every plot whose `notifiedFull` is still false. Plots already marked
    /// full are excluded so the ticker stays cheap as the playerbase grows.
    public static func allUnfull(on db: any Database) async throws -> [Plot] {
        return try await Plot.query(on: db)
            .filter(\.$notifiedFull, .equal, false)
            .with(\.$user)
            .all()
    }
}
