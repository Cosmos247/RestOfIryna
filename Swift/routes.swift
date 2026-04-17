//
//  routes.swift
//  RestOfIryna
//
//  Created by Maxim Lanskoy on 13.06.2025.
//  Maintained by Dmytro Ihnatyuhin from 17.04.2026.
//

import Fluent
@preconcurrency import Lingo
import SwiftTelegramBot

// MARK: - Setting up Telegram Routes.
actor RouterStore {
    private var backStore: [String: Router] = [:]

    func set(_ router: Router, forKey key: String) {
        backStore[key] = router
    }

    func get(_ key: String) -> Router? {
        backStore[key]
    }

    func process(key: String, update: TGUpdate, properties: [String: Int64], db: any Database, lingo: Lingo) async throws {
        guard let router = backStore[key] else { return }
        // Rehydrate Users from IDs inside actor to avoid passing non-Sendable models across actor boundary
        var hydrated: [String: User] = [:]
        for (k, v) in properties {
            let user = try await sessionCache.getOrFetch(tgId: v, db: db)
            hydrated[k] = user
        }
        try await router.process(update: update, properties: hydrated, db: db, lingo: lingo)
    }
}

// MARK: - Concurrency Safety Fixes.
// Allow passing Router instances across actors safely
extension Router: @unchecked Sendable {}
