//
//  TuningDTO.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 30.08.2026.
//
//  Wire format for `content/data/tuning/*.json` — the six balance tables.
//
//  These are NOT catalogs. A catalog holds a roster the player scrolls through;
//  these hold the numbers the formulas consume, and that difference decides
//  every decoding rule below:
//
//  • **Everything decodes as REQUIRED.** No `decodeIfPresent`, no defaults,
//    anywhere in this file. The optional-with-default pattern is right for a
//    record whose sub-field is genuinely absent (a ladder step with no material
//    cost), and wrong for a constant: a missing `baseHitChance` silently
//    becoming 0 is precisely the invisible balance drift the pipeline exists to
//    stop. A tuning table that forgets a field must fail the boot.
//
//  • **Per-class and per-kind rows are ARRAYS, not dictionaries.** A JSON
//    object would decode into a `[String: T]`, and mapping that back to
//    `CharacterClass` loses the guarantee that all three classes are present —
//    an absent `mage` would read as "the mage has no flee chance" rather than
//    as an error. An array of rows carrying an explicit `class` lets the
//    validator count them.
//
//  • **`class` is spelled `class` in the JSON** even though it collides with
//    the Swift keyword, because the file is read by a human balancing the
//    game, not by Swift. `CodingKeys` does the translation.
//
//  Two shapes here are not scalars and need their lookup semantics stated,
//  because both replace control flow rather than data:
//
//  1. `StanceTuningDTO` — `CombatService.stanceModifiers(for:)` returns
//     `.none` for an unknown id AND for nil, so the table lookup must miss
//     softly. `stanceActivationVigor` instead has a `default: 4` arm, which is
//     why `defaultActivationVigor` exists as its own field rather than being
//     inferred from the rows.
//  2. `EventWeightTierDTO` — the shipped `switch priorVisits` has arms for 0
//     and 1 and a `default` that swallows everything else, NEGATIVES INCLUDED.
//     So the lookup is "exact match on `priorVisits`, otherwise the LAST row",
//     not "the greatest row at or below the query" — the latter would hand a
//     negative count the fresh-room weights and quietly make re-entered rooms
//     generous. The validator pins the rows to a contiguous 0,1,2,… run so
//     "last" cannot silently become a different tier.
//

import Foundation

// MARK: - combat.json

/// Damage absorption: `min(cap, DEF / (DEF + kBase + kPerLevel·L))`.
///
/// A SEPARATE type from `RatingCurveDTO` on purpose. Both look like
/// diminishing-returns curves, but `cap` here is a CEILING applied after the
/// ratio, while `scale` there is a leading COEFFICIENT the ratio is multiplied
/// by. Reading one as the other inflates every derived value by ~80% and the
/// mistake is invisible in review — it was made once already, in the bestiary
/// generator, and cost a table of enemies whose fights ran far past their
/// target length. Two types means the compiler will not let it happen twice.
public struct MitigationCurveDTO: Codable, Sendable, Equatable {
    /// Hard ceiling on absorption, as a fraction. Nothing may become immune.
    public let cap: Double
    /// The denominator is linear in level BECAUSE the item budget curve is:
    /// that is what holds a stat's PERCENTAGE steady while its rating grows.
    /// Hand-picking these two numbers instead of deriving them from the budget
    /// is how a stat silently rots — an archer's dodge would end lower at the
    /// level cap than it started at level 1.
    public let kBase: Double
    public let kPerLevel: Double

    public init(cap: Double, kBase: Double, kPerLevel: Double) {
        self.cap = cap
        self.kBase = kBase
        self.kPerLevel = kPerLevel
    }

    private enum CodingKeys: String, CodingKey { case cap, kBase, kPerLevel }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        cap       = try c.decode(Double.self, forKey: .cap)
        kBase     = try c.decode(Double.self, forKey: .kBase)
        kPerLevel = try c.decode(Double.self, forKey: .kPerLevel)
    }
}

/// Rating → percent: `scale · R / (R + kBase + kPerLevel·L)`.
///
/// `scale` is the asymptote the percentage approaches but never reaches, so it
/// doubles as the stat's design ceiling: dodge tops out near 55%, crit near
/// 50%, the accuracy bonus near 30.
public struct RatingCurveDTO: Codable, Sendable, Equatable {
    public let scale: Double
    public let kBase: Double
    public let kPerLevel: Double

    public init(scale: Double, kBase: Double, kPerLevel: Double) {
        self.scale = scale
        self.kBase = kBase
        self.kPerLevel = kPerLevel
    }

    private enum CodingKeys: String, CodingKey { case scale, kBase, kPerLevel }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        scale     = try c.decode(Double.self, forKey: .scale)
        kBase     = try c.decode(Double.self, forKey: .kBase)
        kPerLevel = try c.decode(Double.self, forKey: .kPerLevel)
    }
}

public struct CombatCurvesDTO: Codable, Sendable, Equatable {
    public let mitigation: MitigationCurveDTO
    public let dodge: RatingCurveDTO
    public let crit: RatingCurveDTO
    public let accuracy: RatingCurveDTO

    public init(mitigation: MitigationCurveDTO, dodge: RatingCurveDTO,
                crit: RatingCurveDTO, accuracy: RatingCurveDTO) {
        self.mitigation = mitigation
        self.dodge = dodge
        self.crit = crit
        self.accuracy = accuracy
    }

    private enum CodingKeys: String, CodingKey { case mitigation, dodge, crit, accuracy }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        mitigation = try c.decode(MitigationCurveDTO.self, forKey: .mitigation)
        dodge      = try c.decode(RatingCurveDTO.self, forKey: .dodge)
        crit       = try c.decode(RatingCurveDTO.self, forKey: .crit)
        accuracy   = try c.decode(RatingCurveDTO.self, forKey: .accuracy)
    }
}

/// Damage multiplier from the gap between attacker and defender level:
/// `clamp(1 + perLevel·(attackerLevel − defenderLevel), min, max)`.
///
/// Orthogonal to the curves, and load-bearing for feel. The curves alone do not
/// deliver "I have outgrown this zone" — out-levelling a band by ten moves a
/// warrior's absorption from 38% to 44%, which nobody notices. This one line is
/// what sells it, and it is why enemy stats can stay frozen at design time
/// instead of scaling to the player (the trap that makes every gear upgrade
/// worthless the moment it is equipped).
public struct LevelDiffDTO: Codable, Sendable, Equatable {
    public let perLevel: Double
    public let min: Double
    public let max: Double

    public init(perLevel: Double, min: Double, max: Double) {
        self.perLevel = perLevel
        self.min = min
        self.max = max
    }

