//
//  TinctureService.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 07.11.2026.
//
//  The fortune teller brews (the owner's design, 2026-11-07,
//  `content/spec/spec-tinctures.md`): the player brings the plants and a trophy
//  and pays her fee, and a tincture lands in the bag at once.
//
//  She stands in the capital, which has no warehouse, so the inputs are counted
//  and taken from the BAG — and, while it is in town, the hired wagon as the
//  second store (2026-11-08, `spec-wagon.md` §3.4: the bag first, the wagon for
//  the rest) — and the output goes to the bag or nowhere: her brew puts nothing
//  on the wagon, though a tincture may be loaded onto it at home. The arithmetic
//  is `CraftMath`, the craft's own, with the wagon in the warehouse's input
//  column and a ceiling of 0 on its output side — the card and the tap cannot
//  disagree.
//
//  The drains, the output and the fee commit together: the work is done on a row
//  loaded inside the transaction and copied onto the session only once it has
//  committed, as `ClassChangeService` does, so the session's object is never
//  half-paid.
//
//  This is not a craft for the King or a job: she made it, the player did not.
//

import Fluent
import Foundation

enum TinctureService {

    enum BrewResult: Sendable {
        case brewed(itemId: String, quantity: Int, fee: Int)
        case missingMaterials(shortages: [CraftingService.Shortage])
        case notEnoughSilver(have: Int, need: Int)
        case noRoom
    }

    /// Thrown inside the transaction, which rolls it back: an input the plan
    /// counted was gone by the time it was taken.
    enum BrewError: Error {
        case drainFailed(itemId: String)
        case missingRow
    }

    /// Her list, in the order `recipes.json` holds it.
    static var recipes: [Recipe] { RecipeCatalog.recipes(in: .tincture) }

    /// A tincture's recipe by id; nil for anything else, so a forged or stale
    /// callback cannot reach the estate's recipes through her.
    static func find(_ id: String) -> Recipe? {
        RecipeCatalog.find(id).flatMap { $0.category == .tincture ? $0 : nil }
    }

    /// What the bag — and the wagon in town — hold of each input, apart.
    static func stock(_ recipe: Recipe, for user: User, on db: any Database) async throws -> [String: (bag: Int, wagon: Int)] {
        guard user.id != nil else { return [:] }
        var out: [String: (bag: Int, wagon: Int)] = [:]
        for input in recipe.inputs where out[input.itemId] == nil {
            out[input.itemId] = try await WagonService.townStock(of: input.itemId, for: user, on: db)
        }
        return out
    }

    /// What the bag and the wagon in town hold of each input — the number her
    /// card quotes.
    static func held(_ recipe: Recipe, for user: User, on db: any Database) async throws -> [String: Int] {
        try await stock(recipe, for: user, on: db).mapValues { $0.bag + $0.wagon }
    }

    /// One tincture. Nothing moves on a refusal: materials are asked first, then
    /// the silver, then the room, all before the transaction.
    static func brew(_ recipe: Recipe, for user: User, on db: any Database) async throws -> BrewResult {
        let userId = try user.requireID()
        let stock = try await stock(recipe, for: user, on: db)
        // The wagon stands in the warehouse's input column; its output side has
        // a ceiling of 0, so "the rest goes there" stays a refusal — the brew
        // lands in the bag or nowhere. Units, like the writer, with its developer
        // bypass.
        let inputs = recipe.inputs.map {
            CraftMath.Input(need: $0.quantity, bag: stock[$0.itemId]?.bag ?? 0, warehouse: stock[$0.itemId]?.wagon ?? 0)
        }
        let room = CraftMath.Room(bagUsed: try await InventoryEntry.slotsUsed(for: user, on: db),
                                  bagCap: InventoryEntry.slotCap(for: user),
                                  bagUnbounded: user.isDeveloper,
                                  warehouseUsed: 0, warehouseCap: 0)
        let plan: CraftMath.Plan
        switch CraftMath.plan(times: 1, inputs: inputs, outputQuantity: recipe.output.quantity, room: room) {
        case .failure(.short(let indices)):
            return .missingMaterials(shortages: indices.map { index in
                CraftingService.Shortage(itemId: recipe.inputs[index].itemId, need: recipe.inputs[index].quantity,
                                         have: inputs[index].bag + inputs[index].warehouse)
            })
        case .failure(.noRoom):
            return user.silver < recipe.silverFee
                ? .notEnoughSilver(have: user.silver, need: recipe.silverFee) : .noRoom
        case .success(let planned):
            plan = planned
        }
        guard user.silver >= recipe.silverFee else {
            return .notEnoughSilver(have: user.silver, need: recipe.silverFee)
        }

        let left = try await db.transaction { tx -> Int in
            for (index, input) in recipe.inputs.enumerated() {
                let fromBag = plan.fromBag[index], fromWagon = plan.fromWarehouse[index]
                if fromBag > 0 {
                    guard try await InventoryEntry.remove(input.itemId, quantity: fromBag, from: user, on: tx) else {
                        throw BrewError.drainFailed(itemId: input.itemId)
                    }
                }
                if fromWagon > 0 {
                    guard try await WagonService.removeCargo(input.itemId, quantity: fromWagon, userId: userId, on: tx) else {
                        throw BrewError.drainFailed(itemId: input.itemId)
                    }
                }
            }
            try await InventoryEntry.add(recipe.output.itemId, quantity: recipe.output.quantity, to: user, on: tx)
            guard let row = try await User.find(userId, on: tx) else { throw BrewError.missingRow }
            row.silver -= recipe.silverFee
            try await row.save(on: tx)
            return row.silver
        }
        user.silver = left
        try await user.saveAndCache(in: db)
        // A note on this recipe is done once it is made; best-effort, like the
        // craft funnel's own hook.
        try? await RecipeNoteService.recipeMade(recipe.id, for: user, on: db)
        return .brewed(itemId: recipe.output.itemId, quantity: recipe.output.quantity, fee: recipe.silverFee)
    }
}
