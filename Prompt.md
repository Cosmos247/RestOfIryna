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

The whole game is being rebalanced before release, and all content is moving out
of Swift arrays into `content/data/*.json`. **This is the only work in flight.**

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

Batch C surfaced why that is not mechanical. `PlotCatalog.testMode` alone drives
**two different scales**: `intervalSeconds` is 60 ↔ 3600 (60×, which matches
`manifest.timeScale: 60`) while `PlotProductionService`'s sweep is 60 ↔ 300
(**5×**). The flag was carried into `plots.json` verbatim; Phase 4 reconciles all
three flags and deletes it.

Two smaller decisions worth making first: `manifest.json` still reads
`contentVersion: "phase1-export"` (stale by three phases), and `schemaVersion`
has never moved even though the bundle has gained nine required files since v1.

**Current digest baseline: `8053216102eceff7`**
(`records 04cbf2b5331ea85b` · `spawns 635cde3f65184c78` · `quests 2e52ecdfa45276ec`).

### The migration loop (historical — Phase 3 closed)

1. Extend `ContentDigest` **while the catalog is still Swift-backed**; capture the baseline.
2. DTO → mapping → loader → `GameContent` / `DomainContent`.
3. Add to `ContentExporter`; `swift run RestOfIryna --export-content`; commit the JSON verbatim.
   *(deleted at the end of Phase 3 — recover from git if needed)*
4. Flip the catalog to a façade; delete the Swift array.
5. `swift run RestOfIryna --content-digest` — must equal the baseline.
6. Remove it from `ContentExporter` (re-exporting a façade proves nothing).

Normalize nothing during a migration.

### Commands

```
swift run roi-content validate --strict      # content integrity; exit 1 on any error
swift run RestOfIryna --content-digest       # migration verification digest
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
| `Swift/Helpers/ContentDigest.swift` | Migration verification |

## Rules

- After significant work update `.memory/sessions.md`, `.memory/status.md` and `TODO.md`
- Ask before committing; short compact messages, no co-author line
- **Never push** — manual/user-side only
- New locale keys go in BOTH `en.json` and `uk.json`; uk gendered copy uses `.m`/`.f`
- Telegram `callback_data` max 64 bytes
- Content changes: `roi-content validate --strict` must pass before commit
