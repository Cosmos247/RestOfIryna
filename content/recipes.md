# Workshop Recipes

Static crafting catalog used by `Swift/Models/Recipe.swift` (`RecipeCatalog`). All recipes are code-based — no DB rows.

## Source-pool rules

- Inputs are pulled from the **combined inventory + warehouse pool**, inventory first (to free backpack slots) and warehouse for any shortfall.
- Output always lands in the **inventory** so the player can equip it immediately.
- For non-stackable gear output, the slot accept-check accounts for slots that *would* be freed by the inventory drain — a 50/50 bag won't refuse spuriously when it would have made room by consuming the inputs.

## Categories

### 🔥 Forge — smelting and metalwork

| Recipe id | Inputs | Output | Notes |
|---|---|---|---|
| `recipe.iron_ingot` | 10× 🔩 Iron Lump (`mat.iron`) | 1× 🔳 Iron Ingot (`mat.iron_ingot`) | Base material for any future iron gear |

### 🧵 Tannery — leather armor

The **Forester's** set — first craftable armor. Uses hide drops from wild kills (boar / moose / buffalo / bear) and rabid kills (lynx / wolf / rabid bear). Costs scale with piece size.

| Recipe id | Inputs | Output | Slot | Stats |
|---|---|---|---|---|
| `recipe.forester_hood` | 5× 🟫 Hide | 🪖 Forester's Hood (`gear.forester_hood`)         | helmet | +1 DEF |
| `recipe.forester_jerkin` | 15× 🟫 Hide + 4× 🔩 Iron | 🦺 Forester's Jerkin (`gear.forester_jerkin`)     | chest  | +3 DEF |
| `recipe.forester_breeches` | 12× 🟫 Hide + 2× 🔩 Iron | 👖 Forester's Breeches (`gear.forester_breeches`) | legs   | +2 DEF |
| `recipe.forester_boots` | 8× 🟫 Hide + 2× 🔩 Iron | 🥾 Forester's Boots (`gear.forester_boots`)       | boots  | +1 DEF, +1 dodge |

**Full suit:** 40× hide + 8× iron → +7 DEF / +1 dodge. (Raised from the original 16-hide cost on 2026-05-22 so crafting stays cheaper than buying from the Master, without being near-free.)

### 🍳 Kitchen — cooked food (Phase 5.2.1)

Recipes in this category are **gated by `LearnedRecipe`** — they only appear in the Kitchen UI if the player has learned them, with three exceptions: **Baked Potato, Roasted Meat and the Forager's Omelette are always available** (gated through `RecipeCatalog.starterRecipeIds` rather than a learned-set row, and no scroll exists for them). Every player can cook those three from day one — the Kitchen UI unions the always-available set with whatever the player has learned.

**A dish restores exactly the trader buy-price of its ingredients, in Vigor** (2026-09-18). A berry or a nut costs 2 silver, a board 4, a potato or a duck egg 6, raw meat 10 — so a Hunter's Stew of 2 meat + 2 potato + 1 egg + 1 board costs 42 silver and restores 42. The rule replaced a ladder where the cheap dishes paid ~0.9 Vigor per silver of ingredients and the expensive ones ~0.48: the economy of scale ran backwards, and the more a dish cost the worse its return. **Price a new dish's inputs; do not pick its number.**

Three things are edible as found: **a berry at +4, a nut at +5 and a duck egg at +3** — the egg deliberately below both, because it costs 6 silver against their 2 and would otherwise be the most Vigor-efficient food in the game (it was, at +7, until 2026-09-18). Potato and raw meat restore nothing at all until cooked. That is what leaves a dish a clean gain over its own ingredients: the cheap forage is worth 2.0–2.5 Vigor per silver against a dish's 1.0, so every berry and nut a recipe eats costs it margin, while a potato, an egg or a cut of meat costs it almost none.

**The Forest Pie is the dish that formula nearly breaks**, and the fix is worth remembering: its margin is `4 + 3·eggs + 6·potato + 10·meat − 2·berries − 3·nuts`, so with three berries and two nuts it needs **three eggs** to clear its own ingredients at all (+1). Cutting the forage instead would have worked too, but a pie with two berries is not a pie. A dish built mostly out of cheap forage always lands near zero; carry it with an ingredient that is worth nothing raw.

**HP follows the same price, at a quarter of it** (2026-09-18). The three always-available dishes restore Vigor only; every learned dish also restores `price / 4` HP, so a 72-silver Feast heals 18. The biggest one stays below the Small Healing Potion (+30 HP) so food does not displace potions — except that **neither potion is obtainable in play today**: `potion.heal_small` and `potion.heal_medium` sit in `items.json` and in no shop, recipe, drop or forage table, which leaves cooked food the only heal that exists away from the estate.

Clay-Baked Meat is the only dish that eats a second non-food material: 1× 🧱 Wild Clay, foraged in the Old Wood and the Deepwood and nowhere else, which is what makes a T6 dish require walking deep rather than only tending the estate.

**Every kitchen recipe burns 1× 🪵 Pine Lumber for the cooking fire** — both for narrative authenticity (cooking on flame needs firewood) and as a soft cap on farm-cooking. Pine lumber comes from the Lumberyard plot or shallow-zone foraging.

