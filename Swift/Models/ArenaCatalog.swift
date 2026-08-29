//
//  ArenaCatalog.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 20.07.2026.
//
//  Phase 8.3 — the Arena ("Ристалище"). Code-based tuning for the live
//  player-to-player duel (герць): stake tiers, the King's tithe (silver sink),
//  the Honor (Честь) rating curve, per-turn timing, the daily fight budget, and
//  the league thresholds. Everything here is a pure constant / pure function so
//  it can be tuned in one place without touching the store or the controller.
//

import Foundation

public enum ArenaCatalog {

    // MARK: - Stakes & payout

    /// Silver wager tiers offered when challenging. Both fighters put up the
    /// same stake; the pot is `2 × stake`.
    public static let stakeTiers: [Int] = [25, 100, 500]

    /// King's tithe on the pot — burned silver (the Arena's silver sink).
    /// Winner receives `pot − tithe`.
    public static let tithePercent: Int = 10

    /// Tithe (rounded) on a given pot.
    public static func tithe(onPot pot: Int) -> Int {
        Int((Double(pot) * Double(tithePercent) / 100.0).rounded())
    }

    // MARK: - Honor (Честь) rating

    /// Rating everyone starts at (also the pivot for the league ladder).
    public static let startingHonor: Int = 1000

    /// ELO K-factor — how far a single result can move the rating.
    public static let honorKFactor: Double = 32

    /// Honor can't drop below this (no negative rating).
    public static let minHonor: Int = 0

    // MARK: - Turn timing

    /// Seconds a fighter has to act before the turn is auto-resolved.
    public static let turnSeconds: TimeInterval = 45

    /// Consecutive missed turns before the idle fighter forfeits the duel.
    public static let maxMissedTurns: Int = 2

    /// A pending challenge with no answer is swept after this long.
    public static let challengeTTL: TimeInterval = 120

    /// Lobby presence drops out of the challenge list after this idle window.
    public static let lobbyTTL: TimeInterval = 180

    /// How often the background sweeper scans (turn timeouts + stale presence).
    public static let sweepInterval: TimeInterval = 10

    // MARK: - Daily budget

    /// Completed duels a fighter may take part in per day. Generous while the
    /// system is being play-tested — tune down before release.
    public static let dailyFightCap: Int = 20

    // MARK: - Leagues

    /// Ladder tier for a given Honor value. Returns the localization key stem
    /// under `arena.league.*`.
    public static func leagueKey(forHonor honor: Int) -> String {
        switch honor {
        case ..<1000:      return "arena.league.novice"
        case 1000..<1150:  return "arena.league.fighter"
        case 1150..<1350:  return "arena.league.veteran"
        default:           return "arena.league.champion"
        }
    }
}