    private enum CodingKeys: String, CodingKey { case perLevel, min, max }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        perLevel = try c.decode(Double.self, forKey: .perLevel)
        min      = try c.decode(Double.self, forKey: .min)
        max      = try c.decode(Double.self, forKey: .max)
    }
}

public struct HitChanceDTO: Codable, Sendable, Equatable {
    public let base: Int
    public let min: Int
    public let max: Int

    public init(base: Int, min: Int, max: Int) {
        self.base = base
        self.min = min
        self.max = max
    }

    private enum CodingKeys: String, CodingKey { case base, min, max }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        base = try c.decode(Int.self, forKey: .base)
        min  = try c.decode(Int.self, forKey: .min)
        max  = try c.decode(Int.self, forKey: .max)
    }
}

/// Multiplicative damage spread on every landed hit.
public struct VarianceDTO: Codable, Sendable, Equatable {
    public let min: Double
    public let max: Double

    public init(min: Double, max: Double) {
        self.min = min
        self.max = max
    }

    private enum CodingKeys: String, CodingKey { case min, max }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        min = try c.decode(Double.self, forKey: .min)
        max = try c.decode(Double.self, forKey: .max)
    }
}

/// Unlock level and the level at which the kind's per-fight budget goes 1 → 2.
public struct TechniqueTuningDTO: Codable, Sendable, Equatable {
    public let kind: String
    public let requiredLevel: Int
    public let secondUseAtLevel: Int

    public init(kind: String, requiredLevel: Int, secondUseAtLevel: Int) {
        self.kind = kind
        self.requiredLevel = requiredLevel
        self.secondUseAtLevel = secondUseAtLevel
    }

    private enum CodingKeys: String, CodingKey { case kind, requiredLevel, secondUseAtLevel }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        kind             = try c.decode(String.self, forKey: .kind)
        requiredLevel    = try c.decode(Int.self, forKey: .requiredLevel)
        secondUseAtLevel = try c.decode(Int.self, forKey: .secondUseAtLevel)
    }
}

/// One Super stance: which class triggers it, what it costs, and the six
/// multipliers it applies for `durationRounds`.
///
/// **Every lift is a multiplier of the character's OWN stat (Phase 8C).** The
/// five flat `*Bonus` fields this replaces broke the rule Phase 6 wrote for
/// items and never applied here: `hawks_eye`'s +15 crit was ×2.15 of an archer's
/// rating at level 1 and ×1.21 at the cap, and `bloodlust`'s +5 attack decayed
/// ×1.29 → ×1.05 — so two of the three Supers rotted across a lifetime while the
/// mage's, alone in being a multiplier, held. That is the whole reason
/// techniques used to save the mage 30% of a fight and the warrior 5%.
///
/// 1.0 means "no change". A multiplier below 1.0 is legal — a stance that trades
/// defence for attack is a shape worth having — but zero is not: it would delete
/// the stat rather than modify it.
public struct StanceTuningDTO: Codable, Sendable, Equatable {
    public let id: String
    public let characterClass: String
    public let activationVigor: Int
    public let attackMultiplier: Double
    public let defenseMultiplier: Double
    public let critMultiplier: Double
    public let accuracyMultiplier: Double
    public let dodgeMultiplier: Double
    /// Scales the Vigor drain of every action while the stance holds. The one
    /// multiplier that is a COST, so it is the one that may legitimately exceed
    /// the others: bloodlust burning the player out is the mechanic.
    public let vigorMultiplier: Double

    public init(id: String, characterClass: String, activationVigor: Int,
                attackMultiplier: Double = 1.0, defenseMultiplier: Double = 1.0,
                critMultiplier: Double = 1.0, accuracyMultiplier: Double = 1.0,
                dodgeMultiplier: Double = 1.0, vigorMultiplier: Double = 1.0) {
        self.id = id
        self.characterClass = characterClass
        self.activationVigor = activationVigor
        self.attackMultiplier = attackMultiplier
        self.defenseMultiplier = defenseMultiplier
        self.critMultiplier = critMultiplier
        self.accuracyMultiplier = accuracyMultiplier
        self.dodgeMultiplier = dodgeMultiplier
        self.vigorMultiplier = vigorMultiplier
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case characterClass = "class"
        case activationVigor, attackMultiplier, defenseMultiplier
        case critMultiplier, accuracyMultiplier, dodgeMultiplier, vigorMultiplier
    }

    /// Every multiplier is REQUIRED, `1.0` included. A defaulted 1.0 would let a
    /// forgotten key read as "this stance does nothing to that stat", which is
    /// exactly the silent balance drift the tuning tables exist to prevent.
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id                 = try c.decode(String.self, forKey: .id)
        characterClass     = try c.decode(String.self, forKey: .characterClass)
        activationVigor    = try c.decode(Int.self, forKey: .activationVigor)
        attackMultiplier   = try c.decode(Double.self, forKey: .attackMultiplier)
        defenseMultiplier  = try c.decode(Double.self, forKey: .defenseMultiplier)
        critMultiplier     = try c.decode(Double.self, forKey: .critMultiplier)
        accuracyMultiplier = try c.decode(Double.self, forKey: .accuracyMultiplier)
        dodgeMultiplier    = try c.decode(Double.self, forKey: .dodgeMultiplier)
        vigorMultiplier    = try c.decode(Double.self, forKey: .vigorMultiplier)
    }
}

public struct StanceSectionDTO: Codable, Sendable, Equatable {
    public let durationRounds: Int
    /// Charged for a stance id the table does not know. Its own field because
    /// the shipped `stanceActivationVigor` has a real `default:` arm — dropping
    /// it and defaulting to 0 would make an unknown stance free.
    public let defaultActivationVigor: Int
    public let byId: [StanceTuningDTO]

    public init(durationRounds: Int, defaultActivationVigor: Int, byId: [StanceTuningDTO]) {
        self.durationRounds = durationRounds
        self.defaultActivationVigor = defaultActivationVigor
        self.byId = byId
    }

    private enum CodingKeys: String, CodingKey { case durationRounds, defaultActivationVigor, byId }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        durationRounds         = try c.decode(Int.self, forKey: .durationRounds)
        defaultActivationVigor = try c.decode(Int.self, forKey: .defaultActivationVigor)
        byId                   = try c.decode([StanceTuningDTO].self, forKey: .byId)
    }
}

