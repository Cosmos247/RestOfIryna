//
//  WagonService.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 08.11.2026.
//
//  The wagon («🫏 Віз», `content/spec/spec-wagon.md`): hired at the stable on
//  Поділ, a second store that rides with the player — for anything the
//  warehouse takes (the owner, 2026-11-08: «завантажувати у віз можна все»), so
//  everything but the class weapon, which stays with the player as it does at
//  the warehouse. A piece of gear rides with its own tier, wear and enchant, and
//  moves between the warehouse and the wagon one copy at a time.
//
//  Where it is follows from where the player is (§3.2): with them on the road
//  and in town while the hire runs, in the estate's yard otherwise — and in the
//  yard too when they rode off without it («🐎 Верхи», `Wagon.leftHome`, §2.11;
//  `WagonMath.ridesAlong` is the one test). So:
//  - in town, every place that takes from the bag also takes from the wagon,
//    and every place that puts an item into the bag puts the rest onto it —
//    the bag first, the wagon for the rest, all or nothing (`WagonMath`). That
//    holds only while it is there (`inTown`);
//  - at home the wagon trades with the warehouse alone (`load` / `unload`), and
//    no estate service reads it: it is unloaded first (§2.8);
//  - when the hire ends, the watchman takes the cargo into the warehouse up to
//    its cap and the rest waits on the wagon, moving in as room appears (§3.5).
//
//  The warehouse cap holds on every path in, the end-of-hire delivery included,
//  and nothing here bypasses it for a developer. The wagon's own cap exempts
//  nobody either; only the BAG's add skips its ceiling for a developer, and the
//  put arithmetic mirrors that.
//

import Fluent
import Foundation

public enum WagonService {

    // MARK: - Reading

    public static func wagon(for userId: UUID, on db: any Database) async throws -> Wagon? {
        try await Wagon.query(on: db).filter(\.$user.$id, .equal, userId).first()
    }

    /// The cargo, oldest pile first — the order the end-of-hire delivery takes.
    public static func cargo(for userId: UUID, on db: any Database) async throws -> [WagonCargoEntry] {
        try await WagonCargoEntry.query(on: db)
            .filter(\.$user.$id, .equal, userId)
            .sort(\.$createdAt, .ascending)
            .all()
    }

    /// Units on the wagon.
    public static func used(for userId: UUID, on db: any Database) async throws -> Int {
        try await cargo(for: userId, on: db).reduce(0) { $0 + $1.quantity }
    }

    public static func quantity(of itemId: String, for userId: UUID, on db: any Database) async throws -> Int {
        try await WagonCargoEntry.query(on: db)
            .filter(\.$user.$id, .equal, userId)
            .filter(\.$itemId, .equal, itemId)
            .all()
            .reduce(0) { $0 + $1.quantity }
    }

    /// What rides on the wagon: anything the warehouse takes (the owner,
    /// 2026-11-08) — every item but the class weapon, which stays with the
    /// player (`WarehouseService.deposit` → `.notTransferable`).
    public static func carries(_ itemId: String) -> Bool {
        ItemCatalog.find(itemId) != nil && !WeaponUpgradeCatalog.isUpgradable(itemId)
    }

    /// The wagon as a screen sees it. Nil when there is none to show: never
    /// hired, or the hire ran out and nothing is left on it (it went back).
    public struct Status: Sendable {
        public let endsAt: Date
        public let running: Bool
        public let used: Int
        public let capacity: Int
        /// The player rode off without it (§2.11).
        public let leftHome: Bool

        /// The wagon is with the player, wherever that is.
        public var ridesAlong: Bool { WagonMath.ridesAlong(running: running, leftHome: leftHome) }
        public var free: Int { max(0, capacity - used) }
        public func secondsLeft(now: Date = Date()) -> Int { max(0, Int(endsAt.timeIntervalSince(now).rounded())) }
    }

