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

### Where things stand right now (2026-09-15)

| | |
|---|---|
| working tree | clean |
| HEAD | `b32ac32` — the escape ceiling |
| pushed | through `6e3c18e`; **`7469715` and `b32ac32` are unpushed** |
| running on the Pi | **`aa18f57`**, content hash `4eac64ff`, **schema v11**, last restarted 2026-09-12 19:43 |
| committed but NOT deployed | **five commits** — `c658e6c` · `a0f90a8` · `6e3c18e` · `7469715` · `b32ac32` |

**The next deploy is NOT a `/reload`.** It carries a content-schema bump (**v11 → v12**) and
a database migration (`AddCombatFleeFails`), so the new binary and the new `content/data`
must travel together and the bot has to restart. Push is user-side; `pm2 restart ROI` is
asked for, never taken (`CLAUDE.md` → "Running the bot — ASK FIRST"). After it, verify the
TABLE rather than the log line: `combat_flee_fails` must exist on `exploration_state`.

**What the five changed, newest first:** the escape ceiling · coins on the ground · mob XP
halved · bestiary tier 1 and the re-solved roster · one honor ladder plus a doc pass. Each
has its own section below. **None of it has been opened by a human**, which is the next
action — see the walk list further down.

### Where we stopped (2026-09-15) part 2 — the escape has a ceiling (`b32ac32`, NOT deployed)

A player pressed **Flee seven times**, never got away, and was killed. The user asked whether
that was simply the probability. It was — for one class.

**The roll is flat and per class, and nothing else enters it.** Warrior 40 / archer 70 /
mage 90; not the player's level, not the enemy's, not the depth. Seven failures in a row is
**2.80% for a warrior — one fight in 36** — against 0.022% for an archer and 0.00001% for a
mage. The same report means "ordinary bad luck", "once a year" or "there is a bug" depending
on who sent it, which is worth asking before believing any future one.

**What killed them is that a failed escape is not a free round.** It costs 3 Vigor and a
`cannotMiss` counter with the player's DEF HALVED and nothing dealt back — **43–51% more
damage than an ordinary enemy counter** for a warrior, 69–77% for an archer, who also loses
a dodge roll they would otherwise have had. At level 10 in a full on-curve kit that is 6.3%
of the bar per failure to a rabid lynx and **16.3% to the level-22 rabid bear: death in
exactly seven.** Pressing Flee is strictly worse per round than fighting; all it buys is
the chance to end the fight.

**`combat.json` → `flee.maxFailures = 4`.** The attempt after four failures is granted
without a roll, to every class at every level against every enemy. It cuts the tail and
barely moves the mean — warrior attempts **2.50 → 2.31**, archer and mage unchanged to two
decimals, 12.96% of warrior escapes now ending on the guaranteed try. **The class chances
were not touched** (they are the class fantasy) and neither was the backstab — Phase 8C
rebuilt it from a free 1 HP on purpose, and a ceiling bounds how many land rather than
making them cheap.

Three decisions worth not re-opening: the counter is **per FIGHT**
(`ExplorationState.combat_flee_fails`, 0 on `beginCombat`, cleared on `endCombat`) because
per expedition it becomes a resource the player spends rather than a floor under one bad
run; the roll lives in **`CombatMath.fleeSucceeds`** even though the simulator has no flee
policy, since a roll and its ceiling are one rule and the second copy forgets the ceiling;
and `CombatRules` carries `fleeMaxFailures` as a **scalar**, because that struct is copied
per swing and its own doc comment promises it holds no arrays.

**Content schema v11 → v12** — `flee` stopped being an array and became a section
(`byClass` + `maxFailures`). One migration, `AddCombatFleeFails`.

```
validate --strict   ✅ 0/0 · content hash 93923ad1 → 15782bee · schema v12
simulate --strict   exit 0 · 0 broken bands · 12 warnings — the count it started at
swift test          246 passed (242 + 4 for the ceiling)
digest              tuning 2634076e… → 43b809a8…
                    records, spawns and quests byte-identical
```

**Nothing about it is visible to the player** — no copy was added, so the ceiling reads as
luck on the fifth try. Deliberate, and the obvious follow-up if it should teach itself.

