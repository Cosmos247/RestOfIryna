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

### Where things stand right now (the Pi and git as read 2026-10-26 23:15)

| | |
|---|---|
| HEAD | **this commit** (Велесова ніч — content + Swift + art, schema v29, three migrations). Under it, unpushed: **`4c0ef48`** (`5cbfe36`'s hash fill), **`5cbfe36`** (the 10-27 night records: stronger beasts, measured and parked — records only), **`bde0acc`** (`83002a6`'s hash fill), **`83002a6`** (the forest's Defend set by the owner's numbers — content + Swift, schema v28), **`3ddb71e`** (`a0386b1`'s hash fill), **`a0386b1`** (the repair back at ×0.5 — content), **`001212a`** (`cf6e3ea`'s hash fill, and the rewritten history), **`cf6e3ea`** (the gear sheet explains the wear — Swift + locales), **`1c9fce8`** (`6620d39`'s hash fill), **`6620d39`** (a fight wears less — Swift + content, schema v27), **`c2007f8`** (`bac1a70`'s hash fill), **`bac1a70`** (a plot costs materials — Swift + content, schema v26 — carrying the 10-23 22:46 deploy record too, which was written that night and never committed on its own). Under them everything is pushed: `origin/main` = the Pi = **`7ac11f0`** (`34fe88c`'s hash fill). A commit cannot carry its own hash, so read HEAD off the machine; every hash and what it did is the **Commit index** at the top of `.memory/sessions.md` |
| pushed | `origin/main` is at **`7ac11f0`** (the owner pushed 2026-10-23, just before the 22:46 deploy), the commit the Pi runs. Push is the owner's |
| running on the Pi | **`7ac11f0`**, online since **2026-10-24 05:39** (pm2 restarts 8: the host rebooted at 05:17, DNS was not up, and the boot failed seven times — `Failed to start application`, name resolution then connect timeout — before polling at 05:39; the 22:46 deploy itself is unchanged). Still ONE `[WATCHDOG]` line in the log (10-08 11:47:53, before the limiter fix); `Code: 400` still at 922. The log's 429/502 bursts all fall in the same night hour, ~01:00–01:10 UTC (04:00 Kyiv in summer time: 09-16, 09-27, 10-09, 10-18 — 194 × 502 and 38 × 429 that night; and **10-26 03:10–03:11 Kyiv, 207 × 502**, the first night after the clocks went back on 10-25 — read 2026-10-28 19:28), none during play; no freeze, the watchdog did not fire. Content schema **v25**, content hash **`30b0d499`**; the SDK's rate limiter is OFF, `PollWatchdog` runs, the Telegram client is HTTP/1.1. The untracked `core` (a 09-25 dump) and `pgweb/` in the Pi's checkout are old and known. **Read it off the machine before acting on this line** (auto-memory `feedback-ask-the-machine-not-the-record`) |
| access | **The door is OPEN** since 2026-10-07 18:34 — `ROI_OPEN_ACCESS=1` in the Pi's `.env`. `allowed_users` at 10-11 02:57: open 14 · invite 6 · seed 4 · manual 1 (one new open-door account since 10-09 01:47); 15,605 forest fights in `fight_log` since the door opened (read 10-22: 72% at km 1–10). Close it by removing the line and restarting; nobody already in is locked out |
| waiting for a restart | **Five changes, one restart** (schema v28 — a restart, not a `/reload`): **the forest's Defend set by the owner's numbers** (2026-10-27, `83002a6`): «🛡 Парирувати» 40% + DEF ×2, «💨 Ухилитися» dodge ×2 + a 45% knife, «🌀 Магічний бар'єр» 30% off + a 30% spark, «🌑 Тінь лісу»'s knife held at 15% by its own number (`.memory/rebalance.md` → "The forest's Defend, set by numbers"); **a plot costs materials** (2026-10-24, `bac1a70`): each type its own four-material recipe, the player's Nth plot ×N, the first without 🧱 and 🔩 (`spec-progression.md` §7); **a fight wears less** (2026-10-24, `6620d39`): a win ½ (one point in half the fights), a flee 1, a death 2, where it was 1 / 2 / 3 (`.memory/rebalance.md` → "A fight wears less"); **the gear sheet explains the wear** (2026-10-24, `cf6e3ea`): «🔧 Як зношується» under the profile's «🛡 Спорядження», its numbers read from the data; **the armour repair back at ×0.5** (2026-10-24, `a0386b1`): a point 1 / 1.6 / 2.5 / 3 again, the set from zero 405, the weapon 1 (`.memory/rebalance.md` → "The repair back at ×0.5"). Before them, the twelve 2026-10-20/23 changes went live at the 2026-10-23 22:46 restart — the forest past km 49 (`1b99a3f`), the hub's line (`266ad57`), the keyboard fix (`6ac0351`), the warehouse's ℹ️ (`40b52df`), a find that half fits, the road's hint and «Руки майстра» (`c011f9f`), the forest edge's armour warning (`4ebc80b`), the forage without zones (`8308be6`), the manor door's «Принесено» (`ea52cf6`, with `AddExplorationHaul`, verified on the table), the archer's «💨 Ухилитися» (`e9bdb78`) and clay at 24 / 12 (`34fe88c`); `.memory/sessions.md` → "Deploy — 2026-10-23 22:46" |

### Where the last sessions stopped (2026-10-13 → 10-30)

**10-30 — Велесова ніч reworked: the reveal is the palace's, the flask is collected there (this commit, NOT LIVE).**
The owner: the reveal should come when the player walks into the palace, and a flask must be collected to explain
itself — but the player has to be told. Now 18:00 sends ONE message (the scribe summons every governor to the
palace; the flask is not named — struck by the owner); the palace, while the manor is open and the flask not taken, tells the story and
the scribe offers «🩸 Взяти флягу» (`CapitalController+Flask`, the empty `event_blood` row IS the flask); a walk
without it sees the manor at km 5 with the way to the palace instead of the button; Sunday's noon line tells a
player without a flask to fetch it. Then «Велесовий гарбуз»: one manor step in ten finds it instead of a creature
(at that depth), +25% of max HP and Vigor at once, text «Дати гарбуза» (the owner's pick). Last, the owner's three
pictures, only while the holiday runs: the capital map (square and streets), the empty palace, the manor's first
screen (`Assets/events/veles_night_2026/`, `EventArt`) — the three JPGs must be in the commit. Quiz: the km-5 hint and the Sunday line picked; the button and the 18:00 text
left unanswered, then built from the sample on «Давай зробимо це». 501 tests, `validate --strict` 0/0, every line
through the real Lingo in both locales; `records` and the content hash moved. Spec §4.3; `.memory/sessions.md`.

**10-27 night → 10-29 — Велесова ніч, designed and built (this commit, NOT LIVE).** The owner asked for a small
Halloween event for the testers, then gave its idea: the King falls ill, strange decrees, the cure is a creature's
blood from a place left only by dying, blood kept outside the bag, the most blood wins. Over many rounds it became
Велесова ніч: decrees Sat 31.10 09:00 / 14:00 / 16:00, themed 12:00 notices, the reveal at 18:00, Veles's
abandoned manor at km 5 from Sat 18:00 to Sun 18:00 (bats and rats 50/50, their level following the player's,
blood into a flask, 38 / 57 XP), the «🩸 Кров для Короля» board, the per-reader finale. Built and verified the
same night (498 tests, `validate --strict` 0/0, every line through the real Lingo; reworked 10-30, above) and rehearsed on a scratch
Postgres 15.8 (the three migrations on a Pi-shaped database, 21 checks, a mutant caught) — `.memory/sessions.md`. **It needs the owner's commit, push and a restart
before Sat 08:30.** Everything: `content/spec/event-veles-night.md`.

**10-27, night — stronger beasts, measured and parked.** The owner asked to raise the beasts' levels, keeping the
first ones. The step was measured on the week's live fights; 82% of them are with the first four beasts, which no
re-level from the moose touches. Shown: three re-levels from the moose and the level shift, recommended +1 from the
moose with the shift kept at 6%. The owner parked it: «Всі ці розрахунки і відповіді запам'ятай, ми повернемось до
них пізніше». Nothing is picked (`.memory/rebalance.md` → "Stronger beasts — step 2").

**10-26/27 — the forest's Defend set by numbers.** The owner asked to strengthen every class's Defend, and then the
beasts a little. Read off the Pi: Defend is 1.3 / 1.9 / 5.2% of taps, and the median fight is 9 levels below the
player (85% at 5+). The telegraph («звір готує удар», 10-13) went first, with numbers on the week's fights and a
played sample; the owner: «Давай не придумувати нового, а просто змінювати показники». On the owner's numbers and
picks, made equal by value per tap (Defend's damage share + the blow it stops; 59 / 56 / 60% on-level): the parry
40% + DEF ×2, the dodge ×2 + a 45% knife, the barrier 30% off + a 30% spark (asked for «менший відсоток захисту,
але вищий відсоток удару»); Shadow Veil held at 15% by its own key (schema v28) until the techniques are reworked.
No class's "Defend every round" beats attacking. Told before the build: a Defend tap still loses to an Attack tap,
so the game will not get noticeably easier and step 2 lands on everyone. 478 tests; `tuning` and the content hash
moved. `.memory/sessions.md` → the entry.


**10-24, night — the audit, «одягненої», the repair back at ×0.5.** The gear sheet's wear block, left uncommitted by
the session before, was audited clean and committed (`cf6e3ea`, its fill `001212a`); of two notes on the approved copy
the owner took «вдягненої» → «одягненої», folded into the commit itself (`278ba7e` → `cf6e3ea`). Then the repair:
priced on each player's own kit off the Pi (the week to 23:20: 7,663 🪙 live · 3,848 at the new wear · 6,854 at the
new wear and the old price), the owner put the price back — `repairCostFraction` 0.5, content only; `records` and the
content hash moved (`f1501e3c1c9dc759`, `c8d337fe`); 476 tests. `.memory/sessions.md` → the entry.

**10-24, evening — the gear sheet explains the wear.** The owner asked for a short player-facing description of
durability loss on the profile's «🛡 Спорядження». Mocked on Лайкмен's real kit; the owner picked the block always
under the list (over a «❓ Як зношується» button), no repair tip, and — after asking for other phrasings — «перемога —
1 очко з шансом 50%». Built: «🔧 Як зношується» in place of `gear.hint`, every number read from the data
(`WearMath.shape`, `repairMaxShave`); rendered through the real Lingo in uk and en; 476 tests; digest unmoved.

**10-24, later — a fight wears less.** The owner asked to soften the durability each fight outcome takes. Read off
the Pi (7 days): 6,489 wins, 592 flees, 32 deaths — 84% of the wear was wins; Лайкмен (L12) wore 390 points a day
with 662 🪙. Of four variants shown on that week's fights the owner took the recommended **½ / 1 / 2** (Лайкмен
390 → ≈196, Нястюшка 83 → ≈42). Built: `wearBudget` as fractions (schema v27), `WearMath` rolls a fraction per
fight for the forest and the passive run, the digest replays it seeded; 475 tests; `tuning` and the content hash
moved (`17654923` → `90abd2c4`). Also the audit of the plot cost before it (`bac1a70`): the 10-23 deploy record
had never been committed and rode in with it. `.memory/sessions.md` → the entry.

**10-24 — a plot costs materials.** Players asked for a plot to cost resources; it was free. The first proposal
(one frame of 10 🪵 + 10 🪨 for every type plus an item of its own) went back as too uniform — «урізноманітни…
глини та заліза». The owner then picked «кожна своя, повніше»: farm 10🪵 2🟫 1🔩 3🥔 · sawmill 8🪵 10🪨 2🔩 1🧱 ·
mine 12🪵 3🟫 2🔩 1🧱 · coop 8🪵 5🪨 1🧱 3🥚, and the Nth plot at ×N with the first plot leaving out clay and iron
(52–70 🪙 at buy prices against the T2 step's 118; the sixth 504–780). Built: `PlotBuildCost`, the build card's
«📜 Матеріали», the claim paying bag-first in one transaction, eleven validator rules, `spec gates` / `spec economy`,
schema v26; `records` and the content hash moved (`30b0d499` → `17654923`). Rehearsed on a scratch Postgres (31 checks on two clean runs; a claim without the transaction and a
warehouse-first drain each caught). The 57
plots already built stay free. `.memory/sessions.md` → the entry.

**10-23, night — the 22:46 deploy.** On the owner's word, after the push: a pull to `7ac11f0` on the Pi, a
133.6 s debug build, the digest matched the Mac byte for byte (v25, `30b0d499`, COMBINED `c1d4f62d7aed7d8b`),
`pm2 restart ROI` at 22:46:07 with one active walk and one 🏕 run in flight; `AddExplorationHaul` verified on
the table; eight 403s from the restart notice; at 22:48:45 still one `[WATCHDOG]`, 922 `Code: 400`. Before
it the same night: a testers' note for the twelve changes (in the session, ready to publish), the
techniques listed for the owner, and two notes in `TODO.md` → Open («Серпанок тіні», five undeclined
plurals). `.memory/sessions.md` → the deploy entry.

**10-23, night — clay costs 24 / 12; «Мʼясо в глині» re-cut.** The owner asked to recompute the clay price
postponed the night before, now that clay is the rarest find. Recomputed off the data and the Pi (21:45: 548
clay in 17 players, 308 of it beyond what they still need for the estate): T4–T7's 70 clay 280 → 1,680 🪙
(+10% on those steps), the staff's t3 42 → 102, and «Мʼясо в глині» — its Vigor is its ingredients' price —
70 at the old recipe, two short of the Feast. The owner took 24 / 12 and the recipe 2 🥩 + 1 🥔 + 🧱 + 🪵 =
54 Vigor, 14 HP, 135 at the tavern (60 was recommended). Last night's 58, a recipe without potato, was
withdrawn: the dish's description and the innkeeper's lesson tell of meat with potatoes. Content only;
`records` and the content hash moved, no band. `spec-bestiary.md` §13.5; `.memory/sessions.md` → the entry.

**10-23, evening — the archer's Defend is «💨 Ухилитися».** The owner asked for every attack and defence
button and what it does (the answer is the session entry's table), then renamed «💨 Швидкий маневр»: of
four names «💨 Ухилитися» (en «Dodge»), and its own line «💨 Ви пірнаєте вбік і черкаєте ножем — …» where it
borrowed the warrior's «Ви тримаєте удар…». More renames may follow. `.memory/sessions.md` → the entry.

**10-23, later — the manor door names what an active walk brought.** Asked when a player gets the report
of what was brought and lost: the passive report has both, the active walk only its death screen's loss.
From a played sample the owner picked «Принесено:» under «🏰 Ви повертаєтеся додому…» — finds less what was
eaten, then «🪙 Знайдено N срібників», what the bag refused not listed; the passive report unchanged (asked
twice). `ExpeditionHaul` on `exploration_state.haul` (`AddExplorationHaul`); 458 tests, digest unmoved.
`.memory/sessions.md` → the 10-23 entry; auto-memory `project-active-walk-brought`.

**10-22/23 — every material is foraged at every km.** The owner wanted the zones' split gone. Shown how
drops work (the event roll, the three zones' pools, the beasts' own tables, live play: 72% of fights at km
1–10), then four rounds of numbers: of three shapes the owner picked weights that shift with depth (B), clay
the rarest — half of iron — and iron and clay ×1.5. Meat and hide stay kill-only. A clay price of 24/12 was
weighed (it moves «Мʼясо в глині») and postponed — then built on 10-23, night (above). Built as data: five 10-km bands in `zones.json`, all eight
materials in each; `spec-bestiary.md` §13, the `spec opening` block refreshed; 453 tests; `spawns` and the
content hash moved. `.memory/sessions.md` → the 10-23 entry; auto-memory `project-forage-without-zones`.

**10-22, evening — armour a death would take, named at the forest edge.** The owner: new players lose
armour because they forget a death empties the bag. `wipeOnDeath` takes all but the worn and the class
weapon, the Master's armour lands in the bag, and no screen said so before the death screen. Of four
forms the owner picked a block on the edge and on the duration picker («⚠️ У сумці броня, яку ви не
одягли:», a row per piece, «Смерть у лісі забирає все із сумки, а одягнене лишається з вами.») with
«🛡 Одягнути» first, which fills EMPTY slots only; a spare is listed and nothing more. The rule is
`DeathWipe` (ROIContent), asked by the wipe and the warning. Found on the way and fixed on the owner's
word: an edge left in chat across a restart started either expedition from the capital or the road;
every edge button now asks `edgeIsStale` first. 452 tests, digest unmoved. `.memory/sessions.md` → the
10-22 evening entry; auto-memory `project-armour-warning-at-forest-edge`.

**10-21, later — the warehouse's ℹ️ on a weapon.** The gear rows' info button carried the item id, so
a laddered weapon (described per tier, `.desc.t1…t9`) printed the raw `item.gear.simple_bow.desc`. The
owner picked A of two: the button carries the row's id and the alert reads that row's tier
(`EstateController.handleWarehouseInfo`); B, the bag's full gear card, was not picked. On 10-22, after
player questions answered from code (FAQ rows in `.memory/live-ops.md`), two uk lines say «майданчик»
for the arena's «Тренувальний двір» and the training exit's «двір». `.memory/sessions.md` → the 10-21,
later → 10-22 entry.

**10-21 — the vanishing keyboard.** Players reported the REPLY keyboard (the buttons under the
input field — not the inline ones under a message) vanishing, «/menu fixes it, not always»; four
screenshots. Found: (1) Telegram drops a reply keyboard with the message that brought it, and
`postStatusBanner` deleted the previous banner — 2 of 155 banners carry the keyboard (the training
exit, the stray-number hint), so the next harvest or craft took the buttons (`Володимир`, Android, T6:
no keyboard icon at all); (2) the estate and the bag render inline only, so their `unmatched` redraw
restored nothing («Ке» drew the estate again); (3) no keyboard sets `is_persistent`; (4) `/menu` is
not in `TGControllerBase.unmatched`'s global list and the SDK runs every matching handler, so the
screen gets it too (a Settings race, prompts eating it, the guild's found-name prompt taking «/menu»
for 500 silver). Two screenshots stay unexplained from code (Ivan's fight buttons at the estate on
10-19 after a menu-keyboard message; a pre-10-09 iPhone fight whose message carried the right
keyboard). The owner picked (1) and (2), built in `6ac0351`; (3) and (4) raised, not picked. Rule in
`CLAUDE.md`, auto-memory `project-reply-keyboard-lives-on-its-message`, a FAQ row with a ready reply
in `.memory/live-ops.md`, `.memory/sessions.md` → the 10-21 entry.

**10-20, late — the hub stops saying hello.** «👋 Вітаю, <нік>!» was `showMainMenu`'s default line,
so Settings' Back and seven other ways back to the hub greeted the player. The owner picked «👇
Оберіть, куди далі» for Settings' Back, then — told that Telegram carries a keyboard only on a message
with text — the same line everywhere (`266ad57`, `main.menu.prompt`; `greeting.message` deleted).
Raised in the same sweep: the capital square re-sends its photo and prose on every return; `/help` is
the template's (and swaps the `/buttons` and `/settings` descriptions). Auto-memory
`project-hub-never-greets`.

**10-20 — a player past km 49; the forest goes on past its horizon.** The owner relayed four
screenshots of «🕊 Лише тиша» from km 50 to 70. Read off `fight_log`: `Inokentiy`, archer L10, on
10-12 22:07–22:13 — fourteen flees in a row to km 49 on 11 HP, then twenty silent steps and a root
(2 HP); the run ended in a non-fight death out there (his record is 55, most likely from a 10-14 run). The bot log
records no steps and nothing failed. Cause: the deepest band (the rabid bear, 39–49) and the deep
wood end at km 49 and the walk does not, so past it 93% of steps rolled nothing. On the owner's word
the rabid bear, the rabid pack (36–40 and from 50, not 41–49) and the deep wood now answer every km
past the horizon (`beyondHorizon`, `ForestHorizon`, schema v25, 446 tests, `spec-bestiary.md` §12);
the two records past 49 stay. Side findings, not fixed: the warehouse's ℹ️ on a laddered weapon
prints the raw key `item.gear.simple_bow.desc`; a dead `explore:passive:close` handler ends any
expedition (pre-April chats only). Both in `TODO.md` → "Open". `.memory/sessions.md` → the 10-20 entry.

**10-17 — the Pi read; the leaderboard pages; a Telegram name escaped; the wealth board; the 17:40 deploy.** Read off the Pi: it runs
`dda286f`, the 10-15 restart was the host rebooting, and only the barrier's spark waited — a testers'
note for it went to the owner. The log's nine `🌷rilenx🌷` refusals were the registration welcome
printing a first name «<🌷RILENX🌷>» raw; the throw skipped the language picker and the player sits on
step 0. Escaped through `TelegramHTML` (437 tests); a guild name has the same hole, raised.
Then the journal's 🏆 boards learned to turn pages: ten a page, «◀️ N/M ▶️» wrapping round, a page's
first rank COUNTED so a tie across the edge keeps its place (`LeaderboardPaging`, 434 tests, every
live page matched Postgres `rank()`). The laptop died mid-build; the next session resumed from the
transcript. Last, before the push, a fifth board: «🪙 Багатство», the purse as it stands, other
players' places without their sums (the owner's pick). All of it — with the barrier's spark — went
live at 17:40 (`83176b8`, digest matched the Mac, no migration); the stuck player's apology went
once and she registered within two minutes. `.memory/sessions.md` → the 10-17 entry and the deploy.

**10-13, evening — the forest's Defend, measured; the mage's barrier strikes back.** Asked how the
three Defend buttons work: every Defend tap costs HP against an Attack (−2.6 / −4.4 / −3.2 at L9),
≈1.7% of live taps, its one use a sure finisher. Proposed «звір замахується» (a telegraphed ×2 blow
that a Defend stops) — the owner rejected that quiz to clarify and began with the mage: «нічого» is
bad. Built at the owner's 15% (`defend.mageChipMultiplier` 0.5, schema v24): a chip ignores the level
gap, and above ~20% "barrier every round" beats attacking a stronger beast. `.memory/rebalance.md` →
"The forest's Defend, measured"; auto-memory `project-forest-defend`.

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

**Велесова ніч must be live before Sat 31.10 08:30** — the first decree goes out at 09:00. It is committed (this commit,
over the 10-27 records' `5cbfe36` + `4c0ef48`); after the owner's push, ONE restart ships it together with the five
changes below (schema v29: the binary and the content together; three migrations — `CreateEventBlood`,
`CreateEventNotices`, `AddManorToExplorationState`; verify the TABLES after the restart). Its walk list is
`TODO.md` → "Added 2026-10-29" (the palace's reveal and the flask added 10-30); the board SQL for the finale's
zlatnyks is `.memory/live-ops.md` → "Велесова ніч".

**The plot cost, the softer wear, the gear sheet's wear block, the repair price and the Defend numbers wait for the owner's push and restart** (`7ac11f0` + the unpushed commits;
schema v28 — v29 with the holiday — so the Pi needs the new binary and the new content together — a `/reload` of this bundle onto the
running binary is refused by the handshake). After it: build a first plot on a fresh account (no 🧱 / 🔩 asked), a
second with one material short (the modal, the card redrawn); win a few fights and watch the kit lose a point in
about half of them, a flee one, a death two; read «🔧 Як зношується» on «🛡 Спорядження»; at the Master a hood missing 10 points costs 10 🪙 (5 before);
in a forest fight «🛡 Парирувати» strikes ~40% of a clean hit, «💨 Ухилитися» ~45%, «🌀 Магічний бар'єр» lets 70% of a blow through and sparks ~30%, while «🌑 Тінь лісу»'s knife stays small (~15%); read `/content` for hash `a3f69d76`.

**Walk the twelve blocks live since 10-23 22:46** on top of `TODO.md` → "Walk list" — clay at 24 / 12 and
«Мʼясо в глині» at 54 (the trader, the tavern's 135, the kitchen card, a portion cooked before the restart),
the archer's «💨 Ухилитися» and its line, the door's «Принесено» (a find eaten, a refused find, km 1 and back),
the forage at every km (`/content` reads hash `30b0d499`; clay and eggs in the shallows), the forest edge's
armour block («🛡 Одягнути», a spare, the duration picker, an old edge from the capital), «Руки майстра»'s
line, the road's hint (the other place's button), a find of two with one slot free (forage, a ×2 kill drop, a
passive report), the warehouse's ℹ️ on a bow (two tiers, both stores), the keyboard (a training exit, then a
harvest; a number before «🪙 Купити»; a word at the estate and in the bag), the hub's line, the forest past
km 49. The testers' note for them was written on 10-23 night; the owner publishes it.

**0 — Walk what is live and unwalked.** `TODO.md` → "Walk list": the twelve blocks live since 10-23
22:46, the four since 10-17 17:40, the five since 10-13 18:54, the six since 10-11 13:21, the 10-09 ones. For the Chancellery,
credit a test account in DBeaver first (`.memory/live-ops.md` → "Crediting zlatnyks"; if the grid
calls the new columns read-only, quit DBeaver and reopen, or use the SQL editor). No human has seen
the whole King's chain, and `/reload` has never run against a real database.

**1 — Answer the players.** Read the answer off the code and data, end with a ready Ukrainian
reply. Snapshot SQL and its reading traps: `.memory/live-ops.md`. Lost buttons: its FAQ row (ask
whether the ⊞ icon is in the input field; `/menu` re-sends them).

**2 — Watch the poll loop.** Still one `[WATCHDOG]` line on 10-23 22:48 (10-08 11:47:53); `Code: 400` still 922, no 429/502 since the 10-18 04:00 burst. A new one
in `~/.pm2/logs/ROI-out.log` is a freeze the limiter fix did not cover (`.memory/live-ops.md` → "Is
the bot alive?").

**3 — No bug queued.** The warehouse's ℹ️ on a laddered weapon (the raw `item.gear.simple_bow.desc`)
was fixed 10-21 and a find that half fits (one free slot, two found, nothing taken) 10-22; both live since 10-23 22:46; what is left in "Open" are questions for the owner (4).

**4 — Questions waiting on the owner** — `TODO.md` → "Open, decided but not done":
- **the 10-30 block, AFTER THE HOLIDAY:** «Принесено:» undercounted Ліліт's walk (🌰 × 1 for 🫐 ×1 + 🌰 ×2), cause NOT
  found, every fact recorded; count from the bag + a log line, or a log line only — offered, not picked;
- **the 10-27 block:** step 2 of the Defend work, stronger beasts — measured 10-27 night and PARKED by the owner
  («ми повернемось до них пізніше»). The first four beasts are kept; A is +1 from the moose (№5), B is +1 then +2
  from the wolf, C is +2; plus the level shift for outgrown beasts (6 / 5 / 4%). Recommended A and 6%, nothing
  picked (`.memory/rebalance.md` → "Stronger beasts — step 2"). Shadow Veil's knife (held at 15%) comes
  back with the techniques' rework; the three Defend lines' copy left as it was («черкаєте ножем» for a 45% knife);
- **the 10-24 block:** «%{type} закладена на слоті %{slot}» (`estate.plot.alert.claimed`) is feminine for every plot
  type — wrong for «Курник» (found while building the plot cost, not fixed); a «📌 У нотатник» on the plot's build
  card (it has materials now) was not built — not asked;
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

**5 — Read the rest of the `fight_log`.** Read on 10-10 for the repair (`.memory/live-ops.md` → "Day
four"): newcomers' busiest days ran 105–350 fights against the model's ≈25 a day, and 26% of wins end
untouched. Still unread: `estate_level` (do players hold the estate back? T6 gains nothing per day)
and how many wins are one tap — what the technique rework was for.

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
schema change ships `content/data` and the binary TOGETHER (the handshake — **v25** on the Pi, **v28** in the
tree since 10-27 — refuses a mismatch, a `/reload` included). After a migration, verify the TABLE, not the log line. Recipe and
traps: auto-memory `linux-build-gap`, `project-pi-deploy-swiftenv`, `reference-deploy-rehearsal`.

### The baseline and the simulator

**The current baseline — on the Pi since 2026-10-23 22:46 (`7ac11f0`, schema v25):** `records
68ecc8783252a905` · `tuning 799a96eb5f8619df` · `spawns 004c138c83fa9d1a` · `quests
30de20902006e3b9` · `king e3a492be1b017e81`, content hash `30b0d499` (COMBINED `c1d4f62d7aed7d8b`). **This
is the one place the current baseline is kept**; the superseded ones are in `.memory/sessions.md` →
"Digest baselines — superseded". **The tree differs since 2026-10-24** (a plot costs materials, a fight wears
less, the repair is back at ×0.5 and, since 10-27, the Defend numbers; schema v28, waiting for a restart): `records
f1501e3c1c9dc759` (the plot cost and the repair price), `tuning 6b67472ebbcad035` (the wear and the Defend), content
hash `a3f69d76` (COMBINED `6b4053507c3e34fb`); **and since 2026-10-29 (Велесова ніч, schema v29, this commit; the
10-30 rework and the pumpkin moved `records` and the hash): `records 7c252b0e1861e91c` · `tuning c0380e692986ba04` ·
content hash `42ec1955` (COMBINED `a687497d827739b9`)**;
`spawns`, `quests` and `king` as above.
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
swift test                                   # 501 tests, ~5s
```


## Rules

`CLAUDE.md` is the full set and is loaded every session. The three that cost the most when
forgotten: **never push** (user-side only), **never start / restart / stop the bot without
asking** (the Mac instance is the one exception — stop it, it 409s the Pi), and **ask before
committing**. Content edits must pass `roi-content validate --strict`; balance-table edits
must also re-run `roi-content simulate --strict`.
