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

// MARK: - Item

public struct Item: Sendable {
    public let id: String
    public let nameKey: String
    public let type: ItemType
    public let tier: Int
    public let stackable: Bool
    public let effects: [ItemEffect]
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

        // Gear (stats to be attached in Phase 2.3; placeholder entries for now)
        Item(id: "gear.rusty_sword",    nameKey: "item.gear.rusty_sword",   type: .gear,     tier: 1, stackable: false, effects: []),
        Item(id: "gear.simple_bow",     nameKey: "item.gear.simple_bow",    type: .gear,     tier: 1, stackable: false, effects: []),
        Item(id: "gear.wooden_staff",   nameKey: "item.gear.wooden_staff",  type: .gear,     tier: 1, stackable: false, effects: []),
        Item(id: "gear.leather_vest",   nameKey: "item.gear.leather_vest",  type: .gear,     tier: 1, stackable: false, effects: []),

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
