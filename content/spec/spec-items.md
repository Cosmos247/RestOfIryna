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

> *Amended 2026-10-06 by §11.* The armour climbs now. The Master's enchant
> became its ladder: five levels, each budgeting the piece at an item level
> (5 … 25) with 75% of the curve's growth, and gated by its price alone. A
> fully enchanted Forester piece is ×4.6 its authored stats, where it was ×1.2.
> The paragraphs above describe the game until that date.

---

## 3. What that does to the rebalance

The balance report measures every band against the **on-curve reference
character** — level-appropriate gear in every weighted slot. That character is
not one a player can assemble. The gap is printed rather than argued:

<!-- generated: roi-content spec items --levels 1,5,10,15,20,25,30,40 -->
**The obtainable kit against the on-curve kit** — budget points, best item per slot.
`fully enchanted` puts the armour at the enchant's cap, which no level gates —
only its price (`spec-items.md` §11)

| L | on curve | obtainable | of curve | fully enchanted | of curve |
|---|---|---|---|---|---|
| 1 | 75 | 60 | 81% | 196 | 262% |
| 5 | 135 | 74 | 55% | 210 | 156% |
| 10 | 210 | 92 | 44% | 228 | 108% |
| 15 | 285 | 109 | 38% | 245 | 86% |
| 20 | 360 | 126 | 35% | 262 | 73% |
| 25 | 435 | 142 | 33% | 278 | 64% |
| 30 | 510 | 159 | 31% | 295 | 58% |
| 40 | 660 | 192 | 29% | 328 | 50% |
<!-- /generated -->

> *Amended 2026-10-06 by §11.* The table above is refreshed. `obtainable` is
> what it was — the kit as bought. `fully enchanted` changed twice over: it
> used to multiply the whole kit by 1.2, the weapon included, although the
> bench has never taken a weapon; it now puts the ARMOUR at the enchant's cap,
> which is ×4.6 a piece. No level gates the enchant, so the column is not what
> a player of level L has — it is what the price is holding back. At level 1 a
> full enchant would be 2.6 times the curve; from level 20 it is three quarters
> of it and falling. The paragraphs below were written against the old table
> and are kept as the record of why the ladder was needed.

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

> **Amended 2026-10-04 by §9.** The weapon ladder no longer sits on these rungs. It gained a
> rung every five levels (1/5/10 … 40), each gated by the player level, and
> `ReferenceCharacter.ladderRung` became `staleGearOffset`. A gear ladder decided after this
> date starts from §9, not from this paragraph.

> **Amended 2026-10-06 by §11.** The armour's ladder was built — through the Master's enchant,
> not through `weapon_upgrades.json`. The bench was already an upgrade flow with a screen, a
> price and a per-row level that travels with the piece, which is everything this section said
> still had to be built. The lift is derived from the budget curve (`EnchantLadderRules.scale`)
> rather than authored rung by rung, so a piece keeps its own stat mix. Unlike the weapon's, it
> has no player-level gate: the owner had it priced instead (§11.1). "A later set is a new
> ladder beside it" is now a question §11.8 leaves open: an armour piece authored at or above an
> enchant level's item level gains nothing from that level, and the validator refuses it until
> the question is answered.

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

**`itemLevel` is not `tier`.** Tier is a ladder rung (1–9 on the weapon ladder); item level
is the budget input (1–40). Since 2026-10-04 the weapon ladder maps one to the other at
1/5/10 … 40, each rung's item level equal to the player level it opens at (§9); it was
1/10/20/30/40 until then.

**Rarity multiplies budget ×1.00 → ×1.45 while value goes ×1 → ×16.** Decoupled
on purpose: a legendary is worth sixteen times as much and is 45% stronger.

**Ids are the locale contract.** `gear.<name>` derives `item.gear.<name>` and
`item.gear.<name>.desc` in **both** `en.json` and `uk.json`, and the validator
demands both exist. A set id derives its own name key the same way.

**Nothing gets a flat bonus.** The rule that cost the most to learn: the same
+32 DEF is 267% of a level-1 chest and 14% of a level-40 one. Enchant scales the
item's own stats; every Super stance is a multiplier of the character's own stat.

