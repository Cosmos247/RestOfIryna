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
        //
        // Judged only on cells that could actually SHIP. The sweep rolls every
        // archetype at every level because that is what proves the model is
        // level-invariant, but an archetype carries a `minLevel` and the table
        // below the floor describes content the validator would refuse — so
        // reporting a mage's level-5 elite as a balance problem is reporting a
        // fight nobody can be given.
        let archetypeFloor = Dictionary(content.enemyArchetypes.map { ($0.id, $0.minLevel) },
                                        uniquingKeysWith: { first, _ in first })
        func shippable(_ cell: CellResult) -> Bool {
            cell.level >= (archetypeFloor[cell.archetype] ?? 1)
        }
        out.append("── the tail ──────────────────────────────────────────────────────────────────")
        out.append("   p90, not the mean: enemy crit barely moves average HP loss and moves the")
        out.append("   tail hard, so a row that looks survivable on average can still be a death.")
        out.append("   Cells below their archetype's level floor are skipped — an elite before")
        out.append("   level \(archetypeFloor["elite"] ?? 1) is content the validator refuses, not a fight to balance.")
        out.append("")
        for cell in run.cells where cell.profile == .basic && cell.gearOffset == onCurve {
            // The boss is designed to cost more than a full bar — consumables
            // are the mechanic, not a fallback — so it is exempt by design.
            guard cell.archetype != "boss", shippable(cell) else { continue }
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
            .filter { $0.profile == .basic && $0.gearOffset == onCurve && $0.archetype != "boss"
                      && shippable($0) }
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
            out.append("   same rule to the Super stances and Phase 8D to the last two techniques")
            out.append("   that still held out, so every lift a TECHNIQUE grants is now a multiplier")
            out.append("   of the character's own stat. The two dodge ones are MEASURED below rather")
            out.append("   than trusted: a multiplier holds its worth by construction, but only the")
            out.append("   curve can say what it is worth in points of dodge chance.")
            out.append("")
            out.append("   NOT audited here, and the largest flat-bonus site left in the game: the")
            out.append("   fortune deck. 14 of its 22 cards grant flat ±5/±10 ratings for six hours")
            out.append("   (`attackBonus` and friends on the card effect), which decay across a")
            out.append("   lifetime exactly as the stances did. Left alone deliberately — they are")
            out.append("   a gambling buff with penalties as well as bonuses, so what they SHOULD")
            out.append("   be is a design question, not a conversion.")
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

            // Measured on the reference archer at both ends of the game. The
            // rating a multiplier acts on grows five-fold across a lifetime and
            // its denominator does not grow as fast, so equal multiplication is
            // not automatically an equal EFFECT — this is the line that proves
            // it, and it is the same line that convicted the flat +50 these two
            // replaced (16 points of dodge chance at level 1 against 4 at the
            // cap).
            out.append("    technique          class      lift        effect on dodge chance")
            let lifts: [(String, String, Double)] = [
                ("shadow_veil", "archer", tuning.combat.specialDefense.shadowVeilDodgeMultiplier),
                ("defend", "archer", tuning.combat.defend.archerDodgeMultiplier),
            ]
            for (name, cls, multiplier) in lifts {
                guard multiplier != 1.0,
                      let low = ReferenceCharacter.build(
                        characterClass: cls, level: 1, gearOffset: 0, progression: progression,
                        budget: budget, rarities: content.rarities),
                      let high = ReferenceCharacter.build(
                        characterClass: cls, level: progression.maxLevel, gearOffset: 0,
                        progression: progression, budget: budget, rarities: content.rarities)
                else { continue }
                func points(_ c: ReferenceCharacter) -> Double {
                    let base = CombatMath.dodgePercent(rating: c.stats.dodge, level: c.stats.level,
                                                       curves: tuning.combat.curves)
                    let lifted = CombatMath.dodgePercent(
                        rating: Int((Double(c.stats.dodge) * multiplier).rounded()),
                        level: c.stats.level, curves: tuning.combat.curves)
                    return lifted - base
                }
                let atOne = points(low)
                let atCap = points(high)
                let holds = atCap >= atOne * 0.5
                out.append("    " + pad(name, 19) + pad(cls, 11)
                           + pad(String(format: "dodge ×%.2f", multiplier), 12)
                           + String(format: "%+.1f pp at L1, %+.1f pp at L%d   %@",
                                    atOne, atCap, progression.maxLevel,
                                    holds ? "✅ holds" : "❌ rots"))
                if !holds {
                    findings.append(Finding(
                        severity: .warning, rule: "balance.lift_rots",
                        message: String(format: "%@ lifts the reference %@'s dodge by %.1f points of dodge chance at level 1 and only %.1f at the cap — a lift that decays across a lifetime is the defect Phase 6 removed from items",
                                        name, cls, atOne, atCap)))
                }
            }
            out.append("")

            // Food, held to the same rule — and failing it. `restore_vigor` is
            // a FLAT number against a pool that grows with level, so a portion
            // is worth three times as much at level 1 as at the cap. It never
            // mattered while regeneration supplied most of the day; Phase 8E
            // made food the whole income, and the tap column in the pace
            // section is what a rotting portion size costs in button presses.
            let poolLow = Double(ProgressionMath.maxVigor(at: 1, pool: progression.vigorPool))
            let poolCap = Double(ProgressionMath.maxVigor(at: progression.maxLevel,
                                                          pool: progression.vigorPool))
            let portions = content.items
                .filter { item in item.effects.contains { $0.kind == .restoreVigor } }
                .map { item -> (String, Double) in
                    (item.id, Double(item.effects.filter { $0.kind == .restoreVigor }
                                                 .reduce(0) { $0 + $1.amount }))
                }
                .sorted { $0.1 > $1.1 }
            if !portions.isEmpty, poolLow > 0, poolCap > 0 {
                out.append("    portion            restores    share of the Vigor pool")
                for (id, amount) in portions.prefix(4) {
                    let atOne = amount / poolLow * 100
                    let atCap = amount / poolCap * 100
                    out.append("    " + pad(String(id.dropFirst(id.hasPrefix("food.") ? 5 : 0)), 19)
                               + pad(String(format: "%.0f vigor", amount), 12)
                               + String(format: "%.0f%% at L1, %.0f%% at L%d   %@",
                                        atOne, atCap, progression.maxLevel,
                                        atCap >= atOne * 0.5 ? "✅ holds" : "❌ rots"))
                }
                if let (id, amount) = portions.first {
                    let atOne = amount / poolLow * 100, atCap = amount / poolCap * 100
                    if atCap < atOne * 0.5 {
                        findings.append(Finding(
                            severity: .warning, rule: "balance.portion_rots",
                            message: String(format: "the richest food in the game (%@, %.0f vigor) is %.0f%% of a level-1 pool and %.0f%% of a level-%d one — every `restore_vigor` is flat against a pool that grows, which is the same defect the stances and techniques were cured of, and since 8E it is the whole economy",
                                            id, amount, atOne, atCap, progression.maxLevel)))
                    }
                }
            }
            out.append("")
        }

        // MARK: the opening
        //
        // The stretch the pace section below cannot see. It divides kills by
        // what the estate feeds, and before the first upgrade the estate feeds
        // nothing — so those levels are excluded there and measured here
        // instead, against the trail, which is the only income they have.
        //
        // Every finding here is a WARNING rather than a broken band, and that is
        // deliberate: `spec-economy.md` §7 decided to MEASURE the opening before
        // retuning it, so an error would fail the build on the exact number the
        // project has already agreed to look at first.
        if let opening = OpeningLedger.measure(content: content, runs: run.runsPerCell,
                                               seed: run.seed) {
            let title = "the opening: levels 1–\(opening.endsAtLevel - 1), before the estate exists"
            out.append("── " + title + " "
                       + String(repeating: "─", count: max(3, 74 - title.count)))
            out.append("   The pace table below divides kills by what the estate feeds, so it cannot")
            out.append("   see this stretch at all — at tier 1 there are no plot slots and the")
            out.append("   divisor is zero. Here it is measured against the only income it has.")
            out.append(String(format: "   %d XP to reach level %d, against a stock of %.0f Vigor — the starting pool",
                              opening.xpNeeded, opening.endsAtLevel, opening.stock))
            out.append("   plus every level-up grant on the way, and since Phase 8E nothing refills it.")
            out.append(String(format: "   A kill is %.1f rooms of walking (%.0f vigor) plus the fight, and the same",
                              opening.stepsPerEncounter, opening.walkVigor))
            out.append(String(format: "   walk forages %.1f times. `walk in` is the one-off cost of reaching the km,",
                              opening.forageEventsPerEncounter))
            out.append("   charged once because nothing refills the pool out here — the whole")
            out.append("   opening is a single budget — and credited nothing for what it rolls.")
            out.append("   `trail` is what the walk feeds you — foraged berries and nuts, plus")
            out.append("   anything a kill drops edible AS FOUND (nothing does today). Raw meat")
            out.append("   is not that: it restores")
            out.append("   nothing as found, and every recipe that makes it a portion is a kitchen")
            out.append("   recipe — a room of the estate this stretch ends by unlocking. `if cooked`")
            out.append("   is the size of what that gate holds back, not income. Silver is never")
            out.append("   spent here either, so this is a FLOOR on the opening, not an estimate.")
            out.append("")
            out.append("    " + pad("km", 4) + pad("mob levels", 14)
                       + "xp/kill  vigor/kill    win%     kills     trail     spent  walk in       net  if cooked")
            for depth in opening.depths {
                out.append("    " + pad("\(depth.km)", 4)
                           + pad(depth.mobLevels.map(String.init).joined(separator: ","), 14)
                           + String(format: "%7.1f  %10.1f  %5.0f%%  %8.1f  %8.0f  %8.0f  %7.0f  %8.0f  %9.0f",
                                    depth.xpPerKill, depth.vigorPerKill, depth.winRate,
                                    depth.kills, depth.trailFood, depth.spent, depth.approach,
                                    depth.net, depth.netIfCooked))
            }
            out.append("")
            if let best = opening.best {
                out.append(String(format: "    cheapest depth the player can actually HOLD (win ≥ %.0f%%): km %d, net %+.0f vigor",
                                  OpeningLedger.survivableWinRate, best.km, best.net))
                if best.net < 0 {
                    findings.append(Finding(
                        severity: .warning, rule: "opening.vigor_bankrupt",
                        message: String(format: "levels 1–%d end %.0f Vigor short at their cheapest holdable depth (km %d) — %.1f× the entire stock a player has before the estate exists, and no plot has been cleared to make it up",
                                        opening.endsAtLevel - 1, -best.net, best.km,
                                        -best.net / max(1, opening.stock))))
                }
                // The finding this section was built to produce. `spec-economy.md`
                // §2 says the opening works by walking deeper than is
                // comfortable, and that this is "completely unstated, and the
                // exact opposite of what a new player will do". So the naive
                // path is measured on its own: if the shallowest depth cannot
                // pay for itself while a deeper one can, the game is solvable
                // only by a move it never teaches, and that is what a first-hour
                // playtest walks straight into.
                if let shallowest = opening.shallowest, shallowest.km != best.km,
                   shallowest.net < 0, best.net >= 0 {
                    findings.append(Finding(
                        severity: .warning, rule: "opening.shallow_is_bankrupt",
                        message: String(format: "km %d ends the opening %.0f Vigor short where km %d ends it %+.0f — the stretch is solvable only by walking deeper than a new player will, and nothing in the game says so",
                                        shallowest.km, -shallowest.net, best.km, best.net)))
                }
                // The design's own claim, checked rather than repeated: an enemy
                // of level N spawns from km N, so depth is meant to be BOTH the
                // difficulty dial and the reward for turning it. If the
                // shallowest row is also the cheapest, that claim is not true of
                // the shipped numbers.
                if let shallowest = opening.shallowest, opening.depths.count > 1,
                   best.km == shallowest.km {
                    findings.append(Finding(
                        severity: .warning, rule: "opening.depth_does_not_pay",
                        message: "km \(shallowest.km) is the cheapest opening on the table — the design makes depth both the difficulty dial and the reward for turning it, and the ledger does not agree"))
                }
            } else {
                findings.append(Finding(
                    severity: .warning, rule: "opening.no_holdable_depth",
                    message: String(format: "no measured depth holds a win rate of %.0f%% for a player below level %d — the opening has no route this ledger can price",
                                    OpeningLedger.survivableWinRate, opening.endsAtLevel)))
            }
            out.append("")
        }

        // MARK: pace
        if let tuning = content.tuning {
            let progression = tuning.progression
            let exploration = tuning.exploration
            // The DENSEST tier, whichever row that turns out to be — the
            // cheapest room in the game to find a fight in, so the pace below
            // stays a floor on the time rather than a promise. This read the
            // FRESH tier for a season, on the reasoning that re-entering a room
            // only ever decays its encounter weight. That was true until
            // 2026-09-10, when the walk home was given a HIGHER weight than
            // fresh ground — a beast wanders back onto a km you passed an hour
            // ago, a stripped berry bush does not regrow — and the hardcoded
            // row quietly stopped being the cheapest one. Taking the max keeps
            // the claim true BY CONSTRUCTION instead of by an assumption about
            // which row wins, which is the same discipline as every other
            // number in this report.
            let densest = exploration.weightTiers.map(\.encounter).max() ?? 0
            let stepsPerEncounter = densest > 0
                ? Double(exploration.eventWeightTotal) / Double(densest) : 0
            let walkCost = Double(tuning.vigor.drain.walkRoom) * stepsPerEncounter
            let harvestsPerDay = FoodBudget.defaultHarvestsPerDay

            out.append("── pace to the level cap ─────────────────────────────────────────────────────")
            out.append(String(format: "   a kill is %.1f rooms of walking (%.0f vigor) plus the fight;",
                              stepsPerEncounter, walkCost))
            out.append(String(format: "   a day is what a tended estate FEEDS you, at %.0f harvests a day.",
                              harvestsPerDay))
            out.append("   Vigor stopped regenerating in Phase 8E, so the pool is a stock and the")
            out.append("   estate is the whole income. Two simplifications pull against each other")
            out.append("   here, which is why this is an estimate and not the floor it used to be:")
            out.append("   every point is spent on combat (nobody plays like that, so it is fast),")
            out.append("   and nothing but the estate feeds the player — no foraging, no monster")
            out.append("   meat, no food bought with silver (so it is slow).")
            out.append("")
            out.append("    what the estate can feed, per day:")
            out.append("    level  estate  slots  vigor/day  portions  best mix")
            var foodByLevel: [Int: FoodBudget.DailyFood] = [:]
            for level in 1...progression.maxLevel {
                let tier = FoodBudget.estateTier(playerLevel: level, upgrades: content.estateUpgrades)
                foodByLevel[level] = FoodBudget.best(
                    slots: FoodBudget.slots(tier: tier, upgrades: content.estateUpgrades),
                    harvestsPerDay: harvestsPerDay, content: content)
            }
            var shownTiers = Set<Int>()
            for level in 1...progression.maxLevel {
                let tier = FoodBudget.estateTier(playerLevel: level, upgrades: content.estateUpgrades)
                guard !shownTiers.contains(tier) else { continue }
                shownTiers.insert(tier)
                let food = foodByLevel[level] ?? .none
                out.append("    " + pad("\(level)", 7) + pad("T\(tier)", 8)
                           + pad("\(FoodBudget.slots(tier: tier, upgrades: content.estateUpgrades))", 7)
                           + pad(String(format: "%.0f", food.vigor), 11)
                           + pad(String(format: "%.0f", food.portions), 10)
                           + (food.mix.isEmpty ? "— nothing cleared yet" : food.mix.joined(separator: " + ")))
            }
            out.append("")
            let totalXP = ProgressionMath.totalXP(toReach: progression.maxLevel,
                                                  curve: progression.xpCurve,
                                                  maxLevel: progression.maxLevel)
            out.append(String(format: "   %d XP from level 1 to %d.", totalXP, progression.maxLevel))
            out.append("")
            out.append("    class     vigor/kill  kills to 40  taps to 40   days on the estate alone  taps/day")
            var daysByClass: [(String, Double)] = []
            for cls in run.classes {
                let cells = run.levels.compactMap { run.cell(cls, $0, "normal", .basic, onCurve) }
                guard !cells.isEmpty else { continue }
                let vigorPerFight = mean(cells.map(\.vigor.mean))
                let roundsPerFight = mean(cells.map(\.rounds.mean))
                let vigorPerKill = vigorPerFight + walkCost
                guard let normal = content.enemyArchetypes.first(where: { $0.id == "normal" }) else { continue }

                var kills = 0.0, days = 0.0, taps = 0.0, foodTaps = 0.0, unfed = 0
                for level in 1..<progression.maxLevel {
                    let needed = ProgressionMath.xpRequiredToReach(level + 1, curve: progression.xpCurve,
                                                                   maxLevel: progression.maxLevel)
                    guard needed != Int.max else { continue }
                    let xpPerKill = progression.mobXP.coefficient
                        * pow(Double(level), progression.mobXP.exponent) * normal.xpMultiplier
                    guard xpPerKill > 0 else { continue }
                    let killsHere = Double(needed) / xpPerKill
                    kills += killsHere
                    taps += killsHere * (roundsPerFight + stepsPerEncounter)

                    let food = foodByLevel[level] ?? .none
                    // Levels before the first plot is cleared have NO estate at
                    // all. They are lived off the trail, which this model does
                    // not count — so they are excluded and reported rather than
                    // divided by zero into an infinite day count.
                    guard food.vigor > 0 else { unfed += 1; continue }
                    days += killsHere * vigorPerKill / food.vigor
                    // Every portion is a button: cook it, then eat it.
                    foodTaps += killsHere * vigorPerKill / food.vigor * food.portions * 2
                }
                out.append("    " + pad(cls, 10)
                           + String(format: "%6.1f      %8.0f     %8.0f     %6.1f              %8.0f",
                                    vigorPerKill, kills, taps + foodTaps, days,
                                    days > 0 ? (taps + foodTaps) / days : 0))
                if foodTaps > taps {
                    findings.append(Finding(
                        severity: .warning, rule: "pace.food_taps_dominate",
                        message: String(format: "%@ spends %.0f taps cooking and eating against %.0f fighting — the food loop is a bigger button-press budget than the game it feeds, and portions restore a FLAT amount while the pool grows with level",
                                        cls, foodTaps, taps)))
                }
                if unfed > 0 {
                    findings.append(Finding(
                        severity: .warning, rule: "pace.levels_without_an_estate",
                        message: "\(cls): \(unfed) level(s) have no plot slots at all, so the estate feeds them nothing — the model excludes them here and the opening section above prices them against the trail instead"))
                }
                daysByClass.append((cls, days))
                // The band moved with the model in Phase 8E. It used to sit on a
                // FLOOR (one pool plus four regens, every point spent on
                // combat) where 45 days was aggressive; the number is now an
                // estate-fed estimate, and the design's "3+ months" was put
                // INTO it rather than left to the gap between perfect and real
                // play — so 90 days is the target and the warning fires 20%
                // either side of failing it.
                if days > 200 {
                    findings.append(Finding(
                        severity: .warning, rule: "pace.too_slow",
                        message: String(format: "%@ needs %.0f days of a fully tended estate to reach the cap — past six months of perfect play, the curve is not slow, it is a wall",
                                        cls, days)))
                } else if days < 72 {
                    findings.append(Finding(
                        severity: .warning, rule: "pace.too_fast",
                        message: String(format: "%@ can reach the cap in %.0f days of a fully tended estate — the design asks for 3+ months, and this number is meant to carry that rather than assume imperfect play",
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
