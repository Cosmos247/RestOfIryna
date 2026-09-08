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
                // `fflush(nil)` flushes every open output stream, which is what we
                // actually want before `exit`. Naming `stdout` instead does not
                // build on Linux: Glibc imports it as `extern FILE *stdout`, a
                // mutable global, and Swift 6 strict concurrency refuses the
                // reference. Darwin imports the same symbol as a computed
                // property, so the mistake is invisible on the dev Mac and only
                // surfaces on the Pi.
                fflush(nil)
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
