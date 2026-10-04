# CLAUDE.md — ROI Project Reference

## Project Overview

**Rest Of Iryna (ROI)** is a massively-multiplayer medieval text RPG for Telegram, built in Swift. Players explore a wilderness plagued by rabies, build up an estate of production plots, battle beasts, band together in guilds and duel in the capital's arena. (The estate is an abstract slot-indexed plot list — the 30×30 spatial grid was removed from the roadmap on 2026-05-18 and must not be proposed again, and **territorial warfare went with it on 2026-09-15**: it stood entirely on map tiles. `GDD.md` §11 is SUPERSEDED.)

- **Language:** Swift 6.2 (strict concurrency, `ExistentialAny`)
- **Platform:** developed on macOS 14+, **deployed on Linux/aarch64** (a Raspberry Pi 5 under pm2). Telegram Bot, long polling
- **Database:** PostgreSQL 15 via Fluent ORM (the Pi's native cluster, port 5433)
- **Target:** 1,000-3,000 concurrent players

## Key Documents

| File | Purpose |
|------|---------|
| `GDD.md` | Full game design — classes, vigor, exploration, combat, estates, economy |
| `README.md` | Stack overview, architecture diagram, setup guide, dev notes |
| `TODO.md` | Phased implementation tracker with progress markers |
| `Prompt.md` | Compact session primer — read this at session start |
| `content/spec/*.md` | The five approved content specifications (Phase 9, closed 2026-09-01) plus `king.md` (the decree chain, 2026-09-21). Numbers in them are emitted by `roi-content spec`, never typed — refresh the `<!-- generated -->` blocks after any content edit |
| `.memory/INDEX.md` | Project memory system index |
| `.memory/status.md` | What's implemented vs planned |

## Architecture (Router-Controller State Machine)

```
TGUpdate -> TGDispatcher -> Auth check -> SessionCache -> RouterStore.process(routerName)
                                                              |
                              RegistrationController  MainController  SettingsController  ...
```

Each user has a `routerName` field. Updates route to the controller registered under that name. Controllers transition by setting `session.routerName` and calling `saveAndCache()`.

**The router is resolved INSIDE `RouterStore`'s per-user chain**, on the routerName as it
stands — never earlier. The SDK hands every update to its own `Task.detached`, so two quick
taps are both read before either has transitioned; `TGDispatcher` still passes the key it
read, but only as a fallback. `[ROUTE]` in the log fires when the requested and live keys
differ, which measures the race rather than arguing about it.

**A refusal carries the keyboard of the router the player is actually on**
(`TGControllerBase.currentKeyboard(for:lingo:)`) — a notice sent with no markup leaves
whatever was last set. Better still, a guard re-renders the screen that owns the state
instead of only refusing, so the mis-tap is also what repairs it.

Why both, and the symptoms each fixed: `.memory/architecture.md`,
`.memory/controller-pattern.md`.

## Source Layout

Game code lives in `Swift/` (not `Sources/`). The content pipeline lives in `Modules/`
(also not `Sources/` — a `Sources/` directory would contradict the rule above).

```
Modules/
├── ROIContent/          # Foundation-only: content DTOs, loader, validator, live snapshot, EquipmentSlot
├── ROISim/              # The balance math itself + deterministic RNG + the simulator
└── roi-content/         # CLI: `validate [--strict]` · `simulate [--runs N] [--seed S] [--strict]` · `spec <table>`
Tests/ROIContentTests/   # Fast tests — no Fluent/Postgres/Telegram in this graph
```

**The combat, progression and budget math lives in `ROISim`, not in the services.**
`CombatService`, `User`, `ItemBudget` and `VigorService` keep their whole public API and
delegate to `CombatMath` / `ProgressionMath` / `BudgetMath`. The direction matters: a
simulator that reimplements the maths measures the simulator, so the bot and
`roi-content simulate` execute the same lines. Add a new roll or curve THERE and expose
it through the façade — never as a second implementation beside it.

`Swift/configure.swift` carries `@_exported import ROIContent` / `ROISim`, so files under
`Swift/` use those types without their own import line.

```
Swift/
├── entrypoint.swift     # @main, calls configure()
├── configure.swift      # Bootstrap: DB, Lingo, Bot, Hummingbird (projectPath read from `ROI_PROJECT_PATH` env with dev-Mac fallback)
├── routes.swift         # RouterStore actor + per-user dispatch serialization
├── Controllers/         # Game screen controllers
├── Models/              # Fluent models + catalog façades (Item, Enemy, Recipe, … — data lives in content/data/*.json)
├── Migrations/          # DB migrations
├── Services/            # Domain services (pure where possible)
├── Telegram/            # Router engine + TG client
└── Helpers/             # TGControllerBase, SessionCache, ScreenEdit, PhotoCache, Countdown, Lingo ext, env, EphemeralChatState
```

Per-file annotations: `.memory/file-map.md` (canonical, updated per session).

`Localizations/` — `en.json`, `uk.json`. `Assets/` — registration artwork + per-level estate art.
`content/data/` — the game itself as JSON. `content/spec/` — the five content specifications signed off in Phase 9 (closed) and `king.md`. `content/lore.md` — the world (families, zones, visual reference); `content/bestiary.md` and `recipes.md` are pre-rebalance reference docs, the bestiary one marked SUPERSEDED.

## Game and Content Rules

Each rule below states the imperative and the trap, then names the record that holds the
measurement behind it. **Never delete a "never do X" guard from this file** — auto-memory
files are not loaded each session, so a rule moved out of here goes invisible
(`feedback-docs-keep-the-rule`).

### Content and tuning are data

**Game content AND balance numbers are data, not code.** ALL of it — items, enemies, recipes, the
weapon / bag / estate ladders, the five capital institutions (trader, tavern,
market, guild, arena), the Master's shop, estate plots, the fortune deck, the
daily quest pools, the King's decree chain (`king.json`), the Training Ground ladder (`training_ground.json`), the rarity ladder
(`rarities.json`), equipment sets
(`sets.json`) and the foraging zones (`zones.json`) — lives in `content/data/*.json`; the `*Catalog` types are façades over
a validated snapshot loaded at boot. Adding content is a JSON edit plus locale keys
in both `en.json` and `uk.json` — never a Swift array edit.

The **tuning constants** live beside them in `content/data/tuning/` — six tables
(`combat` · `vigor` · `exploration` · `progression` · `economy` · `time`) holding
hit/crit maths, vigor costs, the XP curve, per-class starting stats, gear wear and
every duration. `CombatService.baseHitChance` and friends are computed `var`s over
the snapshot, so **never add a `static let` that reads a catalog or a tuning value** —
it runs at type-init and traps before `ContentBootstrap.load`.

`tuning/time.json` splits `gameTime` from `realTime`. A `gameTime` value is authored
at scale 1 and **DIVIDED by `scale`** at the point of use, so a bigger scale means a
faster game: at the 60 the whole rebalance ran on, a 3600 s plot cycle was 60 s.
**`scale` is 1.0 since 2026-09-09** — game time is real time. `realTime` never scales at
all: Telegram's 24 h dice-delete window is a protocol constant, not a balance knob, and
so are the trade TTLs and the 12:00 rollover.

**Every equippable item is bounded by a stat budget.** `budget(itemLevel, slot, rarity)
= slotWeight · (6.0 + 1.5·itemLevel) · rarityBudget` in `tuning/budget.json`; an item's stats
ARE that budget spent at fixed exchange rates, and the validator refuses an overspend. The
combat curves were derived from the same budget, so an item that respects it cannot move any
stat's percentage — which is what makes adding items safe. Two consequences:
- `itemLevel` is NOT `tier`. Tier is a crafting-ladder rung (1–9 on the weapon ladder); item
  level is the budget input (1–40). Since 2026-10-04 the weapon ladders map nine tiers to
  1/5/10 … 40, each rung's item level equal to the player level it opens at.
- **Never give anything a flat bonus — items OR techniques.** Enchant is `1 + 4% × level`
  of the item's OWN stats, set bonuses are capped against their members' combined budget,
  and every Super stance lifts by a multiplier of the character's own stat. The same
  +32 DEF is 267% of a level-1 chest and 14% of a level-40 one. No flat number works at
  both ends, and `roi-content simulate` audits every lift for exactly this.

**`/reload` hot-swaps content without a restart** (dev-only, `developerUsers`; `/content`
shows what is loaded). The order is the safety: **parse → validate → live-check → build
→ install**, with `install` the only infallible step and last, so a refused reload leaves
the running game untouched. `LiveReferenceCheck` refuses a bundle that would drop an id
live rows still point at — if you add a column that stores a content id, add it to
`LiveReferenceQuery.collect` or the hot swap will happily break it. **Lingo is NOT
reloaded**: new locale strings still need a restart.

**A key the validator REQUIRES is not a key anything renders.** `ContentValidator`'s
`requireKey` proves a string exists in both locales, never that a player can reach it — four
of five `plot.type.<t>.desc` blurbs were enforced for months while `PlotCatalog.descriptionKey`
was read in one dead branch. **When you add a `requireKey`, name the screen that renders it**,
and when a screen describes a thing it must describe ALL of it: both lines are built from the
data (`bonusOutput`, `descriptionKey`), so a future two-stream plot gets them free. Auto-memory
`project-plot-streams-and-dead-lore`.

**Content is specified before it is authored.** `content/spec/*.md` holds the signed-off
list — what creatures exist, at what level and archetype, what items fill which slot, what a
set bonus may cost and where silver enters and leaves — and content work follows it, never
goes around it. Every number in a spec is printed by `swift run roi-content spec
<progression|gates|bestiary|items|sets|economy|opening|king>`, never typed, so a specification
cannot drift from the generator it feeds. `opening` ROLLS rather than solves, so give it
`-c release`.

**A spec quotes generated tables inside `<!-- generated: … -->` markers, and the marker
records the COMPLETE command including flags** — a block produced with extra flags under a
bare marker cannot be reproduced. **After any content edit, re-run the command in the marker
and refresh those blocks.** It protects tables, not the prose beside them: a hand-counted
number in a sentence is exactly where the one real error of Phase 9 lived. See auto-memory
`feedback-content-spec-before-authoring`,
`feedback-printed-numbers-protect-tables-not-prose`.

Full rules, the migration pattern and the verification discipline: `.memory/content-pipeline.md`.
Run `swift run roi-content validate --strict` before committing content, and
`swift run -c release roi-content simulate` after touching `tuning/combat.json`,
`tuning/progression.json`, `tuning/budget.json` or the archetype table — those four
decide every fight, and the report is the only thing that shows what moved. It bands
level invariance (a level-1 and a level-40 fight must play the same), the p90 tail,
win rates, pace to the cap and the shipped roster against its own archetype contract;
`--strict` exits 1 on a broken band. Every band measures the AUTHORED contract: the
estate's strength (below, under Combat) is printed in a section of its own and priced into
the pace, never banded, because it departs from level invariance on purpose.

### Access

**Access is invite-only and lives in the database.** The `allowed_users` table
(`AllowedUser` / `AccessControl`) replaced the hardcoded `allowedUsers` array; `foundingUsers`
in `configure.swift` is now only the migration's seed list. **To let a new tester in use
`/link`** (developer-only), never a code edit. The gate lives in `TGDispatcher` **ahead of
routing**, so a refused stranger never gets a `User` row. `allowed_users` is in
`WipeForRebalance.preserved` — a wipe resets the game, not the guest list — and
`developerUsers` stays hardcoded and allowed before the table is read: the brake against
locking yourself out of your own bot. Auto-memory `invite-only-access`.

### Quests and the daily cycle

**A daily job is taken by hand** (2026-09-07). `QuestCatalog.daily` still decides WHICH job
each NPC offers — a stable hash of `userId:npc:dayStamp`, rolling at 12:00 Kyiv — but the
offer sits on the board until the player accepts it at the NPC (`QuestProgress.accepted`,
`QuestService.accept`). `record` neither creates nor ticks an unaccepted row, so taking a job
STARTS the count and never backfills the day. Each job carries a `minLevel` and the pool is
filtered before the hash; the validator refuses a pool whose cheapest job starts above level
1. Rewards are authored at level 1 and scaled at payout by `ProgressionMath.questReward`, so
**the board must quote `Status.reward`, never `def.reward`**.

**A taken job does not burn at noon** (2026-09-19, the owner's call). It stays open until it is
turned in, and while it is open that NPC offers nothing new: **one open job per NPC**, which
`QuestService.accept` enforces and every other reader relies on — the board, `record`, the Turn
in button (no day in its callback: only one job can be meant) and the trader's "wanted for a
job" warning. Only a carried job can be dropped (`QuestService.abandon`, asked first).
Auto-memory `project-quests-taken-by-hand`.

**A job is phrased once** (2026-10-03): the NPC board and the journal both print a taken job through
`CapitalController.questRequirementLine` — the decree's `RequirementLine`, a delivery's items or a
counter's `quest.counter.<c>` label (validator-required). The 8-cell bar (`questProgressBar`) is
the BOARD's only, on the owner's word, and an untaken offer carries neither line nor bar. Досвід is
📖 on every screen, Снага 🍖, and whatever the player GETS — a job's or a decree's reward, the claim
button, a tarot card's loot — 💰 (the King's 🎁 went 2026-10-04, the owner's pick).

**The innkeeper's job also teaches cooking.** `recipes.json` → `unlocks` is a ladder of
`{recipeId, npc, minEstateTier}` rungs; finishing a job pays the lowest rung the player has
earned and does not know, one per job, resolved by `RecipeUnlockDTO.next` — the ONLY resolver,
asked by `QuestService.finish` at the payout and by nothing earlier. **No screen announces the
recipe in advance** (2026-09-19): `rewardPhrase`, the board and the journal quote silver and
Vigor only. A recipe is **not** scaled — it is not a number — and the NPC's line is a message
of its own (`recipe.<id>.taught`, then the shared `quest.recipe_learned` under it), because
`postStatusBanner` deletes the previous banner and an NPC speaking is not a status line.
Auto-memory `project-npcs-teach-recipes`, `project-food-is-priced-not-picked`,
`feedback-a-checker-that-cannot-fail`.

**The King's decree chain is ONE linear list, and its array order is the game.**
`content/data/king.json` holds 39 decrees from level 1 to 25; the player holds exactly one,
and turning it in opens the next. Four rules the validator enforces, each of which a design
draft broke first: **no decree pays more Vigor than the pool at its level**
(`100 + 5·L` — the grant runs through `min(maxVigor, …)`, so the excess is a number the
player is shown and never gets), **every decree pays something** (an unpaid step is a screen
tapped through for nothing), **food is a named item and a count**, never "portions" (a dish
is 10–72 Vigor, so portions cannot be added up), and **a `player_level` decree's target must
equal its own `level`**. A decree's kind is DERIVED — it is a level decree when one of its
conditions is `player_level` — because a second discriminator beside the conditions is a
field that can disagree with them. No screen shows "decree N of 39". The chain is printed by
`roi-content spec king` and hashed by the fifth digest line, `king`. A fifth rule came from a
live change, not a draft: **a Training Ground or technique decree may not sit below its first
technique's floor** (`king.technique_before_its_floor`) — «Наука бою» and «Перший прийом» sat at 9
against a floor of 10, and the estate decree they need came after them, until the 2026-09-27
reorder. A sixth, `king.weapon_tier_before_its_gate`, came the same way. «Гострий край» asked
at level 4 for a weapon rung nobody could buy before level 7, because the upgrade lives in
the T3 workshop. It moved to 5 with the 2026-10-04 ladder.

**A player's place in the chain is a POSITION** (`KingProgress.decreeIndex`), so reordering or
inserting decrees moves everyone standing in or past the change. Read `king_progress` off the
machine first, and ship a migration with the edit. Two shapes exist, both because a second
payout is recoverable and a skipped decree is not:
- `RewalkReorderedDecrees` sends anyone inside a reordered window back to its start. It is safe
  only when the window holds nothing but live state reads.
- `ReseatDecreesById` (`KingChainReseat`) re-seats each row on the first decree of the new order
  it had not passed. Use it when the window holds events.

Verify the TABLE afterwards.

**Eleven of the eighteen condition kinds are live state reads; seven are events that leave
no trace.** `KingService.record` is the one funnel for those seven, and it ticks
`KingProgress.counter` ONLY when the open decree is the one asking — nothing accumulates
ahead of time, so "defeat five beasts" counts from when the decree opens. Each hook sits
beside the counter that already passes through that site. **A harvest is an event, not a
state**: `Plot.lastHarvestedAt` starts at the moment the plot is claimed and is reset by
every harvest, so it can never answer "has this player ever harvested". The palace is a
`Location` inside `CapitalController`, not a controller — `routerName` stays `"capital"`
all over town. Spec: `content/spec/king.md`; the two decrees cut on 2026-09-21 and why:
auto-memory `project-king-decrees-deferred`.

### Vigor, rest and background work

**Vigor does not regenerate** (Phase 8E). The pool is a stock; food, quests and the
level-up grant are the only sources, and the estate's plots are the intended income —
which is what makes the pool plus the food in the bag the real limit on how deep the
wilderness can be walked and still walked out of. Never reintroduce a trickle: the old
one deliberately did not pause during an expedition, so a player could stand at km 25
and wait out a full pool.

**Every Vigor spend goes through `VigorService.drain(_:base:multiplier:)` or its `action:`
form**, which applies the active tarot card's `vigorDrainMultiplier` on top of the stance's and
rounds half up. `drain(_:amount:)` is for a number that is already final (the dev `/drain`): the
techniques, the stance activation and the mage's flee tax called it until 2026-10-04 and the
card never touched them. Base costs are 1–5, so a card multiplier must move a 2 by a whole
point after rounding — ×0.75 moved nothing, which is why the Chariot is ×0.5.

**A Vigor reward that will not fit is asked about, never silently clamped** (2026-10-04). Both
payouts clamp to the pool, so a decree paying only Vigor (20 of 39) turned in at full Vigor
paid nothing, over a bare «💰». `VigorRewardNotice` is the one phrasing of that loss:
- a warning on the card once the decree is done or the job is ready;
- a question on the turn-in tap (`king:report` → `king:report_ok`, `quest:do:` →
  `quest:do_ok:`);
- a banner line naming what was lost.

The arithmetic is `VigorService.overflow`, the payouts' own clamp asked beforehand. A level-up
inside the payout moves the cap and the pool by the same step, so it cannot change the answer.
Asking costs the player nothing, because a decree and a taken job both wait. A new Vigor reward
goes through the same three.

**HP regeneration is a different mechanic from Vigor and stays — but it is a PLACE, not a
pause between fights** (2026-09-10). `HealingService.canRest` names the three states that
suspend it: an `ExplorationState` row (in the forest), a `TravelState` row (on the road) and
`location == capital` (in town) — the road needs its own check because `location` is not
flipped until arrival. Callers query the rows and pass the answer; `tick` does no lookups of
its own, and away from the estate the clock is CLEARED, not merely skipped. The away-from-home
heal is a **cooked dish** (a quarter of its silver price in HP); `potion.heal_small` and
`potion.heal_medium` are obtainable nowhere. Auto-memory `feedback-a-checker-that-cannot-fail`.

Regen is **computed lazily on interaction**, so both ends of an absence are stamped
explicitly: `suspendResting` when an expedition or trip begins, `beginResting` when the
player lands home. A tick that only runs on interaction cannot observe a transition that
happens while nobody is interacting.

**What finishes while nobody is looking needs a watchman.** `RestNotificationService` (one
`Task.detached` on `realTime.restSweepInterval`, 60 s) answers four questions per player:
- HP topped out at the estate;
- the fortune teller's 24 h cooldown elapsed;
- the 12:00 job rollover;
- a task became ready (2026-10-04): the open decree complete, or a taken job ready to hand in.

It runs the regen through `HealingService.tick` — never a second copy of the arithmetic. **A
task's readiness is its board's own test** (`KingService.standing`, `QuestService.liveDone`),
asked through `readyUnannounced`, so the notice cannot announce what the palace or the NPC would
refuse. It fires once per task, on markers in the progress rows. Those markers are written by a
one-column query, never a row save, because the player may be ticking the same row.

**A background writer MUST take the session-cached `User` when one exists**
(`SessionCache.peek`): Fluent saves whole rows, so a sweeper holding its own copy silently
undoes the tap the player made a second earlier.

Full reasoning: `.memory/game-core.md` §Rest and the road, `.memory/session-auth.md`;
auto-memory `project-rest-notification-watchman`,
`feedback-background-writers-session-cache`.

### Exploration and the forest

**Passive expeditions are capped at `passive.dailyBudgetMinutes` (180) per game day**,
counted in the authored minutes the three choices are written in — a budget in wall-clock
seconds would mean a different number of runs at every `time.scale`. Counter plus day stamp,
rolling at 12:00 like every other daily system. The picker offers only what the day can still
pay for AND the handler re-checks; the charge lands after `beginPassive` succeeds, so a
failed start never costs the player a run. Auto-memory `project-daily-and-storage-ceilings`.

**A leaderboard is a `Leaderboard`, never a `Rating`.** `rating` already means crit / dodge /
accuracy here, so the four boards behind the journal say «Рейтинги» to the player and
`Leaderboard` in every identifier. They are ALL-TIME, which is the first period and not the
only one: a seasonal board is a second READING with its own storage — **never a reset of
`deepestKm` / `totalKmWalked`**. The one exception was `ResetDeepestKm`, because that column's
MEANING changed; a period changing is not a reason. **One ladder, one implementation:** the
Arena's «Найкращі бійці» renders the same `LeaderboardService.view(.honor,…)` as the journal's
board. Auto-memory `project-leaderboards-will-go-seasonal`.

**A lifetime counter has exactly one writer — and WHEN it writes is half the rule.**
`totalKmWalked` is a tally: `User.recordStep()` from `ExplorationService.rollStep`, the funnel
all three kinds of step share, plus `handleHomeReached` for the last stride. `deepestKm` is a
RETURN: `User.bankDepth(_:)`, called only where the player is standing at the manor again,
from `ExplorationState.maxDepthKm` — `stepsDeep` counts back down on the way home, so it
cannot serve as the record. **Every change of depth goes through
`ExplorationState.moveTo(km:)`**, for the same reason the tally lives in `rollStep`: put a new
counter where the thing it counts already funnels. Auto-memory
`project-depth-is-banked-on-arrival`.

**The forest is left on foot, or not at all.** `/start` and a stray Cancel used to force-end
an expedition from any depth with the bag intact, and `/start` inside a fight deleted the
expedition row outright. Both re-render instead — the walk screen, or the fight — which
serves the case the hatch was really there for (a lost or stale keyboard) without ending the
walk. It has to be closed on BOTH screens: banking depth at the door makes any free exit the
cheapest way to bank a record, and a hatch closed in one controller just moves one screen in.
The one real escape left is a fight whose enemy id no longer resolves, which ends the
expedition rather than trapping the player.

**A creature's number is its rung, and a kill pays its full XP at any player level**
(2026-10-02, tier 2). Bands run km 3N−3…3N+1, no longer "level N → km N…N+9", and the
last creature is stretched to the horizon at km 49. `xpLevelDiff.perLevel` is 0. The knob
stays, so the penalty can come back by `/reload`, and so does the damage shift
(`levelDiff`): an outgrown creature dies faster and hurts less. What keeps the depth ladder
alive is the roster, because every trip walks out from the manor through the weaker
bands. The validator guards it: **a creature whose band starts deeper may never pay less XP
than one whose band starts shallower** (`enemy.xp_falls_with_depth`, which replaced the
guard that demanded a positive penalty). `simulate`'s pace table cannot see any of this:
it assumes on-level fights and never walks from the manor. `content/spec/spec-bestiary.md`
§10.5 describes the expedition model that can. Auto-memory `project-new-beasts-draft`.

### Combat

**One number, one source. A screen never sums two losses under one label.** A step can cost
HP twice — the event it rolled, and the hunger tick charged on every step once Vigor hits 0 —
so `ExplorationService.rollStep` returns a `StepResult` pairing the event with
`starvationHpLost`, each printed on its own line. Carrying it on the RESULT rather than inside
an enum case is the point: when each branch had to remember, six of ten starving-reachable
exits dropped it silently. **Add a new source of damage to `StepResult`**, never to another
source's number. Auto-memory `project-damage-sources-named-separately`.

**An escape is `CombatService.fleeSucceeds`, never a roll against `fleeChance`.** The
per-class chance (warrior 40 / archer 70 / mage 90) is half the rule; the other half is
`combat.json` → `flee.maxFailures`, the per-fight ceiling that grants the attempt to every
class after that many failures. Both live behind one function because a failed escape is an
unmissable hit at half armour with nothing dealt back. The count is per FIGHT
(`ExplorationState.combatFleeFails`, 0 on `beginCombat`, cleared on `endCombat`): per
expedition it becomes a resource the player spends rather than a floor under a bad run.
Auto-memory `project-flee-has-a-ceiling`.

**A rating is a rating on every screen, and is never labelled `%`.** `crit` · `dodge` ·
`accuracy` are RATINGS converted through a level-linear curve (`CombatMath.percent`), so the
same +5 crit is 4.16% at level 1 and 1.35% at the cap. Every screen prints the bare rating, so
the item, the level-up banner and the sheet add up against each other.
`CombatService.critPercent` / `dodgePercent` / `accuracyPercent` exist for when a screen says
what a rating is WORTH — BESIDE the rating, never instead of it — and **the level-up banner can
never follow**: 26% of level-ups would announce a drop. Auto-memory
`project-rating-vs-percent-display`.

**A death screen carries the round that caused it** (2026-09-27). `finishRound` hands its own
lines to `handleCombatDeath` — the player's action, the killing blow, a failed flee, a burn
tick — together with the enemy's HP left, and the shared `ExplorationController.handleDeath`
names what the wipe took: `InventoryEntry.wipeOnDeath` returns `[DeathLoss]`, not a count.
Before, the screen ahead of a death read ❤️ 45/150 and the next one «Ви полягли», with
nothing in between. Auto-memory `project-combat-lines-and-death-screen`.

**Techniques are bought with the Training Ground** (2026-09-27). It is a room of the house
(`EstateTierGates.trainingGround`, T4), not a plot: `training_ground.json` sells one technique
per level for silver + materials, and the player-level floor of each level is the technique's
own `requiredLevel` in `combat.json` (10 / 11 / 14) — read, never restated, so the building,
the simulator and `spec gates` quote one number. **Paying never charges for a technique the
player already knows**: after the paid level the building climbs through every next level whose
technique is known (`TrainingGroundLevelDTO.levelAfterCatchUp`, the one implementation the card
and `TrainingGroundService` both ask). The `training_ground` plot type is gone
(`MoveTrainingGroundOffPlots`) — do not bring back a plot that produces nothing. Auto-memory
`project-training-ground-building`.

**No technique blow hits harder than an ordinary crit, and every technique tap strikes**
(2026-09-27). Vital Shot is a guaranteed crit AT the standard ×1.5 and
`tuning.combat.effect_crit_above_standard` refuses more — at ×2.0 two shots killed the strongest
beast in the game every time. The kit is tuned so it shortens an elite fight by ~20% for EVERY
class; measure with `simulate --levels 21` and `--levels 40`, because the default sweep averages
in levels with no techniques at all. Raising a stance swings through `strikeRound` — the tap is
the round's attack, paid by the activation — and all three special defences deal damage back: a
tap that takes Vigor and strikes nothing is exactly what the owner had removed, so do not add
one. The stance lines carry no stat breakdown, on the owner's word. Auto-memory
`project-technique-rework`.

**A finished forest fight writes one `fight_log` row** (win / death / flee — not training, the
registration dog or the passive autobattle). Its numbers gather between taps in
`exploration_state.combat_tally`, so **a new source of player damage must feed `state.tally`** —
the blow it rolled (for `max_blow`) and the HP it actually removed (for every sum, so overkill
inflates nothing) — or the log quietly undercounts it, and `FightLog.record` runs with `try?`
BEFORE `endCombat`, which clears the tally. `fight_log.enemy_id` is history and deliberately NOT
in `LiveReferenceQuery`: a retired beast's old fights must never block a reload.

**Creature strength follows the ESTATE tier, never the player** (2026-10-03, `spec-bestiary.md`
§11). A spawnable creature fights with HP and ATK × `1 + perTier·(tier − 1)` (`tuning/combat.json`
→ `estateScaling`, 0.1: ×1.0 at T1, ×1.6 at T7); XP, loot, DEF, the ratings and its level stay as
authored. It is the one runtime multiplier on an enemy, and it does not reopen the trap the
frozen stat lines exist for, because a building the player chooses to raise cancels no gear and no
level. **Never key it, or anything like it, to the player's level or gear.** The formula and its
rounding live in `CombatMath.scaled(_:forEstateTier:spec:)`; the game reaches them only through
`Enemy.scaled(forEstateTier:)`, and **exactly two funnels call that**: `ExplorationService.rollEncounter`,
where an encounter is born (both modes), and `ExplorationState.combatEnemy(for:)`, where a fight
in progress is read back. **A new reader of a fight goes through the second, never through a bare
`EnemyCatalog.find`**, or its screen draws the HP the fight started with over a maximum the creature
never had. The dummy and the dog (`0...0`, never spawn) are not the forest and never scale. The tier
is read live, not stored on the row, which is safe only because nothing can raise the estate while an
expedition row stands — keep it that way. No screen announces the strength, on the owner's word;
`fight_log.estate_level` records it. Auto-memory `project-estate-scaling`.

**The arena duel is played in simultaneous rounds** (2026-10-03). Both fighters choose blind;
the round is played on the second choice, or when the clock (`arena.json` → `turnSeconds`, 15 s)
runs out with a missing choice played as a forced Defend — and both blows are rolled against the
state the round STARTED with. Alternating, the challenger's first blow won 60–66% of mirror
duels, so **never resolve one side's blow before the other's**. The round is
`DuelMath.resolveRound` in `ROISim`, reached only through `CombatService.resolveDuelRound`: a
Defend braces against the same round's attack, and when both fall the heavier blow wins
(equal blows draw). `sweepInterval` (1 s) is the clock's precision — at 10 s a 15 s round would
last up to 25. Every ending goes through `ArenaController.finish`, and settlement is a write the player
did not tap, so it takes the session-cached `User` (`ArenaService.liveUser`). Auto-memory
`project-arena-simultaneous-rounds`.

**The duel's choices are a cycle of three, and must stay one** (2026-10-03): Attack beats the
class special attack (the wind-up is cut off), the technique breaks a Defend (it cannot miss a
defender), a Defend turns an Attack (65% blocked, a 60% riposte). With two blind choices one
always dominates whatever the numbers — every brace measured was either never worth choosing or
always worth it — so **never fix Defend by tuning a two-choice duel**. The technique is free and
unlimited in the arena, because a use limit breaks the cycle once spent; a clock-forced Defend
blocks and answers nothing; two techniques both fizzle. The numbers are the arena's own
(`arena.json` → `duel`, content schema v16) — **never move `combat.json` →
`defendChipFraction` for the arena**: the forest's Defend, Iron Bulwark and Shadow Veil share it.
`arena.duel_defend_loses` warns when a riposte no longer outweighs what gets through the block.
The arena admits only those who have LEARNED the special attack (`ArenaService.isAdmitted`, at
the capital's door and again at the arena's home). Auto-memory `project-arena-technique-cycle`.

### Gear, inventory and storage

**A death takes the bag, never the class weapon.** `InventoryEntry.wipeOnDeath` is the ONE
implementation both death paths call — `ExplorationController.handleDeath` and
`PassiveExpeditionService.applyDeath`. Worn gear survives, and so does a bound starter weapon
carried in the bag; every other path already refused to take it, so death was the single hole
in a rule the rest of the code kept — and the only one that could not be undone. **Put the
next wipe in that function too**: a rule each caller filters for itself is a rule one caller
forgets. Auto-memory `project-death-spares-the-class-weapon`.

**Every gear screen renders all six `GearStats` fields, HP included.** HP reuses
`profile.health` rather than adding a `workshop.stats.hp`: `profile.*` and `workshop.stats.*`
are already two families for one set of names kept in step by hand, and that duplication is
exactly how `accuracy` shipped under two different Ukrainian words.

**The warehouse cap is enforced on every path in, including
`PlotService.harvest(to: .warehouse)`** — the estate's own income was once the only way to
overflow the store. Harvest is all-or-nothing like the bag, with the yield left standing on
the plot: partial cannot be expressed, because the Mine's two output streams share one
`lastHarvestedAt`. **No account is exempt** — the `isDeveloper` bypass is gone from all four
warehouse checks (it remains on the BAG, a different ceiling). Auto-memory
`project-daily-and-storage-ceilings`.

**A fit check must be the SAME arithmetic as the writer it is predicting, in the same
units.** `InventoryEntry.add` counts UNITS and throws when it will not fit; `CraftingService`
predicted in ROWS and treated "a row already exists" as room — the throw escaped the callback
handler, and because the drain runs before the add with no transaction it ate the ingredients
on the way out. `TradeService` has the shape to copy: `used − outgoing + incoming ≤ cap`, in
units, with the dev bypass matching the writer's. **Predict for EVERY store the write could
land in.** A full bag is no longer a refusal to craft — the output goes to the warehouse and
the banner names where it landed. Auto-memory `project-fit-check-matches-the-writer`.

**What a place can draw on is where it stands** (2026-10-05). The Master is in the capital, which
has no warehouse, so his lesson and his enchant count and take materials from the BAG alone. The
workshop, the kitchen, the Training Ground and the estate and bag upgrades stand at the estate
and draw bag + warehouse. **A card counts in the same place its service draws from.** The enchant
counted bag + warehouse from the capital until 2026-10-05, so it told a player with an empty bag
«маєте 14».

**A transfer that RE-CREATES a row resets everything the row knew.** Tier, wear and enchant
are per-instance (`GearState`), so a delete-here-and-`add`-there path hands back a
factory-fresh item — which made a warehouse round-trip a free repair that also undid the max
shave and burned the enchant. Both `InventoryEntry` and `WarehouseEntry` carry `GearState` and
every create-path takes it as `carrying:`; `TradeService` shows the other correct shape, it
REASSIGNS the owner. **A new per-instance column belongs IN `GearState`, not beside it.** The
screen half: **the Master repairs a ROW, not a loadout** — a list must ask the same question of
every kind it lists. Auto-memory `project-gear-state-travels-with-the-unit`.

**A gear list names ROWS, and the workshop is the one place a piece is destroyed**
(2026-09-27). Copies differ by wear, so the bag's gear list and the warehouse's gear rows
print each copy's wear and every button carries the ROW's id (`inv:info|equip|unequip:<uuid>`,
`estate:wh:deposit|withdraw:<uuid>`). An item-id [Одягнути] left in chat acts only when one
copy qualifies and otherwise redraws the list — it used to take whichever copy the heap
returned; the warehouse's old item-id buttons still move the OLDEST copy, which is
deterministic and reversible, so they were left as they were.
**«Розібрати»** (`CraftingService.salvage`, workshop → 🔨) returns the piece's recipe ×
`gear.salvageFraction` × max/`maxDurabilityStart`, floored per line by `SalvageMath` —
derived, never a picked number — so armour repaired down to 1/1 gives nothing back but still
leaves the bag. It predicts the fit in units for both stores, like `craft`, and names the
row it destroys. Auto-memory `project-salvage-and-gear-rows`.

**Armour is not crafted** (2026-09-28, the owner's call): the Master is the only source, at the
prices he always had. The four Forester recipes stay in `recipes.json` as PATTERNS —
`RecipeCategory.isCraftable` is false for the tannery, so no list shows them and
`CraftingService.craft` refuses them — because salvage reads them to know what a piece gives
back. **Deleting them as unused breaks «Розібрати» for every armour piece**, and with it the only
way to be rid of armour worn to 1/1.

**A weapon ladder is ONE object.** The three upgradable weapons render through
`ItemDisplay.nameKey(for:tier:)` → `item.<id>.t<tier>`, and the rungs must keep a word in
common — the player is upgrading a thing, not swapping it — which `locale.ladder_name_drift`
warns about. Wherever a label describes an inventory ROW rather than a shop listing, pass the
row's tier (`CapitalController.itemLabel(_:tier:lingo:locale:)`). **An item id alone cannot
name a row**, so a service that reports rows hands back the tier with them:
`GearConditionService` returns `BrokenPiece(itemId:tier:)`, not `[String]`. Auto-memory
`feedback-ladder-names-one-noun`.

**The weapon follows the PLAYER level, and its first rung is the Master's lesson**
(2026-10-04, `spec-items.md` §9).
- **The ladder.** Nine rungs, one every five levels (1 … 40). Each carries its own
  `requiredPlayerLevel` and is budgeted at that level, at 75% of the shipped growth.
- **Why.** The estate used to open tier N at T N, which put the item-level-40 sword in hand
  at level 13. The model behind tier 2 of the bestiary had assumed `itemLevel <= level` all
  along.
- **Who sells what.** Tier 1 → 2 is sold only by the Master
  (`WeaponUpgradeService.lesson`): the rung's materials from the bag plus `master.json` →
  `weaponLessonSilver`. The workshop refuses a tier-1 weapon as `.notLearned`.
- **"Has learned" is derived** (tier ≥ 2), so never add a column for it.
- **The gate is one rule**, `WeaponLadderRules.highestTier`, shared by the catalog, the
  clamp migration and the tests.
- **The upgrade button lives only in the workshop, which opens at T3.** That is how
  «Гострий край» (level 4, weapon tier 2) could not be finished before level 7.
  `king.weapon_tier_before_its_gate` now refuses a weapon decree filed below its rung's gate.
- Auto-memory `project-weapon-ladder-rework`.

### Screens, buttons and refusals

**Every "time left" the player sees goes through `Countdown.format`** — `2год 5хв` ·
`1хв 22сек` · `5хв` · `42сек`: the two most significant units that carry a value, with an
exact one dropping its tail so a whole-minute window still reads `5хв`. Durations are never
written into copy either — the expedition buttons, the tarot window on the fortune teller's
price line and the invite window are all printed from the values that own them.

**A tarot card is phrased by `FortuneDisplay` on every screen** — the reveal, the fortune
screen and the profile — from its `FortuneEffect`, so no locale key carries a card's number.
The 22 hand-typed `buff_desc` lines it replaced (2026-10-04) still matched the JSON, in a second
phrasing («×1.5» against «+50%») that no retune could reach. A one-shot's gift is printed from
the RECEIPT (`oneShotParts`), never the card: the Wheel rolls and every loss is clamped.

**"What it costs / what you have" is ONE sentence, and `RequirementLine` renders it.**
`✅ 1× 🪵 Соснова дошка  (12/1)` — marker, the count the recipe asks for, the label, then the
fraction in brackets. A gate line carries no count, which is why the count belongs to
`RequirementLine.item` and not to `render`. Every material list, every gate and the shortage
modal go through it, so a screen and the modal that refuses the same tap cannot phrase one
number two ways. **⛔ is retired.** **Current-against-maximum is a DIFFERENT sentence** —
durability `0/100`, the bag `18/25`, a plot `40/40` — and must not grow a ✅/❌: a full bag is
not a failed requirement. Auto-memory `project-requirement-line-one-format`.

**And the shortage modal is CAPPED at 200 UTF-16 units, because Telegram refuses a longer
`answerCallbackQuery` outright and every call site swallows that with `try?`.** Five of them
were over — the Governor's Feast and every estate step from T4 up — so the tap that was
supposed to explain the refusal produced no modal at all. `RequirementLine.shortageModal`
drops rows until it fits and ends with a wordless `… +N`. **Measure an alert in UTF-16 and
measure it in Ukrainian**: the English side of all five was comfortably under, which is
exactly how the overflow stayed invisible to the person who wrote it. Auto-memory
`project-requirement-line-one-format`.

**A choice that cannot be undone is asked, not just tapped.** Nothing a player can do deletes
a `Plot` row or changes its type (the one deletion ever was the 2026-09-27 migration that retired
the `training_ground` type) (`PlotService` has `claim` and `harvest` and no third verb),
so claiming a slot on one tap cost it for the life of the account. `estate:plot:type:` draws
the picked type's card and asks; only `estate:plot:build:` writes. **Which callback keeps its
old name is part of the fix**: the QUESTION inherited it, so a stale picker message in chat
history lands on the safe path. This is the shape every buildable thing already had — list →
detail → act, and `ItemCard` before every purchase. Auto-memory
`project-plot-streams-and-dead-lore`.

**A dead inline button is the house symptom, and it has two causes.** A **throw** out of a
callback handler spins it forever — nothing answers `answerCallbackQuery`. A callback **no
handler claims** is just as silent: `Router.process` reaches `unmatched` only when
`update.message != nil`, which a callback query never has. So a controller that renders
another controller's screen must END by forwarding what it does not recognise —
`ExplorationController` and `CapitalController` both hand the rest to `MainController` — and
it must be **a catch-all, never a list of prefixes**. A handler that answers LATE — because a
refusal is a modal, which must be the tap's only answer (`finishMasterLesson`,
`finishMasterEnchant`) — answers in a `catch` before rethrowing, or a throw ahead of it spins the
button. Auto-memory `project-dead-inline-buttons`.

**A number typed before its button gets a hint, never the root screen.** Every quantity is
asked AFTER a button (a trader card's [🪙 Купити], a warehouse row's [✏️ N], a vault row),
and `unmatched` used to answer a number nobody had asked for by re-rendering the
controller's root, which buried the inline screen the player was on. The server never knows
which inline screen is open, so it cannot redraw that one. A controller with a numeric
prompt calls `answerStrayNumber` **after** its own pending-prompt checks and **before** its
root fallback. WORDS still fall through to the re-render, because stray text is usually a
stale reply-keyboard tap and the redraw is what repairs it; a number is never a button
label. A prompt still waiting for a BUTTON (the warehouse's «Куди?») repeats itself with a
hint instead. Auto-memory `project-stray-number-hint`.

**A screen that can answer a question should answer it before the player gets it wrong.**
The recipe screen printed what a dish REQUIRES and never what the player HELD, so the only
way to read your own pantry was to tap Cook and fail — the shortage modal was the one place
the number appeared. `CraftingService.stock(for:on:)` is now that number for both the screen
and the craft itself (two queries, whatever is asked about), so a screen cannot quote a total
the button then disagrees with.

## How to Add a New Controller

1. Create `Swift/Controllers/MyController.swift`:
   - Subclass `TGControllerBase`, mark `@unchecked Sendable`
   - Override `attachHandlers(to:lingo:)` — create Router, register paths
   - Override `generateControllerKB(session:lingo:)` for persistent keyboard
   - Override `unmatched(context:)` — call `super.unmatched()` first (skips global cmds)
   - Callback handlers must be `static`

2. Register in `AllControllers.swift`:
   ```swift
   static let myCtrl = MyController(routerName: "myname")
   static let all: [TGControllerBase] = [ ..., myCtrl ]
   ```

3. Transition from another controller:
   ```swift
   context.session.routerName = Controllers.myCtrl.routerName
   try await context.session.saveAndCache(in: context.db)
   ```

4. Register localized buttons for ALL locales (important for text matching):
   ```swift
   let locales = Commands.myCommand.buttonsForAllLocales(lingo: lingo)
   for button in locales { router[button.text] = onMyCommand }
   ```

## Key Patterns

### Session Access
```swift
context.session          // Current User (via properties["session"])
context.session.routerName  // Which controller handles this user
context.session.locale      // "en" or "uk"
```

### Sending Messages
```swift
try await context.bot.sendMessage(session: context.session, text: "...", parseMode: .html, replyMarkup: markup)
```

### Inline Keyboards (callback_data max 64 bytes)
```swift
let button = TGInlineKeyboardButton(text: "Label", callbackData: "prefix:value")
```

### Localization
```swift
lingo.localize("key", locale: session.locale, interpolations: ["var": value])
```

**The player is addressed as «ви» (uk).** Every Ukrainian string that speaks to the player
uses the formal plural — `ви / вас / вам / ваш`, present `-єте/-ите`, imperative
`-іть/-те` — NPC speech included. That settles past tense and adjectives on its own, so the
only thing left that declines by gender is a **noun naming the player**.

**One exception, and only one** (2026-09-19): the innkeeper's recipe lessons — the six
`recipe.<id>.taught` lines — say «ти», by the owner's decision. It covers those lines and
nothing else: the `quest.recipe_learned` line under them, his board and the rest of the tavern
stay «ви». Under «ти» a past tense or adjective about the player declines by gender again, so
such a line goes into `uk.json` as `.m`/`.f` — the render site falls back to the gendered
lookup by itself.

**Ukrainian agrees with the NOUN being named** — «лук зламав**ся**», «чоботи зламали**сь**»,
«Шахта заповнен**а**» but «Курник заповнен**ий**». Items declare `item.<id>.gender` and plots
`plot.type.<type>.gender` (`m` · `f` · `n` · `pl`), **in `uk.json` only**: gender belongs to
the WORD, not the object, and English never asks. The suffix rule itself is
`Lingo.localize(_:agreeingWith:locale:)` — ONE implementation, which
`ItemDisplay.localize(_:agreeingWith:lingo:locale:)` wraps for items; a new kind of noun
looks its gender up and calls the same function rather than copying three lines and
forgetting `pl`. The validator warns on a missing declaration and errors on a bad one, for
both kinds.

**An enemy's name is nominative only.** Content stores one form, so a line must make the name
its SUBJECT or set it after a dash — «… — %{enemy} втрачає N ОЗ» — never after a preposition
or as an object: «по %{enemy}» printed «по Скажений ведмідь» on every plain hit until
2026-09-27. The last four lines that broke it were rewritten on 2026-10-02, with tier 2's
five new names, in the owner's wording. **A player's nick is the same** — free-form, so no
declension can be computed: fifteen lines that broke it («проти / від / у / із %{nick}»,
«Очікуємо %{nick}») were rewritten on 2026-10-03, six of them in the arena. The one-liner
that finds a new one is in `.memory/localization.md` — run it after any copy edit that touches
`%{enemy}` or `%{nick}`.

**Gendered text (uk feminitives):** a string that names the player with a gendered noun uses
`lingo.localize("key", gender: session.gender, locale: ..., interpolations: ...)`, which
looks up `key.m`/`key.f` for `uk` and the plain `key` for English — so **never duplicate
English**, only `uk.json` gets `.m`/`.f`. Player gender is `User.gender` ("m"/"f", nil=male),
chosen at registration step 1. When new copy names the player, either add `.m`/`.f` + the
overload, or phrase around the noun.

**A string whose point is a NUMBER routes through `lingo.localize(key, count:, locale:)`.**
Ukrainian has three noun forms, so `uk.json` carries `.one`/`.few`/`.many` and English keeps
the plain key. The rule is `UkrainianPlural.form(for:)` in `ROIContent` — there, not beside
the Lingo extension, so the tests can reach it — and its one trap is that **11–14 take
`many` despite ending in 1–4**: «21 срібник» but «11 срібників». The older «раунд(ів)»
dodge stays where it is; use this where the count is the sentence.

Key lists, the three-way sweep that catches a missed mid-sentence imperative, and the full
rationale: `.memory/localization.md`; auto-memory `feedback-formal-address-vy`,
`project-item-grammatical-gender`.

### Daily resets (`Swift/Helpers/GameDay.swift`)

**RULE — every "once per day" system keys off `GameDay.stamp(...)`, never off a
raw calendar date.** The in-game day rolls at **12:00 Kyiv, not midnight**, so an
evening session plus the following morning stay inside one day instead of being
cut in half. `stamp(date)` returns the `yyyy-MM-dd` key of the day an instant
falls in; store that key alongside the counter and compare keys to detect a
rollover (see `ArenaProfile.fightsSpentToday` and `QuestProgress.dayStamp`).
`secondsUntilNextRollover(from:)` gives the countdown for screens that show
"new jobs in Xh Ym". Keeping every daily system on this one helper is what stops
the Arena budget and the quest of the day from drifting apart.

### Player-visible photos (capital / estate / location backdrops / registration / lore)

**RULE — every player-visible image goes through `sendCachedPhoto(...)`
(`Swift/Helpers/PhotoCache.swift`), no exceptions.** It captures Telegram's `file_id` on
first send and reuses it forever, so newly-added art is cached the first time it is shown —
there is nothing extra to register. Never call `bot.sendPhoto` directly for player art, and
note `TGBot.sendMessage(session:text:…)` has **no `photo:` parameter** on purpose. (After
swapping an asset file on disk, restart the bot so the stale in-memory file_id is dropped.)

**RULE — every in-place screen redraw goes through `editScreen(...)`
(`Swift/Helpers/ScreenEdit.swift`).** Telegram edits a message's TEXT or its CAPTION, never
either, and which one a screen has depends on whether it was sent with artwork — so
`editMessageText` against a photo fails. `editScreen` takes `isPhoto` as the caller's
expectation and the fast path, falls back to the other field when that is wrong, and logs
the recovery with the call site (`#function`). Never call `editMessageText` /
`editMessageCaption` directly. Its `TelegramAPIError` also lets `HummingbirdTGClient` pick a
log level by refusal, so the benign refusals stop burying the ones that matter.

**A message whose buttons you will one day need to take away must have its id kept.**
`sendMessage` returns the message; `_ = try? await bot.sendMessage(...)` throws away the only
handle on it, and an invite answered, declined or expired then keeps live buttons forever —
the arena's duel invite did exactly that until 2026-09-16, and every tap on it answered
«недійсний». Store the id beside the state the buttons act on (`PendingChallenge.inviteMessageId`)
and close the bubble on EVERY path that ends that state, not just the happy one. Closing means
`editScreen(..., replyMarkup: nil)` with the outcome in place of the question — the buttons go,
the record stays. `CapitalController.pushTradeInvite` still has the original defect.

Photos are **kept in chat history** — nothing is deleted. Players asked for a scrollable
record of where they have been, and because every bubble references the same server-side
file_id, a long history of repeated backdrops costs no extra storage.
```swift
_ = try await sendCachedPhoto(
    assetPath: "\(projectPath)/Assets/capital/<id>.jpg",
    caption: text,
    replyMarkup: .inlineKeyboardMarkup(keyboard),
    toUser: context.session,
    bot: context.bot
)
```
**Exception — tavern gambling rolls (24 h sweep).** Telegram forbids bots from deleting a
**dice** message in a private chat until it is 24 h old, so those rounds stay as game
history; `TavernCleanupService.record(...)` logs every message id into
`tavern_game_messages` and a background sweeper deletes each once it ages past 24 h. This is
the only message flow that gets cleaned up. Auto-memory `project-tavern-dice-cleanup`,
`reference-telegram-dice-24h-delete`.

## Environment Variables

Required in `.env` (see `.env.example`):
- `TELEGRAM_BOT_TOKEN` — from BotFather
- `DB_HOST`, `DB_PORT`, `DB_USER`, `DB_PASSWORD`, `DB_NAME` — PostgreSQL

## Current State

For the up-to-date implemented-vs-planned tracker, see `.memory/status.md` — kept in sync per session, covers all phases (registration, equipment, exploration, combat techniques, estate plots, workshop/kitchen, weapon upgrade, training mode, capital travel + trader + tavern + fortune teller) plus what's planned next. `TODO.md` has the phased roadmap with progress markers.

## Instructions for AI Assistant

### Memory Management
- Read `.memory/INDEX.md` at session start for orientation
- After completing significant work, update `.memory/sessions.md` with what was done
- Update `.memory/status.md` when features are implemented or plans change
- Update `.memory/file-map.md` when new files are added
- Keep `.memory/` files concise — facts and references, not prose

### Documentation Updates
- Update `TODO.md` progress markers when tasks complete
- Add new localization keys to both `en.json` and `uk.json` simultaneously
- Write new uk player-facing copy in «ви» (see Localization above); add `.m`/`.f` + the `gender:` overload only when the string names the player with a gendered noun
- Keep `uk.json` free of English game-stat tokens / loot slang — use the UA glossary (`ОЗ`, `Досвід`/`досвіду`, `Снага`, `АТК`, `ЗАХ`, `здобич`); English tokens (HP/XP/ATK/DEF/Vigor) stay only in `en.json`. Full table in `.memory/localization.md`.
- If adding new controllers/models, update the file map in README.md's Project Structure section

### Git Workflow
- When a task is finished, ask user explicitly: "Task done. Commit?"
- On confirmation, generate a short compact commit message (no co-author line)
- **Never push.** Push operations are manual, user-side only.
- Stage only relevant files, never `git add -A`

### Running the bot — ASK FIRST

- **Never start, restart or stop the bot without explicit permission.** This covers
  `pm2 start / restart / stop / delete` on the Pi and killing a local run. The user
  steps away while changes are being made and cannot always test straight away; a
  restart chosen by the assistant lands unseen changes in a game other people may be
  playing, with nobody watching.
- **Do the work up to the last step, then hand over the command.** Edit, build,
  `roi-content validate --strict`, `swift test`, `simulate`, the digest, copy files
  where that was asked for — then stop and say plainly that the change is **not live**
  until the user runs it:
  - `pm2 restart ROI` (on the Pi), or
  - `/reload` in Telegram when only `content/data` changed — tuning tables included,
    since the catalogs are computed `var`s over the snapshot.
- **Builds are exempt** — they disturb nobody. But a build is only ever half the job,
  and saying so is part of the handover.
- **The Mac instance is the one exception: stop it, don't ask.** Both `.env` files
  carry the same bot token, so a Mac run left polling means a Telegram 409 for the Pi.
  Stopping it is part of deploying, not a separate decision. Kill `debugserver` first —
  a crashed Xcode run sits as `STAT SX` and survives `kill -9` while the debugger
  traces it.

### Code Conventions
- All controllers subclass `TGControllerBase`, mark `@unchecked Sendable`
- Handler return type: `async throws -> Bool`
- Callback handlers: `static` methods
- Register button text for ALL locales in `attachHandlers`
- Use `context.bot.sendMessage(session:text:...)` over `context.respond()` in controllers
- Follow existing file header format (Created by / Maintained by)
- New models need corresponding migrations
- Keep Telegram callback_data under 64 bytes
- Hand-edit `content/data/*.json` in the Swift `JSONEncoder` style already there
  (`"key" : value`, keys sorted, 2-space indent) — a python-style re-emit reformats
  every line and buries the real change. The one exception is a re-emit that has proven
  itself byte-for-byte: `json.dumps(obj, indent=2, sort_keys=True, ensure_ascii=False,
  separators=(',', ' : ')) + "\n"` reproduces all 28 files (2026-10-02). Swift's own
  `JSONEncoder` on the Mac does NOT (`10` for `10.0`, `[\n\n]` for `[]`), and neither
  does a DTO round-trip, because `EnemyStatsDTO` drops the zero stats most rows keep.
  Auto-memory `reference-house-json-style`.
- Never interpolate an Optional directly into a player-facing string (`"\(item.icon)"` prints `Optional("🪖")`) — unwrap it (`item.icon.map { "\($0) " } ?? ""`). A clean build won't catch this; verify new strings actually render. (Same vigilance as the Lingo emoji-before-`%{}` rule in `.memory/localization.md`.)
