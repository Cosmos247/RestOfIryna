# Content spec — Sets

**Status: approved 2026-08-31**, §4 settled 2026-09-01. Phase 9. Decisions in §7.

Scope: levels 1–25. This document inherits three decisions from `spec-items.md`
§5 — flat bonuses become multipliers, the 25% cap must cover multipliers, and the
Forester set's numbers are unfrozen — and it changes the first, because measuring
it showed the obvious fix walks into the same defect it repairs (§2). What it
does with the third is §4: the set is rewritten as **the first and weakest rung**
of a strength ladder, not as a preservation of what it is today.

Numbers are printed, never typed:

```
swift run roi-content spec sets --levels 1,10,20,25,30,40
```

---

## 1. What a set is, and what is reachable today

A set is a group of items sharing a `setId` and a list of thresholds: *at N
equipped pieces, this.* Every threshold at or below the equipped count applies,
so a four-piece wearer also gets the two-piece bonus. The validator already
enforces the shape — thresholds ascend, none may be below 2 (a "bonus" at one
piece is just the piece), and none may exceed the set's own membership.

**The game has exactly one set**: `set.forester`, four armour pieces. Which fixes
what this document can specify:

| threshold | reachable today | why |
|---|---|---|
| 2 pieces | ✅ | four members exist |
| 4 pieces | ✅ | four members exist |
| **6 pieces** | ❌ | `off_hand` and both accessories are empty (`spec-items.md` §2), so no set can have six members. The validator refuses the threshold as unreachable. |

The six-piece tier is therefore **not a design decision that was taken and
rejected — it is a shape the content cannot express yet**, and it unblocks
exactly when the three empty slots do.

---

## 2. The bonus form, and the defect the obvious fix walks into

`spec-items.md` §5 handed this document "flat bonuses rot, make them
multipliers". Both halves of that need correcting before anything is authored.

### First, the record: the flat bonus does not rot *today*

<!-- generated: roi-content spec sets --levels 1,10,20,25,30,40 -->
**`set.forester`** — 4 member(s), 36.0 points of member budget, 37.0 actually spent

| L | kit worn | flat 8.4 pts | ×1.05 on the KIT | ×1.05 on MEMBERS | cap allows, kit | cap allows, members |
|---|---|---|---|---|---|---|
| 1 | 60 | 23% | 3.0 = 8% | 1.9 = 5% | ×1.15 | ×1.24 |
| 10 | 101 | 23% | 5.0 = 14% | 1.9 = 5% | ×1.09 | ×1.24 |
| 20 | 146 | 23% | 7.3 = 20% | 1.9 = 5% | ×1.06 | ×1.24 |
| 25 | 146 | 23% | 7.3 = 20% | 1.9 = 5% | ×1.06 | ×1.24 |
| 30 | 190 | 23% | 9.5 = 26% | 1.9 = 5% | ×1.05 | ×1.24 |
| 40 | 236 | 23% | 11.8 = 33% | 1.9 = 5% | ×1.04 | ×1.24 |

`cap allows` inverts the validator's 25%-of-members ceiling: the largest
multiplier that would pass, under each reading of what it scales.
<!-- /generated -->

**23% at every level.** The flat bonus is stable because its denominator is
stable: the set never climbs, so 8.4 points against 36 is the same fraction at
level 1 and level 40. It sits just under the 25% ceiling and stays there.

It rots the moment the **gear ladder** lands — the members go from 36 points of
budget at item level 1 to 210 at item level 25 while the bonus stays 8.4, which
is 23% falling to 4%. So the flat problem is real but **not live**: it arrives
with the ladder, and it must be fixed in the same package rather than before it.

### Second, and worse: a `gear_multiplier` scales the wrong thing

`EquipmentService.recomputeBonuses` applies the factor to the wearer's **whole
equipped contribution** — the weapon included, and the weapon is not a member of
the set. So a four-piece armour set's multiplier is levered by a slot it does not
own, and by the one slot that actually climbs.

