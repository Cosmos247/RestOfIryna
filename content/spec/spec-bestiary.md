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

*(This section describes the roster **before** Phase 10 — it is the problem
statement, and the table below is what the game looked like on 2026-08-31. §3 is
what replaced it, and §4 measures the result.)*

The roster was seven creatures, and the level↔km rule from
`spec-progression.md` (**an enemy of level N spawns from km N to km N+9**) shows
what that meant in play:

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
  (62% at level 1, 48% by 25 — ~60% across the board after Phase 10's re-spread
  lowered the levels without touching the stats). The roster was authored before the archetype
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
| 22 | `enemy.rabid_bear` | Rabid Bear | Скажений ведмідь | rabid | elite | 22–**40** | level 25 → 22 |

> ### AMENDED 2026-09-14 — tier 1 is filled, and the boar moves to level 2
>
> The table above is the roster as Phase 10 left it, and §8's "no new creatures"
> was a decision about the **rebalance release**, which has shipped. Content is
> now added tier by tier, weakest tier first. Tier 1:
>
> | L | id | EN | UA | family | archetype | km band | change |
> |---|---|---|---|---|---|---|---|
> | 1 | `enemy.wild_viper` | Viper | Гадюка | wild | trash | 1–10 | **new** |
> | 1 | `enemy.wild_eagle` | Golden Eagle | Беркут | wild | skirmisher | 1–10 | **new** |
> | 2 | `enemy.wild_boar` | Wild Boar | Дикий кабан | wild | **normal** | **2–11** | level 1 → 2, trash → normal |
>
> **Why the boar moved rather than being hand-buffed.** Two creatures were asked
> for below it, and the order wanted was viper < eagle < boar — which is an order
> in XP, and XP is `round(mobXP.coefficient · level^1.55 ·
> archetype.xpMultiplier)`, nothing else. Level and archetype are the only two dials; the stat line follows from
> them through `EnemyGenerator`. Moving the boar to level 2 `normal` is what
> raises it, and it raises HP 34 → 88 and DEF 6 → 16 without a number being
> chosen by hand.
>
> **The XP ladder is the point.** The first step used to be ×22.3 — 10 XP from
> the boar, then 223 from the moose with nothing between. It is now
> `10 → 34 → 76 → 223`, steps of ×3.4, ×2.2, ×2.9. At km 1 the opening ledger
> falls from 92.2 kills to reach level 4 to **53.4**, and km 2 — which used to be
> the same single boar as km 1 — becomes a rung of its own at 24.5.
>
> **Stats are on a different recipe from the rest of the roster, deliberately:
> HP at 100% of contract, ATK at 65%, DEF/crit/dodge on curve at their own
> level.** §9 explains why the shipped roster carries ~60% of both. The half of
> that which is not an error is the ATK: the real level-1 player has the
> **on-curve weapon** — the three starter weapons carry the ATTACK the budget
> prices for a `main_hand` at itemLevel 1 (sword 7 against 7.56, bow 6 against
> 6.24, staff 7 against 6.61; their accuracy is authored above curve, which does
> not enter this) — and **no armour at all**, DEF 12 against the reference
> character's 30.9. A mob on full contract therefore costs an actual new player
> 1.5× the share of the bar its archetype asks for, and 0.65 cancels that. HP
> needs no such correction, because at level 1 attack is the stat the player
> already has. Measured: viper 3.1 rounds / 11% of the bar, eagle 4.1 / 31%,
> boar 5.5 / 27% — against contracts of 3.0/10%, 4.0/28% and 5.0/24%.
>
> `roi-content simulate` will keep reporting all four as
> `content.roster_off_curve` on ATK. That is expected rather than a defect: the
> report measures against the reference character's full kit, and 65% is
> calibrated against the kit registration actually grants.
>
> **`enemy.wild_moose` gains HP 73 → 114** and changes in no other way. Its ATK 8
> is already 65% of its contract. Without it a level-2 boar (88 HP) would be
> tankier than a level-4 moose, and the ladder would invert where a new player
> walks.
>
> **Two consequences worth stating rather than discovering.** Km 1 now drops no
> food at all — both new creatures were authored with an empty loot table, and
> the boar, which was the only meat at km 1, has moved to km 2. And a level-1
> creature covers km 1–10, so the two of them lower the average XP of every
> kilometre in that band: the ledger's km 4 falls from +44 Vigor to **+3**, km 7
> from +66 to **+45** (measured after the whole pass, including the re-solve below,
> which moved each by one).
> *Superseded the same day by the XP halving.* `mobXP.coefficient` went **26 → 13**
> and every `xpReward` with it, so every figure in this note is now the record of
> an intermediate state that never shipped on its own. Current: km 1 costs
> **106.1** kills and **−665** Vigor, km 2 −299, km 4 **−106**, km 7 **−13**, and
> the cheapest holdable depth pays nothing at all. (The last two Vigor of each
> of those went to the silver find on 2026-09-15, which took its 2% out of the
> `loot` bucket — so the trail feeds fractionally less and pays coins instead.) The causal claims above still
> hold — they are about the dilution a level-1 creature causes, which the XP
> change did not touch. **This recurs for every tier added below an existing one** — it is
> the km rule (`level N → km N…N+9`) working as designed, not a defect.

