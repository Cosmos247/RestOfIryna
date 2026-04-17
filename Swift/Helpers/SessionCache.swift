//
//  SessionCache.swift
//  RestOfIryna
//
//  Created by Maxim Lanskoy on 27.12.2025.
//  Maintained by Dmytro Ihnatyuhin from 17.04.2026.
//

import Foundation
import Fluent
import SwiftTelegramBot

/// Thread-safe session cache with automatic expiration
actor SessionCache {

    // MARK: - Types

    private struct CachedSession {
        let user: User
        let expiration: Date

        var isExpired: Bool {
            Date() > expiration
        }
    }

    // MARK: - Properties

    private var cache: [Int64: CachedSession] = [:]
    private let ttl: TimeInterval
    private var cleanupTask: Task<Void, Never>?

    // MARK: - Initialization

    init(ttl: TimeInterval = 300) { // 5 minutes default
        self.ttl = ttl
        self.cleanupTask = nil
    }

    /// Start the cleanup task (call after initialization)
    func startCleanupTask() {
        guard cleanupTask == nil else { return }
        cleanupTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 60_000_000_000) // Clean every minute
                await self?.cleanup()
            }
        }
    }

    deinit {
        cleanupTask?.cancel()
    }

    // MARK: - Public Methods

    /// Get user from cache or database
    func getOrFetch(tgUser: TGUser, db: any Database) async throws -> User {
        // Check cache first
        if let cached = cache[tgUser.id], !cached.isExpired {
            return cached.user
        }

        // Cache miss - fetch from database
        let user = try await User._session(for: tgUser, db: db)

        // Store in cache
        cache[tgUser.id] = CachedSession(
            user: user,
            expiration: Date().addingTimeInterval(ttl)
        )

        return user
    }
    
    func getOrFetch(tgId: Int64, db: any Database) async throws -> User {
        // Check cache first
        if let cached = cache[tgId], !cached.isExpired {
            return cached.user
        }

        // Cache miss - fetch from database
        let user = try await User._session(for: tgId, db: db)

        // Store in cache
        cache[tgId] = CachedSession(
            user: user,
            expiration: Date().addingTimeInterval(ttl)
        )

        return user
    }

    /// Invalidate cache entry (call after user updates)
    func invalidate(telegramId: Int64) {
        cache.removeValue(forKey: telegramId)
    }

    /// Update cached user (call after successful save)
    func update(_ user: User) {
        cache[user.telegramId] = CachedSession(
            user: user,
            expiration: Date().addingTimeInterval(ttl)
        )
    }

    /// Clear all cached sessions
    func clear() {
        cache.removeAll()
    }

    /// Get cache statistics
    func stats() -> (count: Int, memoryEstimate: Int) {
        let count = cache.count
        let memoryEstimate = count * 512 // Rough estimate: ~512 bytes per user
        return (count, memoryEstimate)
    }

    // MARK: - Private Methods

    private func cleanup() {
        cache = cache.filter { !$0.value.isExpired }
    }
}

// MARK: - Global Session Cache Instance

/// Global session cache - configure this in configure.swift
nonisolated(unsafe) var sessionCache: SessionCache = SessionCache()

// NOTE: Cache integration methods are in User.swift to avoid conflicts
