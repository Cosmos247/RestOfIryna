//
//  EventTests.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 29.10.2026.
//
//  `events.json` against the shipped content (Велесова ніч,
//  `content/spec/event-veles-night.md`): the file is clean, every validator
//  rule fails on the one mistake it exists for, the maths draws the lines the
//  spec quotes, a fight's enemy id survives the round trip and `/reload`, and
//  the place on the board reads as Ukrainian and English write it.
//

import XCTest
@testable import ROIContent
@testable import ROISim

final class EventTests: XCTestCase {

    private static let contentRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("content/data")

    private static let localeRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("Localizations")

    private func shipped() throws -> ContentBundle {
        try ContentLoader.load(from: Self.contentRoot)
    }

    private func veles() throws -> EventDTO {
        try XCTUnwrap(try shipped().events?.events.first { $0.id == "veles_night_2026" })
    }

    /// The shipped bundle with only the events swapped.
    private func bundle(_ events: [EventDTO]) throws -> ContentBundle {
        let s = try shipped()
        return ContentBundle(
            manifest: s.manifest, items: s.items, enemies: s.enemies, enemyArchetypes: s.enemyArchetypes,
            recipes: s.recipes, rarities: s.rarities, budget: s.budget,
            starterRecipeIds: s.starterRecipeIds, weaponLadders: s.weaponLadders,
            bags: s.bags, estateUpgrades: s.estateUpgrades, plots: s.plots,
            events: EventFileDTO(events: events),
            tuning: s.tuning, contentHash: "test")
    }

    /// The events' own rules.
    private func rules(_ events: [EventDTO], locales: LocaleIndex? = nil) throws -> [String] {
        ContentValidator.validate(try bundle(events), localizations: locales).issues
            .map(\.rule)
            .filter { $0.hasPrefix("event.") || $0 == "identity.duplicate_id" }
    }

    /// `veles` with one field changed. Swift structs with `let`s are rebuilt.
    /// `artFrom: .some(nil)` drops the field, as a file without it would.
    private func variant(_ base: EventDTO, id: String? = nil, preludeAt: String? = nil, opensAt: String? = nil,
                         endsAt: String? = nil, artFrom: String?? = .none, entranceKm: Int? = nil,
                         creatures: [EventCreatureDTO]? = nil,
                         rooms: [EventRoomDTO]? = nil, notices: [EventNoticeDTO]? = nil,
                         rollovers: [EventRolloverDTO]? = nil, finds: [EventFindDTO]? = nil) -> EventDTO {
        EventDTO(id: id ?? base.id, preludeAt: preludeAt ?? base.preludeAt, opensAt: opensAt ?? base.opensAt,
                 endsAt: endsAt ?? base.endsAt, artFrom: artFrom ?? base.artFrom, entranceKm: entranceKm ?? base.entranceKm,
                 creatureLevelOffset: base.creatureLevelOffset, creatures: creatures ?? base.creatures,
                 rooms: rooms ?? base.rooms, notices: notices ?? base.notices, rollovers: rollovers ?? base.rollovers,
                 finds: finds ?? base.finds)
    }

    private func creature(_ base: EventCreatureDTO, archetype: String? = nil, xpReward: Int? = nil,
                          bloodDivisor: Int? = nil, weight: Int? = nil, hpScale: Double? = nil,
                          icon: String? = nil) -> EventCreatureDTO {
        EventCreatureDTO(id: base.id, icon: icon ?? base.icon, archetype: archetype ?? base.archetype,
                         hpScale: hpScale ?? base.hpScale, attackScale: base.attackScale,
                         xpReward: xpReward ?? base.xpReward, bloodDivisor: bloodDivisor ?? base.bloodDivisor,
                         weight: weight ?? base.weight)
    }

    // MARK: - The shipped file

