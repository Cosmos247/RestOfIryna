//
//  ClassChangeService.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 11.10.2026.
//
//  The Treasury's class change (2026-10-11, the owner's answers): for
//  zlatnyks, the player becomes another class at the same level.
//  - The stat line is the new class's at that level (`applyLevelDerivedStats`,
//    the level-up's own recompute), and HP follows the level-up rule, clamped
//    to `effectiveMaxHp`.
//  - The class weapon is REFORGED into the new class's weapon at its tier and
//    wear: the three ladders share tiers, player-level gates and
//    `durabilityByTier`, so nothing is given and nothing is lost.
//  - Techniques need nothing: `learned_techniques` stores class-agnostic kinds,
//    and the class resolves which one fires. The arena's admission comes with
//    them.
//  - A pinned note for the weapon's next rung follows the weapon.
//  - No limit on how often, only the price. Refused during an arena duel,
//    whose fighters are snapshots of their class.
//
//  `apply` is the ONE transformation: the confirm screen runs it on a stand-in
//  to show «now → after», and the purchase runs it on the row it saves, so the
//  screen and the result cannot disagree.
//

import Fluent
import Foundation

public enum ClassChangeService {

    /// The numbers the confirm screen compares, read the way the profile reads
    /// them (`effective*`).
    public struct Line: Sendable, Equatable {
        public let maxHp: Int
        public let attack: Int
        public let defense: Int
        public let accuracy: Int
        public let dodge: Int
        public let crit: Int

        init(_ user: User) {
            maxHp = user.effectiveMaxHp
            attack = user.effectiveAttack
            defense = user.effectiveDefense
            accuracy = user.effectiveAccuracy
            dodge = user.effectiveDodge
            crit = user.effectiveCrit
        }
    }

    /// The class weapon a player holds, as the confirm screen names it.
    public struct Weapon: Sendable, Equatable {
        public let itemId: String
        public let tier: Int
        public let durability: Int
        public let maxDurability: Int
    }

    public struct Preview: Sendable {
        public let from: CharacterClass
        public let to: CharacterClass
        public let before: Line
        public let after: Line
        /// The worn class weapon, or the one in the bag; nil if the player has none.
        public let weapon: Weapon?
        /// The learned technique kinds — the same three rows under either class.
        public let techniques: [CombatService.TechniqueKind]
    }

    public enum Refusal: Error, Equatable {
        case sameClass
        case inDuel
        case notEnough(have: Int, need: Int)
    }

    public struct Outcome: Sendable {
        public let to: CharacterClass
        public let balanceAfter: Int
    }

    // MARK: - The one transformation

    /// Rewrites `user` and the weapon rows in `rows` (in memory) into
    /// `newClass`. Nothing is saved here.
    static func apply(_ newClass: CharacterClass, to user: User, rows: [InventoryEntry]) {
        let oldWeapon = CharacterClass(rawValue: user.characterClass ?? "")?.starterWeaponId
        let newWeapon = newClass.starterWeaponId
        user.characterClass = newClass.rawValue
        for row in rows where row.itemId == oldWeapon {
            row.itemId = newWeapon
        }
        user.applyLevelDerivedStats()
        EquipmentService.applyBonuses(of: rows, to: user)
        // The recompute clamped against the old bonuses. A weapon carries no
        // HP, so this changes nothing today — it is here so a weapon that ever
        // does cannot leave HP above the new ceiling.
        user.hp = min(user.hp, user.effectiveMaxHp)
    }

    /// The fields `apply` writes, copied from the row the purchase saved onto
    /// the session's object — so the dispatcher's copy says what the database
    /// says. If `apply` ever writes another field, it belongs here too.
    private static func adopt(_ saved: User, into session: User) {
        session.characterClass = saved.characterClass
        session.maxHp = saved.maxHp
        session.hp = saved.hp
        session.attack = saved.attack
        session.defense = saved.defense
        session.crit = saved.crit
        session.dodge = saved.dodge
        session.accuracy = saved.accuracy
        session.maxVigor = saved.maxVigor
        session.vigor = saved.vigor
        session.gearAttackBonus = saved.gearAttackBonus
        session.gearDefenseBonus = saved.gearDefenseBonus
        session.gearCritBonus = saved.gearCritBonus
        session.gearDodgeBonus = saved.gearDodgeBonus
        session.gearHpBonus = saved.gearHpBonus
        session.gearAccuracyBonus = saved.gearAccuracyBonus
    }

