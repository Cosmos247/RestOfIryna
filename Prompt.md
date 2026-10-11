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

### Where things stand right now (the Pi and git as read 2026-10-11 22:26)

| | |
|---|---|
| HEAD | **this commit** (an apostrophe in a name; a lone unit needs no quantity; a broken piece no longer counts toward its set; the 10-08 pair dropped; the expedition research recorded) on top of **`5a7a3e5`** (`a9e5a98`'s hash fill), **`a9e5a98`** (the delivery jobs break even against buying), **`2e8e385`** (the 2026-10-11 13:21 deploy recorded), **`98580ce`** (`0b18908`'s hash fill; the class change's charter copy folded into `1c39595`), **`0b18908`** (the 10-11 sync pass), **`3a7d746`**, **`1c39595`** (the Chancellery: the class change for zlatnyks), **`a683888`**, **`021e9ac`** (a level-up keeps the armour's HP), **`7ee41c1`**, **`1f4b442`** (the zlatnyks), **`608f2c5`**, **`04368cd`** (the 10-10 sync pass), **`743f042`**, **`7995d2a`** (the armour repair halved), **`248ce7e`**, **`7860aaa`** (the dispel and second card), **`0d556f5`**, **`d77d600`** (the recipe notebook), **`2d8ab41`**, **`34872f6`**, **`4459f79`** and **`de0e062`**. A commit cannot carry its own hash, so read HEAD off the machine; every hash and what it did is the **Commit index** at the top of `.memory/sessions.md` |
| pushed | `origin/main` is at **`98580ce`** (the owner pushed 2026-10-11). **Not pushed: `2e8e385`, `a9e5a98`, `5a7a3e5` and this commit** — push is the owner's |
| running on the Pi | **`98580ce`**, online since **2026-10-11 13:21:10** (pm2 restarts 10; read again at 22:26), still ONE `[WATCHDOG]` line in the log (10-08 11:47:53, before the limiter fix). Content schema **v22**, content hash **`681d611a`**, `records 92300a4769c8933e`; the four migrations verified on the tables. The SDK's rate limiter is OFF, `PollWatchdog` runs, the Telegram client is HTTP/1.1. **Read it off the machine before acting on this line** (auto-memory `feedback-ask-the-machine-not-the-record`) |
| access | **The door is OPEN** since 2026-10-07 18:34 — `ROI_OPEN_ACCESS=1` in the Pi's `.env`. `allowed_users` at 10-11 02:57: open 14 · invite 6 · seed 4 · manual 1 (one new open-door account since 10-09 01:47); 5,441 forest fights since the door opened, 22 deaths. Close it by removing the line and restarting; nobody already in is locked out |
| waiting for a restart | **An apostrophe in a name**, **a lone unit needs no quantity** and **a broken piece no longer counts toward its set** (this commit, Swift only). Before it, the six went live at the 2026-10-11 13:21 restart: the Chancellery (`1c39595`, «📜 Грамота про зміну класу»), a level-up keeps the armour's HP (`021e9ac`), the zlatnyks and the profile's silver (`1f4b442`), the armour repair halved (`7995d2a`), the fortune teller's dispel and second card (`7860aaa`) and the recipe notebook (`d77d600`). What it carried: `.memory/sessions.md` → `## Deploy — 2026-10-11 13:21`. **Waiting for a `/reload`**: the delivery jobs' rewards (`quests.json` only; the tree's content hash `cb2b3fed`, `records 78ce585986927122`) |

### Where the last sessions stopped (2026-10-10 → 10-11)

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

**10-11, evening — the 🏕 Expedition researched, nothing built** (session `52cd50db`, no commit).
The passive run walks only deeper and lands home at once, books those km as 🌲 Глибина, runs one
step short, never retreats and logs no death. The owner chose there-and-back with a 3-minute step
(5/10/15 km), retreat below 50% HP and when the Vigor left only covers the road home, the depth on
the buttons, 📍 and 💀. **Two questions are open**: does the player eat on the run, and can it go
past the chosen km? TODO → "Open, decided but not done"; `.memory/sessions.md` → that entry.

**10-11, afternoon — the delivery jobs break even against buying.** A table of every NPC job against
its items' trader price; on the owner's rule the five that lost (hides, iron, ore, raw meat, the
cook's dishes) were raised to the minimum — 60 · 91 · 141 · 60 · 40 authored. The jobs' daily take
78 → 98 at L1, 153 → 217 at L40. Content only: live on a `/reload`.

**10-11, 13:21 — the six deployed**, on the owner's word after the push: pull, a 130 s build, the
digest matched, the restart, the four migrations verified on the tables. Before it: the class
change worded as a charter («📜 Грамота про зміну класу», «✅ Скріпити печаткою»), folded into the
Chancellery's own commit, and a testers' note. The Mac's DBeaver needed its tunnel back up and a
metadata refresh (`.memory/sessions.md` → the deploy entry).

**10-11, the sync pass — records, two comments' reasons, two unread fields.**
- The session's research went into `.memory/rebalance.md` → "The zlatnyk and the Chancellery,
  decided".
- «Fluent saves whole rows» was corrected everywhere it was claimed. Fluent writes only changed
  fields; the background-writer guard stands for the true reason: a copy's stale values, installed
  as the session.
- Stale GDD, `game-core` and status lines were fixed; TODO gained its 10-11 walk-list and open
  blocks; `ClassChangeService`'s unread `Line.hp` and `Outcome.from` were removed.
- `.memory/sessions.md` → the 10-11 sync pass entry.

**10-11, night — the Chancellery built.** The owner's quizzes chose:
- the class change and nothing else (no new name or estate name, no upgrades, gender unchangeable);
- the weapon reforged at its tier and wear;
- no limit but the price, 100 🟡;
- a purchase log;
- then renamed «Скарбниця» → «Канцелярія» (the guild already has a «🪙 Скарбниця»; the code keeps
  `treasury`).
- then the class change worded as a charter: «📜 Грамота про зміну класу», 📜 on the preview,
  «✅ Скріпити печаткою» on the confirm — never «указ», the decree chain's word on the same screen
  (folded into `1c39595`).

Rehearsed at 120 checks twice (the screens word for word, a rollback, a stale second tap) and four
planted mutants caught. Auto-memory `project-premium-currency-zlatnyk`.

**10-11, later — a level-up keeps the armour's HP.** Found while designing the class change:
`applyLevelDerivedStats` clamped HP to the base maximum (209/209 at L17 came out 176/214). It was
fixed on its own, on the owner's word.

**10-10 late → 10-11 — the zlatnyk named, credited, shown.**
- The owner picked «златник» (en *zlatnyk*, the owner's spelling).
- The balance is a `users` column outside the cached `User`, credited in DBeaver, and the watchman
  announces each credit.
- The profile shows it under silver, only above 0.
- The played sample turned up the profile's fixed «срібників», fixed the same session.

**10-10 — the recipe notebook, the dispel and second card, the repair halved, a sync pass.**
- **The notebook:** «📌 У нотатник» on eight price cards, at most three notes in the journal.
- **The dispel:** «🕯 Відчарувати» for 30 on the free card's running effect, then ONE final
  «🔮 Друга карта» for 20.
- **The repair:** `repairCostFraction` 0.25, on live-play wear data.

Each has its auto-memory (`project-recipe-notebook`, `project-fortune-dispel-and-second-card`,
`project-repair-cost-complaint`). Everything earlier: `.memory/sessions.md`.

### Next action

**0 — `/reload` for the delivery jobs' rewards** (the owner's, in Telegram; `/content` must then
read hash `cb2b3fed`), and a restart for the apostrophe, the lone unit and the broken set piece (the
owner's: push, pull, build, the digest, then ASK). Then **walk the six, now live.** Start by crediting a test account in DBeaver (`.memory/live-ops.md`
→ "Crediting zlatnyks"; if the grid calls the new columns read-only, quit DBeaver and reopen, or use the
SQL editor), then
the six top blocks of `TODO.md` → "Walk list". The testers' note went to the owner on 10-11.

**1 — Answer the players.** Read the answer off the code and data, end with a ready Ukrainian
reply. Snapshot SQL and its reading traps: `.memory/live-ops.md`.

**2 — Watch the poll loop.** Still one `[WATCHDOG]` line on 10-11 22:26 (10-08 11:47:53). A new one
in `~/.pm2/logs/ROI-out.log` is a freeze the limiter fix did not cover (`.memory/live-ops.md` → "Is
the bot alive?").

**3 — Questions waiting on the owner** — `TODO.md` → "Open, decided but not done":
- **the 10-11 evening block:** the 🏕 Expedition's two open questions (does the player eat on the
  run; can it go past the chosen km?) — the rest of its design is chosen; the refusal copy that does
  not mention the apostrophe; the trader prompt's «Скільки Лісові горіхи продати?» (its case);
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
- three ideas raised but not yet asked:
  - a «Відновити» service at the Master (reset the max for silver, keep the enchant: a silver sink);
  - the Master refusing to mend a piece worn to 1/1;
  - the passive report naming its losses the way the death screen does.

**Deploying to the Pi:** `git push` is the owner's, never yours. On the Pi: `git pull --ff-only`, a
detached debug build, then the free pre-flight
`ROI_PROJECT_PATH=/home/rpi5/RestOfIryna ./.build/debug/RestOfIryna --content-digest`, which must
match the Mac BEFORE the restart is ordered — then **ASK before `pm2 restart ROI`**. A content or
schema change ships `content/data` and the binary TOGETHER (the handshake, **v22** in the tree and
on the Pi, refuses a mismatch). After a migration, verify the TABLE, not the log line. Recipe and
traps: auto-memory `linux-build-gap`, `project-pi-deploy-swiftenv`, `reference-deploy-rehearsal`.

### The baseline and the simulator

**The current baseline — on the Pi since 2026-10-11 13:21 (`98580ce`, schema v22):** `records
92300a4769c8933e` · `tuning 4edf65507bbb5e48` · `spawns 0cf31905171d7944` · `quests
30de20902006e3b9` · `king e3a492be1b017e81`, content hash `681d611a`. **This is the one place the
current baseline is kept**; the superseded ones are in `.memory/sessions.md` → "Digest baselines —
superseded".
**The tree's baseline, waiting for a `/reload` (the delivery jobs' rewards):** `records
78ce585986927122`, content hash `cb2b3fed`, the other four halves as above. It becomes the current one
when the Pi runs it; the line above then moves to the superseded list.
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
swift test                                   # 414 tests, ~5s
```


## Rules

`CLAUDE.md` is the full set and is loaded every session. The three that cost the most when
forgotten: **never push** (user-side only), **never start / restart / stop the bot without
asking** (the Mac instance is the one exception — stop it, it 409s the Pi), and **ask before
committing**. Content edits must pass `roi-content validate --strict`; balance-table edits
must also re-run `roi-content simulate --strict`.
