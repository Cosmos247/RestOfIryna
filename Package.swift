//  swift-tools-version: 6.2
//
//  Package.swift
//  RestOfIryna
//
//  Created by Maxim Lanskoy on 13.06.2025.
//  Maintained by Dmytro Ihnatyuhin from 17.04.2026.
//

import PackageDescription

let package = Package(
    name: "RestOfIryna",
    platforms: [
       .macOS(.v14)
    ],
    dependencies: [
        // 🐦 Lightweight, flexible HTTP server framework written in Swift.
        .package(url: "https://github.com/hummingbird-project/hummingbird.git", from: "2.22.0"),
        // 🗄 An ORM for SQL and NoSQL databases.
        .package(url: "https://github.com/vapor/fluent.git", from: "4.13.0"),
        // 🐘 Fluent driver for PostgreSQL.
        .package(url: "https://github.com/vapor/fluent-postgres-driver.git", from: "2.12.0"),
        // 🔵 Non-blocking, event-driven networking for Swift. Used for custom executors
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.98.0"),
        // 🌐 Async HTTP client for Swift.
        .package(url: "https://github.com/swift-server/async-http-client.git", from: "1.31.1"),
        // ✈ A Swift wrapper for the Telegram API.
        .package(url: "https://github.com/nerzh/swift-telegram-sdk", from: "4.6.0"),
        // 🔑 A dotenv library for Swift.
        .package(url: "https://github.com/thebarndog/swift-dotenv.git", from: "2.1.0"),
        // 🗺️ Lingo: A Swift package for localization.
        .package(url: "https://github.com/miroslavkovac/Lingo.git", from: "4.0.0"),
        // 🔐 HMAC-SHA256 for the closed-test invite tokens. swift-crypto rather
        // than CryptoKit because the bot also runs on Linux (the Pi).
        .package(url: "https://github.com/apple/swift-crypto.git", from: "4.0.0"),
    ],
    targets: [
        // 📦 Game content: DTOs, loader, validator and the live snapshot.
        // Foundation only — no Fluent, no Telegram — so the CLI and the tests
        // build in a second and can run in CI without a database.
        .target(
            name: "ROIContent",
            path: "Modules/ROIContent", swiftSettings: swiftSettings
        ),
        // 🎲 Pure balance math + deterministic RNG for the simulator.
        .target(
            name: "ROISim",
            dependencies: ["ROIContent"],
            path: "Modules/ROISim", swiftSettings: swiftSettings
        ),
        // 🛠 Content pipeline CLI: validate / simulate.
        .executableTarget(
            name: "roi-content",
            dependencies: ["ROIContent", "ROISim"],
            path: "Modules/roi-content", swiftSettings: swiftSettings
        ),
        .executableTarget(
            name: "RestOfIryna",
            dependencies: [
                "ROIContent",
                "ROISim",
                .product(name: "Hummingbird", package: "hummingbird"),
                .product(name: "Fluent", package: "fluent"),
                .product(name: "FluentPostgresDriver", package: "fluent-postgres-driver"),
                .product(name: "NIOCore", package: "swift-nio"),
                .product(name: "NIOPosix", package: "swift-nio"),
                .product(name: "AsyncHTTPClient", package: "async-http-client"),
                .product(name: "SwiftTelegramBot", package: "swift-telegram-sdk"),
                .product(name: "SwiftDotenv", package: "swift-dotenv"),
                .product(name: "Lingo", package: "Lingo"),
                .product(name: "Crypto", package: "swift-crypto"),
            ],
            path: "Swift", swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "ROIContentTests",
            dependencies: ["ROIContent", "ROISim"],
            path: "Tests/ROIContentTests", swiftSettings: swiftSettings
        )
    ]
)

var swiftSettings: [SwiftSetting] { [
    .enableUpcomingFeature("ExistentialAny"),
] }