    public static func status(for user: User, on db: any Database, now: Date = Date()) async throws -> Status? {
        guard let userId = user.id, let wagon = try await wagon(for: userId, on: db) else { return nil }
        let used = try await used(for: userId, on: db)
        let running = wagon.isRunning(at: now)
        guard running || used > 0 else { return nil }
        return Status(endsAt: wagon.endsAt, running: running, used: used, capacity: WagonCatalog.capacity,
                      leftHome: wagon.leftHome)
    }

    /// The wagon is in town with the player: they stand in the capital, not on
    /// the road, the hire runs and they brought it. The one condition every
    /// capital place asks before it counts or touches the wagon.
    public static func inTown(for user: User, on db: any Database, now: Date = Date()) async throws -> Bool {
        guard user.location == TravelDestination.capital.rawValue, let userId = user.id else { return false }
        guard try await TravelState.current(for: user, on: db) == nil else { return false }
        guard let wagon = try await wagon(for: userId, on: db) else { return false }
        return WagonMath.ridesAlong(running: wagon.isRunning(at: now), leftHome: wagon.leftHome)
    }

    /// Whether the wagon stays at home. Asked at every departure from the
    /// estate and cleared on landing there, one column so it cannot undo
    /// anything the watchman writes to the row.
    public static func setLeftHome(_ left: Bool, userId: UUID, on db: any Database) async throws {
        try await Wagon.query(on: db)
            .filter(\.$user.$id, .equal, userId)
            .set(\.$leftHome, to: left)
            .update()
    }

    /// The wagon in the estate's yard, for the warehouse's screens: the player
    /// is at home, not on the road and not in the forest — the same place the
    /// warehouse's own buttons ask for.
    public static func atHome(for user: User, on db: any Database, now: Date = Date()) async throws -> Status? {
        guard try await isHome(user, on: db) else { return nil }
        return try await status(for: user, on: db, now: now)
    }

    /// At the estate, not on the road and not in the forest.
    static func isHome(_ user: User, on db: any Database) async throws -> Bool {
        guard user.location == TravelDestination.estate.rawValue else { return false }
        guard try await TravelState.current(for: user, on: db) == nil else { return false }
        return try await ExplorationState.current(for: user, on: db) == nil
    }

    // MARK: - Hiring

    public enum HireResult: Sendable {
        case hired(endsAt: Date, length: WagonLengthDTO, silverLeft: Int)
        case notEnoughSilver(have: Int, need: Int)
        case unknownLength
        /// Asked away from the capital — a stable button left in chat.
        case notInTown
    }

    /// Hire the wagon for the length at `lengthIndex`. A hire that still runs
    /// grows by the length; one that ran out starts again from now, with
    /// whatever is still on the wagon. The silver and the row are one
    /// transaction, on a user row loaded inside it.
    public static func hire(lengthIndex: Int, for user: User, on db: any Database,
                            now: Date = Date()) async throws -> HireResult {
        guard user.location == TravelDestination.capital.rawValue,
              try await TravelState.current(for: user, on: db) == nil else { return .notInTown }
        guard let length = WagonCatalog.length(at: lengthIndex) else { return .unknownLength }
        guard user.silver >= length.silver else { return .notEnoughSilver(have: user.silver, need: length.silver) }
        let userId = try user.requireID()
        let seconds = WagonCatalog.seconds(of: length)

        let outcome = try await db.transaction { tx -> (end: Date, left: Int)? in
            guard let row = try await User.find(userId, on: tx), row.silver >= length.silver else { return nil }
            let wagon = try await wagon(for: userId, on: tx) ?? Wagon(userID: userId, endsAt: now)
            let end = WagonMath.end(after: wagon.id == nil ? nil : wagon.endsAt, now: now, adding: seconds)
            // A new hire starts here at the stable, beside the player. A longer
            // one changes nothing about where the wagon stands.
            if !wagon.isRunning(at: now) { wagon.leftHome = false }
            wagon.endsAt = end
            try await wagon.save(on: tx)
            row.silver -= length.silver
            try await row.save(on: tx)
            return (end, row.silver)
        }
        guard let outcome else { return .notEnoughSilver(have: user.silver, need: length.silver) }
        user.silver = outcome.left
        try await user.saveAndCache(in: db)
        return .hired(endsAt: outcome.end, length: length, silverLeft: outcome.left)
    }

