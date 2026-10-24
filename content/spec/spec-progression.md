# Content spec — Progression

**Status: approved 2026-08-31.** Phase 9 of the pre-release rebalance. The three
decisions this document was written to force are in §5; the rest is the skeleton
the other four specs hang from.

This is the skeleton the other four specs hang from — how long a life is, what a
level costs, what each one unlocks, and where in the world a player of that level
belongs. The bestiary fills the bands, the item spec fills the slots, the economy
spec prices both.

**Every number below is PRINTED by the code that owns it**, not typed here:

```
swift run roi-content spec progression     # the XP ladder and the stat line
swift run roi-content spec gates           # techniques, estate, bag
```

Re-run either after touching `tuning/progression.json`, `tuning/combat.json`,
`estate_upgrades.json` or `bags.json`, and paste the result back. A spec that
quotes numbers by hand is a fourth copy of the same curves and starts rotting the
moment a coefficient moves.

---

## 1. What is already decided

These came out of Phases 5–8 and are **not** open here. They are restated because
the rest of the document leans on them.

| | |
|---|---|
| Level cap | **40** |
| XP curve | `xpToNext(L) = max(round(11.4 · L^3.30), 120 · L)` |
| Mob XP | `mobXP(L) = 26 · L^1.55 × archetype.xpMultiplier`, scaled by the level gap |
| Stat growth | proportional every level: HP ×(1+0.056·(L−1)), ATK ×(1+0.100·(L−1)), ratings ×(1+0.085·(L−1)) |
| Vigor pool | `100 + 5L`, and it does **not** regenerate (Phase 8E) — food is the only income |
| Death | the whole unequipped backpack, unchanged |
| Pace | 78–87 days of perfect play on a tended estate |

> *Amended 2026-10-02.* Mob XP is no longer scaled by the level gap: `xpLevelDiff.perLevel`
> is 0, so a kill pays its full reward at any player level, and the archetype multiplier
> is 1.0 for every archetype, so XP depends on the creature's number alone
> (`spec-bestiary.md` §10.2, §10.4). The table above is the state this spec was approved
> in.

---

## 2. The ladder

<!-- generated: roi-content spec progression -->
| L | XP to next | cumulative | % of the climb | max Vigor | warrior HP/ATK/DEF | archer HP/ATK/DEF | mage HP/ATK/DEF |
|---|---|---|---|---|---|---|---|
| 1 | 120 | 0 | 0.0% | 105 | 120/12/12 | 90/14/8 | 80/15/6 |
| 2 | 240 | 120 | 0.0% | 110 | 127/13/13 | 95/15/9 | 84/17/7 |
| 3 | 428 | 360 | 0.0% | 115 | 133/14/14 | 100/17/9 | 89/18/7 |
| 4 | 1,106 | 788 | 0.0% | 120 | 140/16/15 | 105/18/10 | 93/20/8 |
| 5 | 2,309 | 1,894 | 0.0% | 125 | 147/17/16 | 110/20/11 | 98/21/8 |
| 6 | 4,215 | 4,203 | 0.0% | 130 | 154/18/17 | 115/21/11 | 102/23/9 |
| 7 | 7,010 | 8,418 | 0.0% | 135 | 160/19/18 | 120/22/12 | 107/24/9 |
| 8 | 10,892 | 15,428 | 0.1% | 140 | 167/20/19 | 125/24/13 | 111/26/10 |
| 9 | 16,066 | 26,320 | 0.1% | 145 | 174/22/20 | 130/25/13 | 116/27/10 |
| 10 | 22,746 | 42,386 | 0.2% | 150 | 180/23/21 | 135/27/14 | 120/29/11 |
| 11 | 31,153 | 65,132 | 0.3% | 155 | 187/24/22 | 140/28/15 | 125/30/11 |
| 12 | 41,515 | 96,285 | 0.5% | 160 | 194/25/23 | 145/29/15 | 129/32/12 |
| 13 | 54,065 | 137,800 | 0.7% | 165 | 201/26/24 | 150/31/16 | 134/33/12 |
| 14 | 69,044 | 191,865 | 1.0% | 170 | 207/28/25 | 156/32/17 | 138/35/13 |
| 15 | 86,697 | 260,909 | 1.3% | 175 | 214/29/26 | 161/34/18 | 143/36/13 |
| 20 | 224,029 | 933,297 | 4.8% | 200 | 248/35/31 | 186/41/21 | 165/44/16 |
| 25 | 467,850 | 2,491,517 | 12.8% | 225 | 281/41/36 | 211/48/24 | 188/51/18 |
| 30 | 853,896 | 5,538,529 | 28.5% | 250 | 315/47/42 | 236/55/28 | 210/59/21 |
| 35 | 1,420,134 | 10,860,559 | 55.9% | 275 | 348/53/47 | 261/62/31 | 232/66/23 |
| 40 | — | 19,437,688 | 100.0% | 300 | 382/59/52 | 287/69/35 | 255/74/26 |

