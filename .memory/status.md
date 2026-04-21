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
- [x] RouterStore actor (thread-safe router dispatch)
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
- [x] RegistrationController — lore-driven 6-step flow: language → Artanian welcome + name → class selection → King's Oath (grants starter weapon) → wolf encounter stub → estate naming
- [x] MainController — greeting, profile view (3 switchable styles), settings nav, Explore/Inventory/Estate/Capital nav buttons
- [x] SettingsController — language change via inline keyboard
- [x] GlobalCommandsController — /help, /settings, /buttons from any state
- [x] ExplorationController — stub (coming-soon message + back), reserved for Phase 3
- [x] EstateController — stub (coming-soon message + back), reserved for Phase 5
- [x] CapitalController — stub (coming-soon message + back), reserved for Phase 6
- [x] InventoryController — tree navigation (root → category) via inline buttons; every item is a button (future description view); `[🍽 Use]` shown for all types except Materials (food/potion consume; gear/recipe/artifact toast "not yet available"); main-nav button pass-through; equip planned for Phase 2.3

### Character System
- [x] CharacterClass enum (warrior/archer/mage) with icons
- [x] Lore-driven 6-step registration (language → welcome + name → class → King's Oath → wolves → estate naming)
- [x] Character profile display with 3 switchable visual styles
- [x] Profile style preference saved per user
- [x] Dev profile reset flag for testing (resetDevProfile in configure.swift)

### Localization
- [x] English (en.json) — ~111 keys
- [x] Ukrainian (uk.json) — ~111 keys

### Services
- [x] HungerService — pure functions (drain, consume, effective-stat penalty, starvation HP loss); callers persist

### Equipment (Phase 2.3 — done)
- [x] 2.3.1 Slot design: `EquipmentSlot` enum (8 slots), `GearStats` struct, Item gains optional slot + gearStats. Starter gear wired: rusty_sword/simple_bow/wooden_staff → mainHand; leather_vest → chest.
- [x] 2.3.2 Data layer: `equipped_slot: String?` on `inventory` + 5 cached `gear_*_bonus: Int` on `users`. Migrations `AddEquipSlotToInventory` + `AddGearBonuses`.
- [x] 2.3.3 `EquipmentService` (equip / unequip / equipped(for:) / recomputeBonuses). Registration auto-equips the class starter weapon after the King's Oath. `User.effectiveAttack/Defense/Crit/Dodge/Accuracy` now read `base + gear − hunger penalty`.
- [x] 2.3.4 Inventory UI toggle: gear rows carry a persistent per-item icon (`Item.icon` — ⚔️ / 🏹 / 🪄 / 🦺 ...) visible whether equipped or not; action button toggles between "🛡 Equip" and "❌ Unequip" (callbacks `inv:equip:<id>` / `inv:unequip:<id>`). Profile gains a "Main hand: <item>" line on all three styles.
- [x] Lingo integration with SupportedLocale enum
- [x] Interpolation support (%{full-name}, %{nickname}, %{class}, %{estate})

## What's Planned (from GDD, not yet implemented)

### Controllers Needed
- [~] ExplorationController — stub exists; needs timed room chain, events, dungeons
- [ ] CombatController — round-based PvE & PvP
- [~] EstateController — stub exists; needs 30x30 grid editor, manor rooms, plots
- [~] CapitalController — stub exists; needs location menu, quests, stables, bank, chapel
- [ ] MarketController — NPC stall + player bazaar
- [ ] GuildController — guild management
- [ ] ArenaController — PvP matchmaking
- [ ] PetController — taming, pet battles, assignments

### Models Needed
- [x] Character stats (HP, Attack, Defense, Crit, Dodge, Accuracy) — on User model
- [x] Inventory system (items + quantities) — code-based Item catalog + `inventory` table with InventoryEntry; helpers for add/remove/has/list
- [ ] Equipment slots (helmet, chest, legs, boots, weapons, accessories)
- [ ] Estate model (30x30 grid, manor layout, plots)
- [ ] Exploration state (current km, timer, accumulated loot)
- [ ] Combat state (opponent, round, actions)
- [ ] Pet model (stats, species, bond, role)
- [ ] Guild model
- [ ] Market listings
- [ ] Quest/achievement tracking

### Game Systems Needed
- [x] Class selection during registration (warrior/archer/mage)
- [ ] Hunger system (drain, starvation, food)
- [ ] XP/leveling system
- [ ] Exploration loop (timed transitions, events, return prompts)
- [ ] Combat engine (damage formula, round resolution)
- [ ] Estate management (grid rendering, plot upgrades, production timers)
- [ ] Crafting system (recipes, room tiers)
- [ ] NPC and player market
- [ ] Pet taming and management
- [ ] Territorial warfare
- [ ] Dungeon system (instancing, party invites)
- [ ] Tutorial/onboarding quest

### Content Needed
- [ ] Bestiary (enemy types, stats, loot tables)
- [ ] Recipe book (crafting recipes per tier)
- [ ] Tuning curves (XP per level, hunger scaling, stat curves)
- [ ] Quest definitions
- [ ] Localization for all new game strings

---

*Last updated: 2026-04-19 (main-menu nav buttons + stub controllers for Explore/Estate/Capital)*
