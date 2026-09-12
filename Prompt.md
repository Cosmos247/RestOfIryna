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

### Where we stopped (2026-09-12)

**Phases 3–11 are done. Phase 11 is closed as CODE** — the wipe, the opening ledger,
invite-only access, the Pi deployment and `scale` 1.0 all landed by 09-09. Since then the
work has been **live-play polish: fixing what playing the deployed build revealed.**

**The bot is LIVE on the Pi running `fea2343`** (restarted 2026-09-11 01:26, content hash
`4eac64ff`, **schema v11**), and the working tree is clean.

⚠️ **Two commits are UNPUSHED and are not on the Pi: `fd98632` and the 09-12 doc pass.**
Both are documentation only — no game code, no content, no schema — so the Pi is not behind
on anything a player can see and **needs no restart.** `origin/main` sits at `fea2343`.
Pushing is manual and user-side; do not push.

**2026-09-12 part 2 — leaderboards.** Four all-time boards in the quest journal: ⚔️ level ·
🎖 arena honor · 🌲 deepest km · 🚶 total km walked, as tabs redrawing one message. Two new
lifetime columns (`deepest_km`, `total_km_walked`) with a single writer,
`User.recordWalk(toKm:)`, on the `rollStep` funnel. **A migration ships with this**, so the
Pi needs a rebuild and a restart, not `/reload`. `Leaderboard` in code, «Рейтинги» on screen
— `rating` is taken. Seasons are a decided future direction: auto-memory
`project-leaderboards-will-go-seasonal`.

**2026-09-12 — the roots, and what else hid behind them.** One game-code change since the
doc pass: a player asked why a root took 22 HP when it used to take 10. It took 11; hunger
took the other 11 on the same step, and `.trip` reported the sum under the root's own label.
The audit found the tick was applied once in `rollStep` and then each branch had to carry it:
of the ten exits reachable while starving, two carried it, one fused it, one blamed a beast,
and six dropped it silently. `rollStep` returns a `StepResult` now and every source
of damage prints its own line. Reporting only — all four digest hashes byte-identical.
**Not deployed: this is game code, so it needs a rebuild and a `pm2 restart`, not `/reload`.**
Full account in `.memory/sessions.md` (2026-09-12), auto-memory
`project-damage-sources-named-separately`.

**The session before it changed no game code.** It was a documentation and memory audit: the
session preamble was ~20,300 tokens with about 45% of it narrative the memory bank already
held, and one narrative existed in three places at once. The split now in force is **the
doc keeps the RULE, the memory bank keeps the REASON** — `CLAUDE.md` states the imperative
and the trap, then points at the record. Seven stale memory records were corrected in the
same pass. Full account: `.memory/sessions.md` (2026-09-12) and the auto-memory
`feedback-docs-keep-the-rule`.

**What a fresh session should know about the eleven commits before that.** Every single
defect came from someone PLAYING — none from a test. The pattern worth carrying: each was a
place where the code was right and could not say so, or where a number was shown in a unit
it was not measured in. Three of the last four were found by the user glancing at a screen,
not by running anything. **That is still the most productive way to find the next one, and
it is exactly what has not been done to the three surfaces below.**

