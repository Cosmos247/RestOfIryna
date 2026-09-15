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
| `content/spec/*.md` | The five approved content specifications (Phase 9, closed 2026-09-01). Numbers in them are emitted by `roi-content spec`, never typed — refresh the `<!-- generated -->` blocks after any content edit |
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

**Game content AND balance numbers are data, not code.** ALL of it — items, enemies, recipes, the
weapon / bag / estate ladders, the five capital institutions (trader, tavern,
market, guild, arena), the Master's shop, estate plots, the fortune deck, the
daily quest pools, the rarity ladder (`rarities.json`), equipment sets
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

**A daily job is taken by hand** (2026-09-07). `QuestCatalog.daily` still decides WHICH job
each NPC offers — a stable hash of `userId:npc:dayStamp`, rolling at 12:00 Kyiv — but the
offer sits on the board until the player accepts it at the NPC (`QuestProgress.accepted`,
`QuestService.accept`). `record` neither creates nor ticks an unaccepted row, so taking a job
STARTS the count and never backfills the day. Each job carries a `minLevel` and the pool is
filtered before the hash; the validator refuses a pool whose cheapest job starts above level
1. Rewards are authored at level 1 and scaled at payout by `ProgressionMath.questReward`, so
**the board must quote `Status.reward`, never `def.reward`**. Auto-memory
`project-quests-taken-by-hand`.

**Vigor does not regenerate** (Phase 8E). The pool is a stock; food, quests and the
level-up grant are the only sources, and the estate's plots are the intended income —
which is what makes the pool plus the food in the bag the real limit on how deep the
wilderness can be walked and still walked out of. Never reintroduce a trickle: the old
one deliberately did not pause during an expedition, so a player could stand at km 25
and wait out a full pool.

**HP regeneration is a different mechanic from Vigor and stays — but it is a PLACE, not a
pause between fights** (2026-09-10). `HealingService.canRest` names the three states that
suspend it: an `ExplorationState` row (in the forest), a `TravelState` row (on the road) and
`location == capital` (in town). The road needs its own check rather than falling out of the
other two — `location` is not flipped until arrival. Callers query the rows and pass the
answer; `tick` does no lookups of its own. Away from the estate the clock is CLEARED, not
merely skipped. Potions are the away-from-home heal.

Regen is **computed lazily on interaction**, so both ends of an absence are stamped
explicitly: `suspendResting` when an expedition or trip begins, `beginResting` when the
player lands home. A tick that only runs on interaction cannot observe a transition that
happens while nobody is interacting.

**What finishes while nobody is looking needs a watchman.** `RestNotificationService` (one
`Task.detached` on `realTime.restSweepInterval`, 60 s) answers three questions per player: HP
topped out at the estate, the fortune teller's 24 h cooldown elapsed, the 12:00 job rollover.
It runs the regen through `HealingService.tick` — never a second copy of the arithmetic.

**A background writer MUST take the session-cached `User` when one exists**
(`SessionCache.peek`): Fluent saves whole rows, so a sweeper holding its own copy silently
undoes the tap the player made a second earlier.

Full reasoning: `.memory/game-core.md` §Rest and the road, `.memory/session-auth.md`;
auto-memory `project-rest-notification-watchman`,
`feedback-background-writers-session-cache`.

**Passive expeditions are capped at `passive.dailyBudgetMinutes` (180) per game day**,
counted in the authored minutes the three choices are written in — a budget in wall-clock
seconds would mean a different number of runs at every `time.scale`. Counter plus day stamp,
rolling at 12:00 like every other daily system. The picker offers only what the day can still
pay for AND the handler re-checks; the charge lands after `beginPassive` succeeds, so a
failed start never costs the player a run. Auto-memory `project-daily-and-storage-ceilings`.

