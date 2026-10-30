//
//  EventMath.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 29.10.2026.
//
//  The maths of a holiday's manor (`events.json`, `content/spec/event-veles-night.md`):
//  which creature stands at a depth, how strong it is, what its blood is worth,
//  and what a find in its place puts back (2026-10-30). Here, not in the bot,
//  so `roi-content spec events` prints the lines the game fights and the game
//  cannot fight a line the spec never showed.
//
//  A manor creature is an archetype's CONTRACT at its level — the stat line
//  `EnemyGenerator` solves against the reference characters, the same one every
//  forest creature was frozen from — with HP and ATK scaled. Its level follows
//  the PLAYER (`playerLevel + offset + depth`), which the forest never does:
//  the manor is a once-a-year contest where a level-3 newcomer and a level-19
//  veteran must both have a descent worth taking, and on the owner's word
//  (2026-10-27) it is the one place that bends the estate-tier rule.
//  The reference character carries the level's own gear and nothing the
//  player earned, so out-gearing the contract still shows here too.
//

import Foundation
import ROIContent

public enum EventMath {

    /// The level of the creature at `depth`, clamped to the levels the game
    /// has reference characters for.
    public static func creatureLevel(playerLevel: Int, depth: Int, offset: Int, maxLevel: Int) -> Int {
        Swift.min(Swift.max(1, maxLevel), Swift.max(1, playerLevel + offset + depth))
    }

    /// Blood for a kill at `depth`: `⌈depth / divisor⌉`, so the first depth
    /// still pays a drop with a divisor of 2.
    public static func blood(depth: Int, divisor: Int) -> Int {
        let d = Swift.max(1, depth)
        let k = Swift.max(1, divisor)
        return (d + k - 1) / k
    }

    /// A creature by weight. `roll` is in `0 ..< total weight`; nil for an
    /// empty or weightless list, which the validator refuses.
    public static func pick(_ creatures: [EventCreatureDTO], roll: Int) -> EventCreatureDTO? {
        var left = roll
        for creature in creatures where creature.weight > 0 {
            if left < creature.weight { return creature }
            left -= creature.weight
        }
        return nil
    }

    public static func totalWeight(_ creatures: [EventCreatureDTO]) -> Int {
        creatures.reduce(0) { $0 + Swift.max(0, $1.weight) }
    }

    /// The find a step deeper turns up instead of a creature (2026-10-30), or
    /// nil for a creature. `roll` is in `0 ..< 1`; each find owns a slice of it
    /// as wide as its chance, from 0 up, and the rest is the creatures'.
    public static func pickFind(_ finds: [EventFindDTO], roll: Double) -> EventFindDTO? {
        var floor = 0.0
        for find in finds where find.chance > 0 {
            if roll < floor + find.chance { return find }
            floor += find.chance
        }
        return nil
    }

    /// What a find's share of `maximum` puts back on `current`: the share
    /// rounded half up, never past the maximum and never below nothing — the
    /// receipt the screen prints, the way a meal's is.
    public static func restore(share: Double, maximum: Int, current: Int) -> Int {
        let room = Swift.max(0, maximum - current)
        let amount = Swift.max(0, Int((Double(maximum) * share).rounded()))
        return Swift.min(room, amount)
    }

    /// The creature's stat line at `level`: its archetype's contract, solved
    /// against every class's reference character at that level (their mean,
    /// as the forest roster was), HP and ATK × the creature's scales. Nil when
    /// the archetype or a reference character is missing — `DomainContent`
    /// refuses such a bundle at install.
    public static func line(of creature: EventCreatureDTO, level: Int,
                            archetypes: [EnemyArchetypeDTO], tuning: TuningBundleDTO,
                            budget: BudgetTuningDTO, rarities: [RarityDTO]) -> CombatantStats? {
        guard let archetype = archetypes.first(where: { $0.id == creature.archetype }) else { return nil }
        var references: [CombatantStats] = []
        for row in tuning.progression.classes {
            guard let reference = ReferenceCharacter.build(characterClass: row.characterClass, level: level,
                                                           gearOffset: 0, progression: tuning.progression,
                                                           budget: budget, rarities: rarities)
            else { return nil }
            references.append(reference.stats)
        }
        guard !references.isEmpty else { return nil }
        let contract = EnemyGenerator.generate(archetype: archetype, level: level, against: references,
                                               rules: CombatRules(tuning.combat),
                                               mobXP: tuning.progression.mobXP).stats
        return CombatantStats(level: level,
                              maxHP: Swift.max(1, Int((Double(contract.maxHP) * creature.hpScale).rounded())),
                              attack: Swift.max(1, Int((Double(contract.attack) * creature.attackScale).rounded())),
                              defense: contract.defense, crit: contract.crit, dodge: contract.dodge,
                              accuracy: contract.accuracy)
    }
}
