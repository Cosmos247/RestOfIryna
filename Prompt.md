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

**Phase 3 is complete — all 12 catalogs read `content/data/`.** No Swift catalog
array remains anywhere in the tree.

```
content/data/  manifest · items · enemies · recipes · weapon_upgrades · bags ·
               estate_upgrades · trader · tavern · market · guild · arena ·
               master · plots · fortune · quests          (16 files)
```

**Next step — Phase 4: tuning tables + collapsing the three `testMode` flags
into one `time.scale`** (its own commit).

**It is not mechanical.** There are three flags but FIVE scale sites, and they do
not all use the same ratio:

| Flag | Site | test : prod | ratio |
|---|---|---|---|
| `PlotCatalog.testMode` *(now in `plots.json`)* | `PlotCatalog.intervalSeconds:82` | 60 : 3600 | 60× |
| ↑ same flag | `PlotProductionService:38` sweep | 60 : 300 | **5×** |
| ↑ same flag | `EstateController:637` | picks `estate.plot.rate.per_minute` / `.per_hour` | UI label |
| `TravelService.testMode:27` | `TravelService:35` | ×1.0 : ×60.0 | 60× |
| `PassiveExpeditionService.testMode:199` | `:203` | 1 : 60 | 60× |

So a naive `timeScale = 60` would speed the plot sweeper up 12× beyond its
current behaviour, and the UI label has to follow whatever replaces the boolean.
`plots.json` carries `testMode` verbatim for now; Phase 4 reconciles all five
sites and deletes the field.

Two smaller decisions worth making first: `manifest.json` still reads
`contentVersion: "phase1-export"` (stale by three phases), and `schemaVersion`
has never moved even though the bundle has gained nine required files since v1.
Neither is broken — a stale bundle fails loudly with `missingFile(...)` — but a
handshake that never moves slowly becomes decorative.

**Current digest baseline: `8053216102eceff7`**
(`records 04cbf2b5331ea85b` · `spawns 635cde3f65184c78` · `quests 2e52ecdfa45276ec`).

### How content works now

All 12 catalogs are façades over a snapshot installed at boot:

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
swift test                                   # 85 tests, ~0.04s
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

⚠️ All three `testMode` flags are still `true`, so every time gate is 60×
compressed. `manifest.json` records this as `timeScale: 60.0` and the validator
warns about it. Phase 4 flips it.

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
