# Bestiary

Reference for every enemy in `Swift/Models/Enemy.swift` (`EnemyCatalog`). Stats are tuned against Phase 4 combat — the player's effective ATK/DEF + class techniques shape what's "fair" at each tier. Adjust here, then mirror in `Enemy.swift`.

Two families share the wilderness:

- **Wild** — natural game. Killable, edible. Loot tables include both `food.raw_meat` and `mat.hide`.
- **Rabid** — Beastfever-twisted predators. Meat is poisoned by the plague, so loot tables yield `mat.hide` only.

Tier maps to a 5-km depth band (T1 = km 1–5, T2 = 6–10, T3 = 11–15, T4 = 16–20, T5 = 21–30, T6 = 26–35). `pickFor(kmDepth:)` randomly picks any enemy whose `depthRange` contains the player's km — most animals overlap two consecutive tiers. Three deep-zone overlaps stack: rabid_wolf (16–25) ↔ wild_bear (21–30) ↔ rabid_bear (25–35).

---

## Roster

| ID | Name | Tier | Family | HP | ATK | DEF | Depth | Loot | Icon |
|----|------|------|--------|----|-----|-----|-------|------|------|
| `enemy.wild_boar` | Wild Boar | 1 | Wild | 18 | 14 | 1 | 1–10 | meat ×1 @ 0.7 · hide ×1 @ 0.8 | 🐗 |
| `enemy.wild_moose` | Wild Moose | 2 | Wild | 32 | 18 | 2 | 6–15 | meat ×2 @ 0.8 · hide ×1 @ 0.7 | 🫎 |
| `enemy.wild_buffalo` | Wild Buffalo | 3 | Wild | 55 | 23 | 4 | 11–20 | meat ×2 @ 0.8 · hide ×1 @ 0.9 | 🦬 |
| `enemy.rabid_lynx` | Rabid Lynx | 3 | Rabid | 45 | 25 | 2 | 11–20 | hide ×1 @ 0.7 | 🐈‍⬛ |
| `enemy.rabid_wolf` | Rabid Wolf | 4 | Rabid | 70 | 28 | 4 | 16–25 | hide ×1 @ 0.8 | 🐺 |
| `enemy.wild_bear` | Wild Bear | 5 | Wild | 95 | 32 | 5 | 21–30 | meat ×2 @ 0.85 · hide ×1 @ 0.9 | 🐻 |
| `enemy.rabid_bear` | Rabid Bear | 6 | Rabid | 120 | 38 | 4 | 25–35 | hide ×2 @ 0.9 | 🐻‍❄️ |

> **ATK rebalance (2026-05-15)**: bestiary ATK roughly doubled across all tiers (T1 5 → 14, T6 22 → 38). Old numbers were tuned before the player's effective DEF stabilized — a fresh L1 Warrior (DEF 12) used to take 1 HP from the boar (`max(1, 5-12)`), making early combat trivial and flee-fail penalty meaningless. New numbers put per-hit damage at 2-3% HP for the warrior vs T1 enemies and ~10% for the mage, scaling up to ~22% / ~40% at T6. Flee-fail now uses the player's effective DEF at 50% (`halvedDEF = player.effectiveDefense / 2`) to model "turned your back" — see `CombatController.onFlee`.

## Tier summary

| Tier | Depth (km) | Roster | Notes |
|------|------------|--------|-------|
| T1 | 1–5 | wild_boar | First big game; reliable food source. |
| T2 | 6–10 | wild_boar (overlap), wild_moose | Mid-range hunting band. |
| T3 | 11–15 | wild_moose (overlap), wild_buffalo, rabid_lynx | Wild + rabid families both appear; first taste of the plague. |
| T4 | 16–20 | wild_buffalo (overlap), rabid_lynx (overlap), rabid_wolf | Heavy hostiles. |
| T5 | 21–30 | rabid_wolf (overlap, 21–25), wild_bear, rabid_bear (overlap, 25–30) | Deep wilderness with overlapping families — wolves give way to bears across this band. |
| T6 | 26–35 | wild_bear (overlap, 26–30), rabid_bear | The deepest currently survivable zone. From km 31 onward only the rabid_bear remains. A dedicated boss encounter is reserved for Phase 3.5 once the boss-fight mechanics are designed. |

