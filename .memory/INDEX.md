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
- [`content/spec/`](../content/spec/) — **five approved, Phase 9 closed 2026-09-01, plus `king.md` (2026-09-21).** Every number is printed by `roi-content spec` and quoted inside `<!-- generated -->` markers, so drift is mechanically detectable
  - `spec-progression.md` — the XP ladder, unlock gates, the level↔km rule (superseded 2026-10-02 by `spec-bestiary.md` §10)
  - `spec-bestiary.md` — the roster, zones and loot; §10 (2026-10-02) is tier 2: 14 creatures numbered by depth, the XP level-gap penalty off; §11 (2026-10-03) is creature strength by estate tier
  - `spec-items.md` — a FRAME, not a list: the gear ladder and the 40%-of-curve wardrobe gap
  - `spec-sets.md` — a set bonus multiplies its OWN members; set strength is a ladder topped by the 25% ceiling
  - `spec-economy.md` — silver has almost no sink; §2 amended 2026-09-02 by its own measurement
  - `king.md` — the King's decree chain: 39 decrees, levels 1–25, one open at a time
- [`content/lore.md`](../content/lore.md) — the world: families, the three wilderness zones, visual reference. `content/bestiary.md` is pre-rebalance reference, marked SUPERSEDED

## Where the work stands

- **Phases 3–11 done; Phase 11 closed as CODE.** What follows is **live-play polish** —
  fixing what playing the deployed build reveals — plus the occasional small feature the
  play surfaces a need for. The Pi runs **`8ae6772`** since **2026-09-28 22:11** (schema
  **v14**, content hash `490a2d4b`, digest `tuning fe05ceaa38e03c6b` · `king 5dbddfd689f3cede`,
  matched byte for byte before the restart was ordered). **Tier 2 of the bestiary (`f03d502`, 2026-10-02)
  is committed and NOT deployed**: 14 creatures, XP penalty off, content hash `cd9d73bf`
  (`spec-bestiary.md` §10). **Seven game changes of 2026-09-27/28 went live with that
  restart** (schema **v14**, five migrations, the tables checked after): the stray-number hint, the workshop's
  «Розібрати» with gear lists that name rows, combat lines with a death screen that shows the
  last round, the Training Ground as a house room, the technique rework with its fight log,
  the King's chain asking for the estate before the ground, and a workshop that no longer
  makes armour.
- **Next actions.**
  - The owner deploys tier 2 and the estate scaling, both committed and NOT deployed. The
    scaling (`4be2758`, 2026-10-03, `spec-bestiary.md` §11) makes creature HP and ATK +10% per estate
    tier, strength only, with T6 left as it is, no player notice, and
    `fight_log.estate_level`. It brings content schema v15 and one migration. The testers
    should hear about it first, because the game announces nothing.
  - Then the first `fight_log` rows, and a human walking the screens. The estate and tier-2
    blocks head `TODO.md`'s walk list and wait for their deploy.
- **State of the deployment: `Prompt.md`.** That file is the session primer and the only
  place the current commit, digest baseline and next action are kept in sync. **The
  surfaces still unwalked moved to `TODO.md` on 2026-09-20** — "Walk list — shipped
  surfaces nobody has opened", with "Open, decided but not done" beside it; a QA
  checklist read at the start of every session is not a primer.
- **What each commit did and why: [Session History](sessions.md)** — its **Commit index**
  at the top is the single changelog (hash → what it did, 2026-09-09 onward), moved there
  from `Prompt.md` on 2026-09-15 because six hashes lived nowhere else. Dated narrative
  entries follow it: the 09-07 pre-push pass, the 09-08 Pi audit and invite-only access,
  the 09-09 → 09-17 polish entries, the 09-18 kitchen rebuild, and on through the 09-27/28
  entries, the `## Deploy — 2026-09-28` restart, the 10-02 tier-2 entry and the 10-03 sync pass.
- **What each phase decided: [Rebalance](rebalance.md).** Since 2026-10-02 it also holds the
  tier-2 research: the expedition model that can see depth (which `simulate`'s pace cannot), every
  figure it produced, the reconstructed 09-14 stat method, and how to rebuild the harness.
- **The rules all of it produced: `CLAUDE.md`.** It states the rule and the trap; the
  story behind each one lives here or in the auto-memory bank. See the auto-memory
  `feedback-docs-keep-the-rule` for the split and for why every "never do X" guard stays
  in the repo doc rather than moving into a memory file.

## The auto-memory bank (outside the repo)

Lives in `~/.claude/projects/-Users-cosmos-RestOfIryna/memory/`, indexed by its own
`MEMORY.md`, and is **not** a second copy of this one. The split in force: **the repo doc
keeps the RULE, the auto-memory keeps the REASON** — `CLAUDE.md` states the imperative and
the trap, the memory holds the measurement that produced it. See `feedback-docs-keep-the-rule`
for why every "never do X" guard stays in the repo rather than moving there.

Each `CLAUDE.md` rule names the auto-memory behind it inline, so they are reached by
following the rule you are about to break — which is the only index that is needed here.
**Do not list them in this file.** `MEMORY.md` loads automatically every session and
already carries all 78 at one line each, so a selection copied into this file is the
third-copy pattern `feedback-docs-keep-the-rule` was written about: on 2026-09-20 it had
grown back to 24 entries, every one of them already in `MEMORY.md` and one of them listed
twice.

## Session Log
- [Session History](sessions.md) — Chronological log of what was done per session
