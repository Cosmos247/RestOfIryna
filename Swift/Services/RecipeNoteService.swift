//
//  RecipeNoteService.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 10.10.2026.
//
//  The journal's recipe notes: pinning, unpinning, and knowing when a note is
//  finished. The design is the owner's, settled in quizzes on 2026-10-09 and
//  2026-10-10 (auto-memory `project-recipe-notebook-planned`):
//
//    • up to `capacity` notes; a fourth pin is refused with a modal;
//    • a note disappears SILENTLY once it is done — the upgrade reached its
//      target, the enchanted piece is gone, or the recipe was made once.
//
//  **Done is read, not announced.** Every upgrade a note can wait on is a STATE
//  the player's rows already carry (a tier, a level, an enchant), so `live`
//  asks those rows each time and deletes what they answer. No upgrade path has
//  to remember the journal, and none can forget it — the "rule each caller
//  filters for itself" shape this codebase keeps paying for. The one EVENT is a
//  craft: nothing records that a dish was ever cooked, so the craft funnel
//  calls `recipeMade` where it succeeds.
//
//  Every reader goes through `live` — the journal's count, its screen and the
//  cap a pin checks — so a finished note is never shown and never takes a
//  place. A card's own "is this pinned?" can stay a plain lookup: a card always
//  shows the NEXT step, and a finished note aims at a step already passed.
//

import Fluent
import Foundation

public enum RecipeNoteService {

    /// How many notes the journal holds — the owner's pick, 2026-10-09.
    public static let capacity = 3

    public enum ToggleResult: Sendable, Equatable {
        /// Pinned; `count` is how many notes the journal holds now.
        case pinned(count: Int)
        case unpinned
        /// The journal is full and nothing was written.
        case full
    }

    /// The player's notes that still mean something, oldest first. A finished
    /// note, or one whose item or recipe is no longer in the content, is deleted
    /// on the way.
    public static func live(for user: User, on db: any Database) async throws -> [RecipeNote] {
        guard let userId = user.id else { return [] }
        let notes = try await RecipeNote.query(on: db)
            .filter(\.$user.$id, .equal, userId)
            .sort(\.$createdAt, .ascending)
            .all()
        guard !notes.isEmpty else { return [] }

        // The rows are read only when a note asks about them.
        let kinds = Set(notes.compactMap(\.kind))
        let bag = kinds.isDisjoint(with: [.lesson, .weapon, .enchant])
            ? [] : try await InventoryEntry.list(for: user, on: db)
        let stored = kinds.contains(.enchant) ? try await WarehouseEntry.list(for: user, on: db) : []

        var open: [RecipeNote] = []
        var finished: [UUID] = []
        for note in notes {
            if isOpen(note, user: user, bag: bag, stored: stored) {
                open.append(note)
            } else if let id = note.id {
                finished.append(id)
            }
        }
        if !finished.isEmpty {
            try await RecipeNote.query(on: db).filter(\.$id ~~ finished).delete()
        }
        return open
    }

    /// Whether a note still waits on something. The weapon is the one in the
    /// main hand, as for both doors that reforge it (`WeaponUpgradeService`) —
    /// a spare of the same kind answers only while the hand holds something
    /// else. The armour piece counts wherever it lies: worn, in the bag or in
    /// the warehouse.
    static func isOpen(_ note: RecipeNote, user: User, bag: [InventoryEntry], stored: [WarehouseEntry]) -> Bool {
        guard let kind = note.kind else { return false }
        switch kind {
        case .lesson, .weapon:
            guard WeaponUpgradeCatalog.step(for: note.ref, tier: note.target) != nil else { return false }
            let rows = bag.filter { $0.itemId == note.ref }
            let worn = rows.first { $0.equippedSlot == EquipmentSlot.mainHand.rawValue }
            guard let tier = worn?.tier ?? rows.map(\.tier).max() else { return false }
            return tier < note.target
        case .enchant:
            let from = note.target - 1
            guard ItemCatalog.find(note.ref) != nil,
                  MasterCatalog.enchantStep(currentLevel: from) != nil else { return false }
            return bag.contains { $0.itemId == note.ref && $0.enchantLevel == from }
                || stored.contains { $0.itemId == note.ref && $0.enchantLevel == from }
        case .bag:
            return BagCatalog.nextStep(from: note.target - 1) != nil && user.bagTier < note.target
        case .estate:
            return EstateUpgradeCatalog.nextStep(from: note.target - 1) != nil && user.estateLevel < note.target
        case .training:
            return TrainingGroundCatalog.level(note.target) != nil && user.trainingGroundLevel < note.target
        case .recipe:
            return RecipeCatalog.find(note.ref)?.category.isCraftable == true
        }
    }

    /// Whether the card for `key` is pinned.
    public static func isPinned(_ key: RecipeNote.Key, for user: User, on db: any Database) async throws -> Bool {
        guard let userId = user.id else { return false }
        return try await find(key, userId: userId, on: db) != nil
    }

    /// The card's «📌» tap: unpin a pinned card, pin an unpinned one while the
    /// journal has room.
    public static func toggle(_ key: RecipeNote.Key, for user: User, on db: any Database) async throws -> ToggleResult {
        // A user without an id has no notes and cannot get one.
        guard let userId = user.id else { return .full }
        if let pinned = try await find(key, userId: userId, on: db) {
            try await pinned.delete(on: db)
            return .unpinned
        }
        let open = try await live(for: user, on: db)
        guard open.count < capacity else { return .full }
        try await RecipeNote(userID: userId, key: key).save(on: db)
        return .pinned(count: open.count + 1)
    }

    /// The journal's «❌»: one of the player's own notes, by id. False when it
    /// is not theirs or is already gone.
    @discardableResult
    public static func remove(_ noteId: UUID, for user: User, on db: any Database) async throws -> Bool {
        guard let userId = user.id,
              let note = try await RecipeNote.query(on: db)
                .filter(\.$id, .equal, noteId)
                .filter(\.$user.$id, .equal, userId)
                .first() else { return false }
        try await note.delete(on: db)
        return true
    }

    /// The craft funnel's hook. A recipe note is done the first time the recipe
    /// is made (the owner's pick, 2026-10-09) — an event no row remembers, so it
    /// is cleared here, where the craft succeeded.
    public static func recipeMade(_ recipeId: String, for user: User, on db: any Database) async throws {
        guard let userId = user.id else { return }
        try await RecipeNote.query(on: db)
            .filter(\.$user.$id, .equal, userId)
            .filter(\.$kindRaw, .equal, RecipeNote.Kind.recipe.rawValue)
            .filter(\.$ref, .equal, recipeId)
            .delete()
    }

    private static func find(_ key: RecipeNote.Key, userId: UUID, on db: any Database) async throws -> RecipeNote? {
        try await RecipeNote.query(on: db)
            .filter(\.$user.$id, .equal, userId)
            .filter(\.$kindRaw, .equal, key.kind.rawValue)
            .filter(\.$ref, .equal, key.ref)
            .filter(\.$target, .equal, key.target)
            .first()
    }
}
