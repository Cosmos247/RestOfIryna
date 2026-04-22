//
//  HealingService.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 22.04.2026.
//
//  Lazy passive HP regeneration (5% of maxHp per minute) while the player is
//  at the estate — outside any active expedition and below max HP. Computed
//  on interaction rather than by a background tick: `tick(user:on:)` is called
//  from `RouterStore.process` before every controller dispatch, so the user
//  always sees up-to-date HP in profile / status cards.
//
//  Regen is explicitly PAUSED during expeditions: the `last_hp_tick_at`
//  column is cleared while `routerName == "exploration"`, so idle time from
//  before the expedition can't cascade into free healing once the player
//  returns home.
//
//  At max HP the clock is pinned to `now` on every tick — without that, if
//  the player took damage hours after reaching full HP, we'd mistakenly
//  credit them for the full idle window.
//

import Fluent
import Foundation

public enum HealingService {
    /// Fraction of `maxHp` restored per minute of eligible idle time.
    public static let regenPerMinute: Double = 0.05

    /// Cap on elapsed time credited in a single tick, to keep long-offline
    /// players from instantly topping up on their next hello.
    public static let maxIdleMinutes: Double = 60 * 24

    /// Apply idle-time HP regen. Writes the user back (via `saveAndCache`)
    /// whenever a field is touched. Returns amount of HP restored (0 if the
    /// player is exploring, already full, or not enough minutes have elapsed
    /// to round to a whole HP).
    @discardableResult
    public static func tick(_ user: User, on db: any Database) async throws -> Int {
        let now = Date()

        // Suspend regen during expedition — clear the clock so banked idle
        // time from before the expedition can't leak through.
        if user.routerName == "exploration" {
            if user.lastHpTickAt != nil {
                user.lastHpTickAt = nil
                try await user.saveAndCache(in: db)
            }
            return 0
        }

        // Full HP — pin the clock to `now` to prevent banked regen piling
        // up against future damage.
        if user.hp >= user.maxHp {
            user.lastHpTickAt = now
            try await user.saveAndCache(in: db)
            return 0
        }

        // First damaged observation — prime the clock, no regen yet.
        guard let last = user.lastHpTickAt else {
            user.lastHpTickAt = now
            try await user.saveAndCache(in: db)
            return 0
        }

        let minutes = min(maxIdleMinutes, now.timeIntervalSince(last) / 60.0)
        let restored = Int((Double(user.maxHp) * regenPerMinute * minutes).rounded(.down))

        // Too few minutes to round up to 1 HP — keep the old timestamp so
        // partial elapsed time isn't lost.
        guard restored > 0 else { return 0 }

        user.hp = min(user.maxHp, user.hp + restored)
        user.lastHpTickAt = now
        try await user.saveAndCache(in: db)
        return restored
    }
}
