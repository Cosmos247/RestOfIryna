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

Recipes in this category are **gated by `LearnedRecipe`** — they only appear in the Kitchen UI if the player has learned them via a recipe-scroll artifact (`artifact.recipe.<dish_id>`, non-stackable, used through the "📖 Learn" button in the inventory), with one exception: **Baked Potato and Roasted Meat are always available** (gated through `RecipeCatalog.starterRecipeIds` rather than a learned-set row, no scroll exists for them). Every player can cook these two from day one — the Kitchen UI unions the always-available set with whatever the player has learned via scrolls.

Vigor / HP effects scale with ingredient count: 1-ingredient dishes restore vigor only; 3+ ingredient dishes also restore some HP. The biggest dish stays below the Small Healing Potion (+30 HP) so food doesn't displace potions.

**Every kitchen recipe burns 1× 🪵 Pine Lumber for the cooking fire** — both for narrative authenticity (cooking on flame needs firewood) and as a soft cap on farm-cooking. Pine lumber comes from the Lumberyard plot or shallow-zone foraging.

| Recipe id | Inputs | Output | Vigor | HP | Unlock |
|---|---|---|---|---|---|
| `recipe.baked_potato`       | 1× 🥔 Potato + 1× 🪵 Pine Lumber | 🍠 Baked Potato (`food.baked_potato`)             | +9  | — | ✅ always available |
| `recipe.roasted_meat`       | 1× 🥩 Raw Meat + 1× 🪵 Pine Lumber | 🍗 Roasted Meat (`food.roasted_meat`)           | +12 | — | ✅ always available |
| `recipe.foragers_omelette`  | 2× 🥚 Egg + 2× 🌰 Nuts + 1× 🫐 Berries + 1× 🪵 Lumber | 🍳 Forager's Omelette (`food.foragers_omelette`) | +16 | +3 | scroll |
| `recipe.hunters_stew`       | 2× 🥩 Meat + 2× 🥔 Potato + 1× 🥚 Egg + 1× 🪵 Lumber | 🍲 Hunter's Stew (`food.hunters_stew`)           | +20 | +5 | scroll |
| `recipe.meat_ragout`        | 2× 🥩 Meat + 2× 🥔 Potato + 1× 🌰 Nuts + 1× 🪵 Lumber | 🥘 Meat Ragout (`food.meat_ragout`)             | +18 | +4 | scroll |
| `recipe.berry_tart`         | 4× 🫐 Berries + 2× 🌰 Nuts + 1× 🥚 Egg + 1× 🪵 Lumber | 🥧 Forest Berry Tart (`food.berry_tart`)        | +16 | +6 | scroll |
| `recipe.governors_feast`    | 3× 🥩 Meat + 3× 🥔 Potato + 2× 🥚 Egg + 2× 🫐 Berries + 2× 🌰 Nuts + 1× 🪵 Lumber | 🍽 Governor's Feast (`food.governors_feast`) | +35 | +10 | scroll |

Raw ingredients (eaten as-is, foraged in the wilds):
- 🫐 Forest Berries — +4 vigor
- 🌰 Forest Nuts — +5 vigor
- 🥚 Duck Egg — +7 vigor
- 🥔 Potato — inedible raw, must be cooked
- 🥩 Raw Meat — inedible raw, must be cooked

#### Learn flow

1. Player finds (or buys, in future Capital quests) a `📜 Recipe: <Dish>` scroll → it lands in **Inventory → Artifacts**.
2. Tapping the row shows a `📖 Learn` button instead of the default `✨ Use`. Tap it.
3. On a fresh learn: scroll is consumed, recipe is added to the user's `learned_recipes` row set, an inline `✅ <Dish> — recipe learned` banner appears above the refreshed Artifacts list.
4. On a duplicate (already known): scroll stays in the bag, modal alert "📖 You already know this recipe" — tradeable in the future market once that ships.
5. Kitchen lists only learned recipes. Cooking is the same `CraftingService.craft` as Workshop — inventory-first input pool, output to inventory, `✅ Crafted ...` banner appended at the bottom of the detail screen.

## Migration history

- `gear.leather_vest` (placeholder, +2 DEF) → `gear.forester_jerkin` (+3 DEF) via `RenameLeatherVest` (Phase 5.2). Existing rows in inventory + warehouse remap in place; no data loss.

## Future

- Kitchen recipes (cooked food) — separate `RecipeCategory.kitchen` once Phase 5.2 Kitchen lands.
- Weapon upgrade — Phase 5.2.2 (modify existing weapon item vs. consume to craft a new one).
- Blueprint learning — recipes unlock via drops / shop purchases instead of being globally available.
- Iron-tier armor — replaces parts of the Forester's set with `mat.iron_ingot`-based variants once Forge has the demand to justify ingot stockpiles.
