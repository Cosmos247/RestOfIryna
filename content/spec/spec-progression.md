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
| Pace | 85–93 days of perfect play on a tended estate |

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
| `special_atk` | 8 | 17 |
| `special_def` | 11 | 20 |
| `super` | 14 | 21 |

**Estate** (`estate_upgrades.json`) — the plot slots are the daily Vigor budget

| tier | player level | plot slots | warehouse cap |
|---|---|---|---|
| T1 | start | 0 | 200 |
| T2 | 4 | 1 | 400 |
| T3 | 7 | 2 | 600 |
| T4 | 10 | 3 | 800 |
| T5 | 13 | 4 | 1200 |
| T6 | 16 | 5 | 1600 |
| T7 | 19 | 6 | 2000 |

**Bag** (`bags.json`) — gated on the ESTATE, not the player level

| tier | estate level | slots |
|---|---|---|
| T1 | start | 25 |
| T2 | T3 | 35 |
| T3 | T4 | 45 |
| T4 | T5 | 60 |
| T5 | T6 | 80 |
| T6 | T7 | 85 |
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
> nets −374 and km 4 nets +40, so walking deeper is not merely faster, it is what
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
learning the game: every technique gate (8 / 11 / 14, second uses at 17 / 20 /
21) and every estate tier (to T7 at level 19) lands inside it. Levels 26–40 stay
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
