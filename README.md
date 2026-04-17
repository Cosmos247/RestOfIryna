# Rest Of Iryna 🤖

[![Build Status](https://img.shields.io/badge/Build-Passing-brightgreen)](https://github.com/Maxim-Lanskoy/GPTGram/actions)
[![Swift](https://img.shields.io/badge/Swift-6.2-orange)](https://github.com/swiftlang/swift/releases/tag/swift-6.2-RELEASE)
[![Hummingbird](https://img.shields.io/badge/Hummingbird-2.10-blue)](https://github.com/hummingbird-project/hummingbird)

Telegram text RPG built with Swift, using a router-controller architecture, multiple languages, and database persistence.

<p align="center">[ <a href="https://docs.hummingbird.codes">Hummingbird Documentation</a> ]
  [ <a href="https://docs.vapor.codes/fluent/overview/#fluent">Fluent ORM / PostgreSQL</a> ]
  [ <a href="https://core.telegram.org/bots/api">Telegram Bot API</a> ]
  [ <a href="https://github.com/nerzh/swift-telegram-sdk">Swift Telegram SDK</a> ]
</p>

## 🎯 Purpose

Repo provides a robust foundation for building Telegram games in Swift with:
- **State-based navigation** using a router-controller pattern
- **Multi-language support** with dynamic locale switching
- **User session management** with PostgreSQL database persistence
- **Modern Swift concurrency** with async/await
- **Session caching** for improved performance
- **Lightweight HTTP server** with Hummingbird for webhooks/health checks

Perfect for creating bots that need to manage complex user interactions, multiple conversation states, and persistent data.

## 🏗️ Architecture

### Core Components

```
┌─────────────────────────────────────────────────────────────┐
│                     TGBot + Dispatcher                       │
│         (Bot instance stored in AppState)                    │
└─────────────────────────────────────────────────────────────┘
                               │
          ┌────────────────────┼────────────────────┐
          ▼                    ▼                    ▼
┌──────────────────┐ ┌──────────────────┐ ┌──────────────────┐
│  Global Commands │ │   Router System  │ │  Session Cache   │
│ (/help /settings)│ │ (State routing)  │ │ (Fast lookups)   │
└──────────────────┘ └──────────────────┘ └──────────────────┘
                               │
                    ┌──────────┴──────────┐
                    ▼                     ▼
        ┌─────────────────────┐   ┌───────────────────┐
        │    Controllers      │   │   User Sessions   │
        │ (Handle "UI" logic) │   │ (Persistent state)│
        └─────────────────────┘   └───────────────────┘
```

### Router-Controller Pattern

Project implements a sophisticated state machine where each controller represents a different "screen" or interaction mode:

1. **Router**: Processes incoming Telegram updates and routes them to the appropriate controller based on:
   - User's current state (stored in database)
   - Command matching
   - Content type (text, callback query, etc.)

2. **Controllers**: Each controller encapsulates logic for a specific interaction flow:
   - `RegistrationController`: Handles first-time user setup and language selection
   - `MainController`: The main menu and home screen
   - `SettingsController`: User preferences and configuration
   - Custom controllers can be easily added for new features

3. **Context**: Provides controllers with everything needed to handle requests:
   - Bot instance for sending messages
   - Database connection
   - Localization (Lingo)
   - User session data
   - Parsed arguments from commands

## 📁 Project Structure

```
RestOfIryna/
├── Swift/
│   ├── Controllers/              # Bot controllers (screens/states)
│   │   ├── AllControllers.swift  # Controller registry
│   │   ├── MainController.swift  # Main menu controller
│   │   ├── RegistrationController.swift
│   │   ├── SettingsController.swift
│   │   └── GlobalCommandsController.swift  # Global command handlers
│   │
│   ├── Models/                   # Database models (Fluent ORM)
│   │   └── User.swift           # User session and preferences
│   │
│   ├── Migrations/              # Database schema migrations
│   │   └── CreateUser.swift
│   │
│   ├── Telegram/
│   │   ├── Router/              # Routing system
│   │   │   ├── Router.swift     # Main router logic
│   │   │   ├── Context.swift    # Request context
│   │   │   ├── Commands.swift   # Command definitions
│   │   │   ├── ContentType.swift # Message content types
│   │   │   ├── Arguments.swift  # Command argument parsing
│   │   │   └── Router+Helpers.swift
│   │   │
│   │   └── TGBot/               # Bot infrastructure
│   │       ├── TGDispatcher.swift        # Unified dispatcher
│   │       └── HummingbirdTGClient.swift # AsyncHTTPClient for TG API
│   │
│   ├── Helpers/
│   │   ├── TGBot+Extensions.swift # Convenience extensions
│   │   ├── SessionCache.swift    # User session caching
│   │   ├── Lingo+Locales.swift   # Locale type-safe extensions
│   │   └── DotEnv+Env.swift      # Environment helpers
│   │
│   ├── entrypoint.swift         # Application entry point
│   ├── configure.swift          # Application configuration
│   └── routes.swift             # Router store for controllers
│
├── Resources/
│   └── Localizations/           # Multi-language support
│       ├── en.json              # English translations
│       └── uk.json              # Ukrainian translations
│
├── Public/                      # Static files for web routes
│   └── favicon.ico
│
├── Package.swift                # Swift Package Manager manifest
├── Package.resolved             # Dependency lock file
├── .env.example                 # Environment template
└── .gitignore
```

## 🚀 Getting Started

### Prerequisites

- **Swift 6.2+** toolchain
- **Xcode 16+** (optional, for IDE support)
- **Docker** (for PostgreSQL)
- **Telegram Bot Token** from [@BotFather](https://t.me/botfather)

### Installation

1. **Clone the repository**:
   ```bash
   git clone <repository-url>
   cd RestOfIryna
   ```

2. **Start PostgreSQL with Docker**:
   ```bash
   docker run -d \
     --name tgbot-postgres \
     -e POSTGRES_USER=tgbot \
     -e POSTGRES_PASSWORD=your-secure-password \
     -e POSTGRES_DB=tgbot_db \
     -p 5432:5432 \
     -v tgbot_pgdata:/var/lib/postgresql/data \
     postgres:16-alpine
   ```

3. **Configure environment**:
   ```bash
   cp .env.example .env
   ```
   Edit `.env` with your settings:
   ```env
   # Telegram Configuration
   TELEGRAM_BOT_TOKEN=YOUR_BOT_TOKEN_HERE

   # PostgreSQL Connection
   DB_HOST=localhost
   DB_PORT=5432
   DB_USER=tgbot
   DB_PASSWORD=your-secure-password
   DB_NAME=tgbot_db
   ```

4. **Update configuration**:

   Edit `Swift/configure.swift` and replace the following:
   - `projectPath`: Update to your actual project path
   - `owner` and `helper`: Replace with your Telegram user IDs
   - `@TGUserName`: Replace with your Telegram username in localizations

5. **Build and run**:
   ```bash
   swift build
   swift run
   ```

### Docker Commands Reference

```bash
# Check if container is running
docker ps

# View logs
docker logs tgbot-postgres

# Stop container
docker stop tgbot-postgres

# Start existing container
docker start tgbot-postgres

# Remove container (data persists in volume)
docker rm tgbot-postgres

# Connect to psql shell
docker exec -it tgbot-postgres psql -U tgbot -d tgbot_db

# Remove volume (WARNING: deletes all data)
docker volume rm tgbot_pgdata
```

### Finding Your Telegram User ID

To get your Telegram user ID:
1. Start a chat with [@ForwardInfoBot](https://t.me/ForwardInfoBot)
2. The bot will reply with your user ID
3. Add this ID to the `allowedUsers` array in `configure.swift`

## 💡 How It Works

### User Flow

1. **First Contact**: When a user messages the bot for the first time:
   - `User.cachedSession()` creates a new user record (with caching)
   - User is routed to `RegistrationController`
   - Language selection is presented

2. **State Management**: Each user has a `routerName` field that tracks their current controller:
   - `"registration"` → Registration flow
   - `"main"` → Main menu
   - `"settings"` → Settings menu
   - Custom states for your features

3. **Message Processing**:
   ```swift
   Update arrives → RouterStore finds current controller →
   Controller processes → Updates user state → Sends response
   ```

### Adding a New Feature

1. **Create a new controller**:
   ```swift
   final class MyFeatureController: TGControllerBase {
       override func attachHandlers(to bot: TGBot, lingo: Lingo) async {
           let router = Router(bot: bot) { router in
               router["/mycommand"] = onMyCommand
               router.unmatched = unmatched
           }
           await processRouterForEachName(router)
       }

       func onMyCommand(context: Context) async throws -> Bool {
           try await context.respond("Hello from my feature!")
           return true
       }
   }
   ```

2. **Register the controller** in `AllControllers.swift`:
   ```swift
   static let myFeature = MyFeatureController(routerName: "myfeature")
   static let all: [TGControllerBase] = [
       registration, mainController, settingsController, myFeature
   ]
   ```

3. **Add navigation** from another controller:
   ```swift
   context.session.routerName = "myfeature"
   try await context.session.saveAndCache(in: context.db)
   ```

### Working with Keyboards

Project provides sophisticated keyboard management:

```swift
// Reply keyboard (persistent buttons)
let markup = TGReplyKeyboardMarkup(keyboard: [
    [TGKeyboardButton(text: "Button 1"), TGKeyboardButton(text: "Button 2")]
], resizeKeyboard: true)

// Inline keyboard (buttons under messages)
let inline = TGInlineKeyboardMarkup(inlineKeyboard: [
    [TGInlineKeyboardButton(text: "Click me", callbackData: "action:123")]
])
```

## 🌐 Localization

Project includes built-in multi-language support:

1. **Add translations** to `Localizations/*.json`
2. **Use in code**:
   ```swift
   let welcomeText = lingo.localize("welcome", locale: user.locale)
   let greeting = lingo.localize("greeting.message", locale: user.locale,
                                  interpolations: ["full-name": user.name])
   ```

3. **Add new language**:
   - Create new JSON file in `Localizations/`
   - Add locale case to `SupportedLocale` enum in `configure.swift`
   - Update language selection UI in registration/settings

## 🔧 Configuration Options

### Environment Variables

| Variable | Description | Required |
|----------|-------------|----------|
| `TELEGRAM_BOT_TOKEN` | Bot token from BotFather | Yes |
| `DB_HOST` | PostgreSQL host | Yes |
| `DB_PORT` | PostgreSQL port (default: 5432) | No |
| `DB_USER` | PostgreSQL username | Yes |
| `DB_PASSWORD` | PostgreSQL password | Yes |
| `DB_NAME` | PostgreSQL database name | Yes |
| `PG_CONN_STR` | Full PostgreSQL connection URL (alternative) | No |

### Bot Settings

In `configure.swift`:
- `owner`, `helper` - Admin user IDs
- `allowedUsers` - Array of authorized user IDs (remove for public access)
- `SupportedLocale` - Enum with available languages and their flags

## 📚 Dependencies

- **[Hummingbird](https://github.com/hummingbird-project/hummingbird)** - Lightweight Swift HTTP server
- **[Fluent](https://docs.vapor.codes/fluent/overview/)** - ORM for database operations
- **[FluentPostgresDriver](https://github.com/vapor/fluent-postgres-driver)** - PostgreSQL driver
- **[AsyncHTTPClient](https://github.com/swift-server/async-http-client)** - HTTP client for Telegram API
- **[SwiftTelegramBot](https://github.com/nerzh/swift-telegram-sdk)** - Telegram Bot API client
- **[swift-dotenv](https://github.com/thebarndog/swift-dotenv)** - Environment file support
- **[Lingo](https://github.com/miroslavkovac/Lingo)** - Localization support

## 🛠️ Advanced Features

### Custom Routers

Create specialized routers for complex command handling:

```swift
router.add(.photo) { context in
    // Handle photo messages
}

router.add(.callback_query(data: "specific_action")) { context in
    // Handle specific callback
}
```

### Middleware-like Processing

Use `GlobalCommandsController` for global command handling that works across all states:
- `/help` - Always available
- `/settings` - Accessible from anywhere
- `/buttons` - Restore keyboard from any state

### Session Caching

The bot uses an actor-based cache for fast user session lookups:
```swift
// Get cached session (creates new user if needed)
let session = try await User.cachedSession(for: tgUser, db: db)

// Save and update cache after modifications
try await session.saveAndCache(in: db)

// Invalidate cache entry if needed
await session.invalidateCache()
```

### Health Check Endpoint

Hummingbird provides a health check endpoint at `http://localhost:8080/health` for monitoring.

## 🙏 Acknowledgments

- [Hummingbird](https://github.com/hummingbird-project/hummingbird) team for the excellent HTTP framework
- [swift-telegram-sdk](https://github.com/nerzh/swift-telegram-sdk) for Telegram integration
- Swift community for the amazing language and tooling
