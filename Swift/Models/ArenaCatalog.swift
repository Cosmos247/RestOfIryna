//
//  ArenaCatalog.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 20.07.2026.
//
//  Façade over `content/data/arena.json` (Phase 3B — was eleven Swift constants
//  and a hardcoded `switch`). The Arena ("Ристалище") is the live player-to-
//  player duel (герць): stake tiers, the King's tithe (silver sink), the Honor
//  (Честь) rating curve, per-turn timing, the daily fight budget, and the
//  league ladder.
//
//  `leagueKey` was the one piece of control flow in the batch. It is now a table
//  of ascending bands; the migration digest replays it across honor 0…2000 and
//  the exporter proved the table reproduces the original switch over −500…3000
//  before the flip.
//

import Foundation

public enum ArenaCatalog {

    // MARK: - Stakes & payout

    /// Silver wager tiers offered when challenging. Both fighters put up the
    /// same stake; the pot is `2 × stake`.
    public static var stakeTiers: [Int] { Catalogs.current.arena.stakeTiers }

    /// King's tithe on the pot — burned silver (the Arena's silver sink).
    /// Winner receives `pot − tithe`.
    public static var tithePercent: Int { Catalogs.current.arena.tithePercent }

    /// Tithe (rounded) on a given pot.
    public static func tithe(onPot pot: Int) -> Int {
        Int((Double(pot) * Double(tithePercent) / 100.0).rounded())
    }

    // MARK: - Honor (Честь) rating

    /// Rating everyone starts at (also the pivot for the league ladder).
    public static var startingHonor: Int { Catalogs.current.arena.startingHonor }

    /// ELO K-factor — how far a single result can move the rating.
    public static var honorKFactor: Double { Catalogs.current.arena.honorKFactor }

    /// Honor can't drop below this (no negative rating).
    public static var minHonor: Int { Catalogs.current.arena.minHonor }

    // MARK: - Turn timing

    /// Seconds a fighter has to act before the turn is auto-resolved.
    public static var turnSeconds: TimeInterval { Catalogs.current.arena.turnSeconds }

    /// Consecutive missed turns before the idle fighter forfeits the duel.
    public static var maxMissedTurns: Int { Catalogs.current.arena.maxMissedTurns }

    /// A pending challenge with no answer is swept after this long.
    public static var challengeTTL: TimeInterval { Catalogs.current.arena.challengeTTL }

    /// Lobby presence drops out of the challenge list after this idle window.
    public static var lobbyTTL: TimeInterval { Catalogs.current.arena.lobbyTTL }

    /// How often the background sweeper scans (turn timeouts + stale presence).
    public static var sweepInterval: TimeInterval { Catalogs.current.arena.sweepInterval }

    // MARK: - Daily budget

    /// Completed duels a fighter may take part in per day. Generous while the
    /// system is being play-tested — tune down before release.
    public static var dailyFightCap: Int { Catalogs.current.arena.dailyFightCap }

    // MARK: - Leagues

    /// Ladder tier for a given Honor value. Returns the localization key stem
    /// under `arena.league.*`.
    ///
    /// The last band at or below `honor`, falling back to the first band. That
    /// tail is not decoration: the shipped `case ..<1000` also caught negative
    /// Honor, and the validator only guarantees the opening band starts at or
    /// below `minHonor` — a rating below it still has to resolve to something.
    public static func leagueKey(forHonor honor: Int) -> String {
        let leagues = Catalogs.current.arena.leagues
        return (leagues.last { honor >= $0.fromHonor } ?? leagues.first)?.key ?? ""
    }
}
