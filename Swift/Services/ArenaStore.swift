//
//  ArenaStore.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 20.07.2026.
//
//  Phase 8.3 — the in-memory engine for the live Arena duel (герць). Modelled on
//  `TradeStore`: a duel is a TWO-party shared object that can't live in the
//  single-owner `EphemeralChatState`, so this dedicated actor holds
//
//    • `lobby`      — who is standing in the Ристалище (presence room), keyed by
//                     telegramId with a short refreshed TTL. Busy fighters hidden.
//    • `pending`    — issued-but-unanswered challenges, keyed by a UUID.
//    • `duels`      — the live fights, keyed by a UUID (source of truth).
//    • `byUser`     — busy-index mapping BOTH fighters' telegramIds to their duel
//                     (or pending) UUID so any tap resolves in O(1) and double-
//                     initiation is trivially blocked.
//
//  Nothing is persisted. A bot restart drops every duel ⇒ the fight simply
//  cancels; the escrowed stakes are refunded by `configure`'s restart handling
//  path (in-flight duels don't survive, so no settlement fires). The ONLY DB
//  writes in the whole flow are the stake escrow at accept and the settlement at
//  the end — both in `ArenaService`.
//
//  Every mutation is an actor method returning a decision-snapshot; all Telegram
//  I/O happens in `ArenaController` AFTER the actor call returns, so the actor
//  never blocks on the network and state can't tear under races. Combat dice are
//  rolled INSIDE the actor (via `CombatService`) so the roll and the HP mutation
//  are atomic.
//

import Foundation
import SwiftTelegramBot
@preconcurrency import Lingo

