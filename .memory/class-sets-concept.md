# Class sets — a parked concept (2026-10-05)

**Status: PARKED. Nothing here is approved, specified or built.** The owner asked for class sets
for higher-level players ("just the concept — show how you see their stats and the recipe"),
read this proposal, did not answer the four forks below, and said «Запамʼятай це на майбутнє, ми
до цього повернемось». Pick it up from the forks.

**Read this first — the armour got a ladder on 2026-10-06** (`content/spec/spec-items.md` §11),
after this concept was written, and four things below no longer stand as stated:
- **The Forester is not "the starter, levels 1–9".** The Master's enchant lifts it to item level
  25 at +5 (🛡55 ❤️83 💥20 💨15 for the set), by the weapon ladder's law at 75% of the growth. A
  class piece of rank I (item level 10) now competes with a Forester piece at +2.
- **The owner gates armour by PRICE, not by player level.** A gate a level was built with that
  ladder and refused: «замість обмеження рівнем … краще зробити просто велику вартість». §1's
  "appears at L10, reforged at L20 / L30 / L40" and §4's "the rank's level gates it" are that
  same level gate. Expect the question again, and lead with the price a rank would cost.
- **Ranks and the enchant are one axis.** Both raise a piece's item level. A class set needs one
  of: its own enchant steps past item level 25, ranks INSTEAD of an enchant, or ranks that are
  enchant levels under another name. The validator forces the choice:
  `master.enchant_level_changes_nothing` refuses armour authored at or above an enchant level's
  item level.
- **§3's fight table compares against the unenchanted Forester.** Against a Forester set at +4
  the class set's lead is its class profile, the off-hand and the set multiplier — not the whole
  +65–71%.

What still stands: the class profiles, the off-hand, the set multiplier on the set's own
members, the commission's shape and the forks on structure, off-hand and materials. The
Forester's flat set bonus now rots as its members are enchanted (`spec-sets.md` §2), which makes
the multiplier form more urgent, not less.

**It is not a spec.** Every number below came from a scratch script built from the formulas in
§6. When this becomes `content/spec/…`, the numbers must be printed by `roi-content spec`, never
typed — `CLAUDE.md` → "Content is specified before it is authored". Re-derive them then: the
budget tables or the weapon ladder may have moved.

---

## 1. The frame proposed

- **One branch per class, climbing like the sword.** The class piece appears at L10 and the
  Master reforges it at L20 / L30 / L40 (ranks I–IV). The Forester set stays the starter, levels
  1–9. The noun is kept across ranks and the epithet changes (`feedback-ladder-names-one-noun`):
  «Кольчуга вартового» → «Кольчуга лицаря».
- **Five pieces:** the four armour slots plus a class off-hand (shield / quiver / grimoire). The
  off-hand slot exists in `EquipmentSlot` and has never had an item.
- **Strength of a rank:** the item budget of its level at **75% of the growth**, the rule the
  owner chose for the weapon on 2026-10-04 (`spec-items.md` §9). The spread is the class profile
  `tuning/budget.json` → `classProfiles` already uses for the simulator's reference character, so
  the reference would become the real kit.
- **Set bonus:** `spec-sets.md`'s approved form — a multiplier on the set's OWN equipped members,
  never the kit:
  - 2 pieces ×1.05;
  - 4 pieces ×1.13 total;
  - 5 pieces ×1.19 total, which is 78% of the 25% ceiling.

  The Forester stays the bottom rung, at ×1.07 per the spec; it is still flat stats in
  `sets.json` today.
- **Durability:** 70 / 100 / 140 / 180 by rank; from L20 that matches the weapon at the same
  level. The off-hand does not wear, as today.

## 2. Stats per piece (75% growth, common rarity)

Icons: 🛡 DEF · ❤️ HP · 💥 crit · 💨 dodge · 🎯 accuracy (ratings, not percentages).

**🛡 Warrior — «Лицарська варта»** (ranks: вартового → лицаря → ветерана → королівської гвардії)

| piece | L10 | L20 | L30 | L40 |
|---|---|---|---|---|
| Шолом | 🛡8 ❤️9 | 🛡12 ❤️14 | 🛡17 ❤️19 | 🛡22 ❤️25 |
| Кольчуга | 🛡12 ❤️14 | 🛡20 ❤️22 | 🛡28 ❤️31 | 🛡35 ❤️40 |
| Поножі | 🛡10 ❤️11 | 🛡16 ❤️18 | 🛡22 ❤️25 | 🛡29 ❤️32 |
| Чоботи | 🛡7 ❤️8 | 🛡11 ❤️13 | 🛡15 ❤️17 | 🛡20 ❤️22 |
| Щит | 🛡8 ❤️14 | 🛡13 ❤️23 | 🛡19 ❤️32 | 🛡24 ❤️41 |
| **set ×1.19** | **🛡54 ❤️67** | **🛡86 ❤️107** | **🛡120 ❤️148** | **🛡155 ❤️190** |

