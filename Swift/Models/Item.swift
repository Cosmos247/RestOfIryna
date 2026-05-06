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
    case restoreVigor(Int)
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
    /// Set on artifacts that act as recipe scrolls — using the artifact
    /// teaches the named recipe via `LearnedRecipe.add` and consumes the
    /// scroll. The inventory action button switches from "✨ Use" to
    /// "📖 Learn" whenever this is non-nil. Phase 5.2.1.
    public let teachesRecipe: String?

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
        descriptionKey: String? = nil,
        teachesRecipe: String? = nil
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
        self.teachesRecipe = teachesRecipe
    }
}

// MARK: - Catalog

public enum ItemCatalog {
    public static let all: [Item] = [
        // Food — raw foragables + kill drops. Cooked variants will come from
        // the Kitchen (Phase 5.3). Potato is the one strategic ingredient:
        // inedible raw, only useful once cooking lands.
        Item(id: "food.forest_berries", nameKey: "item.food.forest_berries", type: .food, tier: 1, stackable: true,
             effects: [.restoreVigor(4)],  icon: "🫐", descriptionKey: "item.food.forest_berries.desc"),
        Item(id: "food.forest_nuts",    nameKey: "item.food.forest_nuts",    type: .food, tier: 1, stackable: true,
             effects: [.restoreVigor(5)],  icon: "🌰", descriptionKey: "item.food.forest_nuts.desc"),
        Item(id: "food.potato",         nameKey: "item.food.potato",         type: .food, tier: 1, stackable: true,
             effects: [],                   icon: "🥔", descriptionKey: "item.food.potato.desc"),
        Item(id: "food.duck_egg",       nameKey: "item.food.duck_egg",       type: .food, tier: 1, stackable: true,
             effects: [.restoreVigor(7)],  icon: "🥚", descriptionKey: "item.food.duck_egg.desc"),
        Item(id: "food.raw_meat",       nameKey: "item.food.raw_meat",       type: .food, tier: 2, stackable: true,
             effects: [], icon: "🥩", descriptionKey: "item.food.raw_meat.desc"),

        // Cooked food — Kitchen recipes (Phase 5.2.1). Tuning intent: cooked
        // dishes give meaningfully more vigor than raw foragables (15-25)
        // but stay below the small healing potion (+30 HP) on the HP side
        // so food doesn't displace potions.
        Item(id: "food.baked_potato",    nameKey: "item.food.baked_potato",    type: .food, tier: 1, stackable: true,
             effects: [.restoreVigor(9)],  icon: "🍠", descriptionKey: "item.food.baked_potato.desc"),
        Item(id: "food.roasted_meat",    nameKey: "item.food.roasted_meat",    type: .food, tier: 1, stackable: true,
             effects: [.restoreVigor(12)], icon: "🍗", descriptionKey: "item.food.roasted_meat.desc"),
        Item(id: "food.foragers_omelette", nameKey: "item.food.foragers_omelette", type: .food, tier: 2, stackable: true,
             effects: [.restoreVigor(16), .restoreHP(3)], icon: "🍳", descriptionKey: "item.food.foragers_omelette.desc"),
        Item(id: "food.hunters_stew",    nameKey: "item.food.hunters_stew",    type: .food, tier: 2, stackable: true,
             effects: [.restoreVigor(20), .restoreHP(5)], icon: "🍲", descriptionKey: "item.food.hunters_stew.desc"),
        Item(id: "food.meat_ragout",     nameKey: "item.food.meat_ragout",     type: .food, tier: 2, stackable: true,
             effects: [.restoreVigor(18), .restoreHP(4)], icon: "🥘", descriptionKey: "item.food.meat_ragout.desc"),
        Item(id: "food.berry_tart",      nameKey: "item.food.berry_tart",      type: .food, tier: 2, stackable: true,
             effects: [.restoreVigor(16), .restoreHP(6)], icon: "🥧", descriptionKey: "item.food.berry_tart.desc"),
        Item(id: "food.governors_feast", nameKey: "item.food.governors_feast", type: .food, tier: 3, stackable: true,
             effects: [.restoreVigor(35), .restoreHP(10)], icon: "🍽", descriptionKey: "item.food.governors_feast.desc"),

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
        // Class starter weapons — granted by the King at registration. Stats are
        // the T1 baseline from `WeaponUpgradeCatalog`; subsequent tiers are
        // applied via `InventoryEntry.tier` and `EquipmentService.recomputeBonuses`,
        // which prefer the catalog over `gearStats` when the item is upgradable.
        // Display name / description keys resolve through `ItemDisplay.nameKey(for:tier:)`.
        Item(id: "gear.rusty_sword",    nameKey: "item.gear.rusty_sword",   type: .gear,     tier: 1, stackable: false, effects: [],
             slot: .mainHand, gearStats: GearStats(attack: 3), icon: "⚔️", descriptionKey: "item.gear.rusty_sword.desc"),
        Item(id: "gear.simple_bow",     nameKey: "item.gear.simple_bow",    type: .gear,     tier: 1, stackable: false, effects: [],
             slot: .mainHand, gearStats: GearStats(attack: 2, accuracy: 1), icon: "🏹", descriptionKey: "item.gear.simple_bow.desc"),
        Item(id: "gear.wooden_staff",   nameKey: "item.gear.wooden_staff",  type: .gear,     tier: 1, stackable: false, effects: [],
             slot: .mainHand, gearStats: GearStats(attack: 2, crit: 1), icon: "🪄", descriptionKey: "item.gear.wooden_staff.desc"),
        // Forester's set — first craftable armor (Phase 5.2 Workshop / Tannery).
        // `gear.forester_jerkin` succeeds the retired `gear.leather_vest`; old DB
        // rows are remapped by `RenameLeatherVest`. Set total = 16 hide for full
        // suit (+7 DEF / +1 dodge), tunable as new gear tiers come online.
        Item(id: "gear.forester_hood",     nameKey: "item.gear.forester_hood",     type: .gear, tier: 1, stackable: false, effects: [],
             slot: .helmet, gearStats: GearStats(defense: 1), icon: "🪖", descriptionKey: "item.gear.forester_hood.desc"),
        Item(id: "gear.forester_jerkin",   nameKey: "item.gear.forester_jerkin",   type: .gear, tier: 1, stackable: false, effects: [],
             slot: .chest,  gearStats: GearStats(defense: 3), icon: "🦺", descriptionKey: "item.gear.forester_jerkin.desc"),
        Item(id: "gear.forester_breeches", nameKey: "item.gear.forester_breeches", type: .gear, tier: 1, stackable: false, effects: [],
             slot: .legs,   gearStats: GearStats(defense: 2), icon: "👖", descriptionKey: "item.gear.forester_breeches.desc"),
        Item(id: "gear.forester_boots",    nameKey: "item.gear.forester_boots",    type: .gear, tier: 1, stackable: false, effects: [],
             slot: .boots,  gearStats: GearStats(defense: 1, dodge: 1), icon: "🥾", descriptionKey: "item.gear.forester_boots.desc"),

        // Artifacts. Recipe scrolls (Phase 5.2.1): each carries a
        // `teachesRecipe` link to the dish recipe it unlocks. Tapping
        // "📖 Learn" in the inventory adds an entry to `learned_recipes`
        // and removes the scroll. Non-stackable so each scroll is a
        // distinct row — duplicates can be traded once the market opens.
        Item(id: "artifact.shrine_coin", nameKey: "item.artifact.shrine_coin", type: .artifact, tier: 3, stackable: true, effects: []),
        // Baked Potato + Roasted Meat have no scroll — they're starter dishes
        // every player can cook from day one (gated as always-available via
        // `RecipeCatalog.starterRecipeIds`, no LearnedRecipe row required).
        Item(id: "artifact.recipe.foragers_omelette", nameKey: "item.artifact.recipe.foragers_omelette", type: .artifact, tier: 2, stackable: false,
             effects: [], icon: "📜", descriptionKey: "item.artifact.recipe.foragers_omelette.desc", teachesRecipe: "recipe.foragers_omelette"),
        Item(id: "artifact.recipe.hunters_stew", nameKey: "item.artifact.recipe.hunters_stew", type: .artifact, tier: 2, stackable: false,
             effects: [], icon: "📜", descriptionKey: "item.artifact.recipe.hunters_stew.desc", teachesRecipe: "recipe.hunters_stew"),
        Item(id: "artifact.recipe.meat_ragout", nameKey: "item.artifact.recipe.meat_ragout", type: .artifact, tier: 2, stackable: false,
             effects: [], icon: "📜", descriptionKey: "item.artifact.recipe.meat_ragout.desc", teachesRecipe: "recipe.meat_ragout"),
        Item(id: "artifact.recipe.berry_tart", nameKey: "item.artifact.recipe.berry_tart", type: .artifact, tier: 2, stackable: false,
             effects: [], icon: "📜", descriptionKey: "item.artifact.recipe.berry_tart.desc", teachesRecipe: "recipe.berry_tart"),
        Item(id: "artifact.recipe.governors_feast", nameKey: "item.artifact.recipe.governors_feast", type: .artifact, tier: 3, stackable: false,
             effects: [], icon: "📜", descriptionKey: "item.artifact.recipe.governors_feast.desc", teachesRecipe: "recipe.governors_feast"),
    ]

