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
| `enemy.wild_viper` at level 1 | 5 XP → **158 kills** |
| starting Vigor pool | 105 |
| `enemy.wild_boar` at level 2, on curve | 38 XP — 8 of those |

The second row is the path that never leaves the shallowest band. The last
is why it is not the intended one: depth is the difficulty dial from the
first hour.
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
| 1 | 1,1 | 7.4 | 11.4 | 100% | 106.1 | 430 | 1208 | 2 | **-665** | -665 |
| 2 | 1,1,2 | 16.1 | 12.6 | 100% | 48.9 | 198 | 616 | 4 | **-307** | -60 |
| 4 | 1,1,2,4 | 37.8 | 14.3 | 100% | 20.8 | 84 | 297 | 8 | **-106** | +160 |
| 7 | 1,1,2,4,7 | 78.3 | 15.4 | 97% | 10.1 | 41 | 155 | 14 | **-13** | +138 |
| 10 | 1,1,2,4,7,10 | 142.6 | 16.2 | 88% | 5.5 | 22 | 89 | 20 | **+28** | +101 |
| 11 | 2,4,7,10 | 244.8 | 19.8 | 79% | 3.2 | 10 | 64 | 22 | **+39** | +113 |
| 12 | 4,7,10 | 344.8 | 21.9 | 69% | 2.3 | 7 | 50 | 24 | **+48** | +108 |
| 13 | 4,7,10,13 | 456.8 | 23.3 | 46% | 1.7 | 5 | 40 | 26 | **+54** | +84 |
| 14 | 7,10,13 | 623.2 | 24.9 | 21% | 1.3 | 4 | 32 | 28 | **+59** | +69 |
| 16 | 7,10,13,16 | 819.3 | 24.1 | 17% | 1.0 | 3 | 23 | 32 | **+63** | +75 |
| 17 | 10,13,16 | 883.2 | 23.4 | 8% | 0.9 | 3 | 21 | 34 | **+63** | +70 |
| 20 | 13,16 | 1016.5 | 24.2 | 0% | 0.8 | 2 | 19 | 40 | **+59** | +68 |
| 22 | 13,16,22 | 1359.1 | 23.3 | 0% | 0.6 | 2 | 14 | 44 | **+59** | +66 |
| 23 | 16,22 | 2575.8 | 18.3 | 0% | 0.3 | 1 | 6 | 46 | **+64** | +74 |
| 26 | 22 | 5000.0 | 13.6 | 0% | 0.2 | 0 | 2 | 52 | **+61** | +61 |

Cheapest depth a player can actually HOLD (win ≥ 95%): **km 7**, at -13 Vigor.
<!-- /generated -->

**The answer to "at what depth" is: four kilometres further than a new player
will walk.** Four kilometres of walking is worth more than the entire deficit,
and the flip lands at km 4 — the first depth the moose spawns at. Depth then has
a measured **optimum** rather than an open ceiling: Vigor stops being the binding
constraint at about km 4, and by about km 8 survival takes over (88% win at km 10,
79% at km 11, 46% at km 13, 0% at km 20). What §2 argued from prose is now a
table, and it holds — but the window it leaves open is **km 4 to km 7**, four
kilometres wide, and that is the whole of the intended opening.

> *Re-measured 2026-09-14, after tier 1 was filled (`spec-bestiary.md` §3).* The
> shape above is unchanged and every number under it moved. Km 1 costs **270**
> rather than 335 and takes **53.4** kills rather than 92.2 — the viper and the
> eagle are what a shallow kilometre is made of now. The middle of the band paid
> for it: km 4 fell from +44 to **+3** and km 7 from +66 to **+45**, because a
> level-1 creature spawns across km 1–10 and drags that whole band's average XP
> down. Km 2 is a row at all for the first time, at −94.
> *Superseded the same day by the XP halving.* `mobXP.coefficient` went **26 → 13**
> and every `xpReward` with it, so every figure in this note is now the record of
> an intermediate state that never shipped on its own. Current: km 1 costs
> **106.1** kills and **−665** Vigor, km 2 −299, km 4 **−106**, km 7 **−13**, and
> the cheapest holdable depth pays nothing at all. (The last two Vigor of each
> of those went to the silver find on 2026-09-15, which took its 2% out of the
> `loot` bucket — so the trail feeds fractionally less and pays coins instead.) The causal claims above still
> hold — they are about the dilution a level-1 creature causes, which the XP
> change did not touch.
>
> *And again the same day, after the other five creatures were re-solved.* The
> Vigor column barely moved; the **win** column moved a great deal — km 10 from
> 95% to 88%, km 13 from 66% to 46%, km 17 from 34% to 8%. A level 1–3 player
> could walk much deeper than they should have been able to, because the deep
> roster was carrying a quarter of its archetype's danger. The cheapest depth a
> player can actually HOLD moved **km 10 → km 7**, and the profitable-and-
> survivable window narrowed from km 4–11 to **km 4–7**. That is the design
> asserting itself, not a regression: depth is supposed to be the dial.

