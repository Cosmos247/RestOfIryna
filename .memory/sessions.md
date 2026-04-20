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

## Session 5 — 2026-04-20 (Hunger system, Phase 2.2)

### Architectural decisions:
- Stats in DB are BASE values. Effective stats (after hunger / future gear / buffs) are computed via `user.effectiveAttack` / `user.effectiveDefense` computed properties. Callers (combat, UI) read effective values. Gear bonuses (Phase 2.3) and pet buffs layer into the same extension.
- Service layer introduced in `Swift/Services/`. `HungerService` is pure — no DB writes, no actor state. Mutates user in-place when drain/consume are called; caller persists. This pattern will be reused by future services (Exploration, Combat, Crafting).
- Drain hooks are written now but not yet wired, because Exploration (room transitions) and Combat (rounds) don't exist yet. `HungerService.drain(user, action:)` is ready to be called from those when they ship.

### What was done:
- New `Swift/Services/HungerService.swift`:
  - `HungerAction` enum (walkRoom / walkRoomDoubleSpeed / combatRound / idle) with tunable cost constants (⚙️ TBD, GDD values)
  - `drain(user, action:)` and `drain(user, amount:)` — clamp to 0
  - `isStarving(user)` — hunger <= 0
  - `consume(item, user) -> ConsumeResult?` — applies `restoreHunger` / `restoreHP` effects, returns nil if fully wasted (rejects consumption)
  - `applyStarvationHPLoss(user) -> Int` — 5% max HP lost per room when starving (callers invoke per room)
  - `isConsumable(item)` — true for food / potion
  - Constants: `drainWalkRoom=2`, `drainWalkRoomDoubleSpeed=4`, `drainCombatRound=1`, `starvationStatPenalty=0.25`, `starvationHPDrainPercent=0.05`
- User extension: `effectiveAttack`, `effectiveDefense` apply `-starvationStatPenalty` when starving (clamped to min 1)
- `InventoryController` — single-message tree navigation:
  - Root view: "🎒 Inventory" + category buttons for ALL 5 item types (2 per row, e.g. `🍖 Food (4)` · `💎 Artifacts (0)`). Empty categories show count (0) and reply with a toast "You have no items in this category" on tap instead of opening an empty drill-down. No Close button — player navigates away via main's reply keyboard, which stays visible throughout the inventory session.
  - Category drill-down: every item is its own inline button (future-proofed — tapping will show per-item description). For all categories except Materials, each row is `[Item × N] [action]`; the action button label/emoji is type-specific via `ItemType.actionKey` → `inventory.action.<type>`: 🍴 Eat / 🍷 Use / 🛡 Equip / ✨ Use. Materials have no action button (they're crafting inputs, not usables).
  - Navigation edits the same message in place (editMessageText).
  - `inv:info:<id>` callback: placeholder toast "`<name> — description coming soon`" until per-item description view is built.
  - `inv:use:<id>` callback: food/potion consume via HungerService (toast with "+X hunger" / "+Y HP"); gear/artifact reply with "🚧 Not yet available" toast until their systems ship (Phase 2.3 / TBD).
  - Consume refreshes category view; auto-pops back to root when the category becomes empty.
  - Rejects consumption if item's total effect would be zero (no wasted eating).
  - Inventory router registers main-nav button-text handlers (Explore / Estate / Capital / Profile / Settings / Inventory) so main's reply keyboard clicks during inventory still navigate properly.
- `MainController.renderProfile` — shows effective ATK/DEF (respect starvation penalty); appends `😵 Starving` suffix to hunger line in all 3 styles when hunger is 0
- Dev command `/drain <amount>` in GlobalCommandsController — mitya-only; drains hunger by N (clamped); does not trigger starvation HP loss (that's a per-room effect)
- Dev command `/revoke <item_id> <quantity>` — mitya-only; symmetric counterpart to `/grant`. Uses `InventoryEntry.remove`; responds "not enough" if player has fewer than requested (nothing partially removed in that case).
- Localization changes per locale (EN + UK): added inventory.choose_category, inventory.back_root, inventory.action.food/potion/gear/artifact, inventory.info.placeholder, inventory.use.unavailable, hunger.restored, hp.restored, hunger.starving, consume.not_consumable, consume.no_effect, drain.usage, drain.success. Removed inventory.type.recipe, inventory.action.recipe, item.recipe.stew (recipe as an item type was folded away — blueprints will reappear as a separate concept in Phase 5.3 crafting).
- `ItemType.recipe` removed from the catalog/enum (only 5 types now: food, material, potion, gear, artifact). Seed replaces `recipe.stew × 1` with `artifact.shrine_coin × 1`.
- Dev inventory seed upgraded from "run once when empty" to "top-up per item + orphan cleanup": every startup cleans rows whose `item_id` is no longer in the catalog, then tops each seed entry up to its target quantity (never reduces). Rationale: after catalog changes (like removing recipes), stale DB rows linger and the old all-or-nothing seed never refills the new item. Per-item top-up also means consumed test items (e.g., eaten bread) come back on restart — handy for dev.
- Build fully green
