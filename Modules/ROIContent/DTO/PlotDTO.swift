//
//  PlotDTO.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 29.08.2026.
//
//  Wire format for `content/data/plots.json` — estate plot production.
//
//  Modelled as an ARRAY of rows keyed by `type`, not a JSON object. The shipped
//  catalog is a `[PlotType: PlotTuning]` dictionary, which has no order at all;
//  writing the rows as a list gives the file a stable, reviewable order and a
//  diff that stays put.
//
//  `tuning` is OPTIONAL and that is load-bearing: `training_ground` is a real
//  plot type with an icon and locale keys that deliberately produces nothing —
//  `PlotCatalog.tuning(for:)` returning nil is exactly how the estate
//  controller decides to route a tap to combat instead of a harvest. An absent
//  `tuning` key is that nil, written down.
//
//  Display name and lore keys stay derived in Swift (`plot.type.<type>.name` /
//  `.desc`) — a fixed naming convention with no overrides, so writing them into
//  the file would only be duplication. The validator derives the same keys and
//  demands they exist in both locales.
//

import Foundation

/// Secondary plot output — the rare side-yield that accumulates from the same
/// harvest timestamp at its own, slower rate. Only the Mine uses one today
/// (iron alongside the river-pebble staple).
public struct PlotBonusOutputDTO: Codable, Sendable, Equatable {
    public let producedItemId: String
    public let ratePerInterval: Int
    public let capacity: Int

    public init(producedItemId: String, ratePerInterval: Int, capacity: Int) {
        self.producedItemId = producedItemId
        self.ratePerInterval = ratePerInterval
        self.capacity = capacity
    }

    private enum CodingKeys: String, CodingKey { case producedItemId, ratePerInterval, capacity }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        producedItemId  = try c.decode(String.self, forKey: .producedItemId)
        ratePerInterval = try c.decode(Int.self, forKey: .ratePerInterval)
        capacity        = try c.decode(Int.self, forKey: .capacity)
    }
}

/// Production config for one plot type. Rate is units per INTERVAL, and the
/// interval is `tuning/time.json` → `gameTime.plotIntervalSeconds` divided by
/// `time.scale` — an hour at release pacing, a minute in the dev bundle.
public struct PlotTuningDTO: Codable, Sendable, Equatable {
    public let producedItemId: String
    public let ratePerInterval: Int
    /// Maximum accumulation; production stops until the player harvests.
    public let capacity: Int
    public let bonusOutput: PlotBonusOutputDTO?

    public init(producedItemId: String, ratePerInterval: Int, capacity: Int,
                bonusOutput: PlotBonusOutputDTO? = nil) {
        self.producedItemId = producedItemId
        self.ratePerInterval = ratePerInterval
        self.capacity = capacity
        self.bonusOutput = bonusOutput
    }

    private enum CodingKeys: String, CodingKey {
        case producedItemId, ratePerInterval, capacity, bonusOutput
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        producedItemId  = try c.decode(String.self, forKey: .producedItemId)
        ratePerInterval = try c.decode(Int.self, forKey: .ratePerInterval)
        capacity        = try c.decode(Int.self, forKey: .capacity)
        bonusOutput     = try c.decodeIfPresent(PlotBonusOutputDTO.self, forKey: .bonusOutput)
    }
}

/// One plot type: identity, icon, and production config when it produces.
public struct PlotTypeDTO: Codable, Sendable, Equatable {
    /// Matches a `PlotType` raw value — the string persisted in `Plot.plotType`,
    /// which is why the enum itself stays in Swift.
    public let type: String
    /// UI icon, tied to the type rather than the tier for visual continuity.
    public let icon: String
    /// Absent for a non-producing plot (`training_ground`).
    public let tuning: PlotTuningDTO?

    public init(type: String, icon: String, tuning: PlotTuningDTO? = nil) {
        self.type = type
        self.icon = icon
        self.tuning = tuning
    }

    private enum CodingKeys: String, CodingKey { case type, icon, tuning }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        type   = try c.decode(String.self, forKey: .type)
        icon   = try c.decode(String.self, forKey: .icon)
        tuning = try c.decodeIfPresent(PlotTuningDTO.self, forKey: .tuning)
    }
}

/// Top-level shape of `plots.json`.
public struct PlotFileDTO: Codable, Sendable {
    /// Temporary: scales production so plots fill in minutes. Phase 4 replaces
    /// it with `manifest.timeScale` and deletes this field.
    public let types: [PlotTypeDTO]

    public init(types: [PlotTypeDTO]) {
        self.types = types
    }

    private enum CodingKeys: String, CodingKey { case types }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        types    = try c.decode([PlotTypeDTO].self, forKey: .types)
    }
}
