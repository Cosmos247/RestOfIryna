//
//  EventDTO.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 29.10.2026.
//
//  `events.json` — a holiday the game runs for a window of days (schema v29,
//  2026-10-29). The first is Велесова ніч (`content/spec/event-veles-night.md`):
//  a prelude of strange decrees, then an abandoned manor at a kilometre of the
//  forest that is left only by dying, whose creatures pay blood into a flask
//  the death does not take.
//
//  The WHEN is data, so `/reload` can move a notice or the close; the WHAT the
//  player reads is Lingo, under keys derived from the ids below, so new text
//  still needs a restart. What a creature is — an archetype's contract at a
//  level, scaled — is data too; the maths that turns it into a stat line is
//  `EventMath` in ROISim.
//

import Foundation

public struct EventFileDTO: Codable, Sendable, Equatable {
    public let events: [EventDTO]

    public init(events: [EventDTO]) {
        self.events = events
    }
}

public struct EventDTO: Codable, Sendable, Equatable {
    /// Stable: the blood table, the notice log and a manor descent store it,
    /// and every `event.<id>.*` locale key is built from it.
    public let id: String
    /// ISO 8601 with an offset. The capital hears of the King's illness from
    /// here; the manor is not open yet.
    public let preludeAt: String
    /// The manor opens.
    public let opensAt: String
    /// The manor closes; whoever is inside is walked out.
    public let endsAt: String
    /// When the capital starts to wear the holiday — its own pictures, the
    /// palace's empty throne, the square's welcome (2026-10-31, the owner: at
    /// 12:00, not with the 09:00 decree). Optional in the file — absent, from
    /// `preludeAt`; it always ends at `endsAt`.
    public let artFrom: String?
    /// The km of an active walk where the manor stands.
    public let entranceKm: Int
    /// The depth-`d` creature is level `max(1, playerLevel + offset + d)`.
    public let creatureLevelOffset: Int
    /// Drawn by `weight` at every depth.
    public let creatures: [EventCreatureDTO]
    /// The manor's rooms by depth; the first starts at depth 1.
    public let rooms: [EventRoomDTO]
    /// One-off messages to every player, in send order.
    public let notices: [EventNoticeDTO]
    /// Game days whose 12:00 «new day» notice reads the event's own text.
    public let rollovers: [EventRolloverDTO]
    /// What a step deeper can turn up in place of a creature (2026-10-30: the
    /// pumpkin). Optional in the file, so a holiday without one says nothing.
    public let finds: [EventFindDTO]?
    /// What the holiday pays once it is over (2026-11-01, the owner), collected
    /// in person at the palace. Optional in the file: absent, it pays nothing.
    public let rewards: EventRewardsDTO?

    public init(id: String, preludeAt: String, opensAt: String, endsAt: String, artFrom: String? = nil,
                entranceKm: Int, creatureLevelOffset: Int, creatures: [EventCreatureDTO], rooms: [EventRoomDTO],
                notices: [EventNoticeDTO], rollovers: [EventRolloverDTO], finds: [EventFindDTO]? = nil,
                rewards: EventRewardsDTO? = nil) {
        self.id = id
        self.preludeAt = preludeAt
        self.opensAt = opensAt
        self.endsAt = endsAt
        self.artFrom = artFrom
        self.entranceKm = entranceKm
        self.creatureLevelOffset = creatureLevelOffset
        self.creatures = creatures
        self.rooms = rooms
        self.notices = notices
        self.rollovers = rollovers
        self.finds = finds
        self.rewards = rewards
    }

    /// The finds, none when the file names none.
    public var findList: [EventFindDTO] { finds ?? [] }

    /// The room a depth belongs to: the last one starting at or above it.
    /// Nil only below depth 1, which no descent reaches.
    public func room(forDepth depth: Int) -> EventRoomDTO? {
        rooms.last { $0.fromDepth <= depth }
    }

    public func creature(_ id: String) -> EventCreatureDTO? {
        creatures.first { $0.id == id }
    }
}

