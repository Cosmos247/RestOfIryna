//
//  configure.swift
//  RestOfIryna
//
//  Created by Maxim Lanskoy on 13.06.2025.
//  Maintained by Dmytro Ihnatyuhin from 17.04.2026.
//

import FluentPostgresDriver
import Fluent
import Hummingbird
import Logging
import AsyncHTTPClient
import SwiftDotenv
import SwiftTelegramBot
@preconcurrency import Lingo

let store = RouterStore()

let maxim: Int64 = 327887608
let basel: Int64 = 768795585
let mitya: Int64 = 398698463
let irina: Int64 = 1269829617
let allowedUsers: [Int64] = [maxim, basel, mitya, irina]

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

    let projectPath: String = "/Users/cosmos/RestOfIryna"
    try Dotenv.configure(atPath: "\(projectPath)/.env", overwrite: false)

    // MARK: - Database Setup (Fluent + PostgreSQL)

    let databases = Databases(threadPool: .singleton, on: MultiThreadedEventLoopGroup.singleton)

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

    let migrator = Migrator(databases: databases, migrations: migrations, logger: logger, on: MultiThreadedEventLoopGroup.singleton.any())
    _ = migrator.setupIfNeeded()
    _ = migrator.prepareBatch()

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
