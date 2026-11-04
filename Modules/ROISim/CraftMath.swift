//
//  CraftMath.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 04.11.2026.
//
//  How many of one recipe a single tap can make, and where everything comes
//  from and goes (2026-11-04, the owner's pick: the kitchen cooks several at
//  once — «🍳 ×5» and «🍳 Усі (N)» in a column under «🍳 Готувати», no ×10,
//  the workshop left one at a time).
//
//  This is the arithmetic `CraftingService.craft` always used, made N times
//  larger, and the single craft is N = 1 of it — so the card's buttons, the
//  tap's re-check and the write cannot disagree:
//  - every input is drawn from the bag first and from the warehouse for the
//    rest;
//  - the room is measured AFTER the whole drain, in units, because the drain
//    frees space in whichever store it takes from;
//  - whole dishes go to the bag while they fit and the rest to the warehouse.
//    For one dish that is the rule as it stood: the bag if it fits, else the
//    warehouse, else no room at all;
//  - a developer's bag has no ceiling, exactly as `InventoryEntry.add` has
//    none, and the warehouse exempts nobody.
//
//  The bot asks it twice, like the bag's «Зʼїсти всі (N)» (`MealMath`): to draw
//  the buttons, and again on the tap, where a count the card no longer offers
//  redraws the card instead of cooking.
//

import Foundation

public enum CraftMath {

    /// The fixed batch beside «Усі (N)» (2026-11-04, the owner's pick; ×10 was
    /// declined). A step of the screen, not a balance number.
    public static let preset = 5

    /// One recipe input, and what the player holds of it in each store.
    public struct Input: Sendable, Equatable {
        public let need: Int
        public let bag: Int
        public let warehouse: Int

        public init(need: Int, bag: Int, warehouse: Int) {
            self.need = need
            self.bag = bag
            self.warehouse = warehouse
        }
    }

    /// Both stores as they stand before the craft, in units.
    public struct Room: Sendable, Equatable {
        public let bagUsed: Int
        public let bagCap: Int
        /// A developer account: `InventoryEntry.add` skips the bag's ceiling.
        public let bagUnbounded: Bool
        public let warehouseUsed: Int
        public let warehouseCap: Int

        public init(bagUsed: Int, bagCap: Int, bagUnbounded: Bool, warehouseUsed: Int, warehouseCap: Int) {
            self.bagUsed = bagUsed
            self.bagCap = bagCap
            self.bagUnbounded = bagUnbounded
            self.warehouseUsed = warehouseUsed
            self.warehouseCap = warehouseCap
        }
    }

    /// What a batch takes, and where its output lands.
    public struct Plan: Sendable, Equatable {
        public let times: Int
        /// Per input, in the recipe's order.
        public let fromBag: [Int]
        public let fromWarehouse: [Int]
        /// Units of the output, not dishes.
        public let toBag: Int
        public let toWarehouse: Int
    }

    public enum Refusal: Error, Sendable, Equatable {
        /// The inputs that fall short for this many, by index in the recipe.
        case short([Int])
        /// Neither store can take what is left over.
        case noRoom
    }

    /// `times` of the recipe, or why not. `times` must be at least 1.
    public static func plan(times: Int, inputs: [Input], outputQuantity: Int, room: Room) -> Result<Plan, Refusal> {
        precondition(times >= 1, "a batch makes at least one")
        let short = inputs.indices.filter { inputs[$0].bag + inputs[$0].warehouse < inputs[$0].need * times }
        guard short.isEmpty else { return .failure(.short(short)) }

        var fromBag: [Int] = []
        var fromWarehouse: [Int] = []
        for input in inputs {
            let total = input.need * times
            let bag = Swift.min(total, Swift.max(0, input.bag))
            fromBag.append(bag)
            fromWarehouse.append(total - bag)
        }

        let perDish = Swift.max(0, outputQuantity)
        let dishesToBag: Int
        if room.bagUnbounded || perDish == 0 {
            dishesToBag = times
        } else {
            let bagAfter = Swift.max(0, room.bagUsed - fromBag.reduce(0, +))
            dishesToBag = Swift.min(times, Swift.max(0, room.bagCap - bagAfter) / perDish)
        }
        let dishesToWarehouse = times - dishesToBag
        if dishesToWarehouse > 0 {
            let warehouseAfter = Swift.max(0, room.warehouseUsed - fromWarehouse.reduce(0, +))
            guard warehouseAfter + dishesToWarehouse * perDish <= room.warehouseCap else {
                return .failure(.noRoom)
            }
        }
        return .success(Plan(times: times, fromBag: fromBag, fromWarehouse: fromWarehouse,
                             toBag: dishesToBag * perDish, toWarehouse: dishesToWarehouse * perDish))
    }

    /// The largest batch `plan` accepts right now — 0 when not even one does.
    public static func limit(inputs: [Input], outputQuantity: Int, room: Room) -> Int {
        let bounds = inputs.filter { $0.need > 0 }
            .map { Swift.max(0, $0.bag + $0.warehouse) / $0.need }
        var times = bounds.min() ?? 1
        while times >= 1 {
            if case .success = plan(times: times, inputs: inputs, outputQuantity: outputQuantity, room: room) {
                return times
            }
            times -= 1
        }
        return 0
    }

    /// The buttons a card offers beside the single «🍳 Готувати».
    public struct Offer: Sendable, Equatable {
        /// «🍳 ×5» — when five fit and more than five do, so it never does what
        /// «Усі» does.
        public let preset: Int?
        /// «🍳 Усі (N)» — whenever two or more fit; one is the plain button.
        public let all: Int?

        public init(preset: Int?, all: Int?) {
            self.preset = preset
            self.all = all
        }

        public static let none = Offer(preset: nil, all: nil)
    }

    /// What the card offers, and what the tap asks again.
    ///
    /// Five is planned on its own rather than assumed from the limit: a store
    /// already over its ceiling (a bag tier that shrank under it) is helped by
    /// every input a batch drains, so seven can fit where five do not.
    public static func offer(inputs: [Input], outputQuantity: Int, room: Room) -> Offer {
        let most = limit(inputs: inputs, outputQuantity: outputQuantity, room: room)
        var fivePlanned = false
        if most > preset,
           case .success = plan(times: preset, inputs: inputs, outputQuantity: outputQuantity, room: room) {
            fivePlanned = true
        }
        return Offer(preset: fivePlanned ? preset : nil, all: most >= 2 ? most : nil)
    }
}
