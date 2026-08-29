//
//  configure.swift
//  RestOfIryna
//
//  Created by Maxim Lanskoy on 13.06.2025.
//  Maintained by Dmytro Ihnatyuhin from 17.04.2026.
//

import FluentPostgresDriver
import Fluent
import Foundation
import Hummingbird
import Logging
import AsyncHTTPClient
import SwiftDotenv
import SwiftTelegramBot
@preconcurrency import Lingo

let store = RouterStore()

/// Root path of the project on disk. Used to locate `Localizations/`, `Assets/`, etc.
/// Read from the process env (`ROI_PROJECT_PATH`) so each deployment box can point
/// at its own checkout without merge conflicts. Falls back to the dev Mac path.
/// Must be a real env var (shell rc / systemd `Environment=`) — `.env` is loaded
/// LATER, using this very path.
public let projectPath: String = ProcessInfo.processInfo.environment["ROI_PROJECT_PATH"]
    ?? "/Users/cosmos/RestOfIryna"

let maxim: Int64 = 327887608
let basel: Int64 = 768795585
let mitya: Int64 = 398698463
let irina: Int64 = 1269829617
let allowedUsers: [Int64] = [mitya, irina, maxim, basel]
let developerUsers: [Int64] = [mitya]

/// Reset dev profile on every launch (sets mitya back to registration)
let resetDevProfile = false

/// Seed a starter inventory + warehouse for every `developerUsers` account on launch.
/// Per-item top-up (never reduces), so it recovers gracefully from catalog changes.
let seedDevInventory = false

// MARK: - Character Classes
public enum CharacterClass: String, CaseIterable, Codable, Sendable {
    case warrior = "warrior"
    case archer = "archer"
    case mage = "mage"

    func icon() -> String {
        switch self {
        case .warrior: return "⚔️"
        case .archer: return "🏹"
        case .mage: return "🔮"
        }
    }

    /// Starting stats for level 1 (hp, atk, def, crit%, dodge, acc)
    var startingStats: (hp: Int, attack: Int, defense: Int, crit: Int, dodge: Int, accuracy: Int) {
        switch self {
        case .warrior: return (hp: 120, attack: 10, defense: 12, crit: 5,  dodge: 5,  accuracy: 10)
        case .archer:  return (hp: 90,  attack: 14, defense: 8,  crit: 10, dodge: 8,  accuracy: 14)
        case .mage:    return (hp: 80,  attack: 15, defense: 6,  crit: 12, dodge: 6,  accuracy: 10)
        }
    }

    /// Starter weapon granted on registration when this class is chosen.
    /// Must reference an entry in ItemCatalog.
    var starterWeaponId: String {
        switch self {
        case .warrior: return "gear.rusty_sword"
        case .archer:  return "gear.simple_bow"
        case .mage:    return "gear.wooden_staff"
        }
    }

    /// Filename under `Assets/registration/` for the class+gender-specific
    /// "approaching the estate" artwork shown during the rabid-dog encounter
    /// step (e.g. `warrior_estate_f.jpg`).
    func journeyImageName(gender: CharacterGender) -> String {
        return "\(rawValue)_estate_\(gender.rawValue).jpg"
    }
}

// MARK: - Character Gender
/// Player gender chosen during registration. Drives Ukrainian feminitive text
/// variants (`Lingo.localize(_:gender:locale:)`) and per-gender estate artwork.
/// English copy is gender-neutral, so this only affects the `uk` locale and
/// asset selection.
public enum CharacterGender: String, CaseIterable, Codable, Sendable {
    case male = "m"
    case female = "f"

    func icon() -> String {
        switch self {
        case .male:   return "♂️"
        case .female: return "♀️"
        }
    }
}

// MARK: - Localization
public enum SupportedLocale: String, CaseIterable, Codable, Sendable {
    case en = "en"
    case ua = "uk"

    func flag() -> String {
        switch self {
        case .en: return "🇬🇧"
        case .ua: return "🇺🇦"
        }
    }
}

// MARK: - Application State
public final class AppState: Sendable {
    public let db: any Database
    public let lingo: Lingo
    public let logger: Logger
    public let httpClient: HTTPClient
    public nonisolated(unsafe) var bot: TGBot!

