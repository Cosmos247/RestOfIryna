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
| `recipe.forester_hood`      | 2× 🟫 Hide | 🪖 Forester's Hood (`gear.forester_hood`)         | helmet | +1 DEF |
| `recipe.forester_jerkin`    | 6× 🟫 Hide | 🦺 Forester's Jerkin (`gear.forester_jerkin`)     | chest  | +3 DEF |
| `recipe.forester_breeches`  | 5× 🟫 Hide | 👖 Forester's Breeches (`gear.forester_breeches`) | legs   | +2 DEF |
| `recipe.forester_boots`     | 3× 🟫 Hide | 🥾 Forester's Boots (`gear.forester_boots`)       | boots  | +1 DEF, +1 dodge |

**Full suit:** 16× hide → +7 DEF / +1 dodge.

### 🍳 Kitchen — cooked food (Phase 5.2.1)

Recipes in this category are **gated by `LearnedRecipe`** — they only appear in the Kitchen UI if the player has learned them via a recipe-scroll artifact (`artifact.recipe.<dish_id>`, non-stackable, used through the "📖 Learn" button in the inventory). Two starter recipes (Baked Potato + Roasted Meat) are auto-granted at registration so the Kitchen is never empty for new players.

Hunger / HP effects scale with ingredient count: 1-ingredient dishes restore hunger only; 3+ ingredient dishes also restore some HP. The biggest dish stays below the Small Healing Potion (+30 HP) so food doesn't displace potions.

| Recipe id | Inputs | Output | Hunger | HP | Auto-learned? |
|---|---|---|---|---|---|
| `recipe.baked_potato`       | 2× 🥔 Potato | 🍠 Baked Potato (`food.baked_potato`)             | +20 | — | ✅ starter |
| `recipe.roasted_meat`       | 2× 🥩 Raw Meat | 🍗 Roasted Meat (`food.roasted_meat`)           | +25 | — | ✅ starter |
| `recipe.foragers_omelette`  | 2× 🥚 Egg + 2× 🌰 Nuts + 1× 🫐 Berries | 🍳 Forager's Omelette (`food.foragers_omelette`) | +35 | +5 | scroll |
| `recipe.hunters_stew`       | 2× 🥩 Meat + 2× 🥔 Potato + 1× 🥚 Egg | 🍲 Hunter's Stew (`food.hunters_stew`)           | +45 | +10 | scroll |
| `recipe.berry_tart`         | 4× 🫐 Berries + 2× 🌰 Nuts + 1× 🥚 Egg | 🥧 Forest Berry Tart (`food.berry_tart`)        | +35 | +12 | scroll |
| `recipe.governors_feast`    | 3× 🥩 Meat + 3× 🥔 Potato + 2× 🥚 Egg + 2× 🫐 Berries + 2× 🌰 Nuts | 🍽 Governor's Feast (`food.governors_feast`) | +70 | +20 | scroll |

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
