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

### Where we stopped (2026-09-10)

**Phases 3–10 are done. Phase 11 is closed as CODE** — the wipe, the opening ledger,
invite-only access, the Pi deployment and `scale` 1.0 all landed by 09-09. Since then the
work has been **live-play polish: fixing what playing the deployed build revealed.**

**The bot is LIVE on the Pi, running `509f2db`** (restarted 2026-09-09 23:42, content hash
`954b2608`, three migrations applied clean: `AddFortuneOneShot`, `AddNotificationFlags`,
`AddPassiveDailyBudget`). **`04bd80d` and anything after it is NOT deployed** — it needs a
push, a Pi build and a restart.

> ## Next action: watch the log this build now writes, then keep walking
>
> **1. The Telegram API errors are fixed but UNPROVEN in the wild** (2026-09-10). All 20
> edit call sites go through `editScreen`, and the client classifies refusals, so the log
> should now be nearly empty of 400s. Three lines are the payoff and want checking after
> the next restart:
>
> ```
> ssh rpi5@192.168.0.203 'grep -c "^Code: 400" ~/.pm2/logs/ROI-out.log'   # should stop growing
> ssh rpi5@192.168.0.203 'grep -E "\[ROUTE\]|\[COMBAT\]|\[SCREEN\]" ~/.pm2/logs/ROI-out.log'
> ```
>
> `[ROUTE]` means two taps raced and the second was re-aimed at the live controller —
> it MEASURES the race that produced the wrong-keyboard reports. `[COMBAT]` should be
> silent now that routing is fixed; if it appears, routerName and the expedition row are
> disagreeing for some other reason. `[SCREEN]` names a call site whose `isPhoto` guess is
> wrong (recovered) or an edit that failed both ways (not recovered).
>
> **2. Keep walking the first hour.** The user IS playing and reporting — that is how
> every fix below was found. What has NOT been walked deliberately: a fight lost, a
> **flee**, the trade screens, and one run of **`/reload` + `/content`**, which have still
> never executed against a real database.
>
> **Deploying to the Pi — the recipe, with the trap that cost ten minutes on 09-09:**
>
> ```
> ssh rpi5@192.168.0.203 'cd ~/RestOfIryna && git pull --ff-only'
> # swift is installed via SWIFTENV and its PATH lives in .bashrc, which a
> # NON-INTERACTIVE ssh does not read. Without this the build never starts:
> #   nohup: failed to run command 'swift': No such file or directory
> ssh rpi5@192.168.0.203 'cd ~/RestOfIryna && setsid nohup env \
>   PATH="$HOME/.swiftenv/bin:$HOME/.swiftenv/shims:$PATH" swift build \
>   > /tmp/roi-build.log 2>&1 < /dev/null &'
> # Wait on `pgrep -x swift-build` — NEVER `pgrep -f swift-build`, which matches the
> # ssh command's own argument string and waits forever on nothing.
> ```
>
> A full build touching `User.swift` is ~2 minutes on the Pi (it recompiles the whole app
> module); a few files is ~80 s. **Then ASK before `pm2 restart ROI`.** A content-only edit
> needs no restart — `/reload` re-reads `content/data`; new locale strings DO need one.

### What the live-play polish landed (four commits, 2026-09-09 → 10)

**`75a89cc` — the router raced, and the edits were aimed at the wrong field.** Three
reported symptoms, no game logic among them. `TGDispatcher` chose the controller from a
`routerName` read before the previous tap had transitioned — the SDK gives every update its
own `Task.detached` — so a second quick tap was delivered to the controller the first had
just left; routing moved inside `RouterStore`'s per-user chain, and `[ROUTE]` now measures
the race. Exploration refuses to walk while a beast is standing and re-renders the fight
instead, which re-asserts the combat keyboard. `TravelService` and `PassiveExpeditionService`
took `SessionCache.peek`. And `Helpers/ScreenEdit.swift` gave all 20 edit call sites one
photo-aware `editScreen`: **310 of the 807 API refusals in a day and a half of log were
`editMessageText` against a caption**, each swallowed by `try?` — which is exactly the "the
tap did nothing" report, and why the warehouse never refreshed after a withdraw-N.

