//
//  ArenaService.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 20.07.2026.
//
//  Phase 8.3 — the database side of the Arena. `ArenaStore` runs the live duel
//  in memory; this enum does the DB jobs:
//
//    • `snapshot`      — freeze a User into a duel `Combatant` (effective stats +
//                        current HP + pre-duel Honor).
//    • `validateMatch` — both fighters alive, both can cover the stake, both under
//                        the daily budget. NO silver is moved here: a герць isn't
//                        backed by escrow, so a bot restart mid-fight cancels with
//                        zero financial effect. Silver only changes hands at
//                        settlement, when a winner exists.
//    • `settle`        — transfer the wager (loser → winner, minus the King's
//                        tithe which is burned), carry the battle HP back onto both
//                        Users (non-lethal: floored at 1, no death penalty), update
//                        both Honor ratings (ELO), bump win/loss + the daily
//                        counter. Validate-then-mutate, mirroring TradeService.
//
//  The background sweeper (started from configure) handles turn timeouts and
//  challenge expiry, settling any duel that ends by forfeit and pushing the
//  round updates to both chats via `ArenaController`'s render helpers.
//

import Fluent
import Foundation
import SwiftTelegramBot
@preconcurrency import Lingo

public enum ArenaService {

    // MARK: - Snapshot

    /// Freeze a user into a combatant. HP starts from the player's CURRENT hp
    /// (the "поточне HP" rule — you fight with the body you bring), stats from
    /// the effective (gear + fortune) values, Honor from the arena profile.
    public static func snapshot(for user: User, stake: Int, honor: Int) -> ArenaStore.Combatant {
        ArenaStore.Combatant(
            telegramId: user.telegramId,
            userId: user.id ?? UUID(),
            nickname: user.nickname ?? "—",
            locale: user.locale,
            atk: user.effectiveAttack,
            def: user.effectiveDefense,
            crit: user.effectiveCrit,
            dodge: user.effectiveDodge,
            acc: user.effectiveAccuracy,
            maxHp: user.maxHp,
            hp: max(1, user.hp),
            stake: stake,
            honor: honor
        )
    }

    // MARK: - Match validation (no silver moved)

    public enum MatchProblem: Sendable {
        case challengerBroke(have: Int, need: Int)
        case opponentBroke(have: Int, need: Int)
        case challengerDead
        case opponentDead
        case challengerDailyCap
        case opponentDailyCap
    }

    public enum MatchCheck: Sendable {
        case ok(challengerHonor: Int, opponentHonor: Int)
        case failed(MatchProblem)
    }

    /// Both fighters alive, solvent for the stake, and under the daily budget.
    public static func validateMatch(challenger: User, opponent: User, stake: Int, on db: any Database) async throws -> MatchCheck {
        if challenger.hp <= 0 { return .failed(.challengerDead) }
        if opponent.hp <= 0 { return .failed(.opponentDead) }
        if challenger.silver < stake { return .failed(.challengerBroke(have: challenger.silver, need: stake)) }
        if opponent.silver < stake { return .failed(.opponentBroke(have: opponent.silver, need: stake)) }

        guard let cId = challenger.id, let oId = opponent.id else { return .failed(.challengerDead) }
        let cProfile = try await ArenaProfile.forUser(cId, on: db)
        let oProfile = try await ArenaProfile.forUser(oId, on: db)
        if cProfile.fightsSpentToday() >= ArenaCatalog.dailyFightCap { return .failed(.challengerDailyCap) }
        if oProfile.fightsSpentToday() >= ArenaCatalog.dailyFightCap { return .failed(.opponentDailyCap) }

        return .ok(challengerHonor: cProfile.honor, opponentHonor: oProfile.honor)
    }

    // MARK: - Honor (ELO)

    /// Symmetric ELO update. Returns the fighters' new ratings.
    public static func honorAfter(winner: Int, loser: Int) -> (winner: Int, loser: Int) {
        let expWinner = 1.0 / (1.0 + pow(10.0, Double(loser - winner) / 400.0))
        let expLoser  = 1.0 / (1.0 + pow(10.0, Double(winner - loser) / 400.0))
        let winnerNew = winner + Int((ArenaCatalog.honorKFactor * (1.0 - expWinner)).rounded())
        let loserNew  = max(ArenaCatalog.minHonor, loser + Int((ArenaCatalog.honorKFactor * (0.0 - expLoser)).rounded()))
        return (winnerNew, loserNew)
    }

