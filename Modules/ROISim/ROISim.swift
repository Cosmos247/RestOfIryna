//
//  ROISim.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 29.08.2026.
//
//  Namespace and version for the balance module.
//
//  Since Phase 8 this target holds the game's combat, progression and budget
//  MATHS — not a model of them. `CombatService`, `User` and `ItemBudget` are
//  façades that read the live tuning tables and delegate here, so the bot and
//  `roi-content simulate` execute the same functions. That is the whole design:
//  a simulator that reimplements the maths measures the simulator.
//
//    CombatantStats · CombatMath · ProgressionMath · BudgetMath   the maths
//    ReferenceCharacter · EnemyGenerator · FightSimulator          the subjects
//    Statistics · BalanceReport · BalanceFormatter                 the report
//    SplitMix64                                                    the RNG
//

import Foundation

public enum ROISim {
    public static let version = "1.0.0-phase8"
}
