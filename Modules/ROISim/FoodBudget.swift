//
//  FoodBudget.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 31.08.2026.
//
//  What a day of play is worth in Vigor, now that nothing refills it on a clock.
//
//  Phase 8E removed passive Vigor regeneration. The pace section used to read
//  "one full pool plus 4× regen" straight off `progression.vigorPool`, which is
//  the one line of the balance report that stopped being true the moment the
//  trickle went away: the pool is a STOCK now, and the estate is the income.
//
//  So this file answers a different question — how much Vigor a TENDED estate
//  can put into the player's hands in a day — and it answers it by brute force
//  rather than by an assumed layout. With at most six slots and four producing
//  plot types there are 84 possible estates; enumerating them and cooking each
//  one out is cheaper than arguing about which mix is representative, and it
//  removes the last hand-picked constant from the pace number. What comes out
//  is the CEILING of a well-run estate, which is the right shape for a floor on
//  the day count.
//
//  Two things it deliberately does not count: foraging and monster meat (the
//  trail feeds the player too, and `ExplorationService` still keeps those pools
//  in Swift), and anything bought with silver. Both make the real day faster
//  than the printed one.
//

import Foundation
import ROIContent

public enum FoodBudget {

    /// Harvests a day the pace estimate assumes.
    ///
    /// The one number in this file that is not read from content, and it is an
    /// assumption about the PLAYER rather than about the game: three visits
    /// means morning, afternoon and evening. It matters only while it binds —
    /// a farm fills in five hours, so past roughly five visits a day the rate
    /// ceiling takes over and visiting more often buys nothing. The report
    /// prints it beside the numbers it produces.
    public static let defaultHarvestsPerDay: Double = 3

    /// One estate layout and what it is worth per day.
    public struct DailyFood: Sendable {
        /// Vigor a day of that estate's output converts into, once cooked.
        public let vigor: Double
        /// Portions eaten to spend it — the tap cost of the food loop, and the
        /// number that decides whether the loop is playable at all.
        public let portions: Double
        /// Plot types, one per slot.
        public let mix: [String]

        public static let none = DailyFood(vigor: 0, portions: 0, mix: [])
    }

    /// Highest estate tier a player of `playerLevel` can have reached, from the
    /// upgrade ladder's own level gates. Tier 1 needs nothing.
    public static func estateTier(playerLevel: Int, upgrades: EstateUpgradeFileDTO) -> Int {
        var tier = 1
        for step in upgrades.progression.sorted(by: { $0.toTier < $1.toTier })
        where playerLevel >= step.requiredPlayerLevel && step.toTier == tier + 1 {
            tier = step.toTier
        }
        return tier
    }

    /// Plot slots at an estate tier. Mirrors `PlotService.slotsForLevel`, off
    /// the same table in `estate_upgrades.json` — the reason that table became
    /// content in Phase 8E.
    public static func slots(tier: Int, upgrades: EstateUpgradeFileDTO) -> Int {
        let table = upgrades.plotSlotsByTier
        guard let last = table.last else { return 0 }
        let index = Swift.max(0, tier - 1)
        return index < table.count ? table[index] : last
    }

    /// Units a single plot yields in a day.
    ///
    /// Two ceilings, and which one binds is the whole shape of the mechanic: a
    /// plot fills to `capacity` and then STOPS, so a player who visits twice a
    /// day gets `2 × capacity`, while one who visits often enough is bounded by
    /// the rate instead. `harvestsPerDay` is the only number here that is not
    /// read from content, which is why the report prints it.
    static func unitsPerDay(rate: Int, capacity: Int, harvestsPerDay: Double,
                            intervalHours: Double) -> Double {
        guard intervalHours > 0 else { return 0 }
        let rateBound = Double(rate) * (24.0 / intervalHours)
        let harvestBound = harvestsPerDay * Double(capacity)
        return Swift.min(rateBound, harvestBound)
    }

