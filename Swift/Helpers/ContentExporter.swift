//
//  ContentExporter.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 29.08.2026.
//
//  Migration tool: dumps still-compiled Swift catalogs to `content/data/*.json`
//  so each catalog's move to data starts from a provably neutral baseline.
//
//    swift run RestOfIryna --export-content [outputDir]
//
//  Runs from `entrypoint.swift` before `configure`, so it never touches
//  Postgres, the bot token or the network.
//
//  It exports ONLY catalogs that still live as Swift arrays. `ItemCatalog`,
//  `EnemyCatalog` and `RecipeCatalog` flipped to façades in Phase 2 and are
//  deliberately absent: re-exporting them would just write back what was loaded
//  a moment earlier, and a self-check over that circle proves nothing.
//
//  Still Swift-backed, to be added here as Phase 3 works through them:
//  BagCatalog, EstateUpgradeCatalog, PlotCatalog, TraderCatalog, MasterCatalog,
//  TavernCatalog, MarketCatalog, GuildCatalog, ArenaCatalog, FortuneCatalog,
//  QuestCatalog.
//
//  The export normalizes nothing — orderings and sentinels are preserved, so a
//  behavioural difference after a flip is provably a pipeline bug rather than a
//  design change.
//
//  `manifest.json` is NOT rewritten: it describes the whole bundle and is now
//  hand-maintained. Deleted along with this file at the end of Phase 3.
//

import Foundation

enum ContentExporter {

    static func run(outputDirectory: String) throws {
        let root = URL(fileURLWithPath: outputDirectory)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        // `progression` is a dictionary — unordered. Sorted by item id so the
        // export is reproducible. Ladder order carries no gameplay meaning
        // (lookup is by id), unlike the item and enemy arrays.
        let ladders = WeaponUpgradeCatalog.progression
            .sorted { $0.key < $1.key }
            .map { WeaponLadderDTO(itemId: $0.key, steps: $0.value) }

        let encoder = ContentLoader.makeEncoder()
        try write(WeaponUpgradeFileDTO(ladders: ladders,
                                       durabilityByTier: WeaponUpgradeCatalog.durabilityByTier),
                  to: root, "weapon_upgrades.json", encoder)

        print("Exported to \(root.path)")
        print("  weapon_upgrades.json  \(ladders.count) ladders")
        print("")
        try selfCheck(ladders: ladders, encoder: encoder)
    }

    // MARK: - Verification

    /// Layer 0 (domain equivalence) is the load-bearing check and the reason
    /// this is not just a round-trip: `domain → DTO → domain → DTO → JSON`
    /// stays byte-stable even when the mapper never captured a field, because
    /// both directions drop it consistently. Only comparing the REBUILT domain
    /// value against the original catches a dropped column.
    ///
    /// Proven non-vacuous during the Phase 1 audit: deleting `teachesRecipe`
    /// from the mapper — which would have silently removed all five recipe
    /// scrolls from the game — left the round-trip and the count checks green
    /// and was caught by layer 0 alone.
    private static func selfCheck(ladders: [WeaponLadderDTO], encoder: JSONEncoder) throws {
        var failures: [String] = []

        print("Layer 0 — domain equivalence")
        let sourceIds = WeaponUpgradeCatalog.progression.keys.sorted()
        if ladders.map(\.itemId) == sourceIds {
            var mismatches = 0
            for ladder in ladders {
                let original = WeaponUpgradeCatalog.progression[ladder.itemId] ?? []
                let rebuilt = ladder.domainSteps
                if fingerprint(original) != fingerprint(rebuilt) { mismatches += 1 }
            }
            if mismatches == 0 {
                print("  ✅ ladders: every field survives domain → DTO → domain")
            } else {
                failures.append("ladders: \(mismatches) ladder(s) lost or changed a field")
                print("  ❌ ladders: \(mismatches) ladder(s) differ")
            }
        } else {
            failures.append("ladders: id set drifted from the source catalog")
            print("  ❌ ladders: id set drifted")
        }

        print("")
        print("Layer 1 — canonical round-trip")
        do {
            let first = try encoder.encode(ladders)
            let decoded = try JSONDecoder().decode([WeaponLadderDTO].self, from: first)
            let rebuilt = decoded.map { WeaponLadderDTO(itemId: $0.itemId, steps: $0.domainSteps) }
            let second = try encoder.encode(rebuilt)
            if first == second {
                print("  ✅ ladders: encoding is byte-identical across the round-trip")
            } else {
                failures.append("ladders: round-trip is lossy")
                print("  ❌ ladders: round-trip is LOSSY")
            }
        } catch {
            failures.append("ladders: \(error)")
            print("  ❌ ladders: \(error)")
        }

        print("")
        print("Layer 2 — counts")
        func expect(_ label: String, _ actual: Int, _ expected: Int) {
            if actual == expected {
                print("  ✅ \(label): \(actual)")
            } else {
                failures.append("\(label): expected \(expected), got \(actual)")
                print("  ❌ \(label): expected \(expected), got \(actual)")
            }
        }
        expect("weapon ladders", ladders.count, 3)
        expect("durability tiers", WeaponUpgradeCatalog.durabilityByTier.count, 5)

        print("")
        if failures.isEmpty {
            print("✅ export verified — \(ladders.count) ladders, no drift")
        } else {
            print("❌ \(failures.count) verification failure(s):")
            for failure in failures { print("   • \(failure)") }
            // `print` is block-buffered when stdout is a pipe, and an error
            // escaping `@main` terminates without flushing — which loses the
            // whole diagnostic exactly when it is needed.
            fflush(stdout)
            throw ContentError.validationFailed(errorCount: failures.count)
        }
    }

    /// Field-complete fingerprint of a ladder. Extend this in the same edit as
    /// the mapper when `WeaponUpgradeStep` gains a stored property.
    private static func fingerprint(_ steps: [WeaponUpgradeStep]) -> String {
        steps.enumerated().map { index, step in
            let stats = "\(step.stats.attack)/\(step.stats.defense)/\(step.stats.crit)/\(step.stats.dodge)/\(step.stats.accuracy)"
            let inputs = step.inputs.map { "\($0.itemId)x\($0.quantity)" }.joined(separator: "|")
            return "t\(index + 1):\(stats):\(inputs)"
        }.joined(separator: " · ")
    }

    private static func write<T: Encodable>(
        _ value: T, to root: URL, _ name: String, _ encoder: JSONEncoder
    ) throws {
        var data = try encoder.encode(value)
        data.append(0x0A)   // trailing newline — POSIX text file, clean git diffs
        try data.write(to: root.appendingPathComponent(name))
    }
}
