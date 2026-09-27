//
//  TrainingGroundCatalog.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 27.09.2026.
//
//  Façade over `training_ground.json`: the house's Training Ground, one
//  technique per level. The player-level floor of each level is NOT stored
//  here — it is the technique's own `requiredLevel` in `combat.json`, so the
//  gate the building shows and the gate the simulator reads are one number.
//

import Foundation

public enum TrainingGroundCatalog {
    public static var levels: [TrainingGroundLevelDTO] { Catalogs.current.trainingGroundLevels }

    public static var maxLevel: Int { levels.last?.level ?? 0 }

    public static func level(_ number: Int) -> TrainingGroundLevelDTO? {
        levels.first { $0.level == number }
    }

    /// The building level that teaches `technique`.
    public static func level(teaching technique: String) -> Int? {
        levels.first { $0.technique == technique }?.level
    }

    /// The player level a building level opens at: its technique's floor.
    public static func playerLevel(for step: TrainingGroundLevelDTO) -> Int {
        CombatService.TechniqueKind(rawValue: step.technique).map(CombatService.requiredLevel(for:)) ?? 1
    }
}
