//
//  VigorService.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 20.04.2026.
//
//  Pure functions for the vigor system (player's "satiety" meter — formerly
//  named "hunger"; the underlying DB column is still `hunger` to avoid a
//  destructive rename migration). Callers (exploration, combat, inventory)
//  invoke drain/consume and are responsible for persisting the user. No DB
//  writes happen here.
//
//  Values tagged ⚙️ TBD are initial GDD values and will be tuned later.
//

import Fluent
import Foundation

// MARK: - Vigor-draining actions

public enum VigorAction: String, CaseIterable, Sendable {
    case walkRoom
    case walkRoomDoubleSpeed
    /// Used by passive autobattle, where the player picks no actions and the
    /// simulation just resolves. Priced at PARITY with an active attack since
    /// Phase 5D: charging less was half of why the unattended mode measured
    /// 53% more efficient than the one that needs a human.
    case combatRound
    /// Active CombatController per-action costs (Phase 4.1).
    case combatAttack
    case combatDefend
    case combatFlee
    case idle
}

// MARK: - Consume result

public struct ConsumeResult: Sendable {
    public let vigorRestored: Int
    public let hpRestored: Int
}

// MARK: - Service

public enum VigorService {

    // Drain costs per action — `tuning/vigor.json`. Computed `var`s, never
    // `static let`: a `static let` reading `Catalogs.current` runs at type-init,
    // before `ContentBootstrap.load`.
    public static var drainWalkRoom: Int { Catalogs.current.tuningVigor.drain.walkRoom }
    public static var drainWalkRoomDoubleSpeed: Int { Catalogs.current.tuningVigor.drain.walkRoomDoubleSpeed }
    public static var drainCombatRound: Int { Catalogs.current.tuningVigor.drain.combatRound }
    /// The tap governor as much as a cost: at level 40 this is what keeps a day
    /// of combat inside a human number of button presses. Not to be lowered
    /// "for convenience" without re-checking the taps-per-day budget.
    public static var drainCombatAttack: Int { Catalogs.current.tuningVigor.drain.combatAttack }
    public static var drainCombatDefend: Int { Catalogs.current.tuningVigor.drain.combatDefend }
    public static var drainCombatFlee: Int { Catalogs.current.tuningVigor.drain.combatFlee }

    /// Fraction subtracted from Attack and Defense while starving (0.25 = -25%).
    public static var starvationStatPenalty: Double { Catalogs.current.tuningVigor.starvation.statPenalty }
    /// Fraction of max HP lost per room transition while starving (0.05 = 5%).
    public static var starvationHPDrainPercent: Double { Catalogs.current.tuningVigor.starvation.hpDrainPercent }

    // MARK: - Regeneration (Phase 5B)

    /// Vigor restored per minute of elapsed wall-clock time: the whole pool
    /// over `fullRegenHours`.
    ///
    /// Scaling with `maxVigor` rather than being a flat number per hour is the
    /// point — a flat rate shrinks, as a share of the pool, every time the pool
    /// grows, and by the level cap the player would be recovering 2.7% an hour
    /// instead of the 16.7% they started with.
    public static func regenPerMinute(for user: User) -> Double {
        let hours = Catalogs.current.tuningProgression.vigorPool.fullRegenHours
        guard hours > 0 else { return 0 }
        return Double(user.maxVigor) / (hours * 60)
    }

    /// Credit idle time as Vigor. Mirrors `HealingService.tick`, with one
    /// deliberate difference: it is NOT suspended during an expedition.
    ///
    /// HP regen pauses out in the wilderness because resting is something you
    /// do at the manor. Vigor is stamina, it is *spent* by walking and fighting,
    /// and a trickle while the governor catches their breath is exactly the
    /// mechanic — suspending it would make the pool strictly a pre-expedition
    /// budget and delete the "wait a bit, then push deeper" decision.
    ///
    /// Returns the amount actually restored. Writes the user only when
    /// something changed.
    @discardableResult
    public static func regenTick(_ user: User, on db: any Database) async throws -> Int {
        let now = Date()

        // Full pool — pin the clock so idle time cannot bank against future
        // spending. Same guard `HealingService` needs, same reason.
        if user.vigor >= user.maxVigor {
            if user.lastVigorTickAt != now {
                user.lastVigorTickAt = now
                try await user.saveAndCache(in: db)
            }
            return 0
        }

        // First observation on a drained pool primes the clock and grants
        // nothing: a row that predates the column must not pay out months.
        guard let last = user.lastVigorTickAt else {
            user.lastVigorTickAt = now
            try await user.saveAndCache(in: db)
            return 0
        }

        let minutes = max(0, now.timeIntervalSince(last) / 60.0)
        let restored = Int((regenPerMinute(for: user) * minutes).rounded(.down))
        // Not enough elapsed time to round up to a whole point — keep the old
        // timestamp so the partial minutes are not thrown away.
        guard restored > 0 else { return 0 }

        user.vigor = min(user.maxVigor, user.vigor + restored)
        user.lastVigorTickAt = now
        try await user.saveAndCache(in: db)
        return restored
    }

    // MARK: - Queries

    public static func isStarving(_ user: User) -> Bool {
        return user.vigor <= 0
    }

    /// Vigor cost for the given action. Pure — does not mutate.
    public static func cost(of action: VigorAction) -> Int {
        switch action {
        case .walkRoom:             return drainWalkRoom
        case .walkRoomDoubleSpeed:  return drainWalkRoomDoubleSpeed
        case .combatRound:          return drainCombatRound
        case .combatAttack:         return drainCombatAttack
        case .combatDefend:         return drainCombatDefend
        case .combatFlee:           return drainCombatFlee
        case .idle:                 return Catalogs.current.tuningVigor.drain.idle
        }
    }

