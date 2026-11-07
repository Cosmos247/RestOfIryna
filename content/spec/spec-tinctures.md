# Tinctures — the fortune teller's cauldron (2026-11-07)

**Status: DECIDED and BUILT 2026-11-07.** Swift, content, locales and two migrations (`AddSleepWard`, `AddVigorThrift`), content
schema **v32**, not deployed. It ships with a build and a restart, never a `/reload` first: a v31 binary refuses v32
content, and names are Lingo's.

## 1. What was asked

The owner: a place first — tinctures as a separate screen at the fortune teller, with her mentions saying so — then the
recipes, brewed from the plants (`spec-bestiary.md` §16) and the trophies (§15). «Покажи мені рецепти які ти вигадав.»
Mid-design: the game's word is «настоянка», never «зілля». At the last step: the recipes can be pinned to the notebook.

## 2. Decided (the owner)

<!-- generated: roi-content spec tinctures -->
| recipe | makes | inputs | brew 🪙 | effect |
|---|---|---|---|---|
| `recipe.tincture_small` | `potion.heal_small` | 1× `mat.herb_st_johns_wort` + 1× `mat.trophy_venom` | 10 | +25% of max HP |
| `recipe.tincture_medium` | `potion.heal_medium` | 2× `mat.herb_st_johns_wort` + 1× `mat.trophy_venom` | 30 | +50% of max HP |
| `recipe.tincture_thyme` | `potion.thyme` | 2× `mat.herb_thyme` + 1× `mat.trophy_fang` | 15 | +30% of the Vigor pool |
| `recipe.tincture_thyme_strong` | `potion.thyme_strong` | 3× `mat.herb_thyme` + 1× `mat.herb_wormwood` + 1× `mat.trophy_feather` | 30 | +30% of the Vigor pool · every Vigor cost −50% for 60 min |
| `recipe.tincture_sleep` | `potion.sleep` | 1× `mat.herb_pasque_flower` + 1× `mat.trophy_horn` | 40 | the next death leaves the bag |
<!-- /generated -->

1. **The place.** «🧪 Настоянки» on her screen, in both its states, opening in the same message; no level or estate gate.
   Not on a card's reveal, whose photo stays in chat. Her intro and Podil's caption name the tinctures.
2. **She brews**, at once, for a fee of 10–40 silver on top of the materials. Her fee is a new silver sink, printed by
   `spec economy`.
3. **Healing is a share of the bar, not a number.** The two items shipped at 30 and 60 HP, obtainable nowhere: 30 HP is
   18–26% of a level-5 bar and 8–11% of a level-30 one. 25% is about one hard fight at any level (§4).
4. **The two heals are alike** («на середню просто треба більше»): the same two ingredients, more of the plant, one drop
   of venom. A medium of two venoms was shown (once every 14 walks at any depth) and not taken. Venom comes only from
   the viper, about 0.14 a walk however deep it goes, while plants grow with the steps.
5. **Thyme is Vigor alone**: «Тільки 30% снаги», the owner's number. Shown and not taken: +20% with beasts' blows −15%,
   +40% with Vigor drain −50% for 30 min, +40% with XP +15%, +40% with attack +10%, and +60% alone. No timer. Its plant's
   card lost «Посилює захист».
6. **The Sleep Tincture lasts to the door or the first death**, no clock, over one hour. Drunk at home it waits for the
   next walk; it covers a whole 🏕 run.
7. **The bitter tincture (🌱 + 🪶, half the encounters) was not picked.** 🐾 Кіготь has no recipe.
8. **A tincture's icon is the flask and its plant** (the owner, on the test bot): 🧪🌼 for both heals, 🧪🌿, 🧪🌸. The bag's
   category stays 🧪.
9. **Міцна настоянка чебрецю, «все ж таки» — the same evening, the last change.** 3× 🌿 + 1× 🌱 + 1× 🪶, 30 🪙: +30% Vigor at once
   and every Vigor cost halved for an hour. The owner took the recommended recipe and the name, and added the +30% over the
   recommended drain alone. Shown and not taken: 2× 🌿 + 1× 🌱 + 1× 🪶, and 3× 🌿 + 1× 🐾.
10. **«📌 У нотатник» on every card.** A note is its own kind, `tincture`: it counts the bag and names her fee. It is done
   the first time the recipe is brewed, like a dish's note.

## 3. How it plays

- **List → card → brew.** The list is buttons, because every screen here is a caption edit of her photo. The card prints
  the description, the effect, each input as a `RequirementLine` counted in the BAG alone (the capital has no warehouse,
  auto-memory `project-master-draws-from-bag`), and the fee. A shortage is the usual modal; the card stays.
- **The brew** is `TinctureService.brew`: `CraftMath` with the warehouse left out of both sides, then the drains, the
  output and the fee in ONE transaction, on a row loaded inside it and copied onto the session after the commit. It feeds
  no decree and no job: she made it.
- **Drinking** is the dish's flow: the card's «🍷 Використати», at home, in town or on a walk; never in a fight, which has no
  bag. A share is read off the pool as it stands (`MealMath.share`, half up, at least a point) and clamped by the pool. No
  many-portion button: `vigorPerPortion` reads flat restores alone. A tincture that would restore nothing is refused like a
  dish, and a ward already up answers in its own words.
