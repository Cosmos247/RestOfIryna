# ROI Project Memory Index

Session-persistent knowledge base. Each entry links to a detailed file.

## Architecture & Stack
- [Architecture Overview](architecture.md) — Router-controller state machine, app lifecycle, dispatcher chain
- [Tech Stack](tech-stack.md) — Swift 6.2, Hummingbird 2, Fluent, swift-telegram-sdk, Lingo
- [File Map](file-map.md) — Source tree with purpose annotations per file (canonical; covers `Modules/` including the `ROISim` balance maths + simulator, the tuning DTOs, the Phase 5–7 migrations and the test suite)
- [Content Pipeline](content-pipeline.md) — Data-driven catalogs and tuning tables: JSON layout, loader/validator, snapshots, the item stat budget, the bestiary archetype table, hot reload, and the verification discipline (four digest halves + four live checks + the balance simulator)

## Content specifications (in the repo, not here)
- [`content/spec/`](../content/spec/) — **all five approved; Phase 9 closed 2026-09-01.**
  Every number in them is printed by `roi-content spec`, never typed, and quoted inside
  `<!-- generated -->` markers so drift is mechanically detectable.
  - **`spec-progression.md`** — the skeleton: XP ladder, unlock gates, and the level↔km rule
  - **`spec-bestiary.md`** — the roster, zones and loot; no new creatures, the seven are re-spread
  - **`spec-items.md`** — a FRAME, not a list: no new items in the rebalance, the gear ladder,
    and the printed 40%-of-curve wardrobe gap that amended the bestiary spec's §9
  - **`spec-sets.md`** — a set bonus multiplies its OWN members, not the whole kit; set strength
    is a ladder whose top rung is the 25% ceiling, and the Forester set is its weakest rung
  - **`spec-economy.md`** — silver has almost no sink; `lootMultiplier` multiplies quantity; and
    §2 on the opening, **amended 2026-09-02 by its own measurement**: the opening is not
    Vigor-bankrupt, the *shallow* opening is (km 1 nets −374, km 4 nets +40). Quotes
    `roi-content spec opening`
- [`content/lore.md`](../content/lore.md) — the world: families, the three wilderness zones, visual reference. `content/bestiary.md` is a pre-rebalance reference doc, marked SUPERSEDED

## Game Design
- [Game Core](game-core.md) — GDD summary: classes, vigor, exploration, combat, estates
- [Implemented vs Planned](status.md) — What exists now vs what GDD describes, plus the rebalance phase table
- [Rebalance](rebalance.md) — **Active work.** Audit findings, locked decisions, the calibrated math model, the phase tracker (**3–10 done · 11 all but closed** — ledger and wipe 2026-09-02, invite-only access and the Pi deployment 09-08/09, `scale` 60→1.0 on 09-09; what remains is a deliberate first-hour walkthrough) and the per-phase lessons

## Patterns & Conventions
- [Controller Pattern](controller-pattern.md) — How to build/register controllers, routing, keyboards
- [Session & Auth](session-auth.md) — User model, session cache, authorization flow
- [Localization](localization.md) — Lingo setup, JSON structure, interpolation, adding locales

## Live-play polish (2026-09-09 → 10) — the work in flight

Phase 11 is closed as CODE; what is happening now is **fixing what playing the deployed
build reveals**. Three commits, full narrative in [Session History](sessions.md)
(the two 2026-09-09 entries).

- **The bot is live on the Pi running `509f2db`**; `04bd80d` and later are not deployed.
  The deploy recipe — including the swiftenv `PATH` trap that stops a non-interactive
  `ssh` from finding `swift` at all — is in `Prompt.md` → "Next action".
- **`Countdown.format` is the one time format** and no duration is written into copy any
  more; **`RestNotificationService`** is the 60 s watchman for what finishes while nobody
  is looking (HP full · fortune cooldown · 12:00 rollover). A background writer must take
  the session-cached `User` (`SessionCache.peek`) or it silently undoes the player's last
  tap — Fluent saves whole rows.
- **Two ceilings that were not real:** passive expeditions now cost against a 3 h/day
  budget, and the warehouse cap finally applies to the plot harvest — the one path that
  filled the warehouse unchecked — with no developer exemption left.
- **Two defects the code review caught rather than a test:** starvation was charging
  double on three of the four step buckets (10 HP where the message said 5), and the
  broken-gear line was written in a gender that fits none of the nineteen breakable items.
  uk now agrees with the item's own noun — see [Localization](localization.md).
- **Still parked:** ~328 Telegram API errors a day in the live log, 162 of them an
  `editMessageText` against a photo message that leaves the screen silently un-updated.

