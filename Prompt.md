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
far came from someone PLAYING, none from a test. Gear work so far: durability as each item's own
(`bf15669`) and the armour's ladder through the Master's enchant (`bad142b`, `spec-items.md` §11)
are built; class sets are parked (`.memory/class-sets-concept.md`). The armour's ladder shipped
WITHOUT the bestiary re-solve, which holds only at its price — a cheaper enchant or anything
stronger still needs the re-solve (auto-memory `project-post-rebalance-package`).

### Where things stand right now (the Pi as read 2026-10-09 01:47; git re-read 2026-10-10)

| | |
|---|---|
| HEAD | **this hash fill** on top of **`7860aaa`** (the fortune teller's dispel and second card), **`0d556f5`** (`d77d600`'s hash fill), **`d77d600`** (the recipe notebook), **`2d8ab41`** (`34872f6`'s hash fill), **`34872f6`** (the doc pass: the session preamble trimmed against the records), **`4459f79`** (the sync pass that recorded the 10-09 01:30 deploy) and **`de0e062`**. A commit cannot carry its own hash, so read HEAD off the machine; every hash and what it did is the **Commit index** at the top of `.memory/sessions.md` |
| pushed | `origin/main` is at **`de0e062`** (the owner pushed 2026-10-09). **`4459f79`, `34872f6`, `2d8ab41`, `d77d600`, `0d556f5`, `7860aaa` and this hash fill are not pushed** — push is the owner's |
| running on the Pi | **`de0e062`**, restarted **2026-10-09 01:30:47** — content schema **v20**, content hash **`47888401`**, `records 4c0802f927fb8be4`. The SDK's rate limiter is OFF, `PollWatchdog` runs, the Telegram client is HTTP/1.1. Record: `.memory/sessions.md` → `## Deploy — 2026-10-09 01:30`. **Read it off the machine before acting on this line** (auto-memory `feedback-ask-the-machine-not-the-record`) |
| access | **The door is OPEN** since 2026-10-07 18:34 — `ROI_OPEN_ACCESS=1` is line 20 of the Pi's `.env`; 13 accounts in by 10-09 01:47 (`allowed_users` source `open`). Close it by removing the line and restarting; nobody already in is locked out |
| waiting for a restart | **the fortune teller's dispel and second card** (`7860aaa`, 2026-10-10): `FortuneStage`, `AddFortuneStage` (`users.fortune_stage`), two prices in `fortune.json` — content schema **v21**, so `content/data` and the binary ship TOGETHER — and 14 uk / 8 en strings; `records` → `2c754b9daf5c0d5a`. **And the recipe notebook** (`d77d600`, 2026-10-10): four new files (`RecipeNote`, `CreateRecipeNotes`, `RecipeNoteService`, `RecipeNoteDisplay`), the eight cards, the journal, 21 uk / 19 en strings. A migration and new strings, so a **restart**, not a `/reload`; the notebook left the digest unmoved. Everything before them, up to `de0e062`, is live |

### Where the last sessions stopped (2026-10-08 late → 10-10)

**10-10, later — the dispel and the second card built.** A players' proposal (pay ~30 to cancel a
card) and the owner's addition (a second card for 20), shaped in five quizzes: «🕯 Відчарувати»
for 30 on the FREE card's running duration effect, on the fortune screen only; ONE final «🔮 Друга
карта» for 20, only after a dispel; nothing after a one-shot or a card that ran out; the free
card's time never sooner. Rehearsed (81 checks twice, five mutants caught). Auto-memory
`project-fortune-dispel-and-second-card`; `.memory/sessions.md` → the 10-10 later entry.

**10-10 — the recipe notebook built.** On «Починаємо», the six entries the 10-09 samples had not
covered were shown on real numbers and approved. The enchant note was keyed by item + level
after the owner's answer: a warehouse trip re-creates the row. Everything was built on all eight
cards and the journal. A scratch-Postgres rehearsal met the migration the way the Pi will, alone
in a new batch, and passed 82 checks through the real services, twice. Two planted mutants were
caught. Auto-memory `project-recipe-notebook`; `.memory/sessions.md` → the 10-10 entry.

**10-09 evening — a doc pass, no game change.** The session preamble was measured against Claude
Code's own limits and trimmed against the records (auto-memory `feedback-docs-keep-the-rule`, its
fourth run): `MEMORY.md` stood at 98% of a hard 25,000-char cut, `CLAUDE.md` at 182% of its
40,000-char warning. The owner chose the index rewrite, the `CLAUDE.md` trim (every rule kept)
and this file cut to its live state; the fix of the stale records the audit found was offered and
NOT chosen, and path-scoped rule files were declined for now.

