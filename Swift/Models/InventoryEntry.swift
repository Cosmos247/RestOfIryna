//
//  InventoryEntry.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 19.04.2026.
//
//  One row per item stack per user. Stackable items are merged into a single
//  row by the `add` helper; non-stackable items (gear) occupy a row each.
//

import Fluent
import Foundation

final public class InventoryEntry: Model, @unchecked Sendable {
    public static let schema = "inventory"

    @ID(key: .id)
    public var id: UUID?

    @Parent(key: "user_id")
    public var user: User

    @Field(key: "item_id")
    public var itemId: String

    @Field(key: "quantity")
    public var quantity: Int

    /// When non-nil, this stack is equipped to the named EquipmentSlot (raw value).
    /// Nil means the item is just carried in the backpack.
    @Field(key: "equipped_slot")
    public var equippedSlot: String?

    /// Upgrade tier for items that participate in `WeaponUpgradeCatalog` —
    /// the three class starter weapons. Defaults to 1 for every row, so
    /// non-tiered items just ignore the column. Bumped by `WeaponUpgradeService`
    /// when the player upgrades the weapon at the Workshop.
    @Field(key: "tier")
    public var tier: Int

    /// Phase 6.5 — gear durability. Drains with every fight (see
    /// `GearConditionService`) for armor and the main-hand weapon. At 0: armor is
    /// "broken" (no stats), the weapon keeps half its stats. Repair restores full
    /// at the Master — armor's `maxDurability` is shaved 1 each time (it wears
    /// out), the weapon's max holds (per-tier 30→100, never shaved). `init`
    /// stamps a flat 30; weapons get their tier ceiling on upgrade / backfill.
    /// Other rows keep these full and never drain.
    @Field(key: "durability")
    public var durability: Int

    @Field(key: "max_durability")
    public var maxDurability: Int

    /// Phase 6.5 — permanent armor enchant level (0…`MasterCatalog.enchantCap`).
    /// Grants defense plus a class-identity bonus via `EquipmentService`, scaling
    /// on the non-linear `MasterCatalog.enchantBonusPoints` curve. Bought at the
    /// Master for silver + materials. Weapons stay at 0 (gem inlay later).
    @Field(key: "enchant_level")
    public var enchantLevel: Int

    @Timestamp(key: "created_at", on: .create)
    public var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    public var updatedAt: Date?

    public init() {}

    public init(userID: UUID, itemId: String, quantity: Int) {
        self.$user.id = userID
        self.itemId = itemId
        self.quantity = quantity
        self.tier = 1
        self.durability = GearConditionService.maxDurabilityStart
        self.maxDurability = GearConditionService.maxDurabilityStart
        self.enchantLevel = 0
    }
}

// MARK: - Errors

public enum InventoryError: Error, Sendable {
    case unknownItem(String)
    case userNotPersisted
    case inventoryFull
}

// MARK: - Helpers (add / remove / has / list)

extension InventoryEntry {
    /// Per-user backpack slot cap. Driven by `User.bagTier` via `BagCatalog`
    /// — T1 starts at 25, T6 caps at 85. Each unit takes a slot (`bread × 50`
    /// occupies 50). Equipped gear rows don't count — they're "on the body"
    /// rather than in the bag.
    public static func slotCap(for user: User) -> Int {
        return BagCatalog.capForTier(user.bagTier)
    }

    /// Total units in the user's backpack (sum of `quantity` across all
    /// non-equipped rows). Per-unit accounting was the deliberate switch on
    /// 2026-05-12 — one stack-row used to be one slot; now `flour × 8` costs
    /// 8 slots, matching most RPG inventory feels.
    public static func slotsUsed(for user: User, on db: any Database) async throws -> Int {
        guard let userId = user.id else { return 0 }
        let rows = try await InventoryEntry.query(on: db)
            .filter(\.$user.$id, .equal, userId)
            .all()
        return rows.filter { $0.equippedSlot == nil }.reduce(0) { $0 + $1.quantity }
    }

