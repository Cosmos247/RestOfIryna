//
//  ContentValidator.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 29.08.2026.
//
//  Pure, DB-free, Foundation-only. The same entry point runs at bot boot and in
//  the `roi-content validate` CLI, so a check can never be enforced in one and
//  skipped in the other.
//
//  Phase 0 covers identity, referential integrity, localization and the
//  time-scale guard. Budget-curve and economic-invariant rules land with the
//  tuning tables (Phase 4) and rarity/sets (Phase 6).
//

import Foundation

public enum ContentValidator {

    /// `strict` promotes every warning to an error. Release builds and CI run
    /// strict; local balance iteration does not.
    public static func validate(
        _ bundle: ContentBundle,
        localizations: LocaleIndex? = nil,
        strict: Bool = false
    ) -> ContentReport {
        var issues: [ContentIssue] = []

        issues += validateIdentity(bundle)
        issues += validateEnums(bundle)
        issues += validateReferences(bundle)
        issues += validateTime(bundle)
        if let localizations {
            issues += validateLocalization(bundle, localizations)
        }

        if strict {
            issues = issues.map {
                $0.severity == .warning
                    ? ContentIssue(severity: .error, file: $0.file, path: $0.path, id: $0.id, rule: $0.rule, message: $0.message)
                    : $0
            }
        }
        return ContentReport(issues: issues)
    }

    // MARK: - Identity

    private static func validateIdentity(_ bundle: ContentBundle) -> [ContentIssue] {
        var issues: [ContentIssue] = []

        issues += duplicates(bundle.items.map(\.id), file: "items.json", collection: "items")
        issues += duplicates(bundle.enemies.map(\.id), file: "enemies.json", collection: "enemies")
        issues += duplicates(bundle.recipes.map(\.id), file: "recipes.json", collection: "recipes")

        for (index, item) in bundle.items.enumerated() {
            let path = "items[\(index)]"
            let isGear = item.type == "gear"

            if isGear && item.slot == nil {
                issues.append(.init(severity: .error, file: "items.json", path: path, id: item.id,
                                    rule: "identity.gear.missing_slot",
                                    message: "type is \"gear\" but no slot is set"))
            }
            if !isGear && item.slot != nil {
                issues.append(.init(severity: .error, file: "items.json", path: path, id: item.id,
                                    rule: "identity.slot.on_non_gear",
                                    message: "slot is set but type is \"\(item.type)\""))
            }
            // Gear carries per-row tier, durability and enchant level, so the
            // model requires exactly one inventory row per physical piece.
            if isGear && item.stackable {
                issues.append(.init(severity: .error, file: "items.json", path: path, id: item.id,
                                    rule: "identity.gear.stackable",
                                    message: "gear must not be stackable — per-row tier/durability/enchant assumes one row per piece"))
            }
            if item.tier < 0 {
                issues.append(.init(severity: .error, file: "items.json", path: path, id: item.id,
                                    rule: "identity.tier.negative",
                                    message: "tier must be >= 0, found \(item.tier)"))
            }
            for (effectIndex, effect) in item.effects.enumerated() where effect.amount <= 0 {
                issues.append(.init(severity: .warning, file: "items.json", path: "\(path).effects[\(effectIndex)]", id: item.id,
                                    rule: "identity.effect.non_positive",
                                    message: "\(effect.kind.rawValue) amount is \(effect.amount)"))
            }
        }

        for (index, enemy) in bundle.enemies.enumerated() {
            let path = "enemies[\(index)]"
            if let depth = enemy.depth, depth.closedRange == nil {
                issues.append(.init(severity: .error, file: "enemies.json", path: "\(path).depth", id: enemy.id,
                                    rule: "identity.range.inverted",
                                    message: "depth min \(depth.min) is greater than max \(depth.max)"))
            }
            if enemy.stats.hp <= 0 {
                issues.append(.init(severity: .error, file: "enemies.json", path: "\(path).stats.hp", id: enemy.id,
                                    rule: "identity.enemy.hp",
                                    message: "hp must be positive, found \(enemy.stats.hp)"))
            }
            for (lootIndex, drop) in enemy.loot.enumerated() {
                if drop.chance < 0 || drop.chance > 1 {
                    issues.append(.init(severity: .error, file: "enemies.json", path: "\(path).loot[\(lootIndex)]", id: enemy.id,
                                        rule: "identity.loot.chance_range",
                                        message: "chance \(drop.chance) is outside 0…1"))
                }
                if drop.quantity < 1 {
                    issues.append(.init(severity: .error, file: "enemies.json", path: "\(path).loot[\(lootIndex)]", id: enemy.id,
                                        rule: "identity.loot.quantity",
                                        message: "quantity must be >= 1, found \(drop.quantity)"))
                }
            }
        }

        for (index, recipe) in bundle.recipes.enumerated() {
            let path = "recipes[\(index)]"
            if recipe.inputs.isEmpty {
                issues.append(.init(severity: .error, file: "recipes.json", path: path, id: recipe.id,
                                    rule: "identity.recipe.no_inputs",
                                    message: "recipe has no inputs"))
            }
            for (inputIndex, input) in recipe.inputs.enumerated() where input.quantity < 1 {
                issues.append(.init(severity: .error, file: "recipes.json", path: "\(path).inputs[\(inputIndex)]", id: recipe.id,
                                    rule: "identity.recipe.quantity",
                                    message: "quantity must be >= 1, found \(input.quantity)"))
            }
            if recipe.output.quantity < 1 {
                issues.append(.init(severity: .error, file: "recipes.json", path: "\(path).output", id: recipe.id,
                                    rule: "identity.recipe.quantity",
                                    message: "output quantity must be >= 1, found \(recipe.output.quantity)"))
            }
        }

        return issues
    }

