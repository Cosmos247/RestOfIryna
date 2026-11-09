//
//  HorseCatalog.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 09.11.2026.
//
//  Façade over `stable.json`'s horse («🐴 Рисак», `content/spec/spec-horse.md`):
//  how long a crossing takes on it, and the lengths it is hired for, with their
//  prices. Data, so `/reload` moves them; a hire already paid keeps the end it
//  was given, and a trip in flight its crossing.
//

import Foundation

public enum HorseCatalog {
    /// A crossing's game seconds on the Rysak (`stable.json` → `travelSeconds`).
    public static var authoredCrossingSeconds: Int { Catalogs.current.horseTravelSeconds }

    /// Wall-clock seconds of a crossing on the Rysak, compressed by
    /// `time.scale` like the road's own `TravelService.travelSeconds`.
    public static var travelSeconds: TimeInterval {
        Double(authoredCrossingSeconds) / Catalogs.current.timeScale
    }

    /// The lengths the stable offers, shortest first.
    public static var lengths: [WagonLengthDTO] { Catalogs.current.horseLengths }

    /// The length behind a stable button. Nil for an index a reload removed.
    public static func length(at index: Int) -> WagonLengthDTO? {
        lengths.indices.contains(index) ? lengths[index] : nil
    }
}
