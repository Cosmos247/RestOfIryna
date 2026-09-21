//
//  KingService.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 21.09.2026.
//
//  The King's decree chain: where a player stands, whether the open decree is
//  done, and what turning it in pays.
//
//  **Ten of the seventeen condition kinds are reads of state the game already
//  keeps** — depth banked, level, estate / weapon / bag tier, what is on the
//  warehouse shelf, whether a plot has been claimed, a technique learned or a
//  duel won. Those need no bookkeeping: the answer is recomputed every time the
//  screen is drawn, so a decree cannot drift out of step with the thing it is
//  about, and a player who satisfied it long ago simply finds it already done.
//
//  **The other seven are events nothing records.** Defeating a beast, selling
//  to the trader, turning in an NPC job, cooking, crafting, sending a passive
//  expedition and harvesting a plot all leave no readable trace afterwards —
//  `Plot.lastHarvestedAt` in particular starts at the moment the plot is
//  claimed and is reset by every harvest, so it can never answer "has this
//  player ever harvested". Those tick `KingProgress.counter` through
//  `record(_:for:on:)`, and **only when the OPEN decree is the one asking**:
//  nothing accumulates ahead of time, which is what keeps "defeat five beasts"
//  counting from the moment the decree opens rather than being backfilled by
//  the prologue dog.
//
//  **Turning in is all-or-nothing and the bag is checked first.** A reward
//  carrying food is predicted with the writer's own arithmetic —
//  `InventoryEntry.slotsUsed + quantity <= slotCap`, dev bypass included —
//  before a single field is mutated, because the drain-then-add shape with no
//  transaction is exactly what ate a player's ingredients in the workshop. A
//  refused turn-in leaves the decree open and says why.
//
//  Vigor is granted through the same clamp every other payout uses, and what
//  ACTUALLY landed is what the banner prints: `content/data/king.json` is
//  validated to never pay more than the pool at the decree's level can hold,
//  so the clamp should be a formality — but a screen that quotes the authored
//  number instead of the received one is the defect that rule exists for.
//

import Fluent
import Foundation

enum KingService {

    /// The seven things the chain cannot read off state. One funnel per event,
    /// called from the site the event already passes through.
    enum Event: String, Sendable {
        case beastKill
        case traderSale
        case questTurnedIn
        case dishCooked
        case crafted
        case passiveSent
        case plotHarvested

        /// The condition kind this event feeds. A `record` call ticks nothing
        /// unless the open decree asks for exactly this.
        var conditionKind: KingConditionDTO.Kind {
            switch self {
            case .beastKill:     return .beastKills
            case .traderSale:    return .sellToTrader
            case .questTurnedIn: return .finishNpcQuest
            case .dishCooked:    return .cookDish
            case .crafted:       return .craftAny
            case .passiveSent:   return .sendPassive
            case .plotHarvested: return .harvestPlot
            }
        }
    }

    /// One condition, resolved against the player, ready for `RequirementLine`.
    struct ConditionView: Sendable {
        let have: Int
        let need: Int
        /// Set for a warehouse material, so the renderer can use the item line
        /// with its icon and localized name instead of a bare label.
        let itemId: String?
        /// Locale key for everything that is not an item.
        let labelKey: String?
        var met: Bool { have >= need }
    }

    struct Standing: Sendable {
        let decree: KingDecreeDTO
        let index: Int
        let conditions: [ConditionView]
        var isComplete: Bool { conditions.allSatisfy(\.met) }
    }

    /// What a turn-in actually did. `vigorLanded` is what the pool accepted,
    /// never the authored number.
    struct Payout: Sendable {
        let decreeId: String
        let vigorLanded: Int
        let silver: Int
        let xp: Int
        let foodItemId: String?
        let foodQuantity: Int
        let leveledUp: Bool
        let newLevel: Int
    }

    enum ReportFailure: Error, Sendable {
        /// Conditions are not all met — the screen and the button disagreed,
        /// which a stale message in chat history can always produce.
        case notComplete
        /// The food reward will not fit. Carries what was refused so the
        /// modal can name it.
        case bagFull(itemId: String, quantity: Int)
        /// The chain is over.
        case finished
    }

