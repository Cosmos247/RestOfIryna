//
//  Catalogs.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 29.08.2026.
//
//  Live domain-side catalog snapshot. `ItemCatalog` / `EnemyCatalog` /
//  `RecipeCatalog` are thin façades over this; it is built once from the
//  validated `GameContent` (DTOs) at boot.
//
//  Why a SECOND snapshot next to `GameData`:
//  the domain types (`Item`, `Enemy`, `Recipe`) still live in the main target,
//  so `ROIContent` cannot hold them — it holds DTOs. Mapping DTO → domain on
//  every `ItemCatalog.find` would allocate on a path that runs inside combat
//  loops, so the mapping happens once here and the result is what the ~315 call
//  sites read. `GameData` keeps the DTO snapshot for the validator, `/content`
//  and (Phase 7) hot reload.
//
//  The two must never drift: `ContentBootstrap.load` is the ONLY place that
//  installs either, and it installs both from the same bundle in one call.
//
//  Same holder shape as `GameData`: `nonisolated(unsafe)` + `NSLock`, because
//  the façade accessors have to stay synchronous, non-throwing and nonisolated
//  for call sites like `EquipmentService.contributedStats`.
//

import Foundation

final class DomainContent: Sendable {
    let items: [Item]
    let itemsById: [String: Item]
    let itemsByType: [ItemType: [Item]]

    let enemies: [Enemy]
    let enemiesById: [String: Enemy]

    let recipes: [Recipe]
    let recipesById: [String: Recipe]
    let starterRecipeIds: Set<String>

    let weaponLadders: [String: [WeaponUpgradeStep]]
    let weaponDurabilityByTier: [Int]

    let bagMaxTier: Int
    let bagCapacities: [Int]
    let bagProgression: [BagUpgradeStep]

    let estateMaxTier: Int
    let estateProgression: [EstateUpgradeStep]

    /// Throws when a DTO carries a value the domain enums can't represent
    /// (unknown item type, slot or recipe category) or an inverted depth range.
    /// Those are validator errors too, so this should be unreachable in
    /// practice — but failing here is still better than trapping later.
    init(_ content: GameContent) throws {
        // Declaration order is preserved end to end: `EnemyCatalog.pickFor`
        // selects with `filter().randomElement()`, so the order of `enemies`
        // decides which enemy a given roll returns.
        self.items = try content.items.map { try $0.toDomain() }
        self.enemies = try content.enemies.map { try $0.toDomain() }
        self.recipes = try content.recipes.map { try $0.toDomain() }

        // `uniquingKeysWith:` rather than `uniqueKeysWithValues:` — the latter
        // TRAPS on a duplicate id, and ids now come from a file. Duplicates are
        // a validator error, so a bundle carrying one never reaches install.
        self.itemsById = Dictionary(items.map { ($0.id, $0) }, uniquingKeysWith: { _, last in last })
        self.itemsByType = Dictionary(grouping: items, by: \.type)
        self.enemiesById = Dictionary(enemies.map { ($0.id, $0) }, uniquingKeysWith: { _, last in last })
        self.recipesById = Dictionary(recipes.map { ($0.id, $0) }, uniquingKeysWith: { _, last in last })
        self.starterRecipeIds = content.starterRecipeIds

        self.weaponLadders = Dictionary(
            content.weaponLaddersByItemId.map { ($0.key, $0.value.domainSteps) },
            uniquingKeysWith: { _, last in last })
        self.weaponDurabilityByTier = content.weaponDurabilityByTier

        self.bagMaxTier = content.bags.maxTier
        self.bagCapacities = content.bags.capacities
        // Sorted by `toTier`: `BagCatalog.nextStep` indexes `progression[tier - 2]`,
        // so a shuffled file would hand out the wrong upgrade. The validator
        // rejects a non-contiguous ladder outright; sorting here means a merge
        // that only reorders cannot break the game in the meantime.
        self.bagProgression = content.bags.progression.sorted { $0.toTier < $1.toTier }.map(\.domain)

        self.estateMaxTier = content.estateUpgrades.maxTier
        self.estateProgression = content.estateUpgrades.progression.sorted { $0.toTier < $1.toTier }.map(\.domain)
    }
}

enum Catalogs {
    private nonisolated(unsafe) static var _current: DomainContent?
    private static let lock = NSLock()

    static var current: DomainContent {
        lock.lock()
        defer { lock.unlock() }
        guard let content = _current else {
            fatalError("Catalog read before ContentBootstrap.load — check ordering in configure.swift")
        }
        return content
    }

    static var isLoaded: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _current != nil
    }

    static func install(_ content: DomainContent) {
        lock.lock()
        _current = content
        lock.unlock()
    }
}
