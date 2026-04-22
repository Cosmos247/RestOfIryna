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
/// Hardcoded to the dev machine for now; move to env/config when deploying.
public let projectPath: String = "/Users/cosmos/RestOfIryna"

let maxim: Int64 = 327887608
let basel: Int64 = 768795585
let mitya: Int64 = 398698463
let irina: Int64 = 1269829617
let allowedUsers: [Int64] = [mitya, irina, maxim, basel]
let developerUsers: [Int64] = [mitya, irina, maxim]

/// Reset dev profile on every launch (sets mitya back to registration)
let resetDevProfile = true

/// Seed a starter inventory + warehouse for every `developerUsers` account on launch.
/// Per-item top-up (never reduces), so it recovers gracefully from catalog changes.
let seedDevInventory = true

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

    /// Filename under `Assets/registration/` for the class-specific "approaching the estate"
    /// artwork shown during the wolves encounter step.
    var journeyImageName: String {
        switch self {
        case .warrior: return "warrior_estate.jpg"
        case .archer:  return "archer_estate.jpg"
        case .mage:    return "mage_estate.jpg"
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
                user.estateName = nil
                user.level = 1
                user.xp = 0
                user.hp = 100
                user.maxHp = 100
                user.hunger = 100
                user.maxHunger = 100
                user.attack = 10
                user.defense = 10
                user.crit = 5
                user.dodge = 5
                user.accuracy = 10
                user.gold = 0
                user.gearAttackBonus = 0
                user.gearDefenseBonus = 0
                user.gearCritBonus = 0
                user.gearDodgeBonus = 0
                user.gearAccuracyBonus = 0
                try await user.saveAndCache(in: db)

                // Also wipe inventory + warehouse so registration-grants + seeds start from scratch.
                let existingEntries = try await InventoryEntry.list(for: user, on: db)
                for entry in existingEntries {
                    try await entry.delete(on: db)
                }
                let existingWarehouse = try await WarehouseEntry.list(for: user, on: db)
                for entry in existingWarehouse {
                    try await entry.delete(on: db)
                }

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
            ("food.bread", 3),
            ("food.stew", 1),
            ("mat.wood", 5),
            ("mat.stone", 3),
            ("potion.heal_small", 2),
            ("artifact.shrine_coin", 1),
        ]

        for developer in developerUsers {
            guard let devUser = try await User.query(on: db).filter(\.$telegramId, .equal, developer).first(),
                  let devId = devUser.id else { continue }
            let label = devUser.nickname ?? "\(developer)"

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

    // Start the bot
    try await appState.bot.start()

    // MARK: - Notify admins about starting bot
    for user in allowedUsers {
        let chatId = TGChatId.chat(user)
        let text = "📟 Bot started."
        let params = TGSendMessageParams(chatId: chatId, text: text, disableNotification: true)
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
