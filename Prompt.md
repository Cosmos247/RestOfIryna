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

### Where things stand right now (2026-09-16, after the 00:32 deploy)

| | |
|---|---|
| working tree | clean |
| HEAD | **this commit** — a Profile key on the walk keyboard, and the seller finally learns who bought the lot |
| pushed | **no** — `origin/main` is three commits behind. Push is user-side |
| running on the Pi | **`201f093`** — **three commits behind** — schema v12, content hash `b1a1af00`, digest `records a5eca6451d8f6236` · `tuning 43b809a87450a3b8` · `spawns c9bdb57d456adc26` · `quests 30de20902006e3b9`, restarted **2026-09-16 00:32** with all four migrations applied and verified against the tables |
| committed but NOT deployed | **three commits** — `dc5f037` (two ladders + the bag's Turn back button), `5e55139` (the kitchen repair) and this one |

**A deploy is waiting, and `/reload` cannot carry any of it.** `dc5f037` moves `plots.json`
and `bags.json` — which the hot swap could take on its own — but all three commits also move
Swift, and two of them move **locale strings**, which are not hot-reloaded at all. Binary,
content and Lingo have to land together: pull, build, `pm2 restart ROI`. **No migration, no
schema bump — v12 stands.** The 09-16 00:32 restart's four migrations are history, not
something these commits repeat. What is still waiting besides this is a human opening the
screens.

**Before ever claiming what is live, read it off the Pi.** On 2026-09-16 a patch note for
the testers listed three already-shipped commits as new, because every doc here said the Pi
still ran `aa18f57` while it had taken `6e3c18e` two days earlier. A deploy is the one fact
nothing writes down by itself. Four read-only commands, none of which touch the bot or the
database, are in auto-memory `feedback-ask-the-machine-not-the-record`.

### What the 09-16 deploy carried

`78393aa` the Mine on one clock + the plot card · `c9ec209` depth banked on arrival and the
forest's back door closed · `42e8818` the Master's repair list + `GearState` on the warehouse
· `b32ac32` the escape ceiling · `7469715` coins on the ground. **None of it has been opened
by a human**, which is the next action.

Each one's account — what it changed, why, and its `validate` / `simulate` / `swift test` /
digest block — is the **Commit index** at the top of `.memory/sessions.md` plus the dated
entry under it. The rules they produced are in `CLAUDE.md`; the reasons are in the
auto-memories `project-plot-streams-and-dead-lore`, `project-depth-is-banked-on-arrival`,
`project-gear-state-travels-with-the-unit`, `project-flee-has-a-ceiling`,
`feedback-no-monster-silver` (§where the line actually is).

### Next action: walk it. Nothing below has been looked at.
>
> **Every surface listed here is live and unopened by a human.** The Pi took the tip on
> 2026-09-16 00:32, so nothing below waits on a deploy — it waits on someone looking. Every
> defect this project has found came from glancing at a screen, not from running anything,
> so this list is the highest-yield thing available and it costs one session in Telegram.
> It is also the whole backlog.
>
> **Added 2026-09-16 part 2 — NOT deployed:**
> - **walk into the forest and tap 👤 Профіль.** It must open over the walk screen, and the
>   step buttons must still work underneath. Then 📓 Нотатник → switch a leaderboard tab →
>   🔙 back → step forward. Every one of those taps was silent before: the profile's buttons
>   answered nothing at all on the trail, so they spun forever.
> - **sell something on the market and wait for it to sell.** The push must now name the
>   buyer: «Ваш лот продано: … Купує <нік>. Срібло зараховано.»
>
> **Added 2026-09-16 — NOT deployed. Walk after the restart; two came from players:**
> - **cook with a full bag.** It must now cook and say «— сумка повна, тож на склад 📦»,
>   and the dish must really be in the warehouse. Before this the button spun forever and
>   the ingredients were eaten. The worst case to try is the one that broke: ingredients on
>   the WAREHOUSE, bag at exactly its cap, and a dish you already own a portion of.
> - **fill the warehouse too, then cook.** One modal: «🎒 Сумка і 📦 склад повні» — and
>   nothing may be consumed. Check the ingredient count is unchanged afterwards.
> - **open any recipe.** Every ingredient line must carry ✅/❌ and «маєте N», where N is
>   bag + warehouse TOGETHER. Cook once without leaving the screen: the numbers must tick
>   down in place.
> - **a recipe you cannot afford.** The ❌ lines must match what the shortage modal says if
>   you tap Cook anyway — they are the same reading now, so a disagreement is a real bug.
> - **the ladders from `dc5f037`** — a farm at 2/год, єм 10 filling in 5 h, and the bag
>   upgrade screen quoting **+15** at both of the top two steps (T6 now 90).
> - **turn back from inside the bag.** Travel to the capital, open 🎒 Сумка, tap
>   «↩️ Розвернутись». It must turn you around, not redraw the bag.
>
> **Added 2026-09-15 part 5 — LIVE since the 09-16 00:32 deploy, never walked:**
> - **claim a slot and read the Mine's line.** It must now be two lines: «Річкова галька,
>   8/год, єм 40» and «і 🔩 Шматок заліза, 2/год, єм 10» — «єм», not «cap», and «8/год»
>   with no space.
> - **let a Mine fill (5 h).** Both numbers must cap together now, `40/40 🪨 · 10/10 🔩`,
>   and the notification must name both.
> - **let a Курник fill.** It must read «Курник (слот N) заповнений» — masculine. Three of
>   the four plots are feminine, which is why this read wrong for months without anyone
>   noticing.
> - **collect 10 iron and check the forge** — a full Mine should be exactly one Залізний
>   злиток.
> - **read the plot picker.** Every type must now carry its lore under the numbers, the
>   Mine's must mention iron, and the Training Ground's blurb must have moved onto its own
>   line like everyone else's.
> - **tap a claimed slot, full and empty.** Both must open a card — «⛏ Ділянка 3 · Шахта»,
>   the lore, then each stream against its ceiling. Empty shows «💤 Ще нічого не
>   накопичилось» and only [🔙 До ділянок]; full also shows the two destinations, and
>   collecting must still land you on the plot list with the usual ✅ banner. This replaces
>   the old «Куди покласти?» screen, so it is the change most likely to be felt.
>
> **Added 2026-09-15 part 4 — LIVE since 09-16 00:32. The board IS zeroed; that is the migration, not a bug:**
> - **the depth board is empty after the deploy.** 🌲 Глибина must read «Поки порожньо» for
>   everyone — `ResetDeepestKm` zeroed it. 🚶 Шлях must be UNTOUCHED: if that one is empty
>   too, the wrong column was reset.
> - **walk out and back, then look at 🌲.** It should show the deepest km of that run, and
>   only after you are home — check it is still «порожньо» while you are standing in the
>   forest.
> - **die in the forest on purpose, deeper than your record.** The board must not move.
>   Then walk a shallow run home: it must not LOWER what you already earned either.
> - **type `/start` while walking, and again inside a fight.** Both must redraw the screen
>   you are on — not drop you at the manor. This was a free exit from any depth and is the
>   change most likely to be felt as a regression, so it is worth trying the way a stuck
>   player would.
> - **a passive run that kills nothing.** Its depth must still bank — the only save on that
>   path used to be conditional on XP.
>
> **Added 2026-09-15 part 3 — LIVE since 09-16 00:32, never walked:**
> - **take the weapon OFF, then visit the Master.** The repair line for it must still be
>   there, named by the item («Мисливський довгий лук · 0/100») rather than by the verb;
>   put it back on and the verb («🏹 Перетягнути тятиву») returns. Both must repair.
> - **take off a WORN-DOWN piece of armour** (equipped gear cannot be stored), **deposit it
>   in the warehouse and withdraw it again.** It must come back in the condition it went in
>   — same `x/y`, same `+N` enchant. Before this it came back 30/30 with the enchant gone,
>   which was a free repair and the reason to check it first on a piece you do not mind.
> - **verify the columns**, not the log line: `tier` · `durability` · `max_durability` ·
>   `enchant_level` must exist on `warehouse`.
>
> **Added 2026-09-15 — LIVE since 09-16 00:32, never walked. Walk it FIRST:**
> - **fail a flee four times on a warrior.** The fifth attempt must always work, whatever
>   the enemy. 40% means four failures happen in 13% of escapes, so this is reachable in a
>   session rather than a curiosity — tap Flee at a beast you can survive and count. The
>   player is told nothing, so what you are checking is that the fifth tap ends the fight.
> - **check the counter does NOT carry between fights.** Fail twice, escape, walk into the
>   next encounter and fail there: the second fight must start its own count from zero.
>
> **Added 2026-09-14 — LIVE since the 09-14 22:14 restart, walkable today, never walked:**
> - **km 1 and km 2.** A new character should now meet 🐍 Гадюка or 🦅 Беркут, never a
>   boar, and the boar should first appear at km 2. Check the eagle actually feels like the
>   spiky one — its contract is 28% of the bar and it measured 28% median / 47% p90 / 72%
>   p99 against a real armourless level-1 player. Two bad eagles in a row can kill.
> - **the two new mobs drop nothing.** That is deliberate, not a bug; the loot line should
>   simply be absent.
> - **a defeat message with a feminine enemy** — «🐈‍⬛ Скажена рись проламує ваш захист».
>   It read «прорвав» until now.
> - **the deep half of the forest is a different game now.** Every creature from km 7 down
>   was re-solved; the lynx gained 45% HP and the rabid bear 33%. Four accounts are
>   mid-progression around level 10 and will feel it immediately. The ledger says a level
>   1–3 character can no longer hold km 10 (88% win, was 95%) — km 7 is the new edge.
>
> **Added 2026-09-12 — live, never walked:**
> - **the four boards** — Profile → 📓 Нотатник → 🏆 Рейтинги. ⚔️ Рівень and 🎖 Честь have
>   data from the first second; 🌲 Глибина and 🚶 Шлях read "порожньо" until somebody walks,
>   because the counters started at zero (no depth record was ever stored to backfill from).
>   Walk one km and they should both come alive. Check the tabs redraw ONE message.
> - **the honor ladder on TWO screens** — the journal's 🎖 board and the Arena's own
>   «Найкращі бійці» now render from the same `LeaderboardService`. They must agree, ties
>   included; they did not before 2026-09-12.
> - **a starving step** — walk Vigor to 0. The root and the hunger tick must print on
>   SEPARATE lines now. Also check a starving step that finds loot, and one that starts a
>   fight: both used to take HP and say nothing at all.
>
> **From the older list, still never walked:**
> - **the forest on the way home** — the return leg should be noticeably more fight-heavy
>   than the walk out (8.8 fights over 17 km against 3.4 before). Walk to km 15–18 and back
>   on foot. With a full bag and low HP this is a real risk: death still wipes the bag.
> - **the road** — turn back twice in a row; the second should quote most of the crossing
>   (~`1хв 58сек`), not five seconds.
> - **the character sheet and any Forester piece** — three rating stats with no `%`, and a
>   `❤️ Здоров'я` line on armour that was invisible before.
> - **a fight lost, a flee, the trade screens**, and one run of **`/reload` + `/content`**
>   against a real database — `/reload` has still never run against one.
>
> **The API-error question is CLOSED.** `Code: 400` stood at **913** before the `editScreen`
> deploy, 913 an hour after, 913 after the 09-12 restart and **913 after the 09-16 one**. The
> only `[SCREEN]` lines in the whole log are **8 `StreamClosed` redraw failures dated
> 09-15** — HTTP/2 transport, not screen logic — and none appeared after the restart. If a
> new screen bug is ever reported, this is the cheap first look:
>
> ```
> ssh rpi5@192.168.0.203 'grep -c "^Code: 400" ~/.pm2/logs/ROI-out.log'   # baseline 913
> ssh rpi5@192.168.0.203 'grep -E "\[ROUTE\]|\[COMBAT\]|\[SCREEN\]" ~/.pm2/logs/ROI-out.log'
> ```
>
> **Deploying to the Pi:** `git push` — user-side, never you — then on the Pi
> `git pull --ff-only`, build, and **ASK before `pm2 restart ROI`**. A content or schema
> change must ship the new `content/data` and the new binary TOGETHER. Free pre-flight that
> touches neither the running bot nor the database:
> `ROI_PROJECT_PATH=/home/rpi5/RestOfIryna ./.build/debug/RestOfIryna --content-digest`.
> **After a migration, verify the TABLE, not the log line.** The two traps that cost real
> time — swiftenv's `PATH` living in `.bashrc`, and `pgrep -f` matching its own ssh command
> — are in auto-memory `project-pi-deploy-swiftenv`, `linux-build-gap`.

### Open, decided but not done

- **The estate calls one place three words.** «Слот» in the plot-list rows, «наділів» in the
  picker's Back button, «Ділянка» in the list title and the new slot card. The user leans to
  «ділянка»; unifying is ~6 locale keys in two files and no code. Raised 2026-09-16, left
  open on purpose rather than folded into an unrelated commit.
- **Six dead functions from April**, none touched since: `renderStub`,
  `backToRootKeyboard`, `backToHomeKeyboard` (EstateController), `itemNameOrId`
  (ExplorationController), `isPassiveInflight` (ExplorationState), `invalidateCache` (User).
  Found by the 09-16 sweep; deleting them is a standalone cleanup, not part of any feature.
- **The standing deferrals below** — flat food portions, the level 21–40 unlock gap, no
  estate at levels 1–3, seven `roster_off_curve` warnings and `opening.vigor_bankrupt` —
  are all reported by every `simulate` run and all deliberate.

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
against a pool that grows** (33% of a level-1 pool, 12% of a level-40 one),
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
from level 1 to 40, **117–129 days** on a tended estate (warrior 128.7 / archer 124.0 / mage
116.6 — it was 157–173 until the farm was doubled to 2/h cap 10 on 2026-09-16, and 78–87
before the 09-14 XP halving; the band the report gates on is 72–200, and taps/day went 513 →
690 with the same edit). `EnemyGenerator` is what the
post-rebalance regeneration will lean on — run at design time and frozen, never at runtime.
What each phase taught: `.memory/rebalance.md`.

**Current digest baseline (2026-09-16, schema v12):** `records 14d4fdd6442626ae` ·
`tuning 43b809a87450a3b8` · `spawns c9bdb57d456adc26` · `quests 30de20902006e3b9`. The
`records` half moved twice in one sitting — the farm's rate and cap, then the bag ladder's
top two steps — and the other three did not move at all, which is the whole point of
splitting them. **Until the Pi is restarted it will still report `a5eca6451d8f6236`**: that
disagreement is the undeployed commit, not a fault. **This
is the one place the baseline is kept** — `.memory/status.md` quotes it, and
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
swift run roi-content spec <table>           # progression · gates · bestiary · items · sets · economy · opening
swift run RestOfIryna --content-digest       # confirm ONLY the intended change moved
swift test                                   # 248 tests, ~0.2s
```

## What Works Now (shipped game)

Registration · exploration (active + passive, three-tier visit decay, restart-safe
scheduler) · turn-based PvE combat with 9 class techniques · estate (plots, warehouse,
workshop, kitchen, weapon/bag/estate upgrades, technique gates) · capital hub (travel,
Trader, Tavern, Fortune Teller, Master, player Market, synchronous Trade) · Guilds · Arena
(live PvP duel, Honor ELO, stakes, daily budget) · daily NPC quests **taken by hand at the
NPC** + journal · **four all-time leaderboards** behind that journal, as tabs redrawing one
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
| `content/spec/` | The five approved specifications (Phase 9, closed) |

## Rules

`CLAUDE.md` is the full set and is loaded every session. The three that cost the most when
forgotten: **never push** (user-side only), **never start / restart / stop the bot without
asking** (the Mac instance is the one exception — stop it, it 409s the Pi), and **ask before
committing**. Content edits must pass `roi-content validate --strict`; balance-table edits
must also re-run `roi-content simulate --strict`.