Full account: `.memory/sessions.md` (2026-09-15, the escape ceiling); auto-memory
`project-flee-has-a-ceiling`; the rule is in `CLAUDE.md`.

### Where we stopped (2026-09-15) — coins on the ground (`7469715`, NOT deployed)

A fifth step event, on request. Walking a kilometre can turn up **2, 5, 10 or 20 silver**,
credited on the spot.

**Not monster silver, and the distinction is what made it buildable.** Phase 8C deleted
coin drops from kills and that stands; this is a find on a STEP — no relationship to what
was killed, no per-creature curve, unfarmable by picking soft enemies. Hanging it off a
victory would be the deleted mechanic in a new coat.

**The denominations are a rule, not four numbers somebody liked.** Weights `10 : 4 : 2 : 1`
against `2 : 5 : 10 : 20` — that is `1/amount` scaled to integers, so the chance is
inversely proportional to the find and **every denomination contributes the same expected
silver** (1.18 each, 4.71 a find). A fifth denomination is written as `1/amount` again
rather than by re-balancing the set.

Frequency **2 of 100, taken from `loot`** in every row including passive — a find is a
second kind of loot, not a second kind of nothing. One step in fifty pays; a twenty turns
up once every **850 km**. ≈94 silver per 1000 km against quest income of 96–152 a day.

```
🪙 Під коренем з-під землі ви помічаєте старі срібники. Схоже, якийсь Намісник
   невдало тут спіткнувся й загубив свої монети. Ви отримуєте 🪙 <b>2 срібники</b>.
```

**Two traps this walked into, both caught before shipping.** 🪙 is U+1FA99 —
supplementary plane, two UTF-16 units — and the sentence puts it immediately before the
amount, which is the exact configuration where Lingo drops the `%{}` that follows it. Both
coins are passed as interpolation VALUES so the template holds no emoji at all; rendered
through real Lingo to prove it, because a clean build says nothing here. And Ukrainian
needs three noun forms, so `UkrainianPlural` lives in `ROIContent` (where tests can reach
it) with the 11–14 band checked first: 11 ends in 1 and 12 ends in 2, and a units-only
rule calls them «срібник» and «срібники» when both are «срібників». The shipped
denominations are 2/5/10/20 — **none of which touch the trap** — so it would have waited
for the first eleven the game ever printed.

**It makes the silver surplus worse and was added anyway.** `spec-economy` §4 measures
~20,000 spare over a lifetime and says the fix is more to buy, not less to earn. This is
neither; it ships as flavour, sized at the low end, and the frequency is one number if it
ever starts to matter. The other cost is real and small: the 2 weight came out of `loot`,
so the trail feeds 2% less — km 1 went −647 → **−665** Vigor, km 7 −11 → **−13**.

```
validate --strict   ✅ 0/0 · content hash f74773a3 → 93923ad1
simulate --strict   exit 0 · 0 broken bands · 12 warnings
swift test          242 passed (236 + 6 for the plural rule)
digest              tuning c2ed0785… → 2634076e…
                    records, spawns and quests byte-identical
```

Full design record: `content/spec/spec-economy.md` §4b.

### Where we stopped (2026-09-14) part 2 — mob XP halved (`6e3c18e`, NOT deployed)

**Driven by the database, not by a model.** The live rows said it plainly: the archer was
**level 24, estate T7, km 41, in 5.94 days** — 2,296,342 XP earned, **386,590 a day**,
3.9 levels a day. Two other accounts ran 15–27× slower, so the spread is play intensity,
not balance — but the top of it reaches the cap in ~50 days against a design that asks for
90+.

**Kills are the whole faucet, which is what makes a mob-XP lever work at all.** The
warrior reached level 13 in 12 days having claimed **zero** quests. The archer's 17 claimed
jobs are ≈51k XP against 2.3M — **2%**. Between 95% and 100% of everything earned comes
from killing things.

**`mobXP.coefficient` 26.0 → 13.0, and every `xpReward` rebaked with it.** Both halves
are required and this nearly went wrong: **the game never reads the coefficient.** It reads
`xpReward` straight out of `enemies.json`; the coefficient is design-time input for the
generator and the spec tables (`ContentDigest` says so in its own comment). Change only the
coefficient and nothing moves for the player; change only the JSON and the next creature
authored lands on the old scale.

