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
| AsyncHTTPClient | 1.31.1+ (resolved 1.33.1) | HTTP client for Telegram API calls |
| swift-telegram-sdk | 4.6.0+ (resolved 4.6.0; its rate limiter is OFF, see below) | Telegram Bot API wrapper (TGBot actor, dispatchers, handlers) |
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
- Rate limits: the SDK ships its own limiter, 5 req/s for long polling and 30 req/s for webhook
  — **turned OFF here since 2026-10-08** (`apiRequestLimitLongPolling: nil` in `configure`).
  `TGBot.tgClient` (read by EVERY API call, `getUpdates` included) passes through
  `LimiterAsync`, whose ticker stops with the count at the maximum when its last tick releases
  exactly `maxRequests` waiters; every later call then parks forever — no socket, no error, the
  process `online`. A burst of 10 requests reproduces it; a restart's update backlog is such a
  burst. It froze the bot four times on 2026-10-08. Re-run that burst test before turning it on
  again or upgrading the SDK. Telegram's own limits answer an excess with a 429 instead.

### AsyncHTTPClient (the Telegram client)
- One `HTTPClient` (`configure`), used only by `HummingbirdTGClient`.
- **`.http1Only`, connect 10 s / read 60 s** since 2026-10-08. The 125 `StreamClosed` errors
  logged since 2026-09-09 are all HTTP/2 streams cancelled under a request (each a failed
  redraw); HTTP/1.1 was the first suspect for the freezes and was cleared, but it stays — it is
  harmless, and the read timeout bounds a request on a dead connection (the long-poll holds 10 s).
- `HummingbirdTGClient.post` stamps every completed `getUpdates` for `PollWatchdog`, which exits
  the process after 120 s without one so pm2 restarts it (`CLAUDE.md` → Running the bot).

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