    private static let lookup: [String: Item] = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })

    public static func find(_ id: String) -> Item? {
        return lookup[id]
    }

    public static func items(of type: ItemType) -> [Item] {
        return all.filter { $0.type == type }
    }
}

// MARK: - Tier-aware display helpers (Phase 5.2.2)

/// One namespace for "what locale key shows this row's name / description?"
/// — answers depend on whether the item is a tiered weapon and what the
/// row's current tier is. Non-tiered items fall through to `Item.nameKey` /
/// `Item.descriptionKey` unchanged.
public enum ItemDisplay {
    /// Locale key for the row's display name. Tiered weapons resolve to
    /// `<base.nameKey>.t<tier>` (e.g. `item.gear.rusty_sword.t3`); other
    /// items return the item's static `nameKey`.
    public static func nameKey(for item: Item, tier: Int) -> String {
        guard WeaponUpgradeCatalog.isUpgradable(item.id) else { return item.nameKey }
        return "\(item.nameKey).t\(tier)"
    }

    /// Locale key for the row's lore blurb. Same tier rule, applied to the
    /// item's `descriptionKey`. Returns nil if the item itself has no
    /// description key (caller falls back to the placeholder modal).
    public static func descriptionKey(for item: Item, tier: Int) -> String? {
        guard let baseDesc = item.descriptionKey else { return nil }
        guard WeaponUpgradeCatalog.isUpgradable(item.id) else { return baseDesc }
        return "\(baseDesc).t\(tier)"
    }
}
