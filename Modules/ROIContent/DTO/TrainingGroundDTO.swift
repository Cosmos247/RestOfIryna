//
//  TrainingGroundDTO.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 27.09.2026.
//
//  `training_ground.json` — the Training Ground as a building of the house
//  (2026-09-27). It used to be a plot type that cost a production slot and
//  nothing else; now it is built and raised for silver and materials, and each
//  level teaches one technique. The player-level floor of that technique stays
//  in `combat.json` → `techniques`, so the gate has one home and the simulator
//  keeps reading it.
//

import Foundation

public struct TrainingGroundFileDTO: Codable, Sendable, Equatable {
    /// Level 1 is the building itself; every level teaches `technique`.
    public let levels: [TrainingGroundLevelDTO]

    public init(levels: [TrainingGroundLevelDTO]) {
        self.levels = levels
    }
}

public struct TrainingGroundLevelDTO: Codable, Sendable, Equatable {
    public let level: Int
    /// A `combat.json` technique kind — `special_atk` / `special_def` / `super`.
    public let technique: String
    public let silverCost: Int
    public let inputs: [MaterialCostDTO]

    public init(level: Int, technique: String, silverCost: Int, inputs: [MaterialCostDTO]) {
        self.level = level
        self.technique = technique
        self.silverCost = silverCost
        self.inputs = inputs
    }
}

extension TrainingGroundLevelDTO {
    /// The level a building stands at once `paid` is bought, for a player who
    /// already knows `known`: the paid level, then every next level whose
    /// technique they know. Players who learned techniques on the old
    /// plot-based ground keep them, and nobody pays for a technique they have —
    /// the owner's rule of 2026-09-27. The ONE implementation the upgrade and
    /// the build card both ask.
    public static func levelAfterCatchUp(paid: Int, in levels: [TrainingGroundLevelDTO], known: Set<String>) -> Int {
        let ordered = levels.sorted { $0.level < $1.level }
        var level = paid
        while let next = ordered.first(where: { $0.level == level + 1 }), known.contains(next.technique) {
            level = next.level
        }
        return level
    }
}
