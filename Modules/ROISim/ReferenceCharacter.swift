//
//  ReferenceCharacter.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 30.08.2026.
//
//  The character every balance number is measured against.
//
//  A level-L player is their class's proportional stat line plus a full kit of
//  common gear. `gearOffset` is how far the kit trails the player: 0 is the
//  on-curve character the design table describes, and a negative offset is the
//  one real players actually are — a rung behind the ladder, because gear comes
//  from drops and crafting rather than from levelling.
//
//  The two accessory slots stay empty: no accessory has been authored, and
//  their 1.0 of slot weight is the entire gap between this kit and the design's
//  published HP and ATK (DEF and absorption land exactly, since they come from
//  slots that ARE filled).
//

import Foundation
import ROIContent

public struct ReferenceCharacter: Sendable {
    public let characterClass: String
    public let level: Int
    /// The item level of the gear, after the offset — never below 1.
    public let itemLevel: Int
    public let stats: CombatantStats
    public let maxVigor: Int

    /// The weapon ladder maps tiers to item levels 1 / 10 / 20 / 30 / 40, so
    /// "one rung behind" is ten item levels, not one.
    public static let ladderRung = 10

    public init(characterClass: String, level: Int, gearOffset: Int = 0,
                progression: ProgressionTuningDTO, budget: BudgetTuningDTO,
                profile: ClassBudgetProfileDTO, start: ClassStartDTO,
                rarityMultiplier: Double = 1.0) {
        self.characterClass = characterClass
        self.level = level
        self.itemLevel = Swift.max(1, level + gearOffset)
        let base = ProgressionMath.baseStats(start: start, growth: progression.statGrowth,
                                             level: level)
        let gear = BudgetMath.referenceGear(profile: profile, itemLevel: itemLevel,
                                            budget: budget, rarityMultiplier: rarityMultiplier)
        self.stats = CombatantStats(
            level: level,
            maxHP: base.maxHp + gear.hp,
            attack: base.attack + gear.attack,
            defense: base.defense + gear.defense,
            crit: base.crit + gear.crit,
            dodge: base.dodge + gear.dodge,
            accuracy: base.accuracy + gear.accuracy)
        self.maxVigor = ProgressionMath.maxVigor(at: level, pool: progression.vigorPool)
    }

    /// Build one per class from a whole tuning bundle. Returns nil when the
    /// bundle has no profile or no starting row for the class — which
    /// `DomainContent` refuses at install, so it can only happen to a fixture.
    public static func build(characterClass: String, level: Int, gearOffset: Int = 0,
                             progression: ProgressionTuningDTO, budget: BudgetTuningDTO,
                             rarities: [RarityDTO]) -> ReferenceCharacter? {
        guard let profile = budget.classProfiles.first(where: { $0.characterClass == characterClass }),
              let start = progression.classes.first(where: { $0.characterClass == characterClass })
        else { return nil }
        let common = rarities.first(where: { $0.id == "common" })?.budgetMultiplier ?? 1.0
        return ReferenceCharacter(characterClass: characterClass, level: level,
                                  gearOffset: gearOffset, progression: progression,
                                  budget: budget, profile: profile, start: start,
                                  rarityMultiplier: common)
    }
}
