# File Map

```
RestOfIryna/
├── .env.example                    # Environment template (TG token, DB creds)
├── .gitignore                      # Ignores .build, .env, .xcodeproj, etc.
├── .memory/                        # Project-scoped AI memory (this system)
├── Package.swift                   # SPM manifest, Swift 6.2, macOS 14+
├── GDD.md                          # Game Design Document (full v1 vision)
├── README.md                       # Project overview, arch, setup, dev notes
├── CLAUDE.md                       # AI assistant instructions & project reference
├── TODO.md                         # Phased progress tracker
├── Prompt.me                       # New-session primer
├── icon.png                        # Bot icon asset
│
├── Localizations/
│   ├── en.json                     # English strings (~207 keys)
│   └── uk.json                     # Ukrainian strings (~207 keys)
│
├── Assets/
│   ├── registration/               # Artwork for the onboarding narrative
│   │   ├── kings_charter.jpg       # Shown in the King's Oath step (same for every class)
│   │   ├── warrior_estate.jpg      # Wolves encounter step, warrior variant
│   │   ├── archer_estate.jpg       # ... archer
│   │   └── mage_estate.jpg         # ... mage
│   └── estate/                     # Per-level estate artwork (optional — empty until user adds files)
│       └── level_<N>.jpg           # e.g. level_1.jpg, level_2.jpg — filename = estate level index
│
├── Public/
│   └── favicon.ico                 # (if present)
│
├── PostgreSQL/                     # Docker volume mount for PG data
│
└── Swift/                          # All source code (SPM target root)
    ├── entrypoint.swift            # @main, logging setup, calls configure()
    ├── configure.swift             # App bootstrap: DB, Lingo, Bot, Hummingbird
    ├── routes.swift                # RouterStore actor + Sendable conformance
    │
    ├── Controllers/
    │   ├── AllControllers.swift     # Controller registry, attachAllHandlers()
    │   ├── MainController.swift    # Main hub, profile view (3 styles), Explore/Estate/Capital/Profile/Settings nav
    │   ├── RegistrationController.swift  # Multi-step: language, nickname, class, estate
    │   ├── SettingsController.swift      # Language change, back navigation
    │   ├── GlobalCommandsController.swift # /help, /settings, /buttons (any state)
    │   ├── ExplorationController.swift   # Phase 3.1 active + 3.2 visit-decay return + 3.3 passive mode. Entry shows mode picker [🏃 Розвідка / 🏕 Експедиція] when no state; passive branches into countdown status (in-flight) or report delivery (completed). Active: Step Forward increments & rolls with prior visit count; Step Back decrements & rolls (km ≥ 2) or arrives home (km ≤ 1). Reply keyboard [🚶 Step fwd] [🔙 Step back] / [🎒 Bag] only during active. Inline `explore:` callbacks for bag, mode-picker, duration-picker, passive-report close.
    │   ├── EstateController.swift        # Tree nav: Root → House (Workshop/Kitchen/Warehouse stubs) / Plot stub. Per-level artwork loader. Main-nav pass-through.
    │   ├── CapitalController.swift       # STUB (Phase 6): coming-soon + back to main
    │   └── InventoryController.swift     # Tree nav: root categories → drill-down with Use buttons for food/potion
    │
    ├── Models/
    │   ├── User.swift              # Fluent model: identity, class, nickname, estate, profile style, game stats
    │   ├── Item.swift              # Static item catalog: ItemType, ItemEffect, EquipmentSlot (8), GearStats, Item, ItemCatalog (code-based)
    │   ├── InventoryEntry.swift    # Fluent model: user_id, item_id, quantity, equipped_slot + add/remove/has/list/canAccept/slotsUsed helpers; 50-slot cap (equipped doesn't count)
    │   ├── WarehouseEntry.swift    # Fluent model: estate storage, separate table; add/list/totalQuantity helpers
    │   ├── ExplorationState.swift  # Fluent model: one row per active or passive expedition (user_id unique, stepsDeep, visited_rooms JSON dict, mode, ends_at, report_json). Presence = "exploring"; begin/beginPassive/current/end/allPassive helpers; recordVisit/visitCount + visitedRooms computed wrapper; isPassive/hasReadyReport/secondsRemaining queries; ExplorationMode enum (active / passive). The `returning` column still exists on the schema but isn't mapped here (dormant from an earlier 3.2 design pass).
    │   └── Enemy.swift             # Static bestiary (EnemyLootDrop + Enemy struct + EnemyCatalog). Code-based like ItemCatalog. 5 animals across 4 tiers: wild family (🐗 boar / 🫎 moose / 🦬 buffalo) drops meat+hide; rabid family (🐈‍⬛ lynx / 🐺 wolf) drops hide only.
    │
    ├── Migrations/
    │   ├── CreateUser.swift        # users table: id, telegram_id, router_name, locale, names
    │   ├── AddCharacterFields.swift # nickname, character_class, estate_name, registration_step
    │   ├── AddProfileStyle.swift   # profile_style (1-3)
    │   ├── AddGameStats.swift      # level, xp, hp, max_hp, hunger, max_hunger, atk/def/crit/dodge/acc, gold (crowns originally here)
    │   ├── CreateInventory.swift   # inventory table: user_id (FK, cascade), item_id, quantity, timestamps
    │   ├── RemoveCrownsField.swift # drops crowns column; premium currency name TBD
    │   ├── AddEquipSlotToInventory.swift # nullable equipped_slot column on inventory (Phase 2.3.2)
    │   ├── AddGearBonuses.swift    # 5 cached gear_*_bonus fields on users (Phase 2.3.2)
    │   ├── CreateWarehouse.swift   # warehouse table (Phase 5 — estate storage, separate from inventory)
    │   ├── CreateExplorationState.swift # exploration_state table (Phase 3.1): per-user stepsDeep, unique on user_id, cascades on user delete
    │   ├── AddExplorationReturnState.swift # (Phase 3.2): adds `visited_rooms` TEXT (JSON dict km → visit count) and a dormant `returning` Bool to exploration_state
    │   ├── AddHpRegenTick.swift    # (Phase 3.2 polish): adds `last_hp_tick_at` nullable Date to users
    │   ├── AddPassiveExpeditionFields.swift # (Phase 3.3): adds nullable `mode`, `ends_at`, `report_json` to exploration_state
    │   ├── RenameMaterialIds.swift # Data migration: mat.wood→mat.pine_lumber, mat.stone→mat.river_pebble, mat.iron_ore→mat.old_iron (inventory + warehouse)
    │   └── RenameFoodIds.swift    # Data migration: food.berry→food.forest_berries; bread/stew/roast rows deleted outright
    │
    ├── Services/
    │   ├── HungerService.swift    # Pure: HungerAction enum, drain, consume, isStarving, applyStarvationHPLoss, starvation penalty on effective ATK/DEF (on User via extension); effective-stat extension also includes crit/dodge/accuracy + gear bonuses
    │   ├── EquipmentService.swift # equip (atomic slot swap), unequip, equipped(for:), recomputeBonuses (writes cached gear_*_bonus on User)
    │   ├── WarehouseService.swift # deposit / withdraw — moves one unit between InventoryEntry and WarehouseEntry; returns typed enum (success / nothingToTransfer / inventoryFull); deposits skip equipped rows; withdraw preflights backpack space
    │   ├── ExplorationService.swift # Phase 3.1/3.2: rollStep with `priorVisits:Int` three-tier weight table (fresh 20/40/30/10 → reduced 50/20/20/10 → bare 100/0/0/0), autobattle stub, loot drop rolls, hunger/starvation integration. StepOutcome enum captures every path (nothing/loot/trip/encounterWon/encounterLost/starvationOnly).
    │   ├── HealingService.swift # Phase 3.2 polish: lazy-compute passive HP regen (5%·maxHp per minute) while player is NOT on any expedition (active or passive) and hp < maxHp. `tick(_:inExpedition:on:)` is called from RouterStore.process on every interaction — RouterStore queries ExplorationState presence to derive `inExpedition`. Pins `user.lastHpTickAt` at full HP and clears it during expedition to prevent banked regen.
    │   └── PassiveExpeditionService.swift # Phase 3.3: passive expedition. PassiveDuration (30/60/90 units), testMode flag (seconds vs minutes), start() arms a Task.detached running runLive (live per-step loop with Task.sleep between each step + absolute-fire-time catch-up after restart). Early exit on death pushes the report immediately. Progress tracked via state.stepsDeep so restart resumes at the right step. PassiveReport Codable blob stored in exploration_state.report_json. rescheduleInflight() runs on bot startup via configure.swift.
    │
    ├── Telegram/
    │   ├── Router/
    │   │   ├── Router.swift        # Path-matching engine (command, content type, callback)
    │   │   ├── Context.swift       # Request context: bot, db, lingo, update, session, args
    │   │   ├── Command.swift       # Command name matcher (slash handling, case sensitivity)
    │   │   ├── Commands.swift      # Commands enum (start, cancel, exit, settings, language, profile, explore, estate, capital, inventory)
    │   │   ├── ContentType.swift   # Enum of all matchable Telegram content types
    │   │   ├── Arguments.swift     # Scanner-based argument parser (words, ints, doubles)
    │   │   └── Router+Helpers.swift # Subscript shortcuts for adding handlers
    │   │
    │   └── TGBot/
    │       ├── TGDispatcher.swift   # Main dispatcher: auth + global cmds + router catch-all
    │       └── HummingbirdTGClient.swift # TGClientPrtcl impl using AsyncHTTPClient
    │
    └── Helpers/
        ├── TGBot+Extensions.swift  # TGControllerBase, Context.session, TGMessage helpers
        ├── SessionCache.swift      # Actor-based user cache (5min TTL, auto-cleanup)
        ├── Lingo+Locales.swift     # Lingo convenience: accept SupportedLocale enum
        └── DotEnv+Env.swift        # Env helper: get env vars with fallback to .env file
```