Total to the cap: **19,437,688 XP**.
<!-- /generated -->

**The shape of that table is the first thing to look at.** Levels 1–15 — the band
the plan says to author in full — are **1.3% of the whole climb**. Levels 30–40
are 71.5% of it. The authored content therefore covers the part every player
sees and almost none of the time they spend; the generated draft above 15 carries
the rest. That is not an argument against authoring 1–15 first. It is an argument
for being honest that "levels 16–40 generated as a draft" means *most of the
game*, and for revisiting them before anyone reaches them rather than after.

---

## 3. What each level unlocks

<!-- generated: roi-content spec gates -->
**Techniques** (`tuning/combat.json` → `techniques`)

| technique | unlocks at | second use at |
|---|---|---|
| `special_atk` | 10 | 17 |
| `special_def` | 11 | 20 |
| `super` | 14 | 21 |

**Training Ground** (`training_ground.json`) — a room of the house, one technique per level

| level | teaches | player level | silver | materials |
|---|---|---|---|---|
| 1 | `special_atk` | 10 | 150 | 30× `mat.pine_lumber` 20× `mat.river_pebble` 5× `mat.hide` |
| 2 | `special_def` | 11 | 400 | 40× `mat.pine_lumber` 30× `mat.river_pebble` 10× `mat.iron` 8× `mat.hide` |
| 3 | `super` | 14 | 800 | 60× `mat.pine_lumber` 40× `mat.river_pebble` 15× `mat.iron` 3× `mat.iron_ingot` 10× `mat.hide` |

**Estate** (`estate_upgrades.json`) — the plot slots are the daily Vigor budget;
the creatures column is the forest's HP and ATK at that tier (`tuning/combat.json`
→ `estateScaling`, `spec-bestiary.md` §11)

| tier | player level | plot slots | warehouse cap | creatures |
|---|---|---|---|---|
| T1 | start | 0 | 200 | ×1 |
| T2 | 4 | 1 | 400 | ×1.1 |
| T3 | 7 | 2 | 600 | ×1.2 |
| T4 | 10 | 3 | 800 | ×1.3 |
| T5 | 13 | 4 | 1200 | ×1.4 |
| T6 | 16 | 5 | 1600 | ×1.5 |
| T7 | 19 | 6 | 2000 | ×1.6 |

**Bag** (`bags.json`) — gated on the ESTATE, not the player level

| tier | estate level | slots |
|---|---|---|
| T1 | start | 25 |
| T2 | T3 | 35 |
| T3 | T4 | 45 |
| T4 | T5 | 60 |
| T5 | T6 | 75 |
| T6 | T7 | 90 |

**Weapon** (`weapon_upgrades.json`) — gated on the PLAYER level (`spec-items.md` §9);
the first reforge is the Master's lesson, the rest the workshop's

| tier | player level | where | `gear.rusty_sword` ⚔️/💥/🎯 | `gear.simple_bow` ⚔️/💥/🎯 | `gear.wooden_staff` ⚔️/💥/🎯 | durability |
|---|---|---|---|---|---|---|
| t1 | 1 | starter | 7 / 3 / 3 | 6 / 3 / 3 | 7 / 5 / 1 | 30 |
| t2 | 5 | the Master's lesson | 11 / 5 / 5 | 10 / 5 / 5 | 11 / 8 / 2 | 40 |
| t3 | 10 | workshop | 16 / 8 / 6 | 14 / 8 / 8 | 16 / 13 / 3 | 50 |
| t4 | 15 | workshop | 21 / 10 / 8 | 20 / 11 / 11 | 21 / 17 / 3 | 70 |
| t5 | 20 | workshop | 27 / 12 / 10 | 24 / 13 / 13 | 26 / 21 / 4 | 100 |
| t6 | 25 | workshop | 32 / 14 / 12 | 29 / 16 / 16 | 31 / 25 / 5 | 120 |
| t7 | 30 | workshop | 36 / 17 / 14 | 33 / 18 / 18 | 36 / 29 / 6 | 140 |
| t8 | 35 | workshop | 42 / 20 / 16 | 38 / 21 / 21 | 41 / 34 / 7 | 160 |
| t9 | 40 | workshop | 47 / 22 / 17 | 43 / 23 / 23 | 45 / 37 / 8 | 180 |
<!-- /generated -->

