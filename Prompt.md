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

**Phases 3–8 are done, 8D and 8E included. Phase 9 is IN FLIGHT — content
specifications, approved before a byte of content is authored. Two of five are
signed off (`content/spec/spec-progression.md`, `spec-bestiary.md`); items, sets
and economy remain.**

The rule the phase runs on: **numbers are printed, never typed.**
`roi-content spec <progression|gates|bestiary|items>` emits every table from the
code that owns the maths, so a specification cannot drift from the generator it
feeds — and that command is the seed of Phase 10's generator.

What the two approved documents decided: the **authored band is levels 1–25**
(not 1–15 — that was 1.3% of the climb); **no new creatures**, the seven that
exist are re-spread instead (boar 1, moose 4, bison 7, lynx 10, wolf 13, bear 16,
rabid bear 22); **the boss stays unmembered** until the game has been played;
**nothing new unlocks between 21 and 40** and that is deferred on purpose; and
the three zone systems are reconciled to **Гущавина 1–10 / Старий ліс 11–25 /
Пуща 26–49**, already applied to `zones.json` and `lore.md`.

The rule that had always been true and was never written down: **an enemy of
level N spawns from km N to km N+9**, so at km K a player meets levels K−9…K.
Depth is the difficulty dial, and the player's hand is on it.

Phase 8E removed passive Vigor regeneration entirely (2026-08-31). The trickle
did not pause during an expedition — `VigorService.regenTick`'s own comment
argued for that — so a player could stand at km 25, wait six hours and refill:
there was no depth gate, only patience. Vigor now comes from food, quests and
levelling; the pool is a stock and **the estate is the income**, which is what
finally makes it load-bearing.

`FoodBudget` in `ROISim` measures that income by enumerating every plot layout
the slots allow and cooking each one out, so the pace number reads off content
rather than an assumed mix:

```
level  estate  slots  vigor/day  portions  best mix
1      T1      0      0          0         — nothing cleared yet   (a feature)
7      T3      2      210        30        coop + coop
19     T7      6      810        90        farm ×5 + forest
```

The food plots were cut (farm 4/h cap 20 → 1/h cap 6, coop 2/h cap 12 → 1/h
cap 5) to land the pace at **85–93 days of perfect play** — slower than the old
51–56 on purpose, so "3+ months" sits in the figure instead of in an assumption
about imperfect play. Taps fell from 1,211/day to 513 on the way.

Two things the report flags every run and nobody has fixed, both deliberate:
**food portions are flat against a pool that grows** (33% of a level-1 pool, 12%
of a level-40 one — deferred with batch cooking to after the rebalance), and
**levels 1–3 have no estate at all** (the first days are lived off the trail).

`zones.json` landed with it: the foraging pools left `ExplorationService`, the
last content in Swift. Proved equivalent by replaying the shipped arrays out of
git for km 1–40 — identical including weights and order.

#### What Phase 9 has to answer

The simulator already named the content gaps, so the spec is not starting from a
blank page:

- **The bestiary is half-strength.** Every shipped enemy carries ~50% of the HP
  and ATK its archetype asks for (62% at level 1, falling to 48% by level 25), so
  all seven are a 100% win at 4–13% HP where the archetype asks 10–62%.
  `EnemyGenerator` regenerates the table from the archetype targets — that is
  Phase 10's job, and it needs a roster list first.
- **km 31–40 holds a single elite**, the `boss` archetype has **no members**, and
  `offHand` plus both accessory slots have **no items at all** (1.0 + 1.2 of slot
  weight sitting idle — it is exactly the residual the reference character prints).
Three of the gaps this list used to carry are closed. **The foraging pools are
in `zones.json`** as of 8E, so no content is left in Swift. **The elite floor is
enforced**: every archetype row carries a required `minLevel` and elite/boss are
14, so the generator cannot emit the fight that made the mage's level-5 elite a
93% win. And **the last two flat rating bonuses are multipliers** — Shadow Veil
dodge ×2.0, the archer's Defend ×1.5, both worth the same points of dodge chance
at level 1 and at level 40.

#### What Phase 8 left behind (the tools Phase 9+ leans on)

`swift run -c release roi-content simulate` rolls the SAME `CombatMath` the bot
calls — the maths lives in `ROISim` and `CombatService` / `User` / `ItemBudget` /
`VigorService` are façades over it, so a report cannot drift from the game. It
sweeps levels × archetypes × classes × play profiles × gear offsets and bands
level invariance, the p90 tail, win rates, pace to the cap, and the shipped
roster against its archetype contract. `--strict` exits 1 on a broken band.