**Every "time left" the player sees goes through `Countdown.format`** — `2год 5хв` ·
`1хв 22сек` · `5хв` · `42сек`: the two most significant units that carry a value, with an
exact one dropping its tail so a whole-minute window still reads `5хв`. Durations are never
written into copy either — the expedition buttons, the tarot "active for" prefix and the
invite window are all printed from the values that own them.

**A leaderboard is a `Leaderboard`, never a `Rating`.** `rating` already means
crit / dodge / accuracy in this codebase and carries a display rule of its own, so the
four boards behind the journal say «Рейтинги» to the player and `Leaderboard` in every
identifier. They are ALL-TIME, which is the first period and not the only one: seasons are
a decided direction, and a seasonal board will be a second READING of a metric with its own
storage — **never a reset of `deepestKm` / `totalKmWalked`**, because zeroing those destroys
the all-time board to build the seasonal one. The single exception, 2026-09-15: `deepestKm`
stopped counting steps and started counting RETURNS, and a column whose meaning changed is
not the same ladder, so `ResetDeepestKm` zeroed it once. `totalKmWalked` was left standing —
it still measures what it always measured, which is the test to apply before ever doing this
again. **One ladder, one implementation:** the Arena's
own «Найкращі бійці» renders the same `LeaderboardService.view(.honor,…)` as the journal's
board, because two screens that rank the same rows with two code paths disagreed about ties
for four months before anyone looked. Auto-memory `project-leaderboards-will-go-seasonal`.

**A lifetime counter has exactly one writer — and WHEN it writes is half the rule.**
`totalKmWalked` is a tally: `User.recordStep()`, called from `ExplorationService.rollStep`,
the funnel all three kinds of step share, plus `handleHomeReached` for the last stride, which
rolls no event. `deepestKm` is a RETURN: `User.bankDepth(_:)`, called only where the player is
standing at the manor again — `handleHomeReached` and the passive report's surviving branch —
from `ExplorationState.maxDepthKm`, the run's high-water mark, because `stepsDeep` counts back
down on the way home. Until 2026-09-15 depth was raised per step, so a governor who died at
km 31 kept the record while the board promised a kilometre walked back from; the words were
the half that was right. **Every change of depth goes through `ExplorationState.moveTo(km:)`**
— step out, step back, passive walk, the flee that pushes you back a km — for the same reason
the tally lives in `rollStep`. Put a new counter where the thing it counts already funnels;
a counter each caller has to remember is a counter some caller forgets, which is exactly how
the hunger tick went missing on six of ten exits. Auto-memory `project-depth-is-banked-on-arrival`.

**The forest is left on foot, or not at all.** `/start` and a stray Cancel used to force-end
an expedition from any depth with the bag intact, and `/start` inside a fight deleted the
expedition row outright. Both re-render instead — the walk screen, or the fight — which
serves the case the hatch was really there for (a lost or stale keyboard) without ending the
walk. It has to be closed on BOTH screens: banking depth at the door makes any free exit the
cheapest way to bank a record, and a hatch closed in one controller just moves one screen in.
The one real escape left is a fight whose enemy id no longer resolves, which ends the
expedition rather than trapping the player.

**One number, one source. A screen never sums two losses under one label.** A step in
the forest can cost HP twice — the event it rolled, and the hunger tick that is charged on
every step once Vigor hits 0 — so `ExplorationService.rollStep` returns a `StepResult`
pairing the event with `starvationHpLost`, and each is printed on its own line. Carrying it
on the RESULT rather than inside an enum case is the point: when it was each branch's job
to remember, ten of `rollStep`'s exits are reachable while starving, and **two carried the tick, one fused it into the root's own number, one blamed a beast for it, and six dropped it silently**. If you add a source of damage to a step, add it
to `StepResult` — never to another source's number. The measurement that forced this, and
what the fused number told a player: auto-memory `project-damage-sources-named-separately`.

