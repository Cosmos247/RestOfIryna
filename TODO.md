# ROI — Implementation Progress Tracker

**Legend:** `[ ]` not started | `[~]` in progress | `[x]` done | `[-]` skipped/deferred

---

## Phase 0: Foundation (Infrastructure & Scaffolding)

### 0.1 Core Infrastructure
- [x] Swift 6.2 project setup with SPM
- [x] Hummingbird HTTP server (health endpoint)
- [x] PostgreSQL + Fluent ORM integration
- [x] Telegram Bot (long polling via swift-telegram-sdk)
- [x] HummingbirdTGClient (AsyncHTTPClient-based)
- [x] Environment config (.env + SwiftDotenv)
- [x] Logging system

### 0.2 Bot Framework
- [x] Router-Controller state machine
- [x] RouterStore actor (thread-safe dispatch)
- [x] TGDispatcher (auth + global cmds + routing)
- [x] Context object (bot, db, lingo, session, args)
- [x] Command system (Commands enum, Command class)
- [x] ContentType matching (text, callback, media, etc.)
- [x] Arguments parser (Scanner-based)
- [x] Session caching (actor, 5min TTL, auto-cleanup)

### 0.3 Basic Controllers
- [x] RegistrationController — language selection
- [x] MainController — greeting, settings nav
- [x] SettingsController — language change
- [x] GlobalCommandsController — /help, /settings, /buttons

### 0.4 Localization
- [x] English (en.json)
- [x] Ukrainian (uk.json)
- [x] Lingo integration + SupportedLocale enum
- [x] Multi-locale button registration pattern

### 0.5 Project Tooling
- [x] .memory/ session-persistent knowledge base
- [x] CLAUDE.md AI assistant reference
- [x] TODO.md progress tracker
- [x] Prompt.me session primer

---

## Phase 1: Character System & Registration Rework

### 1.1 User Model Expansion
- [x] Add character stats fields (hp, max_hp, attack, defense, crit, dodge, accuracy)
- [x] Add level + XP fields
- [x] Add class field (warrior/archer/mage enum)
- [x] Add hunger fields (current_hunger, max_hunger)
- [x] Add gold currency field (premium currency name TBD — crowns removed until decided)
- [x] Create migration for new User fields (AddCharacterFields, AddProfileStyle, AddGameStats)
- [x] Update User model with applyStartingStats(for:) method

