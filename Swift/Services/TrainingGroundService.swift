//
//  TrainingGroundService.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 27.09.2026.
//
//  Building and raising the Training Ground. Same order as the estate's own
//  upgrade: the room's tier gate, the next level, the player-level floor, the
//  silver (checked before materials, so a cash-short player gets one clean
//  sentence), then the materials from the combined bag + warehouse pool —
//  drained bag first. Paying teaches the level's technique, and the level then
//  climbs through every next one the player already knows
//  (`TrainingGroundLevelDTO.levelAfterCatchUp`), so a technique learned on the
//  old plot-based ground is never paid for twice.
//

import Fluent
import Foundation

public enum TrainingGroundService {

    public enum UpgradeResult: Sendable {
        /// `taught` is the technique id when paying taught something new;
        /// `built` when this was level 1; `caughtUp` when the level climbed
        /// past the one paid for.
        case success(level: Int, taught: String?, built: Bool, caughtUp: Bool)
        case maxLevel
        case estateTooLow(required: Int)
        case playerLevelTooLow(required: Int, current: Int)
        case insufficientSilver(required: Int, current: Int)
        case missingMaterials(shortages: [CraftingService.Shortage])
    }

    public static func upgrade(for user: User, on db: any Database) async throws -> UpgradeResult {
        guard let userId = user.id else { return .maxLevel }
        guard user.estateLevel >= EstateTierGates.trainingGround else {
            return .estateTooLow(required: EstateTierGates.trainingGround)
        }
        guard let next = TrainingGroundCatalog.level(user.trainingGroundLevel + 1) else { return .maxLevel }

        let floor = TrainingGroundCatalog.playerLevel(for: next)
        if user.level < floor { return .playerLevelTooLow(required: floor, current: user.level) }
        if user.silver < next.silverCost {
            return .insufficientSilver(required: next.silverCost, current: user.silver)
        }

        var shortages: [CraftingService.Shortage] = []
        var snapshot: [String: (inv: Int, wh: Int)] = [:]
        for input in next.inputs {
            let invQty = try await InventoryEntry.totalQuantity(of: input.itemId, for: userId, on: db)
            let whQty  = try await WarehouseEntry.totalQuantity(of: input.itemId, for: userId, on: db)
            snapshot[input.itemId] = (invQty, whQty)
            if invQty + whQty < input.quantity {
                shortages.append(CraftingService.Shortage(itemId: input.itemId, need: input.quantity, have: invQty + whQty))
            }
        }
        if !shortages.isEmpty { return .missingMaterials(shortages: shortages) }

        for input in next.inputs {
            let (invQty, _) = snapshot[input.itemId] ?? (0, 0)
            let fromInv = min(input.quantity, invQty)
            if fromInv > 0 {
                _ = try await InventoryEntry.remove(input.itemId, quantity: fromInv, from: user, on: db)
            }
            let fromWH = input.quantity - fromInv
            if fromWH > 0 {
                _ = try await WarehouseEntry.remove(input.itemId, quantity: fromWH, from: user, on: db)
            }
        }
        user.silver -= next.silverCost

        let taught = try await LearnedTechnique.add(next.technique, for: user, on: db)
        var known = try await LearnedTechnique.allIds(for: user, on: db)
        known.insert(next.technique)
        let level = TrainingGroundLevelDTO.levelAfterCatchUp(paid: next.level, in: TrainingGroundCatalog.levels, known: known)
        let built = user.trainingGroundLevel == 0
        user.trainingGroundLevel = level
        try await user.saveAndCache(in: db)

        return .success(level: level, taught: taught ? next.technique : nil, built: built, caughtUp: level > next.level)
    }
}
