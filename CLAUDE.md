# CLAUDE.md — ROI Project Reference

## Project Overview

**Rest Of Iryna (ROI)** is a massively-multiplayer medieval text RPG for Telegram, built in Swift. Players explore a wilderness plagued by rabies, manage 30x30 estates, battle beasts, and wage territorial wars.

- **Language:** Swift 6.2 (strict concurrency, `ExistentialAny`)
- **Platform:** macOS 14+, Telegram Bot (long polling)
- **Database:** PostgreSQL 16 via Fluent ORM
- **Target:** 1,000-3,000 concurrent players

## Key Documents

| File | Purpose |
|------|---------|
| `GDD.md` | Full game design — classes, hunger, exploration, combat, estates, economy |
| `README.md` | Stack overview, architecture diagram, setup guide, dev notes |
| `TODO.md` | Phased implementation tracker with progress markers |
| `Prompt.me` | Compact session primer — read this at session start |
| `.memory/INDEX.md` | Project memory system index |
| `.memory/status.md` | What's implemented vs planned |

## Architecture (Router-Controller State Machine)

```
TGUpdate -> TGDispatcher -> Auth check -> SessionCache -> RouterStore.process(routerName)
                                                              |
                              RegistrationController  MainController  SettingsController  ...
```

Each user has a `routerName` field. Updates route to the controller registered under that name. Controllers transition by setting `session.routerName` and calling `saveAndCache()`.

## Source Layout

All Swift code lives in `Swift/` (not `Sources/`).

