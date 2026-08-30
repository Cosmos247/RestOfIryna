# ROI Session Primer

Read this first, then `.memory/INDEX.md`. For the active work read
`.memory/rebalance.md` and `.memory/content-pipeline.md` — everything else in
this file is background.

## What Is This

**Rest Of Iryna (ROI)** — a multiplayer medieval text RPG Telegram bot in Swift.
Players fight rabid beasts, manage estates, trade, and duel. All interaction via
text + emoji + inline keyboards.

## Stack

Swift 6.2 (strict concurrency) | Hummingbird 2.22+ | Fluent 4.13+ / PostgreSQL 16 |
swift-telegram-sdk 4.6+ | AsyncHTTPClient | Lingo 4 (i18n) | SwiftDotenv

Router–controller state machine: each user has a `routerName` in the DB;
`TGUpdate → TGDispatcher (auth) → SessionCache → RouterStore → Controller[routerName]`.
Controllers transition by setting `routerName` + `saveAndCache()`.

Game code lives in `Swift/`. The content pipeline lives in `Modules/`. Never
`Sources/`.

## ⏳ ACTIVE WORK — pre-release rebalance

The whole game is being rebalanced before release. All content has already moved
out of Swift arrays into `content/data/*.json` (Phase 3, done); what remains is
the maths. **This is the only work in flight.**

- Plan: `~/.claude/plans/roi-session-primer-eventual-wirth.md`
- Tracker: the "Full Rebalance" section of `TODO.md`
- Decisions + calibrated math: `.memory/rebalance.md`
- Pipeline rules: `.memory/content-pipeline.md`

### Where we stopped

**Phases 3 and 4 are complete.** All 12 catalogs read `content/data/`, and the
balance numbers now live beside them in `content/data/tuning/`. No Swift catalog
array and no hardcoded tuning constant remains.

```
content/data/         manifest · items · enemies · recipes · weapon_upgrades ·
                      bags · estate_upgrades · trader · tavern · market · guild ·
                      arena · master · plots · fortune · quests      (16 files)
content/data/tuning/  combat · vigor · exploration · progression · economy · time
```

`time.scale` is now the single time knob — the three `testMode` booleans and
`manifest.timeScale` are gone, and `schemaVersion` is 2. **It is still 60**, on
purpose: Phase 11 flips it to 1.0 as a one-number change, which is what kept the
collapse a verified no-op. `roi-content validate` says so, and `--strict` exits 1.

**Next step — Phase 5: the new combat model.** Mitigation instead of
subtraction, ratings→percent with denominators derived from the item budget
curve, `levelDiff`, a hit floor of 40, enemy archetypes generated at design time,
`maxLevel = 40` with proportional growth, and the technique rebuild off
`defenderDEFFraction = 0`. Every number it changes is already a JSON edit —
`tuning/combat.json`, `tuning/progression.json` — but the FORMULAS are Swift, so
this phase is a real rewrite of `CombatService` and `User`, not a retune.

Two things Phase 5 inherits, both already surfaced by the tooling rather than
buried in prose:
- `roi-content validate` warns that fleeing wears 5 durability against a
  defeat's 3 — running away costs more than dying.
- `EnemyCatalog.pickFor` still falls back to `all.first` past km 35, so every
  deep encounter is a wild boar. Preserved through the migration on purpose;
  it belongs to the `zones.json` work, alongside the foraging pools still
  hardcoded in `ExplorationService.rollLoot`.

**Current digest baseline: `893b57b06fad8068`**
(`records 296960c1a998a7e7` · `tuning 9ba80c8f77fa3aa8` ·
`spawns 635cde3f65184c78` · `quests 2e52ecdfa45276ec`).

The digest has FOUR halves. Keep `tuning` separate from `records` — holding the
three catalog halves fixed is how a balance change proves it touched only
balance.

### How content works now

All 12 catalogs and all six tuning tables are façades over a snapshot
installed at boot:

```
content/data/*.json → ContentLoader → ContentValidator → GameContent (DTOs)
                                                       → DomainContent → Catalogs.current
```

Adding content is a **JSON edit plus locale keys in both `en.json` and
`uk.json`** — never a Swift array edit, because there are none left. Locale keys
are derived from ids (`item.<id>`, `plot.type.<type>.name`,
`fortune.card.<id>.*`, `quest.<id>.title`) and the validator demands each exists
in both locales.

`ContentBootstrap.load` runs in `configure` **before the database block** — the
dev-seed and `backfillWeaponDurability` both touch a catalog later in the same
function, and a catalog read before install traps. **No `static let` anywhere may
reference a catalog** — that is a real trap, not a theoretical one:
`FortuneCatalog.lookup` was `Dictionary(uniqueKeysWithValues: all.map …)` and
would have run at type-init the moment `all` started reading the snapshot.

The migration loop that got us here, its verification layers and every gotcha
live in `.memory/content-pipeline.md`.

### Commands

```
swift run roi-content validate --strict      # content integrity; exit 1 on any error
swift run RestOfIryna --content-digest       # confirm ONLY the intended change moved
swift test                                   # 130 tests, ~0.08s
```

## What Works Now (shipped game)

Registration · exploration (active + passive, three-tier visit decay, restart-safe
scheduler) · turn-based PvE combat with 9 class techniques · estate (plots,
warehouse, workshop, kitchen, weapon/bag/estate upgrades, technique gates) ·
capital hub (travel, Trader, Tavern with dice/darts, Fortune Teller, Master with
durability + enchant, player Market, synchronous Trade) · Guilds (roster, invites,
item vault, silver treasury) · Arena (live PvP duel, Honor ELO, stakes, daily
budget) · daily NPC quests derived from a stable hash + quest journal.

Every daily system keys off `GameDay` (rolls at **12:00 Kyiv**). EN + UK
localization (956 / 977 keys). Auth is still gated to 4 hardcoded TG IDs.

⚠️ `tuning/time.json` → `scale` is **60**, so every game-time gate is 60×
compressed and the validator warns about it. Deliberate; Phase 11 sets it to 1.0.
Nothing under `realTime` is affected — Telegram's 24 h dice-delete window, the
trade TTLs and the 12:00 rollover never scale.

## Key Files

| File | What |
|------|------|
| `CLAUDE.md` | Conventions, patterns, git rules — read before writing code |
| `.memory/INDEX.md` | Knowledge base index |
| `.memory/rebalance.md` | Active work: decisions, math model, phase tracker |
| `.memory/content-pipeline.md` | How content loading/validation/migration works |
| `TODO.md` | Phase tracker |
| `GDD.md` | Game design document (predates the rebalance — treat its numbers as intent, not truth) |
| `Swift/configure.swift` | Bootstrap; content loads before the DB block |
| `Swift/Helpers/Catalogs.swift` | Domain content snapshot the façades read |
| `Swift/Helpers/ContentDigest.swift` | `--content-digest`: records + spawn replay + daily-quest replay. Run before/after any content edit to confirm ONLY the intended change moved |

## Rules

- After significant work update `.memory/sessions.md`, `.memory/status.md` and `TODO.md`
- Ask before committing; short compact messages, no co-author line
- **Never push** — manual/user-side only
- New locale keys go in BOTH `en.json` and `uk.json`; uk gendered copy uses `.m`/`.f`
- Telegram `callback_data` max 64 bytes
- Content changes: `roi-content validate --strict` must pass before commit
