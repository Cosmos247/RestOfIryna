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

### Where things stand right now (the Pi and git as read 2026-10-10 15:37)

| | |
|---|---|
| HEAD | **this hash fill** on top of **`021e9ac`** (a level-up keeps the armour's HP), **`7ee41c1`** (`1f4b442`'s hash fill), **`1f4b442`** (the zlatnyks: named, credited by hand, shown; the profile's silver declines), **`608f2c5`** (`04368cd`'s hash fill), **`04368cd`** (the sync pass, records only), **`743f042`** (`7995d2a`'s hash fill), **`7995d2a`** (the armour repair halved), **`248ce7e`** (`7860aaa`'s hash fill), **`7860aaa`** (the fortune teller's dispel and second card), **`0d556f5`** (`d77d600`'s hash fill), **`d77d600`** (the recipe notebook), **`2d8ab41`**, **`34872f6`** (the 10-09 doc pass), **`4459f79`** and **`de0e062`**. A commit cannot carry its own hash, so read HEAD off the machine; every hash and what it did is the **Commit index** at the top of `.memory/sessions.md` |
| pushed | `origin/main` is at **`de0e062`** (the owner pushed 2026-10-09). **Not pushed: `4459f79`, `34872f6`, `2d8ab41`, `d77d600`, `0d556f5`, `7860aaa`, `248ce7e`, `7995d2a`, `743f042`, `04368cd`, `608f2c5`, `1f4b442`, `7ee41c1`, `021e9ac` and this hash fill** — push is the owner's |
| running on the Pi | **`de0e062`**, online since **2026-10-09 01:30:47** — no restart since (read 10-10 15:37), still ONE `[WATCHDOG]` line in the log (10-08 11:47:53, before the limiter fix). Content schema **v20**, content hash **`47888401`**, `records 4c0802f927fb8be4`. The SDK's rate limiter is OFF, `PollWatchdog` runs, the Telegram client is HTTP/1.1. **Read it off the machine before acting on this line** (auto-memory `feedback-ask-the-machine-not-the-record`) |
| access | **The door is OPEN** since 2026-10-07 18:34 — `ROI_OPEN_ACCESS=1` in the Pi's `.env`. `allowed_users` at 10-10 15:37: open 13 · invite 6 · seed 4 · manual 1 (no new open-door account since 10-09 01:47); 4,772 forest fights since the door opened, 16 deaths. Close it by removing the line and restarting; nobody already in is locked out |
| waiting for a restart | **A level-up keeps the armour's HP** (`021e9ac`, 2026-10-11): `applyLevelDerivedStats` clamps to `effectiveMaxHp` — Swift only. **The zlatnyks and the profile's silver** (`1f4b442`, 2026-10-11): `AddZlatnyks` (two columns on `users`), `ZlatnykService`, the watchman's credit notice, the profile's «🟡 N златників» line, and `unit.silver` with the count instead of a fixed «срібників» — a migration and new strings, so the restart; the digest is unmoved. Crediting is a DBeaver edit, `.memory/live-ops.md` → "Crediting zlatnyks". **The armour repair halved** (`7995d2a`, 2026-10-10): `repairCostFraction` 0.5 → 0.25 in `master.json`, `records` → `c3720e93c10c13a8`, content hash `c9cf0506` — content only, but it rides the restart because the tree's content is schema v21. **The fortune teller's dispel and second card** (`7860aaa`, 2026-10-10): `FortuneStage`, `AddFortuneStage` (`users.fortune_stage`), two prices in `fortune.json` — content schema **v21**, so `content/data` and the binary ship TOGETHER — and 14 uk / 8 en strings (it moved `records` to `2c754b9daf5c0d5a`; the repair moved it on). **And the recipe notebook** (`d77d600`, 2026-10-10): four new files (`RecipeNote`, `CreateRecipeNotes`, `RecipeNoteService`, `RecipeNoteDisplay`), the eight cards, the journal, 21 uk / 19 en strings. A migration and new strings, so a **restart**, not a `/reload`; the notebook left the digest unmoved. Everything before them, up to `de0e062`, is live |

### Where the last sessions stopped (2026-10-08 late → 10-11)

**10-11, later — a level-up keeps the armour's HP; the Treasury designed.** A level-up clamped HP to
the base maximum and took the armour's share; fixed on its own. The Treasury's design is settled:
it sells only a class change, the weapon is reforged with its tier and wear kept, and there is no
limit but the price. Still open: the price, then the build. `.memory/sessions.md` → the 10-11 later
entry.