    // MARK: - The capital's second store

    /// What a capital place may count of an item: the bag, and the wagon
    /// when it is in town. `wagon` is 0 for anything that does not ride on it.
    public static func townStock(of itemId: String, for user: User, on db: any Database) async throws -> (bag: Int, wagon: Int) {
        let userId = try user.requireID()
        let bag = try await InventoryEntry.totalQuantity(of: itemId, for: userId, on: db)
        guard carries(itemId), try await inTown(for: user, on: db) else { return (bag, 0) }
        return (bag, try await quantity(of: itemId, for: userId, on: db))
    }

    /// What the wagon carries of an item while it is with the player, wherever
    /// they stand — it rides to town with them, so a job's readiness counts it
    /// before they arrive. 0 once the hire has run out (that cargo goes home)
    /// and while they are away without it.
    public static func runningQuantity(of itemId: String, for user: User, on db: any Database,
                                       now: Date = Date()) async throws -> Int {
        guard carries(itemId), let userId = user.id,
              let wagon = try await wagon(for: userId, on: db),
              WagonMath.ridesAlong(running: wagon.isRunning(at: now), leftHome: wagon.leftHome) else { return 0 }
        return try await quantity(of: itemId, for: userId, on: db)
    }

    /// `townStock`, summed: the one number a capital card prints as «маєте».
    public static func townTotal(of itemId: String, for user: User, on db: any Database) async throws -> Int {
        let stock = try await townStock(of: itemId, for: user, on: db)
        return stock.bag + stock.wagon
    }

    /// The bag first, the wagon for the rest. False, with nothing changed, when
    /// the two together hold less. Call it inside the place's own transaction;
    /// `wagonInTown` is the answer `inTown` gave before it.
    @discardableResult
    public static func take(_ itemId: String, quantity: Int, from user: User, wagonInTown: Bool,
                            on db: any Database) async throws -> Bool {
        guard quantity > 0 else { return true }
        let userId = try user.requireID()
        let bag = try await InventoryEntry.totalQuantity(of: itemId, for: userId, on: db)
        let onWagon = wagonInTown && carries(itemId) ? try await self.quantity(of: itemId, for: userId, on: db) : 0
        guard let split = WagonMath.take(quantity, bag: bag, wagon: onWagon) else { return false }
        if split.fromBag > 0 {
            guard try await InventoryEntry.remove(itemId, quantity: split.fromBag, from: user, on: db) else { return false }
        }
        if split.fromWagon > 0 {
            guard try await removeCargo(itemId, quantity: split.fromWagon, userId: userId, on: db) else { return false }
        }
        return true
    }

    /// The room a put of this item can land in: the bag's free places, and the
    /// wagon's when it is in town and carries the item.
    public static func room(for itemId: String, user: User, wagonInTown: Bool,
                            on db: any Database) async throws -> (bagFree: Int, wagonFree: Int) {
        let userId = try user.requireID()
        let bagFree = try await InventoryEntry.freeSlots(for: user, on: db)
        guard wagonInTown, carries(itemId) else { return (bagFree, 0) }
        return (bagFree, max(0, WagonCatalog.capacity - (try await used(for: userId, on: db))))
    }

    /// Where a put of `quantity` would land, or nil when it does not fit — the
    /// same arithmetic `put` writes with.
    public static func plan(put itemId: String, quantity: Int, to user: User, wagonInTown: Bool,
                            on db: any Database) async throws -> (toBag: Int, toWagon: Int)? {
        let room = try await room(for: itemId, user: user, wagonInTown: wagonInTown, on: db)
        return WagonMath.put(quantity, bagFree: room.bagFree, bagUnbounded: user.isDeveloper, wagonFree: room.wagonFree)
    }