### 1.2 Registration Rework
- [x] Add class selection step after language (warrior/archer/mage with descriptions)
- [x] Set starting stats based on class choice
- [x] Add nickname input step (2-20 chars)
- [x] Add estate name input step (2-30 chars)
- [x] Create tutorial/onboarding message sequence — lore-driven 6-step registration (Artanian welcome → name → class → King's Oath → wolf encounter → estate naming)
- [x] Add localization keys for class names, descriptions, registration flow

### 1.3 Main Menu Rework
- [x] Add Profile button to main menu keyboard
- [x] Character profile view with 3 switchable display styles (inline buttons + message editing)
- [-] Show character status in main menu (HP, Hunger, Level, Gold) — deferred by user; stats shown in Profile view
- [x] Add navigation buttons: Explore, Estate, Capital (stub controllers for future phases)

---

## Phase 2: Hunger & Inventory Systems

### 2.1 Inventory Model
- [x] Design Item model (id, name, type, tier, stackable, effects) — code-based catalog in `Swift/Models/Item.swift`
- [x] Design Inventory model (user_id, item_id, quantity) — Fluent model in `Swift/Models/InventoryEntry.swift`
- [x] Create item type enum (food, material, gear, potion, recipe, artifact)
- [x] Create migrations for Inventory table (item catalog lives in code, not DB)
- [x] Implement inventory add/remove/has/totalQuantity/list helpers

### 2.2 Hunger System
- [~] Implement hunger drain on actions (configurable rates) — `HungerService.drain(_:action:)` ready; callers wired when Exploration/Combat ship (Phase 3/4)
- [~] Implement starvation penalties (stat reduction, HP drain, slow travel) — `effectiveAttack`/`effectiveDefense` apply −25% when starving; `applyStarvationHPLoss` ready; travel slowdown is Phase 3
- [x] Implement food consumption (restore hunger from inventory) — inline Use buttons in InventoryController + `HungerService.consume`
- [x] Add hunger display to status messages — profile shows 😵 Starving suffix when hunger is 0; effective ATK/DEF reflect penalty
- [x] Add localization keys for hunger states and food use

### 2.3 Equipment System
- [x] Design Equipment slots (helmet, chest, legs, boots, main-hand, off-hand, accessory x2) — `EquipmentSlot` enum + `GearStats` struct + slot/gearStats attached to all 4 starter gear items
- [x] Add equipped gear fields to User or separate EquippedGear model — `equipped_slot` column on `inventory` + 5 cached `gear_*_bonus` fields on `users`; migrations `AddEquipSlotToInventory` and `AddGearBonuses`; `recomputeGearBonuses` stub on User (real impl in 2.3.3)
- [x] Implement equip/unequip logic with stat recalculation — `EquipmentService` (pure-ish: touches DB for atomic slot swap + user save); `User.effective*` now read `base + gearBonus − hunger penalty`; registration auto-equips starter weapon
- [x] Create EquipmentController or integrate into ProfileController — integrated into `InventoryController` (gear-category rows toggle between 🛡 Equip and ❌ Unequip; each gear item carries a persistent per-item icon via `Item.icon`) + profile gets a "Main hand" line

---

## Phase 3: Exploration System

### 3.0 Inventory slot limit *(landed)*
- [x] Fixed 50-slot cap on `InventoryEntry` (equipped gear doesn't count; Workshop will raise it later)
- [x] `slotsUsed` / `canAccept` helpers; `add` throws `InventoryError.inventoryFull`
- [x] `WarehouseService.deposit/withdraw` return typed enum results (success / nothingToTransfer / inventoryFull on withdraw)
- [x] `EstateController.handleWarehouseTransfer` shows precise toast per failure mode (e.g. "backpack is full")
- [x] `/grant` dev cmd catches `.inventoryFull` and reports
- [x] Inventory root header shows `X/50 slots` indicator
- [x] 2 new locale keys per locale: `inventory.full`, `inventory.slots_label`

### 3.1 Active exploration MVP *(landed)*
- [x] ExplorationState model + migration (user_id unique, stepsDeep)
- [x] Enemy bestiary (code-based EnemyCatalog, 5 animals across 4 tiers — wild family: boar/moose/buffalo drops meat+hide; rabid family: lynx/wolf drops hide only)
- [x] ExplorationService.rollStep — weighted events (nothing 40 / loot 30 / encounter 25 / trip 5), depth-aware loot, autobattle stub for encounters, hunger/starvation integration
- [x] ExplorationController rewritten: step / bag (scoped to consumables) / return / death
- [x] Reply keyboard [🚶 Step] [🎒 Bag] [🔙 Return] while expedition is active
- [x] Death flow: wipe non-equipped inventory, respawn at HP=1, hunger preserved, end ExplorationState
- [x] Return flow: end ExplorationState, back to main with farewell message
- [x] Main/Inventory/Estate onExplore wired to `showExploration` (resume or begin)
- [x] ~20 new locale keys per locale (EN + UK) — expedition UI, outcome narratives, enemy names

### 3.2 Return path with per-room visit decay *(landed, reworked)*
- [x] `visited_rooms` JSON dict on `ExplorationState` (km → visit count) via migration `AddExplorationReturnState`
- [x] `ExplorationService.rollStep` takes `priorVisits: Int` and picks a three-tier weight table: fresh (20/40/30/10) → reduced (50/20/20/10) → bare (100/0/0/0 — only .nothing / .starvationOnly can fire)
- [x] Passive HP regen at estate (5%·maxHp per minute) via `HealingService.tick` fired on every interaction from `RouterStore.process`; `User.lastHpTickAt` pins the clock during expeditions and at full HP to prevent banked regen
- [x] Expedition reply keyboard: `[🚶 Step fwd] [🔙 Step back]` / `[🎒 Bag]` (no direction state)
- [x] Step Back decrements `stepsDeep`; at km 0 or 1 ends expedition with clean arrival (no event)
- [x] Each step records the entered room's visit; repeated entries escalate the decay tier
- [x] Three `.nothing` narrative variants (fresh / thinned / bare) keyed on prior visit count
- [x] `/start` + stray Cancel button = force-end (no walk-back) — dev escape hatch
- [ ] Event-snapshot per room (future: remember *what* happened in each room for richer return narration)

### 3.3 Passive timed expeditions *(MVP landed in test mode)*
Design note: the 5-min room transition is **passive-mode-only**. Active reconnaissance (3.1/3.2) is fully tap-driven — no timer, no gating.
- [x] `AddPassiveExpeditionFields` migration adds `mode` / `ends_at` / `report_json` to `exploration_state`
- [x] `ExplorationMode` enum + helpers on `ExplorationState` (isPassive / hasReadyReport / secondsRemaining)
- [x] `PassiveExpeditionService` — duration enum (30/60/90 units), `testMode` flag (seconds vs minutes), `start` + detached `Task.sleep` scheduler, `simulate` reusing `ExplorationService.rollStep` with priorVisits=0, `PassiveReport` JSON blob, full report rendering, startup `rescheduleInflight`
- [x] `ExplorationController` mode picker [🏃 Розвідка / 🏕 Експедиція] as first screen when no state; duration picker edits message in place; countdown status for inflight; report delivery on re-open
- [x] Background push — the detached task sends the report message directly to the player's chat when the timer fires
- [x] Startup rescheduler in `configure.swift` picks up in-flight passive expeditions across bot restarts
- [ ] Flip `testMode` to `false` once balance + UX validated (swap units from seconds to minutes)
- [ ] Per-user daily expedition budget (2h, rolls over at server midnight)
- [ ] Early-cancel button for in-flight passive

### 3.4 Mode exclusivity *(landed)*
- [x] Data-layer exclusivity inherited from `exploration_state` unique(user_id) — one row per player regardless of mode
- [x] `showExploration` branches (passive in-flight → countdown; passive with report → deliver; active → resume; none → mode picker) — UI can't offer mode picker while a state exists
- [x] Main menu reply keyboard swaps `🗺 Explore` → `🕒 On expedition` via `User.transientInExpedition` (refreshed by `RouterStore.process` every dispatch). Tapping the busy label still leads to `showExploration` which shows the countdown/report.
- [x] Busy label registered in Main / Estate / Inventory routers so pass-through works from any screen
- [x] Idempotency guards on `explore:mode:active` / `explore:mode:passive` / `explore:dur:*` — stale picker taps redirect to `showExploration` instead of silently overwriting an existing expedition
- [x] Estate + Capital entry guarded — "governor is away" notice, no routerName transition. Both controllers now own their routerName transition so blocking is clean.
- [x] Explicit flag resets in end-paths (home-reached / force-end / death / passive report delivery) so the reply keyboard rebuilds with the normal label in that same response

### 3.5 Content expansion (post-MVP)
- [ ] Expanded event pool ("hidden cache / shrine", "dungeon entrance every 7th room", rare events)
- [ ] More enemy tiers (T2-T4 + Boss) and biome variety
- [ ] Flavor text pools per outcome

---

## Phase 4: Combat System

### 4.1 Interactive PvE combat MVP *(landed)*

Turn-based "Standoff" duel triggered when active-mode `rollStep` rolls an encounter. Passive expeditions keep using `ExplorationService.resolveAutobattle`. Class identity comes from existing stat differences + class-flavoured button labels (mechanics are identical; class-specific techniques are deferred to 4.2).

- [x] Migration `AddCombatFields` — nullable `combat_enemy_id: String` + `combat_enemy_hp: Int` on `exploration_state`. Embedded: combat lives inside the active expedition row; both columns null = not in combat.
- [x] `ExplorationState` Fluent fields + helpers (`isInCombat`, `beginCombat(enemyId:hp:)`, `endCombat()`).
- [x] `CombatService.applyAttack(...)` returning `AttackOutcome (miss / hit / crit)`. `hitChance = clamp(70 + acc − dodge, 10, 95)%`; on hit `critChance = crit %`, ×1.5 crit multiplier; damage `max(1, (atk − def) * variance[0.9..1.1] * critMult)`. `chipDamage` for Defend's 30%-of-base parry-counter (always lands, no crit). `resolveAutobattle` refactored onto the same primitives so passive autobattle gains crit / dodge / accuracy semantics for free.
- [x] `StepOutcome.encounterStarted(Enemy)` + `rollStep(mode:)`. Active `rollStep` returns it; `ExplorationController.handOffToCombat` stamps the combat fields, flips `routerName = "combat"`, calls `CombatController.showCombat`. Passive `runLive` passes `mode: .passive` so it keeps the autobattle path.
- [x] `CombatController.swift` with class-flavoured `[Attack] [Defend] / [Flee]` keyboard, hunger costs (2 / 1 / 3), DEF×2 on Defend, 50/50 flee with forced full-damage counter on fail, victory loot via `awardEncounterDrops`, defeat via shared static `ExplorationController.handleDeath(causeNarrative:)`. `EnemyCatalog.find(_:)` helper for rehydration. `HungerAction` gained `combatAttack / combatDefend / combatFlee` cases (kept `combatRound` for autobattle).
- [x] Registration wolves fight (step 4) routes through CombatController too — `Registration.handleCombatEnd(won:)` is the registration-specific end path. Soft retry on defeat / flee / `/start` (full HP heal, re-show wolves prompt). Victory advances to estate naming. Estate-name prompt and the wolves-retry preamble both ship `ReplyKeyboardRemove` so combat-button labels can't be entered as the estate name.
- [x] Locale keys: 9 button labels (3 actions × 3 classes) + 11 narratives (encounter.intro, you.{hit,crit,miss}, enemy.{hit,crit,miss}, defend.absorbed, flee.{success,fail}, victory, defeat) + 2 registration keys (fight_wolves, wolves_retry). 214 → 236 per locale.
- [x] Build clean, en/uk parity.

### 4.2 Class-specific techniques *(landed 2026-04-27)*

All 9 class techniques across all 3 classes are wired up. Submenu UX, per-fight budget, persistent effects, and stance/special-attack/special-defense composition all working.

#### Warrior (Knight)
- [x] **Розкол** *(Cleave)* — Special Attack. −10% hit chance, ignores enemy DEF entirely, +12 flat damage, +20 crit. Risky high-impact swing. 4 hunger.
- [x] **Залізна стіна** *(Iron Bulwark)* — Special Defense. Full block + 50%-of-clean-hit chip damage + persistent armor-split debuff that zeroes enemy DEF for the next swing. 3 hunger.
- [x] **Кровна жага** *(Bloodlust)* — Super stance, 3 rounds. +5 ATK, +3 DEF, ×2 hunger drain while active. 4 hunger to activate.

#### Archer
- [x] **Влучний постріл** *(Vital Shot)* — Special Attack. Cannot miss, +20 crit, ignores DEF. Tradeoff: long aim zeroes player dodge for the enemy counter. 4 hunger.
- [x] **Тінь лісу** *(Shadow Veil)* — Special Defense. Full dodge this round + lingering +50 dodge next round. 3 hunger.
- [x] **Око сокола** *(Hawk's Eye)* — Super stance, 3 rounds. +15 crit, +10 accuracy, +10 dodge. 4 hunger.

#### Mage
- [x] **Полум'я душі** *(Soulfire)* — Special Attack. Cannot miss, ignores DEF, +5 flat damage. 5 hunger.
- [x] **Дзеркальний щит** *(Mirror Ward)* — Special Defense. Full block + reflects 50% of would-be enemy damage back at them. 4 hunger.
- [x] **Магічний резонанс** *(Arcane Resonance)* — Super stance, 3 rounds. ATK ×1.5, +5 DEF. 5 hunger to activate (concentration burn).

#### Shared infrastructure
- [x] Migration `AddCombatStanceFields` — `combat_stance` + `combat_stance_rounds_left`
- [x] Migration `AddCombatDefenseFields` — `combat_enemy_def_debuff` + `combat_player_dodge_buff`
- [x] Migration `AddCombatTechniqueUses` — `combat_special_atk_uses` (max 2) + `combat_special_def_uses` (max 2) + `combat_super_uses` (max 1)
- [x] `[🪄 Techniques]` submenu opens edit-in-place via `editMessageReplyMarkup`; rebuilds from live state so spent buttons hide and remaining show " × N" suffix
- [x] `CombatService` extended with `AttackModifiers` (folded into `applyAttack`), `StanceModifiers`, `SpecialAttack` / `SpecialDefense` namespaces
- [x] `HungerService.drain(_:action:multiplier:)` accepts optional multiplier so stance buffs scale per-action drain
- [x] 32 new locale keys per locale (techniques submenu + 3 supers + 3 special atks + 3 special defs + status indicators + no-uses toast); `combat.special_def.archer.no_target` removed (unused)
- [x] Lingo emoji-prefix gotcha — every Phase 4.2 narrative string stored emoji-free; CombatController prepends class-flavoured icons in Swift
- [x] Class-specific Flee chances: knight 40% / archer 70% / mage 90% (mage pays extra +2 hunger for the teleport, layered on top of the stance multiplier) — *landed 4.3.1*
- [ ] Unlock-by-level wiring — *deferred until the leveling system lands*

### 4.3 Combat polish

- [x] **4.3.1 Class-specific Flee chances** — landed. `CombatService.fleeChance(forClass:)` + `fleeHungerExtra(forClass:)`; warrior 40 / archer 70 / mage 90; mage pays +2 hunger.
- [-] **4.3.2 Edit single message in-place per round** — *deferred by user; preference is to keep all combat logs visible as separate messages*
- [-] **4.3.3 XP grant on victory** — *deferred; XP system will be re-designed during Phase 5 to feed estate progression directly (player XP → estate level), not character level. Phase 5.0's "estate level computed from `user.level`" derivation will be replaced once the new XP-to-Estate model lands.*
- Status effects (rabies from rabid family, cured at chapel) — *moved to Future / Backlog (Phase 6 dependency)*
- Per-enemy AI hooks (aggression, fleeResist) — *moved to Future / Backlog*
- Combat log persistence + replay — *moved to Future / Backlog (Arena dependency)*

### 4.4 Bestiary expansion *(landed)*
- [x] T1–T4 enemy roster (5 animals, wild + rabid families) — see `Swift/Models/Enemy.swift`
- [x] T5 regular mob added: **wild_bear** 🐻 (km 21–30; rabid_wolf range extended to 16–25 so the families share the 21–25 overlap; HP 95 / ATK 17 / DEF 5, drops meat ×2 + hide ×1)
- [x] T6 regular mob added: **rabid_bear** 🐻‍❄️ (km 25–35; overlaps with wild_bear at 25–30, alone at 31–35; HP 120 / ATK 22 / DEF 4 — rabid family pattern, drops hide ×2 only)
- [-] T5 *boss* tier — *deferred to Phase 3.5* once the boss-fight mechanics are designed (separate from regular mobs)
- [x] Create `content/bestiary.md` reference document

### 4.5 PvP combat *(later phase)*
- [ ] Challenge system
- [ ] 30-second per-round timer (timeout = Defend)
- [ ] Mutual Auto = instant resolution
- [ ] Arena integration (separate from territorial PvP)

---

## Phase 5: Estates & Crafting *(started out of order — while Phase 3/4 were paused)*

> **XP-to-Estate redesign (planned during Phase 5.x):** the current `User.estateLevel` derivation (every 5 player levels → +1 estate level) will be replaced. New direction: combat / exploration XP feeds the **estate** progression directly instead of a character level. The `User.level` / `User.xp` fields stay (or get repurposed) but stop being the source of truth for estate tier. Concrete migration path will be locked once estate plot/crafting needs are clearer.

### 5.0 Estate navigation skeleton *(landed)*
- [x] Estate level computed from `user.level` (every 5 player levels → +1 estate level)
- [x] `EstateController` tree nav: Root (image placeholder + text + level) → [🏠 House] / [🌾 Plot]
- [x] House drill-down with stubs for [🛠 Workshop] [🍳 Kitchen] [📦 Warehouse]
- [x] Per-level artwork loader (`Assets/estate/level_<N>.jpg`, text-only fallback)
- [x] Photo/text edit-mode switch in callback handler (editMessageCaption vs editMessageText)
- [x] Main-nav pass-through on EstateController's router (main reply keyboard stays reachable)
- [x] Warehouse: real storage — `WarehouseEntry` Fluent model (separate table from `inventory`), category root with live counts, per-category drill-down with item list. Dev seed mirrors the inventory seed set.
- [x] Warehouse deposit/withdraw: `WarehouseService` moves one unit per tap. Category drill-down renders each distinct item as `[Name] [N ⬆️] [M ⬇️]` — deposit from inventory / withdraw to inventory. Union of inventory + warehouse items; equipped gear is excluded from transferable inventory count. Toast feedback, in-place refresh.

### 5.1 Plot system *(landed 2026-04-30)*

Pragmatic MVP path — abstract per-user plot list (no 30×30 spatial grid yet; that's deferred to Phase 7 territorial PvP design). Plus a Training Ground non-producing plot that opens a sparring fight with a dummy.

- [x] `Plot` Fluent model + `CreatePlots` migration (user_id FK, slot_index, plot_type, tier, last_harvested_at, notified_full)
- [x] `PlotCatalog` code-based config (5 types: Farm 🌾 / Lumberyard 🪚 / Mine ⛏ / Coop 🐔 / Training Ground 🥋); `PlotTuning` with optional `bonusOutput` for Mine's iron-alongside-pebble drop
- [x] `PlotService` helpers (lazy `accumulated` / `bonusAccumulated`, `harvest` deposits to **WarehouseEntry**, `claim` validates slot allowance, `slotsForLevel` — currently flat 5 override pending XP-to-Estate)
- [x] `PlotProductionService` background ticker (single Task.detached, 60s test / 300s prod, pushes "🌾 ready to harvest" message when cap reached, `notified_full` flag suppresses repeats)
- [x] EstateController plot drill-down (slot list, claim picker, harvest, training entry); inline status banners on harvest with current/cap on both primary and bonus
- [x] Training Ground combat mode (clean damage, no hunger drain, no enemy counter, dummy auto-revives, routerName stays at "estate" so reply-keyboard nav unblocked, `combat:*` callback forwarding from Main / Inventory / Estate / Settings)
- [x] Initial farm grant at registration completion (slot 0 = farm)
- [x] Iron resource overhaul: `mat.iron` (Iron Lump 🔩, raw — foraging + Mine bonus) + `mat.iron_ingot` (Iron Ingot 🔳, placeholder for Phase 5.x Workshop crafting); legacy `mat.old_iron` retired with `RemoveOldIron` data migration
- [x] Foraging pool → weighted (`pickWeighted` helper); iron weight 2 vs 10 staples = ~5% medium-zone drop
- [-] 30×30 spatial estate grid — *deferred until Phase 7 territorial PvP design*
- [-] Manor 7×7 interior rooms — *deferred; current model uses abstract House nav*
- [-] Slot count formula → logarithmic table — *currently flat 5 override; restore once XP-to-Estate progression lands*

### 5.2 Workshop crafting *(in progress)*
- [x] `Recipe` code-based catalog (id, category, inputs, output) — `Swift/Models/Recipe.swift`. Two categories shipped: 🔥 Forge (smelting) + 🧵 Tannery (leather armor)
- [x] `CraftingService.craft(...)` — pure: pulls inputs from inventory + warehouse pool (inventory first to free slots), output lands in inventory; `CraftResult` enum (success / missingMaterials / inventoryFull / unknownRecipe / unknownItem); post-drain slot accept-check so a craft never refuses spuriously
- [x] First recipe: `mat.iron × 10 → mat.iron_ingot × 1` (Forge)
- [x] Forester's leather set (Tannery) — 4 pieces consuming hide only:
  - 🪖 Forester's Hood (helmet, +1 DEF) — 2× hide
  - 🦺 Forester's Jerkin (chest, +3 DEF) — 6× hide *(replaces retired `gear.leather_vest` via `RenameLeatherVest` migration)*
  - 👖 Forester's Breeches (legs, +2 DEF) — 5× hide
  - 🥾 Forester's Boots (boots, +1 DEF, +1 dodge) — 3× hide
  Full set = 16 hide for +7 DEF / +1 dodge
- [x] Workshop UI in EstateController (replaces stub) — section header per category, recipe block with `🎒 inv + 📦 wh = total/need ✅|❌` per ingredient, one `[🔨 RecipeName]` button per recipe; success → inline status banner above refreshed view, shortages → modal alert listing missing inputs, bag full → modal alert
- [x] `RenameLeatherVest` migration — remaps existing `gear.leather_vest` rows in inventory + warehouse to `gear.forester_jerkin`
- [x] **Phase 5.2.1 — Kitchen cooking** (seven dishes spanning 1-5 ingredients, two starters always-available, five unlocked via recipe scrolls)
  - `RecipeCategory.kitchen` (3rd category) gated by per-user `LearnedRecipe` set; Forge / Tannery still always available
  - 7 dishes added to `ItemCatalog` (Baked Potato / Roasted Meat = 1 ingredient, Forager's Omelette / Hunter's Stew / Meat Ragout / Forest Berry Tart = 3 ingredients, Governor's Feast = 5 ingredients)
  - 5 recipe scrolls added for the non-starter dishes (`artifact.recipe.<dish_id>`, non-stackable, `📜` icon, lore description); using one teaches the recipe via the new "📖 Learn" action button (replaces "✨ Use" when `item.teachesRecipe != nil`)
  - **Baked Potato + Roasted Meat have no scrolls** — they're always-available starters listed in `RecipeCatalog.starterRecipeIds` (a `Set<String>`); the Kitchen UI unions this with the player's learned set so every player can cook them from day one with no DB row needed
  - New `LearnedRecipe` Fluent model + `CreateLearnedRecipes` migration (per-user known-recipe set, unique on user_id+recipe_id) for the five scroll-locked recipes
  - Kitchen UI in EstateController mirrors Workshop (compact list → detail screen with Recipe + Effects sections + `[🍳 Cook]` / `[🔙 Back]`)
  - Dev seed bumped (5× of every cooking ingredient, all 5 scroll-locked recipes)
- [ ] Weapon upgrade flow (Phase 5.2.2) — modify existing weapon vs craft new one
- [ ] Future: blueprint learning (recipe unlocks via drops / purchases) — defer until base crafting is solid
- [x] Create `content/recipes.md` reference doc

### 5.3 XP-to-Estate progression *(planned)*
- [ ] Replace `User.estateLevel = User.level / 5` derivation with a real model — combat / exploration awards estate XP directly (not character level)
- [ ] Decide: keep `User.xp` / `User.level` as the source of truth (renamed conceptually) or add a new `Estate` model with its own xp/level
- [ ] Wire estate-XP grants from combat victory + exploration completions
- [ ] Tune the level-up curve once the basic loop is in
- [ ] Restore `PlotService.slotsForLevel` to use the logarithmic table (currently flat 5)
- [ ] Hook unlock-by-level for Phase 4.2 techniques (currently all available from start)

### 5.4 Estate Placement *(deferred)*
- [-] 30×30 spatial estate grid — *deferred; needed for territorial PvP design in Phase 7+*
- [-] Frontier-based placement for new players — *same*
- [-] 8-neighbor adjacency queries — *same*

---

## Phase 6: Economy & Capital

### 6.1 Market System
- [ ] Design MarketListing model (seller, item, price, quantity, expiry)
- [ ] Implement NPC stall (fixed prices, buy/sell)
- [ ] Implement player bazaar (listing, purchasing, expiry)
- [ ] Implement listing fee (gold sink)

### 6.2 MarketController
- [ ] Create controller with browse/search/buy/sell UI
- [ ] Implement NPC vs Player stall navigation
- [ ] Implement purchase flow with confirmation

### 6.3 Capital Hub
- [ ] Create CapitalController with location menu
- [ ] Implement Quest Board (daily/weekly quests)
- [ ] Implement Stables (fast travel, gold cost)
- [ ] Implement Bank (personal vault, transfers)
- [ ] Implement Chapel (respec, name change)

---

## Phase 7: Social Systems

### 7.1 Guild System
- [ ] Design Guild model (name, banner, vault, members)
- [ ] Design GuildMembership model (user_id, guild_id, role)
- [ ] Create GuildController (create, join, manage, chat)
- [ ] Implement guild vault (shared storage)
- [ ] Implement non-aggression pacts

### 7.2 Territorial Warfare
- [ ] Implement territorial challenge initiation (adjacent only)
- [ ] Implement win/loss counter per attacker-defender pair
- [ ] Implement tile loss on 10 consecutive losses
- [ ] Implement cooldown between challenges
- [ ] Implement counter reset on defender win

### 7.3 Player Interaction
- [ ] Implement estate visiting (/visit @username)
- [ ] Implement direct trading (two-player confirmation)
- [ ] Implement player search/lookup

---

## Phase 8: Pets & Arena

### 8.1 Pet System
- [ ] Design Pet model (species, stats, level, bond, role)
- [ ] Implement taming mechanic (cure button, success chance)
- [ ] Create PetController (manage, assign, train)
- [ ] Implement passive buffs from active pet
- [ ] Implement worker pets (estate plot bonus)

### 8.2 Pet Battles
- [ ] Implement pet-vs-pet combat mode
- [ ] Implement pet XP and leveling
- [ ] Pet leagues (ranked ladder) — may defer to post-v1

### 8.3 Arena
- [ ] Create ArenaController
- [ ] Implement 1v1 matchmaking (ELO-based)
- [ ] Implement ranked + unranked queues
- [ ] Implement arena rewards (gold, tokens, leaderboards)

---

## Phase 9: Content & Polish

### 9.1 Tuning & Balance
- [ ] Create `content/tuning.md` — XP curves, hunger scaling, stat growth
- [ ] Balance damage formula through playtesting
- [ ] Tune exploration event weights per depth
- [ ] Tune hunger drain vs food availability
- [ ] Balance economy (gold sinks vs sources)

### 9.2 Content Authoring
- [ ] Full bestiary (all enemy types with stats and loot)
- [ ] Full recipe book (all crafting tiers)
- [ ] Quest definitions (tutorial + daily/weekly)
- [ ] Flavor text pools for exploration events
- [ ] Achievement/milestone definitions

### 9.3 Localization Expansion
- [ ] Game strings for all new controllers/features (EN + UK)
- [ ] Class descriptions, item names, enemy names
- [ ] Combat log text, event descriptions
- [ ] Consider additional language support

### 9.4 Scale & Performance
- [ ] Load testing with simulated concurrent users
- [ ] Redis/in-memory actor for PvP combat state
- [ ] Telegram rate limit batching for guild announcements
- [ ] Database query optimization and indexing
- [ ] Message edit strategy for combat (reduce message spam)

---

## Phase 10: Monetization & Launch Prep

### 10.1 Premium Currency
- [ ] Design crown purchase flow
- [ ] Implement crown balance and spending
- [ ] Premium cosmetics system
- [ ] Convenience items (slot expansions, speed-ups)

### 10.2 Launch Preparation
- [ ] Remove hardcoded allowedUsers for public access
- [ ] Webhook mode for production (replace long polling)
- [ ] Production deployment setup
- [ ] Admin tools (ban, announce, debug commands)
- [ ] Monitoring and alerting

---

## Future / Backlog *(reviewed before / after release)*

A parking lot for "interesting but not critical" ideas — collected as the project grows, revisited just before launch (or right after, depending on signal). Items here are not on the active roadmap; they will be promoted into a phase if/when they make sense.

- **Per-enemy AI hooks** *(was 4.3.4)* — add `aggression: Int` (0–100, biases enemies toward Attack vs Defend) and `fleeResist: Int` (0–100, makes the fail roll on Flee harsher) to `Enemy`. Threaded into passive autobattle and active combat's Flee resolution. Cheap once the data is in `EnemyCatalog`; main work is per-tier tuning.
- **Status effects (rabies)** *(was 4.3.5)* — bites from the rabid family (`enemy.rabid_lynx`, `enemy.rabid_wolf`) carry a chance to infect. Effect ticks over time (HP drain, stat penalty, hunger drain — TBD), persists across expeditions, cured at the Capital Chapel (Phase 6 dependency). Needs a generic status-effect system on `User` or a new model.
- **Combat log persistence + replay** *(was 4.3.6)* — record round-by-round combat events (damage rolls, hit/miss, technique uses, stance state) into a Codable blob; expose a "view replay" surface. Mostly useful once the Arena (Phase 8) lands, since solo PvE replays have low replay value.
- *(more items will be added by user as the project grows)*

---

*Last updated: 2026-04-30 — Phases 0-2 complete; Phase 3 MVP done; Phase 4.1+4.2+4.3.1+4.4 combat done (4.3.2/4.3.3 deferred, 4.3.4-6 in Future Backlog); Phase 5.0 estate skeleton + warehouse + Phase 5.1 plot system + Training Ground + iron resource overhaul all landed. Spatial 30×30 grid (5.4) deferred to Phase 7 PvP. Next: Phase 5.2 Workshop / Kitchen crafting (first recipe `mat.iron × 10 → mat.iron_ingot × 1`); Phase 5.3 XP-to-Estate progression (replaces current `User.estateLevel = User.level / 5` derivation).*
