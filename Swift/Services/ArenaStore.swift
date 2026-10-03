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
//  cancels, and since no silver is taken until a winner exists (see
//  `ArenaService`) there is nothing to refund. The ONLY DB write in the whole
//  flow is the settlement at the end.
//
//  Since 2026-10-03 a duel is played in SIMULTANEOUS rounds: both fighters
//  choose blind, the first tap locks the choice, and the round is played the
//  moment the second choice arrives — or when the round's clock runs out, with
//  every missing choice played as a forced Defend. The alternating duel it
//  replaced gave the challenger the first blow, which was worth 60–66% of mirror
//  duels (`DuelMath` has the measurement and the rule).
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
        /// of whoever owns the stat, so a duel needs both sides' levels. Nothing
        /// brackets them yet: a lobby challenge can pair any two levels, and
        /// `levelDiff` applies in full.
        public let level: Int
        public let maxHp: Int
        public var hp: Int
        public let stake: Int
        public let honor: Int          // pre-duel rating, for the ELO settle
        /// Rounds in a row this fighter let the clock run out on. Any choice
        /// resets it; reaching `ArenaCatalog.maxMissedTurns` is a technical
        /// defeat.
        public var missedRounds: Int = 0

        /// The sheet as `DuelMath` reads it.
        var stats: CombatantStats {
            CombatantStats(level: level, maxHP: maxHp, hp: hp, attack: atk, defense: def,
                           crit: crit, dodge: dodge, accuracy: acc)
        }
    }

    public struct PendingChallenge: Sendable {
        public let id: UUID
        public let stake: Int
        public let challenger: Combatant
        public let opponentTelegramId: Int64
        public let opponentNickname: String
        public let opponentLocale: String
        public var createdAt: Date
        /// The invite bubble in the OPPONENT's chat, so every path that closes
        /// this challenge can strip its buttons. Optional only because the
        /// message is sent after the challenge exists; `attachInvite` fills it
        /// in a beat later. A challenge whose send failed keeps nil and simply
        /// has no bubble to close.
        public var inviteMessageId: Int?
    }

    public struct Duel: Sendable {
        public let id: UUID
        public var a: Combatant        // challenger
        public var b: Combatant        // challenged
        /// The round being chosen now, from 1.
        public var round: Int
        /// When the round is played with whatever has been chosen by then.
        public var roundDeadline: Date
        /// The choices locked in for this round — hidden from the other side
        /// until the round is played.
        public var choiceA: DuelMath.Action?
        public var choiceB: DuelMath.Action?

        public func me(_ tg: Int64) -> Combatant { tg == a.telegramId ? a : b }
        public func opp(_ tg: Int64) -> Combatant { tg == a.telegramId ? b : a }
        public func isA(_ tg: Int64) -> Bool { tg == a.telegramId }
        public func choice(of tg: Int64) -> DuelMath.Action? { isA(tg) ? choiceA : choiceB }
    }

    /// One played round, as the screens need it: both blows, who was forced
    /// into Defend by the clock, and both fighters as the round left them.
    public struct RoundReport: Sendable {
        public let round: Int
        public let a: Combatant
        public let b: Combatant
        /// `a`'s blow on `b`, and `b`'s on `a`.
        public let blowA: DuelMath.Blow
        public let blowB: DuelMath.Blow
        public let forcedA: Bool
        public let forcedB: Bool
        /// Both fell this round; the heavier blow decided it (or drew).
        public let bothFell: Bool

        public func opp(_ tg: Int64) -> Combatant { tg == a.telegramId ? b : a }
        /// The viewer's own blow and the opponent's, each with whether the
        /// clock forced it.
        public func blows(seenBy tg: Int64) -> (mine: DuelMath.Blow, mineForced: Bool,
                                                theirs: DuelMath.Blow, theirsForced: Bool) {
            tg == a.telegramId
                ? (blowA, forcedA, blowB, forcedB)
                : (blowB, forcedB, blowA, forcedA)
        }
    }

    /// How a duel ended. Every ending with a winner names both sides; the two
    /// without one are distinct because only one of them is settled.
    public enum Ending: Sendable, Equatable {
        /// A round's blows ended it — including both falling, where the
        /// heavier blow wins.
        case knockout(winner: Int64, loser: Int64)
        case surrender(winner: Int64, loser: Int64)
        /// The loser let `maxMissedTurns` rounds in a row run out.
        case forfeit(winner: Int64, loser: Int64)
        /// Both fell to blows of the same size. Settled — HP and the day's
        /// count — with nothing changing hands.
        case draw
        /// Both let the clock run out to the limit in the same round. Nothing
        /// is written at all, as if the bot had restarted.
        case abandoned

        public var winnerAndLoser: (winner: Int64, loser: Int64)? {
            switch self {
            case .knockout(let w, let l), .surrender(let w, let l), .forfeit(let w, let l):
                return (w, l)
            case .draw, .abandoned:
                return nil
            }
        }
    }

    /// Both fighters' final snapshots — returned by teardown so the controller
    /// can settle + notify + restore both players.
    public struct Ended: Sendable {
        public let a: Combatant
        public let b: Combatant
        public let ending: Ending
        /// The round that ended the duel, for the result screen. Nil when no
        /// round did: a surrender, a forfeit, an abandoned duel.
        public let finalRound: RoundReport?
    }

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
    public func challenge(challenger: Combatant, stake: Int, targetTelegramId tg: Int64,
                          opponentLocale: String, now: Date = Date()) -> ChallengeResult {
        if byUser[challenger.telegramId] != nil { return .selfBusy }
        if byUser[tg] != nil { return .targetBusy }
        guard let entry = lobby[tg], now.timeIntervalSince(entry.lastSeen) < ArenaCatalog.lobbyTTL else {
            return .targetGone
        }
        let pc = PendingChallenge(
            id: UUID(), stake: stake, challenger: challenger,
            opponentTelegramId: tg, opponentNickname: entry.nickname, opponentLocale: opponentLocale,
            createdAt: now, inviteMessageId: nil
        )
        pending[pc.id] = pc
        byUser[challenger.telegramId] = pc.id
        byUser[tg] = pc.id
        // Both are hidden from every opponent list by `byUser` alone —
        // `lobbyMembers` filters on it. Until 2026-09-16 this ALSO deleted both
        // lobby entries, and nothing ever put them back: once a challenge was
        // declined or expired, both players were invisible to everyone until
        // they re-opened the arena screen. A belt-and-braces line that outlived
        // its own reason and became a presence leak. Presence now ages out
        // through `lastSeen` and `lobbyTTL`, which is the only thing that
        // should ever end it.
        return .created(pc)
    }

    /// Remember which message carries this challenge's buttons, so accept,
    /// decline, expiry and abort can all strip them. Sent after the challenge
    /// is created, hence the second step.
    public func attachInvite(_ id: UUID, messageId: Int) {
        pending[id]?.inviteMessageId = messageId
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

    // MARK: - Start

    /// Promote a pending challenge into a live duel. The controller re-snapshots
    /// BOTH fighters fresh at accept-time (stats current as of the answer) and
    /// passes them in. Returns the fresh duel, its first round open.
    public func startDuel(pendingId: UUID, challenger a: Combatant, opponent b: Combatant, now: Date = Date()) -> Duel? {
        guard pending.removeValue(forKey: pendingId) != nil else { return nil }
        let duel = Duel(
            id: UUID(), a: a, b: b,
            round: 1, roundDeadline: now.addingTimeInterval(ArenaCatalog.turnSeconds),
            choiceA: nil, choiceB: nil
        )
        duels[duel.id] = duel
        byUser[a.telegramId] = duel.id
        byUser[b.telegramId] = duel.id
        return duel
    }

    // MARK: - Choosing and playing a round

    public enum ChoiceResult: Sendable {
        /// Locked in; the opponent has not chosen yet.
        case waiting(round: Int)
        /// This fighter already chose this round — the first tap stands.
        case alreadyChosen(round: Int)
        /// Both had chosen, the round was played and the duel goes on;
        /// `next` has the following round open.
        case played(RoundReport, next: Duel)
        case ended(Ended)
        case noDuel
    }

    /// Lock in `tg`'s choice for the current round, and play the round if it
    /// was the second choice. A tap that arrives just after the clock played
    /// the round lands in the NEXT one — the reply keyboard cannot say which
    /// round it meant — which is why the confirmation names the round.
    public func choose(_ action: DuelMath.Action, tg: Int64, now: Date = Date()) -> ChoiceResult {
        guard let id = byUser[tg], var duel = duels[id] else { return .noDuel }
        if duel.choice(of: tg) != nil { return .alreadyChosen(round: duel.round) }

        if duel.isA(tg) {
            duel.choiceA = action
            duel.a.missedRounds = 0
        } else {
            duel.choiceB = action
            duel.b.missedRounds = 0
        }

        guard let actionA = duel.choiceA, let actionB = duel.choiceB else {
            duels[id] = duel
            return .waiting(round: duel.round)
        }
        return play(id, duel, actionA: actionA, actionB: actionB, forcedA: false, forcedB: false, now: now)
    }

    /// Roll the round and either open the next one or tear the duel down.
    private func play(_ id: UUID, _ duel: Duel,
                      actionA: DuelMath.Action, actionB: DuelMath.Action,
                      forcedA: Bool, forcedB: Bool, now: Date) -> ChoiceResult {
        var duel = duel
        let rolled = CombatService.resolveDuelRound(a: duel.a.stats, aAction: actionA,
                                                    b: duel.b.stats, bAction: actionB)
        duel.a.hp = rolled.aHP
        duel.b.hp = rolled.bHP
        let report = RoundReport(round: duel.round, a: duel.a, b: duel.b,
                                 blowA: rolled.a, blowB: rolled.b,
                                 forcedA: forcedA, forcedB: forcedB,
                                 bothFell: rolled.bothFell)

        let a = duel.a.telegramId, b = duel.b.telegramId
        switch rolled.verdict {
        case .continues:
            duel.round += 1
            duel.choiceA = nil
            duel.choiceB = nil
            duel.roundDeadline = now.addingTimeInterval(ArenaCatalog.turnSeconds)
            duels[id] = duel
            return .played(report, next: duel)
        case .aWins:
            return .ended(teardownDuel(id, ending: .knockout(winner: a, loser: b), finalRound: report, from: duel))
        case .bWins:
            return .ended(teardownDuel(id, ending: .knockout(winner: b, loser: a), finalRound: report, from: duel))
        case .draw:
            return .ended(teardownDuel(id, ending: .draw, finalRound: report, from: duel))
        }
    }

    /// A fighter throws in the towel (allowed whether or not they have chosen).
    public func surrender(tg: Int64) -> Ended? {
        guard let id = byUser[tg], let duel = duels[id] else { return nil }
        let opp = duel.opp(tg)
        return teardownDuel(id, ending: .surrender(winner: opp.telegramId, loser: tg), finalRound: nil, from: duel)
    }

    // MARK: - Teardown

    private func teardownDuel(_ id: UUID, ending: Ending, finalRound: RoundReport?, from duel: Duel) -> Ended {
        duels.removeValue(forKey: id)
        byUser.removeValue(forKey: duel.a.telegramId)
        byUser.removeValue(forKey: duel.b.telegramId)
        return Ended(a: duel.a, b: duel.b, ending: ending, finalRound: finalRound)
    }

    // MARK: - Sweep (TTL + round clocks)

    /// Result of one sweep pass for the background loop to act on.
    public struct SweepOutput: Sendable {
        public var expiredChallenges: [PendingChallenge] = []
        /// Rounds the clock played; each duel goes on with its next round open.
        public var playedRounds: [(report: RoundReport, next: Duel)] = []
        /// Duels the clock ended — by the round it played, or by a walkover.
        public var ended: [Ended] = []
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

        // Rounds whose clock ran out: whoever has not chosen defends.
        for (id, var duel) in duels where now >= duel.roundDeadline {
            let missedA = duel.choiceA == nil
            let missedB = duel.choiceB == nil
            if missedA { duel.a.missedRounds += 1 }
            if missedB { duel.b.missedRounds += 1 }

            let a = duel.a.telegramId, b = duel.b.telegramId
            switch DuelMath.walkover(missedA: duel.a.missedRounds, missedB: duel.b.missedRounds,
                                     limit: ArenaCatalog.maxMissedTurns) {
            case .abandoned:
                out.ended.append(teardownDuel(id, ending: .abandoned, finalRound: nil, from: duel))
                continue
            case .aForfeits:
                out.ended.append(teardownDuel(id, ending: .forfeit(winner: b, loser: a), finalRound: nil, from: duel))
                continue
            case .bForfeits:
                out.ended.append(teardownDuel(id, ending: .forfeit(winner: a, loser: b), finalRound: nil, from: duel))
                continue
            case .none:
                break
            }

            switch play(id, duel, actionA: duel.choiceA ?? .defend, actionB: duel.choiceB ?? .defend,
                        forcedA: missedA, forcedB: missedB, now: now) {
            case .played(let report, let next): out.playedRounds.append((report, next))
            case .ended(let ended):             out.ended.append(ended)
            case .waiting, .alreadyChosen, .noDuel: break
            }
        }

        return out
    }
}