    /// A detached copy of what `apply` and `Line` read, for the preview. The
    /// session's own object is never touched by a preview: the watchman may
    /// save it at any moment, and would write a half-changed class.
    private static func standIn(for user: User) -> User {
        let ghost = User()
        ghost.characterClass = user.characterClass
        ghost.level = user.level
        ghost.hp = user.hp
        ghost.maxHp = user.maxHp
        ghost.attack = user.attack
        ghost.defense = user.defense
        ghost.crit = user.crit
        ghost.dodge = user.dodge
        ghost.accuracy = user.accuracy
        ghost.vigor = user.vigor
        ghost.maxVigor = user.maxVigor
        ghost.gearAttackBonus = user.gearAttackBonus
        ghost.gearDefenseBonus = user.gearDefenseBonus
        ghost.gearCritBonus = user.gearCritBonus
        ghost.gearDodgeBonus = user.gearDodgeBonus
        ghost.gearHpBonus = user.gearHpBonus
        ghost.gearAccuracyBonus = user.gearAccuracyBonus
        ghost.activeFortuneCardId = user.activeFortuneCardId
        ghost.activeFortuneExpiresAt = user.activeFortuneExpiresAt
        return ghost
    }

    // MARK: - Preview

    public static func preview(_ user: User, to newClass: CharacterClass, on db: any Database) async throws -> Preview {
        let userId = try user.requireID()
        let from = CharacterClass(rawValue: user.characterClass ?? "") ?? .warrior
        let rows = try await InventoryEntry.query(on: db).filter(\.$user.$id, .equal, userId).all()
        let weaponRow = rows.filter { $0.itemId == from.starterWeaponId }
            .sorted { ($0.equippedSlot != nil ? 0 : 1) < ($1.equippedSlot != nil ? 0 : 1) }
            .first
        let weapon = weaponRow.map {
            Weapon(itemId: $0.itemId, tier: $0.tier, durability: $0.durability, maxDurability: $0.maxDurability)
        }
        let ghost = standIn(for: user)
        // Fresh query objects: rewritten in memory for the ghost, never saved.
        apply(newClass, to: ghost, rows: rows)
        let learned = try await LearnedTechnique.query(on: db).filter(\.$user.$id, .equal, userId).all()
        let kinds = Set(learned.compactMap { CombatService.TechniqueKind(rawValue: $0.techniqueId) })
        return Preview(from: from, to: newClass, before: Line(user), after: Line(ghost), weapon: weapon,
                       techniques: CombatService.TechniqueKind.allCases.filter(kinds.contains))
    }

    // MARK: - The purchase

    /// Pays and changes the class in ONE transaction: the zlatnyks, the weapon
    /// rows, the pinned notes, the player's row and the purchase log commit
    /// together or not at all. The work is done on a row loaded inside the
    /// transaction, and copied onto `session` only once it has committed.
    public static func perform(_ session: User, to newClass: CharacterClass, item: TreasuryItemDTO,
                               on db: any Database) async throws -> Outcome {
        let userId = try session.requireID()
        let from = CharacterClass(rawValue: session.characterClass ?? "") ?? .warrior
        guard from != newClass else { throw Refusal.sameClass }
        if await ArenaStore.shared.activeDuel(for: session.telegramId) != nil { throw Refusal.inDuel }

        let oldWeapon = from.starterWeaponId, newWeapon = newClass.starterWeaponId
        let (saved, balanceAfter) = try await db.transaction { tx -> (User, Int) in
            // Cannot be missing: it is the session's own row.
            guard let row = try await User.find(userId, on: tx) else { throw Refusal.sameClass }
            // The database is the judge, and it is asked before the price: a
            // second tap after the first has committed finds the class already
            // changed and is told so, whatever the balance left.
            guard row.characterClass != newClass.rawValue else { throw Refusal.sameClass }
            guard let left = try await ZlatnykService.spend(item.price, from: userId, on: tx) else {
                let have = (try? await ZlatnykService.balance(of: userId, on: tx)) ?? 0
                throw Refusal.notEnough(have: have, need: item.price)
            }

            let rows = try await InventoryEntry.query(on: tx).filter(\.$user.$id, .equal, userId).all()
            apply(newClass, to: row, rows: rows)
            for entry in rows where entry.itemId == newWeapon && entry.hasChanges {
                try await entry.save(on: tx)
            }
            // The warehouse refuses the class weapon (`WarehouseService`),
            // but a rule can change; the reforge reaches every copy.
            try await WarehouseEntry.query(on: tx)
                .filter(\.$user.$id, .equal, userId)
                .filter(\.$itemId, .equal, oldWeapon)
                .set(\.$itemId, to: newWeapon)
                .update()
            // A note names a THING: «the weapon's next rung» stays pinned.
            try await RecipeNote.query(on: tx)
                .filter(\.$user.$id, .equal, userId)
                .filter(\.$kindRaw ~~ [RecipeNote.Kind.lesson.rawValue, RecipeNote.Kind.weapon.rawValue])
                .filter(\.$ref, .equal, oldWeapon)
                .set(\.$ref, to: newWeapon)
                .update()
            try await row.save(on: tx)
            try await ZlatnykPurchase(userId: userId, telegramId: row.telegramId, nickname: row.nickname,
                                      itemId: item.id, price: item.price,
                                      detail: "\(from.rawValue) → \(newClass.rawValue)",
                                      balanceAfter: left).save(on: tx)
            return (row, left)
        }
        adopt(saved, into: session)
        await sessionCache.update(session)
        return Outcome(to: newClass, balanceAfter: balanceAfter)
    }
}
