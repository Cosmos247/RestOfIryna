//
//  EstateUpBanner.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 07.09.2026.
//
//  The estate tier-up message, shaped like `LevelUpBanner`: its own bubble,
//  kept in history, with the new numbers written out rather than implied.
//
//  It used to be a `postStatusBanner` toast — one line, deleted by the next
//  status banner — for the single most expensive thing a player buys. The
//  tier is also the game's real gate list (the kitchen, the workshop, the
//  training ground, the tannery), and none of that was ever said out loud:
//  the player had to notice a new button had appeared.
//
//  Slots and capacity come from the same façades the estate screen reads,
//  and the gates from `EstateTierGates`, so this cannot print a tier a
//  button disagrees with.
//

import Foundation
@preconcurrency import Lingo

public enum EstateUpBanner {

    public static func text(newTier: Int, previousTier: Int, lingo: Lingo, locale: String) -> String {
        func label(_ key: String) -> String { lingo.localize(key, locale: locale) }
        func gain(_ delta: Int) -> String { delta > 0 ? " (+\(delta))" : "" }
        /// True when this upgrade is the one that crossed the gate.
        func opened(_ gate: Int) -> Bool { previousTier < gate && newTier >= gate }

        // 🏠 prepended in Swift — a leading supplementary-plane emoji breaks
        // Lingo's `%{var}` parser (see .memory/localization.md).
        var lines = ["🏠 " + lingo.localize("estate.upgrade.banner.success", locale: locale, interpolations: [
            "tier": "\(newTier)",
            "name": label("estate.tier.\(newTier).name")
        ]), ""]

        let slots = PlotService.slotsForLevel(newTier)
        let capacity = WarehouseService.capForLevel(newTier)
        lines.append("🌾 \(label("estate.upgrade.banner.slots")): \(slots)\(gain(slots - PlotService.slotsForLevel(previousTier)))")
        lines.append("\(label("estate.warehouse")): \(capacity)\(gain(capacity - WarehouseService.capForLevel(previousTier)))")

        var unlocked: [String] = []
        if opened(EstateTierGates.kitchen) { unlocked.append(label("estate.kitchen")) }
        if opened(EstateTierGates.workshop) { unlocked.append(label("estate.workshop")) }
        if opened(EstateTierGates.trainingGround) {
            unlocked.append("\(PlotCatalog.icon(for: .trainingGround)) " + label("plot.type.training_ground.name"))
        }
        if opened(EstateTierGates.tannery) {
            unlocked.append("🧵 " + label("workshop.category.tannery"))
        }
        if !unlocked.isEmpty {
            lines.append("")
            lines.append("🔓 " + label("estate.upgrade.banner.unlocked"))
            lines.append(contentsOf: unlocked)
        }

        return lines.joined(separator: "\n")
    }
}
