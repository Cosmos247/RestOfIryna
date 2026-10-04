# Content spec — Items

**Status: approved 2026-08-31.** Phase 9. The decisions are in §7.

Scope: levels 1–25, the authored band fixed in `spec-progression.md`.

Numbers are printed, never typed:

```
swift run roi-content spec items --levels 1,5,10,15,20,25,30,40
```

---

## 1. The decision this document was rewritten around

**No new items are authored during the rebalance.** The seven that exist are the
seven that ship.

That turns this specification from a content list into a **frame**: it fixes the
grid a future item must land on, the ladder that carries a set across levels, and
the rules that make adding one a JSON edit instead of a redesign. The furniture
arrives after the rebalance; the room is measured now.

Which means the question this document has to answer is not "what items exist"
but **"what does the rebalance have to get right so that adding them later is
safe — and what does the rebalance itself now stand on, given that they are not
coming?"** The second half is §3, and it is the reason this spec is not simply a
deferral note.

---

## 2. What exists

<!-- generated: roi-content spec items -->
**What the shipped catalogue can fill** — every equippable item there is

| slot | weight | items | itemLevel reach |
|---|---|---|---|
| `main_hand` | 3 | 3 | 1 → 40 |
| `off_hand` | 1.2 | 0 | **none** |
| `helmet` | 1 | 1 | 1 (fixed) |
| `chest` | 1.6 | 1 | 1 (fixed) |
| `legs` | 1.3 | 1 | 1 (fixed) |
| `boots` | 0.9 | 1 | 1 (fixed) |
| `accessory_1` | 0.5 | 0 | **none** |
| `accessory_2` | 0.5 | 0 | **none** |
<!-- /generated -->

Seven items: three starting weapons and the four-piece Forester set. **Since
2026-09-28 the Master is the only way to get the armour** — it sells all four pieces
for silver, and the estate no longer crafts them. `recipes.json` still carries the
four Forester patterns (14 recipes in all: those four, one ingot, nine dishes), but
only so salvage knows what a piece is made of; nothing lists or crafts them. So the
armour has **one** acquisition route and **one** power level. Those seven items
are not a starting point a player builds past. They are the whole wardrobe, for
forty levels.

The three weapons climb. `weapon_upgrades.json` carries each of them across five
rungs at item levels **1 / 10 / 20 / 30 / 40**, gated on materials rather than on
player level. The four armour pieces do not climb: they are item level 1 from the
first hour to the last, and the only thing that ever happens to them is the
Master's enchant, capped at `1 + 4% × 5` = **+20% of the piece's own budget**.

So the shape of a level-40 player is: a fully laddered weapon, four pieces of
starting armour, and three empty slots.

---

## 3. What that does to the rebalance

The balance report measures every band against the **on-curve reference
character** — level-appropriate gear in every weighted slot. That character is
not one a player can assemble. The gap is printed rather than argued:

<!-- generated: roi-content spec items --levels 1,5,10,15,20,25,30,40 -->
**The obtainable kit against the on-curve kit** — budget points, best item per slot

| L | on curve | obtainable | of curve | fully enchanted | of curve |
|---|---|---|---|---|---|
| 1 | 75 | 60 | 81% | 72 | 97% |
| 5 | 135 | 74 | 55% | 89 | 66% |
| 10 | 210 | 92 | 44% | 110 | 52% |
| 15 | 285 | 109 | 38% | 131 | 46% |
| 20 | 360 | 126 | 35% | 151 | 42% |
| 25 | 435 | 142 | 33% | 171 | 39% |
| 30 | 510 | 159 | 31% | 191 | 37% |
| 40 | 660 | 192 | 29% | 231 | 35% |
<!-- /generated -->

**The game starts on curve and leaves it immediately.** At level 1 a fully
enchanted kit is 97% of what the model assumes. It falls with every level after
that, as the table shows. Until 2026-10-04 the fall was a sawtooth: the
ten-level weapon rungs arrived late against a curve that climbs every level.
Since the weapon gained a rung every five levels at 75% of its budget (§9), the
decline is steady. Across the authored band the player carries **roughly 40% of
the gear every acceptance band was computed for.**

### The two halves that have been cancelling each other

The balance run reports the other half of this in its own words:

```
⚠️  [content.roster_off_curve] enemy.wild_buffalo carries 68% of the HP and 65% of the ATK its archetype asks for at L7
⚠️  [content.roster_off_curve] enemy.rabid_wolf carries 58% of the HP and 55% of the ATK its archetype asks for at L13
⚠️  [content.roster_off_curve] enemy.rabid_bear carries 53% of the HP and 50% of the ATK its archetype asks for at L22
```

**The bestiary is at ~60% of its contract and the player is at ~40% of theirs.**
The "100% win" rows are what those two errors produce together, and neither was
chosen — the roster was authored before the archetype table existed, and the
wardrobe was authored before the budget curve did.

> *Amended 2026-09-14.* Tier 1 no longer belongs to that ~60%. The viper, the
> eagle, the boar and the moose carry **100% of their contract's HP and 65% of
> its ATK** (`spec-bestiary.md` §3). The split is not a compromise between the
> two figures above: at level 1 the player's attack is already on curve, because
> the starter weapon already carries the ATTACK the budget prices for a
> `main_hand` at itemLevel 1 — it is only the
> armour that is missing, so only the ATK side needs correcting. That reasoning
> holds where registration's kit is the whole kit, which is the opening and not
> the band this section measures. Levels 7 and up are untouched and the paragraph
> above still describes them.
>
> *And later the same day, the other five were re-solved too* — bison, lynx,
> wolf, bear and rabid bear, to **65–78%** of contract. So the "~60% of its
> contract" figure no longer describes any creature in the game. What survives of
> this section is the OTHER half: the player is still at ~40% of the gear budget,
> and that is now the number the whole bestiary is calibrated against rather than
> a number cancelling an error. If the gear ladder lands, the bestiary has to be
> re-solved with it — the two halves are still one correction, just no longer two
> errors.

> *Updated 2026-09-01, after Phase 10.* These figures were 50% / 40% when this
> section was written. **The level re-spread moved the roster from ~50% to ~60%
> of contract without touching a single stat** — the same HP against a lower
> archetype target is a larger fraction of it. The gap narrowed by accident, not
> by design, and it narrows the argument below by exactly as much: the two errors
> still lean the same way, so correcting one alone is still worse than correcting
> neither, but the imbalance between them is now larger than it was.

