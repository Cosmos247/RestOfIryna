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

## Session 6 — 2026-04-20 (Lore-driven registration — Artania narrative)

### What was done:
- Registration reworked from 4 mechanical steps into a 6-step lore flow driven by the Artanian narrative the user authored:
  - Step 0: language
  - Step 1: Artanian welcome (King's realm, Beastfever plague) + name prompt
  - Step 2: name acknowledged + class descriptions (Knight/Archer/Mage) + class selection buttons
  - Step 3: King's Oath narrative — charter granted, class-specific starter weapon bestowed; inline "🏰 Set out for the estate" button
  - Step 4: road ambush by a pack of rabid wolves (combat stub for now) + inline "⚔️ Continue" button
  - Step 5: arrival at the derelict manor — player names the estate
  - Step 6: complete, transition to main controller
- UK class name for `.warrior` renamed "Воїн" → "Лицар"; EN renamed "Warrior" → "Knight" to match medieval tone
- Added `CharacterClass.starterWeaponId`: warrior → gear.rusty_sword, archer → gear.simple_bow, mage → gear.wooden_staff
- Added two new catalog items: `gear.simple_bow`, `gear.wooden_staff`
- On class selection, `RegistrationController` grants the matching starter weapon via `InventoryEntry.add`
- King's Oath text uses `%{weapon}` interpolation — localized to "клинок/лук/посох" (UK) / "sword/bow/staff" (EN)
- Dev profile reset now wipes the user's inventory too (so the class-weapon grant starts clean on replay)
- Dev seed no longer ships `gear.rusty_sword` (registration handles class weapons instead)
- Phase 1.2 "Create tutorial/onboarding message sequence" marked done — this narrative IS the onboarding
- 10 net new localization keys per locale (96 → 106): registration.welcome, registration.name_accepted, registration.king_oath, registration.weapon.{warrior,archer,mage}, registration.to_estate, registration.journey_wolves, registration.continue, item.gear.simple_bow, item.gear.wooden_staff. Removed `registration.nickname.prompt` (replaced by `registration.welcome`).
- Rewrote class descriptions (registration.class.*.desc) in lore style: Лицар незламний щит / Лучник зірке око / Маг володар стародавніх сил
- Rewrote `registration.estate.prompt` into the plaque-naming lore text
- Rewrote `registration.complete` into a short Artanian benediction
- Build clean.

### Follow-up (same session): class-specific artwork for the wolves step
- Added three illustrations under `Assets/registration/<class>_estate.jpg` (warrior/archer/mage). Each shows the Governor approaching the derelict manor with rabid wolves closing in, art styled per class.
- `CharacterClass.journeyImageName` returns the matching filename.
- `RegistrationController.promptJourneyWolves` now reads the file and sends it via `TGSendPhotoParams` with the narrative text as caption and the Continue button as inline keyboard. Falls back to text-only if the file is missing.
- Promoted `projectPath` from a local variable inside `configure()` to a public global constant so controllers can use it for asset loading.
- Note: no file_id caching yet — each registration re-uploads the JPEG via multipart. Fine for dev; move to file_id cache (or remote URL hosting) before public launch.

### Follow-up: keep onboarding messages in chat history
- Previously the callback handler called `deleteMessage` on the source of each click, so only the opening "Welcome to Artania" and the final estate-naming prompt remained on screen. All narrative steps (class descriptions, King's Oath, wolves artwork) were erased.
- Replaced the delete with `editMessageReplyMarkup` that swaps the inline keyboard for an empty one. Text, HTML, and attached artwork stay; only the buttons disappear so they can't be re-clicked.
- This keeps the full registration arc scrollable in chat and is the groundwork for adding more class-specific artwork to other onboarding steps later.

## Session 7 — 2026-04-21 (Equipment system scaffolding, Phase 2.3.1)

### Plan
Phase 2.3 is being split into four sub-commits matching the TODO subpoints:
  - 2.3.1 — Slot design (types only, no behaviour change)
  - 2.3.2 — Data layer (inventory.equipped_slot + users.gear*Bonus columns)
  - 2.3.3 — EquipmentService + effective-stat integration + registration auto-equip
  - 2.3.4 — Inventory UI toggle + profile "Equipped" line

### Architectural choices
- Equipped state will live as a column on `InventoryEntry` (`equipped_slot: String?`), not as a separate table and not as columns on User. Rationale: gear already occupies one row per unit in inventory; marking a row "equipped to X" is the minimal diff. Unequipping is nilling the slot; the item stays in inventory.
- Gear bonuses (attack/defense/crit/dodge/accuracy) will be cached on the `User` row so combat/UI can read effective stats synchronously. Recomputed on every equip/unequip.
- Equipment UI lives inside `InventoryController` — no new controller. The existing `🛡 Equip` button on gear rows will be wired to real logic, with the label toggling to `❌ Unequip` when the row is currently equipped.

### What was done (2.3.1)
- Added `EquipmentSlot` enum (8 cases: helmet/chest/legs/boots/mainHand/offHand/accessory1/accessory2). Raw values use snake_case for the DB column.
- Added `GearStats` struct (attack/defense/crit/dodge/accuracy, each Int, default 0).
- Extended `Item` with optional `slot: EquipmentSlot?` and `gearStats: GearStats?`. Custom public init with defaults so existing non-gear catalog entries don't need changes.
- Wired stats onto the four starter gear items:
  - gear.rusty_sword → mainHand, +2 atk
  - gear.simple_bow → mainHand, +2 atk, +1 acc
  - gear.wooden_staff → mainHand, +2 atk, +1 crit
  - gear.leather_vest → chest, +2 def
- No runtime behaviour change yet — this step only introduces the type vocabulary. Build clean.

### What was done (2.3.2)
- Two new migrations:
  - `AddEquipSlotToInventory` — nullable `equipped_slot: String` column on `inventory`. When set, that inventory row is the equipped piece for the named slot (EquipmentSlot raw value, snake_case). When nil, the item is simply carried.
  - `AddGearBonuses` — five new `Int` columns on `users` (`gear_attack_bonus`, `gear_defense_bonus`, `gear_crit_bonus`, `gear_dodge_bonus`, `gear_accuracy_bonus`), all `NOT NULL DEFAULT 0` so existing rows backfill cleanly.
- `InventoryEntry.equippedSlot: String?` via `@Field`.
- `User` gains the five cached gear-bonus fields + init zero-out; dev profile reset now also zeroes them.
- `User.recomputeGearBonuses(on:)` is a zero-out stub for now — Phase 2.3.3 will sum equipped rows' GearStats through `EquipmentService`.
- Migrations registered in `configure.swift` after `RemoveCrownsField`.
- Still no runtime behaviour change — gear items can now be "marked equipped" in the DB, but nothing writes that flag yet. Build clean.

### What was done (2.3.3 — equip / unequip logic)
- New `Swift/Services/EquipmentService.swift`. Three entry points:
  - `equip(entry, for: user, on: db)` — fetches all the user's inventory rows, unequips any previous occupant of the target slot, writes the new slot on the target row, calls `recomputeBonuses`, then `user.saveAndCache(in: db)` so the session cache is refreshed. The service owns the DB writes here (unlike HungerService which is purely in-memory) because the equip operation spans multiple rows and the caller would otherwise have to reimplement the swap every time.
  - `unequip(entry, for: user, on: db)` — nils the slot, recomputes bonuses, saves user.
  - `equipped(for: user, on: db) -> [EquipmentSlot: InventoryEntry]` — current loadout, keyed by slot. Used by the profile renderer.
  - `recomputeBonuses(for: user, on: db)` — sums each equipped item's GearStats into the user's cached `gear_*_bonus` fields. Mutates user in place.
- `User.recomputeGearBonuses` stub removed — EquipmentService is the single source of truth.
- `User.effectiveAttack/Defense` now read `base + gearBonus − hunger penalty`. Added `effectiveCrit / effectiveDodge / effectiveAccuracy` (hunger doesn't penalize those per GDD — just layer in gear bonus).
- `RegistrationController` set_class callback: after granting the starter weapon via `InventoryEntry.add`, it now looks the row up and calls `EquipmentService.equip` so the King's Oath isn't a lie — the weapon is actually in hand when the King describes it.

### What was done (2.3.4 — UI)
- `InventoryController.categoryKeyboard` split into `gearRows` + `genericRows`. Gear rows:
  - Aggregated by item-id (so two Rusty Swords show as one row with count). A row is flagged "equipped" if any of the aggregated physical rows is equipped.
  - Equipped rows get a leading `📍` and the action button toggles to "❌ Unequip" with callback prefix `inv:unequip:<item_id>`.
  - Unequipped rows keep the original "🛡 Equip" label with callback prefix `inv:equip:<item_id>`.
- New callback handlers `inv:equip:` and `inv:unequip:`:
  - Equip: finds the first unequipped row of the item (via a filtered query) and hands it to `EquipmentService.equip`. Toast: "📍 Equipped: <item>".
  - Unequip: finds the equipped row and calls `EquipmentService.unequip`. Toast: "Unequipped: <item>".
  - Both re-render the gear category in place (new helper `refreshCategory(type:chatId:messageId:context:)`).
- `MainController.showProfile` is now async-aware of equipment: it loads `EquipmentService.equipped(for:)` and passes the `[EquipmentSlot: InventoryEntry]` map to `renderProfile`. All three profile styles got a new line `🗡 Main hand: <item>` (or "(empty)") between the stats block and the gold line. Effective crit/dodge/accuracy now show with gear bonuses too.
- Localization: 5 new keys per locale (`inventory.action.gear.unequip`, `equip.success`, `unequip.success`, `profile.equipped.main_hand`, `profile.equipped.empty`). Total: 111 keys per locale.
- Build clean. EN/UK parity verified (111 = 111, no key drift).

Phase 2.3 complete end-to-end: new character goes through registration → auto-equips starter weapon → King's Oath text matches inventory → profile shows effective stats (base + gear) → player can walk into inventory and swap gear with atomic slot handoff + bonus recomputation.

### Polish (same session)
- Knight's `rusty_sword` bumped from +2 to +3 ATK (knight's secondary stat is pure attack power — mirrors archer's +acc and mage's +crit).
- Per-item inventory icons added via `Item.icon: String?`, set on all four starter gear pieces: ⚔️ (rusty_sword), 🏹 (simple_bow), 🪄 (wooden_staff), 🦺 (leather_vest). `InventoryController.gearRows` prepends the icon to the row label unconditionally — the glyph is part of the item's identity and stays visible whether the item is equipped or not. Equipped state is still conveyed by the Equip/Unequip button toggle (no more 📍 pin). Distinct from `ItemType.icon`, which is the type-level glyph used in the root-category buttons.
- `registration.estate.prompt` no longer addresses the player as "Наміснику" / "Governor" — it now interpolates the nickname the player entered at step 1 ("<b>%{name}</b>, як ти назвеш свій маєток?"). `RegistrationController.promptEstateName` passes `context.session.nickname` into the localize call.
- Added `Assets/registration/kings_charter.jpg` — a single piece of artwork shown for all classes during the King's Oath step. `promptKingOath` now uses `sendPhoto` with the narrative as caption and the inline "Set out for the estate" button as reply markup (falls back to text-only if the file is missing, same pattern as the wolves encounter). Caption fits comfortably under Telegram's 1024-char limit.

## Session 8 — 2026-04-21 (Phase 5.0 — Estate navigation skeleton, Phase 3/4 paused)

### Why out of order
User asked to skip Phase 3 (Exploration) and Phase 4 (Combat) for now and start on Phase 5 (Estate). There's no hard dependency: the estate UI doesn't need exploration loot or combat drops — it needs inventory (already in place from Phase 2). Material-only flows can be tested with `/grant mat.* N` until the drop systems ship. The full grid/plot/crafting of 5.1–5.4 is deferred; this commit lays just the navigation skeleton that the rest will hang off of.

### What was done
- `User.estateLevel` is a computed property: `1 + max(0, level - 1) / 5`. Every 5 player levels bumps the estate tier by one. Not stored — always in sync with the player's level and cheap to read.
- `EstateController` rewritten from a coming-soon stub into a tree nav controller:
  - Root view — shows the estate name + current level + a short lore blurb + inline `[🏠 House] [🌾 Plot]`. If `Assets/estate/level_<N>.jpg` exists, the message is sent as a photo with that caption; otherwise falls back to plain text. User will drop in artwork as they're drawn.
  - House view — inline `[🛠 Workshop]` / `[🍳 Kitchen]` / `[📦 Warehouse]` rows, plus `[🔙 Back to estate]`. Rooms themselves are coming-soon stubs (reuse `stub.coming_soon`) with a back-to-house button.
  - Plot view — single "coming soon" stub + back-to-estate. Full tile-based plots are Phase 5.1.
  - Callback dispatch edits the same message in place. Because the root may have been sent as a photo (caption message) or as plain text, the callback handler branches on `message.getMessage()?.photo != nil` and calls either `editMessageCaption` or `editMessageText` accordingly.
  - Main-nav pass-through (Explore / Capital / Profile / Settings / Inventory / Estate re-tap) wired on the router, same pattern as InventoryController, so the persistent main reply keyboard continues to work while the player is inside Estate.
- `MainController.onEstate` now calls `estateController.showEstate` instead of the old `showStub`.
- `InventoryController.onEstate` pass-through also updated to call `showEstate`.
- No DB migration. No new controller file. No changes to existing game state.
- Locale: 11 new keys per locale → 122 total (EN/UK parity verified).
- Build clean, no warnings.

### Out of scope (future subtasks of Phase 5)
- 5.1 — Estate Fluent model, 30×30 tile grid, Plot model, grid renderer
- 5.2 — Plot management UI, production timers, resource harvesting
- 5.3 — Recipe model, Workshop/Kitchen flows, blueprint learning
- 5.4 — Global estate placement, adjacency queries, frontier rules
- Level-image assets (user will drop JPEGs into `Assets/estate/level_<N>.jpg` as they are drawn)

### Polish (same session)
- `estate.back_root` shortened from "🔙 До маєтку" / "🔙 Back to estate" to just "🔙 Назад" / "🔙 Back". The other back button (`estate.back_home` = "🔙 До дому" / "🔙 Back to the house") is kept intact — per the user's literal ask to change only the "До маєтку" buttons.
- Added the first three estate artwork files: `Assets/estate/level_1.jpg` / `level_2.jpg` / `level_3.jpg`. Root view now shows the actual painted manor for players at estate tier 1/2/3. Higher tiers still fall back to text-only until their artwork is drawn.

### Warehouse — real storage backing (same session, follow-on)
- Added `Swift/Models/WarehouseEntry.swift` — a Fluent model that mirrors InventoryEntry's shape (user_id FK cascade, item_id, quantity, timestamps) but for the estate warehouse. Separate table keeps the backpack/warehouse concerns cleanly split — equipment, consumption, and inventory helpers don't have to learn about a location column.
- Migration `CreateWarehouse` adds the `warehouse` table.
- Helpers on `WarehouseEntry`: `add` (stackable-aware), `list`, `totalQuantity`. No remove/has yet — deposit/withdraw is a later step.
- Dev profile reset now also wipes warehouse rows. The mitya dev seed block does a matching pile for warehouse (same six items as the inventory seed), same top-up + orphan-cleanup semantics.
- `EstateController` — the Warehouse room is no longer a "coming soon" stub. `estate:home:warehouse` shows a category grid with live per-type counts (🍖 Food (N), 🪨 Materials (N), 🧪 Potions (N), 🗡 Gear (N), 💎 Artifacts (N)). Clicking a category (`estate:wh:<type>`) drills down to a text list of every stored item in that category, with per-item icons. Back button returns to the warehouse root.
- 2 new locale keys: `estate.warehouse.description` (root intro), `estate.warehouse.empty` (shown when a category is empty).
- Deposit / withdraw flows and a proper `WarehouseService` are deliberately deferred — this commit just makes the warehouse legible.

### Warehouse deposit / withdraw (same session, follow-on)
- New `Swift/Services/WarehouseService.swift`: `deposit(itemId:for:on:) -> Bool` and `withdraw(itemId:for:on:) -> Bool`. Both move one unit per call. Deposit picks the first UNEQUIPPED inventory row of the item (equipped gear is not transferable). Stackable items decrement/increment quantities; non-stackable rows are deleted/created as a whole.
- `EstateController` warehouse category drill-down rewritten:
  - Computes a `WarehouseCategoryRow` array — the union of inventory + warehouse items of the requested type. Inventory counts skip equipped rows. Rows with 0 on both sides are dropped.
  - Each item renders as a 3-button row: `[🎒 Name] [N ⬆️] [M ⬇️]`. The name button is reserved for a future description view (right now it shows the shared `inventory.info.placeholder` toast). The arrow buttons dispatch `estate:wh:deposit:<id>` / `estate:wh:withdraw:<id>`.
  - After a transfer: toast with the localized result ("⬆️ moved to warehouse", "⬇️ taken from warehouse", or "nothing to deposit/withdraw"), then the category view is rebuilt in place from fresh `InventoryEntry.list` + `WarehouseEntry.list` data.
- 4 new locale keys per locale: `estate.warehouse.deposited/withdrawn/nothing_to_deposit/nothing_to_withdraw`. EN/UK parity 128/128 verified.
- Gear note: because equipped gear is excluded from the transferable inventory count, a sword currently equipped won't appear in the warehouse Gear category at all. Player has to unequip via Inventory → Gear → Unequip first, then the row appears in warehouse view with `1 ⬆️`.

### Polish: transfer button icons + Lingo leading-emoji interpolation bug
- Added inventory/warehouse emojis to the transfer buttons: `[🎒 N ⬆️]` for deposit (from backpack), `[📦 M ⬇️]` for withdraw (from storage). Visually connects the direction to the source container.
- Found and worked around a Lingo interpolation bug: `StringInterpolator` in the miroslavkovac/Lingo dependency builds its scan range from `rawString.count` (grapheme count) but NSRegularExpression interprets ranges in UTF-16 code units. Strings that start with a multi-UTF-16-unit emoji (e.g. "⬆️ %{item} ..." where ⬆️ is U+2B06 + U+FE0F = 2 UTF-16 units, 1 grapheme) get a range that's short by the extra units, which both moves the extracted match off by one char and can drop the closing `}` out of the scan range. Net effect for callers: `%{item}` stays literal in the output, so the user sees the placeholder instead of the actual item name.
- Fixed by rearranging the affected keys so `%{item}` is at the start (no multi-UTF-16 prefix): `estate.warehouse.deposited/withdrawn` and `equip.success`. Also patched `equip.success` proactively — it had the same leading 📍 issue but hadn't been hit yet because the player auto-equips the starter weapon during registration and hasn't clicked Equip manually.
- Safe prefixes for future keys with interpolation: plain ASCII or single-BMP-code-unit characters (e.g. ✅ is one UTF-16 unit and is fine). Avoid leading 📍 🎒 ⬆️ ⬇️ 📦 etc. before an interpolation placeholder, or put the placeholder first.

### Polish: per-row gear display in inventory + warehouse
- Gear is non-stackable — every unit is its own DB row. Previously the UI aggregated rows by item_id and rendered `Rusty Sword × 2` as a single button. Reworked so each gear row is its own button, with no `× N` suffix (it's always implicit 1). Two unequipped rusty swords now show as two identical button rows.
- `InventoryController.gearRows` — iterates InventoryEntry rows directly (no item_id grouping). Sort order: equipped first, then by item id. Each row renders as `[Icon Name] [🛡 Equip / ❌ Unequip]` based on its own `equippedSlot`. Callbacks stay itemId-based — server picks "first matching row" which is indistinguishable from targeting a specific one since identical gear has no per-instance state yet.
- `EstateController.warehouseCategoryKeyboard` — branches by ItemType. For gear: iterates inventory rows (skipping equipped) then warehouse rows, each rendered as `[Icon Name] [🎒 ⬆️]` or `[Icon Name] [📦 ⬇️]`. Single-direction button per row since each physical unit is either in the backpack or in storage — never both. For non-gear: unchanged aggregate with bidirectional `[🎒 N ⬆️] [📦 M ⬇️]` buttons.
- `renderWarehouseCategory` now takes `invEntries` + `whEntries` directly (dropped the pre-computed rows arg) so empty-state detection can branch on type without the caller having to know the logic.
- Both callers of the keyboard/render functions (open-category + post-transfer refresh) updated.

### Dev seed: fan out across all developerUsers
- Previously the inventory/warehouse seed was hardcoded to mitya. Now it iterates the `developerUsers` array — every account listed there gets the same starter backpack + warehouse contents at launch (same top-up + orphan-cleanup semantics as before).
- If the developer row isn't found in the users table or has a nil id, that user is simply skipped (first /start populates them).
- This means changing `developerUsers` in configure.swift is the single place to turn dev-seeding on for a new tester — no need to add a second mitya-specific hardcoded block.

## Session 9 — 2026-04-21 (Phase 3.0 — backpack slot cap, groundwork for exploration)

Starting on Phase 3 (Exploration) — skipping 3 and 4 into a hybrid exploration system per the user's design spec: two modes (active purchase-by-step, passive timed expedition), inventory = expedition bag, death wipes non-equipped inventory, 2-hour daily passive budget. This is just 3.0 — the backpack slot cap that the rest of the exploration loop depends on.

### What was done
- `InventoryEntry.slotCap = 50` constant. A "slot" is one row, regardless of that row's `quantity` (so `bread × 50` is one slot, matching typical RPG convention). Equipped gear rows don't count — they're "on the body" not in the bag.
- New helpers:
  - `slotsUsed(for:on:)` — count of non-equipped rows for a user
  - `canAccept(itemId:quantity:for:on:)` — preflight check, tells callers whether an add would fit. For stackable items with an existing row: always yes (merge). For stackable with no existing row: needs 1 free slot. For non-stackable (gear): needs N free slots for N units.
- `InventoryEntry.add` now throws `InventoryError.inventoryFull` when the cap would be exceeded.
- `WarehouseService.deposit` / `withdraw` switched from `Bool` to typed result enums (`DepositResult.success | .nothingToDeposit`, `WithdrawResult.success | .nothingToWithdraw | .inventoryFull`). Withdraw preflights inventory space before removing from warehouse so we never leak items on a half-failed transfer.
- `EstateController.handleWarehouseTransfer` now dispatches on the enum and surfaces distinct toasts per failure mode. `inventory.full` toast is shared with the `/grant` command and will be reused by exploration loot pickup later.
- `/grant` dev command catches `inventoryFull` and tells the user instead of propagating the error.
- `InventoryController.renderRoot` gains a fullness indicator next to the title: `🎒 Інвентар  3/50 слотів`. Gives the player immediate feedback before they pick up new loot.
- Dev seed wrapped in `do/catch InventoryError.inventoryFull` — on a fresh/wiped dev user it never triggers, but keeps startup robust if ever called on a populated account.
- 2 new locale keys per locale (130 total): `inventory.full`, `inventory.slots_label`.
- Build clean. EN/UK parity verified.

### Next steps
- 3.1 — ExplorationController (active mode MVP), with HungerService drain hooks finally firing, autobattle stub for encounters, death penalty wiping non-equipped inventory.
- 3.2 — return-path visited-rooms memory + depth-decay "already explored" rolls.
- 3.3 — passive timed expeditions with 2h/day budget.
- 3.4 — mode exclusivity (can't be in both at once).
- Localization changes per locale (EN + UK): added inventory.choose_category, inventory.back_root, inventory.action.food/potion/gear/artifact, inventory.info.placeholder, inventory.use.unavailable, hunger.restored, hp.restored, hunger.starving, consume.not_consumable, consume.no_effect, drain.usage, drain.success. Removed inventory.type.recipe, inventory.action.recipe, item.recipe.stew (recipe as an item type was folded away — blueprints will reappear as a separate concept in Phase 5.3 crafting).
- `ItemType.recipe` removed from the catalog/enum (only 5 types now: food, material, potion, gear, artifact). Seed replaces `recipe.stew × 1` with `artifact.shrine_coin × 1`.
- Dev inventory seed upgraded from "run once when empty" to "top-up per item + orphan cleanup": every startup cleans rows whose `item_id` is no longer in the catalog, then tops each seed entry up to its target quantity (never reduces). Rationale: after catalog changes (like removing recipes), stale DB rows linger and the old all-or-nothing seed never refills the new item. Per-item top-up also means consumed test items (e.g., eaten bread) come back on restart — handy for dev.
- Build fully green

## Session 10 — 2026-04-22 (Phase 3.1 — Active Exploration MVP)

The first playable expedition loop. Hunger finally drains, starvation actually hurts, encounters resolve, death has a cost. Designed against the dual-mode spec (active now, passive later in 3.3).

### What was done
- **Data layer**
  - `Models/ExplorationState.swift` + `Migrations/CreateExplorationState.swift` — Fluent model + migration. One row per active expedition, unique on `user_id`, `stepsDeep` tracks the current km. Presence of a row = "currently out exploring", absence = "at the estate". Helpers `current(for:on:)`, `begin(for:on:)` (deletes stale rows defensively), `end(for:on:)` (no-op if absent). Registered in configure.swift.
  - `Models/Enemy.swift` — static code-based bestiary mirroring `ItemCatalog`. `Enemy` struct (id, nameKey, tier, hp/atk/def, depthRange, lootTable, icon) + `EnemyLootDrop` (itemId, chance 0…1, quantity). MVP bestiary: rabid hare / fox / wolf — tiers 1–2, depth ranges 1–3 and 3–6. `EnemyCatalog.pickFor(kmDepth:)` filters by eligibility and picks randomly.
- **Service**
  - `Services/ExplorationService.swift` — pure-ish service with three entry points. `rollStep(for:kmDepth:on:)` drives a single forward step: drains walk-room hunger, applies a starvation HP tick if hunger is already 0, then rolls an event from the weighted bucket (nothing 40 / loot 30 / encounter 25 / trip 5). Loot pool is depth-aware (shallow forest vs medium forest). Encounter goes through the stub `resolveAutobattle` (alternating strikes, ±10% variance, safety cap 50 rounds, one hunger drained per round). Win rolls the enemy's loot table; each drop preflights inventory space with `InventoryEntry.canAccept` so full-bag drops come back as `picked: false`. `StepOutcome` enum carries every path back to the caller (nothing / loot / trip / encounterWon / encounterLost / starvationOnly).
  - Design note left in the file header: the autobattle is a Phase-4 placeholder. Phase 4's round-based `CombatController` will replace it with a real dodge/accuracy/crit-aware engine; shape of `resolveAutobattle` is kept intentionally narrow so the swap is just a function replacement.
- **Controller rewrite**
  - `Controllers/ExplorationController.swift` — replaced the stub entirely. Public entry `showExploration(context:)` resumes an existing state or begins a new one, sends a narrative + status card, and sets a dedicated reply keyboard `[🚶 Step] [🎒 Bag] [🔙 Return]`. Step handler increments `stepsDeep`, calls `ExplorationService.rollStep`, saves the user, renders the outcome narrative and an updated status card in a fresh message (scrolling narrative log). HP ≤ 0 diverts to the death flow.
  - Bag flow is scoped to consumables only — food and potions. Non-consumable types (materials/gear/artifacts) are managed back at the estate, keeping the expedition UI focused on what actually matters mid-walk (eating to avoid starvation, healing). One-tap eat/use refreshes the bag view in place via `editMessageText`; `explore:back` deletes the bag message.
  - Death: wipes every non-equipped `InventoryEntry` row directly (equipped gear survives — per design), sets `hp = 1`, leaves `hunger` as-is (per user's spec: "Hunger stays the same as at death"), ends the exploration state, and drops back to main menu with a dramatic death screen that includes the cause narrative.
  - Return (voluntary): ends the state and shows a short "you returned home" line through `MainController.showMainMenu(context:text:)`.
  - Main-nav integration: `MainController.onExplore` / `InventoryController.onExplore` / `EstateController.onExplore` now all call `showExploration` instead of the old `showStub`. Since `showExploration` sets `routerName` itself, callers no longer duplicate that — removed the pass-through `saveAndCache` block in all three callers.
- **Locale keys (EN + UK)** — ~20 new per locale: expedition keyboard buttons, started/resumed intros, depth label, every outcome narrative (nothing / loot picked / loot full / trip / encounter won / encounter lost / starvation), returned line, death screen with `%{cause}` slot, bag title/empty/back, three enemy names (rabid_hare / rabid_fox / rabid_wolf).

### Design choices to remember
- **Status card on every step**: each step posts a fresh message (not in-place edit), so the expedition reads as a scrolling narrative log. Old cards stay visible with their buttons; tapping a stale button just acts on current state, which is harmless.
- **Bag view scoped to consumables**: deliberate. Mid-expedition the player can only usefully interact with food/potions. Gear/materials/artifacts flows live back at the estate. Full-inventory management during a run was explicitly rejected as overscope for 3.1.
- **Resume on re-entry**: player can tap Explore from main menu (even after opening inventory from inside the expedition via the Bag button + stepping out). `showExploration` detects the existing `ExplorationState` row and resumes at the same `stepsDeep`. Only a deliberate 🔙 Return or death ends the expedition.
- **Event weights are placeholders**: 40/30/25/5. User flagged they will tune these later. They're class constants at the top of `ExplorationService` for easy editing.
- **Autobattle is intentionally dumb**: no dodge/accuracy/crit yet. Phase 4's real combat UI will replace `resolveAutobattle`; the `AutobattleResult` struct has the shape we'll need (playerWon, rounds, hpLost, hungerLost).

### Next steps
- 3.2 — Return-path visited-rooms memory + depth-decay "already explored" rolls.
- 3.3 — Passive timed expeditions with 2h/day budget.
- 3.4 — Mode exclusivity enforcement (active vs passive).
- Phase 4 — real combat UI replacing the autobattle stub.

## Session 11 — 2026-04-22 (Phase 3.2 — Return path with visited rooms)

The one-way expedition from 3.1 becomes a round trip: players walk back through the same rooms, which now roll events with reduced "already explored" weights.

### What was done
- **Schema** — new migration `AddExplorationReturnState` adds two nullable columns to `exploration_state`: `returning` (Bool) and `visited_rooms` (TEXT — JSON array of ints). Nullable was deliberate: existing 3.1 rows still load; the model resolves nil to `outward` + empty set. Registered in configure.swift right after `CreateExplorationState`.
- **Model** — `ExplorationState` gains `@OptionalField` for both columns plus computed wrappers that hide the Optional: `isReturning: Bool` (nil → false) and `visitedRooms: Set<Int>` (JSON encode/decode). Added `markVisited(_:)` and `isVisited(_:) -> Bool` helpers so controller code reads/writes the set declaratively.
- **Service** — `ExplorationService.rollStep` gained an `alreadyExplored: Bool = false` parameter. New parallel weight constants for the decayed table (`weightNothingDecayed 70 / weightLootDecayed 10 / weightEncounterDecayed 15 / weightTripDecayed 5`, sum = 100 — same total so the existing roll logic still works). When `alreadyExplored == true` the service uses the decayed weights; otherwise fresh. Hunger drain and starvation HP tick still fire on every step regardless of direction (walking back still costs food and a starving player still bleeds HP).
- **Controller** — biggest rework since 3.1:
  - `onStep` now dispatches to `stepOutward` or `stepReturning` based on `state.isReturning`.
  - `stepOutward` — increments stepsDeep, rolls with fresh weights, marks the reached km in `visited_rooms`. Same save-user + death-check + render flow as 3.1.
  - `stepReturning` — if `stepsDeep <= 1`, the next step is the arrival at the estate door: skip the event roll, set stepsDeep to 0, invoke `handleHomeReached` (delete state + drop to main menu with "returned" text). Otherwise decrement stepsDeep and roll with `alreadyExplored: state.isVisited(newDepth)`. Because linear return walks are always over visited km, this will always be true in practice — the `isVisited` check is kept for future partial-backtracking scenarios.
  - `onReturnHome` renamed and split:
    - `onReturnButton` — handles the Return reply-keyboard button press. At km 0 it ends the expedition immediately (nothing to walk back). At km > 0 it toggles `state.isReturning` — turning around is free (no hunger drain, no event roll). Sends a narrative + updated status card.
    - `onForceEnd` — new handler for /start and stray Cancel-button presses from other controllers' keyboards. Hard-ends the expedition without walking back, for dev escape / stuck-player cases.
  - Status card (`renderStatusCard`) signature changed from `depth: Int` to `state: ExplorationState` so it can show a "↩️ returning" suffix when the direction is reversed.
  - `narrateOutcome` gained `revisited: Bool = false` — only affects the `.nothing` case, swapping in the "grove is bare" flavor line. Other outcomes reuse the same narratives (mechanical rarity already signals decay).
- **Localization** — 4 new keys per locale (EN + UK), 155 total each: `exploration.turn_around` (outward → returning narrative), `exploration.turn_forward` (returning → outward — "you change your mind"), `exploration.direction.returning` (status-card suffix "↩️ returning" / "↩️ назад"), `exploration.outcome.nothing.revisited` (bare-grove flavor for revisited silence).

### Design decisions to remember
- **Return is mandatory** except via the /start / Cancel escape hatches. No instant-teleport home from the Return button when km > 0 — you walk. This makes deep expeditions genuinely risky: picking up 5 km worth of loot means committing to 5 km of return steps with their own hunger + starvation cost.
- **Turn-around is free** — no hunger drain, no event roll, no stepsDeep change. Just a direction flip. Keeps the UX forgiving: no punishment for scouting ahead then changing your mind.
- **Arrival step skips the roll** — the km 1 → 0 walk is a narrative beat, not a gameplay beat. No final starvation tick, no final event, just "🏰 You return home." This keeps the end-of-expedition feel clean (player wouldn't want to die from starvation on the literal doorstep).
- **Flat decay for MVP** — every revisited room uses the same reduced weights regardless of how deep or how long ago it was visited. Future refinement (3.2-polish) could make deeper rooms less decayed or add time-based regeneration, but the flat table ships now with a single pair of weight constants.
- **Visited rooms persist in JSON, not a relation** — `Set<Int>` encoded as sorted JSON array in a TEXT column. Simple, portable, no extra table, no per-room-event-snapshot storage (deferred). The model's computed `visitedRooms` var hides the encoding entirely.
- **`alreadyExplored` parameter, not two entrypoints** — `rollStep` stays a single function with a default-false parameter. Cleaner than fork-by-function for such a small branch-point.

### Next steps
- 3.3 — Passive timed expeditions. Duration picker (30m / 1h / 1.5h), first real scheduled-background task in the codebase (cron-like simulation on timer completion), report rendering.
- 3.4 — Mode exclusivity. `User.expeditionEndsAt` field + check in `MainController.onExplore`; main menu replaces [🗺 Explore] with "🕒 Out exploring — X min left" while passive is running.
- Future polish: per-room event snapshots for richer return narration; tuning decay weights; depth-proportional decay curve.

## Session 12 — 2026-04-22 (Phase 3.2 — Step Back rework with per-room visit decay)

Replaced the direction-toggle model from earlier 3.2 with an explicit Step Back button and a three-tier visit-count weight table. Simpler UX, more expressive mechanic.

### What was done
- **Keyboard redesign** — no more "Return" button. New expedition keyboard: `[🚶 Step fwd] [🔙 Step back]` on row 1, `[🎒 Bag]` on row 2. Direction is encoded in the button pressed, not in a state flag.
- **Visit counter** — `visited_rooms` changed from a `Set<Int>` (was visited y/n) to a `Dictionary<Int, Int>` (km → visit count). Same DB column (TEXT), different JSON payload (`{"1": 2, "2": 1}` instead of `[1, 2]`). Old 3.2 array-format rows fail to decode as dict and fall back to empty map — harmless since they'd just get fresh-tier rolls.
- **Model cleanup** — removed the `returningFlag` / `isReturning` computed wrappers; the `returning` column stays on the schema but isn't mapped by the model anymore. Renamed helpers: `markVisited/isVisited` → `recordVisit/visitCount`.
- **Service: three-tier weights** — `ExplorationService.rollStep` takes `priorVisits: Int` instead of `alreadyExplored: Bool`. Tier 0 (fresh, priorVisits == 0) = 40/30/25/5. Tier 1 (reduced, priorVisits == 1) = 70/10/15/5. Tier 2+ (bare, priorVisits ≥ 2) = 100/0/0/0 — only `.nothing` or `.starvationOnly` can fire. Trip hazard goes to zero at tier 2+ too, keeping the "room is picked clean" feel consistent.
- **Controller rewrite** — removed every direction-toggle code path (`onReturnButton`, `stepReturning`, `stepOutward`, `turnAround`, direction hint in status card). Replaced with `onStepForward` (always increments + rolls + records) and `onStepBack` (decrements + rolls at km ≥ 2, arrives home at km ≤ 1). Both step handlers pass `priorVisits = state.visitCount(newDepth)` to the service and call `state.recordVisit(newDepth)` after the roll. Step Back at km 0 or 1 ends the expedition cleanly with no roll.
- **Three-variant `.nothing` narrative** — `narrateOutcome` now takes `priorVisits: Int` and picks between `exploration.outcome.nothing` (fresh), `.revisited` (thinned — visit 2), `.bare` (visit 3+). Other outcomes reuse their single narrative since the mechanical depletion at tier 2+ already communicates the "picked clean" feel.
- **Locale keys** — renamed `exploration.button.return` → `exploration.button.step_back`, removed now-unused `exploration.turn_around` / `exploration.turn_forward` / `exploration.direction.returning`, added `exploration.outcome.nothing.bare`. Net change: 154 keys per locale (EN + UK).

### Why reworked
The earlier direction-toggle model conflated two orthogonal concerns — which way you walk and whether the room is depleted. Splitting them gives:
- Cleaner UX: two distinct buttons, no invisible state.
- More expressive mechanic: oscillating between two rooms burns them out in 2-3 cycles, which encourages going deeper rather than camping a single room. The three-tier table makes the second visit "still worth something" and the third+ visit "fully tapped", matching typical foraging-RPG intuitions.
- Less code: no direction flag on the model, no `isReturning` conditional branches, no turn-around narrative paths. The model now has one meaningful field (`visited_rooms`); the old `returning` column lies dormant.

### Design notes
- **km 0 and km 1 both end the expedition** on Step Back — one is "never left", the other is "walked all the way back". Same narrative key (`exploration.returned`) because the narrative distinction is minor and adding a second key wasn't worth it for MVP.
- **Record AFTER the roll** — `priorVisits` needs to be the count *before* this step, so the counter is bumped after `rollStep` returns. On failure/throw, neither the new count nor the state save persists — safe retry.
- **Dormant `returning` column** — intentional trade-off. Dropping it would require a new migration, and the column is harmless. A future cleanup pass could add `RemoveExplorationReturningField` if the schema ever gets noisy.

### Next steps
- 3.3 — Passive timed expeditions. Duration picker + scheduled simulation + report rendering.
- 3.4 — Mode exclusivity: `User.expeditionEndsAt` + main-menu busy state.
- Balance: playtest visit-decay weights; consider depth-proportional adjustments.

## Session 13 — 2026-04-22 (Weight retuning + passive estate regen)

Two small follow-ups after playtesting 3.2:

### Weight retuning
Fresh-tier had `nothing` at 40% which felt too empty — every other step was silence. Retuned:
- Fresh (priorVisits = 0): `nothing 40 / loot 30 / encounter 25 / trip 5` → **`20 / 40 / 30 / 10`**
- Reduced (priorVisits = 1): `70 / 10 / 15 / 5` → **`50 / 20 / 20 / 10`**
- Bare (priorVisits ≥ 2): unchanged at `100 / 0 / 0 / 0`

Every step now has an 80% chance of *something* on first visit (vs 60% before), still 50% on second visit, zero on third+. Trip doubled from 5 → 10 to make damage more present before encounters come out. Numbers are gameplay-driven, easy to tune later.

### Passive HP regen at the estate
First properly lazy-computed idle mechanic in the codebase. Needed:
- **Migration** `AddHpRegenTick` — adds nullable `last_hp_tick_at: Date?` column on `users`.
- **Model** `User.lastHpTickAt` via `@OptionalField`. Initialized nil; `HealingService` primes it on first damaged observation.
- **Service** `HealingService.tick(_:on:)` — pure enum namespace. Rate is `regenPerMinute = 0.05` (5% of maxHp), capped at `maxIdleMinutes = 1440` (24h) to prevent absurd offline top-ups. Returns the amount restored; caller can log / ignore. Handles four cases:
  1. `routerName == "exploration"` → clear the clock (suspend regen during expedition).
  2. `hp >= maxHp` → pin clock to now (prevents banked regen accruing against future damage).
  3. `lastHpTickAt == nil` → prime clock to now, no regen yet.
  4. Otherwise → compute `floor(maxHp · 5% · minutes)`, apply, advance clock.
  Saves via `user.saveAndCache(in: db)` inside each case that mutates, so the caller doesn't need to remember to.
- **Wire-in** `RouterStore.process` — after hydrating the user from the session cache, calls `HealingService.tick` before dispatching to the router. Every interaction goes through `RouterStore.process` already, so this is the single choke point. `HealingService.tick` is a no-op when the user is exploring or at full HP, so the overhead on those paths is just a routerName + hp compare.

### Why the pin-on-full-HP matters
Without pinning: a player at full HP with `lastHpTickAt` from Monday walks into the forest Friday, takes damage, walks home. On their next interaction, `tick` sees `lastHpTickAt` from Monday, computes four days of elapsed time (capped at 24h), and instantly refills them. Pinning at every full-HP tick bounds the banked regen window to ≈ one interaction interval.

### Design notes
- **Lazy vs scheduled**: opted for lazy compute because user interactions are sparse (text-bot cadence) and the alternative needs a background loop. Scheduled mechanics start landing in 3.3 (passive expeditions); HP regen didn't justify it alone.
- **Capped idle**: 24h cap is a soft anti-abuse measure. Also saves us from pathological clock-skew situations.
- **Routerame as proxy for "at estate"**: any non-`exploration` controller counts as "resting". Registration, settings, inventory, estate, capital — all accrue regen. Simple and matches intuition.

### Next steps (unchanged)
- 3.3 — Passive timed expeditions. Duration picker + scheduled simulation + report rendering. First real background scheduler.
- 3.4 — Mode exclusivity: `User.expeditionEndsAt` + main-menu busy state.

### Clarification (later same session)
User confirmed the two-mode split and explicitly pinned down timing:
- **Active reconnaissance (розвідка)** — fully tap-driven, no transition timer. This already matches the 3.1/3.2 implementation; GDD and game-core had carryover language from an earlier draft that implied a timer in both modes. Edited GDD §5 and `.memory/game-core.md` to scope the 5-min room transition to **passive expedition only**.
- **Passive expedition (експедиція)** — stays timer-gated (5 min prod / 10 sec test), still the Phase 3.3 target.

No code changes needed — active mode's ExplorationController already has zero time-gates. The only "tick" in the codebase now is `HealingService.tick` for passive HP regen at the estate, which is lazy-compute and doesn't gate gameplay.

## Session 14 — 2026-04-22 (Phase 3.3 — Passive expedition MVP in test mode)

First truly background-running code in the project. The passive expedition flow sits behind a new mode-picker and fires a rendered report when its Task.sleep elapses.

### What was done
- **Schema** — new migration `AddPassiveExpeditionFields` adds three nullable columns to `exploration_state`: `mode` (TEXT), `ends_at` (TIMESTAMP), `report_json` (TEXT). One table covers both active and passive runs; active rows leave all three nil.
- **Model** — `ExplorationState` gains `@OptionalField` mappings plus an `ExplorationMode` enum (active/passive), `isPassive` / `hasReadyReport` / `secondsRemaining(now:)` queries, and a `beginPassive(for:endsAt:on:)` factory alongside the existing `begin`. `allPassive(on:)` helper used by the startup rescheduler.
- **Service** — `PassiveExpeditionService`:
  - `PassiveDuration` enum (short=30 / medium=60 / long=90 *units*). `testMode: Bool = true` flag governs whether a "unit" is one second (test) or one minute (prod). Step count is `rawValue / 5` — same 6 / 12 / 18 step count in both modes, only the wall clock changes.
  - `start(for:duration:on:bot:lingo:)` creates the state row then calls `scheduleCompletion(stateId:endsAt:db:bot:lingo:)`, which spawns a `Task.detached` that sleeps until `endsAt` and invokes `completeIfDue`.
  - `completeIfDue` re-fetches the state fresh, confirms it's still passive + unreported, loads the user via `$user.load(on:)`, runs `simulate`, encodes the `PassiveReport`, saves user + state, pushes the report message, and deletes the state on successful push.
  - `simulate` runs N `ExplorationService.rollStep` calls with `priorVisits: 0` (passive treks fresh ground). Mutates the real user (hp/hunger/inventory) directly. Aggregates outcome counts + picked/dropped loot into a `PassiveReport` Codable blob. Breaks early if hp hits 0; applies the same death penalty as active mode (wipe non-equipped inventory, hp = 1).
  - `rescheduleInflight(on:bot:lingo:)` — called from `configure.swift` right after `bot.start()`. Scans all passive states; for each, either delivers immediately (endsAt already passed during downtime) or re-arms a `Task.sleep` for the remainder. Idempotent — `completeIfDue` checks `reportJSON != nil` and skips if already done.
  - `renderReport` builds the multi-line HTML message from the `PassiveReport`. Shows reached depth, HP/hunger before/after, an outcome histogram (🕊 silence × 5 · ✨ find × 3 · ⚔️ victory × 2 · …), and the loot list (with partial-drop footnote if the bag overflowed). Death path swaps the opening line.
- **Controller** — `showExploration` branches:
  1. Passive state with a ready report → deliver report + delete state + drop back to main.
  2. Passive state in flight → send countdown text; routerName stays where it is so HP regen + nav keep working.
  3. Active state → existing resume flow.
  4. No state → mode picker.
  New picker flow: `explore:mode:active` → `beginActive`; `explore:mode:passive` → edits the message to the duration picker; `explore:dur:<raw>` → `PassiveExpeditionService.start` + confirmation message + fresh main-reply-keyboard message. `explore:passive:close` dismisses the delivered report.
- **Startup rescheduler** — `configure.swift` calls `PassiveExpeditionService.rescheduleInflight(on:bot:lingo:)` right after `appState.bot.start()`. Bot restarts no longer orphan passive expeditions.
- **Locale keys (EN + UK, 27 new per locale, 180 total)** — mode picker (prompt / active / passive), duration picker (prompt / 30m / 1h / 1h30m / back), passive status (started / inflight / test_mode_hint), report rendering (title / depth / hp / hunger / events_header / loot_header / no_loot / loot_partial / death / close), and six outcome labels (nothing / loot / encounter_won / encounter_lost / trip / starvation) used in the histogram line.

### Design decisions to remember
- **Test mode toggle, not separate constants.** `testMode: Bool` flips the unit-to-seconds ratio. Same duration numbers (30/60/90), just interpreted differently. Flipping to prod is a one-line change when we're ready.
- **One expedition table, two modes.** Didn't split into a `PassiveExpedition` table because the exclusivity rule ("one expedition at a time") is naturally expressed by a single row per user. `mode` column discriminates.
- **Simulation mutates the real user.** Loot goes straight into inventory; hp/hunger change directly. Relied-upon by `HealingService.tick`: while the passive timer counts down, the player's routerName is NOT "exploration" (they're at estate), so HP regen runs normally. When the simulation fires, user's hp is whatever the regen brought them to — that's the "fresh" pool the simulation damages.
- **Delete state after successful push.** The background push pings the player's chat; on success the row is gone so `showExploration` next goes to mode picker. On push failure the row stays (with reportJSON); `showExploration` delivers on next open. Either way, the player sees the report exactly once.
- **Detached task, no cancellation handle stored.** If the player somehow triggers the same expedition twice (shouldn't happen), `completeIfDue` is idempotent — it no-ops when `reportJSON != nil`.
- **Routername convention.** Active mode still sets routerName = "exploration" because its reply keyboard needs to be distinct. Passive keeps routerName at main so the player can browse estate / inventory / profile normally during the wait, and HP regen works.
- **No 3.4 exclusivity yet.** The player *could* currently start an active mode while a passive is in flight — the mode picker doesn't check. 3.4 will add the guard (+ the "🕒 Out on expedition, X min left" main-menu indicator).

### Next steps
- Test the flow end-to-end in the bot (restart with fresh binary to pick up new migrations + code).
- 3.4 — mode exclusivity: main-menu busy state + guard on Explore entry.
- Flip `testMode` to `false` once UX is validated.
- Daily 2h budget. Early-cancel for in-flight passive.
- Phase 4 — real combat UI replacing the autobattle stub (used by both modes).

### Mini fix (same session): "governor is away" guarantees
Small but important: during passive expedition the governor is in the forest, not at the estate. Two fixes so the mental model matches:
- **HP regen pauses during passive too.** `HealingService.tick` signature changed from `(user, db)` to `(user, inExpedition, db)` — the `routerName == "exploration"` check was a proxy that only caught active mode. `RouterStore.process` now queries `ExplorationState.current` once per interaction and passes the presence as `inExpedition`. Both active and passive correctly suspend regen.
- **Estate entry blocked while any ExplorationState row exists.** `EstateController.showEstate` gained a guard at the top — if an expedition row exists, it sends `estate.blocked_by_expedition` notice and returns without transitioning routerName. Callers (MainController.onEstate, InventoryController.onEstate) were also simplified: they no longer set routerName themselves, `showEstate` owns that transition so it can abort cleanly when blocked. Added one locale key in EN + UK (total 181 per locale).

## Session 15 — 2026-04-22 (Phase 3.4 — mode exclusivity)

Final Phase 3 piece. Surfaces the expedition-in-progress state in the main reply keyboard, blocks both city screens, and closes remaining race windows around the mode picker.

### What was done
- **`User.transientInExpedition: Bool`** — non-persisted stored property on the User class. Refreshed by `RouterStore.process` on every dispatch from the same `ExplorationState.current` query that drives HealingService. Controllers read it synchronously — no extra DB round-trips.
- **Busy-label main keyboard** — `MainController.generateControllerKB` picks `commands.explore.busy` ("🕒 On expedition" / "🕒 У поході") instead of the normal label when `session.transientInExpedition == true`. Tap still routes to `onExplore` → `showExploration`, which branches to passive countdown / active resume / report delivery as before.
- **Busy label registered everywhere that passes through Explore** — MainController, EstateController, InventoryController each add a second pass of locale-iterated registrations for the busy label so a tap from inside any of those controllers still reaches `onExplore`.
- **Picker idempotency** — `explore:mode:active` / `explore:mode:passive` / `explore:dur:*` each re-check `ExplorationState.current` at the top. If a state already exists (stale picker from a previous screen, a race with the passive scheduler), the handler dismisses the inline message and redirects to `showExploration` so active progress / in-flight passive isn't silently wiped.
- **Capital blocked during expedition** — `CapitalController.showStub` got the same guard pattern as `EstateController.showEstate`: check for `ExplorationState.current`, send `capital.blocked_by_expedition` notice, bail out without changing routerName. Callers (MainController.onCapital, InventoryController.onCapital, EstateController.onCapital) simplified to trust `showStub` for the transition. `CapitalController` now imports Fluent.
- **Explicit flag resets at expedition end-paths** — `goToMainMenu` (shared helper used by home-reached, force-end, and the passive-report's close-to-main flow) now sets `transientInExpedition = false` before calling `mainCtrl.showMainMenu`. Same reset at the top of `handleDeath` and at the end of `deliverPassiveReport`. Without this, the reply keyboard in the very same response message would still show the busy label (RouterStore only refreshes on the *next* dispatch).
- **Flag set to `true` after `PassiveExpeditionService.start`** — so the main-menu keyboard sent from the duration-pick callback uses the busy label immediately.
- **Locale keys (+2 per locale, 183 total)**: `commands.explore.busy` and `capital.blocked_by_expedition`.

### Design decisions
- **Transient flag instead of async keyboards.** Making `generateControllerKB` async / db-aware was the clean alternative but touches every call site. A single cached flag read synchronously keeps existing signatures intact.
- **Static busy label, no live countdown in the keyboard.** Reply keyboards only update when a new message sends them; live countdowns would flood the chat. The label is a static "🕒 On expedition" — tapping it opens the countdown message with precise MM:SS.
- **Both rural (Estate) and urban (Capital) locations blocked.** Inventory intentionally stays accessible — the bag is a meta concept the player can always peek at, and forcing it closed during expedition would be annoying.
- **Idempotency on mutating callbacks only.** The `explore:mode:pick` back button and bag callbacks don't mutate state, so they don't need guards.

### Phase 3 closure
3.0 (slot cap) → 3.1 (active MVP) → 3.2 (visit-decay return path + passive HP regen) → 3.3 (passive expedition with background scheduler) → 3.4 (mode exclusivity / UX guards) all landed. Remaining backlog on the exploration track: flip `PassiveExpeditionService.testMode` to `false` for prod durations, 3.5 content expansion (more enemies / richer events), and eventually Phase 4's real combat UI replacing the autobattle stub.

### Post-3.4 fixes (same session)
Two bugs surfaced during playtest:
- **Close-report left "🕒 On expedition" keyboard stale.** The `explore:passive:close` callback only deleted the inline message; the reply keyboard from an earlier message still showed the busy label, and the state row (with `report_json`) lingered, so `transientInExpedition` would flip back to `true` on the next dispatch. Fixed by doing the full cleanup in the close handler — delete state if present, reset the transient flag, save, and send a fresh `MainController.showMainMenu` message so the reply keyboard rebuilds with the normal "🗺 Explore" label. `deliverPassiveReport` (the re-open path) was updated to do the same trailing main-menu send.
- **Passive death report claimed loot that was already wiped.** `applyDeath` inside `simulate` correctly wiped non-equipped inventory rows when HP hit 0, but the `PassiveReport` was still being populated with the picked/dropped list gathered during the loop. Players saw "Brought back: Berry × 3" while the DB showed an empty backpack. Fixed by zeroing `report.loot` in `simulate` when `died == true`, and updating `renderReport` to skip the loot section entirely when `report.died` (the death line at the top already communicates full loss).

### Revert: dynamic busy-label on the main keyboard
During playtest the "🕒 On expedition" reply-keyboard label didn't reliably revert after closing the passive report — Telegram only redraws reply keyboards when a fresh message carries a new `replyMarkup`, and hitting every edge case (close button, scheduler push, deliver-on-reopen, restart) was adding complexity for a feature the user deprioritized. Simplified per user's direction: the Explore button label is now static. The gating is done purely at `showExploration` entry via the passive-countdown branch — tapping Explore during an active passive run now sends the exact message the user requested: "Ти вже в експедиції. Очікуваний час прибуття: MM:SS".

Removed in this pass:
- `User.transientInExpedition` (field + all write sites in RouterStore and ExplorationController end-paths / start callback)
- Busy-label registrations in Main / Estate / Inventory attachHandlers
- `commands.explore.busy` locale key (EN + UK, back to 182 per locale)
- Dynamic branch in `MainController.generateControllerKB`

Kept (still valuable regardless of label strategy):
- Estate + Capital guards during any expedition
- Idempotency guards on mode/duration picker callbacks
- `goToMainMenu` / `deliverPassiveReport` / passive-close callback still send a fresh main menu after cleanup so the reply keyboard from an active expedition (step/back/bag) is replaced by the main reply keyboard.

### Live per-step passive simulation (same session)
User pointed out that dying on step 2 out of 18 still made them wait the full timer for the report — the earlier implementation ran all N steps at once at `endsAt` and only then pushed the result. Rewrote the scheduler:
- `scheduleCompletion` now spawns a `Task.detached` running `runLive` instead of `completeIfDue`. The one-shot `simulate()` + `completeIfDue()` helpers were deleted.
- `runLive` is a per-step loop. Each iteration: sleeps until the step's absolute fire time (`createdAt + K * stepDurationSeconds`), reloads state + user from the DB, calls `rollStep` for one km, persists `state.stepsDeep`, checks for death. On death it calls `applyDeath` (wipe non-equipped inventory, hp = 1) and jumps straight to `finalizeAndPush` — no more waiting out the remaining timer.
- Step duration is `secondsPerUnit * unitsPerStep` (5 units/step). Test mode = 5 s/step, prod = 300 s/step. Same total step count as before (6/12/18), just now spread over real time.
- Progress is tracked via `state.stepsDeep` (previously unused for passive rows). `rescheduleInflight` on bot startup just spawns a fresh runLive task per in-flight state; runLive reads `stepsDeep` to know where to resume. Any step whose scheduled fire time fell during downtime runs without sleep ("catch-up") so the expedition can't be stretched by bot outages.
- Outcome counters / loot totals are NOT persisted across restarts (Swift locals in the Task). If the bot crashes mid-simulation the final report only reflects post-restart events. Acceptable MVP tradeoff — passive expeditions are short; crashes should be rare.
- The `finalizeAndPush` helper is shared by both the normal end-of-run path and the early-death path. It writes the JSON, saves the state, and pushes the report message.

### Post-live-scheduler fixes (same session)
Three bugs surfaced while playtesting the new per-step scheduler:

1. **Stale `exploration_state` row across `resetDevProfile = true` restarts.** When dev mode wipes user fields + inventory + warehouse but leaves `exploration_state` intact, a passive row from a previous session can re-fire `deliverPassiveReport` on the next Explore tap. Fixed by adding `try await ExplorationState.end(for: user, on: db)` to the dev-reset block in `configure.swift`.

2. **Lingo interpolation fails when a surrogate-pair emoji appears BEFORE the `%{placeholder}` in the source string.** Our earlier memory note called it "leading emoji breaks interpolation" but the real rule is stricter: any multi-UTF-16 emoji *anywhere before* a `%{name}` token in the localized string prevents it from substituting. Single-UTF-16 chars (+, Cyrillic, Latin) before the placeholder are fine. Rewrote the affected passive-mode strings so placeholders precede every emoji in the string, e.g. `"Expected return in %{time}. Your governor has set off on an expedition 🏕."` instead of `"🏕 Your governor ... %{time}"`. Added the precise rule to `.memory/localization.md`.

3. **Close button on the scheduler-pushed report did nothing visible (and state wasn't cleaned up).** The scheduler pushes the report inline message while the player's `routerName` is `main` (or `inventory` / `settings` if they navigated). Tapping Close there went through that controller's `onCallbackQuery`, which didn't recognise `explore:passive:close` and fell into a generic "delete message" fallback. `ExplorationController`'s full cleanup (delete state row, send "back at the estate" greeting) never ran, so the next Explore tap hit `deliverPassiveReport` again and re-showed the report. Fixed by forwarding any `explore:`-prefixed callback from `MainController` / `InventoryController` / `SettingsController` to `ExplorationController.onCallbackQuery` at the top of their handlers. Also decoupled `showExploration`'s passive-report branch so the state row is deleted *before* the render call, preventing a future duplicate from a stuck state row.

Also renamed `deliverPassiveReport`'s signature from `(context, state: ExplorationState)` to `(context, reportJSON: String?)` — the caller now snapshots the JSON and deletes the state row first, then hands only the serialized payload to the renderer, so even a thrown exception during render leaves no state to re-deliver.

### Material catalog rework (same session)
Player-defined content pass — replaced the placeholder materials with lore-flavoured resources:
- `mat.wood` → `mat.pine_lumber` 🌲 "Pine Lumber"
- `mat.stone` → `mat.river_pebble` 🪨 "River Pebble"
- `mat.iron_ore` → `mat.old_iron` ⛓ "Old Iron"
- `mat.hide` 🟫 stays (name unchanged, icon + description added)
- NEW: `mat.clay` 🧱 "Wild Clay"

Implementation:
- `Item` struct gained `descriptionKey: String?` — optional locale key for the lore blurb shown as a modal alert (`answerCallbackQuery(text: description, showAlert: true)`) when the player taps the item's info button. Nil falls back to the existing "description coming soon" toast.
- `ItemCatalog` — replaced 3 material entries + added 1. Each now carries `icon:` (per-item emoji) and `descriptionKey:` pointing at a `.desc` locale key.
- `Item.icon` is now rendered for non-gear rows too (`InventoryController.genericRows`, `ExplorationController.renderBag`, `EstateController` warehouse) — previously only gear used it.
- Info callbacks updated in three controllers (inv / explore / estate) — unified pattern: modal alert on description present, placeholder toast otherwise.
- Migration `RenameMaterialIds` rewrites `inventory` + `warehouse` rows via `.set(\.$itemId, to: new).update()` so existing stockpiles carry forward after the rename.
- Side-effects: `ExplorationService.rollLoot` shallow/medium pools, `EnemyCatalog` rabid_wolf loot table, and `configure.swift` dev seed all updated to new IDs (plus `mat.clay` / `mat.old_iron` added to the seed).
- 6 new locale keys per locale (EN + UK): 4 new names (pine_lumber, river_pebble, clay, old_iron) + 5 descriptions (`...desc` keys for every material including existing hide). Total 189 per locale.

### Food catalog rework (same session)
Mirrors the material pass — replaced the placeholder bread/stew/roast/berry lineup with a lore-flavoured raw-food family:
- `food.berry` → `food.forest_berries` 🫐 (+15 hunger)
- NEW `food.forest_nuts` 🌰 (+20 hunger)
- NEW `food.potato` 🥔 (effects: [] — strategic ingredient, not raw-edible)
- NEW `food.duck_egg` 🥚 (+25 hunger)
- NEW `food.raw_meat` 🥩 (+30 hunger)
- Removed: `food.bread`, `food.stew`, `food.roast` (cooked variants come back via Kitchen in Phase 5.3)

Implementation:
- `ItemCatalog` food section rewritten with icon + descriptionKey per entry.
- `Item.effects` kept as `[]` for potato — conveyed through a new `consume.not_raw_edible` toast (new locale key): "You can't eat %{name} raw — it needs cooking." Both `InventoryController.inv:use` and `ExplorationController.explore:eat` now check `item.effects.isEmpty` before calling `HungerService.consume` so the player doesn't get the misleading "no effect — already fully restored" fallback.
- `ExplorationService.rollLoot` pools: shallow forages forest_berries/forest_nuts + lumber/pebble; medium adds duck_egg/raw_meat (alongside hide/old_iron/clay).
- `EnemyCatalog` rabid_hare now drops raw_meat instead of berries (semantically: meat from a kill, not foraged berries).
- `configure.swift` dev seed refreshed: forest_berries × 3, forest_nuts × 2, duck_egg × 1, raw_meat × 1, potato × 2. Bread/stew removed from seed.
- Migration `RenameFoodIds` renames berry → forest_berries in `inventory` + `warehouse`, and DELETEs bread/stew/roast rows (no replacement mapping; orphan cleanup via dev seed handles the dev side but the explicit delete covers any non-dev DB rows too). Registered right after `RenameMaterialIds`.
- 11 new locale keys per locale (EN + UK): 5 new names (forest_berries, forest_nuts, potato, duck_egg, raw_meat) + 5 descriptions + `consume.not_raw_edible` with `%{name}` interpolation. Total 196 per locale.

### Per-item foraging flavor (same session, 2026-04-23)
Active-mode loot narration upgraded from one-line-fits-all to per-item lore:
- 8 new `exploration.find.<item_id>` keys per locale — one flavor sentence per foraging item. E.g. "Ви знайшли повалену сосну 🌲, ідеально придатну для обробки." for `mat.pine_lumber`.
- `ExplorationController.narrateOutcome` `.loot` case now picks the per-item flavor when present (Lingo returns the key verbatim on miss — we detect that and fall back to the pre-existing generic `exploration.outcome.loot.picked/full` template). When found, renders `<flavor>\n<b>+N ItemName</b>` for pickups and appends `<i>Сумка повна — лишається на землі.</i>` (new `exploration.outcome.loot.bag_full` key) for full-bag drops.
- Quantity is now `Int.random(in: 1...2)` — foraged stacks come in 1s or 2s rather than always 1.
- Foraging pool tightened to match the 8-item flavor list: shallow = forest_berries / forest_nuts / pine_lumber / river_pebble; medium = potato / duck_egg / clay / old_iron. `mat.hide` and `food.raw_meat` removed from the pool — both are now exclusively enemy-kill drops (semantically consistent with their lore descriptions).
- Encounter loot (`.encounterWon` drops from enemy kill tables) still uses the plain `exploration.outcome.loot.picked/full` template since those aren't "foraging finds".
- 9 new locale keys per locale (EN + UK, 205 total).

### Bestiary expansion (same session)
Pre-combat content pass — reshaped the roster around two thematic families:
- **Wild animals** (killable + cookable): 🐗 wild_boar / 🫎 wild_moose / 🦬 wild_buffalo — drop `food.raw_meat` + `mat.hide`
- **Rabid animals** (meat inedible, only hide): 🐈‍⬛ rabid_lynx / 🐺 rabid_wolf — drop `mat.hide` only

Removed: `enemy.rabid_hare` and `enemy.rabid_fox` (not in the user's new spec). Tier distribution maps to 5-km bands:
- T1 (km 1-5): boar
- T2 (km 6-10): boar + moose
- T3 (km 11-15): moose + buffalo + lynx
- T4 (km 16-20): buffalo + lynx + wolf

Stats ordered weakest → strongest: boar (hp 18 / atk 5 / def 1) → moose (32/8/2) → buffalo (55/11/4) → lynx (45/13/2 — glass cannon) → wolf (70/15/4 — top hostile). Each animal covers one or two consecutive tiers via its `depthRange`; wolf only spawns at tier 4. `mat.old_iron` was dropped from the wolf loot table to keep rabid drops hide-only per design.

Also updated the file header comment and 4 new/renamed locale keys per locale (enemy.wild_boar / wild_moose / wild_buffalo / rabid_lynx added, rabid_hare / rabid_fox removed, wolf unchanged). Total 207 per locale.

### Exploration outcome emoji → leading position (same session, 2026-04-23)
Cosmetic pass on 5 exploration narration keys to put decorative emoji at the START without breaking Lingo interpolation. New rule refinement uncovered during the fix:

**Lingo interpolation bug extends to BMP+VS16** (variation selector U+FE0F), not just surrogate-pair emoji. ⚔️ = ⚔ (U+2694) + VS16 = 2 UTF-16 units → breaks interpolation after it. ⚔ alone = 1 UTF-16 → SAFE. Single-UTF-16 BMP emojis (✨ ⚡ ❗ ❌ ⏳ ⭐ ⛔ ⛺ etc.) can all safely lead a string with placeholders. See `.memory/localization.md` for the refined rule + verified-safe set.

Changes applied:
- `exploration.outcome.trip`: trailing 🪨 → leading ❗
- `exploration.outcome.encounter.won`: trailing ⚔️ → leading ⚔ (no VS16, single UTF-16)
- `exploration.outcome.encounter.lost`: trailing 💀 → leading ❌
- `exploration.outcome.starvation`: trailing 🥀 → leading ⏳
- `exploration.death`: mid-message 💀 → leading ❌

User confirmed ⚔ without VS16 renders as colour emoji on iOS/Android/Telegram Web; only macOS Telegram shows it text-style — acceptable tradeoff. Surrogate-pair originals (🪨 💀 🥀) had no single-UTF-16 equivalent so were swapped to thematic single-UTF-16 alternatives rather than preserved at end.

Also flipped `resetDevProfile` back to `false` in `configure.swift` (dev profile state persists across restarts again).

No locale count change (207/207). No code changes — cosmetic strings only.
