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

    // Event weights for a step (sum = 100). GDD §5 starting values, trimmed for MVP.
    // Phase 3.2 uses a three-tier table keyed on the room's prior visit count:
    //   tier 0 (fresh)   — first entry ever during this expedition
    //   tier 1 (reduced) — second entry, most of the room's events already fired
    //   tier 2+ (bare)   — third+ entry, the room is picked clean
    // Trip risk shares a small tier-invariant chance at tiers 0 and 1 because
    // roots don't "learn" — it drops to zero at tier 2+ alongside every other
    // interesting outcome. Starvation HP still ticks on every step.
    // Fresh-room tuning (2026-05-12): halved "nothing" (20 → 10) and shifted
    // the 10 points into loot (40 → 50). User feedback — the wilderness felt
    // too quiet; encounters and trips already produce drops via mob loot
    // tables, so the easiest dial is the nothing/loot split.
    static let weightNothing:   Int = 10
    static let weightLoot:      Int = 50
    static let weightEncounter: Int = 30
    static let weightTrip:      Int = 10
    static let weightTotal:     Int = 100

    // Revisit tier (2026-05-12 second pass): step-back through visited rooms
    // showed too many "🍂 Сліди витоптані" in a row. Pulled nothing down to
    // 20 and bumped loot to 50 so the return trip has the same loot odds as
    // a fresh room — encounter/trip stay reduced (thinned predator density,
    // but berries and pebbles still grow back enough to find).
    static let weightNothingReduced:   Int = 20
    static let weightLootReduced:      Int = 50
    static let weightEncounterReduced: Int = 20
    static let weightTripReduced:      Int = 10

    // Bare tier (2026-05-12 second pass): the room is heavily walked-over,
    // but a 1-in-5 chance of stumbling on something keeps the trek alive.
    // Encounter/trip stay at zero — beasts have learned to avoid the path.
    static let weightNothingBare:   Int = 80
    static let weightLootBare:      Int = 20
    static let weightEncounterBare: Int = 0
    static let weightTripBare:      Int = 0

    // Trip damage (% of max HP).
    static let tripDamagePercent: Double = 0.05

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
        var wNothing: Int
        var wLoot: Int
        let wEncounter: Int
        let wTrip: Int
        switch priorVisits {
        case 0:
            wNothing   = weightNothing
            wLoot      = weightLoot
            wEncounter = weightEncounter
            wTrip      = weightTrip
        case 1:
            wNothing   = weightNothingReduced
            wLoot      = weightLootReduced
            wEncounter = weightEncounterReduced
            wTrip      = weightTripReduced
        default:
            // 2+ prior visits — room is picked clean of beasts and hazards,
            // but a small chance of finding overlooked forage remains. No
            // encounter, no trip; starvation still applies (that's physiology).
            wNothing   = weightNothingBare
            wLoot      = weightLootBare
            wEncounter = weightEncounterBare
            wTrip      = weightTripBare
        }

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
        let tripDmg = max(1, Int((Double(user.maxHp) * tripDamagePercent).rounded()))
        let totalHp = tripDmg + starvationLoss
        user.hp = max(0, user.hp - totalHp)
        return .trip(hpLost: totalHp)
    }

    // MARK: - Private rolls

    private static func rollLoot(for user: User, kmDepth: Int, on db: any Database, extraStarvation: Int) async throws -> StepOutcome {
        // Depth-aware FORAGING pool — only items the governor can physically
        // find on the trail. Hide / raw meat are deliberately NOT here; they
        // drop exclusively from enemy kills via EnemyCatalog loot tables.
        // Each itemId listed here has a matching `exploration.find.<id>`
        // locale key with a per-item flavor line. Pairs are (id, weight) —
        // higher weight = more common. `mat.iron` is the rare drop at the
        // medium tier, weighted ~1/5 of the staples so it's a notable find.
        let shallow: [(String, Int)] = [
            ("food.forest_berries", 10),
            ("food.forest_nuts",    10),
            ("mat.pine_lumber",     10),
            ("mat.river_pebble",    10)
        ]
        let medium: [(String, Int)] = [
            ("food.potato",   10),
            ("food.duck_egg", 10),
            ("mat.clay",      10),
            ("mat.iron",       2)   // rare — replaces the retired `mat.old_iron`
        ]
        let pool: [(String, Int)] = kmDepth <= 2 ? shallow : (kmDepth <= 5 ? shallow + medium : medium)
        let itemId = pickWeighted(pool) ?? "mat.pine_lumber"
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
                defenderDEF: enemy.defense, defenderDodge: 0
            )
            switch playerHit {
            case .miss: break
            case .hit(let d), .crit(let d): enemyHP -= d
            }
            if enemyHP <= 0 { break }

            // Enemy counter — no crit/accuracy stats on Enemy yet, so pass 0.
            let enemyHit = CombatService.applyAttack(
                attackerATK: enemy.attack, attackerCrit: 0, attackerAcc: 0,
                defenderDEF: playerDef, defenderDodge: playerDodge
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

    /// Pick a `T` from a (T, weight) list with weights as plain integers —
    /// roll one random integer in `1...sum(weights)` and walk the list. Used
    /// by the foraging pool so rare items can sit alongside staples in the
    /// same `[(id, weight)]` array without bumping their share to even.
    private static func pickWeighted<T>(_ items: [(T, Int)]) -> T? {
        let total = items.reduce(0) { $0 + max(0, $1.1) }
        guard total > 0 else { return nil }
        var roll = Int.random(in: 1...total)
        for (item, weight) in items {
            let w = max(0, weight)
            if roll <= w { return item }
            roll -= w
        }
        return items.last?.0
    }
}
