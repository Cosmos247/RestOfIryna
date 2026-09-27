//
//  CraftingService.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 01.05.2026.
//
//  Pure crafting service — drains recipe inputs from the player's combined
//  inventory + warehouse pool and deposits the output into the inventory.
//
//  Source-pool order:
//    1. Inventory rows (frees backpack slots that the output may need)
//    2. Warehouse rows (the bulk-storage fallback)
//
//  Output destination: the inventory when it fits, so the player can see and
//  equip the new item immediately — and the WAREHOUSE when it does not, rather
//  than refusing. Which one it landed in is reported, never silent: the success
//  banner already named a destination on every craft, so a changed destination
//  reads as information rather than as a surprise.
//
//  Both fit checks are in UNITS and both account for the drain, because the
//  drain frees space in whichever store the inputs came from. Counting one side
//  in ROWS is precisely the bug fixed on 2026-09-16: `freedSlots` still counted
//  rows after the 2026-05-12 per-unit pivot, and a stackable output whose row
//  already existed skipped the capacity test altogether — so `craft` drained the
//  inputs and then `InventoryEntry.add` threw. The throw escaped the callback
//  handler, the query was never answered, and the button span forever while the
//  ingredients were already gone.
//
//  No DB transaction wrapping — same pattern as WarehouseService. The drains
//  are idempotent enough that a partial failure leaves the player's totals
//  consistent (worst case: missing an input row plus its expected output).
//

import Fluent
import Foundation

public enum CraftingService {

    /// Where a finished craft landed. The bag is preferred — the player can
    /// equip and eat out of it — and the warehouse is the fallback, not a
    /// refusal.
    public enum CraftDestination: Sendable {
        case bag
        case warehouse
    }

    public enum CraftResult: Sendable {
        case success(outputItemId: String, outputQuantity: Int, destination: CraftDestination)
        case missingMaterials(shortages: [Shortage])
        /// Neither store has room. Named for what is true rather than for the
        /// bag alone: reaching this means the warehouse was asked and refused
        /// too, which is a different sentence to the player.
        case noRoom
        case unknownRecipe
        case unknownItem(String)
    }

    /// One missing-input record surfaced to the UI when the player taps Craft
    /// without enough materials in either the bag or the warehouse.
    public struct Shortage: Sendable {
        public let itemId: String
        public let need: Int
        public let have: Int
    }

    // MARK: - Stock

    /// What the player holds of one item, split by where it sits. `total` is
    /// what crafting actually operates on — inputs are drawn from the bag first
    /// and the warehouse second, so neither store alone answers "can I cook
    /// this".
    public struct StockLine: Sendable {
        public let bag: Int
        public let warehouse: Int
        public var total: Int { bag + warehouse }

        public init(bag: Int, warehouse: Int) {
            self.bag = bag
            self.warehouse = warehouse
        }
    }

    /// Everything the player holds, keyed by item id.
    ///
    /// TWO queries regardless of how many items are asked about — the shape the
    /// warehouse drill-down already uses. The per-item `totalQuantity` pair it
    /// replaces cost two queries per INPUT, which is ten for the Governor's
    /// Feast and would have been forty to draw one recipe list.
    ///
    /// Every screen that prints "you have N" reads this, and so does `craft`:
    /// a screen that computed its own number would eventually promise something
    /// the button then refused. Rows are counted exactly as
    /// `InventoryEntry.totalQuantity` counted them, equipped rows included —
    /// no recipe input is equippable, so the question never arises, but the
    /// arithmetic stays the one `craft` has always used.
    public static func stock(for user: User, on db: any Database) async throws -> [String: StockLine] {
        guard user.id != nil else { return [:] }
        var bag: [String: Int] = [:]
        var warehouse: [String: Int] = [:]
        for row in try await InventoryEntry.list(for: user, on: db) {
            bag[row.itemId, default: 0] += row.quantity
        }
        for row in try await WarehouseEntry.list(for: user, on: db) {
            warehouse[row.itemId, default: 0] += row.quantity
        }
        return Set(bag.keys).union(warehouse.keys).reduce(into: [:]) { out, id in
            out[id] = StockLine(bag: bag[id, default: 0], warehouse: warehouse[id, default: 0])
        }
    }

