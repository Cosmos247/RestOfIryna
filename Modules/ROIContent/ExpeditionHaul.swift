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

    /// Silver found on the steps.
    public private(set) var silver: Int

    public init() {
        taken = [:]
        eaten = [:]
        silver = 0
    }

    /// Units of `itemId` that went into the bag. Zero and below are ignored —
    /// a find the bag refused outright reports `taken: 0`.
    public mutating func take(_ itemId: String, quantity: Int) {
        guard quantity > 0 else { return }
        taken[itemId, default: 0] += quantity
    }

    /// One unit of `itemId` eaten on the walk.
    public mutating func eat(_ itemId: String) {
        eaten[itemId, default: 0] += 1
    }

    public mutating func findSilver(_ amount: Int) {
        guard amount > 0 else { return }
        silver += amount
    }

    /// What came home: every item taken, less what was eaten of it, in item-id
    /// order — the passive report's order. An item eaten down to nothing is
    /// left out.
    public var brought: [(itemId: String, quantity: Int)] {
        taken.keys.sorted().compactMap { id in
            let net = taken[id, default: 0] - eaten[id, default: 0]
            return net > 0 ? (id, net) : nil
        }
    }

    /// Nothing to name: no item came home and no silver was found.
    public var isEmptyHanded: Bool {
        brought.isEmpty && silver == 0
    }
}
