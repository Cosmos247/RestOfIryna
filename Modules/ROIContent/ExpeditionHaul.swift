//
//  ExpeditionHaul.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 23.10.2026.
//
//  What an active walk brings home, named at the manor door (2026-10-23).
//
//  The passive report always said «Принесено:»; the active walk said only
//  «🏰 Ви повертаєтеся додому…», so a player who walked ten km had to scroll
//  the steps to know what the trip was worth. The owner asked for the same
//  list at the door, and picked its rules over two quizzes:
//  - a find eaten on the road was not brought home — the passive report's rule,
//    counted by item, so a berry from home eaten on the road nets the same way;
//  - silver found on the steps gets its own 🪙 line under the list;
//  - what stayed in the forest (a full bag) is NOT listed — every step already
//    said so, and the passive report keeps its own wording.
//  - (2026-11-01) what was thrown away on the walk was not brought home either —
//    the trail bag's card can discard, on the owner's word, and the door nets it
//    out by item exactly as it nets out a meal.
//
//  Pure Foundation, so the arithmetic is pinned by tests; the expedition row
//  carries it as JSON (`exploration_state.haul`).
//

import Foundation

public struct ExpeditionHaul: Codable, Sendable, Equatable {

    /// Units that went into the bag, by item id — finds on the steps and drops
    /// from won fights. What did not fit is never counted.
    public private(set) var taken: [String: Int]

    /// Units eaten from the bag on the walk, by item id — whether found on this
    /// walk or carried from home.
    public private(set) var eaten: [String: Int]

    /// Units thrown away from the trail bag on the walk, by item id (2026-11-01).
    /// Absent from a haul written before it — decoded as none.
    public private(set) var dropped: [String: Int]

    /// Silver found on the steps.
    public private(set) var silver: Int

    public init() {
        taken = [:]
        eaten = [:]
        dropped = [:]
        silver = 0
    }

    private enum CodingKeys: String, CodingKey {
        case taken, eaten, dropped, silver
    }

    /// A walk begun before 2026-11-01 carries a haul with no `dropped`, and a
    /// restart must not strand it: the key is optional on the way in.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        taken = try container.decode([String: Int].self, forKey: .taken)
        eaten = try container.decode([String: Int].self, forKey: .eaten)
        dropped = try container.decodeIfPresent([String: Int].self, forKey: .dropped) ?? [:]
        silver = try container.decode(Int.self, forKey: .silver)
    }

    /// Units of `itemId` that went into the bag. Zero and below are ignored —
    /// a find the bag refused outright reports `taken: 0`.
    public mutating func take(_ itemId: String, quantity: Int) {
        guard quantity > 0 else { return }
        taken[itemId, default: 0] += quantity
    }

    /// Units of `itemId` eaten on the walk — one per tap of «🍴 Зʼїсти», N for
    /// the card's «До повної снаги (N)» / «Зʼїсти всі (N)».
    public mutating func eat(_ itemId: String, quantity: Int = 1) {
        guard quantity > 0 else { return }
        eaten[itemId, default: 0] += quantity
    }

    /// Units of `itemId` thrown away from the trail bag on the walk.
    public mutating func drop(_ itemId: String, quantity: Int) {
        guard quantity > 0 else { return }
        dropped[itemId, default: 0] += quantity
    }

    public mutating func findSilver(_ amount: Int) {
        guard amount > 0 else { return }
        silver += amount
    }

    /// What came home: every item taken, less what was eaten or thrown away of
    /// it, in item-id order — the passive report's order. An item eaten or
    /// thrown down to nothing is left out.
    public var brought: [(itemId: String, quantity: Int)] {
        taken.keys.sorted().compactMap { id in
            let net = taken[id, default: 0] - eaten[id, default: 0] - dropped[id, default: 0]
            return net > 0 ? (id, net) : nil
        }
    }

    /// Nothing to name: no item came home and no silver was found.
    public var isEmptyHanded: Bool {
        brought.isEmpty && silver == 0
    }
}