## Family overview

### Wild family 🐗 🫎 🦬 🐻


The wilderness hasn't fallen entirely. These animals are still themselves — defending territory, scrounging for food. Killing one yields:

- `food.raw_meat` (cooked at the Kitchen in Phase 5; raw is inedible — `consume.not_raw_edible` toast)
- `mat.hide` (crafting material)

Wild animals tend to have higher DEF (thick muscle/hide) and more meat per kill at the upper tiers.

### Rabid family 🐈‍⬛ 🐺 🐻‍❄️

Beastfever has ridden them down. Foaming, fearless, and unmistakably faster than their wild cousins. The meat carries the plague and can't be eaten — loot tables drop `mat.hide` only. They compensate with higher ATK and lower DEF: glass cannons.

The **registration tutorial enemy is `enemy.rabid_dog`** (`RegistrationController`, which resolves it by id) — every player fights it before naming their estate. It is not rollable during exploration.

## Stat scaling

Roughly weakest → strongest (HP/ATK/DEF). **Numbers are generated from
`content/data/enemies.json`, which is the source of truth** — the Swift arrays
were retired in the rebalance, so never hand-edit this table.

```
wild_boar < wild_moose < wild_buffalo < rabid_lynx < rabid_wolf < wild_bear < rabid_bear
18/14/1   32/18/2   55/23/4   45/25/2   70/28/4   95/32/5   120/38/4
```

Rabid enemies trade DEF for ATK at their tier; wild enemies trade ATK for DEF and meat drops. T5 wild_bear breaks the pattern slightly — it's a wild animal with rabid-tier ATK, reflecting its raw "master of the forest" bulk. T6 rabid_bear restores the family pattern: highest ATK in the bestiary, hide-only loot.

## Non-rollable enemies

Two entries carry a `0...0` depth range, which `pickFor` can never match because
it clamps to `max(1, km)`. They are summoned by id instead:

| id | HP | ATK | DEF | Summoned by |
|---|---|---|---|---|
| `enemy.training_dummy` | 200 | 0 | 1 | Training Ground plot (consequence-free sparring) |
| `enemy.rabid_dog` | 18 | 14 | 1 | Registration tutorial fight |

## XP rewards

- `enemy.wild_boar` — 5 XP
- `enemy.wild_moose` — 12 XP
- `enemy.wild_buffalo` — 25 XP
- `enemy.rabid_lynx` — 25 XP
- `enemy.rabid_wolf` — 50 XP
- `enemy.wild_bear` — 100 XP
- `enemy.rabid_bear` — 175 XP

> ⚠️ These are **pre-rebalance** values and are scheduled for replacement in
> Phase 5 of the rebalance: `mobXP(L) = 26 · L^1.55 · archetypeMultiplier`.

## Adding a new enemy

The bestiary is **data**, not code. There is no Swift array to edit.

1. Append an entry to `content/data/enemies.json`.
2. Add the `enemy.<id>` key to **both** `Localizations/en.json` and `uk.json`.
3. Run `swift run roi-content validate --strict` — it checks referential
   integrity (every loot `itemId` must exist), range sanity, and that both
   locale keys are present.
4. Run `swift run RestOfIryna --content-digest` and confirm the change to the
   `spawns` half is the one you intended.

⚠️ **Declaration order is load-bearing.** `EnemyCatalog.pickFor` selects with
`filter().randomElement()`, so the position of an entry in the array decides
which enemy a given roll returns. Appending is safe; reordering silently
changes every encounter in the game. The content loader never sorts.

⚠️ **Adding an enemy to a depth band dilutes its neighbours.** Selection is
uniform among everything whose `depthRange` matches, so a new T3 mob drops each
existing T3 mob's spawn share. Weighted encounter tables land in Phase 5.

### Known bug, preserved deliberately

Past km 35 no `depthRange` matches and `pickFor` falls back to `all.first` —
every encounter becomes a wild boar. Fixing it belongs to the Phase 5 combat
rework; it was left untouched through the content migration so that migration
could be proven behaviour-neutral.
