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
//    - Resolve combat via a stub autobattle — Phase 4 replaces this with a real
//      round-based controller.
//    - Drain hunger and apply starvation HP loss on room transitions.
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
    case encounterWon(enemy: Enemy, rounds: Int, hpLost: Int, hungerLost: Int, loot: [(itemId: String, quantity: Int, picked: Bool)])
    case encounterLost(enemy: Enemy, rounds: Int, hpLost: Int, hungerLost: Int)
    case starvationOnly(hpLost: Int)
}

// MARK: - Autobattle result (Phase 4 stub)

public struct AutobattleResult: Sendable {
    public let playerWon: Bool
    public let rounds: Int
    public let playerHPLost: Int
    public let playerHungerLost: Int
}

public enum ExplorationService {

    // Event weights for a step (sum = 100). GDD §5 starting values, trimmed for MVP.
    static let weightNothing:   Int = 40
    static let weightLoot:      Int = 30
    static let weightEncounter: Int = 25
    static let weightTrip:      Int = 5
    static let weightTotal:     Int = 100

    // Trip damage (% of max HP).
    static let tripDamagePercent: Double = 0.05

    // MARK: - Rolling a step

    /// Roll one forward step: drain hunger, apply starvation HP if starving,
    /// then produce an outcome. Caller applies the outcome to DB / UI separately
    /// (loot is already added to inventory by this function though).
    public static func rollStep(for user: User, kmDepth: Int, on db: any Database) async throws -> StepOutcome {
        // Hunger drain for the walk itself.
        _ = HungerService.drain(user, action: .walkRoom)

        // Starvation HP tick happens every room when hunger is already at 0.
        let starvationLoss = HungerService.applyStarvationHPLoss(user)

        // Pick the event bucket.
        let roll = Int.random(in: 0..<weightTotal)
        if roll < weightNothing {
            if starvationLoss > 0 { return .starvationOnly(hpLost: starvationLoss) }
            return .nothing
        }
        if roll < weightNothing + weightLoot {
            return try await rollLoot(for: user, kmDepth: kmDepth, on: db, extraStarvation: starvationLoss)
        }
        if roll < weightNothing + weightLoot + weightEncounter {
            return try await rollEncounter(for: user, kmDepth: kmDepth, on: db, extraStarvation: starvationLoss)
        }
        // Trip
        let tripDmg = max(1, Int((Double(user.maxHp) * tripDamagePercent).rounded()))
        let totalHp = tripDmg + starvationLoss
        user.hp = max(0, user.hp - totalHp)
        return .trip(hpLost: totalHp)
    }

    // MARK: - Private rolls

    private static func rollLoot(for user: User, kmDepth: Int, on db: any Database, extraStarvation: Int) async throws -> StepOutcome {
        // Depth-aware loot pool. Shallow forest: berries, herbs, wood. Deeper: iron, hides.
        let shallow = ["food.berry", "mat.wood", "mat.stone"]
        let medium  = ["mat.hide", "mat.iron_ore", "food.berry"]
        let pool = kmDepth <= 2 ? shallow : (kmDepth <= 5 ? shallow + medium : medium)
        let itemId = pool.randomElement() ?? "mat.wood"
        let quantity = 1

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

    private static func rollEncounter(for user: User, kmDepth: Int, on db: any Database, extraStarvation: Int) async throws -> StepOutcome {
        if extraStarvation > 0 {
            user.hp = max(0, user.hp - extraStarvation)
            if user.hp <= 0 {
                // Died from starvation on the step — skip the fight; callers handle death.
                let any = EnemyCatalog.pickFor(kmDepth: kmDepth) ?? EnemyCatalog.all[0]
                return .encounterLost(enemy: any, rounds: 0, hpLost: extraStarvation, hungerLost: 0)
            }
        }

        guard let enemy = EnemyCatalog.pickFor(kmDepth: kmDepth) else {
            return .nothing
        }

        let hpBefore = user.hp
        let hungerBefore = user.hunger
        let result = resolveAutobattle(player: user, enemy: enemy)
        let hpLost = max(0, hpBefore - user.hp)
        let hungerLost = max(0, hungerBefore - user.hunger)

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
            return .encounterWon(enemy: enemy, rounds: result.rounds, hpLost: hpLost, hungerLost: hungerLost, loot: picked)
        } else {
            return .encounterLost(enemy: enemy, rounds: result.rounds, hpLost: hpLost, hungerLost: hungerLost)
        }
    }

    // MARK: - Autobattle stub (Phase 4 replaces this)

    /// Simulate rounds until one side dies or a safety cap hits. Mutates
    /// `player.hp` / `player.hunger` directly. Damage formula is intentionally
    /// basic here — Phase 4's CombatController will layer in dodge/accuracy/crit.
    public static func resolveAutobattle(player: User, enemy: Enemy) -> AutobattleResult {
        var enemyHP = enemy.hp
        var rounds = 0
        let maxRounds = 50  // safety cap

        let playerAtk = player.effectiveAttack
        let playerDef = player.effectiveDefense
        let hpBefore = player.hp

        while player.hp > 0 && enemyHP > 0 && rounds < maxRounds {
            rounds += 1
            _ = HungerService.drain(player, action: .combatRound)

            // Player strikes first — simple auto-attack with ±10% variance.
            let playerRaw = Double(max(1, playerAtk - enemy.defense))
            let playerDmg = max(1, Int((playerRaw * Double.random(in: 0.9...1.1)).rounded()))
            enemyHP -= playerDmg
            if enemyHP <= 0 { break }

            let enemyRaw = Double(max(1, enemy.attack - playerDef))
            let enemyDmg = max(1, Int((enemyRaw * Double.random(in: 0.9...1.1)).rounded()))
            player.hp = max(0, player.hp - enemyDmg)
        }

        return AutobattleResult(
            playerWon: enemyHP <= 0 && player.hp > 0,
            rounds: rounds,
            playerHPLost: max(0, hpBefore - player.hp),
            playerHungerLost: rounds  // one hunger per round
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
