//
//  ContentError.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 29.08.2026.
//
//  Failure modes of the content pipeline. Every case renders to a message a
//  balance designer can act on without reading Swift — a raw `DecodingError`
//  description is useless to them, so `ContentLoader` translates coding paths
//  into "file · index · id · expected" before throwing.
//

import Foundation

public enum ContentError: Error, CustomStringConvertible, Sendable {
    /// A required file was absent from the content directory.
    case missingFile(String)
    /// JSON in `file` failed to decode. `detail` is already human-rendered.
    case decodeFailed(file: String, detail: String)
    /// `manifest.schemaVersion` disagrees with `ContentSchema.current`.
    case schemaMismatch(found: Int, expected: Int)
    /// Validation produced at least one error-severity issue.
    case validationFailed(errorCount: Int)

    public var description: String {
        switch self {
        case .missingFile(let file):
            return "missing content file: \(file)"
        case .decodeFailed(let file, let detail):
            return "\(file): \(detail)"
        case .schemaMismatch(let found, let expected):
            return "content schemaVersion \(found) does not match binary schemaVersion \(expected) — pull matching content"
        case .validationFailed(let count):
            return "content validation failed with \(count) error(s)"
        }
    }
}