public struct EventCreatureDTO: Codable, Sendable, Equatable {
    /// `bat`, `rat`: part of the fight's enemy id (`EventCreatureRef`) and of
    /// its locale keys.
    public let id: String
    public let icon: String
    /// An enemy archetype id (`enemies.json` → `archetypes`) whose contract at
    /// the creature's level is its stat line.
    public let archetype: String
    public let hpScale: Double
    public let attackScale: Double
    /// XP for a kill, before the level-gap scaling every kill goes through.
    public let xpReward: Int
    /// Blood for a kill at depth `d`: `⌈d / bloodDivisor⌉`.
    public let bloodDivisor: Int
    /// Relative chance at a depth.
    public let weight: Int

    public init(id: String, icon: String, archetype: String, hpScale: Double, attackScale: Double,
                xpReward: Int, bloodDivisor: Int, weight: Int) {
        self.id = id
        self.icon = icon
        self.archetype = archetype
        self.hpScale = hpScale
        self.attackScale = attackScale
        self.xpReward = xpReward
        self.bloodDivisor = bloodDivisor
        self.weight = weight
    }
}

/// Something a step deeper finds instead of a creature (2026-10-30, the owner:
/// «Велесовий гарбуз», 10% of steps, a quarter of the HP and the Vigor back at
/// once). The step still goes one depth deeper; there is no fight and no blood
/// at that depth. Its text is `EventKeys.findText`.
public struct EventFindDTO: Codable, Sendable, Equatable {
    /// `pumpkin`: part of its locale key.
    public let id: String
    /// Prepended in code, never in the template.
    public let icon: String
    /// Its chance on a step deeper, drawn before the creatures: 0.1 is one step
    /// in ten. The finds together leave the creatures most of the steps.
    public let chance: Double
    /// The share of the maximum HP restored at once (`effectiveMaxHp`, armour
    /// included), and of the Vigor pool — each capped at the maximum.
    public let hpShare: Double
    public let vigorShare: Double

    public init(id: String, icon: String, chance: Double, hpShare: Double, vigorShare: Double) {
        self.id = id
        self.icon = icon
        self.chance = chance
        self.hpShare = hpShare
        self.vigorShare = vigorShare
    }
}

public struct EventRoomDTO: Codable, Sendable, Equatable {
    public let id: String
    public let fromDepth: Int

    public init(id: String, fromDepth: Int) {
        self.id = id
        self.fromDepth = fromDepth
    }
}

public struct EventNoticeDTO: Codable, Sendable, Equatable {
    public let id: String
    /// When it goes out.
    public let at: String
    /// A player first seen after this never gets it: a decree is news only
    /// until the reveal explains it.
    public let until: String
    /// An `EventNoticeKind` raw value.
    public let kind: String
    /// Prepended in code, never in the template: Lingo drops a placeholder
    /// that follows a multi-unit emoji (`.memory/localization.md`).
    public let icon: String

    public init(id: String, at: String, until: String, kind: String, icon: String) {
        self.id = id
        self.at = at
        self.until = until
        self.kind = kind
        self.icon = icon
    }
}

/// What a notice's text is built from. A kind is code.
public enum EventNoticeKind: String, CaseIterable, Sendable {
    /// One locale string, the same for everyone.
    case plain
    /// The podium of the blood board and the reader's own line.
    case finale
    /// One locale string, sent only to a reader owed a prize not yet collected
    /// (2026-11-01: the King's summons to the palace).
    case rewards
}

// MARK: - The prizes

/// A holiday's prizes (2026-11-01, Велесова ніч — `content/spec/event-veles-night.md`
/// §4.8). Owed to every flask with blood once the manor is closed, and handed
/// out in person at the palace (`EventRewardService`): the same items to every
/// participant, and silver and zlatnyks by the board's place, ties sharing it.
public struct EventRewardsDTO: Codable, Sendable, Equatable {
    /// To every reader who brought at least one drop.
    public let everyone: [EventRewardItemDTO]
    /// By place, the first first: `places[i].place` is `i + 1`. A place past
    /// the end of the list is paid `everyone` alone.
    public let places: [EventPlaceRewardDTO]

