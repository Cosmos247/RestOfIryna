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
  play surfaces a need for. The Pi took `201f093` on **2026-09-16 00:32** (schema v12, four
  migrations applied and verified against the tables); **three commits sit on top of it,
  undeployed** — two retuned ladders, the crafting repair, and a Profile key on the walk
  keyboard, none of which `/reload` can carry.
  Besides that restart, what is waiting is a human opening the screens.
- **State of the deployment, and the surfaces still unwalked: `Prompt.md`.** That file is
  the session primer and the only place the current commit, digest baseline and next
  action are kept in sync.
- **What each commit did and why: [Session History](sessions.md)** — its **Commit index**
  at the top is the single changelog (hash → what it did, 2026-09-09 onward), moved there
  from `Prompt.md` on 2026-09-15 because six hashes lived nowhere else. Dated narrative
  entries follow it: the 09-07 pre-push pass, the 09-08 Pi audit and invite-only access,
  and the 09-09 → 09-15 polish entries.
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
following the rule you are about to break. The ones a fresh session most often wants:

- `project-damage-sources-named-separately` — a step can cost HP twice; each source prints
  its own line, and the tick rides on `StepResult` so no branch can drop it
- `project-flee-has-a-ceiling` — a fight may refuse an escape at most `flee.maxFailures`
  times; the roll and the ceiling are one rule, behind `CombatService.fleeSucceeds`
- `project-leaderboards-will-go-seasonal` — all-time is v1's period, not the only one; a
  season is a second reading, never a reset of a lifetime counter
- `project-pi-deploy-swiftenv` + `linux-build-gap` — the deploy recipe and its two traps
- `feedback-ask-the-machine-not-the-record` — a deploy is the one fact nothing writes down
  by itself; read HEAD, pm2 uptime, schema and digest off the Pi before claiming what is live
- `project-gear-state-travels-with-the-unit` — tier / wear / enchant are per-instance; a
  transfer that re-creates a row hands back a factory-fresh item
- `project-depth-is-banked-on-arrival` — `deepestKm` counts only what was walked back from,
  which is also why the forest has no free exit any more
- `project-plot-streams-and-dead-lore` — a ceiling only reachable by idling is not a balance
  knob, and a locale key the validator requires is not a key anything renders
- `feedback-audit-what-else-reads-it` — grep every reader before changing a displayed
  concept; the extra readers are where the real defects sit
- `feedback-docs-in-english` — converse in Ukrainian, persist in English; Cyrillic in a
  doc should only ever be quoted game copy

## Session Log
- [Session History](sessions.md) — Chronological log of what was done per session
