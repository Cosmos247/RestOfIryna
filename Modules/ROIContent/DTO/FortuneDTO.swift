//
//  FortuneDTO.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 29.08.2026.
//
//  Wire format for `content/data/fortune.json` — the 22 Major Arcana the
//  Ворожка draws from.
//
//  `FortuneEffectDTO` follows the `GearStatsDTO` pattern: every field carries a
//  no-op default and only the non-default ones are written. That is what keeps
//  22 cards × 14 fields from becoming 308 lines of zeros, and it is the RECORD
//  rule, not the scalar rule — a card that sets nothing is a legitimate card,
//  whereas a missing tuning scalar is a corrupt file.
//
//  The no-op value differs per field and that matters: additive bonuses default
//  to 0, multipliers to 1.0, flags to false. Encoding a multiplier only when it
//  differs from 1.0 (not from 0) is the whole reason this cannot be a single
//  generic "skip falsy" rule.
//
//  Card ORDER is preserved: `FortuneService.draw` picks with `randomElement()`,
//  so the array's order decides which card a given roll returns.
//
//  Locale keys (`fortune.card.<id>.name` / `.meaning` / `.buff_desc`) and the
//  asset path (`Assets/capital/fortune/<id>.png`) both derive from `id`, so
//  neither is written into the file. The validator derives and checks the keys.
//

import Foundation

/// What one card does. Stat bonuses and multipliers run for the buff window;
/// one-shots land immediately at draw time.
public struct FortuneEffectDTO: Codable, Sendable, Equatable {
    public let attackBonus: Int
    public let defenseBonus: Int
    public let critBonus: Int
    public let dodgeBonus: Int
    public let accuracyBonus: Int

    public let xpMultiplier: Double
    public let lootChanceMultiplier: Double
    public let vigorDrainMultiplier: Double

    public let oneShotSilver: Int
    public let oneShotXpGain: Int
    public let oneShotHpRestore: Bool
    public let oneShotVigorRestore: Bool

    /// Wheel-style 50/50 swing. Both must be non-zero to activate.
    public let randomSilverPositive: Int
    public let randomSilverNegative: Int

