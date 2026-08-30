//
//  CombatantStats.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 30.08.2026.
//
//  One side of a fight, as plain numbers.
//
//  The value that unblocks the simulator. Before Phase 8 a swing was rolled
//  from a Fluent `User` and a domain `Enemy`, both of which live in the game
//  target — so the only way to measure a fight was to boot the bot against a
//  database. `CombatantStats` is what `CombatMath` actually needs: eight
//  integers, no identity, no persistence, `Sendable` and cheap to copy a
//  million times.
//
//  It is deliberately NOT a view onto `User`. Every call site in the game
//  already feeds `applyAttack` numbers that no character actually has — a
//  bloodlust-buffed ATK, an armour-broken enemy DEF, an archer's zeroed dodge —
//  so the struct describes "the stats this particular swing sees", which is
//  also exactly what a simulator wants to sweep.
//

import Foundation

public struct CombatantStats: Sendable, Equatable {
    /// Drives every curve denominator, `levelDiff`, and XP. Both sides carry
    /// their own: a rating is read at the level of whoever owns it.
    public var level: Int
    public var maxHP: Int
    public var hp: Int
    public var attack: Int
    public var defense: Int
    /// Ratings, not percentages — they go through `CombatMath`'s curves.
    public var crit: Int
    public var dodge: Int
    public var accuracy: Int

    /// `hp` defaults to `maxHP`, so a freshly built combatant is at full
    /// health; a swing-only construction leaves both at 0 and never reads them.
    public init(level: Int = 1, maxHP: Int = 0, hp: Int? = nil, attack: Int = 0,
                defense: Int = 0, crit: Int = 0, dodge: Int = 0, accuracy: Int = 0) {
        self.level = level
        self.maxHP = maxHP
        self.hp = hp ?? maxHP
        self.attack = attack
        self.defense = defense
        self.crit = crit
        self.dodge = dodge
        self.accuracy = accuracy
    }

    public var isAlive: Bool { hp > 0 }

    /// Subtract damage, floored at zero. Returns the amount actually taken,
    /// which is what an HP-loss distribution has to be built from — a killing
    /// blow for 40 against 12 remaining HP costs the player 12, not 40.
    @discardableResult
    public mutating func take(_ damage: Int) -> Int {
        let taken = Swift.min(Swift.max(0, damage), Swift.max(0, hp))
        hp -= taken
        return taken
    }
}
