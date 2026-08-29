//
//  main.swift
//  roi-content
//
//  Created by Dmytro Ihnatyuhin on 29.08.2026.
//
//  Content pipeline CLI. Runs the same `ContentValidator` the bot runs at boot,
//  so a check can never be enforced in one place and skipped in the other.
//
//    swift run roi-content validate [--content DIR] [--locales DIR] [--strict]
//    swift run roi-content simulate --runs N --seed S        (Phase 8)
//
//  Exits 0 on success and 1 on failure so it drops into a pre-commit hook or CI
//  unchanged. Argument parsing is hand-rolled — adding swift-argument-parser
//  would pull a dependency into a target whose whole point is being cheap.
//

import Foundation
import ROIContent
import ROISim

private func value(for flag: String, in args: [String]) -> String? {
    guard let index = args.firstIndex(of: flag), index + 1 < args.count else { return nil }
    return args[index + 1]
}

private func projectRoot() -> String {
    ProcessInfo.processInfo.environment["ROI_PROJECT_PATH"] ?? FileManager.default.currentDirectoryPath
}

private func usage() -> Never {
    print("""
    usage: roi-content <command> [options]

    commands:
      validate    parse and validate the content bundle
      simulate    run the balance simulator (Phase 8)

    options:
      --content DIR   content data directory (default: <project>/content/data)
      --locales DIR   localization directory (default: <project>/Localizations)
      --strict        promote every warning to an error
    """)
    exit(2)
}

let args = Array(CommandLine.arguments.dropFirst())
guard let command = args.first else { usage() }

let root = projectRoot()
let contentDir = value(for: "--content", in: args) ?? "\(root)/content/data"
let localeDir  = value(for: "--locales", in: args) ?? "\(root)/Localizations"
let strict     = args.contains("--strict")

switch command {
case "validate":
    do {
        let bundle = try ContentLoader.load(from: URL(fileURLWithPath: contentDir))
        let locales = try? LocaleIndex(rootPath: localeDir)
        if locales == nil {
            print("⚠️  localization directory not readable at \(localeDir) — skipping locale rules")
        }
        let report = ContentValidator.validate(bundle, localizations: locales, strict: strict)

        print(bundle.summaryLine)
        for issue in report.issues { print(issue) }

        if report.hasErrors {
            print("❌ \(report.errors.count) error(s), \(report.warnings.count) warning(s)")
            exit(1)
        }
        print("✅ valid — \(report.warnings.count) warning(s)")
    } catch {
        print("❌ \(error)")
        exit(1)
    }

case "simulate":
    print("simulate is not wired until Phase 8 — \(ROISim.version)")
    exit(2)

default:
    usage()
}
