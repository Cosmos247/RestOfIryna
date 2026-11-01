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
//  Rates are per INTERVAL, and the interval is `tuning/time.json` →
//  `gameTime.plotIntervalSeconds` divided by `time.scale`: an hour at release
//  pacing, a minute in the dev bundle. Phase 4b deleted the `testMode` flag that
//  used to pick between them — it was never one scale anyway, since the same
//  boolean also drove `PlotProductionService`'s sweep at a different ratio.
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
    /// The plot every estate starts with (2026-11-01, `spec-progression.md` §8):
    /// hazel bushes in slot 1 yielding forest nuts. `plots.json` marks it
    /// granted, so the player never chooses or builds it — ask that through
    /// `PlotCatalog.isGranted`, never by naming this case. Only copy that is
    /// about the hazel itself (the welcome's line) names it.
    case hazel          = "hazel"
    // `training_ground` was a fifth, non-producing type until 2026-09-27;
    // it is a building of the house now (`TrainingGroundCatalog`).
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

    /// Translates `ratePerInterval` to "units per second" depending on test mode.
    public static var intervalSeconds: Double {
        let content = Catalogs.current
        return content.tuningTime.gameTime.plotIntervalSeconds / content.timeScale
    }

    /// Lookup tuning for a given type + tier. Returns the T1 row regardless
    /// of `tier` for now — higher tiers ship in a later subphase. Nil only for
    /// a type the content gives no tuning; none ships since the Training
    /// Ground became a house room (2026-09-27).
    public static func tuning(for type: PlotType, tier: Int = 1) -> PlotTuning? {
        return Catalogs.current.plotTunings[type]
    }

    /// Lookup tuning by raw plot-type string (the value stored in `Plot.plotType`).
    public static func tuning(forRaw raw: String, tier: Int = 1) -> PlotTuning? {
        guard let type = PlotType(rawValue: raw) else { return nil }
        return tuning(for: type, tier: tier)
    }

    // MARK: - The plot the estate grants (2026-11-01)

    /// True for the plot every estate starts with — `plots.json` →
    /// `"granted" : true`. Such a plot stands in `GrantedPlot.slotIndex`, is
    /// never offered by the picker or accepted by the claim, and never counts
    /// as a plot the player built.
    public static func isGranted(_ type: PlotType) -> Bool {
        Catalogs.current.plotGranted.contains(type)
    }

    /// The granted type, if the content has one. The validator allows at most
    /// one, since there is one slot for it.
    public static var grantedType: PlotType? {
        PlotType.allCases.first { isGranted($0) }
    }

    /// Raw values of every granted type — for a query that must leave them
    /// out (the King's `claim_plot`) and for `PlotBuildCost.nextPlotNumber`.
    public static var grantedRawValues: Set<String> {
        Set(PlotType.allCases.filter { isGranted($0) }.map(\.rawValue))
    }

    /// The types a player can build, in the enum's order — the picker's list.
    public static var buildableTypes: [PlotType] {
        PlotType.allCases.filter { !isGranted($0) }
    }

    /// How far back a RIPE plot's harvest clock is set: whole intervals to fill
    /// from empty (`GrantedPlot.intervalsToFill`) at the live interval. Nil for
    /// a type that grows nothing.
    public static func secondsToFill(_ type: PlotType) -> TimeInterval? {
        guard let tuning = tuning(for: type) else { return nil }
        let intervals = GrantedPlot.intervalsToFill(capacity: tuning.capacity,
                                                    ratePerInterval: tuning.ratePerInterval)
        return Double(intervals) * intervalSeconds
    }

    /// What the player's `plotNumber`-th plot of `type` costs to build
    /// (2026-10-24) — the number counts the plot being built, so the first is
    /// 1. `PlotService.buildCost` supplies the number; the arithmetic is
    /// `PlotBuildCost`, which `roi-content spec gates` prints.
    public static func buildCost(for type: PlotType, plotNumber: Int) -> [MaterialCostDTO] {
        let content = Catalogs.current
        return PlotBuildCost.inputs(recipe: content.plotBuildRecipes[type] ?? [], plotNumber: plotNumber,
                                    rule: content.plotBuildRule)
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

    /// Locale key for the grammatical gender of the plot's NAME — `m` · `f` ·
    /// `n` · `pl`, in `uk.json` only. Same rule as items: gender belongs to the
    /// WORD, not the thing («Шахта заповнена» but «Курник заповнений»), and
    /// English never asks. Derived like `nameKey`, and checked by the validator.
    public static func genderKey(for type: PlotType) -> String {
        return "plot.type.\(type.rawValue).gender"
    }
}
