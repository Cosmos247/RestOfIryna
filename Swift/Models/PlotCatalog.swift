//
//  PlotCatalog.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 29.04.2026.
//
//  Façade over `content/data/plots.json` (Phase 3C — was a Swift dictionary and
//  an icon `switch`). Plot type identity, tier-1 production rate, capacity,
//  produced item id and the UI icon all come from the file, so a balance change
//  is a JSON edit.
//
//  `PlotType` itself stays in Swift: its raw values are persisted in
//  `Plot.plotType`, so the enum is a database contract rather than content.
//
//  `testMode` scales rates so plots fill in minutes rather than hours. It moved
//  across verbatim rather than folding into `manifest.timeScale`, because that
//  fold is NOT mechanical — the flag drives two different scales: the interval
//  below is 60 ↔ 3600 (60×, which does match the manifest) while
//  `PlotProductionService`'s sweep is 60 ↔ 300 (5×). Phase 4 reconciles them.
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
    /// `false` for production deploys (rate units = per hour); `true` makes
    /// plots fill in minutes for dev playtest.
    public static var testMode: Bool { Catalogs.current.plotTestMode }

    /// Translates `ratePerInterval` to "units per second" depending on test mode.
    public static var intervalSeconds: Double {
        return testMode ? 60.0 : 3600.0
    }

    /// Lookup tuning for a given type + tier. Returns the T1 row regardless
    /// of `tier` for now — higher tiers ship in a later subphase. Returns nil
    /// for `trainingGround`, which is how the estate controller decides to
    /// route a tap to combat instead of a harvest.
    public static func tuning(for type: PlotType, tier: Int = 1) -> PlotTuning? {
        return Catalogs.current.plotTunings[type]
    }

    /// Lookup tuning by raw plot-type string (the value stored in `Plot.plotType`).
    public static func tuning(forRaw raw: String, tier: Int = 1) -> PlotTuning? {
        guard let type = PlotType(rawValue: raw) else { return nil }
        return tuning(for: type, tier: tier)
    }

    /// UI icon per type. Tied to the type, not the tier — visual continuity
    /// across upgrades. The validator requires a row for every `PlotType`, so
    /// the fallback is unreachable on a bundle that installs.
    public static func icon(for type: PlotType) -> String {
        return Catalogs.current.plotIcons[type] ?? ""
    }

    /// Locale key for the plot type's display name. Derived, not stored: a
    /// fixed convention with no overrides, so writing it into the file would
    /// only be duplication. The validator derives the same key and checks it.
    public static func nameKey(for type: PlotType) -> String {
        return "plot.type.\(type.rawValue).name"
    }

    /// Locale key for the plot type's lore blurb (shown in the type-picker
    /// when claiming a slot).
    public static func descriptionKey(for type: PlotType) -> String {
        return "plot.type.\(type.rawValue).desc"
    }
}