/// What a Special Attack actually does, as a tagged union.
///
/// All three used to set `defenderDEFFraction = 0` — "ignore armour". Under
/// subtraction that was worth +50% damage. Under absorption the gain is
/// `1/(1−mitigation) − 1`: **+11% against trash, +25% against normal, +47%
/// against a brute**, for **+150% Vigor**. Efficiency 0.44–0.59×, i.e. the
/// technique was strictly worse than attacking twice, and worst exactly where
/// the player most wanted a trump card.
///
/// The replacements are chosen so their value does NOT shrink as absorption
/// rises. `armourBreak` grows with it, `burn` ignores it entirely, and
/// `guaranteedCrit` multiplies the post-absorption number. A `switch` with no
/// `default:` so a new case cannot be added without every consumer noticing.
public enum SpecialAttackEffectDTO: Codable, Sendable, Equatable {
    /// Sunders the target's armour for `rounds` player actions. The one effect
    /// whose worth RISES with the defender's absorption — the anti-armour tool
    /// matters against armour, which is the shape the old version got backwards.
    case armourBreak(rounds: Int)
    /// The blow always crits, at its own multiplier rather than the standard one.
    case guaranteedCrit(critMultiplier: Double)
    /// Damage per round for `rounds`, as a fraction of the attacker's ATK,
    /// applied whole — absorption never touches it.
    case burn(rounds: Int, fractionOfAttack: Double)

    public enum Kind: String, Codable, Sendable {
        case armourBreak = "armour_break"
        case guaranteedCrit = "guaranteed_crit"
        case burn
    }

    public var kind: Kind {
        switch self {
        case .armourBreak: return .armourBreak
        case .guaranteedCrit: return .guaranteedCrit
        case .burn: return .burn
        }
    }

    private enum CodingKeys: String, CodingKey {
        case kind, rounds, critMultiplier, fractionOfAttack
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        switch try c.decode(Kind.self, forKey: .kind) {
        case .armourBreak:
            self = .armourBreak(rounds: try c.decode(Int.self, forKey: .rounds))
        case .guaranteedCrit:
            self = .guaranteedCrit(critMultiplier: try c.decode(Double.self, forKey: .critMultiplier))
        case .burn:
            self = .burn(rounds: try c.decode(Int.self, forKey: .rounds),
                         fractionOfAttack: try c.decode(Double.self, forKey: .fractionOfAttack))
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(kind, forKey: .kind)
        switch self {
        case .armourBreak(let rounds):
            try c.encode(rounds, forKey: .rounds)
        case .guaranteedCrit(let multiplier):
            try c.encode(multiplier, forKey: .critMultiplier)
        case .burn(let rounds, let fraction):
            try c.encode(rounds, forKey: .rounds)
            try c.encode(fraction, forKey: .fractionOfAttack)
        }
    }
}

/// Per-class Special Attack: the Vigor price, the roll modifiers, and the
/// effect that makes it worth paying for.
public struct SpecialAttackTuningDTO: Codable, Sendable, Equatable {
    public let characterClass: String
    public let vigor: Int
    public let hitChanceModifier: Int
    public let cannotMiss: Bool
    /// True when unleashing the technique zeroes the player's dodge for the
    /// enemy's counter that round (the archer's long aim).
    public let zeroesDodge: Bool
    public let effect: SpecialAttackEffectDTO

    public init(characterClass: String, vigor: Int, hitChanceModifier: Int,
                cannotMiss: Bool, zeroesDodge: Bool, effect: SpecialAttackEffectDTO) {
        self.characterClass = characterClass
        self.vigor = vigor
        self.hitChanceModifier = hitChanceModifier
        self.cannotMiss = cannotMiss
        self.zeroesDodge = zeroesDodge
        self.effect = effect
    }

    private enum CodingKeys: String, CodingKey {
        case characterClass = "class"
        case vigor, hitChanceModifier, cannotMiss, zeroesDodge, effect
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        characterClass    = try c.decode(String.self, forKey: .characterClass)
        vigor             = try c.decode(Int.self, forKey: .vigor)
        hitChanceModifier = try c.decode(Int.self, forKey: .hitChanceModifier)
        cannotMiss        = try c.decode(Bool.self, forKey: .cannotMiss)
        zeroesDodge       = try c.decode(Bool.self, forKey: .zeroesDodge)
        effect            = try c.decode(SpecialAttackEffectDTO.self, forKey: .effect)
    }
}

public struct SpecialDefenseClassDTO: Codable, Sendable, Equatable {
    public let characterClass: String
    public let vigor: Int

    public init(characterClass: String, vigor: Int) {
        self.characterClass = characterClass
        self.vigor = vigor
    }

    private enum CodingKeys: String, CodingKey {
        case characterClass = "class"
        case vigor
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        characterClass = try c.decode(String.self, forKey: .characterClass)
        vigor          = try c.decode(Int.self, forKey: .vigor)
    }
}

public struct SpecialDefenseSectionDTO: Codable, Sendable, Equatable {
    public let effectPersistRounds: Int
    public let ironBulwarkChipFraction: Double
    /// Shadow Veil lifts the archer's dodge by this MULTIPLE of their own
    /// rating (Phase 8D). It was a flat +50 until then — worth 16 points of
    /// dodge chance at level 1 and 4 at the cap, the same rot Phase 8C took
    /// out of the stances one file over.
    public let shadowVeilDodgeMultiplier: Double
    public let mirrorWardReflectFraction: Double
    public let byClass: [SpecialDefenseClassDTO]

    public init(effectPersistRounds: Int, ironBulwarkChipFraction: Double,
                shadowVeilDodgeMultiplier: Double, mirrorWardReflectFraction: Double,
                byClass: [SpecialDefenseClassDTO]) {
        self.effectPersistRounds = effectPersistRounds
        self.ironBulwarkChipFraction = ironBulwarkChipFraction
        self.shadowVeilDodgeMultiplier = shadowVeilDodgeMultiplier
        self.mirrorWardReflectFraction = mirrorWardReflectFraction
        self.byClass = byClass
    }

    private enum CodingKeys: String, CodingKey {
        case effectPersistRounds, ironBulwarkChipFraction
        case shadowVeilDodgeMultiplier, mirrorWardReflectFraction, byClass
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        effectPersistRounds       = try c.decode(Int.self, forKey: .effectPersistRounds)
        ironBulwarkChipFraction   = try c.decode(Double.self, forKey: .ironBulwarkChipFraction)
        shadowVeilDodgeMultiplier = try c.decode(Double.self, forKey: .shadowVeilDodgeMultiplier)
        mirrorWardReflectFraction = try c.decode(Double.self, forKey: .mirrorWardReflectFraction)
        byClass                   = try c.decode([SpecialDefenseClassDTO].self, forKey: .byClass)
    }
}

public struct FleeTuningDTO: Codable, Sendable, Equatable {
    public let characterClass: String
    public let chance: Int
    /// Flat vigor charged on top of the base Flee cost. Non-zero only for the
    /// mage's teleport today, but stored per class so it stays a number rather
    /// than a `case .mage` in Swift.
    public let extraVigor: Int