| | 🐍 5 | 🦅 17 | 🐗 38 | 🫎 110 | 🦬 500 | 🐈‍⬛ 600 | 🐺 690 | 🐻 1800 | 🐻‍❄️ 5000 |
|---|---|---|---|---|---|---|---|---|---|
| було | 10 | 34 | 76 | 223 | 1008 | 1199 | 1385 | 3632 | 10020 |

Values are **solved then rounded to two significant figures** — a documented step, not a
hand-edit, so a new creature is derived the same way. `spec bestiary` prints the unrounded
number (504 where the file says 500) and neither is wrong; `Enemy.xpReward`'s doc comment
carries the rule.

**Quests were not touched, and the digest proves it** — the `quests` half is byte-identical.
That is not luck: `questReward` rides `mobXP.exponent`, which did not move, and never sees
the coefficient. Had the exponent been the lever, this would have been a quest change too.

**The cost, named by the report rather than by me.** The finding changed identity from
`opening.shallow_is_bankrupt` to **`opening.vigor_bankrupt`** — *"levels 1–3 end 11 Vigor
short at their cheapest holdable depth (km 7)"*. There is no longer a depth that is both
survivable and profitable before the estate exists. **XP and Vigor are one currency at one
remove**: fewer XP per kill means more kills per level, and every kill costs Vigor. It is
11 Vigor — marginal, not fatal — and it belongs to the opening's own knobs, not to the XP
rate.

```
pace to 40        83 / 79 days → 173 / 167     (band is 72–200; c=11 would trip too_slow)
km 1 → level 4    53.4 kills → 106.1
validate --strict ✅ 0/0 · content hash 5fa9ab72 → f74773a3
simulate --strict exit 0 · 0 broken bands · 12 warnings
digest            records b410865d… → bef20549…   tuning ee45b18a… → c2ed0785…
                  spawns and quests byte-identical
```

### Where we stopped (2026-09-14) — tier 1 of the bestiary (`a0f90a8`, NOT deployed)

Two creatures were added and two were re-statted. *(Committed since, as `a0f90a8`; still
not on the Pi, which runs `aa18f57` with content hash `4eac64ff`.)*

| | |
|---|---|
| new | 🐍 `enemy.wild_viper` L1 `trash` · 🦅 `enemy.wild_eagle` L1 `skirmisher`, both km 1–10, **both with an empty loot table** |
| moved | 🐗 `enemy.wild_boar` L1 `trash` → **L2 `normal`**, km 2–11, stats regenerated (HP 34→88, DEF 6→16, XP 10→76) |
| re-statted | 🫎 `enemy.wild_moose` HP **73 → 114**, nothing else |
| **re-solved** | the other five — 🦬 bison, 🐈‍⬛ lynx, 🐺 wolf, 🐻 bear, 🐻‍❄️ rabid bear. Stat lines only; levels, archetypes, km bands, loot and XP all untouched |
| unfrozen | 🫎 moose DEF 24→**20**, crit 8→**7**, dodge 4→**3** — the last pre-re-spread curve in the file, and the generator's 114 HP is solved against DEF 20 anyway |

**The whole point was the XP ladder, and XP has exactly two inputs.**
`round(mobXP.coefficient · level^1.55 · archetype.xpMultiplier)` — HP and ATK do not enter
it. So the first step fell from **×22.3 to ×3.4** by choosing levels and archetypes, not by
touching a stat: `10 → 34 → 76 → 223`. Km 1 costs 53.4 kills to reach level 4 instead of
92.2, and km 2 became a rung of its own.

*(Every figure in this section is the tier-1 measurement and was superseded hours later by
the XP halving above — the ladder is `5 → 17 → 38 → 110` now and km 1 costs 106.1 kills.
The ratios between the rungs are what this section is about, and those did not change.)*

**Tier 1 is on a different stat recipe from the rest of the roster, on purpose: HP 100% of
contract, ATK 65%, DEF/crit/dodge on curve.** The shipped roster carries ~60% of both, and
the measurement behind the split is that a real level-1 player has the **on-curve weapon**
(the starter weapons carry the ATTACK the budget prices for a `main_hand` at itemLevel 1 —
sword 7 against 7.56, bow 6 against 6.24) and **no armour** — DEF 12
against the reference character's 30.9. So a full-contract mob costs an actual new player
1.5× the bar its archetype asks for; 0.65 cancels that and HP needs no correction at all.
Expect `content.roster_off_curve` on the ATK of all four **for ever** — the report measures
the reference's full kit, the recipe is calibrated against the kit registration grants.