    // MARK: - Where the player stands

    /// The progress row, created at decree 0 on first ask. Lazily, because a
    /// backfill would have to guess and every existing player simply starts at
    /// the top — the decrees they already satisfy turn in immediately.
    static func progressRow(for user: User, on db: any Database) async throws -> KingProgress {
        guard let userId = user.id else { throw ReportFailure.finished }
        if let row = try await KingProgress.query(on: db)
            .filter(\.$user.$id, .equal, userId)
            .first() {
            return row
        }
        let row = KingProgress(userID: userId)
        try await row.save(on: db)
        return row
    }

    /// The open decree and every condition resolved, or nil once the chain is
    /// walked out.
    static func standing(for user: User, on db: any Database) async throws -> Standing? {
        let chain = KingCatalog.chain
        let row = try await progressRow(for: user, on: db)
        guard row.decreeIndex >= 0, row.decreeIndex < chain.count else { return nil }
        let decree = chain[row.decreeIndex]

        var views: [ConditionView] = []
        for condition in decree.conditions {
            views += try await resolve(condition, user: user, counter: row.counter, on: db)
        }
        return Standing(decree: decree, index: row.decreeIndex, conditions: views)
    }

    // MARK: - Turning one in

    @discardableResult
    static func report(for user: User, on db: any Database) async throws -> Payout {
        guard let standing = try await standing(for: user, on: db) else {
            throw ReportFailure.finished
        }
        guard standing.isComplete else { throw ReportFailure.notComplete }
        let reward = standing.decree.reward

        // Predicted BEFORE anything is mutated, in the writer's own units.
        if let food = reward.food, food.quantity > 0 {
            guard try await foodWillFit(food, for: user, on: db) else {
                throw ReportFailure.bagFull(itemId: food.itemId, quantity: food.quantity)
            }
        }

        if let food = reward.food, food.quantity > 0 {
            try await InventoryEntry.add(food.itemId, quantity: food.quantity, to: user, on: db)
        }

        var vigorLanded = 0
        if reward.vigor > 0 {
            let before = user.vigor
            user.vigor = min(user.maxVigor, user.vigor + reward.vigor)
            vigorLanded = user.vigor - before
        }
        if reward.silver > 0 { user.silver += reward.silver }

        var leveledUp = false
        if reward.xp > 0 {
            leveledUp = user.grantXP(reward.xp).levelsGained > 0
        }

        let row = try await progressRow(for: user, on: db)
        row.advance()
        try await row.save(on: db)
        try await user.save(on: db)

        return Payout(decreeId: standing.decree.id,
                      vigorLanded: vigorLanded,
                      silver: reward.silver,
                      xp: reward.xp,
                      foodItemId: reward.food?.itemId,
                      foodQuantity: reward.food?.quantity ?? 0,
                      leveledUp: leveledUp,
                      newLevel: user.level)
    }

    // MARK: - The seven events

    /// Tick the open decree's counter, if this event is what it is waiting for.
    ///
    /// Silent and cheap on every other call: a player whose open decree reads
    /// state, or who has finished the chain, costs one indexed row read. It is
    /// deliberately fire-and-forget at the call sites — a decree failing to
    /// tick must never break the kill, the sale or the harvest it rode on.
    static func record(_ event: Event, amount: Int = 1, for user: User, on db: any Database) async throws {
        guard amount > 0 else { return }
        let chain = KingCatalog.chain
        let row = try await progressRow(for: user, on: db)
        guard row.decreeIndex >= 0, row.decreeIndex < chain.count else { return }
        let decree = chain[row.decreeIndex]
        guard let condition = decree.conditions.first(where: { $0.kind == event.conditionKind })
        else { return }

        let target = condition.target ?? 1
        guard row.counter < target else { return }

        // A TARGETED update, not `row.save`, and guarded by the index it was
        // read at. Fluent writes whole rows, and this runs from a background
        // task as well as a tap: the passive expedition reports its kills from
        // a detached sweep, which is not serialized against the player's own
        // taps the way `RouterStore` serializes those. A whole-row save from
        // there could put back a `decreeIndex` the player advanced a moment
        // earlier — handing them a decree they had already been paid for. The
        // `decree_index` filter makes that write simply match no row.
        try await KingProgress.query(on: db)
            .filter(\.$user.$id, .equal, row.$user.id)
            .filter(\.$decreeIndex, .equal, row.decreeIndex)
            .set(\.$counter, to: min(target, row.counter + amount))
            .update()
    }

