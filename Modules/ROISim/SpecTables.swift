//
//  SpecTables.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 31.08.2026.
//
//  The numbers a content specification quotes, emitted from the curves that
//  will generate the content itself.
//
//  Phase 9's rule is that the list gets signed off before it reaches JSON — and
//  a specification full of hand-typed numbers is a fourth transcription of the
//  same curves, rotting from the moment a coefficient moves. So the prose and
//  the design calls are written by a human, and every table is printed by the
//  code that owns the maths: `ProgressionMath` for the XP ladder and the stat
//  line, `EnemyGenerator` for what an archetype asks for at a level,
//  `BudgetMath` for what an item of a slot and rarity may spend.
//
//  This is also the seed of Phase 10's generator. The spec is what the
//  generator will emit, one step earlier and in a format a person can argue
//  with.
//

import Foundation
import ROIContent

public enum SpecTables {

    // MARK: - Progression

    /// The XP ladder, the Vigor pool and each class's stat line.
    ///
    /// Every level from 1 to 15 (the band Phase 10 authors in full) and then
    /// every fifth to the cap, because past 15 the interesting thing is the
    /// shape rather than the row.
    public static func progression(content: GameContent) -> String {
        guard let tuning = content.tuning else { return "" }
        let p = tuning.progression
        var out: [String] = []

        let total = ProgressionMath.totalXP(toReach: p.maxLevel, curve: p.xpCurve,
                                            maxLevel: p.maxLevel)
        out.append("| L | XP to next | cumulative | % of the climb | max Vigor | warrior HP/ATK/DEF | archer HP/ATK/DEF | mage HP/ATK/DEF |")
        out.append("|---|---|---|---|---|---|---|---|")

        var cumulative = 0
        for level in 1...p.maxLevel {
            let next = ProgressionMath.xpRequiredToReach(level + 1, curve: p.xpCurve,
                                                        maxLevel: p.maxLevel)
            let toNext = next == Int.max ? 0 : next
            let shown = level <= 15 || level % 5 == 0 || level == p.maxLevel
            if shown {
                var cells: [String] = []
                for cls in ["warrior", "archer", "mage"] {
                    guard let start = p.classes.first(where: { $0.characterClass == cls }) else {
                        cells.append("—"); continue
                    }
                    let s = ProgressionMath.baseStats(start: start, growth: p.statGrowth, level: level)
                    cells.append("\(s.maxHp)/\(s.attack)/\(s.defense)")
                }
                let share = total > 0 ? Double(cumulative) / Double(total) * 100 : 0
                out.append("| \(level) | \(toNext == 0 ? "—" : format(toNext)) | \(format(cumulative)) | "
                           + String(format: "%.1f%%", share)
                           + " | \(ProgressionMath.maxVigor(at: level, pool: p.vigorPool)) | "
                           + cells.joined(separator: " | ") + " |")
            }
            cumulative += toNext
        }
        out.append("")
        out.append("Total to the cap: **\(format(total)) XP**.")
        return out.joined(separator: "\n")
    }