    /// The bag while it has room, the wagon for the rest. Throws
    /// `InventoryError.inventoryFull`, with nothing written, when the two
    /// together cannot take it — the bag's own add would throw the same.
    @discardableResult
    public static func put(_ itemId: String, quantity: Int, to user: User, wagonInTown: Bool,
                           on db: any Database) async throws -> (toBag: Int, toWagon: Int) {
        guard quantity > 0 else { return (0, 0) }
        guard let split = try await plan(put: itemId, quantity: quantity, to: user, wagonInTown: wagonInTown, on: db) else {
            throw InventoryError.inventoryFull
        }
        if split.toBag > 0 { try await InventoryEntry.add(itemId, quantity: split.toBag, to: user, on: db) }
        if split.toWagon > 0 { try await addCargo(itemId, quantity: split.toWagon, userId: try user.requireID(), on: db) }
        return split
    }

    // MARK: - Home: the warehouse and the wagon

    public enum MoveResult: Sendable, Equatable {
        case moved(Int)
        /// Fewer moved than asked: the receiving side filled up.
        case partial(moved: Int, left: Int)
        case nothingToMove
        /// Loading onto a wagon whose hire has run out (§3.5: it takes nothing new).
        case notRunning
        case wagonFull(free: Int)
        case warehouseFull(free: Int)
        /// The class weapon, or a piece of gear asked for by item id rather
        /// than as a copy (`loadPiece` / `unloadPiece`).
        case notCarried
        /// Asked away from the yard — on the road, in town or in the forest.
        case notHere
    }

    /// Warehouse → wagon, up to `quantity` of a stackable item. Only while the
    /// hire runs, never past the wagon's places. Gear moves a copy at a time,
    /// through `loadPiece`.
    public static func load(_ itemId: String, quantity: Int, for user: User, on db: any Database,
                            now: Date = Date()) async throws -> MoveResult {
        guard carries(itemId), ItemCatalog.find(itemId)?.stackable == true else { return .notCarried }
        guard let userId = user.id, try await isHome(user, on: db) else { return .notHere }
        guard let status = try await status(for: user, on: db, now: now), status.running else { return .notRunning }
        let held = try await WarehouseEntry.totalQuantity(of: itemId, for: userId, on: db)
        guard held > 0, quantity > 0 else { return .nothingToMove }
        let wanted = min(quantity, held)
        let moving = min(wanted, status.free)
        guard moving > 0 else { return .wagonFull(free: status.free) }
        try await db.transaction { tx in
            guard try await WarehouseEntry.remove(itemId, quantity: moving, from: user, on: tx) else {
                throw WagonError.drainFailed(itemId)
            }
            try await addCargo(itemId, quantity: moving, userId: userId, on: tx)
        }
        return moving < wanted ? .partial(moved: moving, left: wanted - moving) : .moved(moving)
    }

    /// Wagon → warehouse, up to `quantity` of a stackable item, never past the
    /// warehouse's cap. Allowed whether or not the hire still runs. Gear moves a
    /// copy at a time, through `unloadPiece`.
    public static func unload(_ itemId: String, quantity: Int, for user: User, on db: any Database,
                              now: Date = Date()) async throws -> MoveResult {
        guard ItemCatalog.find(itemId)?.stackable == true else { return .notCarried }
        guard let userId = user.id, try await isHome(user, on: db) else { return .notHere }
        let held = try await self.quantity(of: itemId, for: userId, on: db)
        guard held > 0, quantity > 0 else { return .nothingToMove }
        let wanted = min(quantity, held)
        let free = try await warehouseFree(for: user, on: db)
        let moving = min(wanted, free)
        guard moving > 0 else { return .warehouseFull(free: free) }
        try await db.transaction { tx in
            guard try await removeCargo(itemId, quantity: moving, userId: userId, on: tx) else {
                throw WagonError.drainFailed(itemId)
            }
            try await WarehouseEntry.add(itemId, quantity: moving, to: user, on: tx)
        }
        return moving < wanted ? .partial(moved: moving, left: wanted - moving) : .moved(moving)
    }