That is the finding this specification exists to put in front of a decision:

> **`spec-bestiary.md` §9 commits Phase 10 to regenerating every stat line from
> the archetype contract.** Done on its own, it doubles every enemy in the game
> against a player who stays at 40% of the kit the contract was solved against.
> The cancellation is load-bearing, and half of it is scheduled for removal.

Three ways out, and they are not equivalent:

| | what it does | what it costs |
|---|---|---|
| **A — the gear ladder** | armour climbs the rungs weapons already climb; the kit returns to ~94% of curve | a mechanism, no new items (§4) |
| **B — an honest reference** | `referenceGear` stops wearing what the game does not sell; archetype targets re-solved against the real player | every band in the report moves and must be re-approved |
| **C — neither** | Phase 10 re-spreads the roster's levels but does **not** regenerate its strength | the archetype table stays decorative and the seven warnings become permanent |

**Decided: A, after the rebalance.** The ladder is the right answer and it is
specified in §4 — but it is a mechanism, and mechanisms are not what the
rebalance is for. Nothing in this section is built now.

**Which makes one consequence mandatory rather than optional.** The two errors
cancel today, so removing either one alone is worse than removing neither:

> **Phase 10 re-spreads the roster's levels and does NOT regenerate its
> strength.** The seven creatures keep the stat lines they have. This amends
> `spec-bestiary.md` §9, which was approved before this measurement existed.

The archetype table therefore stays decorative for one more release, and the
seven `content.roster_off_curve` warnings stay in every report. Both are the
accepted price, and both are written down here so that the release ships with a
known gap instead of a surprise. **The gear ladder and the bestiary regeneration
land together, after the rebalance** — that pairing is the whole point, because
either alone breaks a balance the other half is holding up.

---

## 4. The frame — one gear ladder instead of a weapon ladder

`weapon_upgrades.json` already describes exactly the thing an armour set needs:
an item id, and a list of rungs each carrying an `itemLevel`, a stat line and the
materials it costs.

```json
{ "itemId": "gear.rusty_sword",
  "tiers": [ { "tier": 1, "itemLevel": 1,  "stats": {…}, "inputs": [] },
             { "tier": 2, "itemLevel": 10, "stats": {…}, "inputs": [ … ] } ] }
```

**The runtime already accepts armour on it.** `EquipmentService.nominalStats`
resolves a row as `WeaponUpgradeCatalog.stats(for: item.id, tier: row.tier)`
before falling back to `Item.gearStats`, and that lookup **does not check the
slot**. Laddering the Forester set is a data edit against a code path that is
already slot-agnostic; what needs building is the upgrade *flow* (a screen, its
inputs, and durability-by-tier applied to armour), not the stat resolution.

That is the whole frame, and it is what makes "sets of different levels" a JSON
edit later:

- **A set is a ladder, not a tier of items.** One Forester set that climbs
  1 → 40 is four items; four separate sets at levels 1/10/20/30/40 are sixteen,
  with sixteen icons, thirty-two locale keys and a market to price them all.
  The ladder gets the same progression for the four items that already exist.
- **A later set is a new ladder beside it**, not a change to this one. Adding
  "the Houndsman set, rungs at 10/20/30" is one array append plus locale keys.
- **Not a recipe per rung.** The armour was craftable when this was written (it is
  bought from the Master alone since 2026-09-28), so the obvious
  alternative was a higher-tier recipe producing a stronger piece — but a recipe's
  output is an item id, so five rungs is five new items per slot. That is the
  path this document just decided against; upgrading in place is the one that
  needs none.
- **The rungs stay at 1/10/20/30/40.** They are already the weapon ladder's, the
  budget curve's natural sampling, and `ReferenceCharacter.ladderRung`.

### What A leaves behind, stated rather than discovered

Armour laddered to curve fills `main_hand` (3.0) + the four armour slots (4.8) =
**7.8 of the 10.0 slot weight — 78% of curve, or ~94% enchanted.** The residual
is `off_hand` (1.2) and the two accessories (1.0), and it stays empty by the
decision in §1. That is a known, quantified, printed shortfall rather than a
silent one, and §6 says what has to be true before it can be filled.

---

## 5. The rules a future item must obey

None of this is new; it is collected here because Phase 12 will author against
this section and nothing else states it in one place.

**Budget.** `budget(itemLevel, slot, rarity) = slotWeight × (6 + 1.5 × itemLevel)
× rarityBudget`. An item's stats ARE that budget spent at the fixed rates in
`tuning/budget.json` → `statPerPoint`, and the validator refuses an overspend.
Because the combat denominators were derived from this same curve, an item that
respects its budget **cannot move any stat's percentage** — which is what makes
adding an item safe, and why the rule is not negotiable.

**`itemLevel` is not `tier`.** Tier is a ladder rung (1–5); item level is the
budget input (1–40). The ladders map one to the other at 1/10/20/30/40.

**Rarity multiplies budget ×1.00 → ×1.45 while value goes ×1 → ×16.** Decoupled
on purpose: a legendary is worth sixteen times as much and is 45% stronger.

**Ids are the locale contract.** `gear.<name>` derives `item.gear.<name>` and
`item.gear.<name>.desc` in **both** `en.json` and `uk.json`, and the validator
demands both exist. A set id derives its own name key the same way.

**Nothing gets a flat bonus.** The rule that cost the most to learn: the same
+32 DEF is 267% of a level-1 chest and 14% of a level-40 one. Enchant scales the
item's own stats; every Super stance is a multiplier of the character's own stat.

### Two holes in the set frame, both real

**The one shipped set bonus is flat, and it rots exactly as the rule predicts.**
`set.forester` grants 8.4 budget points (+2 dodge at 2 pieces, +2 DEF +6 HP at 4)
against members worth **37 points at item level 1 and 210 at item level 25** —
both read off the slot table in §2. So the bonus is **23% of the set at the
bottom of the band and 4% at the top**, which is the same defect Phase 8C removed
from the stances, still live in `sets.json`. Under the gear ladder of §4 it gets
worse, not better: the members climb and the bonus does not.
The fix is the case the DTO already carries — `gear_multiplier`, so a set bonus
is a percentage of what its own pieces are worth. **`spec-sets.md` decides it**;
it is recorded here because this is where the measurement was taken.

