# ROI Session Primer

Read this first, then `.memory/INDEX.md`. `CLAUDE.md` (loaded every session) holds the rules; this
file holds only the live state, the open threads and the next action. Everything else has one
home: the changelog is the **Commit index** at the top of `.memory/sessions.md` (a dated entry per
session, a `## Deploy —` entry per restart); decisions and measurements, `.memory/rebalance.md`;
open items and the walk list, `TODO.md`; what the shipped game does, `README.md` → Roadmap and
`.memory/status.md`; the pipeline, `.memory/content-pipeline.md`.

## ⏳ ACTIVE WORK — the public test: player support, live-play polish, small features

**Since 2026-10-07 18:34 the game is public** (`ROI_OPEN_ACCESS=1`) and the owner relays players'
questions into the session. Answer from the code and data with a ready Ukrainian reply;
snapshots, reading traps and a verified FAQ: `.memory/live-ops.md`.

The pre-release rebalance is done and deployed (Phases 3–11). What is in flight is **fixing what
playing the deployed build reveals**, plus the small features the play asks for — every defect so
far came from someone PLAYING, none from a test. The newest feature is the **premium currency**:
the zlatnyk («златник» 🟡), credited by the owner by hand in DBeaver and spent in the palace's
Chancellery («🟡 Канцелярія», code `treasury`) on a class change. Gear work so far: durability as
each item's own (`bf15669`) and the armour's ladder through the Master's enchant (`bad142b`,
`spec-items.md` §11); class sets are parked (`.memory/class-sets-concept.md`). The armour's ladder
shipped WITHOUT the bestiary re-solve, which holds only at its price — a cheaper enchant or
anything stronger still needs the re-solve (auto-memory `project-post-rebalance-package`).

### Where things stand right now (the Pi and git as read 2026-10-17 15:45)

| | |
|---|---|
| HEAD | **this commit** (the leaderboard pages) on top of **`32cf650`** (the mage's barrier strikes back, schema v24), **`67aa073`** (the 2026-10-13 18:54 deploy recorded) and **`dda286f`** (`beed258`'s hash fill), the commit the Pi runs. A commit cannot carry its own hash, so read HEAD off the machine; every hash and what it did is the **Commit index** at the top of `.memory/sessions.md` |
| pushed | `origin/main` is at **`dda286f`** (the owner pushed 2026-10-13). **Not pushed: `67aa073`, `32cf650` and this commit** — push is the owner's |
| running on the Pi | **`dda286f`**, deployed **2026-10-13 18:54:16**; online since **2026-10-15 01:42:26**, when the Pi itself rebooted and pm2 resurrected the same build (its count reads 0 since). Still ONE `[WATCHDOG]` line in the log (10-08 11:47:53, before the limiter fix); `Code: 400` at 922 — nine `🌷rilenx🌷` refusals, an unescaped Telegram name (`.memory/live-ops.md`). Content schema **v23**, content hash **`9dba2746`**, `records 78ce585986927122`, `tuning 53e33d38021f0bf4`; no migration in that restart. One passive run straddled it (ending 19:37:05, resumed on its old plan). The SDK's rate limiter is OFF, `PollWatchdog` runs, the Telegram client is HTTP/1.1. **Read it off the machine before acting on this line** (auto-memory `feedback-ask-the-machine-not-the-record`) |
| access | **The door is OPEN** since 2026-10-07 18:34 — `ROI_OPEN_ACCESS=1` in the Pi's `.env`. `allowed_users` at 10-11 02:57: open 14 · invite 6 · seed 4 · manual 1 (one new open-door account since 10-09 01:47); 5,441 forest fights since the door opened, 22 deaths. Close it by removing the line and restarting; nobody already in is locked out |
| waiting for a restart | **The leaderboard pages** (Swift only) and **the mage's barrier strikes back** (`32cf650`, content + Swift, schema **v24**: the old binary refuses this content, a `/reload` included). The tree: schema v24, content hash `19c94a81`, `tuning 799a96eb5f8619df`, the other four halves unmoved. The 10-13 18:54 restart installed everything before it |

### Where the last sessions stopped (2026-10-11 → 10-17)

