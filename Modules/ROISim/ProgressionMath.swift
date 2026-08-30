//
//  ProgressionMath.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 30.08.2026.
//
//  The XP curve, the level-gap scalers, the proportional stat line and the
//  vigor pool — as pure functions over `tuning/progression.json`.
//
//  Moved out of `User` in Phase 8 for the same reason the combat model moved
//  out of `CombatService`: measuring the pace to level 40 must not require a
//  Fluent row. `User` keeps its API and delegates, so there is still exactly
//  one implementation of each curve.
//

import Foundation
import ROIContent

public enum ProgressionMath {

    /// Level-1 stat line for a class, grown proportionally to `level`.
    ///
    /// Stats are a FUNCTION of level, not an accumulated pile of per-level
    /// bonuses: `base × (1 + rate × (L − 1))`. That is what lets a rating keep
    /// pace with its own diminishing-returns denominator — under the old flat
    /// +1/level a warrior's dodge percentage fell from 5.3% to 1.4% across a
    /// lifetime while the rating on the profile screen rose.
    ///
    /// Being a pure function of (class, level) also means a level-up cannot
    /// drift: it recomputes rather than accumulating, so a missed or
    /// double-applied grant self-heals on the next one.
    public static func baseStats(start: ClassStartDTO, growth: StatGrowthDTO, level: Int)
    -> (maxHp: Int, attack: Int, defense: Int, crit: Int, dodge: Int, accuracy: Int) {
        let steps = Double(Swift.max(0, level - 1))
        let hpScale = 1 + growth.hpPerLevel * steps
        let atkScale = 1 + growth.attackPerLevel * steps
        let ratingScale = 1 + growth.ratingPerLevel * steps
        return (
            maxHp:    Swift.max(1, Int((Double(start.hp) * hpScale).rounded())),
            attack:   Swift.max(0, Int((Double(start.attack) * atkScale).rounded())),
            defense:  Swift.max(0, Int((Double(start.defense) * ratingScale).rounded())),
            crit:     Swift.max(0, Int((Double(start.crit) * ratingScale).rounded())),
            dodge:    Swift.max(0, Int((Double(start.dodge) * ratingScale).rounded())),
            accuracy: Swift.max(0, Int((Double(start.accuracy) * ratingScale).rounded()))
        )
    }

    /// XP required to advance from `nextLevel - 1` → `nextLevel`:
    /// `max(round(c · L^e), floor · L)` where L is the level being left.
    ///
    /// Returns `Int.max` past `maxLevel` so callers can treat "no more XP
    /// needed" uniformly.
    public static func xpRequiredToReach(_ nextLevel: Int, curve: XPCurveDTO, maxLevel: Int) -> Int {
        guard nextLevel >= 2, nextLevel <= maxLevel else { return Int.max }
        let from = Double(nextLevel - 1)
        let power = (curve.coefficient * pow(from, curve.exponent)).rounded()
        return Swift.max(Int(power), curve.floorPerLevel * (nextLevel - 1))
    }

    /// Total XP from level 1 to `level`. The pace check's denominator — and
    /// the reason the curve is worth stating twice: a per-level cost that reads
    /// fine can still integrate to a number of months nobody will play.
    public static func totalXP(toReach level: Int, curve: XPCurveDTO, maxLevel: Int) -> Int {
        guard level >= 2 else { return 0 }
        var total = 0
        for step in 2...Swift.min(level, maxLevel) {
            let cost = xpRequiredToReach(step, curve: curve, maxLevel: maxLevel)
            guard cost != Int.max else { break }
            total += cost
        }
        return total
    }

    /// XP multiplier for killing a monster this far below your level.
    ///
    /// Required, not polish: without it, farming ten levels down keeps 67% of
    /// the XP for a fight that is 35% faster and 40% safer, which makes shallow
    /// farming strictly optimal and the whole depth ladder dead content.
    public static func xpMultiplier(playerLevel: Int, monsterLevel: Int,
                                    spec: XPLevelDiffDTO) -> Double {
        let raw = 1 - spec.perLevel * Double(playerLevel - monsterLevel)
        return Swift.max(spec.min, Swift.min(spec.max, raw))
    }

    /// XP a kill is worth to this player, after the level-gap scaling.
    public static func xpFromKill(xpReward: Int, monsterLevel: Int, playerLevel: Int,
                                  spec: XPLevelDiffDTO) -> Int {
        let scaled = Double(xpReward)
            * xpMultiplier(playerLevel: playerLevel, monsterLevel: monsterLevel, spec: spec)
        return Swift.max(0, Int(scaled.rounded()))
    }

    /// Vigor ceiling at a level. Grows with the player so the regen rate, read
    /// as a share of the pool, stays constant instead of decaying to nothing.
    public static func maxVigor(at level: Int, pool: VigorPoolDTO) -> Int {
        Swift.max(1, pool.base + pool.perLevel * Swift.max(0, level))
    }

    /// Vigor restored per minute of wall-clock time: the whole pool over
    /// `fullRegenHours`. Scaling with the pool rather than being flat is the
    /// point — a flat rate shrinks, as a share of the pool, every time the pool
    /// grows, and by the level cap the player would recover 2.7% an hour
    /// instead of the 16.7% they started with.
    public static func vigorRegenPerMinute(maxVigor: Int, pool: VigorPoolDTO) -> Double {
        guard pool.fullRegenHours > 0 else { return 0 }
        return Double(maxVigor) / (pool.fullRegenHours * 60)
    }
}