**And `gear_multiplier` is not capped.** The validator caps a set's total against
25% of its members' combined budget, but `flatSpend` sums only the `flat_stats`
thresholds — a `gear_multiplier` is checked for being positive and nothing else.
`{"kind": "gear_multiplier", "multiplier": 3.0}` validates cleanly and triples
the wearer's entire kit. Today that is theoretical, because no set uses the case.
The moment the transition above is applied it becomes the only case in use, so
**the cap has to be extended to multipliers before a multiplier is authored** —
a 2-piece bonus of ×1.05 spends 5% of the members' budget and is comparable
against the same 25% ceiling. **Deferred with the transition to `spec-sets.md`:**
the two are one decision, and nothing is exposed until the first multiplier is
written.

**The Forester set's numbers are unfrozen — and that buys less than it looks.**
Its stat lines and its bonus may be rewritten from scratch rather than preserved.
Measured before the freedom was spent: the four pieces together spend **37.0
budget points against a nominal 36.0** at item level 1 — they are already on
curve, inside the validator's rounding slack, and re-deriving them through
`BudgetMath.spend` would move almost nothing. **The 40% gap in §3 is the frozen
`itemLevel`, not the way the points are spent**, so no amount of re-authoring
closes it; only the ladder does.

What the freedom is genuinely worth is two things, both in `spec-sets.md`:

- **The flat → multiplier transition becomes a write, not a migration.** There is
  no original intent to preserve, so the bonus is simply defined as a percentage
  of what its own pieces are worth.
- **The shared-set compromise becomes a decision instead of an inheritance.**
  One set is worn by all three classes — nothing in `items.json` or
  `EquipmentService` restricts equipment by class — so its single spread
  (`defense` .59 · `hp` .22 · `crit` .11 · `dodge` .08) can only approximate three
  different profiles: it delivers **81% of what a warrior's armour profile asks
  for, 86% of an archer's and 75% of a mage's**. Splitting it into three sets
  would be twelve items, which §1 rules out. The alternative needs none:
  `EquipmentService.nominalStats` already carries the answer in its own comment —
  *"the class-identity flavour moves to sets, where it can be expressed without
  distorting the budget of the piece it sits on."* A neutral shared set whose
  **bonus** supplies the class tilt costs no new items at all.

And one thing the freedom explicitly does NOT license: **armour that scales with
the wearer.** A set whose `itemLevel` tracked the player's level would close §3's
gap with no ladder and no items — and would nullify every gear upgrade in the
game, which is the same reason `EnemyGenerator` runs at design time and never at
runtime. Rungs are generated; they are not computed at equip time.

**Accessories cannot be generated at all.** `tuning/budget.json` gives every
class a `weapon`, an `armour` and an `offHand` share profile, and **no accessory
profile**. The two slots have weight (0.5 each) and no answer to "what does an
accessory of this class spend its points on". Filling them is therefore a tuning
decision before it is a content one — which is why §6 defers them as a pair.

---

## 6. What is deferred, and what has to be true first

| deferred | blocked on |
|---|---|
| `off_hand` items | nothing structural — the class profiles already exist. A shield / quiver / tome per class is three items and a ladder. |
| the two accessory slots | an **accessory share profile per class** in `tuning/budget.json`. Content cannot be authored against a budget that has no spending rule. |
| new sets beyond Forester | the §4 ladder, and the §5 multiplier cap. Then it is one JSON append plus locale keys. |
| rarity above `common` on any shipped item | a source. Nothing in the game drops or sells an uncommon-or-better piece; the ladder is the progression instead. |

The `off_hand` residual is worth one sentence of honesty: the reference character
**wears one today**, because a class profile exists for it, so the simulator has
always measured a player holding an item the game has never sold.

---

## 7. Decisions (approved 2026-08-31)

**No new items in the rebalance.** The seven that exist are the seven that ship.
This document is the frame they will later be added to, not the list.

**The weapon ladder generalises to a gear ladder** (§4), so the four Forester
pieces climb 1 → 40 on the rungs the weapons already use. Zero new items, and it
is what "sets of different levels" means mechanically. **It is built after the
rebalance, not inside it.**

**Therefore Phase 10 does not regenerate the bestiary's strength** — only the
level re-spread `spec-bestiary.md` §3 specifies. This amends that document's §9,
and the reason is §3 above: the roster's ~60% and the wardrobe's ~40% are
currently holding each other up, so the two halves are corrected together or not
at all. The gear ladder and the regeneration are one piece of work, after the
rebalance.

**The uncapped `gear_multiplier` is recorded, not fixed** (§5). No set uses the
case today, so nothing is exposed; the cap and the flat→multiplier transition are
one decision and they belong to `spec-sets.md`, which takes them next.

**The Forester set's stats and bonus are unfrozen** — `spec-sets.md` may write
them from scratch rather than preserve them (§5). It does not change the schedule
above: the set is already at 103% of its nominal budget, so the gap in §3 is the
frozen `itemLevel` and only the ladder closes it.

**`off_hand` and the accessories stay empty**, with the shortfall printed by
`roi-content spec items` rather than assumed away. Accessories additionally need
a share profile before anything can be authored for them at all.

---

## 8. What this spec does NOT cover

- What a set bonus should *be* thematically — `spec-sets.md`.
- What an item is worth, what drops it, and whether `lootMultiplier` gets wired
  up or deleted — `spec-economy.md`.
- Potions and scrolls. They are consumables, not budgeted equipment, and they
  ride with the economy spec.
- Which creatures drop which materials — `spec-bestiary.md` §6 defers the
  quantities to `spec-economy.md`.

---

## 9. The weapon ladder follows the player level

**Status: APPROVED and APPLIED 2026-10-04.** The owner's decisions are in §9.1, and the copy and
durabilities were approved unchanged (§9.9). The proposal's numbers come from a scratch probe and
a script, both described in §9.7. §9.10 is what the implementation measured.

### 9.1 What was asked and decided

On 2026-10-03 the owner said the weapon upgrade grows too much. The cause was not the step between
rungs but when the rungs open:
- the five rungs are authored at item level 1/10/20/30/40;
- `WeaponUpgradeService` opens tier N at estate tier N, and T2–T5 come at player levels 4/7/10/13;
- so the item-level-40 sword (ATK 60) was in hand at level 13.