Three things are worth noticing in that table before approving it.

**Levels 1–3 have no estate at all** — tier 1 clears no land, and the first plot
opens at tier 2, player level 4. Decided in Phase 8E and kept deliberately: with
no Vigor regeneration the first days are lived off the trail, which is what gives
the estate a reason to exist.

> **Amended 2026-09-01 by `spec-economy.md` §2.** This paragraph used to end
> *"XP there is tiny (about eleven kills to reach level 4), so it is hours, not
> days."* **Eleven kills reaches level 2.** Level 4 is 788 XP — 120 + 240 + 428
> off the table above — which at the shipped boar's 10 XP is **79 kills**, and at
> ~16.8 Vigor a kill against 8.4 returned as meat is **664 Vigor of deficit
> against a 105 pool**. The opening is not short; it is short by six pools.
>
> **Why it works anyway, which is the part that was never written down:** the
> boar is `trash` (XP ×0.4) and it is the only creature at km 1–3, but the next
> creature along pays for the walk many times over — the shipped moose is level 6
> from km 6 and worth **418 XP, forty-two boars** (223 XP and twenty-one boars
> once `spec-bestiary.md` §3's re-spread lands). The intended opening is **to walk
> deeper than is comfortable**, immediately. Depth is the difficulty dial from the first hour,
> not from the first plot. `spec-economy.md` §7 asks for a simulate band that
> measures this stretch before anyone retunes it.
>
> **Amended again 2026-09-02, by the band §7 asked for.** Two things above are
> now stale. (a) *"the shipped moose is level 6 from km 6 worth 418 XP"* — the
> re-spread landed in Phase 10, so the moose **is** level 4 from km 4 at 223 XP,
> and the parenthetical is the shipped truth rather than the pending one.
> (b) The **664 Vigor of deficit is 374**, and the 79 kills are **92.2**: that
> ledger credited the boar with cooked meat across a stretch where the kitchen is
> locked (it is an estate room, opening at the level this stretch ENDS at) and
> counted no foraging, while 79 is the flat 788 ÷ 10 before the level-gap scaler.
> The conclusion this paragraph draws is **strengthened, not weakened** — km 1
> nets −335 and km 4 nets +44, so walking deeper is not merely faster, it is what
> makes the opening solvent at all. Measured table in `spec-economy.md` §2,
> printed by `roi-content spec opening`.

**The bag is gated on the ESTATE, not on the player.** Bag T2 needs estate T3,
which needs player level 7 — so a player carries 25 slots for the first seven
levels. That chain is intentional (the estate is the spine of progression) but it
is stated here because nothing else says it out loud.

**The second-use gates cluster at the top.** Special attack unlocks at 8 and
doubles at 17; defence at 11 and doubles at 20; the Super at 14 and doubles at
21. Levels 17–21 hand out three upgrades in five levels and then nothing for
nineteen. See the open questions below.

---

## 4. Where a level belongs in the world

The wilderness is measured in kilometres of depth, and the shipped roster already
implies a rule that has never been written down:

> **An enemy of level N spawns from km N to km N+9.**

> *Superseded 2026-10-02 by `spec-bestiary.md` §10.* A creature's number is its rung on
> the depth ladder, not a player level, and its band is km 3N−3…3N+1. The last
> creature's band is stretched to the horizon at km 49. Everything below in this section
> is the rule as approved and as it shipped until then.

Every shipped band obeys it — as of Phase 10, boar L1 at km 1–10, moose L4 at km
4–13, bison L7 at km 7–16, lynx L10 at km 10–19, wolf L13 at km 13–22, bear L16
at km 16–25 — with the one elite (L22, km 22–**40**) stretched wider because
nothing else lives out there. That stretch is not decoration: applying the plain
rule to it opens a nine-kilometre hole at km 32–40 where exploration rolls no
encounter, and the validator refuses the bundle (`enemy.depth_gap`). It closes
when something is authored to live past km 31, and not before.

Read from the player's side it says: **at km K you meet levels K−9 through K**.
So a player is level-matched at the shallow edge of a band and progressively
out-levelled the deeper they walk, which is exactly the risk curve the design
wants — depth is the difficulty dial, and it is the player's hand on it.

Two consequences worth approving explicitly:

- **The elite floor of level 14 becomes a place**: elites cannot appear before km
  14. That is the spatial meaning of the rule Phase 8D put in the validator.
- **The wilderness has a content horizon at km 49**, and it is `maxLevel + 9` by
  the rule above: a level-40 enemy spawns to km 49, so nothing can live deeper
  until the cap moves. **Decided:** the deep foraging band was extended from km
  40 to 49 to match, so the trail keeps feeding a player out to the horizon
  instead of going silent at km 40 while enemies still spawn. Content for km
  26–49 arrives after the rebalance; the band is already there to hold it.
  The change is provably inert for everything shipped today — the digest's
  forage replay walks km 1–40 and did not move.

The lore's three zones (`content/lore.md` §7: shallow 1–10, medium 10–20, deep
20–35) and the foraging bands shipped in `zones.json` (1–2, 3–5, 6–40) **do not
agree with each other or with the enemy bands.** The foraging split is the oldest
of the three. Reconciling them is the bestiary spec's job; this document only
fixes the level↔km rule they must all obey.

