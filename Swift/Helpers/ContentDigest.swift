//
//  ContentDigest.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 29.08.2026.
//
//  Verification layer 3 for the catalog migration: a single hex digest over
//  everything the catalogs expose, computed the same way before and after the
//  Swift arrays are replaced by JSON.
//
//    swift run RestOfIryna --content-digest
//
//  Two halves, because two different things can break:
//
//  1. **Record fingerprints** — every stored property of every item, enemy,
//     recipe and ladder step, in catalog order. Catches a changed value and a
//     changed ordering alike.
//  2. **Seeded `pickFor` replay** — 40 depths × 200 draws from a fixed seed.
//     `EnemyCatalog.pickFor` is `filter().randomElement()`, so the DECLARATION
//     ORDER of the roster decides which enemy a given roll returns. A reorder
//     that leaves every record byte-identical would still silently change every
//     encounter in the game; only a seeded replay catches that.
//
//  Full `RandomNumberGenerator` threading through `ExplorationService` /
//  `CombatService` is NOT needed here — the migration changes where catalog
//  data comes from, not how rolls resolve. That refactor stays a Phase 8
//  prerequisite for the simulator.
//

import Foundation

enum ContentDigest {

    /// Fixed seed and draw count. Changing either invalidates every recorded
    /// digest, so treat them as constants.
    private static let seed: UInt64 = 0x5245_4241_4C41_4E43   // "REBALANC"
    private static let drawsPerDepth = 200
    private static let maxDepth = 40

