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

Seven items: three starting weapons and the four-piece Forester set. The Forester
pieces are craftable (four of the twelve recipes make them; the other eight make
one material and seven dishes) and the Master sells them for silver — so the
armour has **two** acquisition routes and **one** power level. Those seven items
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

<!-- generated: roi-content spec items -->
**The obtainable kit against the on-curve kit** — budget points, best item per slot

| L | on curve | obtainable | of curve | fully enchanted | of curve |
|---|---|---|---|---|---|
| 1 | 75 | 60 | 81% | 72 | 97% |
| 5 | 135 | 60 | 45% | 72 | 54% |
| 10 | 210 | 101 | 48% | 121 | 58% |
| 15 | 285 | 101 | 35% | 121 | 43% |
| 20 | 360 | 146 | 40% | 175 | 49% |
| 25 | 435 | 146 | 33% | 175 | 40% |
| 30 | 510 | 190 | 37% | 228 | 45% |
| 40 | 660 | 236 | 36% | 283 | 43% |
<!-- /generated -->

**The game starts on curve and leaves it immediately.** At level 1 a fully
enchanted kit is 97% of what the model assumes. By level 5 it is 54%, and it
never recovers — the sawtooth is the ten-level ladder rungs arriving late
(58% at L10 decaying to 43% at L15) against a curve that climbs every level.
Across the authored band the player carries **roughly 40% of the gear every
acceptance band was computed for.**

### The two halves that have been cancelling each other

The balance run reports the other half of this in its own words:

```
⚠️  [content.roster_off_curve] enemy.wild_boar carries 62% of the HP and 71% of the ATK its archetype asks for at L1
⚠️  [content.roster_off_curve] enemy.rabid_wolf carries 50% of the HP and 50% of the ATK its archetype asks for at L16
⚠️  [content.roster_off_curve] enemy.rabid_bear carries 48% of the HP and 46% of the ATK its archetype asks for at L25
```

**The bestiary is at ~50% of its contract and the player is at ~40% of theirs.**
The seven "100% win at 4–11% HP" rows are what those two errors produce together,
and neither was chosen — the roster was authored before the archetype table
existed, and the wardrobe was authored before the budget curve did.

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
- **Not a recipe per rung.** The armour is already craftable, so the obvious
  alternative is a higher-tier recipe producing a stronger piece — but a recipe's
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
and the reason is §3 above: the roster's ~50% and the wardrobe's ~40% are
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