    /// True if adding `quantity` units of the item would fit. Per-unit
    /// counting means stackable and non-stackable items follow the same
    /// rule: `used + quantity <= cap`. Developer accounts always accept.
    public static func canAccept(_ itemId: String, quantity: Int = 1, for user: User, on db: any Database) async throws -> Bool {
        guard quantity > 0 else { return true }
        guard ItemCatalog.find(itemId) != nil, user.id != nil else { return false }

        // Dev bypass: cap is still shown in UI but never enforced.
        if user.isDeveloper { return true }

        let used = try await slotsUsed(for: user, on: db)
        return used + quantity <= slotCap(for: user)
    }

    /// Add an item to a user's inventory. Stackable items merge into an existing row;
    /// non-stackable items create a new row per unit. Throws `InventoryError.inventoryFull`
    /// if the slot cap would be exceeded — caller must surface that to the UI.
    /// Developer accounts skip the cap check entirely.
    public static func add(_ itemId: String, quantity: Int = 1, to user: User, on db: any Database) async throws {
        guard quantity > 0 else { return }
        guard let item = ItemCatalog.find(itemId) else {
            throw InventoryError.unknownItem(itemId)
        }
        guard let userId = user.id else {
            throw InventoryError.userNotPersisted
        }

        // Per-unit cap check — same rule for stackable and non-stackable.
        // Devs bypass: count grows past cap and UI just shows the overflow.
        if !user.isDeveloper {
            let used = try await slotsUsed(for: user, on: db)
            guard used + quantity <= slotCap(for: user) else { throw InventoryError.inventoryFull }
        }

        if item.stackable {
            if let existing = try await InventoryEntry.query(on: db)
                .filter(\.$user.$id, .equal, userId)
                .filter(\.$itemId, .equal, itemId)
                .first() {
                existing.quantity += quantity
                try await existing.save(on: db)
                return
            }
            try await InventoryEntry(userID: userId, itemId: itemId, quantity: quantity).save(on: db)
        } else {
            // Non-stackable — each unit is its own row.
            for _ in 0..<quantity {
                try await InventoryEntry(userID: userId, itemId: itemId, quantity: 1).save(on: db)
            }
        }
    }

    /// Remove `quantity` of an item from inventory. Returns `false` if the user
    /// doesn't have enough — in that case nothing is changed.
    @discardableResult
    public static func remove(_ itemId: String, quantity: Int = 1, from user: User, on db: any Database) async throws -> Bool {
        guard quantity > 0 else { return true }
        guard let userId = user.id else { return false }

        let available = try await totalQuantity(of: itemId, for: userId, on: db)
        guard available >= quantity else { return false }

        var remaining = quantity
        let rows = try await InventoryEntry.query(on: db)
            .filter(\.$user.$id, .equal, userId)
            .filter(\.$itemId, .equal, itemId)
            .sort(\.$createdAt, .ascending)
            .all()

        for row in rows {
            if remaining == 0 { break }
            if row.quantity <= remaining {
                remaining -= row.quantity
                try await row.delete(on: db)
            } else {
                row.quantity -= remaining
                remaining = 0
                try await row.save(on: db)
            }
        }
        return true
    }

    /// True if the user has at least `quantity` of the item.
    public static func has(_ itemId: String, quantity: Int = 1, user: User, on db: any Database) async throws -> Bool {
        guard let userId = user.id else { return false }
        let total = try await totalQuantity(of: itemId, for: userId, on: db)
        return total >= quantity
    }

    /// Total quantity of a specific item across all rows for a user.
    public static func totalQuantity(of itemId: String, for userId: UUID, on db: any Database) async throws -> Int {
        let rows = try await InventoryEntry.query(on: db)
            .filter(\.$user.$id, .equal, userId)
            .filter(\.$itemId, .equal, itemId)
            .all()
        return rows.reduce(0) { $0 + $1.quantity }
    }

    /// All inventory rows for a user (unordered).
    public static func list(for user: User, on db: any Database) async throws -> [InventoryEntry] {
        guard let userId = user.id else { return [] }
        return try await InventoryEntry.query(on: db)
            .filter(\.$user.$id, .equal, userId)
            .all()
    }
}