Three modelling choices carry that result, and each of them moves it by more than
the deficit this section was arguing about:

- **A kill's raw meat is not income here.** It restores nothing as found, and
  every recipe that turns it into a portion is a `kitchen` recipe — a room gated
  on estate tier 2, which is the level this stretch ENDS at. It is printed as
  `if cooked` and kept out of the net. Since 2026-09-14 that column is **0 at
  km 1** — neither level-1 creature drops anything — and 65 Vigor at km 4. It
  was 774 at km 1 when the boar was the only thing living there.
- **Only forage that is edible as found counts.** Half the km 1–10 pool is lumber
  and river pebble, and the potato deeper in needs the same locked kitchen.
- **Kills use the level-gap scaler.** The generated table in §2 prints 79 as the
  flat 788 ÷ 10 — the cheapest single creature, ground alone — and labels it
  correctly. The ledger's 53.4 is a different path and not the same one decayed:
  it is the whole km-1 pool by spawn weight, where the eagle's 34 XP outweighs
  the decay applied to the viper's 10.

Excluded and named rather than rounded away — silver (hide sells, quests pay, the
trader stocks both food and the lumber a kitchen would want), the events the
approach walk rolls on the way in, and re-entered rooms, which since 2026-09-10
carry a HIGHER encounter weight than fresh ground rather than a decaying one — so
a kill found on the way home costs less walking than the 2.5 rooms charged here.
All three push the same way, so every row is a **floor** on the opening rather
than an estimate of it.

The band is `opening.shallow_is_bankrupt`, and it is a warning rather than a
broken band for the reason §7 gives: measure before retuning, so nothing here
fails a build on a number the project has agreed to look at first.

