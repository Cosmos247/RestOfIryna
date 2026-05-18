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
| `GDD.md` | Full game design — classes, vigor, exploration, combat, estates, economy |
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

```
Swift/
├── entrypoint.swift     # @main, calls configure()
├── configure.swift      # Bootstrap: DB, Lingo, Bot, Hummingbird (projectPath read from `ROI_PROJECT_PATH` env with dev-Mac fallback)
├── routes.swift         # RouterStore actor + per-user dispatch serialization
├── Controllers/         # Game screen controllers
├── Models/              # Fluent models + code-based catalogs (Item, Enemy, Recipe, …)
├── Migrations/          # DB migrations
├── Services/            # Domain services (pure where possible)
├── Telegram/            # Router engine + TG client
└── Helpers/             # TGControllerBase, SessionCache, Lingo ext, env, EphemeralChatState
```

Per-file annotations: `.memory/file-map.md` (canonical, updated per session).

`Localizations/` — `en.json`, `uk.json`. `Assets/` — registration artwork + per-level estate art. `content/` — game-content reference docs (bestiary, recipes).

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

### Scenery photos (capital / estate / future location backdrops)
Always use `sendScenicPhoto(...)` from `Swift/Helpers/PhotoCache.swift` — never call `bot.sendPhoto` directly for player-visible location art. The helper does two things:
- **file_id cache** — first send uploads the JPG bytes, captures Telegram's returned `file_id`, every later send reuses the id (no repeated upload).
- **Scenery slot cleanup** — tracks the user's most recent scenery photo in `EphemeralChatState.lastSceneryPhotoId` and deletes it before sending a new one, so chat never accumulates duplicate location backdrops.
```swift
_ = try await sendScenicPhoto(
    assetPath: "\(projectPath)/Assets/capital/<id>.jpg",
    caption: text,
    replyMarkup: .inlineKeyboardMarkup(keyboard),
    toUser: context.session,
    bot: context.bot
)
```
For one-off narrative art that must stay in chat history (registration King's Oath, lore beats), call `bot.sendPhoto` directly — those don't share the scenery slot.

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