> *Amended 2026-10-06 by §11.* The enchant no longer scales the item by a fixed
> percentage: a level budgets the piece at an item level. The rule above stands
> — nothing flat — and §11 adds the lesson a percentage taught: +4% of a
> level-1 piece is less than one point of any stat, so a share of a small thing
> can fail as completely as a flat number, in the opposite direction.

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

- **Weapons.** Every row of the three ladder items is clamped to the highest tier its owner's
  level allows. In practice the rows are worn or in the bag (the warehouse refuses the class
  weapon), and the warehouse is scanned anyway.
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

---

## 10. Durability is the item's own

**Status: APPROVED and APPLIED 2026-10-05.** The owner's decisions are in §10.1, each taken over a
quiz with the testers' real pieces as the sample.

### 10.1 What was asked and decided

The owner opened a day of gear work by asking for the Forester set at **50 durability**. Every
armour piece used to start at one number, `economy.gear.maxDurabilityStart` = 30, which had been
30 since the Master opened on 2026-05-21. The Forester set is all the armour there is, so a single
edit could have raised it. Three things made it more than one:
- **The class weapon was stamped with the same number.** A fresh row took
  `maxDurabilityStart` whatever it was, and the weapon's ladder starts at 30 too. At 50, a new
  player would have held a 50/50 sword that fell to 40/40 at the Master's lesson.
- **The repair price divides by it.** A point costs price × `repairCostFraction` ÷ durability. At
  50 with nothing else moved, a repaired point would have cost 40% less, and the repair is one of
  the few places silver leaves the game (`spec-economy.md` §4).
- **24 pieces were already in play**, six players' worth. The most worn had a maximum of 12, after
  18 repairs, and one player's whole worn set was at 0.

Decided by the owner on 2026-10-05:
- **The durability lives on each item**, not in one number for all armour, because more sets are
  coming, and items that belong to no set. `items.json` → `maxDurability`, and
  `maxDurabilityStart` is gone.
- **Existing pieces gain the difference in BOTH numbers** (+20 for the Forester): each becomes the
  piece it would be had it been bought at 50 and lived the same life. The shaves stay, and a
  broken piece comes back at 20.
- **The repair price per point stays where it was, by raising the prices** ×5/3 with
  `repairCostFraction` left at 0.5. Raising the fraction to 0.83 at the old prices would have
  priced a repair exactly the same. The owner chose the prices, so «a full repair from zero is
  half the price» stays one rule for every item. The difference falls on the purchase, which new
  players pay: the set costs 810 🪙 where it cost 485.

### 10.2 The rule

- **One source per piece.** A piece a fight wears (armour and the main hand) declares its
  `maxDurability`. The exception is a laddered weapon, whose `durabilityByTier` owns it. A piece
  nothing wears declares none.
- **One reader.** `GearConditionService.startingDurability(for:)` answers "what does a fresh piece
  of this item start at?" for the three places that ask: the row a purchase or a grant mints
  (`GearState.fresh(for:)`), the Master's repair price, and the workshop's salvage share.
- **A set's durability and price are set together.** A point repaired costs
  price × 0.5 ÷ durability, so a sturdier set at the same price is cheaper to keep per fight. That
  is a choice to make on purpose when authoring one.

| Forester | hood | boots | breeches | jerkin | set |
|---|---|---|---|---|---|
| durability | 50 | 50 | 50 | 50 | |
| price before | 60 | 95 | 150 | 180 | 485 |
| price now | 100 | 160 | 250 | 300 | 810 |
| a point repaired | 1 | 1.6 | 2.5 | 3 | as before |

Every piece now survives 49 repairs, where it survived 29. The shave is charged per REPAIR,
whatever was missing, so a player who mends a little and often spends the maximum faster than one
who waits for 0.

### 10.3 What changes for players already playing

`RaiseArmorDurability` moves every armour row in the bag and the warehouse by its item's new
durability minus 30, in both numbers: 6/12 becomes 26/32, 0/25 becomes 20/45, and an untouched
30/30 becomes 50/50. Its SQL was run against a temporary copy of the Pi's 24 rows on 2026-10-05,
and every row read exactly +20/+20.

A piece lifted off 0 grants its stats again, and the cached `User.gear*Bonus` cannot see that.
`EquipmentService.backfillGearBonuses` re-derives every player's bonuses at each boot, after the
migrations.

