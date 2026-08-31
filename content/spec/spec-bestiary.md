# Content spec — Bestiary

**Status: approved 2026-08-31.** Phase 9. The decisions are in §8; §7 was applied
in the same pass.

Scope: **levels 1–25**, the authored band fixed in `spec-progression.md`. Levels
26–40 stay a generated draft from the same archetype table.

Numbers are printed, never typed:

```
swift run roi-content spec bestiary --levels 1,5,11,14,21,25
```

---

## 1. The problem this spec exists to fix

The shipped roster is seven creatures, and the level↔km rule from
`spec-progression.md` (**an enemy of level N spawns from km N to km N+9**) shows
what that means in play:

| km | what can be met |
|---|---|
| 1–6 | **wild boar. Only the wild boar.** |
| 7–10 | boar, moose |
| 11–20 | three candidates |
| 21–29 | two |

The first six kilometres of the game — the part every player walks, and the only
part most will see on day one — contain **one animal, repeated**. Everything else
in this document follows from fixing that.

Two other holes, both already reported by the balance run:

- **The `boss` archetype has no members.** It is designed (12 rounds, 130% of a
  bar, ×9 XP, ×8 loot) and nothing in the game uses it.
- **Every shipped enemy carries ~50% of the HP and ATK its archetype asks for**
  (62% at level 1, 48% by 25). The roster was authored before the archetype
  table existed. This document therefore specifies **level, archetype and family
  — never HP**, so that the stat lines can be regenerated from the table without
  reopening it. *(Amended: that regeneration is deferred past the rebalance —
  see §9. The wardrobe turned out to be off-curve by the same factor, and the
  two are corrected together.)*

---

## 2. What a creature IS in this game

Three fields decide everything else:

- **level** — sets the whole stat line through `EnemyGenerator`, and (with the
  km rule) sets where it lives.
- **archetype** — how the fight FEELS: rounds, share of a bar, absorption, dodge,
  crit, and all reward multipliers. Six of them: `trash`, `normal`,
  `skirmisher`, `brute`, `elite`, `boss`.
- **family** — `wild` or `rabid`, from `content/lore.md` §8. Wild animals are
  clean: they drop meat and hide. Rabid ones carry Beastfever, their meat is
  poison, and they drop hide only.

Nothing else about a creature is a number a person chooses. Name, icon and
flavour are authored; HP, ATK, DEF, crit, dodge and XP are solved.

---

## 3. The roster — levels 1–25

**Decided: no new creatures.** The seven that exist are re-spread across the
whole path instead, overlapping at the edges of their bands. Nine invented
animals were on the table and were turned down; the wilderness gets denser by
rearranging what it already has, and new species wait until after the rebalance.

| L | id | EN | UA | family | archetype | km band | change |
|---|---|---|---|---|---|---|---|
| 1 | `enemy.wild_boar` | Wild Boar | Дикий кабан | wild | trash | 1–10 | — |
| 4 | `enemy.wild_moose` | Wild Moose | Лось | wild | normal | 4–13 | level 6 → 4 |
| 7 | `enemy.wild_buffalo` | Wild Bison | Зубр | wild | brute | 7–16 | level 11 → 7 |
| 10 | `enemy.rabid_lynx` | Rabid Lynx | Скажена рись | rabid | skirmisher | 10–19 | level 11 → 10 |
| 13 | `enemy.rabid_wolf` | Rabid Wolf | Скажений вовк | rabid | normal | 13–22 | level 16 → 13 |
| 16 | `enemy.wild_bear` | Brown Bear | Бурий ведмідь | wild | brute | 16–25 | level 21 → 16 |
| 22 | `enemy.rabid_bear` | Rabid Bear | Скажений ведмідь | rabid | elite | 22–31 | level 25 → 22 |

`enemy.rabid_dog` (the registration fight) and `enemy.training_dummy` keep their
`0…0` depth and never spawn. **No boss ships in this band** — see §5.

Only two things about a creature change: its **level**, and therefore its whole
generated stat line, and its **km band**, which follows from the level by the
rule in `spec-progression.md`. Family, archetype, name, icon and loot table are
untouched. `enemy.wild_buffalo`'s English string is corrected to Bison, which is
what the Ukrainian name and the lore already say; the id stays, because ids are a
database contract.

### Why this ladder and not another

