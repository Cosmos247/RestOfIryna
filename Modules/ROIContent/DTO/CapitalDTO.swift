//
//  CapitalDTO.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 29.08.2026.
//
//  Wire format for the five capital institutions — `trader.json`,
//  `tavern.json`, `market.json`, `guild.json` and `arena.json`. They share one
//  file because they are one thing: every entry in `CapitalController.Location`
//  that carries tunable numbers.
//
//  Two shapes live here, and they are validated differently:
//
//  * **Record files** (trader, tavern) are ordered arrays. Order is gameplay —
//    it decides the menu the player scrolls — so nothing sorts them.
//  * **Scalar files** (market, guild, arena) are flat tuning constants with no
//    array to be empty. That is why every field below is decoded with `decode`
//    and never `decodeIfPresent`: a missing `memberCap` has to fail the boot,
//    because silently falling back to 20 is exactly the invisible balance drift
//    this pipeline exists to prevent. The hand-written `init(from:)` stays
//    anyway so that introducing a default later is a deliberate edit rather
//    than an accident of synthesis (see `ContentDTOTests`).
//
//  `ArenaCatalog.leagueKey` is the one real table here. It ships as a hardcoded
//  `switch`; written down as ascending bands it becomes checkable, and the
//  migration digest replays it across honor 0…2000 to prove the two agree.
//

import Foundation

// MARK: - Trader

/// One row of the capital trader's book. Two asymmetric packets: what the
/// trader pays the player, and what the trader charges them.
public struct TraderListingDTO: Codable, Sendable, Equatable {
    public let itemId: String
    public let sellPacketQty: Int
    public let sellPacketSilver: Int
    public let buyPacketQty: Int
    public let buyPacketSilver: Int

    public init(itemId: String,
                sellPacketQty: Int, sellPacketSilver: Int,
                buyPacketQty: Int, buyPacketSilver: Int) {
        self.itemId = itemId
        self.sellPacketQty = sellPacketQty
        self.sellPacketSilver = sellPacketSilver
        self.buyPacketQty = buyPacketQty
        self.buyPacketSilver = buyPacketSilver
    }

    private enum CodingKeys: String, CodingKey {
        case itemId, sellPacketQty, sellPacketSilver, buyPacketQty, buyPacketSilver
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        itemId           = try c.decode(String.self, forKey: .itemId)
        sellPacketQty    = try c.decode(Int.self, forKey: .sellPacketQty)
        sellPacketSilver = try c.decode(Int.self, forKey: .sellPacketSilver)
        buyPacketQty     = try c.decode(Int.self, forKey: .buyPacketQty)
        buyPacketSilver  = try c.decode(Int.self, forKey: .buyPacketSilver)
    }
}

/// Top-level shape of `trader.json`.
public struct TraderFileDTO: Codable, Sendable {
    /// Display order, preserved verbatim — materials first, then food, rare
    /// items at the end of their block.
    public let listings: [TraderListingDTO]

    public init(listings: [TraderListingDTO]) {
        self.listings = listings
    }

    private enum CodingKeys: String, CodingKey { case listings }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        listings = try c.decode([TraderListingDTO].self, forKey: .listings)
    }
}

// MARK: - Tavern

public struct TavernFoodDTO: Codable, Sendable, Equatable {
    public let itemId: String
    /// Silvers the player pays to receive one of this dish into their bag.
    public let priceSilver: Int

    public init(itemId: String, priceSilver: Int) {
        self.itemId = itemId
        self.priceSilver = priceSilver
    }

    private enum CodingKeys: String, CodingKey { case itemId, priceSilver }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        itemId      = try c.decode(String.self, forKey: .itemId)
        priceSilver = try c.decode(Int.self, forKey: .priceSilver)
    }
}

/// Top-level shape of `tavern.json`.
public struct TavernFileDTO: Codable, Sendable {
    /// Menu order, ascending by price so it reads cheap → premium.
    public let food: [TavernFoodDTO]
    /// Shared wager tiers across dice and darts — one mental model for both.
    public let wagerTiers: [Int]

    public init(food: [TavernFoodDTO], wagerTiers: [Int]) {
        self.food = food
        self.wagerTiers = wagerTiers
    }

    private enum CodingKeys: String, CodingKey { case food, wagerTiers }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        food       = try c.decode([TavernFoodDTO].self, forKey: .food)
        wagerTiers = try c.decode([Int].self, forKey: .wagerTiers)
    }
}

// MARK: - Market

/// Top-level shape of `market.json`.
public struct MarketFileDTO: Codable, Sendable {
    /// Flat silver charged when a lot is created. Non-refundable — the
    /// market's silver sink and the soft cap on spam listings.
    public let listingFee: Int
    /// Maximum simultaneous active lots per seller.
    public let maxActiveLots: Int

    public init(listingFee: Int, maxActiveLots: Int) {
        self.listingFee = listingFee
        self.maxActiveLots = maxActiveLots
    }

    private enum CodingKeys: String, CodingKey { case listingFee, maxActiveLots }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        listingFee    = try c.decode(Int.self, forKey: .listingFee)
        maxActiveLots = try c.decode(Int.self, forKey: .maxActiveLots)
    }
}

// MARK: - Guild

/// Top-level shape of `guild.json`. The role model (`GuildRole` and its
/// permissions) deliberately stays in Swift: it is a DB raw value plus
/// authorization logic, not content.
public struct GuildFileDTO: Codable, Sendable {
    public let memberCap: Int
    /// Deputies. The leader is separate and never counted here.
    public let maxOfficers: Int
    /// Silver burned to found a guild — not seeded into the treasury.
    public let foundCost: Int
    public let foundLevelGate: Int
    /// Cosmetic emblem used when the founder doesn't pick one.
    public let defaultEmblem: String
    public let nameMinLength: Int
    public let nameMaxLength: Int
    /// Total units the shared vault holds across all item rows.
    public let vaultUnitCap: Int

