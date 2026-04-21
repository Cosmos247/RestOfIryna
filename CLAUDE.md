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
- `Swift/Controllers/` — Game screen controllers (Main, Registration, Settings, GlobalCommands, Inventory tree nav, Estate tree nav; stubs for Exploration/Capital)
- `Swift/Models/User.swift` — User model (identity, class, nickname, estate, stats, gold) + effective-stat computed properties
- `Swift/Models/Item.swift` — static item catalog (ItemType / ItemEffect / EquipmentSlot / GearStats / Item / ItemCatalog) — code-based, not in DB
- `Swift/Models/InventoryEntry.swift` — Fluent model (user_id, item_id, quantity) + add/remove/has/list helpers
- `Swift/Models/WarehouseEntry.swift` — Fluent model for estate warehouse storage (separate table from inventory); add/list/totalQuantity helpers
- `Swift/Migrations/` — CreateUser, AddCharacterFields, AddProfileStyle, AddGameStats, CreateInventory, RemoveCrownsField, AddEquipSlotToInventory, AddGearBonuses, CreateWarehouse
- `Swift/Services/` — Domain services. HungerService is pure (callers persist). EquipmentService owns the atomic slot swap and saves entries + user itself. WarehouseService transfers one unit at a time between inventory and warehouse (skips equipped rows on deposit). Currently: HungerService, EquipmentService, WarehouseService.
- `Swift/Telegram/Router/` — Router engine (command matching, content types, context, args)
- `Swift/Telegram/TGBot/` — TGDispatcher + HummingbirdTGClient
- `Swift/Helpers/` — TGControllerBase, SessionCache, Lingo extension, Env helper
- `Localizations/` — `en.json`, `uk.json` (~128 keys each)
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

## Current State (as of 2026-04-21)

**Working:** Lore-driven 6-step registration (Artanian welcome → name → class selection with descriptions → King's Oath with class-specific starter weapon grant, automatically equipped → wolf encounter on the road with class-specific artwork sent via `sendPhoto` + caption + Continue button; combat itself is a stub → estate naming). Equipment system: `EquipmentSlot` enum (8 slots), `GearStats` on Item, cached `gear_*_bonus` fields on User, `EquipmentService` for atomic equip/unequip with auto-swap of slot occupant; starter weapons grant +3 ATK (sword), +2 ATK/+1 ACC (bow), +2 ATK/+1 CRIT (staff). Effective stats (`effectiveAttack/Defense/Crit/Dodge/Accuracy` on User) = base + gear − hunger penalty. Main menu with 3-row keyboard (Explore + Inventory / Estate + Capital / Profile + Settings), character profile view (3 switchable styles via inline buttons + message editing, shows effective ATK/DEF and 😵 Starving indicator), settings, language switching, session caching, auth, localization (EN/UK), health endpoint. Inventory tree navigation: root always shows all 5 category buttons with live counts (empty categories show "(0)" and reply with a toast on tap); drill-down shows every item as its own inline button (future per-item description view) with a type-specific action button next to each row — 🍴 Eat / 🍷 Use (potion) / 🛡 Equip ↔ ❌ Unequip (gear) / ✨ Use (artifact). Gear rows carry a persistent per-item icon (⚔️ / 🏹 / 🪄 / 🦺 ...) via `Item.icon`, visible whether equipped or not. Food/potion consume via HungerService; gear equips/unequips via EquipmentService; artifacts still reply with "🚧 Not yet available" toast until their activation flow ships. Hunger service (pure): drain, consume, effective-stat penalty, starvation HP loss — callers wire in when Exploration/Combat ship. Dev-only commands restricted to mitya: `/grant <item_id> <qty>`, `/revoke <item_id> <qty>`, `/drain <amount>`. Dev inventory + warehouse seed on startup iterates `developerUsers` — each listed developer gets the same starter backpack and warehouse piles, with per-item top-up semantics (never reduces) and orphan cleanup for items no longer in the catalog. Dev profile reset flag (currently on for testing) applies to the same list and also wipes inventory + warehouse so registration-grants start clean.

**Stubbed (coming-soon placeholders wired into the router):** Exploration, Capital — each has its own controller that shows a localized "coming soon" message and a back button. Estate now has a real skeleton controller (Phase 5 scaffolding) — tree nav with Root → House / Plot (Plot stub); inside House, Workshop and Kitchen are stubs but Warehouse is a real deposit/withdraw surface backed by the separate `warehouse` table. Category root shows live counts per item type. Drill-down renders two layouts:
  - Stackable types (food / material / potion / artifact): one aggregated row per item_id — `[Name] [🎒 N ⬆️] [📦 M ⬇️]`. Tap ⬆️ to deposit one unit, ⬇️ to withdraw one.
  - Gear (non-stackable): one row per physical unit — `[Name] [🎒 ⬆️]` for rows in the backpack, `[Name] [📦 ⬇️]` for rows in the warehouse. No `× N` aggregation since gear is always 1-per-row.
  Equipped gear is excluded from the inventory side of the transfer view (can't warehouse what you're wearing). Transfers go through `WarehouseService.deposit` / `.withdraw` — one unit per tap, atomic move between `InventoryEntry` and `WarehouseEntry`. The same per-row pattern applies in `InventoryController.gearRows`. Per-level artwork loaded from `Assets/estate/level_<N>.jpg` when the file exists.

Estate level is derived from `user.level` via `User.estateLevel` (every 5 player levels → +1 estate tier).

**Not started:** Combat, artifact activation, crafting, pets, guilds, arena, market, territorial warfare. The hunger system is implemented as a pure service but its drain/starvation hooks are not yet invoked — they wait for Exploration (room transitions) and Combat (rounds).

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