The model behind tier 2 of the bestiary and the estate scaling (`spec-bestiary.md` §10.5, §11.4)
never saw this. Its real-gear player carries the weapon at `itemLevel <= level`, on rungs
1/10/20/30/40, so every figure approved on 2026-10-02/03 assumed a weaker weapon than the game
hands out.

**A second defect surfaced while measuring.** The upgrade button exists only in the workshop
(`EstateController.workshopKeyboard`), and the workshop opens at T3 (`EstateTierGates.workshop`).
So tier 2 cannot be bought before level 7, although the service allows it at T2. «Гострий край»
(`king.sharp_edge`, level 4, weapon tier 2, chain position 10) therefore most likely holds the live
chain from level 4 to level 7. It also means every "today" figure at levels 4–6 quoted in that
session was too light.

Decided by the owner on 2026-10-03/04, each over a quiz:
- **measure first** — §9.7 is that measurement;
- **a rung every 5 player levels**: 1, 5, 10 … 40, nine tiers. Rungs at 45 and 50 wait for the
  level cap to rise to 50;
- **75% of the growth** the shipped ladder allows at the rung's item level, chosen over 100% and 50%
  with both measured;
- **the first upgrade is a lesson at the Master** in the capital, paid with the rung's materials
  plus 30 🪙. Every later rung belongs to the workshop. This was chosen over a one-off job on his
  board and over a Master who forges every rung for a fee;
- **testers' weapons are clamped** to the highest tier their level allows;
- **the t6–t9 recipes are t5's × 1.5 / 2 / 2.5 / 3**, as §9.3 proposes;
- **the names are §9.3's**, with «Посох архімага» moving from t5 to t9;
- **the clamp is refunded in silver** at the trader's buy price of the removed tiers' recipes.

### 9.2 The rule

- **Gate.** Tier N opens at `requiredPlayerLevel`, a new per-tier field in `weapon_upgrades.json`:
  1, 5, 10, 15, 20, 25, 30, 35, 40. The estate no longer gates the weapon. A soft link stays through
  the recipes, because ingots are forged in the workshop.
- **Stats.** Tier N at rung level L gets, per stat, t1 + 0.75 × (shipped ladder at item level
  L − t1), rounded half away from zero.
  - "Shipped ladder" means today's five rungs, interpolated linearly between their item levels.
  - Each tier declares `itemLevel = L`. Spending 75% of the growth stays under the budget by
    construction.
- **Positional.** Tier numbers, names, recipes and durability stay attached to their POSITION, so
  today's t2 «Очищений меч» becomes the level-5 rung. Nothing on a player's row is renumbered; it
  is only clamped (§9.6).
- **Where.** Tier 1→2 is only ever bought at the Master (§9.4), and tiers 3–9 only in the workshop.
- **"Has learned" is DERIVED:** the weapon's tier is 2 or more. No column is added, and every tester
  left at t2+ after the clamp counts as taught.

### 9.3 The ladder

ATK / crit / accuracy:

| tier | player level | item level | Меч ⚔️/💥/🎯 | Лук ⚔️/💥/🎯 | Посох ⚔️/💥/🎯 |
|---|---|---|---|---|---|
| t1 | 1 | 1 | 7 / 3 / 3 | 6 / 3 / 3 | 7 / 5 / 1 |
| t2 | 5 | 5 | 11 / 5 / 5 | 10 / 5 / 5 | 11 / 8 / 2 |
| t3 | 10 | 10 | 16 / 8 / 6 | 14 / 8 / 8 | 16 / 13 / 3 |
| t4 | 15 | 15 | 21 / 10 / 8 | 20 / 11 / 11 | 21 / 17 / 3 |
| t5 | 20 | 20 | 27 / 12 / 10 | 24 / 13 / 13 | 26 / 21 / 4 |
| t6 | 25 | 25 | 32 / 14 / 12 | 29 / 16 / 16 | 31 / 25 / 5 |
| t7 | 30 | 30 | 36 / 17 / 14 | 33 / 18 / 18 | 36 / 29 / 6 |
| t8 | 35 | 35 | 42 / 20 / 16 | 38 / 21 / 21 | 41 / 34 / 7 |
| t9 | 40 | 40 | 47 / 22 / 17 | 43 / 23 / 23 | 45 / 37 / 8 |

**One upgrade adds +4–6 ATK** on every weapon, against +11–14 before. To the warrior's total ATK, a
rung adds about 17% at level 5 and about 5% at level 40. Before, the two rungs bought together when
the workshop opened at level 7 doubled it, from 26 to 52.

**Recipes.** Tiers 2–5 keep today's recipes. Tiers 6–9 are t5's recipe × 1.5 / 2 / 2.5 / 3, rounded
up. This is a proposal: the trader value is at his buy price, and "iron" counts an ingot as its 10.

**Меч**

| tier | materials | trader value | iron |
|---|---|---|---|
| t1 | — | 0 🪙 | 0 |
| t2 | 3× 🪨 Річкова галька | 6 🪙 | 0 |
| t3 | 5× 🪨 Річкова галька, 2× 🔩 Шматок заліза | 50 🪙 | 2 |
| t4 | 1× 🔳 Залізний злиток, 5× 🔩 Шматок заліза, 3× 🪵 Сосновий брус | 312 🪙 | 15 |
| t5 | 3× 🔳 Залізний злиток, 10× 🔩 Шматок заліза, 5× 🪵 Сосновий брус | 820 🪙 | 40 |
| t6 | 5× 🔳 Залізний злиток, 15× 🔩 Шматок заліза, 8× 🪵 Сосновий брус | 1332 🪙 | 65 |
| t7 | 6× 🔳 Залізний злиток, 20× 🔩 Шматок заліза, 10× 🪵 Сосновий брус | 1640 🪙 | 80 |
| t8 | 8× 🔳 Залізний злиток, 25× 🔩 Шматок заліза, 13× 🪵 Сосновий брус | 2152 🪙 | 105 |
| t9 | 9× 🔳 Залізний злиток, 30× 🔩 Шматок заліза, 15× 🪵 Сосновий брус | 2460 🪙 | 120 |
| **t1→t9** | | **8772 🪙** | **427** |


**Лук**

