//
//  entrypoint.swift
//  RestOfIryna
//
//  Created by Maxim Lanskoy on 13.06.2025.
//  Maintained by Dmytro Ihnatyuhin from 17.04.2026.
//

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

        do {
            try await configure(logger: logger)
        } catch {
            logger.error("Failed to start application: \(error)")
            throw error
        }
    }
}