Read the table's two middle columns against each other. The same **×1.05** costs
**8% of the members' budget at level 1 and 33% at level 40** — it compounds as
the weapon ladders, while the flat bonus decays. **They are the same defect**: a
bonus measured against a denominator that is not its own. Phase 8C removed it
from the stances by making every lift a multiplier of *the character's own stat*;
the missing half of that lesson is that a multiplier is only self-normalising
when it multiplies **its own** base.

The ceiling makes the point sharpest. Under the whole-kit reading the largest
legal multiplier falls from ×1.15 to ×1.04 across a lifetime — **there is no
single value a designer can write that is legal for the whole game.** Under the
members-only reading it is a constant ×1.24.

> **Proposed: a `gear_multiplier` scales the contribution of the set's own
> equipped members, not the whole kit.** Then ×1.05 is 5% of the set at every
> level by construction, the cap is one number, and a set bonus stops depending
> on what the wearer is holding in their other hand.

This is inert to change: **no set in the game uses the case**, so the semantics
can be corrected before anything depends on the current ones.

---

## 3. The cap

The validator caps a set's total bonus at **25% of its members' combined
budget** — a set bonus is extra power bought with slot freedom, so it is a third
axis beside item level and rarity and needs the same kind of ceiling. Unbounded,
"wear the whole set" becomes the only correct answer to every slot decision.

**Today that cap sees only half of what it is meant to bound.** `flatSpend` sums
the `flat_stats` thresholds and nothing else; a `gear_multiplier` is checked for
being positive and then ignored. `{"kind": "gear_multiplier", "multiplier": 3.0}`
validates cleanly and triples the wearer's entire kit.

**Proposed:** a multiplier's cost is measured in the same points as a flat
bonus — `(factor − 1) × members' spent points` — and added to `flatSpend` before
the 25% comparison. With §2's semantics that number is level-independent, which
is what makes a single ceiling meaningful. Under §2's rules today's ceiling
admits up to **×1.24** on the Forester set, printed in the table above rather
than asserted here.

---

## 4. The strength ladder, and where the Forester set sits on it

**The 25% ceiling is not a target. It is the top rung.** A set's bonus is its own
axis, independent of item level: the rung decides what *share of the ceiling* a
set claims, and the members' item level decides how much absolute power that
share is worth. Two knobs, and neither moves the other — which is what makes a
ladder of sets at different levels expressible at all.

<!-- generated: roi-content spec sets -->
**The strength ladder** — a whole-set multiplier against the 25% ceiling

| ×total | of the members' budget | of the ceiling |
|---|---|---|
| ×1.07 | 7.2% | 29% |
| ×1.13 | 13.4% | 53% |
| ×1.19 | 19.5% | 78% |
| ×1.24 | 24.7% | 99% |
<!-- /generated -->

A property worth naming, because it is what makes the rung readable: when a set
spends its budget honestly — members' spend ≈ members' budget — **the multiplier
minus one IS its share of that budget.** So `×1.07` reads directly as "seven of
the twenty-five points of ceiling", and nobody has to do the arithmetic to know
whether a set is modest or greedy.

### The Forester set is the first rung, and the weakest

Its numbers are unfrozen (`spec-items.md` §5), so this is not a migration: it is
the entry set, written as the entry set.

| threshold | bonus | cost |
|---|---|---|
| 4 pieces | **×1.07** on the set's equipped members | 7.2% of the members' budget — **29% of the ceiling** |

**One threshold, not two.** The first set's job is to teach that wearing a whole
outfit does something. A two-piece tier underneath it is a second lesson the
first hour does not need, and it makes the four-piece payoff smaller by splitting
it. Later sets get 2/4 thresholds — and 2/4/6 once the empty slots have items.

**Why not keep its present strength.** The earlier draft of this section proposed
~19%, reasoning that the change should not feel like a nerf. That reasoning
treated `set.forester` as *the* set rather than as *the first* set: 19% of a 25%
ceiling leaves the second and third sets nowhere to go but sideways, and a ladder
whose bottom rung is three-quarters of the way up is not a ladder. The starter
outfit sits at the bottom, and the ceiling stays where later sets can reach it.