> ## Next action: walk the three surfaces this build changed, then the untouched ones
>
> **1. Three surfaces changed on 09-10/11 and NONE has been walked yet.** This is the
> whole next action — the code is deployed and nobody has looked at it:
> - **the forest on the way home** — the return leg should now be noticeably more
>   fight-heavy than the walk out (8.8 fights over 17 km against 3.4 before). Walk to
>   km 15–18 and back on foot. With a full bag and low HP this is a real risk: death
>   still wipes the whole unequipped bag.
> - **the road** — turn back twice in a row; the second should quote most of the
>   crossing (~`1хв 58сек`), not five seconds, and now shows seconds at all.
> - **the character sheet and any Forester piece** — three rating stats with no `%`,
>   and a `❤️ Здоров'я` line on armour that was invisible before.
>
> **2. Still never walked, from the older list:** a fight lost, a **flee**, the trade
> screens, and one run of **`/reload` + `/content`** against a real database.
>
> **3. The API-error question is CLOSED, and needs no more checking.** `Code: 400` stood at
> **913 before the `editScreen` deploy and 913 an hour after it**, with `[ROUTE]` /
> `[COMBAT]` / `[SCREEN]` all silent — the fix is proven. If a new screen bug is ever
> reported, this is still the cheap first look:
>
> ```
> ssh rpi5@192.168.0.203 'grep -c "^Code: 400" ~/.pm2/logs/ROI-out.log'   # baseline 913
> ssh rpi5@192.168.0.203 'grep -E "\[ROUTE\]|\[COMBAT\]|\[SCREEN\]" ~/.pm2/logs/ROI-out.log'
> ```
>
> **Deploying to the Pi:** `git pull --ff-only`, build, then **ASK before
> `pm2 restart ROI`**. Two traps that cost real time — swiftenv's `PATH` lives in `.bashrc`,
> which a non-interactive `ssh` never reads, and `pgrep -f swift-build` matches the ssh
> command's own argument string. The recipe with both: auto-memory
> `project-pi-deploy-swiftenv`, `linux-build-gap`. A content or schema change must ship the
> new `content/data` and the new binary TOGETHER. Free pre-flight, without touching the
> running bot: `ROI_PROJECT_PATH=/home/rpi5/RestOfIryna ./.build/debug/RestOfIryna
> --content-digest` on the Pi exercises parse → validate → install under Linux.

### What the live-play polish landed (eleven commits, 2026-09-09 → 11)

Every defect came from someone PLAYING; none from a test. The pattern worth carrying: each
was a place where the code was right and could not say so, or where a number was shown in a
unit it was not measured in. Full narrative in `.memory/sessions.md` (the 09-09 → 09-11
entries); the rules they produced are in `CLAUDE.md`.

- `fea2343` **one name per stat, one unit per number** — `Countdown` printed one unit for
  minutes, `accuracy` had two Ukrainian names, HP rendered on one gear screen of five, and
  crit was labelled `%` though it is a rating.
- `9a774ae` **a turned leg starts in the middle of the road** — `turnBack` measured from
  `createdAt`, which locates only a leg that began at an endpoint.
- `4f0b54d` **the forest stopped being empty on the way home** — the decay table decayed the
  wrong bucket; tier 1 is `8/35/52/5` now, and passive took its own `passive.weights` row
  (**schema v10 → v11**).
- `1e99198` **a full warehouse said the bag was empty** — `depositAll` returned a bare count,
  and a zero meant two opposite things.
- `4766947` **the road can be turned around** — `↩️ Розвернутись` takes the Explore slot
  while a trip is in flight.
- `3a6d5e3` **resting is a place, not a pause between fights** — `canRest` names all three
  suspensions.
- `75a89cc` **the router raced, and the edits were aimed at the wrong field** — routing moved
  inside `RouterStore`'s chain; `editScreen` gave all 20 edit call sites one photo-aware path.
- `bfc6e00` **five screens say what they were hiding** — bag occupancy, what a drawn card
  does, an item card before the purchase question.
- `509f2db` **one clock, three watchmen, two ceilings that were not real** — `Countdown`,
  `RestNotificationService`, the 3 h/day passive budget and the warehouse cap on harvest.
- `04bd80d` **Ukrainian agrees with the item, not only with the player** — `item.<id>.gender`
  in `uk.json`, two validator rules behind it.

### What the rebalance settled (Phases 8E–10)