**10-10 late → 10-11 — the premium currency: named, credited by hand, shown.**
- The name: the owner asked for an authentic one and picked «златник» 🟡 (en *zlatnyk*). It is the
  silver coin's pair, and gold is what the lore already keeps for the Crown.
- The display: on a played sample of a real profile, the balance goes under silver, only while above
  0.
- The crediting: the owner credits by hand in DBeaver, so the balance is a `users` column outside the
  cached `User`, and the watchman announces each credit.
- Built and rehearsed (54 checks twice, two mutants caught). The sample also turned up the profile
  printing a fixed «срібників», fixed the same session.
- Auto-memory `project-premium-currency-zlatnyk`.

**10-10, the sync pass — records only.** Every record brought to the tree; what was only in the
chat is now kept: the dispel's three shapes and its Vigor arithmetic, and the repair measured on live
play with the shave's hidden price (`.memory/rebalance.md`, two new sections); the wear/repair SQL
and day four's observation (`.memory/live-ops.md`); the 10-10 open items and the declined options
(`TODO.md` → "Open, decided but not done", top block); a repair guard in `CLAUDE.md`.

**10-10, evening — the armour repair halved.** Players called the repair too expensive; the Pi's
`fight_log` showed newcomers wearing 60–460 points a day against ~100 job silver. The owner halved
the price (`repairCostFraction` 0.25), kept the max shave, did not restore the cut maxima and kept
the Master's screens as they are. Auto-memory `project-repair-cost-complaint`.

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

**0 — Ship the recipe notebook, the dispel, the halved repair, the zlatnyks and the level-up HP fix,
on the owner's word.** All four committed (`d77d600`, `7860aaa`, `7995d2a`, `1f4b442` and `021e9ac`), not pushed. Push is the owner's. The deploy is the usual recipe below, and the
restart needs the owner's go: three migrations (`CreateRecipeNotes`, `AddFortuneStage`, `AddZlatnyks` —
rehearsed together in one new batch over existing players on 10-11), new strings and **content schema v21** — the Pi's pre-flight
digest must read `records c3720e93c10c13a8`, content hash `c9cf0506`. After it, the walk list's
top three blocks.

**1 — Answer the players.** Read the answer off the code and data, end with a ready Ukrainian
reply. Snapshot SQL and its reading traps: `.memory/live-ops.md`.

**2 — Watch the poll loop.** Still one `[WATCHDOG]` line on 10-10 15:37 (10-08 11:47:53). A new one
in `~/.pm2/logs/ROI-out.log` is a freeze the limiter fix did not cover (`.memory/live-ops.md` → "Is
the bot alive?").

**3 — The two chosen-but-unanswered forms** — eating straight from the warehouse (its layout) and a
hint under the estate-name prompt (its wording). Build either only on the owner's answer
(`TODO.md` → "Open, decided but not done", top block).

**4 — Read the rest of the `fight_log`.** Read on 10-10 for the repair (`.memory/live-ops.md` → "Day
four"): newcomers' busiest days ran 105–350 fights against the model's ≈25 a day, and 26% of wins end
untouched. Still unread: `estate_level` (do players hold the estate back? T6 gains nothing per day)
and how many wins are one tap — what the technique rework was for.

**5 — Someone opens the screens.** `TODO.md` → "Walk list": the three 10-10 blocks once they are
live, the 10-09 ones now. No human has
seen the whole King's chain, and `/reload` has never run against a real database.

**6 — Older decisions waiting on the owner:** `TODO.md` → "Open, decided but not done". Not there
and still open: the t6–t9 weapon descriptions, written after the names were approved and never
approved on their own; the emblem candidates (`content/lore.md` §14, none chosen); and three
ideas raised but not yet asked — a «Відновити» service at the Master (reset the max for silver,
keep the enchant: a silver sink), the Master refusing to mend a piece worn to 1/1, and the passive
report naming its losses the way the death screen does. And the 10-10 block of `TODO.md` → "Open,
decided but not done": repairing at the estate for hides, and a stale fortune button that deletes
the photo when tapped off the capital.

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
**The tree's baseline, waiting for the restart (the dispel and the repair halved, schema v21):** `records
c3720e93c10c13a8`, content hash `c9cf0506`, the other four halves as above. It becomes the current
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
