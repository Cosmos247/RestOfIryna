//
//  BalanceReport.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 30.08.2026.
//
//  The sweep, its acceptance bands, and the text they print as.
//
//  What is a BAND and what is merely PRINTED is the whole design of this file.
//  A band is a promise the design actually made; everything else is a number
//  worth seeing but not worth failing a build over.
//
//  Bands:
//    • level invariance — the load-bearing claim of the whole rebalance. The
//      rating denominators are derived from the item budget so that a level-1
//      fight and a level-40 fight play the SAME. If a row drifts across
//      levels, the derivation is wrong and every other number is built on it.
//    • the tail is not death — p90 HP loss below 100% for everything but the
//      boss, which is designed to cost more than a full bar.
//    • win rate — a fight the player loses is a wiped backpack, so the floor
//      is high everywhere the design does not say otherwise.
//    • class spread — ±7%, from the plan.
//
//  Printed, not banded: measured rounds against the archetype's `rounds`
//  target. The target is the GENERATOR's input, not a promise to the player —
//  the realised number legitimately differs from it (a fight ends on the swing
//  that kills, not on a fractional one), and a band there would fail by design.
//

import Foundation
import ROIContent

// MARK: - Results

public struct CellResult: Sendable {
    public let characterClass: String
    public let level: Int
    public let archetype: String
    public let profile: PlayerProfile
    public let gearOffset: Int
    public let rounds: Distribution
    public let hpLossPercent: Distribution
    public let vigor: Distribution
    public let winRate: Double
    public let stalemateRate: Double
}

public struct Finding: Sendable {
    public enum Severity: String, Sendable { case error, warning }
    public let severity: Severity
    public let rule: String
    public let message: String
}

public struct BalanceRun: Sendable {
    public let cells: [CellResult]
    public let levels: [Int]
    public let classes: [String]
    public let archetypes: [String]
    public let runsPerCell: Int
    public let seed: UInt64

    public func cell(_ cls: String, _ level: Int, _ archetype: String,
                     _ profile: PlayerProfile, _ offset: Int) -> CellResult? {
        cells.first {
            $0.characterClass == cls && $0.level == level && $0.archetype == archetype
                && $0.profile == profile && $0.gearOffset == offset
        }
    }
}

// MARK: - The sweep

public enum BalanceSimulator {

    /// Levels the design table is stated at.
    public static let defaultLevels = [1, 5, 10, 20, 30, 40]

    /// Per-cell seed. Derived from the cell's identity rather than from a
    /// running counter so a cell rolls the same stream no matter which other
    /// cells ran, were skipped, or ran in parallel — without that, changing
    /// `--levels` would silently move every number below it.
    static func seed(_ base: UInt64, _ parts: [String]) -> UInt64 {
        var hash: UInt64 = 0xcbf29ce484222325 ^ base
        for part in parts {
            for byte in part.utf8 {
                hash ^= UInt64(byte)
                hash = hash &* 0x100000001b3
            }
            hash ^= 0x5F
            hash = hash &* 0x100000001b3
        }
        return hash
    }

    public static func run(content: GameContent, levels: [Int] = defaultLevels,
                           runs: Int, seed baseSeed: UInt64,
                           profiles: [PlayerProfile] = PlayerProfile.allCases,
                           gearOffsets: [Int] = [0, -ReferenceCharacter.ladderRung]) -> BalanceRun? {
        guard let tuning = content.tuning, let budget = content.budget else { return nil }
        let combat = tuning.combat
        let progression = tuning.progression
        let simulator = FightSimulator(combat: combat, vigor: tuning.vigor)
        let rules = CombatRules(combat)
        let classes = progression.classes.map(\.characterClass)
        let archetypes = content.enemyArchetypes

        var cells: [CellResult] = []
        for level in levels {
            // The generator's yardstick is the on-curve reference of every
            // class, averaged — see `EnemyGenerator.generate`.
            let onCurve = classes.compactMap {
                ReferenceCharacter.build(characterClass: $0, level: level, gearOffset: 0,
                                         progression: progression, budget: budget,
                                         rarities: content.rarities)?.stats
            }
            guard onCurve.count == classes.count else { return nil }

            for archetype in archetypes {
                let enemy = EnemyGenerator.generate(archetype: archetype, level: level,
                                                    against: onCurve, rules: rules,
                                                    mobXP: progression.mobXP)
                for offset in gearOffsets {
                    for cls in classes {
                        guard let character = ReferenceCharacter.build(
                            characterClass: cls, level: level, gearOffset: offset,
                            progression: progression, budget: budget,
                            rarities: content.rarities) else { return nil }
                        for profile in profiles {
                            var rng = SplitMix64(seed: seed(baseSeed, [
                                cls, "\(level)", archetype.id, profile.rawValue, "\(offset)"]))
                            cells.append(measure(
                                player: character.stats, characterClass: cls,
                                enemy: enemy.stats, profile: profile, level: level,
                                archetype: archetype.id, offset: offset,
                                runs: runs, simulator: simulator, rng: &rng))
                        }
                    }
                }
            }
        }
        return BalanceRun(cells: cells, levels: levels, classes: classes,
                          archetypes: archetypes.map(\.id), runsPerCell: runs, seed: baseSeed)
    }

    static func measure<G: RandomNumberGenerator>(
        player: CombatantStats, characterClass: String, enemy: CombatantStats,
        profile: PlayerProfile, level: Int, archetype: String, offset: Int,
        runs: Int, simulator: FightSimulator, rng: inout G
    ) -> CellResult {
        var rounds: [Double] = []; rounds.reserveCapacity(runs)
        var hpLoss: [Double] = []; hpLoss.reserveCapacity(runs)
        var vigor: [Double] = []; vigor.reserveCapacity(runs)
        var wins = 0
        var stalemates = 0
        for _ in 0..<runs {
            let outcome = simulator.fight(player: player, characterClass: characterClass,
                                          enemy: enemy, profile: profile, using: &rng)
            rounds.append(Double(outcome.rounds))
            hpLoss.append(outcome.hpLostPercent)
            vigor.append(Double(outcome.vigorSpent))
            if outcome.won { wins += 1 }
            if outcome.stalemate { stalemates += 1 }
        }
        return CellResult(
            characterClass: characterClass, level: level, archetype: archetype,
            profile: profile, gearOffset: offset,
            rounds: Distribution(rounds), hpLossPercent: Distribution(hpLoss),
            vigor: Distribution(vigor),
            winRate: Double(wins) / Double(runs) * 100,
            stalemateRate: Double(stalemates) / Double(runs) * 100)
    }
}
