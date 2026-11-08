//
//  Wagon.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 08.11.2026.
//
//  The wagon a player hired at the stable («🫏 Віз», `content/spec/spec-wagon.md`)
//  and what is on it. One `Wagon` row a player, kept once it has run out so a
//  new hire takes the same wagon with whatever is still on it (§3.5). The cargo
//  is the warehouse's shape (the owner, 2026-11-08: anything the warehouse takes
//  rides on it): one row per stackable item, one row per piece of gear carrying
//  its own `GearState` — a piece that rode on the wagon comes off it as worn and
//  as enchanted as it went on.
//
//  Where the wagon IS is never stored: it rides with the player on the road and
//  in town and waits in the yard while they are in the forest (§3.2), so the
//  player's own location answers the question. `WagonService` owns every rule.
//

import Fluent
import Foundation

final public class Wagon: Model, @unchecked Sendable {
    public static let schema = "wagons"

    @ID(key: .id)
    public var id: UUID?

    @Parent(key: "user_id")
    public var user: User

    /// When the hire runs out.
    @Field(key: "ends_at")
    public var endsAt: Date

    /// The end the watchman has settled — delivered the cargo for and
    /// announced. Written before the notice goes out; a new hire moves
    /// `endsAt` past it, which is what arms the next settlement.
    @OptionalField(key: "settled_end")
    public var settledEnd: Date?

    @Timestamp(key: "created_at", on: .create)
    public var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    public var updatedAt: Date?

    public init() {}

    public init(userID: UUID, endsAt: Date) {
        self.$user.id = userID
        self.endsAt = endsAt
        self.settledEnd = nil
    }

    /// True while the hire runs: the wagon follows the player and takes cargo.
    public func isRunning(at now: Date = Date()) -> Bool {
        endsAt > now
    }
}

/// One pile on a wagon: a stackable item's units, or one piece of gear with its
/// own tier, wear and enchant — the four `GearState` columns the warehouse and
/// the bag carry, defaults on a stackable.
final public class WagonCargoEntry: Model, @unchecked Sendable {
    public static let schema = "wagon_cargo"

    @ID(key: .id)
    public var id: UUID?

    @Parent(key: "user_id")
    public var user: User

    @Field(key: "item_id")
    public var itemId: String

    @Field(key: "quantity")
    public var quantity: Int

    @Field(key: "tier")
    public var tier: Int

    @Field(key: "durability")
    public var durability: Int

    @Field(key: "max_durability")
    public var maxDurability: Int

    @Field(key: "enchant_level")
    public var enchantLevel: Int

    @Timestamp(key: "created_at", on: .create)
    public var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    public var updatedAt: Date?

    public init() {}

    /// `carrying` stamps a piece's own state; nil mints the item's fresh one,
    /// as `WarehouseEntry` does.
    public init(userID: UUID, itemId: String, quantity: Int, carrying state: GearState? = nil) {
        let state = state ?? .fresh(for: itemId)
        self.$user.id = userID
        self.itemId = itemId
        self.quantity = quantity
        self.tier = state.tier
        self.durability = state.durability
        self.maxDurability = state.maxDurability
        self.enchantLevel = state.enchantLevel
    }

    /// The piece's state as a value, to hand back to the warehouse.
    public var gearState: GearState {
        GearState(tier: tier, durability: durability, maxDurability: maxDurability, enchantLevel: enchantLevel)
    }
}
