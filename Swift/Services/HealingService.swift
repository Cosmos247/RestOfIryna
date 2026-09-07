//
//  HealingService.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 22.04.2026.
//
//  Lazy passive HP regeneration (5% of maxHp per minute) while the player is
//  at the estate — outside any expedition (active or passive) and below max
//  HP. Computed on interaction rather than by a background tick: `tick` is
//  called from `RouterStore.process` before every controller dispatch, so
//  the user always sees up-to-date HP in profile / status cards.
//
//  Regen is explicitly PAUSED whenever an `ExplorationState` row exists for
//  the user (either active-mode in progress or passive-mode in flight). The
//  governor is physically in the forest at that point, so no resting-at-home
//  healing should accrue. The caller queries the row once and passes the
//  presence as `inExpedition` to avoid a second DB round-trip per tick.
//
//  Because the tick only runs on an interaction, the two ends of an
//  expedition are stamped explicitly instead: `suspendResting` when one
//  begins and `beginResting` when the player lands back home (walked back,
//  died, a passive report delivered by the scheduler, a travel arrival). A
//  passive run is exactly the case where the player taps nothing from
//  departure to return, so without those two stamps the clock would both
//  bank the whole run as idle time and then start counting only from the
//  first tap after coming home.
//
//  At max HP the clock is pinned to `now` on every tick — without that, if
//  the player took damage hours after reaching full HP, we'd mistakenly
//  credit them for the full idle window.
//

import Fluent
import Foundation

public enum HealingService {
    // `tuning/vigor.json` → `healing`. Resting lives in the vigor table on
    // purpose: HP regen and vigor regen are one recovery model, and splitting
    // them across two files is how the two halves drift apart.

    /// Fraction of `maxHp` restored per minute of eligible idle time.
    public static var regenPerMinute: Double { Catalogs.current.tuningVigor.healing.regenPerMinute }

    /// Cap on elapsed time credited in a single tick, to keep long-offline
    /// players from instantly topping up on their next hello.
    public static var maxIdleMinutes: Double { Catalogs.current.tuningVigor.healing.maxIdleMinutes }

    /// Start the rest clock now, unless it is already running. Call it at the
    /// moment the player lands back at the estate — a passive expedition
    /// finishing in the background, a travel arrival, walking home, dying.
    ///
    /// `tick` clears the clock for as long as an `ExplorationState` row
    /// exists, and it only runs on interaction: without this the stretch
    /// between coming home and the player's next tap heals nothing, because
    /// that tap merely primes a nil clock. Priming only when the clock is nil
    /// is what makes it safe to call from anywhere — a running clock keeps its
    /// accrued time instead of being reset to zero.
    ///
    /// Returns true when it actually started the clock.
    @discardableResult
    public static func beginResting(_ user: User, on db: any Database) async throws -> Bool {
        guard user.lastHpTickAt == nil else { return false }
        user.lastHpTickAt = Date()
        try await user.saveAndCache(in: db)
        return true
    }

    /// Stop the rest clock. Call it when an expedition begins, so the stretch
    /// spent out on the trail cannot be credited later.
    ///
    /// `tick` does the same thing, but only on an interaction — and a passive
    /// expedition is precisely the case where the player taps nothing between
    /// leaving and coming back, which would leave the pre-departure stamp
    /// standing and refund the whole run's damage on their next tap.
    @discardableResult
    public static func suspendResting(_ user: User, on db: any Database) async throws -> Bool {
        guard user.lastHpTickAt != nil else { return false }
        user.lastHpTickAt = nil
        try await user.saveAndCache(in: db)
        return true
    }

    /// Apply idle-time HP regen. Writes the user back (via `saveAndCache`)
    /// whenever a field is touched. Returns amount of HP restored (0 if the
    /// player is exploring, already full, or not enough minutes have elapsed
    /// to round to a whole HP).
    ///
    /// `inExpedition` — true when the user has an `ExplorationState` row
    /// (active or passive). Regen is fully suspended in that case because
    /// the governor is out in the wilderness, not resting at the manor.
    @discardableResult
    public static func tick(_ user: User, inExpedition: Bool, on db: any Database) async throws -> Int {
        let now = Date()

        // Suspend regen during expedition — clear the clock so banked idle
        // time from before the expedition can't leak through.
        if inExpedition {
            if user.lastHpTickAt != nil {
                user.lastHpTickAt = nil
                try await user.saveAndCache(in: db)
            }
            return 0
        }

        // Full HP — pin the clock to `now` to prevent banked regen piling
        // up against future damage.
        if user.hp >= user.effectiveMaxHp {
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
        let restored = Int((Double(user.effectiveMaxHp) * regenPerMinute * minutes).rounded(.down))

        // Too few minutes to round up to 1 HP — keep the old timestamp so
        // partial elapsed time isn't lost.
        guard restored > 0 else { return 0 }

        user.hp = min(user.effectiveMaxHp, user.hp + restored)
        user.lastHpTickAt = now
        try await user.saveAndCache(in: db)
        return restored
    }
}
