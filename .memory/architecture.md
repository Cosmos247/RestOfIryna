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

### Per-user dispatch serialization

`RouterStore.process` serializes updates per Telegram user via a token-keyed `Task` chain (`inflightByUser: [Int64: (token, Task)]`). Each call:
1. Reads the previous in-flight task for that user (if any).
2. Allocates a monotonic dispatch token, builds a fresh `Task` whose body awaits the previous task before calling the actual `dispatch(...)` helper.
3. Stores `(token, task)` under the user ID, then awaits its own task's value.
4. On completion the entry is cleared only if our token is still the latest (otherwise a later call already replaced it and is responsible).

Why: actor reentrancy means concurrent updates from the same Telegram user could otherwise interleave between awaits. Real symptom seen: spam-tapping "Step Forward" both rolled events at the same `stepsDeep` (duplicate loot, single vigor drain) because both dispatches read the same `ExplorationState` row before either had written. The chain forces tap N+1 to start only after tap N has fully written its mutations and refreshed `sessionCache`. Dispatches for *different* users still run concurrently — only same-user calls are serialized.

## Global State

- `appState: AppState!` — global, holds bot/db/lingo/logger/httpClient
- `store: RouterStore` — global actor, holds all registered routers
- `sessionCache: SessionCache` — global actor, in-memory user cache (5min TTL)
- `allowedUsers: [Int64]` — hardcoded authorized Telegram IDs
- In-memory stores (actors, not persisted; a restart drops their contents): `TradeStore` (live player-to-player trades + exchange lobby), `ArenaStore` (Arena lobby, challenges, live duels), `EphemeralChatState` (pending prompts, last status banner)

## Service Layer

Pure domain services live in `Swift/Services/`. They hold no state, do no DB writes, and mutate models in-place when needed. Callers (controllers) are responsible for persisting and for coordinating cross-entity flows.

Why: keeps game logic testable, swap-able, and cheap to compose. Same function can be invoked from a controller (player action), a dev command (`/drain`), a scheduled job (future), or a migration-time seeder without code duplication.

- `VigorService` (Phase 2.2) — drain per action, consume food/potion, compute starvation penalty on effective stats, apply per-room HP loss when starving.
- `CombatService` (Phase 4.1) — shared damage primitives. `applyAttack` returns hit/miss/crit; `chipDamage` returns the parry-counter chip for Defend. Both `ExplorationService.resolveAutobattle` (passive) and `CombatController` (active) call into the same primitives so a fight resolves with the same odds in either mode. Single source of truth for combat math; tuning constants (`baseHitChance`, `critMultiplier`, `defendChipFraction`, `varianceRange`) are exported so both consumers stay in sync. Active mode hands off via `StepOutcome.encounterStarted` — `ExplorationService.rollStep(mode:)` short-circuits the autobattle, the ExplorationController stamps `combat_enemy_id` / `combat_enemy_hp` on the expedition row, and CombatController takes over.
- `QuestService` (Phase 9.2) — the daily-quest loop. Reads a board in one call (`status`), ticks counters from gameplay hook sites (`record`), and pays out (`finish` → private `payOut`). Which job a player has today is *derived*, never stored: `QuestCatalog.daily` hashes `userId:npc:GameDay.stamp()` with FNV-1a and indexes the NPC's pool, so the assignment survives a restart with zero DB writes. Hook sites call `record` best-effort (`try?`) — a quest write must never break the fight, craft or sale it rides on.
- `ArenaService` / `ArenaStore` (Phase 8.3) — the split is deliberate: `ArenaStore` is an actor holding everything live (lobby presence, pending challenges, in-flight duels) and rolls the combat dice *inside* the actor so roll and HP mutation can't interleave; `ArenaService` owns the DB side (validation, Honor ELO, stake settlement) and the background sweeper. Nothing about a live duel is persisted — a restart cancels it.
- Both `CraftingService` and `EstateService`-shaped work now exist (`CraftingService`, `PlotService`, `EstateUpgradeService`).

## Concurrency Model

- Swift 6.2 strict concurrency
- `SessionCache` is an actor (thread-safe)
- `RouterStore` is an actor (thread-safe) **and** serializes dispatches per Telegram user via an internal token-keyed task chain — see the "Per-user dispatch serialization" section above for the why and the symptom it prevents.
- Controllers marked `@unchecked Sendable` (intentional — safe due to no mutable state)
- `Router` extended with `@unchecked Sendable` conformance
- `AppState` is `Sendable` with `nonisolated(unsafe)` for bot (set once during init)
