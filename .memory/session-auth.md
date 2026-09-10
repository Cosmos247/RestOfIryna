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
`routerName`, the two fields that decide which keyboard the player is looking at).
`peek` deliberately does not insert, so a once-a-minute sweep cannot pin every
account in the cache forever.

## Authorization Flow

### In TGDispatcher (catch-all handler):
1. Extract `TGUser` entity from update (message.from / editedMessage.from / callbackQuery.from)
2. Check `allowedUsers.contains(entity.id)`
3. If unauthorized: send rejection message to user + notify owner (mitya)
4. If authorized: fetch/create session via cache, route to controller

### In GlobalCommandsController (per-handler):
Each handler independently checks `allowedUsers.contains(fromId.id)`

### Allowed Users (configure.swift):
```swift
let maxim: Int64 = 327887608
let basel: Int64 = 768795585
let mitya: Int64 = 398698463
let irina: Int64 = 1269829617
let allowedUsers: [Int64] = [maxim, basel, mitya, irina]
```

## New User Flow
1. First interaction -> `User._session(for:)` creates new user with `routerName = "registration"`
2. RegistrationController shows language selection (inline keyboard)
3. User picks language -> callback sets locale, changes `routerName` to "main"
4. MainController shows greeting with reply keyboard
