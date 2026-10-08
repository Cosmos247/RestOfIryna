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
- [Live ops — the public test](live-ops.md) — **since 2026-10-07**: the open door, telling a frozen poll loop from a dead network, the player-activity snapshot SQL and its reading traps, what the first evening showed, day two's starving play, and a verified player FAQ with sources

## Game Design
- [Game Core](game-core.md) — GDD summary: classes, vigor, exploration, combat, estates, rest
- [Implemented vs Planned](status.md) — What exists now vs what the GDD describes, plus the rebalance phase table
- [Rebalance](rebalance.md) — Audit findings, locked decisions, the calibrated math model, the phase tracker and the per-phase lessons
- [Class sets concept](class-sets-concept.md) — **PARKED 2026-10-05, nothing approved**: three class branches L10–40 (5 pieces with the off-hand, 75% growth, ×1.19 on the set's own members), per-piece stats, the fight impact (+65–71% survivability at L20, so it ships only with a bestiary re-solve), Master commissions sized to fit a bag, four unanswered forks, and the formulas to re-derive every number

## Content specifications (in the repo, not here)
- [`content/spec/`](../content/spec/) — **five approved, Phase 9 closed 2026-09-01, plus `king.md` (2026-09-21).** Every number is printed by `roi-content spec` and quoted inside `<!-- generated -->` markers, so drift is mechanically detectable
  - `spec-progression.md` — the XP ladder, unlock gates, the level↔km rule (superseded 2026-10-02 by `spec-bestiary.md` §10)
  - `spec-bestiary.md` — the roster, zones and loot; §10 (2026-10-02) is tier 2: 14 creatures numbered by depth, the XP level-gap penalty off; §11 (2026-10-03) is creature strength by estate tier
  - `spec-items.md` — a FRAME, not a list: the gear ladder and the 40%-of-curve wardrobe gap; §9 (2026-10-04) is the weapon ladder by player level and the Master's lesson; §10 (2026-10-05) is durability as the item's own, the Forester set at 50 with its prices ×5/3; §11 (2026-10-06) is the Master's enchant as the armour's ladder — the gear ladder of §4, built, and gated by its price where the weapon's is gated by level
  - `spec-sets.md` — a set bonus multiplies its OWN members; set strength is a ladder topped by the 25% ceiling; §5's note (2026-10-05) points at the parked class-sets concept; §2's amendment and second table (2026-10-06): the members climb by the enchant now, so the Forester's flat bonus rots
  - `spec-economy.md` — silver has almost no sink; §2 amended 2026-09-02 by its own measurement
  - `king.md` — the King's decree chain: 39 decrees, levels 1–25, one open at a time
- [`content/lore.md`](../content/lore.md) — the world: families, the three wilderness zones, visual reference. `content/bestiary.md` is pre-rebalance reference, marked SUPERSEDED

## Where the work stands

- **The public test is running** since **2026-10-07 18:34** (`ROI_OPEN_ACCESS=1` on the Pi; 13
  accounts in by 10-08 21:59). Sessions now mix live-play polish with **player support**: the
  owner relays questions, answers come from the code and data with a ready Ukrainian reply
  ([live-ops.md](live-ops.md), auto-memory `project-public-test`).
- **On the Pi: `94620a4`** since **2026-10-08 11:55:36** — schema v19, content hash `a89b39b0`
  (guilds from level 30), the SDK's rate limiter OFF after it deadlocked the poll loop four
  times that morning, `PollWatchdog`, the Telegram client on HTTP/1.1. Up ~10 h with no freeze by
  21:59. **Committed, not pushed, not deployed: `2ed296e`** — one road card per trip (the owner's
  picture, `Assets/travel/road.jpg`) and «поїжте»; it needs the owner's push, a build and
  `pm2 restart ROI`.
- **The 2026-10-06 21:39 restart** took everything committed since `8ae6772` (tier 2 through the
  owner's screen art, five migrations, the tables checked after — `sessions.md` →
  `## Deploy — 2026-10-06`); the 2026-10-07 18:34 restart took the open door and the guild gate;
  the 2026-10-08 restarts the freeze fixes.
- **Committed 2026-10-08 late as `88156d4`, not deployed:** the starving players' four — the hunger tick only on a
  step that begins at 0 Vigor, «Ви повністю відпочили» for every rest that tops out, the road open
  at 0 Vigor, the forest edge explaining hunger ([live-ops.md](live-ops.md) → "Day two").
- **Waiting on the owner** (`TODO.md` → "Open, decided but not done", top block): two features
  chosen with their form unanswered, so not built — eating straight from the warehouse, and a hint
  under the estate-name prompt; a question left unanswered builds nothing. Below them, the older
  open threads: the arena's
  matchmaking and class gap, the weapon ladder's leftovers, the 10-04 tarot/watchman items, the
  10-05 durability items and the 10-06 armour-ladder items.
- **Parked: the class sets** ([class-sets-concept.md](class-sets-concept.md)). The owner asked
  for the concept on 10-05 and said «ми до цього повернемось» without answering its four forks.
  It was the gear ladder in class form; since 10-06 the armour has a ladder (the enchant,
  gated by price, not level), so the concept's ranks and the enchant share an axis — its top
  note says what that changes.
- **Emblem candidates** (2026-10-08, none chosen): `content/lore.md` §14.
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
  entries, the `## Deploy — 2026-09-28` restart, the 10-02 tier-2 entry, the 10-03 sync pass,
  the 10-03 estate-scaling entry (`4be2758`), the second 10-03 sync pass, the 10-03 arena
  entries (`cad61c3`, `f0c1749`) and the third 10-03 sync pass, then the 10-04 weapon-ladder
  entry (`9ab349c`) and the 10-04 sync pass, then the tester-driven entries of 10-04/05 (the
  tarot, the Vigor reward, the task-ready notice, the support button, the enchant), the 10-05
  sync pass, the 10-05 durability entry (the first of the day's gear work), and the class-sets
  concept with the second 10-05 sync pass, the 10-06 armour-ladder entry (`bad142b`) and its
  sync pass, the 10-06 deploy, then the public test: the 10-07 open door and guild gate with its
  deploy, the 10-08 poll-loop freeze and the SDK limiter with the 11:55 deploy, and the 10-08 road
  card and player-support entries.
- **What each phase decided: [Rebalance](rebalance.md).** Since 2026-10-02 it also holds the
  tier-2 research: the expedition model that can see depth (which `simulate`'s pace cannot), every
  figure it produced, the reconstructed 09-14 stat method, and how to rebuild the harness. Since
  2026-10-03 it adds the estate scaling: the variants measured, the upgrade check, what the
  implementation measured, and how each derived figure was read off the model. Then the arena
  duel, measured the same day: the first striker's edge, double knockouts, why Defend is a dead
  choice, the level and class gaps, silent fighters, and how to rebuild the probe. Since
  2026-10-04 it holds the weapon ladder, measured: the estate gate behind the overgrowth, three
  rounds of variants (v1–v3, every other estate tier, a rung every five levels at
  100/75/50%), the probe's rebuild recipe, and the path to each decision. Since 2026-10-04 also
  the tarot's Vigor multipliers, measured: why −25% rounded away to nothing, both cost tables and
  the Hanged Man decision. Since 2026-10-06 the armour enchant, measured: why a percentage of a
  level-1 piece gave nothing, the path to the ladder and from a level gate to a price, the grids
  (four strengths, a level bought ahead of the player, five price ladders) and how to rebuild the
  probe.
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
already carries all 100 at one line each, so a selection copied into this file is the
third-copy pattern `feedback-docs-keep-the-rule` was written about: on 2026-09-20 it had
grown back to 24 entries, every one of them already in `MEMORY.md` and one of them listed
twice.

## Session Log
- [Session History](sessions.md) — Chronological log of what was done per session
