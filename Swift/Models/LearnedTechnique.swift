//
//  LearnedTechnique.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 11.05.2026.
//
//  Phase 5.3e: per-user known-technique set. Each player can learn up to
//  three techniques — one Special Attack, one Special Defense, one Super
//  stance — all tied to their class. The actual mechanics live in
//  `CombatService`; this table only records whether the kind has been
//  unlocked. IDs are class-agnostic (`special_atk` / `special_def` /
//  `super`) because every class has exactly one of each — the user's
//  `characterClass` field resolves which concrete technique fires.
//
//  Unlock flow: player must (1) reach the kind's player-level threshold
//  (8 / 11 / 14) and (2) visit the Training Ground plot at the estate
//  (which itself unlocks at estate T3). Tapping "📖 Learn" in the
//  Training Ground UI calls `add(_:for:on:)`.
//

import Fluent
import Foundation

public final class LearnedTechnique: Model, @unchecked Sendable {
    public static let schema = "learned_techniques"

    @ID(key: .id)
    public var id: UUID?

    @Parent(key: "user_id")
    public var user: User

    /// One of `CombatService.TechniqueKind.rawValue` — `special_atk` /
    /// `special_def` / `super`. Class-agnostic — the user's class
    /// resolves which concrete technique these IDs map to in combat.
    @Field(key: "technique_id")
    public var techniqueId: String

    @Timestamp(key: "learned_at", on: .create)
    public var learnedAt: Date?

    public init() {}

    public init(userID: UUID, techniqueId: String) {
        self.$user.id = userID
        self.techniqueId = techniqueId
    }
}

// MARK: - Helpers

extension LearnedTechnique {
    /// True if the user already knows this technique kind.
    public static func has(_ techniqueId: String, for user: User, on db: any Database) async throws -> Bool {
        guard let userId = user.id else { return false }
        let count = try await LearnedTechnique.query(on: db)
            .filter(\.$user.$id, .equal, userId)
            .filter(\.$techniqueId, .equal, techniqueId)
            .count()
        return count > 0
    }

    /// Add a technique to the user's known set. Idempotent — returns
    /// `false` if the technique was already learned (no row created),
    /// `true` on a fresh add.
    @discardableResult
    public static func add(_ techniqueId: String, for user: User, on db: any Database) async throws -> Bool {
        guard let userId = user.id else { return false }
        if try await has(techniqueId, for: user, on: db) { return false }
        try await LearnedTechnique(userID: userId, techniqueId: techniqueId).save(on: db)
        return true
    }

    /// Set of every technique id the user has learned. Combat UI consults
    /// this set when rendering the `[🪄 Techniques]` submenu — unknown
    /// kinds render with a 🔒 prefix and route to a "learn at Training
    /// Ground" alert instead of executing.
    public static func allIds(for user: User, on db: any Database) async throws -> Set<String> {
        guard let userId = user.id else { return [] }
        let rows = try await LearnedTechnique.query(on: db)
            .filter(\.$user.$id, .equal, userId)
            .all()
        return Set(rows.map { $0.techniqueId })
    }
}
