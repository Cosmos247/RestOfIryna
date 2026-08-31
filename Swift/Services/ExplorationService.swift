//
//  ExplorationService.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 21.04.2026.
//
//  Per-step logic for the active exploration loop.
//
//  Responsibilities:
//    - Roll the outcome of a step (nothing / loot / encounter / trip).
//    - Resolve combat via autobattle (passive expeditions) on top of
//      `CombatService.applyAttack` — the active CombatController shares the
//      same primitives so a fight resolves with the same odds in either mode.
//    - Drain vigor and apply starvation HP loss on room transitions.
//
//  The service mutates the `User` model in place; callers persist via
//  `saveAndCache`. Loot drops are added directly to the player's inventory
//  (inventory == expedition bag per design) and may be refused when the bag
//  is full — the outcome enum carries that information back to the UI.
//

import Fluent
import Foundation

// MARK: - Step outcomes

public enum StepOutcome: Sendable {
    case nothing
    case loot(itemId: String, quantity: Int, picked: Bool)        // picked=false → bag full
    case trip(hpLost: Int)
    /// Active mode: an enemy is in front of the player and the controller
    /// should hand off to CombatController. The fight isn't resolved yet —
    /// no HP / vigor has been spent on the encounter itself (only the
    /// walk-room drain for the step). Caller persists `combatEnemyId` /
    /// `combatEnemyHP` on the ExplorationState row.
    case encounterStarted(enemy: Enemy)
    case encounterWon(enemy: Enemy, rounds: Int, hpLost: Int, vigorLost: Int, loot: [(itemId: String, quantity: Int, picked: Bool)])
    case encounterLost(enemy: Enemy, rounds: Int, hpLost: Int, vigorLost: Int)
    case starvationOnly(hpLost: Int)
}

// MARK: - Autobattle result (Phase 4 stub)

public struct AutobattleResult: Sendable {
    public let playerWon: Bool
    public let rounds: Int
    public let playerHPLost: Int
    public let playerVigorLost: Int
}

public enum ExplorationService {

    // Event weights come from `tuning/exploration.json` — a three-tier table
    // keyed on the room's prior visit count:
    //   tier 0 (fresh)   — first entry ever during this expedition
    //   tier 1 (reduced) — second entry, most of the room's events already fired
    //   tier 2+ (bare)   — third+ entry, the room is picked clean
    // Trip risk shares a small tier-invariant chance at tiers 0 and 1 because
    // roots don't "learn" — it drops to zero at tier 2+ alongside every other
    // interesting outcome. Starvation HP still ticks on every step.
    static var weightTotal: Int { Catalogs.current.tuningExploration.eventWeightTotal }

    /// Discounts and decay applied to an unattended expedition.
    static var passiveTuning: PassiveExpeditionTuningDTO {
        Catalogs.current.tuningExploration.passive
    }

    // Trip damage (% of max HP).
    static var tripDamagePercent: Double { Catalogs.current.tuningExploration.tripDamagePercent }

    /// The four event weights for one step, chosen by how many times the room
    /// has already been entered this expedition (0 = fresh, 1 = reduced,
    /// 2+ = bare; a negative count falls to bare, as the original `default`
    /// arm did).
    ///
    /// Lifted out of `rollStep` so the migration digest can replay it. The body
    /// is a `switch` today and a table lookup once the weights live in
    /// `tuning/exploration.json`, and a table that replaces control flow has to
    /// be *proven* equal across the range rather than assumed equal — the same
    /// treatment `ArenaCatalog.leagueKey` got in batch B. `rollStep` itself
    /// needs a `User` and a `Database`, so it can never be replayed directly.
    struct EventWeights: Sendable {
        let nothing: Int
        let loot: Int
        let encounter: Int
        let trip: Int
    }

