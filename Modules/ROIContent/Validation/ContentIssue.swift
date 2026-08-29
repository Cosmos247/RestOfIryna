//
//  ContentIssue.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 29.08.2026.
//
//  One finding from `ContentValidator`. Shaped so the same value renders
//  usefully in a boot log, in a CLI run, and inside a Telegram `/reload` reply.
//

import Foundation

public struct ContentIssue: Sendable, CustomStringConvertible {
    public enum Severity: String, Sendable {
        case error
        case warning
    }

    public let severity: Severity
    /// Source file, e.g. "items.json".
    public let file: String
    /// Location inside the file, e.g. "items[17].gearStats".
    public let path: String
    /// The offending record's id, when there is one.
    public let id: String?
    /// Stable machine-readable rule name, e.g. "reference.item.unknown".
    public let rule: String
    public let message: String

    public init(
        severity: Severity,
        file: String,
        path: String,
        id: String? = nil,
        rule: String,
        message: String
    ) {
        self.severity = severity
        self.file = file
        self.path = path
        self.id = id
        self.rule = rule
        self.message = message
    }

    public var description: String {
        let subject = id.map { " (\($0))" } ?? ""
        return "[\(severity.rawValue)] \(file) \(path)\(subject) \(rule): \(message)"
    }
}

public struct ContentReport: Sendable {
    public let issues: [ContentIssue]

    public init(issues: [ContentIssue]) { self.issues = issues }

    public var errors: [ContentIssue] { issues.filter { $0.severity == .error } }
    public var warnings: [ContentIssue] { issues.filter { $0.severity == .warning } }
    public var hasErrors: Bool { issues.contains { $0.severity == .error } }

}