    /// The best a tended estate of `slots` plots can do in a day.
    ///
    /// Enumerates every multiset of plot types, converts each one's output into
    /// Vigor — cooking through any recipe whose inputs the estate produces,
    /// richest dish first, then eating what is left raw — and keeps the best.
    public static func best(slots: Int, harvestsPerDay: Double, content: GameContent) -> DailyFood {
        guard slots > 0,
              let plotFile = content.plots,
              let intervalHours = content.tuning.map({ $0.time.gameTime.plotIntervalSeconds / 3600 }),
              intervalHours > 0
        else { return .none }

        let producing = plotFile.types.filter { $0.tuning != nil }
        guard !producing.isEmpty else { return .none }

        var bestFood = DailyFood.none
        for mix in multisets(of: producing.map(\.type), size: slots) {
            var stock: [String: Double] = [:]
            for type in mix {
                guard let tuning = producing.first(where: { $0.type == type })?.tuning else { continue }
                stock[tuning.producedItemId, default: 0] += unitsPerDay(
                    rate: tuning.ratePerInterval, capacity: tuning.capacity,
                    harvestsPerDay: harvestsPerDay, intervalHours: intervalHours)
                if let bonus = tuning.bonusOutput {
                    stock[bonus.producedItemId, default: 0] += unitsPerDay(
                        rate: bonus.ratePerInterval, capacity: bonus.capacity,
                        harvestsPerDay: harvestsPerDay, intervalHours: intervalHours)
                }
            }
            let food = cook(stock: stock, content: content)
            if food.vigor > bestFood.vigor {
                bestFood = DailyFood(vigor: food.vigor, portions: food.portions, mix: mix)
            }
        }
        return bestFood
    }

    /// Vigor restored by one unit of an item. Zero for anything that is not food.
    static func vigor(of itemId: String, content: GameContent) -> Int {
        content.itemsById[itemId]?.effects
            .filter { $0.kind == .restoreVigor }
            .reduce(0) { $0 + $1.amount } ?? 0
    }

    /// Turn a day's raw plot output into Vigor: cook what can be cooked, eat the
    /// rest raw. Greedy on Vigor per portion, which is also the tap-cheapest
    /// order — a richer dish is fewer buttons for the same Vigor.
    ///
    /// Greedy, and therefore exact only while no two cookable recipes compete
    /// for the same input. On the shipped bundle exactly one recipe is reachable
    /// from plot output at all (`baked_potato`, from a farm and a lumberyard),
    /// so the answer is optimal today. If a second one ever becomes reachable,
    /// this can under-count by preferring a rich dish that eats inputs two
    /// cheaper ones would have used better — it is an estimate, and it errs
    /// toward the slower pace, which is the safe direction for a floor.
    private static func cook(stock: [String: Double], content: GameContent) -> (vigor: Double, portions: Double) {
        var remaining = stock
        var vigorTotal = 0.0
        var portions = 0.0

        let usable = content.recipes
            .filter { vigor(of: $0.output.itemId, content: content) > 0 }
            .sorted { vigor(of: $0.output.itemId, content: content) > vigor(of: $1.output.itemId, content: content) }
        for recipe in usable {
            guard !recipe.inputs.isEmpty,
                  recipe.inputs.allSatisfy({ (remaining[$0.itemId] ?? 0) > 0 })
            else { continue }
            let batches = recipe.inputs
                .map { (remaining[$0.itemId] ?? 0) / Double(Swift.max(1, $0.quantity)) }
                .min() ?? 0
            guard batches > 0 else { continue }
            for input in recipe.inputs {
                remaining[input.itemId, default: 0] -= batches * Double(input.quantity)
            }
            let made = batches * Double(Swift.max(1, recipe.output.quantity))
            vigorTotal += made * Double(vigor(of: recipe.output.itemId, content: content))
            portions += made
        }
        for (itemId, units) in remaining where units > 0 {
            let each = vigor(of: itemId, content: content)
            guard each > 0 else { continue }
            vigorTotal += units * Double(each)
            portions += units
        }
        return (vigorTotal, portions)
    }

    /// Every multiset of `size` picks from `options`, order-insensitive — an
    /// estate of two farms is the same estate whichever slot they sit in.
    static func multisets(of options: [String], size: Int) -> [[String]] {
        guard size > 0 else { return [[]] }
        guard let first = options.first else { return [] }
        if options.count == 1 { return [Array(repeating: first, count: size)] }
        let rest = Array(options.dropFirst())
        var out: [[String]] = []
        for take in stride(from: size, through: 0, by: -1) {
            for tail in multisets(of: rest, size: size - take) {
                out.append(Array(repeating: first, count: take) + tail)
            }
        }
        return out
    }
}