    static func weights(forPriorVisits priorVisits: Int) -> EventWeights {
        let tiers = Catalogs.current.tuningExploration.weightTiers
        // Exact match, otherwise the LAST row — NOT "the greatest row at or
        // below the query". The switch this replaced had arms for 0 and 1 and a
        // `default` that swallowed everything else, negatives included, so a
        // negative visit count must land on the bare tier. A "greatest row at
        // or below" lookup would find nothing for −1 and fall back to the fresh
        // tier, quietly making re-entered rooms generous. The validator pins
        // the rows to a contiguous 0,1,2,… run so "last" cannot drift.
        let row = tiers.first { $0.priorVisits == priorVisits } ?? tiers[tiers.count - 1]
        return EventWeights(nothing: row.nothing, loot: row.loot,
                            encounter: row.encounter, trip: row.trip)
    }

    // MARK: - Rolling a step

    /// Roll one step: drain vigor, apply starvation HP if starving, then
    /// produce an outcome. Caller applies the outcome to DB / UI separately
    /// (loot is already added to inventory by this function though).
    ///
    /// `priorVisits` picks the weight tier: 0 = fresh, 1 = reduced, 2+ = bare
    /// (only `.nothing` / `.starvationOnly` can fire). The controller passes
    /// the room's current visit count *before* incrementing it for this step.
    public static func rollStep(for user: User, kmDepth: Int, priorVisits: Int = 0, mode: ExplorationMode = .active, on db: any Database) async throws -> StepOutcome {
        // Vigor drain for the walk itself.
        _ = VigorService.drain(user, action: .walkRoom)

        // Starvation HP tick happens every room when vigor is already at 0.
        let starvationLoss = VigorService.applyStarvationHPLoss(user)

        // Pick weights by tier.
        let tier = weights(forPriorVisits: priorVisits)
        var wNothing = tier.nothing
        var wLoot = tier.loot
        let wEncounter = tier.encounter
        let wTrip = tier.trip

        // Phase 6.4 — Fortune Teller hook. The active card's
        // `lootChanceMultiplier` (default 1.0) reweights the `loot`
        // bucket; we then compensate by shifting weight in/out of
        // `nothing` so the four buckets still sum to `weightTotal`
        // (the roll RNG range stays 0..<100). Negative multipliers
        // shift weight FROM loot INTO nothing; positive multipliers
        // the reverse. Encounter / trip are untouched — the Fool's
        // luck doesn't summon a bear.
        let lootMult = user.activeFortuneEffect?.lootChanceMultiplier ?? 1.0
        if lootMult != 1.0 {
            let originalLoot = wLoot
            let adjustedLoot = max(0, Int((Double(originalLoot) * lootMult).rounded()))
            let delta = adjustedLoot - originalLoot
            // Shift the difference from/to `nothing` so the total stays
            // at `weightTotal`. Floored at 0 — if the shift would push
            // nothing negative we cap (loot gets the rest, rare).
            let newNothing = wNothing - delta
            if newNothing >= 0 {
                wLoot = adjustedLoot
                wNothing = newNothing
            } else {
                wLoot = wLoot + wNothing  // absorb whatever nothing had
                wNothing = 0
            }
        }

        // Pick the event bucket.
        let roll = Int.random(in: 0..<weightTotal)
        if roll < wNothing {
            if starvationLoss > 0 { return .starvationOnly(hpLost: starvationLoss) }
            return .nothing
        }
        if roll < wNothing + wLoot {
            return try await rollLoot(for: user, kmDepth: kmDepth, on: db, extraStarvation: starvationLoss)
        }
        if roll < wNothing + wLoot + wEncounter {
            return try await rollEncounter(for: user, kmDepth: kmDepth, mode: mode, on: db, extraStarvation: starvationLoss)
        }
        _ = wTrip
        let tripDmg = max(1, Int((Double(user.effectiveMaxHp) * tripDamagePercent).rounded()))
        let totalHp = tripDmg + starvationLoss
        user.hp = max(0, user.hp - totalHp)
        return .trip(hpLost: totalHp)
    }

