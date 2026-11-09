//
//  WagonMath.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 08.11.2026.
//
//  The wagon's arithmetic (`content/spec/spec-wagon.md`), kept apart from the
//  database so the fit checks and the screens ask one implementation:
//  - a hire bought while one runs adds its length to the end; one bought after
//    the end starts from now (§3.1);
//  - in town the wagon is the bag's second store, in the house's order at home:
//    a place TAKES from the bag first and from the wagon for the rest, and PUTS
//    into the bag while it has room and onto the wagon for the rest, all or
//    nothing (§3.4) — a developer's bag has no ceiling, exactly as
//    `InventoryEntry.add` has none, and the wagon exempts nobody;
//  - when a hire ends, the cargo goes into the warehouse pile by pile until
//    the warehouse is full, and the rest stays on the wagon (§3.5).
//

import Foundation

public enum WagonMath {

    /// The wagon is with the player: its hire runs and they did not ride off
    /// without it (§2.11). The one test behind the road, the town and a job's
    /// count, so none of them can disagree about where the wagon is.
    public static func ridesAlong(running: Bool, leftHome: Bool) -> Bool {
        running && !leftHome
    }

    /// A crossing, the one reading of it. The wagon sets the pace when it rides
    /// along, never shorter than the road's own (§2.9), hired horse or not (the
    /// owner, 2026-11-09). Otherwise `horse` — the Rysak's crossing while its hire
    /// runs, nil without one (`spec-horse.md` §3.2), never longer than the road.
    /// Otherwise the road is the road.
    public static func crossing(road: TimeInterval, wagon: TimeInterval, ridesAlong: Bool,
                                horse: TimeInterval? = nil) -> TimeInterval {
        if ridesAlong { return Swift.max(road, wagon) }
        if let horse { return Swift.min(road, horse) }
        return road
    }

    /// What a stable question saw of the hire it asks about: when the running
    /// hire ends, in whole seconds, or 0 when none runs. The yes carries it and a
    /// hire that no longer matches spends nothing, so a double tap on «Найняти»
    /// pays once (2026-11-09, the shape of the bag's `drop1ok:<id>:<held>`).
    public static func hireStamp(end: Date?, now: Date) -> Int {
        guard let end, end > now else { return 0 }
        return Int(end.timeIntervalSince1970)
    }

    /// Where a hire of `seconds` ends: a running hire grows by it, one that has
    /// run out starts again from `now`.
    public static func end(after current: Date?, now: Date, adding seconds: TimeInterval) -> Date {
        if let current, current > now { return current.addingTimeInterval(seconds) }
        return now.addingTimeInterval(seconds)
    }

    /// What a take draws from each store: the bag first, the wagon for the
    /// rest. Nil when the two together hold less than `need`.
    public static func take(_ need: Int, bag: Int, wagon: Int) -> (fromBag: Int, fromWagon: Int)? {
        guard need >= 0 else { return nil }
        let inBag = Swift.max(0, bag), onWagon = Swift.max(0, wagon)
        guard inBag + onWagon >= need else { return nil }
        let fromBag = Swift.min(need, inBag)
        return (fromBag, need - fromBag)
    }

    /// Where a put lands: the bag while it has room, the wagon for the rest.
    /// Nil when the two together cannot take all of it.
    public static func put(_ quantity: Int, bagFree: Int, bagUnbounded: Bool,
                           wagonFree: Int) -> (toBag: Int, toWagon: Int)? {
        guard quantity >= 0 else { return nil }
        if bagUnbounded { return (quantity, 0) }
        let toBag = Swift.min(quantity, Swift.max(0, bagFree))
        let rest = quantity - toBag
        guard rest <= Swift.max(0, wagonFree) else { return nil }
        return (toBag, rest)
    }

    /// How much of each pile, in the order given, the warehouse takes at the
    /// end of a hire when it has `warehouseFree` places.
    public static func deliver(_ piles: [Int], warehouseFree: Int) -> [Int] {
        var room = Swift.max(0, warehouseFree)
        return piles.map { pile in
            let moved = Swift.min(Swift.max(0, pile), room)
            room -= moved
            return moved
        }
    }
}