    func testShippedEventIsCleanAndComplete() throws {
        let event = try veles()
        XCTAssertEqual(try rules([event]), [])
        let locales = try LocaleIndex(rootPath: Self.localeRoot.path)
        let report = ContentValidator.validate(try shipped(), localizations: locales)
        XCTAssertEqual(report.issues.filter { $0.file == "events.json" || ($0.id ?? "").hasPrefix("veles") }.map(\.description), [])
        // Every key the event prints exists in both locales.
        for required in EventKeys.required(for: event, at: 0) {
            XCTAssertEqual(locales.missing(required.key), [], required.key)
        }
    }

    func testShippedScheduleIsTheApprovedOne() throws {
        let event = try veles()
        let opens = try XCTUnwrap(EventClock.date(event.opensAt))
        let ends = try XCTUnwrap(EventClock.date(event.endsAt))
        // Sat 31.10 18:00 → Sun 01.11 18:00, Kyiv (UTC+2 after the clocks went back).
        XCTAssertEqual(opens, try XCTUnwrap(EventClock.date("2026-10-31T16:00:00Z")))
        XCTAssertEqual(ends.timeIntervalSince(opens), 24 * 3600)
        XCTAssertEqual(event.entranceKm, 5)
        // «prizes» (2026-11-01, the owner): the prize announcement, Sunday 10:00 until the close.
        XCTAssertEqual(event.notices.map(\.id), ["decree_1", "decree_2", "decree_3", "summons", "prizes", "finale"])
        let prizes = try XCTUnwrap(event.notices.first { $0.id == "prizes" })
        XCTAssertEqual(try XCTUnwrap(EventClock.date(prizes.at)), try XCTUnwrap(EventClock.date("2026-11-01T08:00:00Z")))
        XCTAssertEqual(prizes.until, event.endsAt)
        XCTAssertEqual(event.creatures.map(\.id), ["bat", "rat"])
        XCTAssertEqual(event.creatures.map(\.xpReward), [38, 57])
        XCTAssertEqual(event.creatures.map(\.bloodDivisor), [2, 1])
        XCTAssertEqual(event.creatures.map(\.weight), [1, 1])
        // «Велесовий гарбуз» (2026-10-30): one step in ten, a quarter of each back.
        XCTAssertEqual(event.findList, [EventFindDTO(id: "pumpkin", icon: "🎃", chance: 0.1, hpShare: 0.25, vigorShare: 0.25)])
    }