    /// Reported rather than trapped: `GameContent` de-duplicates with
    /// `uniquingKeysWith:` so a duplicate cannot crash the bot, but it must
    /// never reach `install` either.
    private static func duplicates(_ ids: [String], file: String, collection: String) -> [ContentIssue] {
        var seen: Set<String> = []
        var reported: Set<String> = []
        var issues: [ContentIssue] = []
        for (index, id) in ids.enumerated() {
            if seen.contains(id), !reported.contains(id) {
                reported.insert(id)
                issues.append(.init(severity: .error, file: file, path: "\(collection)[\(index)]", id: id,
                                    rule: "identity.duplicate_id",
                                    message: "id appears more than once"))
            }
            seen.insert(id)
        }
        return issues
    }

    // MARK: - Enumerated values

    /// DTOs decode `type`, `slot` and `category` as plain `String` on purpose —
    /// a tolerant decode lets the validator report a typo with the record's id
    /// instead of failing the whole file with a coding path. That tolerance is
    /// only safe because this pass checks the values against the domain enums.
    ///
    /// Keep these sets in step with `ItemType`, `EquipmentSlot` and
    /// `RecipeCategory` in `Swift/Models/`. They merge into one place when the
    /// domain types move into this module (Phase 2).
    private static let itemTypes: Set<String> = ["food", "material", "gear", "potion", "artifact"]
    private static let equipmentSlots: Set<String> = [
        "helmet", "chest", "legs", "boots", "main_hand", "off_hand", "accessory_1", "accessory_2"
    ]
    private static let recipeCategories: Set<String> = ["forge", "tannery", "kitchen"]

    private static func validateEnums(_ bundle: ContentBundle) -> [ContentIssue] {
        var issues: [ContentIssue] = []

        for (index, item) in bundle.items.enumerated() {
            let path = "items[\(index)]"
            if !itemTypes.contains(item.type) {
                issues.append(.init(severity: .error, file: "items.json", path: "\(path).type", id: item.id,
                                    rule: "enum.item_type.unknown",
                                    message: "\"\(item.type)\" is not a valid type (expected one of: \(sorted(itemTypes)))"))
            }
            if let slot = item.slot, !equipmentSlots.contains(slot) {
                issues.append(.init(severity: .error, file: "items.json", path: "\(path).slot", id: item.id,
                                    rule: "enum.slot.unknown",
                                    message: "\"\(slot)\" is not a valid slot (expected one of: \(sorted(equipmentSlots)))"))
            }
            // An id whose prefix disagrees with its type is nearly always a
            // copy-paste, and it silently breaks the `gear.*` conventions the
            // inventory UI leans on.
            if let prefix = item.id.split(separator: ".").first.map(String.init),
               itemTypes.contains(prefix) || prefix == "mat",
               expectedType(forPrefix: prefix) != item.type {
                issues.append(.init(severity: .warning, file: "items.json", path: path, id: item.id,
                                    rule: "convention.id_prefix",
                                    message: "id prefix \"\(prefix)\" suggests type \"\(expectedType(forPrefix: prefix) ?? "?")\" but type is \"\(item.type)\""))
            }
        }

        for (index, recipe) in bundle.recipes.enumerated() where !recipeCategories.contains(recipe.category) {
            issues.append(.init(severity: .error, file: "recipes.json", path: "recipes[\(index)].category", id: recipe.id,
                                rule: "enum.recipe_category.unknown",
                                message: "\"\(recipe.category)\" is not a valid category (expected one of: \(sorted(recipeCategories)))"))
        }

        return issues
    }

    private static func expectedType(forPrefix prefix: String) -> String? {
        prefix == "mat" ? "material" : (itemTypes.contains(prefix) ? prefix : nil)
    }

    private static func sorted(_ set: Set<String>) -> String {
        set.sorted().joined(separator: ", ")
    }

    // MARK: - References

