//
//  FortuneCatalog.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 17.05.2026.
//
//  Phase 6.4 — static catalogue of the 22 Major Arcana cards the Ворожка
//  draws from. Each card carries:
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
    public static let drawPrice: Int = 10

    /// Buff/debuff effect window — matches the Ворожка's lore
    /// ("наступні шість годин"). 6 hours.
    public static let buffDurationSeconds: TimeInterval = 6 * 60 * 60

    /// Draw cooldown — independent of the buff window. Player can only
    /// draw a new card after this much time has passed since the
    /// previous draw, even if the buff has already worn off. 24 hours
    /// = one draw per day.
    public static let cooldownSeconds: TimeInterval = 24 * 60 * 60

    /// All 22 Major Arcana. Order matches the traditional numbering
    /// (Fool = 0 through World = 21). Random draw picks one uniformly.
    public static let all: [FortuneCard] = [
        // 0 — Fool. Reckless gain.
        FortuneCard(id: "0_fool",            effect: FortuneEffect(defenseBonus: -5, lootChanceMultiplier: 1.20)),
        // 1 — Magician. Focused skill.
        FortuneCard(id: "1_magician",        effect: FortuneEffect(attackBonus: 5)),
        // 2 — High Priestess. Defensive intuition.
        FortuneCard(id: "2_high_priestess",  effect: FortuneEffect(attackBonus: -5, dodgeBonus: 10)),
        // 3 — Empress. Fruitful growth.
        FortuneCard(id: "3_empress",         effect: FortuneEffect(attackBonus: 5, defenseBonus: 5)),
        // 4 — Emperor. Heavy armour, slow reflex.
        FortuneCard(id: "4_emperor",         effect: FortuneEffect(defenseBonus: 10, dodgeBonus: -5)),
        // 5 — Hierophant. Study trades gathering for wisdom.
        FortuneCard(id: "5_hierophant",      effect: FortuneEffect(xpMultiplier: 1.25, lootChanceMultiplier: 0.90)),
        // 6 — Lovers. Full restoration, one-shot.
        FortuneCard(id: "6_lovers",          effect: FortuneEffect(oneShotHpRestore: true, oneShotVigorRestore: true)),
        // 7 — Chariot. Forward motion = less fatigue.
        FortuneCard(id: "7_chariot",         effect: FortuneEffect(vigorDrainMultiplier: 0.75)),
        // 8 — Strength. Inner crit.
        FortuneCard(id: "8_strength",        effect: FortuneEffect(critBonus: 10)),
        // 9 — Hermit. Deep study, lesser gathering.
        FortuneCard(id: "9_hermit",          effect: FortuneEffect(xpMultiplier: 1.35, lootChanceMultiplier: 0.85)),
        // 10 — Wheel of Fortune. 50/50 silver swing.
        FortuneCard(id: "10_wheel_fortune",  effect: FortuneEffect(randomSilverPositive: 30, randomSilverNegative: 15)),
        // 11 — Justice. Karma restrains.
        FortuneCard(id: "11_justice",        effect: FortuneEffect(attackBonus: -5, defenseBonus: 5)),
        // 12 — Hanged Man. Time slows; reflexes dull.
        FortuneCard(id: "12_hanged_man",     effect: FortuneEffect(dodgeBonus: -10, vigorDrainMultiplier: 0.50)),
        // 13 — Death. Transformation costs.
        FortuneCard(id: "13_death",          effect: FortuneEffect(attackBonus: -10, defenseBonus: -10)),
        // 14 — Temperance. Balanced finesse.
        FortuneCard(id: "14_temperance",     effect: FortuneEffect(critBonus: 5, dodgeBonus: 5)),
        // 15 — Devil. Temptation drains and distracts.
        FortuneCard(id: "15_devil",          effect: FortuneEffect(defenseBonus: -5, vigorDrainMultiplier: 1.50)),
        // 16 — Tower. Sudden ruin.
        FortuneCard(id: "16_tower",          effect: FortuneEffect(oneShotSilver: -25)),
        // 17 — Star. Hopeful clarity.
        FortuneCard(id: "17_star",           effect: FortuneEffect(dodgeBonus: 5, accuracyBonus: 5)),
        // 18 — Moon. Fear blurs sight.
        FortuneCard(id: "18_moon",           effect: FortuneEffect(accuracyBonus: -5, lootChanceMultiplier: 0.85)),
        // 19 — Sun. Radiant strike.
        FortuneCard(id: "19_sun",            effect: FortuneEffect(attackBonus: 10)),
        // 20 — Judgement. Heavy reckoning, deep growth.
        FortuneCard(id: "20_judgement",      effect: FortuneEffect(oneShotSilver: -20, oneShotXpGain: 75)),
        // 21 — World. Full circle jackpot.
        FortuneCard(id: "21_world",          effect: FortuneEffect(oneShotSilver: 20, oneShotHpRestore: true, oneShotVigorRestore: true)),
    ]

    private static let lookup: [String: FortuneCard] = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })

    public static func find(_ cardId: String) -> FortuneCard? {
        return lookup[cardId]
    }

    /// Asset path for a card's portrait. Caller passes the result to
    /// `sendScenicPhoto`. Files are PNG (preserve original tarot art).
    public static func assetPath(for cardId: String) -> String {
        return "\(projectPath)/Assets/capital/fortune/\(cardId).png"
    }
}
