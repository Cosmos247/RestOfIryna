//
//  FortuneCatalog.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 17.05.2026.
//
//  Façade over `content/data/fortune.json` (Phase 3C — was a Swift array).
//  The 22 Major Arcana the Ворожка draws from. Each card carries:
//    • `id` — file-system-safe key matching `Assets/capital/fortune/<id>.png`
//      and the locale-key suffix (`fortune.card.<id>.name` / `.meaning` /
//      `.buff_desc`).
//    • `nameKey` / `meaningKey` / `buffDescKey` — Lingo lookups.
//    • `effect: FortuneEffect` — what actually happens when drawn. All 24h
//      effects are uniform 4h post-rebase (Phase 6.4 design call).
//
//  `FortuneEffect` is a single struct with optional fields so a card sets
//  only what it cares about. The same struct serves stat bonuses,
//  multipliers, one-shot silver/HP/vigor/XP gifts, and random "wheel"
//  one-shots. Stat-bonus / multiplier fields are consulted lazily by
//  `User.activeFortuneEffect` (which returns nil once expired); one-shot
//  fields are applied at draw time by `FortuneService.draw`.
//

import Foundation

/// What a single tarot card does. All multiplier fields default to 1.0
/// (no-op); all bonus/one-shot fields default to 0 (no-op). Cards set
/// only the slice that matches their archetype.
public struct FortuneEffect: Sendable {
    // Stat additive bonuses (active for the 4h window). Negative values
    // are debuffs.
    public let attackBonus: Int
    public let defenseBonus: Int
    public let critBonus: Int
    public let dodgeBonus: Int
    public let accuracyBonus: Int

    // Multipliers (active for the 4h window). 1.0 = no-op.
    public let xpMultiplier: Double          // applied in User.grantXP
    public let lootChanceMultiplier: Double  // applied in ExplorationService.rollStep
    public let vigorDrainMultiplier: Double  // applied in VigorService.drain

    // One-shot effects applied immediately on draw. Don't depend on the
    // 4h expiry window — silver lands, HP restores, etc.
    public let oneShotSilver: Int              // positive = gift, negative = loss
    public let oneShotXpGain: Int
    public let oneShotHpRestore: Bool        // true = fully restore HP
    public let oneShotVigorRestore: Bool     // true = fully restore vigor

    // Wheel-style random one-shot: 50/50 between `randomSilverPositive`
    // (gift) and `randomSilverNegative` (loss). Both must be non-zero to
    // activate; otherwise the field is ignored.
    public let randomSilverPositive: Int
    public let randomSilverNegative: Int

    public init(
        attackBonus: Int = 0,
        defenseBonus: Int = 0,
        critBonus: Int = 0,
        dodgeBonus: Int = 0,
        accuracyBonus: Int = 0,
        xpMultiplier: Double = 1.0,
        lootChanceMultiplier: Double = 1.0,
        vigorDrainMultiplier: Double = 1.0,
        oneShotSilver: Int = 0,
        oneShotXpGain: Int = 0,
        oneShotHpRestore: Bool = false,
        oneShotVigorRestore: Bool = false,
        randomSilverPositive: Int = 0,
        randomSilverNegative: Int = 0
    ) {
        self.attackBonus = attackBonus
        self.defenseBonus = defenseBonus
        self.critBonus = critBonus
        self.dodgeBonus = dodgeBonus
        self.accuracyBonus = accuracyBonus
        self.xpMultiplier = xpMultiplier
        self.lootChanceMultiplier = lootChanceMultiplier
        self.vigorDrainMultiplier = vigorDrainMultiplier
        self.oneShotSilver = oneShotSilver
        self.oneShotXpGain = oneShotXpGain
        self.oneShotHpRestore = oneShotHpRestore
        self.oneShotVigorRestore = oneShotVigorRestore
        self.randomSilverPositive = randomSilverPositive
        self.randomSilverNegative = randomSilverNegative
    }

    /// True if this effect carries ANY duration-based component (consulted
    /// at stat-computation time). Used by the UI to decide whether to
    /// render a countdown after the card is drawn — pure one-shots skip
    /// the countdown line.
    public var hasDurationEffect: Bool {
        return attackBonus != 0 || defenseBonus != 0 || critBonus != 0
            || dodgeBonus != 0 || accuracyBonus != 0
            || xpMultiplier != 1.0 || lootChanceMultiplier != 1.0
            || vigorDrainMultiplier != 1.0
    }
}

public struct FortuneCard: Sendable {
    public let id: String
    public let nameKey: String
    public let meaningKey: String
    public let buffDescKey: String
    public let effect: FortuneEffect

    public init(id: String, effect: FortuneEffect) {
        self.id = id
        self.nameKey     = "fortune.card.\(id).name"
        self.meaningKey  = "fortune.card.\(id).meaning"
        self.buffDescKey = "fortune.card.\(id).buff_desc"
        self.effect = effect
    }
}

public enum FortuneCatalog {
    /// Draw price in silvers. 10s matches the v2 economy's "small wager"
    /// scale (10/25/50 in tavern gambling).
    public static var drawPrice: Int { Catalogs.current.fortuneDrawPrice }

    /// Buff/debuff effect window — matches the Ворожка's lore
    /// ("наступні шість годин"). 6 hours.
    public static var buffDurationSeconds: TimeInterval { Catalogs.current.fortuneBuffDurationSeconds }

    /// Draw cooldown — independent of the buff window. Player can only
    /// draw a new card after this much time has passed since the
    /// previous draw, even if the buff has already worn off. 24 hours
    /// = one draw per day.
    public static var cooldownSeconds: TimeInterval { Catalogs.current.fortuneCooldownSeconds }

    /// All 22 Major Arcana, in traditional numbering (Fool = 0 through
    /// World = 21). `FortuneService.draw` picks with `randomElement()`, so the
    /// deck's ORDER decides which card a given roll returns — the loader never
    /// sorts it.
    ///
    /// Computed, never a `static let`. The old `lookup` here WAS a
    /// `private static let` reading `all`; once `all` reads the snapshot that
    /// would have run at type-init and trapped before `ContentBootstrap.load`.
    /// The dictionary lives in `DomainContent` now.
    public static var all: [FortuneCard] { Catalogs.current.fortuneCards }

    public static func find(_ cardId: String) -> FortuneCard? {
        return Catalogs.current.fortuneCardsById[cardId]
    }

    /// Asset path for a card's portrait. Caller passes the result to
    /// `sendCachedPhoto`. Files are PNG (preserve original tarot art).
    public static func assetPath(for cardId: String) -> String {
        return "\(projectPath)/Assets/capital/fortune/\(cardId).png"
    }
}