    private static func validateReferences(_ bundle: ContentBundle) -> [ContentIssue] {
        var issues: [ContentIssue] = []
        let itemIds = Set(bundle.items.map(\.id))
        let recipeIds = Set(bundle.recipes.map(\.id))

        func requireItem(_ id: String, file: String, path: String, owner: String) {
            guard !itemIds.contains(id) else { return }
            issues.append(.init(severity: .error, file: file, path: path, id: owner,
                                rule: "reference.item.unknown",
                                message: "references unknown item \"\(id)\""))
        }

        for (index, enemy) in bundle.enemies.enumerated() {
            for (lootIndex, drop) in enemy.loot.enumerated() {
                requireItem(drop.itemId, file: "enemies.json", path: "enemies[\(index)].loot[\(lootIndex)]", owner: enemy.id)
            }
        }

        for (index, recipe) in bundle.recipes.enumerated() {
            for (inputIndex, input) in recipe.inputs.enumerated() {
                requireItem(input.itemId, file: "recipes.json", path: "recipes[\(index)].inputs[\(inputIndex)]", owner: recipe.id)
            }
            requireItem(recipe.output.itemId, file: "recipes.json", path: "recipes[\(index)].output", owner: recipe.id)
        }

        for (index, item) in bundle.items.enumerated() {
            guard let taught = item.teachesRecipe else { continue }
            if !recipeIds.contains(taught) {
                issues.append(.init(severity: .error, file: "items.json", path: "items[\(index)].teachesRecipe", id: item.id,
                                    rule: "reference.recipe.unknown",
                                    message: "teaches unknown recipe \"\(taught)\""))
            }
        }

        for (index, starter) in bundle.starterRecipeIds.enumerated() where !recipeIds.contains(starter) {
            issues.append(.init(severity: .error, file: "recipes.json", path: "starterRecipeIds[\(index)]", id: starter,
                                rule: "reference.recipe.unknown",
                                message: "starter recipe \"\(starter)\" does not exist"))
        }

        // A recipe nothing teaches and nothing starts with is unreachable
        // content — usually a scroll that was never given a drop source.
        let taughtRecipes = Set(bundle.items.compactMap(\.teachesRecipe))
        for (index, recipe) in bundle.recipes.enumerated() {
            let reachable = taughtRecipes.contains(recipe.id) || bundle.starterRecipeIds.contains(recipe.id)
            if !reachable && recipe.category == "kitchen" {
                issues.append(.init(severity: .warning, file: "recipes.json", path: "recipes[\(index)]", id: recipe.id,
                                    rule: "reachability.recipe.unreachable",
                                    message: "kitchen recipe is neither a starter nor taught by any scroll"))
            }
        }

        return issues
    }

    // MARK: - Localization

    private static func validateLocalization(_ bundle: ContentBundle, _ locales: LocaleIndex) -> [ContentIssue] {
        var issues: [ContentIssue] = []

        for (index, item) in bundle.items.enumerated() {
            for locale in locales.missing(item.nameKey) {
                issues.append(.init(severity: .error, file: "\(locale).json", path: "items[\(index)]", id: item.id,
                                    rule: "locale.key.missing",
                                    message: "missing key \"\(item.nameKey)\""))
            }
            // `descriptionKey` is nil for items that deliberately have no lore
            // blurb — demanding a key for those would be a false positive.
            if let descriptionKey = item.descriptionKey {
                for locale in locales.missing(descriptionKey) {
                    issues.append(.init(severity: .warning, file: "\(locale).json", path: "items[\(index)]", id: item.id,
                                        rule: "locale.key.missing",
                                        message: "missing key \"\(descriptionKey)\""))
                }
            }
        }

        for (index, enemy) in bundle.enemies.enumerated() {
            for locale in locales.missing(enemy.nameKey) {
                issues.append(.init(severity: .error, file: "\(locale).json", path: "enemies[\(index)]", id: enemy.id,
                                    rule: "locale.key.missing",
                                    message: "missing key \"\(enemy.nameKey)\""))
            }
        }

        for locale in LocaleIndex.locales {
            for key in locales.emojiBeforePlaceholderKeys(locale: locale) {
                issues.append(.init(severity: .warning, file: "\(locale).json", path: key, id: nil,
                                    rule: "locale.emoji_before_placeholder",
                                    message: "a supplementary-plane emoji before %{…} breaks Lingo interpolation"))
            }
        }

        return issues
    }

    // MARK: - Time

    private static func validateTime(_ bundle: ContentBundle) -> [ContentIssue] {
        guard bundle.manifest.timeScale != 1.0 else { return [] }
        return [.init(severity: .warning, file: "manifest.json", path: "timeScale", id: nil,
                      rule: "time.scale_not_one",
                      message: "timeScale is \(bundle.manifest.timeScale) — every time gate is scaled; must be 1.0 for release")]
    }
}
