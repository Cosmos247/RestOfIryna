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
- [x] Prompt.md session primer

---

## Phase 1: Character System & Registration Rework

### 1.1 User Model Expansion
- [x] Add character stats fields (hp, max_hp, attack, defense, crit, dodge, accuracy)
- [x] Add level + XP fields
- [x] Add class field (warrior/archer/mage enum)
- [x] Add vigor fields (current_vigor, max_vigor)
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
- [-] Show character status in main menu (HP, Vigor, Level, Gold) — deferred by user; stats shown in Profile view
- [x] Add navigation buttons: Explore, Estate, Capital (stub controllers for future phases)

---

## Phase 2: Vigor & Inventory Systems

### 2.1 Inventory Model
- [x] Design Item model (id, name, type, tier, stackable, effects) — code-based catalog in `Swift/Models/Item.swift`
- [x] Design Inventory model (user_id, item_id, quantity) — Fluent model in `Swift/Models/InventoryEntry.swift`
- [x] Create item type enum (food, material, gear, potion, recipe, artifact)
- [x] Create migrations for Inventory table (item catalog lives in code, not DB)
- [x] Implement inventory add/remove/has/totalQuantity/list helpers

### 2.2 Vigor System
- [~] Implement vigor drain on actions (configurable rates) — `VigorService.drain(_:action:)` ready; callers wired when Exploration/Combat ship (Phase 3/4)
- [~] Implement starvation penalties (stat reduction, HP drain, slow travel) — `effectiveAttack`/`effectiveDefense` apply −25% when starving; `applyStarvationHPLoss` ready; travel slowdown is Phase 3
- [x] Implement food consumption (restore vigor from inventory) — inline Use buttons in InventoryController + `VigorService.consume`
- [x] Add vigor display to status messages — profile shows 😵 Starving suffix when vigor is 0; effective ATK/DEF reflect penalty
- [x] Add localization keys for vigor states and food use

### 2.3 Equipment System
- [x] Design Equipment slots (helmet, chest, legs, boots, main-hand, off-hand, accessory x2) — `EquipmentSlot` enum + `GearStats` struct + slot/gearStats attached to all 4 starter gear items
- [x] Add equipped gear fields to User or separate EquippedGear model — `equipped_slot` column on `inventory` + 5 cached `gear_*_bonus` fields on `users`; migrations `AddEquipSlotToInventory` and `AddGearBonuses`; `recomputeGearBonuses` stub on User (real impl in 2.3.3)
- [x] Implement equip/unequip logic with stat recalculation — `EquipmentService` (pure-ish: touches DB for atomic slot swap + user save); `User.effective*` now read `base + gearBonus − vigor penalty`; registration auto-equips starter weapon
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
- [x] ExplorationService.rollStep — weighted events (nothing 40 / loot 30 / encounter 25 / trip 5), depth-aware loot, autobattle stub for encounters, vigor/starvation integration
- [x] ExplorationController rewritten: step / bag (scoped to consumables) / return / death
- [x] Reply keyboard [🚶 Step] [🎒 Bag] [🔙 Return] while expedition is active
- [x] Death flow: wipe non-equipped inventory, respawn at HP=1, vigor preserved, end ExplorationState
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
- [x] `CombatController.swift` with class-flavoured `[Attack] [Defend] / [Flee]` keyboard, vigor costs (2 / 1 / 3), DEF×2 on Defend, 50/50 flee with forced full-damage counter on fail, victory loot via `awardEncounterDrops`, defeat via shared static `ExplorationController.handleDeath(causeNarrative:)`. `EnemyCatalog.find(_:)` helper for rehydration. `VigorAction` gained `combatAttack / combatDefend / combatFlee` cases (kept `combatRound` for autobattle).
- [x] Registration wolves fight (step 4) routes through CombatController too — `Registration.handleCombatEnd(won:)` is the registration-specific end path. Soft retry on defeat / flee / `/start` (full HP heal, re-show wolves prompt). Victory advances to estate naming. Estate-name prompt and the wolves-retry preamble both ship `ReplyKeyboardRemove` so combat-button labels can't be entered as the estate name.
- [x] Locale keys: 9 button labels (3 actions × 3 classes) + 11 narratives (encounter.intro, you.{hit,crit,miss}, enemy.{hit,crit,miss}, defend.absorbed, flee.{success,fail}, victory, defeat) + 2 registration keys (fight_wolves, wolves_retry). 214 → 236 per locale.
- [x] Build clean, en/uk parity.

### 4.2 Class-specific techniques *(landed 2026-04-27)*

All 9 class techniques across all 3 classes are wired up. Submenu UX, per-fight budget, persistent effects, and stance/special-attack/special-defense composition all working.

#### Warrior (Knight)
- [x] **Розкол** *(Cleave)* — Special Attack. −10% hit chance, ignores enemy DEF entirely, +12 flat damage, +20 crit. Risky high-impact swing. 4 vigor.
- [x] **Залізна стіна** *(Iron Bulwark)* — Special Defense. Full block + 50%-of-clean-hit chip damage + persistent armor-split debuff that zeroes enemy DEF for the next swing. 3 vigor.
- [x] **Кровна жага** *(Bloodlust)* — Super stance, 3 rounds. +5 ATK, +3 DEF, ×2 vigor drain while active. 4 vigor to activate.

