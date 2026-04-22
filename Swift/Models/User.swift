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

    @Field(key: "hunger")
    var hunger: Int

    @Field(key: "max_hunger")
    var maxHunger: Int

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
        self.hunger = 100
        self.maxHunger = 100
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
        self.createdAt = Date()
    }

    /// Estate level derived from the player's level. Every 5 player levels raises
    /// the estate by one tier — player lv 1–5 → estate lv 1, lv 6–10 → 2, and so on.
    /// Drives per-level artwork and unlocked locations (Phase 5 scaffolding).
    var estateLevel: Int {
        return 1 + max(0, (level - 1)) / 5
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