| tier | materials | trader value | iron |
|---|---|---|---|
| t1 | — | 0 🪙 | 0 |
| t2 | 5× 🪵 Сосновий брус, 1× 🟫 Шкура | 26 🪙 | 0 |
| t3 | 5× 🪵 Сосновий брус, 3× 🟫 Шкура | 38 🪙 | 0 |
| t4 | 10× 🪵 Сосновий брус, 5× 🟫 Шкура, 1× 🔳 Залізний злиток | 270 🪙 | 10 |
| t5 | 15× 🪵 Сосновий брус, 8× 🟫 Шкура, 3× 🔳 Залізний злиток | 708 🪙 | 30 |
| t6 | 23× 🪵 Сосновий брус, 12× 🟫 Шкура, 5× 🔳 Залізний злиток | 1164 🪙 | 50 |
| t7 | 30× 🪵 Сосновий брус, 16× 🟫 Шкура, 6× 🔳 Залізний злиток | 1416 🪙 | 60 |
| t8 | 38× 🪵 Сосновий брус, 20× 🟫 Шкура, 8× 🔳 Залізний злиток | 1872 🪙 | 80 |
| t9 | 45× 🪵 Сосновий брус, 24× 🟫 Шкура, 9× 🔳 Залізний злиток | 2124 🪙 | 90 |
| **t1→t9** | | **7618 🪙** | **320** |


**Посох**

| tier | materials | trader value | iron |
|---|---|---|---|
| t1 | — | 0 🪙 | 0 |
| t2 | 5× 🪵 Сосновий брус, 3× 🪨 Річкова галька | 26 🪙 | 0 |
| t3 | 5× 🪵 Сосновий брус, 5× 🪨 Річкова галька, 3× 🧱 Дика глина | 42 🪙 | 0 |
| t4 | 5× 🪵 Сосновий брус, 8× 🪨 Річкова галька, 1× 🔳 Залізний злиток | 236 🪙 | 10 |
| t5 | 8× 🪵 Сосновий брус, 10× 🪨 Річкова галька, 3× 🔳 Залізний злиток, 5× 🟫 Шкура | 682 🪙 | 30 |
| t6 | 12× 🪵 Сосновий брус, 15× 🪨 Річкова галька, 5× 🔳 Залізний злиток, 8× 🟫 Шкура | 1126 🪙 | 50 |
| t7 | 16× 🪵 Сосновий брус, 20× 🪨 Річкова галька, 6× 🔳 Залізний злиток, 10× 🟫 Шкура | 1364 🪙 | 60 |
| t8 | 20× 🪵 Сосновий брус, 25× 🪨 Річкова галька, 8× 🔳 Залізний злиток, 13× 🟫 Шкура | 1808 🪙 | 80 |
| t9 | 24× 🪵 Сосновий брус, 30× 🪨 Річкова галька, 9× 🔳 Залізний злиток, 15× 🟫 Шкура | 2046 🪙 | 90 |
| **t1→t9** | | **7330 🪙** | **320** |

The whole ladder takes 7,330–8,772 🪙 of materials, against 986–1,188 before. That is a sink for the
silver `spec-economy.md` finds over-supplied (about 20k spare over a lifetime). Iron is not the
bottleneck. A mine makes 2 iron an hour and holds 10 (`plots.json` → `bonusOutput`), so it
yields 10–30 a day for one to three harvests. The 320–427 iron of a whole ladder is a few weeks
of one mine.

**Durability** is 30 / 40 / 50 / 70 / 100 / 120 / 140 / 160 / 180. A weapon repair costs 1 🪙 per
missing point (`MasterCatalog.weaponRepairCost`), so a full repair at t6–t9 costs 120–180 🪙.

**Names.** t1–t5 keep theirs. The staff's «Посох архімага» moves from t5, where it would sit
mid-ladder, to t9. Every name keeps the ladder's noun (`locale.ladder_name_drift`).

| tier | sword | bow | staff |
|---|---|---|---|
| t5 | Лицарський меч | Мисливський довгий лук | **Рунний посох** (was «Посох архімага») |
| t6 | **Булатний меч** · Damask Sword | **Тисовий довгий лук** · Yew Longbow | **Зоряний посох** · Starlit Staff |
| t7 | **Воєводин меч** · Voivode's Sword | **Роговий лук** · Horn Bow | **Грозовий посох** · Storm Staff |
| t8 | **Гербовий меч** · Crested Sword | **Лук лісової варти** · Forest Warden's Bow | **Посох віщуна** · Seer's Staff |
| t9 | **Королівський меч** · Royal Sword | **Королівський лук** · Royal Bow | **Посох архімага** · Archmage's Staff |

### 9.4 The lesson

The mockup the owner picked (warrior, level 5, 7 pebbles and 214 🪙 in the bag):

```
🛠 Майстер                                   🔨 Урок перековки
…                                            Майстер крутить ваш меч у руках: «Іржа — ще не
🪙 Ваші срібники: 214                        вирок. Дивіться уважно, двічі показувати не буду.»

[🛡 Купити броню]                            ⚔️ Іржавий меч → Очищений меч
[⚒️ Полагодити] [✨ Покращити]                  ⚔️ АТК 7 → 11 · 💥 Крит 3 → 5 · 🎯 Влучність 3 → 5
[🔨 Урок: перекувати зброю]                  📜 Що потрібно
[📜 Замовлення]                              ✅ 3× 🪨 Річкова галька  (7/3)
[🔙 До столиці]                              ✅ 30 🪙  (214/30)
                                             [🔨 Перекувати] [🔙 Назад]
```

