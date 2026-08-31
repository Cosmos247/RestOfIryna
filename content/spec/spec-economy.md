# Content spec — Economy

**Status: approved 2026-09-01.** Phase 9, the last of five. The decisions are in
§7; §2 is the one that matters and it corrects an approved document.

Scope: levels 1–25, the authored band. Numbers are printed, never typed:

```
swift run roi-content spec economy
swift run -c release roi-content simulate     # for what a kill COSTS
```

---

## 1. Two currencies, and only one of them gates anything

Since Phase 8E removed Vigor regeneration, **Vigor is the constraint on play**:
the pool is a stock, food and the estate are the income, and how deep the
wilderness can be walked and walked out of is decided by how much of it a player
is carrying. **Silver gates nothing.** It buys convenience — materials the player
could have foraged, an enchant, a repair — and the mandatory ladders cost 1,600
silver in total across the entire game.

That asymmetry decides this document's shape. §2 and §3 are about Vigor, because
that is where the game is won or lost; §4 is about silver, where the question is
whether it has anything to do at all.

---

## 2. The opening is Vigor-bankrupt, and an approved spec said otherwise

`spec-progression.md` §3 justified levels 1–3 having no estate like this:

> *"XP there is tiny (about eleven kills to reach level 4), so it is hours, not days."*

**Eleven kills reaches level 2.** Reaching level 4 — the first plot slot, the
first Vigor income of any kind — takes the printed XP ladder and the shipped
boar, and both are unambiguous:

| step | XP needed | boars at 10 XP |
|---|---|---|
| 1 → 2 | 120 | 12 |
| 2 → 3 | 240 | 24 |
| 3 → 4 | 428 | 43 |
| **to reach 4** | **788** | **79** |

<!-- generated: roi-content spec economy -->
**The opening** — levels 1–3, the only stretch with no estate behind it

| | |
|---|---|
| XP to reach level 4 | 788 |
| `enemy.wild_boar` at level 1 | 10 XP → **79 kills** |
| starting Vigor pool | 105 |
| `enemy.wild_moose` at level 4, on curve | 223 XP — 22 boars |

The second row is the pure-boar path at km 1–3. The last is why it is
not the intended one: depth is the difficulty dial from the first hour.
<!-- /generated -->

At the ledger in §3 a boar costs ~16.8 Vigor and returns 8.4 as cooked meat, so
79 of them is **664 Vigor of deficit** against a starting pool of 105 and a
level-up grant of +5 a level. **The opening is short by roughly six pools**, and
the estate — the thing designed to pay for it — does not exist yet.

### The game does have an answer, and it should be stated rather than discovered

The boar is `trash` (XP ×0.4) and it is the only creature at km 1–3. The next
creature along is the moose, and since Phase 10 applied `spec-bestiary.md` §3 it
is **level 4, spawns from km 4, and is worth 223 XP — twenty-two boars.** (Before
the re-spread it was level 6 from km 6 at 418 XP, or forty-two boars: the
re-spread made the reward smaller and the walk to it shorter, which is the trade
it was chosen for.)

So the intended opening is not "grind the boar", it is **walk deeper than is
comfortable, early**. Depth is the difficulty dial and the player's hand is on it
from the first hour.

That is a good design. It is also completely unstated, it is the exact opposite
of what a new player will do, and the one document that discussed the opening got
its cost wrong by a factor of seven. Three things follow, and they are the
decisions in §7:

- **`spec-progression.md` §3 is amended** — the sentence is corrected and the
  reason levels 1–3 work is rewritten to name depth rather than to under-count.
- **The opening needs a measurement, not a sentence.** `roi-content simulate`
  reports pace from level 1 to 40 as an aggregate; it does not report whether the
  first three levels are survivable, which is the only stretch where the estate
  contributes nothing. That is a gap in the report, not in the game.
- **Nothing is retuned yet.** The cheapest fix is one number — the boar's meat
  chance from 0.70 to ~1.4 takes a kill to break-even — but retuning the opening
  before the report can measure it is guessing, and §6 puts it in order.

---

## 3. What a kill returns

<!-- generated: roi-content spec economy -->
**What a kill returns** — cooked meat is 12 Vigor a portion

| enemy | L | archetype | lootMult | meat | as Vigor | hide | as silver | hide ×mult |
|---|---|---|---|---|---|---|---|---|
| `enemy.wild_boar` | 1 | trash | ×0.5 | 0.70 | 8.4 | 0.80 | 2.4 | 0.40 |
| `enemy.wild_moose` | 4 | normal | ×1.0 | 1.60 | 19.2 | 0.70 | 2.1 | 0.70 |
| `enemy.wild_buffalo` | 7 | brute | ×1.7 | 1.60 | 19.2 | 0.90 | 2.7 | 1.53 |
| `enemy.rabid_lynx` | 10 | skirmisher | ×1.2 | 0.00 | 0.0 | 0.70 | 2.1 | 0.84 |
| `enemy.rabid_wolf` | 13 | normal | ×1.0 | 0.00 | 0.0 | 0.80 | 2.4 | 0.80 |
| `enemy.wild_bear` | 16 | brute | ×1.7 | 1.70 | 20.4 | 0.90 | 2.7 | 1.53 |
| `enemy.rabid_bear` | 22 | elite | ×3.0 | 0.00 | 0.0 | 1.80 | 5.4 | 5.40 |

