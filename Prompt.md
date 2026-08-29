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

Phases 0–2 done and committed; **Phase 3 is 3 of 12 catalogs in**.

| Reads from `content/data/` | Still a Swift array |
|---|---|
| items · enemies · recipes | Trader · Tavern · Market · Guild · Arena |
| weapon ladders · bags · estate upgrades | Master · Plot · Fortune · Quest |

**Next step — Phase 3 batch B: Trader / Tavern / Market / Guild / Arena.**
Their digest coverage is *already in place* while they are still Swift-backed, so
the baseline to match after the flip is **`9242a2c1501994ed`**. `ArenaCatalog
.leagueKey` is a hardcoded `switch` that becomes a league table in JSON — the
digest already replays it across honor 0…2000, plus `tithe` rounding.

Then batch C: Master / Plot / Fortune / Quest. Then Phase 4 (tuning tables +
collapsing the three `testMode` flags into one `time.scale`).

### The migration loop (repeat per catalog)

1. Extend `ContentDigest` **while the catalog is still Swift-backed**; capture the baseline.
2. DTO → mapping → loader → `GameContent` / `DomainContent`.
3. Add to `ContentExporter`; `swift run RestOfIryna --export-content`; commit the JSON verbatim.
4. Flip the catalog to a façade; delete the Swift array.
5. `swift run RestOfIryna --content-digest` — must equal the baseline.
6. Remove it from `ContentExporter` (re-exporting a façade proves nothing).

Normalize nothing during a migration.

### Commands

```
swift run roi-content validate --strict      # content integrity; exit 1 on any error
swift run RestOfIryna --content-digest       # migration verification digest
swift run RestOfIryna --export-content       # dump still-Swift catalogs to JSON
swift test                                   # 42 tests, ~0.03s
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
