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
//    swift run roi-content simulate [--runs N] [--seed S] [--levels 1,5,…] [--strict]
//    swift run roi-content spec <progression|gates|bestiary|items> [--levels 1,5,…]
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
      simulate    roll the balance sweep and report TTK, tails and pace
      spec        print a content-specification table, straight off the curves

    options:
      --content DIR   content data directory (default: <project>/content/data)
      --locales DIR   localization directory (default: <project>/Localizations)
      --strict        validate: promote every warning to an error
                      simulate: exit 1 when a band is broken

    simulate options:
      --runs N        fights per cell (default 8000)
      --seed S        RNG seed — the same seed always gives the same report
      --levels L,L,…  levels to sweep (default 1,5,10,20,30,40)

    spec <table>      progression · gates · bestiary · items
      --levels L,L,…  levels the table covers (default 1…25, the authored band)

      Phase 9 signs the content list off before it reaches JSON, and a spec full
      of hand-typed numbers is a fourth copy of the same curves. Every table here
      is printed by the code that owns the maths, so the document and the
      generator cannot disagree.
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
    do {
        let bundle = try ContentLoader.load(from: URL(fileURLWithPath: contentDir))
        // The simulator reads a bundle the validator has passed, never a raw
        // one: measuring an inverted variance range or a class with no budget
        // profile produces numbers, and numbers from a broken bundle are worse
        // than no numbers at all.
        let report = ContentValidator.validate(bundle, localizations: nil, strict: false)
        if report.hasErrors {
            print("❌ the bundle does not validate — fix it before measuring it")
            for issue in report.errors { print(issue) }
            exit(1)
        }
        let content = GameContent(bundle)
        // 8000, not the 2000 this shipped with. The level-invariance band is a
        // ±15% ratio of two MEANS, and at 2000 fights the sampling error on a
        // cell is wide enough to cross it on its own: the mage-vs-skirmisher
        // row reads ×1.16 at 2000 and ×1.13 at 8000 from the same seed, so
        // `--strict` failed the build on noise. The whole sweep costs 2.6s at
        // 8000 against 0.7s at 2000, which is no reason at all to keep a gate
        // that cries wolf.
        let runs = value(for: "--runs", in: args).flatMap(Int.init) ?? 8000
        let seed = value(for: "--seed", in: args).flatMap(UInt64.init) ?? 20260830
        let levels = value(for: "--levels", in: args)
            .map { $0.split(separator: ",").compactMap { Int($0) } }
            .flatMap { $0.isEmpty ? nil : $0 } ?? BalanceSimulator.defaultLevels

        guard let run = BalanceSimulator.run(content: content, levels: levels,
                                             runs: runs, seed: seed) else {
            print("❌ the bundle is missing the tuning or budget tables the sweep needs")
            exit(1)
        }
        let roster = BalanceFormatter.checkRoster(content: content, runs: runs, seed: seed)
        let (text, findings) = BalanceFormatter.render(run: run, roster: roster, content: content)
        print(text)

        let errors = findings.filter { $0.severity == .error }
        let warnings = findings.filter { $0.severity == .warning }
        if findings.isEmpty {
            print("✅ every band holds")
        } else {
            print("── findings ──────────────────────────────────────────────────────────────────")
            for finding in findings {
                let mark = finding.severity == .error ? "❌" : "⚠️ "
                print("  \(mark) [\(finding.rule)] \(finding.message)")
            }
            print("")
            print("\(errors.count) broken band(s), \(warnings.count) warning(s)")
        }
        // Bands are advisory by default so the calibration loop — edit a curve,
        // re-simulate — is not a fight with the exit code. `--strict` is what
        // a pre-commit hook or CI runs.
        if strict && !errors.isEmpty { exit(1) }
    } catch {
        print("❌ \(error)")
        exit(1)
    }

case "spec":
    do {
        let bundle = try ContentLoader.load(from: URL(fileURLWithPath: contentDir))
        // Same posture as `simulate`: a spec is quoted in a document people
        // sign off on, so it is read off a bundle the validator has passed.
        let report = ContentValidator.validate(bundle)
        if report.hasErrors {
            print("❌ the bundle does not validate — fix it before quoting it")
            for issue in report.errors { print(issue) }
            exit(1)
        }
        let content = GameContent(bundle)
        let levels = value(for: "--levels", in: args)
            .map { $0.split(separator: ",").compactMap { Int($0) } }
            // The authored band from `spec-progression.md`. Narrow it with
            // `--levels` when a table only needs a few rows.
            .flatMap { $0.isEmpty ? nil : $0 } ?? Array(1...25)

        // The positional table name, skipping flags AND their values —
        // `spec --levels 1,5 bestiary` used to read "1,5" as the table, because
        // a flag's value does not start with a dash either.
        var positional: String?
        var index = 1
        while index < args.count {
            let token = args[index]
            if token.hasPrefix("--") { index += 2; continue }   // flag + its value
            positional = token
            break
        }
        switch positional {
        case "progression": print(SpecTables.progression(content: content))
        case "gates":       print(SpecTables.gates(content: content))
        case "bestiary":    print(SpecTables.bestiary(content: content, levels: levels))
        case "items":       print(SpecTables.items(content: content, levels: levels))
        default:
            print("spec: pick a table — progression · gates · bestiary · items")
            exit(2)
        }
    } catch {
        print("❌ \(error)")
        exit(1)
    }

default:
    usage()
}
