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
| T1 | start | 1 | 200 | ×1 |
| T2 | 4 | 2 | 400 | ×1.1 |
| T3 | 7 | 3 | 600 | ×1.2 |
| T4 | 10 | 4 | 800 | ×1.3 |
| T5 | 13 | 5 | 1200 | ×1.4 |
| T6 | 16 | 6 | 1600 | ×1.5 |
| T7 | 19 | 7 | 2000 | ×1.6 |

Slot 1 is granted at every tier: `hazel` yields 1 `food.forest_nuts` an hour, holding 5 — never built, never counted as a plot the player built, planted ripe when the estate is named

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
>
> **Amended 2026-11-01 — §8.** Tier 1 has one slot now: the hazel's. Every estate starts
> with a plot of nuts in slot 1 that the player never chooses, so levels 1–3 have a small
> income at home — and still no plot of their own choosing. The slots column above counts
> the hazel's slot at every tier, and the line under the table names it.

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
the first plot leaves out `mat.clay` `mat.iron`; `hazel` is granted, never built, and N never counts it

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

> *Amended 2026-11-01.* The owner asked for the «📌 У нотатник»: it is built. The card's three
> buttons stand each on a row of their own — «✅ Будувати», «📌 У нотатник», «🔙 Назад». The note
> is the plot type and how many of it the estate will hold (`PlotService.noteKey`); the journal
> prices it as the player's NEXT plot, so building another type first keeps it and raises its
> price, and building the type ends it (auto-memory `project-recipe-notebook`). The line saying
> why the price grew is still not built. The plot screens now read «ємність» for «єм».

---

## 8. The hazel — the plot every estate starts with (2026-11-01)

