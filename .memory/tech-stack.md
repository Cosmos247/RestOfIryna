# Tech Stack

## Language & Tooling
- **Swift 6.2** (strict concurrency, `ExistentialAny` upcoming feature enabled)
- **macOS 14+** deployment target
- **Package.swift** — five targets:
  - `RestOfIryna` (executable) path `Swift/` — the bot
  - `ROIContent` (library) path `Modules/ROIContent` — Foundation only
  - `ROISim` (library) path `Modules/ROISim`
  - `roi-content` (executable) path `Modules/roi-content` — content CLI
  - `ROIContentTests` path `Tests/ROIContentTests`
  Never `Sources/` — game code is `Swift/`, pipeline code is `Modules/`.
- `Synchronization.Mutex` is **not** usable (macOS 15; package targets 14) — the
  content snapshots use `nonisolated(unsafe)` + `NSLock`.

## Dependencies (from Package.swift)

| Package | Version | Role |
|---------|---------|------|
| Hummingbird | 2.22.0+ | HTTP server (only serves `/health` endpoint) |
| Fluent | 4.13.0+ | ORM framework (model definitions, queries) |
| FluentPostgresDriver | 2.12.0+ | PostgreSQL driver for Fluent |
| swift-nio | 2.98.0+ | NIO event loop groups (used for Fluent + HTTPClient) |
| AsyncHTTPClient | 1.31.1+ | HTTP client for Telegram API calls |
| swift-telegram-sdk | 4.6.0+ | Telegram Bot API wrapper (TGBot actor, dispatchers, handlers) |
| swift-dotenv | 2.1.0+ | `.env` file loading |
| Lingo | 4.0.0+ | i18n/localization from JSON files |

## Key SDK Details

### swift-telegram-sdk
- `TGBot` is an actor — thread-safe
- Connection via `.longpolling()` — polls `getUpdates` in a loop
- `TGDefaultDispatcher` — must subclass and override `handle()` to register handlers
- `TGBaseHandler` — fires for every update (catch-all)
- `TGCommandHandler` — fires for specific `/command` entities
- `TGClientPrtcl` — protocol for HTTP backend (project implements `HummingbirdTGClient`)
- Rate limits: 5 req/s for long polling, 30 req/s for webhook

### Hummingbird 2.x
- Lightweight HTTP framework (no built-in ORM, auth, etc.)
- Built on Swift structured concurrency
- `Application(router:)` + `app.run()`
- Used here purely as health-check HTTP server alongside the bot

### Fluent (standalone, no Vapor)
- Uses `Databases`, `Migrations`, `Migrator` directly (not through Vapor's `Application`)
- Models use `@ID`, `@Field`, `@Timestamp` property wrappers
- Database operations via `Database` protocol
- PostgreSQL **15** — the Pi's native cluster on port 5433, which is what production and the dev Mac (over an SSH tunnel) both talk to. A `postgres:16-alpine` Docker container also runs on the Pi but belongs to a DIFFERENT project; connecting there fails with `role "ArtaniaAdmin" does not exist`, i.e. right host, wrong server

### Lingo 4.x
- JSON locale files in `Localizations/` directory
- `%{variable-name}` interpolation syntax
- Fallback to default locale ("en")
- `@preconcurrency import Lingo` needed (not yet fully Sendable)
