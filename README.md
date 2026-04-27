# Rest Of Iryna (ROI) ⚔️🐺

[![Build Status](https://img.shields.io/badge/Build-Passing-brightgreen)](https://github.com/Maxim-Lanskoy/GPTGram/actions)
[![Swift](https://img.shields.io/badge/Swift-6.2-orange)](https://github.com/swiftlang/swift/releases/tag/swift-6.2-RELEASE)
[![Hummingbird](https://img.shields.io/badge/Hummingbird-2.10-blue)](https://github.com/hummingbird-project/hummingbird)

**ROI** is a massively-multiplayer medieval text RPG for Telegram, built in Swift. Players explore a kingdom plagued by an epidemic of rabies spreading through its wildlife, expanding their personal estates, battling mad beasts, and waging territorial wars against neighbors.

> 📖 **Full game design lives in [GDD.md](./GDD.md).** This README covers the project, the stack, and how to run it.

<p align="center">[ <a href="https://docs.hummingbird.codes">Hummingbird</a> ]
  [ <a href="https://docs.vapor.codes/fluent/overview/#fluent">Fluent / PostgreSQL</a> ]
  [ <a href="https://core.telegram.org/bots/api">Telegram Bot API</a> ]
  [ <a href="https://github.com/nerzh/swift-telegram-sdk">Swift Telegram SDK</a> ]
</p>

---

## 🎮 The Game in One Paragraph

The kingdom's forests have fallen to a rabies plague. Playing a **mage**, **warrior**, or **archer**, each player claims a 30×30 estate with a central manor, then ventures out to explore an infinite chain of wilderness rooms — finding resources, fighting rabid beasts, occasionally taming them, and diving into multi-player dungeons deep in the woods. Back home, they upgrade the manor, expand plots for farming / mining / livestock, craft gear and food, and — because land is finite — fight adjacent players for territory. The capital hosts markets, quests, guilds, and a PvP arena. See [GDD.md](./GDD.md) for the full system breakdown.

---

## 🏗️ Architecture

ROI is built on a router–controller state machine. Each controller represents a "screen" — registration, main menu, exploration, combat, estate editor, market — and the router dispatches incoming Telegram updates to whichever controller the user is currently in.

```
┌─────────────────────────────────────────────────────────────┐
│                     TGBot + Dispatcher                       │
│              (stored in AppState, shared)                    │
└─────────────────────────────────────────────────────────────┘
                               │
          ┌────────────────────┼────────────────────┐
          ▼                    ▼                    ▼
┌──────────────────┐ ┌──────────────────┐ ┌──────────────────┐
│  Global Commands │ │   Router System  │ │  Session Cache   │
│ (/help /settings)│ │ (per-user state) │ │ (actor-based)    │
└──────────────────┘ └──────────────────┘ └──────────────────┘
                               │
                    ┌──────────┴──────────┐
                    ▼                     ▼
        ┌─────────────────────┐   ┌───────────────────┐
        │  Game Controllers   │   │   User Sessions   │
        │  (Explore, Combat,  │   │  (PostgreSQL +    │
        │   Estate, Market…)  │   │    cache layer)   │
        └─────────────────────┘   └───────────────────┘
```

### Router–Controller Pattern

1. **Router** — inspects each update and routes it to the right controller, based on the user's `routerName` (persisted in DB), command matching, and content type (text / callback / photo).
2. **Controllers** — each encapsulates a discrete interaction flow. Current and planned controllers:
   - `RegistrationController` — lore-driven 6-step onboarding: language → Artanian welcome + name → class descriptions → King's Oath (grants class starter weapon) → wolf encounter with class-specific artwork → real CombatController fight against `enemy.rabid_wolf` (only victory advances; defeat / flee / `/start` is a soft retry with full HP) → estate naming. First message and the post-fight estate prompt both ship `ReplyKeyboardRemove` so leftover button labels (mode picker / combat keyboard) can't be submitted as names. Nickname + estate-name inputs are validated against digits / Latin / Ukrainian Cyrillic, single internal spaces only, with five distinct error toasts (too short / too long / edge space / consecutive spaces / invalid character).
   - `MainController` — town hub / main menu with Explore / Inventory / Estate / Capital / Profile / Settings nav
   - `SettingsController` — language, preferences
   - `ExplorationController` — Phase 3.1/3.2/3.3. Tapping 🗺 Explore opens a **mode picker** `[🏃 Reconnaissance]` (active) / `[🏕 Expedition]` (passive) — the picker keeps the player in `MainController`'s routerName so tapping any main-menu button cleanly dismisses the picker and navigates normally (handled via the `EphemeralChatState` actor + `dismissPendingPicker` helper). **Active**: step-forward / step-back / bag / death, reply keyboard `[🚶 Step fwd] [🔙 Step back]` / `[🎒 Bag]`, three-tier visit-decay weights (fresh → reduced → bare). **Passive**: duration picker (30/60/90 units, seconds in test mode / minutes in prod), `PassiveExpeditionService` arms a Task.detached + live per-step loop, pushes a combined "🏰 back at estate" + `PassiveReport` message to the player's chat on completion (no Close button — state is auto-deleted), and exits early on death so the report lands immediately. Startup rescheduler in `configure.swift` re-arms any in-flight passive expeditions across bot restarts. Death (in either mode) wipes non-equipped inventory and respawns at HP=1 (hunger preserved).
   - `EstateController` — tree nav: Root (per-level artwork, tiers 1–3 drawn) → House (Workshop / Kitchen stubs; Warehouse with real deposit/withdraw via `WarehouseService` — stackable types aggregate per item_id with counts on both sides, gear renders per physical row with a single-direction arrow) / Plot stub. Estate level is derived from `user.level` — every 5 player levels bumps it by one.
   - `CapitalController` *(stubbed)* — capital hub: market, quests, bank, arena
   - `InventoryController` — tree navigation; root shows all 5 category buttons with counts plus a fullness indicator (X/50 slots); drill-down renders each item as an inline button (future per-item description) plus a type-specific action. Food/potion consume via HungerService; gear is shown per-row (each physical unit is its own button, no `× N` aggregation) and toggles between 🛡 Equip / ❌ Unequip via EquipmentService, with a persistent per-item icon via `Item.icon`; artifact placeholder until TBD. Backpack is capped at 50 non-equipped slots — future exploration / warehouse withdraw respect this.
   - `CombatController` — Phase 4.1 turn-based PvE duel triggered when active-mode `rollStep` rolls an encounter. Actions are **inline buttons** on each round message (`combat:attack` / `combat:defend` / `combat:flee` callbacks) with class-flavoured labels (warrior = Slash / Parry / Retreat; archer = Arrow / Hide / Maneuver; mage = Magic / Barrier / Teleport); the controller owns no reply keyboard so the previous one (exploration's, or none during registration) stays visible but inert. Tapping anything outside the inline buttons mid-fight produces a one-line "you're in combat with X" nudge — the live buttons are still on the previous message above. Attack (−2 hunger) runs `CombatService.applyAttack` both directions; Defend (−1) chip-damages the enemy and doubles effective DEF for the round; Flee (−3) is 50/50 with a forced full-damage counter on fail. Victory awards loot via `ExplorationService.awardEncounterDrops` and hands the player back to ExplorationController at the same km; defeat shares `handleDeath`. The same controller also drives the registration wolves fight at step 4 — `Registration.handleCombatEnd(won:)` routes back into the registration flow when `session.registrationStep < 6`. Class-specific Defend/Flee mechanics, XP, edit-in-place UX, and status effects are deferred to 4.2/4.3.
   - `MarketController` *(planned)* — trading with players and NPCs
   - `GlobalCommandsController` — `/help`, `/settings`, `/buttons` (works from any state)
3. **Context** — passed to every controller; holds the bot instance, DB handle, localization (Lingo), user session, and parsed command arguments.

---

## 📁 Project Structure

```
RestOfIryna/
├── Swift/
│   ├── Controllers/              # Bot controllers (game screens)
│   │   ├── AllControllers.swift
│   │   ├── MainController.swift
│   │   ├── RegistrationController.swift
│   │   ├── SettingsController.swift
│   │   ├── GlobalCommandsController.swift
│   │   ├── ExplorationController.swift   # Phase 3.1 active exploration (step/bag/return/death) — encounters now hand off to CombatController
│   │   ├── CombatController.swift        # Phase 4.1 turn-based PvE duel (Attack/Defend/Flee, class-flavoured labels, registration wolves fight)
│   │   ├── EstateController.swift        # Phase 5.0 skeleton: Root → House (room stubs) / Plot stub; per-level artwork
│   │   ├── CapitalController.swift       # stub (Phase 6)
│   │   └── InventoryController.swift     # tree nav root → category; inline Use/Eat/Equip action buttons
│   │
│   ├── Models/                   # Fluent ORM models + code-based catalogs
│   │   ├── User.swift
│   │   ├── Item.swift            # static item catalog (code, not DB)
│   │   ├── InventoryEntry.swift  # per-user item stacks in the backpack (DB) + helpers
│   │   ├── WarehouseEntry.swift  # per-user estate storage (separate table from inventory)
│   │   ├── ExplorationState.swift # one row per expedition — active or passive (user_id unique, stepsDeep, mode, ends_at, report_json, visited_rooms)
│   │   └── Enemy.swift           # code-based bestiary (EnemyCatalog) — 5 animals across 4 tiers (wild + rabid families)
│   │
│   ├── Migrations/
│   │   ├── CreateUser.swift
│   │   ├── AddCharacterFields.swift
│   │   ├── AddProfileStyle.swift
│   │   ├── AddGameStats.swift
│   │   ├── CreateInventory.swift
│   │   ├── RemoveCrownsField.swift
│   │   ├── AddEquipSlotToInventory.swift
│   │   ├── AddGearBonuses.swift
│   │   ├── CreateWarehouse.swift
│   │   ├── CreateExplorationState.swift
│   │   ├── AddExplorationReturnState.swift
│   │   ├── AddHpRegenTick.swift
│   │   ├── AddPassiveExpeditionFields.swift
│   │   ├── RenameMaterialIds.swift
│   │   ├── RenameFoodIds.swift
│   │   └── AddCombatFields.swift
│   │
│   ├── Services/                 # Domain services
│   │   ├── HungerService.swift   # drain, consume, starvation penalty, HP loss (pure)
│   │   ├── EquipmentService.swift # atomic equip/unequip, bonus recomputation
│   │   ├── WarehouseService.swift # deposit/withdraw between inventory and warehouse
│   │   ├── ExplorationService.swift # step outcome roll + autobattle stub + loot drops
│   │   ├── HealingService.swift  # passive HP regen (5%·maxHp/min) while at estate
│   │   ├── PassiveExpeditionService.swift # passive-mode duration picker + Task.sleep scheduler + simulation + report push
│   │   └── CombatService.swift   # Phase 4.1 shared damage primitives (applyAttack hit/miss/crit + chipDamage for Defend)
│   │
│   ├── Telegram/
│   │   ├── Router/               # Routing system
│   │   │   ├── Router.swift
│   │   │   ├── Context.swift
│   │   │   ├── Commands.swift
│   │   │   ├── ContentType.swift
│   │   │   ├── Arguments.swift
│   │   │   └── Router+Helpers.swift
│   │   └── TGBot/
│   │       ├── TGDispatcher.swift
│   │       └── HummingbirdTGClient.swift
│   │
│   ├── Helpers/
│   │   ├── TGBot+Extensions.swift
│   │   ├── SessionCache.swift
│   │   ├── Lingo+Locales.swift
│   │   ├── EphemeralChatState.swift  # in-memory actor — tracks transient mode-picker message IDs per user
│   │   └── DotEnv+Env.swift
│   │
│   ├── entrypoint.swift
│   ├── configure.swift
│   └── routes.swift
│
├── Localizations/
│   ├── en.json
│   └── uk.json
│
├── Assets/
│   ├── registration/                # Artwork used during onboarding
│   │   ├── kings_charter.jpg        # Shown in the King's Oath step (all classes)
│   │   ├── warrior_estate.jpg       # Wolves encounter (warrior)
│   │   ├── archer_estate.jpg        # Wolves encounter (archer)
│   │   └── mage_estate.jpg          # Wolves encounter (mage)
│   └── estate/                      # Per-level estate artwork (optional; added as drawn)
│       └── level_<N>.jpg            # e.g. level_1.jpg, level_2.jpg …
│
├── Public/
│   └── favicon.ico
│
├── GDD.md                        # Game design document — read this
├── README.md
├── Package.swift
├── Package.resolved
├── .env.example
└── .gitignore
```

---

## 🚀 Getting Started

### Prerequisites

- **Swift 6.2+** toolchain
- **Xcode 16+** (optional, for IDE support)
- **Docker** (for PostgreSQL)
- **Telegram Bot Token** from [@BotFather](https://t.me/botfather)

### Installation

1. **Clone**:
   ```bash
   git clone <repository-url>
   cd RestOfIryna
   ```

2. **Start PostgreSQL**:
   ```bash
   docker run -d \
     --name roi-postgres \
     -e POSTGRES_USER=roi \
     -e POSTGRES_PASSWORD=your-secure-password \
     -e POSTGRES_DB=roi_db \
     -p 5432:5432 \
     -v roi_pgdata:/var/lib/postgresql/data \
     postgres:16-alpine
   ```

3. **Configure environment**:
   ```bash
   cp .env.example .env
   ```
   ```env
   TELEGRAM_BOT_TOKEN=YOUR_BOT_TOKEN_HERE
   DB_HOST=localhost
   DB_PORT=5432
   DB_USER=roi
   DB_PASSWORD=your-secure-password
   DB_NAME=roi_db
   ```

4. **Update `Swift/configure.swift`**:
   - `projectPath` — your absolute project path
   - `@TGUserName` — your Telegram username in localizations

5. **Run**:
   ```bash
   swift build
   swift run
   ```

### Docker Reference

```bash
docker ps                                              # status
docker logs roi-postgres                               # logs
docker stop roi-postgres                               # stop
docker start roi-postgres                              # resume
docker exec -it roi-postgres psql -U roi -d roi_db     # psql shell
docker volume rm roi_pgdata                            # wipe data ⚠️
```

### Finding Your Telegram User ID

DM [@ForwardInfoBot](https://t.me/ForwardInfoBot) — it replies with your ID. Add it to `allowedUsers` in `configure.swift` for admin access.

---

## 💡 Development Notes

### Adding a New Controller

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
        try await context.respond("Hello from ROI!")
        return true
    }
}
```

Register in `AllControllers.swift`:
```swift
static let myFeature = MyFeatureController(routerName: "myfeature")
static let all: [TGControllerBase] = [
    registration, mainController, settingsController, myFeature
]
```

Transition into it from another controller:
```swift
context.session.routerName = "myfeature"
try await context.session.saveAndCache(in: context.db)
```

### Session Caching

```swift
let session = try await User.cachedSession(for: tgUser, db: db)  // fetch or create
try await session.saveAndCache(in: db)                            // persist + refresh cache
await session.invalidateCache()                                   // drop cache entry
```

### Keyboards

```swift
// Persistent reply keyboard (main menu, exploration nav)
let markup = TGReplyKeyboardMarkup(keyboard: [
    [TGKeyboardButton(text: "🚶 Step fwd"), TGKeyboardButton(text: "🔙 Step back")],
    [TGKeyboardButton(text: "🎒 Bag")]
], resizeKeyboard: true)

// Inline keyboard (callbacks — exploration events, estate tiles, combat actions)
let inline = TGInlineKeyboardMarkup(inlineKeyboard: [
    [TGInlineKeyboardButton(text: "Continue deeper", callbackData: "explore:continue")]
])
```

### Localization

```swift
let text = lingo.localize("welcome", locale: user.locale)
let greeting = lingo.localize("combat.hit", locale: user.locale,
                              interpolations: ["damage": damage])
```

Add a new language by creating `Localizations/<code>.json` and adding a case to `SupportedLocale` in `configure.swift`.

---

## 🔧 Configuration Reference

| Variable | Description | Required |
|----------|-------------|----------|
| `TELEGRAM_BOT_TOKEN` | Bot token from BotFather | Yes |
| `DB_HOST` | PostgreSQL host | Yes |
| `DB_PORT` | PostgreSQL port (default 5432) | No |
| `DB_USER` | PostgreSQL username | Yes |
| `DB_PASSWORD` | PostgreSQL password | Yes |
| `DB_NAME` | PostgreSQL database name | Yes |
| `PG_CONN_STR` | Full connection URL (alternative) | No |

Bot-level settings in `configure.swift`:
- `allowedUsers` — authorized IDs (remove for public access)
- `SupportedLocale` — enum of languages with flag emojis

---

## 📚 Dependencies

- **[Hummingbird](https://github.com/hummingbird-project/hummingbird)** — HTTP server (webhook / health endpoint)
- **[Fluent](https://docs.vapor.codes/fluent/overview/)** — ORM
- **[FluentPostgresDriver](https://github.com/vapor/fluent-postgres-driver)** — Postgres driver
- **[AsyncHTTPClient](https://github.com/swift-server/async-http-client)** — HTTP client for Telegram API
- **[swift-telegram-sdk](https://github.com/nerzh/swift-telegram-sdk)** — Telegram Bot API bindings
- **[swift-dotenv](https://github.com/thebarndog/swift-dotenv)** — `.env` support
- **[Lingo](https://github.com/miroslavkovac/Lingo)** — localization

---

## 🗺️ Roadmap

ROI targets **1,000–3,000 concurrent players** in a shared world. Version 1 includes the full game vision: exploration, combat (PvE + PvP), estates, territorial wars, guilds, dungeons, taming, and the capital city with arena.

See [**GDD.md**](./GDD.md) for systems detail, numeric tuning placeholders, and scope notes.

---

## 🙏 Acknowledgments

- The [Hummingbird](https://github.com/hummingbird-project/hummingbird) team
- [swift-telegram-sdk](https://github.com/nerzh/swift-telegram-sdk) by @nerzh
- The Swift Server Work Group for the ecosystem

*"Rest Of Iryna" is the working title; **ROI** is the persistent brand — the letters will find new meaning as the game grows.*