**A wearer scales what they wear.** The bonus applies to the set's *equipped*
members, so a player in three of the four pieces gets nothing from a four-piece
threshold — which is the only reading that makes a partial set a partial bonus.

---

## 5. Class identity, and why it waits

`spec-items.md` §5 measured the compromise: one shared set is worn by all three
classes — nothing restricts equipment by class anywhere in the data — and its
single spread delivers **81% of what a warrior's armour profile asks for, 86% of
an archer's and 75% of a mage's**. `EquipmentService.nominalStats` already names
the intended cure in its own comment: *"the class-identity flavour moves to sets,
where it can be expressed without distorting the budget of the piece it sits
on."*

**It cannot be expressed today, and the reason is worth stating precisely.** A
`gear_multiplier` is one scalar; it cannot tilt toward defence for a warrior and
crit for a mage. Expressing a tilt needs either

- a new effect case that names stats (`stat_multiplier`) — which still gives
  *everyone* the same tilt, so it fixes nothing on its own; or
- a class dimension in the bonus, which is a new axis in content and a new thing
  for the validator and the budget to bound.

**Deferred, and the better answer is probably neither.** With more than one set
in the game the tilt lives in *which set a player chooses* — a warrior's set, an
archer's set — which needs no new effect case, no class dimension, and no runtime
class check. That arrives with the second and third sets, after the rebalance.
The effect enum is a closed tagged union precisely so a case can be added later
and every consumer is forced to handle it.

---

## 6. What lands when

**Nothing in this document lands inside the rebalance**, and that is consistent
rather than convenient:

| change | where it lands | why not sooner |
|---|---|---|
| multiplier scales members, not the kit | with the gear ladder | it edits `EquipmentService.recomputeBonuses` — live combat code, and a mechanism |
| the cap covers multipliers | with the above | a cap cannot be written before what it caps is defined |
| the Forester bonus becomes a single ×1.07 at four pieces | with the above | flat→multiplier is one change with the two rows above it |
| a second and third set, and the class tilt | after the ladder | new items, ruled out by `spec-items.md` §1 |

**What the rebalance gets from this document is that the decisions are already
taken and already measured** — so the ladder package is a build rather than a
design, and nobody writes the naive multiplier first and discovers §2 afterwards.

Nothing is exposed in the meantime: no set uses `gear_multiplier`, and the flat
bonus is stable at 23% for exactly as long as the set does not climb.

---

## 7. Decisions (approved 2026-08-31; §4 settled 2026-09-01)

**A `gear_multiplier` scales the set's own equipped members, not the wearer's
whole kit.** Today it scales everything, so the same ×1.05 costs 8% of the
members' budget at level 1 and 33% at level 40 — the mirror of the flat bonus's
rot, and the same underlying defect. Inert to change: no set uses the case.

**The 25% cap is extended to multipliers**, costed as
`(factor − 1) × members' spent points` and summed with the flat spend. With the
decision above that cost is level-independent, which is what makes one ceiling
meaningful — under the current one, ×1.24 on the Forester set.

**Set strength is a ladder whose top rung is the 25% ceiling**, independent of
the members' item level: the rung sets the share of the ceiling, item level sets
what that share is worth. **The Forester set is the first rung and the weakest —
a single four-piece threshold at ×1.07, 29% of the ceiling** — written from
scratch under the freedom granted in `spec-items.md` §5. It is deliberately not
its present 23%: a starter outfit that claims three-quarters of the ceiling
leaves later sets nowhere to climb.

**Six-piece thresholds are not designed** — they are unreachable until
`off_hand` and the accessories have items, and they unblock with those slots.

**The class tilt waits for the second and third sets**, where it is expressed by
*which set a player wears* rather than by a new effect case or a class dimension
in content.

**All of it ships with the gear ladder, after the rebalance** (§6).

---

## 8. What this spec does NOT cover

- What a set is *made of* — its members, their slots and their item levels are
  `spec-items.md`.
- What a set is worth in silver, and what drops or sells one — `spec-economy.md`.
- Enchanting. It scales a single item's own stats and is bounded separately;
  a set bonus and an enchant do not interact beyond both being multipliers.
