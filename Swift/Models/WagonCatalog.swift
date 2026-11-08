//
//  WagonCatalog.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 08.11.2026.
//
//  Façade over `stable.json`'s wagon («🫏 Віз», `content/spec/spec-wagon.md`):
//  how many places it has, how long a crossing takes with it, and the lengths
//  it is hired for, with their prices. Data, so `/reload` moves them; a hire
//  already paid keeps the end it was given, and a trip in flight its crossing.
//

import Foundation

public enum WagonCatalog {
    /// Places, in units.
    public static var capacity: Int { Catalogs.current.wagonCapacity }

    /// A crossing's game minutes while the hire runs (`stable.json` → `travelMinutes`).
    public static var travelMinutes: Int { Catalogs.current.wagonTravelMinutes }

    /// Wall-clock seconds of a crossing with the wagon, compressed by
    /// `time.scale` like the road's own `TravelService.travelSeconds`.
    public static var travelSeconds: TimeInterval {
        Double(travelMinutes) * 60.0 / Catalogs.current.timeScale
    }

    /// The lengths the stable offers, shortest first.
    public static var lengths: [WagonLengthDTO] { Catalogs.current.wagonLengths }

    /// The length behind a stable button. Nil for an index a reload removed.
    public static func length(at index: Int) -> WagonLengthDTO? {
        lengths.indices.contains(index) ? lengths[index] : nil
    }

    /// Wall-clock seconds a length lasts. Its minutes are game time, so they
    /// are divided by `time.scale` like every other game duration.
    public static func seconds(of length: WagonLengthDTO) -> TimeInterval {
        Double(length.minutes) * 60.0 / Catalogs.current.timeScale
    }
}
