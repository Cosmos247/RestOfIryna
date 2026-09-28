# ROI Session Primer

Read this first, then `.memory/INDEX.md`. For the active work read
`.memory/rebalance.md` and `.memory/content-pipeline.md` — everything else in
this file is background.

## What Is This

**Rest Of Iryna (ROI)** — a multiplayer medieval text RPG Telegram bot in Swift.
Players fight rabid beasts, manage estates, trade, and duel. All interaction via
text + emoji + inline keyboards.

## Stack

Swift 6.2 (strict concurrency) | Hummingbird 2.22+ | Fluent 4.13+ / PostgreSQL 15 |
swift-telegram-sdk 4.6+ | AsyncHTTPClient | Lingo 4 (i18n) | SwiftDotenv

Router–controller state machine; game code in `Swift/`, the pipeline in `Modules/`, never
`Sources/`. Both stated in full in `CLAUDE.md`; the dependency table with exact version
pins is `.memory/tech-stack.md`.

## ⏳ ACTIVE WORK — live-play polish, and small features on top

**The pre-release rebalance is DONE and deployed.** Phases 3–11 all landed; Phase 11
closed as CODE on 2026-09-09. Its decisions and calibrated maths are history worth
reading, not work in flight: `.memory/rebalance.md`.

What is in flight is **fixing what playing the deployed build reveals**, plus the
occasional small feature the play surfaces a need for. Every defect so far came from
someone PLAYING; none from a test.

- Tracker: the "Full Rebalance" section of `TODO.md` (its tail is the polish log)
- Rebalance decisions + calibrated math: `.memory/rebalance.md`
- Pipeline rules: `.memory/content-pipeline.md`

### Where things stand right now (2026-09-27; `origin/main` is at `60a8bad`)

| | |
|---|---|
| working tree | clean |
| HEAD | **`ada1ae7`** — the workshop stops making armour (the Master is the only source; the Forester recipes stay as patterns for salvage). Under it `2689764`, the hash fill for `1b10572` — techniques trimmed to one target, every technique tap strikes, a `fight_log`, and the King's chain asking for the estate first (three migrations) — then the 09-27 sync pass, `bd25699` (the hash fill for `1d1fec4`, the Training Ground as a house room), `d1e2ccd` (combat lines and the death screen), `df6d341` (the workshop's «Розібрати» and gear lists by row), `254967b` (the stray-number hint), each with its hash fill, and `60a8bad`, the last deploy. **A commit cannot carry its own hash**, so this line always trails by one; read HEAD off the machine |
| pushed | `origin/main` is at **`60a8bad`**; everything after it is **unpushed** — three 09-22 record passes, the six 2026-09-27 game changes and the 09-28 one, with their hash fills, and the sync pass. Push stays user-side |
| running on the Pi | **`60a8bad`**, restarted **2026-09-22 00:33** (a locale-only follow-up to the 00:22 deploy that carried everything else); the Pi itself **rebooted 2026-09-25 20:45** and pm2 brought ROI back on the same binary, built 09-22 00:20 (read off the machine 09-27) — schema **v13**, content hash `703a0404`, digest `records 6588329ab2bdbc70` · `tuning 43b809a87450a3b8` · `spawns c9bdb57d456adc26` · `quests 30de20902006e3b9` · `king 4326bb40aa735a50` (matched the Mac byte for byte BEFORE the restart was ordered, which is the order the decision has to happen in). **Read it off the machine before acting on this line** (auto-memory `feedback-ask-the-machine-not-the-record`) |
| committed but NOT deployed | **Seven game changes, 2026-09-27 and 09-28** — (1) a number typed before its button gets a `🔢` hint instead of the root screen; (2) the workshop's 🔨 «Розібрати» (recipe × `gear.salvageFraction` × max/30) and gear lists that act on the ROW; (3) attack lines that end «X втрачає N ОЗ» and name a crit, and a death screen with the last round, the enemy's HP left and the loss by name; (4) **the Training Ground as a house room** — T4, 150 / 400 / 800 🪙 + materials, one technique per level (10 / 11 / 14), catch-up for techniques already known; (5) **the technique rework** — a stance's tap strikes, every special defence strikes back, no technique blow above an ordinary crit (Vital Shot ×1.5), the kit tuned to ~20% off an elite fight for every class, and a `fight_log` row per forest fight; (6) **the King's chain asks for the estate before the Training Ground** — «Зрілість» and «Третя сходинка» moved ahead of «Наука бою» / «Перший прийом», both lifted 9 → 10; (7) **the workshop no longer makes armour** (09-28) — the Master is the only source, the Forester recipes kept as patterns for salvage. **Schema v14 and five migrations** (`AddTrainingGroundLevel`, `MoveTrainingGroundOffPlots`, `CreateFightLog`, `AddCombatTally`, `RewalkReorderedDecrees`) plus new Lingo strings: content and binary together, then `pm2 restart ROI` — `/reload` cannot carry it |

