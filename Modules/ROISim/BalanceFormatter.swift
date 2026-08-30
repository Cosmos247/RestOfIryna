//
//  BalanceFormatter.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 30.08.2026.
//
//  Turns a sweep into the page a human reads and the findings a build fails on.
//

import Foundation
import ROIContent

public enum BalanceFormatter {

    // MARK: - Roster

    /// One shipped enemy, measured against the reference character at its own
    /// level, beside the contract its archetype states.
    public struct RosterCheck: Sendable {
        public let id: String
        public let level: Int
        public let archetype: String
        public let rounds: Distribution
        public let hpLossPercent: Distribution
        public let winRate: Double
        public let targetRounds: Double
        public let targetHPLoss: Double
        /// What the generator would have emitted for this level and archetype.
        public let generated: CombatantStats
        public let shipped: CombatantStats
    }

    public static func checkRoster(content: GameContent, runs: Int, seed: UInt64) -> [RosterCheck] {
        guard let tuning = content.tuning, let budget = content.budget else { return [] }
        let progression = tuning.progression
        let rules = CombatRules(tuning.combat)
        let simulator = FightSimulator(combat: tuning.combat, vigor: tuning.vigor)
        let classes = progression.classes.map(\.characterClass)
        let archetypes = Dictionary(content.enemyArchetypes.map { ($0.id, $0) },
                                    uniquingKeysWith: { first, _ in first })

        var out: [RosterCheck] = []
        for enemy in content.enemies {
            // Enemies with no depth range are never rolled by exploration —
            // the training dummy and the scripted registration dog — so
            // measuring them would report on a punching bag.
            guard let depth = enemy.depth, depth.max > 0,
                  let archetype = archetypes[enemy.archetype] else { continue }
            let archetypeId = enemy.archetype
            let level = enemy.level
            let references = classes.compactMap {
                ReferenceCharacter.build(characterClass: $0, level: level, gearOffset: 0,
                                         progression: progression, budget: budget,
                                         rarities: content.rarities)
            }
            guard references.count == classes.count else { continue }
            let shipped = CombatantStats(
                level: level, maxHP: enemy.stats.hp, attack: enemy.stats.attack,
                defense: enemy.stats.defense, crit: enemy.stats.crit,
                dodge: enemy.stats.dodge, accuracy: enemy.stats.accuracy)

            var rounds: [Double] = [], hpLoss: [Double] = [], wins = 0, total = 0
            for reference in references {
                var rng = SplitMix64(seed: BalanceSimulator.seed(seed, ["roster", enemy.id,
                                                                        reference.characterClass]))
                for _ in 0..<runs {
                    let outcome = simulator.fight(player: reference.stats,
                                                  characterClass: reference.characterClass,
                                                  enemy: shipped, profile: .basic, using: &rng)
                    rounds.append(Double(outcome.rounds))
                    hpLoss.append(outcome.hpLostPercent)
                    if outcome.won { wins += 1 }
                    total += 1
                }
            }
            let generated = EnemyGenerator.generate(archetype: archetype, level: level,
                                                    against: references.map(\.stats),
                                                    rules: rules, mobXP: progression.mobXP)
            out.append(RosterCheck(
                id: enemy.id, level: level, archetype: archetypeId,
                rounds: Distribution(rounds), hpLossPercent: Distribution(hpLoss),
                winRate: Double(wins) / Double(max(1, total)) * 100,
                targetRounds: archetype.rounds, targetHPLoss: archetype.hpLossPercent,
                generated: generated.stats, shipped: shipped))
        }
        return out
    }

    // MARK: - Rendering

