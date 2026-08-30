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
    /// v3 (Phase 5A): `enemies.json` gains a required `archetypes` table, and
    /// every enemy a required `level` and `archetype`. A v2 bundle has neither,
    /// and defaulting them would misprice every encounter silently.
    /// v4 (Phase 5B): `progression.statGrowth` changes shape entirely — flat
    /// per-level bonuses on named levels become proportional rates — and gains
    /// `vigorPool`. A v3 bundle's `statGrowth` would decode as garbage, so the
    /// handshake has to refuse rather than reinterpret.
    /// v5 (Phase 5C): `combat.json` gains `curves` and `levelDiff`, and
    /// `hitChance` changes meaning (base 70 → 85, floor 10 → 40) because damage
    /// is absorbed rather than subtracted. A v4 bundle would decode into the
    /// new formula and produce silently wrong fights.
    /// v6 (Phase 5D): `exploration.json` gains a required `passive` block and
    /// `combat.json` the rebuilt technique effects.
    /// v7 (Phase 6): gear stats gain `hp`, items gain `itemLevel` / `rarity` /
    /// `setId`, and `master.enchantPerLevelPoints` becomes a budget FRACTION.
    /// A v6 bundle's flat point table would decode as nothing at all.
    public static let current: Int = 7
}