**`bfc6e00` — five screens say what they were hiding.** The expedition bag prints its
occupancy; the fortune screen and the profile say what the drawn card actually does
(generated from its own `FortuneEffect`) and what a one-shot handed over (stamped at draw
time, because the Wheel rolls 50/50 and a silver loss is clamped to the purse); every
capital shop shows an item card before the purchase question; selling into a job taken
today warns first.

**`509f2db` — one clock, three watchmen, two ceilings that were not real.**
`Countdown.format` replaced the `MM:SS` / `HH:MM` pair no screen could tell apart, and
every hand-written duration in the copy went with it. `RestNotificationService` watches
what finishes while nobody is looking. Passive expeditions got a **3 h/day** ceiling. The
**warehouse cap now applies to the plot harvest** — the one path that filled the warehouse
unchecked — and no account is exempt any more. And **starvation was charging double** on
three of the four step buckets: 10 HP where the message said 5.

**`04bd80d` — Ukrainian agrees with the item, not only with the player.** The
broken-gear line shipped in the neuter, which fits none of the nineteen breakable items
(seventeen masculine, two plural). Gender now lives in `uk.json` as `item.<id>.gender`,
with two validator rules behind it. The journal's job description waits until the job is
taken.

### What the 2026-09-07 pass landed (four commits)

Bug fixes first (`29b233c`): the character screen renders **one** layout (the
style switcher and `User.profileStyle` are gone); **HP regen is stamped at both
ends of an expedition** (`HealingService.beginResting` / `suspendResting`) —
without the first stamp the stretch between coming home and the next tap healed
nothing, without the second a passive run the player never tapped through refunded
its whole damage; the player is addressed by their **chosen nickname**, never the
Telegram one; and a **level-up is its own message** listing all seven
level-derived stats. The estate line that used to ride along could never print —
`estateLeveledUp` compared a field `grantXP` does not touch — so it was deleted and
the real event got `EstateUpBanner`. 170 uk strings moved to «ви», nine gendered
pairs collapsed.

Then quests (`34825fc`, `f80a514`): **a job is taken at the NPC**, `record` no
longer creates rows, and taking a job starts the count rather than backfilling it.
Each job carries a `minLevel` (trader 1/1/1/6/8 · master 1/1/1/7/10 · tavern
1/1/1/4/5) and the pool is filtered before the daily hash. Authored rewards were
halved and are scaled at payout, each currency on the curve it belongs to. **Six
early forage jobs were authored** so a level-1 board still offers three per NPC —
new content in a release that had ruled it out, taken deliberately, because a band
with no early pool behind it is worse than no band. The faucet went from a flat
**220 silver a day to 78 → 153** across the arc.

Finally naming and screens (`d8cfb0c`): the mage ladder read патериця → посох →
жезл (Staff → Rod → Scepter in en) — one object under three nouns, while the
Master's repair button names a fourth. Both ladders stay on посох / Staff, and
`locale.ladder_name_drift` now warns when no word survives a ladder. The Master's
repair and enchant screens rendered inventory rows through a tier-blind label, so a
tier-5 weapon showed under its tier-1 name. Both trade screens print the player's
purse; the profile gained an equipment sheet.

**What Phase 10 changed (2026-09-01).** Six enemies re-levelled — boar 1, moose 4,
bison 7, lynx 10, wolf 13, bear 16, rabid bear 22 — with `depth` following the
level↔km rule and `xpReward` re-solved from the generator (it is solved, not
authored: it was exactly `round(mobXP(level))` before and is again after). Stats
were **not** touched. Wild Buffalo became **Wild Bison / Зубр** in `en.json`,
`uk.json` and `lore.md`. The rabid bear keeps a **stretched band, km 22–40**:
the plain N…N+9 rule opened a nine-km hole at km 32–40 where exploration rolls no
encounter, and the validator refuses that (`enemy.depth_gap`).

