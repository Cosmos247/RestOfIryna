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
//                        A draw carries the HP and the daily count and moves
//                        nothing else; an abandoned duel is not settled at all.
//
//  The background sweeper (started from configure) runs the round clocks and
//  challenge expiry: it plays every round whose time ran out, settles any duel
//  that ends on the clock, and pushes every update to both chats through
//  `ArenaController`'s render helpers.
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
            level: user.level,
            maxHp: user.effectiveMaxHp,
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
        /// One fighter's side of the outcome, as their own result screen reads it.
        public struct Side: Sendable {
            public let telegramId: Int64
            public let nickname: String
            public let locale: String
            public let honorBefore: Int
            public let honorAfter: Int
            public let hp: Int
            public let maxHp: Int
        }

        public let a: Side
        public let b: Side
        public let ending: ArenaStore.Ending
        public let stake: Int
        public let payout: Int          // silver the winner actually gained (transfer − tithe); 0 on a draw
        public let tithe: Int
        /// The round that ended the duel — the result screen opens with it.
        public let finalRound: ArenaStore.RoundReport?

        public func side(_ tg: Int64) -> Side { tg == a.telegramId ? a : b }
        public func other(_ tg: Int64) -> Side { tg == a.telegramId ? b : a }
    }

    /// Apply the outcome of a finished duel. Idempotency is guaranteed upstream:
    /// `ArenaStore` tears the duel down before this runs, so it can fire only once.
    /// Nil for an abandoned duel, which writes nothing, and when a fighter's row
    /// is gone.
    public static func settle(_ ended: ArenaStore.Ended, on db: any Database) async throws -> Settlement? {
        if ended.ending == .abandoned { return nil }
        guard let userA = try await liveUser(ended.a, on: db),
              let userB = try await liveUser(ended.b, on: db) else { return nil }
        let profileA = try await ArenaProfile.forUser(ended.a.userId, on: db)
        let profileB = try await ArenaProfile.forUser(ended.b.userId, on: db)

        let stake = ended.a.stake
        var payout = 0, tithe = 0
        var honorA = ended.a.honor, honorB = ended.b.honor

        if let (winner, _) = ended.ending.winnerAndLoser {
            let aWon = winner == ended.a.telegramId
            let winnerU = aWon ? userA : userB, loserU = aWon ? userB : userA

            // The wager transfers loser → winner; the King's tithe is burned.
            let transfer = min(stake, loserU.silver)
            tithe = ArenaCatalog.tithe(onPot: transfer)
            payout = transfer - tithe
            loserU.silver = max(0, loserU.silver - transfer)
            winnerU.silver += payout

            let (wNew, lNew) = honorAfter(winner: aWon ? ended.a.honor : ended.b.honor,
                                          loser: aWon ? ended.b.honor : ended.a.honor)
            honorA = aWon ? wNew : lNew
            honorB = aWon ? lNew : wNew
            (aWon ? profileA : profileB).wins += 1
            (aWon ? profileB : profileA).losses += 1
        }

        // HP carry-over (non-lethal — floored at 1, no death penalty). A draw
        // lands here too: both fell, both walk out on 1.
        userA.hp = max(1, min(ended.a.hp, userA.effectiveMaxHp))
        userB.hp = max(1, min(ended.b.hp, userB.effectiveMaxHp))
        try await userA.saveAndCache(in: db)
        try await userB.saveAndCache(in: db)

        // Honor + the daily counter. A draw is a fight fought, so it spends a
        // fight from the day's budget and leaves the rating where it was.
        profileA.honor = honorA; profileA.bumpDailyCounter()
        profileB.honor = honorB; profileB.bumpDailyCounter()
        try await profileA.save(on: db)
        try await profileB.save(on: db)

        func side(_ c: ArenaStore.Combatant, _ u: User, honorAfter: Int) -> Settlement.Side {
            Settlement.Side(telegramId: c.telegramId, nickname: c.nickname, locale: c.locale,
                            honorBefore: c.honor, honorAfter: honorAfter,
                            hp: u.hp, maxHp: u.effectiveMaxHp)
        }
        return Settlement(
            a: side(ended.a, userA, honorAfter: honorA),
            b: side(ended.b, userB, honorAfter: honorB),
            ending: ended.ending, stake: stake, payout: payout, tithe: tithe,
            finalRound: ended.finalRound
        )
    }

    /// The fighter's live session object when one is cached, a fresh row
    /// otherwise. Settlement is a write the player did not tap — the round
    /// that ended the duel may have been played by the other fighter's tap or
    /// by the sweeper — so it follows the background-writer rule.
    /// `saveAndCache` installs whatever object it saved as the session for the
    /// next tap, so a settlement working on its own copy leaves the dispatcher
    /// holding a stale one: `/start` mid-duel settles and then saves that very
    /// session, which put the pre-settlement silver and HP back in the cache
    /// as the player's live state.
    private static func liveUser(_ c: ArenaStore.Combatant, on db: any Database) async throws -> User? {
        if let live = await sessionCache.peek(telegramId: c.telegramId) { return live }
        return try await User.find(c.userId, on: db)
    }

    // MARK: - Sweeper

    /// Background loop (mirrors TradeStore.startSweeper). Handles challenge
    /// expiry and the round clocks — playing every round whose time ran out and
    /// settling every duel that ends on the clock — pushing every update to
    /// both chats through ArenaController's render helpers.
    public static func startSweeper(on db: any Database, bot: TGBot, lingo: Lingo) {
        Task.detached {
            while true {
                try? await Task.sleep(nanoseconds: UInt64(ArenaCatalog.sweepInterval * 1_000_000_000))
                let out = await ArenaStore.shared.sweep()

                for pc in out.expiredChallenges {
                    await ArenaController.pushChallengeExpired(pc, bot: bot, lingo: lingo)
                }
                for (report, next) in out.playedRounds {
                    await ArenaController.pushRound(report, next: next, bot: bot, lingo: lingo)
                }
                for ended in out.ended {
                    await ArenaController.finish(ended, db: db, bot: bot, lingo: lingo)
                }
            }
        }
    }
}
