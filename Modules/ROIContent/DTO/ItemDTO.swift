//
//  ItemDTO.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 29.08.2026.
//
//  Wire format for `content/data/items.json`.
//
//  DTOs are deliberately separate from the domain `Item` struct. The validator
//  has to run on data that is not yet valid, and several domain types trap on
//  bad input (`ClosedRange` with min > max, `Dictionary(uniqueKeysWithValues:)`
//  on a duplicate id). Decoding into a tolerant DTO first means bad data is
//  reported, never constructed.
//
//  Decoders are written by hand rather than synthesized: Swift does not apply
//  a property's default value when a key is absent, and terse authoring
//  ("omit everything that is zero") is the whole point of the format.
//

import Foundation

// MARK: - Item effect

/// Tagged union. `kind` + a flat payload, so a future effect with more fields
/// (`{"kind":"buff","stat":"attack","amount":3,"seconds":600}`) does not change
/// the envelope, and an unknown `kind` fails with a coding path that names it.
public struct ItemEffectDTO: Codable, Sendable, Equatable {
    public enum Kind: String, Codable, Sendable {
        case restoreVigor = "restore_vigor"
        case restoreHP    = "restore_hp"
    }

    public let kind: Kind
    public let amount: Int

    public init(kind: Kind, amount: Int) {
        self.kind = kind
        self.amount = amount
    }
}

// MARK: - Gear stats

public struct GearStatsDTO: Codable, Sendable, Equatable {
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

    private enum CodingKeys: String, CodingKey {
        case attack, defense, crit, dodge, accuracy
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        attack   = try c.decodeIfPresent(Int.self, forKey: .attack)   ?? 0
        defense  = try c.decodeIfPresent(Int.self, forKey: .defense)  ?? 0
        crit     = try c.decodeIfPresent(Int.self, forKey: .crit)     ?? 0
        dodge    = try c.decodeIfPresent(Int.self, forKey: .dodge)    ?? 0
        accuracy = try c.decodeIfPresent(Int.self, forKey: .accuracy) ?? 0
    }

    /// Only non-zero stats are written, so a hand-edited file stays readable
    /// and a generated one diffs cleanly.
    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        if attack   != 0 { try c.encode(attack,   forKey: .attack) }
        if defense  != 0 { try c.encode(defense,  forKey: .defense) }
        if crit     != 0 { try c.encode(crit,     forKey: .crit) }
        if dodge    != 0 { try c.encode(dodge,    forKey: .dodge) }
        if accuracy != 0 { try c.encode(accuracy, forKey: .accuracy) }
    }

    public var isEmpty: Bool {
        attack == 0 && defense == 0 && crit == 0 && dodge == 0 && accuracy == 0
    }
}

// MARK: - Item

public struct ItemDTO: Codable, Sendable, Equatable {
    public let id: String
    public let type: String
    public let tier: Int
    public let stackable: Bool
    public let effects: [ItemEffectDTO]
    public let slot: String?
    public let gearStats: GearStatsDTO?
    public let icon: String?
    public let teachesRecipe: String?

    /// Localization keys are derived from the id for every item that ships
    /// today (`item.<id>` / `item.<id>.desc`), so both are optional overrides.
    /// Storing them explicitly would be 66 fields of pure duplication.
    public let nameKeyOverride: String?
    public let descriptionKeyOverride: String?

    /// Set by an explicit `"descriptionKey": null`. The domain
    /// `Item.descriptionKey` is `String?` and three shipped items really do
    /// carry nil (`potion.heal_small`, `potion.heal_medium`,
    /// `artifact.shrine_coin`) — `ItemDisplay.descriptionKey` returns nil for
    /// them and the caller shows a placeholder modal instead. Without this
    /// flag the DTO could not express "no lore key", the export would invent
    /// one, and the validator would demand three locale keys that are absent
    /// on purpose.
    public let suppressesDescription: Bool

    /// Phase 6 fields — accepted by the schema from day one so adding rarity
    /// and sets later is a data edit, not a schema bump.
    public let rarity: String?
    public let setId: String?

