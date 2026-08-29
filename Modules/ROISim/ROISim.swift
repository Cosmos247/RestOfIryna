//
//  ROISim.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 29.08.2026.
//
//  Headless balance simulator.
//
//  Phase 0 lands the target and the deterministic RNG only. The combat model
//  moves in once `CombatService` is re-typed against a `CombatantStats` value
//  struct instead of the Fluent `User` model (Phase 8) — that refactor is the
//  only thing standing between this module and running real TTK tables.
//

import Foundation
import ROIContent

public enum ROISim {
    public static let version = "0.1.0-phase0"

    /// Placeholder so the target has a reason to link ROIContent and the
    /// dependency edge is exercised by the build.
    public static func describe(_ content: GameContent) -> String {
        "ROISim \(version) · \(content.items.count) items · \(content.enemies.count) enemies"
    }
}
