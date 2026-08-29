//
//  ContentExporter.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 29.08.2026.
//
//  One-shot migration tool: dumps the compiled Swift catalogs to
//  `content/data/*.json` so the move to data-driven content starts from a
//  provably neutral baseline.
//
//    swift run RestOfIryna --export-content [outputDir]
//
//  Invoked from `entrypoint.swift` before `configure`, so it never touches
//  Postgres, the bot token or the network.
//
//  The export normalizes NOTHING. Sentinels stay sentinels, orderings stay as
//  declared. Any behavioural difference after the catalogs flip is therefore
//  provably a pipeline bug rather than a design change — balance edits start in
//  a later commit.
//
//  `generatedAt` is deliberately left out of the manifest: a timestamp would
//  make every re-export dirty the diff and destroy the byte-for-byte
//  comparison. `contentHash`, printed at boot and by `/content`, is the
//  identity that actually matters.
//
//  Deleted once the Swift arrays are gone (end of Phase 3).
//

import Foundation

enum ContentExporter {

    /// Current build runs with `PlotCatalog.testMode`, `TravelService.testMode`
    /// and `PassiveExpeditionService.testMode` all `true`, which compresses
    /// every time gate by 60×. The manifest records that truthfully, so the
    /// validator's `time.scale_not_one` rule fires on real data from day one.
    /// Phase 4 flips it to 1.0 in its own commit.
    static let currentTimeScale: Double = 60.0

    static func run(outputDirectory: String) throws {
        let root = URL(fileURLWithPath: outputDirectory)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        let items = ItemCatalog.all.map(ItemDTO.init)
        let enemies = EnemyCatalog.all.map(EnemyDTO.init)
        let recipes = RecipeCatalog.all.map(RecipeDTO.init)
        // `starterRecipeIds` is a Set — unordered. Sorted so the export is
        // reproducible instead of reshuffling on every run.
        let starters = RecipeCatalog.starterRecipeIds.sorted()
        // `progression` is a dictionary — unordered. Sorted by item id so the
        // export is reproducible. Ladder ORDER carries no gameplay meaning
        // (lookup is by id), unlike the item/enemy arrays.
        let ladders = WeaponUpgradeCatalog.progression
            .sorted { $0.key < $1.key }
            .map { WeaponLadderDTO(itemId: $0.key, steps: $0.value) }

        let encoder = ContentLoader.makeEncoder()
        let manifest = ManifestDTO(
            schemaVersion: ContentSchema.current,
            contentVersion: "phase1-export",
            timeScale: currentTimeScale
        )

        try write(manifest, to: root, "manifest.json", encoder)
        try write(ItemFileDTO(items: items), to: root, "items.json", encoder)
        try write(EnemyFileDTO(enemies: enemies), to: root, "enemies.json", encoder)
        try write(RecipeFileDTO(recipes: recipes, starterRecipeIds: starters), to: root, "recipes.json", encoder)
        try write(WeaponUpgradeFileDTO(ladders: ladders,
                                       durabilityByTier: WeaponUpgradeCatalog.durabilityByTier),
                  to: root, "weapon_upgrades.json", encoder)

        print("Exported to \(root.path)")
        print("  items.json    \(items.count)")
        print("  enemies.json  \(enemies.count)")
        print("  recipes.json  \(recipes.count) (+\(starters.count) starter ids)")
        print("  weapon_upgrades.json  \(ladders.count) ladders")
        print("")
        try selfCheck(items: items, enemies: enemies, recipes: recipes, ladders: ladders, encoder: encoder)
    }

    // MARK: - Verification