- `Swift/entrypoint.swift` — `@main`, calls `configure()`
- `Swift/configure.swift` — Bootstrap: DB, Lingo, Bot, Hummingbird. Exposes `projectPath` as a public global so controllers can load assets. **Path is hardcoded to the dev machine.**
- `Swift/routes.swift` — `RouterStore` actor (router registry + **per-user dispatch serialization** — each new update for a given Telegram ID chains behind the previous task's completion via a token-keyed `Task` chain, so spam-taps can't race on the cached `User` instance or DB rows like `ExplorationState`).
- `Swift/Controllers/` — Game screen controllers (Main, Registration, Settings, GlobalCommands, Inventory tree nav, Estate tree nav + expedition-guard, Exploration with mode picker + active + passive + report delivery, Combat with class-flavoured Attack/Defend/Flee turn-based duel rendered as **inline buttons** so the previous reply keyboard stays put; stub for Capital)
- `Swift/Models/User.swift` — User model (identity, class, nickname, estate, stats, gold, last_hp_tick_at) + effective-stat computed properties
- `Swift/Models/Item.swift` — static item catalog (ItemType / ItemEffect / EquipmentSlot / GearStats / Item / ItemCatalog) — code-based, not in DB. Each `Item` has optional `icon` (per-item emoji shown in all inventory/warehouse/bag/report rows) and `descriptionKey` (locale key for the lore blurb shown in a modal alert on the info-button tap). `food.potato` and `food.raw_meat` have `effects: []` — both need to be cooked in the Kitchen (Phase 5) before they become edible; tapping Eat triggers the `consume.not_raw_edible` toast instead of the generic hunger restore.
- `Swift/Models/InventoryEntry.swift` — Fluent model (user_id, item_id, quantity, equipped_slot) + add/remove/has/list/canAccept/slotsUsed helpers. Enforces a 50-slot cap on non-equipped rows (upgradable later via Workshop)
- `Swift/Models/WarehouseEntry.swift` — Fluent model for estate warehouse storage (separate table from inventory); add/list/totalQuantity helpers
- `Swift/Models/ExplorationState.swift` — Fluent model, one row per active or passive expedition (user_id unique, stepsDeep = current km, `visited_rooms` JSON dict of km → visit count, `mode` = active/passive, `ends_at`, `report_json`, `combat_enemy_id`, `combat_enemy_hp`). Presence = exploring; absence = at estate. begin / beginPassive / current / end / allPassive / recordVisit / visitCount / isPassive / hasReadyReport / secondsRemaining / isInCombat / beginCombat / endCombat helpers. Combat fields are nullable — non-null on both = active combat embedded in the expedition row (single-row-per-user invariant gives us "no concurrent fights" for free). Schema still has a dormant `returning` Bool column from an earlier 3.2 pass.
- `Swift/Models/Enemy.swift` — code-based bestiary (Enemy + EnemyLootDrop + EnemyCatalog). 5 animals across 4 tiers (T1 = km 1-5 up to T4 = km 16-20). Two families: wild (🐗 boar / 🫎 moose / 🦬 buffalo — drop raw meat + hide) and rabid (🐈‍⬛ lynx / 🐺 wolf — drop hide only because rabies-tainted meat is inedible).
- `Swift/Migrations/` — CreateUser, AddCharacterFields, AddProfileStyle, AddGameStats, CreateInventory, RemoveCrownsField, AddEquipSlotToInventory, AddGearBonuses, CreateWarehouse, CreateExplorationState, AddExplorationReturnState, AddHpRegenTick, AddPassiveExpeditionFields, RenameMaterialIds, RenameFoodIds, AddCombatFields
- `Swift/Services/` — Domain services. HungerService is pure (callers persist). HungerAction has six cases — `walkRoom`, `walkRoomDoubleSpeed`, `combatRound` (passive autobattle, 1 hunger), `combatAttack` / `combatDefend` / `combatFlee` (active combat per-action: 2 / 1 / 3), `idle`. EquipmentService owns the atomic slot swap and saves entries + user itself. WarehouseService transfers one unit at a time between inventory and warehouse (skips equipped rows on deposit; preflights inventory space on withdraw and returns a typed result enum). ExplorationService drives a single step: hunger drain + starvation HP tick + three-tier weighted event roll (keyed on prior visit count) + branch-on-mode encounter resolution — `rollStep(mode:)` returns `.encounterStarted` for active mode (CombatController takes over) or runs autobattle for passive mode and returns `.encounterWon` / `.encounterLost`. `awardEncounterDrops` is a public hook used by CombatController on victory to mirror the loot path. HealingService.tick lazy-computes passive HP regen (5%·maxHp/min) while at estate; called from `RouterStore.process` on every interaction. PassiveExpeditionService owns the passive-mode flow — duration picker, `Task.detached` + **live per-step** scheduler (`runLive`, which sleeps until each step's absolute fire time and exits early on death so the report pushes immediately), progress tracked via `state.stepsDeep`, PassiveReport JSON blob, completion push via bot.sendMessage, and startup rescheduling (called from configure.swift after bot.start). **CombatService** owns the shared damage primitives — `applyAttack` returns `AttackOutcome (miss / hit / crit)` with `clamp(70 + acc − dodge, 10, 95)%` hit chance, ×1.5 crit on roll vs `attackerCrit %`, and ±10% variance; `chipDamage` returns the 30%-of-base damage Defend's parry-counter deals (no crit, no miss). Both `ExplorationService.resolveAutobattle` (passive) and `CombatController` (active) call into the same primitives — fights resolve with the same odds in either mode. Currently: HungerService, EquipmentService, WarehouseService, ExplorationService, HealingService, PassiveExpeditionService, CombatService.
- `Swift/Telegram/Router/` — Router engine (command matching, content types, context, args)
- `Swift/Telegram/TGBot/` — TGDispatcher + HummingbirdTGClient
- `Swift/Helpers/` — TGControllerBase (+ `dismissPendingPicker`), SessionCache, Lingo extension, Env helper, `EphemeralChatState` actor (tracks transient mode-picker message IDs per user so main-menu handlers can auto-delete the picker on navigation away).
- `Localizations/` — `en.json`, `uk.json` (~237 keys each). `exploration.find.<item_id>` keys carry per-item foraging flavor text used by the active-mode loot narrator. Combat keys live under `combat.*` — `combat.button.<action>.<class>` for class-flavoured Attack/Defend/Flee labels (9 buttons, used as inline-button text), `combat.you.{hit,crit,miss}` / `combat.enemy.{hit,crit,miss}` for round narration, plus `combat.encounter.intro / .victory / .defeat / .defend.absorbed / .flee.{success,fail}`, and `combat.in_progress` — the one-line "you're locked in combat with X" nudge sent when the player taps anything outside the inline action buttons mid-fight.
- `Assets/` — static binary assets loaded by bot. `Assets/registration/kings_charter.jpg` for the King's Oath step, `Assets/registration/<class>_estate.jpg` for the wolves encounter, `Assets/estate/level_<N>.jpg` (optional, user-supplied) for per-level estate artwork.

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

## Environment Variables

Required in `.env` (see `.env.example`):
- `TELEGRAM_BOT_TOKEN` — from BotFather
- `DB_HOST`, `DB_PORT`, `DB_USER`, `DB_PASSWORD`, `DB_NAME` — PostgreSQL

## Current State (as of 2026-04-23)

**Working:** Lore-driven 6-step registration (Artanian welcome → name → class selection with descriptions → King's Oath with class-specific starter weapon grant, automatically equipped → wolf encounter on the road with class-specific artwork sent via `sendPhoto` + caption + "⚔️ Stand and fight" inline button → **real CombatController fight against `enemy.rabid_wolf`**, only victory advances to estate naming → estate naming). Defeat or successful flee during the registration fight is a soft retry: full HP restored, registrationStep stays at 4, the wolves photo + Fight button are re-shown with a "🩸 you scrambled away" preamble. CombatController detects the registration context via `session.registrationStep < 6` — both the victory message and the estate-name prompt ship `ReplyKeyboardRemove` so combat-button labels can't be entered as the estate name. The very first registration message ships with `ReplyKeyboardRemove` so any leftover button labels can't be entered as a nickname or estate name. Nickname and estate-name input both run through a shared `validateName(...)` helper using three character allow-lists (digits / Latin / Ukrainian Cyrillic) plus checks for edge whitespace and consecutive spaces — five distinct error toasts per field (`too_short` / `too_long` / `edge_space` / `consecutive_spaces` / `invalid_chars`). Single internal spaces are permitted so two-word names work. Equipment system: `EquipmentSlot` enum (8 slots), `GearStats` on Item, cached `gear_*_bonus` fields on User, `EquipmentService` for atomic equip/unequip with auto-swap of slot occupant; starter weapons grant +3 ATK (sword), +2 ATK/+1 ACC (bow), +2 ATK/+1 CRIT (staff). Effective stats (`effectiveAttack/Defense/Crit/Dodge/Accuracy` on User) = base + gear − hunger penalty. Main menu with 3-row keyboard (Explore + Inventory / Estate + Capital / Profile + Settings), character profile view (3 switchable styles via inline buttons + message editing, shows effective ATK/DEF and 😵 Starving indicator), settings, language switching, session caching, auth, localization (EN/UK), health endpoint. Inventory tree navigation: root always shows all 5 category buttons with live counts (empty categories show "(0)" and reply with a toast on tap); drill-down shows every item as its own inline button (future per-item description view) with a type-specific action button next to each row — 🍴 Eat / 🍷 Use (potion) / 🛡 Equip ↔ ❌ Unequip (gear) / ✨ Use (artifact). Gear rows carry a persistent per-item icon (⚔️ / 🏹 / 🪄 / 🦺 ...) via `Item.icon`, visible whether equipped or not. Food/potion consume via HungerService; gear equips/unequips via EquipmentService; artifacts still reply with "🚧 Not yet available" toast until their activation flow ships. Hunger service (pure): drain, consume, effective-stat penalty, starvation HP loss — callers wire in when Exploration/Combat ship. Backpack has a fixed 50-slot cap (1 row = 1 slot, equipped gear doesn't count) — enforced by `InventoryEntry.add` throwing `.inventoryFull`. `WarehouseService.withdraw` preflights space before moving. `InventoryController` header shows `X/50 slots`. Slot cap will be raised later via Workshop upgrades.

Dev-only commands restricted to mitya: `/grant <item_id> <qty>`, `/revoke <item_id> <qty>`, `/drain <amount>`. Dev inventory + warehouse seed on startup iterates `developerUsers` — each listed developer gets the same starter backpack and warehouse piles, with per-item top-up semantics (never reduces) and orphan cleanup for items no longer in the catalog. Dev profile reset flag (`resetDevProfile` in configure.swift, currently **off** so dev profile state persists across launches; flip to `true` when you want registration exercised end-to-end on every launch) also wipes inventory + warehouse + any lingering `exploration_state` row for each developer when enabled, so registration-grants start clean. On bot startup admins receive a localized "Artania awakens" message; the attached reply keyboard is now context-aware — registered players (`registrationStep >= 6`) keep whatever keyboard their current controller owns (main / exploration / settings…), while combat falls back to the exploration keyboard since combat itself owns no reply markup. Unregistered users still get a one-time `[/start]` button so they have an obvious entry point. Locale per admin is read from the User row; falls back to `uk` if the user hasn't registered.

**Exploration (Phase 3.1 MVP + 3.2 per-room visit decay + passive estate regen + 3.3 passive expedition MVP landed):** Tapping 🗺 Explore now opens a **mode picker** first — `[🏃 Розвідка]` (active) / `[🏕 Експедиція]` (passive) — whenever there's no live expedition. If a passive expedition is in flight, re-opening shows a countdown status. If the background scheduler already completed the simulation, re-opening delivers the report and clears the state.

**Active mode (3.1 + 3.2):** A dedicated reply keyboard `[🚶 Step fwd] [🔙 Step back]` / `[🎒 Bag]` replaces main nav for the expedition. Step Forward increments `stepsDeep` and fires `ExplorationService.rollStep` at the new km with the room's prior visit count; the service picks a three-tier weight table — tier 0 fresh (nothing 20 / loot 40 / encounter 30 / trip 10), tier 1 reduced (50/20/20/10), tier 2+ bare (100/0/0/0 — only .nothing / .starvationOnly fires). After the roll the room's counter is incremented. Walk-room hunger drain + per-step starvation HP tick fire on every step. Loot narration is **per-item** for the 8 foraging items — each one has an `exploration.find.<item_id>` flavor sentence, rendered as `<flavor>\n<b>+N 🌲 ItemName</b>` (quantity random 1-2). Foraging pool: shallow = pine_lumber / river_pebble / forest_berries / forest_nuts; medium = potato / duck_egg / clay / old_iron. Hide + raw_meat are **enemy-kill drops only**. Encounter drops use the generic `loot.picked/full` template (also now includes item icon). Step Back at km ≥ 2 decrements + rolls; at km ≤ 1 it ends with a clean arrival. `/start` and stray Cancel presses force-end.

**Passive mode (3.3):** Duration picker → 30 / 60 / 90 units (in test mode = seconds, in prod = minutes via `PassiveExpeditionService.testMode` constant). `PassiveExpeditionService.start` creates an `ExplorationState` row with `mode = .passive` and `ends_at = now + duration`, then arms a `Task.detached` running `runLive` — the **live per-step simulator**. runLive loops over the scheduled steps (5 units per step): sleeps until each step's absolute fire time (`createdAt + K * stepDuration`), rolls one event via `ExplorationService.rollStep`, persists progress via `state.stepsDeep`, and either continues or **exits early on death** — in which case the report pushes immediately without waiting out the remaining timer. State persists the current step count so bot restart resumes at the right step (catch-up: any steps whose fire times fell during downtime run back-to-back with no sleep). Outcome counters + loot totals are NOT persisted between restarts (MVP tradeoff); a crash mid-expedition means the final report only reflects post-restart events. Final push: write `PassiveReport` JSON to `report_json`, then **send one combined message** — "🏰 You're back at the estate." line followed by the full report body (no Close button, no inline keyboard) — and delete the state row immediately so Estate / Capital unlock the moment the expedition ends. Report loot lines include per-item icons (🥔 🥩 🪵 etc.) via `Item.icon`, prepended in Swift to keep Lingo interpolations safe. If either message send fails, state is preserved so the controller can retry via `deliverPassiveReport` on the next Explore tap. On bot restart, `PassiveExpeditionService.rescheduleInflight` (called from configure.swift after `bot.start`) spawns a fresh runLive task for each in-flight state. While the timer counts down, the governor is considered to be in the forest — HP regen is PAUSED and the Estate menu is LOCKED until the expedition ends.

**Shared plumbing:** While the player is at the estate and NOT on any expedition (active or passive), `HealingService.tick` lazy-computes passive HP regen — 5% of maxHp per minute — on every interaction via `RouterStore.process`. During any expedition regen is fully paused (governor is in the forest, not resting at the manor). `RouterStore` queries `ExplorationState.current` once per dispatch and passes the presence as an `inExpedition` flag to `HealingService`.

**Mode exclusivity (3.4):** The Explore button label is static — no dynamic keyboard swaps (tried briefly but Telegram's reply-keyboard update semantics made it fragile). Gating happens at controller entry: tapping Explore while an expedition exists routes to `showExploration`, which shows either the active resume view or a passive countdown ("Expected arrival in MM:SS. Your governor is still on expedition 🏕."). Both **Estate** (`EstateController.showEstate`) and **Capital** (`CapitalController.showStub`) are locked during any expedition — each owns its `routerName` transition so the guard returns cleanly without leaving the player inside a "blocked" controller. Idempotency guards on the `explore:mode:active` / `explore:mode:passive` / `explore:dur:*` callbacks re-check `ExplorationState.current` before mutating state, so a stale picker tap can't silently overwrite an existing expedition. Three `.nothing` narrative variants render based on prior visit count: `exploration.outcome.nothing` / `.revisited` / `.bare`. Bag button (active mode only) shows a scoped inline view of food+potions. Death wipes every non-equipped `InventoryEntry` row, respawns at HP=1 (hunger preserved).

**Mode picker (lightweight state):** Tapping 🗺 Explore with no active expedition sends an inline `[🏃 Reconnaissance] / [🏕 Expedition]` picker but keeps `routerName = "main"` — the player is still in MainController throughout the picker phase. This is important so that tapping any main-menu button (Profile, Estate, Capital, Inventory, Settings) routes normally instead of falling through to `ExplorationController.unmatched`. To make the picker vanish cleanly when the player navigates away, `showModePicker` records the sent message ID in `EphemeralChatState.shared` (in-memory actor, not persisted) and every main-menu handler calls `dismissPendingPicker(context:)` at the top — that reads the cached ID, issues `deleteMessage`, and clears the entry. The inline callbacks still land on `ExplorationController` because `MainController.onCallbackQuery` forwards every `explore:*`-prefixed callback. No migration; if the bot restarts with a stale picker in chat, the Active/Passive buttons still work normally (just without auto-dismissal when the player leaves).

**Callback forwarding:** Inline buttons sent from background tasks (the scheduler-pushed passive report's "Close") can arrive while the player's `routerName` is `main` / `inventory` / `settings`. Each of those controllers' `onCallbackQuery` forwards any `explore:*`-prefixed data to `ExplorationController.onCallbackQuery` before falling through to its own logic, so the full state-cleanup + "back at the estate" greeting runs regardless of where the player is when they tap Close.

**Stubbed (coming-soon placeholders wired into the router):** Capital — shows a localized "coming soon" message and a back button. Estate now has a real skeleton controller (Phase 5 scaffolding) — tree nav with Root → House / Plot (Plot stub); inside House, Workshop and Kitchen are stubs but Warehouse is a real deposit/withdraw surface backed by the separate `warehouse` table. Category root shows live counts per item type. Drill-down renders two layouts:
  - Stackable types (food / material / potion / artifact): one aggregated row per item_id — `[Name] [🎒 N ⬆️] [📦 M ⬇️]`. Tap ⬆️ to deposit one unit, ⬇️ to withdraw one.
  - Gear (non-stackable): one row per physical unit — `[Name] [🎒 ⬆️]` for rows in the backpack, `[Name] [📦 ⬇️]` for rows in the warehouse. No `× N` aggregation since gear is always 1-per-row.
  Equipped gear is excluded from the inventory side of the transfer view (can't warehouse what you're wearing). Transfers go through `WarehouseService.deposit` / `.withdraw` — one unit per tap, atomic move between `InventoryEntry` and `WarehouseEntry`. The same per-row pattern applies in `InventoryController.gearRows`. Per-level artwork loaded from `Assets/estate/level_<N>.jpg` when the file exists.

Estate level is derived from `user.level` via `User.estateLevel` (every 5 player levels → +1 estate tier).

**Combat (Phase 4.1 MVP landed):** Turn-based "Standoff" duel triggered when active-mode `rollStep` rolls an encounter. `ExplorationService.rollStep(mode:)` returns `.encounterStarted(enemy)` for active mode (no HP / hunger spent on the encounter itself yet — only the walk-room drain for the step); passive mode keeps running `resolveAutobattle` since there's no UI to prompt the player from a Task. ExplorationController stamps `combat_enemy_id` + `combat_enemy_hp` on the expedition row, flips `routerName = "combat"`, and calls `CombatController.showCombat`. `CombatController` actions are **inline buttons** attached to each round message — `[Attack][Defend] / [Flee]` with class-flavoured labels via `combat.button.<action>.<class>` (warrior = Slash with sword / Parry / Retreat; archer = Loose arrow / Hide in shadow / Quick maneuver; mage = Magic strike / Magic barrier / Teleport). Each button carries `combat:attack` / `combat:defend` / `combat:flee` callback data; the controller's `generateControllerKB` returns nil so the player's previous reply keyboard (exploration's `[Step fwd][Step back]/[Bag]`, or nothing during registration) **stays put** but cannot drive the fight. Anything that isn't a valid combat callback (a tap on the old reply keyboard, free-form text, a stale Estate inline button) gets a one-line "you're in combat with X" nudge via `combat.in_progress` — no status-card or button duplication, since the previous combat message above still carries the live action buttons. **Attack** (−2 hunger): `applyAttack(player→enemy)` then `applyAttack(enemy→player)` with the player's full effectiveDodge. **Defend** (−1 hunger): chip damage to enemy via `chipDamage` (30% of base, no crit, no miss), incoming hit rolls against doubled `effectiveDefense`. **Flee** (−3 hunger): 50% flat — success = clear combat fields, `stepsDeep -= 1`, hand back to ExplorationController; failure = enemy lands a guaranteed full-damage hit "in the back" (no dodge, no crit roll), combat continues. Victory: `awardEncounterDrops` adds loot to inventory, "🏆 falls. The forest goes still." narrative + loot lines, clear combat fields, hand back to ExplorationController at the same km. Defeat: `ExplorationController.handleDeath(causeNarrative:)` (shared static helper — wipes non-equipped inventory, hp = 1, back to estate). The same controller also drives the **registration wolves fight** (step 4) — `CombatController` detects the registration context via `session.registrationStep < 6` and routes to `Registration.handleCombatEnd(won:)` instead of the exploration handoff; defeat / flee / `/start` are all soft retries with full HP, only victory advances to estate naming.

**Not started:** Artifact activation, crafting, pets, guilds, arena, market, territorial warfare, daily 2h passive budget, early-cancel button for in-flight passive, production-mode durations (flip `PassiveExpeditionService.testMode` to false when ready), content expansion (3.5 — more enemy tiers, richer event pool). Phase 4.2 deferrals (class-specific Defend/Flee mechanics, edit-in-place combat UX, XP grant on victory, per-enemy AI hooks, status effects like rabies) are tracked in `TODO.md`. Hunger drain is wired: walk-room drain + combat-round drain (passive) + per-action drain (active) + per-room starvation HP tick fire inside `ExplorationService.rollStep` / `CombatController` on every step (both active and passive simulation).

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
- If adding new controllers/models, update the file map in README.md's Project Structure section

### Git Workflow
- When a task is finished, ask user explicitly: "Task done. Commit?"
- On confirmation, generate a short compact commit message (no co-author line)
- **Never push.** Push operations are manual, user-side only.
- Stage only relevant files, never `git add -A`

### Code Conventions
- All controllers subclass `TGControllerBase`, mark `@unchecked Sendable`
- Handler return type: `async throws -> Bool`
- Callback handlers: `static` methods
- Register button text for ALL locales in `attachHandlers`
- Use `context.bot.sendMessage(session:text:...)` over `context.respond()` in controllers
- Follow existing file header format (Created by / Maintained by)
- New models need corresponding migrations
- Keep Telegram callback_data under 64 bytes
