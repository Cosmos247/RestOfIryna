//
//  User.swift
//  RestOfIryna
//
//  Created by Maxim Lanskoy on 13.06.2025.
//  Maintained by Dmytro Ihnatyuhin from 17.04.2026.
//

import Fluent
import Foundation
import SwiftTelegramBot

/// Property wrappers interact poorly with `Sendable` checking, causing a warning for the `@ID` property
/// It is recommended you write your model with sendability checking on and then suppress the warning
/// afterwards with `@unchecked Sendable`.
final public class User: Model, @unchecked Sendable {
    public static let schema = "users"

    @ID(key: .id)
    public var id: UUID?

    @Field(key: "telegram_id")
    var telegramId: Int64

    @Field(key: "router_name")
    var routerName: String

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?
    
    @Field(key: "user_name")
    var userName: String?
    
    @Field(key: "first_name")
    var firstName: String?
    
    @Field(key: "last_name")
    var lastName: String?
    
    @Field(key: "locale")
    var locale: String

    @Field(key: "nickname")
    var nickname: String?

    @Field(key: "character_class")
    var characterClass: String?

    @Field(key: "estate_name")
    var estateName: String?

    @Field(key: "registration_step")
    var registrationStep: Int

    @Field(key: "profile_style")
    var profileStyle: Int

    // MARK: - Game Stats

    @Field(key: "level")
    var level: Int

    @Field(key: "xp")
    var xp: Int

    @Field(key: "hp")
    var hp: Int

    @Field(key: "max_hp")
    var maxHp: Int

    /// Vigor — the "satiety" meter. DB column is still named `hunger` to avoid
    /// a destructive rename migration; only the Swift identifier is rebranded.
    @Field(key: "hunger")
    var vigor: Int

    @Field(key: "max_hunger")
    var maxVigor: Int

    @Field(key: "attack")
    var attack: Int

    @Field(key: "defense")
    var defense: Int

    @Field(key: "crit")
    var crit: Int

    @Field(key: "dodge")
    var dodge: Int

    @Field(key: "accuracy")
    var accuracy: Int

    @Field(key: "gold")
    var gold: Int

    // MARK: - Cached Gear Bonuses
    // Sum of equipped gear's GearStats. Recomputed on every equip/unequip so
    // readers (combat, profile) get effective stats synchronously without
    // re-querying inventory. See EquipmentService (Phase 2.3.3).

    @Field(key: "gear_attack_bonus")
    var gearAttackBonus: Int

    @Field(key: "gear_defense_bonus")
    var gearDefenseBonus: Int

    @Field(key: "gear_crit_bonus")
    var gearCritBonus: Int

    @Field(key: "gear_dodge_bonus")
    var gearDodgeBonus: Int

    @Field(key: "gear_accuracy_bonus")
    var gearAccuracyBonus: Int

    // MARK: - Passive Regen
    /// Last wall-clock tick used by `HealingService.tick`. Nil = needs priming on
    /// next interaction. Pinned to `now` while at full HP or during an active
    /// expedition so idle time doesn't accumulate into banked regen.
    @OptionalField(key: "last_hp_tick_at")
    var lastHpTickAt: Date?

    /// Phase 5.3c — estate tier is now player-controlled, not derived. Starts
    /// at 1 (the wooden hut from the King's grant) and only grows when the
    /// player spends materials at the Estate root via `EstateUpgradeService`.
    /// Each tier unlocks rooms, plot slots, recipe categories, and weapon
    /// upgrade gates per the Phase 5.3 unlock map.
    @Field(key: "estate_level")
    var estateLevel: Int

    /// Phase 5.3d — backpack tier. T1 starts at 20 slots; later tiers
    /// (crafted at the Workshop via `BagUpgradeService`) raise the cap up
    /// to 75 at T5. Existing rows in the bag stay regardless of cap; the
    /// limit only blocks new inserts past it, same as the warehouse policy.
    @Field(key: "bag_tier")
    var bagTier: Int


