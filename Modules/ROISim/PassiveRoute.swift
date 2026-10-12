//
//  PassiveRoute.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 12.10.2026.
//
//  The governor's walk on a passive expedition, as rules (2026-10-12).
//
//  Until then the passive run walked only deeper — km 1 → 17 on the
//  90-minute choice — and was at the manor the moment its last step ended:
//  the road back cost no time, no Vigor and no fights, and the 17 km nobody
//  walked back from were banked on the depth board. It also ran one step
//  short of its label, its step count floored out of two timestamps (89.99
//  minutes made 17 steps).
//
//  Now the run is there and back in the same time: half the strides out, half
//  home, and the last stride is the manor door, with no event, like the active
//  walk's last step. He turns at the planned depth, or earlier — below a
//  share of his HP, or when his Vigor only covers the road home and the bag
//  holds nothing to eat. He eats only when he must, the smallest portion
//  first. All of it is the owner's, chosen over four quizzes; the measurement
//  behind each choice is in `.memory/rebalance.md`.
//
//  Pure on purpose: `PassiveExpeditionService` asks these, and the tests pin
//  them, so the rules cannot drift between the runner and what was approved.
//

import Foundation

public enum PassiveRoute {

    // MARK: - The route

    /// Strides a run buys: its AUTHORED minutes over the minutes one stride
    /// takes, in integers. Never derived from timestamps — `created_at` is
    /// stamped milliseconds after the end time is computed, and the floor of
    /// 89.99 minutes is the stride the 90-minute run used to lose.
    public static func strides(minutes: Int, unitsPerStep: Int) -> Int {
        guard unitsPerStep > 0 else { return 0 }
        return minutes / unitsPerStep
    }

    /// The planned turnaround: half the strides out, the other half home —
    /// `depth − 1` kilometres back and the door.
    public static func depth(strides: Int) -> Int {
        strides / 2
    }

    /// Strides from `km` to the door on the way home: `km − 1` kilometres
    /// walked and the door, which rolls nothing.
    public static func stridesHome(fromKm km: Int) -> Int {
        max(0, km)
    }

    // MARK: - When he turns

    /// The Vigor the road home is held to: one walk a kilometre, the door
    /// counted too. The door is free, so the reserve keeps one step in hand.
    public static func roadHome(fromKm km: Int, walkCost: Int) -> Int {
        walkCost * max(0, km)
    }

    /// On the way out: the Vigor left only covers the road home. He eats then,
    /// and turns if there is nothing to eat.
    public static func onlyRoadHomeLeft(vigor: Int, km: Int, walkCost: Int) -> Bool {
        vigor <= roadHome(fromKm: km, walkCost: walkCost)
    }

    /// On the way out: wounded below `share` of his HP. At any depth — a
    /// stricter share for deeper ground was shown and declined.
    public static func woundedEnough(hp: Int, maxHP: Int, share: Double) -> Bool {
        Double(hp) < share * Double(maxHP)
    }

    // MARK: - When and what he eats

    /// Before a step that would leave him at 0 Vigor. A fight that begins at 0
    /// is fought at the starvation penalty, and the step after it starves.
    public static func mustEatBeforeStep(vigor: Int, walkCost: Int) -> Bool {
        vigor <= walkCost
    }

    /// One kind of food in the bag, as the choice sees it.
    public struct Ration: Sendable, Equatable {
        public let itemId: String
        public let vigor: Int
        public let hp: Int
        /// A taken delivery job waits for this item.
        public let wanted: Bool

        public init(itemId: String, vigor: Int, hp: Int, wanted: Bool) {
            self.itemId = itemId
            self.vigor = vigor
            self.hp = hp
            self.wanted = wanted
        }
    }

    /// The next portion: the smallest Vigor first, which is also the cheapest
    /// (a dish restores the buy-price of its ingredients), so the dishes the
    /// player cooked go last and nothing overshoots the pool; what a taken job
    /// waits for after everything else; then the smaller HP restore, then the
    /// id, so the choice never depends on the order the bag was read in. Nil
    /// when nothing in the bag restores Vigor — a potion heals but feeds
    /// nobody.
    public static func nextRation(_ rations: [Ration]) -> Ration? {
        rations.filter { $0.vigor > 0 }.min { a, b in
            (a.wanted ? 1 : 0, a.vigor, a.hp, a.itemId) < (b.wanted ? 1 : 0, b.vigor, b.hp, b.itemId)
        }
    }
}