    // MARK: - Settlement

    public struct Settlement: Sendable {
        public let winnerTelegramId: Int64
        public let loserTelegramId: Int64
        public let winnerNickname: String
        public let loserNickname: String
        public let winnerLocale: String
        public let loserLocale: String
        public let stake: Int
        public let payout: Int          // silver the winner actually gained (stake − tithe)
        public let tithe: Int
        public let winnerHonorBefore: Int
        public let winnerHonorAfter: Int
        public let loserHonorBefore: Int
        public let loserHonorAfter: Int
        public let winnerHp: Int
        public let winnerMaxHp: Int
        public let loserHp: Int
        public let loserMaxHp: Int
        public let reason: ArenaStore.EndReason
    }

    /// Apply the outcome of a finished duel. Idempotency is guaranteed upstream:
    /// `ArenaStore` tears the duel down before this runs, so it can fire only once.
    public static func settle(_ ended: ArenaStore.Ended, on db: any Database) async throws -> Settlement? {
        let winnerC = ended.winnerTelegramId == ended.a.telegramId ? ended.a : ended.b
        let loserC  = ended.winnerTelegramId == ended.a.telegramId ? ended.b : ended.a

        guard let winnerU = try await User.find(winnerC.userId, on: db),
              let loserU  = try await User.find(loserC.userId, on: db) else { return nil }

        let stake = winnerC.stake
        // The wager transfers loser → winner; the King's tithe is burned.
        let transfer = min(stake, loserU.silver)
        let tithe = ArenaCatalog.tithe(onPot: transfer)
        let payout = transfer - tithe

        // Silver.
        loserU.silver = max(0, loserU.silver - transfer)
        winnerU.silver += payout

        // HP carry-over (non-lethal — floored at 1, no death penalty).
        winnerU.hp = max(1, min(winnerC.hp, winnerU.maxHp))
        loserU.hp  = max(1, min(loserC.hp, loserU.maxHp))

        try await winnerU.saveAndCache(in: db)
        try await loserU.saveAndCache(in: db)

        // Honor + tallies + daily counter.
        let (wNew, lNew) = honorAfter(winner: winnerC.honor, loser: loserC.honor)
        let wProfile = try await ArenaProfile.forUser(winnerC.userId, on: db)
        let lProfile = try await ArenaProfile.forUser(loserC.userId, on: db)
        wProfile.honor = wNew; wProfile.wins += 1; wProfile.bumpDailyCounter()
        lProfile.honor = lNew; lProfile.losses += 1; lProfile.bumpDailyCounter()
        try await wProfile.save(on: db)
        try await lProfile.save(on: db)

        return Settlement(
            winnerTelegramId: winnerC.telegramId, loserTelegramId: loserC.telegramId,
            winnerNickname: winnerC.nickname, loserNickname: loserC.nickname,
            winnerLocale: winnerC.locale, loserLocale: loserC.locale,
            stake: stake, payout: payout, tithe: tithe,
            winnerHonorBefore: winnerC.honor, winnerHonorAfter: wNew,
            loserHonorBefore: loserC.honor, loserHonorAfter: lNew,
            winnerHp: winnerU.hp, winnerMaxHp: winnerU.maxHp,
            loserHp: loserU.hp, loserMaxHp: loserU.maxHp,
            reason: ended.reason
        )
    }

    // MARK: - Sweeper

    /// Background loop (mirrors TradeStore.startSweeper). Handles challenge
    /// expiry, turn timeouts, and timeout-forfeits — settling the latter and
    /// pushing every update to both chats through ArenaController render helpers.
    public static func startSweeper(on db: any Database, bot: TGBot, lingo: Lingo) {
        Task.detached {
            while true {
                try? await Task.sleep(nanoseconds: UInt64(ArenaCatalog.sweepInterval * 1_000_000_000))
                let out = await ArenaStore.shared.sweep()

                for pc in out.expiredChallenges {
                    await ArenaController.pushChallengeExpired(pc, bot: bot, lingo: lingo)
                }
                for (duel, log, actorTg) in out.timedOutTurns {
                    await ArenaController.pushDuelState(duel, log: log, actorTelegramId: actorTg, bot: bot, lingo: lingo)
                }
                for (ended, log) in out.forfeits {
                    if let settlement = try? await settle(ended, on: db) {
                        await ArenaController.pushDuelResult(settlement, finalLog: log, bot: bot, lingo: lingo)
                    }
                }
            }
        }
    }
}
