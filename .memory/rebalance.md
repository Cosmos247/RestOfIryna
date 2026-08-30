# Pre-release Rebalance

Full rebuild of the game's mathematics plus the move to data-driven content.
Started 2026-08-29. Plan: `~/.claude/plans/roi-session-primer-eventual-wirth.md`.
Tracker: the "Full Rebalance" section of `TODO.md`.
Pipeline details: [content-pipeline.md](content-pipeline.md).

## Why

The numbers were never balanced — this is a broken foundation, not a mistune.
Audit findings:

| Problem | Evidence |
|---|---|
| XP curve detached from XP supply | 868,585 XP to L21, best mob 175 XP → **4,963 kills**; L20→21 alone = 1,422 rabid bears |
| DEF subtracts, so it has no scale | `max(1, ATK − DEF)`. 1 DEF ≈ 7% of a hit at L1 and 3% at L21 — which is *why* a flat +32 enchant breaks the game |
| Levels are inert | +40 HP / +8 ATK / +8 DEF over a lifetime, vs +16 ATK from one weapon and +32 DEF from an enchanted set |
| Enemies are props | `Enemy` has no crit/dodge/accuracy; combat passes `0/0/0` on the enemy side in both paths |
| Economy has no faucet and no sink | Mobs drop **no silver**; the tavern has **exactly 0% house edge**; a full enchant costs 37× the armour it enchants |
| Everything runs on test timing | All three `testMode` flags are `true` — every time gate is 60× compressed |

## Locked decisions

| Question | Decision |
|---|---|
| Depth | Full data-driven — content and tuning constants in JSON, balanced without recompiling |
| Existing players | **Full wipe** at release (only 4 hardcoded test TG IDs today) |
| Pacing | **3+ months** of engaged play to cap |
| Level cap | **40** (was 21), stats grow **every** level |
| Death | **Stays harsh** — the whole unequipped backpack is destroyed |
| Vigor | Slow regeneration **plus** food; `maxVigor` grows with level |
| Content scope | Framework + levels 1–15 fully authored; 16–40 generated as a draft |
| Authoring order | **Spec approved before authoring** — nothing reaches JSON until the list is written down and signed off |

## Calibrated model

Monte-Carlo verified at 4,000 fights per cell. Five structural corrections were
made to the first draft — each is a trap worth remembering:

1. **Diminishing-returns denominators must be derived from the item budget
   curve, not hand-picked.** Otherwise a stat's *percentage* rots while its
   *rating* grows: an archer with 60 dodge rating would end at 9.7% dodge on
   L40, below the L1 value.
2. **Growth must be proportional, not flat.** Flat rating growth drops warrior
   dodge from 5.3% to 1.4% — the sheet number rises while the effect vanishes.
3. **Enemy stats are generated at DESIGN time, not runtime.** Runtime scaling
   nullifies every gear upgrade (the Oblivion trap). A separate
   `levelDiff = clamp(1 + 0.06·Δlevel, 0.25, 2.5)` multiplier is what actually
   sells "I out-gear this zone".
4. **The drafted boss archetype was arithmetically impossible.** Fixed HP-loss
   over rising rounds makes per-hit damage *fall*: the boss hit softer than
   trash (4.5% vs 6.6% maxHP).
5. **Rarity multipliers were 3× too large.** 1.95/2.45 budget gave 2.73×/4.15×
   total power. Capped at 1.45, with enchant as **+4% of the item's own budget**
   per step (a flat bonus is worth 267% of base DEF at L1 and 14% at L40).

### Core formulas

