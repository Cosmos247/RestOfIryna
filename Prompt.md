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

Router–controller state machine; game code in `Swift/`, the pipeline in `Modules/`, never
`Sources/`. Both stated in full in `CLAUDE.md`; the dependency table with exact version
pins is `.memory/tech-stack.md`.

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

### Where things stand right now (2026-10-04; `origin/main` is at `8ae6772`)

| | |
|---|---|
| working tree | clean |
| HEAD | the hash fill for **`4fe5b7a`**, **the Master's enchant draws from the bag alone** (a tester was told «треба 15, маєте 14» with 0 in the bag; the card now shows `RequirementLine`s; Swift and locale, digest unmoved), on top of `e569bca` — the hash fill for **`b0c9d80`**, **«💛 Допомога грі» in Settings** (one button, one text naming @irina_chemeris1998; Swift and four locale strings, digest unmoved), on top of `28511cf` — the hash fill for **`0b53e82`**, **the watchman says when a task is ready** (one unnamed «📓 Одне з ваших завдань виконано — загляньте в нотатник» per sweep; one migration, two strings, digest unmoved), on top of `c241d71` — the hash fill for **`47e0e8f`**, **a Vigor reward that will not fit is asked about** (a warning on the decree card and the NPC board, a question on the turn-in tap, the loss named in the banner; Swift and nine locale strings, digest unmoved), on top of `c1c0570` — the hash fill for **`a91226f`** (a one-shot card's later line without «отримано»; Swift and locale, digest unmoved), which also carries the Hanged Man's +15% XP (2026-10-04, `fortune.json` only); under them `e8c9580` — the hash fill for **`e861c73`**, the tarot pass (2026-10-04: a card phrased once by `FortuneDisplay`, 💰 for every reward, «Витрата снаги», the Chariot −50% and the card's multiplier on the techniques), on top of `f2d7855`, the 2026-10-04 sync pass (records; the weapon-ladder research made durable; `ReferenceCharacter.ladderRung` renamed `staleGearOffset`; four decree rules that had no test got one), on top of **`994c752`** — the hash fill for **`9ab349c`**, the weapon follows the player level (2026-10-04, `spec-items.md` §9). Under it, newest first: `9084528` / **`95e8492`** (the quest board as a scroll), `8b2bc4e` / **`f0c1749`** (the arena as a cycle of three), `51ec578` (the third 10-03 sync pass), `2dcf87c` / **`cad61c3`** (the arena in simultaneous rounds), `790560f` (the second 10-03 sync pass), `c28a3e5` / **`4be2758`** (the estate scaling), `7a6b458` (the 10-03 sync pass), `b407840` / **`f03d502`** (tier 2 of the bestiary), `ce8ef2f` (the 09-29 sync pass), and **`8ae6772`**, the build the Pi runs. **A commit cannot carry its own hash**, so this line always trails by one; read HEAD off the machine |
| pushed | `origin/main` is at **`8ae6772`**; the seventeen commits from `ce8ef2f` to `f2d7855`, then `e861c73` / `e8c9580` (the tarot pass) and `a91226f` with its hash fill `c1c0570`, and `47e0e8f` / `c241d71` (the Vigor-reward notice), and `0b53e82` / `28511cf` (the task-ready notice), and `b0c9d80` / `e569bca` (the Settings support button), and `4fe5b7a` (the enchant fix), are not pushed. Push stays user-side |
| running on the Pi | **`8ae6772`**, restarted **2026-09-28 22:11** — schema **v14**, content hash `490a2d4b`, digest `records 33e5c6e3259d51ba` · `tuning fe05ceaa38e03c6b` · `spawns c9bdb57d456adc26` · `quests 30de20902006e3b9` · `king 5dbddfd689f3cede` (matched the Mac byte for byte BEFORE the restart was ordered). Five migrations ran and the TABLES were checked after: 5 → 0 `training_ground` plots, `training_ground_level` 0 for all 10 users, `fight_log` and `exploration_state.combat_tally` exist, nobody at decree positions 23–25, 64 → 69 migrations. **Read it off the machine before acting on this line** (auto-memory `feedback-ask-the-machine-not-the-record`) |
| committed but NOT deployed | **`f03d502`, tier 2 of the bestiary** (2026-10-02, `spec-bestiary.md` §10): 14 creatures numbered in order (5 new), bands km 3N−3…3N+1, XP by number alone, the XP level-gap penalty off (`xpLevelDiff.perLevel` 0) with `enemy.xp_falls_with_depth` guarding the ladder instead. Needs `pm2 restart ROI`, not `/reload` (validator code, five new locale strings and the four rewritten oblique-case lines); no migration, because no id was removed. Digest `records 696d3c25c1a74d98` · `tuning c01ccfdb585f4a68` · `spawns 0cf31905171d7944`, content hash `cd9d73bf`. The 09-29 sync pass (`ce8ef2f`) is unpushed under it.<br>**`4be2758`, the estate scaling** (2026-10-03, `spec-bestiary.md` §11), sits on top: a spawnable creature's HP and ATK × (1 + 0.1·(estate tier − 1)), content schema **v15**, one migration (`AddFightLogEstateLevel`), and no locale string. With it, `tuning` reads `605fd06bd8abdfda` and the content hash `be4350a5`; the other four lines are unchanged. 336 tests, `validate --strict` 0/0, `simulate --strict` 0 broken bands.<br>**`cad61c3`, the arena in simultaneous rounds** (2026-10-03), sits on top: both fighters choose blind, a 15 s clock defends for the silent one, both blows land together and the heavier wins when both fall (`DuelMath`). Swift, locale and `arena.json` only — no migration, no schema change; `records` → `259f6cb6ca152450`, content hash → `7f6a7317`; 344 tests.<br>**`f0c1749`, the arena as a cycle of three** (2026-10-03) sits on top: a third button (the class special attack), arena-own round numbers in `arena.json` → `duel`, content schema **v16**, admission only for those who learned the special attack. `records` → `1b5577693d8733af`, content hash → `6963c31b`; 352 tests.<br>**`95e8492`, the quest board as a scroll** (2026-10-03) sits on top: the decree's requirement line and an 8-cell bar on the NPC board, 📖 for «Досвід» and 🍖 for «Снага» on every screen. Swift and locale only, the digest unmoved; 353 tests.<br>**`9ab349c`, the weapon follows the player level** (2026-10-04, `spec-items.md` §9) sits on top: nine rungs, one every five levels, at 75% of the growth; the first reforge is a lesson at the Master (materials + 30 🪙); the four weapon decrees moved to L5/10/15/20. Content schema **v17**, two migrations (`ClampWeaponTiersToLevel` with a silver refund, `ReseatDecreesById`); `records` → `1041961908ba2d3f`, `king` → `e3a492be1b017e81`, content hash → `00b40443`; 366 tests. Match the Pi's `--content-digest` against the line that ships BEFORE the restart.<br>**`e861c73`, the tarot card phrased once, and 💰 for every reward** sits on top: the reveal prints the card through `FortuneDisplay` like the fortune screen and the profile (the 22 hand-typed `buff_desc` keys deleted), silver as «+🪙 30» everywhere, the window on the price line instead of the intro's prose, «Ієрофант», and 🎁 → 💰 on the King's reward, the palace banner, the claim button and the tarot's loot. The same pass relabels «Виснаження снаги» «Витрата снаги», takes the Chariot from −25% to −50% Vigor (`fortune.json`; −25% rounded away on every step and blow), and lets the card's multiplier reach the techniques, the stance activation and the mage's flee tax, which bypassed it. No migration; `records` → `e91795fe3b76c8bf`, content hash → `794be740`; 370 tests.<br>**`a91226f`, a one-shot card's later line without «отримано»** sits on top: «Карта дня: Вежа · −🪙 25» on the fortune screen and in the profile, `fortune.effect.received` deleted. Swift and locale only, the digest unmoved.<br>**The Hanged Man's +15% XP** (in the commit that fills `a91226f`'s hash) sits on top, so the Chariot no longer dominates it: −10 dodge for −50% Vigor and +15% XP, against the Chariot's −50% alone. `fortune.json` only — a `/reload` would carry it alone; `records` → `438be135e3090fb5`, content hash → `73568a2a`.<br>**`47e0e8f`, a Vigor reward that will not fit is asked about** sits on top: a tester turned a Vigor-only decree in at full Vigor and got «✅ Указ виконано» over an empty «💰». Now the decree card (once done) and the NPC board (once ready) warn, the turn-in tap asks first («Доповісти / Здати все одно» or «Повернуся пізніше»), and the banner names what did not fit. Swift and nine locale strings, no migration, the digest unmoved.<br>**`0b53e82`, the watchman says when a task is ready** sits on top: a player asked to be told when a task was done. `RestNotificationService` asks a fourth question — the open decree complete, or a taken job ready to hand in — and sends one «📓 Одне з ваших завдань виконано — загляньте в нотатник.» (or «Кілька…») per sweep, anywhere, once per task. One migration (`AddReadyNotifiedFlags`), two locale strings, the digest unmoved.<br>**`b0c9d80`, «💛 Допомога грі» in Settings** sits on top: a third button on the settings keyboard that answers with the owner's text — «Якщо маєте бажання фінансово допомогти у розвитку гри, ви можете звернутись до @irina_chemeris1998.» Swift and four locale strings, no migration, the digest unmoved; the Settings button's label «⚙️ Налаштуваня» was corrected to «Налаштування» with it.<br>**`4fe5b7a`, the Master's enchant draws from the bag alone** sits on top: it counted the bag and the estate's warehouse and drew from both, so a tester with 0 hides in the bag and 14 at the estate read «Шкура: треба 15, маєте 14». Now the bag alone, as the lesson already did; the card shows `✅ 🪙 Срібло (540/220)` · `❌ 15× 🟫 Шкура (0/15)`; a refusal is a modal and leaves the card standing. Swift and locale (two strings dropped), no migration, the digest unmoved |

**Everything up to `8ae6772` is deployed** — the 2026-09-28 22:11 restart took the seven changes of 09-27/28 (the stray-number hint, salvage and gear rows, combat lines and the death screen, the Training Ground as a house room, the technique rework with `fight_log`, the decree reorder, and the workshop without armour). Before that, two restarts on 2026-09-22 took the whole backlog: 00:22
carried fourteen commits (`536fbf6` → `1faaddb`) — the capital street split, the quest
carry-over and the King's decree chain end to end — and 00:33 followed with a locale-only
pass for the two street descriptions. Three migrations ran at 00:22: `CloseBurnedQuestJobs`
(**36 of 39** open jobs closed, verified on the table, not the log line), `AddCapitalStreet`
and `CreateKingProgress`. The chain was live within minutes — a player had turned the first
decree in before the deploy entry was written.

Every deploy's hashes, what each carried and its verification block: the **Commit index** at
the top of `.memory/sessions.md`, with a dated `## Deploy —` entry for each restart.

### Where the last session stopped (2026-10-04 — the weapon ladder)

The laptop shut down on 2026-10-03 in the middle of the weapon work. The session was recovered
from its transcript (`75c2311f`; auto-memory `reference-session-transcripts`).

**The finding.** The owner had found the weapon growth too big. Measured, the cause was the gate:
- the rungs were authored at item level 1/10/20/30/40 but opened by the estate at L4/7/10/13;
- so the item-level-40 sword was in hand at L13, and fights from L7 ran at about half their
  contract.

**What shipped (`9ab349c`).** Over a series of quizzes the owner chose:
- a rung every five player levels at 75% of the growth, nine rungs to L40;
- the first reforge as a lesson at the Master;
- the testers clamped with a silver refund.

**A live defect fixed on the way.** The upgrade lives only in the T3 workshop, so «Гострий край»
(L4) most likely held the King's chain until level 7.

The day closed with the audit (`994c752`) and this sync pass. The decision record is
`spec-items.md` §9, and every table is in `.memory/rebalance.md` → "The weapon ladder, measured".

**Nothing is in flight.** Threads the owner may pick up:
- **The deploy** (item 0 below) — the biggest backlog since 09-28: eleven changes and four
  migrations.
- **The t6–t9 descriptions** were written after the names were approved and shown in the report,
  never approved on their own.
- **The weapon's leftovers** (`TODO.md` open items 1–4):
  - rungs 10–11 for a level cap of 50;
  - the tier-2 stat lines against the new obtainable share;
  - the workshop's T3 gate moved into content, where the validator could see it;
  - whether players now hold the estate back (`fight_log.estate_level`).
- **The arena.** Matchmaking, and the class gap: the warrior still wins 75–76% against the other
  classes. The owner's probable cure is each class's forest effect in the arena.

### Next action

**0 — Deploy everything committed since `8ae6772`:** tier 2, the estate scaling, the arena
(simultaneous rounds and the cycle of three), the quest board, the weapon ladder by player
level (2026-10-04, `spec-items.md` §9), the tarot pass, the Vigor-reward notice, the task-ready notice and the Settings support button (all 2026-10-04), and the enchant fix (2026-10-05). All of it is committed and audited (`spec-bestiary.md`
§10 and §11; §11.12 has every figure of the scaling; the arena's are in `.memory/rebalance.md` →
"The arena duel, measured"). One restart takes it all from HEAD. Shipping tier 2 alone would
mean the Pi stops at `7a6b458`.
- Read the Pi before assuming anything (auto-memory `feedback-ask-the-machine-not-the-record`).
- The owner pushes. On the Pi: `git pull --ff-only`, then build.
- Match its `--content-digest` BEFORE the restart:
  - everything (HEAD): `records 438be135e3090fb5` · `tuning 605fd06bd8abdfda` · `spawns
    0cf31905171d7944` · `quests 30de20902006e3b9` · `king e3a492be1b017e81` · content hash
    `73568a2a`, schema v17;
  - without the Hanged Man's +15% XP (`a91226f`): `records e91795fe3b76c8bf`, content hash
    `794be740`;
  - without the tarot pass (the weapon ladder, `9ab349c`): `records 1041961908ba2d3f`, content
    hash `00b40443`, the rest as above;
  - without the weapon ladder (the arena cycle, `f0c1749`): `records 1b5577693d8733af`, `king
    5dbddfd689f3cede`, content hash `6963c31b`, schema v16;
  - without either arena change (`790560f`): see the next line, schema v15;
  - without the arena (`790560f`): `records 696d3c25c1a74d98` and content hash `be4350a5`;
  - tier 2 alone (`7a6b458`): `tuning c01ccfdb585f4a68` and content hash `cd9d73bf`, schema v14.
- **Tell the testers above T1 first.** The game announces nothing (the owner's call), and from
  the first fight after the restart a T4 player loses ~75% more HP to the same creature. Tell
  them the arena changed too: rounds are simultaneous, 15 s a choice. And the weapon: every
  class weapon comes down to the tier its owner's level allows (L10 keeps t3), with the removed
  rungs refunded in silver; the first reforge is now a lesson at the Master.
- The owner runs `pm2 restart ROI`. A `/reload` is not enough, because of validator, combat and
  arena code, the new locale strings and the content schema.
- Four migrations run: `AddFightLogEstateLevel` (the estate scaling), then
  `ClampWeaponTiersToLevel` and `ReseatDecreesById` (the weapon ladder), then
  `AddReadyNotifiedFlags` (the task-ready notice). Verify the TABLES:
  `fight_log` has a nullable `estate_level`; no weapon row above its owner's level and the
  `king_progress` positions as predicted — both queries are in the migrations' headers;
  `quest_progress.ready_notified` and `king_progress.ready_notified_index` exist. Run
  `SELECT decree_index, count(*) FROM king_progress GROUP BY 1` BEFORE the restart to compare.
  The first sweep after the restart announces, once, every task already ready.
- Then record the deploy (a `## Deploy —` entry in `.memory/sessions.md`, this table) and point
  the testers at the eleven new walk-list blocks.

**1 — Read the first `fight_log` rows** once the testers have fought: the rework's first live
measurement. `SELECT nickname, character_class, player_level, estate_level, enemy_id, outcome,
rounds, max_blow, max_blow_source, special_atk_uses, stance_uses FROM fight_log ORDER BY
created_at DESC` — a one-tap kill of an on-level beast (`rounds = 1`, a `win`, `max_blow` from a
technique) is the thing the rework was for. Since the estate scaling, `estate_level` also shows
whether players hold an upgrade back to keep the forest soft (T6 gains nothing per day). The
rework's own deploy is done and recorded (2026-09-28 22:11, tables verified).

**2 — Someone opens the screens.** Every defect this project has found came from glancing at a
screen, not from running anything. **`TODO.md` → "Walk list"**: the enchant, support-button, task-ready, Vigor-reward, tarot, weapon, quest-board, two
arena, estate and tier-2 blocks on top (after their deploy; the arena ones need two accounts),
then the six 2026-09-27/28 blocks (the workshop without armour; the technique rework; the Training Ground build and catch-up, with the decree reorder;
salvage and the gear rows; the stray-number hint; combat lines and the death screen), then the
older backlog — the whole King's chain included, which no human has seen.

**3 — Decisions waiting on the owner**, all in `TODO.md` → "Open, decided but not done": the
kit still costing more Vigor than
plain attacks (+35 / +16 / +36% on an elite, prices untouched); a mage winning a fight at 0 HP
(the burn ticks before the player's death check); `/menu` missing from the base `unmatched`
filter; for the arena, matchmaking and the class gap; and the weapon ladder's four leftovers
(the section above).
Ideas raised and not asked yet: a «Відновити» service at the Master (reset max for silver, keep
the enchant — a silver sink), the Master refusing to mend a piece worn to 1/1, and the passive
report naming its losses the way the death screen now does.

**Deploying to the Pi:** `git push` — user-side, never you — then on the Pi
`git pull --ff-only`, build, and **ASK before `pm2 restart ROI`** (the rule in full:
`CLAUDE.md` § Running the bot). A content or schema change must ship the new `content/data`
and the new binary TOGETHER — the working tree's schema handshake is at **v17** (the weapon ladder's gates and the lesson fee; v16 was the arena's `duel` section, v15 the estate scaling; the Pi runs v14) and refuses a mismatch.
Free pre-flight that touches neither the running bot nor the database:
`ROI_PROJECT_PATH=/home/rpi5/RestOfIryna ./.build/debug/RestOfIryna --content-digest`; match
it against the Mac BEFORE ordering the restart, which is the order the decision has to happen
in. **After a migration, verify the TABLE, not the log line.** The traps that cost real time —
swiftenv's `PATH` living in `.bashrc` (a non-interactive ssh needs
`export PATH="$HOME/.swiftenv/shims:$PATH"`), and `pgrep -f` matching its own ssh command —
are in auto-memory `project-pi-deploy-swiftenv`, `linux-build-gap`.

**The API-error question is CLOSED.** `Code: 400` has held at its **913** baseline across four
restarts, and the only `[SCREEN]` lines in the whole log are 8 `StreamClosed` redraw failures
dated 09-15 — HTTP/2 transport, not screen logic. The two log greps to run if a new screen bug
is ever reported are in auto-memory `feedback-ask-the-machine-not-the-record`, beside the four
that say what is actually live.

### Open, decided but not done

Twenty-two items, each raised deliberately and kept out of an unrelated commit on purpose.
- **From 2026-10-04, the weapon ladder's four:**
  - rungs 10–11 (L45/50) wait for a level cap of 50;
  - the tier-2 stat lines were solved against the old obtainable-kit share;
  - the workshop's T3 gate is a Swift constant the validator cannot see;
  - the estate no longer opens the weapon.
- **From 2026-10-03, the arena's two:**
  - level and class decide a duel (L10 against L12 wins 2.5%, the warrior beats the other
    classes 75–76%), with no bracket and no queue;
  - a challenger who leaves by `/settings` while waiting is not moved back on accept.
- **The estate scaling's two accepted costs:**
  - T5→T6 gains no XP per day (×0.9) until new estate tiers add food;
  - «Пуща» (km 26 at level 17) has no margin left for the mage.
- **From 2026-10-02, tier 2's leftovers**, plus a dead knob found while modelling —
  `walkRoomDoubleSpeed`, the cost of a double-speed walk that does not exist:
  - №3–4 running above contract for a player without armour;
  - the opening ledger fighting with the armoured reference;
  - `simulate`'s pace not seeing depth.
- **From 2026-09-27:** the kit's Vigor cost, a mage winning at 0 HP, and `/menu` missing from
  the base `unmatched` filter.
- **Older:**
  - the estate calling one place **two** words now that «наділ» is gone but «Слот» still stands
    in 18 keys;
  - `InventoryEntry.remove` ignoring `equipped_slot`;
  - `CapitalController.pushTradeInvite` discarding its message id;
  - the recipe-scroll machinery (`Item.teachesRecipe`, `InventoryController.handleLearnRecipe`)
    kept unreachable on purpose;
  - the Master's blade trial naming a zone it does not mean;
  - seven dead functions (`renderStub`, `backToRootKeyboard`, `backToHomeKeyboard`,
    `itemNameOrId`, `isPassiveInflight`, `invalidateCache`, `CapitalController.renderLocation`),
    left for a standalone cleanup.

Each one's reasoning: **`TODO.md` → "Open, decided but not done"**. The standing simulator
deferrals are below.

### Where the changelog went

Every commit from 2026-09-09 onward — hash, what it did, and the pattern behind it — is the
**Commit index** at the top of `.memory/sessions.md`, with a dated narrative entry for each
below it. This file no longer carries one, on purpose: it was the third copy.

### What the rebalance settled

The authored band is **levels 1–25**, an enemy of level N spawned **km N…N+9** (since tier 2,
2026-10-02, a creature's number is its rung and its band is km 3N−3…3N+1 — `spec-bestiary.md`
§10), the zones are
**Гущавина 1–10 / Старий ліс 11–25 / Пуща 26–49**, and **no new items or sets** ship in this
release. Vigor does not regenerate (Phase 8E) — food, quests and the estate are the only
sources, and the estate is the intended income. The wardrobe sits at ~40% of the on-curve
budget and the bestiary at 65–78% of its archetype contract; **both half-strength errors
lean the same way**, so the gear ladder and a roster re-solve ship together, afterwards.

The debt Phase 9 wrote itself is paid. Its finding is **`opening.shallow_is_bankrupt`** again since
tier 2 (2026-10-02; it read `opening.vigor_bankrupt` from the 09-14 XP halving until then). It
comes with a caveat: the ledger's profitable window at km 12–17 is held by the ARMOURED reference
character, not by a level-3 player in the registration kit. Read the current ledger from
`roi-content spec opening -c release`, never from a doc.

The rule all five specifications run on: **numbers are printed, never typed** — and the
corollary learned the hard way, **the rule protects tables, not the prose beside them**.

Decisions, the calibrated math model, the phase tracker and the per-phase lessons:
`.memory/rebalance.md`. Auto-memory `project-world-ladder`,
`project-vigor-no-passive-regen`, `project-opening-is-vigor-bankrupt`,
`project-post-rebalance-package`, `feedback-printed-numbers-protect-tables-not-prose`.

#### Standing deferrals

Reported by every `simulate` run, all deliberate: **food portions are flat
against a pool that grows** (the Feast is 69% of a level-1 pool and 24% of a
level-40 one since the 09-18 repricing, up from 33% / 12%),
**nothing new unlocks between level 21 and 40**, **levels 1–3 have no estate at
all**, the **thirteen `content.roster_off_curve` warnings** (since tier 2, every stat line is
solved against the kit players actually carry, so all read light against the reference
character; they stay until the gear ladder moves the wardrobe), and
**`opening.shallow_is_bankrupt`** — back since tier 2, after reading `opening.vigor_bankrupt` from
the 09-14 XP halving; a warning and not a broken band on purpose, because §7 decided to measure
before retuning. Silver is also **over-supplied** — roughly twenty
thousand spare over a lifetime against 2,950 of mandatory spend (the estate's 1,600 plus the
Training Ground's 1,350 since 2026-09-27) — and the fix is
more to buy, which is items, which is after the rebalance.

#### The simulator, and what it currently says

`swift run -c release roi-content simulate` rolls the SAME `CombatMath` the bot calls, so a
report cannot drift from the game. It sweeps levels × archetypes × classes × play profiles ×
gear offsets and bands level invariance, the p90 tail, win rates, pace to the cap and the
shipped roster against its archetype contract; `--strict` exits 1 on a broken band. Default
sample size **8000 fights per cell** — 2000 crossed the invariance band on sampling noise alone.

Current state: **18 of 18 invariance rows pass, 0 broken bands, 18 warnings** (12 until tier 2; the
six added are all `roster_off_curve`), 19,437,688 XP
from level 1 to 40, **151–167 days** on a tended estate (warrior 167.0 / archer 159.6 / mage
150.9; the band the report gates on is 72–200, taps/day ~711). **The estate scaling moved it
from 114–126** (125.5 / 120.9 / 113.8): since 2026-10-03 the pace lifts each level's fight by
the factor its estate tier measured in the new «the forest by estate tier» section, which
prints and never bands — every band still measures the authored contract. Before that, the
headline swung 128.7 → 122.4 → 110.0 → 125.5 across the 09-18 edits and **most of the
swing was not speed**: the model drops tiers that feed nothing out of the average, so making
the duck egg inedible and then edible again took T2 out and put it back. The real movement is
the estate being 11–15% richer on every tier above T2. `EnemyGenerator` is what the
post-rebalance regeneration will lean on — run at design time and frozen, never at runtime.
**The pace section cannot see depth.** It prices every kill as an on-level fight and never walks
from the manor, so no roster or band change moves it. The tier-2 expedition model can see it, and
put today's game at ~600 days to L40 with real gear (`.memory/rebalance.md`). What each phase
taught: `.memory/rebalance.md`.

**HEAD digest (2026-10-04, schema v17 — the tarot pass on top of the weapon ladder, NOT yet on the Pi):**
`records 438be135e3090fb5` · `tuning 605fd06bd8abdfda` · `spawns 0cf31905171d7944` ·
`quests 30de20902006e3b9` · `king e3a492be1b017e81`, content hash `73568a2a`. The tarot pass
moved `records` alone, three times: a card's fingerprint names its locale keys (`buff_desc` gone,
`8c58515e0b4d51d7`), then the Chariot's `vigorDrainMultiplier` 0.75 → 0.5 (`e91795fe3b76c8bf`,
`794be740`), then the Hanged Man's `xpMultiplier` 1.15. `fortune.json` is the one data file
touched, hence the content hash.

**The weapon ladder's baseline** (`9ab349c`) is the same with `records 1041961908ba2d3f` and
content hash `00b40443`. It
moved `records` (nine gated rungs and `weaponLessonSilver`) and `king` (four decrees moved);
`tuning`, `spawns` and `quests` are byte-identical.

**The arena cycle's baseline** (`f0c1749`, schema v16) is `records 1b5577693d8733af`, `king
5dbddfd689f3cede` and content hash `6963c31b`, the other three lines as below. The cycle moved
`records` alone (the four `arena.json` → `duel` numbers).

**Current digest baseline (2026-10-03, schema v15 — the simultaneous arena, `cad61c3`, NOT yet on the Pi):**
`records 259f6cb6ca152450` · `tuning 605fd06bd8abdfda` · `spawns 0cf31905171d7944` ·
`quests 30de20902006e3b9` · `king 5dbddfd689f3cede`, content hash `7f6a7317`. The arena moved
`records` alone (`696d3c25c1a74d98` → `259f6cb6ca152450`: `turnSeconds` 45 → 15,
`maxMissedTurns` 2 → 3, `sweepInterval` 10 → 1); with the old `arena.json` the new code reads
the estate scaling's baseline byte for byte.

**The estate scaling's baseline** (`4be2758`) is the same with `records 696d3c25c1a74d98` and
content hash `be4350a5`. The estate
scaling moved `tuning` alone (`c01ccfdb585f4a68` → `605fd06bd8abdfda`). It replays
`estateScale` and the façade on a synthetic pair, and no record, band, quest or decree changed.

**Tier 2's committed baseline** (`f03d502`, schema v14) is the same with `tuning
c01ccfdb585f4a68` and content hash `cd9d73bf`. Tier 2 moved three lines and left two:
- `records`, for the roster and the archetype XP multipliers;
- `tuning`, for `xpLevelDiff.perLevel` 0.08 → 0;
- `spawns`, for the new bands.
`quests` and `king` are byte-identical.

**The Pi still runs the 09-28 baseline:** `records 33e5c6e3259d51ba` · `tuning fe05ceaa38e03c6b` ·
`spawns c9bdb57d456adc26`, content hash `490a2d4b`. Its own `--content-digest` matched the Mac
byte for byte before the 2026-09-28 22:11 restart. Three lines moved on 09-27:
- `tuning`, for `gear.salvageFraction`, the special attack's floor 8 → 10 and then the
  technique rework's five numbers (`11797ea73591e02f` → `fe05ceaa38e03c6b`);
- `records`, for the Training Ground ladder;
- `king`, for «Наука бою»'s new condition and then the reorder that put the estate before the
  ground (`08733a95f4d34e68` → `5dbddfd689f3cede`).

`king` is a fifth line, added with the decree chain, and the four older ones are
byte-identical across it — which is the entire point of splitting them. `records` moved four
times to get to its value (the farm ladder, the bag ladder, the food repricing, the
innkeeper's unlock rungs) and has not moved since. **This is the one place the baseline is
kept** — `.memory/status.md` quotes it, and `.memory/rebalance.md`'s figures are a Phase-11
record, not a current reading. A knob is invisible to the digest until it is hashed — add the
line in the same commit that adds the knob (auto-memory `feedback-digest-names-constants`).

HP regen is **10% of max HP per real minute** (`tuning/vigor.json` → `healing.regenPerMinute`),
so a full rest at the estate takes 10 minutes — and **only at the estate**. `simulate --strict`
stands at 0 broken bands / 18 warnings: the sweep models fights, not the rest between them.

⚠️ **Four accounts played 2026-09-02 → 09-09** and reached L10 / estate T4, so the
rebalanced formulas have been exercised — but nobody stepped through the first hour against
a checklist, and **`/reload` has still never run against a real database**. It is now the
cheapest way to ship a content edit, so it is worth proving early. Auto-memory
`first-playtest-happened`.

### How content works now

All 15 catalogs and all seven tuning tables are façades over a snapshot installed at boot:

```
content/data/*.json → ContentLoader → ContentValidator → GameContent (DTOs)
                                                       → DomainContent → Catalogs.current
```

`ContentBootstrap.load` runs in `configure` **before the database block**, and **no
`static let` anywhere may reference a catalog**. The migration loop, the verification
layers and every gotcha: `.memory/content-pipeline.md`.

### Running locally (rare now — the Pi is production)

Only to debug against the live database from the Mac. **Stop the Pi's instance first** —
the same token sits in both `.env` files, so two pollers means a 409 — and kill
`debugserver` before the process, since a crashed Xcode run survives `kill -9` while the
debugger traces it. The three commands, the `S`/`N` handshake probe that proves more than
`nc -z`, and the full recovery order: auto-memory `roi-local-run-setup`.

### Commands

```
/content   /reload                           # dev-only, in Telegram: inspect and hot-swap
swift run roi-content validate --strict      # content integrity; exit 1 on any error
swift run -c release roi-content simulate    # balance sweep; --runs/--seed/--levels, --strict gates
swift run roi-content spec <table>           # progression · gates · bestiary · items · sets · economy · opening · king
swift run RestOfIryna --content-digest       # confirm ONLY the intended change moved
swift test                                   # 370 tests, ~5s
```

## What Works Now (shipped game)

**The King's decree chain** (2026-09-21, live since 09-22) — 39 decrees from level 1 to 25,
one open at a time, walked in `king.json`'s array order. The first arrives as the royal
charter right after registration; the open one is always visible read-only in the journal;
it is turned in at 👑 Палац, a `Location` on Замкова. Eleven of the eighteen condition kinds
are live state reads, seven are events funnelled through `KingService.record`. No screen
shows "decree N of 39". Spec `content/spec/king.md`, table `roi-content spec king`.

Registration · exploration (active + passive, three-tier visit decay, restart-safe
scheduler) · turn-based PvE combat with 9 class techniques (since 2026-09-27 the full kit shortens an
elite fight by ~20% for every class, every technique tap strikes, and each forest fight leaves a
`fight_log` row) · estate (plots, warehouse, workshop — ingots, upgrades, salvage; armour only from the
Master since 09-28 — kitchen, weapon/bag/estate upgrades, the Training Ground room at T4; since
2026-10-04 the weapon climbs nine rungs opened by the player level, the first a lesson at the
Master) · capital hub (travel across
**two streets** — 👑 Замкова: Базар / Ристалище / Гільдії / Палац, 🏘 Поділ: Крамар / Майстер /
Шинок / Ворожка, the square holding only the two roads — plus
Trader, Tavern, Fortune Teller, Master, player Market, synchronous Trade) · Guilds · Arena
(live PvP duel in simultaneous rounds since 2026-10-03, a cycle of three — Attack, Defend, the
class special attack — Honor ELO, stakes, daily budget) · daily NPC quests **taken by hand at the
NPC**, and since `328bf88` **a taken job never burns** — one open job per NPC, today's offer
waiting behind it, a carried one droppable — the innkeeper's also **teaches a cooking recipe**,
one rung of the ladder per finished job, announced nowhere in advance — + journal · **four all-time leaderboards** behind that journal, as tabs redrawing one
message. Every daily system keys off `GameDay` (rolls at **12:00 Kyiv**). EN + UK
localization. **Access is invite-only and lives in `allowed_users`**; `/link` mints a
five-minute deep link and nobody else gets a `User` row at all.

✅ `tuning/time.json` → `scale` is **1.0** (2026-09-09): game time is real time. Plot cycle
1 h, passive runs 30 / 60 / 90 min, a trip to the capital 2 min. Nothing under `realTime`
ever scaled. Key counts, per-feature detail and what is still planned:
`.memory/status.md`.

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
| `content/spec/` | The five approved specifications (Phase 9, closed) + `king.md` (the decree chain, 2026-09-21) |

## Rules

`CLAUDE.md` is the full set and is loaded every session. The three that cost the most when
forgotten: **never push** (user-side only), **never start / restart / stop the bot without
asking** (the Mac instance is the one exception — stop it, it 409s the Pi), and **ask before
committing**. Content edits must pass `roi-content validate --strict`; balance-table edits
must also re-run `roi-content simulate --strict`.