**An escape is `CombatService.fleeSucceeds`, never a roll against `fleeChance`.** The
per-class chance (warrior 40 / archer 70 / mage 90) is half the rule; the other half is
`combat.json` → `flee.maxFailures`, the per-fight ceiling that grants the attempt after
that many failures to every class. Both live behind one function because a failed escape is
not a free round — it is an unmissable hit at half armour with nothing dealt back, so an
unbounded tail sits on the one button a player reaches for when already losing. The count
is per FIGHT (`ExplorationState.combatFleeFails`, 0 on `beginCombat`, cleared on
`endCombat`): per expedition it would become a resource the player spends rather than a
floor under a bad run. Auto-memory `project-flee-has-a-ceiling`.

**A rating is a rating on every screen, and is never labelled `%`.** `crit` · `dodge` ·
`accuracy` are RATINGS converted through a level-linear curve (`CombatMath.percent`), so the
same +5 crit is 4.16% at level 1 and 1.35% at the cap. Every screen prints the bare rating,
so the three screens a player compares add up exactly against each other: an item grants a
rating, the level-up banner reports the rating gained, the sheet shows the rating held.
`CombatService.critPercent` / `dodgePercent` / `accuracyPercent` exist for when a screen is
ready to say what a rating is WORTH; it belongs BESIDE the rating, never instead of it, and
**the level-up banner can never follow** — 26% of level-ups would announce a drop, and a
celebration screen must not report a loss. The measurement that reversed this: auto-memory
`project-rating-vs-percent-display`.

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

**A transfer that RE-CREATES a row resets everything the row knew.** Tier, wear and enchant
are per-instance (`GearState`), so a path that deletes a row here and calls `add` there hands
back a factory-fresh item — which is how a warehouse round-trip was a free repair that also
undid the max shave, and burned the enchant silently, until 2026-09-15. Both `InventoryEntry`
and `WarehouseEntry` carry `GearState` now and every create-path takes it as `carrying:`;
`TradeService` shows the other correct shape — it REASSIGNS the row's owner and never
re-creates it. A new per-instance column belongs IN `GearState`, not beside it. The same
day's other defect is the screen half of the rule: **the Master repairs a ROW, not a
loadout** — a list must ask the same question of every kind it lists, and asking armour "do
you own it" while asking the weapon "is it worn" is how an unequipped bow silently lost the
right to be mended. Auto-memory `project-gear-state-travels-with-the-unit`.

**Every equippable item is bounded by a stat budget.** `budget(itemLevel, slot, rarity)
= slotWeight · (6.0 + 1.5·itemLevel) · rarityBudget` in `tuning/budget.json`; an item's
stats ARE that budget spent at fixed exchange rates, and the validator refuses an
overspend. Because the combat curves were derived from this same budget, an item that
respects it cannot move any stat's percentage — which is what makes adding items safe.
Two consequences worth knowing before touching gear:
- `itemLevel` is NOT `tier`. Tier is a crafting-ladder rung (1–5); item level is the
  budget input (1–40). The weapon ladders map tiers to 1/10/20/30/40.
- **Never give anything a flat bonus — items OR techniques.** Enchant is `1 + 4% × level`
  of the item's OWN stats, set bonuses are capped against their members' combined budget,
  and every Super stance lifts by a multiplier of the character's own stat. The same
  +32 DEF is 267% of a level-1 chest and 14% of a level-40 one; the same rule caught
  `hawks_eye` granting +115% crit at level 1 and +21% at the cap. No flat number works
  at both ends, and `roi-content simulate` now audits every lift for exactly this.

**A weapon ladder is ONE object.** The three upgradable weapons render through
`ItemDisplay.nameKey(for:tier:)` → `item.<id>.t<tier>`, and the rungs must keep a word in
common — the player is upgrading a thing, not swapping it for a different one, and
`locale.ladder_name_drift` warns when no word survives. Wherever a label describes an
inventory ROW rather than a shop listing, pass the row's tier —
`CapitalController.itemLabel(_:tier:lingo:locale:)`. Auto-memory
`feedback-ladder-names-one-noun`.