---

## 5. Decisions (approved 2026-08-31)

**The authored band is levels 1–25**, not the plan's 1–15. That is 12.8% of the
climb rather than 1.3%, and it covers the whole period in which a player is still
learning the game: every technique gate (10 / 11 / 14 — bought as levels of the
Training Ground since 2026-09-27, the first one moved from 8 with the room's T4
gate — second uses at 17 / 20 / 21) and every estate tier (to T7 at level 19) lands inside it. Levels 26–40 stay
a generated draft from the same curves. `spec-bestiary.md`, `spec-items.md` and
`spec-sets.md` all author to 25.

**Nothing new unlocks between 21 and 40, and that is deliberate for now.** The
hole is real — 78% of the XP with only stat growth and gear in it — but the game
is going into testing before it goes into anyone's hands, and what fills that
band is better decided after the rebalance has been played than guessed at now.
Recorded here so it is a decision with a reason rather than an oversight nobody
noticed: **the second-use gates stay at 17 / 20 / 21 and the ladders stay where
they are.**

**Past km 40 the deep zone continues** rather than ending in a wall. Applied
above: `zones.json` → `zone.deepwood` now covers km 6–49, the horizon the
level↔km rule implies. Later content goes there.

## 6. What this spec does NOT cover

- Which creatures live in which band — `spec-bestiary.md`.
- What drops, and what it is worth — `spec-items.md`, `spec-economy.md`.
- Set bonuses and their sources — `spec-sets.md`.
- Levels 26–40 as authored content. They are a generated draft by decision, and
  the band above is where that decision was taken.

---

## 7. What a plot costs (2026-10-24)

### 7.1 What was asked

Players asked for a plot to cost resources. Until then building one was free: pick a type,
read the card, «✅ Будувати». A plot can never be rebuilt or changed (the card says so), so
the price is paid once for the life of the account.

### 7.2 Decided 2026-10-24 (the owner)

1. **The first proposal was sent back.** It gave every type the same frame of 10 🪵 + 10 🪨
   plus one item of its own (3 🥔 · 3 🥚 · 1 🔩 · 1 🔩); the owner asked for something more
   varied, with clay and iron in it.
2. **Every type has a recipe of its own, four materials each** — of two diversified sets, the
   fuller (the leaner had three each). The farm is the only one without clay, the coop the only
   one without iron, and pebbles and hides — the materials warehouses hold most of — are asked
   for too:
   - farm — a fence 🪵, a harness 🟫, a ploughshare 🔩, seed potatoes 🥔;
   - coop — a frame 🪵, a floor 🪨, clay-daubed walls 🧱, eggs to hatch 🥚;
   - sawmill (`forest`) — the saw frame and its wheel 🪵, a foundation 🪨, the saws 🔩, a dam 🧱;
   - mine — pit props 🪵, bellows 🟫, picks 🔩, a forge 🧱.
3. **The player's Nth plot costs N recipes, and the first leaves out clay and iron** — over
   ×N with clay and iron from the first plot, and over one price for all six. Without the
   exception the first mine would have cost more than the estate step that opens its slot.

### 7.3 The rule

- **N counts the plot being built**: the player's plots plus one, never the slot index — a
  slot can be claimed out of order, and the price is about how much land the estate already
  works.