    public init(memberCap: Int, maxOfficers: Int, foundCost: Int, foundLevelGate: Int,
                defaultEmblem: String, nameMinLength: Int, nameMaxLength: Int, vaultUnitCap: Int) {
        self.memberCap = memberCap
        self.maxOfficers = maxOfficers
        self.foundCost = foundCost
        self.foundLevelGate = foundLevelGate
        self.defaultEmblem = defaultEmblem
        self.nameMinLength = nameMinLength
        self.nameMaxLength = nameMaxLength
        self.vaultUnitCap = vaultUnitCap
    }

    private enum CodingKeys: String, CodingKey {
        case memberCap, maxOfficers, foundCost, foundLevelGate
        case defaultEmblem, nameMinLength, nameMaxLength, vaultUnitCap
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        memberCap      = try c.decode(Int.self, forKey: .memberCap)
        maxOfficers    = try c.decode(Int.self, forKey: .maxOfficers)
        foundCost      = try c.decode(Int.self, forKey: .foundCost)
        foundLevelGate = try c.decode(Int.self, forKey: .foundLevelGate)
        defaultEmblem  = try c.decode(String.self, forKey: .defaultEmblem)
        nameMinLength  = try c.decode(Int.self, forKey: .nameMinLength)
        nameMaxLength  = try c.decode(Int.self, forKey: .nameMaxLength)
        vaultUnitCap   = try c.decode(Int.self, forKey: .vaultUnitCap)
    }
}

// MARK: - Arena

/// One rung of the Honor ladder. `fromHonor` is the INCLUSIVE lower bound; the
/// band runs until the next one starts. Named `fromHonor` rather than
/// `minHonor` so it never reads as `ArenaFileDTO.minHonor`, which is the
/// rating floor and a different number entirely.
public struct ArenaLeagueDTO: Codable, Sendable, Equatable {
    public let fromHonor: Int
    /// Localization key stem under `arena.league.*`.
    public let key: String

    public init(fromHonor: Int, key: String) {
        self.fromHonor = fromHonor
        self.key = key
    }

    private enum CodingKeys: String, CodingKey { case fromHonor, key }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        fromHonor = try c.decode(Int.self, forKey: .fromHonor)
        key       = try c.decode(String.self, forKey: .key)
    }
}

/// Top-level shape of `arena.json`.
///
/// The four `TimeInterval` fields are `Double` on the wire. `45` and `45.0`
/// decode to the same value, and the migration digest interpolates them as
/// strings — so the JSON may hold either form without moving the digest.
public struct ArenaFileDTO: Codable, Sendable {
    /// Silver wager tiers. Both fighters put up the same stake; pot = 2 × stake.
    public let stakeTiers: [Int]
    /// King's tithe on the pot — burned silver, the Arena's sink.
    public let tithePercent: Int
    public let startingHonor: Int
    /// ELO K-factor: how far one result can move the rating.
    public let honorKFactor: Double
    /// Rating floor. Honor never drops below this.
    public let minHonor: Int
    public let turnSeconds: Double
    public let maxMissedTurns: Int
    public let challengeTTL: Double
    public let lobbyTTL: Double
    public let sweepInterval: Double
    public let dailyFightCap: Int
    /// Ascending by `fromHonor`; the validator enforces both the order and that
    /// the first band starts at or below `minHonor`, which is what makes every
    /// reachable rating land in a band.
    public let leagues: [ArenaLeagueDTO]

    public init(stakeTiers: [Int], tithePercent: Int, startingHonor: Int, honorKFactor: Double,
                minHonor: Int, turnSeconds: Double, maxMissedTurns: Int, challengeTTL: Double,
                lobbyTTL: Double, sweepInterval: Double, dailyFightCap: Int,
                leagues: [ArenaLeagueDTO]) {
        self.stakeTiers = stakeTiers
        self.tithePercent = tithePercent
        self.startingHonor = startingHonor
        self.honorKFactor = honorKFactor
        self.minHonor = minHonor
        self.turnSeconds = turnSeconds
        self.maxMissedTurns = maxMissedTurns
        self.challengeTTL = challengeTTL
        self.lobbyTTL = lobbyTTL
        self.sweepInterval = sweepInterval
        self.dailyFightCap = dailyFightCap
        self.leagues = leagues
    }

    private enum CodingKeys: String, CodingKey {
        case stakeTiers, tithePercent, startingHonor, honorKFactor, minHonor
        case turnSeconds, maxMissedTurns, challengeTTL, lobbyTTL, sweepInterval
        case dailyFightCap, leagues
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        stakeTiers     = try c.decode([Int].self, forKey: .stakeTiers)
        tithePercent   = try c.decode(Int.self, forKey: .tithePercent)
        startingHonor  = try c.decode(Int.self, forKey: .startingHonor)
        honorKFactor   = try c.decode(Double.self, forKey: .honorKFactor)
        minHonor       = try c.decode(Int.self, forKey: .minHonor)
        turnSeconds    = try c.decode(Double.self, forKey: .turnSeconds)
        maxMissedTurns = try c.decode(Int.self, forKey: .maxMissedTurns)
        challengeTTL   = try c.decode(Double.self, forKey: .challengeTTL)
        lobbyTTL       = try c.decode(Double.self, forKey: .lobbyTTL)
        sweepInterval  = try c.decode(Double.self, forKey: .sweepInterval)
        dailyFightCap  = try c.decode(Int.self, forKey: .dailyFightCap)
        leagues        = try c.decode([ArenaLeagueDTO].self, forKey: .leagues)
    }
}