    public init(
        attackBonus: Int = 0, defenseBonus: Int = 0, critBonus: Int = 0,
        dodgeBonus: Int = 0, accuracyBonus: Int = 0,
        xpMultiplier: Double = 1.0, lootChanceMultiplier: Double = 1.0,
        vigorDrainMultiplier: Double = 1.0,
        oneShotSilver: Int = 0, oneShotXpGain: Int = 0,
        oneShotHpRestore: Bool = false, oneShotVigorRestore: Bool = false,
        randomSilverPositive: Int = 0, randomSilverNegative: Int = 0
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

    private enum CodingKeys: String, CodingKey {
        case attackBonus, defenseBonus, critBonus, dodgeBonus, accuracyBonus
        case xpMultiplier, lootChanceMultiplier, vigorDrainMultiplier
        case oneShotSilver, oneShotXpGain, oneShotHpRestore, oneShotVigorRestore
        case randomSilverPositive, randomSilverNegative
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        attackBonus          = try c.decodeIfPresent(Int.self, forKey: .attackBonus)   ?? 0
        defenseBonus         = try c.decodeIfPresent(Int.self, forKey: .defenseBonus)  ?? 0
        critBonus            = try c.decodeIfPresent(Int.self, forKey: .critBonus)     ?? 0
        dodgeBonus           = try c.decodeIfPresent(Int.self, forKey: .dodgeBonus)    ?? 0
        accuracyBonus        = try c.decodeIfPresent(Int.self, forKey: .accuracyBonus) ?? 0
        xpMultiplier         = try c.decodeIfPresent(Double.self, forKey: .xpMultiplier)         ?? 1.0
        lootChanceMultiplier = try c.decodeIfPresent(Double.self, forKey: .lootChanceMultiplier) ?? 1.0
        vigorDrainMultiplier = try c.decodeIfPresent(Double.self, forKey: .vigorDrainMultiplier) ?? 1.0
        oneShotSilver        = try c.decodeIfPresent(Int.self, forKey: .oneShotSilver)  ?? 0
        oneShotXpGain        = try c.decodeIfPresent(Int.self, forKey: .oneShotXpGain)  ?? 0
        oneShotHpRestore     = try c.decodeIfPresent(Bool.self, forKey: .oneShotHpRestore)    ?? false
        oneShotVigorRestore  = try c.decodeIfPresent(Bool.self, forKey: .oneShotVigorRestore) ?? false
        randomSilverPositive = try c.decodeIfPresent(Int.self, forKey: .randomSilverPositive) ?? 0
        randomSilverNegative = try c.decodeIfPresent(Int.self, forKey: .randomSilverNegative) ?? 0
    }

    /// Only fields that differ from their no-op value are written. Note each
    /// group's no-op is different — 0 for bonuses, 1.0 for multipliers, false
    /// for flags — so this cannot collapse into one condition.
    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        if attackBonus   != 0 { try c.encode(attackBonus,   forKey: .attackBonus) }
        if defenseBonus  != 0 { try c.encode(defenseBonus,  forKey: .defenseBonus) }
        if critBonus     != 0 { try c.encode(critBonus,     forKey: .critBonus) }
        if dodgeBonus    != 0 { try c.encode(dodgeBonus,    forKey: .dodgeBonus) }
        if accuracyBonus != 0 { try c.encode(accuracyBonus, forKey: .accuracyBonus) }
        if xpMultiplier         != 1.0 { try c.encode(xpMultiplier,         forKey: .xpMultiplier) }
        if lootChanceMultiplier != 1.0 { try c.encode(lootChanceMultiplier, forKey: .lootChanceMultiplier) }
        if vigorDrainMultiplier != 1.0 { try c.encode(vigorDrainMultiplier, forKey: .vigorDrainMultiplier) }
        if oneShotSilver != 0 { try c.encode(oneShotSilver, forKey: .oneShotSilver) }
        if oneShotXpGain != 0 { try c.encode(oneShotXpGain, forKey: .oneShotXpGain) }
        if oneShotHpRestore    { try c.encode(oneShotHpRestore,    forKey: .oneShotHpRestore) }
        if oneShotVigorRestore { try c.encode(oneShotVigorRestore, forKey: .oneShotVigorRestore) }
        if randomSilverPositive != 0 { try c.encode(randomSilverPositive, forKey: .randomSilverPositive) }
        if randomSilverNegative != 0 { try c.encode(randomSilverNegative, forKey: .randomSilverNegative) }
    }
}

public struct FortuneCardDTO: Codable, Sendable, Equatable {
    /// Doubles as the locale-key suffix and the PNG filename, so it has to stay
    /// filesystem-safe.
    public let id: String
    public let effect: FortuneEffectDTO

    public init(id: String, effect: FortuneEffectDTO = FortuneEffectDTO()) {
        self.id = id
        self.effect = effect
    }

    private enum CodingKeys: String, CodingKey { case id, effect }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id     = try c.decode(String.self, forKey: .id)
        // A card with no effect at all is legal data, not a corrupt row.
        effect = try c.decodeIfPresent(FortuneEffectDTO.self, forKey: .effect) ?? FortuneEffectDTO()
    }
}

/// Top-level shape of `fortune.json`.
public struct FortuneFileDTO: Codable, Sendable {
    /// Draw price in silvers.
    public let drawPrice: Int
    /// Buff/debuff window. Matches the Ворожка's lore line.
    public let buffDurationSeconds: Double
    /// Draw cooldown — independent of the buff window.
    public let cooldownSeconds: Double
    /// Traditional numbering, Fool (0) through World (21). Order is preserved
    /// because the draw indexes into this array.
    public let cards: [FortuneCardDTO]

    public init(drawPrice: Int, buffDurationSeconds: Double, cooldownSeconds: Double,
                cards: [FortuneCardDTO]) {
        self.drawPrice = drawPrice
        self.buffDurationSeconds = buffDurationSeconds
        self.cooldownSeconds = cooldownSeconds
        self.cards = cards
    }

    private enum CodingKeys: String, CodingKey {
        case drawPrice, buffDurationSeconds, cooldownSeconds, cards
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        drawPrice           = try c.decode(Int.self, forKey: .drawPrice)
        buffDurationSeconds = try c.decode(Double.self, forKey: .buffDurationSeconds)
        cooldownSeconds     = try c.decode(Double.self, forKey: .cooldownSeconds)
        cards               = try c.decode([FortuneCardDTO].self, forKey: .cards)
    }
}
