//
//  EventRewardService.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 01.11.2026.
//
//  A holiday's prizes, handed out in person at the palace once its manor is
//  closed (2026-11-01, the owner — `content/spec/event-veles-night.md` §4.8).
//  What a reader is owed is `events.json` → `rewards` at the board's place
//  (`EventStandings.rank`, so ties share it); every flask with blood is owed the
//  items, and the places the list names add silver and zlatnyks.
//
//  Not by hand: zlatnyks would be safe in SQL, but silver is a cached `User`
//  field a player's next silver tap would write back, and a bag row inserted
//  by hand skips the bag's cap and is never announced. So the player collects
//  it, in ONE transaction:
//    - the marker (`event_blood.rewarded_at`), set only where it is still nil —
//      a second tap, or a tap racing the first, finds nothing owed;
//    - the zlatnyks, with their announced marker, so the watchman does not
//      announce what the receipt already names;
//    - the items into the BAG (the capital has no warehouse), after a fit check
//      in units with the writer's own developer bypass;
//    - the silver on a fresh row, adopted into the session after the commit,
//      as `ClassChangeService` does — the session's object is never half-paid.
//

import Fluent
import Foundation
import SQLKit

enum EventRewardService {

    /// A prize a reader is owed and has not collected.
    struct Owed: Sendable {
        let event: GameEvent
        let blood: Int
        let prize: EventPrize
    }

    enum Refusal: Error {
        /// Nothing is owed: before the close, an empty flask, a holiday with no
        /// prizes, or already collected.
        case nothingOwed
        /// The items do not fit the bag (units).
        case bagFull(need: Int, free: Int)
    }

    /// What the claim paid, for the receipt.
    struct Receipt: Sendable {
        let prize: EventPrize
        /// The balances after the claim; nil for a currency the prize did not pay.
        let zlatnyks: Int?
        let silver: Int?
    }

    /// The prize `user` is owed for `event` and has not collected — nil before
    /// the close, for an empty flask, a holiday with no prizes, or one collected.
    static func owed(_ user: User, event: GameEvent, now: Date = Date(), on db: any Database) async throws -> Owed? {
        guard event.isOver(at: now), let rewards = event.dto.rewards, let userId = user.id,
              let row = try await EventBlood.query(on: db)
                .filter(\.$user.$id == userId)
                .filter(\.$eventId == event.id)
                .first(),
              row.total > 0, row.rewardedAt == nil else { return nil }
        let standings = try await EventStandings.load(event, on: db)
        guard let prize = rewards.prize(place: standings.rank(of: row.total), blood: row.total) else { return nil }
        return Owed(event: event, blood: row.total, prize: prize)
    }

    /// Every holiday whose prize `user` is still owed, oldest first.
    static func allOwed(_ user: User, now: Date = Date(), on db: any Database) async throws -> [Owed] {
        var out: [Owed] = []
        for event in EventCatalog.all where event.isOver(at: now) && event.dto.rewards != nil {
            if let owed = try await owed(user, event: event, now: now, on: db) { out.append(owed) }
        }
        return out
    }

    /// The players owed a prize for `event` and not yet paid — the King's
    /// summons goes to them alone (`EventNoticeKind.rewards`).
    static func owedUserIds(_ event: GameEvent, on db: any Database) async throws -> Set<UUID> {
        guard event.dto.rewards != nil else { return [] }
        let rows = try await EventBlood.query(on: db)
            .filter(\.$eventId == event.id)
            .filter(\.$total > 0)
            .filter(\.$rewardedAt == nil)
            .all()
        return Set(rows.map { $0.$user.id })
    }

    /// Pays `session` the prize it is owed for `event`. Throws a `Refusal`
    /// before anything moves; a throw inside the transaction undoes all of it.
    static func claim(_ session: User, event: GameEvent, now: Date = Date(), on db: any Database) async throws -> Receipt {
        guard let owed = try await owed(session, event: event, now: now, on: db) else { throw Refusal.nothingOwed }
        let userId = try session.requireID()
        let prize = owed.prize

        // The bag's own arithmetic (`InventoryEntry.add`): units, and a
        // developer account always fits. Asked first for the modal; `add`
        // asks again inside the transaction and its throw undoes the rest.
        if !session.isDeveloper {
            let used = try await InventoryEntry.slotsUsed(for: session, on: db)
            let cap = InventoryEntry.slotCap(for: session)
            if used + prize.units > cap {
                throw Refusal.bagFull(need: prize.units, free: Swift.max(0, cap - used))
            }
        }

        let (zlatnyks, silver) = try await db.transaction { tx -> (Int?, Int?) in
            guard let sql = tx as? any SQLDatabase else { throw Refusal.nothingOwed }
            // The database is the judge: only a row still owed is marked, and a
            // second tap finds none.
            let marked = try await sql.raw("""
                UPDATE event_blood SET rewarded_at = \(bind: now)
                WHERE user_id = \(bind: userId) AND event_id = \(bind: event.id)
                  AND rewarded_at IS NULL AND total > 0
                RETURNING id
                """).first()
            guard marked != nil else { throw Refusal.nothingOwed }

            var zlatnyks: Int?
            if prize.zlatnyks > 0 {
                let row = try await sql.raw("""
                    UPDATE users SET zlatnyks = zlatnyks + \(bind: prize.zlatnyks),
                                     zlatnyks_announced = zlatnyks_announced + \(bind: prize.zlatnyks)
                    WHERE id = \(bind: userId)
                    RETURNING zlatnyks
                    """).first()
                zlatnyks = try row?.decode(column: "zlatnyks", as: Int.self)
            }

            for item in prize.items {
                try await InventoryEntry.add(item.itemId, quantity: item.count, to: session, on: tx)
            }

            var silver: Int?
            if prize.silver > 0 {
                // Cannot be missing: it is the session's own row.
                guard let row = try await User.find(userId, on: tx) else { throw Refusal.nothingOwed }
                row.silver += prize.silver
                try await row.save(on: tx)
                silver = row.silver
            }
            return (zlatnyks, silver)
        }
        if let silver {
            session.silver = silver
            await sessionCache.update(session)
        }
        return Receipt(prize: prize, zlatnyks: zlatnyks, silver: silver)
    }
}