    var name: String {
        if let firstName = firstName, let lastName = lastName {
            return "\(firstName) \(lastName)"
        } else if let firstName = firstName {
            return firstName
        } else if let lastName = lastName {
            return lastName
        } else if let userName = userName {
            return userName
        } else {
            return "🧑‍💻 User"
        }
    }

    public init() {}

    init(id: UUID? = nil, telegramId: Int64, locale: String, userName: String? = nil, firstName: String? = nil, lastName: String? = nil) {
        self.id = id
        self.telegramId = telegramId
        self.routerName = "registration"
        self.userName = userName
        self.firstName = firstName
        self.lastName = lastName
        self.locale = locale
        self.registrationStep = 0
        self.profileStyle = 1
        self.level = 1
        self.xp = 0
        self.hp = 100
        self.maxHp = 100
        self.vigor = 100
        self.maxVigor = 100
        self.attack = 10
        self.defense = 10
        self.crit = 5
        self.dodge = 5
        self.accuracy = 10
        self.gold = 0
        self.gearAttackBonus = 0
        self.gearDefenseBonus = 0
        self.gearCritBonus = 0
        self.gearDodgeBonus = 0
        self.gearAccuracyBonus = 0
        self.estateLevel = 1
        self.bagTier = 1
        self.createdAt = Date()
    }

    // MARK: - Phase 5.3a — Player XP / level

    /// Hard cap on player level. Reaching `maxLevel` freezes XP at zero and
    /// `xpToNextLevel` returns `Int.max` so progress bars render as full.
    public static let maxLevel: Int = 21

    /// XP required to advance from `forLevel` → `forLevel + 1`. Softcap curve:
    ///   - L1→L5: pure doubling — 100, 200, 400, 800, 1600
    ///   - L5+:   `prev * 1.4`, rounded — 2240, 3136, 4390, …
    /// Returns `Int.max` past `maxLevel` so callers can treat "no more XP needed"
    /// uniformly.
    public static func xpRequiredToReach(_ nextLevel: Int) -> Int {
        // nextLevel is the level the player would reach by spending the XP.
        // I.e. the cost of L1→L2 is xpRequiredToReach(2).
        guard nextLevel >= 2, nextLevel <= maxLevel else { return Int.max }
        var cost = 100
        var lvl = 2
        while lvl < nextLevel {
            if lvl <= 5 {
                cost *= 2
            } else {
                cost = Int((Double(cost) * 1.4).rounded())
            }
            lvl += 1
        }
        return cost
    }

    /// XP cost of the current pending level-up. `Int.max` once at max level.
    var xpToNextLevel: Int {
        return User.xpRequiredToReach(level + 1)
    }

    /// Phase 5.3b — levels that grant the +HP / +ATK / +DEF boost. Mid-tier
    /// levels only (not the estate-tier-up levels: 4 / 7 / 10 / 13 / 16 / 19,
    /// which already feel rewarding from the structural unlocks they bring).
    /// 8 boosts total → +40 maxHP, +8 ATK, +8 DEF by L21.
    public static let statGrowthLevels: Set<Int> = [2, 3, 5, 6, 9, 12, 15, 18]

    public static let statGrowthMaxHp: Int = 5
    public static let statGrowthAttack: Int = 1
    public static let statGrowthDefense: Int = 1

    /// Result of a `grantXP` call. UI banners read these to decide what to show.
    public struct XPGrantResult: Sendable {
        public let xpAwarded: Int
        public let levelsGained: Int
        public let estateLeveledUp: Bool
        public let newLevel: Int
        public let newEstateLevel: Int
        /// Phase 5.3b — total stat growth from this grant. Zero when no
        /// stat-growth level was crossed (either no level-up at all, or only
        /// estate-tier-up levels were crossed).
        public let maxHpGained: Int
        public let attackGained: Int
        public let defenseGained: Int
    }

