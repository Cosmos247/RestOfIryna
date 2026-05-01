# Implementation Status

## What Exists (implemented and working)

### Infrastructure
- [x] Swift 6.2 project with all dependencies configured
- [x] Hummingbird HTTP server (health endpoint on :8080)
- [x] PostgreSQL integration via Fluent
- [x] Telegram Bot via long polling (swift-telegram-sdk)
- [x] HummingbirdTGClient (custom TGClientPrtcl using AsyncHTTPClient)
- [x] Environment config (.env via SwiftDotenv)
- [x] Logging (Swift Logging)

### Core Systems
- [x] Router-Controller state machine (full implementation)
- [x] RouterStore actor (thread-safe router dispatch + per-user dispatch serialization via token-keyed Task chain — prevents spam-tap races on cached User / ExplorationState)
- [x] TGDispatcher (auth + global commands + router catch-all)
- [x] Context object (bot, db, lingo, update, session, args)
- [x] Command system (Commands enum, Command class, ContentType matching)
- [x] Arguments parser (Scanner-based: words, ints, doubles, rest-of-string)
- [x] Session caching (actor-based, 5min TTL, auto-cleanup)
- [x] User model + migrations (identity, class, nickname, estate, profile style)
- [x] Authorization (hardcoded allowedUsers list)
- [x] Proper migration awaiting (try await migrator.prepareBatch().get())
- [x] Database connection pool graceful shutdown (defer in configure)

### Controllers
- [x] RegistrationController — lore-driven 6-step flow: language → Artanian welcome + name → class selection → King's Oath (grants starter weapon) → wolf encounter stub → estate naming. First message strips any leftover reply keyboard via `ReplyKeyboardRemove`. Nickname + estate-name inputs are validated against three character allow-lists (digits / Latin / Ukrainian) with separate error toasts for too short, too long, edge whitespace, consecutive spaces, and invalid characters; single internal spaces are permitted so two-word names work.
- [x] MainController — greeting, profile view (3 switchable styles), settings nav, Explore/Inventory/Estate/Capital nav buttons
- [x] SettingsController — language change via inline keyboard
- [x] GlobalCommandsController — /help, /settings, /buttons from any state
- [x] ExplorationController — Phase 3.1 active-mode MVP: step → outcome narrative (nothing / loot / trip / encounter / starvation) with depth+HP+hunger status card, in-expedition bag view (scoped to consumables) with one-tap eat/use + in-place refresh, return-home button that ends ExplorationState, death flow that wipes non-equipped inventory and respawns at HP=1 (hunger preserved). Reply keyboard is [🚶 Step] [🎒 Bag] [🔙 Return] while expedition is active. Main/Inventory/Estate onExplore now call showExploration — resumes current ExplorationState (stepsDeep preserved across bag trips) or begins a fresh one at km 0.
- [x] EstateController — stub (coming-soon message + back), reserved for Phase 5
- [x] CapitalController — stub (coming-soon message + back), reserved for Phase 6
- [x] EstateController — tree nav (Phase 5.0 scaffolding): Root (estate name + level + optional per-level artwork) → [🏠 House] drilldown with Workshop/Kitchen/Warehouse stubs / [🌾 Plot] stub; main-nav pass-through; switches between editMessageText and editMessageCaption based on whether the root rendered as text or photo.
- [x] InventoryController — tree navigation (root → category) via inline buttons; every item is a button with item-info modal showing the lore description on tap. Action acks (eat, equip, unequip) appear as an inline `✅ ...` status line above the refreshed view; warnings (raw food, no_effect, empty category, use_unavailable) appear as Telegram modal alerts via `showAlert: true`. Eat status appends current/max pool indicator ("+15 голоду (20/100)"). No top-strip toasts.

