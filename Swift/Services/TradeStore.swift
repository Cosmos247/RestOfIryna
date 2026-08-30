//
//  TradeStore.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 10.06.2026.
//
//  Phase 6.5 — in-memory engine for the synchronous player-to-player trade
//  (Capital → Market → 🤝 Обмін). A trade is a TWO-party shared object, so it
//  cannot live in `EphemeralChatState` (whose every record is single-owner,
//  keyed by one telegramId). Instead this dedicated actor holds:
//
//    • `lobby`    — who is currently standing in the exchange (presence room),
//                   keyed by telegramId, with a short TTL refreshed on every
//                   interaction. Busy players are hidden from each other.
//    • `sessions` — the live trades, keyed by a UUID (the source of truth).
//    • `byUser`   — a derived busy-index mapping BOTH participants' telegramIds
//                   to their session UUID, so any tap resolves to its trade in
//                   O(1) and double-initiation is trivially blocked.
//
//  Nothing is persisted. A bot restart drops every session ⇒ the trade simply
//  cancels (stale inline buttons resolve to a no-op). The ONLY database write
//  in the whole flow is the final atomic swap in `TradeService.commit`.
//
//  Every mutation is an actor method that returns a decision-snapshot; all
//  Telegram I/O happens in `CapitalController` AFTER the actor call returns, so
//  the actor never blocks on the network and state can't tear under races.
//

import Foundation
import SwiftTelegramBot
@preconcurrency import Lingo

