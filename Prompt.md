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

### Where things stand right now (2026-09-21, five commits ahead of the Pi, three of them code)

| | |
|---|---|
| working tree | clean |
| HEAD | **`065bc6e`** — the King's decrees, content (`978eef7`) then playable (`520513e`: the palace, the engine and all seven event hooks; `ad09c74`: the journal and the charter), plus two locale renames and the hash fills. **A commit cannot carry its own hash**, so the newest entry here always trails by one; read HEAD off the machine |
| pushed | `origin/main` is at **`536fbf6`**; **everything after it is unpushed** — ten commits, of which four change the game: `328bf88`, `f57a6b9`, `978eef7`, `520513e`. Push is user-side |
| running on the Pi | **`536fbf6`**, restarted **2026-09-19 14:21** and still up — schema v12, content hash `0fa93e96`, digest `records 6588329ab2bdbc70` · `tuning 43b809a87450a3b8` · `spawns c9bdb57d456adc26` · `quests 30de20902006e3b9` (identical to the Mac). **Read it off the machine before acting on this line** (auto-memory `feedback-ask-the-machine-not-the-record`) |
| committed but NOT deployed | Three things now. **The capital street split** — 👑 Замкова / 🏘 Поділ, `AddCapitalStreet`, six keyboard rows down to three. **`328bf88`** — a taken job no longer burning at noon, plus the one-time `CloseBurnedQuestJobs`. **`978eef7` + `520513e`** — the King's decrees, first as content (**schema v13**) and then as a playable palace on Замкова, with the `CreateKingProgress` table behind it. **Three migrations in one restart** (only `CloseBurnedQuestJobs` writes existing data; the other two are additive), and **`/reload` carries none of it**: locale strings in the first two, and a schema bump in the third means the v12 binary on the Pi will refuse the new `content/data` until it is rebuilt |

**The 09-19 deploy cleared a backlog of ten commits**, so the whole walk list except its
newest block is live and waiting only on a human opening the screens.

**What is waiting now is `328bf88`, and it is not the same kind of deploy.** It carries the
**first data migration since `ResetDeepestKm`** — `CloseBurnedQuestJobs`, which closes the
taken-but-unfinished quest rows the old noon rule left behind (33 rows over 6 players; a dry
run on 09-19 data kept 9). Neither 09-19 commit moved `content/data`, but Swift and locale
strings did and Lingo is not hot-reloaded, so **`pm2 restart ROI` is the only way in** —
`/reload` carries none of it. After the restart, **verify the TABLE, not the log line**:

```
ssh rpi5@192.168.0.203 'cd ~/RestOfIryna && eval "$(grep -E "^DB_(HOST|PORT|USER|PASSWORD|NAME)=" .env | sed "s/^/export /")" && PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -At -c "SELECT day_stamp, npc, count(*) FROM quest_progress WHERE accepted AND NOT claimed GROUP BY 1,2 ORDER BY 1"'
```

### What the 09-19 deploy carried

Ten commits in one pull, `7050933` → `536fbf6`: six change the game, and four (`7050933`,
`e625320`, `99799e5`, `bcafef3`) are record passes. Before it the 09-17 00:10 deploy carried
`dc5f037` · `5e55139` · `6eefe85` · `b63f835`, and the 09-16 one `78393aa` · `c9ec209` ·
`42e8818` · `b32ac32` · `7469715`. **None of the three batches has been opened by a human.**

What each one changed, why, and its `validate` / `simulate` / `swift test` / digest block: the
**Commit index** at the top of `.memory/sessions.md`, which now carries every hash above.

### Next action: walk the game, then ship the two waiting commits

**Step one is someone opening the screens.** Every defect this project has found came from
glancing at a screen, not from running anything, so this is the highest-yield thing available
and it costs one session in Telegram. The backlog spans three deploys, the whole kitchen among
them, and none of it has been opened by a human. It is fourteen blocks grouped by what shipped
when, in **`TODO.md` → "Walk list — shipped surfaces nobody has opened"**. Everything in it
except the newest block is LIVE.

**Step two is shipping the two waiting commits** — push, pull, build, `pm2 restart ROI` (ask
first), then check the `quest_progress` TABLE with the query above, because `328bf88` migrates
data. `AddCapitalStreet` is additive and nullable: nothing to verify past the column existing,
and every existing player starts on the square. The two newest walk blocks are waiting on them.