    public init(characterClass: String, chance: Int, extraVigor: Int) {
        self.characterClass = characterClass
        self.chance = chance
        self.extraVigor = extraVigor
    }

    private enum CodingKeys: String, CodingKey {
        case characterClass = "class"
        case chance, extraVigor
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        characterClass = try c.decode(String.self, forKey: .characterClass)
        chance         = try c.decode(Int.self, forKey: .chance)
        extraVigor     = try c.decode(Int.self, forKey: .extraVigor)
    }
}

public struct DefendTuningDTO: Codable, Sendable, Equatable {
    public let archerChipMultiplier: Double
    /// The archer's Defend melts into cover: dodge is multiplied by this for
    /// the round. A MULTIPLE of their own rating since Phase 8D, for the same
    /// reason as `shadowVeilDodgeMultiplier` — and this one is worse as a flat
    /// number, because Defend is available every round from level 1.
    public let archerDodgeMultiplier: Double
    /// Fraction of incoming damage the mage actually takes (0.4 = 60% off).
    public let mageBarrierDamageFraction: Double

    public init(archerChipMultiplier: Double, archerDodgeMultiplier: Double,
                mageBarrierDamageFraction: Double) {
        self.archerChipMultiplier = archerChipMultiplier
        self.archerDodgeMultiplier = archerDodgeMultiplier
        self.mageBarrierDamageFraction = mageBarrierDamageFraction
    }

    private enum CodingKeys: String, CodingKey {
        case archerChipMultiplier, archerDodgeMultiplier, mageBarrierDamageFraction
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        archerChipMultiplier      = try c.decode(Double.self, forKey: .archerChipMultiplier)
        archerDodgeMultiplier     = try c.decode(Double.self, forKey: .archerDodgeMultiplier)
        mageBarrierDamageFraction = try c.decode(Double.self, forKey: .mageBarrierDamageFraction)
    }
}

public struct CombatTuningDTO: Codable, Sendable {
    public let hitChance: HitChanceDTO
    public let curves: CombatCurvesDTO
    public let levelDiff: LevelDiffDTO
    public let critMultiplier: Double
    public let variance: VarianceDTO
    public let defendChipFraction: Double
    /// Enemy the Training Ground spawns. A content REFERENCE living in a tuning
    /// file — the validator resolves it against `enemies.json`, the same way it
    /// resolves a recipe input.
    public let trainingDummyEnemyId: String
    public let techniques: [TechniqueTuningDTO]
    public let stances: StanceSectionDTO
    public let specialAttack: [SpecialAttackTuningDTO]
    public let specialDefense: SpecialDefenseSectionDTO
    public let flee: [FleeTuningDTO]
    public let defend: DefendTuningDTO

    public init(hitChance: HitChanceDTO, curves: CombatCurvesDTO, levelDiff: LevelDiffDTO,
                critMultiplier: Double, variance: VarianceDTO,
                defendChipFraction: Double, trainingDummyEnemyId: String,
                techniques: [TechniqueTuningDTO], stances: StanceSectionDTO,
                specialAttack: [SpecialAttackTuningDTO],
                specialDefense: SpecialDefenseSectionDTO,
                flee: [FleeTuningDTO], defend: DefendTuningDTO) {
        self.hitChance = hitChance
        self.curves = curves
        self.levelDiff = levelDiff
        self.critMultiplier = critMultiplier
        self.variance = variance
        self.defendChipFraction = defendChipFraction
        self.trainingDummyEnemyId = trainingDummyEnemyId
        self.techniques = techniques
        self.stances = stances
        self.specialAttack = specialAttack
        self.specialDefense = specialDefense
        self.flee = flee
        self.defend = defend
    }

    private enum CodingKeys: String, CodingKey {
        case hitChance, curves, levelDiff, critMultiplier, variance
        case defendChipFraction, trainingDummyEnemyId
        case techniques, stances, specialAttack, specialDefense, flee, defend
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        hitChance            = try c.decode(HitChanceDTO.self, forKey: .hitChance)
        curves               = try c.decode(CombatCurvesDTO.self, forKey: .curves)
        levelDiff            = try c.decode(LevelDiffDTO.self, forKey: .levelDiff)
        critMultiplier       = try c.decode(Double.self, forKey: .critMultiplier)
        variance             = try c.decode(VarianceDTO.self, forKey: .variance)
        defendChipFraction   = try c.decode(Double.self, forKey: .defendChipFraction)
        trainingDummyEnemyId = try c.decode(String.self, forKey: .trainingDummyEnemyId)
        techniques           = try c.decode([TechniqueTuningDTO].self, forKey: .techniques)
        stances              = try c.decode(StanceSectionDTO.self, forKey: .stances)
        specialAttack        = try c.decode([SpecialAttackTuningDTO].self, forKey: .specialAttack)
        specialDefense       = try c.decode(SpecialDefenseSectionDTO.self, forKey: .specialDefense)
        flee                 = try c.decode([FleeTuningDTO].self, forKey: .flee)
        defend               = try c.decode(DefendTuningDTO.self, forKey: .defend)
    }
}

// MARK: - vigor.json

/// Vigor charged per action. One required field per `VigorAction` case,
/// including `idle`, whose cost is 0 — a zero that is *stated* rather than
/// inferred from an absent key, so adding a case and forgetting the number is
/// a decode failure instead of a free action.
public struct VigorDrainDTO: Codable, Sendable, Equatable {
    public let walkRoom: Int
    public let walkRoomDoubleSpeed: Int
    public let combatRound: Int
    public let combatAttack: Int
    public let combatDefend: Int
    public let combatFlee: Int
    public let idle: Int

    public init(walkRoom: Int, walkRoomDoubleSpeed: Int, combatRound: Int,
                combatAttack: Int, combatDefend: Int, combatFlee: Int, idle: Int) {
        self.walkRoom = walkRoom
        self.walkRoomDoubleSpeed = walkRoomDoubleSpeed
        self.combatRound = combatRound
        self.combatAttack = combatAttack
        self.combatDefend = combatDefend
        self.combatFlee = combatFlee
        self.idle = idle
    }

    private enum CodingKeys: String, CodingKey {
        case walkRoom, walkRoomDoubleSpeed, combatRound
        case combatAttack, combatDefend, combatFlee, idle
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        walkRoom            = try c.decode(Int.self, forKey: .walkRoom)
        walkRoomDoubleSpeed = try c.decode(Int.self, forKey: .walkRoomDoubleSpeed)
        combatRound         = try c.decode(Int.self, forKey: .combatRound)
        combatAttack        = try c.decode(Int.self, forKey: .combatAttack)
        combatDefend        = try c.decode(Int.self, forKey: .combatDefend)
        combatFlee          = try c.decode(Int.self, forKey: .combatFlee)
        idle                = try c.decode(Int.self, forKey: .idle)
    }
}

public struct StarvationDTO: Codable, Sendable, Equatable {
    /// Fraction subtracted from ATK and DEF while at zero vigor (0.25 = −25%).
    public let statPenalty: Double
    /// Fraction of max HP lost per room transition while starving.
    public let hpDrainPercent: Double