    // MARK: - Resolving one condition

    private static func resolve(_ condition: KingConditionDTO, user: User, counter: Int,
                                on db: any Database) async throws -> [ConditionView] {
        func view(_ have: Int, _ need: Int, key: String) -> [ConditionView] {
            [ConditionView(have: have, need: need, itemId: nil, labelKey: key)]
        }
        let target = condition.target ?? 1
        let key = "king.cond.\(condition.kind.rawValue)"

        switch condition.kind {
        case .reachKm:
            return view(user.deepestKm, target, key: key)
        case .playerLevel:
            return view(user.level, target, key: key)
        case .estateTier:
            return view(user.estateLevel, target, key: key)
        case .bagTier:
            return view(user.bagTier, target, key: key)
        case .weaponTier:
            return view(try await equippedWeaponTier(for: user, on: db), target, key: key)

        case .arriveCapital:
            return view(user.location == TravelDestination.capital.rawValue ? 1 : 0, 1, key: key)

        case .winDuel:
            // A win is state, not an event: `ArenaProfile.wins` is a lifetime
            // tally that already exists, so this needs no hook and is true for
            // anyone who won a duel before the decree ever opened.
            let wins = try await ArenaProfile.query(on: db)
                .filter(\.$user.$id, .equal, user.id ?? UUID())
                .first()?.wins ?? 0
            return view(min(wins, 1), 1, key: key)

        case .learnTechnique:
            let known = try await LearnedTechnique.query(on: db)
                .filter(\.$user.$id, .equal, user.id ?? UUID())
                .count()
            return view(min(known, 1), 1, key: key)

        case .claimPlot:
            let query = Plot.query(on: db).filter(\.$user.$id, .equal, user.id ?? UUID())
            if let type = condition.plotType { query.filter(\.$plotType, .equal, type) }
            let claimed = try await query.count()
            // A typed plot names itself, so the line can say which one.
            let typedKey = condition.plotType.map { "king.cond.claim_plot.\($0)" } ?? key
            return view(min(claimed, 1), 1, key: typedKey)

        case .warehouseMaterials:
            var out: [ConditionView] = []
            for material in condition.materials {
                let held = try await WarehouseEntry.query(on: db)
                    .filter(\.$user.$id, .equal, user.id ?? UUID())
                    .filter(\.$itemId, .equal, material.itemId)
                    .first()?.quantity ?? 0
                out.append(ConditionView(have: held, need: material.quantity,
                                         itemId: material.itemId, labelKey: nil))
            }
            return out

        // The seven the counter answers for.
        case .beastKills, .sellToTrader, .finishNpcQuest, .cookDish,
             .craftAny, .sendPassive, .harvestPlot:
            return view(min(counter, target), target, key: key)
        }
    }

    /// Tier of the weapon actually in hand. 0 when nothing is equipped, which
    /// reads as "not yet" rather than as an error.
    private static func equippedWeaponTier(for user: User, on db: any Database) async throws -> Int {
        try await InventoryEntry.query(on: db)
            .filter(\.$user.$id, .equal, user.id ?? UUID())
            .filter(\.$equippedSlot, .equal, EquipmentSlot.mainHand.rawValue)
            .first()?.tier ?? 0
    }

    /// The same arithmetic `InventoryEntry.add` uses to decide, in the same
    /// units, with the same developer bypass. Predicting in rows instead of
    /// units is what let the workshop drain ingredients into a throw.
    private static func foodWillFit(_ food: KingFoodRewardDTO, for user: User,
                                    on db: any Database) async throws -> Bool {
        guard !user.isDeveloper else { return true }
        let used = try await InventoryEntry.slotsUsed(for: user, on: db)
        return used + food.quantity <= InventoryEntry.slotCap(for: user)
    }
}
