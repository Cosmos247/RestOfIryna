//
//  PlotCatalog.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 29.04.2026.
//
//  Phase 5.1: code-based config for estate plots — analogous to ItemCatalog
//  and EnemyCatalog. Plot type identity, tier-1 production rate, capacity,
//  produced item id, and the UI icon all live here so balance changes are a
//  single-file edit.
//
//  Test mode (`PlotCatalog.testMode`) scales rates so plots fill in minutes
//  rather than hours — same pattern as `PassiveExpeditionService.testMode`.
//

import Foundation

public enum PlotType: String, CaseIterable, Sendable {
    case farm           = "farm"
    /// Stored as `forest` for DB compatibility; UI now reads "Lumberyard"
    /// (a saw mill / lumber-processing plot, not a wild forest). Same
    /// produced item (`mat.pine_lumber`) — only the lore framing changed.
    case forest         = "forest"
    case mine           = "mine"
    case coop           = "coop"
    /// Phase 5.1: non-producing plot. Tap → opens combat against a
    /// Training Dummy so the player can see their damage output without
    /// risk. Detected by `PlotCatalog.tuning(for:)` returning nil.
    case trainingGround = "training_ground"
}

/// Per-tier configuration for one plot type.
public struct PlotTuning: Sendable {
    public let producedItemId: String
    /// Production rate, expressed as units per HOUR in prod or per MINUTE in test mode.
    public let ratePerInterval: Int
    /// Maximum accumulation; once reached the player must harvest before
    /// production resumes.
    public let capacity: Int
    /// Optional secondary output that accumulates from the same
    /// `lastHarvestedAt` timestamp at its own (typically slower) rate. Used
    /// by the Mine to also yield rare iron alongside the river-pebble
    /// staple. The "ready to harvest" notification triggers off the primary
    /// only — the bonus is just a nice extra at harvest time.
    public let bonusOutput: PlotBonusOutput?

    public init(producedItemId: String, ratePerInterval: Int, capacity: Int, bonusOutput: PlotBonusOutput? = nil) {
        self.producedItemId = producedItemId
        self.ratePerInterval = ratePerInterval
        self.capacity = capacity
        self.bonusOutput = bonusOutput
    }
}

/// Secondary plot output (rare side-yield). Same shape as the primary —
/// rate uses the same `PlotCatalog.intervalSeconds` test/prod scaling.
public struct PlotBonusOutput: Sendable {
    public let producedItemId: String
    public let ratePerInterval: Int
    public let capacity: Int

    public init(producedItemId: String, ratePerInterval: Int, capacity: Int) {
        self.producedItemId = producedItemId
        self.ratePerInterval = ratePerInterval
        self.capacity = capacity
    }
}

public enum PlotCatalog {
    /// Flip to `false` for production deploys (rate units = per hour).
    /// `true` makes plots fill in minutes for dev playtest.
    public static let testMode: Bool = true

    /// Translates `ratePerInterval` to "units per second" depending on test mode.
    public static var intervalSeconds: Double {
        return testMode ? 60.0 : 3600.0
    }

    /// Per (type, tier=1) tunings. Tier 2+ will scale rate/cap when added.
    /// `trainingGround` is intentionally absent — it doesn't produce; the
    /// estate controller routes a tap on it to combat instead of harvest.
    /// The Mine carries a `bonusOutput` of `mat.iron` at a much lower rate
    /// (1/interval, cap 5) — primary pebble feel-rate is unchanged, iron
    /// just trickles in alongside.
    private static let t1Tunings: [PlotType: PlotTuning] = [
        .farm:   PlotTuning(producedItemId: "food.potato",       ratePerInterval: 4, capacity: 20),
        .forest: PlotTuning(producedItemId: "mat.pine_lumber",   ratePerInterval: 6, capacity: 30),
        .mine:   PlotTuning(producedItemId: "mat.river_pebble",  ratePerInterval: 8, capacity: 40,
                            bonusOutput: PlotBonusOutput(producedItemId: "mat.iron", ratePerInterval: 1, capacity: 20)),
        .coop:   PlotTuning(producedItemId: "food.duck_egg",     ratePerInterval: 2, capacity: 12),
    ]

    /// Lookup tuning for a given type + tier. Returns the T1 row regardless
    /// of `tier` for now — higher tiers ship in a later subphase.
    public static func tuning(for type: PlotType, tier: Int = 1) -> PlotTuning? {
        return t1Tunings[type]
    }

    /// Lookup tuning by raw plot-type string (the value stored in `Plot.plotType`).
    public static func tuning(forRaw raw: String, tier: Int = 1) -> PlotTuning? {
        guard let type = PlotType(rawValue: raw) else { return nil }
        return tuning(for: type, tier: tier)
    }

    /// UI icon per type. Tied to the type, not the tier — visual continuity
    /// across upgrades.
    public static func icon(for type: PlotType) -> String {
        switch type {
        case .farm:           return "🌾"
        case .forest:         return "🪚"
        case .mine:           return "⛏"
        case .coop:           return "🐔"
        case .trainingGround: return "🥋"
        }
    }

    /// Locale key for the plot type's display name.
    public static func nameKey(for type: PlotType) -> String {
        return "plot.type.\(type.rawValue).name"
    }

    /// Locale key for the plot type's lore blurb (shown in the type-picker
    /// when claiming a slot).
    public static func descriptionKey(for type: PlotType) -> String {
        return "plot.type.\(type.rawValue).desc"
    }
}