    /// One piece of gear from the warehouse onto the wagon, with its own state —
    /// the row is re-created on the wagon carrying it, as a deposit does.
    public static func loadPiece(warehouseRowId: UUID, for user: User, on db: any Database,
                                 now: Date = Date()) async throws -> MoveResult {
        guard let userId = user.id, try await isHome(user, on: db) else { return .notHere }
        guard let status = try await status(for: user, on: db, now: now), status.running else { return .notRunning }
        guard let row = try await WarehouseEntry.query(on: db)
            .filter(\.$user.$id, .equal, userId)
            .filter(\.$id, .equal, warehouseRowId)
            .first() else { return .nothingToMove }
        guard carries(row.itemId), ItemCatalog.find(row.itemId)?.stackable == false else { return .notCarried }
        guard status.free >= 1 else { return .wagonFull(free: status.free) }
        let state = row.gearState
        try await db.transaction { tx in
            try await row.delete(on: tx)
            try await WagonCargoEntry(userID: userId, itemId: row.itemId, quantity: 1, carrying: state).save(on: tx)
        }
        return .moved(1)
    }

    /// One piece of gear from the wagon into the warehouse, with its own state,
    /// never past the warehouse's cap. Allowed whether or not the hire runs.
    public static func unloadPiece(cargoRowId: UUID, for user: User, on db: any Database) async throws -> MoveResult {
        guard let userId = user.id, try await isHome(user, on: db) else { return .notHere }
        guard let pile = try await WagonCargoEntry.query(on: db)
            .filter(\.$user.$id, .equal, userId)
            .filter(\.$id, .equal, cargoRowId)
            .first() else { return .nothingToMove }
        let free = try await warehouseFree(for: user, on: db)
        guard free >= pile.quantity else { return .warehouseFull(free: free) }
        let isGear = ItemCatalog.find(pile.itemId)?.stackable == false
        try await db.transaction { tx in
            try await WarehouseEntry.add(pile.itemId, quantity: pile.quantity, to: user, on: tx,
                                         carrying: isGear ? pile.gearState : nil)
            try await pile.delete(on: tx)
        }
        return .moved(pile.quantity)
    }

    /// «📦 Розвантажити все»: every pile, oldest first, until the warehouse is
    /// full. Returns what moved and what stayed on the wagon.
    public static func unloadAll(for user: User, on db: any Database, now: Date = Date()) async throws -> (moved: Int, left: Int)? {
        guard try await atHome(for: user, on: db, now: now) != nil else { return nil }
        return try await deliver(for: user, on: db)
    }

    // MARK: - The end of a hire

    /// What the watchman tells a player once their hire has run out.
    public struct Settlement: Sendable {
        public let telegramId: Int64
        public let locale: String
        public let moved: Int
        public let left: Int
    }

    /// Every hire that has run out and not yet been settled: its cargo goes
    /// into the warehouse up to the cap, and the marker is written in the same
    /// transaction — before the notice is pushed, so it goes out once.
    public static func settleEnded(on db: any Database, now: Date = Date()) async throws -> [Settlement] {
        let ended = try await Wagon.query(on: db)
            .filter(\.$endsAt, .lessThanOrEqual, now)
            .with(\.$user)
            .all()
            .filter { $0.settledEnd != $0.endsAt }
        var out: [Settlement] = []
        for wagon in ended {
            let user = await sessionCache.peek(telegramId: wagon.user.telegramId) ?? wagon.user
            let result = try await db.transaction { tx -> (moved: Int, left: Int) in
                guard let row = try await Wagon.find(wagon.id, on: tx), row.endsAt <= now,
                      row.settledEnd != row.endsAt else { return (-1, 0) }
                let delivered = try await deliver(for: user, on: tx)
                row.settledEnd = row.endsAt
                try await row.save(on: tx)
                return delivered
            }
            guard result.moved >= 0 else { continue }
            out.append(Settlement(telegramId: user.telegramId, locale: user.locale, moved: result.moved, left: result.left))
        }
        return out
    }

