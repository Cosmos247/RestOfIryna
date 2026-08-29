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
//  It exports ONLY catalogs that still live as Swift arrays. Everything wired
//  so far — items, enemies, recipes (Phase 2), the weapon / bag / estate ladders
//  (3A), and trader / tavern / market / guild / arena (3B) — is deliberately
//  absent: re-exporting a façade writes back what was loaded a moment earlier,
//  and a self-check over that circle proves nothing.
//
//  The export normalizes nothing — orderings and sentinels are preserved, so a
//  behavioural difference after a flip is provably a pipeline bug rather than a
//  design change.
//
//  `manifest.json` is NOT rewritten: it describes the whole bundle and is now
//  hand-maintained. Deleted along with this file at the end of Phase 3.
//
//  One thing the 3B pass is worth remembering, because the next batch has the
//  same shape: `ArenaCatalog.leagueKey` was a `switch`, i.e. control flow rather
//  than data, so the exporter could not read the table off the catalog — it had
//  to be hand-translated into `arena.json`. The translation was proven, not
//  trusted: the exporter replayed the shipped switch against the new table over
//  honor −500…3000 and refused to write anything on the first mismatch. Any
//  future catalog whose behaviour lives in code, not in an array, needs that
//  same replay before its flip. `PlotCatalog` and `QuestCatalog` both qualify.
//

import Foundation

enum ContentExporter {

    static func run(outputDirectory: String) throws {
        _ = outputDirectory
        print("Nothing to export: every catalog wired so far now reads from content/data.")
        print("Add the next catalog here when Phase 3 moves it — export first, then flip,")
        print("then remove it from this list, because re-exporting a façade would write")
        print("back what was just loaded and a self-check over that circle proves nothing.")
        print("")
        print("Still Swift-backed: PlotCatalog · MasterCatalog · FortuneCatalog · QuestCatalog")
        fflush(stdout)
    }

    private static func write<T: Encodable>(
        _ value: T, to root: URL, _ name: String, _ encoder: JSONEncoder
    ) throws {
        var data = try encoder.encode(value)
        data.append(0x0A)   // trailing newline — POSIX text file, clean git diffs
        try data.write(to: root.appendingPathComponent(name))
    }
}