**🏹 Archer — «Слідопит»** (ranks: слідопита → мисливця → ловчого → королівського стрільця)

| piece | L10 | L20 | L30 | L40 |
|---|---|---|---|---|
| Каптур | 🛡6 ❤️8 💨4 | 🛡9 ❤️13 💨6 | 🛡13 ❤️18 💨9 | 🛡16 ❤️23 💨11 |
| Куртка | 🛡9 ❤️12 💨6 | 🛡15 ❤️20 💨10 | 🛡20 ❤️28 💨14 | 🛡26 ❤️36 💨18 |
| Штани | 🛡7 ❤️10 💨5 | 🛡12 ❤️17 💨8 | 🛡17 ❤️23 💨11 | 🛡21 ❤️29 💨15 |
| Чоботи | 🛡5 ❤️7 💨3 | 🛡8 ❤️11 💨6 | 🛡12 ❤️16 💨8 | 🛡15 ❤️20 💨10 |
| Сагайдак | 💨12 🎯8 | 💨19 🎯12 | 💨26 🎯17 | 💨34 🎯22 |
| **set ×1.19** | **🛡32 ❤️44 💨36 🎯10** | **🛡52 ❤️73 💨58 🎯14** | **🛡74 ❤️101 💨81 🎯20** | **🛡93 ❤️129 💨105 🎯26** |

**🔮 Mage — «Мандрівник»** (ranks: учня → мандрівника → мудреця → архімага, matching the t9
«Посох архімага»)

| piece | L10 | L20 | L30 | L40 |
|---|---|---|---|---|
| Відлога | 🛡4 ❤️10 💥6 | 🛡7 ❤️17 💥9 | 🛡9 ❤️23 💥13 | 🛡12 ❤️29 💥16 |
| Мантія | 🛡7 ❤️16 💥9 | 🛡11 ❤️26 💥15 | 🛡15 ❤️37 💥21 | 🛡19 ❤️47 💥26 |
| Ноговиці | 🛡5 ❤️13 💥7 | 🛡9 ❤️21 💥12 | 🛡12 ❤️30 💥17 | 🛡15 ❤️38 💥21 |
| Черевики | 🛡4 ❤️9 💥5 | 🛡6 ❤️15 💥8 | 🛡8 ❤️21 💥12 | 🛡11 ❤️26 💥15 |
| Гримуар | ❤️21 💥12 | ❤️34 💥19 | ❤️48 💥26 | ❤️61 💥34 |
| **set ×1.19** | **🛡24 ❤️82 💥46** | **🛡39 ❤️134 💥75** | **🛡52 ❤️189 💥106** | **🛡68 ❤️239 💥133** |

For comparison, today's Forester set gives every class 🛡14 ❤️24 💥4 💨5 (with its flat bonus).
All names are drafts; copy waits for the owner.

## 3. What it does in a fight (L20, full set against today's Forester)

| class | HP | mitigation | crit chance | dodge chance |
|---|---|---|---|---|
| warrior | 272 → 355 | 17.9% → 36.1% | 10.0% → 8.9% | 7.3% → 5.5% |
| archer | 210 → 259 | 14.5% → 26.1% | 13.5% → 12.6% | 10.0% → 22.2% |
| mage | 189 → 299 | 12.7% → 21.0% | 16.3% → 26.1% | 8.4% → 6.6% |

- **Survivability:** effective HP after mitigation and dodge rises **+65–71%**, and the kit at L20
  goes from ~35% to ~80% of the on-curve budget.
- **The warrior's and mage's small losses** in crit and dodge are by design: their profiles carry
  neither stat, while the Forester did.
- **L30 shows the same shape:** warrior 339 → 463 HP and 16.3% → 36.1%; mage crit 16.8% → 27.2%.

## 4. The recipe proposed: a commission at the Master

**How it is bought.**
- **Per piece.** The Master draws from the BAG only (`CLAUDE.md` → "What a place can draw on is
  where it stands"), so the set is not one commission.
- **The rank's level gates it.**
- **Rank I could take the Forester piece of the same slot as an ingredient**, so a bought
  Forester is not wasted. Its enchant then needs a rule: a +5 Forester enchant was paid for a
  weak piece.

| rank | warrior | archer | mage | fee per set |
|---|---|---|---|---|
| I · L10 | 20🟫 8🔩 5🪵 | 30🟫 5🔩 5🪵 | 20🟫 5🔩 10🧱 10🪨 | 300🪙 |
| II · L20 | 30🟫 15🔩 4🔳 | 50🟫 10🔩 4🔳 | 25🟫 10🔩 4🔳 20🧱 20🪨 | 800🪙 |
| III · L30 | 50🟫 25🔩 9🔳 | 80🟫 15🔩 9🔳 | 40🟫 15🔩 9🔳 30🧱 30🪨 | 1,600🪙 |
| IV · L40 | 60🟫 35🔩 14🔳 | 100🟫 25🔩 14🔳 | 50🟫 25🔩 14🔳 40🧱 40🪨 | 2,500🪙 |

- **Value.** At the trader's buy prices (🟫 hide 6, 🔩 iron 20, 🔳 ingot 200, 🪵 lumber 4, 🧱 clay 4,
  🪨 pebble 2) the materials come to ≈300 / 1,300 / 2,600 / 3,900 🪙 per rank. They are kept
  equal across the three classes.