    /// Attempt to craft `recipe` for `user`. Order of operations:
    ///   1. Validate output item exists in catalog.
    ///   2. Compute combined inventory + warehouse availability per input.
    ///   3. If any input is short → return `.missingMaterials`, no state change.
    ///   4. Pick a destination: the bag if the output fits it after the drain,
    ///      otherwise the warehouse. If neither has room → `.noRoom`, no state
    ///      change.
    ///   5. Drain inputs (inventory first, warehouse second).
    ///   6. Add output to the store chosen in step 4.
    @discardableResult
    public static func craft(_ recipe: Recipe, for user: User, on db: any Database) async throws -> CraftResult {
        guard user.id != nil else { return .unknownRecipe }
        // Existence check only — the fit no longer depends on the item's shape,
        // so there is nothing to bind.
        guard ItemCatalog.find(recipe.output.itemId) != nil else {
            return .unknownItem(recipe.output.itemId)
        }

        // 1. Availability snapshot — the same reading the recipe screen quotes.
        let snapshot = try await stock(for: user, on: db)
        let shortages: [Shortage] = recipe.inputs.compactMap { input in
            let have = snapshot[input.itemId]?.total ?? 0
            guard have < input.quantity else { return nil }
            return Shortage(itemId: input.itemId, need: input.quantity, have: have)
        }
        if !shortages.isEmpty {
            return .missingMaterials(shortages: shortages)
        }

        // 2. Where can the output land? Both stores count UNITS, and both are
        // asked about the state AFTER the drain, because the drain frees space
        // in whichever store it takes from. Same arithmetic as
        // `TradeService`: used − outgoing + incoming ≤ cap.
        //
        // `outputItem.stackable` is deliberately NOT consulted. Since the
        // per-unit pivot a stackable output costs exactly as many slots as a
        // non-stackable one; the old branch asked whether a row already existed
        // and treated that as room, which it has not been since 2026-05-12.
        var drainedFromBag = 0
        var drainedFromWarehouse = 0
        for input in recipe.inputs {
            let fromInv = min(input.quantity, snapshot[input.itemId]?.bag ?? 0)
            drainedFromBag += fromInv
            drainedFromWarehouse += input.quantity - fromInv
        }
        let bagUsed = try await InventoryEntry.slotsUsed(for: user, on: db)
        let postDrainBag = max(0, bagUsed - drainedFromBag)
        // Devs bypass the BAG ceiling, exactly as `InventoryEntry.add` does —
        // a prediction that disagrees with the writer it is predicting is worse
        // than no prediction at all.
        let bagFits = user.isDeveloper
            || (postDrainBag + recipe.output.quantity) <= InventoryEntry.slotCap(for: user)

        let destination: CraftDestination
        if bagFits {
            destination = .bag
        } else {
            // The warehouse has no developer bypass — that exemption was
            // removed from all four warehouse checks and this is a fifth.
            let whUsed = try await WarehouseService.slotsUsed(for: user, on: db)
            let postDrainWarehouse = max(0, whUsed - drainedFromWarehouse)
            let warehouseFits =
                (postDrainWarehouse + recipe.output.quantity) <= WarehouseService.capForLevel(user.estateLevel)
            guard warehouseFits else { return .noRoom }
            destination = .warehouse
        }

        // 3. Drain — inventory first, warehouse for any shortfall.
        for input in recipe.inputs {
            let fromInv = min(input.quantity, snapshot[input.itemId]?.bag ?? 0)
            if fromInv > 0 {
                _ = try await InventoryEntry.remove(input.itemId, quantity: fromInv, from: user, on: db)
            }
            let fromWH = input.quantity - fromInv
            if fromWH > 0 {
                _ = try await WarehouseEntry.remove(input.itemId, quantity: fromWH, from: user, on: db)
            }
        }

        // 4. Output to whichever store step 2 chose.
        switch destination {
        case .bag:
            try await InventoryEntry.add(recipe.output.itemId, quantity: recipe.output.quantity, to: user, on: db)
        case .warehouse:
            try await WarehouseEntry.add(recipe.output.itemId, quantity: recipe.output.quantity, to: user, on: db)
        }

        // The King asks for a cooked dish and for a crafted thing as two
        // different decrees, so the split is by the recipe's own category —
        // firing both would let a pot of stew answer "craft something".
        try? await KingService.record(recipe.category == .kitchen ? .dishCooked : .crafted,
                                      for: user, on: db)

        // Phase 9.2 — the Master's "Виплавка" job counts forge output. Only the
        // ingot is tracked in v1; best-effort so a quest hiccup can't eat a craft.
        if recipe.output.itemId == "mat.iron_ingot" {
            try? await QuestService.record(.ironIngotForged, amount: recipe.output.quantity, for: user, on: db)
        }

        return .success(outputItemId: recipe.output.itemId, outputQuantity: recipe.output.quantity, destination: destination)
    }

