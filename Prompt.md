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

### Where things stand right now (the Pi and git as read 2026-11-01 11:16)

| | |
|---|---|
| HEAD | **this commit** (`f62175e`'s hash fill), unpushed. Under it, unpushed: **`f62175e`** (the plot's «📌 У нотатник» and «ємність»), **`17e1e73`** (`29f38c5`'s hash fill), **`29f38c5`** (the hazel every estate starts with — schema v30 and the `PlantHazel` migration), **`ff6433e`** (`266d28e`'s hash fill and the 17:21 deploy record) and **`266d28e`** (the bag's item card, all three steps — kept off the Pi by the owner's choice). Under them everything is pushed: `origin/main` = the Pi = **`b04bef3`** (`96973ba`'s hash fill; `96973ba` Велесова ніч's prizes at the palace). A commit cannot carry its own hash, so read HEAD off the machine; every hash and what it did is the **Commit index** at the top of `.memory/sessions.md` |
| pushed | `origin/main` is at **`b04bef3`** (the owner pushed 2026-11-01 ~17:18, `! git push origin b04bef3:main`, after the session's permissions refused mine), the commit the Pi runs. Push is the owner's |
| running on the Pi | **`b04bef3`**, online since **2026-11-01 17:21:25** (pm2 restarts 12; the binary built on the Pi 17:20:42). Content schema **v29**, content hash **`1ac5a7bc`** — the digest matched the Mac in every line before the restart; `AddEventBloodRewardedAt` verified on the table (16 flasks, all `rewarded_at` NULL, 15 with blood). The finale and the King's summons go out at 18:00. 11 × 403 per mass notice (players who blocked the bot), no 409 / 429 / 502; still ONE `[WATCHDOG]` line (10-08 11:47:53). The SDK's rate limiter is OFF, `PollWatchdog` runs. The untracked `core` (a 09-25 dump) and `pgweb/` in the Pi's checkout are old and known. **Read it off the machine before acting on this line** (auto-memory `feedback-ask-the-machine-not-the-record`) |
| access | **The door is OPEN** since 2026-10-07 18:34 — `ROI_OPEN_ACCESS=1` in the Pi's `.env`. `allowed_users` at 10-11 02:57: open 14 · invite 6 · seed 4 · manual 1 (one new open-door account since 10-09 01:47); 15,605 forest fights in `fight_log` since the door opened (read 10-22: 72% at km 1–10). Close it by removing the line and restarting; nobody already in is locked out |
| waiting for a restart | **The plot's «📌 У нотатник» and «ємність» (`f62175e`)** — Swift + uk/en, no migration, the digest unchanged; the same restart as the hazel. **The hazel every estate starts with (`29f38c5`, `spec-progression.md` §8)** — Swift + content **schema v30** + uk/en + the **`PlantHazel` migration, which REWRITES ROWS** (every plot moves down a slot, a ripe hazel goes into slot 1 of every registered estate). Content and binary ship TOGETHER; the tree's digest is `records 4f4dcf860af8605f`, content `95421568`, COMBINED `d0b897ae80619502` (only `records` and the hash moved). Read the plot counts off the Pi BEFORE the restart and the table AFTER it (`TODO.md` → its walk block); a rollback past it is unsafe. **The bag's item card (`266d28e`)** — Swift + locales, no migration, the digest unchanged; a push, a Pi build and `pm2 restart ROI`. **The next big deploy also removes the 🩸 blood board's tab** (the owner, 2026-11-01; `TODO.md` → Open, the 11-01 evening block — not built yet). Its warehouse swap (`WarehouseService.wear`) has NOT run on a real database: check it on the test bot first (`TODO.md` → its walk block) |

### Where the last sessions stopped (2026-10-24 → 11-01)

**11-01, late night — the plot's «📌 У нотатник» (`f62175e`, NOT deployed).** The owner asked for the build card to pin its
materials; the note is the plot type + how many of it the estate will hold, read like a recipe, done when that type
is built (the owner's picks); the card's three buttons each on a row (the owner's layout); «єм» → «ємність»,
"cap" → "capacity". `.memory/sessions.md` → the entry.

**11-01, night — the hazel every estate starts with (`29f38c5`, NOT deployed).** The owner's idea: a plot that opens with
the estate, never chosen, in slot 1, hazel bushes yielding forest nuts — to help the first explorations and to show the
plot loop from day one. Shown as a played sample and three questions; the owner took every recommended option (slot 1 with
the rest shifting, 1 nut an hour holding 5, ripe at once + a line in the welcome), approved the spec («так», §8) and it was
built the same night. `simulate --strict`: 15 warnings (was 18 — `pace.levels_without_an_estate` gone), the pace to L40
136–151 days (was 151–167). `.memory/sessions.md` → the entry.

**10-31, after the deploy — the records synced, the digest names `artFrom` (`006ad51`).** The owner's long-form
audit: every doc and both memory banks brought to "live since 02:01"; stale lines fixed (README's art window, the
holiday spec's «before Sat 08:30», `status.md`'s test count and the v25 clause, a 09-19 walk block still «NOT LIVE»);
`CLAUDE.md`'s holiday rule gained the `artFrom` window and «copy read across a window names days»; `INDEX.md` gained
`spec-bestiary.md` §14; the FAQ gained the repair's fixed ÷ 50 and a plot's build order. **Found:** the holiday's
`artFrom` moved only the content hash — the digest's `records` now names it (mutation-checked: 13:00 moves
`records`), so the tree's digest reads differently from the Pi's until the next deploy (the table above).

**10-31 02:01 — the deploy.** On the owner's word («Запушив, задеплой на Пай і перезапусти бота»): a pull to `20f5681`
(22 commits), a 145 s debug build, the digest on the Pi matched the Mac in every line (v29, `231acc72`, COMBINED
`ea15c16c660f81f2`), `pm2 restart ROI` at 02:01:39 with nobody on the road, in a fight or in a walk but two stale rows
(KQ since 10-17, xeuzo's unclaimed run since 10-12); the three migrations verified on the tables; online and polling
at 02:04. `.memory/sessions.md` → the deploy entry.

**10-31, past midnight — the holiday's last polish, the autumn road, the coop (`2db2435` · `97a2be9` · `9701f27` ·
`084f23b` · `2c2d895`, live since 02:01).** Five changes on the owner's word, each its own commit: Saturday's noon line
no longer claims the fortune teller deals no cards (she does, and a card ready at noon comes in the same message);
the capital wears the holiday from 12:00 — pictures, the palace's empty throne, the square's welcome — with only the
09:00 decree before it (`events.json` → `artFrom`); the scribe's «третю ніч» became days of the week; the road card is
an autumn forest «поки осінь» (the summer one at `2ed296e`); «Курник закладений». Also in that session, in the chat
and not in a file: the testers' list of every undeployed change (the owner publishes it) and the whole event written
out twice (the second time with the fortune teller's and the innkeeper's screens); the pumpkin's receipt, the repair's
÷ 50, the plot build card and the build order answered from the code (FAQ rows). `.memory/sessions.md` → the entry.

**10-30, night — stronger beasts: №5–14 a level up (`ff3e64e`, live since 10-31 02:01).** Step 2 of the Defend work,
measured on 10-27 and parked, finished before the holiday's restart. Re-read off the Pi (the week to 10-30 22:54:
3,972 fights, 81.5% with №1–4) and replayed with the fresh kits: A +18% HP a fight, B +21%, C +34%, the shift at 5%
+23%. The level shift also moves a holiday's manor (its creatures start seven levels below the player); a re-level
never reaches it. The owner: A, the shift kept at 6%. The documented re-solve (§10.8, the 10-02 wardrobe) proved weak
and lumpy a level up, so the owner picked the lines as measured — each keeps its share of the contract. XP, bands,
№1–4 and the manor unchanged. The audit found the 90-minute 🏕 run turns at km 15 and so meets the moose, and a model
of that run that kills L1–5 players in 40–60% of runs already today — unverified, in Open. `spec-bestiary.md` §14,
`.memory/rebalance.md` → "Stronger beasts — step 2".

**10-27 → 10-30 — Велесова ніч, designed, built and reworked (`3e11ef6`, live since 10-31 02:01).** The owner's idea:
the King falls ill, strange decrees, the cure is a creature's blood from a place left only by dying, blood kept
outside the bag, the most blood wins. Decrees Sat 31.10 09:00 / 14:00 / 16:00, themed noon notices, at 18:00 a summons
to the palace where the scribe tells the story and hands over the flask («🩸 Взяти флягу»), Veles's abandoned manor at
km 5 from Sat 18:00 to Sun 18:00 (bats and rats by the player's level, blood into the flask, «Велесовий гарбуз» one
step in ten), the «🩸 Кров для Короля» board and the per-reader finale; the owner's three pictures. Rehearsed on a
scratch Postgres before the deploy. Everything: `content/spec/event-veles-night.md`.

**10-26/27 — the forest's Defend set by numbers (`83002a6`, live since 10-31 02:01).** On the owner's numbers, made
equal by value per tap: the parry 40% + DEF ×2, the dodge ×2 + a 45% knife, the barrier 30% off + a 30% spark; Shadow
Veil held at 15% by its own key. The telegraph («звір готує удар») was declined: «Давай не придумувати нового, а просто
змінювати показники». `.memory/rebalance.md` → "The forest's Defend, set by numbers".

**10-24 — a plot costs materials, a fight wears less, the gear sheet says so, the repair back at ×0.5 (`bac1a70`,
`6620d39`, `cf6e3ea`, `a0386b1`, live since 10-31 02:01).** Each plot type its own four-material recipe, the Nth plot
×N, the first without clay and iron (`spec-progression.md` §7); a win wears ½ (a point in half the fights), a flee 1, a
death 2; «🔧 Як зношується» under the profile's «🛡 Спорядження»; the repair priced at ×0.5 again once a fight wore half
as much. `.memory/sessions.md` → the 10-24 entries, `.memory/rebalance.md`.

**Live since the 10-23 22:46 restart (`7ac11f0`):** the forest past km 49 (`1b99a3f`), the hub's «👇 Оберіть, куди
далі» (`266ad57`), the reply keyboard kept (`6ac0351`), the warehouse's ℹ️ on a weapon (`40b52df`), a find that half
fits, the road's hint and «Руки майстра» (`c011f9f`), the forest edge's armour warning (`4ebc80b`), every material at
every km (`8308be6`), the door's «Принесено» (`ea52cf6`), the archer's «💨 Ухилитися» (`e9bdb78`), clay at 24 / 12 with
«Мʼясо в глині» re-cut (`34fe88c`). Each has its session entry and auto-memory; their side findings are in Open.

**Live since the 10-17 17:40 restart:** the leaderboard pages and the «🪙 Багатство» board, the registration welcome
escaping a Telegram name (`TelegramHTML`), and the mage's barrier spark (10-13, `defend.mageChipMultiplier`).

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

**Dead-looking code kept on purpose** (the 10-12 sync pass, `beed258`): the passive report's
unread `stepsTaken` (the Pi's binary decodes it as required, so a rollback would strand a report) and
the dead `walkRoomDoubleSpeed` knob (deleting it moves the digest a restart is checked against).

### Next action

**0 — The hazel every estate starts with is BUILT, NOT deployed** (`spec-progression.md` §8; schema v30 and `PlantHazel`, which rewrites rows: the Pi's plot counts BEFORE the restart, the table AFTER — `TODO.md` → its walk block; rehearsed on a scratch Postgres, `.memory/sessions.md` → the 11-01 night entry). **0 — The prize announcement is LIVE** (sent 10:00:36, 44 players); **the prizes at the palace are BUILT** and must be live before 18:00 (the row above; spec §4.8, `TODO.md` → the walk block). **The bag's item card: all three steps (the bag, the trail bag, the warehouse) BUILT, NOT deployed** (`TODO.md` → Open and the walk block; every decision in `.memory/sessions.md` → the 11-01 midday entry). **0 — Велесова ніч runs today and once (Sat 31.10 09:00 → Sun 01.11 18:00) — watch it as it happens.** The 09:00 /
14:00 / 16:00 decrees (each once: count `event_notices`), the capital wearing the holiday from 12:00, at 18:00 the
summons, the manor at km 5, the scribe's story and the flasks; the board, the flasks and who is inside are read with the
SQL in `.memory/live-ops.md` → "Велесова ніч" (and "what shows when"). Walk list: `TODO.md` → "Added 2026-10-29".
**After the finale (Sun 18:00) the prizes are paid at the palace** (spec §4.8 — not by hand any more, 2026-11-01). Then the two after-holiday questions in Open: the «Принесено» undercount and the 90-minute
🏕 run for L1–5.

**1 — Walk the blocks live since 10-31 02:01** — `TODO.md` → "Walk list", the top blocks: a first plot on a fresh
account (no 🧱 / 🔩 asked) and a second with one material short (the modal, the card redrawn), a coop's banner
«закладений»; a few fights — the kit loses a point in about half the wins, a flee one, a death two; «🔧 Як зношується»
on «🛡 Спорядження»; at the Master a hood missing 10 points costs 10 🪙; in a forest fight «🛡 Парирувати» strikes ~40%
of a clean hit, «💨 Ухилитися» ~45%, «🌀 Магічний бар'єр» lets 70% of a blow through and sparks ~30%; the moose on a T1
estate shows ❤️ 102; the road card is the autumn forest; `/content` reads schema v29 and hash `1ac5a7bc` (since the 2026-11-01 17:21 restart; v30 and `95421568` once the hazel deploys). Under them the
twelve blocks live since 10-23 22:46, the four since 10-17 17:40, the five since 10-13 18:54, the six since 10-11 13:21
and the 10-09 ones. For the Chancellery, credit a test account in DBeaver first (`.memory/live-ops.md` → "Crediting
zlatnyks"). No human has seen the whole King's chain, and `/reload` has never run against a real database. The
testers' list for the 10-31 deploy was written in that session's chat; the owner publishes it.

**2 — Answer the players.** Read the answer off the code and data, end with a ready Ukrainian
reply. Snapshot SQL and its reading traps: `.memory/live-ops.md`. Lost buttons: its FAQ row (ask
whether the ⊞ icon is in the input field; `/menu` re-sends them).

**3 — Watch the poll loop.** Still one `[WATCHDOG]` line at 10-31 02:04 (10-08 11:47:53); `Code: 400` still 922, no 429/502
since the 10-26 03:10 burst. A new one in `~/.pm2/logs/ROI-out.log` is a freeze the limiter fix did not cover
(`.memory/live-ops.md` → "Is the bot alive?").

**4 — No bug queued.** What is left in "Open" are questions for the owner (5). **After the autumn**, put the green
summer road back or the owner's winter one (`TODO.md` → "Added 2026-10-31 — the autumn road"), then restart.

**5 — Questions waiting on the owner** — `TODO.md` → "Open, decided but not done":
- **the 10-30 night block:** is the 90-minute 🏕 run a trap for L1–5 (a model says 40–60% deaths a run today; read
  real reports first) — raised in the stronger-beasts audit, not asked;
- **the 10-30 block, AFTER THE HOLIDAY:** «Принесено:» undercounted Ліліт's walk (🌰 × 1 for 🫐 ×1 + 🌰 ×2), cause NOT
  found, every fact recorded; count from the bag + a log line, or a log line only — offered, not picked;
- **the 10-27 block:** step 2 of the Defend work, stronger beasts — DECIDED and built 10-30 (A, the shift kept at
  6%; `spec-bestiary.md` §14). The shift (5 / 4%) is the one knob that reaches the 81.5% of fights with №1–4, and it
  also moves a holiday's manor, so any change waits until no manor is open. Shadow Veil's knife (held at 15%) comes
  back with the techniques' rework; the three Defend lines' copy left as it was («черкаєте ножем» for a 45% knife);
- **the 10-23 night block:** the staff's t3 keeps 3 🧱 — at 24 it costs 102 🪙 against the sword's 50 and the
  bow's 38 («1 🧱 instead of 3» offered, not answered); the archer's special defence named twice («🌑 Тінь
  лісу» on the button, «Серпанок тіні» on the fight card); five uk lines with an undeclined plural
  («раунд(ів)», «удар(ів)», «крок(ів)»);
- **the 10-23 archer block:** the forest pie at 12 HP (the pie alone, or every taught dish at ⅜ of its price —
  `TODO.md` → Open; the owner asked to clarify, nothing built);
- **the 10-21 block:** `is_persistent` on the keyboards; `/menu` as a global command (with the guild
  «/menu» hole and the training fight's flee key); a character rule for guild names;
- **the 10-20, later block:** the capital square re-sending itself; `/help`'s template copy;
- **the 10-20 block:** the dead `explore:passive:close` handler (pre-April chats only);
- **the 10-13 Defend block:** Defend's lines that say nothing (the archer's done 10-23); a validator ceiling for
  the barrier's spark (its line moves with the cut, so it would read both halves). «Звір замахується» is CLOSED —
  declined again on 10-27, never re-raise it;
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

**6 — Read the rest of the `fight_log`.** Read on 10-10 for the repair (`.memory/live-ops.md` → "Day
four"): newcomers' busiest days ran 105–350 fights against the model's ≈25 a day, and 26% of wins end
untouched. Still unread: `estate_level` (do players hold the estate back? T6 gains nothing per day)
and how many wins are one tap — what the technique rework was for.

**7 — Older decisions waiting on the owner:** `TODO.md` → "Open, decided but not done". Not there
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
schema change ships `content/data` and the binary TOGETHER (the handshake — **v29** on the Pi and in the tree since
10-31 02:01 — refuses a mismatch, a `/reload` included). After a migration, verify the TABLE, not the log line. Recipe and
traps: auto-memory `linux-build-gap`, `project-pi-deploy-swiftenv`, `reference-deploy-rehearsal`. The Pi's
binary is `c77a25b`'s (built 2026-10-31 17:56:23), so a change with no Swift needs no build there — the 11-01 09:56 deploy
was a pull and a restart. Restart with plain `pm2 restart ROI` (no `--update-env`).

### The baseline and the simulator

**The current baseline — on the Pi since 2026-11-01 17:21 (`b04bef3`, schema v29):** `records 207c959cf4807072` ·
`tuning c0380e692986ba04` · `spawns 004c138c83fa9d1a` · `quests 30de20902006e3b9` · `king e3a492be1b017e81`, content
hash `1ac5a7bc` (COMBINED `0f31c3b586671117`). **This is the one place the current baseline is kept**; the superseded
ones are in `.memory/sessions.md` → "Digest baselines — superseded", and the tree's steps in the Commit index.
A knob is invisible to the digest until it is hashed (auto-memory `feedback-digest-names-constants`).

`simulate --strict` on the Pi's content: 18 of 18 invariance rows, 0 broken bands, 18 warnings, all deliberate
(`TODO.md` → the standing deferrals). Pace to L40: 151–167 days (warrior 167.0 / archer 159.6 /
mage 150.9; band 72–200; taps/day ~711). **The tree since the hazel (11-01 night, not deployed): 15 warnings** —
`pace.levels_without_an_estate` gone — and **136–151 days** (151.1 / 144.3 / 136.4; taps/day ~801). The pace cannot see depth: the expedition model puts real
play at ~600–640 days (auto-memory `project-expedition-model`, `.memory/rebalance.md`).

### Commands

```
/content   /reload                           # dev-only, in Telegram: inspect and hot-swap
swift run roi-content validate --strict      # content integrity; exit 1 on any error
swift run -c release roi-content simulate    # balance sweep; --runs/--seed/--levels, --strict gates
swift run roi-content spec <table>           # progression · gates · bestiary · items · sets · economy · opening · king
swift run RestOfIryna --content-digest       # confirm ONLY the intended change moved
swift test                                   # 526 tests, ~5s
```


## Rules

`CLAUDE.md` is the full set and is loaded every session. The three that cost the most when
forgotten: **never push** (user-side only), **never start / restart / stop the bot without
asking** (the Mac's test bot `@artania_gamebot` included — its own token and `roi_test`), and **ask before
committing**. Content edits must pass `roi-content validate --strict`; balance-table edits
must also re-run `roi-content simulate --strict`.