#### Archer
- [x] **Влучний постріл** *(Vital Shot)* — Special Attack. Cannot miss, +20 crit, ignores DEF. Tradeoff: long aim zeroes player dodge for the enemy counter. 4 vigor.
- [x] **Тінь лісу** *(Shadow Veil)* — Special Defense. Full dodge this round + lingering +50 dodge next round. 3 vigor.
- [x] **Око сокола** *(Hawk's Eye)* — Super stance, 3 rounds. +15 crit, +10 accuracy, +10 dodge. 4 vigor.

#### Mage
- [x] **Полум'я душі** *(Soulfire)* — Special Attack. Cannot miss, ignores DEF, +5 flat damage. 5 vigor.
- [x] **Дзеркальний щит** *(Mirror Ward)* — Special Defense. Full block + reflects 50% of would-be enemy damage back at them. 4 vigor.
- [x] **Магічний резонанс** *(Arcane Resonance)* — Super stance, 3 rounds. ATK ×1.5, +5 DEF. 5 vigor to activate (concentration burn).

#### Shared infrastructure
- [x] Migration `AddCombatStanceFields` — `combat_stance` + `combat_stance_rounds_left`
- [x] Migration `AddCombatDefenseFields` — `combat_enemy_def_debuff` + `combat_player_dodge_buff`
- [x] Migration `AddCombatTechniqueUses` — `combat_special_atk_uses` (max 2) + `combat_special_def_uses` (max 2) + `combat_super_uses` (max 1)
- [x] `[🪄 Techniques]` submenu opens edit-in-place via `editMessageReplyMarkup`; rebuilds from live state so spent buttons hide and remaining show " × N" suffix
- [x] `CombatService` extended with `AttackModifiers` (folded into `applyAttack`), `StanceModifiers`, `SpecialAttack` / `SpecialDefense` namespaces
- [x] `VigorService.drain(_:action:multiplier:)` accepts optional multiplier so stance buffs scale per-action drain
- [x] 32 new locale keys per locale (techniques submenu + 3 supers + 3 special atks + 3 special defs + status indicators + no-uses toast); `combat.special_def.archer.no_target` removed (unused)
- [x] Lingo emoji-prefix gotcha — every Phase 4.2 narrative string stored emoji-free; CombatController prepends class-flavoured icons in Swift
- [x] Class-specific Flee chances: knight 40% / archer 70% / mage 90% (mage pays extra +2 vigor for the teleport, layered on top of the stance multiplier) — *landed 4.3.1*
- [ ] Unlock-by-level wiring — *deferred until the leveling system lands*

### 4.3 Combat polish

- [x] **4.3.1 Class-specific Flee chances** — landed. `CombatService.fleeChance(forClass:)` + `fleeVigorExtra(forClass:)`; warrior 40 / archer 70 / mage 90; mage pays +2 vigor.
- [-] **4.3.2 Edit single message in-place per round** — *deferred by user; preference is to keep all combat logs visible as separate messages. Moot since the 2026-05-27 reply-keyboard switch (combat actions are now reply-keyboard buttons that replace the main keyboard; every action re-sends a message).*
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

> **XP-to-Estate redesign — DROPPED (decided 2026-06-16).** Was: replace the player-level-driven estate progression with XP feeding estate tier directly. No longer pursued — the current model is the intended one: XP → player level → player-level gate on manual `EstateUpgradeService.upgrade`. That already makes "experience advances the estate" true enough. Do not resurrect this redesign.

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
- [x] Training Ground combat mode (clean damage, no vigor drain, no enemy counter, dummy auto-revives). *2026-05-27: with the combat reply-keyboard switch, `handleTrainingSpar` now flips routerName to "combat" (was "estate"); `onTrainingExit` restores routerName + the estate keyboard. The `combat:*` callback forwarding from Main / Inventory / Estate / Settings is now just a stale-button safety net.*
- [x] Initial farm grant at registration completion (slot 0 = farm)
- [x] Iron resource overhaul: `mat.iron` (Iron Lump 🔩, raw — foraging + Mine bonus) + `mat.iron_ingot` (Iron Ingot 🔳, placeholder for Phase 5.x Workshop crafting); legacy `mat.old_iron` retired with `RemoveOldIron` data migration
- [x] Foraging pool → weighted (`pickWeighted` helper); iron weight 2 vs 10 staples = ~5% medium-zone drop
- [-] 30×30 spatial estate grid — **removed from the roadmap (2026-05-18).** User explicitly closed this design direction; the abstract slot-index Plot model is the final design, NOT a placeholder. Do not propose this as a future feature. See line further down ("do not resurrect this approach") for the long-form rationale.
- [-] Manor 7×7 interior rooms — *deferred; current model uses abstract House nav*
- [-] Slot count formula → logarithmic table — *currently flat 5 override; restore once XP-to-Estate progression lands*

### 5.2 Workshop crafting *(landed — Forge + Tannery + 5.2.1 Kitchen + 5.2.2 Weapon upgrade; bag upgrade lives in 5.3d)*
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
  - 7 dishes added to `ItemCatalog` (Baked Potato / Roasted Meat = 1 food ingredient, Forager's Omelette / Hunter's Stew / Meat Ragout / Forest Berry Tart = 3, Governor's Feast = 5). **Every kitchen recipe also burns 1× 🪵 pine_lumber for the cooking fire** — authenticity + soft farm-cooking cap; lumber sourced from Lumberyard plot or shallow-zone foraging
  - Kitchen-specific success banner ("Cooked ..." / "Приготовано ...") via `RecipeCategory.craftedAlertKey` — Workshop keeps "Crafted ..." / "Викувано ..."
  - 5 recipe scrolls added for the non-starter dishes (`artifact.recipe.<dish_id>`, non-stackable, `📜` icon, lore description); using one teaches the recipe via the new "📖 Learn" action button (replaces "✨ Use" when `item.teachesRecipe != nil`)
  - **Baked Potato + Roasted Meat have no scrolls** — they're always-available starters listed in `RecipeCatalog.starterRecipeIds` (a `Set<String>`); the Kitchen UI unions this with the player's learned set so every player can cook them from day one with no DB row needed
  - New `LearnedRecipe` Fluent model + `CreateLearnedRecipes` migration (per-user known-recipe set, unique on user_id+recipe_id) for the five scroll-locked recipes
  - Kitchen UI in EstateController mirrors Workshop (compact list → detail screen with Recipe + Effects sections + `[🍳 Cook]` / `[🔙 Back]`)
  - Dev seed bumped (5× of every cooking ingredient, all 5 scroll-locked recipes)
- [x] Weapon upgrade flow (Phase 5.2.2) — Workshop button `[⚔️ Upgrade weapon]` advances the player's class starter weapon one tier at a time. Three weapons × 5 tiers (Rusty Sword → Knight's Sword / Simple Bow → Hunter's Longbow / Wooden Staff → Archmage's Scepter). Stats + materials live in `WeaponUpgradeCatalog`; T1 stats match legacy `Item.gearStats`. Tier persisted on `InventoryEntry.tier` (`AddInventoryTier` migration, default 1). Estate-level gate (tier N requires estate ≥ N), no skip-ahead — sequential progression. `WeaponUpgradeService.upgrade(for:on:)` drains materials from combined inventory + warehouse pool, bumps tier in place (item id never changes). Tier-aware display names via `ItemDisplay.nameKey(for:tier:)`. Tiered weapons can't be warehoused (new `notTransferable` result on WarehouseService.deposit).
- [x] Create `content/recipes.md` reference doc
- [-] Blueprint learning (recipe unlocks via drops / purchases) — *moved to Phase 6.3 Capital Hub, where Quest Board will hand out recipe scrolls as rewards*

### 5.3 Player XP / level → estate-tier derivation + per-level unlocks *(landed — 5.3a/b/c/d/e all shipped)*

Decision (2026-05-11): keep single source of truth on `User.level`/`User.xp` (Strategy A); estate level is derived as `(level - 1) / 3 + 1`. 21 player levels → 7 estate tiers. Two-track unlocks: estate-tier (every 3 levels) for structural unlocks (rooms, plot slots, weapon tiers), player-level (each level) for personal unlocks (techniques, stat growth, bag size).

#### 5.3a Base XP/level system *(landed 2026-05-11)*
- [x] `Enemy.xpReward: Int` per-tier (T1=5 / T2=12 / T3=25 / T4=50 / T5=100 / T6=175 / dummy=0)
- [x] `User.maxLevel = 21`, `User.xpRequiredToReach(_)` softcap helper (×2 to L5, ×1.4 after), `User.xpToNextLevel`, `User.grantXP(_) -> XPGrantResult` (returns `levelsGained` + `estateLeveledUp` + `newLevel` + `newEstateLevel`)
- [x] `User.estateLevel` formula `(level - 1) / 3 + 1` replaces `/5 + 1`
- [x] `CombatController.finishVictory` grants XP + appends `📊 +N XP` / `🎉 Level N!` / `🏰 Estate tier N!` banners (skipped during registration tutorial; training dummy is xpReward=0 natural no-op)
- [x] `PassiveExpeditionService` accumulates XP via `RunningPassiveReport.xpEarned`, grants at `finalizeAndPush`, surfaces in report (`PassiveReport` gains `xpEarned` / `levelsGained` / `newLevel` with backwards-compat Codable)
- [x] Profile XP visualization in all 3 styles (compact / text-bar / emoji-bar); `Max` label at L21
- [x] 6 new locale keys × 2 locales; parity 418/418

#### 5.3b Stat growth on level-up *(landed 2026-05-11 part 2)*
- [x] On level-up, grant +5 maxHP / +1 ATK / +1 DEF at L2, L3, L5, L6, L9, L12, L15, L18 (8 boosts total → +40 maxHP / +8 ATK / +8 DEF by L21)
- [x] Current HP bumps alongside maxHP (RPG-standard "you feel stronger" cadence)
- [x] `User.statGrowthLevels` Set + per-stat constants; `XPGrantResult` extended with `maxHpGained` / `attackGained` / `defenseGained` totals
- [x] maxVigor stays 100 always — no growth (per design)
- [x] Banner suffix: combat → "🎉 Level N! 💪 +H maxHP +A ATK +D DEF"; passive report rebuilt from 3 composable fragments behind separate locale keys (shared `level_up.stat_boost`)

#### 5.3c Room / plot-type / plot-slot gates + manual estate upgrade *(landed 2026-05-11 part 3)*
- [x] Kitchen unlocks at estate T2; Workshop at T3; Tannery sub-category in Workshop at T4
- [x] Training Ground plot type unlocks at estate T3 (other 4 types available from T2 with the first plot slot)
- [x] First plot slot at T2; slot count `[0,1,2,3,4,5,6]` by tier — restored from flat 5; registration auto-Farm grant dropped
- [x] `WarehouseService` capacity by tier: T1=50, T2=100, T3=150, T4=200, T5=300, T6=400, T7=500. New `.warehouseFull` only blocks creating new rows (stackable merges always succeed). Warehouse root UI shows `📦 X/Y slots`
- [x] Stale-callback defensive alerts: `estate.locked.room`, `estate.plot.type_locked`, `estate.warehouse.full`
- [x] **Manual estate upgrade pivot:** `User.estateLevel` converted from computed `(level-1)/3+1` to stored `@Field` (default 1) via `AddEstateLevel` migration. New `EstateUpgradeCatalog` (6 transitions: T1→T2 ... T6→T7, each with `requiredPlayerLevel` 4/7/10/13/16/19 + materials list scaling from ~33 units to ~313 units). New `EstateUpgradeService` mirrors `WeaponUpgradeService`. EstateController gains `[🏠 Upgrade estate]` root button + detail screen with current+next tier names, player-level gate (✅/⛔), materials with have/need, `[🏗 Upgrade]` confirm. Result enum: success/maxTierReached/playerLevelTooLow/**insufficientGold**/missingMaterials — all failures → modal alert, success → in-place refresh + banner.
- [x] **Gold cost for T3+ transitions:** `EstateUpgradeStep.goldCost: Int` (default 0). T1→T2 + T2→T3 cost 0 (free onramp), T3→T4=50g, T4→T5=150g, T5→T6=400g, T6→T7=1000g. Drained directly from `User.gold` (not an inventory item — lives on the User row, never appears in the backpack or warehouse). Gold gate checked between player-level and material snapshot for cleaner failure attribution. Gold source = quest rewards in Phase 6+ (no mob drops); dev grants via Postico. UI line `⛔ 💰 50 gold (30/50)` sits outside the `📜 Materials` block when goldCost > 0; ✅/⛔ marker matches the player-level gate style.
- [x] 7 tier names per locale (Wooden Hut → Settler's House → Forester's Lodge → Manor → Knight's Manor → Baron's Estate → Lord's Holdings). Locale parity 442/442 (+19 keys total — 17 base 5.3c + 2 gold)
- [x] `XPGrantResult.estateLeveledUp` is now structurally always false (XP grants no longer change estate); inert banner branches kept as forward-compat hooks

#### 5.3d Bag size / starter rebalance + craftable bag upgrades *(landed 2026-05-11 part 5)*
- [x] Starter bag drops 50 → 20 slots (`User.bagTier = 1` default). Warehouse stays generous so safe storage > carry capacity makes narrative sense.
- [x] Bag becomes upgradable in Workshop via `BagUpgradeService` (parallel to weapon upgrade): T1 Linen Sack 20 → T2 Leather Bag 30 (5× hide + 2× iron, est T3+) → T3 Reinforced Backpack 40 (10× hide + 3× ingot, est T4+) → T4 Hunter's Pack 55 (15× hide + 5× ingot, est T5+) → T5 Master's Knapsack 75 (20× hide + 8× ingot, est T6+). Materials only — no gold cost.
- [x] `User.bagTier` Int field (default 1) + `AddUserBagTier` migration. `BagCatalog` (5 tiers + per-step materials + estate gates) and `BagUpgradeService` (mirrors `WeaponUpgradeService` pattern).
- [x] `InventoryEntry.slotCap` converted from `static let = 50` to `static func slotCap(for user: User) -> Int` reading `BagCatalog.capForTier(user.bagTier)`. All call sites updated (`CraftingService`, `InventoryController.renderRoot`, internal `canAccept` / `add`).
- [x] Workshop UI: second universal button `[🎒 Upgrade bag]` after the weapon button. Detail screen mirrors weapon flow with capacity delta (`+10 slots`), estate-tier gate (✅/⛔), materials with have/need, `[🧵 Sew]` confirm. Failures → modal alert; success → in-place refresh + `✅ Bag upgraded to tier N — Name · K slots` banner.
- [x] 15 new locale keys × 2 locales (5 tier names + 10 UI keys); parity 457/457.

#### 5.3e Technique gates + "learn at Training Ground" flow *(landed 2026-05-11 part 7)*
- [x] Unlock-by-level gating for the 3 class-bound technique slots (Special Atk / Special Def / Super) — each player has exactly one of each, resolved by `User.characterClass`. Class-agnostic IDs `special_atk` / `special_def` / `super` stored in `LearnedTechnique`.
- [x] Player-level thresholds: Special Atk @ L8, Special Def @ L11, Super @ L14 (via `CombatService.requiredLevel(for:)`)
- [x] Per-fight uses growth: 1/1/1 initial → 2 at L17 (atk) / L20 (def) / L21 (super) via `CombatService.initialUses(for:playerLevel:)`. `ExplorationState.beginCombat` takes uses as parameters; all 3 call sites updated (active encounter, training dummy, registration wolves)
- [x] Combat submenu (Variant 2): learned + uses → "<name> × N"; spent learned → hidden; unlearned → "🔒 <name>" (same callback). Handlers call `sendLockedToastIfUnlearned` first; locked tap → modal alert via `combat.tech.locked` with required-level interpolation
- [x] Training Ground screen replaces direct-to-spar: per-kind status lines (✅ learned / 📖 learnable / 🔒 locked) + `[📖 Learn X]` buttons (only shown for learnable kinds) + `[🥋 Spar]` + `[🔙 Back]`. Learn handler defensively re-checks level gate. Spar reuses the existing dummy combat flow.
- [x] `LearnedTechnique` Fluent model + `CreateLearnedTechniques` migration (unique on user_id+technique_id, mirrors LearnedRecipe shape)
- [x] 11 new locale keys × 2 locales (combat.tech.locked + estate.training.{title,description,kind.{learned,learnable,locked},button.{learn,spar,back},banner.{learned,already_known}}); parity 468/468

**Phase 5.3 series complete.** All sub-phases (a/b/c/d/e) landed. Next: Phase 6.

#### 5.3 — Future / deferred
- [ ] L21 max-level perk (TBD — large stat boost, cosmetic, or unique skin)
- [ ] Granular per-stat curve tuning (ATK/DEF growth rates may need rebalance after playtesting)

### 5.4 Estate Placement *(abandoned 2026-05-11)*
- [-] **30×30 spatial estate grid + frontier placement + 8-neighbor adjacency** — replaced by a different PvP-on-estate attack mechanic (TBD, lives in Phase 7+ as a clean-sheet design). The original GDD plan around adjacency-gated territorial wars is no longer the direction; do not resurrect this approach.

---

## Phase 6: Economy & Capital

### 6.0 Capital travel + nav skeleton *(landed)*
- [x] `TravelState` Fluent model + `CreateTravelState` migration (per-user, unique, destination + ends_at)
- [x] `User.location` stored field + `AddUserLocation` migration (default "estate")
- [x] `TravelService` (Task.detached + Task.sleep, `rescheduleInflight` on bot start, flips location + routerName on arrival, pushes welcome screen)
- [x] `CapitalController` rewritten — reply-keyboard with 6 location buttons + utility row [Inventory] [Profile] + 🏡 Back-to-estate
- [x] `Assets/capital/welcome.jpg` + atmospheric lore + auto-loader (`renderLocation` picks up `Assets/capital/<id>.jpg` if present)
- [x] Cross-controller guards: travel countdown in Main / Estate / Exploration; explore-from-capital blocked; estate-from-capital starts return trip
- [x] Bugfix: inventory-from-capital no longer flips routerName (preserves capital nav); `inv:*` callbacks forwarded from CapitalController
- [ ] Flip `TravelService.testMode = false` before shipping (currently 2 s per minute)

### 6.1 Trader (Crамар) *(landed)*
- [x] `TraderCatalog` static catalog — 11 listings, asymmetric (sell/buy) packets, per-tier pricing
- [x] `TraderService.sell(qty) / buy(qty)` — quantity-aware with atomic preflight; typed result enums
- [x] Two-step UI in CapitalController — Menu (Buy/Sell choice) → list (edit-in-place over the merchant photo `Assets/capital/trader.jpg`)
- [x] Per-row 2-line layout: info-label (description modal) + action row `[💸/💰 ×1] [✏️ N]`
- [x] `[✏️ N]` flow — bot prompt + `[❌ Cancel]`, `EphemeralChatState.PendingTraderTransfer`, `unmatched` text intercept, invalid-input keeps prompt, validation-failure clears + banner, success clears + banner
- [x] Sell list filtered to items the player has (qty ≥ 1) — no dead-tap rows
- [x] **Economy v2 rebase (2026-05-17)**: pebble anchored at 1 unit = 1g, all tiers doubled per-unit sell price (1/2/3/5/10g across T1-T5, ingot 100g), packets all = 1 unit, UI labels collapse `1·Xg` → just `Xg`

### 6.2 Tavern (Шинок) *(landed)*
- [x] `TavernCatalog` — 7 cooked-dish prices (20-200g, ~5× old scale) + shared wager tiers [10, 25, 50]
- [x] `TavernService.buyDish` (atomic, mirrors trader buy) + pure `resolveWager(playerScore:houseScore:) → WagerOutcome`
- [x] Tavern entry screen — `Assets/capital/tavern.jpg` + lore + `[🍲 Меню][🎲 Кості][🎯 Влучанка]` inline buttons
- [x] Menu sub-screen — sells all 7 dishes bypassing recipe scrolls (no scroll-gate, tavern's value prop)
- [x] Dice + darts gambling — button-driven (bot-rolls model since Telegram doesn't let bots author messages as the player); wager tap → "Готовий?" confirm + `[🎲 Кинути][❌ Скасувати]` (no debit yet, free cancel), Roll tap debits + sequences (player label + N×sendDice → sleep → house label + N×sendDice → sleep → result + replay/back). Dice = 2 throws each, darts = 1.
- [x] Result message has `[🔄 Зіграти ще раз][🔙 До шинка]` — replay edits text in place at same wager, back sends fresh photo tavern entry

### 6.3 Photo infrastructure *(landed; reworked 2026-05-20)*
- [x] `PhotoCache` actor + `sendCachedPhoto` helper — file_id cache (no repeat uploads). **Reworked 2026-05-20**: dropped the scenery-slot auto-deletion — photos now stay in chat as history (players wanted a record of visits; file_id dedup makes accumulation free).
- [x] PNG MIME auto-detect (for tarot card art and future PNG assets)
- [x] ALL player-visible art on `sendCachedPhoto` — capital + estate backdrops AND registration narrative art (converted from direct `bot.sendPhoto` on 2026-05-20)
- [x] Tavern dice 24h cleanup — Telegram blocks deleting private-chat dice <24h old, so `TavernGameMessage` table + `TavernCleanupService` sweeper delete each round once it ages past 24h

### 6.4 Fortune Teller (Ворожка) *(landed)*
- [x] `FortuneCatalog` — 22 Major Arcana cards (0_fool through 21_world) + `FortuneEffect` struct (14 optional fields covering stat bonuses + multipliers + one-shots + Wheel-style random)
- [x] `FortuneService.draw(for:on:)` — 24h cooldown gate + 10g gold + uniform random draw + one-shot apply + state stamp
- [x] 3 new User fields + 2 migrations (`AddFortuneFields` + `AddFortuneCooldownField`; split fields after 6h-buff vs 24h-cooldown design call)
- [x] Effect hooks in 5 sites: User.effectiveAttack/Defense/Crit/Dodge/Accuracy, User.grantXP, ExplorationService.rollStep (loot weight), VigorService.drain (drain multiplier composes with stance)
- [x] UI: showFortune (3 render states — can-draw / cooldown-with-buff / cooldown-only), reveal screen with card portrait + lore meaning + buff description + 6h countdown
- [x] Profile fortune line (`🔮 <Card> · HH:MM`) on all 3 profile styles
- [x] 22 card PNGs in `Assets/capital/fortune/` + entry portrait `Assets/capital/fortune.jpg`
- [x] Reply-keyboard insurance — inline `[🔙 До столиці]` back button on fortune/tavern/trader entries (also re-attaches reply keyboard if a Telegram client collapsed it)
- [x] Bugfix: `CapitalController.onCallbackQuery` forwards unknown callbacks (pstyle, stale explore/combat) to MainController instead of returning false — no more "Unsupported content type"

### 6.5 Capital Hub (remaining)
- [x] **Market** *(landed 2026-05-28)* — player-to-player marketplace. `MarketListing` model + `CreateMarketListings` migration + `MarketCatalog` (flat `listingFee = 5` silver sink, `maxActiveLots = 5`) + `MarketService` (createListing / buyListing / cancelListing, typed results, DB-only). Stackables only (gear excluded via `Item.stackable`). **Escrow at listing** — units leave the seller's bag onto the lot row; cancel returns them (fee kept). **Two-level item-grouped buy board**: Level 1 = one row per distinct item (`<item> · lots: K · from 🪙U`), Level 2 = that item's lots sorted cheapest-per-unit first (`×N · 🪙total (🪙U/ea) · @nick`) → confirm → buy. Buying debits buyer, credits seller, delivers items, deletes the lot, and pushes the seller a "sold" notification (PlotProductionService-style fire-and-forget). Sell = two-prompt flow (quantity → price, fee shown inline) via `PendingMarketListing` two-stage `EphemeralChatState` + `unmatched` text intercept. My-lots screen cancels with one tap. `onMarket` → `showMarket` (was the `renderLocation` stub). 37 locale keys × 2 (all neutral — no gendered words). `Assets/capital/market.jpg` not supplied yet → text fallback via `sendCachedPhoto`.
- [x] **Trade** *(landed 2026-06-10)* — synchronous player-to-player exchange (MMO-style trade window), reached via the Market menu `[🤝 Обмін]` button. New `TradeStore` actor (in-memory: lobby presence + live sessions + `byUser` busy-index, TTL sweeper) + `TradeService` (offerable-items list + validate-then-mutate atomic swap) + `PendingTradeInput` in `EphemeralChatState` (silver / stack-qty text prompts). Flow: presence lobby (only players who opened the exchange; busy hidden) → invite → accept/decline push → both bags open (toggle stackables w/ qty prompt + gear by exact instance + `[+ срібло]`) → stage-1 `[✅ Погодити]` (both ready → lock) → combined-offer screen → stage-2 `[✅ Підтвердити обмін]` → commit. **Gear moves as the exact `InventoryEntry` row** (enchant/durability/tier preserved); bound starter weapon excluded (`WeaponUpgradeCatalog.isUpgradable`). No DB persistence — bot restart cancels in-flight trades. 33 locale keys × 2 (all neutral). Build clean. Known v1 limitation: a simultaneous double-confirm can briefly show a stale screen (state stays consistent, self-heals).
  - *Post-playtest polish (2026-06-15):* uk renamed Ринок→**Базар** across the locale; fixed the `🪙 Срібло: %{silver}` button (Lingo emoji-before-`%{}` bug) + dropped unused `від %U` from the buy-board row; `mutateBuilding` resets only the editor's ready-flag (1 tap each at selection — partner's «Погодити» no longer wiped by your edits); `finishTradeSuccess` posts a permanent per-side gave/got trade record at the bottom of chat (+`capital.trade.gave`/`got`, 35 keys × 2); transient numeric prompts now delete on submit/cancel while banners + the record stay.
- [ ] **PvP Arena** — async duels (snapshot opponent stats, bot autobattles, ladder)
- [x] **Master** *(landed 2026-05-21, expanded 2026-05-22)* — armor shop / repair / enchant; the first real silver sink. Durability system on `InventoryEntry.durability`/`max_durability` + `enchant_level` (via `AddGearCondition`); `GearConditionService` model-C wear (win 1 / loss 3 / flee 5, point-by-point across random equipped pieces). **2026-05-22 expansion:** (1) enchant gives a class-identity bonus on top of flat DEF (⚔️ +DEF / 🏹 +dodge / 🔮 +crit), cap raised +3→+5, non-linear point curve (1/2/3/5/8), step costs 40/100/220/450/850🪙 + hide; (2) premium armor buy prices (Forester set 485🪙 ≈4× material value) + heavier craft recipe (40🦴 + 8🔩 iron); (3) **weapon durability** by tier (`WeaponUpgradeCatalog.durabilityByTier` 30/40/50/70/100) — weapon joins the wear pool, at 0 keeps HALF its stats (lore: King's weapon can't break), repair is 1🪙/point with no max shave, class-flavoured repair buttons (🗡 Sharpen / 🏹 Restring / 🔮 Re-empower); (4) inventory gear-detail card (tap → HTML message with stats + durability + enchant). Gem inlay still deferred.
- [ ] Tutorial prompt that flags "you can travel to the capital" — currently players discover it by tapping the existing main-menu button

---

## Phase 7: Social Systems

### 7.1 Guild System
- [x] **Guild model + membership** *(landed 2026-06-16)* — `Guild` (name unique, tag, emblem, leader, treasury, motto) + membership on `User` (`guild_id` + `guild_role`, one guild per player) + `GuildInvite` + `GuildVaultEntry` + `GuildCatalog` (memberCap 20, maxOfficers 2, foundCost 500🪙, foundLevelGate 5, vaultUnitCap 3000) + `GuildRole` enum. Migrations: `CreateGuilds` → `AddUserGuildFields` → `CreateGuildInvites` → `CreateGuildVault`.
- [x] **GuildController** *(landed 2026-06-16)* — capital `🏰 Гільдії` button → routerName `"guild"`; membership-branched reply keyboard. Found (silver sink + level gate; **tag left empty, game-creator-assigned via DB** — name prompt directs the player to `@TGUserName`), invite (by nickname/@username + push) / accept / decline, roster, kick / promote / demote (officer cap 2), leave / disband. All via `GuildService` (typed results).
- [x] **Guild vault (shared storage)** *(landed 2026-06-16)* — item vault `🏦` (stackables only, deposit any member / withdraw leader+officers, cap 3000) **and** silver treasury `🪙` (deposit any member / withdraw leader+officers, `Guild.treasury`).
- [ ] Guild chat (bot-proxied broadcast) — deferred (rate-limit-aware fan-out)
- [ ] Guild banner on estate (cosmetic) — deferred
- [ ] Implement non-aggression pacts — deferred (depends on territorial PvP, 7.2)
- [ ] Leadership transfer (currently the leader must disband; no hand-off)

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

### 8.3 Arena — "Ристалище" *(live герць, started 2026-07-20)*
Design locked with the user: name **Ристалище**, **live** real-time turn-based duel (not async), rating currency **Честь** (ELO). Matchmaking: **queue + lobby-challenge** (both). Start HP: **current** (heal before fighting). Penalties: **no gear/vigor wear** — silver stake is the only cost. Non-lethal (loser floored at 1 HP, no inventory wipe).
- [x] **ArenaController** *(landed 2026-07-20)* — capital `⚔️ Ристалище` → routerName "arena"; membership-style reply keyboard branches hub `[⚔️ Виклик][🏆 Честь]/[🔙 Столиця]` vs live fight `[⚔️ Атака][🛡 Оборона]/[🏳 Здатися]`. Both fighters keep the fight keyboard the whole duel; the actor rejects out-of-turn taps (no keyboard swapping).
- [x] **Live герць engine** *(landed 2026-07-20)* — `ArenaStore` actor (TradeStore-shaped: lobby + pending challenges + live duels + byUser busy-index; combat dice rolled INSIDE the actor via `CombatService.applyAttack` so roll+HP mutation are atomic). Alternating turns, 45 s turn timer, auto-defend on timeout, forfeit after 2 consecutive misses. `ArenaService` does the DB work: match validation (alive + solvent + daily cap), Honor ELO, settlement (stake transfer loser→winner minus King's tithe = silver sink, HP carry-over, win/loss tally, daily counter). `ArenaProfile` model + `CreateArenaProfiles` migration + `ArenaCatalog` tunings. Background sweeper in configure (challenge expiry + turn timeouts + forfeit settlement).
- [x] **Honor rating + leaderboard** *(landed 2026-07-20)* — ELO on `ArenaProfile.honor` (start 1000, K=32); leagues Новак/Боєць/Ветеран/Чемпіон by threshold; `🏆 Честь` screen shows honor/league/W-L/daily + top-10 board. 58 arena locale keys × 2 (all neutral).
- [ ] **Queue matchmaking** — auto-pair by Честь (the second half of the "both modes" decision; lobby-challenge shipped first). Reuses the same `ArenaStore` engine.
- [ ] Ranked vs unranked (casual/no-stake) queues
- [ ] Seasons + end-of-season league rewards (silver / cosmetic title)
- [ ] Escrow-on-restart refund (in-flight duel during a bot restart currently just cancels with no settlement — acceptable while testing)

---

## Phase 9: Content & Polish

### 9.1 Tuning & Balance — **superseded by the Full Rebalance (below)**

The original five bullets turned out to be under-scoped: an audit (2026-08-29) found the
math itself is broken, not merely mistuned. Kept here for provenance; the work now lives in
the phased plan.

- [ ] Create `content/tuning.md` — XP curves, vigor scaling, stat growth
- [ ] Balance damage formula through playtesting
- [ ] Tune exploration event weights per depth
- [ ] Tune vigor drain vs food availability
- [ ] Balance economy (silver sinks vs sources)

---

## Full Rebalance (pre-release) — started 2026-08-29

**Why:** 868,585 XP to L21 against a 175-XP best mob (≈4,963 kills); `max(1, ATK − DEF)` is
scale-free so a geared warrior takes 1 damage from the strongest mob while a fresh mage takes
28 from a boar; enemies have no crit/dodge/accuracy (always `0/0/0`); monsters drop no silver
and the tavern has exactly 0% house edge; all three `testMode` flags are `true`, so every time
gate is 60× compressed.

**Decisions:** full data-driven content · full wipe at release · 3+ months to cap ·
`maxLevel = 40` · death stays harsh · slow vigor regen + food · framework + levels 1–15
authored · **content spec approved before authoring**.

**Model (calibrated, Monte-Carlo verified at 4,000 fights/cell):** DEF becomes
`min(0.70, DEF/(DEF+K_def(L)))`; crit/dodge/accuracy become ratings→percent with denominators
*derived from the item budget curve* (hand-picked ones let a stat rot — archer dodge would fall
below its L1 value by L40); per-level growth is proportional, not flat; enemies are generated
**at design time** from archetype tables (runtime generation would nullify every gear upgrade);
`xpToNext(L) = max(11.4·L^3.30, 120L)`, `mobXP(L) = 26·L^1.55·archXP` → 19.4M XP ≈ 110 days at
80% engagement; rarity budget multipliers capped at 1.45 (the drafted 2.45 gave 4.15× power).

Full plan: `~/.claude/plans/roi-session-primer-eventual-wirth.md`

- [x] **Phase 0 — Scaffolding** *(2026-08-29)* — `ROIContent` / `ROISim` / `roi-content` /
      `ROIContentTests` targets; DTOs for Item/GearStats/ItemEffect/Enemy/Recipe/Manifest;
      `ContentLoader` (readable decode errors, FNV-1a hash, never sorts), `GameData` snapshot
      holder (`nonisolated(unsafe)` + `NSLock`, keeps catalog façades synchronous),
      `GameContent`, `LocaleIndex` (uk `.m`/`.f` aware), `ContentValidator` (identity · enums ·
      references · localization · timeScale). 24 tests green. **`@_exported import` spike passed** —
      `ContentBootstrap.swift` compiles with no import of its own, so the ~315 existing catalog
      call sites need no churn. Platform stays macOS 14 (`NSLock` instead of `Mutex`).
      Provably inert: +26 lines in `Package.swift`, +6 in `configure.swift`, nothing else touched.
- [x] **Phase 1 — Exporter + first JSON** *(2026-08-29)* — `ContentExporter` + `--export-content`
      argv branch in `entrypoint.swift` (runs before `configure`, so no DB/token/network);
      `ContentMapping` gives domain⇄DTO in BOTH directions, so `toDomain()` is ready for Phase 2.
      Exported `content/data/{manifest,items,enemies,recipes,weapon_upgrades}.json` — 33 items,
      9 enemies, 12 recipes, 3 ladders. **Nothing normalized**: the `0...0` depthRange sentinel
      is exported verbatim, declaration order preserved (`pickFor` uses `filter().randomElement()`,
      so order decides seeded rolls). Three verification layers pass: **layer 0 (domain
      equivalence)**, layer 1 (canonical round-trip byte-identical), layer 2 (counts + id sets +
      order); two independent exports are byte-identical. Layer 0 was added during the audit and
      is the load-bearing one: `domain→DTO→domain→DTO→JSON` stays byte-stable even when the mapper
      never captured a field, because both directions drop it consistently. Proven by negative
      test — deleting `teachesRecipe` from the mapper (which would have silently removed all five
      recipe scrolls from the game) left layers 1 and 2 **green**; only layer 0 caught it.
      Independently cross-checked by parsing the Swift sources in Python: all 11 item fields ×
      33 items and all 10 enemy fields × 9 enemies match the JSON. `roi-content validate` on the real bundle: **0 errors, 1 warning**
      (`timeScale 60.0`, truthful — the three `testMode` flags are still on). `--strict` exits 1
      on it, as intended. 37 tests green.
      **Scope note:** `weapon_upgrades.json` was pulled forward from Phase 3 — the localization
      rules cannot be correct without it. `ItemDisplay` appends `.t<tier>` for laddered items, so
      the base `.desc` key is never resolved and all three shipped weapons legitimately lack it;
      without ladder data the validator emitted six false warnings.
- [x] **Phase 2 — Catalog façades** *(2026-08-29)* — `ContentBootstrap.load` wired into
      `configure` right after `Dotenv.configure` and BEFORE the database block (the dev-seed and
      `backfillWeaponDurability` later in the same function both touch a catalog). `ItemCatalog` /
      `EnemyCatalog` / `RecipeCatalog` are now façades over a `DomainContent` snapshot;
      **397 lines of hardcoded arrays deleted, replaced by 40 lines of routing**. `all` changed
      from `static let` to a computed property — verified no `static let` anywhere reads a catalog
      at type-init.
      **Verification layer 3 (`--content-digest`)**: field-complete record fingerprints + a seeded
      `pickFor` replay (40 depths × 200 draws). Baseline from the Swift arrays and the result from
      JSON are **identical: `545017168ce60953`**. Non-vacuous by two negative tests — reordering
      two enemies in JSON moved both halves; dropping `?? all.first` from `pickFor` left `records`
      byte-identical and moved `spawns` alone, which is exactly the class of bug record hashes
      cannot see. Plus a live façade smoke test: every recipe input/output, loot id, scroll,
      starter recipe and class starter weapon resolves through `find()`.
      `pickFor` was unified to a single implementation (the argument-free overload delegates to the
      seedable one) so the digest can never replay different logic than the game runs. The
      `?? all.first` km≥36 fallback bug is preserved deliberately — fixing it belongs to Phase 5.
      `ContentExporter` narrowed to Swift-backed catalogs only, since re-exporting a façade is
      circular. 37 tests green.
- [x] **Phase 3 — Remaining catalogs** *(2026-08-29 — 12 of 12 done)*
  - [x] **Batch A** *(2026-08-29)* — `WeaponUpgradeCatalog`, `BagCatalog`, `EstateUpgradeCatalog`
        are façades; `bags.json` + `estate_upgrades.json` exported (weapon_upgrades.json landed in
        Phase 1). **386 lines of Swift arrays deleted.** Migration digest identical across the
        flip. Cross-checked independently by parsing the pre-flip Swift arrays out of git: maxTier,
        capacities, every ladder step and `durabilityByTier` all match.
        **Digest gained an accessor replay** during the audit — the record fingerprints cover the
        DATA, but `nextStep` / `capForTier` / `durability(forTier:)` / `stats(for:tier:)` bodies
        were rewritten and nothing checked them. Verified by reverting only the three catalog files
        to HEAD and re-running the *same* digest code: identical, including out-of-range tiers.
        New validator rules: tier contiguity (`nextStep` indexes `progression[tier − 2]`, so a gap
        silently hands out the wrong upgrade), ladder-vs-`capacities` disagreement, capacity
        regression, estate level-gate regression. 42 tests green.
  - [x] **Batch B** *(2026-08-29)* — `TraderCatalog`, `TavernCatalog`, `MarketCatalog`,
        `GuildCatalog`, `ArenaCatalog` are façades; `trader.json` + `tavern.json` + `market.json`
        + `guild.json` + `arena.json` exported. **Migration digest identical across the flip
        (`9242a2c1501994ed`).** The batch was heterogeneous — 18 ordered records, 22 tuning
        scalars and one table — and each shape needed a different guarantee:
        · **Records** (trader, tavern) keep declaration order, because it is the order the player
        scrolls; layer 0 rebuilds the domain value and compares fingerprints, as the ladders do.
        · **Scalars** (market, guild, arena timings) decode as REQUIRED — never `decodeIfPresent`.
        A missing `memberCap` must fail the boot; defaulting it to 20 is precisely the silent
        balance drift this pipeline exists to prevent. Their layer 0 is encode → decode → compare
        each field against the live Swift constant, which is what catches a transposed pair that a
        self-consistent round-trip is blind to.
        · **`ArenaCatalog.leagueKey` was control flow, not data**, so the table could not be read
        off the catalog — it was hand-translated, then *proven*: the exporter replayed the shipped
        `switch` against the new table over honor −500…3000 and refused to write on any mismatch.
        The range runs wider than the digest's 0…2000 because `case ..<1000` also swallowed
        negatives, and the table's `?? first` tail has to swallow them identically.
        **28 new validator rules, every one negative-tested against a perturbed bundle:** trader arbitrage (`sell ≤ buy`
        compared per unit by cross-multiplication — the one economic invariant the shipped catalog
        held only by convention, one typo away from an unbounded silver faucet), unknown/duplicate
        listing ids, packet quantities, tavern price floor, strictly-ascending wager and stake
        ladders, market fee/lot bounds, guild name bounds and officer headroom, arena tithe range,
        K-factor, rating floor, positive timings, **sweeper-slower-than-a-turn** (warning — the
        sweeper is what enforces `turnSeconds`), league table non-empty · strictly ascending ·
        no gap above the rating floor, and league keys present in both locales. 62 tests green.
        Digest coverage re-proven non-vacuous per file: perturbing `memberCap`, a league boundary,
        `tithePercent`, trader row order, a wager tier and `listingFee` each moved it to a
        distinct value.
  - [x] **Batch C** *(2026-08-29)* — `MasterCatalog`, `PlotCatalog`, `FortuneCatalog`,
        `QuestCatalog` are façades; `master.json` + `plots.json` + `fortune.json` + `quests.json`
        exported. **Digest identical across the flip (`8053216102eceff7`).** 172 lines removed from
        the four catalogs (49 of them data literals), net −78 after the façade code. Step 1 was real work this time — the digest had no coverage yet — so it
        gained a `records` extension (22 cards × 14 effect fields, 9 jobs, 4 plot tunings, the
        Master ladder) **plus a third half, `quests`**: a seeded replay of `daily()` over 200
        users × 4 days × 3 NPCs.
        **That third half is the batch's whole point.** `daily` is
        `pool[stableHash("<uuid>:<npc>:<day>") % pool.count]`, so pool ORDER is the assignment —
        reordering silently reassigns the entire playerbase. Proven by negative test: dropping the
        day from the hash key left `records` **byte-identical** and moved `quests` alone.
        Five more negative tests pinned the pure-code accessors, which have no backing array at
        all — `icon(.mine)` ⛏→🪓, the `repairCost` coefficient 0.5→0.6, a card multiplier
        1.35→1.36 and `enchantPerLevelPoints` each moved `records`.
        **Two hand-translations, both proven before a byte was written:** `repairCostFraction`
        (the 0.5 lifted out of `repairCost` — the exporter recomputed the whole formula from the
        extracted value over 6 items × missing −5…120) and the exported pool order (replayed
        against `daily()` over 200 users × 4 days × 3 NPCs).
        **`FortuneCatalog.lookup` was a `private static let` reading `all`** — after the flip that
        would have run at type-init and trapped before `ContentBootstrap.load`. It moved into
        `DomainContent`, which is the only reason the boot survived.
        Staying in Swift on purpose: `PlotType` (persisted in `Plot.plotType`), `QuestNPC`
        (callback token + locale infix), `QuestCounter` (names the four hook sites),
        `weaponRepairCost` (`max(0, missing)` has no magic number to lift).
        **28 new validator rules, every one negative-tested**, including `master.points_short`
        (a short points table silently stops granting at the top of the ladder),
        `master.levels_not_contiguous` (`enchantStep` looks up by level, so a gap strands the
        player one short of the cap), `plot.type_missing` (a `PlotType` the file forgets is a DB
        row the game cannot describe), `fortune.unsafe_id` (the id is also a PNG filename),
        `fortune.half_wheel` (the wheel needs both sides or it is ignored entirely) and a
        cross-pool `quest` id uniqueness check. 85 tests green.
        **`ContentExporter` deleted** along with the `--export-content` branch: Phase 3 is over,
        no Swift array remains, and there is nothing left for it to export.
- [x] **Phase 4 — Tuning tables + `time.scale`** *(2026-08-30)*
  - [x] **4a — six tuning tables** — `content/data/tuning/{combat,vigor,exploration,progression,
        economy,time}.json`. ~80 constants moved out of `CombatService` / `VigorService` /
        `HealingService` / `ExplorationService` / `User` / `CharacterClass` / `WarehouseService` /
        `GearConditionService` and the six time sites. **Migration digest identical across the
        flip (`tuning a8b3c0fa99f86e3c`)**, with the three catalog halves held at their Phase 3
        values — the proof that Phase 4 moved balance numbers and nothing else.
        The digest gained a FOURTH half for exactly that reason, negative-tested five ways
        (a plain scalar, a stance modifier reachable only through an accessor, a `Set` member, a
        bare-tier weight, a `realTime` constant) — each moved `tuning` to a distinct value while
        `records` / `spawns` / `quests` held.
        `ExplorationService`'s weight-tier `switch` was extracted into `weights(forPriorVisits:)`
        **before** the flip, so the baseline was captured through the accessor and the flip was a
        plain no-op — strictly safer than batch B's hand-translate-then-prove. Its lookup is
        "exact match, otherwise the LAST row": the shipped `default:` arm swallowed NEGATIVE visit
        counts, and a "greatest row at or below" lookup would have handed them the fresh-room
        weights instead. **No exporter** — it died with Phase 3, so the JSON was hand-written;
        safe only because step 1 had already put every constant under the digest.
        **48 new validator rules**, each negative-tested: the ones that matter guard values read
        straight into an operation that TRAPS — an inverted `variance` (`ClosedRange`), a
        non-positive `eventWeightTotal` (`Int.random`), an empty warehouse table (subscript), a
        zero `maxDurabilityStart` (`MasterCatalog.repairCost` divides by it) — plus a contiguous
        revisit-tier run, weights that must sum to the total, an unknown time zone (`GameDay`
        silently falls back to UTC and moves every daily reset), and Telegram's 24 h delete floor.
        Two warnings now fire truthfully: the audit's `flee (5) > defeat (3)` gear-wear inversion,
        and the time scale. 130 tests green.
  - [x] **4b — `testMode` → `time.scale`** — the three booleans and `manifest.timeScale` are gone;
        `tuning/time.json` → `scale` is the single knob, and `schemaVersion` bumped to 2.
        **Verified no-op: all four digest halves identical across the collapse.** The flags were
        never one scale (`PlotProductionService`'s sweep was 5×, the rest 60×), which is why the
        sweeper became DERIVED — `max(minSeconds, plotInterval / divisor)` — a DB polling cadence
        rather than a game-time gate, calibrated so 3600/12 = 300 s reproduces production and the
        60 s floor reproduces test mode. `EstateController`'s `/hr` vs `/min` label now reads the
        interval instead of the deleted boolean. `time.json` splits `gameTime` (scaled) from
        `realTime` (never scaled) because Telegram's 24 h dice-delete window is a protocol
        constant: scaling it would not rebalance the tavern, it would break the sweep.
        Left at **`scale: 60`** deliberately — Phase 11 flips it to 1.0 as a one-number change.
- [x] **Phase 5 — New combat model** *(2026-08-30)* — four commits' worth of work in one:
  - [x] **5A — bestiary data** — `EnemyArchetype` + the six-archetype table in `enemies.json`;
        `Enemy` gains `level`, `archetype`, `crit`/`dodge`/`accuracy`, `silverReward`,
        `spawnWeight`. `pickFor` is weighted and returns **nil** past coverage instead of
        `all.first` — the fallback that made every encounter past km 35 a wild boar, so the
        deepest content in the game was also its easiest. `rabid_bear` extended to km 40 to close
        the hole honestly; a real gap is now a validator finding. Level = the depth an enemy
        starts appearing at, which is what gives `levelDiff` meaning. 17 validator rules.
  - [x] **5B — progression** — proportional growth (`base × (1 + rate·(L−1))`, 0.056 / 0.100 /
        0.085) replaces +5/+1/+1 on eight chosen levels. Under flat growth a warrior's dodge
        RATING rose while its PERCENT fell 5.3% → 1.4%, which reads as a bug. `maxVigor(L) =
        100 + 5L`, and Vigor **regeneration exists at all** for the first time (whole pool per
        6 h, `VigorService.regenTick`, deliberately NOT suspended during an expedition).
        `applyLevelDerivedStats` recomputes rather than accumulates, so it is idempotent and a
        startup backfill moves old rows onto the new line.
  - [x] **5C — combat model** — absorption replaces `max(1, ATK − DEF)`; crit/dodge/accuracy
        become ratings through curves whose denominators grow with level; `levelDiff`; hit band
        85 / floor 40. `maxLevel` 21 → 40 with the power-law XP curve and `mobXP` **landed as a
        pair** (the exponent is solved, not chosen). Enemy stats regenerated from the archetype
        table. Adding levels to `applyAttack` made the compiler find all nine call sites,
        including two `chipDamage` ones a text search would have missed. Enemies had passed
        literal `0/0/0` for crit/dodge/accuracy — no beast had ever landed a critical hit.
        `MitigationCurveDTO` and `RatingCurveDTO` are separate TYPES because `0.70` is a ceiling
        where `55/50/30` are scales; conflating them had already cost one wrong enemy table.
  - [x] **5D — techniques, flee, weights, passive, silver** — all three special attacks moved off
        `defenderDEFFraction = 0`, which absorption turns into a 0.44–0.59× trade (+11% damage
        against trash for +150% Vigor). Warrior → armour break for 3 rounds (worth MORE the more
        armour the target has), archer → guaranteed crit at ×2.0, mage → burn 0.35×ATK for 3
        rounds that absorption cannot touch. `WearEvent.flee` 5 → 2 (fleeing cost more than
        dying). Event weights → 5/45/40/10. Passive expeditions charge full Vigor per round, roll
        the decayed tier past the first step, and pay 70% XP / 70% silver / 100% materials — they
        had measured 53% MORE efficient than active play. **Monsters drop silver**, the game's
        first combat-side coin faucet.
        Verification: the digest's `combat model` check replays the design's published anchors on
        every run; 40 enemy values were independently re-derived from the shipped tables; total
        XP to the cap comes out at **19,437,688** against the plan's 19,437,688. 155 tests.
- [x] **Phase 6 — Rarity, sets and the item stat budget** *(2026-08-30)*
      `budget(itemLevel, slot, rarity) = slotWeight · (6.0 + 1.5·itemLevel) · rarityBudget`, with
      every stat an item carries being that budget SPENT at fixed exchange rates. One number now
      bounds a piece, and because the combat denominators were derived from this same curve, an
      item that respects its budget cannot move any stat's percentage however many items follow.
      `rarities.json` (5 tiers, ×1.00→×1.45 budget against ×1→×16 value — decoupled, because tying
      price to power makes *selling a legendary* the largest silver faucet in the game),
      `sets.json` + a second pass in `recomputeBonuses`, `Item.itemLevel`/`rarity`/`setId`, and
      **gear gains an HP stat** (sixth cached bonus + migration) without which the class armour
      profiles cannot be expressed at all.
      **Enchant is now a percentage of the item's own budget** — `1 + 4% × level`, capped at +20% —
      replacing flat points plus a class-identity stat. No flat number works: +32 DEF is 267% of a
      level-1 chest and 14% of a level-40 one.
      **Regenerated the 7 shipped items and all 3 weapon ladders from the curve**, which dissolves
      the documented T5 asymmetry: the three top weapons now spend ~100% of the same budget where
      the warrior's had carried ~15% more for no stated reason. Ladder tiers map to item levels
      1/10/20/30/40 — five rungs across forty levels, not five item levels.
      **This is the phase that made balance checkable.** `--content-digest` now builds the design's
      reference character from the budget and compares: **DEF and absorption reproduce the
      published table exactly** for all three classes (225/136/99, 38.0%/27.0%/21.2%) and ATK
      exactly for warrior and mage. The residual 4–10% HP gap is precisely the two empty accessory
      slots — 1.0 of slot weight nobody has spent yet.
      **New validator rules, each negative-tested**, including the budget overspend check (with an
      absolute rounding slack, since rounding error is a fixed number of points and a percentage
      tolerance would be far too tight at level 1), the rarity ceiling (which rejects the design
      draft's own ×2.45 legendary at 2.94× a common), a set-bonus budget cap, and ladder item
      levels that must ascend. A round-trip test caught `GearStatsDTO` silently dropping `hp` on
      encode — the Phase 1 layer-0 lesson, one field later. 176 tests.
- [x] **Phase 7 — `/reload` hot swap + `LiveReferenceCheck`** *(2026-08-30)* — `/reload` and
      `/content` in `GlobalCommandsController`, gated on `developerUsers`.
      **The whole safety story is the ORDER: parse → validate → live-check → build → install.**
      Everything that can fail happens before anything is touched and `install` is a reference
      store that cannot fail, so a refused reload leaves the running game on exactly the snapshot
      it was already serving — which is what makes this safe to run with players mid-expedition.
      `LiveReferenceCheck` is the rule that makes a hot swap safe at all: every other check asks
      whether a bundle is internally consistent, this one asks whether it is consistent with the
      game already in progress. Drop `mat.iron` while four players carry it and every one of their
      rows becomes an item the game cannot name, price, equip or sell.
      **The design listed six columns; the schema has ten.** The three additions all fail SILENTLY,
      which is worse than loudly: `combat_stance` (the player's Super does nothing),
      `quest_progress.quest_id` (a job in progress cannot be rendered) and
      `active_fortune_card_id` (a buff they paid for evaporates). `learned_recipes.recipe_id` was
      the fourth.
      Split so it is testable: the MATCHING lives in `ROIContent` (Foundation-only) and the
      queries in the main target. The failure worth catching is a category error — item ids checked
      against the bestiary would report every row as dangling, or none, and either way the rule
      would look like it was working. 9 tests, no database required.
      Not reloaded: **Lingo** (`AppState.lingo` is a `let` captured by every controller, so new
      strings still need a restart) and armed timers, which carry their deadline in the database.
      The boot path runs the same check as a warning once the database is up — it cannot refuse
      there, because content loads before the DB block and half of boot has already read the
      snapshot. Digest unchanged: Phase 7 added machinery, not content. 185 tests.
- [x] **Phase 8 — simulator + constant lock-in** *(2026-08-30)*
  - [x] **8A — the math moves into `ROISim`** — `CombatantStats`, `CombatMath` (absorption, rating
        curves, `levelDiff`, `applyAttack`, `chipDamage`, stance + special-attack modifiers, all
        generic over `RandomNumberGenerator`), `ProgressionMath`, `BudgetMath`. `CombatService` /
        `User` / `ItemBudget` / `VigorService` keep their whole public API and delegate, so there is
        ONE implementation and the report cannot drift from the game. `EquipmentSlot` moved to
        `ROIContent/Vocabulary.swift` — it had been transcribed three times (enum + two literal
        lists in the validator) and `BudgetMath` needed a fourth. **Digest `a4d825a8d728f4f8` held
        across the move**, and its `tuning` half replays `baseStats`, `xpRequiredToReach` and all
        four curves, so the refactor is proven bit-identical rather than assumed so.
  - [x] **8B — `swift run roi-content simulate`** — `EnemyGenerator` (inverts the archetype targets
        at design time), `ReferenceCharacter` (on curve and one ladder rung behind), `FightSimulator`
        (the round order copied from `CombatController.finishRound`; `.basic` = the passive
        autobattle, `.techniques` = super then specials), `Statistics`, and a report with bands:
        level invariance (means, ratios, two-sided), the tail (p90 < 100%, win rate), stalemates,
        pace to the cap, the class ±7% band on days-to-cap, and the shipped roster against its own
        archetype contract. `--strict` exits 1 on a broken band; warnings never fail. 8 new tests.
        **Results: 18 of 18 rows level-invariant** (mean HP loss ×1.01–×1.16 across levels 1–40),
        no broken bands, 8 warnings.
  - [x] **8C — act on what it found** — three changes, all measured before and after.
        · **every stance lift is a multiplier now** (schema v8): the five `*Bonus` fields are gone
          from `StanceTuningDTO`, replaced by `*Multiplier` fields that are REQUIRED on decode.
          bloodlust attack ×1.35 / defence ×1.15 / vigor ×1.5 (was ×2.0 for a bonus that had rotted
          to +5%), hawks_eye crit ×1.60 / accuracy ×1.15 / dodge ×1.15, arcane_resonance attack
          ×1.50 / defence ×1.15. The warrior's techniques went from saving 5% of a fight to 13–21%.
        · **the warrior's budget was re-spent toward offence**: weapon attack 0.72 → 0.80 (accuracy
          0.14 → 0.06, which overshot the 95% hit cap by level 40 anyway), armour defence 0.82 →
          0.78 into HP, base attack 10 → 12. **Days-to-cap spread 17% → 9%**, inside the ±7%-of-mean
          band — and the tank trade finally shows: the warrior loses 50–53% of a bar to an elite
          where the mage loses 65%.
        · **monster silver removed entirely** — `enemies.silverReward`, `archetypes.silverMultiplier`,
          `exploration.passive.silverMultiplier`, both award sites and both locale lines. Every
          faucet left is a player-facing system with a sink attached, which also closes the
          "silverReward has no curve" gap by deleting the thing that needed one.
        · **the failed-flee counter was the last `max(1, ATK − DEF)` in the game** and was dealing
          1 HP to every class at every level (0.2–1.0% of a bar), so a failed escape was free.
          Routed through `applyAttack` with `cannotMiss` and crit rating 0: now 6.1% of a bar for
          a warrior, 8–9% for an archer or mage, 9–14% against an elite, and the same percentage
          at every level. Found by reading the diff — the simulator has no flee policy.
        **Result: 18 of 18 level-invariance rows pass, 0 broken bands.** New baseline
        `583a32cb5a9d9dc7` — `records` and `tuning` moved, `spawns` and `quests` did not.
        Still open and reported by every run: `shadowVeilDodgeBonus` (+50 = 238% of a level-1
        archer's dodge, 34% at the cap) and `defend.archerDodgeBonus` (+30 = 143% → 20%) are the
        same flat-bonus rot in the techniques beside the stances; the mage's 93% win rate against
        an elite at level 5 wants the spawn-level floor the plan specified; the bestiary is
        half-strength against its own archetypes (Phase 10).

- [ ] Phase 9 — Content specs in `content/spec/` **for approval before authoring**
- [ ] Phase 10 — Generate + author content; fill the 3 dead equipment slots; restore potions/scrolls
- [ ] Phase 11 — `WipeForRebalance` migration, `--strict` validation, live first-hour playtest

### 9.2 Content Authoring
- [ ] Full bestiary (all enemy types with stats and loot)
- [ ] Full recipe book (all crafting tiers)
- [x] **Daily NPC quests — v1** *(landed 2026-08-23)* — three quest-giving capital NPCs (Trader / Master / Innkeeper), 3 jobs each, **one auto-assigned job per NPC per game day** (no picking, no journal). Assignment is *derived*, not stored: stable FNV-1a over `userId:npc:GameDay.stamp()` indexes the pool, so it survives restarts and needs no DB write; only progress + claimed live in `quest_progress` (`QuestProgress` model + `CreateQuestProgress`, unique on user+npc+day). Two objective shapes — `deliver` (progress read live from the bag, items consumed at turn-in) and `counter` (ticked by hook sites: combat victory, passive-expedition kills, forge output, trader sales, tavern wins). Rewards: silver on every job + per-NPC accent (Trader = more silver, Master = XP, Innkeeper = Vigor); payouts funnel through `QuestService.payOut` and echo the combat level-up banner. `[📜 Замовлення]` on each NPC menu → board screen edited in place, plus a **quest journal «Нотатник»** on the profile screen (row under the 1/2/3 style buttons; read-only digest of all three jobs + countdown to the 12:00 rollover; claim-free by design). 43 locale keys × 2 (neutral except the gendered journal title).
- [ ] Quest definitions — chains + weeklies (deferred from v1: forester set, governor's feast, blood week, guild co-op, fortune-teller streaks)
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
- **Status effects (rabies)** *(was 4.3.5)* — bites from the rabid family (`enemy.rabid_lynx`, `enemy.rabid_wolf`) carry a chance to infect. Effect ticks over time (HP drain, stat penalty, vigor drain — TBD), persists across expeditions, cured at the Capital Chapel (Phase 6 dependency). Needs a generic status-effect system on `User` or a new model.
- **Combat log persistence + replay** *(was 4.3.6)* — record round-by-round combat events (damage rolls, hit/miss, technique uses, stance state) into a Codable blob; expose a "view replay" surface. Mostly useful once the Arena (Phase 8) lands, since solo PvE replays have low replay value.
- *(more items will be added by user as the project grows)*

---

*Last updated: 2026-05-11 part 5 — Phase 5.3a + 5.3b + 5.3c + 5.3d all landed. Next: 5.3e technique gates by player level + "Learn at Training Ground" flow + per-fight uses growth.*
