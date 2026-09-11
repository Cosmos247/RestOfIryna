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
    Vigor-bankrupt, the *shallow* opening is (km 1 nets −335, km 4 nets +44). Quotes
    `roi-content spec opening`
- [`content/lore.md`](../content/lore.md) — the world: families, the three wilderness zones, visual reference. `content/bestiary.md` is a pre-rebalance reference doc, marked SUPERSEDED

## Game Design
- [Game Core](game-core.md) — GDD summary: classes, vigor, exploration, combat, estates
- [Implemented vs Planned](status.md) — What exists now vs what GDD describes, plus the rebalance phase table
- [Rebalance](rebalance.md) — **Active work.** Audit findings, locked decisions, the calibrated math model, the phase tracker (**3–11 done; 11 closed as CODE** — ledger and wipe 2026-09-02, invite-only access and the Pi deployment 09-08/09, `scale` 60→1.0 on 09-09) and the per-phase lessons. What follows Phase 11 is **live-play polish**, tracked in the section below and in `Prompt.md`; what is still owed is a deliberate first-hour walkthrough

## Patterns & Conventions
- [Controller Pattern](controller-pattern.md) — How to build/register controllers, routing, keyboards
- [Session & Auth](session-auth.md) — User model, session cache, authorization flow
- [Localization](localization.md) — Lingo setup, JSON structure, interpolation, adding locales

## Live-play polish (2026-09-09 → 11) — the work in flight

Phase 11 is closed as CODE; what is happening now is **fixing what playing the deployed
build reveals**. Eleven commits, full narrative in [Session History](sessions.md)
(the 2026-09-09 → 09-11 entries).

- **The bot is live on the Pi running `fea2343`** (content hash `4eac64ff`, **schema v11**),
  and local / `origin/main` / the Pi are all on that same commit — nothing pending. The
  deploy recipe, including the swiftenv `PATH` trap that stops a non-interactive `ssh` from
  finding `swift` at all and the Linux `--content-digest` pre-flight worth running before
  any restart, is in `Prompt.md` → "Next action".
- **The forest was empty on the way home** — the revisit-decay table decayed the wrong
  bucket: encounters fell 40→20→0 while forage held at 45→45→25, backwards in the fiction
  since a beast wanders back onto a walked km and a stripped bush does not regrow. The walk
  home is ALWAYS tier 1 by construction, so 35% of its steps were dead and a run of three
  ran at 37.9% per return leg. Tier 1 is `8/35/52/5` now. **Tier 1 was also the whole
  passive expedition**, so passive took its own required `passive.weights` row — schema
  v10 → v11. See [Rebalance](rebalance.md) and the auto-memory
  `project-exploration-return-leg`.
- **A rating is a rating on every screen and is never labelled `%`** — `crit`/`dodge`/
  `accuracy` convert through a level-linear curve, and the sheet plus four gear screens
  printed the raw rating with a `%`. Every screen shows the bare rating now, deliberately:
  gear is priced in rating, so percentages on the sheet alone break the only arithmetic a
  player can do. Auto-memory `project-rating-vs-percent-display`.
- **Every gear screen renders all six `GearStats` fields** — four of five skipped HP, which
  hid the Forester set's +18 max HP everywhere but the shop card. Reuses `profile.health`
  rather than adding a sixth duplicated key pair.
- **A row created mid-flight cannot be located from `createdAt`** — `TravelService.turnBack`
  measured the walk done as `now − createdAt`, right only for a leg that began at an
  endpoint, so a second turn-back priced a two-minute road at five seconds. `endsAt` is
  anchored to a destination and therefore locates any row; the alternative the original
  commit explicitly rejected was the correct one, and its reasoning is marked superseded in
  place rather than deleted. Auto-memory `feedback-audit-what-else-reads-it`.
- **The dispatcher raced itself.** The SDK gives every update its own `Task.detached`, and
  the router used to be chosen from a `routerName` read before the previous tap had
  transitioned — so a second quick tap reached the controller the first had just left. The
  router is resolved inside `RouterStore`'s per-user chain now, and `[ROUTE]` measures how
  often the race fires. See [Architecture](architecture.md).
- **`editScreen` is the one way to redraw a screen** (`Swift/Helpers/ScreenEdit.swift`).
  310 of the 807 API refusals in a day and a half of log were `editMessageText` against a
  caption, each swallowed by `try?` — that is the whole "the tap did nothing" report. The
  client classifies refusals now, so the benign 497 stop burying the rest.
- **Resting is a place, not a pause between fights.** HP regen suspends in the wilderness,
  on the road AND in the capital; only the wilderness was ever checked. The road needs its
  own check because `location` is not flipped until arrival. See [Game Core](game-core.md).
- **The road can be turned around** — the nav keyboard lends Explore's slot to
  `↩️ Розвернутись` while a trip is in flight, and walking back costs what was walked.
  Keyboard state is told, not asked: see [Controller Pattern](controller-pattern.md).
- **Background writers take the session-cached `User`** (`SessionCache.peek`) or they
  publish a pre-tap row over the player's last action — `TravelService` and
  `PassiveExpeditionService` joined `RestNotificationService` in obeying it. See
  [Session & Auth](session-auth.md).
- **`Countdown.format` is the one time format** and no duration is written into copy any
  more; **`RestNotificationService`** is the 60 s watchman for what finishes while nobody
  is looking (HP full · fortune cooldown · 12:00 rollover).
- **Ceilings that were not real:** passive expeditions cost against a 3 h/day budget, the
  warehouse cap applies to the plot harvest, and the developer exemption is gone from all
  four warehouse checks (it survives on the BAG, a different ceiling).
- **Two classes of defect the log could not report:** starvation charged double on three of
  four step buckets, and a refusal that said "your bag has none of this" over a full bag —
  `depositAll` returned a bare count, and a zero read as both "nothing here" and "no room".
  Reasons travel with the count now.
- **uk agrees with the item's own noun**, not only with the player — see
  [Localization](localization.md).

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
