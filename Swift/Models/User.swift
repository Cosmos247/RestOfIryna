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

    @Field(key: "silver")
    var silver: Int

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

    /// Sixth cached gear bonus, added in Phase 6. See `AddGearHpBonus`.
    @Field(key: "gear_hp_bonus")
    var gearHpBonus: Int

    @Field(key: "gear_accuracy_bonus")
    var gearAccuracyBonus: Int

    // MARK: - Passive HP regen
    /// Last wall-clock tick used by `HealingService.tick`. Nil = needs priming on
    /// next interaction. Pinned to `now` while at full HP or during an active
    /// expedition so idle time doesn't accumulate into banked regen.
    ///
    /// HP only. The Vigor clock beside it went in Phase 8E — Vigor does not
    /// regenerate at all any more, so the column it read is dropped by
    /// `RemoveVigorTick`.
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

    /// Phase 6.0 — where the player is right now. "estate" (default) or
    /// "capital". Flips only when a `TravelState` timer elapses; never set
    /// directly from a controller. Used by `MainController` / `EstateController`
    /// / `ExplorationController` to gate nav and decide whether tapping the
    /// Capital button starts a trip or jumps straight into the capital screen.
    @Field(key: "location")
    var location: String

    /// Phase 6.4 — Fortune Teller's drawn card. `activeFortuneCardId` is
    /// the card's catalogue id (e.g. "19_sun"); `activeFortuneExpiresAt`
    /// is BOTH the effect's expiry AND the next-draw cooldown gate. Nil
    /// means "no active fortune" (player has never drawn OR previous
    /// draw expired). Stat hooks consult `activeFortuneEffect` (below).
    @OptionalField(key: "active_fortune_card_id")
    var activeFortuneCardId: String?

    @OptionalField(key: "active_fortune_expires_at")
    var activeFortuneExpiresAt: Date?

    /// Phase 6.4 fix — separate the 24h draw cooldown from the 6h buff
    /// duration. Stamped to "now" on every successful draw; the next
    /// draw is allowed only after `cooldownSeconds` has elapsed since
    /// this value. `activeFortuneExpiresAt` continues to gate the buff
    /// effects themselves (shorter window).
    @OptionalField(key: "last_fortune_draw_at")
    var lastFortuneDrawAt: Date?

    /// One-shot tutorial flag — flipped to `true` the first time the player
    /// returns from an active expedition. Used by `ExplorationController.handleHomeReached`
    /// to send a single "there's a Trader in the Capital" hint and never again.
    @Field(key: "tutorial_trader_hint_shown")
    var tutorialTraderHintShown: Bool

    /// Player's chosen gender — "m" (male) or "f" (female). Set once during
    /// registration (the gender step, ahead of the name prompt) and read by
    /// `Lingo.localize(_:gender:locale:)` to pick the Ukrainian feminitive
    /// variant of any gendered string, plus the per-gender estate artwork.
    /// Nil only between account creation and the gender step; the gendered
    /// localize helper treats nil as male.
    @OptionalField(key: "gender")
    var gender: String?

    /// The guild this player belongs to, if any (Phase 7.1). One guild per
    /// player — nil = not in a guild. Set/cleared by `GuildService` on
    /// found / join / leave / kick / disband. The roster is a `User` query by
    /// this field; `guildRole` carries their standing.
    @OptionalParent(key: "guild_id")
    var guild: Guild?

    /// Raw `GuildRole` value ("leader"/"officer"/"member"). Nil whenever `guild`
    /// is nil. Officers (max 2) + leader can manage members and withdraw vault.
    @OptionalField(key: "guild_role")
    var guildRole: String?

    /// The `registrationStep` value marking a fully-registered player. The
    /// dispatcher restore + combat bridge compare against this to tell
    /// mid-registration users from active players. It is `7` because the
    /// gender step was inserted ahead of the name prompt (steps 0–7).
    public static let registrationDoneStep: Int = 7


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
        self.silver = 0
        self.gearAttackBonus = 0
        self.gearHpBonus = 0
        self.gearDefenseBonus = 0
        self.gearCritBonus = 0
        self.gearDodgeBonus = 0
        self.gearAccuracyBonus = 0
        self.estateLevel = 1
        self.bagTier = 1
        self.location = "estate"
        self.activeFortuneCardId = nil
        self.activeFortuneExpiresAt = nil
        self.lastFortuneDrawAt = nil
        self.tutorialTraderHintShown = false
        self.gender = nil
        self.$guild.id = nil
        self.guildRole = nil
        self.createdAt = Date()
    }

    // MARK: - Phase 5.3a — Player XP / level

    /// Hard cap on player level. Reaching `maxLevel` freezes XP at zero and
    /// `xpToNextLevel` returns `Int.max` so progress bars render as full.
    public static var maxLevel: Int { Catalogs.current.tuningProgression.maxLevel }

    /// XP required to advance from `nextLevel - 1` → `nextLevel`:
    /// `max(round(c · L^e), floor · L)` where L is the level being left.
    ///
    /// Returns `Int.max` past `maxLevel` so callers can treat "no more XP
    /// needed" uniformly.
    public static func xpRequiredToReach(_ nextLevel: Int) -> Int {
        // nextLevel is the level the player would reach by spending the XP.
        // I.e. the cost of L1→L2 is xpRequiredToReach(2).
        ProgressionMath.xpRequiredToReach(nextLevel,
                                          curve: Catalogs.current.tuningProgression.xpCurve,
                                          maxLevel: maxLevel)
    }

    /// XP multiplier for killing a monster this far below your level.
    ///
    /// Required, not polish: without it, farming ten levels down keeps 67% of
    /// the XP for a fight that is 35% faster and 40% safer, which makes shallow
    /// farming strictly optimal and the whole depth ladder dead content.
    public static func xpMultiplier(playerLevel: Int, monsterLevel: Int) -> Double {
        ProgressionMath.xpMultiplier(playerLevel: playerLevel, monsterLevel: monsterLevel,
                                     spec: Catalogs.current.tuningProgression.xpLevelDiff)
    }

    /// XP this kill is worth to this player, after the level-gap scaling.
    public static func xpFromKill(_ enemy: Enemy, playerLevel: Int) -> Int {
        ProgressionMath.xpFromKill(xpReward: enemy.xpReward, monsterLevel: enemy.level,
                                   playerLevel: playerLevel,
                                   spec: Catalogs.current.tuningProgression.xpLevelDiff)
    }

    /// XP cost of the current pending level-up. `Int.max` once at max level.
    var xpToNextLevel: Int {
        return User.xpRequiredToReach(level + 1)
    }

    /// Phase 5.3b — levels that grant the +HP / +ATK / +DEF boost. Mid-tier
    /// levels only (not the estate-tier-up levels: 4 / 7 / 10 / 13 / 16 / 19,
    /// which already feel rewarding from the structural unlocks they bring).
    /// 8 boosts total → +40 maxHP, +8 ATK, +8 DEF by L21.
    /// Base stat line for a class at a given level.
    ///
    /// Stats are a FUNCTION of level now, not an accumulated pile of per-level
    /// bonuses: `base × (1 + rate × (L − 1))`. That is what lets a rating keep
    /// pace with its own diminishing-returns denominator — under the old flat
    /// +1/level a warrior's dodge percentage fell from 5.3% to 1.4% across a
    /// lifetime while the rating on the profile screen rose.
    ///
    /// Being a pure function of (class, level) also means a level-up cannot
    /// drift: it recomputes rather than accumulating, so a missed or
    /// double-applied grant self-heals on the next one.
    public static func baseStats(
        for characterClass: CharacterClass, at level: Int
    ) -> (maxHp: Int, attack: Int, defense: Int, crit: Int, dodge: Int, accuracy: Int) {
        let progression = Catalogs.current.tuningProgression
        return ProgressionMath.baseStats(start: characterClass.startRow,
                                         growth: progression.statGrowth, level: level)
    }

    /// Bring every existing row onto the proportional model.
    ///
    /// Idempotent by construction: `applyLevelDerivedStats` recomputes from
    /// (class, level) rather than adding to what is already there, so running
    /// this twice is the same as running it once. Rows written under the old
    /// flat-growth model carry stats that no formula produces any more — a
    /// level-21 warrior sits on 160 HP where the new model says 254 — and the
    /// enemies Phase 5C generates are balanced against the new line.
    ///
    /// Registration-incomplete rows are skipped: they have no class yet, and
    /// the King's Oath sets the level-1 line when they get one.
    static func backfillLevelDerivedStats(on db: any Database, logger: Logger) async throws {
        let users = try await User.query(on: db).all()
        var touched = 0
        for user in users where user.characterClass != nil {
            let beforeHp = user.maxHp, beforeAtk = user.attack, beforeDef = user.defense
            let beforeVigor = user.maxVigor
            user.applyLevelDerivedStats()
            guard user.maxHp != beforeHp || user.attack != beforeAtk
                    || user.defense != beforeDef || user.maxVigor != beforeVigor else { continue }
            try await user.save(on: db)
            touched += 1
        }
        if touched > 0 {
            logger.info("Backfilled level-derived stats for \(touched) user(s) onto the proportional model")
        }
    }

    /// Vigor ceiling at a level. Grows with the player so the regen rate, read
    /// as a share of the pool, stays constant instead of decaying to nothing.
    public static func maxVigor(at level: Int) -> Int {
        ProgressionMath.maxVigor(at: level,
                                 pool: Catalogs.current.tuningProgression.vigorPool)
    }

    /// Recompute every level-derived stat from `characterClass` and `level`.
    /// Current HP and Vigor rise by whatever the ceilings rose by, so a
    /// level-up is felt immediately rather than leaving the player at a lower
    /// fraction of a bigger bar. Returns the deltas for the UI banner.
    @discardableResult
    func applyLevelDerivedStats() -> (maxHp: Int, attack: Int, defense: Int) {
        guard let raw = characterClass,
              let cls = CharacterClass(rawValue: raw) else {
            return (0, 0, 0)
        }
        let next = User.baseStats(for: cls, at: level)
        let hpDelta = next.maxHp - maxHp
        let atkDelta = next.attack - attack
        let defDelta = next.defense - defense

        maxHp = next.maxHp
        if hpDelta > 0 { hp += hpDelta }
        hp = min(hp, maxHp)
        attack = next.attack
        defense = next.defense
        crit = next.crit
        dodge = next.dodge
        accuracy = next.accuracy

        let newMaxVigor = User.maxVigor(at: level)
        let vigorDelta = newMaxVigor - maxVigor
        maxVigor = newMaxVigor
        if vigorDelta > 0 { vigor += vigorDelta }
        vigor = min(vigor, maxVigor)

        return (hpDelta, atkDelta, defDelta)
    }

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
    /// at L2/3/5/6/9/12/15/18). Phase 6.4 — multiplies the incoming amount
    /// by `activeFortuneEffect?.xpMultiplier` (1.0 if no active fortune).
    /// Callers persist the user via `saveAndCache`.
    @discardableResult
    func grantXP(_ amount: Int) -> XPGrantResult {
        let oldLevel = level
        let oldEstate = estateLevel
        let xpMult = activeFortuneEffect?.xpMultiplier ?? 1.0
        let amountWithFortune = Int((Double(amount) * xpMult).rounded())
        guard amountWithFortune > 0, level < User.maxLevel else {
            return XPGrantResult(
                xpAwarded: 0, levelsGained: 0, estateLeveledUp: false,
                newLevel: level, newEstateLevel: estateLevel,
                maxHpGained: 0, attackGained: 0, defenseGained: 0
            )
        }
        xp += amountWithFortune
        let amount = amountWithFortune  // shadow for the XPGrantResult below
        var maxHpGained = 0
        var attackGained = 0
        var defenseGained = 0
        while level < User.maxLevel, xp >= xpToNextLevel {
            xp -= xpToNextLevel
            level += 1
            // Phase 5B — every level grows every stat, proportionally. The
            // old model boosted three stats on eight chosen levels and left the
            // other twelve inert; over a lifetime that was +40 HP against +32
            // DEF from a single enchant, which is why levels felt weightless.
            let gained = applyLevelDerivedStats()
            maxHpGained += gained.maxHp
            attackGained += gained.attack
            defenseGained += gained.defense
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

// MARK: - Developer flag

extension User {
    /// True if this user's Telegram id is listed in `developerUsers`. Used to
    /// bypass enforcement-only caps (bag / warehouse) while keeping counts
    /// visible in the UI. Per-developer convenience, not a permission gate —
    /// gating for dev commands stays on `allowedUsers`.
    var isDeveloper: Bool {
        return developerUsers.contains(self.telegramId)
    }
}

// MARK: - Active fortune (Phase 6.4)

extension User {
    /// The currently active fortune effect, or nil if no card is drawn or
    /// the previous one has expired. Read by every stat-computation hook
    /// (`effectiveAttack/Defense/Crit/Dodge/Accuracy`, `grantXP`,
    /// `ExplorationService.rollStep`, `VigorService.drain` callsites)
    /// to layer the buff/debuff on top of base values.
    var activeFortuneEffect: FortuneEffect? {
        guard let cardId = activeFortuneCardId,
              let expiresAt = activeFortuneExpiresAt,
              Date() < expiresAt,
              let card = FortuneCatalog.find(cardId)
        else { return nil }
        return card.effect
    }

    /// Seconds until the active fortune effect expires (the 6h buff
    /// window). Nil if no active fortune or already expired. Different
    /// from `fortuneCooldownRemaining` — the buff can wear off long
    /// before the cooldown allows another draw.
    func fortuneSecondsRemaining(now: Date = Date()) -> Int? {
        guard let expiresAt = activeFortuneExpiresAt, now < expiresAt else { return nil }
        return Int(expiresAt.timeIntervalSince(now).rounded())
    }

    /// Seconds until the player can draw a new card (the 24h cooldown
    /// window). Nil if no draw yet OR cooldown has already elapsed.
    /// Independent of `fortuneSecondsRemaining` — the cooldown ALWAYS
    /// outlasts the buff under the current 24h/6h split.
    func fortuneCooldownRemaining(now: Date = Date()) -> Int? {
        guard let drawn = lastFortuneDrawAt else { return nil }
        let elapsed = now.timeIntervalSince(drawn)
        let left = FortuneCatalog.cooldownSeconds - elapsed
        return left > 0 ? Int(left.rounded()) : nil
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