**10-17 — the Pi read; the leaderboard pages.** Read off the Pi: it runs `dda286f`, the 10-15
restart was the host rebooting, and only the barrier's spark waits — a testers' note for it went to
the owner. The log holds nine `🌷rilenx🌷` refusals (an unescaped Telegram name; offered, not fixed).
Then the journal's 🏆 boards learned to turn pages: ten a page, «◀️ N/M ▶️» wrapping round, a page's
first rank COUNTED so a tie across the edge keeps its place (`LeaderboardPaging`, 434 tests, every
live page matched Postgres `rank()`). The laptop died mid-build; the next session resumed from the
transcript. `.memory/sessions.md` → the 10-17 entry.

**10-13, evening — the forest's Defend, measured; the mage's barrier strikes back.** Asked how the
three Defend buttons work: every Defend tap costs HP against an Attack (−2.6 / −4.4 / −3.2 at L9),
≈1.7% of live taps, its one use a sure finisher. Proposed «звір замахується» (a telegraphed ×2 blow
that a Defend stops) — the owner rejected that quiz to clarify and began with the mage: «нічого» is
bad. Built at the owner's 15% (`defend.mageChipMultiplier` 0.5, schema v24): a chip ignores the level
gap, and above ~20% "barrier every round" beats attacking a stronger beast. `.memory/rebalance.md` →
"The forest's Defend, measured"; auto-memory `project-forest-defend`.

**10-13 — the deploy** (`98580ce` → `dda286f`, 18:54, on the owner's order after the push): pull,
a 142 s build, the digest matched the Mac, the restart; no migration. One passive run straddled it.
The broken-set fix landed on one player at boot (a Forester jerkin at 0/47). Before it, the testers'
note was rechecked against the code — three corrections — and shortened on the owner's word.
`.memory/sessions.md` → the deploy entry.

**10-12, late — the sync pass** (`beed258`). Seven functions with no caller removed — the six from
April and `renderLocation` — with `stub.coming_soon` and `AutobattleResult`'s two unread fields;
`passive.retreatBelowHpPercent` made required (it came in optional); README's roadmap, the GDD's
passive lines, the pipeline, localization and status records synced. Two things stay on purpose: the
passive report's unread `stepsTaken` (the Pi's binary decodes it as required, so a rollback would
strand a report) and the dead `walkRoomDoubleSpeed` knob (deleting it moves the digest the restart
is checked against). `.memory/sessions.md` → the 10-12 sync pass.

**10-11 evening → 10-12 — the 🏕 Expedition walks there and back** (`fac8d5f`; the owner's report: the governor
«телепортує додому після максимального км»). Half the 3-minute strides out, half home, the door last
(30/60/90 min = 5/10/15 km, shown on the buttons). He turns below half his HP, or when his Vigor only
covers the road home and nothing is left to eat; he eats any bag food only when he must, the smallest
first and a taken job's food last; the bag is his while he is out. 📍 on the waiting screen; the food
eaten, an early turn and a death's losses in the report. Measured and decided over four quizzes
(`.memory/rebalance.md`), the screens approved as a played sample, checked on a scratch Postgres
(eight scenarios). Content + Swift: live on a restart, never on a `/reload`.

**10-12 — eating several units at once: built, then rolled back.** A players' proposal, built as the
owner's variant A («Скільки … з'їсти?», typed); the owner had it rolled back the same day, before it
was committed. One tap still eats one unit. Also recorded that day: wiping one player and changing a
gender in DBeaver (`.memory/live-ops.md`).

