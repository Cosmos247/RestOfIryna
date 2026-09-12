# ROI Project Memory Index

Session-persistent knowledge base. Each entry links to a detailed file. **This is an
index — one line per entry.** Narrative belongs in `sessions.md` (what happened when) or
`rebalance.md` (what was decided and why); rules belong in `CLAUDE.md`.

## Architecture & Stack
- [Architecture Overview](architecture.md) — Router-controller state machine, app lifecycle, dispatcher chain, per-user serialization
- [Tech Stack](tech-stack.md) — Swift 6.2, Hummingbird 2, Fluent, swift-telegram-sdk, Lingo
- [File Map](file-map.md) — Source tree with purpose annotations per file (canonical; covers `Modules/` and the test suite)
- [Content Pipeline](content-pipeline.md) — Data-driven catalogs and tuning tables: JSON layout, loader/validator, snapshots, the item stat budget, the archetype table, hot reload, and the verification discipline

## Patterns & Conventions
- [Controller Pattern](controller-pattern.md) — How to build/register controllers, routing, keyboards, refusals
- [Session & Auth](session-auth.md) — User model, session cache, the invite-only access gate, background writers
- [Localization](localization.md) — Lingo setup, JSON structure, «ви», player gender, item gender, the UA glossary

## Game Design
- [Game Core](game-core.md) — GDD summary: classes, vigor, exploration, combat, estates, rest
- [Implemented vs Planned](status.md) — What exists now vs what the GDD describes, plus the rebalance phase table
- [Rebalance](rebalance.md) — Audit findings, locked decisions, the calibrated math model, the phase tracker and the per-phase lessons

## Content specifications (in the repo, not here)
- [`content/spec/`](../content/spec/) — **all five approved; Phase 9 closed 2026-09-01.** Every number is printed by `roi-content spec` and quoted inside `<!-- generated -->` markers, so drift is mechanically detectable
  - `spec-progression.md` — the XP ladder, unlock gates, the level↔km rule
  - `spec-bestiary.md` — the roster, zones and loot
  - `spec-items.md` — a FRAME, not a list: the gear ladder and the 40%-of-curve wardrobe gap
  - `spec-sets.md` — a set bonus multiplies its OWN members; set strength is a ladder topped by the 25% ceiling
  - `spec-economy.md` — silver has almost no sink; §2 amended 2026-09-02 by its own measurement
- [`content/lore.md`](../content/lore.md) — the world: families, the three wilderness zones, visual reference. `content/bestiary.md` is pre-rebalance reference, marked SUPERSEDED

## Where the work stands

- **Phases 3–11 done; Phase 11 closed as CODE.** What follows is **live-play polish** —
  fixing what playing the deployed build reveals. Eleven commits, 2026-09-09 → 11.
- **State of the deployment, and the surfaces still unwalked: `Prompt.md`.** That file is
  the session primer and the only place the current commit, digest baseline and next
  action are kept in sync.
- **What each commit did and why: [Session History](sessions.md)** — the 09-07 pre-push
  pass, the 09-08 Pi audit and invite-only access, and the 09-09 → 09-11 polish entries.
- **What each phase decided: [Rebalance](rebalance.md).**
- **The rules all of it produced: `CLAUDE.md`.**

## Session Log
- [Session History](sessions.md) — Chronological log of what was done per session
