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
| `enemy.wild_boar` | Wild Boar | 1 | Wild | 18 | 5 | 1 | 1–10 | meat ×1 @ 0.7 · hide ×1 @ 0.8 | 🐗 |
| `enemy.wild_moose` | Wild Moose | 2 | Wild | 32 | 8 | 2 | 6–15 | meat ×2 @ 0.8 · hide ×1 @ 0.7 | 🫎 |
| `enemy.wild_buffalo` | Wild Buffalo | 3 | Wild | 55 | 11 | 4 | 11–20 | meat ×2 @ 0.8 · hide ×1 @ 0.9 | 🦬 |
| `enemy.rabid_lynx` | Rabid Lynx | 3 | Rabid | 45 | 13 | 2 | 11–20 | hide ×1 @ 0.7 | 🐈‍⬛ |
| `enemy.rabid_wolf` | Rabid Wolf | 4 | Rabid | 70 | 15 | 4 | 16–25 | hide ×1 @ 0.8 | 🐺 |
| `enemy.wild_bear` | Wild Bear | 5 | Wild | 95 | 17 | 5 | 21–30 | meat ×2 @ 0.85 · hide ×1 @ 0.9 | 🐻 |
| `enemy.rabid_bear` | Rabid Bear | 6 | Rabid | 120 | 22 | 4 | 25–35 | hide ×2 @ 0.9 | 🐻‍❄️ |

## Tier summary

| Tier | Depth (km) | Roster | Notes |
|------|------------|--------|-------|
| T1 | 1–5 | wild_boar | First big game; reliable food source. |
| T2 | 6–10 | wild_boar (overlap), wild_moose | Mid-range hunting band. |
| T3 | 11–15 | wild_moose (overlap), wild_buffalo, rabid_lynx | Wild + rabid families both appear; first taste of the plague. |
| T4 | 16–20 | wild_buffalo (overlap), rabid_lynx (overlap), rabid_wolf | Heavy hostiles; rabid_wolf is the registration tutorial enemy. |
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

The rabid_wolf is the **registration tutorial enemy** — every player fights it before naming their estate (see `RegistrationController.startWolvesFight`).

## Stat scaling

Roughly weakest → strongest:

```
wild_boar < wild_moose < wild_buffalo < rabid_lynx < rabid_wolf < wild_bear < rabid_bear
   18/5/1     32/8/2     55/11/4        45/13/2     70/15/4      95/17/5     120/22/4
```

Rabid enemies trade DEF for ATK at their tier; wild enemies trade ATK for DEF and meat drops. T5 wild_bear breaks the pattern slightly — it's a wild animal with rabid-tier ATK, reflecting its raw "master of the forest" bulk. T6 rabid_bear restores the family pattern: highest ATK in the bestiary, hide-only loot.

## Adding a new enemy

1. Append a new `Enemy(...)` entry to `EnemyCatalog.all` in `Swift/Models/Enemy.swift`.
2. Add `enemy.<id>` locale keys to **both** `Localizations/en.json` and `Localizations/uk.json`.
3. Update this document — both the roster table and any tier/family summaries the new enemy affects.
4. If the loot drop references a new item, add it to `ItemCatalog` in `Swift/Models/Item.swift` first (and its locale keys).
5. `swift build` to verify; locale-key counts in `en.json` / `uk.json` must stay equal.
