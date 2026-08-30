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

**Phases 3, 4 and 5 are complete.** Catalogs and tuning both live in
`content/data/`, and the game's mathematics has been rebuilt.

```
content/data/         manifest · items · enemies (+ archetypes) · recipes ·
                      weapon_upgrades · bags · estate_upgrades · trader · tavern ·
                      market · guild · arena · master · plots · fortune · quests
content/data/tuning/  combat · vigor · exploration · progression · economy · time
```

What Phase 5 changed, in one line each: damage is **absorbed** (`ATK · (1 −
DEF/(DEF+K(L)))`) rather than subtracted · crit/dodge/accuracy are **ratings**
through curves whose denominators grow with level · **`levelDiff`** scales damage
by the level gap · stats grow **proportionally every level**, cap 40 · Vigor has
a **pool that grows and regenerates** · enemies carry level / archetype /
crit / dodge / accuracy / silver / spawn weight and are **generated at design
time** · the three special attacks were rebuilt off "ignore armour" onto armour
break, guaranteed crit and burn · monsters **drop silver**.

**Next — Phase 6: rarity and sets.** `rarities.json`, `sets.json`,
`Item.rarity` / `Item.setId`, enchant as a **percentage of the item's own
budget** (never flat points — a flat +32 is 267% of base DEF at level 1 and 14%
at 40), a second pass in `recomputeBonuses`, and budget rules in the validator.

**This is also the phase that makes the balance checkable.** Phase 5 could only
prove the formulas: the design's reference character carries gear from a budget
curve that does not exist yet, which is why its level-40 warrior shows DEF 225
where the bare stat line gives 52.

**Current digest baseline: `84b3316f44bd18c7`**
(`records 70d6d2396af6f198` · `tuning 88db2a129b96a432` ·
`spawns 81f6639962cbc4a7` · `quests 2e52ecdfa45276ec`).

From Phase 5 on the digest is a change DETECTOR, not an equality check — the
question is no longer "did it stay the same" but "did exactly the intended thing
move". `--content-digest` also prints three live checks (façade lookups, the plot
sweeper's two-point equivalence, and the combat model against the design anchors)
plus the stat ladder and spawn distribution.

⚠️ **No live Telegram pass has been run since the rebalance began.** Every
formula the player touches changed in Phase 5.

Known content gaps, all Phase 10's: km 31–40 has a single elite and nothing else,
the `boss` archetype has no members, and `ExplorationService.rollLoot` still
holds its foraging pools in Swift (they belong in `zones.json`).

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
swift test                                   # 155 tests, ~0.14s
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