After the tap come the success banner «✅ ⚔️ Очищений меч — рівень 2», then the Master's line as a
message of its own (as the innkeeper's lessons are), then the learned line.

- **The button** shows only while the weapon is t1 and the player is level 5 or above. Locked
  buttons are absent, as everywhere else.
- **The card** draws one `RequirementLine` per material and one for the silver, all counted from the
  bag. The capital has no warehouse.
- **The price.** The 30 🪙 is `master.json` → `weaponLessonSilver`, a tuning scalar beside
  `repairCostFraction`, and the digest hashes it.
- **The workshop** refuses a t1 weapon with the not-learned line rather than selling the rung.

Copy, uk (en follows it; the three class lines follow `capital.master.repair.weapon.*`):

| key (proposed) | uk |
|---|---|
| `capital.master.button.lesson` | «🔨 Урок: перекувати зброю» |
| `capital.master.lesson.intro.warrior` | «Майстер крутить ваш меч у руках: «Іржа — ще не вирок. Дивіться уважно, двічі показувати не буду.»» |
| `….intro.archer` | «Майстер натягує тятиву вашого лука й хмикає: «Дерево живе, тільки зле оброблене. Дивіться уважно, двічі показувати не буду.»» |
| `….intro.mage` | «Майстер зважує ваш посох на долоні: «Добре дерево, тільки руки до нього не доходили. Дивіться уважно, двічі показувати не буду.»» |
| `capital.master.lesson.done.warrior` | «Майстер повертає меч і витирає руки об фартух: «Бачили? Нічого хитрого — жар, молот і терпіння. Наступного разу впораєтеся самі, у майстерні свого маєтку.»» |
| `….done.archer` / `….done.mage` | the same, with «ніж, жила й терпіння» / «різець, віск і терпіння» |
| `capital.master.lesson.learned` | «🔨 Ви навчилися перековувати зброю. Далі — самі, у 🛠 Майстерні маєтку: наступна перековка відкриється на %{level} рівні.» |
| `capital.master.lesson.learned_open` | the same line when the next rung is already open: «… Далі — самі, у 🛠 Майстерні маєтку: наступна перековка вже чекає.» |
| `weapon.upgrade.not_learned` | «Ви ще не вмієте перековувати зброю. Майстер на Подолі покаже — зазирніть до нього.» |
| `weapon.upgrade.level_too_low` (replaces `estate_too_low`) | «Наступна перековка відкриється на %{required} рівні. Зараз у вас %{current}.» |
| `capital.location.master.body` | «Столична майстерня, що гучніша за кузню — дерево, залізо, шкіра, скло в одному приміщенні. Тут продадуть готове, полагодять зношене, зачарують варте того — і навчать перековувати власну зброю. Майстер ледь зводить очі: «Показуйте, що ремонтувати.»» |

The Master's body text has to change, because it says «З вашої сировини тут нічого не зроблять».
That was already untrue of enchanting, which takes the player's hides.

### 9.5 The King's chain

Four decrees move to the level at which their rung opens; nothing else changes order.

| decree | asks | was: position · level | becomes |
|---|---|---|---|
| «Гострий край» | weapon t2 | 10 · L4 | 15 · L5, last of the L5 block |
| «Гартована сталь» | weapon t3 | 19 · L8 | 22 · L10, right after «Зрілість» |
| «Ковані грані» | weapon t4 | 26 · L11 | 31 · L15, after «Ристалище» |
| «Королівська криця» | weapon t5 | 30 · L14 | 37 · L20, alone between L19 and L25 |

Two texts change:
- «Гострий край» sends the player to the Master: «Іржава криця не боронить нікого. Майстер на
  Подолі покаже, як перекувати зброю.»
- «Королівська криця» no longer calls t5 the top of the ladder: «Пуща міцнішає, і криця мусить
  встигати. Доведіть зброю до п'ятого тиру.»

**A new validator rule, `king.weapon_tier_before_its_gate`.** A decree asking for weapon tier N must
sit at or above that tier's `requiredPlayerLevel`. It is the twin of
`king.estate_tier_before_its_gate`. Today the weapon condition is only range-checked, which is how a
decree that cannot be finished for three levels shipped. Its failing case lands in the same commit.

**Positions.** `KingProgress` stores a position. This reorder spans positions 10–37, wider than
`RewalkReorderedDecrees`' window, and it holds event decrees (cook, claim, harvest, send, craft, win
a duel) that a re-walk would make players do again. So the migration re-seats each row BY DECREE:
- the done set is the decrees before the row's old position;
- the new position is the first decree of the new order that is not done.

Measured on the order above, the result is:
- **No skipped decree, and no row moves back by more than two.** Rows at 11–15, 20–22, 27–30 and
  33–37 move back one place, and the rows at 31 and 32 move back two.
- **At most two passed decrees come up again,** both weapon decrees that moved later («Ковані грані»
  and «Королівська криця» for a row at 31 or 32). They are live state reads, so they close at once when
  the clamped weapon still qualifies, at worst for one more payout each.
- **The counter resets** whenever the decree changes.

### 9.6 What changes for players already playing

- **Weapons.** Every row of the three ladder items — worn, in the bag or in the warehouse — is
  clamped to the highest tier its owner's level allows.
  - Its maximum durability follows the tier, current durability is capped at it, and the enchant
    stays.
  - A level-10 warrior holding today's t4 (ATK 46) is left with t3 (ATK 16).
- **Decrees** are re-seated by §9.5's rule.
- **Two hits at once.** This ships after tier 2, the estate scaling and the arena, none of which is
  deployed. A tester above T1 meets the weaker weapon and the stronger forest on the same restart, so
  tell them first.
- **A refund in silver** for what the clamp removes: the trader's buy price of the removed tiers'
  recipes, which are today's recipes at those positions. The level-10 warrior above gets back t4's
  312 🪙.

### 9.7 Measured, not reproducible from `roi-content` yet

**The fights** came from a temporary XCTest probe, copied into `Tests/ROIContentTests` for one run
and deleted, that rolls the game's own `FightSimulator`:
- **The player:** class base stats at level L, the class weapon of the variant, and from level 4
  the four Forester pieces with their 4-piece bonus.
- **The creature:** spawnable creature №min(L, 14), scaled by the estate tier the player's level
  allows (`CombatMath.scaled`).
- **The run:** the `.basic` profile, 3,000 fights per cell, seed 20261003 re-seeded per cell.
- **"Today" at levels 4–6** is the starter weapon, because of the workshop gate (§9.1).

The probe first reproduced the 2026-10-03 run's figures exactly. A cell reads: HP lost as % of the
bar · rounds · win % when below 99.5. "Model" is the weapon §10/§11 were measured with.

**The ladder** came from a script over `weapon_upgrades.json`, `trader.json` and `items.json`, with
the rounding above.

**warrior**

