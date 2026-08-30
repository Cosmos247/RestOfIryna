//
//  ManifestDTO.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 29.08.2026.
//
//  `content/data/manifest.json` — the handshake file. Read first, checked
//  against `ContentSchema.current`, and refused on mismatch before a single
//  catalog is parsed.
//

import Foundation

public struct ManifestDTO: Codable, Sendable {
    public let schemaVersion: Int
    /// Free-form label for the content revision (e.g. "2026-08-29-rebalance").
    public let contentVersion: String?
    public let generatedAt: String?
    // `timeScale` used to live here. Phase 4b moved it to `tuning/time.json`
    // → `scale`, alongside the five durations it multiplies: a knob two files
    // away from everything it governs is a knob that gets changed alone.

    public init(schemaVersion: Int, contentVersion: String? = nil, generatedAt: String? = nil) {
        self.schemaVersion = schemaVersion
        self.contentVersion = contentVersion
        self.generatedAt = generatedAt
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, contentVersion, generatedAt
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion  = try c.decode(Int.self, forKey: .schemaVersion)
        contentVersion = try c.decodeIfPresent(String.self, forKey: .contentVersion)
        generatedAt    = try c.decodeIfPresent(String.self, forKey: .generatedAt)
    }
}