`lootMult` does not apply today — no award site reads it, so `hide`
is what the table says regardless of archetype. `hide ×mult` is what
the same row would yield if the multiplier scaled QUANTITY, which is
the only factor that survives: scaling `chance` saturates at 1.0, and
rounding a quantity of 1 collapses ×0.5/×1.0/×1.2/×1.7 into 1 or 2.
<!-- /generated -->

Against a cost the simulator prints rather than this document asserting:

```
    class     vigor/kill  kills to 40  taps to 40   days on the estate alone  taps/day
    warrior     16.8          3925        47686       92.9                   513
    archer      16.2          3925        46057       89.7                   513
    mage        15.3          3925        43513       84.8                   513
    spread 9% — the plan asks for each class within ±7% of the mean
```

So: **clean game roughly pays for itself, Blighted game is a pure loss, and the
boar — the first creature anyone meets — is the worst deal in the table.** The
Blight starving the player as well as fighting them is the design working. The
boar running at −8.4 is not; it is §2.

**Past km 31 nothing edible spawns at all.** Only the rabid bear reaches that
deep in the approved roster, and foraging nets −0.5 Vigor per fresh room in every
zone, so the deepest third of the map is a pure Vigor sink that has to be entered
carrying everything it will cost. That is a legitimate design for a *deep* zone
and it is worth keeping — but it is currently true of km 31–49, which is where
the draft band lives and where content arrives after the rebalance.

---

## 4. Silver: a faucet with almost nothing to drain it

<!-- generated: roi-content spec economy -->
**Every ladder, priced at those buy prices** — the cost of skipping the grind entirely

| ladder | materials | direct silver |
|---|---|---|
| estate →T2 | 118 | 0 |
| estate →T3 | 390 | 0 |
| estate →T4 | 1260 | 50 |
| estate →T5 | 2560 | 150 |
| estate →T6 | 3630 | 400 |
| estate →T7 | 5100 | 1000 |
| bag, every step | 6090 | 0 |
| `gear.rusty_sword` T1→T5 | 1188 | 0 |
| `gear.simple_bow` T1→T5 | 1042 | 0 |
| `gear.wooden_staff` T1→T5 | 986 | 0 |
| **every row** | **23964** | |
| **one player** — a single weapon ladder | **21734–21936** | |

**The faucet** — one job per NPC per game day

| NPC | jobs | average silver |
|---|---|---|
| trader | 3 | 73 |
| master | 3 | 90 |
| tavern | 3 | 57 |
| **per day** | | **220** |
<!-- /generated -->

Put beside the pace: **220 silver a day over ~90 days is ~19,800 from quests
alone**, before a single hide is sold — and hides add roughly 2.4 silver a kill
across 3,925 kills. Against that, **the mandatory spend is 1,600 silver**, every
other silver cost in the game is optional, and the largest optional one is
enchanting at 1,660 an item.

**The trader is the economy's only real drain, and using it is a choice.** Buying
every material rather than gathering it costs ~21,900 — which is almost exactly
the faucet, and that is the sizing working. A player who forages instead ends the
game with roughly twenty thousand silver and nothing to spend it on.

Three specific things fall out of the printed tables:

**The spread is a flat −50% on every line.** Buy at 2×, sell at 1×, for every
item the trader handles. It is honest and legible; it is also completely
uniform, so no material is ever a better or worse thing to trade than any other,
and there is no reason to prefer selling one thing over another.

**The forge adds no silver value in either direction.** Ten iron costs 200 to
buy and one ingot costs 200; ten iron sells for 100 and one ingot sells for 100.
Smelting is therefore pure inventory compression — ten bag slots into one, which
against a 25-slot starting bag is real, but it is a storage mechanic wearing an
economy's clothes.

**The tavern has exactly a 0% house edge.** A win pays `wager × 2`, a tie refunds,
and two fair six-sided dice give 15/36 · 6/36 · 15/36 — so the expected value is
zero to the silver. It is a variance machine, not a sink. Whether that is right
is §7: a gambling table that takes nothing is a strange thing for an innkeeper to
run, but it is also the only place in the game where silver is *at risk*, which
has its own value when silver has so little else to do.

---

## 5. The `lootMultiplier`, wired to quantity

Every archetype declares one — trash 0.5 · normal 1.0 · skirmisher 1.2 · brute
1.7 · **elite 3.0** · **boss 8.0**. It is mapped into the domain and fingerprinted
by the content digest, and **no award site reads it**: both loot paths go through
`ExplorationService.rollLootDrops`, which rolls each table row's own chance and
nothing else.