    /// Every gate that decides what a level unlocks.
    public static func gates(content: GameContent) -> String {
        guard let tuning = content.tuning else { return "" }
        var out: [String] = []

        out.append("**Techniques** (`tuning/combat.json` → `techniques`)")
        out.append("")
        out.append("| technique | unlocks at | second use at |")
        out.append("|---|---|---|")
        for row in tuning.combat.techniques {
            out.append("| `\(row.kind)` | \(row.requiredLevel) | \(row.secondUseAtLevel) |")
        }
        out.append("")

        out.append("**Estate** (`estate_upgrades.json`) — the plot slots are the daily Vigor budget")
        out.append("")
        out.append("| tier | player level | plot slots | warehouse cap |")
        out.append("|---|---|---|---|")
        let caps = tuning.progression.warehouseCapByEstateLevel
        let slots = content.estateUpgrades.plotSlotsByTier
        for tier in 1...content.estateUpgrades.maxTier {
            let gate = content.estateUpgrades.progression.first { $0.toTier == tier }?.requiredPlayerLevel
            let slot = tier - 1 < slots.count ? slots[tier - 1] : (slots.last ?? 0)
            let cap = tier - 1 < caps.count ? caps[tier - 1] : (caps.last ?? 0)
            out.append("| T\(tier) | \(gate.map(String.init) ?? "start") | \(slot) | \(cap) |")
        }
        out.append("")

        out.append("**Bag** (`bags.json`) — gated on the ESTATE, not the player level")
        out.append("")
        out.append("| tier | estate level | slots |")
        out.append("|---|---|---|")
        for (index, capacity) in content.bags.capacities.enumerated() {
            let tier = index + 1
            let gate = content.bags.progression.first { $0.toTier == tier }?.requiredEstateLevel
            out.append("| T\(tier) | \(gate.map { "T\($0)" } ?? "start") | \(capacity) |")
        }
        return out.joined(separator: "\n")
    }

    // MARK: - Bestiary

    /// What each archetype asks for at each level, solved by the generator that
    /// will emit the roster in Phase 10.
    ///
    /// These are the numbers a named creature inherits: authoring one is
    /// choosing its level and archetype, not typing its HP.
    public static func bestiary(content: GameContent, levels: [Int]) -> String {
        guard let tuning = content.tuning, let budget = content.budget else { return "" }
        let rules = CombatRules(tuning.combat)
        var out: [String] = []
        out.append("| archetype | L | HP | ATK | DEF | absorb | crit | dodge | XP | rounds | % of a bar |")
        out.append("|---|---|---|---|---|---|---|---|---|---|---|")
        for archetype in content.enemyArchetypes {
            for level in levels where level >= archetype.minLevel {
                let references = ["warrior", "archer", "mage"].compactMap {
                    ReferenceCharacter.build(characterClass: $0, level: level, gearOffset: 0,
                                             progression: tuning.progression, budget: budget,
                                             rarities: content.rarities)?.stats
                }
                guard !references.isEmpty else { continue }
                let e = EnemyGenerator.generate(archetype: archetype, level: level,
                                                against: references, rules: rules,
                                                mobXP: tuning.progression.mobXP)
                let absorb = CombatMath.mitigation(defenderDEF: e.stats.defense,
                                                   defenderLevel: level,
                                                   curve: rules.curves.mitigation) * 100
                let crit = CombatMath.critPercent(rating: e.stats.crit, level: level,
                                                  curves: rules.curves)
                let dodge = CombatMath.dodgePercent(rating: e.stats.dodge, level: level,
                                                    curves: rules.curves)
                out.append("| \(archetype.id) | \(level) | \(e.stats.maxHP) | \(e.stats.attack) | "
                           + "\(e.stats.defense) | " + String(format: "%.0f%%", absorb) + " | "
                           + String(format: "%.0f%%", crit) + " | " + String(format: "%.0f%%", dodge)
                           + " | \(format(e.xpReward)) | " + String(format: "%.1f", archetype.rounds)
                           + " | " + String(format: "%.0f%%", archetype.hpLossPercent) + " |")
            }
        }
        return out.joined(separator: "\n")
    }

    // MARK: - Items

