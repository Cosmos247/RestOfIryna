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
| Vigor | ~~Slow regeneration **plus** food~~ → **REVERSED 2026-08-31: no passive regeneration at all.** Vigor comes from food, quests and levelling; the estate's plots and kitchen are the faucet. `maxVigor` still grows with level. The original decision is kept here because the reasoning against it is the interesting part: passive regen does not pause during an expedition, so it defuses the only thing gating depth — a player could stand at km 25 and wait out a full pool. See "The vigor rework" below |
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
   sells "I out-gear this zone". The one runtime multiplier since 2026-10-03 reads
   the ESTATE tier, never the player (`spec-bestiary.md` §11), so it cancels no
   gear and no level.
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
xpLevelDiffMult = clamp(1 − 0.08·(playerLvl − mobLvl), 0.10, 1.00)   // REQUIRED — OFF since 2026-10-02 (perLevel 0, spec-bestiary §10.4)
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
| 8 Simulator + constant lock-in | ✅ **8A** math into `ROISim` (digest held) · **8B** `roi-content simulate` · **8C** stances multiplicative · warrior budget re-spent · monster silver removed · **8D** last two flat lifts → multipliers, archetype `minLevel`, sample size 2000 → 8000 |
| 8E Vigor rework — no passive regen | ✅ regen removed · `FoodBudget` pace model · food plots retuned to 85–93 days (reads 78–87 since 09-10) · `zones.json` |
| 9 Content specs (approval gate) | ✅ **5 of 5** — progression · bestiary · items · sets · economy |
| 10 Apply the bestiary level re-spread — **and nothing else** | ✅ six enemies re-levelled + `xpReward` re-solved · Bison rename · elite band kept stretched to km 40 |
| 11 Wipe + final pass | ✅ **closed as CODE** — opening ledger + wipe 2026-09-02 · invite-only access 09-08 · Pi deployment and `scale` 1.0 09-09. What follows is live-play polish (and small features on top), thirteen commits 09-09 → 09-12, tracked in `sessions.md` and `Prompt.md` rather than here |

### Tier 2 of the bestiary and the expedition model (2026-10-02)

**What shipped (`f03d502`, committed 2026-10-02, deployed 2026-10-06 21:39):**
- 14 creatures numbered in order, five of them new;
- bands km 3N−3…3N+1, with the rabid bear stretched to km 49;
- XP by the number alone (every archetype `xpMultiplier` is 1.0);
- the XP level-gap penalty off (`xpLevelDiff.perLevel` 0), with the damage shift `levelDiff`
  kept;
- `enemy.xp_falls_with_depth` replacing the guard that forbade a zero penalty.

The decision record is `content/spec/spec-bestiary.md` §10. This section keeps the research
behind it — the model and every figure it produced — because the harness lived in a scratch
directory and is gone.

**Why a new model.** `simulate`'s pace prices every kill as an on-level `normal` fight plus
1.9 rooms of walking. It never walks from the manor and never meets the shallower bands on
the way, so it cannot see depth and a roster change does not move it.

