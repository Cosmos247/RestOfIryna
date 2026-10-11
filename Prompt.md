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

### Where things stand right now (the Pi and git as read 2026-10-11 02:57)

| | |
|---|---|
| HEAD | **this commit** (the 10-11 sync pass: records, two comments' reasons, two unread fields) on top of **`a9170f7`** (`fb37519`'s hash fill), **`fb37519`** (the Chancellery: the class change for zlatnyks), **`a683888`** (`021e9ac`'s hash fill), **`021e9ac`** (a level-up keeps the armour's HP), **`7ee41c1`** (`1f4b442`'s hash fill), **`1f4b442`** (the zlatnyks: named, credited by hand, shown; the profile's silver declines), **`608f2c5`**, **`04368cd`** (the 10-10 sync pass), **`743f042`**, **`7995d2a`** (the armour repair halved), **`248ce7e`**, **`7860aaa`** (the fortune teller's dispel and second card), **`0d556f5`**, **`d77d600`** (the recipe notebook), **`2d8ab41`**, **`34872f6`** (the 10-09 doc pass), **`4459f79`** and **`de0e062`**. A commit cannot carry its own hash, so read HEAD off the machine; every hash and what it did is the **Commit index** at the top of `.memory/sessions.md` |
| pushed | `origin/main` is at **`de0e062`** (the owner pushed 2026-10-09). **Not pushed: every commit above it** (`4459f79` … `a9170f7`) **and this commit** — push is the owner's |
| running on the Pi | **`de0e062`**, online since **2026-10-09 01:30:47** — no restart since (read 10-11 02:57, pm2 restarts 9), still ONE `[WATCHDOG]` line in the log (10-08 11:47:53, before the limiter fix). Content schema **v20**, content hash **`47888401`**, `records 4c0802f927fb8be4`. The SDK's rate limiter is OFF, `PollWatchdog` runs, the Telegram client is HTTP/1.1. **Read it off the machine before acting on this line** (auto-memory `feedback-ask-the-machine-not-the-record`) |
| access | **The door is OPEN** since 2026-10-07 18:34 — `ROI_OPEN_ACCESS=1` in the Pi's `.env`. `allowed_users` at 10-11 02:57: open 14 · invite 6 · seed 4 · manual 1 (one new open-door account since 10-09 01:47); 5,441 forest fights since the door opened, 22 deaths. Close it by removing the line and restarting; nobody already in is locked out |
| waiting for a restart | **Six changes, all committed, one deploy** — content schema **v22**, so `content/data` and the binary ship TOGETHER, and four migrations. The six: the **Chancellery** (`fb37519`: «🟡 Канцелярія» under the palace card, `treasury.json`, `ClassChangeService`, `CreateZlatnykPurchases`); **a level-up keeps the armour's HP** (`021e9ac`, Swift only); the **zlatnyks and the profile's silver** (`1f4b442`: `AddZlatnyks`, the watchman's credit notice, the profile's «🟡 N златників» line, `unit.silver` with the count — crediting is a DBeaver edit, `.memory/live-ops.md` → "Crediting zlatnyks"); the **armour repair halved** (`7995d2a`, content only); the **fortune teller's dispel and second card** (`7860aaa`: `AddFortuneStage`); and the **recipe notebook** (`d77d600`: `CreateRecipeNotes`). This sync pass adds comment and dead-field edits, with no behaviour change. Everything up to `de0e062` is live |

### Where the last sessions stopped (2026-10-10 → 10-11)

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

**0 — Ship the six, on the owner's word.**
- **Push is the owner's.** Then, on the Pi: `git pull --ff-only`, a detached debug build, and the
  pre-flight digest — it must read `records 92300a4769c8933e`, content hash `681d611a` (schema
  v22). Then **ASK before `pm2 restart ROI`**.
- **The four migrations** (`CreateRecipeNotes`, `AddFortuneStage`, `AddZlatnyks`,
  `CreateZlatnykPurchases`) were rehearsed together in one new batch over existing players.
- **After the restart, verify the TABLES:**
  - `users.zlatnyks` / `zlatnyks_announced` with the CHECK;
  - `zlatnyk_purchases`;
  - `recipe_notes`;
  - `users.fortune_stage`.
- **Then walk** the six top blocks of `TODO.md` → "Walk list", starting by crediting a test
  account in DBeaver (`.memory/live-ops.md` → "Crediting zlatnyks").

**1 — Answer the players.** Read the answer off the code and data, end with a ready Ukrainian
reply. Snapshot SQL and its reading traps: `.memory/live-ops.md`.

**2 — Watch the poll loop.** Still one `[WATCHDOG]` line on 10-11 02:57 (10-08 11:47:53). A new one
in `~/.pm2/logs/ROI-out.log` is a freeze the limiter fix did not cover (`.memory/live-ops.md` → "Is
the bot alive?").

**3 — Questions waiting on the owner** — `TODO.md` → "Open, decided but not done":
- **the 10-11 block:** rename the code's `treasury` to `chancellery`? The unfeminized class name in
  the class-change banner; Telegram's Stars-only rule if zlatnyks are paid for outside the bot;
- **the 10-10 block:** repairing at the estate for hides; a stale fortune button that deletes the
  photo off the capital;
- **the two chosen-but-unanswered forms:** eating straight from the warehouse (its layout), and a
  hint under the estate-name prompt (its wording).

Build none of them without the owner's answer (auto-memory `feedback-unanswered-means-nothing`).

**4 — Read the rest of the `fight_log`.** Read on 10-10 for the repair (`.memory/live-ops.md` → "Day
four"): newcomers' busiest days ran 105–350 fights against the model's ≈25 a day, and 26% of wins end
untouched. Still unread: `estate_level` (do players hold the estate back? T6 gains nothing per day)
and how many wins are one tap — what the technique rework was for.

**5 — Someone opens the screens.** `TODO.md` → "Walk list": the six 2026-10-10/11 blocks once they
are live, the 10-09 ones now. No human has seen the whole King's chain, and `/reload` has never run
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
v20 on the Pi, refuses a mismatch). After a migration, verify the TABLE, not the log line. Recipe and
traps: auto-memory `linux-build-gap`, `project-pi-deploy-swiftenv`, `reference-deploy-rehearsal`.

### The baseline and the simulator

**The current baseline — on the Pi since 2026-10-09 01:30 (`de0e062`, schema v20):** `records
4c0802f927fb8be4` · `tuning 4edf65507bbb5e48` · `spawns 0cf31905171d7944` · `quests
30de20902006e3b9` · `king e3a492be1b017e81`, content hash `47888401`. **This is the one place the
current baseline is kept**; the superseded ones are in `.memory/sessions.md` → "Digest baselines —
superseded".
**The tree's baseline, waiting for the restart (the dispel, the repair halved and the Chancellery,
schema v22):** `records 92300a4769c8933e`, content hash `681d611a`, the other four halves as above
(the Chancellery moved `records` from `c3720e93c10c13a8`, content hash `c9cf0506`). It becomes the
current one when the Pi runs it; the line above then moves to the superseded list.
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
swift test                                   # 408 tests, ~5s
```


## Rules

`CLAUDE.md` is the full set and is loaded every session. The three that cost the most when
forgotten: **never push** (user-side only), **never start / restart / stop the bot without
asking** (the Mac instance is the one exception — stop it, it 409s the Pi), and **ask before
committing**. Content edits must pass `roi-content validate --strict`; balance-table edits
must also re-run `roi-content simulate --strict`.