```
mitigation = min(0.70, DEF / (DEF + K_def(L))),   K_def(L)   = 46.65 + 8.017·L
dodge%     = 55 · D / (D + K_dodge(L)),           K_dodge(L) = 43.32 + 3.682·L
crit%      = 50 · C / (C + K_crit(L)),            K_crit(L)  = 51.89 + 3.213·L
accBonus%  = 30 · A / (A + K_acc(L)),             K_acc(L)   = 33.38 + 1.457·L
hit%       = clamp(85 + accBonus% − dodge%, 40, 95)      // floor 40, not 25
damage     = ATK · (1 − mitigation) · levelDiff · U(0.9, 1.1) · (crit ? 1.5 : 1)

growth (proportional):  HP ×(1+0.056·(L−1)) · ATK ×(1+0.100·(L−1)) · DEF/ratings ×(1+0.085·(L−1))
maxVigor(L) = 100 + 5L        regen = maxVigor(L)/6h
xpToNext(L) = max(11.4·L^3.30, 120L)      mobXP(L) = 26·L^1.55·archXP
xpLevelDiffMult = clamp(1 − 0.08·(playerLvl − mobLvl), 0.10, 1.00)   // REQUIRED
value(iLvl, slot, rarity) = 7.9 · slotWeight · iLvl^1.55 · rarityValue
```

**Total 19.4M XP → ~110 days at 80% engagement.** Derived from the vigor budget,
not guessed: 60 kills/day is short by 3–6×; real throughput is 19/day at L1 and
47/day at L40.

### Unplanned findings that must be fixed

- **DEF-ignoring techniques become net vigor losses** under a mitigation curve:
  +25% damage for +150% vigor (0.44–0.59× efficiency). Cleave / Vital Shot /
  Soulfire must be rebuilt around effects mitigation cannot eat.
- **Fleeing costs more than dying** — `WearEvent.flee = 5` vs `defeat = 3`.
- **Passive expeditions are 53% more vigor-efficient than active play** — they
  always roll the fresh encounter table and charge 1 vigor/round instead of 2.
- **Taps, not vigor, bind at L40**: 390 taps/day ≈ 26–42 min of button-mashing at
  Telegram latency. `combatAttack = 2` is doing double duty as the tap governor
  and must not be lowered "for convenience".
- **The harsh death penalty is an unpriced sink** worth ~10% of gross income at
  L40 (one bag wipe per ~7 days).
- **`pickFor` falls back to `all.first` past km 35** — every deep encounter is a
  wild boar. Preserved through the migration on purpose; fixed in Phase 5.

## Phase status

| Phase | State |
|---|---|
| 0 Scaffolding | ✅ `6cc1889` |
| 1 Exporter + first JSON | ✅ `7e8f2a4` |
| 2 Item/Enemy/Recipe façades | ✅ `c9e329b` |
| 3 Remaining catalogs | ✅ **12 of 12** — A (weapon/bag/estate) `f30a4ca` · B (trader/tavern/market/guild/arena) `cb101f3` · C (master/plot/fortune/quest) |
| 4 Tuning tables + `time.scale` | ✅ **4a** six tables · **4b** flags collapsed |
| 5 New combat model | ✅ 5A bestiary · 5B progression · 5C combat · 5D techniques |
| 6 Rarity + sets | ✅ budget curve · rarities · sets · enchant as % |
| 7 `/reload` hot swap | ✅ + `LiveReferenceCheck` over 10 columns |
| 8 Simulator + constant lock-in | ✅ **8A** math into `ROISim` (digest held) · **8B** `roi-content simulate` · **8C** stances multiplicative · warrior budget re-spent · monster silver removed |
| 9 Content specs (approval gate) | ⬜ |
| 10 Generate + author content | ⬜ |
| 11 Wipe + final pass | ⬜ |

**Current digest baseline: `583a32cb5a9d9dc7`** (schema **v8**) —
`records 7b3a5e700d0b8fe7`, `tuning 5946bb13b530389e`,
`spawns 81f6639962cbc4a7`, `quests 2e52ecdfa45276ec`.

Phase 8C moved exactly two halves and left two untouched, which is the whole
point of the split: `records` (enemy + archetype fingerprints lost silver, the
reference kit moved with the warrior profile) and `tuning` (stances became
multipliers, warrior base attack 10 → 12, `passive.silverMultiplier` deleted).
**`spawns` and `quests` did not move** — no selection logic or daily assignment
was touched, and the digest says so rather than asking to be believed.
Previous baseline `a4d825a8d728f4f8` (schema v7).
Phase 6 moved `records` only: it added item fields, rarity, sets and the budget
curve, and touched none of the six balance tables.