## Phase 11 quick orientation (2026-09-02, extended 2026-09-07 and 09-09)

**Where it stands.** Every code-side piece has landed. `validate --strict` reports
**zero errors and zero warnings** for the first time, the bot runs on the Pi under pm2,
and four accounts have played the rebalanced build. What is NOT done is a first hour
walked deliberately against the checklist in `Prompt.md`, and `/reload` has still never
run against a real database.

- **The opening ledger** — `Modules/ROISim/OpeningLedger.swift`, printed by `simulate` and by
  `roi-content spec opening`. Prices levels 1–3 at every depth against the trail, the stretch
  the pace model must skip because it divides by an estate that does not exist yet. It answers
  `spec-economy.md` §7 and inverts its prose. Warning: `opening.shallow_is_bankrupt`.
- **`WipeForRebalance`** — `Swift/Migrations/WipeForRebalance.swift`, registered LAST. **Already
  executed, 2026-09-02 22:14:41**, and three accounts played on it through 04.09 — Fluent will
  not re-run it, so a clean first hour needs its `_fluent_migrations` row deleted first. The
  pre-wipe database is dumped to `~/RestOfIryna-backups/roi-preplaytest-2026-09-08.sql`. Explicit table list (a cascade would miss
  `tavern_game_messages`, which has no FK) plus an `information_schema` self-check. Two
  migrations now run ahead of it in the same batch: `RemoveProfileStyle`, `AddQuestAccepted`.
- **Read before trusting a printed number at level 1:** the report measures a full common kit
  and registration grants only the starter weapon — the absolute numbers are a ceiling. See the
  auto-memory `project-reference-character-vs-starting-kit`.
- **The playtest has started but was never walked on purpose.** Four accounts played
  2026-09-02 → 09-09 (Nerif reached L10 / estate T4); what they hit is in the auto-memory
  `first-playtest-happened`. The checklist of surfaces to walk is in `Prompt.md`.
- **`scale` is 1.0 since 2026-09-09** — game time is real time, and the flip moved two
  digest halves rather than one: `records` hashes the DERIVED `PlotCatalog.intervalSeconds`,
  a guard Phase 4b placed there so retiring the `testMode` flag could not change the
  produced value in silence.

## Access control (2026-09-08)

Access is **invite-only and lives in the database**, not in code. `allowed_users`
(`AllowedUser` / `CreateAllowedUsers`) plus `AccessControl` (an actor cache whose MISS
queries the DB) and `InviteToken` (an encrypted UNIX timestamp with an HMAC tag, 16
letters, five real minutes). `/link` is developer-only and is how a new tester is
admitted — never a code edit. The gate sits in `TGDispatcher` ahead of routing, so a
refused stranger never gets a `User` row, and it takes the token as a `/start` payload
**or** pasted as a bare message. Full rationale in the auto-memory
`invite-only-access`; deployment context in `pi-host-layout` and `linux-build-gap`.

## The 2026-09-07 pre-push pass (four commits, no combat maths moved)

Bug fixes, then a quest rebalance, then a naming audit. Full narrative in
[Session History](sessions.md) (entries 1–12 of the 2026-09-07 session); the balance half is
in [Rebalance](rebalance.md).

- **One profile layout** (style switcher and `User.profileStyle` gone, `RemoveProfileStyle`),
  the player addressed by their chosen nickname, a **level-up as its own message** listing all
  seven level-derived stats, and the estate tier-up likewise (`LevelUpBanner`, `EstateUpBanner`).
- **HP regen is stamped at both ends of an expedition** — `HealingService.beginResting` /
  `suspendResting`. An interaction-driven tick cannot observe a transition that happens while
  nobody is interacting, which is why one half healed nothing and the other refunded a run.
- **Daily jobs are taken by hand**, carry a `minLevel` band, and their rewards ride curves
  instead of being flat — see the auto-memory `project-quests-taken-by-hand`.
- **The player is addressed as «ви»** in every uk string — auto-memory
  `feedback-formal-address-vy`; nine gendered pairs collapsed as a result.
- **A weapon ladder is one object** — the mage ladder used three nouns; `locale.ladder_name_drift`
  now warns. Auto-memory `feedback-ladder-names-one-noun`.
- **Two tool findings:** a new tuning constant is invisible to the digest until the digest
  names it (auto-memory `feedback-digest-names-constants`), and two spec blocks never
  reproduced from their own markers — both are contiguous excerpts now.

## Session Log
- [Session History](sessions.md) — Chronological log of what was done per session
