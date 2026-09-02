//
//  OpeningLedger.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 02.09.2026.
//
//  The opening — every level below the estate's first upgrade, measured.
//
//  `FoodBudget` answers "how much Vigor can a tended estate put in a player's
//  hands in a day", and the pace section divides kills by it. Before the first
//  upgrade there is no estate to divide by: `plotSlotsByTier` opens at 0, so
//  those levels are excluded and reported as `pace.levels_without_an_estate`.
//  This file is the other half of that warning — the same stretch measured
//  against the only income it actually has, which is the trail.
//
//  `spec-economy.md` §7 asked for exactly one thing: **can these levels be
//  completed, and at what depth.** Depth is the variable because depth is the
//  answer the design gives — an enemy of level N spawns from km N, so walking
//  further is the only way to raise XP per kill, and the spec states that as
//  the intended opening. The table exists to check whether it actually is.
//
//  The ledger is deliberately narrow, and every exclusion is a whole loop
//  rather than a rounding:
//
//    • **Foraging counts here**, where `FoodBudget` leaves it out. Before the
//      estate exists it is not a bonus on top of the income, it IS the income.
//    • **A kill's raw meat does not.** It carries no restore effect, and every
//      recipe that turns it into a portion is a kitchen recipe — a room of the
//      estate, which is the thing this stretch ends by unlocking. The column is
//      printed as what the gate is holding back, and left out of the net.
//    • **Silver is never spent.** Hide sells, quests pay, and the trader stocks
//      both food and the lumber a kitchen would want. That is a different loop
//      with a different question, and leaving it out is what makes this number
//      a FLOOR on the opening rather than an estimate of it.
//
//  Two things it shares with the pace section on purpose: fresh rooms only (a
//  real route re-enters rooms and the encounter weight decays, so every real
//  opening costs more than this one), and no division by the win rate — a lost
//  fight is judged by the win-rate column beside it, not folded into the cost.
//

import Foundation
import ROIContent

public enum OpeningLedger {

    /// Expected items one forage event hands over.
    ///
    /// `ExplorationService.rollLoot` draws ONE id from the zone's weighted pool
    /// and awards `Int.random(in: 1...2)` of it. The mean of that is 1.5, and it
    /// is the only figure in this file that is a property of the roll rather
    /// than of the content being rolled over.
    public static let itemsPerForageEvent: Double = 1.5

    /// The win rate below which a depth is not a path at all. Same line the
    /// report's own `balance.win_rate` band draws — a loss is a wiped backpack,
    /// so a depth the player cannot hold is not a cheaper opening, it is a
    /// shorter one.
    public static let survivableWinRate: Double = 95

    /// One depth, walked by a player who has no estate yet.
    public struct Depth: Sendable {
        public let km: Int
        /// Levels of everything that spawns here — the ladder the walk buys.
        public let mobLevels: [Int]
        /// Kill-weighted over the opening's levels, after the level-gap scaling.
        public let xpPerKill: Double
        /// Walk plus fight, per kill.
        public let vigorPerKill: Double
        public let winRate: Double
        public let kills: Double
        public let spent: Double
        /// Berries and nuts off the trail.
        public let foraged: Double
        /// Anything a kill drops that is edible AS FOUND. Zero for every shipped
        /// enemy — they drop raw meat and hide — but it is counted rather than
        /// assumed away, because the alternative is a drop that silently
        /// contributes to neither column the day one is authored.
        public let killFood: Double
        /// Walking out to this km in the first place, charged ONCE: nothing
        /// refills the pool before the estate, so the whole opening is a single
        /// budget and the player only makes the approach once. The events those
        /// rooms roll on the way in are not credited back, which keeps the
        /// charge on the conservative side of the trade it prices.
        public let approach: Double
        /// What the raw meat those kills drop WOULD restore once a kitchen
        /// exists. Never added to the net: the kitchen is a room of the estate,
        /// and the estate is what this stretch ends by unlocking.
        public let meatLocked: Double
        public let stock: Double

        /// Everything the trail feeds the player, forage plus edible drops.
        public var trailFood: Double { foraged + killFood }
        /// Everything the opening has to spend, less what it costs. Negative is
        /// a deficit that has to be found somewhere this ledger does not look.
        public var net: Double { stock + trailFood - spent - approach }
        /// The same ledger if the meat could be cooked — the size of what the
        /// kitchen gate is holding back, and nothing more.
        public var netIfCooked: Double { net + meatLocked }
    }

    public struct Result: Sendable {
        public let depths: [Depth]
        /// The level the opening ends at: the estate's first upgrade gate.
        public let endsAtLevel: Int
        /// Starting pool plus every level-up grant on the way there.
        public let stock: Double
        public let xpNeeded: Int
        public let stepsPerEncounter: Double
        public let walkVigor: Double
        public let forageEventsPerEncounter: Double

