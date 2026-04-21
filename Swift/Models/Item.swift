//
//  Item.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 19.04.2026.
//
//  Static item catalog. Items live in code, not the database.
//  Player-owned quantities live in the `inventory` table (see InventoryEntry).
//

import Foundation

// MARK: - Item Type

public enum ItemType: String, Codable, CaseIterable, Sendable {
    case food
    case material
    case gear
    case potion
    case artifact

    public var icon: String {
        switch self {
        case .food:     return "🍖"
        case .material: return "🪨"
        case .potion:   return "🧪"
        case .gear:     return "🗡"
        case .artifact: return "💎"
        }
    }

    /// Localization key for the action button next to each item row in the inventory
    /// (e.g. "Eat" for food, "Equip" for gear). Nil for materials — they have no
    /// player-facing action; they're consumed by crafting recipes instead.
    public var actionKey: String? {
        guard self != .material else { return nil }
        return "inventory.action.\(rawValue)"
    }
}

// MARK: - Item Effect

public enum ItemEffect: Sendable {
    case restoreHunger(Int)
    case restoreHP(Int)
}

// MARK: - Equipment Slot

public enum EquipmentSlot: String, Codable, CaseIterable, Sendable {
    case helmet
    case chest
    case legs
    case boots
    case mainHand   = "main_hand"
    case offHand    = "off_hand"
    case accessory1 = "accessory_1"
    case accessory2 = "accessory_2"
}

// MARK: - Gear Stats

/// Passive stat bonuses granted while the item is equipped.
/// All fields default to 0 — callers only specify what the piece actually boosts.
public struct GearStats: Sendable {
    public let attack: Int
    public let defense: Int
    public let crit: Int
    public let dodge: Int
    public let accuracy: Int

    public init(attack: Int = 0, defense: Int = 0, crit: Int = 0, dodge: Int = 0, accuracy: Int = 0) {
        self.attack = attack
        self.defense = defense
        self.crit = crit
        self.dodge = dodge
        self.accuracy = accuracy
    }
}

// MARK: - Item

public struct Item: Sendable {
    public let id: String
    public let nameKey: String
    public let type: ItemType
    public let tier: Int
    public let stackable: Bool
    public let effects: [ItemEffect]
    /// Set only for gear items — which body slot this piece occupies.
    public let slot: EquipmentSlot?
    /// Set only for gear items — bonuses applied while equipped.
    public let gearStats: GearStats?
    /// Per-item display glyph shown next to the name in the inventory list
    /// (e.g. ⚔️ for a sword, 🏹 for a bow). Shown regardless of whether the item
    /// is equipped. Distinct from `ItemType.icon`, which is the type-level header
    /// glyph used in the root-category buttons.
    public let icon: String?

    public init(
        id: String,
        nameKey: String,
        type: ItemType,
        tier: Int,
        stackable: Bool,
        effects: [ItemEffect],
        slot: EquipmentSlot? = nil,
        gearStats: GearStats? = nil,
        icon: String? = nil
    ) {
        self.id = id
        self.nameKey = nameKey
        self.type = type
        self.tier = tier
        self.stackable = stackable
        self.effects = effects
        self.slot = slot
        self.gearStats = gearStats
        self.icon = icon
    }
}

// MARK: - Catalog

public enum ItemCatalog {
    public static let all: [Item] = [
        // Food
        Item(id: "food.berry",          nameKey: "item.food.berry",         type: .food,     tier: 1, stackable: true,  effects: [.restoreHunger(15)]),
        Item(id: "food.bread",          nameKey: "item.food.bread",         type: .food,     tier: 1, stackable: true,  effects: [.restoreHunger(20)]),
        Item(id: "food.stew",           nameKey: "item.food.stew",          type: .food,     tier: 2, stackable: true,  effects: [.restoreHunger(40)]),
        Item(id: "food.roast",          nameKey: "item.food.roast",         type: .food,     tier: 3, stackable: true,  effects: [.restoreHunger(80)]),

        // Materials
        Item(id: "mat.wood",            nameKey: "item.mat.wood",           type: .material, tier: 1, stackable: true,  effects: []),
        Item(id: "mat.stone",           nameKey: "item.mat.stone",          type: .material, tier: 1, stackable: true,  effects: []),
        Item(id: "mat.iron_ore",        nameKey: "item.mat.iron_ore",       type: .material, tier: 2, stackable: true,  effects: []),
        Item(id: "mat.hide",            nameKey: "item.mat.hide",           type: .material, tier: 1, stackable: true,  effects: []),

        // Potions
        Item(id: "potion.heal_small",   nameKey: "item.potion.heal_small",  type: .potion,   tier: 1, stackable: true,  effects: [.restoreHP(30)]),
        Item(id: "potion.heal_medium",  nameKey: "item.potion.heal_medium", type: .potion,   tier: 2, stackable: true,  effects: [.restoreHP(60)]),

        // Gear — starter loadouts. Slot + gearStats wired in Phase 2.3.1.
        Item(id: "gear.rusty_sword",    nameKey: "item.gear.rusty_sword",   type: .gear,     tier: 1, stackable: false, effects: [],
             slot: .mainHand, gearStats: GearStats(attack: 3), icon: "⚔️"),
        Item(id: "gear.simple_bow",     nameKey: "item.gear.simple_bow",    type: .gear,     tier: 1, stackable: false, effects: [],
             slot: .mainHand, gearStats: GearStats(attack: 2, accuracy: 1), icon: "🏹"),
        Item(id: "gear.wooden_staff",   nameKey: "item.gear.wooden_staff",  type: .gear,     tier: 1, stackable: false, effects: [],
             slot: .mainHand, gearStats: GearStats(attack: 2, crit: 1), icon: "🪄"),
        Item(id: "gear.leather_vest",   nameKey: "item.gear.leather_vest",  type: .gear,     tier: 1, stackable: false, effects: [],
             slot: .chest, gearStats: GearStats(defense: 2), icon: "🦺"),

        // Artifacts (crafting recipes will become a separate system in Phase 5.3 — not an item type)
        Item(id: "artifact.shrine_coin", nameKey: "item.artifact.shrine_coin", type: .artifact, tier: 3, stackable: true, effects: []),
    ]

    private static let lookup: [String: Item] = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })

    public static func find(_ id: String) -> Item? {
        return lookup[id]
    }

    public static func items(of type: ItemType) -> [Item] {
        return all.filter { $0.type == type }
    }
}
