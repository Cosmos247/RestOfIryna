# Session & Authorization

## User Model (Swift/Models/User.swift)

Fluent model mapped to `users` table:

| Field | Type | Notes |
|-------|------|-------|
| id | UUID | Primary key (auto) |
| telegram_id | Int64 | Unique, required |
| router_name | String | Current controller state, default "main" |
| locale | String | "en" or "uk" |
| user_name | String? | Telegram username |
| first_name | String? | Telegram first name |
| last_name | String? | Telegram last name |
| created_at | Date? | Auto-set on create |

### Name Resolution
`user.name` computed property: firstName+lastName > firstName > lastName > userName > "User"

### Session Lifecycle
```
User._session(for: tgUser, db:)  // Find by telegram_id or create new
User.cachedSession(for:db:)       // Cache-first lookup
user.saveAndCache(in: db)         // Persist + update cache
user.invalidateCache()            // Drop from cache
```

## Session Cache (Swift/Helpers/SessionCache.swift)

- Actor-isolated `SessionCache`
- Key: `Int64` (telegram_id) -> `CachedSession` (user + expiration)
- TTL: 300 seconds (5 minutes)
- Auto-cleanup every 60 seconds via background Task
- Global instance: `sessionCache`

### Background writers must take the cached instance

`saveAndCache` INSTALLS the object it saved as the next tap's session, and Fluent
saves whole rows — so a background task holding its own freshly-loaded copy does not
merely miss the tap the player made a second ago, it publishes the pre-tap row back
over it. Anything writing a `User` outside a dispatch takes
`sessionCache.peek(telegramId:)` first and falls back to its own row:
`RestNotificationService` (since 2026-09-09), `TravelService` and
`PassiveExpeditionService` (since 2026-09-10 — arrival writes `location` and
`routerName`, the two fields that decide which keyboard the player is looking at), and
`ArenaService.settle` (since 2026-10-03). A duel can end on the other fighter's tap or on the
round clock, and `/start` mid-duel saves the session straight after settling. Settlement
loaded its own copies until then, which put the pre-settlement silver and HP back in the cache.
`peek` deliberately does not insert, so a once-a-minute sweep cannot pin every
account in the cache forever.

The watchman's fourth question (2026-10-04, a task turned ready) writes no `User` at all. Its
markers live on the progress rows (`quest_progress.ready_notified`,
`king_progress.ready_notified_index`) and go by a one-column `query…set…update`, never a row save,
because the player may be ticking the same row's progress at that moment.

## Authorization Flow — invite-only, in the database (since 2026-09-08)

**The hardcoded `allowedUsers` array is gone.** Access lives in the `allowed_users` table
(`AllowedUser` / `CreateAllowedUsers`), read through `AccessControl`, an actor cache whose
MISS queries the database — so a row added by hand in SQL takes effect on that account's
next message rather than at the next restart.

### In TGDispatcher (catch-all handler):
1. Extract `TGUser` entity from update (message.from / editedMessage.from / callbackQuery.from)
2. `await accessControl.isAllowed(entity.id, on: db)` — **ahead of routing**, so a refused
   stranger never gets a `User` row at all
3. If unauthorized: `redeemInvite` accepts a 16-letter `InviteToken`, either as a `/start`
   payload or pasted as a bare message; a valid one inserts the row and opens registration.
   **With the door open** (`ROI_OPEN_ACCESS=1` in `.env`, read at boot into
   `appState.openAccess`, 2026-10-07 — the public test) `admitThroughOpenDoor` inserts the
   row with source `open` instead, says nothing, and lets the update on into registration;
   the owner gets one silent `[ACCESS] … entered through the open door.` per newcomer.
   Closing the door (remove the line, restart) keeps everyone who has a row
4. If authorized: fetch/create session via cache, route to controller

### In GlobalCommandsController (per-handler):
Each handler still checks independently — `guard await accessControl.isAllowed(fromId.id, on: db)`
for player commands, and `guard developerUsers.contains(fromId.id)` for the three dev-only
ones (`/link`, `/reload`, `/content`).

### The two lists still in `configure.swift`:
```swift
let foundingUsers: [Int64]  = [mitya, irina, maxim, basel]  // seed list for the migration ONLY
let developerUsers: [Int64] = [mitya]                       // allowed BEFORE the table is read
```
`developerUsers` is the brake against locking yourself out of your own bot: `AccessControl`
returns true for it before the table is read at all. `allowed_users` is in
`WipeForRebalance.preserved` — a wipe resets the game, not the guest list.

To admit a new tester, use **`/link`** — never a code edit. To admit everyone, open the
door in `.env` and restart — also never a code edit. Token design and the three
decisions behind it: auto-memory `invite-only-access`.

## New User Flow
1. First interaction -> `User._session(for:)` creates new user with `routerName = "registration"`
2. RegistrationController shows language selection (inline keyboard)
3. User picks language -> callback sets locale, changes `routerName` to "main"
4. MainController shows greeting with reply keyboard