    public init(statPenalty: Double, hpDrainPercent: Double) {
        self.statPenalty = statPenalty
        self.hpDrainPercent = hpDrainPercent
    }

    private enum CodingKeys: String, CodingKey { case statPenalty, hpDrainPercent }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        statPenalty    = try c.decode(Double.self, forKey: .statPenalty)
        hpDrainPercent = try c.decode(Double.self, forKey: .hpDrainPercent)
    }
}

/// Idle HP regeneration. Lives in `vigor.json` rather than a file of its own:
/// this table is the player's whole resource-recovery model, and splitting the
/// two halves of "resting restores you" across two files is how they drift.
public struct HealingTuningDTO: Codable, Sendable, Equatable {
    public let regenPerMinute: Double
    public let maxIdleMinutes: Double

    public init(regenPerMinute: Double, maxIdleMinutes: Double) {
        self.regenPerMinute = regenPerMinute
        self.maxIdleMinutes = maxIdleMinutes
    }

    private enum CodingKeys: String, CodingKey { case regenPerMinute, maxIdleMinutes }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        regenPerMinute = try c.decode(Double.self, forKey: .regenPerMinute)
        maxIdleMinutes = try c.decode(Double.self, forKey: .maxIdleMinutes)
    }
}

public struct VigorTuningDTO: Codable, Sendable {
    public let drain: VigorDrainDTO
    public let starvation: StarvationDTO
    public let healing: HealingTuningDTO

    public init(drain: VigorDrainDTO, starvation: StarvationDTO, healing: HealingTuningDTO) {
        self.drain = drain
        self.starvation = starvation
        self.healing = healing
    }

    private enum CodingKeys: String, CodingKey { case drain, starvation, healing }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        drain      = try c.decode(VigorDrainDTO.self, forKey: .drain)
        starvation = try c.decode(StarvationDTO.self, forKey: .starvation)
        healing    = try c.decode(HealingTuningDTO.self, forKey: .healing)
    }
}

// MARK: - exploration.json

/// One row of the revisit-decay table. See the note at the top of this file for
/// why the lookup is "exact match, else the LAST row".
public struct EventWeightTierDTO: Codable, Sendable, Equatable {
    public let priorVisits: Int
    public let nothing: Int
    public let loot: Int
    public let encounter: Int
    public let trip: Int

    public init(priorVisits: Int, nothing: Int, loot: Int, encounter: Int, trip: Int) {
        self.priorVisits = priorVisits
        self.nothing = nothing
        self.loot = loot
        self.encounter = encounter
        self.trip = trip
    }

    private enum CodingKeys: String, CodingKey { case priorVisits, nothing, loot, encounter, trip }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        priorVisits = try c.decode(Int.self, forKey: .priorVisits)
        nothing     = try c.decode(Int.self, forKey: .nothing)
        loot        = try c.decode(Int.self, forKey: .loot)
        encounter   = try c.decode(Int.self, forKey: .encounter)
        trip        = try c.decode(Int.self, forKey: .trip)
    }
}

/// How a passive (offline) expedition is discounted against active play.
///
/// Without these, the mode that needs no attention was measured 53% MORE
/// efficient than the one that does: it charged one Vigor per combat round
/// instead of two AND always rolled the fresh-room table, which no active
/// player can do twice in the same room. A game where ignoring it beats playing
/// it has no reason to be played.
///
/// Materials stay at 100% deliberately. The passive run is the floor — it should
/// keep the estate supplied and the crafting loop alive — while XP and silver,
/// the two progression currencies, are where active play earns its premium.
public struct PassiveExpeditionTuningDTO: Codable, Sendable, Equatable {
    public let xpMultiplier: Double
    public let lootMultiplier: Double
    /// Steps past this index roll the decayed weight tier instead of the fresh
    /// one, so an unattended walk cannot keep harvesting first-visit odds.
    public let freshStepCount: Int

    public init(xpMultiplier: Double,
                lootMultiplier: Double, freshStepCount: Int) {
        self.xpMultiplier = xpMultiplier
        self.lootMultiplier = lootMultiplier
        self.freshStepCount = freshStepCount
    }

    private enum CodingKeys: String, CodingKey {
        case xpMultiplier, lootMultiplier, freshStepCount
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        xpMultiplier     = try c.decode(Double.self, forKey: .xpMultiplier)
        lootMultiplier   = try c.decode(Double.self, forKey: .lootMultiplier)
        freshStepCount   = try c.decode(Int.self, forKey: .freshStepCount)
    }
}

public struct ExplorationTuningDTO: Codable, Sendable {
    /// The RNG range a step rolls in. Every tier's four weights must sum to it,
    /// or the last bucket silently absorbs the remainder.
    public let eventWeightTotal: Int
    /// Trip damage as a fraction of max HP.
    public let tripDamagePercent: Double
    public let weightTiers: [EventWeightTierDTO]
    public let passive: PassiveExpeditionTuningDTO

    public init(eventWeightTotal: Int, tripDamagePercent: Double,
                weightTiers: [EventWeightTierDTO],
                passive: PassiveExpeditionTuningDTO) {
        self.eventWeightTotal = eventWeightTotal
        self.tripDamagePercent = tripDamagePercent
        self.weightTiers = weightTiers
        self.passive = passive
    }

    private enum CodingKeys: String, CodingKey {
        case eventWeightTotal, tripDamagePercent, weightTiers, passive
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        eventWeightTotal  = try c.decode(Int.self, forKey: .eventWeightTotal)
        tripDamagePercent = try c.decode(Double.self, forKey: .tripDamagePercent)
        weightTiers       = try c.decode([EventWeightTierDTO].self, forKey: .weightTiers)
        passive           = try c.decode(PassiveExpeditionTuningDTO.self, forKey: .passive)
    }
}

// MARK: - progression.json

/// XP to advance from level L to L+1: `max(round(coefficient · L^exponent),
/// floorPerLevel · L)`.
///
/// A power law, not the old compounding loop. The compounding curve had no
/// relationship to XP SUPPLY: it asked 868,585 XP to reach level 21 while the
/// best monster in the game gave 175, which is 4,963 kills — and the last level
/// alone was 1,422 rabid bears. This curve was fitted to the measured Vigor
/// budget instead, so days-per-level rises 0.38 → 5.5 smoothly with no wall.
///
/// `floorPerLevel` only bites on levels 1–3, where the power term is still
/// smaller than a single kill.
public struct XPCurveDTO: Codable, Sendable, Equatable {
    public let coefficient: Double
    public let exponent: Double
    public let floorPerLevel: Int