    public init(everyone: [EventRewardItemDTO], places: [EventPlaceRewardDTO]) {
        self.everyone = everyone
        self.places = places
    }

    /// What a flask of `blood` standing at `place` (competition rank, so ties
    /// share it) is owed — nil for an empty flask, which is not a participant.
    public func prize(place: Int, blood: Int) -> EventPrize? {
        guard blood > 0, place >= 1 else { return nil }
        let row = places.first { $0.place == place }
        return EventPrize(place: place, silver: row?.silver ?? 0, zlatnyks: row?.zlatnyks ?? 0, items: everyone)
    }
}

public struct EventRewardItemDTO: Codable, Sendable, Equatable {
    public let itemId: String
    public let count: Int

    public init(itemId: String, count: Int) {
        self.itemId = itemId
        self.count = count
    }
}

public struct EventPlaceRewardDTO: Codable, Sendable, Equatable {
    public let place: Int
    public let silver: Int
    public let zlatnyks: Int

    public init(place: Int, silver: Int, zlatnyks: Int) {
        self.place = place
        self.silver = silver
        self.zlatnyks = zlatnyks
    }
}

/// One reader's prize, as `EventRewardsDTO.prize` resolves it.
public struct EventPrize: Sendable, Equatable {
    public let place: Int
    public let silver: Int
    public let zlatnyks: Int
    public let items: [EventRewardItemDTO]

    public init(place: Int, silver: Int, zlatnyks: Int, items: [EventRewardItemDTO]) {
        self.place = place
        self.silver = silver
        self.zlatnyks = zlatnyks
        self.items = items
    }

    /// The bag units the items take — what the fit check counts.
    public var units: Int { items.reduce(0) { $0 + Swift.max(0, $1.count) } }
}

public struct EventRolloverDTO: Codable, Sendable, Equatable {
    /// The game day's stamp, `yyyy-MM-dd` (`GameDay.stamp`).
    public let day: String
    public let id: String
    /// In place of the ordinary notice's 📜, prepended in code.
    public let icon: String

    public init(day: String, id: String, icon: String) {
        self.day = day
        self.id = id
        self.icon = icon
    }
}

// MARK: - Times

/// Every time in `events.json` is ISO 8601 with its offset, so the file says
/// what the owner said («у суботу о 18:00 за Києвом») without a timezone table.
public enum EventClock {
    public static func date(_ text: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: text)
    }
}

// MARK: - A creature in a fight

/// The id an event creature fights under: `event:<event>:<creature>:<level>`.
///
/// A fight keeps only its creature's id and HP on the expedition row
/// (`ExplorationState.combatEnemyId`), and an event creature's line depends on
/// its level, which therefore rides in the id. Parsed by the one funnel that
/// reads a fight back (`ExplorationState.combatEnemy(for:)`) and by the live
/// reference check, which must not mistake it for a creature `/reload` dropped.
public struct EventCreatureRef: Sendable, Equatable {
    public static let prefix = "event:"

    public let eventId: String
    public let creatureId: String
    public let level: Int

    public init(eventId: String, creatureId: String, level: Int) {
        self.eventId = eventId
        self.creatureId = creatureId
        self.level = level
    }

    public init?(enemyId: String) {
        guard enemyId.hasPrefix(Self.prefix) else { return nil }
        let parts = enemyId.dropFirst(Self.prefix.count).split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count == 3, !parts[0].isEmpty, !parts[1].isEmpty,
              let level = Int(parts[2]), level >= 1 else { return nil }
        self.init(eventId: String(parts[0]), creatureId: String(parts[1]), level: level)
    }

    public var enemyId: String { "\(Self.prefix)\(eventId):\(creatureId):\(level)" }
}