    /// A wagon whose hire has run out with cargo still on it moves what now
    /// fits into the warehouse — quietly, on every sweep, until it is empty.
    public static func settleRemainders(on db: any Database, now: Date = Date()) async throws {
        let ended = try await Wagon.query(on: db)
            .filter(\.$endsAt, .lessThanOrEqual, now)
            .with(\.$user)
            .all()
            .filter { $0.settledEnd == $0.endsAt }
        for wagon in ended {
            let userId = wagon.$user.id
            guard try await used(for: userId, on: db) > 0 else { continue }
            let user = await sessionCache.peek(telegramId: wagon.user.telegramId) ?? wagon.user
            guard try await warehouseFree(for: user, on: db) > 0 else { continue }
            _ = try await db.transaction { tx in try await deliver(for: user, on: tx) }
        }
    }

    // MARK: - Internals

    public enum WagonError: Error, Sendable {
        case drainFailed(String)
    }

    /// The warehouse's free places — its own cap, nobody exempt.
    static func warehouseFree(for user: User, on db: any Database) async throws -> Int {
        max(0, WarehouseService.capForLevel(user.estateLevel) - (try await WarehouseService.slotsUsed(for: user, on: db)))
    }

    /// Every pile into the warehouse, oldest first, until it is full.
    static func deliver(for user: User, on db: any Database) async throws -> (moved: Int, left: Int) {
        let userId = try user.requireID()
        let piles = try await cargo(for: userId, on: db)
        let moves = WagonMath.deliver(piles.map(\.quantity), warehouseFree: try await warehouseFree(for: user, on: db))
        var moved = 0
        for (pile, count) in zip(piles, moves) where count > 0 {
            // A piece of gear goes back with its own wear and enchant.
            let isGear = ItemCatalog.find(pile.itemId)?.stackable == false
            try await WarehouseEntry.add(pile.itemId, quantity: count, to: user, on: db,
                                         carrying: isGear ? pile.gearState : nil)
            if count >= pile.quantity {
                try await pile.delete(on: db)
            } else {
                pile.quantity -= count
                try await pile.save(on: db)
            }
            moved += count
        }
        let left = piles.reduce(0) { $0 + $1.quantity } - moved
        return (moved, max(0, left))
    }

    /// A stackable merges into its one pile; a piece of gear is a row of its
    /// own, carrying `state` (or the item's fresh state), as the warehouse does.
    static func addCargo(_ itemId: String, quantity: Int, userId: UUID, on db: any Database,
                         carrying state: GearState? = nil) async throws {
        guard quantity > 0 else { return }
        guard ItemCatalog.find(itemId)?.stackable != false else {
            for _ in 0..<quantity {
                try await WagonCargoEntry(userID: userId, itemId: itemId, quantity: 1, carrying: state).save(on: db)
            }
            return
        }
        if let pile = try await WagonCargoEntry.query(on: db)
            .filter(\.$user.$id, .equal, userId)
            .filter(\.$itemId, .equal, itemId)
            .first() {
            pile.quantity += quantity
            try await pile.save(on: db)
        } else {
            try await WagonCargoEntry(userID: userId, itemId: itemId, quantity: quantity, carrying: state).save(on: db)
        }
    }

    /// Takes `quantity` units of an item off the wagon, oldest pile first.
    /// False, with nothing changed, when the wagon holds fewer.
    @discardableResult
    static func removeCargo(_ itemId: String, quantity: Int, userId: UUID, on db: any Database) async throws -> Bool {
        guard quantity > 0 else { return true }
        let piles = try await WagonCargoEntry.query(on: db)
            .filter(\.$user.$id, .equal, userId)
            .filter(\.$itemId, .equal, itemId)
            .sort(\.$createdAt, .ascending)
            .all()
        guard piles.reduce(0, { $0 + $1.quantity }) >= quantity else { return false }
        var remaining = quantity
        for pile in piles where remaining > 0 {
            if pile.quantity <= remaining {
                remaining -= pile.quantity
                try await pile.delete(on: db)
            } else {
                pile.quantity -= remaining
                remaining = 0
                try await pile.save(on: db)
            }
        }
        return true
    }
}
