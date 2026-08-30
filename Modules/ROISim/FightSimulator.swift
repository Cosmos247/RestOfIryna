//
//  FightSimulator.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 30.08.2026.
//
//  One fight, rolled the way the game rolls it.
//
//  Every swing goes through `CombatMath.applyAttack`, which is the function the
//  bot calls — so this is not a model of combat, it IS combat with a seeded
//  generator in place of the system one. What the file adds is the round
//  structure the controller owns: who swings first, when a burn ticks, when a
//  stance expires, and what an action costs in Vigor.
//
//  The round order is copied from `CombatController.finishRound` and it
//  matters:
//
//      player swing (armour break, if up, is already applied)
//        → enemy dies? victory, no counter
//      enemy counter
//      burn tick — can kill, and absorption never touches it
//      stance tick, then defence-effect tick
//      player dead? defeat
//
//  Super activation is a FREE action in the shipped controller — it stamps the
//  stance and returns without calling `finishRound`, so the enemy does not get
//  a counter for it. That is modelled, not smoothed over: it is worth real
//  damage and the balance report would be wrong without it.
//
//  Special DEFENCE is not modelled. It is a reactive choice whose value depends
//  on a policy ("defend when the next hit could kill me") that no table
//  states — inventing one would put a number in the report that no design
//  document backs. Its absence makes both profiles a LOWER bound on player
//  power, which is the safe direction for a balance floor.
//

import Foundation
import ROIContent

public enum PlayerProfile: String, Sendable, CaseIterable {
    /// Attack every round, no techniques. Exactly what the passive autobattle
    /// does — so this row is the unattended expedition's true difficulty.
    case basic
    /// Super on the opening action, then Special Attack while uses remain,
    /// then basic attacks. The ceiling a player who knows the kit reaches.
    case techniques
}

public struct FightOutcome: Sendable {
    public let won: Bool
    public let rounds: Int
    public let hpLost: Int
    public let hpLostPercent: Double
    public let vigorSpent: Int
    /// True when the safety cap stopped the fight rather than a death. A
    /// stalemate is neither a win nor an honest loss and has to be visible:
    /// it means someone's damage cannot outpace the other's health at all.
    public let stalemate: Bool
}

public struct FightSimulator: Sendable {
    public let rules: CombatRules
    public let combat: CombatTuningDTO
    public let drain: VigorDrainDTO
    /// Matches `ExplorationService.resolveAutobattle`'s safety cap.
    public let maxRounds: Int

    private let techniques: [String: TechniqueTuningDTO]
    private let stanceByClass: [String: StanceTuningDTO]
    private let specialByClass: [String: SpecialAttackTuningDTO]

    public init(combat: CombatTuningDTO, vigor: VigorTuningDTO, maxRounds: Int = 50) {
        self.rules = CombatRules(combat)
        self.combat = combat
        self.drain = vigor.drain
        self.maxRounds = maxRounds
        self.techniques = Dictionary(combat.techniques.map { ($0.kind, $0) },
                                     uniquingKeysWith: { first, _ in first })
        self.stanceByClass = Dictionary(combat.stances.byId.map { ($0.characterClass, $0) },
                                        uniquingKeysWith: { first, _ in first })
        self.specialByClass = Dictionary(combat.specialAttack.map { ($0.characterClass, $0) },
                                         uniquingKeysWith: { first, _ in first })
    }

    /// Per-fight uses of a technique kind at a level: none before the unlock,
    /// one until `secondUseAtLevel`, two after.
    private func uses(_ kind: String, level: Int) -> Int {
        guard let row = techniques[kind], level >= row.requiredLevel else { return 0 }
        return level >= row.secondUseAtLevel ? 2 : 1
    }

    public func fight<G: RandomNumberGenerator>(
        player: CombatantStats,
        characterClass: String,
        enemy: CombatantStats,
        profile: PlayerProfile,
        using rng: inout G
    ) -> FightOutcome {
        var p = player
        var e = enemy
        let startHP = p.hp
        var vigorSpent = 0
        var rounds = 0

        var stance: StanceTuningDTO?
        var stanceRoundsLeft = 0
        var burnRounds = 0
        var burnDamage = 0
        var defDebuffRounds = 0
        var specialUses = profile == .techniques ? uses("special_atk", level: p.level) : 0

        // Opening: raise the stance. Free of a counter, but not of Vigor.
        if profile == .techniques, uses("super", level: p.level) > 0,
           let row = stanceByClass[characterClass] {
            stance = row
            stanceRoundsLeft = combat.stances.durationRounds
            vigorSpent += row.activationVigor
        }

        while p.isAlive && e.isAlive && rounds < maxRounds {
            rounds += 1
            let mods = stanceRoundsLeft > 0 && stance != nil
                ? CombatMath.StanceModifiers(stance!)
                : CombatMath.StanceModifiers.none
            let buffed = CombatMath.buffed(p, with: mods)

            // Choose the action.
            var swingMods = CombatMath.AttackModifiers()
            var special: SpecialAttackTuningDTO?
            if specialUses > 0, let row = specialByClass[characterClass] {
                special = row
                specialUses -= 1
                swingMods = CombatMath.modifiers(forSpecialAttack: row)
                vigorSpent += Int((Double(row.vigor) * mods.vigorMultiplier).rounded())
                // The effect lands BEFORE the swing, so armour break also
                // sunders for this blow — applying it afterwards would make the
                // first hit of an armour-breaking technique the one hit armour
                // still stops.
                switch row.effect {
                case .armourBreak(let r):
                    defDebuffRounds = r
                case .guaranteedCrit:
                    break                      // carried entirely by `swingMods`
                case .burn(let r, let fraction):
                    // Frozen from the ATK behind THIS cast: a stance expiring
                    // mid-burn must not retroactively weaken a fire already lit.
                    burnRounds = r
                    burnDamage = Swift.max(1, Int((Double(buffed.attack) * fraction).rounded()))
                }
            } else {
                let cost = profile == .basic ? drain.combatRound : drain.combatAttack
                vigorSpent += Int((Double(cost) * mods.vigorMultiplier).rounded())
            }

            // Player swing.
            var target = e
            if defDebuffRounds > 0 { target.defense = 0 }
            let swing = CombatMath.applyAttack(attacker: buffed, defender: target,
                                               modifiers: swingMods, rules: rules, using: &rng)
            e.take(swing.damage)
            if !e.isAlive { break }

            // Enemy counter. The archer's long aim leaves no dodge this round.
            var defender = buffed
            if special?.zeroesDodge == true { defender.dodge = 0 }
            let counter = CombatMath.applyAttack(attacker: e, defender: defender,
                                                 rules: rules, using: &rng)
            p.take(counter.damage)

            // Burn ticks at the end of the round, for every action — a fire
            // that only advanced when the mage cast again would not be a
            // damage-over-time effect at all.
            if burnRounds > 0 {
                e.take(burnDamage)
                burnRounds -= 1
                if !e.isAlive { break }
            }

            if stanceRoundsLeft > 0 {
                stanceRoundsLeft -= 1
                if stanceRoundsLeft == 0 { stance = nil }
            }
            if defDebuffRounds > 0 { defDebuffRounds -= 1 }
        }

        let hpLost = Swift.max(0, startHP - p.hp)
        return FightOutcome(
            won: !e.isAlive && p.isAlive,
            rounds: rounds,
            hpLost: hpLost,
            hpLostPercent: p.maxHP > 0 ? Double(hpLost) / Double(p.maxHP) * 100 : 0,
            vigorSpent: vigorSpent,
            stalemate: rounds >= maxRounds && p.isAlive && e.isAlive)
    }
}