    /// What an item may spend, by slot and rarity, at the levels Phase 10
    /// authors. The stat lines are what a class profile turns that budget into.
    public static func items(content: GameContent, levels: [Int]) -> String {
        guard let budget = content.budget else { return "" }
        var out: [String] = []
        out.append("**Budget points** — `slotWeight × (\(format(budget.base)) + \(format(budget.perItemLevel)) × itemLevel) × rarity`")
        out.append("")
        var header = "| slot | weight |"
        var divider = "|---|---|"
        for level in levels { header += " L\(level) |"; divider += "---|" }
        out.append(header + " rarity × |")
        out.append(divider + "---|")
        let rarityRange = content.rarities.map(\.budgetMultiplier)
        for slot in budget.slotWeights {
            var row = "| `\(slot.slot)` | \(format(slot.weight)) |"
            for level in levels {
                let points = BudgetMath.points(itemLevel: level, slotWeight: slot.weight,
                                               rarityMultiplier: 1.0, curve: budget)
                row += String(format: " %.0f |", points)
            }
            let lo = rarityRange.min() ?? 1, hi = rarityRange.max() ?? 1
            out.append(row + String(format: " %.2f–%.2f |", lo, hi))
        }
        out.append("")
        out.append("**What a class profile buys with it** — the reference kit, common rarity")
        out.append("")
        out.append("| class | L | HP | ATK | DEF | crit | dodge | accuracy |")
        out.append("|---|---|---|---|---|---|---|---|")
        for profile in budget.classProfiles {
            for level in levels {
                let gear = BudgetMath.referenceGear(profile: profile, itemLevel: level,
                                                    budget: budget, rarityMultiplier: 1.0)
                out.append("| \(profile.characterClass) | \(level) | \(gear.hp) | \(gear.attack) | "
                           + "\(gear.defense) | \(gear.crit) | \(gear.dodge) | \(gear.accuracy) |")
            }
        }
        out.append("")
        out.append(contentsOf: coverage(content: content, budget: budget, levels: levels))
        return out.joined(separator: "\n")
    }

    /// What the shipped catalogue can actually put in those slots.
    ///
    /// The two tables above describe the character the balance report measures:
    /// level-appropriate gear in every weighted slot. This one describes the
    /// character a player can assemble out of the items that exist. The gap
    /// between them is not a rounding error and it is not hidden in prose —
    /// it is printed, from the same curve, so it moves when the content does.
    private static func coverage(content: GameContent, budget: BudgetTuningDTO,
                                 levels: [Int]) -> [String] {
        var out: [String] = []
        let equippable = content.items.filter { $0.slot != nil }
        out.append("**What the shipped catalogue can fill** — every equippable item there is")
        out.append("")
        out.append("| slot | weight | items | itemLevel reach |")
        out.append("|---|---|---|---|")
        for slot in budget.slotWeights {
            let members = equippable.filter { $0.slot == slot.slot }
            let reach = members.flatMap { item -> [Int] in
                if let ladder = content.weaponLaddersByItemId[item.id] {
                    return ladder.tiers.map { $0.itemLevel ?? 1 }
                }
                return [item.itemLevel ?? 1]
            }
            let span: String
            if reach.isEmpty {
                span = "**none**"
            } else if let lo = reach.min(), let hi = reach.max(), lo != hi {
                span = "\(lo) → \(hi)"
            } else {
                span = "\(reach.first ?? 1) (fixed)"
            }
            out.append("| `\(slot.slot)` | \(format(slot.weight)) | \(members.count) | \(span) |")
        }

        let enchantCeiling = content.master.map {
            1 + $0.enchantBudgetFractionPerLevel * Double($0.enchantCap)
        } ?? 1

        out.append("")
        out.append("**The obtainable kit against the on-curve kit** — budget points, best item per slot")
        out.append("")
        out.append("| L | on curve | obtainable | of curve | fully enchanted | of curve |")
        out.append("|---|---|---|---|---|---|")
        for level in levels {
            var curve = 0.0, have = 0.0
            for slot in budget.slotWeights {
                curve += BudgetMath.points(itemLevel: level, slotWeight: slot.weight,
                                           rarityMultiplier: 1.0, curve: budget)
                have += bestPoints(content: content, rate: budget.statPerPoint,
                                   slot: slot.slot, level: level) ?? 0
            }
            guard curve > 0 else { continue }
            out.append(String(format: "| %d | %.0f | %.0f | %.0f%% | %.0f | %.0f%% |",
                              level, curve, have, 100 * have / curve,
                              have * enchantCeiling, 100 * have * enchantCeiling / curve))
        }
        return out
    }