- **The ward** is `User.sleepWard`. `InventoryEntry.wipeOnDeath` spends it and takes nothing, for both death paths; the death
  screen and the 🏕 report say so, and both name what came home: «Принесено:» under the death screen (`renderBrought`, the door's
  own list, the owner on the test bot), «Принесено» in the report. Wear, HP 1 and the unbanked depth stay. The
  door lets it go: `handleHomeReached` when the walk left the gate at all, `finalizeAndPush` for a 🏕 run. The forest edge's
  armour warning falls silent under it, and the profile prints a line while it stands (no clock runs on it, and nothing else
  would say so). A holiday's gate still lists the bag (`deathPreview`); no holiday is scheduled.
- **The thrift** is stamped on the player at the drink (`vigorThriftPercent`, `vigorThriftUntil`), so a `/reload` cannot change a
  running bottle. `VigorService.drain` applies it last, on top of the stance and the card, through `MealMath.thriftedCost`, and it
  reaches a 🏕 run while the hour lasts. **Half is the only honest number:** costs are 1–5 and round half up, so ×0.75 leaves a step
  and a blow at 2 (`tincture.thrift_moves_nothing` refuses it). A cost never rounds to nothing, or the Chariot would make a Defend
  free; under the Chariot or the Hanged Man it adds nothing on a step or a blow. A second bottle is refused while one runs, whatever
  its Vigor half could restore: it neither stacks nor restarts the hour. The profile prints the name, the clock and the line.
- **The governor never drinks one.** `eatOne` rations `food` alone: every recipe costs a rare plant and a trophy.
- The trader buys none; a tincture is stackable, so the market and the guild vault take it.

## 4. Measured (2026-11-07)

On a scratch copy of `ROIContent` + `ROISim` with the game's own `FightSimulator`, 40,000 fights a row, no techniques. Model
characters, not live players: the weapon at its level's rung, the Master's armour at +0 / +1 / +3, the estate at 2 / 3 / 5.

| | warrior | archer | mage | a hard fight takes |
|---|---|---|---|---|
| L5: max HP · Small · Medium | 165 · 41 · 83 | 128 · 32 · 64 | 116 · 29 · 58 | 26–33% of the bar (moose) |
| L10 | 209 · 52 · 105 | 164 · 41 · 82 | 149 · 37 · 75 | 20–26% (rabid wolf) |
| L20 | 304 · 76 · 152 | 242 · 61 · 121 | 221 · 55 · 111 | 26–33% (rabid bear) |

Thyme at 30%: +38 at L5, +45 at L10, +60 at L20, +75 at L30. A walk costs 104–111 Vigor at L5 to km 10, 191–209 at L10 to km 20,
239–251 at L20 to km 30; under the thrift 52–56, 96–104 and 119–125.

**The thrift's cost, stated once.** At a step of 1 pacing over cleared km nearly pays for itself in finds (0.84–1.2 Vigor a step,
`.memory/rebalance.md`'s reading of 2026-11-03). What holds it back is the hour, the bag's room and a recipe that needs a trophy from a
fight. The Chariot gives the same for six hours, by chance. Its effect on the pace to L40 was not measured: `simulate` sees no
tincture.

**A multiplier on DEF barely registers.** Armour absorbs 19–24% of a blow, so DEF ×1.2 is −3–5% damage and ×1.5 −9–11%, which
is why the −15% that was offered cut the blow itself. Any later defensive tincture has to do the same.

**Supply**, computed from the data with no 🏕 runs: a walk to km 10 and back is 20 steps and 9.2 fights, 0.6 plants and 0.46
trophies. That brews about 0.4 tinctures a walk: about one a day at 25 fights, 4–14 a day at the busiest 105–350.

`simulate --strict`: 0 broken bands, 15 warnings, as before. `spec opening` unchanged: both read flat restores.

## 5. Left open

- 🐾 Кіготь has no recipe; the trader still buys no plant and no trophy.
- The wormwood's card promises appetite and a cure for poison, and the game has no poison. Left as it stands.
- The plants thinned the Fool's +20% loot (`spec-bestiary.md` §16.3), raised and not decided.
- A 🏕 governor plans his road at the full step cost (`walkCost` in `PassiveExpeditionService`), so under the thrift he eats and
  turns earlier than he must, as he already does under the Chariot. On the safe side; raised, not decided.

## 6. What checks it

`TinctureTests` pins the owner's numbers and shows each rule failing on a copy of the bundle broken on purpose:
`tincture.fee_missing`, `tincture.fee_unread`, `tincture.output_not_a_tincture`, `tincture.effect_off_a_tincture`,
`tincture.percent_range`, `tincture.thrift_moves_nothing`, `tincture.thrift_no_duration`. It also pins the share's rounding, both locales' names and the retired word. **The brew, the drink and
the wipe live in the bot target, which that suite cannot reach**: `TODO.md` → the walk block carries them.

The digest names the fee and the three effect kinds in `records`.