**Everything before 2026-09-27 is deployed.** Two restarts on 2026-09-22 took the whole backlog: 00:22
carried fourteen commits (`536fbf6` → `1faaddb`) — the capital street split, the quest
carry-over and the King's decree chain end to end — and 00:33 followed with a locale-only
pass for the two street descriptions. Three migrations ran at 00:22: `CloseBurnedQuestJobs`
(**36 of 39** open jobs closed, verified on the table, not the log line), `AddCapitalStreet`
and `CreateKingProgress`. The chain was live within minutes — a player had turned the first
decree in before the deploy entry was written.

Every deploy's hashes, what each carried and its verification block: the **Commit index** at
the top of `.memory/sessions.md`, with a dated `## Deploy —` entry for each restart.

### Next action

**1 — Deploy the seven 2026-09-27/28 changes** (user-side from the push on). `git push`, then on the
Pi `git pull --ff-only` and build; its `--content-digest` must read **`records
33e5c6e3259d51ba` · `tuning fe05ceaa38e03c6b` · `spawns c9bdb57d456adc26` · `quests
30de20902006e3b9` · `king 5dbddfd689f3cede`, content hash `490a2d4b`** BEFORE the restart is
ordered. After `pm2 restart ROI`, verify the TABLES: `SELECT count(*) FROM plots WHERE
plot_type = 'training_ground'` is 0, `users.training_ground_level` exists at 0 for every row,
`fight_log` exists and gains a row when a forest fight ends, `exploration_state.combat_tally`
exists, and `SELECT count(*) FROM king_progress WHERE decree_index BETWEEN 23 AND 25` is 0.
**Do not boot this build on the Mac first**: the Mac reaches the Pi's database through the
tunnel, so its first boot would run all five migrations — `RewalkReorderedDecrees` included —
while the Pi still serves the old decree order.
Then record the deploy (Commit index + a `## Deploy —` entry in `.memory/sessions.md`).

**2 — Someone opens the screens.** Every defect this project has found came from glancing at a
screen, not from running anything. **`TODO.md` → "Walk list"**: the six 2026-09-27/28 blocks sit
on top (the workshop without armour; the technique rework; the Training Ground build and catch-up, with the decree reorder;
salvage and the gear rows; the stray-number hint; combat lines and the death screen), then the
older backlog — the whole King's chain included, which no human has seen.

**3 — Decisions waiting on the owner**, all in `TODO.md` → "Open, decided but not done": the
four lines that put an enemy's name in an oblique case; the kit still costing more Vigor than
plain attacks (+35 / +16 / +36% on an elite, prices untouched); a mage winning a fight at 0 HP
(the burn ticks before the player's death check); `/menu` missing from the base `unmatched`
filter.
Ideas raised and not asked yet: a «Відновити» service at the Master (reset max for silver, keep
the enchant — a silver sink), the Master refusing to mend a piece worn to 1/1, and the passive
report naming its losses the way the death screen now does.

**Deploying to the Pi:** `git push` — user-side, never you — then on the Pi
`git pull --ff-only`, build, and **ASK before `pm2 restart ROI`** (the rule in full:
`CLAUDE.md` § Running the bot). A content or schema change must ship the new `content/data`
and the new binary TOGETHER — the schema handshake is at **v14** (the Pi still runs v13) and refuses a mismatch.
Free pre-flight that touches neither the running bot nor the database:
`ROI_PROJECT_PATH=/home/rpi5/RestOfIryna ./.build/debug/RestOfIryna --content-digest`; match
it against the Mac BEFORE ordering the restart, which is the order the decision has to happen
in. **After a migration, verify the TABLE, not the log line.** The traps that cost real time —
swiftenv's `PATH` living in `.bashrc` (a non-interactive ssh needs
`export PATH="$HOME/.swiftenv/shims:$PATH"`), and `pgrep -f` matching its own ssh command —
are in auto-memory `project-pi-deploy-swiftenv`, `linux-build-gap`.