    /// Add XP and process level-ups in a loop. Returns a result describing how
    /// many levels were gained, whether the estate tier crossed a threshold,
    /// and any stat growth applied (Phase 5.3b — +5 maxHP / +1 ATK / +1 DEF
    /// at L2/3/5/6/9/12/15/18). Callers persist the user via `saveAndCache`.
    @discardableResult
    func grantXP(_ amount: Int) -> XPGrantResult {
        let oldLevel = level
        let oldEstate = estateLevel
        guard amount > 0, level < User.maxLevel else {
            return XPGrantResult(
                xpAwarded: 0, levelsGained: 0, estateLeveledUp: false,
                newLevel: level, newEstateLevel: estateLevel,
                maxHpGained: 0, attackGained: 0, defenseGained: 0
            )
        }
        xp += amount
        var maxHpGained = 0
        var attackGained = 0
        var defenseGained = 0
        while level < User.maxLevel, xp >= xpToNextLevel {
            xp -= xpToNextLevel
            level += 1
            // Phase 5.3b — apply stat growth on configured levels. Bump current
            // HP alongside maxHp so the player visibly benefits right away
            // (RPG-standard "you feel stronger" cadence).
            if User.statGrowthLevels.contains(level) {
                maxHp += User.statGrowthMaxHp
                hp += User.statGrowthMaxHp
                attack += User.statGrowthAttack
                defense += User.statGrowthDefense
                maxHpGained += User.statGrowthMaxHp
                attackGained += User.statGrowthAttack
                defenseGained += User.statGrowthDefense
            }
        }
        if level >= User.maxLevel {
            // Pin XP to 0 at cap so the profile doesn't keep accumulating
            // dead XP after the player can no longer spend it.
            xp = 0
        }
        return XPGrantResult(
            xpAwarded: amount,
            levelsGained: level - oldLevel,
            estateLeveledUp: estateLevel > oldEstate,
            newLevel: level,
            newEstateLevel: estateLevel,
            maxHpGained: maxHpGained,
            attackGained: attackGained,
            defenseGained: defenseGained
        )
    }

    /// Apply class-specific starting stats
    func applyStartingStats(for characterClass: CharacterClass) {
        let s = characterClass.startingStats
        self.hp = s.hp
        self.maxHp = s.hp
        self.attack = s.attack
        self.defense = s.defense
        self.crit = s.crit
        self.dodge = s.dodge
        self.accuracy = s.accuracy
    }
    
    static func _session(for telegramId: Int64, locale: String = "en", db: any Database) async throws -> User {
        if let found = try await User.query(on: db).filter(\.$telegramId, .equal, telegramId).first() {
            return found
        } else {
            let newUser = User(telegramId: telegramId, locale: locale, userName: nil, firstName: nil, lastName: nil)
            try await newUser.save(on: db)
            return newUser
        }
    }
    
    static func _session(for tgUser: TGUser, locale: String = "en", db: any Database) async throws -> User {
        if let found = try await User.query(on: db).filter(\.$telegramId, .equal, tgUser.id).first() {
            return found
        } else {
            let newUser = User(telegramId: tgUser.id, locale: locale, userName: tgUser.username, firstName: tgUser.firstName, lastName: tgUser.lastName)
            try await newUser.save(on: db)
            return newUser
        }
    }
}

// MARK: - Cache Integration

extension User {
    /// Get user session with caching (95% faster)
    static func cachedSession(for tgUser: TGUser, db: any Database) async throws -> User {
        try await sessionCache.getOrFetch(tgUser: tgUser, db: db)
    }

    /// Save and update cache
    func saveAndCache(in db: any Database) async throws {
        try await save(on: db)
        await sessionCache.update(self)
    }

    /// Invalidate cache for this user
    func invalidateCache() async {
        await sessionCache.invalidate(telegramId: self.telegramId)
    }
}