> ### AMENDED 2026-09-14, same day — the other five, re-solved
>
> Putting tier 1 on its contract made the rest measurable against it, and the
> answer was that **danger collapsed with depth**. Measured share of each
> archetype's contracted cost: bison **45%**, lynx **21%**, wolf 33%, bear 33%,
> rabid bear **26%** — against tier 1's 54–61%. Two readings say it plainly: a
> level-10 lynx cost the same 6% of the bar as a level-1 viper, and the level-1
> eagle (17%) was more dangerous than the level-22 **elite** (16%), whose
> contract is 62%. Win rate was 100% against all nine.
>
> | id | L | HP | ATK | DEF | crit | dodge |
> |---|---|---|---|---|---|---|
> | `enemy.wild_buffalo` | 7 | 121 → **138** | 13 → **15** | 63 → **48** | 10 → **8** | 0 |
> | `enemy.rabid_lynx` | 10 | 75 → **109** | 14 → **20** | 18 → **17** | 28 → **27** | 31 → **30** |
> | `enemy.rabid_wolf` | 13 | 124 → **156** | 12 → **15** | 44 → **38** | 11 → **10** | 6 → **5** |
> | `enemy.wild_bear` | 16 | 183 → **216** | 17 → **20** | 101 → **82** | 13 → **11** | 0 |
> | `enemy.rabid_bear` | 22 | 240 → **319** | 23 → **30** | 82 → **74** | 57 → **53** | 23 → **21** |
>
> Levels, archetypes, km bands, loot and **XP are all untouched** — only the
> stat lines moved. The DEF/crit/dodge column is the Phase-10 freeze coming off:
> each of these carried the defensive curve of its PRE-re-spread level, so the
> bison absorbed like a level-11 creature and the bear like a level-21 one.
>
> **`enemy.wild_moose` gave up the last frozen line in the same pass** —
> DEF 24 → **20**, crit 8 → **7**, dodge 4 → **3**. The amendment above had
> raised only its HP, which left it the one creature still carrying a
> pre-re-spread curve, and worse: the generator's 114 HP is solved *against*
> DEF 20, so the pair was internally inconsistent. All eleven creatures now carry
> the defensive curve of the level they are actually on.
>
> **The solved figures are 65–78% of contract, not 100%, and that is the whole
> reason this could ship without the gear ladder.** §9 deferred the regeneration
> because regenerating to 100% would double every enemy against a player who had
> not moved — which is true. Solving against the wardrobe that actually exists
> (`spec-items.md` §3: 40–53% of the on-curve kit across these levels) is a third
> option that was never on the table, and it raises the five by **+14% to +45%**
> rather than by ×2. Verified: against a player carrying that wardrobe all five
> now land on contract — 7.0 rounds / 43%, 4.0 / 29%, 5.0 / 25%, 7.0 / 42%,
> 8.0 / 62%.
>
> **It is a provisional calibration.** If the gear ladder ever lands and the
> wardrobe moves toward the curve, these five have to be re-solved against it.
>
> **What it cost, measured rather than guessed.** In the opening ledger the Vigor
> columns barely moved and the WIN column moved a great deal: km 10 from 95% to
> 88%, km 13 from 66% to 46%, km 17 from 34% to 8%. The cheapest depth a level
> 1–3 player can actually hold went **km 10 → km 7**, and the profitable-and-
> survivable window narrowed from km 4–11 to **km 4–7**. `roster_off_curve`
> warnings fell from 9 to 7 and the report's total returned to **12**, its count
> before any of this.
>
> **What stats could not fix, and tier 2 will have to.** The XP ladder's biggest
> remaining step is **×4.5 between the moose (L4, 223) and the bison (L7, 1008)**
> — a content gap, not a stat one. Bison, lynx and wolf then sit within ×1.4 of
> each other, three creatures on one rung; the level gap 16 → 22 is the widest in
> the game; and density falls from 6 candidates at km 10 to 2 at km 20.

