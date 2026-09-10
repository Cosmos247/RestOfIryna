# CLAUDE.md — ROI Project Reference

## Project Overview

**Rest Of Iryna (ROI)** is a massively-multiplayer medieval text RPG for Telegram, built in Swift. Players explore a wilderness plagued by rabies, build up an estate of production plots, battle beasts, and wage territorial wars. (The estate is an abstract slot-indexed plot list — the 30×30 spatial grid was removed from the roadmap on 2026-05-18 and must not be proposed again.)

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

**The router is resolved INSIDE `RouterStore`'s per-user chain, on the routerName as it stands** (2026-09-10). The SDK hands every update to its own `Task.detached`, so two quick taps are both read before either has transitioned; `TGDispatcher` still passes the key it read, but only as a fallback. Resolving it earlier is what delivered a second tap to the controller the first had just left — a step taken mid-fight, a capital tap answered by the estate, and in both cases a screen re-sending the keyboard the player no longer stands in. `[ROUTE]` in the log fires when the requested and live keys differ, which measures the race rather than arguing about it.

**A refusal carries the keyboard of the router the player is actually on.** `TGControllerBase.currentKeyboard(for:lingo:)` looks it up; a "you cannot do that from here" notice sent with no markup leaves whatever was last set, so a player whose keyboard has drifted is left tapping buttons for a place they are not in. Guards re-render the screen that owns the state instead of only refusing — `ExplorationController.guardInCombat` re-draws the fight, which re-asserts the combat keyboard, so the mis-tap is also what repairs it.

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

**A daily job is taken by hand** (2026-09-07). `QuestCatalog.daily` still decides
WHICH job each NPC offers — a stable hash of `userId:npc:dayStamp`, rolling at 12:00
Kyiv — but the offer sits on the board until the player accepts it at the NPC
(`QuestProgress.accepted`, `QuestService.accept`). `record` neither creates nor ticks
an unaccepted row, so taking a job STARTS the count and never backfills the day. Each
job also carries a `minLevel`, and the pool is filtered before the hash so a job whose
materials sit at km 11 or behind an estate room is never offered to someone who cannot
reach it; the validator refuses a pool whose cheapest job starts above level 1. Rewards
are authored at level 1 and scaled at payout by `ProgressionMath.questReward` — XP on
the `mobXP` exponent (a job is worth the same NUMBER OF KILLS at every level), Vigor on
the pool it refills, silver linearly — so the board must quote `Status.reward`, never
`def.reward`.

**Vigor does not regenerate** (Phase 8E). The pool is a stock; food, quests and the
level-up grant are the only sources, and the estate's plots are the intended income —
which is what makes the pool plus the food in the bag the real limit on how deep the
wilderness can be walked and still walked out of. Never reintroduce a trickle: the old
one deliberately did not pause during an expedition, so a player could stand at km 25
and wait out a full pool.

**HP regeneration is a different mechanic and stays — but it is a PLACE, not a pause
between fights** (2026-09-10). `HealingService.canRest` names the three states that
suspend it: an `ExplorationState` row (in the forest), a `TravelState` row (on the
road) and `location == capital` (in town). Only the first was ever checked, so the
manor's bed worked from anywhere in the kingdom. The road needs its own check rather
than falling out of the other two — `location` is not flipped until arrival, so
someone walking to the capital still reads as being at the estate. Callers query the
rows and pass the answer; `tick` does no lookups of its own. Away from the estate the
clock is CLEARED, not merely skipped, so time banked before leaving cannot be spent on
the way back. Potions are the away-from-home heal, and the fortune teller's one card
still restores in full.

Regen is **computed lazily on interaction**, so both ends of an absence are stamped
explicitly: `suspendResting` when an expedition or a trip begins, `beginResting` when
the player lands home (RouterStore's post-dispatch check covers every screen path; the
passive report push and a travel arrival cover the background ones). Miss the first and
a passive run refunds its own damage; miss the second and the stretch between coming
home and the next tap heals nothing. A tick that only runs on interaction cannot
observe a transition that happens while nobody is interacting.