    /// Layer 1 — canonical round-trip, and Layer 2 — counts and id sets.
    ///
    /// Layer 1 compares canonical ENCODINGS rather than values: the domain
    /// structs are not `Equatable`, and conforming fifteen of them would be
    /// churn. With `sortedKeys` the encoding is deterministic, so
    /// `JSON₁ == JSON₂` catches every lossy field in the mapping — the
    /// `ClosedRange`, the tagged `ItemEffect`, the optional locale keys.
    ///
    /// Layer 3 (seeded simulation diff) belongs to Phase 2, where the catalogs
    /// actually flip and behaviour could change. Nothing reads this JSON yet.
    private static func selfCheck(
        items: [ItemDTO], enemies: [EnemyDTO], recipes: [RecipeDTO],
        ladders: [WeaponLadderDTO], encoder: JSONEncoder
    ) throws {
        var failures: [String] = []

        func roundTrip<D: Codable, T>(
            _ label: String,
            _ dtos: [D],
            toDomain: (D) throws -> T,
            toDTO: (T) -> D
        ) {
            do {
                let first = try encoder.encode(dtos)
                let decoded = try JSONDecoder().decode([D].self, from: first)
                let rebuilt = try decoded.map { toDTO(try toDomain($0)) }
                let second = try encoder.encode(rebuilt)
                if first == second {
                    print("  ✅ \(label): domain → DTO → JSON → DTO → domain → DTO → JSON is byte-identical")
                } else {
                    failures.append("\(label): round-trip is lossy")
                    print("  ❌ \(label): round-trip is LOSSY")
                }
            } catch {
                failures.append("\(label): \(error)")
                print("  ❌ \(label): \(error)")
            }
        }

        print("Layer 0 — domain equivalence")
        equivalence("items", ItemCatalog.all, items,
                    rebuild: { try $0.toDomain() }, fingerprint: fingerprint(_:), failures: &failures)
        equivalence("enemies", EnemyCatalog.all, enemies,
                    rebuild: { try $0.toDomain() }, fingerprint: fingerprint(_:), failures: &failures)
        equivalence("recipes", RecipeCatalog.all, recipes,
                    rebuild: { try $0.toDomain() }, fingerprint: fingerprint(_:), failures: &failures)

        print("")
        print("Layer 1 — canonical round-trip")
        roundTrip("items", items, toDomain: { try $0.toDomain() }, toDTO: ItemDTO.init)
        roundTrip("enemies", enemies, toDomain: { try $0.toDomain() }, toDTO: EnemyDTO.init)
        roundTrip("recipes", recipes, toDomain: { try $0.toDomain() }, toDTO: RecipeDTO.init)
        roundTrip("ladders", ladders,
                  toDomain: { (dto: WeaponLadderDTO) in (dto.itemId, dto.domainSteps) },
                  toDTO: { WeaponLadderDTO(itemId: $0.0, steps: $0.1) })

        print("")
        print("Layer 2 — counts and id sets")
        func expect(_ label: String, _ actual: Int, _ expected: Int) {
            if actual == expected {
                print("  ✅ \(label): \(actual)")
            } else {
                failures.append("\(label): expected \(expected), got \(actual)")
                print("  ❌ \(label): expected \(expected), got \(actual)")
            }
        }
        expect("items", items.count, 33)
        expect("enemies", enemies.count, 9)
        expect("recipes", recipes.count, 12)
        expect("weapon ladders", ladders.count, 3)
        expect("durability tiers", WeaponUpgradeCatalog.durabilityByTier.count, 5)

        func expectIds(_ label: String, _ exported: [String], _ source: [String]) {
            if exported == source {
                print("  ✅ \(label): ids match source order exactly")
            } else {
                failures.append("\(label): id set or order drifted")
                print("  ❌ \(label): id set or order drifted")
            }
        }
        // Declaration order is load-bearing: `EnemyCatalog.pickFor` selects with
        // `filter().randomElement()`, so reordering changes which enemy a given
        // seeded roll returns.
        expectIds("items", items.map(\.id), ItemCatalog.all.map(\.id))
        expectIds("enemies", enemies.map(\.id), EnemyCatalog.all.map(\.id))
        expectIds("recipes", recipes.map(\.id), RecipeCatalog.all.map(\.id))
        expectIds("ladders", ladders.map(\.itemId), WeaponUpgradeCatalog.progression.keys.sorted())

        print("")
        if failures.isEmpty {
            print("✅ export verified — \(items.count + enemies.count + recipes.count + ladders.count) records, no drift")
        } else {
            print("❌ \(failures.count) verification failure(s):")
            for failure in failures { print("   • \(failure)") }
            // `print` is block-buffered when stdout is a pipe, and an error
            // escaping `@main` terminates without flushing — which loses the
            // whole diagnostic exactly when it is needed. Flush explicitly.
            fflush(stdout)
            throw ContentError.validationFailed(errorCount: failures.count)
        }
    }