    public init(coefficient: Double, exponent: Double, floorPerLevel: Int) {
        self.coefficient = coefficient
        self.exponent = exponent
        self.floorPerLevel = floorPerLevel
    }

    private enum CodingKeys: String, CodingKey { case coefficient, exponent, floorPerLevel }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        coefficient   = try c.decode(Double.self, forKey: .coefficient)
        exponent      = try c.decode(Double.self, forKey: .exponent)
        floorPerLevel = try c.decode(Int.self, forKey: .floorPerLevel)
    }
}

/// XP a monster awards: `round(coefficient · level^exponent · archetypeXP)`.
///
/// Design-time input — the value is baked into each enemy's `xpReward` — but it
/// lives here, beside `xpCurve`, because the two are SOLVED AS A PAIR. The
/// exponent is not free: it has to satisfy
/// `curveExponent − mobExponent − 0.45 (fights/day slope) − 0.30 (mix slope)
/// = days-per-level slope`. Choosing both independently produces an arbitrary
/// pacing shape; two are chosen and the third is solved. Storing them apart
/// would invite exactly that.
public struct MobXPDTO: Codable, Sendable, Equatable {
    public let coefficient: Double
    public let exponent: Double

    public init(coefficient: Double, exponent: Double) {
        self.coefficient = coefficient
        self.exponent = exponent
    }

    private enum CodingKeys: String, CodingKey { case coefficient, exponent }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        coefficient = try c.decode(Double.self, forKey: .coefficient)
        exponent    = try c.decode(Double.self, forKey: .exponent)
    }
}

/// XP scaling for out-levelling a monster:
/// `clamp(1 − perLevel · (playerLevel − monsterLevel), min, max)`.
///
/// REQUIRED, not optional polish. Without it a level-40 player farming level-30
/// monsters keeps 67% of the XP for a fight that is 35% faster and 40% safer —
/// shallow farming becomes strictly optimal and the entire depth ladder turns
/// into dead content.
public struct XPLevelDiffDTO: Codable, Sendable, Equatable {
    public let perLevel: Double
    public let min: Double
    public let max: Double

    public init(perLevel: Double, min: Double, max: Double) {
        self.perLevel = perLevel
        self.min = min
        self.max = max
    }

    private enum CodingKeys: String, CodingKey { case perLevel, min, max }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        perLevel = try c.decode(Double.self, forKey: .perLevel)
        min      = try c.decode(Double.self, forKey: .min)
        max      = try c.decode(Double.self, forKey: .max)
    }
}

/// Per-level stat growth, as a FRACTION OF THE BASE added per level above 1:
/// `stat(L) = base × (1 + rate × (L − 1))`.
///
/// Proportional, not flat, and that is the whole point. Under flat growth a
/// warrior's dodge RATING rises while its dodge PERCENT falls — 5.3% at level 1
/// down to 1.4% at level 40 — because the diminishing-returns denominator grows
/// with level and a flat rating cannot keep up. The number on the profile screen
/// goes up while the effect quietly disappears, which a player reads as a bug.
/// Scaling ratings at the same rate as the denominator holds the percentage
/// steady instead.
///
/// `ratingPerLevel` covers DEF, crit, dodge and accuracy together: they share
/// the item-budget slope the denominators were derived from, so splitting them
/// would let one rot independently.
public struct StatGrowthDTO: Codable, Sendable, Equatable {
    public let hpPerLevel: Double
    public let attackPerLevel: Double
    public let ratingPerLevel: Double

    public init(hpPerLevel: Double, attackPerLevel: Double, ratingPerLevel: Double) {
        self.hpPerLevel = hpPerLevel
        self.attackPerLevel = attackPerLevel
        self.ratingPerLevel = ratingPerLevel
    }

    private enum CodingKeys: String, CodingKey { case hpPerLevel, attackPerLevel, ratingPerLevel }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        hpPerLevel     = try c.decode(Double.self, forKey: .hpPerLevel)
        attackPerLevel = try c.decode(Double.self, forKey: .attackPerLevel)
        ratingPerLevel = try c.decode(Double.self, forKey: .ratingPerLevel)
    }
}

/// The Vigor pool and how fast it refills on its own.
///
/// `perLevel` matters as much as `base`: a flat pool means the regen rate,
/// expressed as a share of the pool, shrinks every level — the plan measured a
/// flat 8/hour degenerating to 2.7%/hour at the cap. Scaling the pool with level
/// and stating regen as "the whole pool in N hours" keeps the felt recovery rate
/// constant for the player's whole life.
/// The Vigor pool. A STOCK, not an income: since Phase 8E nothing refills it
/// on a clock, so `base + perLevel × level` is the most a player can be holding
/// at once and food is the only way to top it back up.
public struct VigorPoolDTO: Codable, Sendable, Equatable {
    public let base: Int
    public let perLevel: Int

    public init(base: Int, perLevel: Int) {
        self.base = base
        self.perLevel = perLevel
    }

    private enum CodingKeys: String, CodingKey { case base, perLevel }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        base     = try c.decode(Int.self, forKey: .base)
        perLevel = try c.decode(Int.self, forKey: .perLevel)
    }
}

/// Level-1 stat line plus the weapon the King's Oath hands out. The weapon id
/// is a content reference; the validator resolves it and checks it is a
/// main-hand item, which is what `liveLookupCheck` asserts at runtime today.
public struct ClassStartDTO: Codable, Sendable, Equatable {
    public let characterClass: String
    public let hp: Int
    public let attack: Int
    public let defense: Int
    public let crit: Int
    public let dodge: Int
    public let accuracy: Int
    public let starterWeaponId: String

    public init(characterClass: String, hp: Int, attack: Int, defense: Int,
                crit: Int, dodge: Int, accuracy: Int, starterWeaponId: String) {
        self.characterClass = characterClass
        self.hp = hp
        self.attack = attack
        self.defense = defense
        self.crit = crit
        self.dodge = dodge
        self.accuracy = accuracy
        self.starterWeaponId = starterWeaponId
    }

    private enum CodingKeys: String, CodingKey {
        case characterClass = "class"
        case hp, attack, defense, crit, dodge, accuracy, starterWeaponId
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        characterClass  = try c.decode(String.self, forKey: .characterClass)
        hp              = try c.decode(Int.self, forKey: .hp)
        attack          = try c.decode(Int.self, forKey: .attack)
        defense         = try c.decode(Int.self, forKey: .defense)
        crit            = try c.decode(Int.self, forKey: .crit)
        dodge           = try c.decode(Int.self, forKey: .dodge)
        accuracy        = try c.decode(Int.self, forKey: .accuracy)
        starterWeaponId = try c.decode(String.self, forKey: .starterWeaponId)
    }
}