### Character System
- [x] CharacterClass enum (warrior/archer/mage) with icons
- [x] Lore-driven 6-step registration (language → welcome + name → class → King's Oath → wolves → estate naming)
- [x] Character profile display with 3 switchable visual styles
- [x] Profile style preference saved per user
- [x] Dev profile reset flag for testing (resetDevProfile in configure.swift)

### Localization
- [x] English (en.json) — ~236 keys
- [x] Ukrainian (uk.json) — ~236 keys

### Services
- [x] HungerService — pure functions (drain, consume, effective-stat penalty, starvation HP loss); callers persist. Now wired into ExplorationService.rollStep (walkRoom drain on every step, combatRound drain inside autobattle, starvation HP tick per room when hunger == 0).
- [x] EquipmentService — atomic equip/unequip with slot swap, recomputes cached gear bonuses on User
- [x] WarehouseService — deposit / withdraw one unit between InventoryEntry and WarehouseEntry (skips equipped gear on deposit)
- [x] ExplorationService — rollStep (nothing / loot / trip / encounter / starvationOnly outcome), depth-aware loot pool (shallow vs medium), resolveAutobattle on top of CombatService primitives (alternating strikes via applyAttack, hit/miss/crit math, ±10% variance, safety cap 50 rounds). Phase 4.1 active CombatController will share the same applyAttack so fights resolve with identical odds in either mode. Event weights: nothing 40 / loot 30 / encounter 25 / trip 5.
- [x] CombatService (Phase 4.1) — shared damage primitives used by both active CombatController and passive autobattle. `applyAttack(attackerATK,attackerCrit,attackerAcc,defenderDEF,defenderDodge) -> AttackOutcome (miss / hit / crit)` with clamp(70+acc-dodge, 10, 95)% hit chance, ×1.5 crit on roll vs `attackerCrit %`, ±10% variance. `chipDamage` for Defend's 30%-of-base parry-counter (no crit, always lands). Tuning constants exported (baseHitChance / critMultiplier / defendChipFraction / varianceRange) so both consumers stay in sync.

### Equipment (Phase 2.3 — done)
- [x] 2.3.1 Slot design: `EquipmentSlot` enum (8 slots), `GearStats` struct, Item gains optional slot + gearStats. Starter gear wired: rusty_sword/simple_bow/wooden_staff → mainHand; leather_vest → chest.
- [x] 2.3.2 Data layer: `equipped_slot: String?` on `inventory` + 5 cached `gear_*_bonus: Int` on `users`. Migrations `AddEquipSlotToInventory` + `AddGearBonuses`.
- [x] 2.3.3 `EquipmentService` (equip / unequip / equipped(for:) / recomputeBonuses). Registration auto-equips the class starter weapon after the King's Oath. `User.effectiveAttack/Defense/Crit/Dodge/Accuracy` now read `base + gear − hunger penalty`.
- [x] 2.3.4 Inventory UI toggle: gear rows carry a persistent per-item icon (`Item.icon` — ⚔️ / 🏹 / 🪄 / 🦺 ...) visible whether equipped or not; action button toggles between "🛡 Equip" and "❌ Unequip" (callbacks `inv:equip:<id>` / `inv:unequip:<id>`). Profile gains a "Main hand: <item>" line on all three styles.

### Estate (Phase 5 — scaffolding, started out of order while Phase 3/4 are paused)
- [x] 5.0 Navigation skeleton: `User.estateLevel` computed from player level (every 5 levels → +1 tier). `EstateController` tree nav with Root → House → room stubs / Plot stub. Per-level artwork loader (`Assets/estate/level_<N>.jpg`, text-only fallback). `MainController.onEstate` now calls `showEstate` instead of the old `showStub`; `InventoryController.onEstate` pass-through updated too. Warehouse room gets a real category browser (separate `WarehouseEntry` Fluent model + `CreateWarehouse` migration), live counts per category, drill-down item list; deposit/withdraw flows still pending.
- [ ] 5.1 30×30 grid + Plot model (real tile-based land management)
- [ ] 5.2 EstateController grid view + plot management + production timers
- [ ] 5.3 Crafting (Recipe model, workshop/kitchen flows, blueprint learning) — will also raise backpack slot cap via upgrade
- [ ] 5.4 Global estate placement + adjacency

### Exploration (Phase 3 — started)
- [x] 3.0 Backpack slot cap — `InventoryEntry.slotCap = 50` (non-equipped rows only). `add` throws `inventoryFull`; `canAccept` preflight. `WarehouseService.withdraw` returns typed enum so UI can show precise "backpack full" toast. `/grant` catches the error. Inventory root shows `X/50 slots`.
- [x] 3.1 Active exploration MVP — ExplorationState Fluent model (one row per active expedition, `stepsDeep` = current km, unique on user_id, deleted on return/death), EnemyCatalog code-based bestiary (5 animals across 4 tiers: wild boar / moose / buffalo + rabid lynx / wolf, with depth ranges and loot tables), ExplorationService (rollStep + autobattle stub + loot drops + hunger/starvation integration), rewritten ExplorationController with step/bag/return/death flow. Callbacks use `explore:` prefix. Pass-through on main/inventory/estate now resumes or begins an expedition instead of showing the stub.
- [x] 3.2 Return path with per-room visit decay — migration `AddExplorationReturnState` adds a `visited_rooms` TEXT column (JSON dict of km → visit count) and a dormant `returning` column (added in an earlier 3.2 design pass, now unused). `ExplorationService.rollStep` takes `priorVisits:Int` and picks a three-tier weight table: fresh (20/40/30/10), reduced (50/20/20/10), bare (100/0/0/0 — only .nothing / .starvationOnly). Expedition reply keyboard is `[🚶 Step fwd] [🔙 Step back]` / `[🎒 Bag]` — direction is implicit in the button. Step Back at km ≥ 2 decrements + rolls with prior visits; at km ≤ 1 it ends the expedition cleanly with no event. Each step increments the entered room's counter, so oscillating between two rooms deplete them fast (tier 2+ = bare). Three `.nothing` narrative variants (fresh / thinned / bare). /start and stray Cancel presses force-end without walking back.
- [x] Passive HP regen at the estate — 5% of maxHp per minute while the player is not on ANY expedition (active or passive) and hp < maxHp. `HealingService.tick(user:inExpedition:on:)` is called from `RouterStore.process` on every interaction (lazy compute, no background scheduler). `RouterStore` queries `ExplorationState.current` once per dispatch to derive `inExpedition`. `User.lastHpTickAt` column via `AddHpRegenTick` migration. Clock is cleared during expeditions and pinned to now at full HP, so banked regen never accumulates against future damage.
- [x] 3.3 Passive expedition MVP (test-mode) — `AddPassiveExpeditionFields` migration adds `mode` / `ends_at` / `report_json` columns. `PassiveExpeditionService` handles duration picker (30/60/90 units — test mode = seconds, prod = minutes), starts via Task.detached running `runLive` (live per-step loop that sleeps between steps, tracks progress via `state.stepsDeep`, and exits early on death so the report pushes immediately instead of waiting the full timer), serializes a `PassiveReport` JSON on the state row, pushes the completion message to the player's chat, and re-arms itself on bot restart via `rescheduleInflight` (catches up any steps that fell during downtime). ExplorationController entry shows a mode picker [🏃 Розвідка / 🏕 Експедиція] when no state is present; countdown status for inflight; report delivery + state cleanup on re-open. Daily 2h budget and early-cancel still pending. `testMode` constant on the service — flip to prod before shipping.
- [x] 3.4 Mode exclusivity — data-layer exclusivity from unique(user_id) on exploration_state. `showExploration` branches by state — tapping Explore during passive shows a "you're already on expedition, expected return MM:SS" message; during active it resumes the step view. Estate and Capital are both blocked during any expedition (governor is away). Idempotency guards on `explore:mode:*` / `explore:dur:*` callbacks prevent stale picker taps from silently overwriting an existing expedition. (A dynamic busy-label on the main keyboard was briefly tried in an earlier iteration; reverted in favor of the simpler gating-at-entry approach.)
- [x] Lingo integration with SupportedLocale enum
- [x] Interpolation support (%{full-name}, %{nickname}, %{class}, %{estate})

## What's Planned (from GDD, not yet implemented)

### Controllers Needed
- [x] ExplorationController — all of Phase 3 (3.0-3.4) landed. Still pending: dungeons (later phase), content expansion (3.5), flip testMode to prod.
- [x] CombatController — Phase 4.1 + 4.2 + 4.3.1 + 5.1 (Training Mode) landed. Active-mode encounters trigger `StepOutcome.encounterStarted(enemy)`; ExplorationController hands off to CombatController. Main keyboard: inline `[Attack][Defend] / [🪄 Techniques][Flee]`. Tapping `[🪄 Techniques]` edit-in-place reveals a class-flavoured submenu (Special Atk / Special Def / Super) with " × N" suffixes from the per-fight budget (2/2/1); spent buttons hide. Phase 4.2.1: Super stances (Bloodlust / Hawk's Eye / Arcane Resonance) with stance lifecycle on `combat_stance` + `combat_stance_rounds_left`. Phase 4.2.2: Special Attacks (Cleave / Vital Shot / Soulfire) via per-class `AttackModifiers`. Phase 4.2.3: Special Defenses (Iron Bulwark / Shadow Veil / Mirror Ward) with persistent effects on `combat_enemy_def_debuff` / `combat_player_dodge_buff` ticked via `tickDefenseEffects`. Per-fight budget on `combat_special_atk_uses` / `combat_special_def_uses` / `combat_super_uses`; `beginCombat` initialises 2/2/1, `endCombat` clears every combat-scoped column. Phase 4.3.1: class-specific Flee chances (warrior 40 / archer 70 / mage 90; mage pays +2 hunger teleport tax layered after stance multiplier) via `CombatService.fleeChance(forClass:)` + `fleeHungerExtra(forClass:)`. Stance + special mods + persistent effects all compose into the same `applyAttack` primitive. Hunger drain scales with stance multiplier (Bloodlust ×2). Class-flavoured emoji prefixes prepended in Swift (Lingo's `%{var}` parser breaks on leading UTF-16 surrogate pairs). Basic Attack/Defend unchanged from 4.1. Same controller drives the registration wolves fight at step 4 — `Registration.handleCombatEnd(won:)` on victory / defeat / flee / /start, detected via `session.registrationStep < 6`. Phase 4.3.2 (edit-in-place) and 4.3.3 (XP grant) deferred — user prefers visible per-round logs; XP will tie to estate progression during Phase 5.x. Per-enemy AI hooks, status effects (rabies), and combat log persistence moved to the new TODO.md `Future / Backlog` section.
- [~] EstateController — Phase 5.0 navigation skeleton landed (Root → House + Plot stubs); still needs 30x30 grid editor, manor rooms' real logic, crafting flows
- [~] CapitalController — stub exists; needs location menu, quests, stables, bank, chapel
- [ ] MarketController — NPC stall + player bazaar
- [ ] GuildController — guild management
- [ ] ArenaController — PvP matchmaking
- [ ] PetController — taming, pet battles, assignments

### Models Needed
- [x] Character stats (HP, Attack, Defense, Crit, Dodge, Accuracy) — on User model
- [x] Inventory system (items + quantities) — code-based Item catalog + `inventory` table with InventoryEntry; helpers for add/remove/has/list
- [x] Equipment slots (helmet, chest, legs, boots, main-hand, off-hand, accessory ×2) — `EquipmentSlot` enum + `equipped_slot` column + `EquipmentService`
- [ ] Estate model (30x30 grid, manor layout, plots)
- [x] Exploration state — ExplorationState (user_id + stepsDeep + visited_rooms JSON + mode + ends_at + report_json). Single table covers both modes. Per-room event snapshots for richer re-entry narration still deferred.
- [ ] Combat state (opponent, round, actions)
- [ ] Pet model (stats, species, bond, role)
- [ ] Guild model
- [ ] Market listings
- [ ] Quest/achievement tracking

### Game Systems Needed
- [x] Class selection during registration (warrior/archer/mage)
- [ ] Hunger system (drain, starvation, food)
- [ ] XP/leveling system
- [x] Exploration loop — active (3.1) + return path with visited-room decay (3.2) + passive with background scheduler + report (3.3) + mode exclusivity UI/guards (3.4) all landed. Still on deck: flip `PassiveExpeditionService.testMode` to prod, add optional daily budget + early cancel, content expansion (3.5).
- [ ] Combat engine (damage formula, round resolution)
- [ ] Estate management (grid rendering, plot upgrades, production timers)
- [ ] Crafting system (recipes, room tiers)
- [ ] NPC and player market
- [ ] Pet taming and management
- [ ] Territorial warfare
- [ ] Dungeon system (instancing, party invites)
- [ ] Tutorial/onboarding quest

### Content Needed
- [x] Bestiary — 7 animals across 6 tiers in code-based EnemyCatalog. Wild family (🐗 boar km 1-10 / 🫎 moose 6-15 / 🦬 buffalo 11-20 / 🐻 wild_bear 21-30) drops raw meat + hide; rabid family (🐈‍⬛ lynx 11-20 / 🐺 wolf 16-25 / 🐻‍❄️ rabid_bear 25-35) drops hide only. Three deep-zone overlaps stack: rabid_wolf↔wild_bear at 21-25, wild_bear↔rabid_bear at 25-30. Reference doc at `content/bestiary.md`. T5+ currently only has regular mobs; the dedicated boss is reserved for Phase 3.5.
- [ ] Recipe book (crafting recipes per tier)
- [ ] Tuning curves (XP per level, hunger scaling, stat curves)
- [ ] Quest definitions
- [ ] Localization for all new game strings

---

*Last updated: 2026-05-01 (Phase 5.2 Workshop crafting MVP landed. `Recipe` + `RecipeCatalog` code-based catalog with two categories — 🔥 Forge (smelting) and 🧵 Tannery (leather armor). `CraftingService.craft(...)` drains inputs from the combined inventory + warehouse pool (inventory first to free backpack slots, warehouse second) and deposits output into the inventory, with a post-drain slot accept-check so a craft never refuses spuriously when a 50/50 bag would have made room. `CraftResult` enum + `Shortage` struct power the UI's modal alerts. EstateController Workshop replaces the stub with a **two-screen flow**: outer list (compact — title + atmospheric description + one inline button per recipe, no in-body category headers) → detail screen on tap (description + `📜 Recipe` inputs + `📊 Stats` for gear outputs + `[🔨 Craft]` / `[🔙 Back]`). Successful craft refreshes the detail in place with a `✅ Crafted ...` banner appended at the **bottom** of the body (placement chosen so the banner stays visible without scrolling). Failures (missingMaterials / inventoryFull) surface as modal alerts and leave the screen unchanged. Five recipes ship: Iron Ingot (10× lump → 1× ingot) + Forester's leather set (Hood 2× / Boots 3× / Breeches 5× / Jerkin 6× hide; full suit = 16 hide → +7 DEF / +1 dodge). Placeholder `gear.leather_vest` (+2 DEF) retired into `gear.forester_jerkin` (+3 DEF) via `RenameLeatherVest` data migration — existing rows in inventory + warehouse remap in place. `WarehouseEntry.remove(...)` helper added to mirror `InventoryEntry.remove`. Dev seed bumped: `mat.hide` 1→16, `mat.iron` added at 10 (one full set + one ingot craftable on next launch). Inventory main-keyboard label and inventory header renamed `Інвентар → Сумка` (en stays "Inventory") to match the term used everywhere else in the bot. Reference doc at `content/recipes.md`. Kitchen cooking (5.2.1) + weapon-upgrade flow (5.2.2) still pending. Phase 5.1 plot system + Training Ground + iron resource overhaul landed (carryforward). Plot model + PlotCatalog + PlotService + PlotProductionService background ticker + EstateController plot drill-down + 5-type picker (Farm / Lumberyard / Mine / Coop / Training Ground). Mine bonus output: `mat.iron` (1/interval, cap 20) alongside `mat.river_pebble` primary. Harvest deposits to Warehouse (not bag). Training Ground spawns `enemy.training_dummy` with consequence-free combat (no hunger drain, no enemy counter, clean cannotMiss + DEF=0 player swings, dummy auto-revives) and routerName stays at "estate" so reply-keyboard nav stays usable; combat callbacks reach the controller via cross-controller `combat:*` forwarding. New `mat.iron_ingot` (Iron Ingot 🔳) placeholder for Phase 5.x Workshop crafting (planned recipe 10 lumps → 1 ingot). Legacy `mat.old_iron` retired and DB rows wiped via `RemoveOldIron` migration. Foraging pool refactored to weighted (`pickWeighted`) so iron sits at weight 2 vs 10 for staples. Initial farm grant at registration completion.)*
