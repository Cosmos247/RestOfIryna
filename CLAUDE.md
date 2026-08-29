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
| `Prompt.md` | Compact session primer — read this at session start |
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

Game code lives in `Swift/` (not `Sources/`). The content pipeline lives in `Modules/`
(also not `Sources/` — a `Sources/` directory would contradict the rule above).

```
Modules/
├── ROIContent/          # Foundation-only: content DTOs, loader, validator, live snapshot
├── ROISim/              # Pure balance math + deterministic RNG (simulator)
└── roi-content/         # CLI: `swift run roi-content validate [--strict]`
Tests/ROIContentTests/   # Fast tests — no Fluent/Postgres/Telegram in this graph
```

`Swift/configure.swift` carries `@_exported import ROIContent` / `ROISim`, so files under
`Swift/` use those types without their own import line.


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

**Gendered text (uk feminitives):** Ukrainian strings that address the player with a gendered word (past-tense `-в/-ла`, adjective, or намісник/-иця) use the gender-aware overload — `lingo.localize("key", gender: session.gender, locale: ..., interpolations: ...)`. It looks up `key.m`/`key.f` for `uk` and the plain `key` for English (so **never duplicate English** — only `uk.json` gets `.m`/`.f`). Player gender (`User.gender`, "m"/"f", nil=male) is chosen at registration step 1. When adding new player-facing uk copy with a gendered word, either add `.m`/`.f` + route through this overload, or phrase it neutrally (impersonal/plural/passive). Full key list + rationale in `.memory/localization.md`.

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
- For uk strings that address the player with a gendered word, follow the gendered-text rule (see Localization above): `.m`/`.f` in `uk.json` + the `gender:` overload, or neutral phrasing
- Keep `uk.json` free of English game-stat tokens / loot slang — use the UA glossary (`ОЗ`, `Досвід`/`досвіду`, `Снага`, `АТК`, `ЗАХ`, `здобич`); English tokens (HP/XP/ATK/DEF/Vigor) stay only in `en.json`. Full table in `.memory/localization.md`.
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
- Never interpolate an Optional directly into a player-facing string (`"\(item.icon)"` prints `Optional("🪖")`) — unwrap it (`item.icon.map { "\($0) " } ?? ""`). A clean build won't catch this; verify new strings actually render. (Same vigilance as the Lingo emoji-before-`%{}` rule in `.memory/localization.md`.)
