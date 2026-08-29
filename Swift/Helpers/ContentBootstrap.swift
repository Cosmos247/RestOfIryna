//
//  ContentBootstrap.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 29.08.2026.
//
//  Loading seam for the data-driven content bundle.
//
//  Phase 0 lands the function; nothing calls it yet. It gets wired into
//  `configure(logger:)` — immediately after `Dotenv.configure` and BEFORE the
//  database block — in Phase 2, once `ItemCatalog` / `EnemyCatalog` /
//  `RecipeCatalog` become façades over `GameData.current`. The ordering is
//  load-bearing: the dev-seed block later in `configure` already calls
//  `ItemCatalog.find`, and once that reads the snapshot, any touch before
//  install traps.
//
//  NOTE — this file deliberately does NOT `import ROIContent`. It resolves
//  `ContentSchema`, `ContentLoader`, `GameData` and friends through the
//  `@_exported import` in `configure.swift`. If this file stops compiling, the
//  re-export assumption behind "no call-site churn" has broken and every file
//  touching a catalog needs its own import.
//

import Foundation
import Logging

public enum ContentBootstrap {

    /// Directory holding `manifest.json` and the catalog files. Overridable so
    /// a designer can point a running bot at a scratch bundle without touching
    /// the checkout.
    public static var contentDirectory: String {
        ProcessInfo.processInfo.environment["ROI_CONTENT_PATH"] ?? "\(projectPath)/content/data"
    }

    public static var localizationDirectory: String {
        "\(projectPath)/Localizations"
    }

    /// Parse → validate → build → install. `install` is infallible and last, so
    /// any failure leaves the previous snapshot untouched; at boot there is no
    /// previous snapshot and the error propagates out of `configure`, which
    /// `entrypoint.swift` rethrows from `@main` to exit non-zero.
    @discardableResult
    public static func load(logger: Logger) throws -> GameContent {
        let root = URL(fileURLWithPath: contentDirectory)
        do {
            let bundle = try ContentLoader.load(from: root)
            let locales = try? LocaleIndex(rootPath: localizationDirectory)
            let report = ContentValidator.validate(bundle, localizations: locales)

            for issue in report.errors { logger.critical("CONTENT \(issue)") }
            for issue in report.warnings { logger.warning("CONTENT \(issue)") }
            guard !report.hasErrors else {
                throw ContentError.validationFailed(errorCount: report.errors.count)
            }

            // Build both snapshots before installing either: `DomainContent`
            // can still throw on a value the domain enums cannot represent, and
            // a half-installed state would be worse than no install at all.
            let content = GameContent(bundle)
            let domain = try DomainContent(content)
            GameData.install(content)
            Catalogs.install(domain)
            logger.info("Content loaded: \(bundle.summaryLine)")
            return content
        } catch {
            logger.critical("Failed to load game content from \(contentDirectory): \(error)")
            throw error
        }
    }

    /// Schema version this binary speaks. Surfaced for `/content` and for the
    /// startup banner.
    public static var schemaVersion: Int { ContentSchema.current }
}
