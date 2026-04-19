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
│   ├── en.json                     # English strings (~82 keys)
│   └── uk.json                     # Ukrainian strings (~82 keys)
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
    │   ├── ExplorationController.swift   # STUB (Phase 3): coming-soon + back to main
    │   ├── EstateController.swift        # STUB (Phase 5): coming-soon + back to main
    │   ├── CapitalController.swift       # STUB (Phase 6): coming-soon + back to main
    │   └── InventoryController.swift     # Read-only viewer: entries grouped by ItemType, empty state
    │
    ├── Models/
    │   ├── User.swift              # Fluent model: identity, class, nickname, estate, profile style, game stats
    │   ├── Item.swift              # Static item catalog: ItemType, ItemEffect, Item, ItemCatalog (code-based)
    │   └── InventoryEntry.swift    # Fluent model: user_id, item_id, quantity + add/remove/has/list helpers
    │
    ├── Migrations/
    │   ├── CreateUser.swift        # users table: id, telegram_id, router_name, locale, names
    │   ├── AddCharacterFields.swift # nickname, character_class, estate_name, registration_step
    │   ├── AddProfileStyle.swift   # profile_style (1-3)
    │   ├── AddGameStats.swift      # level, xp, hp, max_hp, hunger, max_hunger, atk/def/crit/dodge/acc, gold (crowns originally here)
    │   ├── CreateInventory.swift   # inventory table: user_id (FK, cascade), item_id, quantity, timestamps
    │   └── RemoveCrownsField.swift # drops crowns column; premium currency name TBD
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