The spacing was searched rather than chosen — every arrangement of seven
creatures that keeps the family ladders in order, respects the elite floor of
level 14 and actually ascends across the band. This one wins on the two things
that matter:

- **All four common archetypes are met by km 10.** trash at km 1, normal at 4,
  brute at 7, skirmisher at 10. The four ways a fight can go are all taught
  before the first technique unlocks at level 8.
- **The Blight thickens with depth, in the ratio rather than in a line of text.**
  Thicket (km 1–10): three wild to one rabid. Old Wood (11–25): three to three.
  The lynx reaching km 10 is the first sighting, right at the thicket's edge —
  which is exactly what `lore.md` means by "first sightings" in the middle band.

---

## 4. What that does to a walk

| km | candidates | archetypes on offer |
|---|---|---|
| 1–3 | 1 | trash |
| 4–6 | 2 | trash, normal |
| 7–9 | 3 | trash, normal, brute |
| 10–18 | 3–4 | + skirmisher, second normal |
| 19–21 | 3 | skirmisher, normal, brute |
| 22–25 | 2–3 | + **elite** |
| 26+ | 1 | elite only — the draft band starts here |

Average 2.6 candidates per kilometre against 2.2 shipped, and the improvement is
where it was needed: km 4–9 goes from one creature to three.

**The first three kilometres stay a single animal.** A creature covers km N…N+9,
so only a level-1 creature can appear at km 1, and there is exactly one of those.
Fixing that needs a second level-1 creature — which is a new animal, and new
animals are what this document just decided against. It is a tutorial, and it
lasts about five kills.

**The draft band shows through from km 26.** Only the rabid bear reaches past 31,
and nothing at all lives past km 40. That edge is the first thing Phase 10 fills,
and it is visible in the table rather than discovered in play.

## 5. Spawn weights, and the boss that is not here

Weight is inherited from the archetype (`trash` 100, `normal` 60, `skirmisher`
40, `brute` 25, `elite` 8, `boss` 1). **No creature in this roster overrides it**,
which is worth saying explicitly: rarity is expressed by the archetype a creature
belongs to, never by an absence from the table. The validator refuses a zero
weight for the same reason.

**The `boss` archetype still has no members, and that is now a decision rather
than a gap.** It is fully designed — 12 rounds, 130% of a bar, ×9 XP, ×8 loot,
level floor 14 — and it stays unused until after the rebalance, when what a boss
IS in this world can be decided with a played game rather than a spreadsheet.
The archetype row stays in `enemies.json` so the contract is ready; nothing
spawns against it.

## 6. Loot

The family decides the table; the archetype's `lootMultiplier` decides how much.

| family | drops |
|---|---|
| wild | `food.raw_meat` + `mat.hide` |
| rabid | `mat.hide` only — the meat carries Beastfever |

That rule is from `content/lore.md` §8 and the shipped tables already obey it.
Two things this spec deliberately does **not** decide:

- whether elites and the boss drop something a trash mob cannot (a trophy, a
  crafting material, a recipe scroll);
- what the drop quantities and chances are per level band.

*(Both went to `spec-economy.md` §5 rather than to the item spec, because the
answer turned out to be the archetype's `lootMultiplier` — wired to quantity,
with the loot tables re-normalised to a base in the same pass.)*

What it does decide: **every wild creature is food**, and that matters more than
it used to. Since Phase 8E removed Vigor regeneration, meat is one of the two
faucets that keep a player walking, and the ratio in §3 means the deeper the
player goes the less of the wilderness is edible.

**Checked rather than assumed.** Raw meat restores nothing — it is cooked into
roasted meat (1 meat + 1 lumber → 12 Vigor). Against the ~16.8 Vigor a kill
costs, including the walk to find it:

| creature | meat per kill | as Vigor | net |
|---|---|---|---|
| wild boar | 0.70 | 8.4 | **−8.4** |
| wild moose | 1.60 | 19.2 | **+2.4** |
| wild bison | 1.60 | 19.2 | **+2.4** |
| brown bear | 1.70 | 20.4 | **+3.6** |
| any rabid creature | 0 | 0 | **−16.8** |

So hunting clean game roughly pays for itself and killing a Blighted animal is a
pure loss. **The Blight starves the player as well as fighting them**, which is
the design working — but two consequences fall out of it that `spec-economy.md`
has to price rather than admire:

- **The boar is the exception and it is the first thing anyone meets.** One meat
  at 70% is 8.4 Vigor against a 16.8 Vigor fight, so the opening hours run at a
  loss until the moose appears. The roster re-spread in §3 shortens that stretch
  (moose to level 4) without closing it.
- **Past km 31 there is no meat at all** — only the rabid bear spawns there
  today. Combined with foraging that nets −0.5 Vigor per fresh room, the deepest
  zone in the game is currently a pure Vigor sink.

**And one knob that does nothing.** Every archetype declares a `lootMultiplier`
(trash 0.5 · normal 1.0 · skirmisher 1.2 · brute 1.7 · **elite 3.0** · **boss
8.0**). It is mapped into the domain and fingerprinted by the digest, and **no
award site reads it** — both loot paths go through `ExplorationService.rollLootDrops`,
which rolls each table row's own chance and nothing else. An elite therefore
drops exactly what a trash mob would, and a boss would too. Same class of defect
as the `silverReward` that had no curve: a field that looks like balance and is
not wired to anything. `spec-economy.md` decides whether it is wired up or
deleted.

---

## 7. One wilderness, three zones (applied)

The game described the same wilderness three different ways and no two agreed:
the lore's bands (1–10 / 10–20 / 20–35), the enemy bands (level N → km N…N+9)
and the foraging pools (1–2 / 3–5 / 6–49, written when the map ended at km 10).

**Decided and applied.** One ladder, three named zones:

| zone | km | what it is |
|---|---|---|
| `zone.thicket` — Гущавина | 1–10 | mixed pine and oak; the Blight is rumour |
| `zone.oldwood` — Старий ліс | 11–25 | pine-dominant; the first Blight-touched undergrowth |
| `zone.deepwood` — Пуща | 26–49 | old-growth oak; the Blight everywhere |

The authored band is now exactly the first two zones and the draft band exactly
the third. `zones.json` carries the new bands, and `lore.md` §7 was corrected to
match — its three art paragraphs map one-to-one, with the depths updated from a
world that still ended at km 35.

**The consequence, which was weighed rather than discovered.** Foraging used to
hand out `food.potato`, `food.duck_egg`, `mat.clay` and `mat.iron` from km 3.
They now start at km 11, and km 1–10 forages berries, nuts, lumber and pebble.
Iron is the one that bites: the estate T3 upgrade wants 8 of it at player level
7. The mine plot produces iron from estate T2 (level 4), so the material is
reachable before it is needed — but **the mine stops being optional in the first
week**, which is a real change to how the opening plays and belongs in
`spec-economy.md`'s ledger rather than in a footnote here.

## 8. Decisions (approved 2026-08-31)

**The roster is the seven existing creatures, re-spread.** Nine new animals were
proposed and turned down: density comes from rearranging what exists, and new
species wait until after the rebalance. §3 is the whole change.

**The boss waits.** The `boss` archetype keeps its contract and no members. What
a boss is in this world gets decided against a played game.

**The three zone systems are reconciled** to Гущавина 1–10 / Старий ліс 11–25 /
Пуща 26–49, applied to `zones.json` and `lore.md` in this phase.

## 9. What happens after approval

**Amended 2026-08-31 by `spec-items.md` §3 — read that amendment first.** This
section was approved before the wardrobe was measured. It turns out the shipped
player carries about **40%** of the on-curve kit the archetype targets were
solved against, so the roster's ~50% and the wardrobe's ~40% have been holding
each other up. Regenerating the bestiary alone would double every enemy against
a player who did not move.

**So Phase 10 applies §3 — the level re-spread — and nothing else.** The seven
creatures keep the stat lines they have; the `content.roster_off_curve` warnings
stay in every report; the archetype table stays decorative for one more release.
The regeneration below happens **after the rebalance, together with the gear
ladder** in `spec-items.md` §4, because the two halves are one correction.

What that regeneration will be, when it comes: Phase 10+ regenerates **every**
stat line in the table from the archetype contract — including the seven that
already exist. The specification names creatures, levels, archetypes, families
and loot tables; `EnemyGenerator` supplies HP, ATK, DEF, crit, dodge and XP; the
validator enforces the archetype floor; and the balance report measures the
result against the same contract that produced it.

**No new locale keys are needed** — every creature in the table already has its
`enemy.<id>` name in both locales, which is one of the quieter arguments for
re-spreading the roster rather than inventing one. The only string that changes
is `enemy.wild_buffalo` in `en.json`, from Buffalo to Bison.
