# Content spec — Bestiary

**Status: approved 2026-08-31.** Phase 9. The decisions are in §8; §7 was applied
in the same pass. **§10 — tier 2, fourteen creatures numbered in order — was approved
and applied on 2026-10-02.** §3–§4 describe the roster before it. **§11 — creature
strength by estate tier — was approved and applied on 2026-10-03.**

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

> **Superseded 2026-10-02 by §10.** This section and both of its amendments describe
> the roster before tier 2. They stay as written, because they are the history that
> §10's numbers were measured against.

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

> **Superseded 2026-10-02 by §10.6.** Since tier 2, no km holds more than two creatures.

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

---

## 10. Tier 2 — fourteen creatures, numbered in order

**Status: APPROVED and APPLIED 2026-10-02.** The four open points were decided the
same day (§10.9), and the sandbox and the authoring measurements are in §10.10. On approval this section supersedes §3's roster and both of its amendments,
§4's walk table, and two rules in `spec-progression.md`: the km rule in §4 (**an enemy
of level N spawns from km N to km N+9**) and the level-gap scaling of mob XP in §1.

The contract every creature below is generated from is printed by the same command as
the rest of this document, at every number the roster uses:

```
swift run roi-content spec bestiary --levels 1,2,3,4,5,6,7,8,9,10,11,12,13,14
```

### 10.1 What was asked

The owner asked for new creatures that belong to Ukraine's lore and are a real threat
to a person, because a lizard or anything else harmless attacking makes no sense. Five
were proposed on 2026-09-28 and placed between the nine that exist. The owner kept all
five and their order, and then asked for three changes:

- **numbers run in order from 1**, one per creature, so the list is easy to edit;
- **bands follow one fixed step**: the first creature lives on km 1–4, the second on
  3–7, the third on 6–10, and so on;
- **km 1–2 hold the viper alone.**

Bosses are out of scope for this tier, so the `boss` archetype still has no members
(§5 stands).

### 10.2 The roster

| № | id | EN | UA | family | archetype | km band | today |
|---|---|---|---|---|---|---|---|
| 1 | `enemy.wild_viper` | Viper | Гадюка | wild | trash | 1–4 | L1 · km 1–10 |
| 2 | `enemy.wild_eagle` | Golden Eagle | Беркут | wild | skirmisher | 3–7 | L1 · km 1–10 |
| 3 | `enemy.wild_boar` | Wild Boar | Дикий кабан | wild | normal | 6–10 | L2 · km 2–11 |
| 4 | `enemy.rabid_fox` | Rabid Fox | Скажена лисиця | rabid | skirmisher | 9–13 | **new** |
| 5 | `enemy.wild_moose` | Wild Moose | Дикий лось | wild | normal | 12–16 | L4 · km 4–13 |
| 6 | `enemy.wild_stag` | Red Stag | Олень-рогач | wild | normal | 15–19 | **new** |
| 7 | `enemy.wild_buffalo` | Wild Bison | Зубр | wild | brute | 18–22 | L7 · km 7–16 |
| 8 | `enemy.rabid_lynx` | Rabid Lynx | Скажена рись | rabid | skirmisher | 21–25 | L10 · km 10–19 |
| 9 | `enemy.rabid_wolf` | Rabid Wolf | Скажений вовк | rabid | normal | 24–28 | L13 · km 13–22 |
| 10 | `enemy.wild_tusker` | Old Tusker | Вепр-сікач | wild | brute | 27–31 | **new** |
| 11 | `enemy.wild_bear` | Wild Bear | Дикий ведмідь | wild | brute | 30–34 | L16 · km 16–25 |
| 12 | `enemy.wild_aurochs` | Aurochs | Тур | wild | brute | 33–37 | **new** |
| 13 | `enemy.rabid_pack` | Rabid Pack | Скажена зграя | rabid | skirmisher | 36–40 | **new** |
| 14 | `enemy.rabid_bear` | Rabid Bear | Скажений ведмідь | rabid | elite | 39–**49** | L22 · km 22–40 |

Three rules produce the table, and nothing else in it is chosen:

- **The number is the level.** It feeds the generated stat line, the damage shift
  (`levelDiff`) and the rating curves — but no longer the XP a kill pays (§10.4).
- **The band is km 3N−3 … 3N+1, with №1 starting at km 1.** A new creature every three
  km, each band four km wide, neighbours overlapping by two. No km holds more than two
  creatures; km 1–2, every third km from km 5 on (5, 8, 11 …) and km 41–49 hold only
  one. **One exception, chosen over an empty forest edge:** the last creature's band
  stretches to the zones' horizon at km 49, exactly as today's rabid bear stretches to
  km 40. By the plain rule it would end at km 43 and leave km 44–49 without a single
  encounter. The stretch shrinks back as №15 (km 42–46) and №16 (km 45–49) are
  authored. The horizon holds exactly sixteen creatures, and a seventeenth would need
  it moved.