public actor ArenaStore {
    public static let shared = ArenaStore()

    private struct LobbyEntry { var lastSeen: Date; var nickname: String }
    private var lobby: [Int64: LobbyEntry] = [:]
    private var pending: [UUID: PendingChallenge] = [:]
    private var duels: [UUID: Duel] = [:]
    private var byUser: [Int64: UUID] = [:]

    // MARK: - Value types

    /// A fighter's frozen stat sheet + live HP for the duration of one duel.
    /// Stats are snapshotted at duel start so mid-fight changes can't matter.
    public struct Combatant: Sendable {
        public let telegramId: Int64
        public let userId: UUID
        public let nickname: String
        public let locale: String
        public let atk: Int
        public let def: Int
        public let crit: Int
        public let dodge: Int
        public let acc: Int
        /// Player level. Every combat curve's denominator is read at the level
        /// of whoever owns the stat, so a duel needs both sides' levels; the
        /// matchmaker's ±3 bracket keeps `levelDiff` close to 1 in practice.
        public let level: Int
        public let maxHp: Int
        public var hp: Int
        public let stake: Int
        public let honor: Int          // pre-duel rating, for the ELO settle
        public var defending: Bool = false   // set on this fighter's Defend, consumed by the next incoming Attack
        public var missedTurns: Int = 0
    }

    public struct PendingChallenge: Sendable {
        public let id: UUID
        public let stake: Int
        public let challenger: Combatant
        public let opponentTelegramId: Int64
        public let opponentNickname: String
        public let opponentLocale: String
        public var createdAt: Date
    }

    public enum DuelPhase: Sendable { case active, finished }

    public struct Duel: Sendable {
        public let id: UUID
        public var phase: DuelPhase
        public var a: Combatant        // challenger — strikes first
        public var b: Combatant        // challenged
        public var turn: Int64         // telegramId of the fighter to act
        public var round: Int
        public var turnDeadline: Date
        public var lastActivity: Date

        public func me(_ tg: Int64) -> Combatant { tg == a.telegramId ? a : b }
        public func opp(_ tg: Int64) -> Combatant { tg == a.telegramId ? b : a }
        public func isA(_ tg: Int64) -> Bool { tg == a.telegramId }
    }

    /// Both fighters' final snapshots — returned by teardown so the controller
    /// can settle + notify + restore both players.
    public struct Ended: Sendable {
        public let a: Combatant
        public let b: Combatant
        public let winnerTelegramId: Int64
        public let loserTelegramId: Int64
        public let reason: EndReason
    }

    public enum EndReason: Sendable { case knockout, surrender, forfeit }

    public enum FighterAction: Sendable { case attack, defend }

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
                && now.timeIntervalSince(entry.lastSeen) < ArenaCatalog.lobbyTTL
            }
            .sorted { $0.value.lastSeen > $1.value.lastSeen }
            .map { (telegramId: $0.key, nickname: $0.value.nickname) }
    }

    public func isBusy(_ tg: Int64) -> Bool { byUser[tg] != nil }

    /// The live duel a fighter belongs to (for reconnect re-render / surrender).
    public func activeDuel(for tg: Int64) -> Duel? {
        guard let id = byUser[tg], let d = duels[id] else { return nil }
        return d
    }

    // MARK: - Challenge (invite)

    public enum ChallengeResult: Sendable {
        case created(PendingChallenge)
        case selfBusy
        case targetBusy
        case targetGone
    }

    /// Challenger issues a wagered duel to a lobby member. Both become busy
    /// immediately so a third fighter can't grab either during the request.
    public func challenge(challenger: Combatant, stake: Int, targetTelegramId tg: Int64, now: Date = Date()) -> ChallengeResult {
        if byUser[challenger.telegramId] != nil { return .selfBusy }
        if byUser[tg] != nil { return .targetBusy }
        guard let entry = lobby[tg], now.timeIntervalSince(entry.lastSeen) < ArenaCatalog.lobbyTTL else {
            return .targetGone
        }
        let pc = PendingChallenge(
            id: UUID(), stake: stake, challenger: challenger,
            opponentTelegramId: tg, opponentNickname: entry.nickname, opponentLocale: "",
            createdAt: now
        )
        pending[pc.id] = pc
        byUser[challenger.telegramId] = pc.id
        byUser[tg] = pc.id
        lobby.removeValue(forKey: challenger.telegramId)
        lobby.removeValue(forKey: tg)
        return .created(pc)
    }

    /// Look up a pending challenge (the accept/decline handler resolves it).
    public func pendingChallenge(_ id: UUID) -> PendingChallenge? { pending[id] }

    /// Decline / withdraw a pending challenge — frees both fighters. Returns the
    /// challenge so the controller can notify the challenger.
    public func cancelPending(_ id: UUID) -> PendingChallenge? {
        guard let pc = pending.removeValue(forKey: id) else { return nil }
        byUser.removeValue(forKey: pc.challenger.telegramId)
        byUser.removeValue(forKey: pc.opponentTelegramId)
        return pc
    }

    /// Cancel a pending challenge `tg` is part of (challenger or target) — used
    /// when a player leaves the arena before the invite is answered. Returns the
    /// challenge (nil if `tg` has none pending, e.g. is mid-duel instead).
    public func cancelPendingInvolving(_ tg: Int64) -> PendingChallenge? {
        guard let id = byUser[tg], pending[id] != nil else { return nil }
        return cancelPending(id)
    }

    // MARK: - Start (after escrow succeeds)

    /// Promote a pending challenge into a live duel. The controller re-snapshots
    /// BOTH fighters fresh at accept-time (stats current as of the answer) and
    /// passes them in. Returns the fresh duel (challenger acts first).
    public func startDuel(pendingId: UUID, challenger a: Combatant, opponent b: Combatant, now: Date = Date()) -> Duel? {
        guard pending.removeValue(forKey: pendingId) != nil else { return nil }
        let duel = Duel(
            id: UUID(), phase: .active, a: a, b: b,
            turn: a.telegramId, round: 1,
            turnDeadline: now.addingTimeInterval(ArenaCatalog.turnSeconds), lastActivity: now
        )
        duels[duel.id] = duel
        byUser[a.telegramId] = duel.id
        byUser[b.telegramId] = duel.id
        return duel
    }

    // MARK: - Combat resolution

    public enum ActionResult: Sendable {
        /// The action resolved; `duel` reflects the new state, `log` is the
        /// narrative of what just happened, `nextTurn` is who acts now.
        case continued(duel: Duel, log: [String])
        case ended(Ended, log: [String])
        case notYourTurn
        case noDuel
    }

    /// Resolve `tg`'s Attack / Defend. Dice + HP mutation happen atomically here.
    public func resolve(action: FighterAction, tg: Int64, now: Date = Date()) -> ActionResult {
        guard let id = byUser[tg], var duel = duels[id], duel.phase == .active else { return .noDuel }
        guard duel.turn == tg else { return .notYourTurn }

        let attackerIsA = duel.isA(tg)
        var attacker = attackerIsA ? duel.a : duel.b
        var defender = attackerIsA ? duel.b : duel.a
        attacker.missedTurns = 0
        var log: [String] = []

        switch action {
        case .defend:
            // Brace: buff DEF against the next incoming hit + a chip counter.
            attacker.defending = true
            let chip = CombatService.chipDamage(attackerATK: attacker.atk, defenderDEF: defender.def,
                                                defenderLevel: defender.level)
            defender.hp = max(0, defender.hp - chip)
            log.append("🛡|\(chip)")   // controller expands into localized copy
        case .attack:
            let effectiveDEF = defender.defending ? defender.def * 2 : defender.def
            defender.defending = false
            let outcome = CombatService.applyAttack(
                attackerATK: attacker.atk, attackerCrit: attacker.crit, attackerAcc: attacker.acc,
                attackerLevel: attacker.level,
                defenderDEF: effectiveDEF, defenderDodge: defender.dodge,
                defenderLevel: defender.level
            )
            switch outcome {
            case .miss:            log.append("miss|0")
            case .hit(let dmg):    defender.hp = max(0, defender.hp - dmg); log.append("hit|\(dmg)")
            case .crit(let dmg):   defender.hp = max(0, defender.hp - dmg); log.append("crit|\(dmg)")
            }
        }

        // Write the mutated fighters back.
        if attackerIsA { duel.a = attacker; duel.b = defender } else { duel.b = attacker; duel.a = defender }

        // Knockout?
        if defender.hp <= 0 {
            let ended = teardownDuel(id, winner: attacker.telegramId, loser: defender.telegramId, reason: .knockout, from: duel)
            return .ended(ended, log: log)
        }

        // Pass the turn.
        duel.turn = defender.telegramId
        duel.round += 1
        duel.turnDeadline = now.addingTimeInterval(ArenaCatalog.turnSeconds)
        duel.lastActivity = now
        duels[id] = duel
        return .continued(duel: duel, log: log)
    }

    /// A fighter throws in the towel (allowed on or off their turn).
    public func surrender(tg: Int64) -> Ended? {
        guard let id = byUser[tg], let duel = duels[id], duel.phase == .active else { return nil }
        let opp = duel.opp(tg)
        return teardownDuel(id, winner: opp.telegramId, loser: tg, reason: .surrender, from: duel)
    }

    // MARK: - Teardown

    private func teardownDuel(_ id: UUID, winner: Int64, loser: Int64, reason: EndReason, from duel: Duel) -> Ended {
        duels.removeValue(forKey: id)
        byUser.removeValue(forKey: duel.a.telegramId)
        byUser.removeValue(forKey: duel.b.telegramId)
        return Ended(a: duel.a, b: duel.b, winnerTelegramId: winner, loserTelegramId: loser, reason: reason)
    }

    // MARK: - Sweep (TTL + turn timeouts)

    /// Result of one sweep pass for the background loop to act on.
    public struct SweepOutput: Sendable {
        public var expiredChallenges: [PendingChallenge] = []
        /// A turn timed out: the idle fighter auto-defended and the turn passed.
        /// `actorTelegramId` is the fighter who was forced to defend.
        public var timedOutTurns: [(duel: Duel, log: [String], actorTelegramId: Int64)] = []
        /// A fighter forfeited by repeated timeout.
        public var forfeits: [(Ended, [String])] = []
    }

    public func sweep(now: Date = Date()) -> SweepOutput {
        var out = SweepOutput()

        // Stale lobby presence.
        for (tg, entry) in lobby where now.timeIntervalSince(entry.lastSeen) >= ArenaCatalog.lobbyTTL {
            lobby.removeValue(forKey: tg)
        }

        // Unanswered challenges.
        for (id, pc) in pending where now.timeIntervalSince(pc.createdAt) >= ArenaCatalog.challengeTTL {
            if let expired = cancelPending(id) { out.expiredChallenges.append(expired) }
        }

        // Turn timeouts on active duels.
        for (id, var duel) in duels where duel.phase == .active && now >= duel.turnDeadline {
            let idleTg = duel.turn
            let idleIsA = duel.isA(idleTg)
            var idle = idleIsA ? duel.a : duel.b
            idle.missedTurns += 1

            if idle.missedTurns >= ArenaCatalog.maxMissedTurns {
                // Forfeit — the active fighter wins by walkover.
                let opp = duel.opp(idleTg)
                if idleIsA { duel.a = idle } else { duel.b = idle }
                let ended = teardownDuel(id, winner: opp.telegramId, loser: idleTg, reason: .forfeit, from: duel)
                out.forfeits.append((ended, ["forfeit|0"]))
                continue
            }

            // Auto-defend for the idle fighter, then pass the turn.
            var opp = idleIsA ? duel.b : duel.a
            idle.defending = true
            let chip = CombatService.chipDamage(attackerATK: idle.atk, defenderDEF: opp.def,
                                                defenderLevel: opp.level)
            opp.hp = max(0, opp.hp - chip)
            if idleIsA { duel.a = idle; duel.b = opp } else { duel.b = idle; duel.a = opp }

            if opp.hp <= 0 {
                let ended = teardownDuel(id, winner: idle.telegramId, loser: opp.telegramId, reason: .knockout, from: duel)
                out.forfeits.append((ended, ["autodefend|\(chip)"]))
                continue
            }

            duel.turn = opp.telegramId
            duel.round += 1
            duel.turnDeadline = now.addingTimeInterval(ArenaCatalog.turnSeconds)
            duel.lastActivity = now
            duels[id] = duel
            out.timedOutTurns.append((duel, ["timeout|\(chip)"], idleTg))
        }

        return out
    }
}
