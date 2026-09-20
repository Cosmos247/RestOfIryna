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
  fixing what playing the deployed build reveals — plus the occasional small feature the
  play surfaces a need for. The Pi runs **`536fbf6`** since **2026-09-19 14:21** (schema v12,
  digest `records 6588329ab2bdbc70`, matched byte for byte before the restart was ordered);
  that deploy cleared ten commits at once. **One commit is undeployed and unpushed** —
  `328bf88`, the quest carry-over, which carries the **first data migration since
  `ResetDeepestKm`**, so its restart writes to the database and the `quest_progress` TABLE is
  what to verify afterwards. The next action is a human opening the screens: a backlog spanning
  three deploys and never walked.
- **State of the deployment: `Prompt.md`.** That file is the session primer and the only
  place the current commit, digest baseline and next action are kept in sync. **The
  surfaces still unwalked moved to `TODO.md` on 2026-09-20** — "Walk list — shipped
  surfaces nobody has opened", with "Open, decided but not done" beside it; a QA
  checklist read at the start of every session is not a primer.
- **What each commit did and why: [Session History](sessions.md)** — its **Commit index**
  at the top is the single changelog (hash → what it did, 2026-09-09 onward), moved there
  from `Prompt.md` on 2026-09-15 because six hashes lived nowhere else. Dated narrative
  entries follow it: the 09-07 pre-push pass, the 09-08 Pi audit and invite-only access,
  the 09-09 → 09-17 polish entries, and the 09-18 kitchen rebuild.
- **What each phase decided: [Rebalance](rebalance.md).**
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
already carries all 62 at one line each, so a selection copied into this file is the
third-copy pattern `feedback-docs-keep-the-rule` was written about: on 2026-09-20 it had
grown back to 24 entries, every one of them already in `MEMORY.md` and one of them listed
twice.

## Session Log
- [Session History](sessions.md) — Chronological log of what was done per session
