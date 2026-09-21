# Content spec — The King's decrees

**Status: approved 2026-09-21.** The linear tutorial spine, designed across the
2026-09-20 and 09-21 sessions and signed off decree by decree.

The King already speaks to the player in person: registration step 4
(`RegistrationController.promptKingOath`) hands over the charter, the estate and
the class weapon and ends with *"Очистіть землю, збудуйте стіни та поверніть
Артанії її колишню велич!"* This chain is the rest of that sentence. No herald,
no second messenger — the first decree arrives as the scroll the King already
gave.

**Every number below is PRINTED by the code that owns it**, not typed here:

```
swift run roi-content spec king
```

Re-run it after touching `content/data/king.json` and paste the result back.

---

## 1. What the chain is

A **linear chain of 39 decrees**, levels 1 to 25. The player holds exactly one at
a time; turning it in opens the next. Two kinds, interleaved:

- **Task decrees** (32) — do a thing: walk, kill, build, craft, upgrade.
- **Level decrees** (7) — reach a level. Only the six levels that unlock an
  estate tier (4, 7, 10, 13, 16, 19) carry one, plus the finale at 25. A level
  that unlocks nothing gets no decree, because a step that pays nothing is a
  screen the player taps through for nothing.

**Array order is the order the player walks it.** The `king` digest replays the
chain in order for exactly that reason: reordering two decrees leaves every id
and every reward identical while changing what the player meets first.

**There is no "decree N of 39" counter on any screen** (2026-09-21, the owner's
call): the player does not need to know where they are in a list, only what is
in front of them.

**After the 39th the King falls silent.** Nothing new unlocks between levels 21
and 40, so there is nothing for a decree to point at; the chain is extended when
that stops being true, not before.

## 2. What it pays, and the two rules the numbers obey

**The currency follows the level.** Vigor and food up to 16, silver and XP after
it — the pool is the binding constraint early and irrelevant late, where a level
costs hundreds of thousands of XP instead.

**No decree pays more Vigor than the pool at its level can hold.** A grant runs
through `min(maxVigor, vigor + reward)`, so anything above the pool is a number
the player is shown and never receives. The 2026-09-20 draft broke this three
times (🔋150 of a 180 pool, 🔋200 of 195, 🔋300 of 225); `ContentValidator`
refuses it now, and warns above 60% of the pool, where a reward only lands in
full on a nearly empty bar.

**Food is named, not counted as "portions".** A dish is worth anywhere from 10
to 72 Vigor, so a portion count cannot be added to anything — the design draft's
"59 portions" was a total nobody could check. The chain pays 🍗 `food.roasted_meat`
(14 Vigor) up to level 7 and 🍲 `food.hunters_stew` (42) after it.

## 3. The chain

<!-- generated: roi-content spec king -->

**The chain** (`king.json`) — 👑 marks a decree that asks for a level