    /// Points the best shipped item in `slot` carries when it is built for a
    /// player of `level`. A ladder rung is matched by its own `itemLevel`: the
    /// rung DESIGNED at or below the level, not the rung a player has
    /// necessarily earned — nothing in `weapon_upgrades.json` gates on level, so
    /// design intent is the only honest alignment.
    private static func bestPoints(content: GameContent, rate: StatPerPointDTO,
                                   slot: String, level: Int) -> Double? {
        var best: Double?
        for item in content.items where item.slot == slot {
            let stats: GearStatsDTO?
            if let ladder = content.weaponLaddersByItemId[item.id] {
                stats = ladder.tiers
                    .filter { ($0.itemLevel ?? 1) <= level }
                    .max(by: { ($0.itemLevel ?? 1) < ($1.itemLevel ?? 1) })?.stats
                    ?? ladder.tiers.first?.stats
            } else {
                stats = item.gearStats
            }
            guard let stats else { continue }
            let points = stats.pointsSpent(at: rate)
            if points > (best ?? -1) { best = points }
        }
        return best
    }

    /// Everything a player can actually have equipped at `level`, in points.
    /// This is the denominator a `gear_multiplier` set bonus really scales.
    private static func obtainableKit(content: GameContent, budget: BudgetTuningDTO,
                                      level: Int) -> Double {
        budget.slotWeights.reduce(0.0) { total, slot in
            total + (bestPoints(content: content, rate: budget.statPerPoint,
                                slot: slot.slot, level: level) ?? 0)
        }
    }

    /// What a set bonus is WORTH, which is not the same question as what it says.
    ///
    /// `EquipmentService.recomputeBonuses` applies `gear_multiplier` to the
    /// wearer's whole equipped contribution — the weapon included, and the weapon
    /// is not a member of the set. So the denominator a multiplier is measured
    /// against grows with the ladder while the set stands still, and the same
    /// factor buys steadily more. The validator's 25% ceiling is measured against
    /// the MEMBERS' budget, so the two do not meet; this table is where they are
    /// put side by side.
    public static func sets(content: GameContent, levels: [Int]) -> String {
        guard let budget = content.budget else { return "" }
        let rate = budget.statPerPoint
        var out: [String] = []
        let weights = Dictionary(budget.slotWeights.map { ($0.slot, $0.weight) },
                                 uniquingKeysWith: { first, _ in first })
        let rarityBudget = Dictionary(content.rarities.map { ($0.id, $0.budgetMultiplier) },
                                      uniquingKeysWith: { first, _ in first })

        for set in content.gearSets {
            let members = content.items.filter { $0.setId == set.id }
            let memberBudget = members.reduce(0.0) { total, item in
                guard let slot = item.slot, let weight = weights[slot] else { return total }
                let rarity = rarityBudget[item.rarity ?? "common"] ?? 1.0
                return total + weight * (budget.base
                    + budget.perItemLevel * Double(item.itemLevel ?? 1)) * rarity
            }
            let memberSpend = members.reduce(0.0) { $0 + ($1.gearStats?.pointsSpent(at: rate) ?? 0) }
            let flat = set.bonuses.reduce(0.0) { total, bonus in
                guard case .flatStats(let stats) = bonus.effect else { return total }
                return total + stats.pointsSpent(at: rate)
            }
            let declared = set.bonuses.reduce(1.0) { total, bonus in
                guard case .gearMultiplier(let factor) = bonus.effect else { return total }
                return total * factor
            }
            let probe = declared > 1 ? declared : 1.05
            guard memberBudget > 0 else { continue }

            out.append("**`\(set.id)`** — \(members.count) member(s), "
                       + String(format: "%.1f", memberBudget)
                       + " points of member budget, "
                       + String(format: "%.1f", memberSpend) + " actually spent")
            out.append("")
            out.append("| L | kit worn | flat \(String(format: "%.1f", flat)) pts | ×\(String(format: "%.2f", probe)) on the KIT | ×\(String(format: "%.2f", probe)) on MEMBERS | cap allows, kit | cap allows, members |")
            out.append("|---|---|---|---|---|---|---|")
            for level in levels {
                let kit = obtainableKit(content: content, budget: budget, level: level)
                guard kit > 0 else { continue }
                let onKit = (probe - 1) * kit
                let onMembers = (probe - 1) * memberSpend
                out.append(String(
                    format: "| %d | %.0f | %.0f%% | %.1f = %.0f%% | %.1f = %.0f%% | ×%.2f | ×%.2f |",
                    level, kit,
                    100 * flat / memberBudget,
                    onKit, 100 * onKit / memberBudget,
                    onMembers, 100 * onMembers / memberBudget,
                    1 + 0.25 * memberBudget / kit,
                    1 + 0.25 * memberBudget / max(memberSpend, 0.001)))
            }
            out.append("")
            out.append("**The strength ladder** — a whole-set multiplier against the 25% ceiling")
            out.append("")
            out.append("| ×total | of the members' budget | of the ceiling |")
            out.append("|---|---|---|")
            for rung in [1.07, 1.13, 1.19, 1.24] {
                let cost = (rung - 1) * memberSpend
                out.append(String(format: "| ×%.2f | %.1f%% | %.0f%% |",
                                  rung, 100 * cost / memberBudget,
                                  100 * (cost / memberBudget) / 0.25))
            }
            out.append("")
        }
        if out.isEmpty { return "no sets in this bundle" }
        out.append("`cap allows` inverts the validator's 25%-of-members ceiling: the largest")
        out.append("multiplier that would pass, under each reading of what it scales.")
        return out.joined(separator: "\n")
    }

