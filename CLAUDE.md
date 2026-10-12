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
| `content/spec/*.md` | The five approved content specifications (Phase 9) plus `king.md` (the decree chain) — the rules are below, under "Content and tuning are data" |
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
stands — never earlier: the SDK runs every update in its own `Task.detached`, so two quick
taps are both read before either has transitioned (`TGDispatcher`'s key is only a fallback;
`[ROUTE]` in the log measures the race).

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
└── Helpers/             # TGControllerBase, SessionCache, ScreenEdit, PhotoCache, PollWatchdog, Countdown, Lingo ext, env, EphemeralChatState
```

Per-file annotations: `.memory/file-map.md` (canonical, updated per session).

`Localizations/` — `en.json`, `uk.json`. `Assets/` — the artwork (registration, estate, capital, travel).
`content/data/` — the game itself as JSON. `content/lore.md` — the world (families, zones, visual reference); `content/bestiary.md` and `recipes.md` are pre-rebalance reference docs, the bestiary one marked SUPERSEDED.

## Game and Content Rules

Each rule below states the imperative and the trap, then names the record that holds the
measurement behind it. **Never delete a "never do X" guard from this file** — auto-memory
files are not loaded each session, so a rule moved out of here goes invisible
(`feedback-docs-keep-the-rule`).

### Content and tuning are data

**Game content AND balance numbers are data, not code.** ALL of it — every roster, ladder, shop,
deck and quest pool, the King's decrees, the Training Ground, the rarities, the sets and the
foraging zones (the file list: `.memory/content-pipeline.md`) — lives in `content/data/*.json`;
the `*Catalog` types are façades over a validated snapshot loaded at boot. Adding content is a
JSON edit plus locale keys in both `en.json` and `uk.json` — never a Swift array edit.

The **tuning constants** live beside them in `content/data/tuning/` — seven tables
(`combat` · `vigor` · `exploration` · `progression` · `economy` · `time` · `budget`).
`CombatService.baseHitChance` and friends are computed `var`s over the snapshot, so **never
add a `static let` that reads a catalog or a tuning value** — it runs at type-init and traps
before `ContentBootstrap.load`.

`tuning/time.json` splits `gameTime` from `realTime`. A `gameTime` value is authored at scale 1
and **DIVIDED by `scale`** at the point of use, so a bigger scale means a faster game.
**`scale` is 1.0 since 2026-09-09** — game time is real time. **`realTime` never scales**:
Telegram's 24 h dice-delete window, the trade TTLs and the 12:00 rollover are protocol
constants, not balance knobs.

**Every equippable item is bounded by a stat budget.** `budget(itemLevel, slot, rarity)
= slotWeight · (6.0 + 1.5·itemLevel) · rarityBudget` in `tuning/budget.json`; an item's stats
ARE that budget spent at fixed exchange rates, and the validator refuses an overspend. The
combat curves were derived from the same budget, so an item that respects it cannot move any
stat's percentage — which is what makes adding items safe. Three consequences:
- `itemLevel` is NOT `tier`. Tier is a ladder rung (1–9 on the weapon ladder); item level is
  the budget input (1–40).
- **Never give anything a flat bonus — items OR techniques.** An enchant level budgets the
  armour piece at an ITEM LEVEL (below, under Gear), set bonuses are capped against their
  members' combined budget, and every Super stance lifts by a multiplier of the character's
  own stat. No flat number works at both ends, and `roi-content simulate` audits every lift.
- **A fixed percentage of a small thing fails the other way** — 4% of an item-level-1 piece is
  under one point of any stat. **Size a lift in item levels — the unit the rest of the game is
  measured in — never as a share of the piece alone.** Auto-memory
  `project-armour-enchant-ladder`.

**`/reload` hot-swaps content without a restart** (dev-only, `developerUsers`; `/content`
shows what is loaded). The order is the safety: **parse → validate → live-check → build
→ install**, with `install` the only infallible step and last, so a refused reload leaves
the running game untouched. `LiveReferenceCheck` refuses a bundle that would drop an id
live rows still point at — if you add a column that stores a content id, add it to
`LiveReferenceQuery.collect` or the hot swap will happily break it. **Lingo is NOT
reloaded**: new locale strings still need a restart.

**A key the validator REQUIRES is not a key anything renders.** `ContentValidator`'s
`requireKey` proves a string exists in both locales, never that a player can reach it.
**When you add a `requireKey`, name the screen that renders it**, and when a screen describes
a thing it must describe ALL of it: both lines are built from the data (`bonusOutput`,
`descriptionKey`), so a future two-stream plot gets them free. Auto-memory
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
decide every fight, and the report is the only thing that shows what moved; `--strict`
exits 1 on a broken band. **Every band measures the AUTHORED contract** (level invariance: a
level-1 and a level-40 fight must play the same); the estate's strength (under Combat) is
printed and priced into the pace, never banded.

### Access

**Access is invite-only and lives in the database.** The `allowed_users` table
(`AllowedUser` / `AccessControl`) replaced the hardcoded `allowedUsers` array; `foundingUsers`
in `configure.swift` is now only the migration's seed list. **To let a new tester in use
`/link`** (developer-only), never a code edit. The gate lives in `TGDispatcher` **ahead of
routing**, so a refused stranger never gets a `User` row. `allowed_users` is in
`WipeForRebalance.preserved` — a wipe resets the game, not the guest list — and
`developerUsers` stays hardcoded and allowed before the table is read: the brake against
locking yourself out of your own bot. **The door can be opened** (2026-10-07, the public
test): `ROI_OPEN_ACCESS=1` in the Pi's `.env` and a restart, and the gate ADDS every unlisted
account to `allowed_users` (source `open`) instead of refusing it. Open or shut is a `.env`
line, never a code edit, and closing it again takes nobody out — the row is what keeps a
player in. Auto-memory `invite-only-access`.

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
the BOARD's only, and an untaken offer carries neither line nor bar. Досвід is 📖 on every screen,
Снага 🍖, and whatever the player GETS — a job's or a decree's reward, the claim button, a tarot
card's loot — 💰. Auto-memory `project-quest-board-scroll`.

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
and turning it in opens the next. The validator enforces six rules, each first broken by a
draft or a live change: **no decree pays more Vigor than the pool at its level** (`100 + 5·L`;
the grant clamps to it), **every decree pays something**, **food is a named item and a count**,
never "portions", **a `player_level` decree's target must equal its own `level`**, **a Training
Ground or technique decree may not sit below its first technique's floor**
(`king.technique_before_its_floor`), and **a weapon decree may not sit below its rung's gate**
(`king.weapon_tier_before_its_gate`). A decree's kind is DERIVED — it is a level decree when one
of its conditions is `player_level` — because a second discriminator beside the conditions is a
field that can disagree with them. No screen shows "decree N of 39". The chain is printed by
`roi-content spec king` and hashed by the fifth digest line, `king`. Auto-memory
`project-king-decree-chain`.

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

**Vigor does not regenerate** (Phase 8E). Food, quests and the level-up grant are the only
sources and the estate's plots the intended income, so the pool plus the food in the bag is
what limits how deep the wilderness can be walked and still walked out of. **Never reintroduce
a trickle**: one that runs during an expedition lets a player wait out a full pool at km 25.
Auto-memory `project-vigor-no-passive-regen`.

**0 Vigor must never lock a door that costs no Vigor.** `TravelService.start` refuses 0 HP,
never 0 Vigor: a starving player needs the capital's food, jobs and decrees, and the road
home. Hunger costs what `tuning/vigor.json` → `starvation` says, charged on every step that
BEGINS at 0 Vigor (`ExplorationService.rollStep` reads `isStarving` before the step pays). The
forest edge (`ExplorationController.modePrompt`) is the one place hunger is explained, and it
names no food — both on the owner's word. Why: `.memory/game-core.md` §Vigor and §Rest and the
road; auto-memory `project-starvation-tick-on-the-paying-step`.

**Every Vigor spend goes through `VigorService.drain(_:base:multiplier:)` or its `action:`
form**, which applies the active tarot card's `vigorDrainMultiplier` on top of the stance's and
rounds half up. `drain(_:amount:)` is only for a number already final (the dev `/drain`) — a
spend routed there escapes the card. Base costs are 1–5, so a card multiplier must move a 2 by
a whole point after rounding. Auto-memory `project-tarot-phrased-once`.

**A Vigor reward that will not fit is asked about, never silently clamped.**
`VigorRewardNotice` is the one phrasing of that loss:
- a warning on the card once the decree is done or the job is ready;
- a question on the turn-in tap (`king:report` → `king:report_ok:<decree>`, `quest:do:` →
  `quest:do_ok:<npc>:<job row>`);
- a banner line naming what was lost.

The arithmetic is `VigorService.overflow`, the payouts' own clamp asked beforehand. A new Vigor
reward goes through the same three.

**An answer names what it was asked about.** A turn-in answer carries its decree, or its job's
ROW (`QuestService.Status.rowId`: a quest id recurs on later days); a mismatch — and the bare
form older questions carry — redraws the screen and pays nothing (`handleKingReportAnyway`,
`handleQuestFinishAnyway`). **Both banners print the receipt**: the XP `grantXP` landed (card
multiplier included), and the level a decree crosses gets the same `LevelUpBanner` a job's
does. Auto-memory `project-vigor-reward-overflow`.

**HP regenerates at the estate and nowhere else** — a PLACE, not a pause between fights.
`HealingService.canRest` names the three states that suspend it: an `ExplorationState` row, a
`TravelState` row (the road needs its own check, because `location` is not flipped until
arrival) and `location == capital`. Callers query the rows and pass the answer; `tick` does no
lookups of its own, and away from the estate the clock is CLEARED, not merely skipped. Regen is
**computed lazily on interaction**, so both ends of an absence are stamped explicitly:
`suspendResting` when an expedition or trip begins, `beginResting` when the player lands home.
The away-from-home heal is a **cooked dish**; `potion.heal_small` and `potion.heal_medium` are
obtainable nowhere (auto-memory `feedback-a-checker-that-cannot-fail`).

**What finishes while nobody is looking needs a watchman.** `RestNotificationService` (one
`Task.detached` on `realTime.restSweepInterval`) answers four questions per player, and a fifth
of the whole roster:
- HP topped out at the estate — `HealingService.tick` notes every fill in `RestedToFull`,
  whichever call made it, and the sweep announces it;
- the fortune teller's next card ready (`User.fortuneAvailableAt`, below) — on the 12:00
  rollover's minute the cards and the new day go as ONE message, cards first;
- the 12:00 job rollover;
- a task turned ready: the open decree complete, or a taken job ready to hand in;
- zlatnyks credited by hand (`ZlatnykService.unannounced`) — once per change; a cut is recorded,
  never announced.

It runs the regen through `HealingService.tick` — never a second copy of the arithmetic. **A
task's readiness is its board's own test** (`KingService.standing`, `QuestService.liveDone`,
asked through `readyUnannounced`), so the notice cannot announce what the palace or the NPC
would refuse. It fires once per task, on markers in the progress rows written by a one-column
query, never a row save — the player may be ticking the same row.

**A background writer MUST take the session-cached `User` when one exists**
(`SessionCache.peek`): its own copy writes the fields it touches from values read before the
player's last tap, and `saveAndCache` installs that copy as the session — silently undoing the tap.
(Fluent writes only changed fields, verified 2026-10-11: the danger is the stale VALUES.)

**The zlatnyk balance is deliberately NOT a field of `User`.** The owner credits
`users.zlatnyks` by hand in DBeaver, and a cached copy would show a stale number and let a spend
write it back. Read it through `ZlatnykService`; spend it in ONE statement that takes from
`zlatnyks` and `zlatnyks_announced` alike. Auto-memory `project-premium-currency-zlatnyk`.

**The Chancellery sells for zlatnyks** (the palace, «🟡 Канцелярія»; the code says `treasury` — not the guild's
«🪙 Скарбниця», `guild.treasury.*`; `treasury.json`, where the entries and prices are data and a
`TreasuryKind` is code). Its first entry is the class change, ONE transaction
in `ClassChangeService.perform`: the class asked first, then the spend, the weapon reforged at its
tier and wear, the pinned notes, the row and the purchase log. The confirm screen runs the same
`apply` on a stand-in. **Never preview by mutating the session's `User`** — the watchman may save it
mid-preview.

Full reasoning: `.memory/game-core.md` §Rest and the road, `.memory/session-auth.md`;
auto-memory `project-rest-notification-watchman`, `project-full-hp-notice-gap`,
`project-task-ready-notice`, `project-fortune-once-per-game-day`,
`feedback-background-writers-session-cache`.

### Exploration and the forest

**Passive expeditions are capped at `passive.dailyBudgetMinutes` per game day**, counted in
the AUTHORED minutes the three choices are written in — never wall-clock seconds, which would
change with `time.scale` — on a counter plus day stamp rolling at 12:00. The picker offers only
what the day can still pay for AND the handler re-checks; the charge lands after
`beginPassive` succeeds. Auto-memory `project-daily-and-storage-ceilings`.

**A leaderboard is a `Leaderboard`, never a `Rating`** — `rating` already means crit / dodge /
accuracy; the player reads «Рейтинги». The boards are ALL-TIME, the first period and not the
only one: a seasonal board is a second READING with its own storage — **never a reset of
`deepestKm` / `totalKmWalked`** (`ResetDeepestKm` was the one exception, because that column's
MEANING changed). **One ladder, one implementation:** the Arena's «Найкращі бійці» renders the
same `LeaderboardService.view(.honor,…)` as the journal's board. Auto-memory
`project-leaderboards-will-go-seasonal`.

**A lifetime counter has exactly one writer — and WHEN it writes is half the rule.**
`totalKmWalked` is a tally: `User.recordStep()` from `ExplorationService.rollStep` (all three
kinds of step), plus `handleHomeReached` for the last stride. `deepestKm` is a RETURN:
`User.bankDepth(_:)`, only where the player stands at the manor again, from
`ExplorationState.maxDepthKm` — `stepsDeep` counts back down on the way home. **Every change of
depth goes through `ExplorationState.moveTo(km:)`**: put a new counter where the thing it
counts already funnels. Auto-memory `project-depth-is-banked-on-arrival`.

**The forest is left on foot, or not at all.** `/start` and a stray Cancel re-render the walk
screen or the fight instead of ending the expedition, on BOTH screens: banking depth at the
door makes any free exit the cheapest way to bank a record. The one real escape is a fight
whose enemy id no longer resolves, which ends the expedition rather than trapping the player.

**A creature's number is its rung, and a kill pays its full XP at any player level.** Bands run
km 3N−3…3N+1, the last creature stretched to the horizon at km 49. `xpLevelDiff.perLevel` is 0;
the knob stays, so the penalty can come back by `/reload`, and so does the damage shift
(`levelDiff`). The validator guards the ladder: **a creature whose band starts deeper may never
pay less XP than one whose band starts shallower** (`enemy.xp_falls_with_depth`). `simulate`'s
pace table cannot see any of this — it assumes on-level fights and never walks from the manor;
`content/spec/spec-bestiary.md` §10.5 describes the expedition model that can. Auto-memory
`project-new-beasts-draft`.

### Combat

**One number, one source. A screen never sums two losses under one label.** A step can cost HP
twice — the event it rolled and the hunger tick — so `ExplorationService.rollStep` returns a
`StepResult` pairing the event with `starvationHpLost`, each printed on its own line. It rides
on the RESULT, never inside an enum case where each branch must remember it. **Add a new
source of damage to `StepResult`**, never to another source's number. Auto-memory
`project-damage-sources-named-separately`.

**An escape is `CombatService.fleeSucceeds`, never a roll against `fleeChance`.** The per-class
chance and `combat.json` → `flee.maxFailures` — the per-fight ceiling that grants the attempt
after that many failures — are one rule behind one function, because a failed escape is an
unmissable hit at half armour with nothing dealt back. The count is per FIGHT
(`ExplorationState.combatFleeFails`, 0 on `beginCombat`, cleared on `endCombat`), never per
expedition. Auto-memory `project-flee-has-a-ceiling`.

**A rating is a rating on every screen, and is never labelled `%`.** `crit` · `dodge` ·
`accuracy` are RATINGS converted through a level-linear curve (`CombatMath.percent`); every
screen prints the bare rating, so the item, the level-up banner and the sheet add up.
`CombatService.critPercent` / `dodgePercent` / `accuracyPercent` say what a rating is WORTH —
BESIDE the rating, never instead of it — and **the level-up banner can never follow**: a
quarter of level-ups would announce a drop. Auto-memory `project-rating-vs-percent-display`.

**Every HP on a fight screen carries a name**: the creature's line is its icon and name, the
player's the class icon and «Ви» (`combat.you`) — «⚔️ Ви — ❤️ 8/95  🍖 25/110».

**A death screen carries the round that caused it.** `finishRound` hands its own lines — the
player's action, the killing blow, a failed flee, a burn tick — and the enemy's HP left to
`handleCombatDeath`, and the shared `ExplorationController.handleDeath` names what the wipe
took (`InventoryEntry.wipeOnDeath` returns `[DeathLoss]`, not a count). Auto-memory
`project-combat-lines-and-death-screen`.

**Techniques are bought with the Training Ground**, a room of the house
(`EstateTierGates.trainingGround`, T4), not a plot: `training_ground.json` sells one technique
per level, and each level's player-level floor is the technique's own `requiredLevel` in
`combat.json` — read, never restated. **Paying never charges for a technique the player already
knows** (`TrainingGroundLevelDTO.levelAfterCatchUp`, the one implementation the card and
`TrainingGroundService` both ask). The `training_ground` plot type is gone
(`MoveTrainingGroundOffPlots`) — do not bring back a plot that produces nothing. Auto-memory
`project-training-ground-building`.

**No technique blow hits harder than an ordinary crit, and every technique tap strikes.** Vital
Shot is a guaranteed crit AT the standard ×1.5, and `tuning.combat.effect_crit_above_standard`
refuses more. The kit is tuned to shorten an elite fight by ~20% for EVERY class; measure with
`simulate --levels 21` and `--levels 40`, never the default sweep. Raising a stance swings
through `strikeRound` and all three special defences deal damage back — do not add a tap that
takes Vigor and strikes nothing. The stance lines carry no stat breakdown, on the owner's word.
Auto-memory `project-technique-rework`.

**A finished forest fight writes one `fight_log` row** (win / death / flee — not training, the
registration dog or the passive autobattle). Its numbers gather between taps in
`exploration_state.combat_tally`, so **a new source of player damage must feed `state.tally`** —
the blow it rolled (for `max_blow`) and the HP it actually removed (for every sum, so overkill
inflates nothing) — or the log quietly undercounts it, and `FightLog.record` runs with `try?`
BEFORE `endCombat`, which clears the tally. `fight_log.enemy_id` is history and deliberately NOT
in `LiveReferenceQuery`: a retired beast's old fights must never block a reload.

**Creature strength follows the ESTATE tier, never the player** (`spec-bestiary.md` §11). A
spawnable creature fights with HP and ATK × `1 + perTier·(tier − 1)` (`tuning/combat.json` →
`estateScaling`); XP, loot, DEF, the ratings and its level stay as authored. **Never key it, or
anything like it, to the player's level or gear.** The formula and its rounding live in
`CombatMath.scaled(_:forEstateTier:spec:)`; the game reaches them only through
`Enemy.scaled(forEstateTier:)`, and **exactly two funnels call that**:
`ExplorationService.rollEncounter`, where an encounter is born, and
`ExplorationState.combatEnemy(for:)`, where a fight in progress is read back. **A new reader of
a fight goes through the second, never through a bare `EnemyCatalog.find`**, or its screen draws
HP over a maximum the creature never had. The dummy and the dog (`0...0`) never scale. The tier
is read live, which is safe only because nothing can raise the estate while an expedition row
stands — keep it that way. No screen announces the strength, on the owner's word;
`fight_log.estate_level` records it. Auto-memory `project-estate-scaling`.

**The arena duel is played in simultaneous rounds.** Both fighters choose blind; the round is
played on the second choice, or when the clock (`arena.json` → `turnSeconds`) runs out with a
missing choice played as a forced Defend, and both blows are rolled against the state the round
STARTED with — **never resolve one side's blow before the other's**. The round is
`DuelMath.resolveRound` in `ROISim`, reached only through `CombatService.resolveDuelRound`: a
Defend braces against the same round's attack, and when both fall the heavier blow wins (equal
blows draw). `sweepInterval` is the clock's precision and must stay far below the round. Every
ending goes through `ArenaController.finish`, and settlement takes the session-cached `User`
(`ArenaService.liveUser`). Auto-memory `project-arena-simultaneous-rounds`.

**The duel's choices are a cycle of three, and must stay one**: Attack beats the class special
attack, the technique breaks a Defend (it cannot miss a defender), a Defend turns an Attack.
With two blind choices one always dominates whatever the numbers, so **never fix Defend by
tuning a two-choice duel**. The technique is free and unlimited in the arena (a use limit
breaks the cycle once spent); a clock-forced Defend blocks and answers nothing; two techniques
both fizzle. The numbers are the arena's own (`arena.json` → `duel`) — **never move
`combat.json` → `defendChipFraction` for the arena**: the forest's Defend, Iron Bulwark and
Shadow Veil share it. `arena.duel_defend_loses` warns when a riposte no longer outweighs what
gets through the block. The arena admits only those who have LEARNED the special attack
(`ArenaService.isAdmitted`, at the capital's door and again at the arena's home), and **the
stake picker and the challenge refuse a player off the arena's router**
(`challengeAllowedHere`): a picker stays in the chat and `acceptChallenge` moves only the side
that answers. «Скасувати» strips the picker. Auto-memory `project-arena-technique-cycle`.

### Gear, inventory and storage

**A death takes the bag, never the class weapon.** `InventoryEntry.wipeOnDeath` is the ONE
implementation both death paths call — `ExplorationController.handleDeath` and
`PassiveExpeditionService.applyDeath`; worn gear and a bound starter weapon carried in the bag
survive. **Put the next wipe in that function too**: a rule each caller filters for itself is a
rule one caller forgets. Auto-memory `project-death-spares-the-class-weapon`.

**Every gear screen renders all six `GearStats` fields, HP included.** HP reuses
`profile.health` rather than adding a `workshop.stats.hp`: `profile.*` and `workshop.stats.*`
are already two families for one set of names kept in step by hand, and that duplication is
exactly how `accuracy` shipped under two different Ukrainian words.

**A weapon is shown by its OWN icon, never a slot glyph**: the profile's «Основна рука», the
gear sheet's main hand and the weapon decree print `items.json`'s icon — 🗡 sword, 🏹 bow, 🪄
staff (the decree: the class weapon's, through `ConditionView.icon`). 🗡 stays only for an empty
hand; the CLASS icons are a different thing and stay ⚔️ / 🏹 / 🔮. Auto-memory
`project-weapon-own-icon`.

**The warehouse cap is enforced on every path in, including
`PlotService.harvest(to: .warehouse)`.** Harvest is all-or-nothing like the bag, with the yield
left standing on the plot: partial cannot be expressed, because the Mine's two output streams
share one `lastHarvestedAt`. **No account is exempt** — no `isDeveloper` bypass on any of the
four warehouse checks (it remains on the BAG, a different ceiling). Auto-memory
`project-daily-and-storage-ceilings`.

**A fit check must be the SAME arithmetic as the writer it is predicting, in the same
units, for EVERY store the write could land in.** `InventoryEntry.add` counts UNITS and throws
when it will not fit, and a craft drains before it adds, with no transaction — so a wrong
prediction eats the ingredients. Copy `TradeService`: `used − outgoing + incoming ≤ cap`, in
units, with the dev bypass matching the writer's. A full bag is not a refusal to craft — the
output goes to the warehouse and the banner names where it landed. Auto-memory
`project-fit-check-matches-the-writer`.

**What a place can draw on is where it stands.** The Master is in the capital, which has no
warehouse, so his lesson and his enchant count and take materials from the BAG alone; the
workshop, the kitchen, the Training Ground and the estate and bag upgrades stand at the estate
and draw bag + warehouse. **A card counts in the same place its service draws from.**
Auto-memory `project-master-draws-from-bag`.

**A transfer that RE-CREATES a row resets everything the row knew.** Tier, wear and enchant
are per-instance (`GearState`), carried by both `InventoryEntry` and `WarehouseEntry`; every
create-path takes it as `carrying:`, or reassigns the owner as `TradeService` does. **A new
per-instance column belongs IN `GearState`, not beside it.** The screen half: **the Master
repairs a ROW, not a loadout** — a list must ask the same question of every kind it lists.
Auto-memory `project-gear-state-travels-with-the-unit`.

**A gear list names ROWS, and the workshop is the one place a piece is destroyed.** Copies
differ by wear, so the bag's gear list and the warehouse's gear rows print each copy's wear and
every button carries the ROW's id (`inv:info|equip|unequip:<uuid>`,
`estate:wh:deposit|withdraw:<uuid>`); an item-id [Одягнути] left in chat acts only when one copy
qualifies and otherwise redraws the list (the warehouse's old item-id buttons move the OLDEST
copy, on purpose). **«Розібрати»** (`CraftingService.salvage`, workshop → 🔨) returns the piece's
recipe × `gear.salvageFraction` × max / the item's own starting durability, floored per line by
`SalvageMath` — derived, never a picked number — so armour repaired down to 1/1 gives nothing
back but still leaves the bag. It predicts the fit in units for both stores, like `craft`, and
names the row it destroys. Auto-memory `project-salvage-and-gear-rows`.

**Armour is not crafted** — the Master is the only source. The four Forester recipes stay in
`recipes.json` as PATTERNS (`RecipeCategory.isCraftable` is false for the tannery, so no list
shows them and `CraftingService.craft` refuses them) because salvage reads them to know what a
piece gives back. **Deleting them as unused breaks «Розібрати» for every armour piece**, and with
it the only way to be rid of armour worn to 1/1. Auto-memory `project-salvage-and-gear-rows`.

**Durability is the item's own** (`spec-items.md` §10). Every piece a fight wears declares
`maxDurability` in `items.json`, except a laddered weapon, whose `durabilityByTier` owns it.
The validator's `durability.*` rules refuse a missing number and warn on a second source or a
number nothing reads.
- **One reader.** A fresh row is stamped by `GearState.fresh(for:)` through
  `GearConditionService.startingDurability(for:)`; the Master's repair price and the salvage
  share ask the same function.
- **Never bring back one durability for all armour** — the global
  `economy.gear.maxDurabilityStart` stamped the class weapon as well.
- **A set's durability and its price are one decision**: a repaired point costs
  price × `repairCostFraction` ÷ durability.
- **The repair was halved on 2026-10-10** (`repairCostFraction` 0.25) on live-play data, and the
  rest was kept on the owner's word: the max shave per repair, the already-cut maxima and the
  Master's one-piece screens were each shown and declined — do not soften the shave, restore maxima
  or add a «Полагодити все» without asking. Auto-memory `project-repair-cost-complaint`.
- **Changing a shipped piece's durability is a migration, never a content edit alone.** Rows
  keep the maximum they were minted at, while the repair price and the salvage share read the
  item's new number. `RaiseArmorDurability` is the shape — both numbers shift by the
  difference; its `previousStart` (30) belongs to that one change, the next writes its own.
- **A broken piece counts for nothing, its set included** (2026-10-11): armour at 0 grants no stat
  and no set progress; a weapon at 0 is only dulled (half, rounded half up).
  `EquipmentService.isBroken` is the one test, asked by `contributedStats` and by the set pass.

**The cached gear bonuses are re-derived at every boot** (`EquipmentService.backfillGearBonuses`,
after the migrations). `User.gear*Bonus` is written only by `recomputeBonuses`: on an equip, a
fight's wear, a repair, an enchant and a reforge. **A migration or a content edit that changes
what a worn row grants leaves the cache stale** until that player's next fight: a restart is the
consistency point; a `/reload` is not. Auto-memory `project-durability-per-item`.

**Clamp HP to `effectiveMaxHp`, never to `maxHp`.** `maxHp` is the class line alone, and the armour's
HP sits on top of it. Until 2026-10-11 `applyLevelDerivedStats` clamped to the base, so every
level-up took the whole gear share (209/209 at L17 came out 176/214).

**A weapon ladder is ONE object.** The three upgradable weapons render through
`ItemDisplay.nameKey(for:tier:)` → `item.<id>.t<tier>`, and the rungs must keep a word in
common — the player is upgrading a thing, not swapping it — which `locale.ladder_name_drift`
warns about. Wherever a label describes an inventory ROW rather than a shop listing, pass the
row's tier (`CapitalController.itemLabel(_:tier:lingo:locale:)`). **An item id alone cannot
name a row**, so a service that reports rows hands back the tier with them:
`GearConditionService` returns `BrokenPiece(itemId:tier:)`, not `[String]`. Auto-memory
`feedback-ladder-names-one-noun`.

**The weapon follows the PLAYER level, and its first rung is the Master's lesson**
(`spec-items.md` §9).
- **The ladder.** Nine rungs, one every five levels (1 … 40). Each carries its own
  `requiredPlayerLevel` and is budgeted at that level, at 75% of the shipped growth — the
  bestiary model assumes `itemLevel <= level`, which an estate-opened ladder broke.
- **Who sells what.** Tier 1 → 2 is sold only by the Master (`WeaponUpgradeService.lesson`):
  the rung's materials from the bag plus `master.json` → `weaponLessonSilver`. The workshop
  refuses a tier-1 weapon as `.notLearned`. **"Has learned" is derived** (tier ≥ 2), so never
  add a column for it.
- **The gate is one rule**, `WeaponLadderRules.highestTier`, shared by the catalog, the clamp
  migration and the tests.
- **The upgrade button lives only in the workshop, which opens at T3**, so
  `king.weapon_tier_before_its_gate` refuses a weapon decree filed below its rung's gate.
- Auto-memory `project-weapon-ladder-rework`.

**The armour climbs by the Master's enchant, and only its PRICE gates it** (`spec-items.md` §11).
- **The ladder.** Five levels. Level N budgets the piece at `enchantSteps[N].itemLevel` — 5 /
  10 / 15 / 20 / 25, where the weapon's rungs t2–t6 sit — with `master.json` →
  `enchantGrowthShare` (0.75) of the curve's growth: the weapon ladder's law.
- **One implementation.** `EnchantLadderRules.scale` is the lift, for the game, the validator
  and `spec gates`, derived from `tuning/budget.json`, never typed, and applied multiply first,
  divide last (`LadderScale`) — level 3 puts a stat exactly on a half. `EquipmentService.
  stats(ofItem:tier:enchantLevel:)` is the one reader, for the bonuses and the Master's card.
- **No player level gates it, on the owner's word. Do not bring a level gate back**, on the
  purchase or on what a worn piece grants. An enchant never fails, and no roll is to be added.
- **The price is a balance number, not a fee** — 50 × level² silver a piece, pinned by
  `EnchantLadderTests`. **Re-measure before lowering it**: it is the only thing between a
  low-level player and item-level-25 armour (§11.6).
- **To the player it is «покращення», never «заточка»** — «✨ Покращити», «✨ Покращення броні»,
  «покращено до +N», «✨ Покращення: +N»; the code says `enchant`. **A word from the chat is not
  copy** (auto-memory `feedback-chat-words-are-not-copy`).
- **Every level changes a number on every armour piece**, or the validator refuses it
  (`master.enchant_level_changes_nothing`); it also refuses armour authored at or above a
  level's item level, so **a new armour piece above item level 1 is a ladder decision first**
  (`spec-items.md` §11.8).
- Auto-memory `project-armour-enchant-ladder`.

### Screens, buttons and refusals

**Every "time left" the player sees goes through `Countdown.format`** — `2год 5хв` ·
`1хв 22сек` · `5хв` · `42сек`: the two most significant units that carry a value, with an
exact one dropping its tail so a whole-minute window still reads `5хв`. Durations are never
written into copy either — the expedition buttons, the tarot window on the fortune teller's
price line and the invite window are all printed from the values that own them.

**A tarot card is phrased by `FortuneDisplay` on every screen** — the reveal, the fortune
screen and the profile — from its `FortuneEffect`, so no locale key carries a card's number. A
one-shot's gift is printed from the RECEIPT (`oneShotParts`), never the card: the Wheel rolls
and every loss is clamped. Auto-memory `project-tarot-phrased-once`.

**"What it costs / what you have" is ONE sentence, and `RequirementLine` renders it.**
`✅ 1× 🪵 Соснова дошка  (12/1)` — marker, the count the recipe asks for, the label, then the
fraction in brackets. A gate line carries no count, which is why the count belongs to
`RequirementLine.item` and not to `render`. Every material list, every gate and the shortage
modal go through it, so a screen and the modal that refuses the same tap cannot phrase one
number two ways. **Every question that spends silver ends with `RequirementLine.silver`**
(2026-10-11): the question replaces the caption that held the balance. **⛔ is retired.** **Current-against-maximum is a DIFFERENT sentence** —
durability `0/100`, the bag `18/25`, a plot `40/40` — and must not grow a ✅/❌: a full bag is
not a failed requirement. Auto-memory `project-requirement-line-one-format`.

**And the shortage modal is CAPPED at 200 UTF-16 units, because Telegram refuses a longer
`answerCallbackQuery` outright and every call site swallows that with `try?`** — an overflow
is a tap with no modal at all. `RequirementLine.shortageModal` drops rows until it fits and ends
with a wordless `… +N`. **Measure an alert in UTF-16 and measure it in Ukrainian**: the five that
overflowed were all under in English. Auto-memory `project-requirement-line-one-format`.

**A choice that cannot be undone is asked, not just tapped.** Nothing a player can do deletes
a `Plot` row or changes its type (`PlotService` has `claim` and `harvest` and no third verb), so
`estate:plot:type:` draws the picked type's card and asks; only `estate:plot:build:` writes.
**Which callback keeps its old name is part of the fix**: the QUESTION inherited it, so a stale
picker message in chat history lands on the safe path. This is the shape every buildable thing
has — list → detail → act, and `ItemCard` before every purchase. Auto-memory
`project-plot-streams-and-dead-lore`.

**A dead inline button is the house symptom, and it has two causes.** A **throw** out of a
callback handler spins it forever — nothing answers `answerCallbackQuery`. A callback **no
handler claims** is just as silent: `Router.process` reaches `unmatched` only when
`update.message != nil`, which a callback query never has. So a controller that renders
another controller's screen must END by forwarding what it does not recognise —
`ExplorationController` and `CapitalController` both hand the rest to `MainController` — and
it must be **a catch-all, never a list of prefixes**. A handler that answers LATE — because a
refusal is a modal, which must be the tap's only answer (`finishMasterLesson`,
`finishMasterEnchant`, the workshop's `handleWeaponUpgradeConfirm`) — answers in a `catch` before
rethrowing, or a throw ahead of it spins the button. Auto-memory `project-dead-inline-buttons`.

**A number typed before its button gets a hint, never the root screen.** Every quantity is
asked AFTER a button, and the server never knows which inline screen is open, so it cannot
redraw that one. A controller with a numeric prompt calls `answerStrayNumber` **after** its own
pending-prompt checks and **before** its root fallback. WORDS still fall through to the
re-render, because stray text is usually a stale reply-keyboard tap and the redraw is what
repairs it; a number is never a button label. A prompt still waiting for a BUTTON (the
warehouse's «Куди?») repeats itself with a hint instead. Auto-memory `project-stray-number-hint`.

**A quantity whose only answer is 1 is not asked** (2026-10-11, the owner's variant A): when the
side the units come from holds exactly one, the tap acts on it. The exception is a taken job that
needs the item (`loneUnitWithoutJob`), which keeps the prompt and its ⚠️. Buying always asks. A new
quantity prompt follows the same rule. Auto-memory `project-lone-unit-no-prompt`.

**A screen that can answer a question should answer it before the player gets it wrong** — the
recipe screen once printed what a dish REQUIRES and never what the player HELD.
`CraftingService.stock(for:on:)` is now that number for both the screen and the craft itself
(two queries, whatever is asked about), so a screen cannot quote a total the button then
disagrees with.

**A recipe note names a THING, never a row, and "done" is read, not announced** (2026-10-10).
`RecipeNote` stores kind · ref · target (the enchant's is the piece + the level: a warehouse trip
re-creates the row), priced afresh on every draw. `RecipeNoteService.live` deletes every finished
note on each read — the journal's count, its screen and the pin's cap all go through it — so no
upgrade path remembers the journal; only a craft, an event, is cleared in the craft funnel
(`recipeMade`). `recipe_notes.ref` is deliberately NOT in `LiveReferenceQuery`: a note the
content no longer backs is dropped the same way. Auto-memory `project-recipe-notebook`.

## How to Add a New Controller

1. `Swift/Controllers/MyController.swift`: subclass `TGControllerBase`, mark `@unchecked Sendable`,
   and override `attachHandlers(to:lingo:)` (create the Router, register paths — button text for
   ALL locales via `buttonsForAllLocales`), `generateControllerKB(session:lingo:)` (the persistent
   keyboard) and `unmatched(context:)` (call `super.unmatched()` first — it skips the global
   commands). Callback handlers must be `static`.
2. Register it in `AllControllers.swift` — a `static let` built with its `routerName`, added to `all`.
3. Transition from another controller by setting `context.session.routerName` and calling
   `saveAndCache(in: context.db)`.

The full code samples: `.memory/controller-pattern.md`.

## Key Patterns

### Localization

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

**An enemy's name is nominative only, and so is a player's nick.** Content stores one form and
a free-form nick cannot be declined, so a line makes the name its SUBJECT or sets it after a
dash — «… — %{enemy} втрачає N ОЗ» — never after a preposition or as an object («по %{enemy}»,
«від %{nick}»). After any copy edit that touches `%{enemy}` or `%{nick}`, run the sweep in
`.memory/localization.md` (auto-memory `project-combat-lines-and-death-screen`).

**Gendered text (uk feminitives):** a string that names the player with a gendered noun uses
`lingo.localize("key", gender: session.gender, locale: ..., interpolations: ...)`, which
looks up `key.m`/`key.f` for `uk` and the plain `key` for English — so **never duplicate
English**, only `uk.json` gets `.m`/`.f`. Player gender is `User.gender` ("m"/"f", nil=male),
chosen at registration step 1. When new copy names the player, either add `.m`/`.f` + the
overload, or phrase around the noun.

**A string whose point is a NUMBER routes through `lingo.localize(key, count:, locale:)`.**
Ukrainian has three noun forms, so `uk.json` carries `.one`/`.few`/`.many` and English keeps
the plain key. The rule is `UkrainianPlural.form(for:)` in `ROIContent`, and its one trap is that
**11–14 take `many` despite ending in 1–4**: «21 срібник» but «11 срібників».

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

**The fortune teller is once a game day too**: the next card waits for the LATER of the drawn
card's window — the end STAMPED on the card at the draw, so a `/reload` cannot cut a running card
short — and `GameDay.nextRollover(after:)`. `User.fortuneAvailableAt` is the one place it lives:
the fortune screen, `FortuneService.draw` and the watchman all read it. Auto-memory
`project-fortune-once-per-game-day`.

**A card can be dispelled, and only a dispelled card replaced** (2026-10-10, the owner's rules).
«🕯 Відчарувати» ends the FREE card's running duration effect (`fortune.dispelPrice`); only then
is ONE «🔮 Друга карта» on sale (`secondDrawPrice`), and it is final. `FortuneStage` (free →
dispelled → second) answers both questions for the screen, its buttons and `FortuneService`. The
dispel drops the card and KEEPS the stamped window, so the free card never comes sooner. **No
dispel of a one-shot or of the second card, no second card after a card that ran out** — do not
add one without asking. Auto-memory `project-fortune-dispel-and-second-card`.

### Player-visible photos (capital / estate / location backdrops / registration / lore)

**RULE — every player-visible image goes through `sendCachedPhoto(...)`
(`Swift/Helpers/PhotoCache.swift`), no exceptions.** It captures Telegram's `file_id` on
first send and reuses it forever, so newly-added art is cached the first time it is shown —
there is nothing extra to register. Never call `bot.sendPhoto` directly for player art, and
note `TGBot.sendMessage(session:text:…)` has **no `photo:` parameter** on purpose. (After
swapping an asset file on disk, restart the bot so the stale in-memory file_id is dropped. A
NEW file needs no restart: a missing asset is never cached.)

```swift
_ = try await sendCachedPhoto(
    assetPath: "\(projectPath)/Assets/capital/<id>.jpg",
    caption: text,
    replyMarkup: .inlineKeyboardMarkup(keyboard),
    toUser: context.session,
    bot: context.bot
)
```

**A screen that gains art turns every in-place redraw into a CAPTION edit, capped at 1,024
characters against a message's 4,096** — and neither `sendCachedPhoto` nor `editScreen` trims,
so an overlong caption is a screen that never draws. Before a file goes into a slot, measure the
screen's worst case in Ukrainian (in UTF-16, like an alert), every sub-screen edited over the
same message included. Auto-memory `project-screen-art-slots`.

**RULE — every in-place screen redraw goes through `editScreen(...)`
(`Swift/Helpers/ScreenEdit.swift`).** Telegram edits a message's TEXT or its CAPTION, never
either, and which one a screen has depends on whether it was sent with artwork — so
`editMessageText` against a photo fails; `editScreen` falls back to the other field and logs the
recovery. Never call `editMessageText` / `editMessageCaption` directly.

**A message whose buttons you will one day need to take away must have its id kept.**
`_ = try? await bot.sendMessage(...)` throws away the only handle on it, and the buttons then
outlive the state they act on. Store the id beside that state (`PendingChallenge.inviteMessageId`)
and close the bubble on EVERY path that ends it, not just the happy one — `editScreen(...,
replyMarkup: nil)` with the outcome in place of the question. `CapitalController.pushTradeInvite`
still has the original defect. Auto-memory `project-close-the-bubble-you-opened`.

Photos are **kept in chat history** — nothing is deleted (auto-memory
`project-tavern-dice-cleanup`). **One exception: the road card.** A trip shows ONE card
(`Assets/travel/road.jpg`): `CapitalController.sendRoadCard` sends the new card for setting out,
a turn-back or "how long is left", then deletes the previous card of the SAME trip. Arrival
forgets the id, so a trip's last card stays in history.

**Exception — tavern dice (24 h sweep).** Telegram refuses to delete a **dice** message in a
private chat until it is 24 h old, so `TavernCleanupService.record(...)` logs every message id
into `tavern_game_messages` and a background sweeper deletes each once it ages past 24 h.
Auto-memory `project-tavern-dice-cleanup`, `reference-telegram-dice-24h-delete`.

## Environment Variables

Required in `.env` (see `.env.example`):
- `TELEGRAM_BOT_TOKEN` — from BotFather
- `DB_HOST`, `DB_PORT`, `DB_USER`, `DB_PASSWORD`, `DB_NAME` — PostgreSQL

Optional:
- `ROI_OPEN_ACCESS` — `1`/`true`/`yes`/`on` opens the door (see Access above); read at boot.
- `ROI_PROJECT_PATH` — a real environment variable, not `.env` (the `.env` is found through it).

## Instructions for AI Assistant

### Memory Management
- Read `.memory/INDEX.md` at session start for orientation
- After completing significant work, update `.memory/sessions.md` with what was done
- Update `.memory/status.md` when features are implemented or plans change
- Update `.memory/file-map.md` when new files are added
- Keep `.memory/` files concise — facts and references, not prose
- **`MEMORY.md` has a hard cap.** Claude Code loads it only up to 200 lines / 25,000 characters
  (UTF-16 units) and cuts the rest — the newest entries, at the bottom. Keep each index line one
  line under ~200 chars; the detail lives in the memory file. `CLAUDE.md` warns above 40,000
  chars (200k-context model): a rule gets 1–3 lines here, its story goes to memory.

### Documentation Updates
- Update `TODO.md` progress markers when tasks complete
- Add new localization keys to both `en.json` and `uk.json` simultaneously
- Write new uk player-facing copy in «ви» (see Localization above); add `.m`/`.f` + the `gender:` overload only when the string names the player with a gendered noun
- Keep `uk.json` free of English game-stat tokens / loot slang — use the UA glossary (`ОЗ`, `Досвід`/`досвіду`, `Снага`, `АТК`, `ЗАХ`, `здобич`, and `рівень` for the estate's, bag's and weapon's tier — **never «тир»**, auto-memory `feedback-tier-is-riven`); English tokens (HP/XP/ATK/DEF/Vigor) stay only in `en.json`, and code and docs keep saying `tier`. Full table in `.memory/localization.md`.
- If adding new controllers/models, update the file map in README.md's Project Structure section

### Git Workflow
- When a task is finished, ask user explicitly: "Task done. Commit?"
- On confirmation, generate a short compact commit message (no co-author line)
- **Never push.** Push operations are manual, user-side only.
- Stage only relevant files, never `git add -A`
- **A fix to an earlier UNPUSHED commit goes into that commit** when the owner asks: an `amend!`
  commit, then `GIT_SEQUENCE_EDITOR=: git rebase -i --autosquash <parent>`. Check the final tree
  against the pre-rebase one and re-record every hash that changed. Never rewrite anything already
  on `origin`. Auto-memory `feedback-fold-fixes-into-their-commit`.

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
- **The bot restarts itself when its poll loop dies, and that is the one automatic
  restart.** `PollWatchdog` exits the process when no `getUpdates` has COMPLETED for 120 s,
  and pm2 starts the same build again — it deploys nothing. **The SDK's rate limiter stays OFF**
  (`apiRequestLimitLongPolling: nil` in `configure`): its `LimiterAsync` deadlocks the poll loop
  after a burst. Never turn it back on, or upgrade the SDK, without re-running the burst test.
  A `[WATCHDOG]` line in the log is a freeze that happened; read the minutes before it, don't
  just enjoy the restart. Auto-memory `project-poll-loop-freeze`, `.memory/tech-stack.md`.

### Code Conventions
- All controllers subclass `TGControllerBase`, mark `@unchecked Sendable`
- Handler return type: `async throws -> Bool`
- Callback handlers: `static` methods
- Register button text for ALL locales in `attachHandlers`
- Use `context.bot.sendMessage(session:text:...)` over `context.respond()` in controllers
- Follow existing file header format (Created by / Maintained by)
- New models need corresponding migrations
- **A migration that rewrites rows runs its body in `database.transaction`.** Fluent records a
  migration only after `prepare` returns and wraps nothing in a transaction, so a throw halfway
  leaves it half-applied AND unrecorded, and the next boot applies it again — and a shift or a
  re-seat is not idempotent. Rehearse a deploy's migrations off the Pi before the restart
  (auto-memory `reference-deploy-rehearsal`).
- Keep Telegram callback_data under 64 bytes
- Hand-edit `content/data/*.json` in the house style already there (`"key" : value`, keys
  sorted, 2-space indent) — a default python re-emit reformats every line and buries the real
  change. The one proven exception: `json.dumps(obj, indent=2, sort_keys=True, ensure_ascii=False,
  separators=(',', ' : ')) + "\n"` reproduces all 29 files byte for byte (re-checked 2026-10-11); Swift's `JSONEncoder` and
  a DTO round-trip do NOT. Auto-memory `reference-house-json-style`.
- Never interpolate an Optional directly into a player-facing string (`"\(item.icon)"` prints `Optional("🪖")`) — unwrap it (`item.icon.map { "\($0) " } ?? ""`). A clean build won't catch this; verify new strings actually render. (Same vigilance as the Lingo emoji-before-`%{}` rule in `.memory/localization.md`.)