> *Changed 2026-09-14, and the report changed it rather than a person.* Halving
> mob XP moved the finding from `opening.shallow_is_bankrupt` to
> **`opening.vigor_bankrupt`**: *"levels 1–3 end 13 Vigor short at their cheapest
> holdable depth (km 7) — 0.1× the entire stock a player has before the estate
> exists."* The qualifier is gone because the exemption is: there is no longer a
> depth that is both survivable and profitable for a level 1–3 character. It is
> 11 Vigor, so it is marginal rather than fatal, and it is the honest cost of the
> XP change — **XP and Vigor are the same currency at one remove**, because XP
> comes from kills and kills cost Vigor. The fix belongs to the opening's own
> knobs (food, loot, the estate's first tier), not to the XP rate, and it is now
> the oldest open item in this document.
>
> *Noticed in the same pass and deliberately left alone:* the fortune deck's
> `20_judgement` grants a **flat 75 XP**. Halving mob XP did not change its
> absolute value — the level curve did not move — but it doubled against a kill,
> from 7.5 level-1 creatures to **15**, while still being 1.5% of one rabid bear.
> Same shape as `balance.portion_rots`. The fix is the one quest rewards already
> use: ride `mobXP.exponent` so the card is worth a fixed NUMBER OF KILLS at every
> level. The other two XP cards are multipliers and do not have the problem.

---

## 3. What a kill returns

<!-- generated: roi-content spec economy -->
**What a kill returns** — cooked meat is 14 Vigor a portion

| enemy | L | archetype | lootMult | meat | as Vigor | hide | as silver | hide ×mult |
|---|---|---|---|---|---|---|---|---|
| `enemy.wild_viper` | 1 | trash | ×0.5 | 0.00 | 0.0 | 0.00 | 0.0 | 0.00 |
| `enemy.wild_eagle` | 1 | skirmisher | ×1.2 | 0.00 | 0.0 | 0.00 | 0.0 | 0.00 |
| `enemy.wild_boar` | 2 | normal | ×1.0 | 0.70 | 9.8 | 0.80 | 2.4 | 0.80 |
| `enemy.wild_moose` | 4 | normal | ×1.0 | 1.60 | 22.4 | 0.70 | 2.1 | 0.70 |
| `enemy.wild_buffalo` | 7 | brute | ×1.7 | 1.60 | 22.4 | 0.90 | 2.7 | 1.53 |
| `enemy.rabid_lynx` | 10 | skirmisher | ×1.2 | 0.00 | 0.0 | 0.70 | 2.1 | 0.84 |
| `enemy.rabid_wolf` | 13 | normal | ×1.0 | 0.00 | 0.0 | 0.80 | 2.4 | 0.80 |
| `enemy.wild_bear` | 16 | brute | ×1.7 | 1.70 | 23.8 | 0.90 | 2.7 | 1.53 |
| `enemy.rabid_bear` | 22 | elite | ×3.0 | 0.00 | 0.0 | 1.80 | 5.4 | 5.40 |

`lootMult` does not apply today — no award site reads it, so `hide`
is what the table says regardless of archetype. `hide ×mult` is what
the same row would yield if the multiplier scaled QUANTITY, which is
the only factor that survives: scaling `chance` saturates at 1.0, and
rounding a quantity of 1 collapses ×0.5/×1.0/×1.2/×1.7 into 1 or 2.
<!-- /generated -->

Against a cost the simulator prints. **This block is a QUOTE from `roi-content
simulate`, not a `spec` table** — no `<!-- generated -->` marker can reproduce it,
so it carries its own date and has to be re-pasted by hand whenever the pace
moves — it went stale the same day the pace changed, and nothing in the drift
check could have said so. That is the argument for keeping numbers inside markers
wherever a `spec` command can emit them, and for dating them where none can:

```
    (roi-content simulate, 2026-09-10)
    class     vigor/kill  kills to 40  taps to 40   days on the estate alone  taps/day
    warrior     15.7          3925        44413       86.5                   513
    archer      15.1          3925        42784       83.3                   513
    mage        14.2          3925        40240       78.4                   513
    spread 10% — the plan asks for each class within ±7% of the mean
```

So: **clean game roughly pays for itself, Blighted game is a pure loss, and the
shallowest creatures are the worst deal in the table.** The Blight starving the
player as well as fighting them is the design working. The shallow end running at
a loss is not; it is §2.

> *Amended 2026-09-14, with tier 1 (`spec-bestiary.md` §3).* It is no longer the
> boar that a player meets first, and the two creatures that replaced it there —
> the viper and the eagle — return **nothing at all**, by decision. So the worst
> deal in the table is now a kill that pays zero against a fight that costs
> Vigor, and it is the first two kills anyone makes. The boar keeps its 0.70 meat
> and now meets the player at km 2 instead of km 1; its `lootMultiplier` rose
> ×0.5 → ×1.0 with the archetype, which changes nothing until §5 wires that
> multiplier to quantity.

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
| tavern food | 25–180 | per dish |
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

## 4b. Coins on the ground (added 2026-09-15)

A fifth step event. Walking a kilometre can turn up **2, 5, 10 or 20 silver**,
credited on the spot.

**It is not monster silver, and the distinction is the whole reason it could be
built.** Phase 8C deleted coin drops from kills and the decision stands — a
corpse full of coin is a faucet with no sink, and `enemies.silverReward` /
`archetypes.silverMultiplier` are gone from the schema. This is a *find on a
step*: it has no relationship to what was killed, needs no per-creature curve,
and cannot be farmed by picking soft enemies. Attaching it to a victory instead
would be the deleted mechanic wearing a new name.

**The denominations are a rule, not four chosen numbers.** Weights are
`10 : 4 : 2 : 1` against `2 : 5 : 10 : 20`, which is `1/amount` scaled to
integers. The chance is therefore inversely proportional to the find, and **every
denomination contributes the same expected silver** — 1.18 each, 4.71 a find. A
fifth denomination is added by writing `1/amount` again rather than by
re-balancing the set.

| find | weight | chance in the event | once every |
|---|---|---|---|
| 2 | 10 | 58.8% | 85 km |
| 5 | 4 | 23.5% | 212 km |
| 10 | 2 | 11.8% | 425 km |
| 20 | 1 | 5.9% | **850 km** |

**Frequency is 2 of 100, taken from `loot`** in every row including the passive
table — a find is a second kind of loot, not a second kind of nothing. So one
step in fifty pays, and ≈94 silver arrives per 1000 km walked. Against quest
income of 96–152 a day that is a **+28%** faucet for a player who walks hard; the
archer measured on 2026-09-14 had covered 1,703 km in six days, which is 34
finds and two twenties.

**Depth does not enter, deliberately.** Every other reward in the forest scales
with how deep it was taken. Making this one scale would turn flavour into a
progression lever that has to be balanced against the estate — for a faucet §4
has already measured as ~20,000 in surplus. A find is a find at km 1 and at km
40, and it fades on its own as the purse grows, which is the intended life of the
mechanic.

**What it costs, and it is not silver.** The 2 weight came out of `loot`, so the
trail feeds 2% less: the opening ledger's km 1 went −647 → **−665** Vigor and km 7
−11 → **−13**. Two Vigor a step of depth, traded for coins. That is the honest
shape of the trade and it is in §2's table, not asserted here.

**This makes the surplus worse, and it was added anyway.** §4 says the fix for
over-supplied silver is more to buy rather than less to earn; this is neither.
It ships as flavour on the user's call, sized at the low end for exactly that
reason — the frequency is the knob if the surplus ever starts to matter, and it
is one number in `tuning/exploration.json`.

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