    public var nameKey: String { nameKeyOverride ?? "item.\(id)" }

    public var descriptionKey: String? {
        if suppressesDescription { return nil }
        return descriptionKeyOverride ?? "\(nameKey).desc"
    }

    public init(
        id: String,
        type: String,
        tier: Int,
        stackable: Bool,
        effects: [ItemEffectDTO] = [],
        slot: String? = nil,
        gearStats: GearStatsDTO? = nil,
        icon: String? = nil,
        teachesRecipe: String? = nil,
        nameKeyOverride: String? = nil,
        descriptionKeyOverride: String? = nil,
        suppressesDescription: Bool = false,
        rarity: String? = nil,
        setId: String? = nil
    ) {
        self.id = id
        self.type = type
        self.tier = tier
        self.stackable = stackable
        self.effects = effects
        self.slot = slot
        self.gearStats = gearStats
        self.icon = icon
        self.teachesRecipe = teachesRecipe
        self.nameKeyOverride = nameKeyOverride
        self.descriptionKeyOverride = descriptionKeyOverride
        self.suppressesDescription = suppressesDescription
        self.rarity = rarity
        self.setId = setId
    }

    private enum CodingKeys: String, CodingKey {
        case id, type, tier, stackable, effects, slot, gearStats, icon, teachesRecipe
        case nameKeyOverride = "nameKey"
        case descriptionKeyOverride = "descriptionKey"
        case rarity, setId
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id            = try c.decode(String.self, forKey: .id)
        type          = try c.decode(String.self, forKey: .type)
        tier          = try c.decodeIfPresent(Int.self, forKey: .tier) ?? 1
        stackable     = try c.decodeIfPresent(Bool.self, forKey: .stackable) ?? true
        effects       = try c.decodeIfPresent([ItemEffectDTO].self, forKey: .effects) ?? []
        slot          = try c.decodeIfPresent(String.self, forKey: .slot)
        gearStats     = try c.decodeIfPresent(GearStatsDTO.self, forKey: .gearStats)
        icon          = try c.decodeIfPresent(String.self, forKey: .icon)
        teachesRecipe = try c.decodeIfPresent(String.self, forKey: .teachesRecipe)
        nameKeyOverride        = try c.decodeIfPresent(String.self, forKey: .nameKeyOverride)
        descriptionKeyOverride = try c.decodeIfPresent(String.self, forKey: .descriptionKeyOverride)
        // `decodeIfPresent` cannot tell an absent key from an explicit null, so
        // ask the container directly. Absent = derive; null = deliberately none.
        if c.contains(.descriptionKeyOverride) {
            suppressesDescription = try c.decodeNil(forKey: .descriptionKeyOverride)
        } else {
            suppressesDescription = false
        }
        rarity        = try c.decodeIfPresent(String.self, forKey: .rarity)
        setId         = try c.decodeIfPresent(String.self, forKey: .setId)
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(type, forKey: .type)
        try c.encode(tier, forKey: .tier)
        try c.encode(stackable, forKey: .stackable)
        if !effects.isEmpty { try c.encode(effects, forKey: .effects) }
        try c.encodeIfPresent(slot, forKey: .slot)
        try c.encodeIfPresent(gearStats, forKey: .gearStats)
        try c.encodeIfPresent(icon, forKey: .icon)
        try c.encodeIfPresent(teachesRecipe, forKey: .teachesRecipe)
        try c.encodeIfPresent(nameKeyOverride, forKey: .nameKeyOverride)
        if suppressesDescription {
            try c.encodeNil(forKey: .descriptionKeyOverride)
        } else {
            try c.encodeIfPresent(descriptionKeyOverride, forKey: .descriptionKeyOverride)
        }
        try c.encodeIfPresent(rarity, forKey: .rarity)
        try c.encodeIfPresent(setId, forKey: .setId)
    }
}

/// Top-level shape of `items.json`.
public struct ItemFileDTO: Codable, Sendable {
    public let items: [ItemDTO]
    public init(items: [ItemDTO]) { self.items = items }
}