```
validate --strict   ✅ 0/0 · 9 → 11 enemies · content hash 4eac64ff → 5fa9ab72
simulate --strict   exit 0 · 0 broken bands · 12 warnings — the count it started at
                    (roster_off_curve fell 9 → 7 when the five were re-solved)
swift test          236 passed
digest              records f6fc4212… → b410865d…   spawns eaea309f… → c9bdb57d…
                    tuning and quests byte-identical
```

**Then the rest of the roster was re-solved, because tier 1 made it measurable.**
Danger had been collapsing with depth: the five carried **21–45%** of their archetype's
contracted cost against tier 1's 54–61%, a level-10 lynx cost the same 6% of the bar as a
level-1 viper, and the level-1 eagle (17%) was more dangerous than the level-22 **elite**
(16%, contract 62%). Win rate 100% against all nine. They are solved to **65–78% of
contract — not 100%** — against the wardrobe `spec-items.md` §3 says the catalogue can
actually fill (40–53% of the on-curve kit), which is why this could ship without the gear
ladder: +14…+45%, not ×2. **It is provisional**: if the gear ladder ever lands, re-solve
these five against it. DEF/crit/dodge also came off the Phase-10 freeze — the bison had
been absorbing like a level-11 creature, the bear like a level-21 one.

The cost is in the ledger's WIN column, not its Vigor column: km 10 fell 95% → 88%, km 13
66% → 46%, km 17 34% → 8%. **The cheapest depth a level 1–3 player can hold moved km 10 →
km 7**, and the profitable-and-survivable window narrowed from km 4–11 to **km 4–7**.

**Two prices of tier 1, both measured and both accepted:** km 1 now drops **no food at all** (neither
new creature has loot, and the boar was the only meat there), and a level-1 creature covers
km 1–10, so it drags that whole band's average XP down — the opening ledger's km 4 fell
from **+44 Vigor to +3**, km 7 from +66 to +45. **That second one recurs every time a tier
is added below an existing one.** It is the km rule working, not a defect.

Also in this change, and unrelated to the mobs: `exploration.outcome.encounter.lost` said
«**прорвав** ваш захист» — masculine past tense, so «Скажена рись **прорвав**» has been
wrong on screen since the lynx shipped. Now «проламує», present tense, which is what the
other 28 combat strings already use. And `SpecTables.economy` had `enemy.wild_boar`
hardcoded with prose reading "the pure-boar path at km 1–3"; it looks the creature up now
and names none, because that sentence is exactly what the boar's move would have falsified.

Full account: `.memory/sessions.md` (2026-09-14). Specification amendments:
`content/spec/spec-bestiary.md` §3 and §8.

### Where we stopped (2026-09-12)

**The bot is LIVE on the Pi running `aa18f57`**, restarted 2026-09-12 19:43 Kyiv.
Content hash `4eac64ff`, **content schema v11**. *(True of the DEPLOYMENT to this day — but
`origin/main` moved on afterwards: five commits have landed since, listed in the
"Where things stand right now" table above.)*

That restart applied the first database migration since the wipe (`AddWalkCounters`).
Verified in the database itself rather than from the log line: both columns present as
`bigint DEFAULT 0`, all four indexes created, 5 users and **zero NULLs**. `Code: 400`
held at its 913 baseline, stderr empty, no `[ROUTE]` / `[COMBAT]` / `[SCREEN]`, 0 unstable
restarts. **A log line says what the code tried; the table says what happened — check the
table.**

**2026-09-12 part 2 — leaderboards.** Four all-time boards in the quest journal: ⚔️ level ·
🎖 arena honor · 🌲 deepest km · 🚶 total km walked, as tabs redrawing one message. Two new
lifetime columns (`deepest_km`, `total_km_walked`) with a single writer,
`User.recordWalk(toKm:)`, on the `rollStep` funnel. A migration shipped with it and **applied cleanly on the
19:43 restart**. `Leaderboard` in code, «Рейтинги» on screen — `rating` is taken here for
crit/dodge/accuracy.