    // MARK: - Salvage (2026-09-27)
    //
    // The reverse of `craft`: a crafted piece goes back to part of its recipe.
    // It is also the game's only way to be rid of a piece at all — armour
    // repaired down to 1/1 used to have nowhere to go, and a tester's bag held
    // fifteen spare and dead pieces with no exit (the trader buys no gear, the
    // market and the guild vault take stackables only).

    /// Which store a piece being taken apart sits in, and which ROW it is. Never
    /// an item id: two hoods at 1/1 and 30/30 are not the same piece, and this
    /// is the one action in the game that destroys one.
    public enum SalvageSource: Sendable, Equatable {
        case bag(UUID)
        case warehouse(UUID)
    }

    /// A piece the workshop could take apart, with what it would give back.
    public struct SalvageCandidate: Sendable {
        public let source: SalvageSource
        public let itemId: String
        public let state: GearState
        public let yield: [SalvageMath.Line]
    }

    public enum SalvageResult: Sendable {
        /// Taken apart. `destination` is nil when the yield was empty: the piece
        /// is gone and nothing landed anywhere.
        case success(itemId: String, tier: Int, yield: [SalvageMath.Line], destination: CraftDestination?)
        /// Neither store can take `units` more — checked before anything moved.
        case noRoom(units: Int)
        /// The row is gone, is being worn, or is nothing the workshop takes
        /// apart. A stale card, answered by redrawing the list.
        case gone
    }

    /// The recipe a piece was made by, when the workshop can take it apart:
    /// gear from a non-kitchen recipe, and never a class weapon on a ladder —
    /// those are upgraded in place and stay with the player. Today that is
    /// exactly the four Forester pieces.
    public static func salvageRecipe(for itemId: String) -> Recipe? {
        guard let item = ItemCatalog.find(itemId), item.type == .gear,
              !WeaponUpgradeCatalog.isUpgradable(itemId) else { return nil }
        return RecipeCatalog.all.first { $0.output.itemId == itemId && $0.category != .kitchen }
    }

    /// What one piece gives back, from its recipe and its max durability. The
    /// arithmetic is `SalvageMath`, so the card, the payout and the tests all
    /// read the same lines.
    public static func salvageYield(itemId: String, maxDurability: Int) -> [SalvageMath.Line] {
        guard let recipe = salvageRecipe(for: itemId) else { return [] }
        return SalvageMath.yield(
            recipeInputs: recipe.inputs.map { SalvageMath.Line(itemId: $0.itemId, quantity: $0.quantity) },
            recipeOutputQuantity: recipe.output.quantity,
            fraction: GearConditionService.salvageFraction,
            maxDurability: maxDurability,
            maxDurabilityStart: GearConditionService.maxDurabilityStart)
    }

    /// Every piece the workshop could take apart now: unequipped bag rows and
    /// warehouse rows, most worn first — the dead pieces are what a player
    /// opens this list for.
    public static func salvageCandidates(for user: User, on db: any Database) async throws -> [SalvageCandidate] {
        var out: [SalvageCandidate] = []
        for row in try await InventoryEntry.list(for: user, on: db) where row.equippedSlot == nil {
            guard let id = row.id, salvageRecipe(for: row.itemId) != nil else { continue }
            out.append(SalvageCandidate(source: .bag(id), itemId: row.itemId, state: row.gearState,
                                        yield: salvageYield(itemId: row.itemId, maxDurability: row.maxDurability)))
        }
        for row in try await WarehouseEntry.list(for: user, on: db) {
            guard let id = row.id, salvageRecipe(for: row.itemId) != nil else { continue }
            out.append(SalvageCandidate(source: .warehouse(id), itemId: row.itemId, state: row.gearState,
                                        yield: salvageYield(itemId: row.itemId, maxDurability: row.maxDurability)))
        }
        return out.sorted { lhs, rhs in
            if lhs.state.maxDurability != rhs.state.maxDurability { return lhs.state.maxDurability < rhs.state.maxDurability }
            if lhs.state.durability != rhs.state.durability { return lhs.state.durability < rhs.state.durability }
            return lhs.itemId < rhs.itemId
        }
    }

