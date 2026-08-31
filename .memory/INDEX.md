# ROI Project Memory Index

Session-persistent knowledge base. Each entry links to a detailed file.

## Architecture & Stack
- [Architecture Overview](architecture.md) — Router-controller state machine, app lifecycle, dispatcher chain
- [Tech Stack](tech-stack.md) — Swift 6.2, Hummingbird 2, Fluent, swift-telegram-sdk, Lingo
- [File Map](file-map.md) — Source tree with purpose annotations per file (canonical; covers `Modules/` including the `ROISim` balance maths + simulator, the tuning DTOs, the Phase 5–7 migrations and the test suite)
- [Content Pipeline](content-pipeline.md) — Data-driven catalogs and tuning tables: JSON layout, loader/validator, snapshots, the item stat budget, the bestiary archetype table, hot reload, and the verification discipline (four digest halves + four live checks + the balance simulator)

## Content specifications (in the repo, not here)
- [`content/spec/`](../content/spec/) — the Phase 9 approval gate: the content list is signed off before it reaches JSON. **`spec-progression.md`** (the skeleton: XP ladder, gates, and the level↔km rule), **`spec-bestiary.md`** (the roster, zones, loot) **`spec-items.md`** (a FRAME, not a list — no new items in the rebalance; the gear ladder; the printed 40%-of-curve wardrobe gap that amended the bestiary spec's §9) **`spec-sets.md`** (a set bonus multiplies its OWN members, not the whole kit; set strength is a ladder whose top rung is the 25% ceiling, and the Forester set is its weakest rung) and **`spec-economy.md`** (the opening is Vigor-bankrupt — 79 boars and 662 Vigor of deficit before the first plot, which amended the progression spec; silver has almost no sink; `lootMultiplier` multiplies quantity) are **all approved — Phase 9 is closed**. Every number in them is emitted by `roi-content spec`, never typed
- [`content/lore.md`](../content/lore.md) — the world: families, the three wilderness zones, visual reference. `content/bestiary.md` is a pre-rebalance reference doc, marked SUPERSEDED

## Game Design
- [Game Core](game-core.md) — GDD summary: classes, vigor, exploration, combat, estates
- [Implemented vs Planned](status.md) — What exists now vs what GDD describes, plus the rebalance phase table
- [Rebalance](rebalance.md) — **Active work.** Audit findings, locked decisions, the calibrated math model, the phase tracker (3–8 done, 9 in flight) and the per-phase lessons

## Patterns & Conventions
- [Controller Pattern](controller-pattern.md) — How to build/register controllers, routing, keyboards
- [Session & Auth](session-auth.md) — User model, session cache, authorization flow
- [Localization](localization.md) — Lingo setup, JSON structure, interpolation, adding locales

## Session Log
- [Session History](sessions.md) — Chronological log of what was done per session
