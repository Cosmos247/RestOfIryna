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

### 3.1 Exploration State
- [ ] Design ExplorationState model (user_id, current_km, next_room_at, loot_bag)
- [ ] Create migration
- [ ] Implement timed room transitions (5 min prod / 10 sec test mode)
- [ ] Add feature flag for test mode timing

### 3.2 ExplorationController
- [ ] Create controller with router registration
- [ ] Implement "start exploration" from main menu
- [ ] Implement room transition logic (timer check on interaction)
- [ ] Implement event rolling (weighted random from event table)
- [ ] Implement 5-km return prompt (HP/Hunger display + Continue/Return buttons)
- [ ] Implement double-speed travel (2x hunger cost, half time)
- [ ] Implement voluntary return (bank loot, return to main)
- [ ] Implement death handling (respawn, lose expedition loot)

### 3.3 Exploration Events
- [ ] "Nothing of note" — flavor text pool
- [ ] "Found item" — mushroom, herb, resource (depth-aware)
- [ ] "Tripped" — small HP loss (depth-gated)
- [ ] "Hidden cache / shrine" — rare currency or buff
- [ ] "Rabid animal encounter" — transition to combat
- [ ] "Dungeon entrance" — guaranteed every 7th room

### 3.4 Timed Action System
- [ ] Design hybrid approach: lazy compute on interaction + push notification scheduler
- [ ] Implement "you've arrived" notification for room completion
- [ ] Handle edge cases (user offline, multiple pending transitions)

---

## Phase 4: Combat System

### 4.1 Combat Engine
- [ ] Design CombatState model (participants, round, hp, actions, log)
- [ ] Implement damage formula (accuracy vs dodge, base damage, crit, defend multiplier)
- [ ] Implement simultaneous round resolution
- [ ] Implement combat log generation (readable on mobile)
- [ ] Add variance and clamp to damage calculations

### 4.2 CombatController (PvE)
- [ ] Create controller with 3-button UI (Attack, Defend, Auto)
- [ ] Implement auto-combat (server resolves rounds until end/stop)
- [ ] Implement extra action row (potions, food, spells — conditional)
- [ ] Implement enemy AI (aggression based on type)
- [ ] Handle combat end: victory (loot + XP) or defeat (death -> respawn)
- [ ] Message editing for combat rounds (avoid spam)

### 4.3 Bestiary
- [ ] Design Enemy model (species, tier, stats, loot table, depth range)
- [ ] Create T1-T4 enemy definitions + Boss tier
- [ ] Implement depth-aware enemy selection
- [ ] Create `content/bestiary.md` reference document

### 4.4 PvP Combat
- [ ] Implement PvP challenge system
- [ ] Add 30-second per-round timer (timeout = Defend)
- [ ] Handle mutual Auto (instant resolution)
- [ ] Arena integration (separate from territorial PvP)

---

## Phase 5: Estates & Crafting

### 5.1 Estate Model
- [ ] Design Estate model (30x30 grid as JSON/binary blob)
- [ ] Design Manor model (7x7 interior rooms)
- [ ] Design Plot model (type, tier, production timer, position)
- [ ] Create migrations
- [ ] Implement grid rendering as emoji tilemap

### 5.2 EstateController
- [ ] Create controller with grid view
- [ ] Implement manor room management (view, upgrade)
- [ ] Implement plot management (buy, assign type, upgrade)
- [ ] Implement production timers (lazy compute on visit)
- [ ] Implement resource harvesting from plots

### 5.3 Crafting System
- [ ] Design Recipe model (room requirement, materials, output, duration)
- [ ] Implement crafting UI in manor rooms
- [ ] Create initial recipe set per class
- [ ] Implement blueprint learning (drops, purchases)
- [ ] Create `content/recipes.md` reference document

### 5.4 Estate Placement
- [ ] Design global estate grid (coordinate system)
- [ ] Implement frontier-based placement for new players
- [ ] Implement adjacency queries (8-neighbor lookup)

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

*Last updated: 2026-04-17 — Phase 0 complete, all subsequent phases pending.*