**The same gap sits under §9, which is committed and not yet deployed, and it is wider there.**
The new ladder re-solved every rung's stats (§9.2), and `ClampWeaponTiersToLevel` (§9.6) also
moves tiers. Neither touches the cache. Every tester holding a weapon at t2+ would therefore have
kept the old rung on the profile and in their first fight. On 2026-10-05 the Pi held four:

| tester | weapon | cached ATK | after the deploy |
|---|---|---|---|
| Дарина | t5 sword, not clamped | +60 | +27 |
| анія | staff t5 → t4 | +58 | +21 |
| Володимир | bow t5 → t4 | +55 | +20 |
| Amae | sword t4 → t3 | +46 | +16 |

The boot pass closes both gaps.

### 10.4 Applied 2026-10-05

**Content.** `items.json`: `maxDurability` 50 on the four Forester pieces. `master.json`: prices
100 / 160 / 250 / 300. `economy.json`: `maxDurabilityStart` removed. `manifest.json`: schema v18.

**Code.**
- `ItemDTO` / `Item.maxDurability`.
- `EquipmentSlot.isArmor` / `isDurable` in `Vocabulary.swift`, which both
  `GearConditionService` and the validator read.
- `startingDurability(for:)`, read by `GearState.fresh(for:)`, `MasterCatalog.repairCost` and
  `CraftingService.salvageYield`.
- The migration and the boot pass of §10.3.
- The trade screen prints wear only for pieces that wear, because a piece nothing wears is now
  minted 0/0 and would read as broken there.

**The validator rules:**
- `durability.missing` — error;
- `durability.non_positive` — error;
- `durability.shave_destroys_gear` — error, armour only, because weapons are not shaved;
- `durability.on_ladder` — warning;
- `durability.not_worn` — warning.

`economy.json` lost `tuning.economy.durability_non_positive` and `tuning.economy.shave_destroys_gear`
with the number they checked. Every rule has its failing case in `DurabilityTests`.

**Verified.**
- 379 tests; `validate --strict` 0 errors, 0 warnings; `simulate --strict` 0 broken bands and the
  same 18 warnings as before.
- `--content-digest`: `records` 438be135e3090fb5 → fefe14b940998631 and `tuning`
  605fd06bd8abdfda → 4edf65507bbb5e48. `spawns`, `quests` and `king` are unchanged. Content hash
  73568a2a → 41455b84.
