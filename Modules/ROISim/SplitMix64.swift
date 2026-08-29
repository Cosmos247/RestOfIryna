//
//  SplitMix64.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 29.08.2026.
//
//  Deterministic, seedable RNG for the balance simulator and for the
//  before/after equivalence check in the content migration.
//
//  Why it matters: `ExplorationService` and `CombatService` currently call the
//  global `Int.random(in:)` / `randomElement()`, so no run is reproducible. The
//  migration proof (Phase 1–2) requires replaying 100k exploration steps
//  against the compiled catalogs and again against the JSON-backed ones and
//  getting a bit-identical outcome stream — impossible without a seeded
//  generator threaded through those roll functions.
//

import Foundation

public struct SplitMix64: RandomNumberGenerator, Sendable {
    private var state: UInt64

    public init(seed: UInt64) {
        self.state = seed
    }

    public mutating func next() -> UInt64 {
        state = state &+ 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

/// Rolling hash over a stream of outcomes, so two simulation runs can be
/// compared with one comparison instead of a diff over millions of lines.
public struct OutcomeDigest: Sendable {
    private var hash: UInt64 = 0xcbf29ce484222325
    private static let prime: UInt64 = 0x100000001b3

    public init() {}

    public mutating func combine(_ value: Int) {
        var v = UInt64(bitPattern: Int64(value))
        for _ in 0..<8 {
            hash ^= (v & 0xFF)
            hash = hash &* Self.prime
            v >>= 8
        }
    }

    public mutating func combine(_ text: String) {
        for byte in text.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* Self.prime
        }
    }

    public var hexDigest: String { String(format: "%016llx", hash) }
}
