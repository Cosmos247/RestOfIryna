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

    // MARK: - Phase 5.3e — Technique unlock gates

    /// The three class-bound technique slots. Each player has exactly one
    /// of each (resolved by `characterClass`). Stored in `LearnedTechnique`
    /// by `rawValue` once the player visits the Training Ground at the
    /// required level.
    public enum TechniqueKind: String, CaseIterable, Sendable {
        case specialAtk = "special_atk"
        case specialDef = "special_def"
        case `super`    = "super"
    }

    /// Player level required to learn the technique kind.
    /// `tuning/combat.json` → `techniques[].requiredLevel`.
    public static func requiredLevel(for kind: TechniqueKind) -> Int {
        technique(kind).requiredLevel
    }

    /// Per-fight uses budget for the kind at the given player level: 1 until
    /// `secondUseAtLevel`, 2 from there on (the "use-count growth" perks of the
    /// upper levels in the Phase 5.3 unlock map).
    public static func initialUses(for kind: TechniqueKind, playerLevel: Int) -> Int {
        playerLevel >= technique(kind).secondUseAtLevel ? 2 : 1
    }

    private static func technique(_ kind: TechniqueKind) -> TechniqueTuningDTO {
        let content = Catalogs.current
        return content.required(content.techniqueTuning[kind], "technique \(kind.rawValue)")
    }

    /// Tuple of per-fight uses for a user — called by every `beginCombat`
    /// caller (active exploration, training dummy, registration rabid dog) so
    /// the budget always tracks the user's current level.
    public static func initialUsesForUser(_ user: User) -> (atk: Int, def: Int, sup: Int) {
        return (
            initialUses(for: .specialAtk, playerLevel: user.level),
            initialUses(for: .specialDef, playerLevel: user.level),
            initialUses(for: .super,      playerLevel: user.level)
        )
    }

    // Every constant below reads `tuning/combat.json`. All are computed `var`s,
    // never `static let`: a `static let` that touches `Catalogs.current` runs at
    // type-init and would trap before `ContentBootstrap.load` — the trap that
    // `FortuneCatalog.lookup` walked into during batch C.

    /// Base hit chance before accuracy/dodge modifiers (percent).
    public static var baseHitChance: Int { Catalogs.current.tuningCombat.hitChance.base }
    /// Floor and ceiling on hit chance so even a heavily out-statted side can
    /// land or miss occasionally (no 100/0 lock-ins).
    public static var minHitChance: Int { Catalogs.current.tuningCombat.hitChance.min }
    public static var maxHitChance: Int { Catalogs.current.tuningCombat.hitChance.max }
    /// Crit damage multiplier on a successful crit roll.
    public static var critMultiplier: Double { Catalogs.current.tuningCombat.critMultiplier }
    /// ±10% variance on every landed hit. `ClosedRange` TRAPS when built with
    /// min > max, so the validator rejects an inverted pair before install
    /// rather than letting the first attack of the session crash the bot.
    public static var varianceRange: ClosedRange<Double> {
        let variance = Catalogs.current.tuningCombat.variance
        return variance.min...variance.max
    }
    /// Defend's parry/counter chip damage as a fraction of a clean hit. Always
    /// lands, never crits — flavour is "you mostly hold the line but tag it".
    public static var defendChipFraction: Double { Catalogs.current.tuningCombat.defendChipFraction }

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
    /// `defendChipFraction × extraMultiplier` of a clean hit. Variance still
    /// applies so the number isn't pure deterministic. `extraMultiplier`
    /// defaults to 1.0 (warrior); the archer's "plinks while hiding" Defend
    /// passes 0.5 to halve the chip.
    public static func chipDamage(attackerATK: Int, defenderDEF: Int, extraMultiplier: Double = 1.0) -> Int {
        let raw = Double(max(1, attackerATK - defenderDEF))
        let varied = raw * Double.random(in: varianceRange) * defendChipFraction * extraMultiplier
        return max(1, Int(varied.rounded()))
    }

    // MARK: - Phase 4.2 stance modifiers

    /// Per-round modifiers applied while a Super-technique stance is active.
    /// Composed by the caller on top of the player's effective stats:
    /// `buffedATK = effectiveATK * attackMultiplier + attackBonus` etc.
    /// `vigorMultiplier` scales the vigor drain on each combat action.
    public struct StanceModifiers: Sendable {
        public var attackMultiplier: Double = 1.0
        public var attackBonus: Int = 0
        public var defenseBonus: Int = 0
        public var critBonus: Int = 0
        public var accuracyBonus: Int = 0
        public var dodgeBonus: Int = 0
        public var vigorMultiplier: Double = 1.0

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

    /// Activation vigor costs per stance — the price the player pays the
    /// moment they tap Super, on top of the round's regular drain. Mage
    /// "concentration burn" is more expensive than the warrior / archer
    /// supers (per Phase 4.2 spec).
    /// An id the table does not carry falls back to `defaultActivationVigor`,
    /// which is the `default:` arm of the switch this replaced — an unknown
    /// stance is charged, not free.
    public static func stanceActivationVigor(for stanceId: String) -> Int {
        let content = Catalogs.current
        return content.stanceById[stanceId]?.activationVigor
            ?? content.tuningCombat.stances.defaultActivationVigor
    }

    /// Default duration in rounds for a freshly activated stance.
    public static var stanceDurationRounds: Int { Catalogs.current.tuningCombat.stances.durationRounds }

    /// Numeric tunings for each stance. Returned `StanceModifiers.none` for
    /// unknown / nil stance ids so callers can compose unconditionally.
    public static func stanceModifiers(for stanceId: String?) -> StanceModifiers {
        // nil and unknown both fall to `.none`, exactly as the `default:` arm of
        // the switch this replaced did. Callers pass the stored
        // `combat_stance` column straight through, and it is nil far more often
        // than it is wrong.
        guard let stanceId, let row = Catalogs.current.stanceById[stanceId] else { return .none }
        var m = StanceModifiers()
        m.attackMultiplier = row.attackMultiplier
        m.attackBonus = row.attackBonus
        m.defenseBonus = row.defenseBonus
        m.critBonus = row.critBonus
        m.accuracyBonus = row.accuracyBonus
        m.dodgeBonus = row.dodgeBonus
        m.vigorMultiplier = row.vigorMultiplier
        return m
    }

    /// Stance ID a given character class triggers when they tap Super.
    public static func stanceId(forClass cls: CharacterClass) -> String {
        let content = Catalogs.current
        return content.required(content.stanceIdByClass[cls], "stance for \(cls.rawValue)")
    }

    // MARK: - Phase 4.2 special attacks

    /// Tuning + modifier construction for the per-class Special Attack
    /// technique (Cleave / Vital Shot / Soulfire). Wrapped in a single
    /// helper so the controller stays narrative-only.
    public enum SpecialAttack {
        // Vigor costs (paid on every tap; stance vigor multiplier composes).
        // Kept as named constants because call sites outside this file read
        // them; the numbers themselves come from `tuning/combat.json`.
        public static var cleaveVigor:    Int { specialAttackVigor(forClass: .warrior) }
        public static var vitalShotVigor: Int { specialAttackVigor(forClass: .archer) }
        public static var soulfireVigor:  Int { specialAttackVigor(forClass: .mage) }
    }

    /// Vigor cost for a class's Special Attack.
    public static func specialAttackVigor(forClass cls: CharacterClass) -> Int {
        specialAttack(cls).vigor
    }

    private static func specialAttack(_ cls: CharacterClass) -> SpecialAttackTuningDTO {
        let content = Catalogs.current
        return content.required(content.specialAttackByClass[cls], "specialAttack for \(cls.rawValue)")
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
    ///   reliable of the three but costs 5 vigor instead of 4.
    public static func specialAttackModifiers(forClass cls: CharacterClass) -> AttackModifiers {
        let row = specialAttack(cls)
        var m = AttackModifiers()
        m.hitChanceModifier = row.hitChanceModifier
        m.defenderDEFFraction = row.defenderDEFFraction
        m.critBonus = row.critBonus
        m.cannotMiss = row.cannotMiss
        m.flatDamageBonus = row.flatDamageBonus
        return m
    }

    /// True if the player keeps no dodge on this round when they unleash this
    /// class's Special Attack — flagship case is the archer's Vital Shot,
    /// where the long aim leaves them open to the enemy counter.
    public static func specialAttackZeroesDodge(forClass cls: CharacterClass) -> Bool {
        specialAttack(cls).zeroesDodge
    }

    // MARK: - Phase 4.2.3 special defenses

    /// Tunings for the per-class Special Defense technique.
    public enum SpecialDefense {
        // Vigor costs.
        public static var ironBulwarkVigor: Int { specialDefenseVigor(forClass: .warrior) }
        public static var shadowVeilVigor:  Int { specialDefenseVigor(forClass: .archer) }
        public static var mirrorWardVigor:  Int { specialDefenseVigor(forClass: .mage) }

        /// Iron Bulwark's parry-counter chip damage as a fraction of a clean
        /// hit. Bigger than the basic Defend's 30% — this is a heavier counter.
        public static var ironBulwarkChipFraction: Double {
            Catalogs.current.tuningCombat.specialDefense.ironBulwarkChipFraction
        }

        /// How much dodge Shadow Veil grants on the lingering buff round.
        public static var shadowVeilDodgeBonus: Int {
            Catalogs.current.tuningCombat.specialDefense.shadowVeilDodgeBonus
        }

        /// Mirror Ward reflects this fraction of the rolled would-be enemy
        /// damage back as direct damage to the enemy (player takes nothing).
        public static var mirrorWardReflectFraction: Double {
            Catalogs.current.tuningCombat.specialDefense.mirrorWardReflectFraction
        }

        /// Persistent-effect duration in rounds. Only one round's worth of
        /// follow-up after activation by design.
        public static var effectPersistRounds: Int {
            Catalogs.current.tuningCombat.specialDefense.effectPersistRounds
        }
    }

    /// Vigor cost for a class's Special Defense.
    public static func specialDefenseVigor(forClass cls: CharacterClass) -> Int {
        let content = Catalogs.current
        return content.required(content.specialDefenseVigorByClass[cls],
                                "specialDefense for \(cls.rawValue)")
    }

    // MARK: - Phase 4.3 class-specific Flee

    /// Phase 4.3 replaces the flat 50% flee chance with a per-class tuning
    /// that maps to the class fantasy: warriors are heavy and lumbering,
    /// archers are mobile, mages flat-out teleport. The mage premium is
    /// paid in vigor (`fleeVigorExtra`) — a teleport isn't free.
    public enum Flee {
        public static var warriorChance: Int { fleeChance(forClass: .warrior) }
        public static var archerChance:  Int { fleeChance(forClass: .archer) }
        public static var mageChance:    Int { fleeChance(forClass: .mage) }

        /// Extra vigor drained on top of the base `combatFlee` cost when a
        /// mage attempts to teleport away. Layers on after the stance vigor
        /// multiplier so an Arcane-Resonance mage still pays the teleport tax.
        public static var mageVigorExtra: Int { fleeVigorExtra(forClass: .mage) }
    }

    /// Per-class success chance for a Flee attempt (1–100). Failure still
    /// triggers the existing forced full-damage counter.
    public static func fleeChance(forClass cls: CharacterClass) -> Int {
        flee(cls).chance
    }

    /// Extra flat vigor drained beyond the base Flee cost. Zero for every class
    /// but the mage today — but stored per class, so making a second class pay
    /// a premium is a JSON edit rather than a new `case` here.
    public static func fleeVigorExtra(forClass cls: CharacterClass) -> Int {
        flee(cls).extraVigor
    }

    private static func flee(_ cls: CharacterClass) -> FleeTuningDTO {
        let content = Catalogs.current
        return content.required(content.fleeByClass[cls], "flee for \(cls.rawValue)")
    }

    // MARK: - Per-class Defend tunings (2026-05-15)
    //
    // Basic Defend used to share one mechanic across all classes: chip damage
    // back + doubled DEF for the round. Thematically that only matched the
    // warrior's "Parry". 2026-05-15 split it three ways:
    //
    //   • Warrior — chip 30% × ATK + 2× DEF (unchanged, the canonical block).
    //   • Archer  — chip 15% × ATK ("plinks a knife while melting into shadow")
    //               + flat +30 dodge for the round; DEF stays single.
    //   • Mage    — no chip ("the barrier is passive") + 60% damage reduction
    //               on the landed enemy hit (raw goes through DEF + dodge
    //               normally, then the final landed damage is multiplied by
    //               `mageBarrierDamageFraction`). Stronger mitigation than
    //               warrior to compensate for zero return damage — a Defend
    //               turn should feel roughly equal in value across classes.
    public enum Defend {
        /// Multiplies `defendChipFraction`, so 0.5 = 15% of raw at the shipped 0.3.
        public static var archerChipMultiplier: Double {
            Catalogs.current.tuningCombat.defend.archerChipMultiplier
        }
        public static var archerDodgeBonus: Int {
            Catalogs.current.tuningCombat.defend.archerDodgeBonus
        }
        /// Fraction of incoming damage the mage actually takes. 0.4 = 60% off.
        public static var mageBarrierDamageFraction: Double {
            Catalogs.current.tuningCombat.defend.mageBarrierDamageFraction
        }
    }

    // MARK: - Phase 5.1 training mode

    /// Enemy id used by the Training Ground plot. CombatController checks
    /// `state.combatEnemyId == trainingDummyEnemyId` to flip into training
    /// mode (Back button instead of Flee, no death/victory flow, dummy
    /// auto-revives when its HP hits 0).
    public static var trainingDummyEnemyId: String {
        Catalogs.current.tuningCombat.trainingDummyEnemyId
    }
}