- The Nth plot pays its type's `buildCost` × `build.multiplierByPlotNumber[N − 1]`; past the
  table the last multiplier holds. The first plot leaves out `build.firstPlotLeavesOut`.
- It is drawn from the bag first and the warehouse for the rest, the estate's policy, and paid
  in one transaction with the plot row: a plot that cannot be rebuilt is paid in full or not
  built at all.
- **The plots built before the rule stay as they are.** Nobody is charged for them.

<!-- generated: roi-content spec gates -->
**Plots** (`plots.json`) — the player's Nth plot costs its type's recipe × N's multiplier;
the first plot leaves out `mat.clay` `mat.iron`

| plot | × | `farm` | `forest` | `mine` | `coop` |
|---|---|---|---|---|---|
| 1 | 1 | 10🪵 2🟫 3🥔 | 8🪵 10🪨 | 12🪵 3🟫 | 8🪵 5🪨 3🥚 |
| 2 | 2 | 20🪵 4🟫 2🔩 6🥔 | 16🪵 20🪨 4🔩 2🧱 | 24🪵 6🟫 4🔩 2🧱 | 16🪵 10🪨 2🧱 6🥚 |
| 3 | 3 | 30🪵 6🟫 3🔩 9🥔 | 24🪵 30🪨 6🔩 3🧱 | 36🪵 9🟫 6🔩 3🧱 | 24🪵 15🪨 3🧱 9🥚 |
| 4 | 4 | 40🪵 8🟫 4🔩 12🥔 | 32🪵 40🪨 8🔩 4🧱 | 48🪵 12🟫 8🔩 4🧱 | 32🪵 20🪨 4🧱 12🥚 |
| 5 | 5 | 50🪵 10🟫 5🔩 15🥔 | 40🪵 50🪨 10🔩 5🧱 | 60🪵 15🟫 10🔩 5🧱 | 40🪵 25🪨 5🧱 15🥚 |
| 6 | 6 | 60🪵 12🟫 6🔩 18🥔 | 48🪵 60🪨 12🔩 6🧱 | 72🪵 18🟫 12🔩 6🧱 | 48🪵 30🪨 6🧱 18🥚 |

🪵 `mat.pine_lumber` · 🟫 `mat.hide` · 🔩 `mat.iron` · 🥔 `food.potato` · 🪨 `mat.river_pebble` · 🧱 `mat.clay` · 🥚 `food.duck_egg`
<!-- /generated -->

### 7.4 What it costs

At the trader's buy prices a player's first plot costs 52–70 (sawmill, coop, mine, farm)
against the 118 of the estate step that opens its slot; the sixth costs 504 (coop) to 780
(mine). Six plots of one type are the `plots, 6 × …` rows of `spec-economy.md` §4, and a full
estate of them is what moved its `one player` row. Clay is the material to watch: a passive
day forages under one, the trader sells it at 24, and a full estate of plots asks for up to
twenty — none for a farm — on top of the seventy the estate's own steps from T4 to T7 take.

### 7.5 What checks it

- **The validator**, every rule an error but one: `plot.build_cost_missing`,
  `plot.build_rule_missing`, `reference.item.unknown`, `plot.build_cost_unobtainable`,
  `ladder.quantity`, `plot.build_cost_duplicate`, `plot.build_multiplier_short`,
  `plot.build_multiplier_non_positive`, `plot.build_multiplier_drops`,
  `plot.build_first_plot_free`, and the warning `plot.build_leaves_out_nothing`.
- **The tests**: `PlotBuildCostTests` pins the rule and the owner's pick on the shipped bundle
  (mutation-tested: a farm given clay, a first plot that leaves out nothing and a resolver
  that leaves clay and iron out of every plot each fail it); `EstateAndNPCCatalogTests` makes every rule fire.
- **The digest**: `records` replays `PlotCatalog.buildCost` for every type at plot numbers
  −1…8.
- **Content schema v26**: both fields decode as optional, so only the handshake keeps the
  bundle off a binary that would hand out free plots.

### 7.6 Where it lives

`PlotBuildCost` (`Modules/ROIContent`) is the one reading of the rule, for the build card,
`PlotService.claim`, the validator and `roi-content spec`. The card asks
`PlotService.buildCost(of:for:on:)` and `CraftingService.stock` — the two readings the claim
pays from — and lists the materials under «📜 Матеріали» through `RequirementLine`; a refused
«✅ Будувати» answers with the shortage modal and redraws the card under it. Not built: a
«📌 У нотатник» on the build card, and a line on the card saying why the price grew — the
approved sample had neither.