**Deploying to the Pi:** `git push` — user-side, never you — then on the Pi
`git pull --ff-only`, build, and **ASK before `pm2 restart ROI`** (the rule in full:
`CLAUDE.md` § Running the bot). A content or schema change must ship the new `content/data`
and the new binary TOGETHER. Free pre-flight that touches neither the running bot nor the
database: `ROI_PROJECT_PATH=/home/rpi5/RestOfIryna ./.build/debug/RestOfIryna --content-digest`.
**After a migration, verify the TABLE, not the log line.** The two traps that cost real time —
swiftenv's `PATH` living in `.bashrc`, and `pgrep -f` matching its own ssh command — are in
auto-memory `project-pi-deploy-swiftenv`, `linux-build-gap`.

**The API-error question is CLOSED.** `Code: 400` has held at its **913** baseline across four
restarts, and the only `[SCREEN]` lines in the whole log are 8 `StreamClosed` redraw failures
dated 09-15 — HTTP/2 transport, not screen logic. The two log greps to run if a new screen bug
is ever reported are in auto-memory `feedback-ask-the-machine-not-the-record`, beside the four
that say what is actually live.

### Open, decided but not done

Six items, each raised deliberately and each kept out of an unrelated commit on purpose: the
estate calling one place three words; `InventoryEntry.remove` ignoring `equipped_slot`;
`CapitalController.pushTradeInvite` discarding its message id; the recipe-scroll machinery
(`Item.teachesRecipe`, `InventoryController.handleLearnRecipe`) kept unreachable on purpose;
the Master's blade trial naming a zone it does not mean; and six functions dead since April
(`renderStub`, `backToRootKeyboard`, `backToHomeKeyboard`, `itemNameOrId`,
`isPassiveInflight`, `invalidateCache`). Each one's reasoning: **`TODO.md` → "Open, decided
but not done"**. The standing simulator deferrals are below.
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
thousand spare over a lifetime against 1,600 of mandatory spend — and the fix is
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

**Current digest baseline (2026-09-21, schema v13):** `records 6588329ab2bdbc70` ·
`tuning 43b809a87450a3b8` · `spawns c9bdb57d456adc26` · `quests 30de20902006e3b9` ·
**`king 4326bb40aa735a50`** — a fifth line since the King's decree chain landed, and the
four older ones are byte-identical across it, which is the entire point of the split. The
content hash moved `0fa93e96` → `703a0404` (a new file) and the schema **v12 → v13**, so the
content directory and the binary must now ship together or the handshake refuses the boot. **The Pi has
run this exact baseline since the 09-19 14:21 restart** (content hash `0fa93e96`), matched byte
for byte before the restart was ordered, which is the order the decision has to happen in.
`records` moved four times to get here — the farm ladder, the bag ladder, then the whole food
repricing and the innkeeper's unlock rungs — while the other three have not moved once, which
is the entire point of splitting them. Neither 09-19 commit touched `content/data` at all. **This is the one place the baseline is kept** — `.memory/status.md` quotes it, and
`.memory/rebalance.md`'s figures are a Phase-11 record, not a current reading. A knob is
invisible to the digest until it is hashed — add the line in the same commit that adds the
knob (auto-memory `feedback-digest-names-constants`).

HP regen is **10% of max HP per real minute** (`tuning/vigor.json` → `healing.regenPerMinute`),
so a full rest at the estate takes 10 minutes — and **only at the estate**. `simulate --strict`
stands at 0 broken bands / 12 warnings: the sweep models fights, not the rest between them.

⚠️ **Four accounts played 2026-09-02 → 09-09** and reached L10 / estate T4, so the
rebalanced formulas have been exercised — but nobody stepped through the first hour against
a checklist, and **`/reload` has still never run against a real database**. It is now the
cheapest way to ship a content edit, so it is worth proving early. Auto-memory
`first-playtest-happened`.

### How content works now

All 13 catalogs and all seven tuning tables are façades over a snapshot installed at boot:

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
swift test                                   # 271 tests, ~0.2s
```

## What Works Now (shipped game)

Registration · exploration (active + passive, three-tier visit decay, restart-safe
scheduler) · turn-based PvE combat with 9 class techniques · estate (plots, warehouse,
workshop, kitchen, weapon/bag/estate upgrades, technique gates) · capital hub (travel,
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