Phase 5 moved all three of `records`, `tuning` and `spawns` ON PURPOSE — it is the
first phase that changes behaviour rather than relocating it. From here the
digest is a change DETECTOR, not an equality check: the question stopped being
"did it stay the same" and became "did exactly the intended thing move".
The digest gained a FOURTH half in Phase 4 (`tuning`), kept separate from
`records` on purpose: holding the three catalog halves at their Phase 3 values
through the whole tuning migration is what proves Phase 4 touched only balance
numbers.

Baseline history — each move is an *added* coverage step, never a flip:
`9242a2c1501994ed` (batch B) → `8053216102eceff7` (batch C added `quests`) →
`5694aea8e3beca54` (Phase 4a added `tuning`; `tuning a8b3c0fa99f86e3c` held
across the flip of ~80 constants) → `893b57b06fad8068` (Phase 4b's step 1 dropped
the three `testMode` booleans from the hash, leaving only the DERIVED durations —
which is what made the collapse itself a provable no-op).

**Phase 3 is complete — all 12 catalogs read `content/data/`.** No Swift array
remains, so `ContentExporter` and the `--export-content` branch were deleted with
the batch. `ContentDigest` stays: it is the "confirm only the intended change"
tool in the add-content workflow, not just a migration artefact.

**Next is Phase 4** — tuning tables plus collapsing the three `testMode` flags
into one `time.scale`. Batch C surfaced why that needs its own commit: the flags
are NOT one scale. `PlotCatalog.testMode` alone drives two — `intervalSeconds` is
60 ↔ 3600 (60×, matching `manifest.timeScale: 60`) while
`PlotProductionService`'s sweep is 60 ↔ 300 (5×). The flag was carried into
`plots.json` verbatim; Phase 4 reconciles and deletes it.

### What Phase 8 taught

**The refactor had to be provably inert, and the digest is what proved it.**
8A moved absorption, the rating curves, `levelDiff`, `applyAttack`, `chipDamage`,
the XP curve, the stat line and the item budget out of `CombatService` / `User` /
`ItemBudget` and into `ROISim`, leaving façades behind. The `tuning` half of the
digest already replays `baseStats` over 3 classes × 6 levels, `xpRequiredToReach`
over 0…45 and all four curves — so `a4d825a8d728f4f8` holding across the move is
a bit-level equality proof, not a smell test. Only `applyAttack`'s three random
draws are outside that net, and they moved verbatim.

**The direction of the dependency is the whole point.** A simulator that
reimplements the maths measures the simulator. `CombatService` now calls
`CombatMath`; `roi-content simulate` calls `CombatMath`. There is one copy, so
the report cannot drift from the game — and `StanceModifiers` /
`specialAttackModifiers` were pulled down too, because a technique the simulator
models differently is the same bug wearing a hat.

**`enemies.json`'s archetype table is a generator, and always was.** The targets
(`rounds`, `hpLossPercent`, `mitigationPercent`, `dodgePercent`, `critPercent`)
invert cleanly: `DEF = m·K/(1−m)`, `rating = k·p/(scale−p)`, `HP = rounds ×
expected damage`, `ATK` from the HP-loss target. Fed the shipped roster's levels
and archetypes the inversions return **every enemy's DEF, crit and dodge to
within rounding** — `rabid_bear` wants DEF 82.36 and carries 82, crit 56.66 and
carries 57. That is what says the Phase 5A ratings came off this curve, and it is
pinned by test against literal numbers so it cannot quietly stop being true.

**HP and ATK did NOT come off it.** The same inversion says the roster should
carry roughly twice the HP and twice the ATK it does — 64% → 50% of contract as
level rises, so the bestiary falls further behind at depth. Against the on-curve
reference character every shipped enemy is a 100% win at 4–13% HP where its
archetype asks for 10–62%. Phase 10 regenerates the table; the generator now
exists to do it with.