    /// The palace tells the story and hands the flask over (2026-10-30): the
    /// opening's one notice is the summons, every line of the palace and the
    /// flask is required, and the holiday day whose noon falls while the manor
    /// is open reads the reader's flask in both locales — the day before it
    /// has no flask to speak of.
    func testTheFlaskIsCollectedAtThePalace() throws {
        let event = try veles()
        let keys = EventKeys(event.id)
        let required = Set(EventKeys.required(for: event, at: 0).map(\.key))
        for key in [keys.palaceStory, keys.palaceScribe, keys.palaceTake, keys.flaskTaken, keys.entranceNoFlask,
                    keys.rolloverFlaskTaken, keys.rolloverFlaskWaiting] {
            XCTAssertTrue(required.contains(key), key)
        }
        let opens = try XCTUnwrap(EventClock.date(event.opensAt))
        let ends = try XCTUnwrap(EventClock.date(event.endsAt))
        XCTAssertEqual(event.notices.filter { EventClock.date($0.at) == opens }.map(\.id), ["summons"])

        let locales = try LocaleIndex(rootPath: Self.localeRoot.path)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "Europe/Kyiv"))
        for day in event.rollovers {
            let parts = day.day.split(separator: "-").compactMap { Int($0) }
            let noon = try XCTUnwrap(calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2], hour: 12)))
            let asksForFlask = opens <= noon && noon < ends
            for locale in LocaleIndex.locales {
                let text = try XCTUnwrap(locales.value(keys.rollover(day.id), locale: locale), "\(day.id) \(locale)")
                XCTAssertEqual(text.contains("%{flask}"), asksForFlask, "\(day.id) \(locale)")
            }
        }
        XCTAssertTrue(event.rollovers.contains { $0.id == "sunday" })
    }

    // MARK: - Every rule, failing on purpose

    func testBadIdIsRefused() throws {
        XCTAssertTrue(try rules([variant(veles(), id: "Велес")]).contains("event.bad_id"))
    }

    func testDuplicateEventIsRefused() throws {
        let event = try veles()
        XCTAssertTrue(try rules([event, event]).contains("identity.duplicate_id"))
    }

    func testUnparseableTimeIsRefused() throws {
        XCTAssertTrue(try rules([variant(veles(), opensAt: "31.10.2026 18:00")]).contains("event.bad_time"))
    }

    func testWindowOutOfOrderIsRefused() throws {
        let event = try veles()
        XCTAssertTrue(try rules([variant(event, endsAt: event.opensAt)]).contains("event.window_order"))
        XCTAssertTrue(try rules([variant(event, preludeAt: event.endsAt)]).contains("event.window_order"))
    }

    /// The pictures come at 12:00 on Saturday, three hours after the 09:00
    /// news (2026-10-31, the owner: «Картинки івентові повинні з'являтись не о
    /// 9, а о 12»).
    func testThePicturesComeAtNoonNotWithTheNews() throws {
        let event = try veles()
        let prelude = try XCTUnwrap(EventClock.date(event.preludeAt))
        let art = try XCTUnwrap(event.artFrom.flatMap(EventClock.date))
        XCTAssertEqual(art, try XCTUnwrap(EventClock.date("2026-10-31T10:00:00Z")), "12:00 Kyiv")
        XCTAssertEqual(art.timeIntervalSince(prelude), 3 * 3600)
    }

    func testArtOutsideTheWindowIsRefused() throws {
        let event = try veles()
        XCTAssertTrue(try rules([variant(event, artFrom: "2026-10-31T08:59:00+02:00")]).contains("event.art_window"),
                      "before the prelude")
        XCTAssertTrue(try rules([variant(event, artFrom: .some(event.endsAt))]).contains("event.art_window"),
                      "at the close: the pictures would never show")
        XCTAssertTrue(try rules([variant(event, artFrom: "31.10.2026 12:00")]).contains("event.bad_time"))
        // Without the field the pictures start with the prelude, and nothing complains.
        XCTAssertEqual(try rules([variant(event, artFrom: .some(nil))]), [])
        XCTAssertFalse(try rules([variant(event, artFrom: .some(event.preludeAt))]).contains("event.art_window"),
                       "the prelude itself is allowed")
    }

    func testEntranceAtZeroIsRefused() throws {
        XCTAssertTrue(try rules([variant(veles(), entranceKm: 0)]).contains("event.bad_entrance"))
    }

    func testCreatureRulesFail() throws {
        let event = try veles()
        let bat = event.creatures[0]
        XCTAssertTrue(try rules([variant(event, creatures: [])]).contains("event.no_creatures"))
        XCTAssertTrue(try rules([variant(event, creatures: [creature(bat, archetype: "ghost")])]).contains("event.unknown_archetype"))
        XCTAssertTrue(try rules([variant(event, creatures: [creature(bat, xpReward: -1)])]).contains("event.xp_negative"))
        XCTAssertTrue(try rules([variant(event, creatures: [creature(bat, bloodDivisor: 0)])]).contains("event.bad_blood_divisor"))
        XCTAssertTrue(try rules([variant(event, creatures: [creature(bat, weight: 0)])]).contains("event.weight_not_positive"))
        XCTAssertTrue(try rules([variant(event, creatures: [creature(bat, hpScale: 0)])]).contains("event.scale_not_positive"))
        XCTAssertTrue(try rules([variant(event, creatures: [creature(bat, icon: "")])]).contains("event.no_icon"))
    }

    func testRoomRulesFail() throws {
        let event = try veles()
        XCTAssertTrue(try rules([variant(event, rooms: [])]).contains("event.no_rooms"))
        XCTAssertTrue(try rules([variant(event, rooms: [EventRoomDTO(id: "yard", fromDepth: 2)])]).contains("event.rooms_start"))
        let unreachable = [EventRoomDTO(id: "yard", fromDepth: 1), EventRoomDTO(id: "cellar", fromDepth: 1)]
        XCTAssertTrue(try rules([variant(event, rooms: unreachable)]).contains("event.rooms_order"))
    }

    func testNoticeRulesFail() throws {
        let event = try veles()
        let decree = event.notices[0]
        let backwards = EventNoticeDTO(id: decree.id, at: decree.until, until: decree.at, kind: decree.kind, icon: decree.icon)
        XCTAssertTrue(try rules([variant(event, notices: [backwards])]).contains("event.notice_window"))
        let odd = EventNoticeDTO(id: decree.id, at: decree.at, until: decree.until, kind: "riddle", icon: decree.icon)
        XCTAssertTrue(try rules([variant(event, notices: [odd])]).contains("event.unknown_notice_kind"))
        let bare = EventNoticeDTO(id: decree.id, at: decree.at, until: decree.until, kind: decree.kind, icon: "")
        XCTAssertTrue(try rules([variant(event, notices: [bare])]).contains("event.no_icon"))
        // A finale before the close would announce a podium still moving.
        let early = EventNoticeDTO(id: "finale", at: event.opensAt, until: event.endsAt, kind: "finale", icon: "👑")
        XCTAssertTrue(try rules([variant(event, notices: [early])]).contains("event.finale_before_close"))
        let finale = try XCTUnwrap(event.notices.last)
        let twice = EventNoticeDTO(id: "finale_2", at: finale.at, until: finale.until, kind: "finale", icon: "👑")
        XCTAssertTrue(try rules([variant(event, notices: [finale, twice])]).contains("event.finale_twice"))
    }

    func testFindRulesFail() throws {
        let event = try veles()
        func find(_ id: String = "pumpkin", icon: String = "🎃", chance: Double = 0.1,
                  hp: Double = 0.25, vigor: Double = 0.25) -> EventFindDTO {
            EventFindDTO(id: id, icon: icon, chance: chance, hpShare: hp, vigorShare: vigor)
        }
        func refused(_ finds: [EventFindDTO], _ rule: String) throws -> Bool {
            try rules([variant(event, finds: finds)]).contains(rule)
        }
        XCTAssertEqual(try rules([variant(event, finds: [find()])]), [])
        XCTAssertEqual(try rules([variant(event, finds: [])]), [])
        XCTAssertTrue(try refused([find(chance: 0)], "event.find_chance"))
        XCTAssertTrue(try refused([find(chance: 1)], "event.find_chance"))
        XCTAssertTrue(try refused([find(hp: 1.5)], "event.find_share"))
        XCTAssertTrue(try refused([find(vigor: -0.1)], "event.find_share"))
        XCTAssertTrue(try refused([find(hp: 0, vigor: 0)], "event.find_restores_nothing"))
        XCTAssertTrue(try refused([find(chance: 0.6), find("candle", chance: 0.4)], "event.finds_crowd_out_creatures"))
        XCTAssertFalse(try refused([find(chance: 0.6), find("candle", chance: 0.3)], "event.finds_crowd_out_creatures"))
        XCTAssertTrue(try refused([find("Гарбуз")], "event.bad_id"))
        XCTAssertTrue(try refused([find(icon: "")], "event.no_icon"))
        XCTAssertTrue(try refused([find(), find()], "identity.duplicate_id"))
    }

    func testRolloverRulesFail() throws {
        let event = try veles()
        XCTAssertTrue(try rules([variant(event, rollovers: [EventRolloverDTO(day: "31.10.2026", id: "sat", icon: "🌑")])])
            .contains("event.bad_day"))
        XCTAssertTrue(try rules([variant(event, rollovers: [EventRolloverDTO(day: "2026-10-31", id: "sat", icon: "")])])
            .contains("event.no_icon"))
    }

    func testMissingTextIsRefused() throws {
        // A locale index with nothing in it: every key the event prints is missing.
        let empty = LocaleIndex(tables: ["en": [:], "uk": [:]])
        let issues = ContentValidator.validate(try bundle([try veles()]), localizations: empty).issues
            .filter { $0.rule == "locale.key.missing" && $0.file.hasSuffix(".json") && $0.message.contains("event.veles_night_2026") }
        XCTAssertFalse(issues.isEmpty)
    }

    // MARK: - The maths

    func testCreatureLevelFollowsThePlayerAndClamps() {
        XCTAssertEqual(EventMath.creatureLevel(playerLevel: 13, depth: 1, offset: -8, maxLevel: 40), 6)
        XCTAssertEqual(EventMath.creatureLevel(playerLevel: 1, depth: 1, offset: -8, maxLevel: 40), 1)
        XCTAssertEqual(EventMath.creatureLevel(playerLevel: 40, depth: 30, offset: -8, maxLevel: 40), 40)
    }

    func testBloodIsDepthOverTheDivisorRoundedUp() {
        // The bat pays half, rounded up, so its first depth still pays a drop.
        XCTAssertEqual((1...6).map { EventMath.blood(depth: $0, divisor: 2) }, [1, 1, 2, 2, 3, 3])
        XCTAssertEqual((1...6).map { EventMath.blood(depth: $0, divisor: 1) }, [1, 2, 3, 4, 5, 6])
    }

    /// The find owns the first `chance` of the roll; its restore is the share
    /// of the maximum rounded half up, capped at what the pool has room for.
    func testFindIsDrawnByChanceAndRestoresAShareOfTheMaximum() throws {
        let finds = try veles().findList
        XCTAssertEqual(EventMath.pickFind(finds, roll: 0)?.id, "pumpkin")
        XCTAssertEqual(EventMath.pickFind(finds, roll: 0.0999)?.id, "pumpkin")
        XCTAssertNil(EventMath.pickFind(finds, roll: 0.1))
        XCTAssertNil(EventMath.pickFind(finds, roll: 0.99))
        XCTAssertNil(EventMath.pickFind([], roll: 0))
        // The archer of the walkthrough: L13, ❤️ 82/204 🍖 83/165 → +51 / +41.
        XCTAssertEqual(EventMath.restore(share: 0.25, maximum: 204, current: 82), 51)
        XCTAssertEqual(EventMath.restore(share: 0.25, maximum: 165, current: 83), 41)
        XCTAssertEqual(EventMath.restore(share: 0.25, maximum: 166, current: 0), 42)
        XCTAssertEqual(EventMath.restore(share: 0.25, maximum: 165, current: 150), 15)
        XCTAssertEqual(EventMath.restore(share: 0.25, maximum: 165, current: 165), 0)
        XCTAssertEqual(EventMath.restore(share: 0.25, maximum: 165, current: 170), 0)
    }

    func testPickWalksTheWeights() throws {
        let event = try veles()
        XCTAssertEqual(EventMath.totalWeight(event.creatures), 2)
        XCTAssertEqual(EventMath.pick(event.creatures, roll: 0)?.id, "bat")
        XCTAssertEqual(EventMath.pick(event.creatures, roll: 1)?.id, "rat")
        XCTAssertNil(EventMath.pick(event.creatures, roll: 2))
    }

    /// The lines `content/spec/event-veles-night.md` §5 quotes, from the code
    /// that draws them.
    func testLinesMatchTheSpec() throws {
        let s = try shipped()
        let event = try veles()
        let tuning = try XCTUnwrap(s.tuning)
        let budget = try XCTUnwrap(s.budget)
        func line(_ id: String, _ level: Int) throws -> CombatantStats {
            try XCTUnwrap(EventMath.line(of: try XCTUnwrap(event.creature(id)), level: level,
                                         archetypes: s.enemyArchetypes, tuning: tuning, budget: budget, rarities: s.rarities))
        }
        let bat13 = try line("bat", 13)
        XCTAssertEqual([bat13.maxHP, bat13.attack, bat13.defense, bat13.crit, bat13.dodge], [114, 21, 21, 30, 34])
        let rat13 = try line("rat", 13)
        XCTAssertEqual([rat13.maxHP, rat13.attack, rat13.defense, rat13.crit, rat13.dodge], [212, 22, 38, 10, 5])
        let bat1 = try line("bat", 1)
        XCTAssertEqual([bat1.maxHP, bat1.attack], [43, 11])
        let rat19 = try line("rat", 19)
        XCTAssertEqual([rat19.maxHP, rat19.attack, rat19.defense], [280, 27, 50])
    }

    // MARK: - A fight's enemy id

    func testCreatureRefRoundTrips() {
        let ref = EventCreatureRef(eventId: "veles_night_2026", creatureId: "rat", level: 12)
        XCTAssertEqual(ref.enemyId, "event:veles_night_2026:rat:12")
        XCTAssertEqual(EventCreatureRef(enemyId: ref.enemyId), ref)
        XCTAssertNil(EventCreatureRef(enemyId: "enemy.wild_boar"))
        XCTAssertNil(EventCreatureRef(enemyId: "event:veles_night_2026:rat"))
        XCTAssertNil(EventCreatureRef(enemyId: "event:veles_night_2026:rat:0"))
        XCTAssertNil(EventCreatureRef(enemyId: "event::rat:3"))
    }

    func testReloadKeepsALiveManorFightAndRefusesToDropIt() throws {
        let s = try shipped()
        let fighting = LiveReferenceCheck.LiveIds(table: "exploration_state", column: "combat_enemy_id", kind: .enemy,
                                                  ids: ["event:veles_night_2026:bat:9", "enemy.wild_boar"])
        let inside = LiveReferenceCheck.LiveIds(table: "exploration_state", column: "manor_event_id", kind: .event,
                                                ids: ["veles_night_2026"])
        XCTAssertEqual(LiveReferenceCheck.dangling(in: s, live: [fighting, inside]), [])

        // The same fight against a bundle whose holiday no longer names the rat.
        let ghost = LiveReferenceCheck.LiveIds(table: "exploration_state", column: "combat_enemy_id", kind: .enemy,
                                               ids: ["event:veles_night_2026:ghost:9"])
        XCTAssertEqual(LiveReferenceCheck.dangling(in: s, live: [ghost]).map(\.id), ["event:veles_night_2026:ghost:9"])

        // A bundle without the holiday strands both.
        let without = try bundle([])
        XCTAssertEqual(LiveReferenceCheck.dangling(in: without, live: [fighting, inside]).map(\.id).sorted(),
                       ["event:veles_night_2026:bat:9", "veles_night_2026"])
    }

    // MARK: - Text helpers

    func testEveryRoomHasAnEncounterForEveryCreature() throws {
        let event = try veles()
        let keys = Set(EventKeys.required(for: event, at: 0).map(\.key))
        for creature in event.creatures {
            for room in event.rooms {
                XCTAssertTrue(keys.contains(EventKeys(event.id).encounter(creature.id, room: room.id)))
            }
        }
        XCTAssertEqual(event.room(forDepth: 1)?.id, "yard")
        XCTAssertEqual(event.room(forDepth: 6)?.id, "svitlytsia")
        XCTAssertEqual(event.room(forDepth: 9)?.id, "cellar")
        XCTAssertEqual(event.room(forDepth: 31)?.id, "water")
        XCTAssertNil(event.room(forDepth: 0))
    }

    func testPlaceOrdinals() {
        XCTAssertEqual([1, 2, 3, 4, 5, 6, 7, 8, 9, 10].map(PlaceOrdinal.ukrainian),
                       ["1-ше", "2-ге", "3-тє", "4-те", "5-те", "6-те", "7-ме", "8-ме", "9-те", "10-те"])
        XCTAssertEqual([11, 12, 13, 21, 23, 27, 40, 42, 100].map(PlaceOrdinal.ukrainian),
                       ["11-те", "12-те", "13-те", "21-ше", "23-тє", "27-ме", "40-ве", "42-ге", "100-те"])
        XCTAssertEqual([1, 2, 3, 4, 11, 12, 13, 21, 22, 23, 111].map(PlaceOrdinal.english),
                       ["1st", "2nd", "3rd", "4th", "11th", "12th", "13th", "21st", "22nd", "23rd", "111th"])
    }
}