**What finishes while nobody is looking needs a watchman.** Lazy-on-interaction
state has no observer at the moment it completes, so `RestNotificationService`
(one `Task.detached` on `realTime.restSweepInterval`, 60 s) answers three
questions per player: HP topped out at the estate, the fortune teller's 24 h
cooldown elapsed, the 12:00 job rollover. It runs the regen through
`HealingService.tick` — never a second copy of the arithmetic. **A background
writer MUST take the session-cached `User` when one exists**
(`SessionCache.peek`): Fluent saves whole rows, so a sweeper holding its own copy
silently undoes the tap the player made a second earlier. Two of the three need a
persisted flag (`fortune_ready_notified`, `quest_rollover_stamp`); HP needs none,
because a player at full HP is not a player about to reach it.

**Passive expeditions are capped at `passive.dailyBudgetMinutes` (180) per game
day**, counted in the authored minutes the three choices are written in — a budget
in wall-clock seconds would mean a different number of runs at every `time.scale`.
Counter plus day stamp (`passive_minutes_today` / `passive_day_stamp`), rolling at
12:00 like every other daily system. The picker offers only what the day can still
pay for AND the handler re-checks, because a picker left in the chat from an
earlier run is exactly the tap that would overspend; the charge lands after
`beginPassive` succeeds, so a failed start never costs the player a run.

**Every "time left" the player sees goes through `Countdown.format`** — `2год 5хв`
· `1хв 22сек` · `5хв` · `42сек`: the two most significant units that carry a value,
with an exact one dropping its tail so a whole-minute window still reads `5хв`.
Minutes printed alone until 2026-09-11, which made `1хв` mean anything from 1:00 to
1:59 — a whole crossing of doubt on a two-minute road.
The `MM:SS` / `HH:MM` pair it replaced could not be told apart: `05:30` was five
and a half MINUTES on the trail and five and a half HOURS at the fortune teller.
Durations are never written into copy either — the expedition buttons, the tarot
"active for" prefix and the invite window are all printed from the values that own
them.

**A rating is a rating on every screen, and is never labelled `%`.**
`crit` · `dodge` · `accuracy` are RATINGS converted through a level-linear curve
(`CombatMath.percent`), so the same +5 crit is 4.16% at level 1 and 1.35% at the
cap. The character sheet printed `12%` beside a raw rating until 2026-09-11 —
roughly true at level 1 and threefold wrong at the end, the same rot a flat bonus
has — and four gear screens did the same. All of them print the bare rating now,
so the three screens a player compares add up exactly against each other: an item
grants a rating, the level-up banner reports the rating gained, the sheet shows
the rating held. `CombatService.critPercent` / `dodgePercent` / `accuracyPercent`
exist for when the sheet is ready to say what a rating is WORTH; when that lands
it belongs BESIDE the rating rather than instead of it, because **the level-up
banner cannot follow** — the rating grows in rounded proportional steps while the
curve's denominator grows every level, so 26% of level-ups (93 of 351) would
announce a drop of up to 0.48 points, and a celebration screen must not report a
loss.

**Every gear screen renders all six `GearStats` fields, HP included.** Four of
the five skipped HP until 2026-09-11, which hid the whole Forester set's +18 max
HP everywhere except the shop card a player sees once before buying. HP reuses
`profile.health` rather than adding a `workshop.stats.hp`: `profile.*` and
`workshop.stats.*` are already two families for one set of names kept in step by
hand, and that duplication is exactly how `accuracy` shipped as «Влучність» on
two screens and «Точність» on two others.