public struct ProgressionTuningDTO: Codable, Sendable {
    public let maxLevel: Int
    public let xpCurve: XPCurveDTO
    public let mobXP: MobXPDTO
    public let xpLevelDiff: XPLevelDiffDTO
    public let statGrowth: StatGrowthDTO
    public let vigorPool: VigorPoolDTO
    public let classes: [ClassStartDTO]
    /// Warehouse unit cap indexed by estate level (level 1 = index 0). Estates
    /// past the end of the table clamp to the last entry, so the array length
    /// is itself the top tier.
    public let warehouseCapByEstateLevel: [Int]

    public init(maxLevel: Int, xpCurve: XPCurveDTO, mobXP: MobXPDTO,
                xpLevelDiff: XPLevelDiffDTO, statGrowth: StatGrowthDTO,
                vigorPool: VigorPoolDTO, classes: [ClassStartDTO],
                warehouseCapByEstateLevel: [Int]) {
        self.maxLevel = maxLevel
        self.xpCurve = xpCurve
        self.mobXP = mobXP
        self.xpLevelDiff = xpLevelDiff
        self.statGrowth = statGrowth
        self.vigorPool = vigorPool
        self.classes = classes
        self.warehouseCapByEstateLevel = warehouseCapByEstateLevel
    }

    private enum CodingKeys: String, CodingKey {
        case maxLevel, xpCurve, mobXP, xpLevelDiff, statGrowth, vigorPool
        case classes, warehouseCapByEstateLevel
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        maxLevel                  = try c.decode(Int.self, forKey: .maxLevel)
        xpCurve                   = try c.decode(XPCurveDTO.self, forKey: .xpCurve)
        mobXP                     = try c.decode(MobXPDTO.self, forKey: .mobXP)
        xpLevelDiff               = try c.decode(XPLevelDiffDTO.self, forKey: .xpLevelDiff)
        statGrowth                = try c.decode(StatGrowthDTO.self, forKey: .statGrowth)
        vigorPool                 = try c.decode(VigorPoolDTO.self, forKey: .vigorPool)
        classes                   = try c.decode([ClassStartDTO].self, forKey: .classes)
        warehouseCapByEstateLevel = try c.decode([Int].self, forKey: .warehouseCapByEstateLevel)
    }
}

// MARK: - economy.json

/// The per-fight durability budget. One required field per `WearEvent` case.
public struct WearBudgetDTO: Codable, Sendable, Equatable {
    public let victory: Int
    public let defeat: Int
    public let flee: Int

    public init(victory: Int, defeat: Int, flee: Int) {
        self.victory = victory
        self.defeat = defeat
        self.flee = flee
    }

    private enum CodingKeys: String, CodingKey { case victory, defeat, flee }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        victory = try c.decode(Int.self, forKey: .victory)
        defeat  = try c.decode(Int.self, forKey: .defeat)
        flee    = try c.decode(Int.self, forKey: .flee)
    }
}

public struct GearEconomyDTO: Codable, Sendable, Equatable {
    /// Durability a fresh piece starts (and is repaired back) to.
    public let maxDurabilityStart: Int
    /// Permanent max-durability loss per repair, so armor eventually wears out.
    public let repairMaxShave: Int
    public let wearBudget: WearBudgetDTO

    public init(maxDurabilityStart: Int, repairMaxShave: Int, wearBudget: WearBudgetDTO) {
        self.maxDurabilityStart = maxDurabilityStart
        self.repairMaxShave = repairMaxShave
        self.wearBudget = wearBudget
    }

    private enum CodingKeys: String, CodingKey {
        case maxDurabilityStart, repairMaxShave, wearBudget
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        maxDurabilityStart = try c.decode(Int.self, forKey: .maxDurabilityStart)
        repairMaxShave     = try c.decode(Int.self, forKey: .repairMaxShave)
        wearBudget         = try c.decode(WearBudgetDTO.self, forKey: .wearBudget)
    }
}

/// How a daily job's authored reward grows with the player's level. The XP and
/// Vigor sides need no constant of their own: XP rides the `mobXP` exponent so
/// a job stays worth the same number of kills at every level, and Vigor rides
/// the pool it refills.
public struct QuestRewardTuningDTO: Codable, Sendable, Equatable {
    /// Silver multiplier per level above 1: `base × (1 + rate × (L − 1))`.
    public let silverPerLevel: Double

    public init(silverPerLevel: Double) {
        self.silverPerLevel = silverPerLevel
    }

    private enum CodingKeys: String, CodingKey { case silverPerLevel }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        silverPerLevel = try c.decode(Double.self, forKey: .silverPerLevel)
    }
}

public struct EconomyTuningDTO: Codable, Sendable {
    public let gear: GearEconomyDTO
    public let questRewards: QuestRewardTuningDTO

    public init(gear: GearEconomyDTO, questRewards: QuestRewardTuningDTO) {
        self.gear = gear
        self.questRewards = questRewards
    }

    private enum CodingKeys: String, CodingKey { case gear, questRewards }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        gear = try c.decode(GearEconomyDTO.self, forKey: .gear)
        questRewards = try c.decode(QuestRewardTuningDTO.self, forKey: .questRewards)
    }
}

// MARK: - time.json

public struct PassiveExpeditionTimeDTO: Codable, Sendable, Equatable {
    public let unitsPerStep: Int
    /// Real seconds one duration unit represents at scale 1.
    public let secondsPerUnit: Double

    public init(unitsPerStep: Int, secondsPerUnit: Double) {
        self.unitsPerStep = unitsPerStep
        self.secondsPerUnit = secondsPerUnit
    }

    private enum CodingKeys: String, CodingKey { case unitsPerStep, secondsPerUnit }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        unitsPerStep   = try c.decode(Int.self, forKey: .unitsPerStep)
        secondsPerUnit = try c.decode(Double.self, forKey: .secondsPerUnit)
    }
}

/// How often the plot-production ticker wakes.
///
/// DERIVED, not stored: `max(minSeconds, plotIntervalSeconds / intervalDivisor)`.
/// The sweeper is a database polling cadence, not a game-time gate, so scaling
/// it alongside game time is wrong in both directions — but it must never be
/// SLOWER than the interval it sweeps, or a filled plot waits a whole extra
/// cycle to be announced. Deriving it from the interval makes that invariant
/// hold by construction instead of by a validator rule someone has to remember.
///
/// The two numbers are calibrated to reproduce both shipped values exactly:
/// at scale 1 the interval is 3600 s → 3600/12 = 300 s (production today), and
/// at scale 60 it is 60 s → floored to 60 s (test mode today).
public struct PlotSweeperDTO: Codable, Sendable, Equatable {
    public let intervalDivisor: Int
    public let minSeconds: Double

