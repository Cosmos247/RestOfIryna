# Content spec — Economy

**Status: approved 2026-09-01.** Phase 9, the last of five. The decisions are in
§7; §2 is the one that matters and it corrects an approved document.

Scope: levels 1–25, the authored band. Numbers are printed, never typed:

```
swift run roi-content spec economy
swift run -c release roi-content spec opening # §2's amendment — it rolls fights
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

> **AMENDED 2026-09-02, and the title is now half wrong.** The measurement this
> section asked for exists, and it says the opening is not bankrupt — **the
> SHALLOW opening is.** Everything down to "The game does have an answer" is the
> approved text and is kept as written; the measured answer is at the end of the
> section under *Measured*. Two numbers below are superseded there.

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

> *Superseded by the measurement below: **374**, not 664, and **92.2** kills, not
> 79. Both were hand-computed here. The deficit was overstated because the boar
> is credited with 8.4 Vigor of cooked meat across a stretch where the kitchen is
> locked, and because foraging was not counted at all; the kill count was
> understated because a level-3 player earns 8 XP from a level-1 boar, not 10.
> The two errors ran in opposite directions, which is why neither showed.*

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

### Measured (2026-09-02) — and it is the shallow opening that is bankrupt

`OpeningLedger` prices this stretch at every depth against the trail, because
before the estate exists the trail is the whole income. It rolls the same
`FightSimulator` the balance report rolls, so `roi-content spec opening` and
`simulate`'s own opening section are the same numbers in two formats.

<!-- generated: roi-content spec opening -->
**The opening** — levels 1–3, the only stretch with no estate behind it

788 XP to reach level 4 against a stock of 115 Vigor — the starting pool plus
every level-up grant, with a kill costing 2.5 rooms of walking plus the fight.
`trail` is what the walk feeds you: foraged food, plus anything a kill drops
edible AS FOUND. A kill's raw meat is not that — every recipe for it is a
kitchen recipe, and the kitchen is a room of the estate this stretch ends by
unlocking — `if cooked` is the size of what that gate holds back. Silver is
never spent here either, so every row is a floor and not an estimate.

| km | mob levels | XP/kill | vigor/kill | win | kills | trail | spent | walk in | **net** | if cooked |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 | 1 | 8.5 | 9.1 | 100% | 92.2 | 350 | 837 | 2 | **-374** | +400 |
| 4 | 1,4 | 89.0 | 11.4 | 100% | 8.9 | 34 | 101 | 8 | **+40** | +150 |
| 7 | 1,4,7 | 213.2 | 13.6 | 97% | 3.7 | 14 | 50 | 14 | **+65** | +114 |
| 10 | 1,4,7,10 | 388.4 | 14.9 | 95% | 2.0 | 8 | 30 | 20 | **+72** | +95 |
| 11 | 4,7,10 | 692.3 | 19.6 | 91% | 1.1 | 4 | 22 | 22 | **+75** | +90 |
| 13 | 4,7,10,13 | 917.0 | 23.2 | 66% | 0.9 | 3 | 20 | 26 | **+72** | +80 |
| 14 | 7,10,13 | 1250.1 | 27.0 | 50% | 0.6 | 2 | 17 | 28 | **+72** | +75 |
| 16 | 7,10,13,16 | 1647.1 | 26.2 | 41% | 0.5 | 2 | 13 | 32 | **+72** | +75 |
| 17 | 10,13,16 | 1774.9 | 25.9 | 34% | 0.4 | 2 | 12 | 34 | **+71** | +73 |
| 20 | 13,16 | 2045.9 | 28.1 | 9% | 0.4 | 1 | 11 | 40 | **+66** | +68 |
| 22 | 13,16,22 | 2731.8 | 27.0 | 9% | 0.3 | 1 | 8 | 44 | **+64** | +66 |
| 23 | 16,22 | 5180.6 | 20.5 | 0% | 0.2 | 1 | 3 | 46 | **+66** | +69 |
| 26 | 22 | 10020.0 | 15.7 | 0% | 0.1 | 0 | 1 | 52 | **+62** | +62 |

Cheapest depth a player can actually HOLD (win ≥ 95%): **km 10**, at +72 Vigor.
<!-- /generated -->

**The answer to "at what depth" is: four kilometres further than a new player
will walk.** Four kilometres of walking is worth more than the entire deficit,
and the flip lands at km 4 — the first depth where anything but the boar spawns.
Depth then has a measured **optimum** rather than an open ceiling: Vigor stops
being the binding constraint at about km 4, and at about km 11 survival takes
over (95% win at km 10, 66% at km 13, 9% at km 20). What §2 argued from prose is
now a table, and it holds.

Three modelling choices carry that result, and each of them moves it by more than
the deficit this section was arguing about:

- **A kill's raw meat is not income here.** It restores nothing as found, and
  every recipe that turns it into a portion is a `kitchen` recipe — a room gated
  on estate tier 2, which is the level this stretch ENDS at. It is printed as
  `if cooked` (774 Vigor at km 1, twice the deficit) and kept out of the net.
- **Only forage that is edible as found counts.** Half the km 1–10 pool is lumber
  and river pebble, and the potato deeper in needs the same locked kitchen.
- **Kills use the level-gap scaler.** The generated table in §2 prints 79 as the
  flat 788 ÷ 10 and labels it correctly; the ledger's 92.2 is the same path with
  the decay applied.

Excluded and named rather than rounded away — silver (hide sells, quests pay, the
trader stocks both food and the lumber a kitchen would want), the events the
approach walk rolls on the way in, and re-entered rooms, whose encounter weight
decays. All three push the same way, so every row is a **floor** on the opening
rather than an estimate of it.

The band is `opening.shallow_is_bankrupt`, and it is a warning rather than a
broken band for the reason §7 gives: measure before retuning, so nothing here
fails a build on a number the project has agreed to look at first.

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

**The sinks that are not a ladder**

| sink | silver | note |
|---|---|---|
| enchant one item to +5 | 1660 | ×5 filled slots = 8300 |
| the Master's armour | 485 | one-off |
| repair | 50% of value | per repair, ongoing |
| found a guild | 500 | one-off, level 5 |
| market listing | 5 | per lot, up to 5 |
| arena tithe | 10% of the stake | the only PvP drain |
| tavern food | 20–200 | per dish |
| tavern wagers | none | payout is in `CapitalController.runRound` — ×2 on a win, refund on a tie, so a fair die is a 0% edge |

**The faucet** — one job per NPC per game day, taken at the NPC

| NPC | jobs | offered from | L1 | L8 | L20 | L40 |
|---|---|---|---|---|---|---|
| trader | 5 | 1 / 1 / 1 / 6 / 8 | 27 | 35 | 41 | 51 |
| master | 5 | 1 / 1 / 1 / 7 / 10 | 25 | 38 | 47 | 59 |
| tavern | 5 | 1 / 1 / 1 / 4 / 5 | 27 | 30 | 35 | 43 |
| **per day** | | | **78** | **103** | **123** | **153** |
<!-- /generated -->

*AMENDED 2026-09-07 — the faucet was retuned by the finding below.* The authored
rewards were halved, a job is now offered only from its own level band and taken
by hand at the NPC, and what it pays grows with the player: silver linearly at
1.5% a level, XP on the `mobXP` exponent so a job stays worth the same number of
kills, Vigor on the pool it refills. Read off the four columns above, the daily
take runs **78 → 153** across the arc where it used to be a flat **220** — never
above the old number at any level, and roughly **10,000 over ~90 days** against
the ~19,800 the old table implied. Six early jobs were authored alongside the
bands (forage deliveries a level-1 player can actually finish), so each NPC now
offers three at level 1 rather than one — the bands would otherwise have handed
a new player the same job every day until level 6.

Against that, **the mandatory spend is 1,600 silver**, every other silver cost in
the game is optional, and the largest optional one is enchanting at 1,660 an
item. Hides add roughly 2.4 silver a kill across 3,925 kills.

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

**It compounds with §2.** The opening asks for 92 kills at km 1 before the first
plot exists (§2, *Measured*), and the mine sits behind that same gate — iron is
the first material the estate ladder cannot do without. §2's measured answer
shortens this problem rather than removing it: a player who walks to km 4 needs
nine kills instead of ninety-two, but the mine is still three levels away, and
they are the same first week.

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

> **DISCHARGED 2026-09-02.** The band exists (`OpeningLedger`, printed by both
> `roi-content spec opening` and `simulate`), and the answer is in §2 under
> *Measured*: yes, from km 4, best at km 10. **The one-number retune is no longer
> obviously wanted** — the boar's meat chance does not enter the opening at all,
> because the kitchen that would cook it opens at the level this stretch ends at.
> What the ledger points at instead is that the game never tells the player to
> walk, which is a first-hour teaching problem rather than a tuning one, and it
> belongs to the playtest.

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
