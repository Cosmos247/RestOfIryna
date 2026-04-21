//
//  HungerService.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 20.04.2026.
//
//  Pure functions for the hunger system. Callers (exploration, combat, inventory)
//  invoke drain/consume and are responsible for persisting the user. No DB writes
//  happen here.
//
//  Values tagged ⚙️ TBD are initial GDD values and will be tuned later.
//

import Foundation

// MARK: - Hunger-draining actions

public enum HungerAction: Sendable {
    case walkRoom
    case walkRoomDoubleSpeed
    case combatRound
    case idle
}

// MARK: - Consume result

public struct ConsumeResult: Sendable {
    public let hungerRestored: Int
    public let hpRestored: Int
}

// MARK: - Service

public enum HungerService {

    // Drain costs per action (⚙️ TBD — values from GDD §4)
    public static let drainWalkRoom: Int = 2
    public static let drainWalkRoomDoubleSpeed: Int = 4
    public static let drainCombatRound: Int = 1

    // Starvation penalties (⚙️ TBD — values from GDD §4)
    /// Fraction subtracted from Attack and Defense while starving (0.25 = -25%).
    public static let starvationStatPenalty: Double = 0.25
    /// Fraction of max HP lost per room transition while starving (0.05 = 5%).
    public static let starvationHPDrainPercent: Double = 0.05

    // MARK: - Queries

    public static func isStarving(_ user: User) -> Bool {
        return user.hunger <= 0
    }

    /// Hunger cost for the given action. Pure — does not mutate.
    public static func cost(of action: HungerAction) -> Int {
        switch action {
        case .walkRoom:             return drainWalkRoom
        case .walkRoomDoubleSpeed:  return drainWalkRoomDoubleSpeed
        case .combatRound:          return drainCombatRound
        case .idle:                 return 0
        }
    }

    // MARK: - Drain

    /// Drain hunger on the user for a given action. Clamps to 0. Mutates — caller must save.
    /// Returns the amount actually drained.
    @discardableResult
    public static func drain(_ user: User, action: HungerAction) -> Int {
        return drain(user, amount: cost(of: action))
    }

    /// Drain an explicit amount. Used by dev tools (/drain) and any caller that wants
    /// finer control than the enum provides.
    @discardableResult
    public static func drain(_ user: User, amount: Int) -> Int {
        guard amount > 0 else { return 0 }
        let before = user.hunger
        user.hunger = max(0, user.hunger - amount)
        return before - user.hunger
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
        var predictedHunger = 0
        var predictedHP = 0
        for effect in item.effects {
            switch effect {
            case .restoreHunger(let amount):
                predictedHunger += min(amount, max(0, user.maxHunger - user.hunger))
            case .restoreHP(let amount):
                predictedHP += min(amount, max(0, user.maxHp - user.hp))
            }
        }
        guard predictedHunger > 0 || predictedHP > 0 else { return nil }

        var hungerRestored = 0
        var hpRestored = 0
        for effect in item.effects {
            switch effect {
            case .restoreHunger(let amount):
                let before = user.hunger
                user.hunger = min(user.maxHunger, user.hunger + amount)
                hungerRestored += user.hunger - before
            case .restoreHP(let amount):
                let before = user.hp
                user.hp = min(user.maxHp, user.hp + amount)
                hpRestored += user.hp - before
            }
        }
        return ConsumeResult(hungerRestored: hungerRestored, hpRestored: hpRestored)
    }

    /// True if this item type can be used by the player via "Use" buttons.
    public static func isConsumable(_ item: Item) -> Bool {
        return item.type == .food || item.type == .potion
    }
}

// MARK: - Effective stats on User

extension User {
    /// Attack after all active modifiers: base + equipped gear − starvation penalty.
    public var effectiveAttack: Int {
        return Self.applyHungerPenalty(base: attack + gearAttackBonus, user: self)
    }

    /// Defense after all active modifiers: base + equipped gear − starvation penalty.
    public var effectiveDefense: Int {
        return Self.applyHungerPenalty(base: defense + gearDefenseBonus, user: self)
    }

    /// Crit / Dodge / Accuracy aren't affected by hunger in v1; gear still layers in.
    public var effectiveCrit: Int     { return crit + gearCritBonus }
    public var effectiveDodge: Int    { return dodge + gearDodgeBonus }
    public var effectiveAccuracy: Int { return accuracy + gearAccuracyBonus }

    private static func applyHungerPenalty(base: Int, user: User) -> Int {
        guard HungerService.isStarving(user) else { return base }
        let penalised = Double(base) * (1.0 - HungerService.starvationStatPenalty)
        return max(1, Int(penalised.rounded()))
    }
}
