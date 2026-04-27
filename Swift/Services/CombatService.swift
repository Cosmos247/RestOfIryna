//
//  CombatService.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 25.04.2026.
//
//  Phase 4.1: shared damage primitives for the interactive PvE controller AND
//  the passive-mode autobattle. The active controller calls `applyAttack` once
//  per round per direction (player→enemy, enemy→player); `resolveAutobattle`
//  loops the same primitives until one side falls.
//
//  Single source of truth for hit / miss / crit math — keeps active and
//  passive expeditions in numerical sync (no surprise where the same fight
//  resolves differently depending on mode).
//

import Foundation

public enum AttackOutcome: Sendable {
    case miss
    case hit(damage: Int)
    case crit(damage: Int)
}

public enum CombatService {
    /// Base hit chance before accuracy/dodge modifiers (percent).
    public static let baseHitChance: Int = 70
    /// Floor and ceiling on hit chance so even a heavily out-statted side can
    /// land or miss occasionally (no 100/0 lock-ins).
    public static let minHitChance: Int = 10
    public static let maxHitChance: Int = 95
    /// Crit damage multiplier on a successful crit roll.
    public static let critMultiplier: Double = 1.5
    /// ±10% variance on every landed hit.
    public static let varianceRange: ClosedRange<Double> = 0.9...1.1
    /// Defend's parry/counter chip damage as a fraction of a clean hit. Always
    /// lands, never crits — flavour is "you mostly hold the line but tag it".
    public static let defendChipFraction: Double = 0.3

    /// Per-attack modifiers used by special techniques to bend the standard
    /// applyAttack roll without writing a new function. Defaults are no-ops
    /// so existing callers keep working unchanged.
    ///
    /// - `hitChanceModifier`: added to the clamped hit-chance roll (Cleave: -15)
    /// - `defenderDEFFraction`: scales enemy DEF before subtraction
    ///   (Cleave: 0.5 — armor-piercing; Vital Shot / Soulfire: 0.0 — ignore DEF)
    /// - `critBonus`: added to attacker crit % (Vital Shot: +20)
    /// - `cannotMiss`: if true, hit-chance roll is bypassed (Vital Shot, Soulfire)
    /// - `flatDamageBonus`: added to raw pre-variance damage (Soulfire: +5)
    public struct AttackModifiers: Sendable {
        public var hitChanceModifier: Int = 0
        public var defenderDEFFraction: Double = 1.0
        public var critBonus: Int = 0
        public var cannotMiss: Bool = false
        public var flatDamageBonus: Int = 0

        public init() {}
    }

    /// Roll a single attack. Damage variance, crit chance, and accuracy/dodge
    /// are baked in. Defender stats are passed in raw so the caller can boost
    /// them ad-hoc (e.g. doubling player's effective DEF on a Defend round).
    /// Optional `modifiers` are used by Phase 4.2 special techniques.
    public static func applyAttack(
        attackerATK: Int,
        attackerCrit: Int,
        attackerAcc: Int,
        defenderDEF: Int,
        defenderDodge: Int,
        modifiers: AttackModifiers = AttackModifiers()
    ) -> AttackOutcome {
        let hitChance: Int
        if modifiers.cannotMiss {
            hitChance = 100
        } else {
            hitChance = max(minHitChance, min(maxHitChance, baseHitChance + attackerAcc - defenderDodge + modifiers.hitChanceModifier))
        }
        if Int.random(in: 1...100) > hitChance {
            return .miss
        }

        let effectiveDEF = max(0, Int((Double(defenderDEF) * modifiers.defenderDEFFraction).rounded()))
        let raw = Double(max(1, attackerATK - effectiveDEF + modifiers.flatDamageBonus))
        let varied = raw * Double.random(in: varianceRange)

        let isCrit = Int.random(in: 1...100) <= max(0, attackerCrit + modifiers.critBonus)
        if isCrit {
            let damage = max(1, Int((varied * critMultiplier).rounded()))
            return .crit(damage: damage)
        }

        let damage = max(1, Int(varied.rounded()))
        return .hit(damage: damage)
    }

    /// Defend-mode chip damage. Always lands, never crits, scaled to
    /// `defendChipFraction` of a clean hit. Variance still applies so the
    /// number isn't pure deterministic.
    public static func chipDamage(attackerATK: Int, defenderDEF: Int) -> Int {
        let raw = Double(max(1, attackerATK - defenderDEF))
        let varied = raw * Double.random(in: varianceRange) * defendChipFraction
        return max(1, Int(varied.rounded()))
    }