    // MARK: - Private rolls

    private static func rollLoot(for user: User, kmDepth: Int, on db: any Database, extraStarvation: Int) async throws -> StepOutcome {
        // Depth-aware FORAGING pool, from `content/data/zones.json` since Phase
        // 8E — it was two Swift arrays and a nested ternary here, the last
        // content left in code after Phase 3 emptied every catalog. Hide and
        // raw meat are deliberately absent: they drop only from kills, through
        // the enemy loot tables. Each id in a pool has a matching
        // `exploration.find.<id>` locale line, which the validator enforces.
        //
        // The `?? "mat.pine_lumber"` fallback went with the arrays. A zone that
        // covers no km is a content gap the validator reports; handing out
        // lumber forever instead is the same silent-wrong-item bug that made
        // every encounter past km 35 a wild boar.
        guard let itemId = ZoneCatalog.rollForage(atDepth: kmDepth) else {
            // Nothing to find here — but the starvation tick still has to be
            // both APPLIED and REPORTED, exactly as the "nothing happens"
            // bucket above does it. Swallowing it into `.nothing` would take
            // HP off the player and tell them the room was empty.
            if extraStarvation > 0 {
                user.hp = max(0, user.hp - extraStarvation)
                return .starvationOnly(hpLost: extraStarvation)
            }
            return .nothing
        }
        let quantity = Int.random(in: 1...2)

        // Apply any starvation HP loss first.
        if extraStarvation > 0 {
            user.hp = max(0, user.hp - extraStarvation)
        }

        let canFit = try await InventoryEntry.canAccept(itemId, quantity: quantity, for: user, on: db)
        if canFit {
            try await InventoryEntry.add(itemId, quantity: quantity, to: user, on: db)
            return .loot(itemId: itemId, quantity: quantity, picked: true)
        } else {
            return .loot(itemId: itemId, quantity: quantity, picked: false)
        }
    }

    private static func rollEncounter(for user: User, kmDepth: Int, mode: ExplorationMode, on db: any Database, extraStarvation: Int) async throws -> StepOutcome {
        if extraStarvation > 0 {
            user.hp = max(0, user.hp - extraStarvation)
            if user.hp <= 0 {
                // Died from starvation on the step — skip the fight; callers handle death.
                let any = EnemyCatalog.pickFor(kmDepth: kmDepth) ?? EnemyCatalog.all[0]
                return .encounterLost(enemy: any, rounds: 0, hpLost: extraStarvation, vigorLost: 0)
            }
        }

        guard let enemy = EnemyCatalog.pickFor(kmDepth: kmDepth) else {
            return .nothing
        }

        // Active mode hands off to CombatController — no HP/vigor spent on the
        // encounter itself yet. Passive mode resolves it on the spot via
        // autobattle since there's no UI to prompt the player from a Task.
        if mode == .active {
            return .encounterStarted(enemy: enemy)
        }

        let hpBefore = user.hp
        let vigorBefore = user.vigor
        let result = resolveAutobattle(player: user, enemy: enemy)
        let hpLost = max(0, hpBefore - user.hp)
        let vigorLost = max(0, vigorBefore - user.vigor)

        if result.playerWon {
            let drops = rollLootDrops(for: enemy)
            var picked: [(itemId: String, quantity: Int, picked: Bool)] = []
            for drop in drops {
                let canFit = try await InventoryEntry.canAccept(drop.itemId, quantity: drop.quantity, for: user, on: db)
                if canFit {
                    try await InventoryEntry.add(drop.itemId, quantity: drop.quantity, to: user, on: db)
                    picked.append((drop.itemId, drop.quantity, true))
                } else {
                    picked.append((drop.itemId, drop.quantity, false))
                }
            }
            return .encounterWon(enemy: enemy, rounds: result.rounds, hpLost: hpLost, vigorLost: vigorLost, loot: picked)
        } else {
            return .encounterLost(enemy: enemy, rounds: result.rounds, hpLost: hpLost, vigorLost: vigorLost)
        }
    }