Two things the pre-commit audit caught and a fresh session should not re-learn: **the 🎖
board already existed** inside the Arena, rendering the same ladder since Phase 8.3 with
`var rank = 1` and no tie-sharing, so the two screens disagreed — both read one
`LeaderboardService` now; and **the depth/distance counters started at zero for everyone**,
because no depth record was ever stored to backfill from (`exploration_state` is deleted
when the expedition ends). Seasons are a decided future direction: auto-memory
`project-leaderboards-will-go-seasonal`, `project-damage-sources-named-separately`.

**2026-09-12 — the roots, and what else hid behind them.** One game-code change since the
doc pass: a player asked why a root took 22 HP when it used to take 10. It took 11; hunger
took the other 11 on the same step, and `.trip` reported the sum under the root's own label.
The audit found the tick was applied once in `rollStep` and then each branch had to carry it:
of the ten exits reachable while starving, two carried it, one fused it, one blamed a beast,
and six dropped it silently. `rollStep` returns a `StepResult` now and every source
of damage prints its own line. Reporting only — all four digest hashes byte-identical.
**Deployed 2026-09-12 19:43**, in the same restart as the leaderboards.
Full account in `.memory/sessions.md` (2026-09-12), auto-memory
`project-damage-sources-named-separately`.

**The session before it changed no game code.** It was a documentation and memory audit: the
session preamble was ~20,300 tokens with about 45% of it narrative the memory bank already
held, and one narrative existed in three places at once. The split now in force is **the
doc keeps the RULE, the memory bank keeps the REASON** — `CLAUDE.md` states the imperative
and the trap, then points at the record. Seven stale memory records were corrected in the
same pass. Full account: `.memory/sessions.md` (2026-09-12) and the auto-memory
`feedback-docs-keep-the-rule`.

**What a fresh session should know about the eleven polish commits before those two.** Every single
defect came from someone PLAYING — none from a test. The pattern worth carrying: each was a
place where the code was right and could not say so, or where a number was shown in a unit
it was not measured in. Three of the last four were found by the user glancing at a screen,
not by running anything. **That is still the most productive way to find the next one, and
it is exactly what has not been done to the three surfaces below.**

> ## Next action: walk it. Nothing below has been looked at.
>
> Thirteen commits are live, **five more are committed and not deployed**, and every
> surface listed here is unopened by a human. That is the whole next action. Every defect
> this project has found came from someone glancing at a screen, not from running anything
> — so this list is the highest-yield thing available, and it costs one session in Telegram.
> The 09-14 / 09-15 items need the deploy first (schema bump + migration, see the table at
> the top); the 09-12 and older ones are already live and can be walked today.
>
> **Added 2026-09-15, not built into a deploy yet — walk it FIRST:**
> - **fail a flee four times on a warrior.** The fifth attempt must always work, whatever
>   the enemy. 40% means four failures happen in 13% of escapes, so this is reachable in a
>   session rather than a curiosity — tap Flee at a beast you can survive and count. The
>   player is told nothing, so what you are checking is that the fifth tap ends the fight.
> - **check the counter does NOT carry between fights.** Fail twice, escape, walk into the
>   next encounter and fail there: the second fight must start its own count from zero.
>
> **Added 2026-09-14, also never walked:**
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
> **Added 2026-09-12, never walked:**
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
> deploy, 913 an hour after, and 913 after the 09-12 restart, with `[ROUTE]` / `[COMBAT]` /
> `[SCREEN]` silent throughout. If a new screen bug is ever reported, this is the cheap
> first look:
>
> ```
> ssh rpi5@192.168.0.203 'grep -c "^Code: 400" ~/.pm2/logs/ROI-out.log'   # baseline 913
> ssh rpi5@192.168.0.203 'grep -E "\[ROUTE\]|\[COMBAT\]|\[SCREEN\]" ~/.pm2/logs/ROI-out.log'
> ```
>
> **Deploying to the Pi** (done successfully on 09-12; the recipe works as written):
> `git push` — user-side, never you — then on the Pi `git pull --ff-only`, build, and
> **ASK before `pm2 restart ROI`**. Two traps that cost real time: swiftenv's `PATH` lives
> in `.bashrc`, which a non-interactive `ssh` never reads, and `pgrep -f swift-build` matches
> the ssh command's own argument string (use `pgrep -x`). Auto-memory
> `project-pi-deploy-swiftenv`, `linux-build-gap`. A content or schema change must ship the
> new `content/data` and the new binary TOGETHER. Free pre-flight that never touches the
> running bot or the database:
> `ROI_PROJECT_PATH=/home/rpi5/RestOfIryna ./.build/debug/RestOfIryna --content-digest`.
> **After a migration, verify the TABLE, not the log line.**