The first model, built in the lost 09-28 → 10-01 session, made two errors:
- it charged the walk to a band as empty walking, and ignored HP;
- its report headlined the variant without the walk (L14 in 26 days against today's 32),
  which made a table paying LESS XP look faster.

With the walk included, that model gave 66 against 46. The owner caught it with one question,
and both models were replaced.

**The expedition model.**
- **Trip.** Manor → km D → manor, one km per step, 2 Vigor a step (`walkRoom`). Encounters
  come on 40% of the fresh steps going in (weight tier 0) and 52% of the steps coming home
  (tier 1, the first revisit). Trip events hit 5% of steps for 5% of max HP. The turnaround
  km counts once.
- **Encounter.** A spawn-weighted pick among the creatures whose band covers the km, as
  `pickFor` does. Archetype weights: trash 100, normal 60, skirmisher 40, brute 25, elite 8.
- **Fights.** The game's own `FightSimulator` with the `.basic` profile, 1,000 fights per
  player level 1–40 × class × creature, giving win rate, rounds, Vigor and HP%.
- **Players.** Either of two:
  - the simulator's on-curve reference character against creatures generated on contract at
    their own level, which on level is equivalent to real kit against lines solved for the
    real kit;
  - a player built from the real items: class base stats, the class weapon at its ladder
    rung (itemLevel ≤ level, rungs 1/10/20/30/40), and from level 4 the four Forester pieces
    with the 4-piece bonus (HP +24, DEF +14, crit +4, dodge +5).
- **XP.** `xpReward` × the variant's level-gap multiplier × the win rate.
- **Depth.** Per level, the D with the best XP per Vigor subject to two limits:
  - mean HP lost over the trip, minus healing, is at most 90% of max HP. Dishes eaten for the
    trip's Vigor above the pool heal a quarter of that Vigor in HP;
  - the odds of getting home are at least 90%, taken as the product over encounters.
- **Days.** Vigor needed ÷ the tended estate's food per day, from `FoodBudget`: 0 / 45 / 300
  / 600 / 900 / 990 / 1200 for T1–T7, reached at levels 1 / 4 / 7 / 10 / 13 / 16 / 19.
  Levels 1–3 cost no days, as in `simulate`. XP need is the `progression.json` curve
  (19,437,688 to L40).
- **Calibration.** An on-level `normal` fight costs 11.1 Vigor, which is the simulator's 15.0
  per kill minus its 4 of walking. Every creature's on-level fight lands on its archetype
  contract.

**What it measured.** Days to L14 / L25 / L40, mean of the three classes, on-contract
creatures against the reference. In brackets, the figure before the rabid bear was stretched
to km 49:

| case | L14 | L25 | L40 |
|---|---|---|---|
| today's roster, today's rules | 75 | 159 | 642 |
| tier 2, XP penalty kept | 97 | 367 (389) | ~3,070 (~3,430) — the wall |
| tier 2, no level comparison at all | 99 | 246 | 811 |
| **tier 2, XP penalty off, damage shift kept — shipped** | 67 | 128 (129) | 399 (434) |
| the same, archetype XP multiplier kept | — | — | 229 (277) |

- **Sensitivity**, run with HP budgets from 60% / 95% odds up to 250% / 70% odds. Today's
  rule walls every time (L40 3,218 → 2,947). The shipped variant beats today's game at L14
  and at L40 every time: L40 424 against 813 at 60%, and 365 against 509 at 250%. At 250%,
  today's game pulls ahead at L25–30 (91 against 94, 120 against 147).
- **Why tier 2 trailed today's game in the first two variants.** Decomposed on the
  no-comparison variant:
  - bands as today (km N…N+9): L14 69, L40 600;
  - archetype multiplier kept: L14 94, L40 634;
  - both: L40 403.
  Two roughly equal causes: the 3-km bands make every trip fight through the weaker bands,
  and dropping the multiplier pays brutes and the elite less.
- **Depth under the shipped rules.** About 10 km at L5, ~19 at L10, ~28 at L14 and ~40 at
  L20, and the whole forest (km 49) from about L25.
  - An L20 trip is ~80 steps and ~36 fights, and costs ~320 Vigor against a pool of 200.
  - From L25 a trip is ~45 fights and 320–390 Vigor.
  - Levels 22–40 take ~290 days of that same walk.
  No shallow farming appeared with the penalty off: the chosen depth grows about 2 km a level.
- **XP per Vigor at L10–14** stays about where it is today: 11.0 against 10.8 at L10, 19.8
  against 17.0 at L14.

**Real gear with the authored lines — the most realistic reading.** Days to L10 / 14 / 19 / 25
/ 30 / 40:
- today's roster: 64 / 78 / 105 / 152 / 218 / 598;
- tier 2: 60 / 73 / 97 / 132 / 181 / 392.

**The stat method, reconstructed — 09-14 never wrote it down.**
- **№1–4 use the tier-1 recipe.** `EnemyGenerator` solves against the on-curve reference at
  level N for HP, ATK is round(0.65 × the solved ATK), and DEF/crit/dodge sit on curve. It
  reproduces the viper exactly (55/5/6).
- **№5 and up.** `EnemyGenerator` solves against the on-curve reference built with
  `rarityMultiplier` equal to the obtainable-kit share at level N, computed exactly as
  `spec items` prints it: Σ `SpecTables.bestPoints` ÷ Σ `BudgetMath.points` at rarity 1.0.
  - The shares: L5 0.448 · L6 0.403 · L7 0.366 · L8 0.336 · L9 0.310 · L10 0.481 · L11 0.449 ·
    L12 0.421 · L13 0.396 · L14 0.374.
  - This lands within 2–8% of the 09-14 lines. The shares have fallen since: the 09-14 lines
    imply ~0.39–0.51, which is the "40–53%" its notes quote.
  - A player built from the real items does NOT reproduce the 09-14 lines, because the L10
    weapon rung overshoots (lynx HP 136 against 109).
- **Every creature's DEF, crit and dodge sit exactly on the curves.** `SimulatorTests` now pins
  all fourteen.
- **The sandbox fight check**, each creature against the player it was solved for:
  - №5–14 land on contract, and run lighter against real gear, clearly so from №10;
  - №3–4 run above contract for an armourless player: the boar takes 29% of a bar against 24%,
    the fox 36% against 28%. Today's moose sat at 29%;
  - an L9 player without the L10 weapon meets 56–69% of a bar per fight from №10–11;
  - the moose's HP (94) is below the boar's (101), yet the fight ladder does not invert: to an
    L5 player the boar costs 12% and the moose 20%.

**Estate-tier scaling — decided 2026-10-02, implemented 2026-10-03 (`spec-bestiary.md` §11).** The owner's call: creatures grow
with the ESTATE tier, strength only, with XP unchanged. It was measured with real gear and the
authored lines, scaling by s = estate tier − 1, the tier a player of that level can have.

Days to L14 / L19 / L25 / L40:
- unscaled: 73 / 97 / 132 / 392;
- **A, +10% HP/ATK per tier: 96 / 130 / 184 / 477 — chosen**;
- C, one creature level per tier (regenerated by the tier-2 recipe at № + s): 103 / 148 / 212
  / 506;
- B, +20% per tier: 120 / 173 / 249 / 652.

Depth at L20 falls from 41 to 32 under A and to 27 under B or C, and with A the whole forest
opens around L30.

The upgrade check compares XP per day with the next estate tier (stronger creatures, more
food) against XP per day without it:
- T2→T3 ×5.2–5.8, T3→T4 ×1.6–1.7, T4→T5 ×1.3–1.4;
- **T5→T6 ×0.9–1.0**, because T6 adds only 90 food a day (900 → 990);
- T6→T7 ×1.0–1.2.

The owner left T6 as it is, expecting new estate tiers to add food. §11.3 answers the
runtime-scaling objection: the estate tier reads a building the player chooses to raise, never
their level or gear; it has six coarse steps; and between T2 and T7 the forest grows ×1.45 while
base ATK grows ×2.15.

**What the implementation added on 2026-10-03.**
- **Two more owner decisions:** no screen announces the strength (a card line was proposed and
  turned down), and `fight_log` gains `estate_level`.
- **Findings shown before the code:**
  - against today's live roster, A is slower at every milestone up to L30
    (64 / 78 / 105 / 152 / 218 / 598 against 74 / 96 / 130 / 184 / 249 / 477);
  - a fight costs ×1.09…×1.40 rounds and ×1.24…×2.75 HP from T2 to T7. The HP cost exceeds m²
    because small ATK values round up and longer fights give more swings;
  - «Пуща» (km 26 at L17) keeps zero margin for the mage: the deepest safe trip is 28 / 27 / 26.
- **The repo's own checks:**
  - `simulate`'s pace went 125.5 / 120.9 / 113.8 → 167.0 / 159.6 / 150.9 days;
  - the new «forest by estate tier» section shows the on-level `normal` fight at T7 going from
    5.6 to 8.6 rounds and from 22% to 58% of a bar;
  - `tuning` moved to `605fd06bd8abdfda`, and nothing else did.
- **The harness, rebuilt against the repo** (a scratch package copying `Modules/ROIContent` and
  `Modules/ROISim`, plus an `estatefights` roller that calls `CombatMath.scaled` with the shipped
  knob), produced a fight table byte-identical to the 10-02 sandbox's `scaled_A.csv` (3,234 rows).
  The expedition model then gave the same 74 / 96 / 130 / 184 / 249 / 477.
- **How the three derived figures were read off the model**, so they can be read again:
  - **per-fight cost by tier.** Over every fight the real-gear player wins at least 95% of the
    time unscaled, compare the row at the player's own tier step with the unscaled row for the
    same level, class and creature, and average the ratios of rounds, Vigor and HP%;
  - **the upgrade check.** At each tier's opening level, take the best XP per Vigor at that
    tier times its food against the same at the tier below times its food;
  - **a depth decree.** It needs the DEEPEST trip that passes both limits (HP budget and 90%
    odds), not the best-XP one. That is how «Пуща» read 28 / 27 / 26 at L17 against 34 / 32 /
    32 unscaled, and 29 / 28 / 28 at L18.

**Rebuilding the harness.** The repo's SwiftPM targets are not library products, so a scratch
package copied `Modules/ROIContent` and `Modules/ROISim` into its own `Sources/`; both are
Foundation-only. Its executables:
- a fight-table roller, writing one CSV row per player level × class × creature: win, rounds,
  Vigor, HP%. For a scaled variant it writes two rows per cell, at the player's tier step and the
  one below, seeded by FNV-1a over `[variant, creature, class, level, step]`. The 10-03 rebuild
  (`estatefights`) calls `CombatMath.scaled(_:forEstateTier:spec:)` with the bundle's knob and
  keeps those seeds, which is what let its table be compared byte for byte;
- a stat-line solver. `SpecTables.bestPoints` had to be made public in the copy to compute the
  share;
- a CLI copy of `Modules/roi-content/main.swift` whose validator copy carried the new rule.
  `--content DIR --locales DIR` point it at a sandbox.

The expedition model itself was about 150 lines of Python over the fight CSVs. The
no-comparison variant is a content copy with `combat.json` → `levelDiff.perLevel` at 0.
Swift 6 trap: a top-level `var` cache is main-actor isolated, so the function that uses it
must be `@MainActor`.

**Emitting the JSON.** Python's `json.dumps(obj, indent=2, sort_keys=True, ensure_ascii=False,
separators=(',', ' : ')) + "\n"` reproduces all 28 `content/data` files byte for byte. Swift's
`JSONEncoder` does not, and neither does a DTO round-trip. The rule is in `CLAUDE.md`, the
detail in auto-memory `reference-house-json-style`.

### The arena duel, measured (2026-10-03)

Every figure behind `cad61c3` (the duel in simultaneous rounds), rolled on the shipped
`CombatMath` against `ReferenceCharacter.build` stat lines. A cell is 40,000 duels, both fighters
at full HP, both always attacking unless a row says otherwise. Seeds: `SplitMix64(20261003)` for
the duels, `42` for the per-swing averages. The reference lines at L10, a rung behind the ladder
(`gearOffset` −10): warrior HP 204 · ATK 31 · DEF 39 · crit 12 · dodge 9 · acc 19; archer
150 · 33 · 25 · 21 · 27 · 31; mage 150 · 36 · 20 · 42 · 11 · 19.

**The alternating duel it replaced: the challenger's first blow.** First striker's win rate in a
mirror duel:

| level | warrior (off 0 / −10) | archer (0 / −10) | mage (0 / −10) | actions a duel (0 / −10) |
|---|---|---|---|---|
| 3 | 60.9 / 60.2 | 59.4 / 59.8 | 62.6 / 63.4 | 16.0 / 15.9 |
| 10 | 61.9 / 62.2 | 59.6 / 61.6 | 64.2 / 66.5 | 13.6 / 13.1 |
| 20 | 62.8 / 63.9 | 60.2 / 61.2 | 65.1 / 66.0 | 12.5 / 12.0 |
| 25 | 64.3 / 63.4 | 61.1 / 62.9 | 65.0 / 66.2 | 12.0 / 11.7 |

It is structural: a short race between near-identical fighters, where whoever swings first stays a
blow ahead. At a 500 stake the challenger's expected gain was about +90 🪙 a duel and the
challenged player's about −140.

**Simultaneous rounds.** Mirror duels, `gearOffset` −10:

| level | class | a wins | b wins | both fall | rounds |
|---|---|---|---|---|---|
| 3 | warrior / archer / mage | 40.1 / 40.1 / 36.3 | 39.6 / 40.1 / 36.5 | 20.3 / 19.8 / 27.2 | 11.3 / 7.4 / 6.1 |
| 10 | warrior / archer / mage | 37.8 / 38.7 / 33.5 | 37.7 / 37.9 / 34.2 | 24.5 / 23.4 / 32.3 | 9.3 / 6.2 / 5.1 |
| 20 | warrior / archer / mage | 36.5 / 38.2 / 34.4 | 36.4 / 39.1 / 34.4 | 27.1 / 22.6 / 31.2 | 8.4 / 5.7 / 4.9 |
| 25 | warrior / archer / mage | 36.2 / 37.7 / 34.0 | 36.5 / 37.6 / 33.9 | 27.4 / 24.6 / 32.1 | 8.1 / 5.5 / 4.9 |

Fair, but both fighters fall in the same round in 20–32% of duels, which made the double-knockout
rule the real decision. The residual tie under each candidate rule, as a share of ALL duels: the
heavier blow ties in 1.3–4.1% (L10: 4.10 / 2.92 / 3.29%, warrior / archer / mage; L25: 2.31 /
1.59 / 1.34%), the smaller overkill in 0.4–1.1%. The owner chose the heavier blow, which is
visible in the round's own lines, with equal blows drawn. The 20,000-duel mirror in
`DuelMathTests` pins the fairness.

**Level and class decide a duel, and nothing brackets them.** Alternating, a L10 warrior striking
first against a higher-level warrior won 61.9% against L10, 2.5% against L12, 0.1% against L13 and
0.0% from L15. The level gap moves damage by `levelDiff` (±6% a level) on top of better stat
lines, and a duel is many hits, so any edge compounds. Class at L10 (`gearOffset` −10), the row
class's win rate:

| | vs warrior | vs archer | vs mage |
|---|---|---|---|
| warrior, alternating (first / second) | 62.1 / 38.3 | 87.3 / 73.0 | 90.4 / 75.5 |
| archer, alternating | 26.9 / 13.1 | 61.7 / 38.2 | 64.6 / 39.5 |
| mage, alternating | 24.3 / 9.2 | 60.7 / 35.5 | 66.0 / 33.8 |

Simultaneous, L10: archer 13.0 / warrior 73.0 / both 13.9; archer 39.8 / mage 34.8 / both 25.4;
mage 9.4 / warrior 75.5 / both 15.1. The duel has no techniques, so the warrior's HP decides.

**Defend is a dead choice.** Always-Defend against always-Attack wins 0.0% of mirror duels at L10
for every class, alternating or simultaneous. What each tap is worth, per swing on average:

| | Attack deals | Defend chip | brace saves of the other's hit |
|---|---|---|---|
| L10 warrior (DEF 39) | 21.5 | 7.2 | 4.1 (21.5 → 17.4, −19%) |
| L10 archer (DEF 25) | 24.0 | 8.3 | 3.4 (24.0 → 20.6, −14%) |
| L10 mage (DEF 20) | 29.3 | 9.4 | 3.5 (29.3 → 25.8, −12%) |
| L20 warrior (DEF 84) | 36.9 | 12.0 | 8.3 |
| L20 archer (DEF 54) | 39.5 | 13.8 | 6.8 |
| L20 mage (DEF 39) | 51.7 | 15.9 | 7.1 |

Doubling DEF works through the absorption curve (`DEF / (DEF + 46.65 + 8.017·level)`, capped at
0.7): the archer's 25 → 50 at L10 lifts absorption from 16% to 28%. For always-Defend merely to
match always-Attack, the brace would have to block more than `1 − chip / attack` of a hit, about
65% (archer L10: 1 − 8.3 / 24.0), against the 12–19% it blocks. Its one rational use is a
finishing chip, because a chip never misses. Under simultaneous rounds Defend is also what the
clock plays for a silent fighter, so it works as the penalty the owner asked for. The ×2 is the
constant `DuelMath.braceDefenseMultiplier`, and the 30% chip is `defendChipFraction`, shared with
forest fights: moving both into `arena.json` comes first whenever Defend is reworked. (Done the
same day: the duel became a cycle of three with its own numbers — next section.)

**Silent fighters.** A fighter who never chooses, against one who always attacks, lasts on average
12.2 / 7.9 / 6.4 rounds (warrior / archer / mage; worst 22 / 16 / 15) — up to five minutes at 15 s
a round. Two silent fighters last 28.8 / 18.2 / 16.2 rounds and fall together 66 / 51 / 50% of
the time. That is why three missed rounds in a row became a technical defeat, and both at once
an abandoned duel.

**The mockup duel.** The seven rounds the owner approved the screens on were seed 219: a L10
archer against a L10 mage, the mage defending in round 2 and silent in round 4. The rounds went
26 / 32, 26 through the brace / chip 9, crit 44 / crit 45, 23 through the brace / forced chip 8,
miss / 33, 29 / miss, then crit 45 / 32 with both falling, so the heavier blow went to the archer.
The mockup note said a brace cuts "about 8%" of the mage's hit; the curve gives 12%.

**Rebuilding the harness.** It is the same scratch package as the expedition model's (above):
`Modules/ROIContent` and `Modules/ROISim` copied into its `Sources/`, plus one `probe` executable
target with `ExistentialAny`. It loads `content/data` with `ContentLoader.load`, then takes
`CombatRules(tuning.combat)` and `ReferenceCharacter.build(...)`. Simultaneous rounds call
`DuelMath.resolveRound` directly. The alternating duel no longer exists in the repo, and it was a
20-line loop: the attacker rolls `CombatMath.applyAttack` against DEF ×2 when the defender braced
since its last attack, and a Defend is `CombatMath.chipDamage` plus the brace flag. Built with
`-c release`, each run took seconds.

### The arena cycle, measured (2026-10-03, after `cad61c3`)

Why the duel got a third choice, and what the shipped numbers play like. Rolled on `CombatMath`
against `ReferenceCharacter.build` at `gearOffset` −10, seed `SplitMix64(20261003)`. Strategies
were STATIONARY mixes (a fixed probability per action, not reading HP) on a grid of 0.1 (two
choices, 3,000 duels a cell) or 0.125 (three, 600–800 a cell); the equilibrium is fictitious play
on the win-share matrix (60,000 iterations), a draw counted as half.

**Two choices: no brace works.** Equilibrium share of Defend, L10 warrior mirror (archer and mage
alike), and the rounds a duel lasts at it:

| brace | Defend in equilibrium | rounds (always-attack 9.4) |
|---|---|---|
| DEF ×2 (shipped until now), block 50% | 0% | 9.4 |
| block 65% | 10% — indifference, not a choice; 0% again at L25 | 10.8 |
| block 80%; block 50/65% + a 60% riposte; block 50% + the next Attack a sure crit | 100% | 28.8 |

A symmetric two-choice game has a pure answer: the net of Defend against Attack is either
positive (everyone defends) or negative (no one does). The HP race does not rescue it.

**Three choices** (Attack beats the technique, the technique breaks Defend, Defend turns
Attack). Equilibrium Attack / Defend / Technique, L10 warrior · archer · mage · L25 warrior:

| variant | mix | rounds (always-attack 9.4 / 6.2 / 5.1 / 8.1) |
|---|---|---|
| A: block 65%, riposte 60%, technique ×1.0 | 48/37/15 · 46/37/17 · 51/35/15 · 47/40/14 | 15.7 / 10.3 / 8.5 / 14.0 |
| B: block 50%, riposte 60%, technique ×1.5 | 63/29/8 · 62/29/10 · 69/22/8 · 62/30/8 | 13.3 / 8.7 / 7.0 / 11.6 |
| C: block 65%, no riposte, technique ×1.5 | 87/13/0 · 66/34/0 · mage 100/0/0 | ≈ always-attack |

The owner chose A. Under A and B always-Attack is exploited: always-Defend beats it 95–100%.

**As shipped** (A, with a technique that cannot miss a defender), rolled through `DuelMath`
itself on the 0.125 grid, 600 duels a cell:

| pairing | row wins | mix (row · column) | rounds (always-attack) |
|---|---|---|---|
| L10 warrior mirror | 50% | 50/36/14 · 48/39/14 | 15.3 (9.4) |
| L10 archer mirror | 50% | 51/34/15 · 50/35/15 | 9.7 (6.2) |
| L10 mage mirror | 50% | 49/38/13 · 49/37/14 | 8.3 (5.1) |
| L25 warrior mirror | 50% | 50/36/14 · 49/37/14 | 13.3 (8.1) |
| L10 warrior vs archer | 76% | 53/34/13 · 43/36/21 | 11.9 (7.3) |
| L10 warrior vs mage | 75% | 53/34/13 · 45/36/19 | 10.8 (6.7) |
| L10 archer vs mage | 48% | 51/33/16 · 49/37/13 | 9.0 (5.6) |

**The cycle does not fix class.** The warrior won 78–80% of always-attack duels against the
archer and the mage, and still wins 75–76% at the equilibrium: 204 HP against 150 decides a duel
that has no class effects. The owner recorded it for later; the probable cure is giving each
class its forest effect back in the arena (armour break / sure crit / burn), balanced one by one.

**The played sample the copy was approved on** was the first of six scripted seeds: a L10
warrior (204 HP) against a L10 archer (150), ten rounds — 27/25, riposte 17 / 8 into the block,
26 / Vital Shot cut off, guard broken / Vital Shot crit 37, Cleave 28 / guard broken, both cut
off, chip 8/7, riposte 14 / 8, 26/28, then a Cleave crit 38 into the archer's guard at 4 HP.

### The weapon ladder, measured (2026-10-03/04, shipped as `9ab349c`)

Why the weapon left the estate, and every variant the owner was shown before choosing. The decision
record is `content/spec/spec-items.md` §9. This section keeps the research — and the probe, whose
scratch copy died with /tmp when the laptop shut down mid-measurement on 10-03. The session was
recovered from transcript `75c2311f` and finished in `a3d46812`.

**The cause was the gate, not the step.**
- The five rungs were authored at item level 1/10/20/30/40.
- `WeaponUpgradeService` opened tier N at estate T N, and T2–T5 come at player levels 4/7/10/13,
  so the item-level-40 sword (ATK 60) was in hand at level 13.
- Bought together at L7, the first two rungs doubled the warrior's ATK (26 → 52).
- The model behind tier 2 and the estate scaling (§ "Tier 2 of the bestiary" above) had assumed
  a weapon at `itemLevel <= level` ("v1" below). Every figure approved on 10-02/03 therefore
  assumed a weaker weapon than the game handed out.

**A second live defect found while measuring.** The upgrade button lives only in the workshop
(`EstateController.workshopKeyboard`), and the workshop opens at T3. So tier 2 could not be bought
before level 7, although the service allowed it at T2. «Гострий край» (L4, weapon T2, chain
position 10) therefore most likely held the live chain from L4 to L7. The 10-03 "today" figures
at L4–6 were too light for the same reason; the 10-04 tables use the starter weapon there.

**The probe** (rebuild it to re-measure).
- **Setup.** An XCTest file in `Tests/ROIContentTests`, copied in for one `swift test --filter`
  run and deleted at once; the test target is the only graph that reaches `ROISim` without a
  library product. It loads `content/data` with `ContentLoader`.
- **The player.**
  - `ProgressionMath.baseStats` at level L;
  - the class weapon of the variant: the shipped ladder's ATK/crit/accuracy, interpolated
    linearly between its rungs' item levels, and for a k% variant
    `t1 + k·(stats − t1)`, rounded half away from zero;
  - from L4, the four Forester pieces plus their set bonus (+6 HP, +2 DEF, +2 dodge).
- **The creature.** Spawnable creature №min(L, 14), sorted by level, scaled by
  `CombatMath.scaled(_:forEstateTier:spec:)` at the estate tier L allows (T2 at 4, T3 at 7 … T7 at
  19).
- **The fight.** `FightSimulator.fight(... profile: .basic)`, 3,000 fights a cell,
  `SplitMix64(seed: 20261003)` re-seeded per cell. One line is printed per cell (HP lost % of the
  bar, rounds, win %).
- **Watch out.** XCTest's own log line can split one printed row in two — re-join it before
  parsing.
- **Where the source lives.** Transcript `75c2311f` records 1233/1249/1296, and `a3d46812`. The
  10-04 rebuild reproduced every checked 10-03 figure exactly.

**Round 1 (10-03): which rungs, at which item levels.** Warrior, HP lost per fight with the
creature of his number (contract in brackets). "v1" is a rung at player level = item level, the
model's assumption. "v2" rescores the five rungs at iL 1/4/7/10/13 by estate tier. "v3" uses
iL 1/4/7/10/13/16/19 by estate T1–T7, plus iL 30/40 by player level.

| L | creature | today | v1 | v2 | v3 |
|---|---|---|---|---|---|
| 4 | Скажена лисиця (28%) | 16%* | 25% | 20% | 20% |
| 7 | Зубр (42%) | 21% | 46% | 34% | 34% |
| 10 | Вепр-сікач (42%) | 27% | 48% | 48% | 48% |
| 13 | Скажена зграя (28%) | 18% | 38% | 33% | 33% |
| 14 | Скажений ведмідь (62%) | 40% | 82% | 77% | 77% |
| 19 | ведмідь | 24% | 48% | 44% | 37% |
| 25 | ведмідь | 7% | 11% | 13% | 11% |

\*Too light: the T3 workshop gate held tier 2 back to L7.

The bear at L14, win % warrior/archer/mage: today 100/99/96, v1 77/48/36, v2/v3 86/63/48.
Hidden cost: v1 breaks four decrees (`weapon_tier` 2–5 at levels 4/8/11/14).

**Round 2 (10-04): "every other estate tier", the owner's idea.** Seven tiers fit only three
upgrades, so tier 5 had no home. Two alignments, each with today's numbers or rescored to the
level a rung opens at (A–D here were shown to the owner as А/Б/В/Г):

| variant | sword ATK by rung | warrior HP%: L7 / L10 / L13 / L14 / L19 | bear L14 win % w/a/m |
|---|---|---|---|
| A: T2/T4/T6, numbers as shipped | 7 → 19 → 33 → 46 | 29 / 34 / 28 / 63 / 29 | 98/86/72 |
| B: T2/T4/T6, iL 4/10/16 | 7 → 11 → 19 → 27 | 39 / 48 / 38 / 82 / 41 | 77/48/36 |
| C: T3/T5/T7, numbers as shipped | 7 → 19 → 33 → 46 | 29 / 48 / 28 / 63 / 29 | 98/86/72 |
| D: T3/T5/T7, iL 7/13/19 | 7 → 15 → 23 → 32 | 34 / 54 / 33 / 77 / 37 | 86/63/48 |

- A and C kept the +12–14 jumps the owner disliked.
- Every alignment moved decrees: three for T2/T4/T6, four for T3/T5/T7.
- This round also found that the validator only range-checked `weapon_tier`.

The owner then asked for something else.

**Round 3 (10-04): a rung every five player levels, with smaller stats, computed to L50.**
- S100 is the shipped ladder at item level = rung level: L10/20/30/40 ARE the old t2–t5, and
  L5/15/25/35 sit between them.
- S75 and S50 take that share of the growth.

Warrior HP lost, with the model (v1) beside them:

| L | creature (contract) | model | S100 | S75 | S50 |
|---|---|---|---|---|---|
| 5 | Дикий лось (24%) | 22% | 17% | 18% | 18% |
| 7 | Зубр (42%) | 46% | 38% | 39% | 40% |
| 10 | Вепр-сікач (42%) | 48% | 48% | 52% | 57% |
| 13 | Скажена зграя (28%) | 38% | 38% | 41% | 44% |
| 15 | Скажений ведмідь (62%) | 72% | 62% | 68% | 75% |
| 19 | ведмідь | 48% | 42% | 46% | 50% |
| 25 | ведмідь | 11% | 10% | 11% | 13% |

- **The mage at L10–13** loses 1–2% of fights at S100 and in the model, 2–3% at S75, and 4–6%
  at S50.
- **One upgrade adds** +5–7 sword ATK at S100, +4–6 at S75 and +3–4 at S50, against +12–14
  before.
- **Share of the warrior's total ATK per rung:** at S100, 21% at L5 down to 5% at L50; at S75,
  17% down to 4–5%; at S50, 12% down to 4%.
- **The weapon's share of the warrior's total ATK** at S100 rises from 37% (L1) to about 50% from
  L20; the old ladder stood at 70% at L13.
- **Below S100**, the weapon falls behind the model from L10, so L10–19 run heavier than tier 2
  was solved for. The owner took S75 as the compromise.

**Decided, each over a quiz.**
- **Measure first** (10-03), and recompute the existing weapons from the new numbers.
- **The ladder:** S75, nine rungs to L40; L45/50 wait for a level cap of 50.
- **Testers** are clamped to the rung their level allows.
- **The first reforge** is a lesson at the Master — variant A of three played samples (a one-time
  button), against a one-off job on his board and a Master who forges every rung for a fee. It
  costs the rung's materials plus 30 🪙.
- **Recipes** for t6–t9 are t5 × 1.5/2/2.5/3. **Names:** the staff's «Посох архімага» moved t5 →
  t9. **The clamp** is refunded in silver at the trader's buy price. **Copy and durabilities**
  (120/140/160/180) were approved as written.

**Side measurements.**
- **Iron is not a bottleneck.** A mine makes 2 iron/h and holds 10 (`plots.json` →
  `bonusOutput`), so it yields 10–30 a day. A whole ladder takes 320–427 iron (an ingot is 10)
  and 7,330–8,772 🪙 of materials at the trader's buy price, against 986–1,188 before — a sink
  for the over-supplied silver.
- **`spec items`' obtainable-kit share moved** (L10 48% → 44%, L40 36% → 29%). The tier-2 stat
  lines were solved against the old share on 10-02; they are frozen and were not re-solved.
- **The estate's upgrade value** (`spec-bestiary.md` §11.5) never counted the weapon, because the
  model's weapon was level-gated. Nothing approved moves, but T2–T5 lost a pull players felt.
- **`simulate`** does not read the ladder (the reference character wears on-curve gear), so its
  pace stayed at 167.0 / 159.6 / 150.9 days.

### The tarot's Vigor multipliers, measured (2026-10-04, `e861c73` + `c1c0570`)

The owner asked how the Chariot's «−25% витрати снаги» works. Read off `VigorService.drain`: the
base cost × the stance multiplier × the card's `vigorDrainMultiplier`, then `Int(x.rounded())`, half
away from zero (checked in Swift: 1.5 → 2, 0.75 → 1, 2.25 → 2, 4.5 → 5, 0.5 → 1).

Base costs (`tuning/vigor.json`, `tuning/combat.json`): a step 2, an autobattle round 2, an attack
2, a defend 1, a flee 3, the mage's flee tax 2, the special attack 4/4/5, the special defence 3/3/4
and the stance activation 4/4/5 (warrior/archer/mage); Bloodlust lifts the warrior's blows ×1.5.

**Before** (the card did not reach the techniques at all — they called `drain(_:amount:)`):

| Action | Base | Chariot ×0.75 | Hanged Man ×0.5 | Devil ×1.5 |
|---|---|---|---|---|
| step · autobattle round · attack | 2 | **2** | 1 | 3 |
| defend | 1 | 1 | 1 | **2** |
| flee | 3 | 2 | 2 | 5 |
| techniques, the stance, the mage's flee tax | 2–5 | not applied | not applied | not applied |

- ×0.75 saved nothing on the walk, which is the card's whole point: 1 on a flee, 1–2 inside
  Bloodlust.
- ×1.5 doubled a defend.

**Offered:** a fractional carry (recommended; one column and a migration), stochastic rounding, or
keeping the rounding. The owner kept the rounding, moved the Chariot to ×0.5, and had the card reach
every spend (`drain(_:base:multiplier:)`).

**After** (the Chariot and the Hanged Man at ×0.5, the Devil at ×1.5):

| Action | Base | ×0.5 | ×1.5 |
|---|---|---|---|
| step · autobattle round · attack | 2 | 1 | 3 |
| defend | 1 | 1 | 2 |
| flee | 3 | 2 | 5 |
| the mage's flee tax | 2 | 1 | 3 |
| special attack, warrior·archer / mage | 4 / 5 | 2 / 3 | 6 / 8 |
| special defence, warrior·archer / mage | 3 / 4 | 2 / 2 | 5 / 6 |
| stance, warrior·archer / mage | 4 / 5 | 2 / 3 | 6 / 8 |

A 40-step trip costs 80 Vigor, 40 under a ×0.5 card and 120 under the Devil.

**The Chariot then dominated the Hanged Man** (×0.5 against ×0.5 and −10 dodge). Rounding leaves no
room on the walk: a step of 2 can only fall to 1 or 0. Offered:
- the Hanged Man at ×0.25 (recommended — equal on steps and plain blows, a free defend, flees and
  techniques at 1);
- the Hanged Man at ×0.5 and +25% XP;
- the road for the Chariot and the fight for the Hanged Man (a new card field, content schema v18).

The owner chose XP at **+15%** (`c1c0570`). A kill worth 100 pays 115. It covers every XP source
except the Judgement's one-shot: a draw needs the 24 h cooldown and a card lasts 6 h, so no card is
active when the Judgement pays.

**Still open:** the Devil doubles a defend; and since rounding stays half-up, a card multiplier must
move a 2 by a whole point (×0.75 cannot) — the rule is in `CLAUDE.md`.

### The armour enchant, measured (2026-10-05/06)

Why the Master's enchant became the armour's ladder, and why its price is its only gate. The
decision record is `content/spec/spec-items.md` §11, which carries the tables the owner decided
on: the four strengths, a level bought ahead of the player, the price ladders, days to a level,
the fight at the edge of a trip, the arena. This section keeps what the spec does not — the path,
the finer grids and the harness, which lived in the session's scratch directory and is gone.

**What was wrong.** The enchant was `1 + 4% × level` of the piece's own stats, each stat rounded
on its own, and the only armour is item level 1.

| piece (🛡/❤️, crit and dodge 1) | first level that changes anything | what +5 added |
|---|---|---|
| hood 3 / 4 | +4 (+1 HP), 810 🪙 and 53 hides in | +1 DEF, +1 HP |
| jerkin 4 / 6 | +3 (+1 HP), 360 🪙 and 27 hides in | +1 DEF, +1 HP — and +5 added nothing to +4 |
| breeches 3 / 5 | +3 (+1 HP), 360 🪙 and 27 hides in | +1 DEF, +1 HP |
| boots 2 / 3 | +5 (+1 HP), 1,660 🪙 and 95 hides in | +1 HP |

- A stat of 1 or 2 never moves at ×1.2; a 3 moves at +5; a 4 at +4; a 5 or 6 at +3. Confirmed by
  compiling the game's two expressions (`1 + 0.04 × level`, `Int((Double(v) × f).rounded())`).
- 2,750 🪙 and 172 hides of a full set bought levels that changed nothing.
- Effective HP from a full set: about +7–8% at level 1, +4–5% at 10, +3% at 20, +2% at 40.
- 913 🪙 a budget point, against 22 for the armour itself and about 67 for the sword's ladder.
- The 380 hides of a set exceeded every other hide cost in the game together (estate 53, bags
  75, Training Ground 23, weapon 0–89).
- On bigger pieces the same percentage would have healed itself: 13–14 empty purchases of 20 at
  item level 1, 4–9 at 10, 1–2 at 20, 0–1 at 30–40.

**The path to the decision** — the owner redirected most of its turns.
1. The first proposal kept the 4% and the +20% ceiling: sell only the levels that change a number
   (seven purchases instead of twenty), show the stats on the card, price the enchant as a share
   of the piece's own price. Its question — "how many times the piece's price should a full
   enchant cost" — was not understood, and the quiz was rejected.
2. Shown the stats (+3 DEF, +4 HP on the set), the owner said: keep the steps as they are and
   make the upgrade worth buying.
3. A bigger percentage alone fades: ×2.0 at +5 is +13–16% XP per Vigor at levels 5–10 and +3% at
   20, because it still multiplies a level-1 piece. So the lift has to be an item level — the
   weapon ladder's law. Four strengths went into a quiz with the set's real numbers, each ladder
   described as opening at player levels 5 … 25. The owner picked 75%.
4. I built it with those gates: a gate on the purchase, the wearer's level in a piece's stats (a
   traded or older piece worked at the level its wearer had opened), and a cache refresh on every
   level-up. The owner read the report and refused the gate: «Хіба ми говорили про те що заточка
   відкривається згідно рівня? Мені це не подобається … краще зробити просто велику вартість».
   It had been a table column and a clause in an option, never a question of its own.
5. Shown the price table and four ladders, the owner asked for variants between the old prices
   and 100 × level², and of three picked the cheapest, 50 × level². Then: an enchant keeps its
   100% success, the Master's button goes back to «✨ Покращити», and the word «заточка» leaves
   every screen as slang.

**The four strengths.** XP per Vigor against today (the estate scaling, no enchant), mean of the
three classes, the simplified trip (HP budget, no dish healing). The percentage row is shown at
+5; the ladders at the enchant level of the same height as the weapon rung the level opens.

| L | +20% a level | ladder 50% | ladder 75% | ladder 100% | 75% against the forest as solved |
|---|---|---|---|---|---|
| 5 | +14% | +6% | +11% | +14% | −7% |
| 8 | +16% | +6% | +10% | +10% | −19% |
| 10 | +13% | +13% | +18% | +21% | −21% |
| 12 | +8% | +8% | +8% | +13% | −28% |
| 15 | +11% | +11% | +16% | +20% | −19% |
| 18 | +5% | +5% | +6% | +9% | −23% |
| 20 | +3% | +7% | +9% | +12% | −33% |
| 22 | +4% | +8% | +12% | +17% | −30% |
| 25 | +3% | +7% | +10% | +13% | −24% |
| 30 | +2% | +6% | +8% | +9% | −13% |

- The forest as solved pays 19–62% more XP per Vigor than today's in this measure — that gap is
  the estate scaling.
- The marginal value of each rung of the 75% ladder at the level of its height: +11% / +7% / +5%
  / +2% / +2%. +4 and +5 buy 31–37% less HP lost per fight and little pace.
- Past level 20 every creature is outgrown (the roster tops out at №14), and the level gap cuts
  incoming damage far more than armour can. That is why the late rungs move pace so little.

**A level bought ahead of the player** — what removing the gate exposed. XP per Vigor of the
75% ladder against today / against the forest as solved, full model:

| L | +1 | +2 | +3 | +4 | +5 |
|---|---|---|---|---|---|
| 4 | +12% / −5% | +23% / +4% | +35% / +15% | +51% / +28% | +66% / +41% |
| 5 | +11% / −7% | +22% / +3% | +35% / +14% | +61% / +36% | +79% / +51% |
| 6 | +12% / −5% | +23% / +5% | +34% / +15% | +58% / +35% | +69% / +45% |
| 7 | +12% / −22% | +23% / −14% | +34% / −6% | +53% / +8% | +69% / +19% |
| 8 | +10% / −23% | +20% / −16% | +33% / −7% | +50% / +5% | +59% / +11% |
| 10 | +11% / −26% | +18% / −21% | +28% / −14% | +36% / −9% | +44% / −3% |
| 12 | +6% / −32% | +10% / −29% | +17% / −25% | +27% / −18% | +37% / −12% |
| 15 | +7% / −23% | +12% / −20% | +15% / −17% | +19% / −14% | +22% / −12% |
| 20 | +1% / −39% | +3% / −37% | +7% / −35% | +10% / −33% | +11% / −33% |
| 25 | +3% / −27% | +5% / −26% | +6% / −25% | +8% / −24% | +10% / −22% |

Levels 4–6 are estate T2 and level 7 opens T3, which is why the "against solved" column drops
there. From level 10 not even +5 beats the solved forest.

**The affordability model** — what a price ladder does with no gate. Day by day:
- the level reached by each day comes from the days model below;
- silver in: the three daily jobs at that level (the average of the jobs offered, scaled as
  `ProgressionMath.questReward` does: 78 a day at level 1, 108 at 10, 123 at 20, 131 at 25) and
  the King's silver at each decree's level (2,820 over the chain);
- silver out first: the armour (810 from level 4), the estate's silver steps and the Training
  Ground;
- then each enchant level for the WHOLE set as soon as it is affordable. No loot is sold.

The first pass used today's pace. The chosen row was then iterated — the enchant speeds the
levels, which moves the levels the same days fall on — and converged in two rounds.

| price a piece | set | +1 | +2 | +3 | +4 | +5 | peak against solved |
|---|---|---|---|---|---|---|---|
| 40 / 100 / 220 / 450 / 850 (the old table) | 6,640 | L4 | L5 | L5 | L7 | L12 | +15% (L6, +3) |
| 50 / 200 / 450 / 800 / 1,250 — chosen | 11,000 | L5 | L5 | L6 | L11 | L19 | +15% (L6, +3) |
| 80 / 200 / 440 / 900 / 1,700 (×2) | 13,280 | L5 | L5 | L6 | L12 | L22 | +15% |
| 70 / 250 / 550 / 1,000 / 1,700 | 14,280 | L5 | L5 | L7 | L15 | L22 | +5% |
| 75 / 300 / 675 / 1,200 / 1,875 | 16,500 | L5 | L6 | L8 | L17 | L24 | +5% |
| 100 / 400 / 900 / 1,600 / 2,500 | 22,000 | L5 | L6 | L10 | L20 | L27 | +5% |
| 120 / 300 / 660 / 1,350 / 2,550 (×3) | 19,920 | L5 | L6 | L8 | L17 | L26 | — |
| 200 / 500 / 1,100 / 2,250 / 4,250 (×5) | 33,200 | L5 | L6 | L13 | L24 | L32 | — |

- **The chosen row, iterated:** +1 day 9 and +2 day 17 (both level 5), +3 day 38 (level 7), +4
  day 76 (level 15), +5 day 122 (level 22). Its peak against the solved forest falls to +5%
  (level 6, with +2), because +3 now lands on level 7. The owner chose on the first-pass row.
- Days to L10 / 14 / 19 / 25 / 30 / 40 for that saver: 51 / 70 / 99 / 149 / 209 / 439, against
  today's 63 / 86 / 119 / 175 / 241 / 474 and the solved forest's 51 / 65 / 88 / 123 / 173 / 385.
  With the gates (each level bought at 5 / 10 / 15 / 20 / 25) the same model gave
  57 / 78 / 108 / 158 / 218 / 448.
- The days model spends levels 5–6 slowly (estate T2 feeds 45 Vigor a day), which is why two
  enchant levels fit inside level 5. Bought food, job Vigor and decree Vigor are not in it.

**Rebuilding the harness.** A scratch SwiftPM package with copies of `Modules/ROIContent` and
`Modules/ROISim` as its own targets — the tier-2 recipe above.
- **`enchantfights`**, the roller. Arguments are armour factors; `--unscaled` fights at T1;
  `--weapon-lag` holds the weapon one rung behind. It writes one CSV row per factor × player
  level 1–40 × class × spawnable creature: win, rounds, HP%, Vigor, the player's HP and DEF. It
  runs 2,000 `.basic` fights a cell, seeded by FNV-1a over `[creature, class, level]`, so every
  factor faces the same dice. `BalanceSimulator.seed` is internal to `ROISim`, hence the FNV.
  - The player: `ProgressionMath.baseStats`, the highest weapon rung whose gate is open, and from
    level 4 the four Forester pieces scaled per stat plus the flat 4-piece bonus.
  - The creature: authored stats through `CombatMath.scaled` at the estate tier the level opens.
- **`enchantduels`**, the arena: the same players through `DuelMath.resolveRound`, both sides
  on a stationary mix, 6,000 duels a cell.
- **The trip, the days and the affordability**, about 200 lines of Python over the CSVs: the
  expedition model exactly as it is stated above, and the day-by-day silver model of this section. Food per day is 0 / 45 / 300 / 600 / 900 / 990 / 1200 by tier, reached at
  levels 1 / 4 / 7 / 10 / 13 / 16 / 19; dishes eaten above the pool heal a quarter of their Vigor.
- **The spec-block checker:** for every `<!-- generated: roi-content spec … -->` block, re-run
  the command in the marker and test that the block is still a contiguous excerpt of its output.
  Three were stale after this change.
- **Traps met.**
  - `swift build --build-tests` builds the game target too, so the tests cannot run until the
    game compiles against a changed DTO.
  - In zsh `$VAR:content/…` applies a modifier to the variable. Write `"${VAR}:content/…"`.
  - A factor of 3.1 puts a stat of 5 on 15.5. The probe multiplied by the literal and the game
    by a derived quotient, which can differ in the last bit. `LadderScale` keeps the numerator and
    the denominator for that reason, and a test pins the result.

### The 2026-09-07 quest rebalance (the balance half of the pre-push pass)

Two faults with one cause — a flat reward and an unfiltered pool.

**Three of nine jobs were impossible before level 7.** `mat.iron` is foraged only from
km 11 (the Old Wood), where the opening ledger puts survival rather than Vigor as the
binding constraint, and the only other source is a Mine plot behind an estate slot
(T2 = player level 4). So `trader.iron`, `master.ore` and `master.smelt` (which also
needs the forge, T3 = level 7) could be handed to a level-1 player as their one job.

**And a flat XP reward is worth 1,800× more at one end of the game than the other.**
`master.blade_trial` paid 80 XP for five kills: 67% of a level at 1, 0.036% at 20.

Fixed as: `minLevel` per job, filtered BEFORE the daily hash (the pool is content, the
filter is not a difficulty dial — a daily that cannot be done is a day with one fewer
job); authored rewards halved; and payout scaled by `ProgressionMath.questReward`, each
currency on the curve it belongs to — **XP on the `mobXP` exponent** so a job stays worth
the same NUMBER OF KILLS, **Vigor on the pool it refills**, **silver linearly at 1.5% a
level**. The silver rate came from arithmetic: at the 4% first written, the level-40 daily
came to 282 against the old flat 220 — a cut that raises the number where the surplus
already is.

**Bands alone left one reachable job per NPC below level 4**, so six early forage
deliveries were authored (5 lumber · 6 berries · 6 nuts · 6 pebbles, split across the
three NPCs). That is new content in a release that ruled new content out — taken
deliberately on the user's call, because a band with no early pool behind it is worse
than no band. `spec-economy.md` §4 is *AMENDED* and its faucet table regenerated: the
daily take is **78 → 153 silver across the arc** where it was a flat 220, ≈10k over a
90-day lifetime against ~19.8k.

Two tool findings came out of it. **A new tuning constant is invisible to the digest
until the digest names it** — `questRewards.silverPerLevel` was added to `economy.json`
and the `tuning` half did not move; hashing it was the fix. And the verbatim check over
all ten generated spec blocks found **two that never reproduced from their own markers**
(`spec-economy`, `spec-sets`): two fragments of one command's output with a section
silently skipped between them, one with prose living inside the markers. Not drift in the
numbers — drift in the mechanism meant to detect drift.

**Digest as Phase 11 left it (schema v10):** `records f6fc421256085066`,
`tuning a23248441d58a78a`, `spawns eaea309f4813dfa2`, `quests 30de20902006e3b9`. **This is
a record of that moment, not a current reading** — it said "Current" until 2026-09-14 while
two other files carried different figures, which is the drift a single source exists to
stop. The live baseline lives in `Prompt.md` and nowhere else.

`tuning` moved twice during the 2026-09-09 live-play polish, both predicted and both
named in the digest BEFORE the edit — the 09-07 lesson applied rather than relearned:
`realTime.restSweepInterval` (`ad7bdb94d0efc668` → `80e4b32ee7392d30`, the notification
watchman's cadence) and `passive.dailyBudgetMinutes` (`→ a23248441d58a78a`, the 3 h/day
ceiling on passive expeditions). `records`, `spawns` and `quests` have not moved since
09-09: no record, spawn band or quest pool was touched by any of it.

`scale` 60 → 1.0 moved TWO halves, and both were predicted. `tuning` for the obvious
reason. `records` because it hashes the DERIVED `PlotCatalog.intervalSeconds`
(`plotIntervalSeconds / timeScale`) rather than the authored number — a guard Phase 4b
placed there so that retiring the `testMode` flag in favour of `time.scale` could not
change the value it produced without saying so. It said so.

The 2026-09-08 change moved `tuning` alone (`fa84304a356e65a0` → `c44f38cf0fae5ecd`):
HP regen 5% → 20% of max HP per real minute, `tuning/vigor.json` →
`healing.regenPerMinute`. A full rest at the estate became 5 minutes instead of 20.
`simulate --strict` did not move at all — 0 broken bands, 12 warnings — because the
sweep models fights, not the recovery between them, which is also the reason this knob
can be turned without re-deriving anything.

**Settled at 10% on 2026-09-09** (`941eef33f757fa6b` → `ad7bdb94d0efc668`), halfway
between the original 5% and the 20% that replaced it: a full rest is 10 minutes.
`tuning` alone moved, and `records` held — which retroactively confirms that the
scale flip moved `records` because of `PlotCatalog.intervalSeconds` and nothing else.

The 2026-09-07 quest retune moved three of the four: `records` (halved rewards plus the new `minLevel` band), `tuning` (the quest reward curve in `economy.json` — which held on its first run, because the digest was not hashing the new knob yet; hashing it was the fix) and `quests` (the daily pick is filtered by level before the hash, and the replay sweeps levels 1/8/20 now). `spawns` held, as it must — no foraging band moved.

Before it, and unmoved since Phase 10: `records ee3fa4731c5a3a27`, `tuning 3ef097038094a4d8`, `quests 2e52ecdfa45276ec`.

Phase 10 moved `records` and `spawns` and held `tuning` and `quests` — the two
halves predicted before the edit, which is the whole point of splitting them.
Before it: `records 992c19419d162379`, `spawns 1a18e0cd09136c69` (bundle digest
`e004ea8d93ba32b9`), unmoved through the whole of Phase 9.

Phase 9 moved `spawns` alone, and only because the three zone systems were
reconciled — the foraging bands went from 1–2 / 3–5 / 6–49 to 1–10 / 11–25 /
26–49. No roster change is in the data yet: the bestiary spec is approved, and
authoring it is Phase 10's job.
Phase 8E before it moved three of the four: `records` (the plot ladder, the retuned farm
and coop), `tuning` (`fullRegenHours` gone) and `spawns` (the forage replay is
new, and the pools it replays moved out of Swift). **`quests` did not move.**
Phase 8D before it moved `records` (the archetype fingerprint gained `minLevel`)
and `tuning` (the two dodge lifts became multipliers) and left the other two
alone; its baseline was `dfe1ff8e24605e0d` (schema v9).
Previous baseline `583a32cb5a9d9dc7` (schema v8). Phase 8C moved exactly two
halves for its own reasons: `records` (enemy + archetype fingerprints lost
silver, the reference kit moved with the warrior profile) and `tuning` (stances
became multipliers, warrior base attack 10 → 12, `passive.silverMultiplier`
deleted). Before that, `a4d825a8d728f4f8` (schema v7).
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

### What the opening ledger measured (2026-09-02)

`spec-economy.md` §7 decided to **measure the opening before retuning it**, and
`Modules/ROISim/OpeningLedger.swift` is that measurement: levels 1–3 priced at
every depth against the trail, since before the estate exists the trail is the
only income there is. It reports one row per distinct spawn set, at the
shallowest km that has it.

```
km  mob levels    xp/kill  vigor/kill    win%     kills     trail     spent  walk in       net  if cooked
1   1                 8.5         9.1    100%      92.2       389       837        2      -335        439
4   1,4              89.0        11.4    100%       8.9        37       101        8        44        154
7   1,4,7           213.2        13.6     97%       3.7        16        50       14        66        116
10  1,4,7,10        388.4        14.9     95%       2.0         9        30       20        73         96
13  4,7,10,13       917.0        23.2     66%       0.9         4        20       26        73         80
20  13,16          2045.9        28.1      9%       0.4         2        11       40        66         68
26  22            10020.0        15.7      0%       0.1         0         1       52        62         62
```

**The spec's own conclusion is inverted by its own measurement.** The opening is
not Vigor-bankrupt; the SHALLOW opening is. One kilometre of extra walking is
worth more than the whole deficit, and the flip happens at km 4 — the first
depth where anything but the boar spawns. Depth then has a measured **optimum**
rather than an open ceiling: Vigor stops binding at about km 4 and survival
takes over at about km 11, where the win rate falls off a cliff (95% at km 10,
66% at km 13, 9% at km 20). "Walk deeper than is comfortable" is now a number.

Three modelling choices carry the result, and each of them moves it:

- **Raw meat is not income during this stretch.** It restores nothing as found,
  and every recipe that turns it into a portion is a `kitchen` recipe — a room
  gated on estate tier 2, which is the level the opening ENDS at. So it is
  printed as `if cooked` (the size of what the gate holds back: 774 Vigor at km
  1, more than twice the deficit) and kept out of the net. `spec-economy.md` §3's ledger
  credited the boar with 8.4 Vigor of cooked meat during a stretch where the
  oven is locked.
- **Only forage that is edible as found counts.** Half the km 1–10 pool is
  lumber and river pebble; the raw potato deeper in is food that needs the same
  locked kitchen. Counting the whole pool would have paid double.
- **Kills use the level-gap scaler.** 92.2 at km 1, not the flat 788 ÷ 10 = 79
  the generated table prints — a level-3 player earns 8 XP from a level-1 boar,
  not 10, and the decay adds 17% to the count.

Deliberately excluded, and each one a whole loop rather than a rounding: silver
(hide sells, quests pay, the trader stocks both food and lumber), the events the
approach walk rolls on the way in, and re-entered rooms (the encounter weight
decays, so every real route costs more than this one). All three push the same
way, which is what makes the table a **floor** on the opening rather than an
estimate of it.

**The new finding is `opening.shallow_is_bankrupt`**, and it is a warning rather
than a broken band on purpose: §7 decided to measure before retuning, so an
error would fail the build on the exact number the project agreed to look at
first. It fires when the shallowest depth cannot pay for itself while a deeper
one can — which is to say, when the game is solvable only by a move it never
teaches. That is precisely what a first-hour playtest walks into.

`spec-economy.md` §2 was **amended the same day**: an *AMENDED* notice on the
heading, a *superseded* note under the 664, and a *Measured* subsection quoting a
generated block. Rather than typing the table in, the ledger got its own spec
table — `roi-content spec opening` — sharing `simulate`'s seed and sample size, so
the two cannot print different numbers; `runs`/`seed` moved to one place in
`main.swift` to make that structural rather than coincidental.

**Read the absolute numbers as a ceiling.** The ledger measures
`ReferenceCharacter` — a class stat line plus a FULL common kit — while
registration grants only the class starter weapon and the first armour is a
workshop craft at estate T3 / player level 7. So a real level-1 player is weaker
than anything the report prints: more rounds, more Vigor, lower win rates. The
km-1-vs-km-4 ORDERING survives it and is amplified (weaker gear multiplies the
per-kill cost equally, but km 1 needs 92 kills and km 4 needs 9); what is at risk
is whether a level-1 player can actually beat the km-4 moose, which the sim puts
at 100% *with the kit*. That is the single most important thing the playtest
measures.

### What Phase 9's item spec found (2026-08-31)

**The measurement.** `roi-content spec items` gained two tables — slot coverage and
the obtainable kit against the on-curve kit — so the gap is printed rather than
argued. The shipped wardrobe is **7 items**: three weapons that ladder 1→40 and
four armour pieces frozen at **itemLevel 1 forever** (the Master's enchant, +20%
of the piece's own budget, is the only thing that ever happens to them), plus
three slots with nothing in them at all. A fully enchanted kit is **97% of the
on-curve budget at level 1 and 40% at level 25**: the game starts on curve and
leaves it immediately, and the sawtooth (58% at L10 → 43% at L15) is the
ten-level ladder rungs arriving late against a curve that climbs every level.

**The finding that reset the plan: two half-strength errors were cancelling.**
The bestiary carries ~60% of its archetype contract (~50% before Phase 10's
re-spread lowered the levels without touching the stats); the player carries ~40% of
theirs. The seven "100% win at 4–11% HP" rows are what those two produce
*together*, and neither was chosen — the roster predates the archetype table, the
wardrobe predates the budget curve. `spec-bestiary.md` §9 had committed Phase 10
to regenerating the roster, which would have removed exactly one side and doubled
every enemy against a player who did not move. **The specs were about to
contradict each other, and only a printed number caught it.** §9 was amended in
place rather than quietly rewritten.

**The frame that costs no content.** `weapon_upgrades.json` already describes
what an armour set needs — an item id and rungs carrying an `itemLevel`, a stat
line and material costs — and `EquipmentService.nominalStats` resolves a row by
`itemId + tier` **without checking the slot**. So laddering armour is a data edit
against a code path that is already slot-agnostic; only the upgrade *flow* needs
building. That is what "sets of different levels" means mechanically: one set
that climbs is four items, four sets at four levels is sixteen items with
thirty-two locale keys. Decided: built **after** the rebalance, together with the
bestiary regeneration, because the two halves are one correction.

**Two holes in the set frame, deferred to `spec-sets.md` with the measurement
recorded.** The one shipped set bonus is flat and rots exactly as the project's
own rule predicts — 8.4 points against members worth 37 at item level 1 and 210
at item level 25, so **23% of the set at the bottom of the band and 4% at the
top**. And the 25% cap does not cover the fix: `flatSpend` sums only the
`flat_stats` thresholds, so `{"kind": "gear_multiplier", "multiplier": 3.0}`
validates cleanly. Nothing is exposed while no set uses the case — which is
exactly why the cap must land *before* the first multiplier is authored.

**The Forester set's numbers were then unfrozen by the user, and measuring first
is what kept it from being wasted.** The offer was to rewrite the set's stats from
scratch. Measured: the four pieces already spend **37.0 budget points against a
nominal 36.0** at item level 1 — on curve, inside the validator's rounding slack.
So re-deriving them moves nothing, because **the 40% gap is the frozen
`itemLevel`, not the spread**. What the freedom does buy is real but smaller: the
flat→multiplier transition becomes a write instead of a migration, and the
shared-set compromise becomes a decision — one set is worn by all three classes
(nothing restricts equipment by class anywhere) and its single spread delivers
**81 / 86 / 75%** of what the warrior / archer / mage armour profiles ask for.
The cheap fix needs no new items and the codebase already named it:
`EquipmentService.nominalStats`'s comment says *"the class-identity flavour moves
to sets"*. Explicitly NOT licensed: armour whose `itemLevel` tracks the wearer —
that closes the gap and nullifies every gear upgrade, the same reason
`EnemyGenerator` runs at design time.

**And a slot that cannot be authored at all.** `tuning/budget.json` gives every
class a `weapon`, an `armour` and an `offHand` share profile and **no accessory
profile**. The two accessory slots have weight (0.5 each) and no answer to what
an accessory spends its points on, so filling them is a tuning decision before it
is a content one. Related: the reference character **wears an off-hand today**,
because that profile does exist — the simulator has always measured a player
holding an item the game has never sold.

**Housekeeping that came with it.** `GearStatsDTO.pointsSpent(at:)` (the inverse
of `BudgetMath.spend`) now lives in `ROIContent/BudgetCurve.swift`, because the
validator's set-bonus cap needs it and ROIContent cannot import ROISim — a second
copy of the exchange rate is the exact duplicate the item budget exists to
prevent. Verified inert: 222 tests, `validate --strict` unchanged, the cap
negative-tested (raising a bonus past 25% still fails), and **all four digest
halves unmoved**.

### What Phase 9's set spec found (2026-08-31)

**The inherited fix was wrong, and only measuring it caught that.** `spec-items.md`
handed the set spec "flat bonuses rot, make them multipliers". Both halves needed
correcting.

**The flat bonus does not rot today.** Its denominator is stable because the set
never climbs: 8.4 points against 36 is **23% at every level**, sitting just under
the 25% ceiling. It rots only when the gear ladder lands and the members go 36 →
210 across the band. So the defect is real but not live, and it must be fixed in
the same package as the ladder rather than before it.

**And `gear_multiplier` scales the wrong thing — the mirror of the same defect.**
`EquipmentService.recomputeBonuses` applies the factor to the wearer's WHOLE
equipped contribution, weapon included, and the weapon is not a member of the set
— it is also the only slot that climbs. The same **×1.05 costs 8% of the members'
budget at level 1 and 33% at level 40**. A flat bonus decays; a whole-kit
multiplier compounds; both measure a bonus by a denominator that is not its own.
Phase 8C learned half of this when it made every stance lift a multiplier of the
character's OWN stat; the other half is that a multiplier only self-normalises
when it multiplies its own base. Sharpest form: under the whole-kit reading the
largest legal multiplier falls ×1.15 → ×1.04, so **no single authored value is
legal for a whole lifetime.** Scaling the members only is a constant ×1.24.
Inert to correct — no set uses the case, so the semantics can be fixed before
anything depends on them.

**The frame the user actually asked for, finally in one piece.** Set strength is
a **ladder whose top rung is the 25% ceiling**, and it is independent of the
members' item level: the rung sets the share of the ceiling, item level sets what
that share is worth. Because a set that spends its budget honestly has
`memberSpend ≈ memberBudget`, **the multiplier minus one IS its share** — ×1.07
reads as "7 of the 25 points of ceiling" with no arithmetic. `set.forester` is
rewritten as the **first and weakest rung**: one four-piece threshold at ×1.07,
29% of the ceiling. An earlier draft proposed ~19% to preserve its present
strength and was wrong for a reason worth keeping: it treated Forester as *the*
set rather than *the first* set, and a ladder whose bottom rung is
three-quarters of the way up is not a ladder.

**Two shapes the content cannot express yet.** Six-piece thresholds are
unreachable while `off_hand` and the accessories are empty — the validator
refuses them as exceeding membership — so they are not a rejected design but a
blocked one. And the class tilt cannot live in a bonus: `gear_multiplier` is one
scalar, and a case that named stats would still tilt everyone the same way. With
more than one set the tilt is simply *which set a player wears*, which needs no
new effect case, no class dimension and no runtime class check.

**Everything ships with the gear ladder, after the rebalance.** What the
rebalance gets is that the decisions are taken and measured, so the ladder
package is a build rather than a design. New: `roi-content spec sets`.

### What Phase 9's economy spec found (2026-09-01)

**The last spec's finding was not about silver.** It was that the game's opening
is Vigor-bankrupt and an APPROVED document said otherwise. `spec-progression.md`
§3 justified levels 1–3 having no estate with *"about eleven kills to reach level
4, so it is hours, not days"*. **Eleven reaches level 2.** Level 4 is 788 XP —
120 + 240 + 428, straight off that document's own printed table — which at the
shipped boar's 10 XP is **79 kills**, and at ~16.8 Vigor a kill against 8.4
returned as cooked meat is **664 Vigor of deficit against a 105 pool.** Short by
six pools, and the estate that is designed to pay for it does not exist yet.

> **Superseded 2026-09-02 by the measurement it asked for** — see *What the
> opening ledger measured* above. The deficit is 374, not 664, and the pure-boar
> path is 92.2 kills, not 79: this paragraph's ledger credited the boar with
> cooked meat across a stretch where the kitchen is locked, and counted no
> foraging at all. The finding below about WHERE errors hide stands unchanged,
> and now has a second instance — the correction was wrong the same way.

**The lesson is about where errors hide.** Every table in that spec was printed
and every table was right. The wrong number was in the PROSE ABOUT the table —
a count nobody generated, in the one sentence that decided a design question.
"Numbers are printed, never typed" protects the tables; it does not protect the
sentence underneath them, and that is where this one lived for two weeks.

**The game does have an answer, and it was never written down either.** The boar
is `trash` (XP ×0.4) and the only creature at km 1–3, but the shipped moose at
level 6 pays **418 XP — forty-two boars** (223 and twenty-one once the re-spread
lands; the generated table prints the shipped state, which is how the plan-vs-data
slip was caught at all). The intended opening is **to walk deeper than is comfortable,
immediately**: depth is the difficulty dial from the first hour, not from the
first plot. Decided: **measure before retuning.** The report gives pace 1→40 as
an aggregate and says nothing about the only stretch with no estate behind it, so
a band for levels 1–3 comes first; the one-number fix (boar meat 0.70 → ~1.4)
waits for a number the report can check.

**Silver: a faucet with almost nothing to drain it.** Mandatory spend across the
entire game is **1,600**. Quests alone pay **220/day ≈ 19,800 over ~90 days**,
before a hide is sold. Buying every material rather than gathering it costs
~21,900 — so the trader is the only real sink and using it is a choice, and a
player who forages ends with roughly twenty thousand spare. Three shapes nobody
chose, recorded and left alone because none is broken: the spread is a uniform
**−50%** on every line (so no material is ever a better trade than another),
**the forge adds no value in either direction** (10 iron = 200 to buy = 1 ingot =
200; both sell for 100 — inventory compression wearing an economy's clothes), and
**the tavern has exactly a 0% house edge** (win pays ×2, tie refunds, two fair
dice = EV zero — a variance machine, not a sink).

**`lootMultiplier` is wired to QUANTITY, and the detail is the decision.**
Scaling `chance` is impossible — it is a probability, and ×3.0 on the boar's 0.8
hide is 2.4. Scaling quantity is linear, but `quantity` is an `Int` and the
multiplier a `Double`, and **rounding destroys the distinction it exists to
make**: at a base quantity of 1, ×0.5 · ×1.0 · ×1.2 · ×1.7 all round to 1 or 2
and six archetypes collapse into two. So the fractional part becomes a
probability rather than a rounding — `floor(q×m)` plus one more at `frac(q×m)` —
and the expected yield is exactly `chance × quantity × multiplier` at any base.
**And wiring it is not a one-line change**: the printed `hide ×mult` column shows
the elite going 1.80 → 5.40, because its table was already hand-differentiated.
The loot tables must be re-normalised to a base in the same pass the stat lines
are — two answers to one question is what the pipeline exists to remove, and this
was the last place in the bestiary holding both. It goes with the regeneration.

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

*Superseded 2026-09-27 — these are Phase 8C's values, not today's.* The technique rework
tuned the kit to shorten an elite fight by ~20% for every class (the mage's was 52%) and
capped any technique blow at an ordinary crit: bloodlust attack ×1.25, hawks_eye gained attack
×1.15, arcane_resonance attack ×1.15, Vital Shot ×2.0 → ×1.5, Soulfire's burn 0.35 → 0.15.
Read the live values from `tuning/combat.json`; the why is in `sessions.md`.

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

**The last subtractive formula in the game is gone.** The failed-flee counter
still ran `max(1, ATK − DEF/2)` — Phase 5C replaced subtraction with absorption
everywhere else and missed this one site. Absorption made DEF values large (a
level-40 warrior carries 217 where the old model expected ~30), so half of it
exceeded every enemy's attack and the "forced full-damage hit" was dealing
literally **1 HP to every class at every level**: 0.2–1.0% of a bar, which made a
failed escape free. Routed through `applyAttack` with `cannotMiss` and a crit
RATING of 0 (the spec's "no crit roll", said to the curve rather than to a
branch). It now costs 6.1% of a bar for a warrior, 8–9% for an archer or mage,
and **the same percentage at every level** — 9–14% against an elite. Roughly two
rounds' worth of damage for a failed escape, which is what the comment always
claimed it was. The digest does not move: the flee formula was never
fingerprinted, only `fleeChance` and `fleeVigorExtra` are.

Found by reading the diff, not by the simulator — `FightSimulator` has no flee
policy, because no design document states when a player should run. Worth knowing
about the tool: it measures the fights you tell it to have.

**Still open after 8C, and all reported by the run itself:** the two remaining
flat rating bonuses, the mage's 93% win rate against an elite at level 5, and the
half-strength bestiary. Phase 8D closed the first two; the bestiary is Phase 10's.

### What Phase 8D did

Three things, all of them items the 8B report had been printing every run.

**The last two flat lifts became multipliers (schema v9).**
`specialDefense.shadowVeilDodgeBonus` → `shadowVeilDodgeMultiplier ×2.0` and
`defend.archerDodgeBonus` → `archerDodgeMultiplier ×1.5`, both REQUIRED on decode
for the same reason the stance fields are: a defaulted 1.0 reads as "this
technique does nothing". The values were chosen on the EFFECT, not the rating —
what the flat bonus was worth in points of dodge chance around level 10, which is
the middle of its own decay:

| | L1 | L10 | L20 | L40 |
|---|---|---|---|---|
| Shadow Veil +50 (was) | +16.1 pp | +9.4 | +6.4 | +4.0 |
| Shadow Veil ×2.0 (now) | +9.0 pp | +9.4 | +9.4 | +9.4 |
| Defend +30 (was) | +11.6 pp | +6.3 | +4.2 | +2.5 |
| Defend ×1.5 (now) | +5.3 pp | +5.5 | +5.5 | +5.6 |

The report now MEASURES both rather than trusting them: a multiplier holds by
construction only if the rating's denominator grows with the rating, and the
curve is the only thing that can say so. Three call sites in `CombatController`
compose the lifts as a product of the player's own rating and round once, the way
`CombatMath.buffed` rounds each stat once.

**Every archetype row gained a required `minLevel`; elite and boss are 14.** The
plan specified the floor and nothing enforced it. Enemy stats are frozen at
design time, so `enemies.json` is the only place it can break and the validator
is the only thing that can catch it — which matters in Phase 10, when the
generator fills the table. The shipped roster already complies (its one elite is
level 25), so this is a lock rather than a fix, negative-tested in both
directions plus the level-14 positive control. The floor applies to the `0...0`
sentinels too, deliberately: a rule with an "unless it is unreachable" clause is
a rule nobody can check.

The floor also made the report honest. The sweep rolls every archetype at every
level because that is what proves level invariance, but the tail band was raising
findings on cells the validator now refuses — the mage's level-1 and level-5
elites. They are skipped, and the worst shippable tail reads `mage L20 vs elite —
p90 89% HP, p99 100%, win 96.2%`.

**`simulate`'s default sample size went 2000 → 8000, because `--strict` was
failing on noise.** The level-invariance band is a ±15% ratio of two means; at
2000 fights the mage-vs-skirmisher row reads ×1.16 from the same seed that gives
×1.13 at 8000, so the gate the workflow depends on was crying wolf at HEAD. The
whole sweep costs 2.6s at 8000 against 0.7s at 2000.

**Proof the change is confined:** at equal sample size every fight number in the
report is byte-identical before and after. `FightSimulator` models neither
Defend nor Special Defence, so the only lines that moved are the lift audit, the
four warnings that went away, and the header. Digest: `records` and `tuning`
moved (the archetype fingerprint gained the floor, the tuning half the two
multipliers) and **`spawns` and `quests` did not** — no selection logic was
touched, and each new field was negative-tested to a DISTINCT digest value
(veil ×2.1 → `924ff095f7971c49`, defend ×1.6 → `f09d71add3e1d551`, elite floor 15
→ records `b94c5e72a1a899fc`), so the coverage is not vacuous. 201 tests: the two
beyond the floor rules cover the schema handshake, which four version bumps had
leaned on with nothing exercising it — a v8 bundle would decode `+50` straight
into a multiplier.

**Deferred out of 8D on purpose:** `zones.json` (the foraging pools still in
`ExplorationService.rollLoot`). Zones now have to answer to the vigor rework —
depth gating and the food economy are the same question — so migrating them
first would mean migrating them twice.

### Phase 8E — the vigor rework (built 2026-08-31)

**Passive Vigor regeneration is gone.** This reverses the plan's "slow
regeneration plus food" and returns to the original intent.

The argument is the depth gate. `stepsDeep` increments per step with no level
gate, and it does not need one: the pool plus the food in the bag decides how
deep a player can walk and still walk home, and the walk home is symmetric.
Passive regen defused precisely that, because `VigorService.regenTick`
deliberately did not pause during an expedition — the comment argued for it, and
it was the loophole: stand at km 25, wait six hours, full pool. There was no
depth gate; there was only patience.

Removed: `regenTick`, `regenPerMinute`, `ProgressionMath.vigorRegenPerMinute`,
the call site in `routes.swift`, `progression.vigorPool.fullRegenHours` (schema
**v10**) and its validator rule, plus the `last_vigor_tick_at` column
(`RemoveVigorTick`). HP regeneration is untouched and still pauses in the
wilderness — resting is something you do at the manor.

#### The number that was wrong, and how it was caught

The first estimate said "a 2-slot estate at level 1 yields ~540 Vigor/day
against the regen's 525". **It was wrong.** It came from `PlotService`'s file
header, which described a pre-5.3c ladder of "2 / 3 / 4 / 5 / 5 / 6 / 6, +1
every 4 levels" and a "flat 5 override" — while the code four lines below it had
read `[0, 1, 2, 3, 4, 5, 6]` for three phases. **Estate tier 1 has no plots at
all.** The header is corrected and the table is now content
(`estate_upgrades.json` → `plotSlotsByTier`), which is what let the simulator
read the same ladder the game grants from.

Lesson worth keeping: a stale header outlives a stale value, because nothing
executes it. This one survived three phases of edits to the very function it
sits above.

#### What the estate actually feeds

`FoodBudget` (in `ROISim`) enumerates every multiset of plot types the slots
allow — 84 layouts at six slots — cooks each one through any recipe whose inputs
it produces, eats the rest raw, and keeps the best. No assumed mix, no
hand-picked constant except the harvest cadence, which the report prints.

    level  estate  slots  vigor/day  portions  best mix
    1      T1      0      0          0         — nothing cleared yet
    4      T2      1      105        15        coop
    7      T3      2      210        30        coop + coop
    13     T5      4      486        54        farm ×3 + forest
    19     T7      6      810        90        farm ×5 + forest

#### What it measured, and what changed because of it

Three findings, all acted on except the one deliberately deferred:

- **Pace.** The first run came out at 36–40 days against the old model's 51–56:
  the estate at three harvests a day was MORE generous than the regen. The
  decision was to go slower than the old number rather than back to it — 90 days
  of perfect play, so "3+ months" lives in the figure instead of in an assumption
  about imperfect play. The food plots were cut to land there (farm 4/h cap 20 →
  **1/h cap 6**, coop 2/h cap 12 → **1/h cap 5**; forest and mine untouched, so
  building materials keep their pace). Result: **85–93 days** as the pace then read it — **78–87** since 2026-09-10,
  when the pace started measuring from the densest room instead of the fresh
  one; the estate did not move at all, the yardstick did. The
  `pace.too_fast` band moved with the model, from 45 to 72 days.
- **Taps.** 1,211 a day at the first run, against the ~390 the plan budgeted —
  because 190 portions a day is 380 button presses on their own. Cutting the
  plots took it to **513/day**, and the report now prints taps/day rather than
  only taps-to-cap.
- **Portions rot, and it is deferred.** `restore_vigor` is a FLAT number against
  a pool that grows: the best dish in the game is 33% of a level-1 pool and 12%
  of a level-40 one — the same defect Phase 6 removed from items and 8C and 8D
  from techniques, now sitting in the whole economy. Left alone on purpose:
  batch cooking is the alternative fix and both are post-rebalance decisions.
  The report warns every run (`balance.portion_rots`) so it cannot be forgotten.
- **Levels 1–3 have no estate at all** and that is a FEATURE, decided: the first
  days are lived off the trail, XP requirements there are tiny (~11 kills to
  reach level 4), and it gives the estate a reason to exist. The report says so
  every run rather than dividing by zero.

#### `zones.json` — the last content in Swift

The foraging pools moved out of `ExplorationService.rollLoot` (two arrays and a
nested ternary) into `content/data/zones.json`: three bands, weights and
declaration order preserved. **Proved equivalent by replaying the shipped arrays
out of git against the new file for km 1–40 — identical, including weights and
ORDER**, which matters because the roll walks the array and a reordered pool
changes every draw while leaving each entry byte-identical.

Two deliberate differences: the `?? "mat.pine_lumber"` fallback is gone (a km no
zone covers now finds nothing, and the validator reports the gap — the same
lesson as `pickFor`'s `?? all.first`), and past km 40 foraging finds nothing
where it used to hand out the deep pool forever. That matches what the encounter
table already does past its own horizon.

Nine new validator rules, the digest gained a seeded forage replay folded into
the `spawns` half, and `pickWeighted` was deleted as dead.

Digest coverage was proved rather than assumed: a forage weight 2 → 3 moves
`spawns` alone, the plot-slot ladder T7 6 → 5 and a farm capacity 6 → 7 each move
`records` alone, and every enemy count in the printed spawn distribution is
unchanged across the whole phase — so `spawns` moved because foraging JOINED the
replay, not because enemy selection shifted.

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
  `intervalDivisor` WAS invisible to the digest at `scale = 60` — the 60 s floor
  swallowed every sane divisor, and the hash was identical for 12 and for 6.
  Covered instead by a two-point equivalence check that prints on every digest
  run. When a derivation has a clamp, check the unclamped branch somewhere the
  hash is not looking. **Since `scale` went to 1.0 (2026-09-09) the mask is
  gone** — 3600/12 = 300 s clears the floor, so the divisor now moves the derived
  value and the hash along with it. The lesson outlived the configuration that
  taught it, which is the usual way round: the check stays, because the next
  clamp will not announce itself either.
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
