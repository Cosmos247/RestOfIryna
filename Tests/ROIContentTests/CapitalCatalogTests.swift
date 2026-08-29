//
//  CapitalCatalogTests.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 29.08.2026.
//
//  Locks the Phase 3B contract for the five capital institutions.
//
//  The theme is the difference between the ladders and these files. A ladder is
//  a list, so an omitted `inputs` sensibly means "no cost". A tuning scalar has
//  no such reading: a missing `memberCap` is a corrupt file, and defaulting it
//  to anything at all would be a silent balance change of exactly the kind this
//  pipeline exists to make impossible. So these DTOs decode every field as
//  REQUIRED, and the first tests here are what stops someone from "helpfully"
//  relaxing one into `decodeIfPresent` later.
//

import XCTest
@testable import ROIContent

final class CapitalCatalogTests: XCTestCase {

    // MARK: - Strictness

    func testGuildFileRejectsAMissingScalar() {
        // Everything but `vaultUnitCap`.
        let json = Data(#"""
        {"memberCap":20,"maxOfficers":2,"foundCost":500,"foundLevelGate":5,
         "defaultEmblem":"🛡","nameMinLength":3,"nameMaxLength":24}
        """#.utf8)
        XCTAssertThrowsError(try JSONDecoder().decode(GuildFileDTO.self, from: json),
                             "a missing tuning scalar must fail the load, never fall back to a default")
    }

    func testMarketFileRejectsAMissingScalar() {
        let json = Data(#"{"listingFee":5}"#.utf8)
        XCTAssertThrowsError(try JSONDecoder().decode(MarketFileDTO.self, from: json))
    }

    func testArenaFileRejectsAMissingLeagueTable() {
        let json = Data(#"""
        {"stakeTiers":[25],"tithePercent":10,"startingHonor":1000,"honorKFactor":32,
         "minHonor":0,"turnSeconds":45,"maxMissedTurns":2,"challengeTTL":120,
         "lobbyTTL":180,"sweepInterval":10,"dailyFightCap":20}
        """#.utf8)
        XCTAssertThrowsError(try JSONDecoder().decode(ArenaFileDTO.self, from: json))
    }

    /// The digest interpolates the four timing fields as strings (`"45.0"`), so
    /// an integral JSON number and a decimal one have to land on the same
    /// `Double` or the migration proof would depend on JSON formatting.
    func testIntegralAndDecimalTimingsDecodeIdentically() throws {
        func arena(_ turn: String) throws -> ArenaFileDTO {
            let json = Data(#"""
            {"stakeTiers":[25],"tithePercent":10,"startingHonor":1000,"honorKFactor":32,
             "minHonor":0,"turnSeconds":\#(turn),"maxMissedTurns":2,"challengeTTL":120,
             "lobbyTTL":180,"sweepInterval":10,"dailyFightCap":20,
             "leagues":[{"fromHonor":0,"key":"arena.league.novice"}]}
            """#.utf8)
            return try JSONDecoder().decode(ArenaFileDTO.self, from: json)
        }
        XCTAssertEqual(try arena("45").turnSeconds, try arena("45.0").turnSeconds)
        XCTAssertEqual("\(try arena("45").turnSeconds)", "45.0")
    }

    // MARK: - Fixtures

    private func bundle(trader: TraderFileDTO? = nil,
                        tavern: TavernFileDTO? = nil,
                        market: MarketFileDTO? = nil,
                        guild: GuildFileDTO? = nil,
                        arena: ArenaFileDTO? = nil) -> ContentBundle {
        ContentBundle(
            manifest: ManifestDTO(schemaVersion: ContentSchema.current),
            items: [
                ItemDTO(id: "mat.river_pebble", type: "material", tier: 1, stackable: true),
                ItemDTO(id: "food.baked_potato", type: "food", tier: 1, stackable: true)
            ],
            enemies: [], recipes: [], starterRecipeIds: [],
            trader: trader, tavern: tavern, market: market, guild: guild, arena: arena,
            contentHash: "test"
        )
    }

    private func validGuild(_ mutate: (inout [String: Int]) -> Void = { _ in }) -> GuildFileDTO {
        var v = ["memberCap": 20, "maxOfficers": 2, "foundCost": 500, "foundLevelGate": 5,
                 "nameMinLength": 3, "nameMaxLength": 24, "vaultUnitCap": 3000]
        mutate(&v)
        return GuildFileDTO(memberCap: v["memberCap"]!, maxOfficers: v["maxOfficers"]!,
                            foundCost: v["foundCost"]!, foundLevelGate: v["foundLevelGate"]!,
                            defaultEmblem: "🛡", nameMinLength: v["nameMinLength"]!,
                            nameMaxLength: v["nameMaxLength"]!, vaultUnitCap: v["vaultUnitCap"]!)
    }

    private func validArena(leagues: [ArenaLeagueDTO]? = nil, minHonor: Int = 0,
                            sweepInterval: Double = 10) -> ArenaFileDTO {
        ArenaFileDTO(
            stakeTiers: [25, 100, 500], tithePercent: 10, startingHonor: 1000,
            honorKFactor: 32, minHonor: minHonor, turnSeconds: 45, maxMissedTurns: 2,
            challengeTTL: 120, lobbyTTL: 180, sweepInterval: sweepInterval, dailyFightCap: 20,
            leagues: leagues ?? [
                ArenaLeagueDTO(fromHonor: 0, key: "arena.league.novice"),
                ArenaLeagueDTO(fromHonor: 1000, key: "arena.league.fighter")
            ]
        )
    }

    private func rules(_ bundle: ContentBundle) -> Set<String> {
        Set(ContentValidator.validate(bundle).issues.map(\.rule))
    }

    // MARK: - Trader

    /// The invariant the shipped catalog held only by convention. Buying a unit
    /// for less than selling it pays is an unbounded silver faucet, and it is a
    /// one-character typo away at every price edit.
    func testTraderArbitrageIsAnError() {
        let bad = TraderFileDTO(listings: [
            TraderListingDTO(itemId: "mat.river_pebble", sellPacketQty: 1, sellPacketSilver: 3,
                             buyPacketQty: 1, buyPacketSilver: 2)
        ])
        XCTAssertTrue(rules(bundle(trader: bad)).contains("trader.arbitrage"))
    }

    /// Equal prices are a zero-margin trade, not a faucet — it must stay legal.
    func testTraderEqualSellAndBuyIsClean() {
        let even = TraderFileDTO(listings: [
            TraderListingDTO(itemId: "mat.river_pebble", sellPacketQty: 1, sellPacketSilver: 2,
                             buyPacketQty: 1, buyPacketSilver: 2)
        ])
        XCTAssertFalse(rules(bundle(trader: even)).contains("trader.arbitrage"))
    }

    /// Unequal packet sizes have to be compared per unit, not per packet:
    /// selling 10 for 20s while buying 1 for 3s is still a loss-free loop.
    func testTraderArbitrageComparesPerUnitNotPerPacket() {
        let bad = TraderFileDTO(listings: [
            TraderListingDTO(itemId: "mat.river_pebble", sellPacketQty: 10, sellPacketSilver: 20,
                             buyPacketQty: 1, buyPacketSilver: 1)
        ])
        XCTAssertTrue(rules(bundle(trader: bad)).contains("trader.arbitrage"))
    }

    func testTraderUnknownItemIsAnError() {
        let bad = TraderFileDTO(listings: [
            TraderListingDTO(itemId: "mat.nope", sellPacketQty: 1, sellPacketSilver: 1,
                             buyPacketQty: 1, buyPacketSilver: 2)
        ])
        XCTAssertTrue(rules(bundle(trader: bad)).contains("reference.item.unknown"))
    }

    // MARK: - Tavern

    func testTavernWagerTiersMustStrictlyAscend() {
        let bad = TavernFileDTO(food: [TavernFoodDTO(itemId: "food.baked_potato", priceSilver: 20)],
                                wagerTiers: [10, 25, 25])
        XCTAssertTrue(rules(bundle(tavern: bad)).contains("tiers.not_ascending"))
    }

    func testTavernFreeDishIsAnError() {
        let bad = TavernFileDTO(food: [TavernFoodDTO(itemId: "food.baked_potato", priceSilver: 0)],
                                wagerTiers: [10])
        XCTAssertTrue(rules(bundle(tavern: bad)).contains("tavern.price"))
    }

    // MARK: - Market / guild

    func testMarketWithNoLotsIsAnError() {
        XCTAssertTrue(rules(bundle(market: MarketFileDTO(listingFee: 5, maxActiveLots: 0)))
            .contains("market.no_lots"))
    }

    /// An inverted pair means no guild name is ever valid — the founding flow
    /// would reject every input with no way for the player to tell why.
    func testGuildInvertedNameBoundsAreAnError() {
        XCTAssertTrue(rules(bundle(guild: validGuild { $0["nameMaxLength"] = 2 }))
            .contains("guild.name_bounds"))
    }

    /// The leader is not counted in `maxOfficers`, so the deputies must leave
    /// room for them.
    func testGuildOfficersFillingTheCapIsAnError() {
        XCTAssertTrue(rules(bundle(guild: validGuild { $0["maxOfficers"] = 20 }))
            .contains("guild.officers_exceed_cap"))
    }

    func testWellFormedGuildIsClean() {
        XCTAssertTrue(rules(bundle(guild: validGuild())).isEmpty)
    }

    // MARK: - Arena leagues

    /// The table replaces a `switch`, so it has to carry what the compiler used
    /// to guarantee: total coverage and unambiguous ordering.
    func testArenaLeaguesMustStrictlyAscend() {
        let bad = validArena(leagues: [
            ArenaLeagueDTO(fromHonor: 1000, key: "arena.league.fighter"),
            ArenaLeagueDTO(fromHonor: 0, key: "arena.league.novice")
        ])
        XCTAssertTrue(rules(bundle(arena: bad)).contains("arena.leagues_not_ascending"))
    }

    /// A first band above the rating floor leaves live ratings with no league.
    func testArenaLeagueGapAboveTheFloorIsAnError() {
        let bad = validArena(leagues: [
            ArenaLeagueDTO(fromHonor: 50, key: "arena.league.novice")
        ], minHonor: 0)
        XCTAssertTrue(rules(bundle(arena: bad)).contains("arena.leagues_gap_at_floor"))
    }

    func testArenaEmptyLeagueTableIsAnError() {
        XCTAssertTrue(rules(bundle(arena: validArena(leagues: [])))
            .contains("arena.leagues_empty"))
    }

    /// The sweeper enforces `turnSeconds`; scanning less often than the deadline
    /// it polices means the clock silently stops meaning anything.
    func testArenaSweeperSlowerThanATurnIsAWarning() {
        let report = ContentValidator.validate(bundle(arena: validArena(sweepInterval: 60)))
        XCTAssertTrue(report.warnings.contains { $0.rule == "arena.sweep_slower_than_turn" })
        XCTAssertFalse(report.hasErrors)
    }

    func testWellFormedArenaIsClean() {
        XCTAssertTrue(rules(bundle(arena: validArena())).isEmpty)
    }

    // MARK: - Localization

    /// League keys are the only locale keys the content data names outright —
    /// every other content key is derived from an id — so a renamed band would
    /// print the raw stem to the player.
    func testUnlocalizedLeagueKeyIsAnError() {
        let locales = LocaleIndex(tables: [
            "en": ["arena.league.novice": "Novice"],
            "uk": ["arena.league.novice": "Новачок"]
        ])
        let bad = validArena(leagues: [
            ArenaLeagueDTO(fromHonor: 0, key: "arena.league.novice"),
            ArenaLeagueDTO(fromHonor: 1000, key: "arena.league.unnamed")
        ])
        let report = ContentValidator.validate(bundle(arena: bad), localizations: locales)
        XCTAssertTrue(report.errors.contains {
            $0.rule == "locale.key.missing" && $0.id == "arena.league.unnamed"
        })
    }
}
