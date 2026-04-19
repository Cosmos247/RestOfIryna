# Session History

## Session 1 — 2026-04-17 (Initial Setup)

### What was done:
- Full codebase analysis (all Swift files, Package.swift, localizations, .env)
- GDD.md and README.md deep review
- Online research: swift-telegram-sdk, Hummingbird 2.x, Fluent standalone, Lingo 4.x
- Created `.memory/` project-scoped memory system with index and 8 knowledge files
- Created `CLAUDE.md` — AI assistant instructions and project reference
- Created `TODO.md` — phased progress tracker with status markers
- Created `Prompt.me` — new-session compact primer

### Key findings:
- Project has solid infrastructure: routing, auth, sessions, localization all working
- Only 3 controllers implemented (Registration, Main, Settings) + GlobalCommands
- User model is minimal (no game stats, inventory, etc.)
- No game mechanics implemented yet — entire GDD is planned/future work
- Localization has ~24 keys per locale (EN + UK)
- Auth is hardcoded to 4 Telegram IDs

### Architecture assessment:
- Router-controller pattern is clean and extensible
- Session cache is well-implemented (actor, TTL, auto-cleanup)
- Code quality is high, Swift 6.2 concurrency compliance is good
- Main scaling concern: global mutable state (appState, store, sessionCache)

## Session 2 — 2026-04-18 (Registration Rework + Profile)

### What was done:
- Multi-step registration: language -> nickname (2-20 chars) -> class (warrior/archer/mage) -> estate name (2-30 chars)
- CharacterClass enum in configure.swift with icons
- User model expanded: nickname, characterClass, estateName, registrationStep, profileStyle
- Two new migrations: AddCharacterFields, AddProfileStyle
- Profile view in MainController with 3 switchable visual styles (inline buttons, message editing)
- Profile button added to main menu keyboard
- Dev profile reset flag (resetDevProfile) for testing registration flow
- Fixed: migrator calls now properly awaited (try await .get())
- Fixed: databases.shutdown() in defer to prevent ConnectionPool assertion
- Replaced dead onCancel with showCurrentStep for better UX on unexpected input during registration
- ~28 new localization keys per locale (registration flow + profile stats)

### Bugs fixed:
- ConnectionPool.shutdown() assertion on app exit — added defer with DispatchQueue.global()
- Migration not running (profile_style column missing) — changed `_ = migrator.prepareBatch()` to `try await migrator.prepareBatch().get()`
- Duplicate greeting after registration — merged completion message into showMainMenu text param

### Game stats addition (same session):
- AddGameStats migration: 13 fields (level, xp, hp, maxHp, hunger, maxHunger, attack, defense, crit, dodge, accuracy, gold, crowns)
- User.applyStartingStats(for:) method — sets class-specific stats at registration
- CharacterClass.startingStats computed property (warrior: hp120/def12, archer: atk14/crit10/acc14, mage: atk15/crit12/hp80)
- Profile rendering now reads real User fields instead of hardcoded placeholders
- XP curve: level * 100
- Dev reset updated to clear all stat fields

## Session 3 — 2026-04-19 (Main-menu navigation scaffold)

### What was done:
- Added three new Commands enum cases: `explore`, `estate`, `capital`
- Created three stub controllers: ExplorationController, EstateController, CapitalController (all identical shape — show "coming soon" + back-to-main)
- Registered new controllers in AllControllers.swift (routerNames: exploration / estate / capital)
- MainController keyboard reshaped to 3 rows: [Explore] / [Estate, Capital] / [Profile, Settings]
- MainController handlers (onExplore/onEstate/onCapital) transition user to the matching stub router
- Added 4 new localization keys per locale: commands.explore/estate/capital + stub.coming_soon (EN + UK)
- Build green (Swift 6.2, only pre-existing `crowns` unused-var warning)

### User decisions captured in project memory:
- Phase 1.2 tutorial/onboarding deferred until game lore is finalized
- Phase 1.3 main-menu character status line skipped — stats remain in Profile view only

## Session 4 — 2026-04-19 (Inventory data layer, Phase 2.1)

### What was done:
- Designed Item model as a code-based catalog (not a DB table) — `Swift/Models/Item.swift`
  - `ItemType` enum: food / material / gear / potion / recipe / artifact
  - `ItemEffect` enum with associated values: `.restoreHunger(Int)` / `.restoreHP(Int)` (extendable)
  - `Item` struct: id, nameKey, type, tier, stackable, effects
  - `ItemCatalog` with 14 seed items spanning all types, plus `find(id)` + `items(of:type)` lookup
- Created `InventoryEntry` Fluent model — one row per stack (user_id FK cascade, item_id, quantity, timestamps)
- CreateInventory migration (indexed FK, no unique constraint; non-stackable gear gets one row per unit)
- Inventory helpers as static methods: `add`, `remove` (returns false if insufficient), `has`, `totalQuantity`, `list`
- 14 new localization keys per locale for seed item display names (EN + UK)
- Build green (Swift 6.2, only pre-existing `crowns` warning)

### Architectural decisions:
- Item catalog in code (not DB): chosen for type-safe effects, compile-time safety, and because GDD expects a bounded set (~50–200 items) with diverse effect shapes. Trade-off: adding an item requires a deploy.
- Normalized `inventory` table (not JSON blob on User): needed for future market / guild vault / trade / quest-prereq queries.
- No unique constraint on (user_id, item_id): gear is non-stackable, would need per-instance rows. Stacking is enforced by helper logic instead.

### Inventory nav button + real viewer (same session):
- Added `Commands.inventory` case + main-menu keyboard reshape: row 1 is now 🗺 Explore | 🎒 Inventory
- `InventoryController` is a real read-only viewer (not a stub): loads `InventoryEntry.list()`, groups by `ItemType` with icons (🍖🪨🧪🗡📜💎), shows empty-state when bag is empty
- Added `ItemType.icon` property
- Dev command `/grant <item_id> <quantity>` registered on TGDispatcher via GlobalCommandsController — restricted to mitya only; validates item exists, uses existing `InventoryEntry.add` helper
- Dev inventory seed in configure.swift: mitya-only, idempotent (skips when inventory non-empty); controlled by `seedDevInventory` flag (default true). Seeds: bread×3, stew×1, wood×5, stone×3, heal_small×2, rusty_sword×1, recipe.stew×1
- 12 new localization keys per locale: inventory.title/empty, inventory.type.* (6), grant.usage/unknown_item/success

### Crowns removal (same session):
- Removed `crowns` field from User model, init, dev reset, MainController profile rendering
- Dropped `profile.crowns` localization key (EN + UK)
- New migration `RemoveCrownsField` drops the `crowns` column from `users` (the original AddGameStats migration is untouched — it's already applied)
- Motivation: user hasn't decided on the final premium-currency name yet; removing avoids stale references. Concept remains in GDD as "premium currency (name TBD)". When a name is picked, a new AddX migration will reintroduce the column.
- Build clean — previous pre-existing `crowns` unused-var warning is gone too