**Decided: it is wired up, and it multiplies QUANTITY.** The archetype table is
already the contract for rounds, share of a bar, absorption, dodge, crit and XP;
loot is the one multiplier in it that silently does not apply, and an elite that
drops what a trash mob drops is the same defect as the `silverReward` that had no
curve. Three things make *quantity* the only workable factor:

- **Scaling `chance` saturates.** It is a probability; ×3.0 on anything above
  0.34 is clamped, and the boar's 0.8 hide would become 2.4, which is not a
  number a probability can be.
- **Scaling quantity is linear and unbounded**, which is what a reward multiplier
  wants to be.
- **But quantity is an `Int` and the multiplier is a `Double`**, and rounding
  destroys the very distinction it is there to make: at a base quantity of 1,
  ×0.5 · ×1.0 · ×1.2 · ×1.7 all round to 1 or 2 and the six archetypes collapse
  into two. **The fractional part becomes a probability, not a rounding** —
  `floor(q × m)` items, plus one more with probability `frac(q × m)`. Expected
  yield is then exactly `chance × quantity × lootMultiplier` at any base
  quantity, including 1, which is the base almost every shipped row uses.

### The consequence, which the table prints rather than hides

The `hide ×mult` column in §3 is what each row would yield once the multiplier
applies. Read the elite: **1.80 becomes 5.40**, because its loot table was
*already* hand-differentiated — somebody answered "an elite should drop more" by
writing 1.8 into the row. Wiring the archetype in on top applies that answer
twice.

So wiring it is not a one-line change at the award site. **The loot tables have
to be re-normalised to a base first**, exactly as the stat lines are being
re-normalised to the archetype contract: the row says what the creature drops,
the archetype says how much its rank multiplies that. Two answers to one question
is what the whole content pipeline exists to remove, and this is the last place
in the bestiary still holding both.

Which puts it, unambiguously, **in the same package as the bestiary
regeneration** — after the rebalance. Changing what a creature rewards before
changing what a creature *is* measures nothing.

## 6. The mine stopped being optional

`spec-bestiary.md` §7 reconciled the zones and moved foraged iron and clay from
km 3 to km 11. The estate T3 upgrade still wants **8 iron at player level 7**,
and the mine plot — which produces iron — opens at estate T2, player level 4.

So the chain is now: reach level 4, clear a plot, put a mine on it, and wait,
because the alternative is walking to km 11 at level 7 or buying iron at 20
silver a unit. That is a real change to how the first week plays, it was weighed
and accepted when the zones were reconciled, and it is recorded here as the
ledger entry it is rather than as a footnote there.

**It compounds with §2.** The opening already asks for 79 kills before the first
plot exists; the mine now sits behind that same gate, and iron is the first
material the estate ladder cannot do without. Whatever measurement §2 asks for
has to cover this too — they are the same first week.

---

## 7. Decisions (approved 2026-09-01)

**`spec-progression.md` §3 is amended.** "About eleven kills to reach level 4" is
wrong — eleven reaches level 2, and level 4 takes 79 boars and 664 Vigor of
deficit against a 105 pool. The correction goes in that document, along with the
actual reason the opening works: **the player is meant to walk deeper than is
comfortable**, where the moose pays 223 XP against the boar's 10 — twenty-two
boars for a four-kilometre walk.

**The opening gets a measurement before it gets a retune** — decided. `roi-content
simulate` reports pace as an aggregate over levels 1–40 and says nothing about
the only stretch with no estate behind it. The band to add: **can levels 1–3 be
completed, and at what depth**. Retuning first — the boar's meat chance from 0.70
to ~1.4 is the one-number fix — would be guessing at a number the report cannot
yet check.

**The `lootMultiplier` is wired up and multiplies QUANTITY, not chance** (§5) —
chance is a probability and saturates. The fractional part of `quantity ×
multiplier` becomes a probability rather than a rounding, because at a base
quantity of 1 rounding collapses four of the six archetypes together. It lands
with the bestiary regeneration, and **the loot tables are re-normalised to a base
in the same pass**: the elite's 1.80 hide is already a hand-written answer to
"elites drop more", and the multiplier would apply it a second time.

**The trader's uniform −50% spread, the value-free forge and the 0%-edge tavern
are recorded and left alone.** None of them is broken; all three are shapes
nobody chose, and each is a lever available when silver is given something to do.

**Silver is over-supplied and that is deferred.** Roughly 20,000 surplus over a
lifetime, against 1,600 of mandatory spend. The fix is more to buy, not less to
earn — which is items, which is after the rebalance.

---

## 8. What this spec does NOT cover

- What items exist to buy — `spec-items.md`, and there are no new ones.
- What a set is worth — `spec-sets.md`.
- The XP curve and the level gates themselves — `spec-progression.md`.
- Guild treasuries, market price discovery and Arena stakes as *systems*. They
  move silver between players; this document is about where it enters and leaves.