    /// The silver economy: what it costs to finish the game's ladders, priced at
    /// the only shop that sells the inputs, against what the game pays out.
    ///
    /// Nothing here is a new number — every row is read out of `trader.json`,
    /// the three upgrade ladders, `master.json` and the quest pools. It is
    /// collected because no single file shows whether the faucets and the drains
    /// are the same size, and that is the only question an economy spec has.
    public static func economy(content: GameContent) -> String {
        guard let trader = content.trader else { return "no trader in this bundle" }
        var out: [String] = []
        let buy = Dictionary(trader.listings.map {
            ($0.itemId, Double($0.buyPacketSilver) / Double(max(1, $0.buyPacketQty))) },
                             uniquingKeysWith: { first, _ in first })
        let sell = Dictionary(trader.listings.map {
            ($0.itemId, Double($0.sellPacketSilver) / Double(max(1, $0.sellPacketQty))) },
                              uniquingKeysWith: { first, _ in first })

        out.append("**The trader's spread** — per unit, the only shop that both buys and sells")
        out.append("")
        out.append("| item | player pays | player receives | round trip |")
        out.append("|---|---|---|---|")
        for row in trader.listings {
            let b = buy[row.itemId] ?? 0, s = sell[row.itemId] ?? 0
            out.append(String(format: "| `%@` | %.0f | %.0f | −%.0f%% |",
                              row.itemId, b, s, b > 0 ? 100 * (1 - s / b) : 0))
        }

        func priced(_ inputs: [MaterialCostDTO]) -> Double {
            inputs.reduce(0.0) { $0 + (buy[$1.itemId] ?? 0) * Double($1.quantity) }
        }

        out.append("")
        out.append("**Every ladder, priced at those buy prices** — the cost of skipping the grind entirely")
        out.append("")
        out.append("| ladder | materials | direct silver |")
        out.append("|---|---|---|")
        var total = 0.0
        for step in content.estateUpgrades.progression {
            let m = priced(step.inputs)
            total += m + Double(step.silverCost)
            out.append(String(format: "| estate →T%d | %.0f | %d |",
                              step.toTier, m, step.silverCost))
        }
        let bagCost = content.bags.progression.reduce(0.0) { $0 + priced($1.inputs) }
        total += bagCost
        out.append(String(format: "| bag, every step | %.0f | 0 |", bagCost))
        for (id, ladder) in content.weaponLaddersByItemId.sorted(by: { $0.key < $1.key }) {
            let c = ladder.tiers.reduce(0.0) { $0 + priced($1.inputs) }
            total += c
            out.append(String(format: "| `%@` T1→T%d | %.0f | 0 |", id, ladder.tiers.count, c))
        }
        let weaponCosts = content.weaponLaddersByItemId.values.map { ladder in
            ladder.tiers.reduce(0.0) { $0 + priced($1.inputs) }
        }
        let allWeapons = weaponCosts.reduce(0, +)
        out.append(String(format: "| **every row** | **%.0f** | |", total))
        out.append(String(format: "| **one player** — a single weapon ladder | **%.0f–%.0f** | |",
                          total - allWeapons + (weaponCosts.min() ?? 0),
                          total - allWeapons + (weaponCosts.max() ?? 0)))

        out.append("")
        out.append("**The sinks that are not a ladder**")
        out.append("")
        out.append("| sink | silver | note |")
        out.append("|---|---|---|")
        if let m = content.master {
            let ench = m.enchantSteps.reduce(0) { $0 + $1.silver }
            let gearWithItems = Set(content.items.compactMap(\.slot)).count
            out.append("| enchant one item to +\(m.enchantCap) | \(ench) | ×\(gearWithItems) filled slots = \(ench * gearWithItems) |")
            out.append("| the Master's armour | \(m.armorForSale.reduce(0) { $0 + $1.priceSilver }) | one-off |")
            out.append(String(format: "| repair | %.0f%% of value | per repair, ongoing |",
                              m.repairCostFraction * 100))
        }
        if let g = content.guild { out.append("| found a guild | \(g.foundCost) | one-off, level \(g.foundLevelGate) |") }
        if let mk = content.market { out.append("| market listing | \(mk.listingFee) | per lot, up to \(mk.maxActiveLots) |") }
        if let a = content.arena { out.append("| arena tithe | \(a.tithePercent)% of the stake | the only PvP drain |") }
        if let t = content.tavern {
            let lo = t.food.map(\.priceSilver).min() ?? 0, hi = t.food.map(\.priceSilver).max() ?? 0
            out.append("| tavern food | \(lo)–\(hi) | per dish |")
            // The only row here that is not read out of content: the payout lives in
            // `CapitalController.runRound`, so the note points at it rather than
            // pretending this table derived it.
            out.append("| tavern wagers | none | payout is in `CapitalController.runRound` — ×2 on a win, refund on a tie, so a fair die is a 0% edge |")
        }

        if let q = content.quests {
            out.append("")
            out.append("**The faucet** — one job per NPC per game day")
            out.append("")
            out.append("| NPC | jobs | average silver |")
            out.append("|---|---|---|")
            var perDay = 0.0
            for pool in q.pools {
                let avg = pool.quests.reduce(0.0) { $0 + Double($1.reward.silver) }
                    / Double(max(1, pool.quests.count))
                perDay += avg
                out.append(String(format: "| %@ | %d | %.0f |", pool.npc, pool.quests.count, avg))
            }
            out.append(String(format: "| **per day** | | **%.0f** |", perDay))
        }

        // The opening, which is the only stretch with no estate behind it and the
        // one this spec exists to correct. Generated because the number that was
        // wrong for two weeks — "about eleven kills to reach level 4" — was typed
        // into prose beside a table that was right.
        if let tuning = content.tuning?.progression,
           let boar = content.enemiesById["enemy.wild_boar"],
           let moose = content.enemiesById["enemy.wild_moose"] {
            let archXP = Dictionary(content.enemyArchetypes.map { ($0.id, $0.xpMultiplier) },
                                    uniquingKeysWith: { first, _ in first })
            func mobXP(_ level: Int, _ archetype: String) -> Double {
                tuning.mobXP.coefficient * pow(Double(level), tuning.mobXP.exponent)
                    * (archXP[archetype] ?? 1)
            }
            let toFour = (1..<4).reduce(0) {
                $0 + ProgressionMath.xpRequiredToReach($1 + 1, curve: tuning.xpCurve,
                                                       maxLevel: tuning.maxLevel)
            }
            let boarXP = Double(boar.xpReward)
            let kills = boarXP > 0 ? Double(toFour) / boarXP : 0
            let pool = ProgressionMath.maxVigor(at: 1, pool: tuning.vigorPool)
            out.append("")
            out.append("**The opening** — levels 1–3, the only stretch with no estate behind it")
            out.append("")
            out.append("| | |")
            out.append("|---|---|")
            out.append("| XP to reach level 4 | \(format(toFour)) |")
            out.append(String(format: "| `%@` at level %d | %.0f XP → **%.0f kills** |",
                              boar.id, boar.level, boarXP, kills))
            out.append("| starting Vigor pool | \(pool) |")
            out.append(String(format: "| `%@` at level %d, on curve | %.0f XP — %.0f boars |",
                              moose.id, moose.level, mobXP(moose.level, moose.archetype),
                              mobXP(moose.level, moose.archetype) / max(boarXP, 1)))
            out.append("")
            out.append("The second row is the pure-boar path at km 1–3. The last is why it is")
            out.append("not the intended one: depth is the difficulty dial from the first hour.")
        }

        // What a kill actually returns, in both currencies. The Vigor side is
        // the one that decides whether the wilderness can be walked at all
        // since Phase 8E; the silver side is the whole non-quest faucet.
        let meatVigor = content.itemsById["food.roasted_meat"]?.effects
            .filter { $0.kind == .restoreVigor }
            .reduce(0) { $0 + $1.amount } ?? 0
        if meatVigor > 0 {
            let archetypes = Dictionary(content.enemyArchetypes.map { ($0.id, $0) },
                                        uniquingKeysWith: { first, _ in first })
            out.append("")
            out.append("**What a kill returns** — cooked meat is \(meatVigor) Vigor a portion")
            out.append("")
            out.append("| enemy | L | archetype | lootMult | meat | as Vigor | hide | as silver | hide ×mult |")
            out.append("|---|---|---|---|---|---|---|---|---|")
            for enemy in content.enemies.sorted(by: { $0.level < $1.level })
            where (enemy.depth?.max ?? 0) > 0 {
                func expected(_ id: String) -> Double {
                    enemy.loot.filter { $0.itemId == id }
                        .reduce(0.0) { $0 + $1.chance * Double($1.quantity) }
                }
                let meat = expected("food.raw_meat"), hide = expected("mat.hide")
                let mult = archetypes[enemy.archetype]?.lootMultiplier ?? 1
                out.append(String(format: "| `%@` | %d | %@ | ×%.1f | %.2f | %.1f | %.2f | %.1f | %.2f |",
                                  enemy.id, enemy.level, enemy.archetype, mult,
                                  meat, meat * Double(meatVigor),
                                  hide, hide * (sell["mat.hide"] ?? 0), hide * mult))
            }
            out.append("")
            out.append("`lootMult` does not apply today — no award site reads it, so `hide`")
            out.append("is what the table says regardless of archetype. `hide ×mult` is what")
            out.append("the same row would yield if the multiplier scaled QUANTITY, which is")
            out.append("the only factor that survives: scaling `chance` saturates at 1.0, and")
            out.append("rounding a quantity of 1 collapses ×0.5/×1.0/×1.2/×1.7 into 1 or 2.")
        }
        return out.joined(separator: "\n")
    }

    // MARK: - Helpers

    private static func format(_ value: Int) -> String {
        let s = String(value)
        guard s.count > 3 else { return s }
        var out = ""
        for (index, character) in s.enumerated() {
            if index > 0 && (s.count - index) % 3 == 0 { out.append(",") }
            out.append(character)
        }
        return out
    }

    private static func format(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(format: "%g", value)
    }
}