- `spec economy` re-run; its one moved row («the Master's armour», 485 → 810) is refreshed in
  `spec-economy.md` §4.

---

## 11. The Master's enchant is the armour's ladder

**Status: APPROVED and APPLIED 2026-10-06.** The owner's decisions are in §11.1, each taken over a
quiz with the Forester set's real numbers as the sample. The fight and pace figures come from a
scratch probe described in §11.6. The copy beyond the picked card (§11.4) was written with the
build and goes to the owner with the report.

### 11.1 What was asked and decided

On 2026-10-05 the owner asked how the armour enchant works, what it does to the game and how to
improve it. It worked as Phase 6 left it: a level multiplied the piece's own stats by
`1 + 4% × level`, to ×1.20 at +5, each stat rounded on its own.

**What that gave on the only armour in the game** — the Forester set, item level 1, all four
pieces at the same level (a script over `items.json` and `master.json`, with the game's rounding):

| level | paid so far | what changed |
|---|---|---|
| +1 | 160 🪙, 16 hides | nothing |
| +2 | 560 🪙, 48 hides | nothing |
| +3 | 1,440 🪙, 108 hides | +2 HP |
| +4 | 3,240 🪙, 212 hides | +1 DEF, +3 HP |
| +5 | 6,640 🪙, 380 hides | +3 DEF, +4 HP |

- **Thirteen of the twenty purchases changed no number.** The dearest thing the Master sold — the
  jerkin's +4 → +5, at 850 🪙 and 42 hides — was one of them. Crit and dodge, 1 on a piece, never
  moved at any level.
- **The cause is the size of the piece, not the rounding.** 4% of an item-level-1 piece is
  0.27–0.48 budget points, and the cheapest whole stat, 1 HP, costs 0.45. No rounding rule fixes
  that inside the budget.
- **The price was never the percentage's.** The step table (40 … 850 🪙, 4 … 42 hides) and the
  bench's hint date from 2026-05-22, when +5 was a flat +8 DEF a piece. Phase 6 replaced the effect
  and kept both.
- **No screen said so.** The card showed «+0 → +1» and a price; the banner read «+4% до кожного
  стата предмета» over a piece that had not changed.
- **A full set was worth less than its own free set bonus** (+2 DEF, +6 HP, +2 dodge), at 42 times
  the silver per budget point of the armour itself.

Decided by the owner on 2026-10-05/06, in this order:
- **Keep the five steps, and make the level worth buying.** A first proposal — keep the 4%, sell
  only the levels that change a number, price the enchant as a share of the piece's own price —
  was turned down in those words.
- **The enchant is the armour's ladder, at 75% of the growth** — the weapon ladder's share
  (§9.1). Chosen over 50%, over 100%, and over a plain +20% of the piece's own stats a level, all
  four measured (§11.6).
- **No player level gates it.** The ladder was first built with a gate a level (5 / 10 / 15 / 20
  / 25, the weapon's rungs), and that was in the option the owner had picked. Reading the report,
  the owner refused it: «замість обмеження рівнем … краще зробити просто велику вартість». The
  gates came out the same day, with everything they had needed — the wearer's level in a piece's
  stats, and a refresh of the cached bonuses on a level-up.
- **The price is the gate: 50 × level² silver a piece** — 50 / 200 / 450 / 800 / 1,250, 11,000
  for a set — with the hides unchanged. Picked from three ladders between the old prices (6,640 a
  set) and 100 × level² (22,000), each shown with the earliest level a saving player could reach
  every step at.
- **An enchant never fails.** The owner asked; there is no roll anywhere in it.
- **The card is the mockup the owner picked**, less its player-level line (§11.4).
- **The player-facing word is «покращення», never «заточка»** — slang, the owner's word for it.
  The button, the title and every line say «покращити» / «покращення» / «покращено».

### 11.2 The rule

- **Level.** Enchant level N budgets the piece at that level's `itemLevel` — a per-level field in
  `master.json` → `enchantSteps`, the weapon rung's own. Shipped: 5, 10, 15, 20, 25, where the
  weapon's rungs t2–t6 sit.
- **Stats.** Every stat of the piece × (own + share × (target − own)) ÷ own. `own` and `target`
  are the budget curve at the piece's item level and at the level's; `share` is `master.json` →
  `enchantGrowthShare`, 0.75. Multiplied first and divided last, each stat rounded half away from
  zero.
  - `EnchantLadderRules.scale` is the one implementation. The game, the validator and
    `spec gates` all call it, so the table in §11.3 is the game's arithmetic.
  - It is derived, never typed: retune the curve or the share and the ladder follows.
  - The division comes last because level 3 is ×3.1 and puts a stat of 5 exactly on 15.5.
    Multiplying by the quotient can land a hair under and hand back 15.
- **Gate.** The price, and nothing else. A piece grants its enchant to whoever wears it, at any
  level, so a strong player can dress a new one — by trading the piece, or the silver.
  - This is where the armour parts from the weapon, whose rungs open by the player level
    because the estate once put the item-level-40 sword in hand at level 13 (§9.1). Here the
    owner chose the price to do that work.
  - **So the price table is a balance number, not a fee.** `EnchantLadderTests` pins it, and
    `master.enchant_cost_drops` watches its shape: a price that falls opens the level above it
    early.
- **Bound.** With a share of 1 or less, a piece at enchant level N never outgrows the on-curve
  item of that level's item level. Nothing bounds it against its WEARER's level; §3's refreshed
  table prints what that means (a full enchant on a level-1 player is 2.6 times the curve).
  Phase 6's ceiling — top rarity × a full enchant ≤ ×1.75 a common of the same level — is measured
  against the on-curve common of the level's item level, where the rarity alone is ×1.45.
- **What stays.** Nothing gets a flat bonus. What changed is the lesson beside that rule: a fixed
  percentage of a small thing fails as completely as a flat number, in the opposite direction.

### 11.3 The ladder

<!-- generated: roi-content spec gates -->
**Armour** (`master.json` → `enchantSteps`) — the Master's enchant; NO level gate, the price
is what holds a level back (`spec-items.md` §11). A level budgets the piece at an item level, at 75%
of the curve's growth; `set so far` is the silver all the armour pieces cost up to that level

| enchant | item level | × own stats | price a piece | set so far | `gear.forester_hood` 🛡/❤️/💥/💨 | `gear.forester_jerkin` 🛡/❤️/💥/💨 | `gear.forester_breeches` 🛡/❤️/💥/💨 | `gear.forester_boots` 🛡/❤️/💥/💨 | all pieces |
|---|---|---|---|---|---|---|---|---|---|
| +0 | own | ×1 | — | — | 3 / 4 / 1 / 1 | 4 / 6 / 1 / 1 | 3 / 5 / 1 / 1 | 2 / 3 / 1 / 0 | 12 / 18 / 4 / 3 |
| +1 | 5 | ×1.6 | 50 🪙 + 4× `mat.hide` | 200 🪙 | 5 / 6 / 2 / 2 | 6 / 10 / 2 / 2 | 5 / 8 / 2 / 2 | 3 / 5 / 2 / 0 | 19 / 29 / 8 / 6 |
| +2 | 10 | ×2.35 | 200 🪙 + 8× `mat.hide` | 1000 🪙 | 7 / 9 / 2 / 2 | 9 / 14 / 2 / 2 | 7 / 12 / 2 / 2 | 5 / 7 / 2 / 0 | 28 / 42 / 8 / 6 |
| +3 | 15 | ×3.1 | 450 🪙 + 15× `mat.hide` | 2800 🪙 | 9 / 12 / 3 / 3 | 12 / 19 / 3 / 3 | 9 / 16 / 3 / 3 | 6 / 9 / 3 / 0 | 36 / 56 / 12 / 9 |
| +4 | 20 | ×3.85 | 800 🪙 + 26× `mat.hide` | 6000 🪙 | 12 / 15 / 4 / 4 | 15 / 23 / 4 / 4 | 12 / 19 / 4 / 4 | 8 / 12 / 4 / 0 | 47 / 69 / 16 / 12 |
| +5 | 25 | ×4.6 | 1250 🪙 + 42× `mat.hide` | 11000 🪙 | 14 / 18 / 5 / 5 | 18 / 28 / 5 / 5 | 14 / 23 / 5 / 5 | 9 / 14 / 5 / 0 | 55 / 83 / 20 / 15 |
<!-- /generated -->

`price a piece` is one piece; a set is four. `set so far` is what the whole set has cost in silver
by that level.

### 11.4 The screens

The card as built (a warrior with 540 🪙 and 12 hides in the bag, the jerkin at +1):

```
✨ Покращення броні

🦺 Жилет лісника +1 → +2
   +6 → +9  (↑+3) 🛡 Захист
   +10 → +14  (↑+4) ❤️ Здоров'я
   +2 → +2 💥 Крит
   +2 → +2 💨 Ухилення
   ✅ 🪙 Срібло  (540/200)
   ✅ 8× 🟫 Шкура  (12/8)
```

It is the mockup the owner picked, with three differences that followed from later decisions:
the «✅ Рівень гравця (10/10)» line went with the gates, the silver line reads the new price, and
the title is «Покращення броні» where the mockup said «Заточка броні».

- **The stat lines** are the weapon reforge's own sentence (`GearStatLines.deltas`). One ladder is
  shown one way.
- **A refusal is a modal** and leaves the card standing, as it has since 2026-10-05.
- **The banner names what the level added**, in the piece's own numbers: «✅ 🦺 Жилет лісника —
  покращено до +2: +3 🛡 Захист · +4 ❤️ Здоров'я». It replaces «+N% до кожного стата предмета».
- **The word is «покращення», and «заточка» is on no screen.** The owner: it is slang. The mockup
  the owner picked had carried it, and I had spread it to the button, the title and four more
  lines; all of that went back. Two lines that had said it BEFORE this change went with it — the
  bag card's «✨ Заточка: +N» is «✨ Покращення: +N», and the banner's «заточено до» is «покращено
  до». The salvage card's «Зачарування +N буде втрачено» and the Master's «зачарують варте того»
  are as they were.
- **The hint is new:** «Майстер покращує броню щабель за щаблем: кожен рівень помітно додає речі
  сили й коштує дорожче за попередній. Найвищий — +5.» The old one described the flat mechanic of
  May («… Рівні 4-5 дають більший приріст»), and the three per-class "focus" keys went with it.

### 11.5 What changes for players already playing

- **No migration and no refund.** `enchant_level` is the column it always was. A level bought at
  the old price was bought for less than it costs now.
- **Every enchanted piece is stronger from the restart**, at the level it already carries. A
  hood at +3 granted 🛡3 ❤️4 and grants 🛡9 ❤️12. `EquipmentService.backfillGearBonuses` re-derives
  every player's cached bonuses at boot, as it does for §9 and §10.
- **Tell the testers.** The game announces nothing, and this lands with the stronger forest
  (`spec-bestiary.md` §11), which it partly answers. What they already hold was not read: the
  Pi's rows could not be queried from this session.

### 11.6 Measured, not reproducible from `roi-content` yet

**The harness** was a scratch package holding copies of `Modules/ROIContent` and `Modules/ROISim`,
the recipe `.memory/rebalance.md` records for the tier-2 research:
- **The fights:** the game's own `FightSimulator`, the `.basic` profile, 2,000 fights a cell, one
  seed per (creature, class, level) shared by every variant.
- **The player:** class base stats at level L, the class weapon at the rung its level opens, and
  from level 4 the four Forester pieces with their 4-piece bonus. The armour's own stats were
  lifted by the variant's factor with the game's per-stat rounding.
- **The creature:** every spawnable creature, at the strength of the estate tier the player's
  level opens (`CombatMath.scaled`).
- **The trip:** the expedition model of `.memory/rebalance.md` — manor to km D and back, 40%
  encounters going in and 52% coming home, a spawn-weighted pick per km, the deepest trip whose mean
  HP loss stays within 90% of the bar with a 90% chance of getting home, and the best XP per Vigor
  among those.
- **Calibration:** the full model reproduced the recorded cost of the estate scaling. Its days
  with the scaling against without run ×1.23–1.42 by milestone, where the 2026-10-03 record has
  ×1.22–1.39. Its absolute days run 3–15% under that record up to level 30 and within 2% of it at
  level 40, because it carries the nine-rung weapon the record predates.

**The four strengths.** XP per Vigor against today's game — the estate scaling, no enchant. The
trip here is the simplified one: the HP budget without dish healing. The three ladders are shown
at the enchant level of the same height as the weapon rung the player's level opens (+1 at 5 … +5
at 25), which is how they were put to the owner.

| variant | set at +5 🛡/❤️/💥/💨 | L5 | L10 | L15 | L20 | L25 |
|---|---|---|---|---|---|---|
| +20% of own stats a level (shown at +5) | 24 / 36 / 8 / 6 | +14% | +13% | +11% | +3% | +3% |
| ladder, 50% of the growth | 41 / 61 / 12 / 9 | +6% | +13% | +11% | +7% | +7% |
| **ladder, 75% — chosen** | **55 / 83 / 20 / 15** | **+11%** | **+18%** | **+16%** | **+9%** | **+10%** |
| ladder, 100% | 69 / 104 / 24 / 18 | +14% | +21% | +20% | +12% | +13% |

- **A percentage of the piece fades with the player's level,** because it multiplies a level-1
  piece. That is why the lift became an item level.
- **A yardstick from the same model:** the newest weapon rung against one rung behind is worth
  +17% / +18% / +17% / +4% / +9% at levels 5 / 10 / 15 / 20 / 25. A level of the chosen ladder
  across the set weighs about what a weapon rung does.
- **The figures are coarse.** The trip's depth moves in whole kilometres, so a row can step by
  three points where its neighbour does not move.

**What a level is worth ahead of the player** — the reason the price matters. XP per Vigor
against the forest as it was solved (no estate scaling, no enchant), full model:

| player level | +1 | +2 | +3 | +4 | +5 |
|---|---|---|---|---|---|
| 5 | −7% | +3% | +14% | +36% | +51% |
| 7 | −22% | −14% | −6% | +8% | +19% |
| 10 | −26% | −21% | −14% | −9% | −3% |
| 15 | −23% | −20% | −17% | −14% | −12% |
| 20 | −39% | −37% | −35% | −33% | −33% |
| 25 | −27% | −26% | −25% | −24% | −22% |

From level 10 not even the full enchant makes the forest easier than it was solved to be — the
estate scaling took more than the armour returns. Below about level 10 a high level bought early
does, and only its price stands in the way.

**The price ladders.** The earliest level each step can be bought for the WHOLE set by a player
who saves every coin of the three daily jobs and the King's silver for it, after the armour and
the mandatory ladders, selling no loot. First estimate, on today's pace:

| price a piece | set | +1 | +2 | +3 | +4 | +5 |
|---|---|---|---|---|---|---|
| 40 / 100 / 220 / 450 / 850 (the old table) | 6,640 | 4 | 5 | 5 | 7 | 12 |
| **50 / 200 / 450 / 800 / 1,250 — chosen** | **11,000** | **5** | **5** | **6** | **11** | **19** |
| 70 / 250 / 550 / 1,000 / 1,700 | 14,280 | 5 | 5 | 7 | 15 | 22 |
| 75 / 300 / 675 / 1,200 / 1,875 | 16,500 | 5 | 6 | 8 | 17 | 24 |
| 100 / 400 / 900 / 1,600 / 2,500 | 22,000 | 5 | 6 | 10 | 20 | 27 |

- **The chosen row, re-run with the pace the enchant itself gives:** +1 and +2 at level 5 (days
  9 and 17), +3 at level 7 (day 38), +4 at level 15 (day 76), +5 at level 22 (day 122). The days
  barely move; the levels come later than the first estimate because the player is levelling
  faster. These are the earliest possible — a player who also buys food or a weapon rung is later.
- **Along that path the forest is at most 5% easier than it was solved to be** (level 6, with
  +2), and harder from level 7 on.

**Days to a level** — the full model, with dish healing and the estate's food per day; mean of the
three classes:

| | L10 | L14 | L19 | L25 | L30 | L40 |
|---|---|---|---|---|---|---|
| the forest as solved: no estate scaling, no enchant | 51 | 65 | 88 | 123 | 173 | 385 |
| today: the estate scaling, no enchant | 63 | 86 | 119 | 175 | 241 | 474 |
| **the earliest saver at the chosen prices** | **51** | **70** | **99** | **149** | **209** | **439** |

- **A player who buys every level as early as it can be bought is 13–18% faster than today** up
  to level 30, and 7% at level 40.
- **And reaches level 10 when the forest as solved would have let them, then falls behind it** by
  8% at level 14 and 21% at level 25. So the fastest path through the ladder does not outrun the
  forest's design, which is why it ships without the bestiary re-solve §3 pairs with a gear ladder.
  A player handed a finished set at level 5 does outrun it, until about level 10.

**A fight at the edge of a trip** — HP lost as a share of the bar, warrior / archer / mage, every
cell a 100% win:

| player level | creature | no enchant | with the enchant |
|---|---|---|---|
| 5 | Скажена лисиця | 17.2% / 20.2% / 23.0% | +1: 14.5% / 16.9% / 19.0% |
| 10 | Зубр | 21.8% / 26.0% / 27.0% | +2: 17.3% / 19.9% / 20.2% |
| 15 | Вепр-сікач | 21.9% / 25.4% / 28.1% | +3: 16.5% / 18.0% / 19.8% |
| 20 | Тур | 15.0% / 18.1% / 19.2% | +4: 10.4% / 12.1% / 12.6% |
| 25 | Скажений ведмідь | 10.9% / 12.7% / 14.3% | +5: 7.5% / 8.2% / 9.0% |

**The arena** — the same players through `DuelMath.resolveRound`, both sides on the shipped
equilibrium's mix (50% Attack, 36% Defend, 14% technique), 6,000 duels a cell, a draw as half.
Both fighters wear the same enchant, the one in the fight table above:

| level | warrior – archer | warrior – mage | archer – mage | warrior mirror, rounds |
|---|---|---|---|---|
| 10 | 71% → 69% | 73% → 71% | 53% → 52% | 11.4 → 14.0 |
| 15 | 66% → 64% | 74% → 70% | 59% → 58% | 10.0 → 13.0 |
| 20 | 69% → 68% | 73% → 72% | 54% → 55% | 9.0 → 12.2 |
| 25 | 69% → 66% | 73% → 70% | 57% → 55% | 8.4 → 11.8 |

Between equally enchanted fighters the class gap narrows by one to four points — the same armour
is a larger share of a frailer class — and a duel lasts about three rounds longer. A duel between
an enchanted fighter and a bare one was not measured, and with no gate it can happen at any level.

### 11.7 Applied 2026-10-06 — what the implementation touched

**Content.**
- `master.json`: `enchantGrowthShare` 0.75 in place of `enchantBudgetFractionPerLevel`, an
  `itemLevel` on each of the five steps, and the silver 50 / 200 / 450 / 800 / 1,250. The hides did
  not move.
- `manifest.json`: schema v19.
- Locales, uk + en: the copy of §11.4. Four keys are gone — the three class "focus" lines and the
  percentage phrase — the hint is new, and in uk two lines lost the word «заточка».

**Code.**
- `EnchantLadderRules` and `LadderScale` in `ROIContent`: the lift.
- `MasterCatalog.enchantScale(level:for:)`.
- `EquipmentService.stats(ofItem:tier:enchantLevel:)`, which `nominalStats` and the Master's card
  both ask.
- `MasterService.enchant` returns the piece's stats before and after, for the banner.
- `CapitalController`: the list's hint, the card and the banner.
- `SpecTables`: `spec gates` prints the armour ladder last; `spec items` prints the kit fully
  enchanted beside the kit as bought, the armour only; `spec sets` adds the bonus against the
  members as they are enchanted; `spec economy` counts armour slots where it counted filled ones.
- The digest hashes the share and each step's item level, and replays every armour piece at every
  level from −1 past the cap.

**The validator rules**, each with its failing case in `EnchantLadderTests` or
`EstateAndNPCCatalogTests`:
- `master.enchant_no_effect` — error, a share of 0;
- `master.enchant_growth_share` — error, a share above 1;
- `master.enchant_item_level` — error, below 1;
- `master.enchant_item_level_not_ascending` — error;
- `master.enchant_cost_drops` — warning, as before; it now guards the ladder's only gate;
- `master.enchant_level_changes_nothing` — error: every level has to change a number on every
  armour piece. It replaces a rule that asked only whether the percentage was above zero, which
  it was while thirteen levels did nothing.

`master.enchant_runaway` is gone with the percentage it bounded, and `rarity.ceiling_exceeded`
measures the ladder (§11.2).

**Built and taken out the same day:** the per-level player gate (`requiredPlayerLevel`, four
validator rules, the gate line on the card and its refusal), the wearer's level in a piece's
stats, and `refreshAfterLevelUp` at the five `grantXP` sites. None of it is in the tree.

**Verified.**
- 395 tests; `validate --strict` 0 errors, 0 warnings; `simulate --strict` 0 broken bands and the
  same 18 warnings as before, because the sweep does not read the enchant.
- `--content-digest`: `records` fefe14b940998631 → 9303bb274d4517d8. `tuning`, `spawns`, `quests`
  and `king` are unchanged. Content hash 41455b84 → be1102fc.
- The digest was mutation-tested in a copy of the bundle: the share, an item level, a price and
  the budget curve each move `records`.
- `spec gates` prints the approved table from the game's arithmetic (§11.3), and
  `EnchantLadderTests` pins it and the prices.
- Three generated blocks were stale and are refreshed: §3's coverage table here,
  `spec-sets.md` §2 and one row of `spec-economy.md` §4.

### 11.8 Left open

- **Armour above item level 1.** The ladder's levels are absolute item levels, so a piece
  authored at item level 20 would gain nothing from +1…+4. The validator refuses such a piece
  (`master.enchant_level_changes_nothing`) until the class sets decide how their ranks and the
  enchant share one axis (`.memory/class-sets-concept.md`).
- **The ladder stops at +5, item level 25**, where the authored band stops. The weapon runs to 40.
- **Wealth is power now, and it moves.** With no gate, a finished set or the silver for one can be
  handed to a new player, for whom the forest is then up to half again as generous as it was
  solved to be until about level 10. The owner was told and chose the price. If it shows in play,
  the levers are the price, or binding an enchanted piece to its owner.
- **The set bonus is flat and now rots**, as §5 predicted: 23% of the set unenchanted and 5% at
  +5 (`spec-sets.md` §2). The set ceiling still reads the members' authored budget.
- **The obtainable kit depends on what the player paid**, which `spec items` can no longer state
  per level. The tier-2 stat lines were solved against the unenchanted column (§9.10); §11.6
  measured the fights directly.
- **A +5 piece is still a 50-durability piece** that loses 1 from its maximum at every repair. A
  «Відновити» at the Master — the maximum restored, the enchant kept — was raised and not asked.
