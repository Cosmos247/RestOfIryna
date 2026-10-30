//
//  EventCatalog.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 29.10.2026.
//
//  Façade over `events.json`: the holidays, their phases and the manor's
//  creatures (`content/spec/event-veles-night.md`). The times and the numbers
//  are data, so `/reload` moves them; the text is Lingo, under `EventKeys`.
//
//  A holiday runs in three phases, read off the clock and never stored:
//  - the prelude (`preludeAt` ..< `opensAt`): the decrees, and the capital
//    hears the King is ill;
//  - open (`opensAt` ..< `endsAt`): the manor stands at the entrance km, and
//    the palace tells the story and hands out the flask that lets a walk in;
//  - over (from `endsAt`): whoever is inside is walked out at their next tap,
//    the finale goes out, and the blood board keeps the result.
//
//  A creature's line depends on its level, and its level on the player, so
//  every level's line is solved ONCE here at install (`EventMath.line`) rather
//  than inside a fight.
//

import Foundation

public struct GameEvent: Sendable {
    public struct Notice: Sendable {
        public let dto: EventNoticeDTO
        public let at: Date
        public let until: Date
        public var kind: EventNoticeKind { EventNoticeKind(rawValue: dto.kind) ?? .plain }
    }

    public let dto: EventDTO
    public let prelude: Date
    public let opens: Date
    public let ends: Date
    public let notices: [Notice]
    /// creature id → its line at level `index + 1`, for every level the game has.
    private let lines: [String: [CombatantStats]]

    public var id: String { dto.id }
    public var keys: EventKeys { EventKeys(dto.id) }

    init(dto: EventDTO, archetypes: [EnemyArchetypeDTO], tuning: TuningBundleDTO,
         budget: BudgetTuningDTO, rarities: [RarityDTO]) throws {
        guard let prelude = EventClock.date(dto.preludeAt),
              let opens = EventClock.date(dto.opensAt),
              let ends = EventClock.date(dto.endsAt) else {
            throw ContentMappingError.invalidEvent("a time is not ISO 8601 with an offset", id: dto.id)
        }
        self.dto = dto
        self.prelude = prelude
        self.opens = opens
        self.ends = ends
        self.notices = try dto.notices.map { notice in
            guard let at = EventClock.date(notice.at), let until = EventClock.date(notice.until) else {
                throw ContentMappingError.invalidEvent("a time is not ISO 8601 with an offset", id: "\(dto.id).\(notice.id)")
            }
            return Notice(dto: notice, at: at, until: until)
        }
        var lines: [String: [CombatantStats]] = [:]
        let maxLevel = Swift.max(1, tuning.progression.maxLevel)
        for creature in dto.creatures {
            var byLevel: [CombatantStats] = []
            for level in 1...maxLevel {
                guard let line = EventMath.line(of: creature, level: level, archetypes: archetypes, tuning: tuning,
                                                budget: budget, rarities: rarities) else {
                    throw ContentMappingError.invalidEvent("no line for archetype \"\(creature.archetype)\" at level \(level)",
                                                           id: "\(dto.id).\(creature.id)")
                }
                byLevel.append(line)
            }
            lines[creature.id] = byLevel
        }
        self.lines = lines
    }

    // MARK: Phases

    /// The prelude or the manor open: the capital's lines and the decrees.
    public func isRunning(at now: Date) -> Bool { prelude <= now && now < ends }
    public func isOpen(at now: Date) -> Bool { opens <= now && now < ends }
    public func isOver(at now: Date) -> Bool { now >= ends }

    // MARK: The manor

    /// The level the depth-`depth` creature fights at for a player of `playerLevel`.
    public func creatureLevel(playerLevel: Int, depth: Int) -> Int {
        EventMath.creatureLevel(playerLevel: playerLevel, depth: depth, offset: dto.creatureLevelOffset,
                                maxLevel: Catalogs.current.tuningProgression.maxLevel)
    }

