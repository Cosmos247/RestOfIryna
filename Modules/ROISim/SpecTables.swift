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