    // MARK: - Phase 4.2 stance modifiers

    /// Per-round modifiers applied while a Super-technique stance is active.
    /// Composed by the caller on top of the player's effective stats:
    /// `buffedATK = effectiveATK * attackMultiplier + attackBonus` etc.
    /// `hungerMultiplier` scales the hunger drain on each combat action.
    public struct StanceModifiers: Sendable {
        public var attackMultiplier: Double = 1.0
        public var attackBonus: Int = 0
        public var defenseBonus: Int = 0
        public var critBonus: Int = 0
        public var accuracyBonus: Int = 0
        public var dodgeBonus: Int = 0
        public var hungerMultiplier: Double = 1.0

        public static let none = StanceModifiers()
    }

    /// Stance IDs persisted on `exploration_state.combat_stance`. Plain string
    /// constants (no enum) so adding more techniques later is a one-line
    /// change here + one branch in `stanceModifiers(for:)`.
    public enum StanceId {
        public static let bloodlust          = "bloodlust"           // warrior
        public static let hawksEye           = "hawks_eye"           // archer
        public static let arcaneResonance    = "arcane_resonance"    // mage
    }

    /// Activation hunger costs per stance — the price the player pays the
    /// moment they tap Super, on top of the round's regular drain. Mage
    /// "concentration burn" is more expensive than the warrior / archer
    /// supers (per Phase 4.2 spec).
    public static func stanceActivationHunger(for stanceId: String) -> Int {
        switch stanceId {
        case StanceId.arcaneResonance: return 5
        default: return 4
        }
    }

    /// Default duration in rounds for a freshly activated stance.
    public static let stanceDurationRounds: Int = 3

    /// Numeric tunings for each stance. Returned `StanceModifiers.none` for
    /// unknown / nil stance ids so callers can compose unconditionally.
    public static func stanceModifiers(for stanceId: String?) -> StanceModifiers {
        switch stanceId {
        case StanceId.bloodlust:
            // Warrior — physical frenzy. Higher ATK, sturdier, but burns hunger fast.
            var m = StanceModifiers()
            m.attackBonus = 5
            m.defenseBonus = 3
            m.hungerMultiplier = 2.0
            return m
        case StanceId.hawksEye:
            // Archer — hyper-focus. Buffs precision (crit / accuracy) and mobility (dodge).
            var m = StanceModifiers()
            m.critBonus = 15
            m.accuracyBonus = 10
            m.dodgeBonus = 10
            return m
        case StanceId.arcaneResonance:
            // Mage — arcane surge. Big damage swing through a multiplier on ATK,
            // plus a magical DEF buff against incoming blows.
            var m = StanceModifiers()
            m.attackMultiplier = 1.5
            m.defenseBonus = 5
            return m
        default:
            return .none
        }
    }

    /// Stance ID a given character class triggers when they tap Super.
    public static func stanceId(forClass cls: CharacterClass) -> String {
        switch cls {
        case .warrior: return StanceId.bloodlust
        case .archer:  return StanceId.hawksEye
        case .mage:    return StanceId.arcaneResonance
        }
    }

    // MARK: - Phase 4.2 special attacks

    /// Tuning + modifier construction for the per-class Special Attack
    /// technique (Cleave / Vital Shot / Soulfire). Wrapped in a single
    /// helper so the controller stays narrative-only.
    public enum SpecialAttack {
        // Hunger costs (paid on every tap; stance hunger multiplier composes).
        public static let cleaveHunger:    Int = 4
        public static let vitalShotHunger: Int = 4
        public static let soulfireHunger:  Int = 5
    }

    /// Hunger cost for a class's Special Attack.
    public static func specialAttackHunger(forClass cls: CharacterClass) -> Int {
        switch cls {
        case .warrior: return SpecialAttack.cleaveHunger
        case .archer:  return SpecialAttack.vitalShotHunger
        case .mage:    return SpecialAttack.soulfireHunger
        }
    }