    public init(intervalDivisor: Int, minSeconds: Double) {
        self.intervalDivisor = intervalDivisor
        self.minSeconds = minSeconds
    }

    private enum CodingKeys: String, CodingKey { case intervalDivisor, minSeconds }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        intervalDivisor = try c.decode(Int.self, forKey: .intervalDivisor)
        minSeconds      = try c.decode(Double.self, forKey: .minSeconds)
    }
}

/// Durations `time.scale` compresses. Every value here is stated at scale 1 —
/// i.e. in the units a released build runs at — so the file reads as the real
/// game even while the dev bundle runs compressed.
public struct GameTimeDTO: Codable, Sendable, Equatable {
    public let travelMinutes: Int
    public let passiveExpedition: PassiveExpeditionTimeDTO
    public let plotIntervalSeconds: Double
    public let plotSweeper: PlotSweeperDTO

    public init(travelMinutes: Int, passiveExpedition: PassiveExpeditionTimeDTO,
                plotIntervalSeconds: Double, plotSweeper: PlotSweeperDTO) {
        self.travelMinutes = travelMinutes
        self.passiveExpedition = passiveExpedition
        self.plotIntervalSeconds = plotIntervalSeconds
        self.plotSweeper = plotSweeper
    }

    private enum CodingKeys: String, CodingKey {
        case travelMinutes, passiveExpedition, plotIntervalSeconds, plotSweeper
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        travelMinutes       = try c.decode(Int.self, forKey: .travelMinutes)
        passiveExpedition   = try c.decode(PassiveExpeditionTimeDTO.self, forKey: .passiveExpedition)
        plotIntervalSeconds = try c.decode(Double.self, forKey: .plotIntervalSeconds)
        plotSweeper         = try c.decode(PlotSweeperDTO.self, forKey: .plotSweeper)
    }
}

/// Wall-clock constants `time.scale` must NEVER touch.
///
/// `tavernDeletableAfter` is the reason this section exists as its own type
/// rather than a comment: Telegram refuses to delete a private-chat dice
/// message younger than 24 h, so that number is a PROTOCOL constant. Scaling it
/// would not rebalance the tavern, it would break the sweep — every delete
/// would fail and the rows would pile up forever. The trade TTLs and the game-
/// day rollover are the same kind of thing: they are anchored to how long a
/// human waits and to a wall-clock hour, not to game pacing.
public struct RealTimeDTO: Codable, Sendable, Equatable {
    public let tradeLobbyTTL: Double
    public let tradeSessionTTL: Double
    public let tradeSweepInterval: Double
    public let tavernDeletableAfter: Double
    public let tavernSweepInterval: Double
    public let dayRolloverHour: Int
    public let dayTimeZoneId: String

    public init(tradeLobbyTTL: Double, tradeSessionTTL: Double, tradeSweepInterval: Double,
                tavernDeletableAfter: Double, tavernSweepInterval: Double,
                dayRolloverHour: Int, dayTimeZoneId: String) {
        self.tradeLobbyTTL = tradeLobbyTTL
        self.tradeSessionTTL = tradeSessionTTL
        self.tradeSweepInterval = tradeSweepInterval
        self.tavernDeletableAfter = tavernDeletableAfter
        self.tavernSweepInterval = tavernSweepInterval
        self.dayRolloverHour = dayRolloverHour
        self.dayTimeZoneId = dayTimeZoneId
    }

    private enum CodingKeys: String, CodingKey {
        case tradeLobbyTTL, tradeSessionTTL, tradeSweepInterval
        case tavernDeletableAfter, tavernSweepInterval, dayRolloverHour, dayTimeZoneId
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        tradeLobbyTTL        = try c.decode(Double.self, forKey: .tradeLobbyTTL)
        tradeSessionTTL      = try c.decode(Double.self, forKey: .tradeSessionTTL)
        tradeSweepInterval   = try c.decode(Double.self, forKey: .tradeSweepInterval)
        tavernDeletableAfter = try c.decode(Double.self, forKey: .tavernDeletableAfter)
        tavernSweepInterval  = try c.decode(Double.self, forKey: .tavernSweepInterval)
        dayRolloverHour      = try c.decode(Int.self, forKey: .dayRolloverHour)
        dayTimeZoneId        = try c.decode(String.self, forKey: .dayTimeZoneId)
    }
}

public struct TimeTuningDTO: Codable, Sendable {
    /// How many times faster than real life the game runs. 1.0 is release
    /// pacing; the dev bundle runs 60, so a "minute" of travel takes a second.
    ///
    /// The single owner of that number, replacing the three independent
    /// `testMode` booleans this file's `gameTime` section supersedes. They were
    /// never one scale: two of them were 60× while the plot sweeper's was 5×,
    /// which is why folding them was a commit of its own rather than a rename.
    /// `manifest.json` no longer carries `timeScale` — one knob, one home.
    public let scale: Double
    public let gameTime: GameTimeDTO
    public let realTime: RealTimeDTO

    public init(scale: Double, gameTime: GameTimeDTO, realTime: RealTimeDTO) {
        self.scale = scale
        self.gameTime = gameTime
        self.realTime = realTime
    }

    private enum CodingKeys: String, CodingKey { case scale, gameTime, realTime }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        scale    = try c.decode(Double.self, forKey: .scale)
        gameTime = try c.decode(GameTimeDTO.self, forKey: .gameTime)
        realTime = try c.decode(RealTimeDTO.self, forKey: .realTime)
    }
}

// MARK: - The six tables as one value

/// Everything under `content/data/tuning/`. Bundled into one struct so the
/// loader, the bundle and the snapshot each carry a single field rather than
/// six that can be wired up half-way.
public struct TuningBundleDTO: Sendable {
    public let combat: CombatTuningDTO
    public let vigor: VigorTuningDTO
    public let exploration: ExplorationTuningDTO
    public let progression: ProgressionTuningDTO
    public let economy: EconomyTuningDTO
    public let time: TimeTuningDTO

    public init(combat: CombatTuningDTO, vigor: VigorTuningDTO,
                exploration: ExplorationTuningDTO, progression: ProgressionTuningDTO,
                economy: EconomyTuningDTO, time: TimeTuningDTO) {
        self.combat = combat
        self.vigor = vigor
        self.exploration = exploration
        self.progression = progression
        self.economy = economy
        self.time = time
    }
}