    public init(db: any Database, lingo: Lingo, logger: Logger, httpClient: HTTPClient) {
        self.db = db
        self.lingo = lingo
        self.logger = logger
        self.httpClient = httpClient
    }
}

/// Global application state - initialized during configure
public nonisolated(unsafe) var appState: AppState!

// MARK: - Setting up Hummingbird Application.
public func configure(logger: Logger) async throws {

    try Dotenv.configure(atPath: "\(projectPath)/.env", overwrite: false)

    // MARK: - Database Setup (Fluent + PostgreSQL)

    let databases = Databases(threadPool: .singleton, on: MultiThreadedEventLoopGroup.singleton)
    defer {
        let databases = databases
        DispatchQueue.global().async { databases.shutdown() }
    }

    // Configure PostgreSQL connection
    let postgresConfig = SQLPostgresConfiguration(
        hostname: try Env.get("DB_HOST", default: "localhost"),
        port: Int(try Env.get("DB_PORT", default: "5432"))!,
        username: try Env.get("DB_USER"),
        password: try Env.get("DB_PASSWORD"),
        database: try Env.get("DB_NAME"),
        tls: .disable
    )
    databases.use(.postgres(configuration: postgresConfig), as: .psql)

    let db = databases.database(.psql, logger: logger, on: MultiThreadedEventLoopGroup.singleton.any())!

    // MARK: - Migrations

    let migrations = Migrations()
    migrations.add(CreateUser())
    migrations.add(AddCharacterFields())
    migrations.add(AddProfileStyle())
    migrations.add(AddGameStats())
    migrations.add(CreateInventory())
    migrations.add(RemoveCrownsField())
    migrations.add(AddEquipSlotToInventory())
    migrations.add(AddGearBonuses())
    migrations.add(CreateWarehouse())
    migrations.add(CreateExplorationState())
    migrations.add(AddExplorationReturnState())
    migrations.add(AddHpRegenTick())
    migrations.add(AddPassiveExpeditionFields())
    migrations.add(RenameMaterialIds())
    migrations.add(RenameFoodIds())
    migrations.add(AddCombatFields())
    migrations.add(AddCombatStanceFields())
    migrations.add(AddCombatDefenseFields())
    migrations.add(AddCombatTechniqueUses())
    migrations.add(CreatePlots())
    migrations.add(RemoveOldIron())
    migrations.add(RenameLeatherVest())
    migrations.add(CreateLearnedRecipes())
    migrations.add(AddPassiveRunningReport())
    migrations.add(AddInventoryTier())
    migrations.add(AddEstateLevel())
    migrations.add(AddUserBagTier())
    migrations.add(CreateLearnedTechniques())
    migrations.add(AddUserLocation())
    migrations.add(CreateTravelState())
    migrations.add(AddFortuneFields())
    migrations.add(AddFortuneCooldownField())
    migrations.add(RenameGoldToSilver())
    migrations.add(AddTutorialTraderHint())
    migrations.add(AddCombatRound())
    migrations.add(CreateTavernGameMessages())
    migrations.add(AddGender())
    migrations.add(AddGearCondition())
    migrations.add(CreateMarketListings())
    migrations.add(CreateGuilds())
    migrations.add(AddUserGuildFields())
    migrations.add(CreateGuildInvites())
    migrations.add(CreateGuildVault())
    migrations.add(CreateArenaProfiles())

    let migrator = Migrator(databases: databases, migrations: migrations, logger: logger, on: MultiThreadedEventLoopGroup.singleton.any())
    try await migrator.setupIfNeeded().get()
    try await migrator.prepareBatch().get()

    // MARK: - Localization

    let lingo = try Lingo(rootPath: "\(projectPath)/Localizations", defaultLocale: "en")

    // MARK: - HTTP Client

    let httpClient = HTTPClient(eventLoopGroupProvider: .shared(MultiThreadedEventLoopGroup.singleton))

    // MARK: - Application State

    appState = AppState(db: db, lingo: lingo, logger: logger, httpClient: httpClient)

    // MARK: - Telegram Bot Setup

    let tgApi: String = try Env.get("TELEGRAM_BOT_TOKEN")

    // Create bot with AsyncHTTPClient
    appState.bot = try await .init(
        connectionType: .longpolling(),
        tgClient: HummingbirdTGClient(httpClient: httpClient, logger: logger),
        tgURI: TGBot.standardTGURL,
        botId: tgApi,
        log: logger
    )

    // Create and add unified dispatcher (auth + global commands + routing)
    let dispatcher = TGDispatcher(bot: appState.bot, appState: appState)
    try await appState.bot.add(dispatcher: dispatcher)

    // Attach controller-specific handlers
    await Controllers.attachAllHandlers(for: appState.bot, lingo: lingo)

    // MARK: - Dev Profile Reset
    if resetDevProfile {
        for developer in developerUsers {
            if let user = try await User.query(on: db).filter(\.$telegramId, .equal, developer).first() {
                user.routerName = "registration"
                user.registrationStep = 0
                user.nickname = nil
                user.characterClass = nil
                user.gender = nil
                user.estateName = nil
                user.level = 1
                user.xp = 0
                user.hp = 100
                user.maxHp = 100
                user.vigor = 100
                user.maxVigor = 100
                user.attack = 10
                user.defense = 10
                user.crit = 5
                user.dodge = 5
                user.accuracy = 10
                user.silver = 0
                user.gearAttackBonus = 0
                user.gearDefenseBonus = 0
                user.gearCritBonus = 0
                user.gearDodgeBonus = 0
                user.gearAccuracyBonus = 0
                user.location = "estate"
                user.activeFortuneCardId = nil
                user.activeFortuneExpiresAt = nil
                // Dev convenience: keep the trader-hint flag set so the tutorial
                // line doesn't pop up on every reset cycle. Flip to false in
                // Postico to retest the hint flow.
                user.tutorialTraderHintShown = true
                try await user.saveAndCache(in: db)

                // Wipe any in-flight travel row so a stale trip from a
                // previous session doesn't block the freshly-reset profile.
                try await TravelState.end(for: user, on: db)

                // Also wipe inventory + warehouse so registration-grants + seeds start from scratch.
                let existingEntries = try await InventoryEntry.list(for: user, on: db)
                for entry in existingEntries {
                    try await entry.delete(on: db)
                }
                let existingWarehouse = try await WarehouseEntry.list(for: user, on: db)
                for entry in existingWarehouse {
                    try await entry.delete(on: db)
                }

                // Wipe any stale ExplorationState row so a passive report from
                // a previous session can't resurface on the first Explore tap
                // after registration. `.end` is a no-op if no row exists.
                try await ExplorationState.end(for: user, on: db)

                let name = user.nickname ?? "\((user.telegramId))"
                logger.info("Dev profile reset for \(name) (wiped \(existingEntries.count) inventory + \(existingWarehouse.count) warehouse row(s))")
            }
        }
    }

    // MARK: - Dev Inventory + Warehouse Seed (developerUsers)
    // Each developer user's backpack + warehouse is brought up to the target
    // quantities below. Per-item top-up so the seed recovers gracefully from
    // catalog changes: quantities are never reduced, and rows that reference an
    // item_id no longer in the catalog are cleaned up first. Starter class weapons
    // come from registration, so they're deliberately left out of this list.
    if seedDevInventory {
        let seed: [(String, Int)] = [
            // Cooking ingredients — bumped so dev can craft every Kitchen
            // recipe at least once on first launch (Governor's Feast needs
            // 3 meat + 3 potato + 2 egg + 2 berries + 2 nuts).
            ("food.forest_berries", 6),
            ("food.forest_nuts", 6),
            ("food.duck_egg", 5),
            ("food.raw_meat", 5),
            ("food.potato", 5),
            ("mat.pine_lumber", 15),
            ("mat.river_pebble", 3),
            ("mat.clay", 2),
            ("mat.iron", 10),
            ("mat.hide", 16),
            ("potion.heal_small", 2),
            ("artifact.shrine_coin", 1),
            // Phase 5.2.1: every Kitchen scroll so dev can test the Learn
            // flow end-to-end. Baked Potato + Roasted Meat have no scrolls —
            // they're always-available starters cookable from day one.
            ("artifact.recipe.foragers_omelette", 1),
            ("artifact.recipe.hunters_stew", 1),
            ("artifact.recipe.meat_ragout", 1),
            ("artifact.recipe.berry_tart", 1),
            ("artifact.recipe.governors_feast", 1),
        ]

        for developer in developerUsers {
            guard let devUser = try await User.query(on: db).filter(\.$telegramId, .equal, developer).first(),
                  let devId = devUser.id else { continue }
            let label = devUser.nickname ?? "\(developer)"

            // Recipe-scroll skip set: any seed entry that teaches a recipe
            // already in `learned_recipes` is dropped from this run, both for
            // inventory and warehouse. Without this the dev keeps getting the
            // same scroll back on every relaunch even after Learn deletes it.
            var skipItems: Set<String> = []
            for (itemId, _) in seed {
                guard let item = ItemCatalog.find(itemId),
                      let recipeId = item.teachesRecipe else { continue }
                if try await LearnedRecipe.has(recipeId, for: devUser, on: db) {
                    skipItems.insert(itemId)
                }
            }
            if !skipItems.isEmpty {
                logger.info("Dev seed: \(label) already knows \(skipItems.count) recipe(s); skipping their scrolls")
            }

            // Inventory: orphan cleanup + top-up.
            let allEntries = try await InventoryEntry.list(for: devUser, on: db)
            var orphansDeleted = 0
            for entry in allEntries where ItemCatalog.find(entry.itemId) == nil {
                try await entry.delete(on: db)
                orphansDeleted += 1
            }
            if orphansDeleted > 0 {
                logger.info("Cleaned \(orphansDeleted) orphaned inventory row(s) for \(label)")
            }
            var grantedCount = 0
            for (itemId, targetQty) in seed {
                if skipItems.contains(itemId) { continue }
                let have = try await InventoryEntry.totalQuantity(of: itemId, for: devId, on: db)
                if have < targetQty {
                    do {
                        try await InventoryEntry.add(itemId, quantity: targetQty - have, to: devUser, on: db)
                        grantedCount += 1
                    } catch InventoryError.inventoryFull {
                        logger.warning("Dev seed: \(label)'s backpack full — skipped \(itemId)")
                    }
                }
            }
            if grantedCount > 0 {
                logger.info("Topped up \(label)'s inventory: \(grantedCount) item(s) seeded")
            }

            // Warehouse: same shape as inventory so the estate UI shows a stockpile.
            let allWH = try await WarehouseEntry.list(for: devUser, on: db)
            var whOrphansDeleted = 0
            for entry in allWH where ItemCatalog.find(entry.itemId) == nil {
                try await entry.delete(on: db)
                whOrphansDeleted += 1
            }
            if whOrphansDeleted > 0 {
                logger.info("Cleaned \(whOrphansDeleted) orphaned warehouse row(s) for \(label)")
            }
            var whGrantedCount = 0
            for (itemId, targetQty) in seed {
                if skipItems.contains(itemId) { continue }
                let have = try await WarehouseEntry.totalQuantity(of: itemId, for: devId, on: db)
                if have < targetQty {
                    try await WarehouseEntry.add(itemId, quantity: targetQty - have, to: devUser, on: db)
                    whGrantedCount += 1
                }
            }
            if whGrantedCount > 0 {
                logger.info("Topped up \(label)'s warehouse: \(whGrantedCount) item(s) seeded")
            }

        }
    }

    // One-shot, idempotent: lift pre-existing weapons to their per-tier
    // durability ceiling (rows created before the tier table carried a flat 30).
    try await GearConditionService.backfillWeaponDurability(on: db)

    // Start the bot
    try await appState.bot.start()

    // MARK: - Bot commands menu
    // Register the player-facing slash commands so Telegram's hamburger menu
    // (left of the input field) surfaces them. `/menu` is the discoverable
    // escape hatch — re-attaches the current controller's reply keyboard if
    // a player's client collapsed it or opened the chat with stale buttons
    // from another device.
    for code in ["en", "uk"] {
        let cmds = [
            TGBotCommand(command: "menu",     description: lingo.localize("menu.cmd.description", locale: code)),
            TGBotCommand(command: "help",     description: lingo.localize("menu.cmd.help",        locale: code)),
            TGBotCommand(command: "settings", description: lingo.localize("menu.cmd.settings",    locale: code))
        ]
        _ = try? await appState.bot.setMyCommands(params: TGSetMyCommandsParams(commands: cmds, languageCode: code))
    }

    // MARK: - Passive expedition rescheduler
    // Pick up any passive expeditions that were mid-flight when the bot last
    // stopped. Each one either delivers immediately (if its endsAt already
    // passed during downtime) or re-arms a Task.sleep until its endsAt.
    try await PassiveExpeditionService.rescheduleInflight(on: db, bot: appState.bot, lingo: lingo)

    // MARK: - Travel rescheduler
    // Phase 6.0 — same idea as passive: any in-flight trip from estate to
    // capital (or back) gets a fresh Task.sleep until its endsAt. Trips
    // whose timer already elapsed during downtime fire immediately.
    try await TravelService.rescheduleInflight(on: db, bot: appState.bot, lingo: lingo)

    // MARK: - Plot production ticker
    // Single long-running Task.detached that wakes every PlotProductionService
    // .tickInterval and pushes "ready to harvest" notifications when a plot
    // crosses its cap. Production amount is computed lazily on visit, the
    // ticker only handles notifications.
    PlotProductionService.startTicker(on: db, bot: appState.bot, lingo: lingo)

    // MARK: - Tavern dice cleanup sweeper
    // Tavern rounds leave their dice/labels/result in chat (Telegram blocks
    // deleting a private-chat dice message until it's 24 h old). This loop
    // sweeps each recorded message away the moment it ages past that limit.
    TavernCleanupService.startSweeper(on: db, bot: appState.bot)

    // MARK: - Trade lobby / session TTL sweeper
    // Live player-to-player trades and exchange-lobby presence live in the
    // in-memory TradeStore. This loop drops stale presence and cancels idle
    // trades (notifying both participants).
    TradeStore.startSweeper(bot: appState.bot, lingo: lingo)

    // MARK: - Arena duel sweeper
    // Live герць duels + challenge invites live in the in-memory ArenaStore.
    // This loop expires unanswered challenges, auto-resolves turn timeouts, and
    // settles any duel that ends by forfeit (pushing updates to both fighters).
    ArenaService.startSweeper(on: db, bot: appState.bot, lingo: lingo)

    // MARK: - Notify admins about starting bot
    // Restored players keep whatever reply keyboard their current controller
    // owns — no one-time `/start` button forced on top of it. Unregistered
    // users (no row yet, or still mid-registration) get the `/start` button
    // so they have an obvious entry point. Combat has no reply keyboard of
    // its own (inline only) so we fall back to the exploration keyboard,
    // since combat is always nested inside an active expedition.
    let startKB = TGReplyMarkup.replyKeyboardMarkup(TGReplyKeyboardMarkup(
        keyboard: [[TGKeyboardButton(text: "/start")]],
        resizeKeyboard: true,
        oneTimeKeyboard: true
    ))
    for tgId in allowedUsers {
        let chatId = TGChatId.chat(tgId)
        let user = try? await User.query(on: db).filter(\.$telegramId, .equal, tgId).first()
        let locale = user?.locale ?? "uk"
        let text = lingo.localize("bot.restarted", gender: user?.gender, locale: locale)

        let markup: TGReplyMarkup
        if let user = user, user.registrationStep >= User.registrationDoneStep {
            let activeCtrl = Controllers.all.first { $0.routerName == user.routerName }
            let kbCtrl: TGControllerBase
            if activeCtrl?.routerName == Controllers.combatController.routerName {
                kbCtrl = Controllers.explorationController
            } else {
                kbCtrl = activeCtrl ?? Controllers.mainController
            }
            markup = kbCtrl.generateControllerKB(session: user, lingo: lingo) ?? startKB
        } else {
            markup = startKB
        }

        let params = TGSendMessageParams(chatId: chatId, text: text, parseMode: .html, disableNotification: true, replyMarkup: markup)
        _ = try? await appState.bot.sendMessage(params: params)
    }

    // MARK: - Hummingbird HTTP Server

    let router = Hummingbird.Router()
    router.get("/health") { _, _ in
        return "OK"
    }

    let app = Application(router: router)

    logger.info("Starting Hummingbird server on port 8080...")
    try await app.run()
}