    static func run() {
        var digest = OutcomeDigest()

        for item in ItemCatalog.all { digest.combine(fingerprint(item)) }
        for enemy in EnemyCatalog.all { digest.combine(fingerprint(enemy)) }
        for recipe in RecipeCatalog.all { digest.combine(fingerprint(recipe)) }
        for id in RecipeCatalog.starterRecipeIds.sorted() { digest.combine(id) }
        for id in WeaponUpgradeCatalog.progression.keys.sorted() {
            digest.combine(id)
            for (index, step) in (WeaponUpgradeCatalog.progression[id] ?? []).enumerated() {
                digest.combine("t\(index + 1)")
                digest.combine("\(step.stats.attack)/\(step.stats.defense)/\(step.stats.crit)/\(step.stats.dodge)/\(step.stats.accuracy)")
                for input in step.inputs { digest.combine("\(input.itemId)x\(input.quantity)") }
            }
        }
        for durability in WeaponUpgradeCatalog.durabilityByTier { digest.combine(durability) }

        digest.combine(BagCatalog.maxTier)
        for capacity in BagCatalog.capacities { digest.combine(capacity) }
        for step in BagCatalog.progression { digest.combine(fingerprint(step)) }

        digest.combine(EstateUpgradeCatalog.maxTier)
        for step in EstateUpgradeCatalog.progression { digest.combine(fingerprint(step)) }

        for listing in TraderCatalog.all {
            digest.combine("\(listing.itemId) s\(listing.sellPacketQty)@\(listing.sellPacketSilver) b\(listing.buyPacketQty)@\(listing.buyPacketSilver)")
        }
        for listing in TavernCatalog.food { digest.combine("\(listing.itemId)@\(listing.priceSilver)") }
        for wager in TavernCatalog.wagerTiers { digest.combine(wager) }

        digest.combine(MarketCatalog.listingFee)
        digest.combine(MarketCatalog.maxActiveLots)

        digest.combine(GuildCatalog.memberCap)
        digest.combine(GuildCatalog.maxOfficers)
        digest.combine(GuildCatalog.foundCost)
        digest.combine(GuildCatalog.foundLevelGate)
        digest.combine(GuildCatalog.defaultEmblem)
        digest.combine(GuildCatalog.nameMinLength)
        digest.combine(GuildCatalog.nameMaxLength)
        digest.combine(GuildCatalog.vaultUnitCap)

        for stake in ArenaCatalog.stakeTiers { digest.combine(stake) }
        digest.combine(ArenaCatalog.tithePercent)
        digest.combine(ArenaCatalog.startingHonor)
        digest.combine("\(ArenaCatalog.honorKFactor)")
        digest.combine(ArenaCatalog.minHonor)
        digest.combine("\(ArenaCatalog.turnSeconds)")
        digest.combine(ArenaCatalog.maxMissedTurns)
        digest.combine("\(ArenaCatalog.challengeTTL)")
        digest.combine("\(ArenaCatalog.lobbyTTL)")
        digest.combine("\(ArenaCatalog.sweepInterval)")
        digest.combine(ArenaCatalog.dailyFightCap)
        // Replay the league boundaries rather than trusting the thresholds:
        // `leagueKey` is a switch today and a table after the move, so only
        // exercising it across the range proves the two agree.
        for honor in stride(from: 0, through: 2000, by: 5) {
            digest.combine(ArenaCatalog.leagueKey(forHonor: honor))
        }
        // Accessor replay. The record fingerprints above cover the DATA; these
        // cover the derived READS, whose bodies were rewritten when the
        // catalogs became façades. `nextStep` indexes by position, `capForTier`
        // and `durability(forTier:)` clamp — all three are exactly the kind of
        // logic a data fingerprint cannot see.
        for tier in -2...12 {
            digest.combine(BagCatalog.capForTier(tier))
            digest.combine(WeaponUpgradeCatalog.durability(forTier: tier))
            digest.combine(BagCatalog.nextStep(from: tier).map(fingerprint) ?? "-")
            digest.combine(EstateUpgradeCatalog.nextStep(from: tier).map(fingerprint) ?? "-")
            digest.combine("\(BagCatalog.canUpgrade(from: tier))")
            digest.combine("\(EstateUpgradeCatalog.canUpgrade(from: tier))")
        }
        for itemId in ["gear.rusty_sword", "gear.simple_bow", "gear.wooden_staff", "gear.forester_hood", "nope"] {
            digest.combine("\(WeaponUpgradeCatalog.isUpgradable(itemId))")
            digest.combine(WeaponUpgradeCatalog.maxTier(for: itemId).map(String.init) ?? "-")
            for tier in 0...6 {
                let stats = WeaponUpgradeCatalog.stats(for: itemId, tier: tier)
                digest.combine(stats.map { "\($0.attack)/\($0.defense)/\($0.crit)/\($0.dodge)/\($0.accuracy)" } ?? "-")
            }
        }

        // Tithe rounding is `.rounded()` on a Double — replay it too.
        for pot in stride(from: 0, through: 2000, by: 7) {
            digest.combine(ArenaCatalog.tithe(onPot: pot))
        }

        // Snapshot the record-only hash before the spawn replay folds in.
        let recordDigest = digest.hexDigest

        // Seeded encounter replay — the half that catches a reordered roster.
        var rng = SplitMix64(seed: seed)
        var spawns = OutcomeDigest()
        var counts: [String: Int] = [:]
        for km in 1...maxDepth {
            for _ in 0..<drawsPerDepth {
                let picked = EnemyCatalog.pickFor(kmDepth: km, using: &rng)
                let id = picked?.id ?? "-"
                spawns.combine(id)
                counts[id, default: 0] += 1
            }
        }
        let spawnDigest = spawns.hexDigest

        digest.combine(spawnDigest)

        print("records  \(recordDigest)   (\(ItemCatalog.all.count) items · \(EnemyCatalog.all.count) enemies · \(RecipeCatalog.all.count) recipes · \(WeaponUpgradeCatalog.progression.count) ladders · \(BagCatalog.progression.count) bag steps · \(EstateUpgradeCatalog.progression.count) estate steps)")
        print("spawns   \(spawnDigest)   (\(maxDepth) depths × \(drawsPerDepth) seeded draws)")
        print("COMBINED \(digest.hexDigest)")
        print("")
        liveLookupCheck()

        print("spawn distribution:")
        for (id, count) in counts.sorted(by: { $0.key < $1.key }) {
            print("  \(id.padding(toLength: 24, withPad: " ", startingAt: 0)) \(count)")
        }
        fflush(stdout)
    }