Measured after: density km 1–25 went **2.24 → 2.56** candidates per km, all four
common archetypes are met by km 10, km 4–9 went from one creature to three — and
the roster moved from **~50% to ~60% of its archetype contract with no stat change
at all**, because a lower level is a lower target.

**What Phase 9 decided, compressed.** The authored band is **levels 1–25**; an
enemy of level N spawns **km N…N+9**; the zones are **Гущавина 1–10 / Старий ліс
11–25 / Пуща 26–49**; **no new creatures** and **no new items**. The wardrobe was
then measured and it reset the plan: a fully enchanted kit is **97% of the
on-curve budget at level 1 and 40% at level 25** (armour is frozen at itemLevel 1
forever; only weapons ladder). Since the bestiary is at ~60% of its contract,
**the two half-strength errors lean the same way**, so correcting one alone is
worse than correcting neither — which is why Phase 10 corrected the levels and
left the strength alone.

**One package, all of it after the rebalance:** the **gear ladder** (the Forester
set climbing the weapons' own rungs 1/10/20/30/40 — zero new items), the
**bestiary regeneration**, a set bonus that multiplies its **own members** rather
than the whole kit (the same ×1.05 costs 8% of the members' budget at L1 and 33%
at L40), the 25% cap extended to multipliers, `set.forester` rewritten as the
**first and weakest rung** of a strength ladder at ×1.07, and `lootMultiplier`
wired to **quantity** with its loot tables re-normalised to a base in the same
pass.

**The debt Phase 9 wrote itself is PAID (2026-09-02).** `spec-economy.md` claimed
the opening was Vigor-bankrupt — 79 boars, ~664 Vigor of deficit against a 105
pool — and decided to **measure before retuning**. `OpeningLedger` measured it and
inverted the conclusion: **the opening is not bankrupt, the SHALLOW opening is.**
km 1 nets −374, km 4 nets **+40**, km 10 nets +72 and is the deepest km still won
95% of the time; past km 11 survival rather than Vigor binds. §2 is amended, and
both of its hand-computed numbers were wrong in opposite directions — the deficit
credited the boar with cooked meat across a stretch where the kitchen is locked
(it is an estate room, opening at the level the stretch ENDS at) and counted no
foraging; the kill count missed the level-gap scaler, which adds 17%. The
one-number retune that was on the table — the boar's meat chance 0.70 → ~1.4 — is
**no longer obviously wanted**, because that meat cannot be cooked during the
opening at all. What the ledger points at instead is that the game never tells the
player to walk: a first-hour teaching problem, not a tuning one.

The rule those five documents run on, and the reason they can be trusted:
**numbers are printed, never typed.** `roi-content spec
<progression|gates|bestiary|items|sets|economy|opening>` emits every table from the code
that owns the maths, so a specification cannot drift from the generator it feeds.
It earns its keep: during the Phase 10 audit the verbatim check caught two
generated blocks in `spec-economy.md` that the re-spread had silently invalidated,
plus a passage quoting a *planned* change as though it were already in the data.

The corollary, learned the hard way and worth keeping in mind: **the rule protects
tables, not the prose beside them.** `spec-progression.md` §3 carried "about
eleven kills to reach level 4" for two weeks — eleven reaches level 2 — in the one
sentence that settled a design question, right under a table that was correct.

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

`zones.json` landed with it: the foraging pools left `ExplorationService`, the
last content in Swift. Proved equivalent by replaying the shipped arrays out of
git for km 1–40 — identical including weights and order.

#### Standing deferrals

Reported by every `simulate` run, all deliberate: **food portions are flat
against a pool that grows** (33% of a level-1 pool, 12% of a level-40 one),
**nothing new unlocks between level 21 and 40**, **levels 1–3 have no estate at
all**, the **seven `content.roster_off_curve` warnings** (until the regeneration
package lands), and **`opening.shallow_is_bankrupt`** — a warning and not a broken
band on purpose, because §7 decided to measure before retuning. Silver is also **over-supplied** — roughly twenty
thousand spare over a lifetime against 1,600 of mandatory spend — and the fix is
more to buy, which is items, which is after the rebalance.

#### What Phase 8 left behind (the tools Phase 9+ leans on)

`swift run -c release roi-content simulate` rolls the SAME `CombatMath` the bot
calls — the maths lives in `ROISim` and `CombatService` / `User` / `ItemBudget` /
`VigorService` are façades over it, so a report cannot drift from the game. It
sweeps levels × archetypes × classes × play profiles × gear offsets and bands
level invariance, the p90 tail, win rates, pace to the cap, and the shipped
roster against its archetype contract. `--strict` exits 1 on a broken band.

Current state of those bands: **18 of 18 level-invariance rows pass, 0 broken
bands, 12 warnings** — seven are the off-curve roster, three are the levels with
no estate, one is the flat food portion, and one is
`opening.shallow_is_bankrupt`. 19,437,688 XP from
level 1 to 40, and **85–93 days** on a tended estate — an estimate between two
opposing simplifications (every point spent on combat, but nothing except the
estate feeding the player) rather than the floor the old number was.

The default sample size is **8000 fights per cell** (2.6s for the sweep). It was
2000 until Phase 8D, where the level-invariance band — a ±15% ratio of two
means — turned out to cross on sampling noise alone, so `--strict` was failing
the build on a row that reads ×1.13 at 8000 and ×1.16 at 2000 from the same seed.

`EnemyGenerator` is what the post-rebalance regeneration will lean on: the
archetype table is a GENERATOR, and inverting its targets reproduces every shipped
enemy's DEF, crit and dodge to within rounding. Phase 10 already used it for
`xpReward`. Run at design time and frozen — never at runtime, which is how gear
upgrades evaporate.

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

**Current digest baseline (2026-09-10, schema v10):** `records f6fc421256085066` ·
`tuning a23248441d58a78a` · `spawns eaea309f4813dfa2` · `quests 30de20902006e3b9`.
`tuning` moved twice on 09-09, both predicted and both named in the digest first:
`realTime.restSweepInterval` (the watchman's cadence) and `passive.dailyBudgetMinutes`
(the 3 h ceiling). The other three halves have not moved since 09-09.

HP regen is **10% of max HP per real minute** (`tuning/vigor.json` →
`healing.regenPerMinute`), so a full rest at the estate takes 10 minutes. It went
5% → 20% on 2026-09-08 and settled at 10% on 2026-09-09; each move touched
`tuning` alone. The other three halves held, as they
must — no record, spawn band or quest pool was touched. `simulate --strict` is
unchanged at 0 broken bands / 12 warnings: the sweep models fights, not the rest
between them.

The 2026-09-07 quest retune moved three of the four: `records` (halved rewards plus the new `minLevel` band), `tuning` (the quest reward curve in `economy.json` — which held on its first run, because the digest was not hashing the new knob yet; hashing it was the fix) and `quests` (the daily pick is filtered by level before the hash, and the replay sweeps levels 1/8/20 now). `spawns` held, as it must — no foraging band moved.

Phase 10 moved `records` and `spawns` and held `tuning` and `quests` — the two
halves predicted *before* the edit, which is the whole point of splitting the
digest in four. Phase 9 moved nothing at all: five specifications, three new spec
tables and a validator refactor, and every half stood still.

⚠️ **The live pass is under way and is finding real defects** — every fix in the
2026-09-09/10 polish commits came out of playing the deployed build. What follows is the
pre-playtest note, kept for the surfaces it lists that are STILL untouched. Four accounts
played 2026-09-02 → 09-09 and reached L10 / estate T4, so the rebalanced formulas have
been exercised — but nobody stepped through the first hour against a checklist. Every
formula the player touches changed in Phase 5, every item's stat in Phase 6, the stances
plus the failed-Flee counter in Phase 8C, Shadow Veil plus the archer's Defend in 8D,
and the whole Vigor economy in 8E. **`/reload` has still never run against a real
database** — and it is now the cheapest way to ship a content edit, so it is worth
proving early.

### How content works now

All 13 catalogs (Zone joined in 8E) and all seven tuning tables are façades over a snapshot
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

### Running locally (rare now — the Pi is production)

Only needed to debug against the live database from the Mac. Both traps below look
identical, as `Fatal error: Error raised at top level`:

```
pkill -f debugserver; pkill -9 -f 'Build/Products/Debug/RestOfIryna'
ssh -f -N -L 5433:localhost:5433 rpi5@192.168.0.203
printf '\x00\x00\x00\x08\x04\xd2\x16\x2f' | nc -w2 localhost 5433 | head -c1
```

The last line must print `S` or `N` — that is Postgres answering behind the tunnel.
`nc -z` alone only proves ssh is up, because an `-L` forward listens locally even when
the far side is dead. A crashed Xcode run sits as `STAT SX` and survives `kill -9` while
debugserver traces it, so kill the debugger first. **And stop the Pi's instance first,
or one of the two gets a 409** — same token in both `.env` files.

### Commands

```
/content   /reload                           # dev-only, in Telegram: inspect and hot-swap
swift run roi-content validate --strict      # content integrity; exit 1 on any error
swift run -c release roi-content simulate    # balance sweep; --runs/--seed/--levels, --strict gates
swift run roi-content spec <table>           # progression · gates · bestiary · items · sets · economy · opening
swift run RestOfIryna --content-digest       # confirm ONLY the intended change moved
swift test                                   # 234 tests, ~0.2s
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
localization (**1002 / 1050 keys** — uk carries 13 `.m`/`.f` player-gender pairs, 33
`item.<id>.gender` declarations and the four-way `gear.broken.notice`). **Access is invite-only and lives in the database**
(`allowed_users`): `/link` mints a five-minute deep link, redeeming one adds the
account and opens registration, and nobody else gets a `User` row at all.

✅ `tuning/time.json` → `scale` is **1.0** (2026-09-09): game time is real time.
Plot cycle 1 h, passive runs 30 / 60 / 90 min, a trip to the capital 2 min.
`validate --strict` is clean — zero errors, zero warnings.
Nothing under `realTime` ever was affected — Telegram's 24 h dice-delete window, the
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
| `Modules/ROISim/SpecTables.swift` | What `roi-content spec` prints — the tables a content spec quotes, from the code that owns them |
| `Modules/ROISim/OpeningLedger.swift` | **Phase 11.** Levels 1–3 priced at every depth against the trail — the stretch the pace model must skip. Raw meat is NOT income (its recipes are kitchen recipes, and the kitchen is a room of the estate this stretch ends by unlocking) |
| `Swift/Helpers/AccessControl.swift` | **2026-09-08.** The allow list as an actor. A cache MISS queries the DB, so a row added by hand takes effect on the next message; `developerUsers` are allowed before the table is read — the lockout brake |
| `Swift/Helpers/InviteToken.swift` | **2026-09-08.** The `/link` token: encrypted UNIX timestamp + HMAC tag keyed on SHA256(bot token), 16 letters, five REAL minutes. Encryption hides the date; the tag is what stops anyone minting their own |
| `Swift/Migrations/WipeForRebalance.swift` | **Phase 11.** The full wipe. LAST in `configure.swift`, no-op on a fresh DB. Explicit table list because `tavern_game_messages` has no FK, plus an `information_schema` self-check that refuses to finish while any table holds a row |
| `content/spec/` | The five approved specifications (Phase 9, closed). Numbers in them are printed by `roi-content spec`; re-run it after any content edit and refresh the `<!-- generated -->` blocks |

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