        /// The cheapest depth that can actually be held — the answer to "at
        /// what depth", when there is one.
        public var best: Depth? {
            depths.filter { $0.winRate >= survivableWinRate }.max { $0.net < $1.net }
        }
        /// Shallowest measured depth, which is what the design says should NOT
        /// be the answer.
        public var shallowest: Depth? { depths.first }
    }

    // MARK: - Measurement

    /// `maxKm` defaults to the deepest kilometre anything spawns at, read off
    /// the roster's own bands. A written-down ceiling would truncate the table
    /// the day something is authored past it — silently, and in the one
    /// direction ("is there a better depth further out?") the table exists to
    /// answer.
    public static func measure(content: GameContent, runs: Int, seed: UInt64,
                               maxKm: Int? = nil) -> Result? {
        guard let tuning = content.tuning, let budget = content.budget,
              let zoneFile = content.zones else { return nil }
        let deepest = maxKm ?? content.enemies.compactMap { enemy -> Int? in
            guard let depth = enemy.depth, depth.max > 0 else { return nil }
            return depth.max
        }.max() ?? 0
        guard deepest > 0 else { return nil }
        let progression = tuning.progression
        let exploration = tuning.exploration
        guard let fresh = exploration.weightTiers.first(where: { $0.priorVisits == 0 }),
              fresh.encounter > 0 else { return nil }

        // The opening is every level below the estate's first upgrade, read off
        // the ladder rather than written down — so this section follows the gate
        // if the gate ever moves.
        let endsAtLevel = content.estateUpgrades.progression
            .map(\.requiredPlayerLevel).min() ?? 0
        guard endsAtLevel > 1 else { return nil }

        // A level-up adds its delta to the CURRENT pool (`User.levelUp`), and
        // since Phase 8E nothing else refills it — so everything the opening has
        // to spend is the pool ceiling at its last level.
        let stock = Double(ProgressionMath.maxVigor(at: endsAtLevel - 1,
                                                    pool: progression.vigorPool))
        let xpNeeded = ProgressionMath.totalXP(toReach: endsAtLevel,
                                               curve: progression.xpCurve,
                                               maxLevel: progression.maxLevel)

        let stepsPerEncounter = Double(exploration.eventWeightTotal) / Double(fresh.encounter)
        let walkVigor = Double(tuning.vigor.drain.walkRoom) * stepsPerEncounter
        let forageEvents = Double(fresh.loot) / Double(fresh.encounter)

        // What a unit of an item is worth in Vigor. Its own restore effect if it
        // has one; otherwise the best rate a single recipe converts it at. One
        // level deep and no further — a chain of crafts is a different economy,
        // and the only conversion this ledger needs is a kill's meat becoming a
        // portion.
        func restore(_ itemId: String) -> Double {
            Double(content.itemsById[itemId]?.effects
                .filter { $0.kind == .restoreVigor }
                .reduce(0) { $0 + $1.amount } ?? 0)
        }
        func cookedValue(of itemId: String) -> Double {
            var best = 0.0
            for recipe in content.recipes {
                guard let input = recipe.inputs.first(where: { $0.itemId == itemId }),
                      input.quantity > 0 else { continue }
                let produced = restore(recipe.output.itemId) * Double(recipe.output.quantity)
                best = Swift.max(best, produced / Double(input.quantity))
            }
            return best
        }

        func forageVigor(atKm km: Int) -> Double {
            guard let zone = zoneFile.zones.first(where: { km >= $0.depth.min && km <= $0.depth.max })
            else { return 0 }
            let total = zone.forage.reduce(0) { $0 + Swift.max(0, $1.weight) }
            guard total > 0 else { return 0 }
            // Only what is edible AS FOUND. A raw potato restores nothing and
            // needs the same locked kitchen the meat does, so it counts for
            // exactly as much here as the meat does: nothing.
            let perItem = zone.forage.reduce(0.0) {
                $0 + Double(Swift.max(0, $1.weight)) / Double(total) * restore($1.itemId)
            }
            return perItem * itemsPerForageEvent * forageEvents
        }

        let simulator = FightSimulator(combat: tuning.combat, vigor: tuning.vigor)
        let classes = progression.classes.map(\.characterClass)
        let archetypeWeight = Dictionary(content.enemyArchetypes.map { ($0.id, $0.spawnWeight) },
                                         uniquingKeysWith: { first, _ in first })

        var fightCache: [String: (vigor: Double, winRate: Double)] = [:]
        func fightCost(level: Int, enemy: EnemyDTO) -> (vigor: Double, winRate: Double)? {
            let key = "\(level)|\(enemy.id)"
            if let hit = fightCache[key] { return hit }
            let shipped = CombatantStats(
                level: enemy.level, maxHP: enemy.stats.hp, attack: enemy.stats.attack,
                defense: enemy.stats.defense, crit: enemy.stats.crit,
                dodge: enemy.stats.dodge, accuracy: enemy.stats.accuracy)
            var vigorTotal = 0.0
            var wins = 0, fights = 0
            for cls in classes {
                guard let reference = ReferenceCharacter.build(
                    characterClass: cls, level: level, gearOffset: 0,
                    progression: progression, budget: budget,
                    rarities: content.rarities) else { return nil }
                var rng = SplitMix64(seed: BalanceSimulator.seed(
                    seed, ["opening", "\(level)", enemy.id, cls]))
                for _ in 0..<runs {
                    // `.basic` is not a simplification here, it is the only
                    // profile that exists: the earliest technique in
                    // `combat.techniques` unlocks well above this stretch, so
                    // the opening IS the basic-attack profile.
                    let outcome = simulator.fight(player: reference.stats, characterClass: cls,
                                                  enemy: shipped, profile: .basic, using: &rng)
                    vigorTotal += Double(outcome.vigorSpent)
                    if outcome.won { wins += 1 }
                    fights += 1
                }
            }
            guard fights > 0 else { return nil }
            let result = (vigor: vigorTotal / Double(fights),
                          winRate: Double(wins) / Double(fights) * 100)
            fightCache[key] = result
            return result
        }

        var depths: [Depth] = []
        var shown = Set<[String]>()
        for km in 1...deepest {
            // Exactly `EnemyCatalog.pickFor`'s eligibility: the band contains
            // the km, and an enemy with no band is never rolled by exploration.
            let eligible = content.enemies.filter { enemy in
                guard let depth = enemy.depth, depth.max > 0 else { return false }
                return km >= depth.min && km <= depth.max
            }
            guard !eligible.isEmpty else { continue }
            // One row per distinct spawn set, at the SHALLOWEST km that has it.
            // Every km between two bands rolls the same encounter table, so
            // printing them all would be the same row repeated — and the
            // shallowest is the one a player would actually stand on, since it
            // is the same table for the shortest walk.
            let signature = eligible.map(\.id).sorted()
            guard !shown.contains(signature) else { continue }
            shown.insert(signature)

            let weights = eligible.map { enemy in
                Swift.max(0, enemy.spawnWeight ?? archetypeWeight[enemy.archetype] ?? 1)
            }
            let totalWeight = weights.reduce(0, +)
            guard totalWeight > 0 else { continue }

            var kills = 0.0, spent = 0.0, foraged = 0.0, food = 0.0, meat = 0.0
            var xpWeighted = 0.0, winWeighted = 0.0
            var complete = true
            let forage = forageVigor(atKm: km)

            for level in 1..<endsAtLevel {
                var xpPerKill = 0.0, fightVigor = 0.0, winRate = 0.0
                var foodPerKill = 0.0, lockedPerKill = 0.0
                for (enemy, weight) in zip(eligible, weights) {
                    guard let cost = fightCost(level: level, enemy: enemy) else {
                        complete = false; break
                    }
                    let share = weight / totalWeight
                    xpPerKill += share * Double(ProgressionMath.xpFromKill(
                        xpReward: enemy.xpReward, monsterLevel: enemy.level,
                        playerLevel: level, spec: progression.xpLevelDiff))
                    fightVigor += share * cost.vigor
                    winRate += share * cost.winRate
                    // A drop is income if it can be eaten as it falls, and
                    // LOCKED if the only thing that turns it into Vigor is a
                    // kitchen recipe — the kitchen being a room of the estate
                    // this stretch ends by unlocking.
                    for drop in enemy.loot {
                        let expected = drop.chance * Double(drop.quantity)
                        let direct = restore(drop.itemId)
                        if direct > 0 { foodPerKill += share * expected * direct }
                        else { lockedPerKill += share * expected * cookedValue(of: drop.itemId) }
                    }
                }
                guard complete else { break }
                guard xpPerKill > 0 else { continue }
                let needed = ProgressionMath.xpRequiredToReach(level + 1, curve: progression.xpCurve,
                                                               maxLevel: progression.maxLevel)
                guard needed != Int.max else { continue }
                let killsHere = Double(needed) / xpPerKill
                kills += killsHere
                spent += killsHere * (fightVigor + walkVigor)
                foraged += killsHere * forage
                food += killsHere * foodPerKill
                meat += killsHere * lockedPerKill
                xpWeighted += killsHere * xpPerKill
                winWeighted += killsHere * winRate
            }
            guard complete, kills > 0 else { continue }

            depths.append(Depth(
                km: km, mobLevels: eligible.map(\.level).sorted(),
                xpPerKill: xpWeighted / kills, vigorPerKill: spent / kills,
                winRate: winWeighted / kills, kills: kills, spent: spent,
                foraged: foraged, killFood: food,
                approach: Double(km) * Double(tuning.vigor.drain.walkRoom),
                meatLocked: meat, stock: stock))
        }
        guard !depths.isEmpty else { return nil }
        return Result(depths: depths, endsAtLevel: endsAtLevel, stock: stock,
                      xpNeeded: xpNeeded, stepsPerEncounter: stepsPerEncounter,
                      walkVigor: walkVigor, forageEventsPerEncounter: forageEvents)
    }
}
