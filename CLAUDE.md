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
- `Swift/routes.swift` — `RouterStore` actor (router registry)
- `Swift/Controllers/` — Game screen controllers (Main, Registration, Settings, GlobalCommands, Inventory tree nav, Estate tree nav + expedition-guard, Exploration with mode picker + active + passive + report delivery; stub for Capital)
- `Swift/Models/User.swift` — User model (identity, class, nickname, estate, stats, gold, last_hp_tick_at) + effective-stat computed properties
- `Swift/Models/Item.swift` — static item catalog (ItemType / ItemEffect / EquipmentSlot / GearStats / Item / ItemCatalog) — code-based, not in DB
- `Swift/Models/InventoryEntry.swift` — Fluent model (user_id, item_id, quantity, equipped_slot) + add/remove/has/list/canAccept/slotsUsed helpers. Enforces a 50-slot cap on non-equipped rows (upgradable later via Workshop)
- `Swift/Models/WarehouseEntry.swift` — Fluent model for estate warehouse storage (separate table from inventory); add/list/totalQuantity helpers
- `Swift/Models/ExplorationState.swift` — Fluent model, one row per active or passive expedition (user_id unique, stepsDeep = current km, `visited_rooms` JSON dict of km → visit count, `mode` = active/passive, `ends_at`, `report_json`). Presence = exploring; absence = at estate. begin / beginPassive / current / end / allPassive / recordVisit / visitCount / isPassive / hasReadyReport / secondsRemaining helpers. Schema still has a dormant `returning` Bool column from an earlier 3.2 pass.
- `Swift/Models/Enemy.swift` — code-based bestiary (Enemy + EnemyLootDrop + EnemyCatalog). Phase 3.1 MVP: 3 tier-1 enemies (rabid hare / fox / wolf) with depth ranges and loot tables.
- `Swift/Migrations/` — CreateUser, AddCharacterFields, AddProfileStyle, AddGameStats, CreateInventory, RemoveCrownsField, AddEquipSlotToInventory, AddGearBonuses, CreateWarehouse, CreateExplorationState, AddExplorationReturnState, AddHpRegenTick, AddPassiveExpeditionFields
- `Swift/Services/` — Domain services. HungerService is pure (callers persist). EquipmentService owns the atomic slot swap and saves entries + user itself. WarehouseService transfers one unit at a time between inventory and warehouse (skips equipped rows on deposit; preflights inventory space on withdraw and returns a typed result enum). ExplorationService drives a single step: hunger drain + starvation HP tick + three-tier weighted event roll (keyed on prior visit count) + autobattle stub for encounters, returning a StepOutcome enum. HealingService.tick lazy-computes passive HP regen (5%·maxHp/min) while at estate; called from `RouterStore.process` on every interaction. PassiveExpeditionService owns the passive-mode flow — duration picker, `Task.detached` + **live per-step** scheduler (`runLive`, which sleeps until each step's absolute fire time and exits early on death so the report pushes immediately), progress tracked via `state.stepsDeep`, PassiveReport JSON blob, completion push via bot.sendMessage, and startup rescheduling (called from configure.swift after bot.start). Currently: HungerService, EquipmentService, WarehouseService, ExplorationService, HealingService, PassiveExpeditionService.
- `Swift/Telegram/Router/` — Router engine (command matching, content types, context, args)
- `Swift/Telegram/TGBot/` — TGDispatcher + HummingbirdTGClient
- `Swift/Helpers/` — TGControllerBase, SessionCache, Lingo extension, Env helper
- `Localizations/` — `en.json`, `uk.json` (~183 keys each)
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

## Current State (as of 2026-04-22)

**Working:** Lore-driven 6-step registration (Artanian welcome → name → class selection with descriptions → King's Oath with class-specific starter weapon grant, automatically equipped → wolf encounter on the road with class-specific artwork sent via `sendPhoto` + caption + Continue button; combat itself is a stub → estate naming). Equipment system: `EquipmentSlot` enum (8 slots), `GearStats` on Item, cached `gear_*_bonus` fields on User, `EquipmentService` for atomic equip/unequip with auto-swap of slot occupant; starter weapons grant +3 ATK (sword), +2 ATK/+1 ACC (bow), +2 ATK/+1 CRIT (staff). Effective stats (`effectiveAttack/Defense/Crit/Dodge/Accuracy` on User) = base + gear − hunger penalty. Main menu with 3-row keyboard (Explore + Inventory / Estate + Capital / Profile + Settings), character profile view (3 switchable styles via inline buttons + message editing, shows effective ATK/DEF and 😵 Starving indicator), settings, language switching, session caching, auth, localization (EN/UK), health endpoint. Inventory tree navigation: root always shows all 5 category buttons with live counts (empty categories show "(0)" and reply with a toast on tap); drill-down shows every item as its own inline button (future per-item description view) with a type-specific action button next to each row — 🍴 Eat / 🍷 Use (potion) / 🛡 Equip ↔ ❌ Unequip (gear) / ✨ Use (artifact). Gear rows carry a persistent per-item icon (⚔️ / 🏹 / 🪄 / 🦺 ...) via `Item.icon`, visible whether equipped or not. Food/potion consume via HungerService; gear equips/unequips via EquipmentService; artifacts still reply with "🚧 Not yet available" toast until their activation flow ships. Hunger service (pure): drain, consume, effective-stat penalty, starvation HP loss — callers wire in when Exploration/Combat ship. Backpack has a fixed 50-slot cap (1 row = 1 slot, equipped gear doesn't count) — enforced by `InventoryEntry.add` throwing `.inventoryFull`. `WarehouseService.withdraw` preflights space before moving. `InventoryController` header shows `X/50 slots`. Slot cap will be raised later via Workshop upgrades.

Dev-only commands restricted to mitya: `/grant <item_id> <qty>`, `/revoke <item_id> <qty>`, `/drain <amount>`. Dev inventory + warehouse seed on startup iterates `developerUsers` — each listed developer gets the same starter backpack and warehouse piles, with per-item top-up semantics (never reduces) and orphan cleanup for items no longer in the catalog. Dev profile reset flag (`resetDevProfile` in configure.swift, currently off so 3.2 return-path state can accumulate across restarts) also wipes inventory + warehouse for each developer when enabled, so registration-grants start clean.

**Exploration (Phase 3.1 MVP + 3.2 per-room visit decay + passive estate regen + 3.3 passive expedition MVP landed):** Tapping 🗺 Explore now opens a **mode picker** first — `[🏃 Розвідка]` (active) / `[🏕 Експедиція]` (passive) — whenever there's no live expedition. If a passive expedition is in flight, re-opening shows a countdown status. If the background scheduler already completed the simulation, re-opening delivers the report and clears the state.

**Active mode (3.1 + 3.2):** A dedicated reply keyboard `[🚶 Step fwd] [🔙 Step back]` / `[🎒 Bag]` replaces main nav for the expedition. Step Forward increments `stepsDeep` and fires `ExplorationService.rollStep` at the new km with the room's prior visit count; the service picks a three-tier weight table — tier 0 fresh (nothing 20 / loot 40 / encounter 30 / trip 10), tier 1 reduced (50/20/20/10), tier 2+ bare (100/0/0/0 — only .nothing / .starvationOnly fires). After the roll the room's counter is incremented. Walk-room hunger drain + per-step starvation HP tick fire on every step. Loot is added directly to inventory with a full-bag fallback. Encounters roll an enemy from `EnemyCatalog.pickFor(kmDepth:)` through a stub autobattle. Step Back at km ≥ 2 decrements + rolls; at km ≤ 1 it ends with a clean arrival. `/start` and stray Cancel presses force-end.

**Passive mode (3.3):** Duration picker → 30 / 60 / 90 units (in test mode = seconds, in prod = minutes via `PassiveExpeditionService.testMode` constant). `PassiveExpeditionService.start` creates an `ExplorationState` row with `mode = .passive` and `ends_at = now + duration`, then arms a `Task.detached` running `runLive` — the **live per-step simulator**. runLive loops over the scheduled steps (5 units per step): sleeps until each step's absolute fire time (`createdAt + K * stepDuration`), rolls one event via `ExplorationService.rollStep`, persists progress via `state.stepsDeep`, and either continues or **exits early on death** — in which case the report pushes immediately without waiting out the remaining timer. State persists the current step count so bot restart resumes at the right step (catch-up: any steps whose fire times fell during downtime run back-to-back with no sleep). Outcome counters + loot totals are NOT persisted between restarts (MVP tradeoff); a crash mid-expedition means the final report only reflects post-restart events. Final push: write `PassiveReport` JSON to `report_json`, send completion message with Close button, delete state on user's close tap. On bot restart, `PassiveExpeditionService.rescheduleInflight` (called from configure.swift after `bot.start`) spawns a fresh runLive task for each in-flight state. While the timer counts down, the governor is considered to be in the forest — HP regen is PAUSED and the Estate menu is LOCKED until the expedition ends.

**Shared plumbing:** While the player is at the estate and NOT on any expedition (active or passive), `HealingService.tick` lazy-computes passive HP regen — 5% of maxHp per minute — on every interaction via `RouterStore.process`. During any expedition regen is fully paused (governor is in the forest, not resting at the manor). `RouterStore` queries `ExplorationState.current` once per dispatch and passes the presence as an `inExpedition` flag to `HealingService`.

**Mode exclusivity (3.4):** The Explore button label is static — no dynamic keyboard swaps (tried briefly but Telegram's reply-keyboard update semantics made it fragile). Gating happens at controller entry: tapping Explore while an expedition exists routes to `showExploration`, which shows either the active resume view or a passive countdown ("Expected return: MM:SS. Your governor is already on expedition 🏕."). Both **Estate** (`EstateController.showEstate`) and **Capital** (`CapitalController.showStub`) are locked during any expedition — each owns its `routerName` transition so the guard returns cleanly without leaving the player inside a "blocked" controller. Idempotency guards on the `explore:mode:active` / `explore:mode:passive` / `explore:dur:*` callbacks re-check `ExplorationState.current` before mutating state, so a stale picker tap can't silently overwrite an existing expedition. Three `.nothing` narrative variants render based on prior visit count: `exploration.outcome.nothing` / `.revisited` / `.bare`. Bag button (active mode only) shows a scoped inline view of food+potions. Death wipes every non-equipped `InventoryEntry` row, respawns at HP=1 (hunger preserved).

**Callback forwarding:** Inline buttons sent from background tasks (the scheduler-pushed passive report's "Close") can arrive while the player's `routerName` is `main` / `inventory` / `settings`. Each of those controllers' `onCallbackQuery` forwards any `explore:*`-prefixed data to `ExplorationController.onCallbackQuery` before falling through to its own logic, so the full state-cleanup + "back at the estate" greeting runs regardless of where the player is when they tap Close.

**Stubbed (coming-soon placeholders wired into the router):** Capital — shows a localized "coming soon" message and a back button. Estate now has a real skeleton controller (Phase 5 scaffolding) — tree nav with Root → House / Plot (Plot stub); inside House, Workshop and Kitchen are stubs but Warehouse is a real deposit/withdraw surface backed by the separate `warehouse` table. Category root shows live counts per item type. Drill-down renders two layouts:
  - Stackable types (food / material / potion / artifact): one aggregated row per item_id — `[Name] [🎒 N ⬆️] [📦 M ⬇️]`. Tap ⬆️ to deposit one unit, ⬇️ to withdraw one.
  - Gear (non-stackable): one row per physical unit — `[Name] [🎒 ⬆️]` for rows in the backpack, `[Name] [📦 ⬇️]` for rows in the warehouse. No `× N` aggregation since gear is always 1-per-row.
  Equipped gear is excluded from the inventory side of the transfer view (can't warehouse what you're wearing). Transfers go through `WarehouseService.deposit` / `.withdraw` — one unit per tap, atomic move between `InventoryEntry` and `WarehouseEntry`. The same per-row pattern applies in `InventoryController.gearRows`. Per-level artwork loaded from `Assets/estate/level_<N>.jpg` when the file exists.

Estate level is derived from `user.level` via `User.estateLevel` (every 5 player levels → +1 estate tier).

**Not started:** Real combat UI (Phase 4 replaces the exploration autobattle stub), artifact activation, crafting, pets, guilds, arena, market, territorial warfare, daily 2h passive budget, early-cancel button for in-flight passive, production-mode durations (flip `PassiveExpeditionService.testMode` to false when ready), content expansion (3.5 — more enemy tiers, richer event pool). Hunger drain is wired: walk-room drain + combat-round drain + per-room starvation HP tick fire inside `ExplorationService.rollStep` on every step (both active and passive simulation).

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
