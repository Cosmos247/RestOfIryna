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

/// One Super stance: which class triggers it, what it costs, and the seven
/// modifier fields it applies for `durationRounds`.
public struct StanceTuningDTO: Codable, Sendable, Equatable {
    public let id: String
    public let characterClass: String
    public let activationVigor: Int
    public let attackMultiplier: Double
    public let attackBonus: Int
    public let defenseBonus: Int
    public let critBonus: Int
    public let accuracyBonus: Int
    public let dodgeBonus: Int
    public let vigorMultiplier: Double

    public init(id: String, characterClass: String, activationVigor: Int,
                attackMultiplier: Double, attackBonus: Int, defenseBonus: Int,
                critBonus: Int, accuracyBonus: Int, dodgeBonus: Int, vigorMultiplier: Double) {
        self.id = id
        self.characterClass = characterClass
        self.activationVigor = activationVigor
        self.attackMultiplier = attackMultiplier
        self.attackBonus = attackBonus
        self.defenseBonus = defenseBonus
        self.critBonus = critBonus
        self.accuracyBonus = accuracyBonus
        self.dodgeBonus = dodgeBonus
        self.vigorMultiplier = vigorMultiplier
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case characterClass = "class"
        case activationVigor, attackMultiplier, attackBonus, defenseBonus
        case critBonus, accuracyBonus, dodgeBonus, vigorMultiplier
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id               = try c.decode(String.self, forKey: .id)
        characterClass   = try c.decode(String.self, forKey: .characterClass)
        activationVigor  = try c.decode(Int.self, forKey: .activationVigor)
        attackMultiplier = try c.decode(Double.self, forKey: .attackMultiplier)
        attackBonus      = try c.decode(Int.self, forKey: .attackBonus)
        defenseBonus     = try c.decode(Int.self, forKey: .defenseBonus)
        critBonus        = try c.decode(Int.self, forKey: .critBonus)
        accuracyBonus    = try c.decode(Int.self, forKey: .accuracyBonus)
        dodgeBonus       = try c.decode(Int.self, forKey: .dodgeBonus)
        vigorMultiplier  = try c.decode(Double.self, forKey: .vigorMultiplier)
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

/// Per-class Special Attack: the vigor price plus the five `AttackModifiers`
/// fields and the dodge-forfeit flag.
public struct SpecialAttackTuningDTO: Codable, Sendable, Equatable {
    public let characterClass: String
    public let vigor: Int
    public let hitChanceModifier: Int
    public let defenderDEFFraction: Double
    public let critBonus: Int
    public let cannotMiss: Bool
    public let flatDamageBonus: Int
    /// True when unleashing the technique zeroes the player's dodge for the
    /// enemy's counter that round (the archer's long aim).
    public let zeroesDodge: Bool

    public init(characterClass: String, vigor: Int, hitChanceModifier: Int,
                defenderDEFFraction: Double, critBonus: Int, cannotMiss: Bool,
                flatDamageBonus: Int, zeroesDodge: Bool) {
        self.characterClass = characterClass
        self.vigor = vigor
        self.hitChanceModifier = hitChanceModifier
        self.defenderDEFFraction = defenderDEFFraction
        self.critBonus = critBonus
        self.cannotMiss = cannotMiss
        self.flatDamageBonus = flatDamageBonus
        self.zeroesDodge = zeroesDodge
    }

    private enum CodingKeys: String, CodingKey {
        case characterClass = "class"
        case vigor, hitChanceModifier, defenderDEFFraction, critBonus
        case cannotMiss, flatDamageBonus, zeroesDodge
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        characterClass      = try c.decode(String.self, forKey: .characterClass)
        vigor               = try c.decode(Int.self, forKey: .vigor)
        hitChanceModifier   = try c.decode(Int.self, forKey: .hitChanceModifier)
        defenderDEFFraction = try c.decode(Double.self, forKey: .defenderDEFFraction)
        critBonus           = try c.decode(Int.self, forKey: .critBonus)
        cannotMiss          = try c.decode(Bool.self, forKey: .cannotMiss)
        flatDamageBonus     = try c.decode(Int.self, forKey: .flatDamageBonus)
        zeroesDodge         = try c.decode(Bool.self, forKey: .zeroesDodge)
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
    public let shadowVeilDodgeBonus: Int
    public let mirrorWardReflectFraction: Double
    public let byClass: [SpecialDefenseClassDTO]

    public init(effectPersistRounds: Int, ironBulwarkChipFraction: Double,
                shadowVeilDodgeBonus: Int, mirrorWardReflectFraction: Double,
                byClass: [SpecialDefenseClassDTO]) {
        self.effectPersistRounds = effectPersistRounds
        self.ironBulwarkChipFraction = ironBulwarkChipFraction
        self.shadowVeilDodgeBonus = shadowVeilDodgeBonus
        self.mirrorWardReflectFraction = mirrorWardReflectFraction
        self.byClass = byClass
    }

    private enum CodingKeys: String, CodingKey {
        case effectPersistRounds, ironBulwarkChipFraction
        case shadowVeilDodgeBonus, mirrorWardReflectFraction, byClass
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        effectPersistRounds       = try c.decode(Int.self, forKey: .effectPersistRounds)
        ironBulwarkChipFraction   = try c.decode(Double.self, forKey: .ironBulwarkChipFraction)
        shadowVeilDodgeBonus      = try c.decode(Int.self, forKey: .shadowVeilDodgeBonus)
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
    public let archerDodgeBonus: Int
    /// Fraction of incoming damage the mage actually takes (0.4 = 60% off).
    public let mageBarrierDamageFraction: Double

    public init(archerChipMultiplier: Double, archerDodgeBonus: Int,
                mageBarrierDamageFraction: Double) {
        self.archerChipMultiplier = archerChipMultiplier
        self.archerDodgeBonus = archerDodgeBonus
        self.mageBarrierDamageFraction = mageBarrierDamageFraction
    }

    private enum CodingKeys: String, CodingKey {
        case archerChipMultiplier, archerDodgeBonus, mageBarrierDamageFraction
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        archerChipMultiplier      = try c.decode(Double.self, forKey: .archerChipMultiplier)
        archerDodgeBonus          = try c.decode(Int.self, forKey: .archerDodgeBonus)
        mageBarrierDamageFraction = try c.decode(Double.self, forKey: .mageBarrierDamageFraction)
    }
}

public struct CombatTuningDTO: Codable, Sendable {
    public let hitChance: HitChanceDTO
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

    public init(hitChance: HitChanceDTO, critMultiplier: Double, variance: VarianceDTO,
                defendChipFraction: Double, trainingDummyEnemyId: String,
                techniques: [TechniqueTuningDTO], stances: StanceSectionDTO,
                specialAttack: [SpecialAttackTuningDTO],
                specialDefense: SpecialDefenseSectionDTO,
                flee: [FleeTuningDTO], defend: DefendTuningDTO) {
        self.hitChance = hitChance
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
        case hitChance, critMultiplier, variance, defendChipFraction, trainingDummyEnemyId
        case techniques, stances, specialAttack, specialDefense, flee, defend
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        hitChance            = try c.decode(HitChanceDTO.self, forKey: .hitChance)
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

public struct ExplorationTuningDTO: Codable, Sendable {
    /// The RNG range a step rolls in. Every tier's four weights must sum to it,
    /// or the last bucket silently absorbs the remainder.
    public let eventWeightTotal: Int
    /// Trip damage as a fraction of max HP.
    public let tripDamagePercent: Double
    public let weightTiers: [EventWeightTierDTO]

    public init(eventWeightTotal: Int, tripDamagePercent: Double,
                weightTiers: [EventWeightTierDTO]) {
        self.eventWeightTotal = eventWeightTotal
        self.tripDamagePercent = tripDamagePercent
        self.weightTiers = weightTiers
    }

    private enum CodingKeys: String, CodingKey {
        case eventWeightTotal, tripDamagePercent, weightTiers
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        eventWeightTotal  = try c.decode(Int.self, forKey: .eventWeightTotal)
        tripDamagePercent = try c.decode(Double.self, forKey: .tripDamagePercent)
        weightTiers       = try c.decode([EventWeightTierDTO].self, forKey: .weightTiers)
    }
}

// MARK: - progression.json

/// The three constants inside `User.xpRequiredToReach`. The loop shape stays in
/// Swift — only the numbers move — but `doublingThroughLevel` is as much a
/// tuning knob as the multiplier: it is the level the curve stops doubling at.
public struct XPCurveDTO: Codable, Sendable, Equatable {
    public let firstLevelCost: Int
    public let doublingThroughLevel: Int
    public let growthMultiplier: Double

    public init(firstLevelCost: Int, doublingThroughLevel: Int, growthMultiplier: Double) {
        self.firstLevelCost = firstLevelCost
        self.doublingThroughLevel = doublingThroughLevel
        self.growthMultiplier = growthMultiplier
    }

    private enum CodingKeys: String, CodingKey {
        case firstLevelCost, doublingThroughLevel, growthMultiplier
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        firstLevelCost       = try c.decode(Int.self, forKey: .firstLevelCost)
        doublingThroughLevel = try c.decode(Int.self, forKey: .doublingThroughLevel)
        growthMultiplier     = try c.decode(Double.self, forKey: .growthMultiplier)
    }
}

public struct StatGrowthDTO: Codable, Sendable, Equatable {
    /// Levels that grant the boost. An ARRAY, not a set: JSON has no set, and
    /// the array is what makes the file reviewable in order.
    public let levels: [Int]
    public let maxHp: Int
    public let attack: Int
    public let defense: Int

    public init(levels: [Int], maxHp: Int, attack: Int, defense: Int) {
        self.levels = levels
        self.maxHp = maxHp
        self.attack = attack
        self.defense = defense
    }

    private enum CodingKeys: String, CodingKey { case levels, maxHp, attack, defense }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        levels  = try c.decode([Int].self, forKey: .levels)
        maxHp   = try c.decode(Int.self, forKey: .maxHp)
        attack  = try c.decode(Int.self, forKey: .attack)
        defense = try c.decode(Int.self, forKey: .defense)
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
    public let statGrowth: StatGrowthDTO
    public let classes: [ClassStartDTO]
    /// Warehouse unit cap indexed by estate level (level 1 = index 0). Estates
    /// past the end of the table clamp to the last entry, so the array length
    /// is itself the top tier.
    public let warehouseCapByEstateLevel: [Int]

    public init(maxLevel: Int, xpCurve: XPCurveDTO, statGrowth: StatGrowthDTO,
                classes: [ClassStartDTO], warehouseCapByEstateLevel: [Int]) {
        self.maxLevel = maxLevel
        self.xpCurve = xpCurve
        self.statGrowth = statGrowth
        self.classes = classes
        self.warehouseCapByEstateLevel = warehouseCapByEstateLevel
    }

    private enum CodingKeys: String, CodingKey {
        case maxLevel, xpCurve, statGrowth, classes, warehouseCapByEstateLevel
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        maxLevel                  = try c.decode(Int.self, forKey: .maxLevel)
        xpCurve                   = try c.decode(XPCurveDTO.self, forKey: .xpCurve)
        statGrowth                = try c.decode(StatGrowthDTO.self, forKey: .statGrowth)
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

public struct EconomyTuningDTO: Codable, Sendable {
    public let gear: GearEconomyDTO

    public init(gear: GearEconomyDTO) {
        self.gear = gear
    }

    private enum CodingKeys: String, CodingKey { case gear }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        gear = try c.decode(GearEconomyDTO.self, forKey: .gear)
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