| # | id | L | conditions | 🔋 | % pool | 🍲 | 🪙 | ✨ |
|---|---|---|---|---|---|---|---|---|
| 1 | `king.step_out` | 1 | reach km 3 | 25 | 24% |  |  |  |
| 2 | `king.first_blood` | 1 | 5 beasts | 25 | 24% | 2× `food.roasted_meat` |  |  |
| 3 | `king.present_yourself` | 2 | arrive in the capital |  |  |  | 60 |  |
| 4 | `king.honest_scales` | 2 | sell to the Trader |  |  |  | 40 |  |
| 5 | `king.work_will_be_found` | 2 | turn in an NPC job | 30 | 27% |  |  |  |
| 6 | `king.deeper_in` | 3 | reach km 7 | 30 | 26% |  |  |  |
| 7 | `king.catch_by_weight` | 3 | 10 beasts | 40 | 35% |  |  | 150 |
| 8 | `king.forest_feeds` | 3 | warehouse 15× `mat.pine_lumber` 15× `mat.river_pebble` 5× `mat.hide` | 40 | 35% |  |  |  |
| 9 | 👑 `king.worthy_steward` | 4 | level 4 | 30 | 25% | 2× `food.roasted_meat` | 50 |  |
| 10 | `king.own_home` | 4 | estate T2 | 60 | 50% |  |  |  |
| 11 | `king.sharp_edge` | 4 | weapon T2 | 40 | 33% |  |  |  |
| 12 | `king.fire_in_the_hearth` | 4 | cook a dish |  |  | 3× `food.roasted_meat` |  |  |
| 13 | `king.first_ground` | 4 | claim a plot | 40 | 33% |  |  |  |
| 14 | `king.harvest` | 4 | harvest a plot |  |  |  | 100 |  |
| 15 | `king.while_youre_away` | 5 | send a passive expedition | 50 | 40% |  |  |  |
| 16 | `king.stone_and_iron` | 5 | warehouse 10× `mat.iron` |  |  | 3× `food.roasted_meat` | 120 |  |
| 17 | `king.full_storeroom` | 6 | warehouse 40× `mat.pine_lumber` 40× `mat.river_pebble` 10× `mat.hide` | 60 | 46% |  |  |  |
| 18 | 👑 `king.strength_of_a_steward` | 7 | level 7 | 45 | 33% | 2× `food.roasted_meat` |  |  |
| 19 | `king.second_step` | 7 | estate T3 | 65 | 48% |  |  |  |
| 20 | `king.tempered_steel` | 8 | weapon T3 | 70 | 50% |  |  |  |
| 21 | `king.more_on_the_shoulders` | 8 | bag T2 | 70 | 50% |  |  |  |
| 22 | `king.hands_of_a_master` | 8 | craft anything |  |  |  | 100 |  |
| 23 | `king.science_of_battle` | 9 | claim `training_ground` | 60 | 41% |  |  |  |
| 24 | `king.first_technique` | 9 | learn a technique |  |  | 3× `food.hunters_stew` |  |  |
| 25 | 👑 `king.maturity` | 10 | level 10 | 45 | 30% | 2× `food.roasted_meat` |  |  |
| 26 | `king.third_step` | 10 | estate T4 | 75 | 50% |  | 150 |  |
| 27 | `king.forged_facets` | 11 | weapon T4 | 80 | 52% |  |  |  |
| 28 | `king.travelling_sack` | 11 | bag T3 | 80 | 52% |  |  |  |
| 29 | 👑 `king.tempered_will` | 13 | level 13 | 60 | 36% | 3× `food.hunters_stew` |  |  |
| 30 | `king.fourth_step` | 13 | estate T5 | 80 | 48% |  |  |  |
| 31 | `king.royal_steel` | 14 | weapon T5 | 85 | 50% |  |  |  |
| 32 | `king.stewards_train` | 15 | bag T4 | 85 | 49% |  |  |  |
| 33 | `king.the_lists` | 15 | win a duel |  |  |  | 300 | 8670 |
| 34 | 👑 `king.seasoned_steward` | 16 | level 16 | 75 | 42% |  |  |  |
| 35 | `king.fifth_step` | 16 | estate T6 |  |  |  | 200 |  |
| 36 | `king.the_wildwood` | 17 | reach km 26 |  |  |  | 400 | 19660 |
| 37 | 👑 `king.right_hand_of_the_crown` | 19 | level 19 | 75 | 38% |  |  |  |
| 38 | `king.sixth_step` | 19 | estate T7 |  |  |  | 300 |  |
| 39 | 👑 `king.pillar_of_the_crown` | 25 | level 25 + bag T6 |  |  |  | 1000 | 116960 |

**What the chain pays**

| | 🔋 Vigor | food | food as Vigor | Vigor-equivalent | 🪙 silver | ✨ XP |
|---|---|---|---|---|---|---|
| task decrees | 1190 | | | | 1770 | 28480 |
| level decrees | 330 | | | | 1050 | 116960 |
| **total** | **1520** | 6× `food.hunters_stew`, 14× `food.roasted_meat` | 448 | **1968** | **2820** | **145440** |

39 decrees · 7 of them ask for a level · the chain pays 5.8% of the XP from level 1 to 25 (2491517)

<!-- /generated -->

## 4. What is deliberately not here

**Two decrees were cut on 2026-09-21** and are recorded so they are not
reinvented:

- **"Wear something in every slot"** — unreachable. `EquipmentSlot` has eight
  cases and `items.json` has items for five of them: three `main_hand` and one
  each for helmet, chest, legs and boots. There is no off-hand item and no
  accessory item in the game at all. It comes back when the wardrobe covers the
  slots.
- **"Join or found a guild"** — the owner's cut, not a mechanical one. Worth
  knowing: the guild is now the only shipped system the chain never points at.

**Descriptions and names are not authored yet.** `king.<id>.name` / `.desc` land
in both locales with the screens that render them, and the `requireKey` calls
land with them too — a key the validator requires but nothing renders is the
defect this project has already shipped once.

## 5. What still has to be built

This document and `king.json` are the content half. Still open, in order:

1. **The palace** — a location on Castle Street. It does not exist yet: no
   controller, no locale keys, no artwork. The street's body text mentions it
   only as scenery.
2. **Progress storage** — one row per player, a migration, and the counters the
   event-based conditions need.
3. **Four new hooks** — an NPC job turned in, a dish cooked, a passive
   expedition sent, anything crafted. `beast_kills` reuses the counter that
   already exists; everything else is a state read.
4. **The journal** — decrees 1 and 2 land before the capital is reachable, so
   the 📓 Нотатник is where they live until the palace opens.
5. **The charter** — one message after `registration.complete`, carrying the
   first decree.