**Phase 9 decided, and Phase 10 applied:** the authored band is **levels 1–25**, an enemy of
level N spawns **km N…N+9**, the zones are **Гущавина 1–10 / Старий ліс 11–25 / Пуща 26–49**,
and **no new creatures or items** ship in this release. Six enemies were re-levelled with
`xpReward` re-solved from the generator and stats untouched. The wardrobe is at 40% of the
on-curve budget at level 25 and the bestiary at ~60% of its archetype contract — **both
half-strength errors lean the same way**, so correcting one alone is worse than correcting
neither. The full gear-ladder + regeneration package ships together, after the rebalance.

**The debt Phase 9 wrote itself is PAID.** `OpeningLedger` measured the opening and inverted
the conclusion: it is not Vigor-bankrupt, the **shallow** opening is — km 1 nets −335, km 4
nets **+44**, km 10 is the deepest km still won 95% of the time. What it points at is a
first-hour *teaching* problem, not a tuning one. Auto-memory
`project-opening-is-vigor-bankrupt`, `project-world-ladder`; detail in `.memory/rebalance.md`.

The rule those five documents run on: **numbers are printed, never typed** — every table is
emitted by `roi-content spec` from the code that owns the maths. The corollary, learned the
hard way: **the rule protects tables, not the prose beside them** (auto-memory
`feedback-printed-numbers-protect-tables-not-prose`).

Phase 8E removed passive Vigor regeneration entirely: the trickle did not pause during an
expedition, so there was no depth gate, only patience. Vigor now comes from food, quests and
levelling, and **the estate is the income** (auto-memory `project-vigor-no-passive-regen`).

`FoodBudget` in `ROISim` measures the estate's income by enumerating every plot layout the
slots allow, so the pace number reads off content rather than an assumed mix. The food plots
were cut to land the pace at **78–87 days** of perfect play — slower than the old 51–56 on
purpose. `zones.json` landed with it: the foraging pools left `ExplorationService`, the last
content in Swift. Numbers and the layout table: `.memory/rebalance.md` §Phase 8E.

#### Standing deferrals

Reported by every `simulate` run, all deliberate: **food portions are flat
against a pool that grows** (33% of a level-1 pool, 12% of a level-40 one),
**nothing new unlocks between level 21 and 40**, **levels 1–3 have no estate at
all**, the **seven `content.roster_off_curve` warnings** (until the regeneration
package lands), and **`opening.shallow_is_bankrupt`** — a warning and not a broken
band on purpose, because §7 decided to measure before retuning. Silver is also **over-supplied** — roughly twenty
thousand spare over a lifetime against 1,600 of mandatory spend — and the fix is
more to buy, which is items, which is after the rebalance.

#### The simulator, and what it currently says

`swift run -c release roi-content simulate` rolls the SAME `CombatMath` the bot calls, so a
report cannot drift from the game. It sweeps levels × archetypes × classes × play profiles ×
gear offsets and bands level invariance, the p90 tail, win rates, pace to the cap and the
shipped roster against its archetype contract; `--strict` exits 1 on a broken band. Default
sample size **8000 fights per cell** — 2000 crossed the invariance band on sampling noise alone.

Current state: **18 of 18 invariance rows pass, 0 broken bands, 12 warnings**, 19,437,688 XP
from level 1 to 40, **78–87 days** on a tended estate. `EnemyGenerator` is what the
post-rebalance regeneration will lean on — run at design time and frozen, never at runtime.
What each phase taught: `.memory/rebalance.md`.

**Current digest baseline (2026-09-10, schema v11):** `records f6fc421256085066` ·
`tuning ee45b18aea6b2c40` · `spawns eaea309f4813dfa2` · `quests 30de20902006e3b9`. A knob is
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

Adding content is a **JSON edit plus locale keys in both `en.json` and `uk.json`** — never a
Swift array edit, because there are none left. `ContentBootstrap.load` runs in `configure`
**before the database block**, and **no `static let` anywhere may reference a catalog**.

The migration loop, the verification layers and every gotcha: `.memory/content-pipeline.md`.

