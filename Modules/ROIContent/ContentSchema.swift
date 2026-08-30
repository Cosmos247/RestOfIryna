//
//  ContentSchema.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 29.08.2026.
//
//  Version handshake between the compiled binary and the on-disk content
//  bundle. `manifest.json` carries a `schemaVersion`; the loader refuses to
//  boot when it disagrees with `ContentSchema.current`. This is what catches
//  "deployed a new binary, forgot to pull content" (and the reverse).
//
//  Bump `current` whenever a DTO gains a required field or changes meaning.
//  Adding an optional field with a default is backwards-compatible and does
//  NOT need a bump.
//

import Foundation

public enum ContentSchema {
    /// Schema version this binary understands.
    /// v2 (Phase 4b): `manifest.timeScale` and `plots.testMode` are gone,
    /// replaced by `tuning/time.json` → `scale`. A binary reading a v1 bundle
    /// would find no scale at all and run every gate at release pacing, so the
    /// handshake has to refuse rather than default.
    public static let current: Int = 2
}