    /// One candidate, re-read by its row — what the confirmation card shows.
    /// Nil when the row is gone, being worn, or not salvageable.
    public static func salvageCandidate(_ source: SalvageSource, for user: User, on db: any Database) async throws -> SalvageCandidate? {
        guard let piece = try await salvageRow(source, for: user, on: db) else { return nil }
        return SalvageCandidate(source: source, itemId: piece.itemId, state: piece.state,
                                yield: salvageYield(itemId: piece.itemId, maxDurability: piece.state.maxDurability))
    }

    /// Take one piece apart.
    ///
    /// Same order as `craft`: the fit is predicted first, in UNITS, for the
    /// state after the piece leaves whichever store it sat in; then the piece
    /// goes; then the yield lands in the store the prediction chose — the bag,
    /// or the warehouse when the bag cannot take it. The prediction is what
    /// keeps `InventoryEntry.add` from throwing after the piece is already gone.
    public static func salvage(_ source: SalvageSource, for user: User, on db: any Database) async throws -> SalvageResult {
        guard let piece = try await salvageRow(source, for: user, on: db) else { return .gone }

        let yield = salvageYield(itemId: piece.itemId, maxDurability: piece.state.maxDurability)
        let units = yield.reduce(0) { $0 + $1.quantity }

        var destination: CraftDestination?
        if units > 0 {
            let bagUsed = try await InventoryEntry.slotsUsed(for: user, on: db) - (piece.bagRow?.quantity ?? 0)
            // Devs bypass the BAG ceiling, exactly as `InventoryEntry.add` does.
            if user.isDeveloper || bagUsed + units <= InventoryEntry.slotCap(for: user) {
                destination = .bag
            } else {
                // No developer bypass on the warehouse, like every other check on it.
                let whUsed = try await WarehouseService.slotsUsed(for: user, on: db) - (piece.warehouseRow?.quantity ?? 0)
                guard whUsed + units <= WarehouseService.capForLevel(user.estateLevel) else {
                    return .noRoom(units: units)
                }
                destination = .warehouse
            }
        }

        if let row = piece.bagRow { try await row.delete(on: db) }
        if let row = piece.warehouseRow { try await row.delete(on: db) }

        for line in yield {
            switch destination {
            case .bag?:       try await InventoryEntry.add(line.itemId, quantity: line.quantity, to: user, on: db)
            case .warehouse?: try await WarehouseEntry.add(line.itemId, quantity: line.quantity, to: user, on: db)
            case nil:         break
            }
        }
        return .success(itemId: piece.itemId, tier: piece.state.tier, yield: yield, destination: destination)
    }

    /// The row behind a salvage source, owned by this player, not worn, and
    /// made by a recipe the workshop can reverse. Exactly one of the two rows
    /// is set.
    private struct SalvagePiece {
        let itemId: String
        let state: GearState
        let bagRow: InventoryEntry?
        let warehouseRow: WarehouseEntry?
    }

    private static func salvageRow(_ source: SalvageSource, for user: User, on db: any Database) async throws -> SalvagePiece? {
        guard let userId = user.id else { return nil }
        switch source {
        case .bag(let id):
            guard let row = try await InventoryEntry.query(on: db)
                    .filter(\.$user.$id, .equal, userId)
                    .filter(\.$id, .equal, id)
                    .first(),
                  row.equippedSlot == nil,
                  salvageRecipe(for: row.itemId) != nil else { return nil }
            return SalvagePiece(itemId: row.itemId, state: row.gearState, bagRow: row, warehouseRow: nil)
        case .warehouse(let id):
            guard let row = try await WarehouseEntry.query(on: db)
                    .filter(\.$user.$id, .equal, userId)
                    .filter(\.$id, .equal, id)
                    .first(),
                  salvageRecipe(for: row.itemId) != nil else { return nil }
            return SalvagePiece(itemId: row.itemId, state: row.gearState, bagRow: nil, warehouseRow: row)
        }
    }
}