    // MARK: - Drain

    /// Drain vigor on the user for a given action. Clamps to 0. Mutates — caller must save.
    /// Returns the amount actually drained. The optional `multiplier` is used by
    /// stance buffs (e.g. Bloodlust ×2) — the action's base cost is scaled and
    /// rounded before the actual drain is applied.
    @discardableResult
    public static func drain(_ user: User, action: VigorAction, multiplier: Double = 1.0) -> Int {
        // Phase 6.4 — compose the active fortune's vigor-drain multiplier
        // (default 1.0) with the caller-supplied stance multiplier.
        // Chariot's −25% / Hanged Man's −50% reduce drain; Devil's ×1.5
        // increases it. Drain values pre-fortune are visible through the
        // stance multiplier alone, so combat stance + fortune compose
        // multiplicatively.
        let fortuneMult = user.activeFortuneEffect?.vigorDrainMultiplier ?? 1.0
        let scaled = Double(cost(of: action)) * max(0.0, multiplier) * max(0.0, fortuneMult)
        return drain(user, amount: Int(scaled.rounded()))
    }

    /// Drain an explicit amount. Used by dev tools (/drain) and any caller that wants
    /// finer control than the enum provides.
    @discardableResult
    public static func drain(_ user: User, amount: Int) -> Int {
        guard amount > 0 else { return 0 }
        let before = user.vigor
        user.vigor = max(0, user.vigor - amount)
        return before - user.vigor
    }

    // MARK: - Starvation HP loss

    /// Apply starvation HP loss for a single room transition. Returns amount of HP lost.
    /// No-op if not starving. Clamps HP to 0. Mutates — caller must save.
    @discardableResult
    public static func applyStarvationHPLoss(_ user: User) -> Int {
        guard isStarving(user) else { return 0 }
        let loss = max(1, Int((Double(user.effectiveMaxHp) * starvationHPDrainPercent).rounded()))
        let before = user.hp
        user.hp = max(0, user.hp - loss)
        return before - user.hp
    }

    // MARK: - Food / Potion consumption

    /// Consume an item's effects. Returns the result, or nil if every effect would be
    /// fully wasted (user already at cap for each restore type). Mutates user; caller
    /// must remove the item from inventory and save.
    public static func consume(_ item: Item, user: User) -> ConsumeResult? {
        // Predict to reject fully wasted consumption
        var predictedVigor = 0
        var predictedHP = 0
        for effect in item.effects {
            switch effect {
            case .restoreVigor(let amount):
                predictedVigor += min(amount, max(0, user.maxVigor - user.vigor))
            case .restoreHP(let amount):
                predictedHP += min(amount, max(0, user.effectiveMaxHp - user.hp))
            }
        }
        guard predictedVigor > 0 || predictedHP > 0 else { return nil }

        var vigorRestored = 0
        var hpRestored = 0
        for effect in item.effects {
            switch effect {
            case .restoreVigor(let amount):
                let before = user.vigor
                user.vigor = min(user.maxVigor, user.vigor + amount)
                vigorRestored += user.vigor - before
            case .restoreHP(let amount):
                let before = user.hp
                user.hp = min(user.effectiveMaxHp, user.hp + amount)
                hpRestored += user.hp - before
            }
        }
        return ConsumeResult(vigorRestored: vigorRestored, hpRestored: hpRestored)
    }

    /// True if this item type can be used by the player via "Use" buttons.
    public static func isConsumable(_ item: Item) -> Bool {
        return item.type == .food || item.type == .potion
    }
}

// MARK: - Effective stats on User

extension User {
    /// Attack after all active modifiers: base + equipped gear − starvation
    /// penalty + active fortune bonus (Phase 6.4, can be negative).
    /// Max HP after equipped gear. Unlike the other five, this one is NOT
    /// touched by the starvation penalty: hunger saps how hard you hit and how
    /// well you guard, not how much blood you have.
    public var effectiveMaxHp: Int {
        Swift.max(1, maxHp + gearHpBonus)
    }

    public var effectiveAttack: Int {
        let fortune = activeFortuneEffect?.attackBonus ?? 0
        return Self.applyVigorPenalty(base: attack + gearAttackBonus + fortune, user: self)
    }

    /// Defense after all active modifiers: base + equipped gear − starvation
    /// penalty + active fortune bonus.
    public var effectiveDefense: Int {
        let fortune = activeFortuneEffect?.defenseBonus ?? 0
        return Self.applyVigorPenalty(base: defense + gearDefenseBonus + fortune, user: self)
    }

    /// Crit / Dodge / Accuracy aren't affected by vigor in v1; gear +
    /// active fortune layer in.
    public var effectiveCrit: Int {
        return crit + gearCritBonus + (activeFortuneEffect?.critBonus ?? 0)
    }
    public var effectiveDodge: Int {
        return dodge + gearDodgeBonus + (activeFortuneEffect?.dodgeBonus ?? 0)
    }
    public var effectiveAccuracy: Int {
        return accuracy + gearAccuracyBonus + (activeFortuneEffect?.accuracyBonus ?? 0)
    }

    private static func applyVigorPenalty(base: Int, user: User) -> Int {
        guard VigorService.isStarving(user) else { return base }
        let penalised = Double(base) * (1.0 - VigorService.starvationStatPenalty)
        return max(1, Int(penalised.rounded()))
    }
}