**The API-error question is CLOSED.** `Code: 400` has held at its **913** baseline across four
restarts, and the only `[SCREEN]` lines in the whole log are 8 `StreamClosed` redraw failures
dated 09-15 — HTTP/2 transport, not screen logic. The two log greps to run if a new screen bug
is ever reported are in auto-memory `feedback-ask-the-machine-not-the-record`, beside the four
that say what is actually live.

### Open, decided but not done

Ten items, each raised deliberately and kept out of an unrelated commit on purpose: the four
enemy-name lines in an oblique case, the kit's Vigor cost, a mage winning at 0 HP, and `/menu`
missing from the base `unmatched` filter (all four from 2026-09-27); the estate calling one
place **two** words now that «наділ» is gone but «Слот» still stands in 18 keys;
`InventoryEntry.remove` ignoring `equipped_slot`; `CapitalController.pushTradeInvite` discarding
its message id; the recipe-scroll machinery (`Item.teachesRecipe`,
`InventoryController.handleLearnRecipe`) kept unreachable on purpose; the Master's blade trial
naming a zone it does not mean; and six functions dead since April (`renderStub`,
`backToRootKeyboard`, `backToHomeKeyboard`, `itemNameOrId`, `isPassiveInflight`,
`invalidateCache`). Each one's reasoning: **`TODO.md` → "Open, decided but not done"**. The
standing simulator deferrals are below.

### Where the changelog went

Every commit from 2026-09-09 onward — hash, what it did, and the pattern behind it — is the
**Commit index** at the top of `.memory/sessions.md`, with a dated narrative entry for each
below it. This file no longer carries one, on purpose: it was the third copy.

### What the rebalance settled

The authored band is **levels 1–25**, an enemy of level N spawns **km N…N+9**, the zones are
**Гущавина 1–10 / Старий ліс 11–25 / Пуща 26–49**, and **no new items or sets** ship in this
release. Vigor does not regenerate (Phase 8E) — food, quests and the estate are the only
sources, and the estate is the intended income. The wardrobe sits at ~40% of the on-curve
budget and the bestiary at 65–78% of its archetype contract; **both half-strength errors
lean the same way**, so the gear ladder and a roster re-solve ship together, afterwards.

The debt Phase 9 wrote itself is paid, and its finding is now **`opening.vigor_bankrupt`**.
Read the current ledger from `roi-content spec opening -c release`, never from a doc.

The rule all five specifications run on: **numbers are printed, never typed** — and the
corollary learned the hard way, **the rule protects tables, not the prose beside them**.

Decisions, the calibrated math model, the phase tracker and the per-phase lessons:
`.memory/rebalance.md`. Auto-memory `project-world-ladder`,
`project-vigor-no-passive-regen`, `project-opening-is-vigor-bankrupt`,
`project-post-rebalance-package`, `feedback-printed-numbers-protect-tables-not-prose`.

#### Standing deferrals

