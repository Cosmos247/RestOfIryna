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
    /// v8 (Phase 8C): every Super stance's five stat lifts become MULTIPLIERS of
    /// the character's own stat — `attackBonus` and friends are gone. A v6/v7
    /// bundle's `+15 critBonus` would decode into a field that no longer exists,
    /// and silently leaving the multiplier at 1.0 would delete the technique.
    /// Monster silver went with it: `enemies.silverReward` and
    /// `archetypes.silverMultiplier` are no longer read.
    /// v9 (Phase 8D): the last two flat rating bonuses become multipliers —
    /// `specialDefense.shadowVeilDodgeBonus` → `shadowVeilDodgeMultiplier`,
    /// `defend.archerDodgeBonus` → `archerDodgeMultiplier` — and every
    /// archetype row gains a required `minLevel`. A v8 bundle carries `+50`
    /// where a multiplier is now read: decoded as one it would be a ×50 dodge,
    /// so the handshake has to refuse rather than reinterpret.
    public static let current: Int = 9
}
