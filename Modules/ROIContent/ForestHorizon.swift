//
//  ForestHorizon.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 20.10.2026.
//
//  Where the authored forest ends, and what answers for a km past it.
//
//  The wilderness has no edge — «Крок вперед» never refuses — but its content
//  does: every creature's band and every zone's pool stop at some km, and the
//  deepest band a creature can spawn in is the HORIZON (km 49 since the roster
//  of 2026-10-02). Until 2026-10-20 nothing answered past it. A step there
//  still rolled its buckets, the encounter and the find both came back nil, and
//  93% of steps read «Лише тиша»: a level-10 archer walked from km 49 to km 70
//  on 11 HP through twenty silent steps and a root that left him 2
//  (`spec-bestiary.md` §12).
//
//  A creature or a zone marked `beyondHorizon` answers for every km past the
//  horizon as well as for its own band — the rabid bear, the rabid pack and the
//  deep wood, on the owner's word. The pack's own band stays 36–40, so km
//  41–49 is still the bear's alone.
//
//  One rule, here, for the game's two catalogs, the validator and the digest:
//  a second copy of "who lives past the horizon" is the drift this file exists
//  to prevent.
//

import Foundation

public enum ForestHorizon {
    /// The deepest km any of `bands` reaches, nil when there are none. Callers
    /// pass the bands of creatures that SPAWN — the `0...0` sentinel of the
    /// training dummy and the registration dog is not forest.
    public static func km(of bands: [ClosedRange<Int>]) -> Int? {
        bands.map(\.upperBound).max()
    }

    /// Whether something authored for `band` answers for `km`: inside its own
    /// band, or anywhere past the horizon when it is marked to go on there.
    public static func covers(_ band: ClosedRange<Int>, beyondHorizon: Bool,
                              km: Int, horizon: Int?) -> Bool {
        if band.contains(km) { return true }
        guard beyondHorizon, let horizon else { return false }
        return km > horizon
    }
}
