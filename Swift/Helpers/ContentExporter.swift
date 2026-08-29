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
        _ = outputDirectory
        print("Nothing to export: every catalog wired so far now reads from content/data.")
        print("Add the next catalog here when Phase 3 moves it — export first, then flip,")
        print("then remove it from this list, because re-exporting a façade would write")
        print("back what was just loaded and a self-check over that circle proves nothing.")
        print("")
        print("Still Swift-backed: PlotCatalog · TraderCatalog · MasterCatalog · TavernCatalog")
        print("                    MarketCatalog · GuildCatalog · ArenaCatalog · FortuneCatalog")
        print("                    QuestCatalog")
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