| Recipe id | Inputs | Output | Vigor | HP | Unlock |
|---|---|---|---|---|---|
| `recipe.baked_potato`       | 1× 🥔 Potato + 1× 🪵 Pine Lumber | 🍠 Baked Potato (`food.baked_potato`)             | +10 | — | ✅ always available |
| `recipe.roasted_meat`       | 1× 🥩 Raw Meat + 1× 🪵 Pine Lumber | 🍗 Roasted Meat (`food.roasted_meat`)           | +14 | — | ✅ always available |
| `recipe.potato_pancakes`    | 1× 🥔 Potato + 1× 🥚 Egg + 1× 🪵 Lumber | 🥞 Potato Pancakes (`food.potato_pancakes`)      | +16 | +4 | innkeeper, estate T2 |
| `recipe.foragers_omelette`  | 1× 🥚 Egg + 1× 🪵 Lumber | 🍳 Forager's Omelette (`food.foragers_omelette`) | +10 | — | ✅ always available |
| `recipe.berry_tart`         | 3× 🫐 Berries + 2× 🌰 Nuts + 3× 🥚 Egg + 1× 🪵 Lumber | 🥧 Forest Pie (`food.berry_tart`)        | +32 | +8 | innkeeper, estate T3 |
| `recipe.meat_ragout`        | 2× 🥩 Meat + 2× 🥔 Potato + 1× 🌰 Nuts + 1× 🪵 Lumber | 🥘 Pot Roast (`food.meat_ragout`)             | +38 | +10 | innkeeper, estate T4 |
| `recipe.hunters_stew`       | 2× 🥩 Meat + 2× 🥔 Potato + 1× 🥚 Egg + 1× 🪵 Lumber | 🍲 Hunter's Stew (`food.hunters_stew`)           | +42 | +11 | innkeeper, estate T5 |
| `recipe.clay_baked_meat`    | 3× 🥩 Meat + 2× 🥔 Potato + 1× 🧱 Clay + 1× 🪵 Lumber | 🫕 Clay-Baked Meat (`food.clay_baked_meat`) | +50 | +13 | innkeeper, estate T6 |
| `recipe.governors_feast`    | 3× 🥩 Meat + 3× 🥔 Potato + 2× 🥚 Egg + 2× 🫐 Berries + 2× 🌰 Nuts + 1× 🪵 Lumber | 🍽 Governor's Feast (`food.governors_feast`) | +72 | +18 | innkeeper, estate T7 |

Raw ingredients, and what they are worth as found:
- 🫐 Forest Berries — +4 Vigor (2 silver)
- 🌰 Forest Nuts — +5 Vigor (2 silver)
- 🥚 Duck Egg — +3 Vigor (6 silver)
- 🥔 Potato — inedible raw, must be cooked (6 silver)
- 🥩 Raw Meat — inedible raw, must be cooked (10 silver)

#### How a recipe reaches a player (2026-09-18)

The ladder lives in `recipes.json` → `unlocks`, one rung per recipe:
`{recipeId, npc, minEstateTier}`. It rides on the NPC's **daily job**, so a
recipe is earned rather than handed out by the calendar.

1. The quest board quotes it before the player commits — `🎁 Нагорода: 🪙 30 ·
   🍗 25 Снаги · 📖 Рецепт: 🍲 Юшка мисливця` — and so does the journal, because
   both render `CapitalController.rewardPhrase`.
2. The player takes the job and finishes it. `QuestService.payOut` writes the
   `learned_recipes` row in the same step that moves the silver and Vigor, so
   there is one place where a payout can happen.
3. The innkeeper then speaks in a message of his own, separate from the
   `✅ Замовлення виконано` banner: `postStatusBanner` deletes the previous
   banner, and an NPC's line is not a status line. **The copy is per dish, not
   per mechanism** — the key is the recipe id plus `.taught`
   (`recipe.clay_baked_meat.taught`), so he says something different about every
   one, and `%{dish}` is offered to that line but may go unused. The validator
   refuses a rung whose line is missing in either locale, which is why the render
   site carries no fallback to rot.
4. **One rung per finished job**, lowest tier first. A player who built to T5
   without ever visiting the innkeeper owes four visits, not one payout.
5. The tier comes off the live `User.estateLevel`, not the row the job was taken
   on — building the kitchen mid-job pays out today.

Which rung is owed is `RecipeUnlockDTO.next`, and there is exactly one
implementation because the board quotes it before the player commits and the
payout acts on it afterwards. Ties inside a tier fall to file order, so the
ladder's order is content, like a quest pool's.

Cooking itself is unchanged: the Kitchen lists `starterRecipeIds` ∪ the learned
set, and `CraftingService.craft` drains inventory-first from the combined pool.

## Migration history

- `gear.leather_vest` (placeholder, +2 DEF) → `gear.forester_jerkin` (+3 DEF) via `RenameLeatherVest` (Phase 5.2). Existing rows in inventory + warehouse remap in place; no data loss.

## Future

- Kitchen recipes (cooked food) — separate `RecipeCategory.kitchen` once Phase 5.2 Kitchen lands.
- Weapon upgrade — Phase 5.2.2 (modify existing weapon item vs. consume to craft a new one).
- Blueprint learning — recipes unlock via drops / shop purchases instead of being globally available.
- Iron-tier armor — replaces parts of the Forester's set with `mat.iron_ingot`-based variants once Forge has the demand to justify ingot stockpiles.