### Running locally (rare now — the Pi is production)

Only needed to debug against the live database from the Mac. **Stop the Pi's instance
first** — same token in both `.env` files, so two pollers means a 409 — and kill
`debugserver` before the process, since a crashed Xcode run survives `kill -9` while the
debugger traces it.

```
pkill -f debugserver; pkill -9 -f 'Build/Products/Debug/RestOfIryna'
ssh -f -N -L 5433:localhost:5433 rpi5@192.168.0.203
printf '\x00\x00\x00\x08\x04\xd2\x16\x2f' | nc -w2 localhost 5433 | head -c1
```

The last line must print `S` or `N` — `nc -z` alone only proves ssh is up. Both traps
surface identically as `Fatal error: Error raised at top level`. Full recovery order:
auto-memory `roi-local-run-setup`.

### Commands

```
/content   /reload                           # dev-only, in Telegram: inspect and hot-swap
swift run roi-content validate --strict      # content integrity; exit 1 on any error
swift run -c release roi-content simulate    # balance sweep; --runs/--seed/--levels, --strict gates
swift run roi-content spec <table>           # progression · gates · bestiary · items · sets · economy · opening
swift run RestOfIryna --content-digest       # confirm ONLY the intended change moved
swift test                                   # 236 tests, ~0.2s
```

## What Works Now (shipped game)

Registration · exploration (active + passive, three-tier visit decay, restart-safe
scheduler) · turn-based PvE combat with 9 class techniques · estate (plots,
warehouse, workshop, kitchen, weapon/bag/estate upgrades, technique gates) ·
capital hub (travel, Trader, Tavern with dice/darts, Fortune Teller, Master with
durability + enchant, player Market, synchronous Trade) · Guilds (roster, invites,
item vault, silver treasury) · Arena (live PvP duel, Honor ELO, stakes, daily
budget) · daily NPC quests derived from a stable hash, **taken by hand at the NPC** (nothing counts until the player accepts the job), + quest journal.

Every daily system keys off `GameDay` (rolls at **12:00 Kyiv**). EN + UK
localization (**1006 / 1054 keys** — uk carries 13 `.m`/`.f` player-gender pairs, 33
`item.<id>.gender` declarations and the four-way `gear.broken.notice`). **Access is invite-only and lives in the database**
(`allowed_users`): `/link` mints a five-minute deep link, redeeming one adds the
account and opens registration, and nobody else gets a `User` row at all.

✅ `tuning/time.json` → `scale` is **1.0** (2026-09-09): game time is real time.
Plot cycle 1 h, passive runs 30 / 60 / 90 min, a trip to the capital 2 min.
`validate --strict` is clean — zero errors, zero warnings.
Nothing under `realTime` ever was affected — Telegram's 24 h dice-delete window, the
trade TTLs and the 12:00 rollover never scale.

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

- After significant work update `.memory/sessions.md`, `.memory/status.md` and `TODO.md`
- Ask before committing; short compact messages, no co-author line
- **Never push** — manual/user-side only
- **Never start, restart or stop the bot without asking** (`CLAUDE.md` → "Running the
  bot — ASK FIRST"). Builds are exempt; a Mac instance left polling is the one thing to
  stop without asking, because it 409s the Pi
- Admit a new tester with `/link`, never a code edit — the hardcoded list is gone
- New locale keys go in BOTH `en.json` and `uk.json`; uk gendered copy uses `.m`/`.f`
- Telegram `callback_data` max 64 bytes
- Content changes: `roi-content validate --strict` must pass before commit
- Balance-table changes (`combat` / `progression` / `budget` / archetypes): re-run
  `roi-content simulate --strict` too — the digest says what moved, the simulator
  says whether it is survivable
- Hand-edit `content/data/*.json` in the Swift `JSONEncoder` style already there
  (`"key" : value`, keys sorted, 2-space indent) — a python-style re-emit reformats
  every line and buries the real change