**Status: APPROVED 2026-11-01** (the owner's «так» on the section as written) **and BUILT the
same day — not deployed.** The owner's idea and picks, written down before any of it reached
JSON. It needs code, content schema v30 and a migration, so it ships with a restart, never a
`/reload`. What the build measured is §8.8.

### 8.1 What was asked

The owner, 2026-11-01: a plot that opens together with the estate and that the player cannot
choose. It takes the first slot by itself, holds hazel bushes and yields forest nuts. It has two
jobs: to help the first explorations, and to show the plot loop before the player builds a plot
of their own.

Both jobs have a measured reason. Levels 1–3 have no estate at all (§3): tier 1 clears no land,
so the trail is the only income, and the `spec opening` block in `spec-economy.md` ends the
shallow opening short of Vigor (`opening.shallow_is_bankrupt`). The first plot a player can build
opens at estate tier 2, player level 4; until then nothing in the game shows what a plot does.

### 8.2 Decided 2026-11-01 (the owner)

One quiz, after a played sample of the screens a newcomer would see. The recommended option won
all three questions:

1. **The hazel is slot 1, and every other plot moves down one.** The alternative was a row of its
   own, unnumbered, above the slots: nothing would have been renumbered, but the hazel would have
   needed its own button, its own push and a new line at tier 1 in place of «Слотів зайнято: 0 / 0».
2. **It grows one nut an hour and holds five** — the five-hour fill every plot already has. The
   alternatives were holding three (a coop's day of Vigor), holding ten (a morning and an evening
   visit), and two an hour holding ten.
3. **It is ripe from the first minute, and the welcome says where it is.** The alternatives were
   growing from zero, so that the first «заповнена» push would teach it, and the chosen option
   plus a King's decree to harvest it. An insert into the chain moves every player's position
   (`king.md`), so that would have needed a migration of its own.

Settled in the same exchange, stated to the owner and not objected to:

4. **Every estate has one, including the estates that already exist,** and those find it ripe.
   An estate without it would have a free slot that a newer estate does not.
5. **No slot is taken from anyone.** Every tier gains one, so the number of slots a player builds
   on stays as it is. Giving one of today's slots to the hazel was not an option: those slots
   are built on, and nothing in the game removes a plot.
6. **It never counts as a plot the player built.** The price's N (§7.3) does not count it, and
   neither does `claim_plot` («Перша ділянка», level 4). For `harvest_plot` («Урожай») a harvest
   of nuts is a harvest like any other.

### 8.3 The rule

- **`hazel` is a plot type the estate grants.** `plots.json` marks it `"granted" : true`. It has
  no `buildCost`, the picker never offers it, and the claim refuses it, including a stale or
  forged `estate:plot:type:` / `estate:plot:build:` callback. Nothing removes or retypes it:
  `PlotService` gains a grant and still has no verb that deletes or changes a plot.
- **Slot index 0 is the hazel's.** `estate_upgrades.json` → `plotSlotsByTier` becomes 1 / 2 / 3
  / 4 / 5 / 6 / 7: the hazel's slot plus the 0 / 1 / 2 / 3 / 4 / 5 / 6 a player builds on, as
  today. The claim refuses slot 0 whatever stands there.
- **It is planted when the estate is named** (`completeRegistration`), and planted ripe:
  `lastHarvestedAt` is one full fill back (capacity ÷ rate intervals, read from the content, never
  typed), with `notifiedFull` set so the gift sends no push. The plot list plants it whenever slot
  0 is empty, idempotently, so a player never meets a «➕ Слот 1» that the claim refuses.
- **From its first harvest it lives like every plot.** It grows, fills, sends «🌳 Ліщина (слот 1)
  заповнена», and is harvested into the bag or the warehouse under the same caps. Like every plot
  it reads the tier-1 row, so it does not grow with the estate.
- **It yields `food.forest_nuts`**, one stream with no bonus. The nut (5 Vigor raw), its price at
  the trader and every recipe that uses it are untouched.
- **N counts the plots the player built** (§7.3, amended by this section). The hazel never makes a
  plot dearer, and `build.multiplierByPlotNumber` still prices the six a player can build.
- **`claim_plot` without a `plotType` counts built plots.** A decree that names a type counts that
  type. `harvest_plot` counts every harvest, nuts included.
- **The estates that exist get it from one migration, in one transaction:**
  - Every plot's `slot_index` moves up by one. That takes two statements — up by a large offset,
    then back down to +1 — because `unique(user_id, slot_index)` is checked row by row as a row
    moves.
  - Every account past registration then gets a ripe hazel in slot 0. An account still
    registering is planted when it finishes.
  - Before the migration is written, read the plot counts off the Pi. Before the restart,
    rehearse it on a scratch Postgres (auto-memory `reference-deploy-rehearsal`).
  - A stale «Слот 1» button left in a chat will then open the hazel. That is harmless: it can
    only show or harvest the player's own plot.

### 8.4 The copy

Drafts in «ви»; the owner may still change any of them.

| key | uk | en |
|---|---|---|
| `plot.type.hazel.name` | Ліщина | Hazel |
| `plot.type.hazel.desc` | Кущі ліщини, що росли тут задовго до вас. Садити їх не треба — лише не забувайте збирати горіхи. | Hazel bushes that grew here long before you. There is nothing to plant — just remember to gather the nuts. |
| `plot.type.hazel.gender` | f | — |
| `registration.hazel` | Біля хати ростуть кущі ліщини, і горіхи вже стиглі. Зберіть їх: %{estate} → %{plot}. | Hazel bushes grow by the hut, and the nuts are already ripe. Gather them: %{estate} → %{plot}. |

- `registration.hazel` closes the welcome message (`registration.complete`), on a line of its
  own behind a 🌳 added in Swift (the house rule for a leading emoji).
- `%{estate}` and `%{plot}` are the buttons' own labels (`commands.estate`, `estate.plot`),
  interpolated, so the line cannot drift from the buttons it names.
- The plot's icon is 🌳 (`plots.json`); the nut keeps its 🌰.
- Everything else the hazel shows is the plots' shared copy — the list row, the card, the
  harvest banner and the ready push — agreeing with «Ліщина» as feminine: «заповнена».

### 8.5 What it gives

At the decided numbers:

- **A harvest** is five nuts, 25 Vigor.
- **A day** at the three harvests `simulate` assumes is fifteen nuts, 75 Vigor.
- **The ceiling** is one nut an hour: 24 nuts and 120 Vigor a day, for a player who comes back
  every five hours.

Against `simulate`'s estate table as read on 2026-11-01, before the change (Vigor a day, three
harvests):