Current state of those bands: **18 of 18 level-invariance rows pass, 0 broken
bands, 7 warnings** — all seven the half-strength roster. 19,437,688 XP from
level 1 to 40, and **85–93 days** on a tended estate — an estimate between two
opposing simplifications (every point spent on combat, but nothing except the
estate feeding the player) rather than the floor the old number was.

The default sample size is **8000 fights per cell** (2.6s for the sweep). It was
2000 until Phase 8D, where the level-invariance band — a ±15% ratio of two
means — turned out to cross on sampling noise alone, so `--strict` was failing
the build on a row that reads ×1.13 at 8000 and ×1.16 at 2000 from the same seed.

`EnemyGenerator` is the piece Phase 10 will lean on hardest: the archetype table
is a GENERATOR, and inverting its targets reproduces every shipped enemy's DEF,
crit and dodge to within rounding. Run at design time and frozen — never at
runtime, which is how gear upgrades evaporate.

#### The model, compressed

```
budget(itemLevel, slot, rarity) = slotWeight · (6.0 + 1.5·itemLevel) · rarityBudget
```

Every stat an item carries is that budget spent at fixed exchange rates, and the
combat denominators were derived from the same curve — so an item that respects
its budget cannot move any stat's percentage. Rarity multiplies budget ×1.00→×1.45
while value goes ×1→×16 (decoupled on purpose). Enchant is `1 + 4% × level` of the
item's OWN budget, capped at +20%. Sets grant thresholds at 2/4/6 pieces. Gear
carries HP as a sixth stat.

**Nothing gets a flat bonus — items or techniques.** Phase 8C found two of the
three Super stances still granting flat lifts that rotted across a lifetime
(`hawks_eye` +115% crit at level 1, +21% at the cap; `bloodlust` charging double
Vigor for +5%). All five stance lifts are multipliers of the character's own stat
now, and the report audits every lift for it.

`/reload` and `/content` (dev-only) hot-swap the bundle in **parse → validate →
live-check → build → install** order, where `install` is the only infallible step
and last — a refused reload leaves the running game on exactly the snapshot it
was serving. Lingo is NOT reloaded; new strings still need a restart.

**Current digest baseline: `e004ea8d93ba32b9`** (schema **v10**)
(`records 992c19419d162379` · `tuning 3ef097038094a4d8` ·
`spawns 1a18e0cd09136c69` · `quests 2e52ecdfa45276ec`). Phase 9 moved `spawns`
alone, when the foraging bands were realigned — no selection logic or daily assignment was
touched, and the digest says so rather than asking to be believed.

⚠️ **No live Telegram pass since the rebalance began.** Every formula the player
touches changed in Phase 5, every item's stat in Phase 6, the stances plus the
failed-Flee counter in Phase 8C, Shadow Veil plus the archer's Defend in 8D, and
the whole Vigor economy in 8E.
`/reload` itself has never run against a real database.

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
swift run -c release roi-content simulate    # balance sweep; --runs/--seed/--levels, --strict gates
swift run RestOfIryna --content-digest       # confirm ONLY the intended change moved
swift test                                   # 222 tests, ~0.14s
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
| `Modules/ROISim/CombatMath.swift` | The combat model itself. `CombatService` delegates here — add a roll THERE, never a second copy |
| `Modules/ROISim/BalanceFormatter.swift` | The report and its acceptance bands — what fails a build and what is only printed |

## Rules

- After significant work update `.memory/sessions.md`, `.memory/status.md` and `TODO.md`
- Ask before committing; short compact messages, no co-author line
- **Never push** — manual/user-side only
- New locale keys go in BOTH `en.json` and `uk.json`; uk gendered copy uses `.m`/`.f`
- Telegram `callback_data` max 64 bytes
- Content changes: `roi-content validate --strict` must pass before commit
- Balance-table changes (`combat` / `progression` / `budget` / archetypes): re-run
  `roi-content simulate --strict` too — the digest says what moved, the simulator
  says whether it is survivable
- Hand-edit `content/data/*.json` in the Swift `JSONEncoder` style already there
  (`"key" : value`, keys sorted, 2-space indent) — a python-style re-emit reformats
  every line and buries the real change