| L | T | creature (contract) | today | model (v1) | 75% |
|---|---|---|---|---|---|
| 1 | T1 | Гадюка (10% · 3) | 8% · 4.1 | 8% · 4.1 | 8% · 4.1 |
| 3 | T1 | Дикий кабан (24% · 5) | 24% · 7.0 | 24% · 7.0 | 24% · 7.0 |
| 5 | T2 | Дикий лось (24% · 5) | 22% · 6.3 | 22% · 6.3 | 18% · 5.4 |
| 7 | T3 | Зубр (42% · 7) | 21% · 4.8 | 46% · 9.3 | 39% · 8.0 |
| 9 | T3 | Скажений вовк (24% · 5) | 12% · 3.9 | 25% · 6.9 | 22% · 6.2 |
| 10 | T4 | Вепр-сікач (42% · 7) | 27% · 5.1 | 48% · 8.2 | 52% · 8.8 |
| 12 | T4 | Тур (42% · 7) | 28% · 5.2 | 48% · 8.3 | 53% · 8.9 |
| 13 | T5 | Скажена зграя (28% · 4) | 18% · 3.2 | 38% · 5.6 | 41% · 5.9 |
| 14 | T5 | Скажений ведмідь (62% · 8) | 40% · 5.4 | 82% · 9.9 · w77 | 87% · 10.3 · w65 |
| 15 | T5 | Скажений ведмідь (62% · 8) | 35% · 5.2 | 72% · 9.5 · w93 | 68% · 9.1 · w96 |
| 16 | T6 | Скажений ведмідь (62% · 8) | 36% · 5.2 | 72% · 9.5 · w93 | 68% · 9.0 · w96 |
| 19 | T7 | Скажений ведмідь (62% · 8) | 24% · 4.5 | 48% · 8.2 | 46% · 7.9 |
| 20 | T7 | Скажений ведмідь (62% · 8) | 20% · 4.4 | 31% · 6.2 | 34% · 6.7 |
| 25 | T7 | Скажений ведмідь (62% · 8) | 7% · 3.4 | 11% · 4.7 | 11% · 4.8 |
| 30 | T7 | Скажений ведмідь (62% · 8) | 4% · 3.1 | 4% · 3.3 | 5% · 3.6 |
| 40 | T7 | Скажений ведмідь (62% · 8) | 2% · 2.2 | 2% · 2.2 | 2% · 2.3 |

**archer**

| L | T | creature (contract) | today | model (v1) | 75% |
|---|---|---|---|---|---|
| 1 | T1 | Гадюка (10% · 3) | 10% · 3.6 | 10% · 3.6 | 10% · 3.6 |
| 3 | T1 | Дикий кабан (24% · 5) | 29% · 6.2 | 29% · 6.2 | 29% · 6.2 |
| 5 | T2 | Дикий лось (24% · 5) | 24% · 5.6 | 24% · 5.6 | 21% · 5.0 |
| 7 | T3 | Зубр (42% · 7) | 27% · 4.8 | 53% · 8.4 | 46% · 7.4 |
| 9 | T3 | Скажений вовк (24% · 5) | 15% · 3.7 | 29% · 6.2 | 25% · 5.5 |
| 10 | T4 | Вепр-сікач (42% · 7) | 35% · 5.1 | 58% · 7.7 | 62% · 8.2 · w99 |
| 12 | T4 | Тур (42% · 7) | 36% · 5.2 | 60% · 7.9 | 64% · 8.4 · w99 |
| 13 | T5 | Скажена зграя (28% · 4) | 22% · 3.1 | 42% · 4.8 | 47% · 5.3 · w99 |
| 14 | T5 | Скажений ведмідь (62% · 8) | 50% · 5.3 · w99 | 91% · 8.4 · w48 | 94% · 8.6 · w36 |
| 15 | T5 | Скажений ведмідь (62% · 8) | 42% · 4.9 | 80% · 8.3 · w78 | 76% · 7.9 · w84 |
| 16 | T6 | Скажений ведмідь (62% · 8) | 43% · 5.0 | 81% · 8.3 · w77 | 77% · 7.9 · w84 |
| 19 | T7 | Скажений ведмідь (62% · 8) | 29% · 4.4 | 56% · 7.5 · w99 | 53% · 7.1 · w99 |
| 20 | T7 | Скажений ведмідь (62% · 8) | 25% · 4.2 | 36% · 5.6 | 40% · 6.2 |
| 25 | T7 | Скажений ведмідь (62% · 8) | 8% · 3.2 | 12% · 4.3 | 12% · 4.3 |
| 30 | T7 | Скажений ведмідь (62% · 8) | 5% · 3.0 | 5% · 3.1 | 6% · 3.3 |
| 40 | T7 | Скажений ведмідь (62% · 8) | 2% · 2.1 | 2% · 2.1 | 2% · 2.2 |

**mage**

| L | T | creature (contract) | today | model (v1) | 75% |
|---|---|---|---|---|---|
| 1 | T1 | Гадюка (10% · 3) | 10% · 3.2 | 10% · 3.2 | 10% · 3.2 |
| 3 | T1 | Дикий кабан (24% · 5) | 33% · 5.9 | 33% · 5.9 | 33% · 5.9 |
| 5 | T2 | Дикий лось (24% · 5) | 26% · 5.4 | 26% · 5.4 | 22% · 4.7 |
| 7 | T3 | Зубр (42% · 7) | 28% · 4.3 | 56% · 7.8 | 48% · 6.9 |
| 9 | T3 | Скажений вовк (24% · 5) | 16% · 3.4 | 32% · 5.9 | 27% · 5.2 |
| 10 | T4 | Вепр-сікач (42% · 7) | 36% · 4.7 | 60% · 7.1 · w99 | 65% · 7.6 · w98 |
| 12 | T4 | Тур (42% · 7) | 37% · 4.7 | 60% · 7.1 · w99 | 65% · 7.6 · w97 |
| 13 | T5 | Скажена зграя (28% · 4) | 24% · 2.9 | 48% · 4.8 · w98 | 50% · 5.0 · w98 |
| 14 | T5 | Скажений ведмідь (62% · 8) | 58% · 5.2 · w96 | 93% · 7.4 · w36 | 95% · 7.6 · w28 |
| 15 | T5 | Скажений ведмідь (62% · 8) | 50% · 4.9 · w99 | 86% · 7.6 · w61 | 83% · 7.4 · w67 |
| 16 | T6 | Скажений ведмідь (62% · 8) | 50% · 4.9 · w99 | 85% · 7.5 · w64 | 82% · 7.3 · w70 |
| 19 | T7 | Скажений ведмідь (62% · 8) | 34% · 4.4 | 62% · 7.1 · w96 | 58% · 6.8 · w98 |
| 20 | T7 | Скажений ведмідь (62% · 8) | 28% · 4.1 | 40% · 5.5 | 45% · 6.0 |
| 25 | T7 | Скажений ведмідь (62% · 8) | 10% · 3.3 | 14% · 4.3 | 14% · 4.3 |
| 30 | T7 | Скажений ведмідь (62% · 8) | 6% · 2.9 | 6% · 3.1 | 7% · 3.3 |
| 40 | T7 | Скажений ведмідь (62% · 8) | 3% · 2.2 | 3% · 2.2 | 3% · 2.3 |