public actor TradeStore {
    public static let shared = TradeStore()

    // `tuning/time.json` → `realTime`. These are anchored to how long a human
    // is willing to wait at a trade window, not to game pacing, so `time.scale`
    // must never touch them.

    /// Presence drops out of the lobby list this long after the last interaction.
    static var lobbyTTL: TimeInterval { Catalogs.current.tuningTime.realTime.tradeLobbyTTL }
    /// An in-flight trade with no activity for this long is swept and cancelled.
    static var sessionTTL: TimeInterval { Catalogs.current.tuningTime.realTime.tradeSessionTTL }
    /// How often the background sweeper scans.
    static var sweepInterval: TimeInterval { Catalogs.current.tuningTime.realTime.tradeSweepInterval }

    private struct LobbyEntry { var lastSeen: Date; var nickname: String }
    private var lobby: [Int64: LobbyEntry] = [:]
    private var sessions: [UUID: TradeSession] = [:]
    private var byUser: [Int64: UUID] = [:]

    // MARK: - Value types

    public enum Phase: Sendable { case pendingAccept, building, locked, committing }

    /// One participant's evolving offer + UI bookkeeping. `locale`/`nickname`
    /// are copied in so the sweeper can localize a timeout push without a DB hit.
    public struct Side: Sendable {
        public let telegramId: Int64
        public let userId: UUID
        public let nickname: String
        public let locale: String
        public var offeredStacks: [String: Int] = [:]   // itemId -> qty (full-stack)
        public var offeredGear: [UUID] = []             // specific InventoryEntry ids
        public var silver: Int = 0
        public var firstConfirmed = false               // tapped «✅ Погодити»
        public var secondConfirmed = false              // tapped «✅ Підтвердити обмін»
        public var screenMessageId: Int? = nil          // message we edit in place
        public var isPhoto = false
    }

    public struct TradeSession: Sendable {
        public let id: UUID
        public var phase: Phase
        public var a: Side                              // initiator
        public var b: Side                              // invitee
        public var lastActivity: Date

        public func isA(_ tg: Int64) -> Bool { tg == a.telegramId }
        public func side(for tg: Int64) -> Side { tg == a.telegramId ? a : b }
        public func other(for tg: Int64) -> Side { tg == a.telegramId ? b : a }
    }

    /// Both sides snapshot — returned by teardown so the controller can notify
    /// and restore both players.
    public struct Sides: Sendable { public let a: Side; public let b: Side }

    // MARK: - Lobby

    public func touchLobby(telegramId: Int64, nickname: String, now: Date = Date()) {
        lobby[telegramId] = LobbyEntry(lastSeen: now, nickname: nickname)
    }

    public func leaveLobby(telegramId: Int64) {
        lobby.removeValue(forKey: telegramId)
    }

    /// Fresh, non-busy lobby members other than `tg`, newest presence first.
    public func lobbyMembers(excluding tg: Int64, now: Date = Date()) -> [(telegramId: Int64, nickname: String)] {
        lobby
            .filter { key, entry in
                key != tg
                && byUser[key] == nil
                && now.timeIntervalSince(entry.lastSeen) < Self.lobbyTTL
            }
            .sorted { $0.value.lastSeen > $1.value.lastSeen }
            .map { (telegramId: $0.key, nickname: $0.value.nickname) }
    }

    public func isBusy(_ tg: Int64) -> Bool { byUser[tg] != nil }

    /// The live session a player belongs to (for re-rendering the right screen).
    public func snapshot(for tg: Int64) -> TradeSession? {
        guard let id = byUser[tg] else { return nil }
        return sessions[id]
    }

    // MARK: - Invite

    public enum InviteResult: Sendable {
        case created(TradeSession)
        case selfBusy
        case targetBusy
        case targetGone
    }

    /// A invites B. `initiator` carries A's already-set screen message id. B's
    /// identity is passed in (the controller loaded the User first). Both become
    /// busy immediately so a third player can't grab B during the request window.
    public func invite(
        initiator a: Side,
        targetTelegramId bTg: Int64,
        targetUserId bUserId: UUID,
        targetNickname bNick: String,
        targetLocale bLocale: String,
        now: Date = Date()
    ) -> InviteResult {
        if byUser[a.telegramId] != nil { return .selfBusy }
        if byUser[bTg] != nil { return .targetBusy }
        guard let entry = lobby[bTg], now.timeIntervalSince(entry.lastSeen) < Self.lobbyTTL else {
            return .targetGone
        }

        let b = Side(telegramId: bTg, userId: bUserId, nickname: bNick, locale: bLocale)
        let session = TradeSession(id: UUID(), phase: .pendingAccept, a: a, b: b, lastActivity: now)
        sessions[session.id] = session
        byUser[a.telegramId] = session.id
        byUser[bTg] = session.id
        // They're trading now, not browsing — pull both from the lobby list.
        lobby.removeValue(forKey: a.telegramId)
        lobby.removeValue(forKey: bTg)
        return .created(session)
    }

    // MARK: - Accept / decline

    public enum AcceptResult: Sendable { case opened(TradeSession); case stale }

    public func accept(sessionId: UUID, tapper bTg: Int64, screenMessageId: Int, isPhoto: Bool, now: Date = Date()) -> AcceptResult {
        guard var s = sessions[sessionId], s.phase == .pendingAccept, s.b.telegramId == bTg else {
            return .stale
        }
        s.b.screenMessageId = screenMessageId
        s.b.isPhoto = isPhoto
        s.phase = .building
        s.lastActivity = now
        sessions[sessionId] = s
        return .opened(s)
    }

    /// Decline a pending request (or tear down a pre-commit trade). Returns both
    /// sides so the controller can notify each.
    public func decline(sessionId: UUID, tapper tg: Int64) -> Sides? {
        guard let s = sessions[sessionId], s.phase == .pendingAccept,
              s.a.telegramId == tg || s.b.telegramId == tg else { return nil }
        return teardown(sessionId: sessionId)
    }

    // MARK: - Offer edits (always reset BOTH ready-flags)

    /// Flip a full stack into / out of the tapper's offer. `ownedQty` is the
    /// amount currently in the bag (the controller reads it fresh).
    public func toggleStack(tg: Int64, itemId: String, ownedQty: Int, now: Date = Date()) -> TradeSession? {
        mutateBuilding(tg: tg, now: now) { side in
            if side.offeredStacks[itemId] != nil {
                side.offeredStacks.removeValue(forKey: itemId)
            } else if ownedQty > 0 {
                side.offeredStacks[itemId] = ownedQty
            }
        }
    }

    /// Set an explicit quantity of a stackable into the offer (clamped to what's
    /// owned). `qty <= 0` removes it.
    public func setStack(tg: Int64, itemId: String, qty: Int, ownedQty: Int, now: Date = Date()) -> TradeSession? {
        mutateBuilding(tg: tg, now: now) { side in
            let clamped = min(max(0, qty), ownedQty)
            if clamped <= 0 {
                side.offeredStacks.removeValue(forKey: itemId)
            } else {
                side.offeredStacks[itemId] = clamped
            }
        }
    }

    public func toggleGear(tg: Int64, entryId: UUID, now: Date = Date()) -> TradeSession? {
        mutateBuilding(tg: tg, now: now) { side in
            if let idx = side.offeredGear.firstIndex(of: entryId) {
                side.offeredGear.remove(at: idx)
            } else {
                side.offeredGear.append(entryId)
            }
        }
    }

    public func setSilver(tg: Int64, amount: Int, now: Date = Date()) -> TradeSession? {
        mutateBuilding(tg: tg, now: now) { side in
            side.silver = max(0, amount)
        }
    }

    /// Apply `change` to the tapper's side while the trade is in `.building`.
    /// Only the EDITOR un-readies — the other player's «Погодити» stands, so they
    /// don't have to re-tap after every edit the tapper makes. Committing to a
    /// changed deal is still impossible: the locked-summary stage is a fresh
    /// both-sides confirm that shows the final combined offer.
    private func mutateBuilding(tg: Int64, now: Date, _ change: (inout Side) -> Void) -> TradeSession? {
        guard let id = byUser[tg], var s = sessions[id], s.phase == .building else { return nil }
        if s.isA(tg) {
            change(&s.a)
            s.a.firstConfirmed = false
        } else {
            change(&s.b)
            s.b.firstConfirmed = false
        }
        s.lastActivity = now
        sessions[id] = s
        return s
    }

    // MARK: - Confirmations

    public enum ConfirmResult: Sendable { case waiting(TradeSession); case both(TradeSession); case noop }

    /// Stage-1 «Погодити». Valid only in `.building`. When both sides are ready
    /// the trade locks and the combined-offer screen is shown.
    public func confirmFirst(tg: Int64, now: Date = Date()) -> ConfirmResult {
        guard let id = byUser[tg], var s = sessions[id], s.phase == .building else { return .noop }
        if s.isA(tg) { s.a.firstConfirmed = true } else { s.b.firstConfirmed = true }
        s.lastActivity = now
        if s.a.firstConfirmed && s.b.firstConfirmed {
            s.phase = .locked
            sessions[id] = s
            return .both(s)
        }
        sessions[id] = s
        return .waiting(s)
    }

    /// Stage-2 «Підтвердити обмін». Valid only in `.locked`.
    public func confirmSecond(tg: Int64, now: Date = Date()) -> ConfirmResult {
        guard let id = byUser[tg], var s = sessions[id], s.phase == .locked else { return .noop }
        if s.isA(tg) { s.a.secondConfirmed = true } else { s.b.secondConfirmed = true }
        s.lastActivity = now
        sessions[id] = s
        if s.a.secondConfirmed && s.b.secondConfirmed {
            return .both(s)
        }
        return .waiting(s)
    }

    /// Compare-and-set into `.committing`. Returns true exactly once, so even a
    /// duplicate final tap can't drive a second commit.
    public func beginCommit(sessionId: UUID) -> Bool {
        guard var s = sessions[sessionId], s.phase == .locked else { return false }
        s.phase = .committing
        sessions[sessionId] = s
        return true
    }

    // MARK: - Teardown

    /// Cancel whatever trade `tg` is in. Returns both sides (nil if none).
    public func cancel(tg: Int64) -> Sides? {
        guard let id = byUser[tg], let s = sessions[id], s.phase != .committing else { return nil }
        return teardown(sessionId: id)
    }

    /// Remove a finished trade from the store. Returns both sides.
    public func finish(sessionId: UUID) -> Sides? {
        teardown(sessionId: sessionId)
    }

    @discardableResult
    private func teardown(sessionId: UUID) -> Sides? {
        guard let s = sessions.removeValue(forKey: sessionId) else { return nil }
        byUser.removeValue(forKey: s.a.telegramId)
        byUser.removeValue(forKey: s.b.telegramId)
        return Sides(a: s.a, b: s.b)
    }

    // MARK: - Sweep (TTL expiry)

    /// Drop stale lobby presence and tear down idle trades. Returns the sides of
    /// every trade that just timed out, so the caller can push them a notice.
    public func sweep(now: Date = Date()) -> [Sides] {
        for (tg, entry) in lobby where now.timeIntervalSince(entry.lastSeen) >= Self.lobbyTTL {
            lobby.removeValue(forKey: tg)
        }
        let stale = sessions.values
            .filter { now.timeIntervalSince($0.lastActivity) > Self.sessionTTL && $0.phase != .committing }
            .map(\.id)
        return stale.compactMap { teardown(sessionId: $0) }
    }

    /// Background loop, mirrors `TavernCleanupService.startSweeper`. Fire-and-
    /// forget from `configure.swift`. Pushes a localized timeout notice to both
    /// participants of any trade it reaps.
    public static func startSweeper(bot: TGBot, lingo: Lingo) {
        Task.detached {
            while true {
                try? await Task.sleep(nanoseconds: UInt64(sweepInterval * 1_000_000_000))
                let timedOut = await shared.sweep()
                for sides in timedOut {
                    for side in [sides.a, sides.b] {
                        let text = lingo.localize("capital.trade.timed_out", locale: side.locale)
                        _ = try? await bot.sendMessage(params: TGSendMessageParams(
                            chatId: .chat(side.telegramId),
                            text: text,
                            parseMode: .html
                        ))
                    }
                }
            }
        }
    }
}