`enemy.rabid_dog` (the registration fight) and `enemy.training_dummy` keep their
`0…0` depth and never spawn. **No boss ships in this band** — see §5.

Only two things about a creature change: its **level**, and therefore its whole
generated stat line, and its **km band**, which follows from the level by the
rule in `spec-progression.md`.

> *Corrected 2026-09-01, during Phase 10.* The rabid bear's band is **22–40**,
> not 22–31. Applying the plain N…N+9 rule opened a nine-kilometre hole at km
> 32–40 where exploration rolls no encounter at all, and the validator refused it
> (`enemy.depth_gap`). That is not a new exception: `spec-progression.md` §4
> already records this creature's band as "stretched wider because nothing else
> lives out there", which is exactly why it shipped as 25–40. The level moves as
> specified; the stretch stays until something is authored to live past km 31.
> Filling it needs a new creature, and §8 rules those out for this release. Family, archetype, name, icon and loot table are
untouched. `enemy.wild_buffalo` is renamed to Bison / Зубр per the table above;
the id stays, because ids are a database contract.

> *Corrected 2026-09-01, during Phase 10.* This sentence used to justify the
> rename with "which is what the Ukrainian name and the lore already say".
> **They did not** — `uk.json` said «Дикий буйвіл» and `lore.md` said Wild
> Buffalo, so the rename touches three files, not one. The decision stands on
> its own: 🦬 is a bison, and the European bison — зубр — is the animal that
> belongs in a pine-and-oak wilderness. The table in this section always
> specified both names; only the parenthetical was wrong.

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
| 19–21 | 2–3 | skirmisher (to km 19), normal, brute |
| 22–25 | 2–3 | + **elite** |
| 26+ | 1 | elite only — the draft band starts here |

Average **2.56** candidates per kilometre across km 1–25 against **2.24** before,
and the improvement is where it was needed: km 4–9 goes from one creature to
three. *(Measured after the change landed in Phase 10; the km 19–21 row was 3 in
the draft and is 2–3 in fact, because the lynx's band ends at km 19.)*

**The first three kilometres stay a single animal.** A creature covers km N…N+9,
so only a level-1 creature can appear at km 1, and there is exactly one of those.
Fixing that needs a second level-1 creature — which is a new animal, and new
animals are what this document just decided against. It is a tutorial, and it
lasts about five kills.

**The draft band shows through from km 26.** Only the rabid bear reaches out
there, and nothing at all lives past km 40. That edge is the first thing the
post-rebalance content pass fills — Phase 10 shrank to the level re-spread alone
(`spec-items.md` §3), so it is carried by the elite's stretched band and is
visible in the table rather than discovered in play.

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

> *Amended 2026-09-14.* "After the rebalance" has arrived — the release shipped
> and has been played. The decision that stands is its reason, not its letter:
> **new species are added a tier at a time, weakest tier first, and each tier is
> measured before the next is opened.** Tier 1 landed on 2026-09-14 (§3's
> amendment): the viper, the eagle, and the boar moved to level 2. The roster is
> nine spawnable creatures plus the two that never spawn.

**The boss waits.** The `boss` archetype keeps its contract and no members. What
a boss is in this world gets decided against a played game.

**The three zone systems are reconciled** to Гущавина 1–10 / Старий ліс 11–25 /
Пуща 26–49, applied to `zones.json` and `lore.md` in this phase.

## 9. What happens after approval

**Amended 2026-08-31 by `spec-items.md` §3 — read that amendment first.** This
section was approved before the wardrobe was measured. It turns out the shipped
player carries about **40%** of the on-curve kit the archetype targets were
solved against, so the roster's ~60% (~50% before Phase 10) and the wardrobe's ~40% have been holding
each other up. Regenerating the bestiary alone would double every enemy against
a player who did not move.

> *Discharged 2026-09-14.* The regeneration happened, and it did not need the
> gear ladder — because it was solved against the wardrobe that exists rather
> than against the reference character. See §3's second amendment. The clause
> below is why it waited, and the reasoning was sound; what it missed is that
> "regenerate" and "regenerate to 100% of contract" are not the same instruction.

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
is `enemy.wild_buffalo` — and it changes in **`en.json`, `uk.json` and
`lore.md`** (Buffalo → Bison, «Дикий буйвіл» → «Зубр»), not in `en.json` alone as
this section originally said. See the correction in §3.