**The warehouse cap is enforced on every path in, including the plot harvest.**
Hand deposits always checked it; `PlotService.harvest(to: .warehouse)` did not,
which made the estate's own income the one way to overflow the store. Harvest is
all-or-nothing like the bag, and the yield stays standing on the plot — partial
cannot be expressed, because the Mine's two output streams share one
`lastHarvestedAt`. **No account is exempt:** the `isDeveloper` bypass is gone from
all four warehouse checks (it remains on the BAG, which is a different ceiling).

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
`ItemDisplay.nameKey(for:tier:)` → `item.<id>.t<tier>`, and the rungs must keep a word
in common: the player is upgrading a thing, not swapping it for a different one, and the
screens that name a weapon generically (the Master's `capital.master.repair.weapon.<class>`)
cannot follow a noun that changes. `locale.ladder_name_drift` warns when no word survives.
Wherever a label describes an inventory ROW rather than a shop listing, pass the row's
tier — `CapitalController.itemLabel(_:tier:lingo:locale:)`.

**Access is invite-only and lives in the database.** The `allowed_users` table
(`AllowedUser` / `AccessControl`) replaced the hardcoded `allowedUsers` array;
`foundingUsers` in `configure.swift` is now only the migration's seed list. To let a new
tester in, use **`/link`** (developer-only) — never a code edit. `/link` mints a
16-letter `InviteToken`: an encrypted UNIX timestamp plus an HMAC tag keyed on
SHA256(bot token), good for five REAL minutes (`time.scale` never touches it). The gate
lives in `TGDispatcher` **ahead of routing**, so a refused stranger never gets a `User`
row, and it accepts the token either as a `/start` payload or pasted as a bare message —
a deep link only delivers its payload when the client actually sends `/start <token>`,
and live it did not. `allowed_users` is listed in `WipeForRebalance.preserved`: a wipe
resets the game, not the guest list. `developerUsers` stays hardcoded and is allowed
before the table is read — the brake against locking yourself out of your own bot.

**`/reload` hot-swaps content without a restart** (dev-only, `developerUsers`; `/content`
shows what is loaded). The order is the safety: **parse → validate → live-check → build
→ install**, with `install` the only infallible step and last, so a refused reload leaves
the running game untouched. `LiveReferenceCheck` refuses a bundle that would drop an id
live rows still point at — if you add a column that stores a content id, add it to
`LiveReferenceQuery.collect` or the hot swap will happily break it. **Lingo is NOT
reloaded**: new locale strings still need a restart.

**Content is specified before it is authored.** `content/spec/*.md` holds the
signed-off list — what creatures exist, at what level and archetype, what items
fill which slot, what a set bonus may cost and where silver enters and leaves —
and content work follows it, never goes around it. All five were approved in
Phase 9. Every number in a spec is printed by `swift run roi-content spec
<progression|gates|bestiary|items|sets|economy|opening>`, which reads the same
`ProgressionMath` / `EnemyGenerator` / `BudgetMath` / `BudgetCurve` the game does,
so a specification cannot drift from the generator it feeds. `opening` is the one
table that ROLLS rather than solves — a fight's Vigor cost is a distribution — so
it runs `FightSimulator` at the same seed and sample size `simulate` uses, and the
two print the same numbers by construction. Give it `-c release`.

**A spec quotes generated tables inside `<!-- generated: … -->` markers, and the
marker records the COMPLETE command including flags** — a block produced with
`--levels 1,10,20,25,30,40` under a bare `roi-content spec sets` marker cannot be
reproduced, so it reads as permanently drifted even though every number in it is
right. **After any content edit, re-run the command in the marker and refresh those
blocks** — the markers exist so
drift is mechanically detectable, and in Phase 10 that check caught two blocks the
enemy re-spread had silently invalidated. It protects tables, not the prose beside
them: a hand-counted number in a sentence is exactly where the one real error of
Phase 9 lived.

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

**The player is addressed as «ви» (uk).** Every Ukrainian string that speaks to the player uses the formal plural — `ви / вас / вам / ваш`, present `-єте/-ите`, imperative `-іть/-те` — NPC speech included. That settles past tense and adjectives on its own (both go plural), so the only thing left that declines by gender is a **noun naming the player**: намісник/-иця, воїне/войовнице.

**Ukrainian agrees with the ITEM's name too.** A sentence about a thing agrees
with that thing's noun — «лук зламав**ся**», «чоботи зламали**сь**» — so every
item declares `item.<id>.gender` (`m` · `f` · `n` · `pl`) **in `uk.json` only**:
gender belongs to the WORD, not the object, and English never asks. Route such a
string through `ItemDisplay.localize(_:agreeingWith:lingo:locale:)`, which picks
`<key>.m/.f/.n/.pl` for uk and the plain key elsewhere — the mirror of the
player-gender helper below. The validator warns (`locale.item_gender_missing`)
when a name declares no gender, because the silent fallback is masculine and that
is wrong for seventeen of the thirty-three shipped names.

**Gendered text (uk feminitives):** Ukrainian strings that name the player with a gendered noun use the gender-aware overload — `lingo.localize("key", gender: session.gender, locale: ..., interpolations: ...)`. It looks up `key.m`/`key.f` for `uk` and the plain `key` for English (so **never duplicate English** — only `uk.json` gets `.m`/`.f`). Player gender (`User.gender`, "m"/"f", nil=male) is chosen at registration step 1. Thirteen keys still need it; nine collapsed to single keys on 2026-09-07 when «ви» made their two variants identical. When new copy names the player, either add `.m`/`.f` + route through this overload, or phrase around the noun. Full key list + rationale in `.memory/localization.md`.

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
**RULE — every player-visible image goes through `sendCachedPhoto(...)` (`Swift/Helpers/PhotoCache.swift`), no exceptions.** This is the ONLY sanctioned way to send a photo: it captures Telegram's `file_id` on first send and reuses it forever, so any newly-added art is automatically file_id-cached the first time it's shown — there is nothing extra to register. Never call `bot.sendPhoto` directly for player art, and note the `TGBot.sendMessage(session:text:…)` convenience has **no `photo:` parameter** on purpose (that bypass was removed) — if you need an image, you need `sendCachedPhoto`. The helper does one thing:
- **file_id cache** — first send uploads the JPG/PNG bytes, captures Telegram's returned `file_id`, every later send reuses the id (no repeated upload). file_id is a global Telegram reference, so one cached entry serves every user; the cache is in-memory and refills after a restart. (After swapping an asset file on disk, restart the bot so the stale in-memory file_id is dropped and the new bytes re-upload.)

**RULE — every in-place screen redraw goes through `editScreen(...)` (`Swift/Helpers/ScreenEdit.swift`).** Telegram edits a message's TEXT or its CAPTION, never either, and which one a screen has depends on whether it was sent with artwork — so `editMessageText` against a photo fails with "there is no text in the message to edit". That was **310 of the 807 API refusals** in a day and a half of Pi log, every one swallowed by `try?`: the player tapped, the screen did not change, and nothing said why. `editScreen` takes `isPhoto` as the caller's expectation and the fast path, falls back to the other field when that is wrong, and logs the recovery with the call site (`#function`). Never call `editMessageText` / `editMessageCaption` directly. Its `TelegramAPIError` also lets `HummingbirdTGClient` pick a log level by refusal, so "message is not modified" and "message to delete not found" stop burying the failures that matter.

Photos are **kept in chat history** — nothing is deleted. Players asked to keep a scrollable record of where they've been (and for future stats). Because every bubble references the same server-side file_id, a long history of repeated backdrops costs no extra storage (Telegram dedups by file_id), so accumulation is cheap.
```swift
_ = try await sendCachedPhoto(
    assetPath: "\(projectPath)/Assets/capital/<id>.jpg",
    caption: text,
    replyMarkup: .inlineKeyboardMarkup(keyboard),
    toUser: context.session,
    bot: context.bot
)
```
**Exception — tavern gambling rolls (24 h sweep).** Dice/darts rounds spray messages (labels, animated dice, result). Telegram forbids bots from deleting a **dice** message in a private chat until it's 24 h old (anti-cheat), so they can't be removed when the round ends — they stay as game history. Each round records every message id via `TavernCleanupService.record(...)` into the `tavern_game_messages` table; a background sweeper (`TavernCleanupService.startSweeper`, started in `configure.swift`, mirrors `PlotProductionService`) deletes each message + row once it ages past 24 h. This is the only message flow that gets cleaned up.

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
- Never interpolate an Optional directly into a player-facing string (`"\(item.icon)"` prints `Optional("🪖")`) — unwrap it (`item.icon.map { "\($0) " } ?? ""`). A clean build won't catch this; verify new strings actually render. (Same vigilance as the Lingo emoji-before-`%{}` rule in `.memory/localization.md`.)