- **Tier 1** goes from nothing to the hazel's 75.
- **Tier 2** feeds 45 from its one built plot (a coop, the model's best), so the hazel more than
  doubles its day, to 120.
- **From tier 3 on** the hazel is a small share: 300 → 375 at tier 3, 1200 → 1275 at tier 7.

Three things it touches:

- **The innkeeper's job** «Закуска до пива» (`tavern.nuts`, 6 nuts, from level 1) can be paid
  from the hazel.
- **At tier 2 the free hazel feeds more Vigor than the coop a player paid for.** A harvest is
  worth a third of the coop's at the trader (5 nuts against 5 eggs), and its nuts cook into
  nothing the plots alone can make: every nut recipe also needs meat or berries.
- **Selling the nuts is a small new faucet**: one silver a nut.

### 8.6 What moves when it is authored

- **`simulate`.**
  - `FoodBudget` takes the hazel as one fixed plot on top of the built ones. It must never
    enumerate it as a choice: an estate of seven hazels is not one anybody can have.
  - Tier 1's row is fed, so `pace.levels_without_an_estate` stops firing for all three classes.
    Levels 1–3 enter the pace, and every later tier gains the hazel's day.
  - The days to level 40 shorten. Re-measure with `simulate --strict` and record them.
  - Watch `pace.food_taps_dominate`: the hazel adds fifteen raw portions a day.
- **The opening** (`OpeningLedger`, the `spec opening` block in `spec-economy.md`).
  - It prices levels 1–3 per kill and cannot price an income that arrives by the hour, so it
    stays the trail-only floor.
  - Its text stops saying the stretch has no estate and names the hazel as an exclusion beside
    silver.
  - `opening.shallow_is_bankrupt` keeps firing: it is about how deep a newcomer walks, not about
    food at home.
- **`spec gates`.**
  - The estate table's slots read 1…7: refresh this spec's §3 block and the excerpt in
    `spec-bestiary.md` §11.2.
  - The plots table leaves the hazel out of the build prices.
  - A new line names the granted plot with what it produces, so the decided rate and capacity
    are printed rather than typed here.
- **The validator** gains these errors:
  - more than one granted type;
  - a granted type that produces nothing or has a `buildCost` (`plot.build_cost_missing`
    exempts it);
  - tier 1 with fewer slots than there are granted types.

  `plot.build_multiplier_short` measures the largest slot count less the granted.
- **The digest.** `records` hashes the granted flag beside the plot rows it already replays, and
  the content hash moves (auto-memory `feedback-digest-names-constants`).
- **Content schema v30.**
  - The binary and `content/data` ship together.
  - A rollback after the migration is not safe. An older binary cannot read the hazel's rows, so
    its list would draw slot 1 as free and its claim would refuse it — and with its own slot table
    (0…6) it would not draw the highest built plot at all. Roll forward; a rollback needs
    `PlantHazel.revert`'s two steps (delete the hazels, move every plot back up) done by hand
    first, since nothing wires the revert to a command.
- **The tests:**
  - the price's N ignores the hazel;
  - the picker and the claim refuse it;
  - `FoodBudget` adds it exactly once;
  - each new validator rule fires on a broken bundle.
- **The records.**
  - `CLAUDE.md` gets the rule: granted, never chosen, never counted as built, slot 0 reserved,
    planted at registration.
  - `king.md` gets a line on `claim_plot`.
  - `spec-economy.md` gets a dated note on the opening and the faucet.
  - README, `.memory/` and a walk block in `TODO.md` follow, as for every change.

### 8.7 Left as it is

- The hazel does not grow with the estate. It has no upgrade, no second stream and no decree of
  its own.
- The nut's price, `tavern.nuts` and every recipe with nuts are untouched.

### 8.8 What moved (measured 2026-11-01, the build)

- **`simulate --strict`**: 0 broken bands, **15 warnings** (was 18) — the three
  `pace.levels_without_an_estate` are gone and nothing new fires; `pace.food_taps_dominate`
  stays quiet. The estate's day (three harvests): T1 75 · T2 120 · T3 375 · T4 675 · T5 975 ·
  T6 1065 · T7 1275, the hazel in every mix and never twice. **The pace to level 40 is 136–151
  days** (warrior 151.1 / archer 144.3 / mage 136.4; was 167.0 / 159.6 / 150.9), the spread
  still 10%, taps a day ~801 (was ~711). Inside the 72–200 band.
- **The spec blocks**: §3's and §7.3's `spec gates` blocks here, the estate excerpt in
  `spec-bestiary.md` §11.2, and in `spec-economy.md` the opening's heading in both the
  `spec economy` and `spec opening` blocks. The `plots, 6 × …` rows and every other table held.
- **The digest**: only `records` (207c959cf4807072 → 4f4dcf860af8605f) and the content hash
  (1ac5a7bc → 95421568) moved; `tuning`, `spawns`, `quests` and `king` held.
- **The tests**: nine new; each was mutation-checked by breaking the rule it guards — N counting
  the hazel, `FoodBudget` choosing it, the price exemption, the tier-1 slot, the decree rule, the
  three granted-plot rules, the ripe clock's rounding and the shipped pick (the last three in the
  pre-commit audit).
- **The migration, rehearsed** on a scratch Postgres 15 with synthetic estates (neighbouring
  slots, a gap, a full T7, an account mid-registration): every plot one slot down, a ripe hazel
  for each registered account and none mid-registration, a second boot changing nothing, and the
  real services checked on the result (the price's N, the reserved slot, the refused type,
  `claim_plot`). It caught one defect before it shipped: the first version decoded whole accounts
  and would have stopped the boot on a row missing a column the model requires; it reads the
  ids alone now.