**p90 is the right statistic for the tail and the wrong one for invariance.** HP
is an integer, so at level 1 a percentile lands on a coarse grid and reports
quantisation as drift — the first cut failed three rows on exactly that. Level
invariance is judged on MEANS, in ratios, and two-sided (a ratio alone convicts
trash, where a 1.3-point wobble reads as 16%; points alone would acquit an elite
sliding 60% → 75%). The tail band stays on p90, where it belongs.

**Level invariance holds.** 18 of 18 rows: mean HP loss spans ×1.01–×1.16 and
mean rounds ×1.01–×1.11 from level 1 to 40. The derived denominators work, which
is the claim everything else in the rebalance is built on. The plan's one flagged
cell reproduced too — the mage against an elite at low level, p90 90% HP and 95%
wins — which is a strong signal the simulator is measuring the real thing.

**The classes are 17% apart, not 7%.** Same relative HP cost per fight for all
three, but the warrior needs 4.1 rounds where the mage needs 3.1, so 17.8 Vigor
per kill against 15.0 — 59 perfect days to the cap against 50. The warrior's
armour is spent entirely on equalising damage taken and buys no speed back, so
the intended tank/glass-cannon trade does not exist in the numbers: the mage is
strictly ahead. The lever is the class budget profiles or the starting stats;
both change every item, so it is 8C's decision, not a silent edit.

**The stance table was never held to Phase 6's own rule.** Phase 6 banned flat
bonuses on items because the same +5 is a third of a level-1 stat line and a
twentieth of a level-40 one — and then two of the three Supers went on granting
exactly that. `hawks_eye` lifts the archer's crit by **115% at level 1 and 21% at
the cap**; `bloodlust` lifts the warrior's attack by 29% → 5% AND doubles the
Vigor cost of every action while it holds. Only the mage's `arcane_resonance` is a
multiplier, so only it is worth the same at both ends — which is the entire reason
techniques save the mage 30% of a fight and the warrior 5%. The report now audits
every stance against its own class's reference stat line at both ends.

**A band the design never stated should not fail a build.** The class power
index is ours, so it prints and never fails; the ±7% band sits on days-to-cap,
which the plan did state. Warnings do not fail even under `--strict` — only a
broken band does, so the calibration loop (edit a curve, re-simulate) is not a
fight with the exit code.

### What Phase 8C did

Three changes, all of them things the simulator found rather than things the
plan predicted.

