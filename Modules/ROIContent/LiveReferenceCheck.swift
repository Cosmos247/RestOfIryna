//
//  LiveReferenceCheck.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 30.08.2026.
//
//  The safety rule behind `/reload`: a content bundle may not be installed if
//  rows in the live database still point at ids it does not contain.
//
//  Every other check in the pipeline asks "is this bundle internally
//  consistent". Only this one asks "is it consistent with the game already in
//  progress". Drop `mat.iron` from `items.json` while four players are carrying
//  it and every one of their inventory rows becomes an item the game cannot
//  name, price, equip or sell — a corruption no validator working on the file
//  alone can see.
//
//  Deliberately NOT a stat check. Stat drift under a live fight is allowed and
//  clamped at rehydration (`min(persisted, newEnemy.hp)`); it is IDENTITY that
//  must not move.
//
//  The matching lives here, in the Foundation-only module, and the database
//  queries live in the main target. That split is not tidiness: the interesting
//  failure is checking one kind of id against another roster — item ids against
//  the bestiary would report every row as dangling, or none — and that mistake
//  is only catchable in a test if the matching can be tested without a database.
//

import Foundation

public enum LiveReferenceCheck {

    /// Which roster a column's ids must be found in.
    ///
    /// The last three were not in the original design list, which was written
    /// before stances, persisted quests and the fortune buff existed. All three
    /// fail SILENTLY rather than loudly, which is worse: a missing stance makes
    /// the player's Super do nothing, a missing quest leaves a job that cannot
    /// be rendered, and a missing fortune card evaporates a buff they paid for.
    public enum Kind: String, Sendable {
        case item
        case enemy
        case recipe
        case plotType
        case stance
        case quest
        case fortuneCard
    }

    /// Distinct ids one live column currently holds.
    public struct LiveIds: Sendable {
        public let table: String
        public let column: String
        public let kind: Kind
        public let ids: [String]

        public init(table: String, column: String, kind: Kind, ids: [String]) {
            self.table = table
            self.column = column
            self.kind = kind
            self.ids = ids
        }
    }

    /// One live row pointing at an id the candidate bundle does not carry.
    public struct Dangling: Sendable, Equatable, CustomStringConvertible {
        public let table: String
        public let column: String
        public let kind: Kind
        public let id: String

        public var description: String { "\(table).\(column) → \"\(id)\" (no such \(kind.rawValue))" }
    }

    /// Ids the running database references that `bundle` would drop.
    ///
    /// Empty means the swap is safe. Runs against the BUNDLE rather than a built
    /// snapshot because it sits between validate and build in the reload order:
    /// nothing is constructed until this has passed.
    public static func dangling(in bundle: ContentBundle, live: [LiveIds]) -> [Dangling] {
        let known: [Kind: Set<String>] = [
            .item: Set(bundle.items.map(\.id)),
            .enemy: Set(bundle.enemies.map(\.id)),
            .recipe: Set(bundle.recipes.map(\.id)),
            .plotType: Set(bundle.plots?.types.map(\.type) ?? []),
            .stance: Set(bundle.tuning?.combat.stances.byId.map(\.id) ?? []),
            .quest: Set(bundle.quests?.pools.flatMap { $0.quests.map(\.id) } ?? []),
            .fortuneCard: Set(bundle.fortune?.cards.map(\.id) ?? [])
        ]
        var problems: [Dangling] = []
        for column in live {
            let roster = known[column.kind] ?? []
            // Sorted so the report reads the same on every run — a reload that
            // is refused twice should say the same thing twice.
            for id in Set(column.ids).sorted() where !roster.contains(id) {
                problems.append(Dangling(table: column.table, column: column.column,
                                         kind: column.kind, id: id))
            }
        }
        return problems
    }
}