- **XP depends on the number alone:** every creature pays the `normal` row's XP at its
  number, rounded to two significant figures as the shipped roster already is. To make
  the generator and `spec bestiary` print what the roster pays, every archetype's
  `xpMultiplier` becomes **1.0** — the archetype keeps deciding how a fight goes, and
  stops deciding what it pays. With the multiplier the renumbered bison (№7) would pay
  more than the lynx above it (№8), and the aurochs (№12) more than the pack (№13). The
  price of dropping it is that brutes and the elite no longer pay extra for a longer
  fight; their reward is the meat and the hide.

The ids of the nine existing creatures stay — ids are a database contract. Spawn
weights stay inherited from the archetype (§5); nothing overrides one. The rabid bear
sits exactly on the elite floor of level 14. The tusker is a `brute`, because an elite
below level 14 is refused (`enemy.below_archetype_floor`).

### 10.3 Why these five

All five are animals of medieval Ukraine that maim people. Three of them come from one
source: in his «Повчання» (12th c.) Volodymyr Monomakh lists what befell him on the
hunt — two aurochs tossed him and his horse on their horns, a stag gored him, an elk
trampled him, a boar tore the sword from his thigh, a bear bit at his knee. The elk,
the boar and the bear already live here; the aurochs, the stag and the old tusker join
them.

- **Rabid fox** — the main natural carrier of rabies in Ukraine; a sick fox walks up
  to a person in daylight and bites. At km 9–13 it is the first sighting of the Blight,
  at the thicket's edge, which is what `content/lore.md` asks of the middle band.
- **Red stag** — in the rut, September to October, it charges anything that moves.
- **Old tusker** — the old solitary boar, the classic danger to a hunter.
- **Aurochs** — a wild bull up to 1.8 m at the shoulder. It died out in our world in
  1627 and still walks in Artania.
- **Rabid pack** — wolves the Blight stripped of fear. The name is singular on purpose:
  combat lines make it the subject («%{enemy} втрачає N ОЗ»).

Turned down: harmless animals (lizards, grass snakes, hedgehogs, hares, a healthy fox);
the jackal and the raccoon dog, which reached Ukraine only in the 20th century; and the
upyr, the mavka, the drowner and the Zmiy, because `lore.md` §2 says the Blight is
neither skeletal nor demonic. Held in reserve: a hornet swarm, feral dogs, the tarpan,
and for №15 onward the rabid doubles of the bison, the tusker, the stag and the aurochs,
plus the Vovkulaka — what villagers call the pack's leader.

### 10.4 The level gap: XP stops shrinking, damage keeps shifting

Today a kill pays 8% less XP for every level the player stands above the creature,
down to 10% (`tuning/progression.json` → `xpLevelDiff`), and every swing between them
shifts by 6% a level, clamped to ×0.25–×2.5 (`tuning/combat.json` → `levelDiff`).

**Decided: `xpLevelDiff.perLevel` goes 0.08 → 0, and `levelDiff` stays.** Every kill
pays its full `xpReward`; a creature the player has outgrown still dies faster and
hurts less.

**Why, in the owner's words reduced to a rule:** a creature's number is its rung on the
depth ladder, not a player level, and how deep a player can go is paid for by the
estate's food, not granted by their level.

**Why, measured.** Under today's rule a level-22 player already stands above all
fourteen creatures, and from level 26 every one of them pays the 10% floor, so the
climb stops. The damage shift is what keeps the walk alive: outgrown creatures die in a
round or two and barely scratch, so a trip reaches deeper as the player grows. Without
it, the weak creatures on the way hit at full strength and the trips stay short.

**The guard this replaces.** Until this change the validator refused a zero `perLevel`
(`tuning.progression.xp_level_diff_absent`), because without the penalty "farming far
below your level stays fully rewarding and the depth ladder becomes dead content". The
purpose stands and the mechanism changes. Every trip starts at the manor and walks
through the weaker bands, and a deeper creature pays more, so depth is what pays. The
rule that replaces it guards exactly that: **no creature may pay less XP than one whose
band starts shallower.** It ships with its failing case in the same commit. The
`xpLevelDiff` knob stays in the data, so if live play shows shallow farming after all,
the penalty comes back with one number and a `/reload`.

### 10.5 Measured, not reproducible from `roi-content` yet

These figures come from a scratch expedition model built on 2026-10-02. Each trip walks
from the manor to a chosen km and back, one km per step, and fights what the steps roll:
40% of steps going in, 52% coming home, matching `tuning/exploration.json`. Fights are
the game's own `FightSimulator`, rolled 1,000 times for every level 1–40 × class ×
creature, against creatures generated on contract and the on-curve reference character.
Each level takes the depth with the best XP per Vigor that the character survives: mean
HP lost no more than 90% of a bar after dishes eaten on the way, and at least 90% odds
of getting home. Days are Vigor ÷ a tended estate's food, as in `simulate`.

