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
    /// (e.g. ⚔️ for a sword, 🏹 for a bow, 🪵 for pine lumber). Shown regardless
    /// of whether the item is equipped. Distinct from `ItemType.icon`, which is
    /// the type-level header glyph used in the root-category buttons.
    public let icon: String?
    /// Optional localization key for the lore blurb shown when the player
    /// taps the item's info button. Nil = fall back to the generic
    /// "%{name} — description coming soon" placeholder.
    public let descriptionKey: String?

    public init(
        id: String,
        nameKey: String,
        type: ItemType,
        tier: Int,
        stackable: Bool,
        effects: [ItemEffect],
        slot: EquipmentSlot? = nil,
        gearStats: GearStats? = nil,
        icon: String? = nil,
        descriptionKey: String? = nil
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
        self.descriptionKey = descriptionKey
    }
}

// MARK: - Catalog

public enum ItemCatalog {
    public static let all: [Item] = [
        // Food — raw foragables + kill drops. Cooked variants will come from
        // the Kitchen (Phase 5.3). Potato is the one strategic ingredient:
        // inedible raw, only useful once cooking lands.
        Item(id: "food.forest_berries", nameKey: "item.food.forest_berries", type: .food, tier: 1, stackable: true,
             effects: [.restoreHunger(15)], icon: "🫐", descriptionKey: "item.food.forest_berries.desc"),
        Item(id: "food.forest_nuts",    nameKey: "item.food.forest_nuts",    type: .food, tier: 1, stackable: true,
             effects: [.restoreHunger(20)], icon: "🌰", descriptionKey: "item.food.forest_nuts.desc"),
        Item(id: "food.potato",         nameKey: "item.food.potato",         type: .food, tier: 1, stackable: true,
             effects: [],                   icon: "🥔", descriptionKey: "item.food.potato.desc"),
        Item(id: "food.duck_egg",       nameKey: "item.food.duck_egg",       type: .food, tier: 1, stackable: true,
             effects: [.restoreHunger(25)], icon: "🥚", descriptionKey: "item.food.duck_egg.desc"),
        Item(id: "food.raw_meat",       nameKey: "item.food.raw_meat",       type: .food, tier: 2, stackable: true,
             effects: [], icon: "🥩", descriptionKey: "item.food.raw_meat.desc"),

        // Materials — estate-upgrade resources. Icons + descriptions show
        // on the inventory info-button modal.
        Item(id: "mat.pine_lumber",     nameKey: "item.mat.pine_lumber",    type: .material, tier: 1, stackable: true,  effects: [],
             icon: "🪵", descriptionKey: "item.mat.pine_lumber.desc"),
        Item(id: "mat.river_pebble",    nameKey: "item.mat.river_pebble",   type: .material, tier: 1, stackable: true,  effects: [],
             icon: "🪨", descriptionKey: "item.mat.river_pebble.desc"),
        Item(id: "mat.clay",            nameKey: "item.mat.clay",           type: .material, tier: 1, stackable: true,  effects: [],
             icon: "🧱", descriptionKey: "item.mat.clay.desc"),
        // `mat.iron` is the RAW resource — a lump pulled from the rock.
        // Found rarely in exploration foraging and trickled out by the Mine
        // plot. The crafted Iron Ingot (`mat.iron_ingot`, below) is the
        // refined form used by Workshop recipes; the planned recipe is
        // 10 lumps → 1 ingot.
        Item(id: "mat.iron",            nameKey: "item.mat.iron",           type: .material, tier: 2, stackable: true,  effects: [],
             icon: "🔩", descriptionKey: "item.mat.iron.desc"),
        Item(id: "mat.iron_ingot",      nameKey: "item.mat.iron_ingot",     type: .material, tier: 3, stackable: true,  effects: [],
             icon: "🔳", descriptionKey: "item.mat.iron_ingot.desc"),
        Item(id: "mat.hide",            nameKey: "item.mat.hide",           type: .material, tier: 1, stackable: true,  effects: [],
             icon: "🟫", descriptionKey: "item.mat.hide.desc"),

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