    /// Smoke test of the FAÇADE path rather than the data.
    ///
    /// `ContentValidator` checks referential integrity on the DTO bundle; this
    /// resolves the same references through `ItemCatalog.find` / `.items(of:)`
    /// / `RecipeCatalog.find` as the game does, so a façade that silently
    /// returns nil — a lookup dictionary built from the wrong key, a snapshot
    /// installed half-empty — is caught even though the JSON is perfect.
    private static func liveLookupCheck() {
        var problems: [String] = []

        for recipe in RecipeCatalog.all {
            for input in recipe.inputs where ItemCatalog.find(input.itemId) == nil {
                problems.append("recipe \(recipe.id) input \(input.itemId) does not resolve")
            }
            if ItemCatalog.find(recipe.output.itemId) == nil {
                problems.append("recipe \(recipe.id) output \(recipe.output.itemId) does not resolve")
            }
        }
        for enemy in EnemyCatalog.all {
            if EnemyCatalog.find(enemy.id) == nil {
                problems.append("enemy \(enemy.id) does not resolve through find()")
            }
            for drop in enemy.lootTable where ItemCatalog.find(drop.itemId) == nil {
                problems.append("enemy \(enemy.id) loot \(drop.itemId) does not resolve")
            }
        }
        for item in ItemCatalog.all {
            if ItemCatalog.find(item.id) == nil {
                problems.append("item \(item.id) does not resolve through find()")
            }
            if let taught = item.teachesRecipe, RecipeCatalog.find(taught) == nil {
                problems.append("scroll \(item.id) teaches unresolvable \(taught)")
            }
        }
        for id in RecipeCatalog.starterRecipeIds where RecipeCatalog.find(id) == nil {
            problems.append("starter recipe \(id) does not resolve")
        }
        for characterClass in CharacterClass.allCases {
            let weaponId = characterClass.starterWeaponId
            guard let weapon = ItemCatalog.find(weaponId) else {
                problems.append("\(characterClass.rawValue) starter weapon \(weaponId) does not resolve")
                continue
            }
            if weapon.slot != .mainHand {
                problems.append("\(characterClass.rawValue) starter weapon is not a main-hand item")
            }
        }
        // Grouping is a separate index from the id lookup, so check it too.
        let grouped = ItemType.allCases.reduce(0) { $0 + ItemCatalog.items(of: $1).count }
        if grouped != ItemCatalog.all.count {
            problems.append("items(of:) covers \(grouped) items but the catalog holds \(ItemCatalog.all.count)")
        }

        if problems.isEmpty {
            print("live lookups: ✅ every recipe input/output, loot id, scroll, starter recipe and starter weapon resolves through the façades")
        } else {
            print("live lookups: ❌ \(problems.count) problem(s)")
            for problem in problems.prefix(10) { print("   • \(problem)") }
        }
        print("")
    }

    // MARK: - Field-complete fingerprints
    //
    // Shared with `ContentExporter`'s layer-0 equivalence check. When a domain
    // type gains a stored property, extend the matching fingerprint in the same
    // edit — an omission here silently weakens both checks at once.

    static func fingerprint(_ step: BagUpgradeStep) -> String {
        let inputs = step.inputs.map { "\($0.itemId)x\($0.quantity)" }.joined(separator: "|")
        return "t\(step.toTier) cap\(step.capacity) estate\(step.requiredEstateLevel) \(inputs)"
    }

    static func fingerprint(_ step: EstateUpgradeStep) -> String {
        let inputs = step.inputs.map { "\($0.itemId)x\($0.quantity)" }.joined(separator: "|")
        return "t\(step.toTier) lvl\(step.requiredPlayerLevel) silver\(step.silverCost) \(inputs)"
    }

    static func fingerprint(_ item: Item) -> String {
        let effects = item.effects.map { effect -> String in
            switch effect {
            case .restoreVigor(let amount): return "vigor:\(amount)"
            case .restoreHP(let amount):    return "hp:\(amount)"
            }
        }.joined(separator: "|")
        let gear = item.gearStats.map {
            "\($0.attack)/\($0.defense)/\($0.crit)/\($0.dodge)/\($0.accuracy)"
        } ?? "-"
        return [
            item.id, item.nameKey, item.type.rawValue, "\(item.tier)", "\(item.stackable)",
            effects, item.slot?.rawValue ?? "-", gear, item.icon ?? "-",
            item.descriptionKey ?? "-", item.teachesRecipe ?? "-"
        ].joined(separator: " · ")
    }

    static func fingerprint(_ enemy: Enemy) -> String {
        let loot = enemy.lootTable
            .map { "\($0.itemId)@\($0.chance)x\($0.quantity)" }
            .joined(separator: "|")
        return [
            enemy.id, enemy.nameKey, "\(enemy.tier)", "\(enemy.hp)", "\(enemy.attack)",
            "\(enemy.defense)", "\(enemy.depthRange.lowerBound)...\(enemy.depthRange.upperBound)",
            loot, enemy.icon, "\(enemy.xpReward)"
        ].joined(separator: " · ")
    }

    static func fingerprint(_ recipe: Recipe) -> String {
        let inputs = recipe.inputs.map { "\($0.itemId)x\($0.quantity)" }.joined(separator: "|")
        return [
            recipe.id, recipe.category.rawValue, inputs,
            "\(recipe.output.itemId)x\(recipe.output.quantity)"
        ].joined(separator: " · ")
    }
}