What it says:
- **Today,** every fight from level 7 runs at about half its contract.
- **75% against the model,** in the sword's ATK: ahead at levels 5–9 (+4) and 15–19 (+2), behind at
  10–14 (−3) and from level 20 (−1 to −13).
- **Where it shows:** levels 10–13 run 3–5 points heavier than the model. The warrior loses 52–53%
  against the model's 48%, on a 42% contract, and the mage wins 97–98% where the model wins 98–99%.
- **From level 20,** creature №14 (the rabid bear) is outgrown under every variant. Past level 25 the
  ladder matters only for the arena and for content not yet written.

### 9.8 What the implementation touches

- **`content/data`:**
  - `weapon_upgrades.json`: nine tiers, `requiredPlayerLevel`, the 75% stats, the t6–t9 recipes
    and nine durabilities. Content schema v16 → v17;
  - `master.json`: `weaponLessonSilver`;
  - `king.json`: four moves and two texts.
- **Locales, uk + en:** the t6–t9 names, the staff's t5 rename and the §9.4 copy.
- **`ROIContent`:**
  - the DTO field;
  - validator rules: `requiredPlayerLevel` rising, tier 1 at level 1, the last tier within
    `maxLevel`, and `king.weapon_tier_before_its_gate` — each with its failing case.
- **`ROISim/SpecTables`:** `spec items` and `spec gates` print each rung's level. The generated
  blocks that quote them are refreshed, and so is `spec economy`'s ledger, which counts the ladder.
- **`Swift`:**
  - `WeaponUpgradeService`: the level gate, the t1 refusal and the lesson path;
  - `CapitalController`: the button, the card and the confirm;
  - `EstateController`: the two refusals;
  - two migrations: the weapon clamp and the decree re-seat.
- **`ContentDigest`:** `records` and `king` move, and the lesson silver is hashed.
- **After it lands:**
  - `CLAUDE.md` gets the rule: the weapon follows the player level, and its first rung is the
    Master's lesson;
  - `.memory` is updated;
  - verify the TABLES: no weapon row above its owner's level, and `king_progress` positions as
    §9.5 predicts.

### 9.9 Decided 2026-10-04

Nothing. On 2026-10-04 the owner approved the lesson copy of §9.4 as written, the workshop's
«⚔️ Перекувати зброю» / «⚔️ Перековка зброї» rename, and durabilities 120 / 140 / 160 / 180 at
t6–t9. The recipes, the names and the silver refund are in §9.1.

### 9.10 Applied 2026-10-04 — what the implementation touched and measured

**Content.**
- `weapon_upgrades.json`: nine rungs per ladder, each with `requiredPlayerLevel`, and
  `durabilityByTier` with nine entries.
- `master.json`: `weaponLessonSilver` 30.
- `king.json`: the four moves of §9.5.
- `manifest.json`: schema v17.
- Locales: names and descriptions for t6–t9, and the staff's t5 rename with its old description
  moving to t9. The descriptions were written in the house style after the names were approved,
  and were shown to the owner with the report.
- Two copy details changed from the mockup:
  - the price line is the house «✅ 🪙 Срібло (N/30)», because every cost on every screen is
    a `RequirementLine`;
  - the workshop's confirm became «🔨 Перекувати», so the Master's card and the workshop share
    one key.

**Code.**
- `WeaponLadderRules` and `KingChainReseat` in `ROIContent`.
- `WeaponUpgradeService`, with `upgrade` for the workshop and `lesson` for the Master.
- The Master's lesson in `CapitalController`, and the workshop's level gate and not-learned
  state in `EstateController`.
- `GearStatLines`, moved out of `EstateController` so both screens draw a reforge one way.
- `ClampWeaponTiersToLevel` and `ReseatDecreesById`.
- The digest hashes the gates, `highestTier` replayed over levels −1…45, and the lesson fee.
- `spec gates` prints the weapon ladder last, so §11.2's estate excerpt in `spec-bestiary.md`
  stays contiguous.

**The validator rules:** `ladder.required_level_missing`, `ladder.first_rung_gated`,
`ladder.gate_regression` (now also on weapons), `ladder.gate_above_cap`, `ladder.gates_disagree`,
`king.weapon_tier_before_its_gate` and `master.lesson_silver`. Each has its failing case in
`WeaponLadderTests` / `KingChainTests` / `EstateAndNPCCatalogTests`.

**A copy trap met on the way.** The learned line first carried 🔨 and 🛠 in its template, and
`locale.emoji_before_placeholder` refused it: Lingo finds `%{…}` in UTF-16 and slices in
Characters. So 🔨 is prepended in code, and 🛠 arrives as the value of `%{workshop}`, which Lingo
substitutes by plain string matching. The screen reads as approved.

**Verified.**
- 366 tests; `validate --strict` 0 errors, 0 warnings.
- `--content-digest`: `records` 1b5577693d8733af → 1041961908ba2d3f and `king`
  5dbddfd689f3cede → e3a492be1b017e81; `tuning`, `spawns` and `quests` unchanged; content hash
  6963c31b → 00b40443.
- The lesson card, its refusals, the banner and the NPC message were rendered from the real
  templates for all three classes, in both languages.

**The obtainable kit moved.** `spec items`' obtainable column (§3) fell from 48% to 44% at L10
and from 36% to 29% at L40. The tier-2 stat lines were solved against the old column on
2026-10-02. They are frozen, nothing re-solves them, and §9.7 measured the fights directly. A
re-solve belongs with the gear ladder (`TODO.md`, open items).
