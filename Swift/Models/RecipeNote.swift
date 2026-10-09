//
//  RecipeNote.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 10.10.2026.
//
//  A price card the player pinned to the journal: «📌 У нотатник» on the card,
//  read back behind «📌 Рецепти (N)». A player's proposal (2026-10-09): they
//  kept riding to the capital only to see what the next reforge would cost.
//
//  A note stores WHAT it is about, never a copy of the price. The journal prices
//  it afresh from the catalogs and the stores the card itself reads, so a note
//  can never quote a number the card no longer asks for. Three fields say what:
//
//    • `kind`   — which card it was pinned on (`RecipeNote.Kind`);
//    • `ref`    — the item or recipe it is about, "" when the kind has only one;
//    • `target` — the tier, level or enchant it aims at, 0 for a recipe.
//
//  The enchant is keyed by the ITEM and the level, not by the inventory row the
//  card was opened on: a warehouse deposit deletes the row and creates another,
//  and a note tied to the row would vanish while the piece still existed (the
//  owner's call, 2026-10-10).
//
//  `ref` is not a live content reference and `LiveReferenceQuery` does not
//  collect it: a note whose item or recipe a reload removed is dropped the next
//  time it is read, exactly like a finished one (`RecipeNoteService.live`).
//

import Fluent
import Foundation

public final class RecipeNote: Model, @unchecked Sendable {
    public static let schema = "recipe_notes"

    /// The card a note was pinned on. The raw value is what the row stores.
    public enum Kind: String, Sendable {
        /// The Master's first reforge — `ref` the weapon, `target` 2.
        case lesson
        /// The Master's enchant — `ref` the armour piece, `target` the level it reaches.
        case enchant
        /// A workshop reforge — `ref` the weapon, `target` the tier it reaches.
        case weapon
        /// The bag — `target` the tier it reaches.
        case bag
        /// The estate — `target` the tier it reaches.
        case estate
        /// The Training Ground — `target` the level it reaches.
        case training
        /// A workshop craft or a kitchen dish — `ref` the recipe.
        case recipe
    }

    /// What a note is about: the identity a card asks "am I pinned?" with, and
    /// the one a pin writes.
    public struct Key: Sendable, Equatable {
        public let kind: Kind
        public let ref: String
        public let target: Int

        public init(kind: Kind, ref: String, target: Int) {
            self.kind = kind
            self.ref = ref
            self.target = target
        }

        /// The lesson is the reforge from tier 1 to tier 2 by definition
        /// (`WeaponUpgradeService.lesson`), so its target is fixed.
        public static func lesson(weapon itemId: String) -> Key { Key(kind: .lesson, ref: itemId, target: 2) }
        public static func enchant(_ itemId: String, toLevel level: Int) -> Key { Key(kind: .enchant, ref: itemId, target: level) }
        public static func weapon(_ itemId: String, toTier tier: Int) -> Key { Key(kind: .weapon, ref: itemId, target: tier) }
        public static func bag(toTier tier: Int) -> Key { Key(kind: .bag, ref: "", target: tier) }
        public static func estate(toTier tier: Int) -> Key { Key(kind: .estate, ref: "", target: tier) }
        public static func training(toLevel level: Int) -> Key { Key(kind: .training, ref: "", target: level) }
        public static func recipe(_ recipeId: String) -> Key { Key(kind: .recipe, ref: recipeId, target: 0) }
    }

    @ID(key: .id)
    public var id: UUID?

    @Parent(key: "user_id")
    public var user: User

    /// `Kind.rawValue`. Read through `kind`, which is nil for a value this
    /// build does not know — and such a note is dropped as finished.
    @Field(key: "kind")
    public var kindRaw: String

    @Field(key: "ref")
    public var ref: String

    @Field(key: "target")
    public var target: Int

    /// The journal lists notes in the order they were pinned.
    @Timestamp(key: "created_at", on: .create)
    public var createdAt: Date?

    public init() {}

    public init(userID: UUID, key: Key) {
        self.$user.id = userID
        self.kindRaw = key.kind.rawValue
        self.ref = key.ref
        self.target = key.target
    }

    public var kind: Kind? { Kind(rawValue: kindRaw) }
}
