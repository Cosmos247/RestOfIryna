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

## Migration history

- `gear.leather_vest` (placeholder, +2 DEF) → `gear.forester_jerkin` (+3 DEF) via `RenameLeatherVest` (Phase 5.2). Existing rows in inventory + warehouse remap in place; no data loss.

## Future

- Kitchen recipes (cooked food) — separate `RecipeCategory.kitchen` once Phase 5.2 Kitchen lands.
- Weapon upgrade — Phase 5.2.2 (modify existing weapon item vs. consume to craft a new one).
- Blueprint learning — recipes unlock via drops / shop purchases instead of being globally available.
- Iron-tier armor — replaces parts of the Forester's set with `mat.iron_ingot`-based variants once Forge has the demand to justify ingot stockpiles.
