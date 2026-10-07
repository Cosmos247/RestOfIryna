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

- **Phases 3–11 done; Phase 11 closed as CODE.** What follows is **live-play polish** —
  fixing what playing the deployed build reveals — plus the occasional small feature the
  play surfaces a need for. The Pi runs **`9385cd1`** since **2026-10-06 21:39** (schema
  **v19**, content hash `be1102fc`, the digest matched byte for byte before the restart was
  ordered; five migrations, the tables checked after — `sessions.md` → `## Deploy — 2026-10-06`).
  That restart took everything committed since `8ae6772`, tier 2 of the bestiary (`f03d502`,
  `spec-bestiary.md` §10) first among it. **Seven game changes of 2026-09-27/28 went live with the
  restart before it** (2026-09-28 22:11) (schema **v14**, five migrations, the tables checked after): the stray-number hint, the workshop's
  «Розібрати» with gear lists that name rows, combat lines with a death screen that shows the
  last round, the Training Ground as a house room, the technique rework with its fight log,
  the King's chain asking for the estate before the ground, and a workshop that no longer
  makes armour.
- **Next actions.**
  - **DEPLOYED 2026-10-06 21:39 — everything committed since `8ae6772`, in one restart**
    (content schema v19; until then the Pi ran v14):
    - tier 2 of the bestiary (`f03d502`);
    - the estate scaling (`4be2758`): creature HP and ATK +10% per estate tier, one migration;
    - the arena in simultaneous rounds (`cad61c3`) and as a cycle of three (`f0c1749`);
    - the quest board as a scroll (`95e8492`);
    - the weapon ladder by player level (`9ab349c`, `spec-items.md` §9);
    - a tarot card phrased once and 💰 for every reward, with the Chariot at −50% Vigor (10-04,
      `e861c73`; Swift, locale and `fortune.json`, no migration);
    - a Vigor reward that will not fit is asked about (10-04, `47e0e8f`; Swift and locale);
    - the watchman says when a task is ready (10-04, `0b53e82`; one migration);
    - «💛 Допомога грі» in Settings (10-04, `b0c9d80`; Swift and locale);
    - the Master's enchant draws from the bag alone (10-05, `4fe5b7a`; Swift and locale);
    - durability is the item's own, the Forester set at 50 and its prices ×5/3 (10-05,
      `bf15669`, `spec-items.md` §10; content schema v18, one migration);
    - the Master's enchant is the armour's ladder (10-06, `bad142b`, `spec-items.md` §11;
      content schema v19, no migration): a level budgets the piece at item level 5 … 25, and
      its price — 50 × level² silver a piece — is its only gate.
    - the pre-deploy audit's four fixes (10-06, `f2ae7ea`, Swift only): an «… все одно» answer names its
      decree or job, the arena's stake picker asks where the player stands, the palace banner
      prints the XP that landed, and the data migrations run in a transaction — the whole
      backlog rehearsed off the Pi first (auto-memory `reference-deploy-rehearsal`);
    - the owner's screen art (10-06, `873e426`, no code): the Master, the palace, the capital map on the
      square and both streets, the King's charter and the six rabid-dog scenes — and the King's
      first line, «Король жестом підкликає вас до себе і протягує вам згорток:».

    The weapon ladder adds two migrations (`ClampWeaponTiersToLevel` with a silver refund,
    `ReseatDecreesById`), the task-ready notice one (`AddReadyNotifiedFlags`), the durability one
    (`RaiseArmorDurability`, +20 on every Forester piece). The digests to match and the tables to
    verify are in `Prompt.md`. The testers should hear first — the game announces neither the
    stronger forest, nor the weapon clamp, nor the dearer and sturdier armour, nor the enchant
    that now makes it grow.
  - Then the first `fight_log` rows, and a human walking the screens. Fifteen blocks head
    `TODO.md`'s walk list and wait for their deploy — the screen-art, audit-fixes, armour-ladder, durability, enchant, support-button,
    task-ready, Vigor-reward, tarot, weapon, quest-board, two arena, estate and tier-2 blocks; the
    arena ones need two accounts.
  - **Open threads**, all in `TODO.md` → "Open, decided but not done":
    - the arena's matchmaking and class gap — Defend became a real choice with the cycle of
      three (`f0c1749`), but the warrior still wins 75–76% against the other classes (figures
      in `rebalance.md` → "The arena cycle, measured");
    - the weapon ladder's leftovers: rungs 10–11 for a level cap of 50, the tier-2 lines solved
      against the old obtainable-kit share, the workshop's T3 gate the validator cannot see, and
      the estate's lost weapon pull;
    - from the 10-04 tarot and watchman work: the Devil's doubled defend (half-up rounding), the
      tarot's flat bonuses against the no-flat-bonus rule, and the watchman's per-minute cost at
      the target roster;
    - from the 10-05 durability change: the repair price of armour the Master does not sell
      (`?? 30`), `/reload` leaving the cached gear bonuses stale, and salvage of a piece that
      never wears;
    - from the 10-06 armour ladder: armour above item level 1 has no ladder yet (the validator
      refuses it), the ladder stops at +5 / item level 25, its price is its only gate (so a
      finished set can be handed to a new player), the Forester's flat set bonus now rots, and
      what the testers had enchanted (answered at the 10-06 deploy).
  - **Parked: the class sets** ([class-sets-concept.md](class-sets-concept.md)). The owner asked
    for the concept on 10-05 and said «ми до цього повернемось» without answering its four forks.
    It was the gear ladder in class form; since 10-06 the armour has a ladder (the enchant,
    gated by price, not level), so the concept's ranks and the enchant share an axis — its top
    note says what that changes.
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
  sync pass.
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
already carries all 94 at one line each, so a selection copied into this file is the
third-copy pattern `feedback-docs-keep-the-rule` was written about: on 2026-09-20 it had
grown back to 24 entries, every one of them already in `MEMORY.md` and one of them listed
twice.

## Session Log
- [Session History](sessions.md) — Chronological log of what was done per session
