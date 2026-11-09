//
//  ReadyChecks.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 09.11.2026.
//
//  Whether a button earns its «✅» (`ReadyMark`): each check asks what the card
//  behind the button prints, from the same place it counts — bag + warehouse at
//  the estate, bag + the wagon in town at the Master — so a mark and the card's
//  lines cannot disagree. A new card with requirement lines that a list opens
//  belongs here too.
//

import Fluent
import Foundation

enum ReadyChecks {

    /// What an estate place can draw on: the number every estate card prints.
    static func held(for user: User, on db: any Database) async throws -> [String: Int] {
        try await CraftingService.stock(for: user, on: db).mapValues(\.total)
    }

    /// A recipe's card: its ingredients and its fee.
    static func recipe(_ recipe: Recipe, held: [String: Int], silver: Int) -> Bool {
        silver >= recipe.silverFee
            && ReadyMark.covers(recipe.inputs.map { ($0.itemId, $0.quantity) }, held: held)
    }

    /// The estate's next tier: the player's level, the materials and the silver.
    static func estateUpgrade(_ user: User, held: [String: Int]) -> Bool {
        guard let next = EstateUpgradeCatalog.nextStep(from: user.estateLevel) else { return false }
        return user.level >= next.requiredPlayerLevel
            && user.silver >= next.silverCost
            && ReadyMark.covers(next.inputs.map { ($0.itemId, $0.quantity) }, held: held)
    }

    /// The bag's next step: the estate's tier and the materials.
    static func bagUpgrade(_ user: User, held: [String: Int]) -> Bool {
        guard let next = BagCatalog.nextStep(from: user.bagTier) else { return false }
        return user.estateLevel >= next.requiredEstateLevel
            && ReadyMark.covers(next.inputs.map { ($0.itemId, $0.quantity) }, held: held)
    }

    /// The Training Ground's next level: the player's level, the materials and
    /// the silver.
    static func training(_ user: User, held: [String: Int]) -> Bool {
        guard let next = TrainingGroundCatalog.level(user.trainingGroundLevel + 1) else { return false }
        return user.level >= TrainingGroundCatalog.playerLevel(for: next)
            && user.silver >= next.silverCost
            && ReadyMark.covers(next.inputs.map { ($0.itemId, $0.quantity) }, held: held)
    }

    /// The workshop's next rung of the worn weapon, from tier 2 up (tier 1 is
    /// the Master's lesson): the player's level and the materials.
    static func weaponUpgrade(_ user: User, held: [String: Int], on db: any Database) async throws -> Bool {
        guard let weapon = try await WeaponUpgradeService.equippedWeapon(for: user, on: db), weapon.tier >= 2,
              let maxTier = WeaponUpgradeCatalog.maxTier(for: weapon.itemId), weapon.tier < maxTier,
              let next = WeaponUpgradeCatalog.step(for: weapon.itemId, tier: weapon.tier + 1) else { return false }
        return user.level >= next.requiredPlayerLevel
            && ReadyMark.covers(next.inputs.map { ($0.itemId, $0.quantity) }, held: held)
    }

    /// The Master's lesson: its fee and its materials from the bag and the
    /// wagon in town, what his card counts. Its level gate decides whether the
    /// button exists at all.
    static func lesson(_ user: User, on db: any Database) async throws -> Bool {
        guard user.silver >= MasterCatalog.weaponLessonSilver,
              let weapon = try await WeaponUpgradeService.equippedWeapon(for: user, on: db), weapon.tier == 1,
              let next = WeaponUpgradeCatalog.step(for: weapon.itemId, tier: 2) else { return false }
        for input in next.inputs {
            guard try await WagonService.townTotal(of: input.itemId, for: user, on: db) >= input.quantity else { return false }
        }
        return true
    }
}