### What the live-play polish landed (eleven commits, 2026-09-09 → 11; two more on 09-12)

Every defect came from someone PLAYING; none from a test. The pattern worth carrying: each
was a place where the code was right and could not say so, or where a number was shown in a
unit it was not measured in. Full narrative in `.memory/sessions.md` (the 09-09 → 09-11
entries); the rules they produced are in `CLAUDE.md`.

- `aa18f57` **four boards, and the first counters the game ever kept** (09-12) — the
  leaderboards, plus `deepest_km` / `total_km_walked`, the first cumulative counters this
  game has ever stored. The pre-commit audit found the Arena had been rendering the same
  honor ladder since Phase 8.3 with a different idea of a tie; both read one service now.
- `b402b81` **a root that took 11 and said 22** (09-12) — `.trip` reported
  `trip + starvation` under the root's own label. Of `rollStep`'s ten exits reachable while
  starving, two carried the tick, one fused it, one blamed a beast, six dropped it silently.
  `StepResult` carries it now, and every source prints its own line.
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

**The debt Phase 9 wrote itself is PAID — and its numbers have moved twice since.**
`OpeningLedger` measured the opening instead of assuming it, and the SHAPE it found holds:
the first hour is a teaching problem more than a tuning one. Every figure changed under the
09-14 roster re-solve and the XP halving, though, and the finding is now
**`opening.vigor_bankrupt`**: km 1 nets **−665**, km 4 nets **−106**, and **km 7** is the
cheapest depth a level 1–3 player can actually hold (97% win, net −13 Vigor). Read the
current ledger from `roi-content spec opening -c release`, never from a doc. Auto-memory
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
purpose, and **157–173 days since the 09-14 XP halving**. `zones.json` landed with it: the foraging pools left `ExplorationService`, the last
content in Swift. Numbers and the layout table: `.memory/rebalance.md` §Phase 8E.

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
from level 1 to 40, **157–173 days** on a tended estate (warrior 173.0 / archer 166.7 / mage
156.8 — it was 78–87 before the 09-14 XP halving; the band the report gates on is 72–200). `EnemyGenerator` is what the
post-rebalance regeneration will lean on — run at design time and frozen, never at runtime.
What each phase taught: `.memory/rebalance.md`.

**Current digest baseline (2026-09-15, schema v12):** `records bef20549a700d5e0` ·
`tuning 43b809a87450a3b8` · `spawns c9bdb57d456adc26` · `quests 30de20902006e3b9`. **This
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
swift test                                   # 246 tests, ~0.2s
```

## What Works Now (shipped game)

Registration · exploration (active + passive, three-tier visit decay, restart-safe
scheduler) · turn-based PvE combat with 9 class techniques · estate (plots,
warehouse, workshop, kitchen, weapon/bag/estate upgrades, technique gates) ·
capital hub (travel, Trader, Tavern with dice/darts, Fortune Teller, Master with
durability + enchant, player Market, synchronous Trade) · Guilds (roster, invites,
item vault, silver treasury) · Arena (live PvP duel, Honor ELO, stakes, daily
budget) · daily NPC quests derived from a stable hash, **taken by hand at the NPC** (nothing counts until the player accepts the job), + quest journal · **four all-time
leaderboards behind that journal** (⚔️ level · 🎖 arena honor · 🌲 deepest km · 🚶 total km
walked) as tabs redrawing one message.

Every daily system keys off `GameDay` (rolls at **12:00 Kyiv**). EN + UK
localization (**1025 / 1073 keys** — uk carries 13 `.m`/`.f` player-gender pairs, 33
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
