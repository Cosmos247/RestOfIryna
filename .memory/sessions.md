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
- Localization changes per locale (EN + UK): added inventory.choose_category, inventory.back_root, inventory.action.food/potion/gear/artifact, inventory.info.placeholder, inventory.use.unavailable, hunger.restored, hp.restored, hunger.starving, consume.not_consumable, consume.no_effect, drain.usage, drain.success. Removed inventory.type.recipe, inventory.action.recipe, item.recipe.stew (recipe as an item type was folded away — blueprints will reappear as a separate concept in Phase 5.3 crafting).
- `ItemType.recipe` removed from the catalog/enum (only 5 types now: food, material, potion, gear, artifact). Seed replaces `recipe.stew × 1` with `artifact.shrine_coin × 1`.
- Dev inventory seed upgraded from "run once when empty" to "top-up per item + orphan cleanup": every startup cleans rows whose `item_id` is no longer in the catalog, then tops each seed entry up to its target quantity (never reduces). Rationale: after catalog changes (like removing recipes), stale DB rows linger and the old all-or-nothing seed never refills the new item. Per-item top-up also means consumed test items (e.g., eaten bread) come back on restart — handy for dev.
- Build fully green
