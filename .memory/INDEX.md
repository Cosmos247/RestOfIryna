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
- [Session & Auth](session-auth.md) — User model, session cache, the access gate (invite-only, or the open door since 2026-10-07), background writers
- [Localization](localization.md) — Lingo setup, JSON structure, «ви», player gender, item gender, the UA glossary

## Operations
- [Live ops — the public test](live-ops.md) — **since 2026-10-07**: the open door, crediting zlatnyks by hand in DBeaver (2026-10-11), telling a frozen poll loop from a dead network, the player-activity snapshot SQL and its reading traps, what the first evening showed, day two's starving play, day four's repair complaint with its wear SQL (2026-10-10), and a verified player FAQ with sources and ready replies

## Game Design
- [Game Core](game-core.md) — GDD summary: classes, vigor, exploration, combat, estates, rest
- [Implemented vs Planned](status.md) — What exists now vs what the GDD describes, plus the rebalance phase table
- [Rebalance](rebalance.md) — Audit findings, locked decisions, the calibrated math model, the phase tracker and the per-phase lessons
- [Class sets concept](class-sets-concept.md) — **PARKED 2026-10-05, nothing approved**: three class branches L10–40 (5 pieces with the off-hand, 75% growth, ×1.19 on the set's own members), per-piece stats, the fight impact (+65–71% survivability at L20, so it ships only with a bestiary re-solve), Master commissions sized to fit a bag, four unanswered forks, and the formulas to re-derive every number

## Content specifications (in the repo, not here)
- [`content/spec/`](../content/spec/) — **five approved, Phase 9 closed 2026-09-01, plus `king.md` (2026-09-21).** Every number is printed by `roi-content spec` and quoted inside `<!-- generated -->` markers, so drift is mechanically detectable
  - `spec-progression.md` — the XP ladder, unlock gates, the level↔km rule (superseded 2026-10-02 by `spec-bestiary.md` §10)
  - `spec-bestiary.md` — the roster, zones and loot; §10 (2026-10-02) is tier 2: 14 creatures numbered by depth, the XP level-gap penalty off; §11 (2026-10-03) is creature strength by estate tier
  - `spec-items.md` — a FRAME, not a list: the gear ladder and the 40%-of-curve wardrobe gap; §9 (2026-10-04) is the weapon ladder by player level and the Master's lesson; §10 (2026-10-05) is durability as the item's own, the Forester set at 50 with its prices ×5/3; §11 (2026-10-06) is the Master's enchant as the armour's ladder — the gear ladder of §4, built, and gated by its price where the weapon's is gated by level; §10.2 amended 2026-10-10: the repair halved
  - `spec-sets.md` — a set bonus multiplies its OWN members; set strength is a ladder topped by the 25% ceiling; §5's note (2026-10-05) points at the parked class-sets concept; §2's amendment and second table (2026-10-06): the members climb by the enchant now, so the Forester's flat bonus rots
  - `spec-economy.md` — silver has almost no sink; §2 amended 2026-09-02 by its own measurement; §4 amended 2026-10-10 (the repair halved on live data; the fortune teller joins the sinks table)
  - `king.md` — the King's decree chain: 39 decrees, levels 1–25, one open at a time
- [`content/lore.md`](../content/lore.md) — the world: families, the three wilderness zones, visual reference. `content/bestiary.md` is pre-rebalance reference, marked SUPERSEDED

## Where the work stands

- **State, next action, open threads: `Prompt.md`** — the only place the current commit, the
  digest baseline and the next action are kept. Open items and the unwalked surfaces: `TODO.md` →
  "Open, decided but not done" and "Walk list".
- **What each commit did: [Session History](sessions.md)** — the **Commit index** at its top is the
  single changelog (hash → what it did, 2026-09-09 onward), then a dated entry per session and a
  `## Deploy —` entry per restart; the superseded digest baselines sit under the index.
- **What was decided and measured: [Rebalance](rebalance.md)** — the per-phase decisions and the
  calibrated model, then the post-rebalance research, each with its rebuild recipe: tier 2's
  expedition model, the estate scaling, the arena duel, the weapon ladder, the tarot's Vigor
  multipliers, the armour enchant, the fortune teller's dispel and second card, and the repair
  measured on live play (2026-10-10).
- **The rules all of it produced: `CLAUDE.md`** — the rule and the trap; the story lives here or in
  the auto-memory bank, and every "never do X" guard stays in the repo doc
  (`feedback-docs-keep-the-rule`).

## The auto-memory bank (outside the repo)

Lives in `~/.claude/projects/-Users-cosmos-RestOfIryna/memory/`, indexed by its own `MEMORY.md`,
which loads every session — so it is **not** listed here. The split in force: the repo doc keeps
the RULE, the auto-memory keeps the REASON. Each `CLAUDE.md` rule names the auto-memory behind it
inline; follow the rule you are about to break. **Do not copy its entries into this file** — the
third-copy pattern `feedback-docs-keep-the-rule` was written about.

## Session Log
- [Session History](sessions.md) — Chronological log of what was done per session