    /// Public hook for CombatController — mirrors the loot-drop step that
    /// `rollEncounter` runs after autobattle, so the active controller can
    /// share the same drop logic at victory time.
    public static func awardEncounterDrops(for user: User, enemy: Enemy, on db: any Database) async throws -> [(itemId: String, quantity: Int, picked: Bool)] {
        let drops = rollLootDrops(for: enemy)
        var picked: [(itemId: String, quantity: Int, picked: Bool)] = []
        for drop in drops {
            let canFit = try await InventoryEntry.canAccept(drop.itemId, quantity: drop.quantity, for: user, on: db)
            if canFit {
                try await InventoryEntry.add(drop.itemId, quantity: drop.quantity, to: user, on: db)
                picked.append((drop.itemId, drop.quantity, true))
            } else {
                picked.append((drop.itemId, drop.quantity, false))
            }
        }
        return picked
    }

    // MARK: - Autobattle (passive mode)

    /// Simulate rounds until one side dies or a safety cap hits. Mutates
    /// `player.hp` / `player.vigor` directly. Shares hit / miss / crit
    /// primitives with the active CombatController via `CombatService.applyAttack`,
    /// so the same fight resolves with the same odds in both modes. Enemies
    /// don't carry crit/dodge/accuracy stats yet, so we pass 0 for the enemy
    /// side — the player gets effectiveDodge against incoming hits and crits
    /// against the enemy.
    public static func resolveAutobattle(player: User, enemy: Enemy) -> AutobattleResult {
        var enemyHP = enemy.hp
        var rounds = 0
        let maxRounds = 50  // safety cap

        let playerAtk = player.effectiveAttack
        let playerDef = player.effectiveDefense
        let playerCrit = player.effectiveCrit
        let playerAcc  = player.effectiveAccuracy
        let playerDodge = player.effectiveDodge
        let hpBefore = player.hp

        while player.hp > 0 && enemyHP > 0 && rounds < maxRounds {
            rounds += 1
            _ = VigorService.drain(player, action: .combatRound)

            // Player strikes first.
            let playerHit = CombatService.applyAttack(
                attackerATK: playerAtk, attackerCrit: playerCrit, attackerAcc: playerAcc,
                attackerLevel: player.level,
                defenderDEF: enemy.defense, defenderDodge: enemy.dodge,
                defenderLevel: enemy.level
            )
            switch playerHit {
            case .miss: break
            case .hit(let d), .crit(let d): enemyHP -= d
            }
            if enemyHP <= 0 { break }

            // Enemy counter. Enemies carry real crit / dodge / accuracy since
            // Phase 5A — this used to pass literal zeros on both sides, which
            // is why no beast in the game had ever landed a critical hit.
            let enemyHit = CombatService.applyAttack(
                attackerATK: enemy.attack, attackerCrit: enemy.crit, attackerAcc: enemy.accuracy,
                attackerLevel: enemy.level,
                defenderDEF: playerDef, defenderDodge: playerDodge,
                defenderLevel: player.level
            )
            switch enemyHit {
            case .miss: break
            case .hit(let d), .crit(let d): player.hp = max(0, player.hp - d)
            }
        }

        return AutobattleResult(
            playerWon: enemyHP <= 0 && player.hp > 0,
            rounds: rounds,
            playerHPLost: max(0, hpBefore - player.hp),
            playerVigorLost: rounds  // one vigor per round
        )
    }

    // MARK: - Loot drops

    private static func rollLootDrops(for enemy: Enemy) -> [(itemId: String, quantity: Int)] {
        var drops: [(itemId: String, quantity: Int)] = []
        for drop in enemy.lootTable {
            if Double.random(in: 0...1) < drop.chance {
                drops.append((drop.itemId, drop.quantity))
            }
        }
        return drops
    }
}