Reported by every `simulate` run, all deliberate: **food portions are flat
against a pool that grows** (the Feast is 69% of a level-1 pool and 24% of a
level-40 one since the 09-18 repricing, up from 33% / 12%),
**nothing new unlocks between level 21 and 40**, **levels 1–3 have no estate at
all**, the **seven `content.roster_off_curve` warnings** (until the regeneration
package lands), and **`opening.vigor_bankrupt`** — renamed from
`opening.shallow_is_bankrupt` when the XP halving removed the last depth that was both
survivable and profitable; a warning and not a broken band on purpose, because §7 decided
to measure before retuning. Silver is also **over-supplied** — roughly twenty
thousand spare over a lifetime against 2,950 of mandatory spend (the estate's 1,600 plus the
Training Ground's 1,350 since 2026-09-27) — and the fix is
more to buy, which is items, which is after the rebalance.

#### The simulator, and what it currently says

`swift run -c release roi-content simulate` rolls the SAME `CombatMath` the bot calls, so a
report cannot drift from the game. It sweeps levels × archetypes × classes × play profiles ×
gear offsets and bands level invariance, the p90 tail, win rates, pace to the cap and the
shipped roster against its archetype contract; `--strict` exits 1 on a broken band. Default
sample size **8000 fights per cell** — 2000 crossed the invariance band on sampling noise alone.

Current state: **18 of 18 invariance rows pass, 0 broken bands, 12 warnings**, 19,437,688 XP
from level 1 to 40, **114–126 days** on a tended estate (warrior 125.5 / archer 120.9 / mage
113.8 after the 09-18 food repricing; the band the report gates on is 72–200, taps/day 686).
That headline swung 128.7 → 122.4 → 110.0 → 125.5 across the 09-18 edits and **most of the
swing was not speed**: the model drops tiers that feed nothing out of the average, so making
the duck egg inedible and then edible again took T2 out and put it back. The real movement is
the estate being 11–15% richer on every tier above T2. `EnemyGenerator` is what the
post-rebalance regeneration will lean on — run at design time and frozen, never at runtime.
What each phase taught: `.memory/rebalance.md`.

**Current digest baseline (2026-09-27, schema v14):** `records 33e5c6e3259d51ba` ·
`tuning fe05ceaa38e03c6b` · `spawns c9bdb57d456adc26` · `quests 30de20902006e3b9` ·
`king 5dbddfd689f3cede`, content hash `490a2d4b`. Three lines moved on 09-27: `tuning` for
`gear.salvageFraction`, the special attack's floor 8 → 10 and then the technique rework's
five numbers (`11797ea73591e02f` → `fe05ceaa38e03c6b`), `records` for the Training
Ground ladder, `king` for «Наука бою»'s new condition and then the reorder that put the estate
before the ground (`08733a95f4d34e68` → `5dbddfd689f3cede`). **The Pi still runs the 09-22
baseline** (schema v13, `records 6588329ab2bdbc70` · `tuning 43b809a87450a3b8` · `king
4326bb40aa735a50`, hash `703a0404`) until these commits are deployed; its own
`--content-digest` must read the new line BEFORE the restart is ordered.

`king` is a fifth line, added with the decree chain, and the four older ones are
byte-identical across it — which is the entire point of splitting them. `records` moved four
times to get to its value (the farm ladder, the bag ladder, the food repricing, the
innkeeper's unlock rungs) and has not moved since. **This is the one place the baseline is
kept** — `.memory/status.md` quotes it, and `.memory/rebalance.md`'s figures are a Phase-11
record, not a current reading. A knob is invisible to the digest until it is hashed — add the
line in the same commit that adds the knob (auto-memory `feedback-digest-names-constants`).

HP regen is **10% of max HP per real minute** (`tuning/vigor.json` → `healing.regenPerMinute`),
so a full rest at the estate takes 10 minutes — and **only at the estate**. `simulate --strict`
stands at 0 broken bands / 12 warnings: the sweep models fights, not the rest between them.

⚠️ **Four accounts played 2026-09-02 → 09-09** and reached L10 / estate T4, so the
rebalanced formulas have been exercised — but nobody stepped through the first hour against
a checklist, and **`/reload` has still never run against a real database**. It is now the
cheapest way to ship a content edit, so it is worth proving early. Auto-memory
`first-playtest-happened`.

### How content works now

All 15 catalogs and all seven tuning tables are façades over a snapshot installed at boot:

```
content/data/*.json → ContentLoader → ContentValidator → GameContent (DTOs)
                                                       → DomainContent → Catalogs.current
```

`ContentBootstrap.load` runs in `configure` **before the database block**, and **no
`static let` anywhere may reference a catalog**. The migration loop, the verification
layers and every gotcha: `.memory/content-pipeline.md`.

### Running locally (rare now — the Pi is production)

Only to debug against the live database from the Mac. **Stop the Pi's instance first** —
the same token sits in both `.env` files, so two pollers means a 409 — and kill
`debugserver` before the process, since a crashed Xcode run survives `kill -9` while the
debugger traces it. The three commands, the `S`/`N` handshake probe that proves more than
`nc -z`, and the full recovery order: auto-memory `roi-local-run-setup`.

### Commands

```
/content   /reload                           # dev-only, in Telegram: inspect and hot-swap
swift run roi-content validate --strict      # content integrity; exit 1 on any error
swift run -c release roi-content simulate    # balance sweep; --runs/--seed/--levels, --strict gates
swift run roi-content spec <table>           # progression · gates · bestiary · items · sets · economy · opening · king
swift run RestOfIryna --content-digest       # confirm ONLY the intended change moved
swift test                                   # 320 tests, ~0.3s
```

## What Works Now (shipped game)

**The King's decree chain** (2026-09-21, live since 09-22) — 39 decrees from level 1 to 25,
one open at a time, walked in `king.json`'s array order. The first arrives as the royal
charter right after registration; the open one is always visible read-only in the journal;
it is turned in at 👑 Палац, a `Location` on Замкова. Eleven of the eighteen condition kinds
are live state reads, seven are events funnelled through `KingService.record`. No screen
shows "decree N of 39". Spec `content/spec/king.md`, table `roi-content spec king`.

Registration · exploration (active + passive, three-tier visit decay, restart-safe
scheduler) · turn-based PvE combat with 9 class techniques · estate (plots, warehouse,
workshop, kitchen, weapon/bag/estate upgrades, technique gates) · capital hub (travel across
**two streets** — 👑 Замкова: Базар / Ристалище / Гільдії / Палац, 🏘 Поділ: Крамар / Майстер /
Шинок / Ворожка, the square holding only the two roads — plus
Trader, Tavern, Fortune Teller, Master, player Market, synchronous Trade) · Guilds · Arena
(live PvP duel, Honor ELO, stakes, daily budget) · daily NPC quests **taken by hand at the
NPC**, and since `328bf88` **a taken job never burns** — one open job per NPC, today's offer
waiting behind it, a carried one droppable — the innkeeper's also **teaches a cooking recipe**,
one rung of the ladder per finished job, announced nowhere in advance — + journal · **four all-time leaderboards** behind that journal, as tabs redrawing one
message. Every daily system keys off `GameDay` (rolls at **12:00 Kyiv**). EN + UK
localization. **Access is invite-only and lives in `allowed_users`**; `/link` mints a
five-minute deep link and nobody else gets a `User` row at all.

✅ `tuning/time.json` → `scale` is **1.0** (2026-09-09): game time is real time. Plot cycle
1 h, passive runs 30 / 60 / 90 min, a trip to the capital 2 min. Nothing under `realTime`
ever scaled. Key counts, per-feature detail and what is still planned:
`.memory/status.md`.

## Key Files

`.memory/file-map.md` is the canonical per-file annotation list — this table is only the
handful a fresh session reaches for first.

| File | What |
|------|------|
| `CLAUDE.md` | Conventions, patterns, git rules — read before writing code |
| `.memory/INDEX.md` | Knowledge base index |
| `.memory/rebalance.md` | Decisions, math model, phase tracker |
| `.memory/content-pipeline.md` | How content loading/validation/migration works |
| `TODO.md` | Phase tracker |
| `GDD.md` | Game design document (predates the rebalance — its numbers are intent, not truth) |
| `Swift/configure.swift` | Bootstrap; content loads before the DB block |
| `Swift/Helpers/ContentDigest.swift` | `--content-digest`: run before/after any content edit to confirm ONLY the intended change moved |
| `Modules/ROISim/CombatMath.swift` | The combat model itself. `CombatService` delegates here — add a roll THERE, never a second copy |
| `content/spec/` | The five approved specifications (Phase 9, closed) + `king.md` (the decree chain, 2026-09-21) |

## Rules

`CLAUDE.md` is the full set and is loaded every session. The three that cost the most when
forgotten: **never push** (user-side only), **never start / restart / stop the bot without
asking** (the Mac instance is the one exception — stop it, it 409s the Pi), and **ask before
committing**. Content edits must pass `roi-content validate --strict`; balance-table edits
must also re-run `roi-content simulate --strict`.
