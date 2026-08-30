//
//  ContentBootstrap.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 29.08.2026.
//
//  Loading seam for the data-driven content bundle.
//
//  Called from `configure(logger:)` immediately after `Dotenv.configure` and
//  BEFORE the database block. That ordering is load-bearing: all 12 catalogs
//  are façades over the snapshot this installs, and the dev-seed block plus
//  `GearConditionService.backfillWeaponDurability` — both later in the same
//  function — already call `ItemCatalog.find`. Any catalog touch before this
//  line traps rather than returning stale data.
//
//  NOTE — this file deliberately does NOT `import ROIContent`. It resolves
//  `ContentSchema`, `ContentLoader`, `GameData` and friends through the
//  `@_exported import` in `configure.swift`. If this file stops compiling, the
//  re-export assumption behind "no call-site churn" has broken and every file
//  touching a catalog needs its own import.
//

import Fluent
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
    ///
    /// The boot path skips the live-reference check for one reason: content
    /// loads BEFORE the database block, because the dev seed later in the same
    /// function already calls `ItemCatalog.find`. `liveCheckAtBoot` runs the
    /// same check once the database is up, as a warning.
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

    // MARK: - Hot reload (Phase 7)

    /// Why a reload was refused. Every case leaves the running snapshot exactly
    /// as it was — the point of ordering `install` last.
    public enum ReloadFailure: Error, CustomStringConvertible {
        case parse(String)
        case validation([String])
        case liveReferences([LiveReferenceCheck.Dangling])
        case mapping(String)

        public var description: String {
            switch self {
            case .parse(let detail):
                return "could not read the bundle: \(detail)"
            case .validation(let messages):
                return "validation failed (\(messages.count)):\n" + messages.prefix(8).joined(separator: "\n")
            case .liveReferences(let dangling):
                return "\(dangling.count) live reference(s) would break:\n"
                    + dangling.prefix(8).map(\.description).joined(separator: "\n")
            case .mapping(let detail):
                return "the bundle validated but could not be mapped: \(detail)"
            }
        }
    }

    public struct ReloadOutcome: Sendable {
        public let summaryLine: String
        public let warnings: [String]
    }

    /// Swap the live content bundle without restarting.
    ///
    /// **parse → validate → live-check → build → install**, and the order is the
    /// whole design. Everything that can fail happens before anything is
    /// touched; `install` is a reference store that cannot fail and comes last.
    /// A reload that is refused at any step leaves the running game on exactly
    /// the snapshot it was already serving.
    ///
    /// What this does NOT reload: **Lingo**. `AppState.lingo` is a `let`
    /// captured by every controller, so new locale strings still need a
    /// restart. And timers already armed carry their deadline in the database
    /// (`endsAt`), so a changed duration never retroactively moves a trip or an
    /// expedition already in flight.
    public static func reload(on db: any Database, logger: Logger) async throws -> ReloadOutcome {
        let root = URL(fileURLWithPath: contentDirectory)

        let bundle: ContentBundle
        do {
            bundle = try ContentLoader.load(from: root)
        } catch {
            throw ReloadFailure.parse("\(error)")
        }

        let locales = try? LocaleIndex(rootPath: localizationDirectory)
        let report = ContentValidator.validate(bundle, localizations: locales)
        guard !report.hasErrors else {
            throw ReloadFailure.validation(report.errors.map { "\($0)" })
        }

        let live = try await LiveReferenceQuery.collect(on: db)
        let dangling = LiveReferenceCheck.dangling(in: bundle, live: live)
        guard dangling.isEmpty else {
            throw ReloadFailure.liveReferences(dangling)
        }

        let content = GameContent(bundle)
        let domain: DomainContent
        do {
            domain = try DomainContent(content)
        } catch {
            throw ReloadFailure.mapping("\(error)")
        }

        GameData.install(content)
        Catalogs.install(domain)
        logger.info("Content reloaded: \(bundle.summaryLine)")
        return ReloadOutcome(summaryLine: bundle.summaryLine,
                             warnings: report.warnings.map { "\($0)" })
    }

    /// Report live rows pointing at ids the freshly booted bundle does not
    /// carry. A warning rather than a refusal: by the time the database is
    /// reachable the snapshot is already installed and half the boot sequence
    /// has read from it, so there is nothing safe left to refuse.
    public static func liveCheckAtBoot(on db: any Database, logger: Logger) async {
        do {
            let root = URL(fileURLWithPath: contentDirectory)
            let bundle = try ContentLoader.load(from: root)
            let live = try await LiveReferenceQuery.collect(on: db)
        let dangling = LiveReferenceCheck.dangling(in: bundle, live: live)
            guard !dangling.isEmpty else { return }
            logger.warning("CONTENT \(dangling.count) live row(s) reference ids this bundle does not define:")
            for problem in dangling.prefix(10) { logger.warning("CONTENT   \(problem)") }
        } catch {
            logger.warning("CONTENT live-reference check could not run: \(error)")
        }
    }
}