Days to level 14 / 25 / 40, mean of the three classes, with the rabid bear's band
stretched to km 49:
- today's roster under today's rules: 75 / 159 / 642;
- this roster under today's rules: 97 / 367 / ~3,070 (the wall);
- this roster with no level comparison at all: 99 / 246 / 811;
- **this roster as proposed (XP penalty off, damage shift kept): 67 / 128 / 399**;
- the same, keeping the archetype XP multiplier: L40 in 229.

The conclusions held across healing assumptions from 60% to 250% of a bar per trip.
Today's rule still walls, and the proposal still beats today's game at levels 14 and
40. The absolute days moved, and at 250% today's game pulls ahead at levels 25–30.

**What `simulate` cannot see.** Its pace section assumes every fight is with an on-level
`normal` creature at 1.9 rooms of walking. It never sees the walk from the manor through
the weaker bands, which is the mechanism this whole section turns on. That is why the
absolute days above exceed `simulate`'s 114–126 (151–167 since §11 priced the estate's
strength into the pace), and why `simulate` will barely move on this change apart from its
roster check and the opening ledger. Building the expedition model into `simulate` is
separate work and not part of this amendment.

### 10.6 What a walk looks like

- **Depth grows about two km a level:** ~10 at level 5, ~19 at 10, ~28 at 14, ~40 at 20,
  and the whole forest, to km 49, from ~25.
- **Trips get long.** At level 20 a trip is ~80 steps and ~36 fights, and costs ~320
  Vigor against a pool of 200. The rest is eaten from the bag on the way.
- **Past km 40 the rabid bear walks alone**, to the horizon at km 49 (§10.2's one
  exception). From ~level 25 the player walks the whole forest, and levels 22–40 take
  ~290 days of that walk. Nothing new appears there until №15.
- **The opening changes.** Km 1–2 hold the viper, km 3–4 add the eagle at level 2, and
  the boar starts at km 6. The viper and the eagle drop nothing, so **km 1–5 yield no
  meat**; today the first meat is at km 2. Wild meat then runs to km 37, the aurochs'
  last km. Past it live only the pack and the rabid bear.
- **The Blight thickens with depth by ratio.** The thicket holds one rabid creature, the
  fox, on its last two km. The Old Wood holds the fox, the lynx and the wolf against the
  moose, the stag and the bison. The Пуща ends in the pack and the rabid bear.

### 10.7 What changes for players already playing

- The creatures they know move deeper and pay differently: the bison 500 → 270 at km
  18–22, the lynx 600 → 330 at 21–25, the wolf 690 → 390 at 24–28, the bear 1,800 → 530
  at 30–34, the rabid bear 5,000 → 780 at 39–49.
