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
//  and taken from the BAG alone, and the output goes to the bag or nowhere. The
//  arithmetic is `CraftMath`, the craft's own, with the warehouse left out of
//  both sides — the card and the tap cannot disagree.
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

    /// What the bag holds of each input — the number her card quotes.
    static func held(_ recipe: Recipe, for user: User, on db: any Database) async throws -> [String: Int] {
        guard let userId = user.id else { return [:] }
        var out: [String: Int] = [:]
        for input in recipe.inputs where out[input.itemId] == nil {
            out[input.itemId] = try await InventoryEntry.totalQuantity(of: input.itemId, for: userId, on: db)
        }
        return out
    }

    /// One tincture. Nothing moves on a refusal: materials are asked first, then
    /// the silver, then the room, all before the transaction.
    static func brew(_ recipe: Recipe, for user: User, on db: any Database) async throws -> BrewResult {
        let userId = try user.requireID()
        let held = try await held(recipe, for: user, on: db)
        let inputs = recipe.inputs.map { CraftMath.Input(need: $0.quantity, bag: held[$0.itemId] ?? 0, warehouse: 0) }
        // Units, like the writer, with its developer bypass. No warehouse here:
        // its ceiling of 0 turns "the rest goes there" into a refusal.
        let room = CraftMath.Room(bagUsed: try await InventoryEntry.slotsUsed(for: user, on: db),
                                  bagCap: InventoryEntry.slotCap(for: user),
                                  bagUnbounded: user.isDeveloper,
                                  warehouseUsed: 0, warehouseCap: 0)
        switch CraftMath.plan(times: 1, inputs: inputs, outputQuantity: recipe.output.quantity, room: room) {
        case .failure(.short(let indices)):
            return .missingMaterials(shortages: indices.map { index in
                CraftingService.Shortage(itemId: recipe.inputs[index].itemId, need: recipe.inputs[index].quantity,
                                         have: inputs[index].bag)
            })
        case .failure(.noRoom):
            return user.silver < recipe.silverFee
                ? .notEnoughSilver(have: user.silver, need: recipe.silverFee) : .noRoom
        case .success:
            break
        }
        guard user.silver >= recipe.silverFee else {
            return .notEnoughSilver(have: user.silver, need: recipe.silverFee)
        }

        let left = try await db.transaction { tx -> Int in
            for input in recipe.inputs {
                guard try await InventoryEntry.remove(input.itemId, quantity: input.quantity, from: user, on: tx) else {
                    throw BrewError.drainFailed(itemId: input.itemId)
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
