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
| 6 Rarity + sets | ⬜ |
| 7 `/reload` hot swap | ⬜ |
| 8 Simulator + constant lock-in | ⬜ |
| 9 Content specs (approval gate) | ⬜ |
| 10 Generate + author content | ⬜ |
| 11 Wipe + final pass | ⬜ |

**Current digest baseline: `84b3316f44bd18c7`** — `records 70d6d2396af6f198`,
`tuning 88db2a129b96a432`, `spawns 81f6639962cbc4a7`, `quests 2e52ecdfa45276ec`.

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
