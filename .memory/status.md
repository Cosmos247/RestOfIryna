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
- [x] RegistrationController — multi-step: language, nickname, class, estate name
- [x] MainController — greeting, profile view (3 switchable styles), settings nav
- [x] SettingsController — language change via inline keyboard
- [x] GlobalCommandsController — /help, /settings, /buttons from any state

### Character System
- [x] CharacterClass enum (warrior/archer/mage) with icons
- [x] Multi-step registration (language -> nickname -> class -> estate name)
- [x] Character profile display with 3 switchable visual styles
- [x] Profile style preference saved per user
- [x] Dev profile reset flag for testing (resetDevProfile in configure.swift)

### Localization
- [x] English (en.json) — ~52 keys
- [x] Ukrainian (uk.json) — ~52 keys
- [x] Lingo integration with SupportedLocale enum
- [x] Interpolation support (%{full-name}, %{nickname}, %{class}, %{estate})

## What's Planned (from GDD, not yet implemented)

### Controllers Needed
- [ ] ExplorationController — timed room chain, events, dungeons
- [ ] CombatController — round-based PvE & PvP
- [ ] EstateController — 30x30 grid editor, manor rooms, plots
- [ ] MarketController — NPC stall + player bazaar
- [ ] GuildController — guild management
- [ ] ArenaController — PvP matchmaking
- [ ] PetController — taming, pet battles, assignments

### Models Needed
- [x] Character stats (HP, Attack, Defense, Crit, Dodge, Accuracy) — on User model
- [ ] Inventory system (items + quantities)
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

*Last updated: 2026-04-18 (registration rework + profile view)*