    /// The creature standing on a fight's enemy id, ready to fight: the
    /// solved line at its level, its own name, no loot and the depth `0…0`
    /// that keeps it out of the forest's roll and its estate scaling.
    public func enemy(for ref: EventCreatureRef) -> Enemy? {
        guard ref.eventId == dto.id, let creature = dto.creature(ref.creatureId),
              let byLevel = lines[creature.id], ref.level >= 1, ref.level <= byLevel.count else { return nil }
        let line = byLevel[ref.level - 1]
        return Enemy(id: ref.enemyId, nameKey: keys.creatureName(creature.id), tier: 1,
                     hp: line.maxHP, attack: line.attack, defense: line.defense,
                     crit: line.crit, dodge: line.dodge, accuracy: line.accuracy,
                     level: ref.level, archetype: EnemyArchetype(rawValue: creature.archetype) ?? .normal,
                     spawnWeight: 0, depthRange: 0...0, lootTable: [], icon: creature.icon,
                     xpReward: creature.xpReward)
    }

    /// The blood a kill of `creatureId` pays at `depth`.
    public func blood(creatureId: String, depth: Int) -> Int {
        EventMath.blood(depth: depth, divisor: dto.creature(creatureId)?.bloodDivisor ?? 1)
    }
}

// MARK: - Art

/// A screen that can wear a holiday's own art (2026-10-30, the owner: «Всі ці
/// картинки тільки на час івенту»). A slot is a SCREEN, not a file: the capital
/// map is one image in three files (the square and both streets), so its slot
/// covers all three.
public enum EventArtSlot: String, Sendable {
    /// The capital map — the square's welcome and both streets.
    case capital
    /// The palace card (its caption edits ride on whatever photo it was sent with).
    case palace
    /// The manor's first screen, as the player steps through the gate.
    case manor
}

extension GameEvent {
    /// `Assets/events/<event>/<slot>.jpg`, or nil when this holiday ships no
    /// file for the slot — the screen then keeps its usual art. Read at every
    /// send, so a file dropped on the machine shows without a restart (a NEW
    /// path is never cached; `PhotoCache`).
    public func artPath(_ slot: EventArtSlot) -> String? {
        let path = "\(projectPath)/Assets/events/\(id)/\(slot.rawValue).jpg"
        return FileManager.default.fileExists(atPath: path) ? path : nil
    }
}

public enum EventArt {
    /// What a town screen sends now: the running holiday's art for `slot` —
    /// from the prelude to the close, the window the capital's lines follow —
    /// or `usual` outside it, so after the close every screen has its own again.
    public static func path(_ slot: EventArtSlot, usual: String, now: Date = Date()) -> String {
        EventCatalog.running(at: now)?.artPath(slot) ?? usual
    }
}

public enum EventCatalog {
    public static var all: [GameEvent] { Catalogs.current.events }

    public static func find(_ id: String) -> GameEvent? {
        all.first { $0.id == id }
    }

    /// The holiday whose prelude or manor is on now. Two never overlap in
    /// practice; the first in the file wins if they ever do.
    public static func running(at now: Date = Date()) -> GameEvent? {
        all.first { $0.isRunning(at: now) }
    }

    public static func open(at now: Date = Date()) -> GameEvent? {
        all.first { $0.isOpen(at: now) }
    }

    /// The holiday whose blood board the journal shows: the latest one that
    /// has opened, kept after its close so the result stays readable.
    public static func latestOpened(at now: Date = Date()) -> GameEvent? {
        all.filter { $0.opens <= now }.max { $0.opens < $1.opens }
    }

    /// The holiday whose `day` is this game day, with the day's row — the 12:00
    /// notice reads its text.
    public static func rollover(onDay stamp: String) -> (GameEvent, EventRolloverDTO)? {
        for event in all {
            if let day = event.dto.rollovers.first(where: { $0.day == stamp }) { return (event, day) }
        }
        return nil
    }

    /// The creature a fight's enemy id names, or nil when it is not an event
    /// creature or no longer resolves. The one reader is
    /// `ExplorationState.combatEnemy(for:)`.
    public static func enemy(_ enemyId: String) -> Enemy? {
        guard let ref = EventCreatureRef(enemyId: enemyId), let event = find(ref.eventId) else { return nil }
        return event.enemy(for: ref)
    }
}