**Access is invite-only and lives in the database.** The `allowed_users` table
(`AllowedUser` / `AccessControl`) replaced the hardcoded `allowedUsers` array;
`foundingUsers` in `configure.swift` is now only the migration's seed list. To let a new
tester in, use **`/link`** (developer-only) — never a code edit. The gate lives in
`TGDispatcher` **ahead of routing**, so a refused stranger never gets a `User` row, and it
accepts the 16-letter token either as a `/start` payload or pasted as a bare message.
`allowed_users` is in `WipeForRebalance.preserved` — a wipe resets the game, not the guest
list. `developerUsers` stays hardcoded and is allowed before the table is read: the brake
against locking yourself out of your own bot. Token design and the three decisions behind
it: auto-memory `invite-only-access`.

**`/reload` hot-swaps content without a restart** (dev-only, `developerUsers`; `/content`
shows what is loaded). The order is the safety: **parse → validate → live-check → build
→ install**, with `install` the only infallible step and last, so a refused reload leaves
the running game untouched. `LiveReferenceCheck` refuses a bundle that would drop an id
live rows still point at — if you add a column that stores a content id, add it to
`LiveReferenceQuery.collect` or the hot swap will happily break it. **Lingo is NOT
reloaded**: new locale strings still need a restart.

**A key the validator REQUIRES is not a key anything renders.** `ContentValidator`'s
`requireKey` proves a string exists in both locales, never that a player can reach it: four
of the five `plot.type.<t>.desc` blurbs were enforced in `uk.json` and `en.json` for months
while `PlotCatalog.descriptionKey` was read only in the branch for plots that produce
nothing. When you add a `requireKey`, name the screen that renders it — and when a screen
describes a thing, it must describe ALL of it: the Mine's second output stream was invisible
on the one screen where the plot is chosen, so the choice was made on half the information.
Both lines are built from the data (`bonusOutput`, `descriptionKey`) rather than written
into copy, so a future two-stream plot gets them free. Auto-memory
`project-plot-streams-and-dead-lore`.

**Content is specified before it is authored.** `content/spec/*.md` holds the signed-off
list — what creatures exist, at what level and archetype, what items fill which slot, what a
set bonus may cost and where silver enters and leaves — and content work follows it, never
goes around it. Every number in a spec is printed by `swift run roi-content spec
<progression|gates|bestiary|items|sets|economy|opening>`, never typed, so a specification
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
`--strict` exits 1 on a broken band.

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
`content/data/` — the game itself as JSON. `content/spec/` — the five content specifications signed off in Phase 9 (closed). `content/lore.md` — the world (families, zones, visual reference); `content/bestiary.md` and `recipes.md` are pre-rebalance reference docs, the bestiary one marked SUPERSEDED.

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

**Ukrainian agrees with the NOUN being named** — «лук зламав**ся**», «чоботи зламали**сь**»,
«Шахта заповнен**а**» but «Курник заповнен**ий**». Items declare `item.<id>.gender` and plots
`plot.type.<type>.gender` (`m` · `f` · `n` · `pl`), **in `uk.json` only**: gender belongs to
the WORD, not the object, and English never asks. The suffix rule itself is
`Lingo.localize(_:agreeingWith:locale:)` — ONE implementation, which
`ItemDisplay.localize(_:agreeingWith:lingo:locale:)` wraps for items; a new kind of noun
looks its gender up and calls the same function rather than copying three lines and
forgetting `pl`. The validator warns on a missing declaration and errors on a bad one, for
both kinds.

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
  every line and buries the real change
- Never interpolate an Optional directly into a player-facing string (`"\(item.icon)"` prints `Optional("🪖")`) — unwrap it (`item.icon.map { "\($0) " } ?? ""`). A clean build won't catch this; verify new strings actually render. (Same vigilance as the Lingo emoji-before-`%{}` rule in `.memory/localization.md`.)