    public static func render(run: BalanceRun, roster: [RosterCheck],
                              content: GameContent) -> (text: String, findings: [Finding]) {
        var out: [String] = []
        var findings: [Finding] = []
        let onCurve = 0
        let behind = -ReferenceCharacter.ladderRung

        // Provenance, both halves of it. A report gets pasted into a design doc
        // and read months later, so it has to say which DATA it measured (the
        // content summary carries the bundle hash) and which MODEL measured it.
        out.append("ROI balance report — ROISim \(ROISim.version), seed \(run.seed), "
                   + "\(run.runsPerCell) fights per cell")
        out.append(content.summaryLine)
        out.append("")

        // MARK: TTK table
        out.append("── time to kill · basic attacks only · gear on curve ─────────────────────────")
        out.append("   rnd = median rounds · hp = HP lost, median / p90 (% of max) · win = win rate")
        out.append("")
        for archetype in run.archetypes {
            out.append("  \(archetype)")
            out.append("    L     " + run.classes.map {
                pad($0, 26)
            }.joined())
            for level in run.levels {
                var line = "    " + pad("\(level)", 6)
                for cls in run.classes {
                    guard let c = run.cell(cls, level, archetype, .basic, onCurve) else {
                        line += pad("—", 26); continue
                    }
                    line += pad(String(format: "%.1f rnd  %.0f/%.0f%%  %.0f%%",
                                       c.rounds.p50, c.hpLossPercent.p50,
                                       c.hpLossPercent.p90, c.winRate), 26)
                }
                out.append(line)
            }
            out.append("")
        }

        // MARK: level invariance — the load-bearing band
        out.append("── level invariance ──────────────────────────────────────────────────────────")
        out.append("   the whole point of deriving the rating denominators from the item budget:")
        out.append("   a level-1 fight and a level-40 fight must play the same.")
        out.append("")
        out.append("   Judged on MEANS and in RELATIVE terms, unlike the tail band below. p90 is")
        out.append("   the right statistic for \"can this kill me\" and the wrong one for \"does this")
        out.append("   play the same\": HP is an integer, so at level 1 a percentile lands on a")
        out.append("   coarse grid and reports quantisation as drift. Ratios rather than points")
        out.append("   because 5 pp is a third of a trash fight and a sixteenth of an elite one.")
        out.append("")
        out.append("    class     archetype    mean HP% by level" + pad("", 22) + "HP span  rounds span")
        for archetype in run.archetypes {
            for cls in run.classes {
                let cells = run.levels.compactMap { run.cell(cls, $0, archetype, .basic, onCurve) }
                guard cells.count > 1 else { continue }
                let hp = cells.map(\.hpLossPercent.mean)
                let rounds = cells.map(\.rounds.mean)
                let hpSpan = ratio(hp)
                let roundSpan = ratio(rounds)
                // Two-sided on purpose. A ratio alone convicts the cheapest
                // fight in the game — trash costs ~8% of a bar, so a 1.3-point
                // wobble reads as 16% drift and means nothing in play. Points
                // alone would acquit an elite sliding 60% → 75%. A row has to
                // fail BOTH to be a finding.
                let hpPoints = (hp.max() ?? 0) - (hp.min() ?? 0)
                let ok = (hpSpan <= 1.15 || hpPoints <= 3.0) && roundSpan <= 1.15
                if !ok {
                    findings.append(Finding(
                        severity: .error, rule: "balance.level_invariance",
                        message: "\(cls) vs \(archetype): across levels "
                            + "\(run.levels.first ?? 0)–\(run.levels.last ?? 0) mean HP loss spans "
                            + String(format: "×%.2f (%.1f pp) and mean rounds ×%.2f",
                                     hpSpan, hpPoints, roundSpan)))
                }
                out.append("    " + pad(cls, 10) + pad(archetype, 13)
                           + pad(hp.map { String(format: "%.0f", $0) }.joined(separator: " "), 22)
                           + String(format: "  %@ ×%.2f    ×%.2f", ok ? "✅" : "❌", hpSpan, roundSpan))
            }
        }
        out.append("")

        // MARK: the tail
        out.append("── the tail ──────────────────────────────────────────────────────────────────")
        out.append("   p90, not the mean: enemy crit barely moves average HP loss and moves the")
        out.append("   tail hard, so a row that looks survivable on average can still be a death.")
        out.append("")
        for cell in run.cells where cell.profile == .basic && cell.gearOffset == onCurve {
            // The boss is designed to cost more than a full bar — consumables
            // are the mechanic, not a fallback — so it is exempt by design.
            guard cell.archetype != "boss" else { continue }
            if cell.hpLossPercent.p90 >= 100 {
                findings.append(Finding(
                    severity: .error, rule: "balance.tail_is_death",
                    message: "\(cell.characterClass) L\(cell.level) vs \(cell.archetype): "
                        + String(format: "p90 HP loss %.0f%% — one fight in ten is a death",
                                 cell.hpLossPercent.p90)))
            }
            if cell.winRate < 95 {
                findings.append(Finding(
                    severity: cell.winRate < 90 ? .error : .warning,
                    rule: "balance.win_rate",
                    message: "\(cell.characterClass) L\(cell.level) vs \(cell.archetype): "
                        + String(format: "win rate %.1f%% — a loss is a wiped backpack",
                                 cell.winRate)))
            }
            if cell.stalemateRate > 0 {
                findings.append(Finding(
                    severity: .error, rule: "balance.stalemate",
                    message: "\(cell.characterClass) L\(cell.level) vs \(cell.archetype): "
                        + String(format: "%.1f%% of fights hit the round cap with both sides alive",
                                 cell.stalemateRate)))
            }
        }
        let worst = run.cells
            .filter { $0.profile == .basic && $0.gearOffset == onCurve && $0.archetype != "boss" }
            .max { $0.hpLossPercent.p90 < $1.hpLossPercent.p90 }
        if let worst {
            // p99 beside p90 because that is the question p90 leaves open: a
            // 94% tail is survivable, and whether the one-in-a-hundred fight
            // behind it is a death is a different number entirely.
            out.append(String(format: "   worst non-boss tail: %@ L%d vs %@ — p90 %.0f%% HP, p99 %.0f%%, win %.1f%%",
                              worst.characterClass, worst.level, worst.archetype,
                              worst.hpLossPercent.p90, worst.hpLossPercent.p99, worst.winRate))
        }
        out.append("")

        // MARK: profiles
        out.append("── what techniques are worth ─────────────────────────────────────────────────")
        out.append("   basic = the passive autobattle. techniques = super on the opening action,")
        out.append("   then special attacks. The gap is the measured value of playing actively.")
        out.append("")
        out.append("   The policy is NAIVE — it spends the whole kit on every fight, including a")
        out.append("   trash mob nobody would burn a Super on. So read the trash rows as \"what the")
        out.append("   kit is worth when wasted\" and the elite rows as \"what it is worth when it")
        out.append("   matters\"; the vigor column is what the waste costs.")
        out.append("")
        out.append("    class     archetype    rounds basic→tech    HP% basic→tech      vigor")
        for cls in run.classes {
            for archetype in run.archetypes {
                let basics = run.levels.compactMap { run.cell(cls, $0, archetype, .basic, onCurve) }
                let techs = run.levels.compactMap { run.cell(cls, $0, archetype, .techniques, onCurve) }
                guard !basics.isEmpty, basics.count == techs.count else { continue }
                let b = mean(basics.map(\.rounds.mean)), t = mean(techs.map(\.rounds.mean))
                let bh = mean(basics.map(\.hpLossPercent.mean)), th = mean(techs.map(\.hpLossPercent.mean))
                let bv = mean(basics.map(\.vigor.mean)), tv = mean(techs.map(\.vigor.mean))
                out.append("    " + pad(cls, 10) + pad(archetype, 13)
                           + String(format: "%5.1f → %-5.1f (%+4.0f%%)  %5.1f → %-5.1f (%+4.0f%%)  %4.1f → %-4.1f",
                                    b, t, (t - b) / b * 100, bh, th, (th - bh) / bh * 100, bv, tv))
            }
        }
        out.append("")

        // MARK: gear offset
        out.append("── one ladder rung behind ────────────────────────────────────────────────────")
        out.append("   gear at item level L−\(ReferenceCharacter.ladderRung): what a player who has")
        out.append("   not re-geared actually walks into. Levels 1–10 are unaffected (floor at 1).")
        out.append("")
        out.append("    class     archetype    p90 HP on curve → behind    win on curve → behind")
        for cls in run.classes {
            for archetype in run.archetypes {
                let on = run.levels.compactMap { run.cell(cls, $0, archetype, .basic, onCurve) }
                let off = run.levels.compactMap { run.cell(cls, $0, archetype, .basic, behind) }
                guard !on.isEmpty, on.count == off.count else { continue }
                let a = mean(on.map(\.hpLossPercent.p90)), b = mean(off.map(\.hpLossPercent.p90))
                let wa = mean(on.map(\.winRate)), wb = mean(off.map(\.winRate))
                out.append("    " + pad(cls, 10) + pad(archetype, 13)
                           + String(format: "%5.0f%% → %-5.0f%% (%+4.0f%%)      %5.1f%% → %-5.1f%%",
                                    a, b, (b - a) / a * 100, wa, wb))
            }
        }
        out.append("")

        // MARK: class power index
        out.append("── class power index ─────────────────────────────────────────────────────────")
        out.append("   kill speed discounted by what the kill costs: 1 / (rounds × (1 + HP lost)).")
        out.append("   Printed, never banded — the metric is OURS. The ±7% the plan asks for is")
        out.append("   judged in the pace section instead, on days to the cap, which is a number")
        out.append("   the design actually stated. This table is here to show WHICH half moves.")
        out.append("")
        out.append("    archetype    " + run.classes.map { pad($0, 20) }.joined() + "spread")
        for archetype in run.archetypes {
            var indices: [Double] = []
            var line = "    " + pad(archetype, 13)
            for cls in run.classes {
                let cells = run.levels.compactMap { run.cell(cls, $0, archetype, .basic, onCurve) }
                guard !cells.isEmpty else { line += pad("—", 20); continue }
                let r = mean(cells.map(\.rounds.mean))
                let h = mean(cells.map(\.hpLossPercent.mean)) / 100
                let index = 1 / (r * (1 + h))
                indices.append(index)
                line += pad(String(format: "%.4f (%.1fr %.0f%%)", index, r, h * 100), 20)
            }
            if indices.count == run.classes.count, let lo = indices.min(), let hi = indices.max() {
                let avg = mean(indices)
                let spread = avg > 0 ? (hi - lo) / avg * 100 : 0
                line += String(format: "%.0f%%", spread)
            }
            out.append(line)
        }
        out.append("")

        // MARK: stance scaling
        if let tuning = content.tuning, let budget = content.budget {
            let progression = tuning.progression
            out.append("── do the lifts scale? ───────────────────────────────────────────────────────")
            out.append("   Phase 6 banned flat bonuses on ITEMS because the same +5 is a third of a")
            out.append("   level-1 stat line and a twentieth of a level-40 one. Phase 8C applied the")
            out.append("   same rule to the Super stances, which now lift by multiplier and hold")
            out.append("   their worth by construction. What is left flat is audited below it.")
            out.append("")
            out.append("    stance             class      lift                          vigor×")
            for row in tuning.combat.stances.byId {
                let lifts = [("attack", row.attackMultiplier), ("defense", row.defenseMultiplier),
                             ("crit", row.critMultiplier), ("accuracy", row.accuracyMultiplier),
                             ("dodge", row.dodgeMultiplier)]
                    .filter { $0.1 != 1.0 }
                    .map { String(format: "%@ ×%.2f", $0.0, $0.1) }
                    .joined(separator: "  ")
                out.append("    " + pad(row.id, 19) + pad(row.characterClass, 11)
                           + pad(lifts.isEmpty ? "nothing" : lifts, 30)
                           + String(format: "%5.1f   ✅ holds at every level", row.vigorMultiplier))
            }
            out.append("")

            // The stances are fixed; these two are the same defect, still live.
            // Reported rather than changed, because nobody asked for them yet —
            // but a number nobody has seen is a number nobody can decide about.
            out.append("    still flat — the same rot, in the techniques the stances sit beside:")
            let flats: [(String, String, Int, (CombatantStats) -> Int)] = [
                ("shadowVeilDodgeBonus", "archer",
                 tuning.combat.specialDefense.shadowVeilDodgeBonus, { $0.dodge }),
                ("defend.archerDodgeBonus", "archer",
                 tuning.combat.defend.archerDodgeBonus, { $0.dodge }),
            ]
            for (name, cls, bonus, stat) in flats {
                guard bonus != 0,
                      let low = ReferenceCharacter.build(
                        characterClass: cls, level: 1, gearOffset: 0, progression: progression,
                        budget: budget, rarities: content.rarities),
                      let high = ReferenceCharacter.build(
                        characterClass: cls, level: progression.maxLevel, gearOffset: 0,
                        progression: progression, budget: budget, rarities: content.rarities)
                else { continue }
                let atOne = Double(bonus) / Double(Swift.max(1, stat(low.stats))) * 100
                let atCap = Double(bonus) / Double(Swift.max(1, stat(high.stats))) * 100
                let holds = atCap >= atOne * 0.5
                out.append("    " + pad(name, 30)
                           + String(format: "+%d dodge = %.0f%% at L1, %.0f%% at L%d   %@",
                                    bonus, atOne, atCap, progression.maxLevel,
                                    holds ? "✅ holds" : "❌ rots"))
                if !holds {
                    findings.append(Finding(
                        severity: .warning, rule: "balance.flat_bonus_rots",
                        message: String(format: "%@ is +%d on a rating the reference %@ grows five-fold: %.0f%% of it at level 1, %.0f%% at the cap — the stances were fixed in 8C, this one was not",
                                        name, bonus, cls, atOne, atCap)))
                }
            }
            out.append("")
        }

        // MARK: pace
        if let tuning = content.tuning {
            let progression = tuning.progression
            let exploration = tuning.exploration
            // Fresh rooms only. A real expedition re-enters rooms and the
            // encounter weight decays to 20 and then to 0, so this is the
            // CHEAPEST way to find a fight — every real route costs more, and
            // the pace below is therefore a floor on the time, not a promise.
            let fresh = exploration.weightTiers.first { $0.priorVisits == 0 }
            let stepsPerEncounter = (fresh?.encounter ?? 0) > 0
                ? Double(exploration.eventWeightTotal) / Double(fresh!.encounter) : 0
            let walkCost = Double(tuning.vigor.drain.walkRoom) * stepsPerEncounter
            let regenPerDay = progression.vigorPool.fullRegenHours > 0
                ? 24 / progression.vigorPool.fullRegenHours : 0

            out.append("── pace to the level cap ─────────────────────────────────────────────────────")
            out.append(String(format: "   a kill is %.1f rooms of walking (%.0f vigor) plus the fight;",
                              stepsPerEncounter, walkCost))
            out.append(String(format: "   a day is one full pool plus %.0f× regen, and every point is spent on combat.",
                              regenPerDay))
            out.append("   Nobody plays like that, so read the day count as a floor: the fastest")
            out.append("   possible run against level-matched `normal` mobs, with no travel, no")
            out.append("   crafting, no market and no sleep.")
            out.append("")
            let totalXP = ProgressionMath.totalXP(toReach: progression.maxLevel,
                                                  curve: progression.xpCurve,
                                                  maxLevel: progression.maxLevel)
            out.append(String(format: "   %d XP from level 1 to %d.", totalXP, progression.maxLevel))
            out.append("")
            out.append("    class     vigor/kill  kills to 40  taps to 40   days at 100% of the budget")
            var daysByClass: [(String, Double)] = []
            for cls in run.classes {
                let cells = run.levels.compactMap { run.cell(cls, $0, "normal", .basic, onCurve) }
                guard !cells.isEmpty else { continue }
                let vigorPerFight = mean(cells.map(\.vigor.mean))
                let roundsPerFight = mean(cells.map(\.rounds.mean))
                let vigorPerKill = vigorPerFight + walkCost
                guard let normal = content.enemyArchetypes.first(where: { $0.id == "normal" }) else { continue }

                var kills = 0.0, days = 0.0, taps = 0.0
                for level in 1..<progression.maxLevel {
                    let needed = ProgressionMath.xpRequiredToReach(level + 1, curve: progression.xpCurve,
                                                                   maxLevel: progression.maxLevel)
                    guard needed != Int.max else { continue }
                    let xpPerKill = progression.mobXP.coefficient
                        * pow(Double(level), progression.mobXP.exponent) * normal.xpMultiplier
                    guard xpPerKill > 0 else { continue }
                    let killsHere = Double(needed) / xpPerKill
                    let pool = Double(ProgressionMath.maxVigor(at: level, pool: progression.vigorPool))
                    let vigorPerDay = pool * (1 + regenPerDay)
                    kills += killsHere
                    taps += killsHere * (roundsPerFight + stepsPerEncounter)
                    days += killsHere * vigorPerKill / vigorPerDay
                }
                out.append("    " + pad(cls, 10)
                           + String(format: "%6.1f      %8.0f     %8.0f     %6.1f",
                                    vigorPerKill, kills, taps, days))
                daysByClass.append((cls, days))
                if days > 200 {
                    findings.append(Finding(
                        severity: .warning, rule: "pace.too_slow",
                        message: String(format: "%@ needs %.0f perfect days to reach the cap — the design asks for 3+ months of REAL play, and this floor already exceeds it",
                                        cls, days)))
                } else if days < 45 {
                    findings.append(Finding(
                        severity: .warning, rule: "pace.too_fast",
                        message: String(format: "%@ can reach the cap in %.0f perfect days — the design asks for 3+ months",
                                        cls, days)))
                }
            }

            // The plan's ±7% band, on the number it was stated about. Every
            // class fights the same enemies with the same Vigor budget, so a
            // spread here is the whole class imbalance in one figure: the
            // slowest class simply reaches the cap that much later.
            if daysByClass.count > 1 {
                let values = daysByClass.map(\.1)
                let avg = mean(values)
                let spread = avg > 0 ? ((values.max() ?? 0) - (values.min() ?? 0)) / avg * 100 : 0
                out.append(String(format: "    spread %.0f%% — the plan asks for each class within ±7%% of the mean",
                                  spread))
                if spread > 14, let slow = daysByClass.max(by: { $0.1 < $1.1 }),
                   let fast = daysByClass.min(by: { $0.1 < $1.1 }) {
                    findings.append(Finding(
                        severity: .warning, rule: "balance.class_pace_spread",
                        message: String(format: "days to the cap span %.0f%% — %@ needs %.0f where %@ needs %.0f, on the same Vigor budget",
                                        spread, slow.0, slow.1, fast.0, fast.1)))
                }
            }
            out.append("")
        }

        // MARK: roster
        if !roster.isEmpty {
            out.append("── shipped bestiary vs its own archetype contract ────────────────────────────")
            out.append("   measured against the on-curve reference character at the enemy's level,")
            out.append("   averaged over all three classes.")
            out.append("")
            out.append("    enemy                 L  archetype   rounds     HP% p50/p90  win     HP shipped/wanted  ATK")
            for check in roster {
                out.append("    " + pad(check.id, 22) + pad("\(check.level)", 3)
                           + pad(check.archetype, 12)
                           + String(format: "%4.1f/%-4.1f  %3.0f/%-4.0f    %5.1f%%  %5d/%-5d      %3d/%-3d",
                                    check.rounds.p50, check.targetRounds,
                                    check.hpLossPercent.p50, check.hpLossPercent.p90,
                                    check.winRate,
                                    check.shipped.maxHP, check.generated.maxHP,
                                    check.shipped.attack, check.generated.attack))
                let hpRatio = Double(check.shipped.maxHP) / Double(max(1, check.generated.maxHP))
                let atkRatio = Double(check.shipped.attack) / Double(max(1, check.generated.attack))
                if hpRatio < 0.75 || hpRatio > 1.33 || atkRatio < 0.75 || atkRatio > 1.33 {
                    findings.append(Finding(
                        severity: .warning, rule: "content.roster_off_curve",
                        message: String(format: "%@ carries %.0f%% of the HP and %.0f%% of the ATK its archetype asks for at L%d",
                                        check.id, hpRatio * 100, atkRatio * 100, check.level)))
                }
            }
            out.append("")
        }

        return (out.joined(separator: "\n"), findings)
    }

    // MARK: - Helpers

    /// Max ÷ min. The scale-free way to ask "is this the same fight" — a
    /// difference of points means something different at 8% than at 80%.
    static func ratio(_ values: [Double]) -> Double {
        guard let lo = values.min(), let hi = values.max(), lo > 0 else { return 1 }
        return hi / lo
    }

    static func mean(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }

    static func pad(_ text: String, _ width: Int) -> String {
        text.count >= width ? text + " " : text + String(repeating: " ", count: width - text.count)
    }
}