**All five stance lifts became multipliers of the character's own stat.**
`attackBonus` / `defenseBonus` / `critBonus` / `accuracyBonus` / `dodgeBonus` are
gone from `StanceTuningDTO`; `attackMultiplier` / `defenseMultiplier` /
`critMultiplier` / `accuracyMultiplier` / `dodgeMultiplier` replace them, every
one REQUIRED on decode (a defaulted 1.0 would read as "this stance does nothing
to that stat"). Shipped values: bloodlust attack ×1.35 defence ×1.15 vigor ×1.5
(down from ×2.0 — it was charging double for a bonus that had rotted to +5%),
hawks_eye crit ×1.60 accuracy ×1.15 dodge ×1.15, arcane_resonance attack ×1.50
defence ×1.15. The warrior's techniques went from saving 5% of a fight to saving
13–21%, and the audit that found this now runs on every report.

**The warrior's budget was re-spent toward offence.** Weapon attack 0.72 → 0.80
(accuracy 0.14 → 0.06, which was overshooting the 95% hit cap by level 40 anyway),
armour defence 0.82 → 0.78 into HP, base attack 10 → 12. Days-to-cap spread fell
**17% → 9%**, inside the plan's ±7%-of-the-mean band. And the trade the design
always claimed now exists in the numbers: the warrior loses 50–53% of a bar to an
elite where the mage loses 65%, at 10% slower pace instead of 18%.

**Monster silver is gone entirely.** `enemies.silverReward`,
`archetypes.silverMultiplier` and `exploration.passive.silverMultiplier` are
deleted, with the award sites in `CombatController.finishVictory` and
`PassiveExpeditionService` and both locale lines. Every silver faucet left is a
player-facing system with a sink attached — quests, the trader, the tavern, the
market, the arena — which also closes the "`silverReward` has no curve" gap by
removing the thing that needed one.

Schema v8. `--content-digest` moved `records` and `tuning` and left `spawns` and
`quests` alone; the reference-character row for the warrior was **rebased**, with
the archer and mage rows deliberately untouched so the check keeps its teeth.

**Still open, all reported by the run itself:** the two remaining flat rating
bonuses (`shadowVeilDodgeBonus` +50 is 238% of a level-1 archer's dodge and 34%
of a level-40 one; `defend.archerDodgeBonus` +30 is 143% → 20%) — the same defect
as the stances, in the techniques beside them; the mage's 93% win rate against an
elite at level 5, whose fix is the spawn-level floor the plan already specified;
and the half-strength bestiary, which is Phase 10's.

### What Phase 7 taught

- **The failure path was the one that failed.** `/reload` echoes validator
  output into a `parseMode: .html` message, and two rules legitimately say
  "expected min <= base <= max". Unescaped, Telegram rejects the whole message —
  so the single code path whose entire job is explaining a refusal would have
  delivered nothing at all. Escape anything that is not curated locale copy.

- **The safety of a hot swap is entirely in the ORDER.** parse → validate →
  live-check → build → install, with `install` the only infallible step and
  last. Nothing else about the feature matters as much: get the order right and
  a refused reload is a no-op by construction.
- **The design's list of live references was incomplete, and the gaps were the
  quiet ones.** Six columns were specified; the schema has ten. The four
  missing ones — learned recipes, combat stance, quest progress, active fortune
  card — all degrade SILENTLY when their id vanishes, which is exactly why they
  were easy to leave out and exactly why they matter. Re-derive such a list from
  the schema rather than trusting the plan's copy.
- **Split a check so its interesting half is testable.** The matching moved to
  the Foundation-only module and the queries stayed in the main target, which
  has no test host. The failure worth catching is a CATEGORY error — item ids
  checked against the bestiary would report everything as dangling or nothing,
  and either way the rule would look like it was working.

### What Phase 6 taught

- **The budget model is what turns "the formula is right" into "the balance is
  right".** Phase 5's acceptance check could only prove published stats produce
  published percentages. Feeding the budget through the class profiles rebuilds
  the reference character from scratch — and DEF and absorption land exactly on
  the design table for all three classes. That check now prints on every digest
  run.
- **A residual gap is worth printing, not hiding.** The reference kit comes out
  4–10% short on HP. That is not drift: it is the two accessory slots, whose 1.0
  of slot weight nobody has spent. Quantifying the gap turned "the empty slots
  are cheap content" into a number.
- **Decouple price from power.** Rarity multiplies budget ×1.45 at the top and
  value ×16. Tying them (the drafted 1/2.2/5/14/40) makes selling a legendary
  the biggest silver faucet in the game, against an unlimited vendor.
- **A ceiling rule should encode the decision that produced it.** The rarity
  ceiling rejects ×2.45 — the exact value the design draft proposed and then
  rejected — with the arithmetic in the message. The rule is the reasoning, kept
  executable.
- **The validator caught the author.** The first Forester set bonus I wrote was
  33% of its members' combined budget against a 25% cap. A rule that only ever
  fires on hypothetical bad content is not yet known to work.
- **The Phase 5 lesson repeated, and the audit is what caught it.** Four Phase 6
  values had no digest coverage: the class budget profiles and the stat exchange
  rates (both invisible — doubling "one point buys 0.42 attack" would have
  doubled every generated weapon without moving a hash), the ladder rungs' item
  levels, and `critMultiplierOverride`. Hashing the reference KIT covers the
  first two through the same call the acceptance check uses, so the printed
  table and the digest can never disagree about what the model says.
- **Round-trip tests keep earning their keep.** `GearStatsDTO.encode` skips zero
  values field by field, and the new `hp` was never added to it — so an HP stat
  survived in memory and vanished through JSON. Exactly the Phase 1 layer-0
  failure, one field later, caught the same way.

### What Phase 5 taught

- **A published design table can bake in things that do not exist yet.** The
  plan's reference character shows a level-40 warrior at DEF 225; the bare stat
  line gives 52. The other 173 is gear from an item budget curve that arrives in
  Phase 6 and real items that arrive in Phase 10. So Phase 5 can prove the
  FORMULA (published stats in → published percentages out, and five mitigation
  pairs land exactly) and cannot prove the BALANCE. Worth separating explicitly
  before anyone reads a green check as "the numbers are right".
- **Order the phases by data dependency, not by the plan's numbering.** Enemies
  generated against the new growth model kill a level-21 warrior outright under
  the old one (137% of max HP). Swapping the progression step ahead of the combat
  step made every intermediate commit playable; the reverse order has a window
  where the game is arithmetically unwinnable.
- **Calibrate a derivation to reproduce the values it replaces.** The sweeper
  floor and, later, the enemy generator both had a free parameter. Choosing it to
  reproduce the shipped numbers exactly turns a behaviour change into a verified
  no-op at zero cost.
- **Two curve shapes that look alike need two TYPES.** In `min(0.70, DEF/(DEF+K))`
  the 0.70 is a ceiling; in `55·D/(D+K)` the 55 is a leading scale. Inverting one
  as the other inflated every enemy's DEF by ~80% and stretched fights far past
  their target length. It was caught only because the table was reviewed before
  it was written. `MitigationCurveDTO` and `RatingCurveDTO` are now distinct so
  the compiler refuses the confusion.
- **Adding a parameter is a better migration tool than a grep.** Threading
  attacker/defender level through `applyAttack` made the compiler enumerate all
  nine call sites, two of which were `chipDamage` calls no search for
  `applyAttack` would have found.
- **A hash only covers what it reads.** The technique rebuild moved the payload
  from `AttackModifiers` into a separate effect union that the controller reads
  directly — so the digest kept hashing the modifiers and stopped seeing the
  technique. Doubling a burn's duration left it byte-identical. Whenever a value
  moves to a new home, re-check that the digest followed it: `passive`,
  `fullRegenHours`, `mobXP` and `critMultiplierOverride` had all fallen out the
  same way, and all six now move it to distinct values.

### What Phase 4 taught

- **Keep a new digest half SEPARATE from the old ones.** Folding the tuning
  constants into `records` would have made "the catalogs are untouched" an
  assertion; a fourth hash made it an observation. The three catalog halves came
  out of Phase 4 byte-identical to their Phase 3 values.
- **A tuning scalar and a catalog record need opposite decoding rules.** The
  ladders' optional-with-default is right for a record whose sub-field is
  genuinely absent, and catastrophic for a constant. Nothing in `TuningDTO.swift`
  uses `decodeIfPresent`. `vigor.drain.idle` is 0 and is written down anyway,
  because an absent key and a deliberate zero must not be indistinguishable.
- **Extract the switch BEFORE the flip, not during it.** Batch B had to
  hand-translate `ArenaCatalog.leagueKey` and prove it afterwards.
  `ExplorationService`'s weight tiers were lifted into
  `weights(forPriorVisits:)` while still Swift-backed, so the baseline was
  captured *through the accessor* and the flip was a plain no-op. Strictly safer,
  and cheaper.
- **`default:` swallows negatives — a table keyed 0/1/2 does not.** The revisit
  lookup had to be "exact match, otherwise the LAST row", not "the greatest row
  at or below the query": the latter finds nothing for −1 and falls back to the
  FRESH tier, quietly making re-entered rooms generous. Replaying −2…5 is what
  surfaced it.
- **A hash cannot see a value the shipped configuration masks.** The sweeper's
  `intervalDivisor` is invisible to the digest at `scale = 60` — the 60 s floor
  swallows every sane divisor, and the hash is identical for 12 and for 6.
  Covered instead by a two-point equivalence check that prints on every digest
  run. When a derivation has a clamp, check the unclamped branch somewhere the
  hash is not looking.
- **Calibrate a derivation to reproduce BOTH existing values, and it costs
  nothing to adopt.** The first sweeper draft used a floor of 30 s, which would
  have moved the dev cadence 60 → 30 and made 4b a behaviour change. A floor of
  60 reproduces production (3600/12 = 300) and test mode (floored to 60) exactly,
  so the collapse stayed a verified no-op.
- **`Set<Int>` is the dictionary lesson one type over.** `User.statGrowthLevels`
  iterates in seeded-hash order; hashing it directly would have produced a digest
  that differs between processes.
- **A test that cannot fail is worse than no test.** The first
  `realTime`-is-unscaled test compared two DTOs built from the same fixture — a
  tautology that reads like coverage. Replaced with one that pins the base
  durations against both pacings.

### What batch C taught

- **A `private static let` inside a catalog is the flip's sharpest edge.**
  `FortuneCatalog.lookup` was `Dictionary(uniqueKeysWithValues: all.map …)`.
  Harmless while `all` was also a `static let`; the instant `all` reads the
  snapshot, that line runs at type-init and traps before
  `ContentBootstrap.load`. Grep for `static let` inside the catalog itself, not
  only at the call sites.
- **Extracting a constant out of a formula is a hand-translation**, and gets the
  same treatment as a switch-to-table: recompute the whole formula from the
  extracted value and compare against the live function across a range — the
  `?? 30` fallback, the `missing <= 0` short-circuit and the `max(1, …)` floor
  all have to survive, and a naive re-derivation drops one of them.
- **Absence can be a value.** `PlotCatalog.tuning(for: .trainingGround)`
  returning nil is how the estate controller routes a tap to combat instead of a
  harvest. The DTO models it as an absent key and the fingerprint compares
  `<none>` explicitly, so a `training_ground` that gained a tuning is caught.
- **A no-op default is per-field, not per-type.** `FortuneEffect` skips 0 for
  bonuses, **1.0** for multipliers and false for flags. One "skip falsy" rule
  would have written nothing for a 1.0 multiplier and decoded a card that zeroes
  the stat it scales.
- **Dictionaries in a catalog hash in an arbitrary order.** `t1Tunings` and
  `pools` had to be walked via `allCases` in both the digest and the exporter;
  iterating them directly would have produced a digest that changed between
  processes.

### What batch B taught (applies to every remaining catalog)

- **A "catalog" can be three different things at once**, and each needs its own
  guarantee. Batch B held 18 ordered records (11 trader + 7 tavern), 21 tuning scalars
  (2 market + 8 guild + 11 arena) and one table.
  Records need order preservation and a domain-rebuild fingerprint; scalars need
  *required* decoding plus a field-by-field comparison against the live
  constant; a table replacing control flow needs a replay proof.
- **Tuning scalars must decode as required, never `decodeIfPresent`.** The
  ladders' optional-with-default pattern is right for a list (`inputs` absent =
  no cost) and wrong for a constant: a missing `memberCap` silently becoming 20
  is exactly the invisible balance drift the pipeline exists to stop.
- **A round-trip cannot see a transposed pair.** `maxOfficers` written into
  `memberCap` encodes and decodes perfectly. Only comparing each decoded field
  back against the live Swift constant catches it — the scalar analogue of the
  layer-0 lesson.
- **Replay a switch wider than the digest does.** `case ..<1000` also swallowed
  negative Honor; the digest only replays 0…2000. The exporter ran −500…3000, so
  the table's `?? first` fallback was proven to swallow negatives identically
  rather than assumed to.
- **Lookup helpers hide a semantic choice.** `all.first { … }` returns the FIRST
  match, so the replacement dictionary must use `uniquingKeysWith: { first, _ in
  first }`. `{ _, last in last }` would quietly change which row a duplicate id
  resolves to.
- **The trader had an unguarded money printer.** `sell ≤ buy` per unit was held
  by convention alone; it is now `trader.arbitrage`, compared by
  cross-multiplication so unequal packet sizes stay exact.