    /// Per-class Special Attack modifiers folded into `applyAttack`.
    /// - Warrior (Cleave): −10% hit chance, ignores enemy DEF entirely
    ///   ("splits the shield"), +12 flat damage from the heavy two-handed
    ///   weight, +20% crit (a splitting blow tends toward critical).
    ///   Risk = miss chance; reward = peak damage when it lands.
    /// - Archer (Vital Shot): cannot miss, +20% crit, ignores DEF entirely.
    ///   Reliable damage, but the long aim zeroes the player's dodge for
    ///   the enemy counter (handled by `specialAttackZeroesDodge`).
    /// - Mage (Soulfire): cannot miss, ignores DEF, +5 flat damage. Most
    ///   reliable of the three but costs 5 hunger instead of 4.
    public static func specialAttackModifiers(forClass cls: CharacterClass) -> AttackModifiers {
        var m = AttackModifiers()
        switch cls {
        case .warrior:
            m.hitChanceModifier = -10
            m.defenderDEFFraction = 0.0
            m.flatDamageBonus = 12
            m.critBonus = 20
        case .archer:
            m.cannotMiss = true
            m.critBonus = 20
            m.defenderDEFFraction = 0.0
        case .mage:
            m.cannotMiss = true
            m.defenderDEFFraction = 0.0
            m.flatDamageBonus = 5
        }
        return m
    }

    /// True if the player keeps no dodge on this round when they unleash this
    /// class's Special Attack — flagship case is the archer's Vital Shot,
    /// where the long aim leaves them open to the enemy counter.
    public static func specialAttackZeroesDodge(forClass cls: CharacterClass) -> Bool {
        return cls == .archer
    }

    // MARK: - Phase 4.2.3 special defenses

    /// Tunings for the per-class Special Defense technique.
    public enum SpecialDefense {
        // Hunger costs.
        public static let ironBulwarkHunger:    Int = 3
        public static let shadowVeilHunger:     Int = 3
        public static let mirrorWardHunger:     Int = 4

        /// Iron Bulwark's parry-counter chip damage as a fraction of a clean
        /// hit. Bigger than the basic Defend's 30% — this is a heavier counter.
        public static let ironBulwarkChipFraction: Double = 0.5

        /// How much dodge Shadow Veil grants on the lingering buff round.
        public static let shadowVeilDodgeBonus: Int = 50

        /// Mirror Ward reflects this fraction of the rolled would-be enemy
        /// damage back as direct damage to the enemy (player takes nothing).
        public static let mirrorWardReflectFraction: Double = 0.5

        /// Persistent-effect duration in rounds. Only one round's worth of
        /// follow-up after activation by design.
        public static let effectPersistRounds: Int = 1
    }

    /// Hunger cost for a class's Special Defense.
    public static func specialDefenseHunger(forClass cls: CharacterClass) -> Int {
        switch cls {
        case .warrior: return SpecialDefense.ironBulwarkHunger
        case .archer:  return SpecialDefense.shadowVeilHunger
        case .mage:    return SpecialDefense.mirrorWardHunger
        }
    }

    // MARK: - Phase 4.3 class-specific Flee

    /// Phase 4.3 replaces the flat 50% flee chance with a per-class tuning
    /// that maps to the class fantasy: warriors are heavy and lumbering,
    /// archers are mobile, mages flat-out teleport. The mage premium is
    /// paid in hunger (`fleeHungerExtra`) — a teleport isn't free.
    public enum Flee {
        public static let warriorChance: Int = 40
        public static let archerChance:  Int = 70
        public static let mageChance:    Int = 90

        /// Extra hunger drained on top of the base `combatFlee` cost when a
        /// mage attempts to teleport away. Layers on after the stance hunger
        /// multiplier so an Arcane-Resonance mage still pays the teleport tax.
        public static let mageHungerExtra: Int = 2
    }

    /// Per-class success chance for a Flee attempt (1–100). Failure still
    /// triggers the existing forced full-damage counter.
    public static func fleeChance(forClass cls: CharacterClass) -> Int {
        switch cls {
        case .warrior: return Flee.warriorChance
        case .archer:  return Flee.archerChance
        case .mage:    return Flee.mageChance
        }
    }

    /// Extra flat hunger drained beyond the base Flee cost — non-zero only
    /// for the mage (teleport tax).
    public static func fleeHungerExtra(forClass cls: CharacterClass) -> Int {
        switch cls {
        case .mage: return Flee.mageHungerExtra
        default:    return 0
        }
    }
}
