//
//  HorseService.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 09.11.2026.
//
//  The Rysak («🐴 Рисак», `content/spec/spec-horse.md`): hired at the stable on
//  Поділ, it shortens every trip set out while the hire runs, unless the wagon
//  rides along (`WagonMath.crossing` is the one reading of a road). A hire moves
//  no goods, so all this service knows is whether one runs, how to buy one and
//  which ended hires the watchman has not announced yet.
//

import Fluent
import Foundation

public enum HorseService {

    public static func horse(for userId: UUID, on db: any Database) async throws -> Horse? {
        try await Horse.query(on: db).filter(\.$user.$id, .equal, userId).first()
    }

    /// A running hire as a screen sees it.
    public struct Status: Sendable {
        public let endsAt: Date

        public func secondsLeft(now: Date = Date()) -> Int { max(0, Int(endsAt.timeIntervalSince(now).rounded())) }
    }

    /// The hire while it runs; nil when there is none or it has run out.
    public static func status(for user: User, on db: any Database, now: Date = Date()) async throws -> Status? {
        guard let userId = user.id, let horse = try await horse(for: userId, on: db), horse.isRunning(at: now) else {
            return nil
        }
        return Status(endsAt: horse.endsAt)
    }

    // MARK: - Hiring

    /// Hire the Rysak for the length at `lengthIndex`. A hire that still runs
    /// grows by the length; one that ran out starts again from now. Refused
    /// away from the capital and on the road, so a hire never touches a trip
    /// already under way. The silver and the row are one transaction, on a
    /// user row loaded inside it. `seenStamp` is what the question saw
    /// (`WagonMath.hireStamp`), so a second tap spends nothing.
    public static func hire(lengthIndex: Int, seenStamp: Int, for user: User, on db: any Database,
                            now: Date = Date()) async throws -> WagonService.HireResult {
        guard user.location == TravelDestination.capital.rawValue,
              try await TravelState.current(for: user, on: db) == nil else { return .notInTown }
        guard let length = HorseCatalog.length(at: lengthIndex) else { return .unknownLength }
        let userId = try user.requireID()
        guard WagonMath.hireStamp(end: try await horse(for: userId, on: db)?.endsAt, now: now) == seenStamp else { return .stale }
        guard user.silver >= length.silver else { return .notEnoughSilver(have: user.silver, need: length.silver) }
        let seconds = WagonCatalog.seconds(of: length)

        let outcome = try await db.transaction { tx -> (end: Date, left: Int)? in
            guard let row = try await User.find(userId, on: tx), row.silver >= length.silver else { return nil }
            let horse = try await horse(for: userId, on: tx) ?? Horse(userID: userId, endsAt: now)
            let end = WagonMath.end(after: horse.id == nil ? nil : horse.endsAt, now: now, adding: seconds)
            horse.endsAt = end
            try await horse.save(on: tx)
            row.silver -= length.silver
            try await row.save(on: tx)
            return (end, row.silver)
        }
        guard let outcome else { return .notEnoughSilver(have: user.silver, need: length.silver) }
        user.silver = outcome.left
        try await user.saveAndCache(in: db)
        return .hired(endsAt: outcome.end, length: length, silverLeft: outcome.left)
    }

    // MARK: - The end of a hire

    public struct EndedHire: Sendable {
        public let telegramId: Int64
        public let locale: String
    }

    /// Hires that have run out and were not announced yet (§3.5). The marker is
    /// written here, before the watchman's push, so a crash between the two
    /// costs a notice rather than repeating one. A `save` writes only the marker:
    /// a hire bought meanwhile keeps its later end, and is armed by it. A row
    /// that will not save waits for the next sweep and costs the others nothing.
    public static func announceEnded(on db: any Database, now: Date = Date()) async throws -> [EndedHire] {
        let ended = try await Horse.query(on: db)
            .filter(\.$endsAt, .lessThanOrEqual, now)
            .with(\.$user)
            .all()
            .filter { $0.announcedEnd != $0.endsAt }
        var out: [EndedHire] = []
        for horse in ended {
            let user = await sessionCache.peek(telegramId: horse.user.telegramId) ?? horse.user
            horse.announcedEnd = horse.endsAt
            guard (try? await horse.save(on: db)) != nil else { continue }
            out.append(EndedHire(telegramId: user.telegramId, locale: user.locale))
        }
        return out
    }
}
