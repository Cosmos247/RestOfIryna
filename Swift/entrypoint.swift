//
//  entrypoint.swift
//  RestOfIryna
//
//  Created by Maxim Lanskoy on 13.06.2025.
//  Maintained by Dmytro Ihnatyuhin from 17.04.2026.
//

import Foundation
import Hummingbird
import Logging
import NIOCore
import NIOPosix

// MARK: - Setting up Hummingbird Application.
@main
enum Entrypoint {
    static func main() async throws {
        // Setup logging
        LoggingSystem.bootstrap { label in
            var handler = StreamLogHandler.standardOutput(label: label)
            handler.logLevel = .info
            return handler
        }

        let logger = Logger(label: "RestOfIryna")

        // MARK: - Content export (migration tool, Phase 1)
        // Handled before `configure` so it never opens Postgres, reads the bot
        // token, or starts long-polling. Removed once the Swift catalog arrays
        // are gone (end of Phase 3).
        if let flag = CommandLine.arguments.firstIndex(of: "--export-content") {
            // Only treat the next argument as a path when it isn't another
            // flag, so `--export-content --something` doesn't export into a
            // directory literally named "--something".
            let next = CommandLine.arguments.count > flag + 1
                ? CommandLine.arguments[flag + 1] : nil
            let explicit = (next?.hasPrefix("-") == false) ? next : nil
            let outputDirectory = explicit ?? "\(projectPath)/content/data"
            do {
                try ContentExporter.run(outputDirectory: outputDirectory)
            } catch {
                print("❌ export failed: \(error)")
                fflush(stdout)
                exit(1)
            }
            return
        }

        // MARK: - Content digest (migration verification layer 3)
        // Same digest computed before and after the catalogs flip from Swift
        // arrays to JSON. Must match bit-for-bit.
        if CommandLine.arguments.contains("--content-digest") {
            // Post-migration the catalogs read from JSON, so the bundle has to
            // be installed first. Pre-migration this was a no-op for the digest
            // (the Swift arrays ignored it) — which is exactly why running it
            // on both sides is a fair comparison.
            do {
                try ContentBootstrap.load(logger: logger)
            } catch {
                print("❌ could not load content: \(error)")
                fflush(stdout)
                exit(1)
            }
            ContentDigest.run()
            return
        }

        do {
            try await configure(logger: logger)
        } catch {
            logger.error("Failed to start application: \(error)")
            throw error
        }
    }
}
