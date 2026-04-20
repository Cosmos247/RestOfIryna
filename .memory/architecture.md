# Architecture Overview

## App Lifecycle

1. `entrypoint.swift` — `@main enum Entrypoint` calls `configure(logger:)`
2. `configure.swift` — Orchestrates everything:
   - Loads `.env` via SwiftDotenv (hardcoded path: `/Users/cosmos/RestOfIryna`)
   - Configures Fluent + PostgreSQL (via `SQLPostgresConfiguration`)
   - Runs migrations via `Migrator`
   - Initializes Lingo from `Localizations/` directory
   - Creates `HTTPClient` (AsyncHTTPClient)
   - Builds `AppState` (global singleton holding db, lingo, logger, httpClient, bot)
   - Creates `TGBot` with long polling + `HummingbirdTGClient`
   - Creates `TGDispatcher` (subclass of `TGDefaultDispatcher`) and adds it to bot
   - Calls `Controllers.attachAllHandlers()` to register all controller routers
   - Starts the bot (`bot.start()`)
   - Notifies admin users that bot started
   - Starts Hummingbird HTTP server on port 8080 (just a `/health` endpoint)

## Dispatcher Chain (update processing order)

```
TGUpdate arrives via long polling
  -> TGDispatcher.process() iterates handlers in order:
     1. TGCommandHandler("/help")    -> GlobalCommandsController.handleHelp
     2. TGCommandHandler("/settings") -> GlobalCommandsController.handleSettings
     3. TGCommandHandler("/buttons")  -> GlobalCommandsController.handleButtons
     4. TGBaseHandler (catch-all)     -> Auth check -> SessionCache -> RouterStore.process()
        -> Routes to controller based on user's `routerName` field
```

## Router-Controller Pattern

- `RouterStore` (actor in `routes.swift`) — holds `[String: Router]` map
- Each controller registers its Router under its `routerName` key
- When an update arrives, `TGDispatcher` fetches user session, reads `routerName`, calls `store.process(key:)`
- The Router matches the update against registered paths (commands, text, callbacks)
- Controllers transition between each other by setting `session.routerName` and saving

## Global State

- `appState: AppState!` — global, holds bot/db/lingo/logger/httpClient
- `store: RouterStore` — global actor, holds all registered routers
- `sessionCache: SessionCache` — global actor, in-memory user cache (5min TTL)
- `allowedUsers: [Int64]` — hardcoded authorized Telegram IDs

## Service Layer

Pure domain services live in `Swift/Services/`. They hold no state, do no DB writes, and mutate models in-place when needed. Callers (controllers) are responsible for persisting and for coordinating cross-entity flows.

Why: keeps game logic testable, swap-able, and cheap to compose. Same function can be invoked from a controller (player action), a dev command (`/drain`), a scheduled job (future), or a migration-time seeder without code duplication.

- `HungerService` (Phase 2.2) — drain per action, consume food/potion, compute starvation penalty on effective stats, apply per-room HP loss when starving.
- Future: `ExplorationService`, `CombatService`, `CraftingService`, `EstateService`.

## Concurrency Model

- Swift 6.2 strict concurrency
- `SessionCache` is an actor (thread-safe)
- `RouterStore` is an actor (thread-safe)
- Controllers marked `@unchecked Sendable` (intentional — safe due to no mutable state)
- `Router` extended with `@unchecked Sendable` conformance
- `AppState` is `Sendable` with `nonisolated(unsafe)` for bot (set once during init)