**10-08 late → 10-09 01:47.** Built, committed and deployed 2026-10-09 01:30: the starving
players' four (`36e33af`), the fortune teller once a game day (`248dc43`), and the named fight
line, the weapon's own icon and «рівень» (`33551dd`) — `.memory/sessions.md`. The recipe
notebook was designed and approved but NOT built («Зробимо це завтра»). Two working rules from
the owner: auto-memory `feedback-unanswered-means-nothing`, `feedback-fold-fixes-into-their-commit`.

### Next action

**0 — Ship the recipe notebook and the dispel, on the owner's word.** Both committed (`d77d600`
and `7860aaa`), not pushed. Push is the owner's. The deploy is the usual recipe below, and the
restart needs the owner's go: two migrations (`CreateRecipeNotes`, `AddFortuneStage`, each
rehearsed alone in a new batch), new strings and **content schema v21** — the Pi's pre-flight
digest must read `records 2c754b9daf5c0d5a`, content hash `f6a8a23e`. After it, the walk list's
top two blocks.

**1 — Answer the players.** Read the answer off the code and data, end with a ready Ukrainian
reply. Snapshot SQL and its reading traps: `.memory/live-ops.md`.

**2 — Watch the poll loop.** A new `[WATCHDOG]` line in `~/.pm2/logs/ROI-out.log` is a freeze the
limiter fix did not cover (`.memory/live-ops.md` → "Is the bot alive?").

**3 — The two chosen-but-unanswered forms** — eating straight from the warehouse (its layout) and a
hint under the estate-name prompt (its wording). Build either only on the owner's answer
(`TODO.md` → "Open, decided but not done", top block).

**4 — Read the `fight_log` rows** — 3,033 forest fights since the door opened (14 deaths, by 10-09
01:47): `SELECT nickname, character_class, player_level, estate_level, enemy_id, outcome, rounds,
max_blow, max_blow_source, special_atk_uses, stance_uses FROM fight_log ORDER BY created_at DESC`.
A one-tap kill of an on-level beast is what the technique rework was for; `estate_level` shows
whether players hold the estate back (T6 gains nothing per day).

**5 — Someone opens the screens.** `TODO.md` → "Walk list", the 10-09 blocks on top. No human has
seen the whole King's chain, and `/reload` has never run against a real database.

**6 — Older decisions waiting on the owner:** `TODO.md` → "Open, decided but not done". Not there
and still open: the t6–t9 weapon descriptions, written after the names were approved and never
approved on their own; the emblem candidates (`content/lore.md` §14, none chosen); and three
ideas raised but not yet asked — a «Відновити» service at the Master (reset the max for silver,
keep the enchant: a silver sink), the Master refusing to mend a piece worn to 1/1, and the passive
report naming its losses the way the death screen does.

**Deploying to the Pi:** `git push` is the owner's, never yours. On the Pi: `git pull --ff-only`, a
detached debug build, then the free pre-flight
`ROI_PROJECT_PATH=/home/rpi5/RestOfIryna ./.build/debug/RestOfIryna --content-digest`, which must
match the Mac BEFORE the restart is ordered — then **ASK before `pm2 restart ROI`**. A content or
schema change ships `content/data` and the binary TOGETHER (the handshake, **v21** in the tree and v20 on the Pi, refuses a
mismatch). After a migration, verify the TABLE, not the log line. Recipe and traps: auto-memory
`linux-build-gap`, `project-pi-deploy-swiftenv`, `reference-deploy-rehearsal`.

### The baseline and the simulator

**The current baseline — on the Pi since 2026-10-09 01:30 (`de0e062`, schema v20):** `records
4c0802f927fb8be4` · `tuning 4edf65507bbb5e48` · `spawns 0cf31905171d7944` · `quests
30de20902006e3b9` · `king e3a492be1b017e81`, content hash `47888401`. **This is the one place the
current baseline is kept**; the superseded ones are in `.memory/sessions.md` → "Digest baselines —
superseded".
**The tree's baseline, waiting for the restart (the dispel, schema v21):** `records
2c754b9daf5c0d5a`, content hash `f6a8a23e`, the other four halves as above. It becomes the current
one when the Pi runs it; the line above then moves to the superseded list.
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
swift test                                   # 401 tests, ~5s
```


## Rules

`CLAUDE.md` is the full set and is loaded every session. The three that cost the most when
forgotten: **never push** (user-side only), **never start / restart / stop the bot without
asking** (the Mac instance is the one exception — stop it, it 409s the Pi), and **ask before
committing**. Content edits must pass `roi-content validate --strict`; balance-table edits
must also re-run `roi-content simulate --strict`.