    /// Layer 0 — the check the canonical round-trip CANNOT make.
    ///
    /// `domain → DTO → domain → DTO → JSON` stays byte-stable even when the
    /// mapper never captured a field at all: both directions drop it
    /// consistently, so the two encodings still match. The only way to catch a
    /// silently-dropped field is to compare the REBUILT domain value against
    /// the original one, field by field.
    ///
    /// `fingerprint` therefore enumerates every stored property. When a domain
    /// type gains a field, extend the fingerprint in the same edit as the
    /// mapper — this is the assertion that would otherwise let a whole column
    /// vanish from the game without a single test going red.
    private static func equivalence<Domain, DTO>(
        _ label: String,
        _ originals: [Domain],
        _ dtos: [DTO],
        rebuild: (DTO) throws -> Domain,
        fingerprint: (Domain) -> String,
        failures: inout [String]
    ) {
        guard originals.count == dtos.count else {
            failures.append("\(label): \(originals.count) source records but \(dtos.count) exported")
            print("  ❌ \(label): count mismatch")
            return
        }
        do {
            var mismatches: [String] = []
            for (original, dto) in zip(originals, dtos) {
                let before = fingerprint(original)
                let after = fingerprint(try rebuild(dto))
                if before != after {
                    mismatches.append("\n      was: \(before)\n      now: \(after)")
                }
            }
            if mismatches.isEmpty {
                print("  ✅ \(label): every field survives domain → DTO → domain")
            } else {
                failures.append("\(label): \(mismatches.count) record(s) lost or changed a field")
                print("  ❌ \(label): \(mismatches.count) record(s) differ\(mismatches.prefix(3).joined())")
            }
        } catch {
            failures.append("\(label): \(error)")
            print("  ❌ \(label): \(error)")
        }
    }

    // MARK: - Field-complete fingerprints

    private static func fingerprint(_ item: Item) -> String {
        let effects = item.effects.map { effect -> String in
            switch effect {
            case .restoreVigor(let amount): return "vigor:\(amount)"
            case .restoreHP(let amount):    return "hp:\(amount)"
            }
        }.joined(separator: "|")
        let gear = item.gearStats.map {
            "\($0.attack)/\($0.defense)/\($0.crit)/\($0.dodge)/\($0.accuracy)"
        } ?? "-"
        return [
            item.id, item.nameKey, item.type.rawValue, "\(item.tier)", "\(item.stackable)",
            effects, item.slot?.rawValue ?? "-", gear, item.icon ?? "-",
            item.descriptionKey ?? "-", item.teachesRecipe ?? "-"
        ].joined(separator: " · ")
    }

    private static func fingerprint(_ enemy: Enemy) -> String {
        let loot = enemy.lootTable
            .map { "\($0.itemId)@\($0.chance)x\($0.quantity)" }
            .joined(separator: "|")
        return [
            enemy.id, enemy.nameKey, "\(enemy.tier)", "\(enemy.hp)", "\(enemy.attack)",
            "\(enemy.defense)", "\(enemy.depthRange.lowerBound)...\(enemy.depthRange.upperBound)",
            loot, enemy.icon, "\(enemy.xpReward)"
        ].joined(separator: " · ")
    }

    private static func fingerprint(_ recipe: Recipe) -> String {
        let inputs = recipe.inputs.map { "\($0.itemId)x\($0.quantity)" }.joined(separator: "|")
        return [
            recipe.id, recipe.category.rawValue, inputs,
            "\(recipe.output.itemId)x\(recipe.output.quantity)"
        ].joined(separator: " · ")
    }

    private static func write<T: Encodable>(
        _ value: T, to root: URL, _ name: String, _ encoder: JSONEncoder
    ) throws {
        var data = try encoder.encode(value)
        data.append(0x0A)   // trailing newline — POSIX text file, clean git diffs
        try data.write(to: root.appendingPathComponent(name))
    }
}
