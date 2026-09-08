//
//  AccessControl.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 08.09.2026.
//
//  The run-time allow list: who the bot answers at all.
//
//  Every update passes through `isAllowed` before a session is even fetched,
//  so this cannot be a database round trip per message. The set is read once
//  at boot and kept in memory; the only thing that ever changes it is `grant`,
//  which writes the row and updates the set in the same actor hop, so the
//  cache cannot drift from the table within a process.
//
//  It CAN drift between processes — two bots on one database would not see
//  each other's grants — and that is acceptable for the same reason it is
//  acceptable for `SessionCache`: only one instance may poll a bot token at a
//  time anyway (Telegram answers the second with a 409).
//
//  **Developers are allowed unconditionally**, before the set is consulted.
//  The list now lives in a table that a mistyped query could empty, and an
//  admin who can no longer reach `/link` has no way back in except a redeploy.
//  Hardcoding the one account that issues invites is the lockout brake.
//

import Fluent
import Foundation

actor AccessControl {

    private var allowed: Set<Int64> = []
    private var loaded = false

    /// Read the table into memory. Called once from `configure` after the
    /// migrations run; `isAllowed` also calls it lazily so a code path that
    /// forgets to warm the cache degrades to a slow first check rather than to
    /// a locked door.
    func load(on db: any Database) async throws {
        let rows = try await AllowedUser.query(on: db).all()
        allowed = Set(rows.map(\.telegramId))
        loaded = true
    }

    /// A cache HIT answers from memory; a cache MISS asks the database before
    /// refusing, and remembers the answer.
    ///
    /// The miss query is what makes a row added out of band — by hand, in SQL,
    /// while the bot is running — take effect on that account's next message
    /// instead of at the next restart. It costs one indexed lookup, and only
    /// for accounts that are NOT on the list, which is the rare case by
    /// construction: every allowed player is a hit from their second message
    /// onward. Without it the in-memory set is authoritative for refusals, and
    /// the only way to admit someone is a redeploy.
    func isAllowed(_ telegramId: Int64, on db: any Database) async -> Bool {
        if developerUsers.contains(telegramId) { return true }
        if !loaded { try? await load(on: db) }
        if allowed.contains(telegramId) { return true }

        // `first()` already returns an optional row, and `try?` wraps it in a
        // second one; flattening here keeps the guard readable rather than a
        // double-optional puzzle. A thrown query and an absent row mean the
        // same thing to a gate: not proven allowed, so refuse.
        let row = (try? await AllowedUser.query(on: db)
            .filter(\.$telegramId, .equal, telegramId)
            .first()) ?? nil
        guard row != nil else { return false }
        allowed.insert(telegramId)
        return true
    }

    /// Add an account to the list.
    ///
    /// - Returns: `true` when this call is what put them on it, `false` when
    ///   they were already there. The caller uses that to decide whether the
    ///   moment is worth a log line and a greeting.
    @discardableResult
    func grant(_ telegramId: Int64,
               username: String?,
               source: AllowedUser.Source,
               on db: any Database) async throws -> Bool {
        if !loaded { try? await load(on: db) }
        if allowed.contains(telegramId) { return false }

        // The unique index would refuse a duplicate anyway; asking first turns
        // a thrown constraint violation into an ordinary answer.
        if try await AllowedUser.query(on: db).filter(\.$telegramId, .equal, telegramId).first() != nil {
            allowed.insert(telegramId)
            return false
        }

        try await AllowedUser(telegramId: telegramId, username: username, source: source).save(on: db)
        allowed.insert(telegramId)
        return true
    }

    /// Everyone on the list, for the boot-time announcement and for admin
    /// screens. Reads the table rather than the cache so the answer is the
    /// stored truth, not this process's memory of it.
    func roster(on db: any Database) async -> [AllowedUser] {
        (try? await AllowedUser.query(on: db).sort(\.$createdAt).all()) ?? []
    }
}

/// Process-wide allow list. Mirrors `sessionCache` and `store`: one instance,
/// created at load, safe to touch from any task because it is an actor.
let accessControl = AccessControl()
