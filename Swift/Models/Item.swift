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
//
// `EquipmentSlot` moved to `ROIContent/Vocabulary.swift` in Phase 8 — a slot id
// is written in `items.json` and in `tuning/budget.json`, so the validator and
// the simulator need it as much as the game does.

// MARK: - Gear Stats

/// Passive stat bonuses granted while the item is equipped.
/// All fields default to 0 — callers only specify what the piece actually boosts.
public struct GearStats: Sendable {
    public let attack: Int
    public let defense: Int
    /// Flat max HP. See `GearStatsDTO.hp` for why the budget model needs it.
    public let hp: Int
    public let crit: Int
    public let dodge: Int
    public let accuracy: Int

    public init(attack: Int = 0, defense: Int = 0, hp: Int = 0, crit: Int = 0,
                dodge: Int = 0, accuracy: Int = 0) {
        self.attack = attack
        self.defense = defense
        self.hp = hp
        self.crit = crit
        self.dodge = dodge
        self.accuracy = accuracy
    }

    /// Scale every stat by the same factor, rounding each independently.
    ///
    /// This is what an enchant IS as of Phase 6: a percentage of the item's own
    /// budget, which is the same thing as a percentage of the stats that budget
    /// was spent on. A flat bonus cannot work at any size — +32 DEF is 267% of
    /// a level-1 chest piece and 14% of a level-40 one.
    public func scaled(by factor: Double) -> GearStats {
        func s(_ value: Int) -> Int { Int((Double(value) * factor).rounded()) }
        return GearStats(attack: s(attack), defense: s(defense), hp: s(hp),
                         crit: s(crit), dodge: s(dodge), accuracy: s(accuracy))
    }
}

// MARK: - Item

public struct Item: Sendable {
    public let id: String
    public let nameKey: String
    public let type: ItemType
    /// Crafting-ladder position and display concept (1–5). NOT the budget
    /// input — see `itemLevel`.
    public let tier: Int
    /// Input to `budget(itemLevel, slot, rarity)`. 1 for anything unequippable.
    public let itemLevel: Int
    /// Rarity id, resolved against the loaded rarity ladder. "common" by default.
    public let rarity: String
    /// Set membership; nil when the item belongs to no set.
    public let setId: String?
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
        itemLevel: Int = 1,
        rarity: String = "common",
        setId: String? = nil,
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
        self.itemLevel = itemLevel
        self.rarity = rarity
        self.setId = setId
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

/// Façade over the live content snapshot. The item roster now lives in
/// `content/data/items.json`; this type only routes lookups.
///
/// `all` changed from `static let` to a computed property, so the first read
/// happens after `ContentBootstrap.load` rather than at type-init. Reading any
/// catalog before that traps with a message naming the ordering rule — see
/// `Catalogs.current`.
public enum ItemCatalog {
    public static var all: [Item] { Catalogs.current.items }

    public static func find(_ id: String) -> Item? {
        return Catalogs.current.itemsById[id]
    }

    public static func items(of type: ItemType) -> [Item] {
        return Catalogs.current.itemsByType[type] ?? []
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

    /// Rarity glyph to prefix a name with, or "" for the baseline rarity.
    ///
    /// Skipping the baseline is the point: every shipped item is common, and a
    /// ⚪ on all thirty-three of them would be noise rather than information.
    /// A glyph appears only when the item is actually out of the ordinary.
    public static func rarityPrefix(for item: Item) -> String {
        guard let baseline = RarityCatalog.all.first?.id, item.rarity != baseline,
              let rarity = RarityCatalog.find(item.rarity) else { return "" }
        return rarity.glyph + " "
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
