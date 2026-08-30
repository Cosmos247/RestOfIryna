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

**Phases 3–6 are complete.** Content, tuning, the combat model and the item
budget all live in `content/data/`.

```
content/data/         manifest · items · enemies (+ archetypes) · recipes ·
                      rarities · sets · weapon_upgrades · bags · estate_upgrades ·
                      trader · tavern · market · guild · arena · master · plots ·
                      fortune · quests
content/data/tuning/  combat · vigor · exploration · progression · economy ·
                      time · budget
```

Phase 6 added the piece that makes balance CHECKABLE:

```
budget(itemLevel, slot, rarity) = slotWeight · (6.0 + 1.5·itemLevel) · rarityBudget
```

Every stat an item carries is that budget spent at fixed exchange rates, so one
number bounds a piece — and since the combat denominators were derived from the
same curve, an item that respects its budget cannot move any stat's percentage.
Rarity multiplies budget ×1.00→×1.45 while value goes ×1→×16 (decoupled on
purpose). Enchant is `1 + 4% × level` of the item's OWN budget, capped at +20%.
Sets grant thresholds at 2/4/6 pieces through a second pass in
`recomputeBonuses`. Gear now carries HP as a sixth stat.

**Phase 7 is done:** `/reload` and `/content` (dev-only), hot-swapping the
bundle in **parse → validate → live-check → build → install** order, where
`install` is the only infallible step and last — so a refused reload leaves the
running game on exactly the snapshot it was serving. `LiveReferenceCheck`
refuses a swap that would drop an id live rows still point at, across all ten
content-id columns. Lingo is NOT reloaded; new strings still need a restart.

**Phase 8 is done.** **8A** moved the combat, progression and budget math out of
`CombatService` / `User` / `ItemBudget` and into `ROISim`, leaving the façades'
public API untouched — so the game and the simulator execute the SAME
`CombatMath.applyAttack`, and a report cannot drift from the bot. The digest held
at `a4d825a8d728f4f8` across the move, which is a bit-level proof: its `tuning`
half already replays `baseStats`, `xpRequiredToReach` and all four curves.

**8B** shipped `swift run roi-content simulate` — `EnemyGenerator` (inverts the
archetype targets the way the shipped roster's DEF/crit/dodge were derived),
`ReferenceCharacter` (on curve and one ladder rung behind), `FightSimulator` (the
round order copied from `CombatController.finishRound`; `.basic` IS the passive
autobattle), and a banded report. **Level invariance holds on all 18 rows** —
which is the claim the whole rebalance rests on.

**8C acted on what it found**, three changes:
- **every stance lift is a multiplier of the character's own stat** (schema v8).
  Two of the three Supers were flat bonuses that rotted across a lifetime —
  `hawks_eye` was +115% crit at level 1 and +21% at the cap, and `bloodlust` was
  charging **double Vigor** for a bonus worth +5%. Now: bloodlust attack ×1.35 /
  defence ×1.15 / vigor ×1.5, hawks_eye crit ×1.60 / accuracy ×1.15 / dodge ×1.15,
  arcane_resonance attack ×1.50 / defence ×1.15.
- **the warrior's budget was re-spent toward offence** — weapon attack 0.72 → 0.80,
  armour defence 0.82 → 0.78 into HP, base attack 10 → 12. Days-to-cap spread
  **17% → 9%**, and the tank trade finally exists: the warrior loses 50–53% of a
  bar to an elite where the mage loses 65%.
- **monster silver removed entirely** — every faucet left is a player-facing
  system with a sink attached.

**Reported by every run, not yet acted on:** `shadowVeilDodgeBonus` (+50 = 238%
of a level-1 archer's dodge, 34% at the cap) and `defend.archerDodgeBonus`
(+30 = 143% → 20%) are the same flat-bonus rot in the techniques beside the
stances; the mage's 93% win rate against an elite at level 5 wants the
spawn-level floor the plan specified; and the shipped bestiary carries ~50% of
the HP and ATK its archetypes ask for (Phase 10 regenerates it — the generator
now exists to do it with).

**Next is Phase 9** — content specs, approved before a byte is authored.

**Current digest baseline: `583a32cb5a9d9dc7`** (schema **v8**)
(`records 7b3a5e700d0b8fe7` · `tuning 5946bb13b530389e` ·
`spawns 81f6639962cbc4a7` · `quests 2e52ecdfa45276ec`). Phase 8C moved the first
two and left the last two alone — no selection logic or daily assignment was
touched, and the digest says so rather than asking to be believed.

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
/content   /reload                           # dev-only, in Telegram: inspect and hot-swap
swift run roi-content validate --strict      # content integrity; exit 1 on any error
swift run -c release roi-content simulate   # balance sweep; --runs/--seed/--levels, --strict gates
swift run RestOfIryna --content-digest       # confirm ONLY the intended change moved
swift test                                   # 192 tests, ~0.14s
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
localization (955 / 976 keys). Auth is still gated to 4 hardcoded TG IDs.

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
