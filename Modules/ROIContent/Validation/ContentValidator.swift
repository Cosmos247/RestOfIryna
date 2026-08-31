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
        issues += validateWeaponLadders(bundle)
        issues += validateUpgradeLadders(bundle)
        issues += validateCapital(bundle)
        issues += validateEstateAndNPCs(bundle)
        issues += validateTime(bundle)
        issues += validateTuning(bundle)
        issues += validateBestiary(bundle)
        issues += validateZones(bundle)
        issues += validateBudget(bundle)
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
    /// `EquipmentSlot` is the shared enum in `Vocabulary.swift` since Phase 8 —
    /// this pass and `validateBudget` used to carry their own transcription of
    /// its eight cases, which is one copy too many for a list the simulator
    /// also needs. `itemTypes` and `recipeCategories` are still transcribed:
    /// keep them in step with `ItemType` / `RecipeCategory` in `Swift/Models/`.
    private static let itemTypes: Set<String> = ["food", "material", "gear", "potion", "artifact"]
    private static let equipmentSlots: Set<String> = Set(EquipmentSlot.allCases.map(\.rawValue))
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

    // MARK: - Weapon ladders

    private static func validateWeaponLadders(_ bundle: ContentBundle) -> [ContentIssue] {
        var issues: [ContentIssue] = []
        let itemsById = Dictionary(bundle.items.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let file = "weapon_upgrades.json"
        var longestLadder = 0

        for (index, ladder) in bundle.weaponLadders.enumerated() {
            let path = "ladders[\(index)]"
            longestLadder = max(longestLadder, ladder.tiers.count)

            guard let item = itemsById[ladder.itemId] else {
                issues.append(.init(severity: .error, file: file, path: path, id: ladder.itemId,
                                    rule: "reference.item.unknown",
                                    message: "ladder references unknown item \"\(ladder.itemId)\""))
                continue
            }
            if item.type != "gear" || item.slot != "main_hand" {
                issues.append(.init(severity: .error, file: file, path: path, id: ladder.itemId,
                                    rule: "ladder.not_a_weapon",
                                    message: "ladder target must be gear in the main_hand slot"))
            }
            if ladder.tiers.isEmpty {
                issues.append(.init(severity: .error, file: file, path: path, id: ladder.itemId,
                                    rule: "ladder.empty",
                                    message: "ladder has no tiers"))
                continue
            }

            for (position, step) in ladder.tiers.enumerated() {
                let stepPath = "\(path).tiers[\(position)]"
                // The shipped catalog encodes tier purely as array position.
                // Writing it down is what lets an inserted or dropped step be
                // caught instead of silently shifting the whole ladder.
                if step.tier != position + 1 {
                    issues.append(.init(severity: .error, file: file, path: stepPath, id: ladder.itemId,
                                        rule: "ladder.tier_out_of_order",
                                        message: "step at position \(position) declares tier \(step.tier), expected \(position + 1)"))
                }
                if position == 0 && !step.inputs.isEmpty {
                    issues.append(.init(severity: .warning, file: file, path: stepPath, id: ladder.itemId,
                                        rule: "ladder.t1_has_cost",
                                        message: "tier 1 is the granted starter weapon and should cost nothing"))
                }
                for (inputIndex, input) in step.inputs.enumerated() {
                    if itemsById[input.itemId] == nil {
                        issues.append(.init(severity: .error, file: file, path: "\(stepPath).inputs[\(inputIndex)]", id: ladder.itemId,
                                            rule: "reference.item.unknown",
                                            message: "references unknown item \"\(input.itemId)\""))
                    }
                    if input.quantity < 1 {
                        issues.append(.init(severity: .error, file: file, path: "\(stepPath).inputs[\(inputIndex)]", id: ladder.itemId,
                                            rule: "ladder.quantity",
                                            message: "quantity must be >= 1, found \(input.quantity)"))
                    }
                }
                // An upgrade that makes a stat worse is a data entry slip: the
                // player spends materials and gets a weaker weapon.
                if position > 0 {
                    let previous = ladder.tiers[position - 1].stats
                    let pairs: [(String, Int, Int)] = [
                        ("attack", previous.attack, step.stats.attack),
                        ("defense", previous.defense, step.stats.defense),
                        ("crit", previous.crit, step.stats.crit),
                        ("dodge", previous.dodge, step.stats.dodge),
                        ("accuracy", previous.accuracy, step.stats.accuracy)
                    ]
                    for (stat, before, after) in pairs where after < before {
                        issues.append(.init(severity: .error, file: file, path: "\(stepPath).stats.\(stat)", id: ladder.itemId,
                                            rule: "ladder.stat_regression",
                                            message: "\(stat) drops from \(before) to \(after) on upgrade"))
                    }
                }
            }
        }

        if !bundle.weaponLadders.isEmpty && bundle.weaponDurabilityByTier.count < longestLadder {
            issues.append(.init(severity: .error, file: file, path: "durabilityByTier", id: nil,
                                rule: "ladder.durability_short",
                                message: "durabilityByTier has \(bundle.weaponDurabilityByTier.count) entries but the longest ladder is \(longestLadder) tiers"))
        }

        return issues
    }

    // MARK: - Bag / estate ladders

    /// `BagCatalog.nextStep` and `EstateUpgradeCatalog.nextStep` index
    /// `progression[targetTier - 2]`, so a gap or a duplicate tier silently
    /// hands the player the wrong upgrade. The DTO writes `toTier` down; this
    /// is what makes writing it down worth anything.
    private static func validateUpgradeLadders(_ bundle: ContentBundle) -> [ContentIssue] {
        var issues: [ContentIssue] = []
        let itemIds = Set(bundle.items.map(\.id))

        func checkCosts(_ inputs: [MaterialCostDTO], file: String, path: String, id: String?) {
            for (index, cost) in inputs.enumerated() {
                if !itemIds.contains(cost.itemId) {
                    issues.append(.init(severity: .error, file: file, path: "\(path).inputs[\(index)]", id: id,
                                        rule: "reference.item.unknown",
                                        message: "references unknown item \"\(cost.itemId)\""))
                }
                if cost.quantity < 1 {
                    issues.append(.init(severity: .error, file: file, path: "\(path).inputs[\(index)]", id: id,
                                        rule: "ladder.quantity",
                                        message: "quantity must be >= 1, found \(cost.quantity)"))
                }
            }
        }

        /// A ladder must run 2, 3, … maxTier with no gaps and no repeats.
        func checkContiguity(_ tiers: [Int], maxTier: Int, file: String) {
            let expected = Array(2...max(2, maxTier))
            if tiers != expected {
                issues.append(.init(severity: .error, file: file, path: "progression", id: nil,
                                    rule: "ladder.tiers_not_contiguous",
                                    message: "tiers \(tiers) must be exactly \(expected) — nextStep indexes by position"))
            }
        }

        // Bag
        let bagFile = "bags.json"
        let bags = bundle.bags
        if !bags.progression.isEmpty {
            checkContiguity(bags.progression.map(\.toTier), maxTier: bags.maxTier, file: bagFile)
            if bags.capacities.count < bags.maxTier {
                issues.append(.init(severity: .error, file: bagFile, path: "capacities", id: nil,
                                    rule: "ladder.capacities_short",
                                    message: "capacities has \(bags.capacities.count) entries but maxTier is \(bags.maxTier)"))
            }
            for (index, step) in bags.progression.enumerated() {
                let path = "progression[\(index)]"
                checkCosts(step.inputs, file: bagFile, path: path, id: "bag.t\(step.toTier)")
                // The ladder's capacity for a tier and the flat table read by
                // `capForTier` are two separate sources for one number.
                let tableIndex = step.toTier - 1
                if tableIndex >= 0, tableIndex < bags.capacities.count,
                   bags.capacities[tableIndex] != step.capacity {
                    issues.append(.init(severity: .error, file: bagFile, path: "\(path).capacity", id: "bag.t\(step.toTier)",
                                        rule: "ladder.capacity_disagrees",
                                        message: "step says \(step.capacity) but capacities[\(tableIndex)] says \(bags.capacities[tableIndex])"))
                }
                if step.capacity < 1 {
                    issues.append(.init(severity: .error, file: bagFile, path: "\(path).capacity", id: "bag.t\(step.toTier)",
                                        rule: "ladder.capacity", message: "capacity must be positive"))
                }
            }
            // Capacity must never shrink on upgrade.
            for pair in zip(bags.progression, bags.progression.dropFirst()) where pair.1.capacity < pair.0.capacity {
                issues.append(.init(severity: .error, file: bagFile, path: "progression", id: "bag.t\(pair.1.toTier)",
                                    rule: "ladder.capacity_regression",
                                    message: "capacity drops from \(pair.0.capacity) to \(pair.1.capacity) on upgrade"))
            }
        }

        // Estate
        let estateFile = "estate_upgrades.json"
        let estate = bundle.estateUpgrades
        if !estate.progression.isEmpty {
            checkContiguity(estate.progression.map(\.toTier), maxTier: estate.maxTier, file: estateFile)
            for (index, step) in estate.progression.enumerated() {
                let path = "progression[\(index)]"
                checkCosts(step.inputs, file: estateFile, path: path, id: "estate.t\(step.toTier)")
                if step.silverCost < 0 {
                    issues.append(.init(severity: .error, file: estateFile, path: "\(path).silverCost", id: "estate.t\(step.toTier)",
                                        rule: "ladder.negative_cost", message: "silverCost must not be negative"))
                }
            }
            // Later tiers must not unlock earlier than earlier ones.
            for pair in zip(estate.progression, estate.progression.dropFirst())
            where pair.1.requiredPlayerLevel < pair.0.requiredPlayerLevel {
                issues.append(.init(severity: .error, file: estateFile, path: "progression", id: "estate.t\(pair.1.toTier)",
                                    rule: "ladder.gate_regression",
                                    message: "required level drops from \(pair.0.requiredPlayerLevel) to \(pair.1.requiredPlayerLevel)"))
            }
        }

        // Plot slots by tier. Since Phase 8E these are the player's daily Vigor
        // budget rather than a convenience, so the ladder is held to the same
        // shape rules as the tiers it indexes.
        let slots = estate.plotSlotsByTier
        if slots.count != estate.maxTier {
            issues.append(.init(severity: .error, file: estateFile, path: "plotSlotsByTier", id: nil,
                                rule: "estate.slot_table_length",
                                message: "the table has \(slots.count) entries for \(estate.maxTier) tiers — it is indexed by `tier - 1`, so a short table silently caps the top tiers at the last value it does have"))
        }
        for (index, count) in slots.enumerated() where count < 0 {
            issues.append(.init(severity: .error, file: estateFile, path: "plotSlotsByTier[\(index)]", id: nil,
                                rule: "estate.slot_count_negative",
                                message: "plot slots must not be negative, found \(count)"))
        }
        // An upgrade that takes plots AWAY would strand claimed plots above the
        // new allowance — `Plot.list` keeps returning them while `claim` refuses.
        for (index, pair) in zip(slots, slots.dropFirst()).enumerated() where pair.1 < pair.0 {
            issues.append(.init(severity: .error, file: estateFile, path: "plotSlotsByTier[\(index + 1)]", id: nil,
                                rule: "estate.slot_count_regression",
                                message: "slots drop from \(pair.0) to \(pair.1) between tier \(index + 1) and \(index + 2)"))
        }

        return issues
    }

    // MARK: - Capital institutions

    /// Rules for `trader.json`, `tavern.json`, `market.json`, `guild.json` and
    /// `arena.json`. Each section is skipped when the file is absent, which only
    /// happens in a hand-built test fixture — `ContentLoader` always supplies
    /// all five and `DomainContent` throws on a nil.
    private static func validateCapital(_ bundle: ContentBundle) -> [ContentIssue] {
        var issues: [ContentIssue] = []
        let itemIds = Set(bundle.items.map(\.id))

        /// Wager and stake ladders are player-facing button rows: a repeat would
        /// render two identical buttons, and a descent would read as a bug.
        func checkAscending(_ values: [Int], file: String, path: String, label: String) {
            if values.isEmpty {
                issues.append(.init(severity: .error, file: file, path: path, id: nil,
                                    rule: "tiers.empty", message: "\(label) is empty"))
            }
            for (index, value) in values.enumerated() where value < 1 {
                issues.append(.init(severity: .error, file: file, path: "\(path)[\(index)]", id: nil,
                                    rule: "tiers.non_positive", message: "\(label) entry is \(value)"))
            }
            for pair in zip(values, values.dropFirst()) where pair.1 <= pair.0 {
                issues.append(.init(severity: .error, file: file, path: path, id: nil,
                                    rule: "tiers.not_ascending",
                                    message: "\(label) must strictly ascend — \(pair.0) is followed by \(pair.1)"))
            }
        }

        func require(_ passed: Bool, _ severity: ContentIssue.Severity = .error,
                     file: String, path: String, rule: String, _ message: @autoclosure () -> String) {
            guard !passed else { return }
            issues.append(.init(severity: severity, file: file, path: path, id: nil,
                                rule: rule, message: message()))
        }

        // MARK: Trader
        if let trader = bundle.trader {
            let file = "trader.json"
            issues += duplicates(trader.listings.map(\.itemId), file: file, collection: "listings")
            for (index, row) in trader.listings.enumerated() {
                let path = "listings[\(index)]"
                if !itemIds.contains(row.itemId) {
                    issues.append(.init(severity: .error, file: file, path: path, id: row.itemId,
                                        rule: "reference.item.unknown",
                                        message: "references unknown item \"\(row.itemId)\""))
                }
                let quantitiesAreSane = row.sellPacketQty >= 1 && row.buyPacketQty >= 1
                if !quantitiesAreSane {
                    issues.append(.init(severity: .error, file: file, path: path, id: row.itemId,
                                        rule: "trader.packet_quantity",
                                        message: "packet quantities must be >= 1, found sell \(row.sellPacketQty) / buy \(row.buyPacketQty)"))
                }
                if row.sellPacketSilver < 0 || row.buyPacketSilver < 0 {
                    issues.append(.init(severity: .error, file: file, path: path, id: row.itemId,
                                        rule: "trader.negative_silver",
                                        message: "packet prices must not be negative"))
                }
                // The one economic invariant the shipped catalog upheld only by
                // convention: buying a unit must never cost less than selling it
                // pays, or the trader becomes an infinite silver faucet. Compared
                // by cross-multiplication so unequal packet sizes stay exact —
                // and gated on sane quantities, since a zero packet makes both
                // sides collapse to 0 and a negative one flips the comparison.
                // A broken row reports its own defect instead of a second,
                // confusing one on top.
                if quantitiesAreSane,
                   row.sellPacketSilver * row.buyPacketQty > row.buyPacketSilver * row.sellPacketQty {
                    issues.append(.init(severity: .error, file: file, path: path, id: row.itemId,
                                        rule: "trader.arbitrage",
                                        message: "sells for \(row.sellPacketSilver)/\(row.sellPacketQty) but buys for \(row.buyPacketSilver)/\(row.buyPacketQty) — a player could mint silver in a loop"))
                }
            }
        }

        // MARK: Tavern
        if let tavern = bundle.tavern {
            let file = "tavern.json"
            issues += duplicates(tavern.food.map(\.itemId), file: file, collection: "food")
            for (index, dish) in tavern.food.enumerated() {
                let path = "food[\(index)]"
                if !itemIds.contains(dish.itemId) {
                    issues.append(.init(severity: .error, file: file, path: path, id: dish.itemId,
                                        rule: "reference.item.unknown",
                                        message: "references unknown item \"\(dish.itemId)\""))
                }
                if dish.priceSilver < 1 {
                    issues.append(.init(severity: .error, file: file, path: "\(path).priceSilver", id: dish.itemId,
                                        rule: "tavern.price",
                                        message: "price must be >= 1, found \(dish.priceSilver)"))
                }
            }
            checkAscending(tavern.wagerTiers, file: file, path: "wagerTiers", label: "wagerTiers")
        }

        // MARK: Market
        if let market = bundle.market {
            let file = "market.json"
            require(market.listingFee >= 0, file: file, path: "listingFee",
                    rule: "market.negative_fee", "listingFee must not be negative, found \(market.listingFee)")
            require(market.maxActiveLots >= 1, file: file, path: "maxActiveLots",
                    rule: "market.no_lots", "maxActiveLots must be >= 1 or nobody can list anything, found \(market.maxActiveLots)")
        }

        // MARK: Guild
        if let guild = bundle.guild {
            let file = "guild.json"
            require(guild.memberCap >= 1, file: file, path: "memberCap",
                    rule: "guild.member_cap", "memberCap must be >= 1, found \(guild.memberCap)")
            require(guild.maxOfficers >= 0, file: file, path: "maxOfficers",
                    rule: "guild.officers_negative", "maxOfficers must not be negative")
            // The leader is not counted in `maxOfficers`, so officers must leave
            // room for at least the leader — otherwise promotion logic can fill
            // a guild with deputies and no rank left to manage.
            require(guild.maxOfficers < guild.memberCap, file: file, path: "maxOfficers",
                    rule: "guild.officers_exceed_cap",
                    "maxOfficers \(guild.maxOfficers) leaves no room under memberCap \(guild.memberCap)")
            require(guild.foundCost >= 0, file: file, path: "foundCost",
                    rule: "guild.negative_cost", "foundCost must not be negative")
            require(guild.foundLevelGate >= 1, file: file, path: "foundLevelGate",
                    rule: "guild.level_gate", "foundLevelGate must be >= 1, found \(guild.foundLevelGate)")
            require(!guild.defaultEmblem.isEmpty, file: file, path: "defaultEmblem",
                    rule: "guild.empty_emblem", "defaultEmblem must not be empty")
            require(guild.nameMinLength >= 1, file: file, path: "nameMinLength",
                    rule: "guild.name_bounds", "nameMinLength must be >= 1, found \(guild.nameMinLength)")
            require(guild.nameMaxLength >= guild.nameMinLength, file: file, path: "nameMaxLength",
                    rule: "guild.name_bounds",
                    "nameMaxLength \(guild.nameMaxLength) is below nameMinLength \(guild.nameMinLength) — no name could ever be valid")
            require(guild.vaultUnitCap >= 1, file: file, path: "vaultUnitCap",
                    rule: "guild.vault_cap", "vaultUnitCap must be >= 1, found \(guild.vaultUnitCap)")
        }

        // MARK: Arena
        if let arena = bundle.arena {
            let file = "arena.json"
            checkAscending(arena.stakeTiers, file: file, path: "stakeTiers", label: "stakeTiers")
            require((0...100).contains(arena.tithePercent), file: file, path: "tithePercent",
                    rule: "arena.tithe_range", "tithePercent must be 0…100, found \(arena.tithePercent)")
            require(arena.honorKFactor > 0, file: file, path: "honorKFactor",
                    rule: "arena.k_factor", "honorKFactor must be positive — a zero K freezes every rating")
            require(arena.minHonor >= 0, .warning, file: file, path: "minHonor",
                    rule: "arena.negative_floor", "minHonor is \(arena.minHonor); a negative rating floor is almost certainly unintended")
            require(arena.startingHonor >= arena.minHonor, file: file, path: "startingHonor",
                    rule: "arena.start_below_floor",
                    "startingHonor \(arena.startingHonor) is below minHonor \(arena.minHonor)")
            require(arena.turnSeconds > 0, file: file, path: "turnSeconds",
                    rule: "arena.non_positive_time", "turnSeconds must be positive")
            require(arena.challengeTTL > 0, file: file, path: "challengeTTL",
                    rule: "arena.non_positive_time", "challengeTTL must be positive")
            require(arena.lobbyTTL > 0, file: file, path: "lobbyTTL",
                    rule: "arena.non_positive_time", "lobbyTTL must be positive")
            require(arena.sweepInterval > 0, file: file, path: "sweepInterval",
                    rule: "arena.non_positive_time", "sweepInterval must be positive")
            // The sweeper is what enforces `turnSeconds`; if it scans less often
            // than the deadline it polices, a fighter keeps their turn past the
            // clock and the timer stops meaning anything.
            require(arena.sweepInterval <= arena.turnSeconds, .warning, file: file, path: "sweepInterval",
                    rule: "arena.sweep_slower_than_turn",
                    "sweepInterval \(arena.sweepInterval)s exceeds turnSeconds \(arena.turnSeconds)s — turn timeouts would be enforced late")
            require(arena.maxMissedTurns >= 1, file: file, path: "maxMissedTurns",
                    rule: "arena.missed_turns", "maxMissedTurns must be >= 1, found \(arena.maxMissedTurns)")
            require(arena.dailyFightCap >= 1, file: file, path: "dailyFightCap",
                    rule: "arena.daily_cap", "dailyFightCap must be >= 1, found \(arena.dailyFightCap)")

            // The league table replaces a `switch`, so its shape has to carry
            // the guarantees the switch got from the compiler: total coverage
            // and unambiguous ordering.
            if arena.leagues.isEmpty {
                issues.append(.init(severity: .error, file: file, path: "leagues", id: nil,
                                    rule: "arena.leagues_empty",
                                    message: "league table is empty — every rating would render a blank league"))
            } else {
                for pair in zip(arena.leagues, arena.leagues.dropFirst()) where pair.1.fromHonor <= pair.0.fromHonor {
                    issues.append(.init(severity: .error, file: file, path: "leagues", id: pair.1.key,
                                        rule: "arena.leagues_not_ascending",
                                        message: "bands must strictly ascend by fromHonor — \(pair.0.fromHonor) is followed by \(pair.1.fromHonor)"))
                }
                // With the opening band at or below the floor, every rating a
                // player can actually hold lands inside a band and `leagueKey`'s
                // fallback tail is unreachable.
                if let first = arena.leagues.first, first.fromHonor > arena.minHonor {
                    issues.append(.init(severity: .error, file: file, path: "leagues[0].fromHonor", id: first.key,
                                        rule: "arena.leagues_gap_at_floor",
                                        message: "first band starts at \(first.fromHonor) but honor floors at \(arena.minHonor) — ratings in between fall through"))
                }
                issues += duplicates(arena.leagues.map(\.key), file: file, collection: "leagues")
            }
        }

        return issues
    }

    // MARK: - Master / plots / fortune / quests

    /// Mirrors of enums that live in the main target. Keep in step with
    /// `PlotType`, `QuestNPC` and `QuestCounter` — same arrangement as
    /// `itemTypes` above, and for the same reason: this module is
    /// Foundation-only and cannot see them.
    private static let plotTypes: Set<String> = ["farm", "forest", "mine", "coop", "training_ground"]
    private static let questNPCs: Set<String> = ["trader", "master", "tavern"]
    private static let questCounters: Set<String> = ["beastKill", "ironIngotForged", "gambleWin", "traderSilver"]

    private static func validateEstateAndNPCs(_ bundle: ContentBundle) -> [ContentIssue] {
        var issues: [ContentIssue] = []
        let itemIds = Set(bundle.items.map(\.id))
        let gearIds = Set(bundle.items.filter { $0.type == "gear" }.map(\.id))

        func require(_ passed: Bool, _ severity: ContentIssue.Severity = .error,
                     file: String, path: String, id: String? = nil, rule: String,
                     _ message: @autoclosure () -> String) {
            guard !passed else { return }
            issues.append(.init(severity: severity, file: file, path: path, id: id,
                                rule: rule, message: message()))
        }

        // MARK: Master
        if let master = bundle.master {
            let file = "master.json"
            issues += duplicates(master.armorForSale.map(\.itemId), file: file, collection: "armorForSale")
            for (index, row) in master.armorForSale.enumerated() {
                let path = "armorForSale[\(index)]"
                if !itemIds.contains(row.itemId) {
                    issues.append(.init(severity: .error, file: file, path: path, id: row.itemId,
                                        rule: "reference.item.unknown",
                                        message: "references unknown item \"\(row.itemId)\""))
                } else if !gearIds.contains(row.itemId) {
                    // The shop hands the piece straight into an equipment slot;
                    // a material sold as armor would be unequippable.
                    issues.append(.init(severity: .error, file: file, path: path, id: row.itemId,
                                        rule: "master.not_gear",
                                        message: "the armor shop can only sell items of type \"gear\""))
                }
                require(row.priceSilver >= 1, file: file, path: "\(path).priceSilver", id: row.itemId,
                        rule: "master.price", "price must be >= 1, found \(row.priceSilver)")
            }

            // Above 1.0 a full repair costs more than a new piece, so nobody
            // would ever repair; at or below 0 repairs are free.
            require(master.repairCostFraction > 0, file: file, path: "repairCostFraction",
                    rule: "master.repair_fraction",
                    "repairCostFraction must be positive, found \(master.repairCostFraction)")
            require(master.repairCostFraction <= 1.0, file: file, path: "repairCostFraction",
                    rule: "master.repair_fraction",
                    "repairCostFraction \(master.repairCostFraction) exceeds 1.0 — repairing would cost more than rebuying")

            require(master.enchantCap >= 1, file: file, path: "enchantCap",
                    rule: "master.enchant_cap", "enchantCap must be >= 1, found \(master.enchantCap)")
            require(master.enchantBudgetFractionPerLevel > 0, file: file,
                    path: "enchantBudgetFractionPerLevel", rule: "master.enchant_no_effect",
                    "an enchant adding 0% of the item's budget does nothing")
            // The absorption cap is 70%. A fully enchanted legendary is designed
            // to land at 49% — comfortably short, so the cap exists without ever
            // becoming the binding constraint. Past ~35% total the second axis
            // (rarity × enchant) starts outrunning forty levels of stat growth,
            // which is the cliff the drafted 2.45x rarity multipliers fell off.
            let totalEnchant = master.enchantBudgetFractionPerLevel * Double(master.enchantCap)
            if totalEnchant > 0.35 {
                issues.append(.init(severity: .warning, file: file,
                                    path: "enchantBudgetFractionPerLevel", id: nil,
                                    rule: "master.enchant_runaway",
                                    message: "a full enchant multiplies the item by \(1 + totalEnchant)x — past 1.35x the enchant axis starts outrunning the whole level ladder"))
            }

            // `enchantStep` looks a level up by value, so a gap makes that level
            // unreachable — the player is stuck one short of the cap.
            let levels = master.enchantSteps.map(\.level)
            let expected = master.enchantCap >= 1 ? Array(1...master.enchantCap) : []
            require(levels == expected, file: file, path: "enchantSteps", rule: "master.levels_not_contiguous",
                    "levels \(levels) must be exactly \(expected) — enchantStep looks up by level")
            for (index, step) in master.enchantSteps.enumerated() {
                let path = "enchantSteps[\(index)]"
                let id = "enchant.t\(step.level)"
                if !itemIds.contains(step.materialId) {
                    issues.append(.init(severity: .error, file: file, path: path, id: id,
                                        rule: "reference.item.unknown",
                                        message: "references unknown item \"\(step.materialId)\""))
                }
                require(step.materialQty >= 1, file: file, path: "\(path).materialQty", id: id,
                        rule: "master.enchant_quantity", "materialQty must be >= 1, found \(step.materialQty)")
                require(step.silver >= 0, file: file, path: "\(path).silver", id: id,
                        rule: "master.negative_cost", "silver must not be negative")
            }
            // The ladder is designed so the last point is the deepest sink.
            for pair in zip(master.enchantSteps, master.enchantSteps.dropFirst()) where pair.1.silver < pair.0.silver {
                issues.append(.init(severity: .warning, file: file, path: "enchantSteps", id: "enchant.t\(pair.1.level)",
                                    rule: "master.enchant_cost_drops",
                                    message: "cost falls from \(pair.0.silver) to \(pair.1.silver) — the ladder is meant to escalate"))
            }
        }

        // MARK: Plots
        if let plots = bundle.plots {
            let file = "plots.json"
            issues += duplicates(plots.types.map(\.type), file: file, collection: "types")
            let present = Set(plots.types.map(\.type))
            // `PlotType` is persisted in `Plot.plotType`, so a type the file
            // forgets is a row the game can load but not describe.
            for missing in plotTypes.subtracting(present).sorted() {
                issues.append(.init(severity: .error, file: file, path: "types", id: missing,
                                    rule: "plot.type_missing",
                                    message: "PlotType \"\(missing)\" has no row — every case must be described"))
            }
            for (index, row) in plots.types.enumerated() {
                let path = "types[\(index)]"
                if !plotTypes.contains(row.type) {
                    issues.append(.init(severity: .error, file: file, path: "\(path).type", id: row.type,
                                        rule: "enum.plot_type.unknown",
                                        message: "\"\(row.type)\" is not a valid plot type (expected one of: \(sorted(plotTypes)))"))
                }
                require(!row.icon.isEmpty, file: file, path: "\(path).icon", id: row.type,
                        rule: "plot.empty_icon", "icon must not be empty")
                guard let tuning = row.tuning else { continue }
                if !itemIds.contains(tuning.producedItemId) {
                    issues.append(.init(severity: .error, file: file, path: "\(path).tuning", id: row.type,
                                        rule: "reference.item.unknown",
                                        message: "produces unknown item \"\(tuning.producedItemId)\""))
                }
                require(tuning.ratePerInterval >= 1, file: file, path: "\(path).tuning.ratePerInterval", id: row.type,
                        rule: "plot.rate", "ratePerInterval must be >= 1, found \(tuning.ratePerInterval)")
                require(tuning.capacity >= 1, file: file, path: "\(path).tuning.capacity", id: row.type,
                        rule: "plot.capacity", "capacity must be >= 1, found \(tuning.capacity)")
                guard let bonus = tuning.bonusOutput else { continue }
                if !itemIds.contains(bonus.producedItemId) {
                    issues.append(.init(severity: .error, file: file, path: "\(path).tuning.bonusOutput", id: row.type,
                                        rule: "reference.item.unknown",
                                        message: "bonus output is unknown item \"\(bonus.producedItemId)\""))
                }
                require(bonus.ratePerInterval >= 1, file: file, path: "\(path).tuning.bonusOutput.ratePerInterval",
                        id: row.type, rule: "plot.rate", "bonus ratePerInterval must be >= 1")
                require(bonus.capacity >= 1, file: file, path: "\(path).tuning.bonusOutput.capacity",
                        id: row.type, rule: "plot.capacity", "bonus capacity must be >= 1")
            }
        }

        // MARK: Fortune
        if let fortune = bundle.fortune {
            let file = "fortune.json"
            issues += duplicates(fortune.cards.map(\.id), file: file, collection: "cards")
            require(fortune.drawPrice >= 0, file: file, path: "drawPrice",
                    rule: "fortune.negative_price", "drawPrice must not be negative")
            require(fortune.buffDurationSeconds > 0, file: file, path: "buffDurationSeconds",
                    rule: "fortune.non_positive_time", "buffDurationSeconds must be positive")
            require(fortune.cooldownSeconds > 0, file: file, path: "cooldownSeconds",
                    rule: "fortune.non_positive_time", "cooldownSeconds must be positive")
            require(!fortune.cards.isEmpty, file: file, path: "cards",
                    rule: "fortune.deck_empty", "the deck is empty — a draw would have nothing to return")

            for (index, card) in fortune.cards.enumerated() {
                let path = "cards[\(index)]"
                // The id is both a locale-key suffix and a PNG filename under
                // `Assets/capital/fortune/`, so a stray separator would build a
                // path outside the asset directory.
                let safe = card.id.allSatisfy { $0.isLetter || $0.isNumber || $0 == "_" }
                require(!card.id.isEmpty && safe, file: file, path: "\(path).id", id: card.id,
                        rule: "fortune.unsafe_id",
                        "card id doubles as a filename and a locale key — letters, digits and underscores only")

                let e = card.effect
                for (name, value) in [("xpMultiplier", e.xpMultiplier),
                                      ("lootChanceMultiplier", e.lootChanceMultiplier),
                                      ("vigorDrainMultiplier", e.vigorDrainMultiplier)] where value <= 0 {
                    issues.append(.init(severity: .error, file: file, path: "\(path).effect.\(name)", id: card.id,
                                        rule: "fortune.non_positive_multiplier",
                                        message: "\(name) is \(value) — a zero or negative multiplier zeroes or inverts the stat it scales"))
                }
                // `FortuneService` only fires the wheel when BOTH sides are
                // non-zero, so setting one alone is an effect that silently
                // never happens.
                let onlyOneSide = (e.randomSilverPositive == 0) != (e.randomSilverNegative == 0)
                require(!onlyOneSide, .warning, file: file, path: "\(path).effect", id: card.id,
                        rule: "fortune.half_wheel",
                        "randomSilverPositive \(e.randomSilverPositive) / randomSilverNegative \(e.randomSilverNegative) — the wheel needs both sides set or it is ignored entirely")
            }
        }

        // MARK: Quests
        if let quests = bundle.quests {
            let file = "quests.json"
            issues += duplicates(quests.pools.map(\.npc), file: file, collection: "pools")
            let present = Set(quests.pools.map(\.npc))
            for missing in questNPCs.subtracting(present).sorted() {
                issues.append(.init(severity: .error, file: file, path: "pools", id: missing,
                                    rule: "quest.npc_missing",
                                    message: "QuestNPC \"\(missing)\" has no pool — its board would offer a synthetic empty job"))
            }
            // `find` is a global lookup, and a re-hydrated row resolves by id
            // alone, so ids must be unique across every pool, not just within one.
            issues += duplicates(quests.pools.flatMap { $0.quests.map(\.id) }, file: file, collection: "quests")

            for (poolIndex, pool) in quests.pools.enumerated() {
                let poolPath = "pools[\(poolIndex)]"
                if !questNPCs.contains(pool.npc) {
                    issues.append(.init(severity: .error, file: file, path: "\(poolPath).npc", id: pool.npc,
                                        rule: "enum.quest_npc.unknown",
                                        message: "\"\(pool.npc)\" is not a valid quest NPC (expected one of: \(sorted(questNPCs)))"))
                }
                // `daily` falls back to a synthetic zero-reward job on an empty
                // pool rather than trapping — which would ship as a visible but
                // unearnable board entry.
                require(!pool.quests.isEmpty, file: file, path: "\(poolPath).quests", id: pool.npc,
                        rule: "quest.pool_empty", "pool is empty — daily() would hand out a synthetic job paying nothing")

                for (index, def) in pool.quests.enumerated() {
                    let path = "\(poolPath).quests[\(index)]"
                    require(def.objective.target >= 1, file: file, path: "\(path).objective.target", id: def.id,
                            rule: "quest.target", "target must be >= 1, found \(def.objective.target)")
                    switch def.objective.kind {
                    case .deliver:
                        require(!def.objective.itemIds.isEmpty, file: file, path: "\(path).objective.itemIds",
                                id: def.id, rule: "quest.no_items", "a deliver objective needs at least one item")
                        for itemId in def.objective.itemIds where !itemIds.contains(itemId) {
                            issues.append(.init(severity: .error, file: file, path: "\(path).objective.itemIds", id: def.id,
                                                rule: "reference.item.unknown",
                                                message: "requires unknown item \"\(itemId)\""))
                        }
                    case .counter:
                        let counter = def.objective.counter ?? ""
                        if !questCounters.contains(counter) {
                            issues.append(.init(severity: .error, file: file, path: "\(path).objective.counter", id: def.id,
                                                rule: "enum.quest_counter.unknown",
                                                message: "\"\(counter)\" is not a counter any hook site ticks (expected one of: \(sorted(questCounters)))"))
                        }
                    }
                    require(def.reward.silver >= 0 && def.reward.xp >= 0 && def.reward.vigor >= 0,
                            file: file, path: "\(path).reward", id: def.id,
                            rule: "quest.negative_reward", "rewards must not be negative")
                }
            }
        }

        return issues
    }

    // MARK: - Localization

    private static func validateLocalization(_ bundle: ContentBundle, _ locales: LocaleIndex) -> [ContentIssue] {
        var issues: [ContentIssue] = []

        // Every forageable item needs its own flavour line — the exploration
        // screen resolves `exploration.find.<id>` per item, so a missing key is
        // a raw key printed at the player rather than a fallback.
        for (index, zone) in (bundle.zones?.zones ?? []).enumerated() {
            for entry in zone.forage {
                let key = "exploration.find.\(entry.itemId)"
                for locale in locales.missing(key) {
                    issues.append(.init(severity: .error, file: "\(locale).json",
                                        path: "zones[\(index)].forage", id: zone.id,
                                        rule: "locale.key.missing",
                                        message: "missing key \"\(key)\""))
                }
            }
        }

        let ladders = Dictionary(bundle.weaponLadders.map { ($0.itemId, $0) },
                                 uniquingKeysWith: { _, last in last })

        for (index, item) in bundle.items.enumerated() {
            let path = "items[\(index)]"

            func require(_ key: String, _ severity: ContentIssue.Severity) {
                for locale in locales.missing(key) {
                    issues.append(.init(severity: severity, file: "\(locale).json", path: path, id: item.id,
                                        rule: "locale.key.missing",
                                        message: "missing key \"\(key)\""))
                }
            }

            // The base name key is resolved by call sites that don't go through
            // `ItemDisplay` (vendor rows, recipe outputs), so it is required for
            // every item, tiered or not.
            require(item.nameKey, .error)

            if let ladder = ladders[item.id] {
                // `ItemDisplay.nameKey(for:tier:)` / `.descriptionKey(for:tier:)`
                // append `.t<tier>` for anything with a ladder, so these are the
                // keys players actually see. The base `.desc` is never resolved
                // for such an item and must NOT be demanded — all three shipped
                // weapons legitimately lack it.
                for step in ladder.tiers {
                    require("\(item.nameKey).t\(step.tier)", .error)
                    if let descriptionKey = item.descriptionKey {
                        require("\(descriptionKey).t\(step.tier)", .warning)
                    }
                }
            } else if let descriptionKey = item.descriptionKey {
                // nil for items that deliberately have no lore blurb —
                // demanding a key for those would be a false positive.
                require(descriptionKey, .warning)
            }
        }

        for (index, enemy) in bundle.enemies.enumerated() {
            for locale in locales.missing(enemy.nameKey) {
                issues.append(.init(severity: .error, file: "\(locale).json", path: "enemies[\(index)]", id: enemy.id,
                                    rule: "locale.key.missing",
                                    message: "missing key \"\(enemy.nameKey)\""))
            }
        }

        // League names are the only locale keys the data itself names — every
        // other content key is derived from an id. A renamed band would print
        // the raw key stem to the player, so demand it exists.
        for (index, league) in (bundle.arena?.leagues ?? []).enumerated() {
            for locale in locales.missing(league.key) {
                issues.append(.init(severity: .error, file: "\(locale).json", path: "leagues[\(index)]", id: league.key,
                                    rule: "locale.key.missing",
                                    message: "missing key \"\(league.key)\""))
            }
        }

        // Batch C derives its keys from ids the same way items do, so the file
        // carries none of them — which means nothing but this pass stands
        // between a renamed id and a raw key stem rendered to the player.
        func requireKey(_ key: String, file: String, path: String, id: String?) {
            for locale in locales.missing(key) {
                issues.append(.init(severity: .error, file: "\(locale).json", path: path, id: id,
                                    rule: "locale.key.missing", message: "missing key \"\(key)\""))
            }
        }

        for (index, row) in (bundle.plots?.types ?? []).enumerated() {
            requireKey("plot.type.\(row.type).name", file: "plots.json", path: "types[\(index)]", id: row.type)
            requireKey("plot.type.\(row.type).desc", file: "plots.json", path: "types[\(index)]", id: row.type)
        }

        for (index, card) in (bundle.fortune?.cards ?? []).enumerated() {
            for suffix in ["name", "meaning", "buff_desc"] {
                requireKey("fortune.card.\(card.id).\(suffix)",
                           file: "fortune.json", path: "cards[\(index)]", id: card.id)
            }
        }

        for (poolIndex, pool) in (bundle.quests?.pools ?? []).enumerated() {
            requireKey("quest.\(pool.npc).board_title",
                       file: "quests.json", path: "pools[\(poolIndex)]", id: pool.npc)
            for (index, def) in pool.quests.enumerated() {
                let path = "pools[\(poolIndex)].quests[\(index)]"
                requireKey("quest.\(def.id).title", file: "quests.json", path: path, id: def.id)
                requireKey("quest.\(def.id).desc",  file: "quests.json", path: path, id: def.id)
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

    // MARK: - Item stat budget (Phase 6)
    //
    // The rule that makes "add items forever" safe. Every equippable item's
    // stats are a fixed budget SPENT at a fixed exchange rate, so one number
    // bounds the piece — and because the combat denominators were derived from
    // this same curve, an item that respects its budget cannot move any stat's
    // PERCENTAGE, however many items get added later.
    //
    // Without it, power creep is invisible: each new piece looks reasonable
    // beside the last one, and the drift only shows up as "why is everyone
    // immune at level 30".
    private static func validateBudget(_ bundle: ContentBundle) -> [ContentIssue] {
        guard let budget = bundle.budget else { return [] }
        var issues: [ContentIssue] = []
        // Declaration order — it is the order a missing weight is reported in.
        let knownSlots = EquipmentSlot.allCases.map(\.rawValue)

        func fail(_ file: String, _ path: String, _ rule: String,
                  _ message: @autoclosure () -> String,
                  _ severity: ContentIssue.Severity = .error, id: String? = nil) {
            issues.append(.init(severity: severity, file: file, path: path, id: id,
                                rule: rule, message: message()))
        }

        // MARK: the curve itself
        if budget.base <= 0 {
            fail("tuning/budget.json", "base", "budget.non_positive",
                 "the budget intercept must be positive, found \(budget.base)")
        }
        if budget.perItemLevel <= 0 {
            fail("tuning/budget.json", "perItemLevel", "budget.flat_curve",
                 "at \(budget.perItemLevel) per item level a level-40 item is worth no more than a level-1 one")
        }
        let weights = Dictionary(budget.slotWeights.map { ($0.slot, $0.weight) },
                                 uniquingKeysWith: { first, _ in first })
        for slot in knownSlots where weights[slot] == nil {
            fail("tuning/budget.json", "slotWeights", "budget.slot_missing",
                 "no weight for equipment slot \"\(slot)\" — items in it would be unbounded")
        }
        for (index, row) in budget.slotWeights.enumerated() {
            if !knownSlots.contains(row.slot) {
                fail("tuning/budget.json", "slotWeights[\(index)]", "budget.slot_unknown",
                     "unknown equipment slot \"\(row.slot)\"", id: row.slot)
            }
            if row.weight <= 0 {
                fail("tuning/budget.json", "slotWeights[\(index)]", "budget.slot_weight",
                     "slot weight must be positive, found \(row.weight)", id: row.slot)
            }
        }
        let perPoint = budget.statPerPoint
        for (name, rate) in [("attack", perPoint.attack), ("defense", perPoint.defense),
                             ("hp", perPoint.hp), ("crit", perPoint.crit),
                             ("dodge", perPoint.dodge), ("accuracy", perPoint.accuracy)]
        where rate <= 0 {
            fail("tuning/budget.json", "statPerPoint.\(name)", "budget.exchange_non_positive",
                 "\(name) must buy something per point, found \(rate) — the spend check divides by it")
        }

        // MARK: the rarity ladder
        let rarityFile = "rarities.json"
        if bundle.rarities.isEmpty {
            fail(rarityFile, "rarities", "rarity.empty", "at least one rarity must exist")
        }
        issues += duplicates(bundle.rarities.map(\.id), file: rarityFile, collection: "rarities")
        if let first = bundle.rarities.first, first.budgetMultiplier != 1.0 {
            fail(rarityFile, "rarities[0]", "rarity.baseline_not_one",
                 "the lowest rarity is the baseline every other multiplies against, so it must be 1.0, found \(first.budgetMultiplier)",
                 .error, id: first.id)
        }
        for (index, row) in bundle.rarities.enumerated() {
            if row.glyph.isEmpty {
                fail(rarityFile, "rarities[\(index)].glyph", "rarity.no_glyph",
                     "rarity needs a glyph — the id is not player-facing", .error, id: row.id)
            }
            guard index > 0 else { continue }
            let previous = bundle.rarities[index - 1]
            if row.budgetMultiplier <= previous.budgetMultiplier {
                fail(rarityFile, "rarities[\(index)]", "rarity.budget_not_ascending",
                     "budget multipliers must strictly ascend — \(previous.id) is \(previous.budgetMultiplier), \(row.id) is \(row.budgetMultiplier)",
                     .error, id: row.id)
            }
            if row.valueMultiplier <= previous.valueMultiplier {
                fail(rarityFile, "rarities[\(index)]", "rarity.value_not_ascending",
                     "value multipliers must strictly ascend", .error, id: row.id)
            }
        }
        // The ceiling the whole model rests on: rarity times a full enchant must
        // stay under 1.75x a common of the same level. Above that the second
        // axis outgrows forty levels of the first, and — measured through the
        // absorption curve — the 70% cap stops being unreachable and starts
        // being the binding constraint, which is a cliff no design can stand on.
        if let top = bundle.rarities.map(\.budgetMultiplier).max(), let master = bundle.master {
            let full = top * (1 + master.enchantBudgetFractionPerLevel * Double(master.enchantCap))
            if full > 1.75 {
                fail(rarityFile, "rarities", "rarity.ceiling_exceeded",
                     "top rarity \(top)x with a full enchant reaches \(full)x a common of the same level, past the 1.75x ceiling")
            }
        }

        // MARK: every equippable item, and every rung of every ladder
        let rarityBudget = Dictionary(bundle.rarities.map { ($0.id, $0.budgetMultiplier) },
                                      uniquingKeysWith: { first, _ in first })

        /// Points an item's stats cost, plus the most a half-up rounding of each
        /// stat could have added. An absolute slack, not a percentage: rounding
        /// error is a fixed number of points, so a percentage tolerance is far
        /// too tight on a level-1 piece and far too loose on a level-40 one.
        func spend(_ stats: GearStatsDTO) -> (points: Double, slack: Double) {
            var points = 0.0, slack = 0.0
            for (value, rate) in [(stats.attack, perPoint.attack), (stats.defense, perPoint.defense),
                                  (stats.hp, perPoint.hp), (stats.crit, perPoint.crit),
                                  (stats.dodge, perPoint.dodge), (stats.accuracy, perPoint.accuracy)]
            where value != 0 && rate > 0 {
                points += Double(value) / rate
                slack += 0.5 / rate
            }
            return (points, slack)
        }

        func checkSpend(_ stats: GearStatsDTO, itemLevel: Int, slot: String, rarity: String,
                        file: String, path: String, id: String) {
            guard let weight = weights[slot] else { return }   // already reported
            // An unknown rarity is reported by the caller that knows where the
            // item came from; returning quietly here avoids naming the same
            // item twice for one mistake.
            guard let multiplier = rarityBudget[rarity] else { return }
            let allowed = weight * (budget.base + budget.perItemLevel * Double(itemLevel)) * multiplier
            let (points, slack) = spend(stats)
            if points > allowed + slack {
                fail(file, path, "budget.overspent",
                     "spends \(String(format: "%.1f", points)) points against a budget of \(String(format: "%.1f", allowed)) for a \(rarity) \(slot) at item level \(itemLevel)",
                     .error, id: id)
            }
        }

        for (index, item) in bundle.items.enumerated() {
            let rarity = item.rarity ?? "common"
            if rarityBudget[rarity] == nil {
                fail("items.json", "items[\(index)].rarity", "rarity.unknown",
                     "unknown rarity \"\(rarity)\"", .error, id: item.id)
            }
            if let level = item.itemLevel, level < 1 {
                fail("items.json", "items[\(index)].itemLevel", "budget.item_level",
                     "item level must be at least 1, found \(level)", .error, id: item.id)
            }
            guard let slot = item.slot, let stats = item.gearStats else { continue }
            checkSpend(stats, itemLevel: item.itemLevel ?? 1, slot: slot, rarity: rarity,
                       file: "items.json", path: "items[\(index)]", id: item.id)
        }

        // A ladder rung is a whole item at that tier, not an increment, so each
        // rung is measured against the budget for ITS item level.
        for (ladderIndex, ladder) in bundle.weaponLadders.enumerated() {
            let owner = bundle.items.first { $0.id == ladder.itemId }
            let slot = owner?.slot ?? "main_hand"
            let rarity = owner?.rarity ?? "common"
            for (stepIndex, step) in ladder.tiers.enumerated() {
                checkSpend(step.stats, itemLevel: step.itemLevel ?? step.tier, slot: slot,
                           rarity: rarity, file: "weapon_upgrades.json",
                           path: "ladders[\(ladderIndex)].tiers[\(stepIndex)]", id: ladder.itemId)
            }
            // Item level has to climb with the rung, or a later tier is a
            // downgrade wearing a bigger number.
            for pair in zip(ladder.tiers, ladder.tiers.dropFirst()) {
                let previous = pair.0.itemLevel ?? pair.0.tier
                let next = pair.1.itemLevel ?? pair.1.tier
                if next <= previous {
                    fail("weapon_upgrades.json", "ladders[\(ladderIndex)]",
                         "budget.ladder_level_not_ascending",
                         "item level must rise with tier — t\(pair.0.tier) is \(previous), t\(pair.1.tier) is \(next)",
                         .error, id: ladder.itemId)
                }
            }
        }

        // MARK: equipment sets
        let setFile = "sets.json"
        issues += duplicates(bundle.gearSets.map(\.id), file: setFile, collection: "sets")
        let setsById = Dictionary(bundle.gearSets.map { ($0.id, $0) },
                                  uniquingKeysWith: { first, _ in first })
        var membersPerSet: [String: [ItemDTO]] = [:]
        for (index, item) in bundle.items.enumerated() {
            guard let setId = item.setId else { continue }
            if setsById[setId] == nil {
                fail("items.json", "items[\(index)].setId", "set.unknown",
                     "references unknown set \"\(setId)\"", .error, id: item.id)
                continue
            }
            membersPerSet[setId, default: []].append(item)
        }
        for (index, set) in bundle.gearSets.enumerated() {
            let path = "sets[\(index)]"
            let members = membersPerSet[set.id] ?? []
            if set.bonuses.isEmpty {
                fail(setFile, "\(path).bonuses", "set.no_bonuses",
                     "a set with no thresholds grants nothing and is indistinguishable from no set at all",
                     .warning, id: set.id)
            }
            for (bonusIndex, bonus) in set.bonuses.enumerated() {
                if bonus.pieces < 2 {
                    fail(setFile, "\(path).bonuses[\(bonusIndex)]", "set.threshold_below_two",
                         "a threshold of \(bonus.pieces) is not a set bonus — it applies to a single piece",
                         .error, id: set.id)
                }
                if bonus.pieces > members.count {
                    fail(setFile, "\(path).bonuses[\(bonusIndex)]", "set.threshold_unreachable",
                         "needs \(bonus.pieces) pieces but only \(members.count) item(s) belong to the set",
                         .error, id: set.id)
                }
                if case .gearMultiplier(let factor) = bonus.effect, factor <= 0 {
                    fail(setFile, "\(path).bonuses[\(bonusIndex)]", "set.multiplier_non_positive",
                         "a gear multiplier of \(factor) erases the wearer's equipment", .error, id: set.id)
                }
            }
            for pair in zip(set.bonuses, set.bonuses.dropFirst()) where pair.1.pieces <= pair.0.pieces {
                fail(setFile, "\(path).bonuses", "set.thresholds_not_ascending",
                     "thresholds must ascend — \(pair.0.pieces) is followed by \(pair.1.pieces)",
                     .error, id: set.id)
            }
            // A set bonus is EXTRA budget bought with slot freedom, so it is a
            // third power axis beside item level and rarity and needs the same
            // kind of ceiling. Capped against the members' own combined budget:
            // unbounded, "wear the whole set" quietly becomes the only correct
            // answer to every slot decision in the game.
            let memberBudget = members.reduce(0.0) { total, item in
                guard let slot = item.slot, let weight = weights[slot] else { return total }
                let multiplier = rarityBudget[item.rarity ?? "common"] ?? 1.0
                return total + weight * (budget.base + budget.perItemLevel * Double(item.itemLevel ?? 1)) * multiplier
            }
            let flatSpend = set.bonuses.reduce(0.0) { total, bonus in
                guard case .flatStats(let stats) = bonus.effect else { return total }
                return total + spend(stats).points
            }
            if memberBudget > 0, flatSpend > memberBudget * 0.25 {
                fail(setFile, "\(path).bonuses", "set.bonus_over_budget",
                     "grants \(String(format: "%.1f", flatSpend)) points against members worth \(String(format: "%.1f", memberBudget)) — past 25% the set bonus outweighs choosing the right pieces",
                     .error, id: set.id)
            }
        }

        return issues
    }

    // MARK: - Bestiary (Phase 5A)
    //
    // The archetype table is design input for the generator AND runtime data
    // (its multipliers price XP, loot and silver), so it is validated as a
    // tuning table even though it ships inside `enemies.json`.
    //
    // The depth-coverage rule is the one that pays for itself. `pickFor` used
    // to answer an uncovered km with `all.first`, so the gap above km 35 read
    // as "every deep encounter is a wild boar" instead of as missing content.
    // Now the gap is reported here and the roll honestly returns nil.
    /// `zones.json` — the foraging pools, content since Phase 8E.
    ///
    /// Held to the same rules as the bestiary's depth bands, and for the same
    /// reason: the roll now returns nil where nothing covers a km, so a gap is
    /// a step that finds nothing rather than a step that finds the wrong thing
    /// forever. That is only an improvement if somebody is told about the gap.
    private static func validateZones(_ bundle: ContentBundle) -> [ContentIssue] {
        guard let file = bundle.zones else { return [] }
        var issues: [ContentIssue] = []
        let name = "zones.json"
        let knownItems = Set(bundle.items.map(\.id))

        func fail(_ path: String, _ rule: String, _ message: String,
                  _ severity: ContentIssue.Severity = .error, id: String? = nil) {
            issues.append(.init(severity: severity, file: name, path: path, id: id,
                                rule: rule, message: message))
        }

        issues += duplicates(file.zones.map(\.id), file: name, collection: "zones")

        for (index, zone) in file.zones.enumerated() {
            let path = "zones[\(index)]"
            guard let range = zone.depth.closedRange else {
                fail("\(path).depth", "zone.depth_inverted",
                     "depth range is inverted: \(zone.depth.min)...\(zone.depth.max)", id: zone.id)
                continue
            }
            if range.lowerBound < 1 {
                fail("\(path).depth", "zone.depth_range",
                     "depth starts at \(range.lowerBound); km numbering starts at 1", id: zone.id)
            }
            if zone.forage.isEmpty {
                fail("\(path).forage", "zone.pool_empty",
                     "a zone with no forage pool makes every loot roll in its band find nothing",
                     id: zone.id)
            }
            var total = 0
            for (entryIndex, entry) in zone.forage.enumerated() {
                let entryPath = "\(path).forage[\(entryIndex)]"
                if !knownItems.contains(entry.itemId) {
                    fail("\(entryPath).itemId", "zone.unknown_item",
                         "unknown item \"\(entry.itemId)\"", id: zone.id)
                }
                if entry.weight <= 0 {
                    fail("\(entryPath).weight", "zone.weight_range",
                         "weight must be positive, found \(entry.weight) — a zero-weight entry can never be found and is content nobody will ever see",
                         id: zone.id)
                }
                total += Swift.max(0, entry.weight)
            }
            if !zone.forage.isEmpty && total <= 0 {
                fail("\(path).forage", "zone.pool_unreachable",
                     "every weight in the pool is zero, so the roll can never return anything",
                     id: zone.id)
            }
            issues += duplicates(zone.forage.map(\.itemId), file: name,
                                 collection: "\(path).forage")
        }

        // Coverage, walked to the deepest km any enemy can spawn at — the two
        // tables describe the same wilderness, so a band one covers and the
        // other does not is a hole in exactly one of them.
        let horizon = bundle.enemies.compactMap { $0.depth?.closedRange }
            .filter { $0 != 0...0 }.map(\.upperBound).max()
        if let horizon, !file.zones.isEmpty {
            let covered = file.zones.compactMap { $0.depth.closedRange }
            let gaps = (1...horizon).filter { km in !covered.contains { $0.contains(km) } }
            if !gaps.isEmpty {
                fail("zones", "zone.depth_gap",
                     "no zone covers km \(gaps.map(String.init).joined(separator: ", ")) — foraging there finds nothing at all",
                     .warning)
            }
        }

        return issues
    }

    private static func validateBestiary(_ bundle: ContentBundle) -> [ContentIssue] {
        guard !bundle.enemies.isEmpty || !bundle.enemyArchetypes.isEmpty else { return [] }
        var issues: [ContentIssue] = []
        let file = "enemies.json"
        let known = ["trash", "normal", "skirmisher", "brute", "elite", "boss"]

        func fail(_ path: String, _ rule: String, _ message: @autoclosure () -> String,
                  _ severity: ContentIssue.Severity = .error, id: String? = nil) {
            issues.append(.init(severity: severity, file: file, path: path, id: id,
                                rule: rule, message: message()))
        }

        // MARK: archetype table
        let present = bundle.enemyArchetypes.map(\.id)
        for name in known where !present.contains(name) {
            fail("archetypes", "enemy.archetype_missing", "no row for archetype \"\(name)\"")
        }
        issues += duplicates(present, file: file, collection: "archetypes")
        for (index, row) in bundle.enemyArchetypes.enumerated() {
            let path = "archetypes[\(index)]"
            if !known.contains(row.id) {
                fail(path, "enemy.archetype_unknown", "unknown archetype \"\(row.id)\"", id: row.id)
            }
            if row.rounds <= 0 {
                fail(path, "enemy.archetype_rounds",
                     "rounds must be positive, found \(row.rounds)", id: row.id)
            }
            if row.hpLossPercent <= 0 {
                fail(path, "enemy.archetype_danger",
                     "hpLossPercent must be positive, found \(row.hpLossPercent)", id: row.id)
            }
            for (name, value) in [("mitigationPercent", row.mitigationPercent),
                                  ("dodgePercent", row.dodgePercent),
                                  ("critPercent", row.critPercent)] where value < 0 || value > 100 {
                fail("\(path).\(name)", "enemy.archetype_percent_range",
                     "\(name) must sit inside 0...100, found \(value)", id: row.id)
            }
            for (name, value) in [("xpMultiplier", row.xpMultiplier),
                                  ("lootMultiplier", row.lootMultiplier)] where value <= 0 {
                fail("\(path).\(name)", "enemy.archetype_multiplier",
                     "\(name) must be positive, found \(value)", id: row.id)
            }
            if row.spawnWeight < 0 {
                fail("\(path).spawnWeight", "enemy.archetype_weight",
                     "spawn weight must not be negative", id: row.id)
            }
            if row.minLevel < 1 {
                fail("\(path).minLevel", "enemy.archetype_floor_range",
                     "minLevel must be at least 1, found \(row.minLevel)", id: row.id)
            }
        }

        // The level cap arrives with the progression bundle, so the two rules
        // that need it sit here rather than in the loop above.
        let maxLevel = bundle.tuning?.progression.maxLevel
        // A floor above the cap would make the archetype unauthorable, which is
        // a table typo rather than a design choice.
        for (index, row) in bundle.enemyArchetypes.enumerated() {
            guard let maxLevel, row.minLevel > maxLevel else { continue }
            fail("archetypes[\(index)].minLevel", "enemy.archetype_floor_above_cap",
                 "minLevel \(row.minLevel) is above the player cap \(maxLevel), so no enemy of this archetype could ever be authored",
                 id: row.id)
        }
        let archetypeFloor = Dictionary(bundle.enemyArchetypes.map { ($0.id, $0.minLevel) },
                                        uniquingKeysWith: { first, _ in first })

        // MARK: per-enemy design fields
        for (index, enemy) in bundle.enemies.enumerated() {
            let path = "enemies[\(index)]"
            if !known.contains(enemy.archetype) {
                fail("\(path).archetype", "enemy.archetype_unknown",
                     "unknown archetype \"\(enemy.archetype)\"", id: enemy.id)
            }
            if enemy.level < 1 {
                fail("\(path).level", "enemy.level_range",
                     "level must be at least 1, found \(enemy.level)", id: enemy.id)
            }
            if let maxLevel, enemy.level > maxLevel {
                fail("\(path).level", "enemy.level_above_cap",
                     "level \(enemy.level) is above the player cap \(maxLevel), so `levelDiff` can only ever punish",
                     .warning, id: enemy.id)
            }
            if let weight = enemy.spawnWeight, weight < 0 {
                fail("\(path).spawnWeight", "enemy.negative_weight",
                     "spawn weight must not be negative, found \(weight)", id: enemy.id)
            }
            // The archetype's level floor. Enemy stats are frozen at design
            // time, so this file is the only place the floor can be broken —
            // and an elite below level 14 meets a player with no techniques
            // unlocked at all, where its own contract asks for 62% of a bar.
            //
            // Applied to every row, including the `0...0` sentinels that never
            // spawn from the wilderness: a rule with an exception for "it is
            // only reachable another way" is a rule that stops being checked.
            if let floor = archetypeFloor[enemy.archetype], enemy.level < floor {
                fail("\(path).level", "enemy.below_archetype_floor",
                     "level \(enemy.level) is below the \(enemy.archetype) floor of \(floor)",
                     id: enemy.id)
            }
        }

        // MARK: depth coverage
        //
        // Walked up to the player level cap, because the design invariant is
        // "km tracks level": a player who can reach level N must find something
        // to fight at km N. Enemies with the `0...0` sentinel never spawn and
        // are excluded — counting them would hide the very gap this looks for.
        if let horizon = maxLevel, !bundle.enemies.isEmpty {
            let spawnable = bundle.enemies.compactMap { enemy -> (ClosedRange<Int>, Double?)? in
                guard let range = enemy.depth?.closedRange, range != 0...0 else { return nil }
                return (range, enemy.spawnWeight)
            }
            var uncovered: [Int] = []
            for km in 1...horizon where !spawnable.contains(where: { $0.0.contains(km) }) {
                uncovered.append(km)
            }
            if !uncovered.isEmpty {
                let shown = uncovered.prefix(8).map(String.init).joined(separator: ", ")
                let tail = uncovered.count > 8 ? ", … (\(uncovered.count) km total)" : ""
                fail("enemies", "enemy.depth_gap",
                     "no enemy can spawn at km \(shown)\(tail) — exploration there rolls no encounter at all",
                     .warning)
            }
            // A band whose every candidate is weighted zero would make the
            // weighted roll fall back to a uniform draw, silently ignoring the
            // weights the band was written with.
            for km in 1...horizon {
                let band = spawnable.filter { $0.0.contains(km) }
                guard !band.isEmpty, band.allSatisfy({ ($0.1 ?? 1) == 0 }) else { continue }
                fail("enemies", "enemy.band_all_zero_weight",
                     "every enemy that can spawn at km \(km) is weighted 0")
                break
            }
        }

        return issues
    }

    // MARK: - Tuning tables
    //
    // Phase 4. Different in kind from every rule above: a catalog rule mostly
    // asks "does this id resolve", while these ask "can the game survive this
    // number". Several of the values below are read straight into an operation
    // that TRAPS on a bad input — `ClosedRange(min...max)` on an inverted
    // variance, `Int.random(in: 0..<total)` on a non-positive weight total, an
    // array subscript on an empty warehouse table, a division by
    // `maxDurabilityStart` inside `MasterCatalog.repairCost`. For those the
    // validator is not a style checker, it is the thing standing between a typo
    // and a crash on the first fight of the session.
    private static func validateTuning(_ bundle: ContentBundle) -> [ContentIssue] {
        guard let tuning = bundle.tuning else { return [] }
        var issues: [ContentIssue] = []
        let itemIds = Set(bundle.items.map(\.id))
        let enemyIds = Set(bundle.enemies.map(\.id))
        let knownClasses = ["warrior", "archer", "mage"]
        let knownKinds = ["special_atk", "special_def", "super"]

        func fail(_ file: String, _ path: String, _ rule: String,
                  _ message: @autoclosure () -> String,
                  _ severity: ContentIssue.Severity = .error) {
            issues.append(.init(severity: severity, file: "tuning/\(file)", path: path,
                                id: nil, rule: rule, message: message()))
        }

        func require(_ passed: Bool, _ file: String, _ path: String, _ rule: String,
                     _ message: @autoclosure () -> String,
                     _ severity: ContentIssue.Severity = .error) {
            guard !passed else { return }
            fail(file, path, rule, message(), severity)
        }

        /// Every per-class table must carry each class exactly once. A missing
        /// row cannot be defaulted — `fleeChance(forClass:)` is non-optional and
        /// non-throwing, so it would have to invent a number.
        func checkClassCoverage(_ values: [String], file: String, path: String) {
            for cls in knownClasses where !values.contains(cls) {
                fail(file, path, "tuning.class_missing", "no row for class \"\(cls)\"")
            }
            for value in values where !knownClasses.contains(value) {
                fail(file, path, "tuning.class_unknown", "unknown character class \"\(value)\"")
            }
            for (index, value) in values.enumerated()
            where values.firstIndex(of: value) != index {
                fail(file, "\(path)[\(index)]", "tuning.class_duplicate",
                     "class \"\(value)\" appears more than once")
            }
        }

        func checkFraction(_ value: Double, _ file: String, _ path: String,
                           _ rule: String, upperBound: Double = 1.0) {
            require(value >= 0 && value <= upperBound, file, path, rule,
                    "\(path) must be between 0 and \(upperBound), found \(value)")
        }

        // MARK: combat.json
        do {
            let file = "combat.json"
            let combat = tuning.combat
            let hit = combat.hitChance
            require(hit.min <= hit.base && hit.base <= hit.max, file, "hitChance",
                    "tuning.combat.hit_chance_order",
                    "expected min <= base <= max, found \(hit.min) / \(hit.base) / \(hit.max)")
            require(hit.min >= 0 && hit.max <= 100, file, "hitChance",
                    "tuning.combat.hit_chance_range",
                    "hit chance bounds must sit inside 0...100, found \(hit.min)...\(hit.max)")
            // `varianceRange` builds a `ClosedRange`, which TRAPS when the lower
            // bound exceeds the upper. This rule is the only thing between an
            // inverted pair and a crash on the first landed hit.
            require(combat.variance.min <= combat.variance.max, file, "variance",
                    "tuning.combat.variance_inverted",
                    "variance min \(combat.variance.min) exceeds max \(combat.variance.max) — ClosedRange would trap")
            require(combat.variance.min > 0, file, "variance.min",
                    "tuning.combat.variance_non_positive",
                    "variance floor must be positive, found \(combat.variance.min)")
            require(combat.critMultiplier >= 1.0, file, "critMultiplier",
                    "tuning.combat.crit_weaker_than_hit",
                    "a crit multiplier below 1.0 makes crits hit softer than normal, found \(combat.critMultiplier)")
            checkFraction(combat.defendChipFraction, file, "defendChipFraction",
                          "tuning.combat.chip_fraction_range")
            require(enemyIds.contains(combat.trainingDummyEnemyId), file, "trainingDummyEnemyId",
                    "tuning.combat.dummy_unknown",
                    "references unknown enemy \"\(combat.trainingDummyEnemyId)\"")

            for kind in knownKinds where !combat.techniques.contains(where: { $0.kind == kind }) {
                fail(file, "techniques", "tuning.combat.technique_missing", "no row for technique \"\(kind)\"")
            }
            for (index, row) in combat.techniques.enumerated() {
                let path = "techniques[\(index)]"
                require(knownKinds.contains(row.kind), file, path, "tuning.combat.technique_unknown",
                        "unknown technique kind \"\(row.kind)\"")
                require(row.requiredLevel >= 1, file, path, "tuning.combat.technique_level",
                        "requiredLevel must be >= 1, found \(row.requiredLevel)")
                // A second use granted before the technique can be learned is a
                // budget the player can never observe changing.
                require(row.secondUseAtLevel >= row.requiredLevel, file, path,
                        "tuning.combat.second_use_before_unlock",
                        "secondUseAtLevel \(row.secondUseAtLevel) is below requiredLevel \(row.requiredLevel)")
                require(row.requiredLevel <= tuning.progression.maxLevel, file, path,
                        "tuning.combat.technique_unreachable",
                        "requiredLevel \(row.requiredLevel) is above maxLevel \(tuning.progression.maxLevel) — the technique can never be learned")
            }

            require(combat.stances.durationRounds >= 1, file, "stances.durationRounds",
                    "tuning.combat.stance_duration",
                    "a stance lasting \(combat.stances.durationRounds) rounds can never apply")
            require(combat.stances.defaultActivationVigor >= 0, file, "stances.defaultActivationVigor",
                    "tuning.combat.negative_vigor", "activation vigor must not be negative")
            checkClassCoverage(combat.stances.byId.map(\.characterClass), file: file, path: "stances.byId")
            issues += duplicates(combat.stances.byId.map(\.id), file: "tuning/combat.json", collection: "stances")
            for (index, row) in combat.stances.byId.enumerated() {
                let path = "stances.byId[\(index)]"
                require(row.activationVigor >= 0, file, path, "tuning.combat.negative_vigor",
                        "activation vigor must not be negative, found \(row.activationVigor)")
                // Every lift is a multiplier of the character's own stat since
                // Phase 8C. Zero is not "no effect", it DELETES the stat — and a
                // stance that zeroes a defender's DEF is a bug that reads like a
                // balance number, so it is refused rather than warned about.
                for (name, value) in [("attackMultiplier", row.attackMultiplier),
                                      ("defenseMultiplier", row.defenseMultiplier),
                                      ("critMultiplier", row.critMultiplier),
                                      ("accuracyMultiplier", row.accuracyMultiplier),
                                      ("dodgeMultiplier", row.dodgeMultiplier)] {
                    require(value > 0, file, "\(path).\(name)", "tuning.combat.stance_multiplier",
                            "\(name) must be positive (1.0 = no change), found \(value)")
                }
                require(row.vigorMultiplier >= 0, file, path, "tuning.combat.stance_vigor_multiplier",
                        "vigorMultiplier must not be negative, found \(row.vigorMultiplier)")
                // A stance that lifts nothing and costs Vigor is a button that
                // makes the player weaker. Only reachable by a hand edit that
                // dropped the payload, which is exactly when it is worth saying.
                let lifts = [row.attackMultiplier, row.defenseMultiplier, row.critMultiplier,
                             row.accuracyMultiplier, row.dodgeMultiplier]
                if lifts.allSatisfy({ $0 == 1.0 }) {
                    fail(file, path, "tuning.combat.stance_does_nothing",
                         "stance \"\(row.id)\" changes no stat but still costs \(row.activationVigor) vigor",
                         .warning)
                }
            }

            checkClassCoverage(combat.specialAttack.map(\.characterClass), file: file, path: "specialAttack")
            for (index, row) in combat.specialAttack.enumerated() {
                let path = "specialAttack[\(index)]"
                require(row.vigor >= 0, file, path, "tuning.combat.negative_vigor",
                        "vigor cost must not be negative, found \(row.vigor)")
                // Each effect carries its own sanity envelope. No `default:` —
                // a new effect kind has to be validated deliberately, not
                // waved through by an else branch.
                switch row.effect {
                case .armourBreak(let rounds):
                    require(rounds >= 1, file, "\(path).effect.rounds",
                            "tuning.combat.effect_rounds",
                            "an armour break lasting \(rounds) rounds never applies")
                case .guaranteedCrit(let multiplier):
                    // At or below the standard multiplier the technique is a
                    // normal hit that costs twice the Vigor.
                    require(multiplier > combat.critMultiplier, file, "\(path).effect.critMultiplier",
                            "tuning.combat.effect_crit_not_special",
                            "a guaranteed crit at ×\(multiplier) is no better than the standard ×\(combat.critMultiplier) it costs double the Vigor to reach")
                case .burn(let rounds, let fraction):
                    require(rounds >= 1, file, "\(path).effect.rounds",
                            "tuning.combat.effect_rounds",
                            "a burn lasting \(rounds) rounds never ticks")
                    require(fraction > 0, file, "\(path).effect.fractionOfAttack",
                            "tuning.combat.effect_burn_zero",
                            "a burn dealing 0 × ATK is a technique with no effect")
                }
            }

            checkClassCoverage(combat.specialDefense.byClass.map(\.characterClass),
                               file: file, path: "specialDefense.byClass")
            for (index, row) in combat.specialDefense.byClass.enumerated() {
                require(row.vigor >= 0, file, "specialDefense.byClass[\(index)]",
                        "tuning.combat.negative_vigor",
                        "vigor cost must not be negative, found \(row.vigor)")
            }
            require(combat.specialDefense.effectPersistRounds >= 0, file,
                    "specialDefense.effectPersistRounds", "tuning.combat.negative_rounds",
                    "effectPersistRounds must not be negative")
            checkFraction(combat.specialDefense.ironBulwarkChipFraction, file,
                          "specialDefense.ironBulwarkChipFraction", "tuning.combat.chip_fraction_range")
            checkFraction(combat.specialDefense.mirrorWardReflectFraction, file,
                          "specialDefense.mirrorWardReflectFraction", "tuning.combat.reflect_fraction_range")
            // A MULTIPLE of the archer's own dodge since Phase 8D, held to the
            // same rule as the stance lifts: zero does not mean "no effect",
            // it deletes the stat, and a value below 1.0 is a defensive
            // technique that makes the defender easier to hit.
            require(combat.specialDefense.shadowVeilDodgeMultiplier >= 1.0, file,
                    "specialDefense.shadowVeilDodgeMultiplier", "tuning.combat.dodge_multiplier",
                    "shadowVeilDodgeMultiplier must be at least 1.0 (1.0 = no change), found \(combat.specialDefense.shadowVeilDodgeMultiplier)")

            checkClassCoverage(combat.flee.map(\.characterClass), file: file, path: "flee")
            for (index, row) in combat.flee.enumerated() {
                let path = "flee[\(index)]"
                require(row.chance >= 1 && row.chance <= 100, file, path, "tuning.combat.flee_chance_range",
                        "flee chance must sit inside 1...100, found \(row.chance)")
                require(row.extraVigor >= 0, file, path, "tuning.combat.negative_vigor",
                        "extraVigor must not be negative, found \(row.extraVigor)")
            }

            require(combat.defend.archerChipMultiplier >= 0, file, "defend.archerChipMultiplier",
                    "tuning.combat.negative_multiplier", "chip multiplier must not be negative")
            require(combat.defend.archerDodgeMultiplier >= 1.0, file, "defend.archerDodgeMultiplier",
                    "tuning.combat.dodge_multiplier",
                    "archerDodgeMultiplier must be at least 1.0 (1.0 = no change), found \(combat.defend.archerDodgeMultiplier)")
            checkFraction(combat.defend.mageBarrierDamageFraction, file,
                          "defend.mageBarrierDamageFraction", "tuning.combat.barrier_fraction_range")
        }

        // MARK: vigor.json
        do {
            let file = "vigor.json"
            let drain = tuning.vigor.drain
            let costs: [(String, Int)] = [
                ("walkRoom", drain.walkRoom), ("walkRoomDoubleSpeed", drain.walkRoomDoubleSpeed),
                ("combatRound", drain.combatRound), ("combatAttack", drain.combatAttack),
                ("combatDefend", drain.combatDefend), ("combatFlee", drain.combatFlee),
                ("idle", drain.idle)
            ]
            for (name, value) in costs {
                require(value >= 0, file, "drain.\(name)", "tuning.vigor.negative_drain",
                        "drain must not be negative, found \(value)")
            }
            // A free step is not a balance choice, it is an unbounded loot
            // faucet: exploration would cost the player nothing at all.
            require(drain.walkRoom > 0, file, "drain.walkRoom", "tuning.vigor.free_step",
                    "walking a room must cost vigor, found \(drain.walkRoom)")
            checkFraction(tuning.vigor.starvation.statPenalty, file, "starvation.statPenalty",
                          "tuning.vigor.starvation_range")
            checkFraction(tuning.vigor.starvation.hpDrainPercent, file, "starvation.hpDrainPercent",
                          "tuning.vigor.starvation_range")
            checkFraction(tuning.vigor.healing.regenPerMinute, file, "healing.regenPerMinute",
                          "tuning.vigor.regen_range")
            require(tuning.vigor.healing.maxIdleMinutes > 0, file, "healing.maxIdleMinutes",
                    "tuning.vigor.regen_window", "idle credit window must be positive")
        }

        // MARK: exploration.json
        do {
            let file = "exploration.json"
            let exploration = tuning.exploration
            // `Int.random(in: 0..<total)` traps on a non-positive upper bound.
            require(exploration.eventWeightTotal > 0, file, "eventWeightTotal",
                    "tuning.exploration.total_non_positive",
                    "the roll range must be positive, found \(exploration.eventWeightTotal) — Int.random would trap")
            checkFraction(exploration.tripDamagePercent, file, "tripDamagePercent",
                          "tuning.exploration.trip_damage_range")
            // Empty would crash the `tiers[count - 1]` fallback in `weights`.
            require(!exploration.weightTiers.isEmpty, file, "weightTiers",
                    "tuning.exploration.tiers_empty", "the weight table must not be empty")
            // Contiguous from 0 is what makes "exact match, otherwise the LAST
            // row" mean "the bare tier". A gap or a reorder silently changes
            // which weights a re-entered room gets.
            for (index, row) in exploration.weightTiers.enumerated() {
                let path = "weightTiers[\(index)]"
                require(row.priorVisits == index, file, path,
                        "tuning.exploration.tier_not_contiguous",
                        "expected priorVisits \(index), found \(row.priorVisits) — the tail row is the fallback for every higher and every negative count, so the run must be contiguous from 0")
                let weights = [row.nothing, row.loot, row.encounter, row.trip]
                for weight in weights where weight < 0 {
                    fail(file, path, "tuning.exploration.negative_weight",
                         "weights must not be negative, found \(weight)")
                }
                let sum = weights.reduce(0, +)
                require(sum == exploration.eventWeightTotal, file, path,
                        "tuning.exploration.weights_dont_sum",
                        "weights sum to \(sum) but eventWeightTotal is \(exploration.eventWeightTotal) — the remainder silently falls into the last bucket")
            }
        }

        // MARK: progression.json
        do {
            let file = "progression.json"
            let progression = tuning.progression
            require(progression.maxLevel >= 2, file, "maxLevel", "tuning.progression.max_level",
                    "maxLevel must be at least 2, found \(progression.maxLevel)")
            let curve = progression.xpCurve
            require(curve.coefficient > 0, file, "xpCurve.coefficient",
                    "tuning.progression.xp_first_cost",
                    "the curve coefficient must be positive, found \(curve.coefficient)")
            require(curve.floorPerLevel > 0, file, "xpCurve.floorPerLevel",
                    "tuning.progression.xp_floor",
                    "the early-level floor must be positive, found \(curve.floorPerLevel)")
            // At or below 1 the curve is linear or shrinking, so later levels
            // cost no more than early ones and the ladder flattens entirely.
            require(curve.exponent > 1.0, file, "xpCurve.exponent",
                    "tuning.progression.xp_curve_flat",
                    "an exponent at or below 1.0 makes late levels cost no more than early ones, found \(curve.exponent)")

            let mob = progression.mobXP
            require(mob.coefficient > 0, file, "mobXP.coefficient",
                    "tuning.progression.mob_xp_coefficient",
                    "monsters must award XP, found coefficient \(mob.coefficient)")
            // The pacing identity: the XP a level costs must outgrow the XP a
            // monster of that level gives, or kills-per-level FALLS as the
            // player advances and the whole curve inverts.
            require(mob.exponent < curve.exponent, file, "mobXP.exponent",
                    "tuning.progression.mob_xp_outruns_curve",
                    "monster XP grows at L^\(mob.exponent) against a curve of L^\(curve.exponent) — kills per level would fall as the player levels up")

            let xpGap = progression.xpLevelDiff
            require(xpGap.perLevel > 0, file, "xpLevelDiff.perLevel",
                    "tuning.progression.xp_level_diff_absent",
                    "without a per-level penalty, farming far below your level stays fully rewarding and the depth ladder becomes dead content")
            require(xpGap.min >= 0 && xpGap.min <= xpGap.max, file, "xpLevelDiff",
                    "tuning.progression.xp_level_diff_range",
                    "expected 0 <= min <= max, found \(xpGap.min) / \(xpGap.max)")

            let growth = progression.statGrowth
            for (name, rate) in [("hpPerLevel", growth.hpPerLevel),
                                 ("attackPerLevel", growth.attackPerLevel),
                                 ("ratingPerLevel", growth.ratingPerLevel)] {
                require(rate >= 0, file, "statGrowth.\(name)",
                        "tuning.progression.negative_growth",
                        "growth rate must not be negative, found \(rate)")
                // A rate that multiplies a stat by more than ~50x over a
                // lifetime is almost certainly a misplaced decimal point
                // (0.85 where 0.085 was meant) rather than a design choice.
                require(rate * Double(progression.maxLevel) <= 50, file, "statGrowth.\(name)",
                        "tuning.progression.growth_runaway",
                        "a rate of \(rate) multiplies the stat by \(1 + rate * Double(progression.maxLevel - 1)) by the cap — check for a misplaced decimal point",
                        .warning)
            }
            // Ratings must not grow SLOWER than the diminishing-returns
            // denominators they feed, or the percentage they produce rots while
            // the number on the profile screen rises. This is the structural
            // trap the proportional model exists to avoid; a zero rate is the
            // flat-growth model coming back in through the data.
            require(growth.ratingPerLevel > 0, file, "statGrowth.ratingPerLevel",
                    "tuning.progression.ratings_do_not_scale",
                    "ratings must grow with level — at 0 the crit/dodge/accuracy PERCENTAGES fall every level while their ratings stand still")

            let pool = progression.vigorPool
            require(pool.base > 0, file, "vigorPool.base", "tuning.progression.vigor_pool",
                    "the Vigor pool must be positive, found \(pool.base)")
            require(pool.perLevel >= 0, file, "vigorPool.perLevel", "tuning.progression.vigor_pool",
                    "per-level Vigor must not be negative")
            // `fullRegenHours` and its rule went in Phase 8E with the mechanic.
            // Nothing refills the pool on a clock now, so the pool is a stock
            // and food is the whole income.

            checkClassCoverage(progression.classes.map(\.characterClass), file: file, path: "classes")
            for (index, row) in progression.classes.enumerated() {
                let path = "classes[\(index)]"
                require(row.hp > 0, file, path, "tuning.progression.start_hp",
                        "starting HP must be positive, found \(row.hp)")
                let stats = [("attack", row.attack), ("defense", row.defense), ("crit", row.crit),
                             ("dodge", row.dodge), ("accuracy", row.accuracy)]
                for (name, value) in stats where value < 0 {
                    fail(file, "\(path).\(name)", "tuning.progression.negative_start_stat",
                         "\(name) must not be negative, found \(value)")
                }
                if !itemIds.contains(row.starterWeaponId) {
                    fail(file, "\(path).starterWeaponId", "tuning.progression.starter_weapon_unknown",
                         "references unknown item \"\(row.starterWeaponId)\"")
                } else if bundle.items.first(where: { $0.id == row.starterWeaponId })?.slot != "main_hand" {
                    // The King's Oath auto-equips this into the main hand; a
                    // chest piece there would leave the class weaponless.
                    fail(file, "\(path).starterWeaponId", "tuning.progression.starter_weapon_slot",
                         "\"\(row.starterWeaponId)\" is not a main-hand item")
                }
            }

            // Empty would crash the subscript in `WarehouseService.capForLevel`.
            require(!progression.warehouseCapByEstateLevel.isEmpty, file, "warehouseCapByEstateLevel",
                    "tuning.progression.warehouse_empty", "the warehouse cap table must not be empty")
            for (index, cap) in progression.warehouseCapByEstateLevel.enumerated() {
                require(cap > 0, file, "warehouseCapByEstateLevel[\(index)]",
                        "tuning.progression.warehouse_non_positive",
                        "capacity must be positive, found \(cap)")
            }
            for pair in zip(progression.warehouseCapByEstateLevel,
                            progression.warehouseCapByEstateLevel.dropFirst())
            where pair.1 < pair.0 {
                fail(file, "warehouseCapByEstateLevel", "tuning.progression.warehouse_regression",
                     "capacity must not shrink as the estate levels up — \(pair.0) is followed by \(pair.1)")
            }
        }

        // MARK: economy.json
        do {
            let file = "economy.json"
            let gear = tuning.economy.gear
            // `MasterCatalog.repairCost` DIVIDES by this.
            require(gear.maxDurabilityStart > 0, file, "gear.maxDurabilityStart",
                    "tuning.economy.durability_non_positive",
                    "starting durability must be positive, found \(gear.maxDurabilityStart) — MasterCatalog.repairCost divides by it")
            require(gear.repairMaxShave >= 0, file, "gear.repairMaxShave",
                    "tuning.economy.negative_shave", "repair shave must not be negative")
            require(gear.repairMaxShave < gear.maxDurabilityStart, file, "gear.repairMaxShave",
                    "tuning.economy.shave_destroys_gear",
                    "a shave of \(gear.repairMaxShave) against a starting durability of \(gear.maxDurabilityStart) destroys the piece on its first repair")
            let wear = gear.wearBudget
            for (name, value) in [("victory", wear.victory), ("defeat", wear.defeat), ("flee", wear.flee)]
            where value < 0 {
                fail(file, "gear.wearBudget.\(name)", "tuning.economy.negative_wear",
                     "wear must not be negative, found \(value)")
            }
            // The audit's finding, kept live in the tool rather than in prose:
            // running away currently wears gear harder than dying does, which
            // prices flight above death. Phase 5 rebalances it.
            require(wear.flee <= wear.defeat, file, "gear.wearBudget",
                    "tuning.economy.flee_costlier_than_defeat",
                    "fleeing wears \(wear.flee) durability against \(wear.defeat) for a defeat — running away costs more than dying",
                    .warning)
        }

        // MARK: time.json
        do {
            let file = "time.json"
            let game = tuning.time.gameTime
            let real = tuning.time.realTime
            require(game.travelMinutes > 0, file, "gameTime.travelMinutes",
                    "tuning.time.non_positive", "travel time must be positive")
            require(game.passiveExpedition.unitsPerStep > 0, file, "gameTime.passiveExpedition.unitsPerStep",
                    "tuning.time.non_positive", "a step must consume at least one duration unit")
            require(game.passiveExpedition.secondsPerUnit > 0, file, "gameTime.passiveExpedition.secondsPerUnit",
                    "tuning.time.non_positive", "a duration unit must be worth real time")
            require(game.plotIntervalSeconds > 0, file, "gameTime.plotIntervalSeconds",
                    "tuning.time.non_positive", "the production interval must be positive")
            require(game.plotSweeper.intervalDivisor >= 1, file, "gameTime.plotSweeper.intervalDivisor",
                    "tuning.time.sweeper_divisor",
                    "the divisor must be at least 1, found \(game.plotSweeper.intervalDivisor)")
            require(game.plotSweeper.minSeconds > 0, file, "gameTime.plotSweeper.minSeconds",
                    "tuning.time.non_positive", "the sweeper floor must be positive")
            // The floor is what keeps the sweeper off the database, but a floor
            // above the interval inverts the invariant the derivation exists to
            // hold: a filled plot would wait a whole extra cycle to be announced.
            require(game.plotSweeper.minSeconds <= game.plotIntervalSeconds, file,
                    "gameTime.plotSweeper.minSeconds", "tuning.time.sweeper_slower_than_interval",
                    "the sweeper floor \(game.plotSweeper.minSeconds)s exceeds the production interval \(game.plotIntervalSeconds)s",
                    .warning)

            for (name, value) in [("tradeLobbyTTL", real.tradeLobbyTTL),
                                  ("tradeSessionTTL", real.tradeSessionTTL),
                                  ("tradeSweepInterval", real.tradeSweepInterval),
                                  ("tavernSweepInterval", real.tavernSweepInterval)]
            where value <= 0 {
                fail(file, "realTime.\(name)", "tuning.time.non_positive",
                     "\(name) must be positive, found \(value)")
            }
            // A PROTOCOL floor, not a balance number: Telegram refuses to delete
            // a private-chat dice message younger than 24 h, so anything below
            // that turns every sweep into a failed API call and the rows never
            // clear.
            require(real.tavernDeletableAfter >= 24 * 60 * 60, file, "realTime.tavernDeletableAfter",
                    "tuning.time.tavern_below_telegram_floor",
                    "must be at least 86400s — Telegram refuses to delete a private-chat dice message younger than 24 h, so every sweep below this floor fails")
            require(real.dayRolloverHour >= 0 && real.dayRolloverHour <= 23, file,
                    "realTime.dayRolloverHour", "tuning.time.rollover_hour_range",
                    "the rollover hour must sit inside 0...23, found \(real.dayRolloverHour)")
            // `GameDay` falls back to UTC on an unresolvable id, which would
            // shift every daily reset by hours without a single error.
            require(TimeZone(identifier: real.dayTimeZoneId) != nil, file, "realTime.dayTimeZoneId",
                    "tuning.time.timezone_unknown",
                    "\"\(real.dayTimeZoneId)\" is not a known time zone — GameDay would silently fall back to UTC and move every daily reset")
        }

        return issues
    }

    // MARK: - Time

    private static func validateTime(_ bundle: ContentBundle) -> [ContentIssue] {
        guard let scale = bundle.tuning?.time.scale else { return [] }
        // A zero or negative scale is not a warning — every derived duration
        // divides by it, so it would either trap or run the clock backwards.
        if scale <= 0 {
            return [.init(severity: .error, file: "tuning/time.json", path: "scale", id: nil,
                          rule: "time.scale_non_positive",
                          message: "scale must be positive, found \(scale) — every game-time duration divides by it")]
        }
        guard scale != 1.0 else { return [] }
        return [.init(severity: .warning, file: "tuning/time.json", path: "scale", id: nil,
                      rule: "time.scale_not_one",
                      message: "scale is \(scale) — every time gate is compressed \(scale)×; must be 1.0 for release")]
    }
}