- **The whole branch** is ≈13,300 🪙, of which 5,200 is pure fee — a silver sink, which the
  economy wants (`spec-economy.md` §4).
- **Per piece** the set's materials split by slot weight: chest 27%, legs 22%, off-hand 20%,
  helmet 17%, boots 15%. Ingots go to the bigger pieces, because 0.7 of an ingot is not an
  input.
- **Why ingots carry the value.** The first draft priced high ranks in cheap materials, and the
  mage's rank-IV mantle alone came to ~93 units, more than a bag holds. The current largest
  single commission (mage IV mantle) is ≈46 units.
- **Optional trophies (fork 4):** warrior «Ріг тура» (wild aurochs, km 33–37); archer «Шкура
  рисі» (rabid lynx, km 21–25); mage «Ікло вовка» (rabid wolf, km 24–28). Rank IV would also need
  «Кіготь скаженого ведмедя» (km 39–49). These are new materials, loot entries and copy.

## 5. Open forks — the owner's, unanswered

My recommendation is listed first in each.

1. **Structure.**
   - **One piece climbing ranks** (15 items). Recommended: `spec-items.md` §4 already decided "a
     set is a ladder".
   - Two separate sets per class at L15 and L30 (30 items, no armour reforge mechanism).
   - One set per class at L20, growing only by enchant.
2. **Who may wear it.**
   - **Own class only** — the Master offers only your branch, and equipping refuses another
     class's piece, since a player trade can deliver one.
   - Anyone, with the tilt as a choice. This needs no class check, which `spec-sets.md` §5
     preferred.
3. **Off-hand.**
   - **Yes, five pieces** with a 2/4/5 bonus.
   - No, four armour pieces with a 2/4 bonus (×1.05 / ×1.13).
4. **Materials.**
   - **Existing materials only.**
   - Plus the class trophies of §4.

Smaller questions under them:
- the Forester piece as a rank-I ingredient, and what happens to its enchant;
- the durability ladder 70/100/140/180;
- the growth share (75% proposed; measure 100/75/50 as was done for the weapon).

## 6. How the numbers were computed (re-derive before any spec)

- **Budget of a piece at rank level L, 75% growth:**
  `w · (7.5 + 0.75 · 1.5 · (L − 1))`, with `w` the slot weight from `tuning/budget.json`
  (helmet 1.0, chest 1.6, legs 1.3, boots 0.9, off_hand 1.2). 7.5 is the item-level-1 budget,
  `base + perItemLevel`.
- **Stats:** `round(points × share × statPerPoint)`, schoolbook rounding — exactly
  `BudgetMath.spend`. The shares are `classProfiles[class].armour` and `.offHand`. Every piece was
  checked against the validator's allowance: points ≤ budget + Σ 0.5/rate.
- **Set row:** the five pieces summed, × 1.19, rounded.
- **Fight table:**
  - base stats are the class start × (1 + rate · (L − 1)), with rates 0.056 HP, 0.1 ATK and
    0.085 ratings and DEF;
  - the weapon is the rung its level allows;
  - mitigation and percentages use `CombatMath.mitigation` / `percent` with `combat.json` →
    `curves`;
  - effective HP = HP / (1 − mitigation) / (1 − dodge).

## 7. What has to happen before any of it is authored

1. **The bestiary re-solve ships with it.** This IS the gear ladder of `spec-items.md` §3, and the
   2026-08-31 decision ships the ladder and the bestiary regeneration together. Tier 2's stat lines
   were solved against the ~35–40% kit, so without a re-solve the forest becomes easy.
2. **`spec-sets.md`'s two built-later rules:** the multiplier on the set's own members (today
   `recomputeBonuses` multiplies the whole kit, weapon included), and the 25% cap extended to
   multipliers.
3. **Mechanics:**
   - an armour ladder (rank, item level, stats, durability, recipe and level gate per rung);
   - the Master's commission screen (the weapon lesson's shape);
   - a class gate if fork 2 says so;
   - the off-hand on the gear sheet.
4. **A repair price for pieces the Master does not sell.** Today that is `repairCost`'s `?? 30`
   fallback, an open item in `TODO.md`. Proposed: the commission's full value, which keeps a
   repaired point near the Forester jerkin's ~3 🪙.
5. **Re-measure the arena's class gap** (warrior 75–76%) with the sets on.
6. **A spec** in `content/spec/` with printed numbers, and copy approved by the owner.

Related: `content/spec/spec-items.md` §3–§4 and §9, `content/spec/spec-sets.md` §2–§5,
`content/spec/spec-economy.md` §4; auto-memory `project-class-sets-concept`,
`project-post-rebalance-package`, `project-durability-per-item`.