- XP per Vigor at levels 10–14 stays about where it is today (§10.5's model). The trips
  that earn it are deeper and longer.
- No level and no XP is taken. No id is removed, so there is no migration and the live
  reference check has nothing to refuse. `fight_log.enemy_id` keeps its history.
- The King's three depth decrees — km 3 at level 1, km 7 at level 3, km 26 at level 17 —
  stay reachable. In the sandbox the opening ledger holds km 3 and km 7 at a 100% win,
  and a level-17 player's best trip already goes to about km 33. The ledger fights with
  the armoured reference, though, so the first two are easier there than for a player
  in the registration kit.

### 10.8 What authoring touches, once approved

1. `tuning/progression.json`: `xpLevelDiff.perLevel` 0.08 → 0.
2. `ContentValidator`: `tuning.progression.xp_level_diff_absent` is replaced by the
   depth-XP rule in §10.4, with its failing case. The test that asserts the old rule
   moves with it.
3. `enemies.json`: all six archetypes get `xpMultiplier` 1.0. The nine creatures are
   re-numbered, re-banded, re-solved and re-priced (the rabid bear's band is 39–49), and
   five rows are added. `tier` is a legacy field no game code reads (the digest hashes it
   and the validator only checks it is not negative), and the new rows take a
   neighbour's. The JSON is emitted in the house style, by an emitter that first
   reproduced all 28 content files byte for byte.
4. **Stat lines**, solved per creature against the kit a player of that number actually
   carries. That is the tier-1 recipe up to №4, where today's moose already sits on it:
   HP 100%, ATK 65%, DEF/crit/dodge on curve (§3's first amendment). Above №4 it is the
   wardrobe re-solve of §3's second amendment. **That method was never written down,
   so it was reconstructed on 2026-10-02.** `EnemyGenerator` solves against the on-curve
   reference character, with its kit scaled to the share of the on-curve kit that
   `spec items` prints as obtainable at that level (`ReferenceCharacter`'s
   `rarityMultiplier`). That reproduces the 09-14 lines to within 2–8%, and the gap is
   the obtainable shares having fallen since. A player built from the real items —
   laddered weapon plus the Forester set — does NOT reproduce them, because the
   level-10 weapon rung overshoots. The sandbox has to show on-contract rounds and bar
   shares before anything is committed.
5. Five names in `en.json` and `uk.json`, nominative only. The four lines that still put
   an enemy's name in an oblique case (`TODO.md`) are fixed in the same commit, because
   five new names make that defect more visible, not less.
6. `content/lore.md`: the five creatures join the bestiary.
7. Documents: `spec-progression.md` §1 and §4, `CLAUDE.md` (the rule and its guard),
   `Prompt.md` (the world-ladder line), the comment on `ProgressionMath.xpMultiplier`,
   and the `enemy.depth_gap` comment, which said "km tracks level". The audit before the
   commit found five more code comments that described the old roster (`Enemy.swift`'s
   header, `EnemyDTO`, `EnemyGenerator`'s worked example, `OpeningLedger`,
   `BalanceFormatter`), and they were rewritten in the same commit.
8. Tests pinned to today's roster, and a new digest baseline. `records`, `tuning` and
   `spawns` move; `quests` and `king` do not. The digest's printed self-check
   `xp floor` expects a level-40 player to get the floor from a level-1 creature, and
   is rewritten to expect the full reward.
9. Verification: `validate --strict`, `simulate --strict`, `spec opening -c release`
   with `spec-economy.md`'s blocks refreshed, `swift test`, and `--content-digest`.
10. Deploy needs a restart, not a `/reload`: the validator is code, and Lingo does not
    reload new strings.

### 10.9 Decided 2026-10-02

The owner settled the four open points the same day:

1. **The archetype XP multiplier goes to 1.0**, as the approved table has it. Keeping it
   would reach level 40 in 229 days instead of 399 (§10.5), but brutes would again pay
   more than the creatures numbered above them.
2. **Stat lines are solved against the real kit** (§10.8, step 4).
3. **The four oblique-case lines are fixed in the same commit.**
4. **The rabid bear's band stretches to km 49** rather than leaving km 44–49 empty —
   the one exception to the band rule (§10.2), shrinking as №15–16 arrive.

### 10.10 Applied 2026-10-02 — what the sandbox and the authoring measured

`content/data` was first built in a scratch copy, then applied unchanged. The emitter
re-wrote all 28 content files byte for byte before it was allowed to write one.

- **Validation.** `validate --strict` is clean, 0 errors and 0 warnings, with
  `enemy.xp_falls_with_depth` replacing `tuning.progression.xp_level_diff_absent`. The
  old validator refuses this bundle on that one rule and nothing else. The new rule's
  failing case fires: a wolf cut to 300 XP under a 330 XP lynx.
- **Tests.** 320 → 324 (`BestiaryTests` +3, `TuningTests` +1). `SimulatorTests`'
  inversion check now carries the fourteen tier-2 creatures. Its fixture was still the
  Phase 9 roster while claiming to be copied from `enemies.json`. All fourteen land on the
  DEF, crit and dodge curves exactly.
- **`simulate --strict`.** 0 broken bands and 18 warnings instead of 12. The six extra are
  all `content.roster_off_curve`, the same deliberate finding today's seven creatures
  carry: lines solved against the real kit read light against the reference character.
  The pace section did not move, because it never reads the roster.
- **Digest.** `records`, `tuning` and `spawns` moved; `quests` and `king` did not. The
  printed `combat model` check passes with its XP anchor now expecting the full reward.
- **Fights.** №5–14 land on contract against the player they were solved for, and run
  lighter against a player in real gear, clearly so from №10, where the level-10
  weapon rung arrives. №3–4 run heavy for a player without armour: the boar takes
  29% of a bar and the fox 36%, against contracts of 24% and 28%. Today's moose already
  sits at 29%, and the fox drops to 24% once the Forester set is worn. A level-9 player
  without the level-10 weapon who walks into №10–11 meets 56–69% of a bar per fight. In
  practice that band, km 27 on, is reached around level 14.
- **The opening.** The finding is back to `opening.shallow_is_bankrupt` (`spec-economy.md`
  carries the re-measured ledger). Km 1 takes 60.6 kills to level 4 instead of 106.1. The
  ledger's holdable window is km 12–17, but it is held by the armoured reference
  character. A real level-3 player loses ~47% of a bar to every moose there.
- **Loot of the five new creatures**, copied from their nearest kin: the fox from the
  lynx, the stag from the moose, the tusker from the bison, the aurochs from the bear,
  the pack from the wolf.
- **The four oblique-case lines** were rewritten in the owner's wording, picked over a
  quiz: «%{enemy} — перемога за N раунд(ів).», «…зачіпаєте у відповідь — %{enemy} втрачає N
  ОЗ.», «…— %{enemy} лишається позаду.», «Ви зараз у бою — %{enemy} не відступить. …». The
  sweep for an enemy name in an oblique position now finds nothing.
- **Pace with the authored lines.** This uses §10.5's expedition model with a player built
  from the real items. Days to level 14 / 25 / 40: today's roster 78 / 152 / 598, tier 2
  73 / 132 / 392.

## 11. The forest grows with the manor — creature strength by estate tier

**Status: APPROVED and APPLIED 2026-10-03.** The rule and its step were decided on 2026-10-02
(§11.1), this section's two open points on 2026-10-03 (§11.11), and the implementation's
measurements are in §11.12.

### 11.1 What was asked and decided

After tier 2 the owner asked whether creatures should grow stronger as the player does. The
growth is tied to the estate tier rather than the player level, because the tier is coarse, and
more useful estate tiers are planned. Three variants were measured (§11.4), and on 2026-10-02 the
owner decided:

- **a creature's HP and ATK are multiplied by 1 + 0.10 × (estate tier − 1)** — variant A, the
  mildest of the three;
- **strength only:** XP, loot and everything else a kill pays stay as authored. I advised scaling
  XP with it, so that an upgrade never makes the forest worse value; the owner chose otherwise;
- **T6 stays as it is**, although under this rule it is the one upgrade that gains nothing
  (§11.5), until new estate tiers add food.

### 11.2 The rule

- **Input:** the estate tier of the player the creature is fighting, `User.estateLevel` (1–7).
  Never the player's level, gear, class or depth.
- **Multiplier:** `m = 1 + perTier × max(0, tier − 1)`, with `perTier = 0.10` in
  `tuning/combat.json` → `estateScaling`. T1 is ×1.0 by construction, and levels 1–3 can hold
  nothing but T1, so the opening and its ledger (`spec opening`) do not move.
- **What scales:** HP and ATK, each rounded to a whole number half away from zero — the rounding
  the measurement used. DEF, crit, dodge, accuracy, level, XP, loot, band and spawn weight stay as
  authored. Because the level stays, the damage shift (`levelDiff`) and the XP a kill pays are
  untouched, and an outgrown creature still dies faster and hurts less.
- **Which creatures:** the forest's, meaning every creature that spawns. The two with the `0...0`
  depth that never spawn, the training dummy and the registration dog, stay as authored at every
  tier. The dog is met at T1 anyway.
- **When it is read:** when an encounter is rolled, and again every time a fight in progress is
  read back from its row. Both read the same tier, because the tier cannot change during an
  expedition (§11.6).
- **Future tiers:** a tier added at the top extends the line by itself, so a T8 would be ×1.7. A
  tier inserted in the middle renumbers every tier above it, and the forest moves with them. If a
  future tier should step differently, for instance to skip a tier that adds little food as T6
  does now, `perTier` becomes a per-tier table beside `plotSlotsByTier`. That is a data change,
  not a redesign.

The multiplier at each tier, as `spec gates` prints it (an excerpt; the whole table is in
`spec-progression.md` §3):

<!-- generated: roi-content spec gates -->
**Estate** (`estate_upgrades.json`) — the plot slots are the daily Vigor budget;
the creatures column is the forest's HP and ATK at that tier (`tuning/combat.json`
→ `estateScaling`, `spec-bestiary.md` §11)

| tier | player level | plot slots | warehouse cap | creatures |
|---|---|---|---|---|
| T1 | start | 0 | 200 | ×1 |
| T2 | 4 | 1 | 400 | ×1.1 |
| T3 | 7 | 2 | 600 | ×1.2 |
| T4 | 10 | 3 | 800 | ×1.3 |
| T5 | 13 | 4 | 1200 | ×1.4 |
| T6 | 16 | 5 | 1600 | ×1.5 |
| T7 | 19 | 6 | 2000 | ×1.6 |
<!-- /generated -->

### 11.3 Why this is not the runtime-scaling trap

`Enemy.swift`, `EnemyGenerator`, `CombatMath.levelDiffMultiplier` and `content-pipeline.md` all
warn against scaling enemies at runtime. Computed against the player, `EnemyHP = playerDPR ×
targetRounds` gives the creature exactly what a new weapon gave the player, and the upgrade
evaporates as it is equipped. Scaling by the estate tier is a different mechanism:

1. **It reads nothing the player's power is made of.** Equipping, enchanting, repairing and
   levelling never move the estate tier, so each of them keeps its full value against the same
   forest. The trap is a multiplier that follows the character; this one follows a building.
2. **It moves only when the player decides.** The estate is a manual, level-gated upgrade paid in
   materials and silver, so the forest's strength is the price of a choice, not a shadow of the
   character.
3. **It is coarse and bounded:** six steps in the whole game, ×1.6 at most, known in advance.
   Between T2 (level 4) and T7 (level 19) the forest grows ×1.45. Over the same levels the
   player's base stats grow faster, before any gear and before the damage shift: ATK ×2.15, DEF
   and the ratings ×2.02, HP ×1.72 (`progression.json` → `statGrowth`). A given creature still
   gets easier as the player grows, only more slowly.
4. **The ladder survives.** Every creature gets the same multiplier at a given tier, so a deeper
   creature is still the stronger one. XP does not scale, so it still grows with depth, and
   `enemy.xp_falls_with_depth` is untouched.
5. **The stat lines stay frozen.** `enemies.json` keeps the design-time lines, and one tuning
   value is applied on top of them. Nothing is solved at runtime.

### 11.4 Measured, not reproducible from `roi-content` yet

These figures come from §10.5's expedition model, with the player built from the real items
(§10.10). Every creature's HP and ATK were scaled, with the rounding above, by the tier that the
player's level allows. Days to each level, mean of the three classes:

| | L10 | L14 | L19 | L25 | L30 | L40 |
|---|---|---|---|---|---|---|
| today's live roster | 64 | 78 | 105 | 152 | 218 | 598 |
| tier 2, unscaled | 60 | 73 | 97 | 132 | 181 | 392 |
| **tier 2 + A, +10% per tier — decided** | 74 | 96 | 130 | 184 | 249 | 477 |
| tier 2 + C, one creature level per tier | 79 | 103 | 148 | 212 | 281 | 506 |
| tier 2 + B, +20% per tier | 89 | 120 | 173 | 249 | 350 | 652 |

- **Against the game the testers play today, A is slower at every milestone up to level 30**, and
  faster only at the end: level 40 in 477 days against 598.
- **Against unscaled tier 2, A costs about 22% of the road to level 40.**
- The model was re-run on 2026-10-03 from the 2026-10-02 sandbox and reproduced A's row exactly.

### 11.5 What it does to a fight, a trip and an upgrade

**A fight.** Multiplying HP and ATK by m makes a fight about m times as long and costs about m² of
the bar. In practice it costs a little more than that, for two reasons: small ATK values round up
(the viper's 5 is 6 at T2), and a longer fight gives the creature more swings. Measured on every
fight the real-gear player wins at least 95% of the time unscaled:

| tier | × | rounds and Vigor | HP lost |
|---|---|---|---|
| T2 | 1.1 | ×1.09 | ×1.24 |
| T3 | 1.2 | ×1.17 | ×1.49 |
| T4 | 1.3 | ×1.24 | ×1.75 |
| T5 | 1.4 | ×1.29 | ×2.01 |
| T6 | 1.5 | ×1.34 | ×2.38 |
| T7 | 1.6 | ×1.40 | ×2.75 |

Win rates fall by at most about two points.

**A trip.** Trips get shorter, and the forest opens later:
- the best depth, mean of the three classes, falls to about km 16 at level 10 (21 unscaled), 22
  at level 14 (29), 32 at level 20 (41) and 40 at level 25 (49);
- the whole forest, to km 49, opens around level 30 instead of 25. That was the point: unscaled,
  the forest has nothing new to show past level 25.

**An upgrade.** XP per day with the next estate tier (stronger forest, more food), against XP per
day without it:
- T2→T3 ×5.8, T3→T4 ×1.7 and T4→T5 ×1.4, all clearly worth it;
- **T5→T6 ×0.9**, because T6 adds only 90 food a day (900 → 990) against a full step of
  strength;
- T6→T7 ×1.2 at level 19 and ×1.1 at level 25.

Every upgrade except T6 still pays, and the owner accepted T6 until new tiers add food. Any
future tier should pass the same check before it ships.

**The King's chain.** Two of its decrees meet the rule head-on:
- «П'ята сходинка» (`king.fifth_step`, level 16) rewards the player for taking exactly the T6
  upgrade above;
- «Пуща» (`king.the_wildwood`, level 17) then asks for km 26. Under A, the deepest trip the model
  survives at level 17 is km 28 / 27 / 26 (warrior / archer / mage), against 34 / 32 / 32
  unscaled. The decree stays reachable at its level, but the mage has no margin left. One level
  later every class makes km 28.

The two earlier depth decrees, km 3 and km 7, fall at levels 1 and 3, where every player is at T1,
so they do not move.

### 11.6 Where it lives in code

**One formula and one rounding, in `ROISim`,** so the bot and `simulate` run the same lines, as
with every other roll:

```swift
// Modules/ROISim/CombatMath.swift
public static func estateScale(tier: Int, spec: EstateScalingDTO) -> Double
    // 1 + perTier · max(0, tier − 1)
public static func scaled(_ stats: CombatantStats, forEstateTier tier: Int,
                          spec: EstateScalingDTO) -> CombatantStats
    // HP and ATK × estateScale, rounded half away from zero; every other field verbatim
```

**One façade in the game:** `Enemy.scaled(forEstateTier:)`. A creature that never spawns returns
itself, and any other returns a copy with HP and ATK replaced. The copy is made with `var copy =
self` (`hp` and `attack` become `private(set) var`), not by calling the initialiser again.
`Enemy.init` gives six of its fields defaults, so re-creating the value would silently reset any
field added later with a default of its own. That is the `GearState` lesson.

**Two funnels call it, and nothing else does:**

1. **Rolled:** `ExplorationService.rollEncounter`, straight after `EnemyCatalog.pickFor`. Both
   modes start here. The active hand-off stores the scaled HP on the row (`beginCombat`), and the
   passive autobattle fights the scaled creature.
2. **Read back:** `ExplorationState.combatEnemy(for:)`. It replaces the five places that now
   resolve the row's `combatEnemyId` with a bare `EnemyCatalog.find`: `CombatController.loadCombat`
   (every combat tap), its `/start`, its stale-callback redraw, its in-combat notice, and
   `ExplorationController.guardInCombat`. A read-back that skipped the scaling would draw a status
   card like `❤️ 151/131`: the HP the fight started with, over a maximum the creature never had.

`EnemyCatalog.find` and `pickFor` stay pure content. The digest, the validator, the registration
dog and the training dummy read them as they are.

**Why the stat is scaled and not the damage.** Seven places roll the creature's swing from
`enemy.attack`: five in `CombatController` (the strike round, Defend, a failed flee and both
specials), the passive autobattle and `FightSimulator`. The beast's HP is read in more places
still. Scaling the value at its source changes none of them. Scaling the damage would mean
changing all of them.

**The tier cannot change during an expedition, so the creature cannot either.** Both funnels read
the live `estateLevel`. That is safe because nothing can move it while an expedition row stands:
- `showEstate` refuses while the row exists;
- a fight answers every callback by redrawing itself;
- on the walk, `ExplorationController` hands a foreign callback to `MainController`, and a
  passive run leaves the player on `main` itself. `MainController` deletes an `estate:` callback
  instead of acting on it.

So no snapshot is stored on the row. The one thing that can move the multiplier mid-fight is a
`/reload` that changes `perTier`. The creature then keeps the HP it has left, and its maximum and
ATK follow the new value. That is dev-only and harmless.

### 11.7 What the player is told — nothing (decided 2026-10-03)

The owner's call: no screen announces it. The estate upgrade card and the tier-up banner stay as
they are, and the player meets the stronger forest in the fight's own `❤️`. At T5 the rabid wolf
reads `❤️ 162/162`, where at T1 it reads `116/116`. The fight screen does not change either, so
the change adds no locale strings.

The proposal turned down was one line on the upgrade card (`renderEstateUpgrade`), under the next
tier's name. It came from `CLAUDE.md`'s rule that a choice that cannot be undone is asked, not just
tapped:

```
⤴ Тир 5 — Лицарський маєток
🐾 Звірі в лісі: ОЗ і атака ×1.3 → ×1.4
```

It is kept here in case play shows players are caught out. If it ever ships, the multipliers are
printed from the knob with `%g`, like the shadow-veil line, so a `/reload` cannot leave a stale
number in the copy.

### 11.8 What checks it

- **Validator:** `tuning.combat.estate_scaling_negative` is an error when `perTier < 0`, because
  a forest that weakens as the manor grows inverts the decision. It ships with its failing case.
  Zero is legal and means off, as with `xpLevelDiff.perLevel`.
- **Content schema v14 → v15.** `estateScaling` is a required field. The handshake must refuse a
  bundle without it rather than run the forest silently unscaled.
- **Digest:** `tuning` moves, and only `tuning`. It replays `estateScale` over tiers −1…9, past
  both ends, as it already does for `levelDiff`, and runs the façade itself on one synthetic
  creature that spawns and one that does not, so the rounding and the exclusion are hashed too.
  The synthetic pair keeps the real roster in `records`, where it belongs. `records`, `spawns`,
  `quests` and `king` stay byte-identical, because no creature row, band, quest or decree changes.
  The printed `combat model` check gains four anchors on the real roster: T1 leaves every creature
  as authored, T7 is the decided ×1.6 (pinned by number, so a tier added above it does not trip
  it), nothing but HP and ATK moves, and the dummy and the dog come back unscaled at the top
  tier.
- **`simulate`:** the sweep keeps measuring the unscaled contract, because level invariance is a
  property of the curves, and this rule departs from it on purpose. A new printed section, «the
  forest by estate tier», measures the on-level `normal` fight at the level each tier opens,
  authored against scaled, on one seed so the pair differs only by the scaling. The pace section
  lifts each level's fight by the factor its tier measured, so the headline moves with the knob
  instead of hiding it. It still cannot see depth (§10.5).
- **`spec gates`:** the estate table gains the multiplier column, quoted in §11.2. That refreshes
  `spec-progression.md` §3's generated block.
- **Tests:** `EstateScalingTests` pins the formula and the rounding in `ROISim`: the decided line,
  T1 as the identity, tier 0 and below as T1, `perTier` 0 as the identity at every tier, only HP
  and ATK moving, a fresh creature at full health, rounding half away from zero, the ladder's
  order, and the shipped bundle. `TuningTests` adds the validator's failing case, zero as legal,
  and the missing key refused.
- **`fight_log` gains `estate_level`** (decided 2026-10-03). It is nullable, so a fight from
  before this change reads null. With it, the first live rows can be grouped by tier, and the log shows whether
  players hold back an upgrade to keep the forest soft. It takes one migration,
  `AddFightLogEstateLevel`.
- **The harness, rebuilt against the repo:** it calls `CombatMath.scaled` itself rather than its
  own copy, and it must reproduce §11.4's row for A before the change is committed. It did
  (§11.12).

### 11.9 What changes for players already playing

- Every player above T1 meets the stronger forest at their first encounter after the deploy. A
  tester at T4 loses about 75% more HP to the same creature (§11.5), and their comfortable depth
  shrinks. The game does not announce it (§11.7), so the testers should hear it from the owner
  before the restart.
- A fight in progress at the restart keeps its creature's remaining HP. Its maximum and ATK take
  the multiplier on the next tap.
- No level, XP, item or estate tier is touched. No content id is removed, so there is no content
  migration and `LiveReferenceCheck` has nothing to refuse.
- Tier 2 was not deployed yet when this was written. This change built on it, and both went live
  in the same restart, 2026-10-06 21:39.

### 11.10 What the implementation touched

1. `tuning/combat.json` → `"estateScaling" : { "perTier" : 0.1 }`, in the house JSON style, and
   `manifest.json` → `schemaVersion` 15.
2. `TuningDTO.swift`: `EstateScalingDTO`, required on `CombatTuningDTO`; `ContentSchema.current`
   → 15.
3. `CombatMath`: `estateScale` and `scaled(_:forEstateTier:spec:)`, with
   `CombatService.estateScale(tier:)` as their façade. It is a computed accessor, never a
   `static let`.
4. `Enemy.swift`: `spawns`, `scaled(forEstateTier:)`, and `hp` / `attack` as `private(set) var`.
   The header gains a paragraph that states the exception beside the rule.
5. The two funnels (§11.6), with the five read-back sites moved onto the second.
6. `FightLog.estateLevel`, the `AddFightLogEstateLevel` migration, and its registration in
   `configure.swift`.
7. No copy: the game announces nothing (§11.7), so neither locale file changes.
8. `ContentValidator`, `ContentDigest`, `simulate`, `spec gates` and the tests (§11.8).
9. The comments that state the old rule without exception: `EnemyGenerator`'s header,
   `CombatMath.levelDiffMultiplier`, `CombatService.levelDiffMultiplier` and `LevelDiffDTO`.
10. Documents: `CLAUDE.md` (a rule under Combat, and the `simulate` paragraph's level invariance
    scoped to the contract), `content-pipeline.md`, `rebalance.md`, this section's status,
    `Prompt.md`, `TODO.md` (a walk-list block), `.memory/status.md` and `.memory/file-map.md`.
11. Verification: `validate --strict`; `simulate --strict`; the `spec gates` blocks refreshed;
    `spec opening -c release` unchanged; `swift test`; `--content-digest`, where `tuning` alone
    moves; and the rebuilt harness (§11.8).
12. Deploy: `pm2 restart ROI`, not a `/reload`, because the change carries code, a content schema
    bump and a database migration.

### 11.11 Decided 2026-10-03

1. **The player is told nothing** (§11.7): the upgrade card and the tier-up banner stay as they
   are. A line on the card was proposed and turned down.
2. **`fight_log` gains `estate_level`** (§11.8), with its migration.

### 11.12 Applied 2026-10-03 — what the implementation measured

- **Validation.** `validate --strict` is clean, 0 errors and 0 warnings. All three guards fire on
  their failing cases, run on a scratch copy of the bundle:
  - `perTier` −0.1 trips `tuning.combat.estate_scaling_negative`;
  - a `combat.json` without the key is refused as `required field "estateScaling" is missing`;
  - a v14 manifest is refused by the handshake, which `ContentDTOTests` already covers.
- **Tests.** 324 → 336: `EstateScalingTests` +9 and `TuningTests` +3. The six fixtures that
  build a `CombatTuningDTO` by hand now pass the knob.
- **Digest.** `tuning` moved `c01ccfdb585f4a68` → `605fd06bd8abdfda`, and nothing else did:
  `records`, `spawns`, `quests` and `king` are byte-identical. The content hash moved `cd9d73bf`
  → `be4350a5`. `combat model` passes, and its estate anchors were negative-tested twice:
  - `perTier` 0.2 prints «estate scale at T7: got 2.20, design says 1.6»;
  - the façade with its exclusion removed prints that the dummy and the dog never spawn, yet
    scale at T7.
- **`simulate --strict`.** 0 broken bands and 18 warnings, the same as before. On the on-level
  `normal` fight at T7 the new section reads 5.6 → 8.6 rounds, 11.2 → 17.1 Vigor, 22% → 58% of
  a bar and a 100% → 98.8% win. That is the worst case: by T7 most of the forest is creatures the
  player has outgrown, which the damage shift makes cheap.
- **Pace.** Warrior 125.5 → 167.0 days, archer 120.9 → 159.6, mage 113.8 → 150.9. All three stay
  inside the 72–200 band, so no warning fired.
- **`spec gates`** prints the creatures column, and `spec-progression.md` §3 was refreshed.
  `spec opening` is byte-identical, as T1 promised.
- **The harness.** It was rebuilt against the repo's `ROIContent` and `ROISim`, scaling each
  creature with `CombatMath.scaled` and the knob read from the shipped bundle. Its fight table
  came out byte-identical to the 2026-10-02 sandbox's, all 3,234 rows, and the expedition model
  gives the same 74 / 96 / 130 / 184 / 249 / 477 days as §11.4.
