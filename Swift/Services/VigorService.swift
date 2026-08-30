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

import Foundation

// MARK: - Vigor-draining actions

public enum VigorAction: String, CaseIterable, Sendable {
    case walkRoom
    case walkRoomDoubleSpeed
    /// Used by passive autobattle where each round costs one flat unit
    /// (the player isn't picking actions; the simulation just resolves).
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
        let loss = max(1, Int((Double(user.maxHp) * starvationHPDrainPercent).rounded()))
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
                predictedHP += min(amount, max(0, user.maxHp - user.hp))
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
                user.hp = min(user.maxHp, user.hp + amount)
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