**10-11, night — the silver line** (a players' proposal). Every question that spends silver — the
Master's repair and buy, a market lot, «Відчарувати» — ends with «✅/❌ 🪙 Срібло (є/треба)»; the
owner picked the format and all four. `RequirementLine.silver` builds all nine such lines. Swift
only: live on a restart.

**10-11, late evening — a broken piece no longer counts toward its set.** Asked whether broken armour
gives anything: nothing of its own, but a worn set still counted it (a fully broken Forester set
kept +2 DEF · +6 HP · +2 dodge). Fixed on the owner's word through one test, `isBroken`; checked on
the real code before and after. Nobody wore a broken piece (re-read 23:18), so the restart moves no one.
The broken weapon's half rounds half UP (7 → 4), not down as the FAQ said; the records are fixed.

**10-11, late evening — a lone unit needs no quantity** (a players' proposal). The owner picked
variant A of three: where the units come from holds exactly one, the tap acts on it — the trader
sells it, the market skips to the price, the trade offers it, the guild vault and the warehouse's
✏️ N move it. A taken job that needs the item keeps the prompt. Swift only: live on a restart.

**10-11, late evening — an apostrophe in a name; the two players' proposals dropped.** Asked to «do
what the players proposed», the 10-08 pair went out again as samples on real data (six players at
0 Vigor with food only in the warehouse; Iren still at step 6). The owner answered only a finding of
mine and dropped both: «питання про кнопку на складі й рядок на кроці 6 можеш взагалі забути» —
never raise them again. The finding, built: «Дар'я» and «Солов'їний гай» were refused as
"symbols"; an apostrophe between two letters (' ʼ ’) is now accepted and stored as ' —
`PlayerNameRules`, shared with the guild invite's lookup. Swift only: live on a restart.

**10-11, afternoon — the delivery jobs break even against buying.** A table of every NPC job against
its items' trader price; on the owner's rule the five that lost (hides, iron, ore, raw meat, the
cook's dishes) were raised to the minimum — 60 · 91 · 141 · 60 · 40 authored. The jobs' daily take
78 → 98 at L1, 153 → 217 at L40. Content only: live on a `/reload`.

**10-11, 13:21 — the six deployed**, on the owner's word after the push: pull, a 130 s build, the
digest matched, the restart, the four migrations verified on the tables. Before it: the class
change worded as a charter («📜 Грамота про зміну класу», «✅ Скріпити печаткою»), folded into the
Chancellery's own commit, and a testers' note. The Mac's DBeaver needed its tunnel back up and a
metadata refresh (`.memory/sessions.md` → the deploy entry).

**Live since the 10-13 18:54 restart:** the expedition there and back
(`project-passive-expedition-rework`), the silver line, the apostrophe (`project-name-apostrophe`),
the lone unit (`project-lone-unit-no-prompt`), the broken set piece and the delivery jobs' rewards.

**Live since the 10-11 13:21 restart, each with its auto-memory:** the Chancellery's class change for 100 🟡,
worded as a charter («📜 Грамота про зміну класу», never «указ»; `1c39595`,
`project-premium-currency-zlatnyk`); a level-up keeps the armour's HP (`021e9ac`); the zlatnyks,
credited in DBeaver and announced by the watchman, and the profile's declining silver (`1f4b442`);
the armour repair halved (`7995d2a`, `project-repair-cost-complaint`); the fortune teller's dispel and
second card (`7860aaa`, `project-fortune-dispel-and-second-card`); the recipe notebook (`d77d600`,
`project-recipe-notebook`). Everything earlier: `.memory/sessions.md`.

### Next action

**0 — Walk what just went live.** First the passive run that straddled the 10-13 restart (ending
19:37:05): did its report arrive, and does it read right for a row started on the old plan? Then
**walk**: the five blocks on top of `TODO.md` → "Walk list" (live since 10-13 18:54), and the six
under them (live since 10-11 13:21). For the Chancellery, start by crediting a test account in
DBeaver (`.memory/live-ops.md` → "Crediting zlatnyks"; if the grid calls the new columns read-only,
quit DBeaver and reopen, or use the SQL editor). The testers' note for the 10-13 restart went to the
owner the same day.

**1 — Answer the players.** Read the answer off the code and data, end with a ready Ukrainian
reply. Snapshot SQL and its reading traps: `.memory/live-ops.md`.

**2 — Watch the poll loop.** Still one `[WATCHDOG]` line on 10-13 18:56 (10-08 11:47:53). A new one
in `~/.pm2/logs/ROI-out.log` is a freeze the limiter fix did not cover (`.memory/live-ops.md` → "Is
the bot alive?").

**3 — Questions waiting on the owner** — `TODO.md` → "Open, decided but not done":
- **the 10-13 Defend block:** «звір замахується» (in discussion — the owner said «По перше» and
  started with the barrier, so more points may follow); Defend's lines that say nothing; a validator
  ceiling for the barrier's spark;
- **the 10-11 evening block:** the trader prompt's «Скільки Лісові горіхи продати?» (its case); the
  refusal copy that does not mention the apostrophe; two questions open in town at once, where the
  older one takes a typed number (found 10-12); the guild invite's `ILIKE` wildcards; the lone
  unit's one-tap sale (chosen knowingly — the «1» / «Усі (N)» buttons if it bites);
- **the 10-11 block:** rename the code's `treasury` to `chancellery`? The unfeminized class name in
  the class-change banner; Telegram's Stars-only rule if zlatnyks are paid for outside the bot;
- **the 10-10 block:** repairing at the estate for hides; a stale fortune button that deletes the
  photo off the capital.

Eating straight from the warehouse and the estate-name hint are DROPPED (10-11, the owner) — never
raise them again.

Build none of them without the owner's answer (auto-memory `feedback-unanswered-means-nothing`).

**4 — Read the rest of the `fight_log`.** Read on 10-10 for the repair (`.memory/live-ops.md` → "Day
four"): newcomers' busiest days ran 105–350 fights against the model's ≈25 a day, and 26% of wins end
untouched. Still unread: `estate_level` (do players hold the estate back? T6 gains nothing per day)
and how many wins are one tap — what the technique rework was for.

**5 — Someone opens the screens.** `TODO.md` → "Walk list": the six 2026-10-10/11 blocks (live since
10-11 13:21), the 10-09 ones. No human has seen the whole King's chain, and `/reload` has never run
against a real database.

**6 — Older decisions waiting on the owner:** `TODO.md` → "Open, decided but not done". Not there
and still open:
- the t6–t9 weapon descriptions, written after the names were approved and never approved on their
  own;
- the emblem candidates (`content/lore.md` §14, none chosen);
- two ideas raised but not yet asked:
  - a «Відновити» service at the Master (reset the max for silver, keep the enchant: a silver sink);
  - the Master refusing to mend a piece worn to 1/1.

**Deploying to the Pi:** `git push` is the owner's, never yours. On the Pi: `git pull --ff-only`, a
detached debug build, then the free pre-flight
`ROI_PROJECT_PATH=/home/rpi5/RestOfIryna ./.build/debug/RestOfIryna --content-digest`, which must
match the Mac BEFORE the restart is ordered — then **ASK before `pm2 restart ROI`**. A content or
schema change ships `content/data` and the binary TOGETHER (the handshake — **v23** on the Pi, **v24** in the
tree since the 10-13 barrier — refuses a mismatch, a `/reload` included). After a migration, verify the TABLE, not the log line. Recipe and
traps: auto-memory `linux-build-gap`, `project-pi-deploy-swiftenv`, `reference-deploy-rehearsal`.

### The baseline and the simulator

**The current baseline — on the Pi since 2026-10-13 18:54 (`dda286f`, schema v23):** `records
78ce585986927122` · `tuning 53e33d38021f0bf4` · `spawns 0cf31905171d7944` · `quests
30de20902006e3b9` · `king e3a492be1b017e81`, content hash `9dba2746`. **This is the one place the
current baseline is kept**; the superseded ones are in `.memory/sessions.md` → "Digest baselines —
superseded". The tree is ahead of it until the next restart — the barrier's spark moved `tuning`
to `799a96eb5f8619df` and the content hash to `19c94a81` (schema v24); `records`, `spawns`,
`quests` and `king` did not move.
A knob is invisible to the digest until it is hashed (auto-memory `feedback-digest-names-constants`).

`simulate --strict`: 18 of 18 invariance rows, 0 broken bands, 18 warnings, all deliberate
(`TODO.md` → the standing deferrals). Pace to L40: 151–167 days (warrior 167.0 / archer 159.6 /
mage 150.9; band 72–200; taps/day ~711). The pace cannot see depth: the expedition model puts real
play at ~600–640 days (auto-memory `project-expedition-model`, `.memory/rebalance.md`).

### Commands

```
/content   /reload                           # dev-only, in Telegram: inspect and hot-swap
swift run roi-content validate --strict      # content integrity; exit 1 on any error
swift run -c release roi-content simulate    # balance sweep; --runs/--seed/--levels, --strict gates
swift run roi-content spec <table>           # progression · gates · bestiary · items · sets · economy · opening · king
swift run RestOfIryna --content-digest       # confirm ONLY the intended change moved
swift test                                   # 434 tests, ~5s
```


## Rules

`CLAUDE.md` is the full set and is loaded every session. The three that cost the most when
forgotten: **never push** (user-side only), **never start / restart / stop the bot without
asking** (the Mac instance is the one exception — stop it, it 409s the Pi), and **ask before
committing**. Content edits must pass `roi-content validate --strict`; balance-table edits
must also re-run `roi-content simulate --strict`.
