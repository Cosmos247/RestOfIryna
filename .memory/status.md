# Implementation Status

> **How to read this file.** The top sections describe the CURRENT state. The
> `Previously: <date>` blocks near the bottom are frozen snapshots of past
> phases — their numbers were true then and several are now superseded (e.g. the
> Forester set cost rose from 16 hide to 40 hide + 8 iron on 2026-05-22, and
> every catalog roster moved to `content/data/*.json` in the rebalance). For live
> numbers read the JSON; for the active work read [rebalance.md](rebalance.md).


## Rebalance status (Phases 3–11 done · Phase 11 closed as CODE · live-play polish since 2026-09-09)

The pre-release rebalance (done, deployed) rewrote most of the
numbers below. Current state:

| Phase | What landed |
|---|---|
| 3 | All 12 catalogs read `content/data/*.json`; no Swift content array remains (Zone made it 13 in 8E) |
| 4 | Six tuning tables in `content/data/tuning/`; three `testMode` flags collapsed into one `time.scale` (**1.0 since 2026-09-09**) |
| 5 | Combat is ABSORPTION, not subtraction; ratings→% curves; `levelDiff`; `maxLevel` 40; proportional growth; a Vigor pool ~~+ regen~~ *(8E deleted the regen)*; enemies generated from a six-archetype table ~~and dropping silver~~ *(8C deleted the silver)*; the three special attacks rebuilt off "ignore armour" |
| 6 | Item stat budget, rarity ladder, sets with a second `recomputeBonuses` pass, gear HP, enchant as % of the item's own budget *(the armour's ladder since 2026-10-06)*; the 7 shipped items and 3 ladders regenerated |
| 7 | `/reload` + `/content` hot swap, gated by `LiveReferenceCheck` over ten content-id columns |

**2026-10-09 — the fortune teller once a game day** (NOT committed yet, NOT deployed; needs `pm2
restart ROI` — Swift and `content/data`, content schema **v20**; no migration, no locale string).
The owner's rule: the next card waits for the LATER of the drawn card's 6 h and the next 12:00 —
drawn at 22:00, the next at 12:00; at 11:00, at 17:00, and then not before the following noon. A
flat 24 h cooldown stood there (`fortune.cooldownSeconds`, now gone, hence v20), computed twice;
`User.fortuneAvailableAt` is the one rule now, read by the screen, the draw and the watchman. A
card drawn between noon and 06:00 comes back on the rollover's own minute, and then «🔮 Карти
знову готові» and «📜 Новий день…» go as ONE message, cards first (the owner's pick). Digest:
`records` → `f67ba528e8f0cb9f`, content hash → `86aa6b60`; the other four lines unmoved.

**2026-10-08 — the public test's starving players** (`88156d4`, NOT deployed; needs
`pm2 restart ROI` — Swift and three uk/en strings, one deleted; no migration, the digest unmoved).
A snapshot showed the newcomers fighting most of their fights at 0 Vigor, some with food in the
bag; the owner chose four changes in two quizzes:
- **the hunger tick only on a step that BEGINS at 0 Vigor** (`ExplorationService.rollStep` reads
  `isStarving` before the drain) — the paying step was charged too, and killed an archer on 09-12;
- **«Ви повністю відпочили» for every rest that tops out**, a tap's fill included (`RestedToFull`,
  noted by `HealingService.tick`, announced by the watchman within a minute, at the estate only);
- **the road refuses only 0 HP** — the 0-Vigor guard was a May leftover that kept a starving
  player from the capital's food and Vigor-paying jobs (`TravelService.start`);
- **the forest edge explains hunger** (`ExplorationController.modePrompt`): what it costs, from
  the tuning, and the food in the bag with the path to «🍴 Зʼїсти»; nothing when the food is only
  in the warehouse; the forest and the Trader when there is none.

Chosen but not built, the owner having left their form unanswered: eating straight from the
warehouse and a hint under the estate-name prompt. Not chosen: partial market lots.

**2026-10-08 — one road card per trip** (`2ed296e`, NOT deployed; needs `pm2 restart ROI` —
Swift, one asset, one uk string): a player asked for the estate ↔ capital crossing to be visible.
Setting out, `↩️ Розвернутись` and "how long is left" are the owner's picture
(`Assets/travel/road.jpg`) with a new caption; `CapitalController.sendRoadCard` sends the new card
and deletes the trip's previous one (the one exception to "photos are kept"), arrival forgets the
id. Arrival home stays text. The road's no-Vigor refusal «поїж» became «поїжте» (the refusal
itself is gone since the next change).

**2026-10-08 — the poll loop froze four times; the SDK's rate limiter is off** (`ee7437e` +
`94620a4`, deployed 11:45 and 11:55): pm2 `online`, no socket to Telegram, the update queue
growing. The cause is swift-telegram-sdk 4.6's `LimiterAsync`, which every API call passes and
which deadlocks after a burst that ends on exactly `maxRequests` waiters (reproduced with 10
calls) — a restart's backlog is such a burst, so each restart froze again within a minute.
`apiRequestLimitLongPolling: nil` turns it off; `PollWatchdog` exits after 120 s without a
completed `getUpdates` (fired once, 11:47:53, before the fix); the client is HTTP/1.1 with
timeouts (the first suspect, cleared). Up ~10 h with no freeze since. `tech-stack.md`.

**2026-10-07 — the open door, and guilds from level 30** (`f200fa5`, deployed 18:34): the
public test. `ROI_OPEN_ACCESS=1` in the Pi's `.env` admits every account that writes
(`allowed_users` source `open`, a silent owner notice per newcomer); `/link` still works, and
closing the door keeps everyone already in. `guild.json` → `foundLevelGate` 5 → 30 (data only;
the refusal banner interpolates it). Ten players came in the first six hours.

**2026-10-06 — the owner's screen art, and the King's first line** (`873e426`, deployed 2026-10-06 21:39;
art and two locale lines, no code): the Master, the palace, the capital map on the square and both
streets, the charter and the six rabid-dog scenes, each through a slot `sendCachedPhoto` already
had. Measured against the 1,024 caption: the King's oath 578 (uk), the palace ≈500, the Master's
lesson card ≈450. The King's first line now matches the art — he sits and holds out the scroll.
`capital/market.jpg` is the one capital slot still empty.

**2026-10-06 — the pre-deploy audit's four fixes** (`f2ae7ea`, deployed 2026-10-06 21:39; Swift only, no
migration, the digest unmoved). A review of everything since `8ae6772` found no blocker and these
holes in it, all fixed:
- the palace's and the NPC board's «… все одно» named nothing, so a double tap handed in the next
  decree unasked;
- a stake picker left in chat issued a challenge from anywhere, past the arena's door;
- the palace banner quoted the authored XP and sent no level-up banner;
- three data migrations were not transactional.

The rest is in `TODO.md` → "Open, decided but not done".

**2026-10-06 — the Master's enchant is the armour's ladder** (`bad142b`, deployed 2026-10-06 21:39;
it needed `pm2 restart ROI` — Swift, locale strings and content schema **v19**, no migration;
`spec-items.md` §11):
- **Why.** The owner asked how the armour enchant works and how to improve it. A level added 4%
  of the piece's own stats, and the only armour is item level 1: thirteen of the twenty purchases
  on the Forester set changed no number, and a whole +5 (6,640 🪙, 380 hides) gave +3 DEF and
  +4 HP. The prices and the hint dated from May's flat mechanic.
- **Now.** A level budgets the piece at item level 5 / 10 / 15 / 20 / 25 with 75% of the
  curve's growth — the weapon ladder's law, picked over 50%, 100% and +20% a level.
  `EnchantLadderRules.scale` is the one lift (the game, the validator, `spec gates`). The set at
  +5 is 🛡55 ❤️83 💥20 💨15.
- **The gate is the price.** NO player level gates a level, on the owner's word; a gate was built
  with the ladder and taken out the same day. The price is 50 × level² silver a piece — 50 / 200 /
  450 / 800 / 1,250, 11,000 a set — with the hides unchanged (4 / 8 / 15 / 26 / 42). An enchant
  never fails.
- **Screens.** The card prints the stat deltas (`GearStatLines`), silver and hides. The banner
  names what was added. The player-facing word is «покращення»; «заточка» is slang (the owner)
  and is on no screen — the bag card reads «✨ Покращення: +N», the banner «покращено до +N».
- **Validator.** `master.enchant_level_changes_nothing` refuses any level that leaves an armour
  piece unchanged — and with it, armour authored above item level 1 until its ladder is decided.
  `master.enchant_cost_drops` now watches the ladder's only gate.
- **Measured.** Below about level 10 a level bought early beats the forest as solved (a set at +5
  on a level-5 player: +51% XP per Vigor), so the price carries the balance. At the chosen prices
  the fastest saver buys +3 at level 7, +4 at 15 and +5 at 22, never more than 5% above the
  solved forest. Days to L10 / 14 / 19 / 25 / 30 / 40: today 63 / 86 / 119 / 175 / 241 / 474,
  that saver 51 / 70 / 99 / 149 / 209 / 439, the forest as solved 51 / 65 / 88 / 123 / 173 / 385.
  395 tests; `validate --strict` 0/0; `simulate --strict` 0 broken bands, the same 18 warnings;
  digest `records` → `9303bb274d4517d8`, the other four unchanged; content hash `be1102fc`.

**2026-10-05 — durability is the item's own; the Forester set at 50** (`bf15669`, deployed 2026-10-06 21:39; it needed `pm2 restart ROI` — Swift, content schema **v18** and one migration;
`spec-items.md` §10):
- **Why.** The owner opened a day of gear work by asking for the Forester set at 50. One
  number, `economy.gear.maxDurabilityStart` 30, stamped every new row — the class weapon too,
  whose ladder also starts at 30, so at 50 a new sword would have read 50/50 and dropped to
  40/40 at the lesson — and the repair price divides by it.
- **Now.** `items.json` → `maxDurability` on every piece a fight wears outside a weapon ladder
  (the Forester four at 50); the global is gone. `GearConditionService.startingDurability(for:)`
  is the one reader: fresh rows (`GearState.fresh(for:)`), the repair price, the salvage share.
  The Master's prices ×5/3 (100 / 160 / 250 / 300, set 810) with `repairCostFraction` left at
  0.5, so a repaired point costs what it did — the owner's pick over 0.83 at the old prices.
  Validator: `durability.missing` / `non_positive` / `shave_destroys_gear` (errors),
  `on_ladder` / `not_worn` (warnings). The trade list prints wear only for what wears.
- **Existing pieces.** `RaiseArmorDurability`: +20 to both numbers, bag and warehouse — the
  Pi's 24 rows; a broken piece comes back at 20. `EquipmentService.backfillGearBonuses`
  re-derives the cached gear bonuses at every boot. That also closes a wider gap under the
  undeployed weapon ladder. It re-solved every rung's stats and the clamp moves tiers, so four
  testers would have fought their first fight on the old rung: Дарина with a cached sword ATK of
  +60 against the new t5's +27, анія +58/+21, Володимир +55/+20, Amae +46/+16.
- **Measured.** 379 tests; `validate --strict` 0/0; `simulate --strict` 0 broken bands, the same
  18 warnings; digest `records` → `fefe14b940998631`, `tuning` → `4edf65507bbb5e48`, the other
  three unchanged; content hash `41455b84`. The migration's SQL, run on a temp copy of the Pi's
  24 rows, read +20/+20 on every one.

**2026-10-05 — the Master's enchant draws from the bag alone** (`4fe5b7a`, deployed 2026-10-06 21:39;
it needed `pm2 restart ROI` — Swift and locale):
- **Why.** A tester: «треба 15 шкури, а я маю 14. ХОЧА В СУМЦІ 0». `MasterService.enchant`
  (May, `4a13163`) counted bag + estate warehouse and drew from both; the refusal printed the sum.
  The Master's lesson (10-04) already counted the bag alone, so one NPC ran two rules.
- **Now.** Bag alone, as the lesson; the card is `RequirementLine`s (silver, the hides); a refusal
  is a modal that leaves the card standing (`finishMasterEnchant`, the lesson's shape). The fill
  `fd6e6e1` gave the lesson's tap the same answer-on-throw.
  `capital.master.confirm.enchant` and `capital.master.missing_materials` are gone.
- **Accepted.** +4 (26 hides) needs a bag of 35, +5 (42) one of 45.
- **Measured.** Both touched files recompiled with no warning; 370 tests; `validate --strict` 0/0;
  digest unmoved; three cards rendered in both languages.

**2026-10-04 — «💛 Допомога грі» in Settings** (`b0c9d80`, deployed 2026-10-06 21:39; it needed `pm2 restart
ROI` — Swift and four locale strings): `Commands.support`, a third button on the settings keyboard
([🌐 Мова] [💛 Допомога грі] / [🔙 Назад]); the tap answers with the owner's text naming
@irina_chemeris1998 and keeps the keyboard. The Settings button's own label was fixed with it:
«⚙️ Налаштуваня» → «⚙️ Налаштування». 370 tests, `validate --strict` 0/0, digest unmoved.

**2026-10-04 — the watchman says when a task is ready** (`0b53e82`, deployed 2026-10-06 21:39; it needed
`pm2 restart ROI` — Swift, two locale strings and one migration, digest unmoved):
- **Why.** A player asked to be reminded when a task is done. Nothing said so: the journal and
  the boards showed it only to someone who thought of opening them. Most completions are not
  events either — 11 of 15 NPC jobs are deliveries that fill from the bag, and most decree
  conditions are state reads (level, estate tier, gear).
- **Now.** `RestNotificationService`'s fourth question: the open decree complete or a taken job
  ready to hand in, not yet announced. It sends one unnamed «📓 Одне з ваших завдань виконано —
  загляньте в нотатник.» (or «Кілька…») per sweep, anywhere, once per task; the owner picked the
  unnamed form. Readiness is each board's own test (`KingService.readyUnannounced` over
  `standing`, `QuestService.readyUnannounced` over the new shared `liveDone`).
- **Storage.** `AddReadyNotifiedFlags`: `quest_progress.ready_notified`,
  `king_progress.ready_notified_index` (a position). Written by one-column query before the push.
- **Measured.** 370 tests; `validate --strict` 0/0; the digest unmoved. The migration was not
  run against a database here; it follows `AddGearCondition`'s shape.

**2026-10-04 — a Vigor reward that will not fit is asked about** (`47e0e8f`, deployed 2026-10-06 21:39;
it needed `pm2 restart ROI` — Swift and nine locale strings, no migration, digest unmoved):
- **Why.** A tester turned a Vigor-only decree in at full Vigor: «✅ Указ виконано» over an empty
  «💰», no word of where the prize went. 20 of 39 decrees pay only Vigor; a partial fit and every
  NPC job lost the rest silently too.
- **Now** (`VigorRewardNotice`, `VigorService.overflow`): the decree card (palace and journal,
  once done) and the NPC board (once ready) warn; the turn-in tap asks first (`king:report_ok`,
  `quest:do_ok:`, «Повернуся пізніше» redraws the card); the banner names what did not fit, and
  the bare «💰» line is gone. With room, nothing changes.
- **Measured.** 370 tests; `validate --strict` 0/0; every new screen rendered in both languages
  for a full, a nearly full and a roomy pool; the longest palace caption with the warning ≈ 520
  of Telegram's 1024.

**2026-10-04 — a tarot card is phrased once, and 💰 marks every reward** (`e861c73`, deployed 2026-10-06 21:39; it needed `pm2 restart ROI` — Swift, locale strings and `fortune.json`, no migration):
- **The reveal** prints the card through `FortuneDisplay` (`effectLine`, `wheelLine`,
  `oneShotParts`), the helper the fortune screen and the profile already called. The 22
  hand-typed `fortune.card.<id>.buff_desc` keys are gone in both locales, with their six
  parenthesised notes (the owner's call); the window is printed once, a one-shot's gift once,
  and the balance on its own line whenever the card deals in silver.
- **Silver** reads «+🪙 30» / «−🪙 15» on every fortune screen (the later screens printed
  «🪙 +30»). The intro no longer says «шість годин»: the price line prints the window from
  `buffDurationSeconds`. «Іерофант» → «Ієрофант».
- **💰 for what the player gets** (the owner's pick): the King's reward line (journal, palace,
  charter), the palace report banner, «💰 Забрати нагороду» and the tarot's «💰 Здобич». 🎁 is
  used nowhere now.
- **Follow-up (`a91226f`).** A one-shot's later line has no lead word: «Карта дня: Вежа ·
  −🪙 25», not «отримано: −🪙 25» (`fortune.effect.received` deleted).
- **Витрата снаги.** «Виснаження снаги» is «Витрата снаги» now. The Chariot went from −25% to
  −50% (`fortune.json`): every base cost is 1–5 and rounded half up, so ×0.75 saved nothing on a
  step or a plain blow — 1 on a flee, a little more inside the warrior's stance. The card's
  multiplier now reaches the techniques, the stance activation and the mage's flee tax through
  `VigorService.drain(_:base:multiplier:)`; they had called `drain(_:amount:)` and the card never
  saw them.
- **Follow-up (`c1c0570`, `a91226f`'s fill).** The Hanged Man gains +15% XP (the owner's number, over the
  offered 25%), so the Chariot's plain −50% no longer dominates its −50% and −10 dodge.
- **Measured.** 370 tests; `validate --strict` 0/0; `records` → `438be135e3090fb5`, content hash
  → `73568a2a`; `tuning`, `spawns`, `quests`, `king` unchanged.

**2026-10-04 — the weapon follows the player level, and its first rung is the Master's lesson**
(`9ab349c`, deployed 2026-10-06 21:39; it needed `pm2 restart ROI` — code, locale strings, content
schema v17 and two data migrations; spec `content/spec/spec-items.md` §9):
- **The rule.** Nine rungs, one every five levels (1 … 40), each with its own
  `requiredPlayerLevel` and 75% of the shipped ladder's growth at that item level; t6–t9 recipes
  are t5's × 1.5/2/2.5/3; durability up to 180. Tier 1 → 2 is the Master's lesson (rung
  materials from the bag + 30 🪙); the workshop sells tier 3 and up and refuses tier 1.
- **Why.** The estate opened tier N at T N, so the item-level-40 sword was in hand at level 13 —
  fights from L7 ran at about half their contract. And the upgrade button lives in the T3
  workshop, so «Гострий край» (L4, weapon T2) held the live chain to L7.
- **Players already playing.** `ClampWeaponTiersToLevel` walks every class weapon back to its
  owner's level and refunds the removed rungs in silver; `ReseatDecreesById` moves the King's
  chain past the four weapon decrees (now at L5/10/15/20) by decree, never skipping one.
- **Measured.** 366 tests; `validate --strict` 0/0; `records` → `1041961908ba2d3f`, `king` →
  `e3a492be1b017e81`, content hash `00b40443`; `tuning`, `spawns`, `quests` unchanged.

**2026-10-03 — the arena duel is a cycle of three** (`f0c1749`, deployed 2026-10-06 21:39; it needed
`pm2 restart ROI` — code, locale strings and content schema v16, no migration):
- **The rule.** Attack beats the class special attack, the technique breaks Defend (it cannot
  miss a defender), Defend turns Attack (65% blocked, 60% riposte). Free and unlimited in the
  arena; two techniques fizzle; the clock's Defend blocks and answers nothing. The arena admits
  only those who have learned the special attack.
- **Why.** With two blind choices no brace made Defend a choice — it measured 0% or 100%.
- **Measured.** Mirror equilibria ~50/36/14 (A/D/T), duels 1.6× longer; warrior vs archer/mage
  still 75–76% (open). 352 tests; `records` → `1b5577693d8733af`, content hash `6963c31b`.

**2026-10-03 — the arena duel plays in simultaneous rounds** (`cad61c3`, deployed 2026-10-06 21:39; it needed
`pm2 restart ROI` for the code and the locale strings — no migration, no schema change):
- **The rule.** Both fighters choose blind; the round is played on the second choice or after
  15 s, with a missing choice played as a forced Defend. A Defend braces against the SAME round's
  attack. Both falling in one round goes to the heavier blow, and equal blows draw. Three missed
  rounds in a row is a technical defeat; both at once calls the duel off with nothing written.
- **Why.** Alternating, the challenger's first blow won 60–66% of mirror duels at every level.
- **The screens.** Every line from the viewer's side («⚔️ Ви: удар — 26 ОЗ»); the result screen
  opens with the round that ended the duel, which it used to receive and never print. Fifteen
  older lines put the nick where Ukrainian needs a case — six in the arena, nine in the bazaar,
  the trade and the guilds — and were rewritten so the nick stays nominative.
- **The code.** `DuelMath` (ROISim) behind `CombatService.resolveDuelRound`; `ArenaStore.choose`
  and `sweep` (1 s) for the clock; `ArenaController.finish` as the one exit; settlement on the
  session-cached `User`.
- **Measured.** 344 tests; `validate --strict` 0/0; `records` alone moved (`259f6cb6ca152450`),
  content hash `7f6a7317`.

**2026-10-03 — creature strength follows the estate tier** (`4be2758`, deployed 2026-10-06 21:39; it needed
`pm2 restart ROI`, because of code, content schema v15 and one migration, `AddFightLogEstateLevel`).
`spec-bestiary.md` §11:
- **The rule.** A spawnable creature fights with HP and ATK × `1 + 0.1·(estate tier − 1)`, which
  is ×1.0 at T1 and ×1.6 at T7. The knob is `tuning/combat.json` → `estateScaling.perTier`. XP,
  loot, DEF, the ratings and the level stay as authored, and the dummy and the dog never scale.
  No screen announces it, on the owner's word.
- **The code.** One formula and one rounding (`CombatMath.scaled(_:forEstateTier:spec:)`), one
  façade (`Enemy.scaled(forEstateTier:)`), and two funnels: `rollEncounter` and
  `ExplorationState.combatEnemy(for:)`, which replaced five bare `EnemyCatalog.find` calls.
  `fight_log.estate_level` records the tier.
- **The checks.** `tuning.combat.estate_scaling_negative`, four `combat model` anchors, a
  `tuning` replay, `simulate`'s «the forest by estate tier» section with the pace priced by tier,
  and `spec gates`' creatures column.
- **Measured.**
  - 336 tests; `validate --strict` 0/0; `simulate --strict` 0 broken bands and 18 warnings;
  - only `tuning` moved (`605fd06bd8abdfda`), and the content hash is `be4350a5`;
  - pace 167.0 / 159.6 / 150.9 days, up from 125.5 / 120.9 / 113.8;
  - the harness rebuilt against the repo reproduced the 10-02 fight table byte for byte, and with
    it 477 days to L40 against 392 unscaled.

**2026-10-02 — tier 2 of the bestiary** (`f03d502`, deployed 2026-10-06 21:39; it needed `pm2 restart ROI` — the
validator is code, five locale strings are new and four oblique-case lines were rewritten; no migration). `spec-bestiary.md` §10:
- **The roster.** Fourteen creatures numbered in order, five of them new: Скажена лисиця,
  Олень-рогач, Вепр-сікач, Тур and Скажена зграя. A creature's number is its level and its
  rung, and its band is km 3N−3…3N+1; the rabid bear is stretched to km 49 as the one exception.
- **XP.** It follows the number alone: every archetype's `xpMultiplier` is 1.0, and the values
  are the `normal` row at two significant figures.
- **The level gap.** The XP penalty is off (`xpLevelDiff.perLevel` 0). The damage shift
  `levelDiff` stays, and the validator rule `enemy.xp_falls_with_depth` replaced
  `tuning.progression.xp_level_diff_absent`.
- **Stat lines.** Tier-1 recipe for №1–4; for №5+, solved against the on-curve kit scaled to the
  obtainable share — the 09-14 method, reconstructed.
- **Measured.** `simulate` shows 0 broken bands and 18 warnings, +6 `roster_off_curve`. Opening
  finding back to `opening.shallow_is_bankrupt`. 324 tests. Real-gear pace to L40: 392 days
  against today's 598.
- **Next.** The estate-tier scaling, decided after implementation: +10% HP/ATK per tier,
  strength only, T6 as is. It was implemented on 2026-10-03 as its own change (above).

**2026-09-28 — the workshop no longer makes armour** (`ada1ae7`, live since the 2026-09-28 22:11 restart; Swift + two locale lines per
language, no content file touched — the digest does not move). The owner's call, over a quiz:
armour comes from the Master alone, at his old prices (60 / 95 / 150 / 180 🪙), and the workshop
keeps the ingot, the weapon and bag upgrades and salvage. The four Forester recipes stay in
`recipes.json` as patterns — `RecipeCategory.isCraftable` is false for the tannery, so no list
shows them, a stale [Craft] in chat gets «Невідомий рецепт.» and `CraftingService.craft`
refuses them — because salvage reads them; deleting them would have left armour worn to 1/1
with no exit again. `EstateTierGates.tannery` and the T4 banner's «🧵 Кравецька» are gone; the
workshop's description and the Master's hint were rewritten. Nothing is taken from anyone: six
players hold Forester pieces (five full sets, one player 15 spares).

**2026-09-27 — the King's chain asks for the estate before the Training Ground** (`1b10572`, live since the 2026-09-28 22:11 restart;
content only in `king.json` plus one validator rule and one data migration; only `king` moved in
the digest). «Наука бою» and «Перший прийом» sat at level 9 while the ground needs player level
10 and estate T4 — and T4 was the decree AFTER them. Now «Зрілість» and «Третя сходинка» come
first and both ground decrees are filed at 10; «Перший прийом» still closes with the same purchase,
on the owner's call. `king.technique_before_its_floor` refuses a ground or technique decree below
its first technique's floor (it fires on the old file, twice). `RewalkReorderedDecrees` sends
anyone standing at 23…25 back to 22 so nobody skips a decree; nobody stood there when it was
written.

**2026-09-27 — the technique rework** (`1b10572`, live since the 2026-09-28 22:11 restart; content schema stays v14, two DB
migrations `CreateFightLog` + `AddCombatTally`, only `tuning` moved in the digest). The owner:
techniques gave too much — a level-26 archer killed the strongest beast with two Vital Shots,
every time — and a stance took Vigor for a tap that struck nothing. Now: raising a stance IS a
strike (the tap swings with the stance up and the enemy answers); every special defence strikes
back (Shadow Veil's knife = the archer's Defend chip, Mirror Ward cannot be missed); no technique
blow exceeds an ordinary crit (Vital Shot ×2.0 → ×1.5, validator
`tuning.combat.effect_crit_above_standard`); the kit is tuned to shorten an elite fight by ~20%
for every class at L21/L40 (warrior −20/−21 · archer −19/−19 · mage −21/−20; the mage was −52%):
bloodlust attack ×1.25, hawks_eye gained attack ×1.15, arcane_resonance ×1.15, burn 0.15. The
stance lines lost their stat breakdown on the owner's word (and with it the false «вдвічі»). And
the game finally keeps a record: `fight_log`, one row per finished forest fight.

**2026-09-27 — the Training Ground is a room of the house** (`1d1fec4`, live since the 2026-09-28 22:11 restart; schema **v14**, two
migrations, `records` / `tuning` / `king` moved). It was a plot type that cost a production
slot and nothing else; now 🏠 Дім lists it from estate T4 and it is built and raised for
silver + materials (`training_ground.json`: 150 / 400 / 800 🪙), each level teaching one
technique at its own player-level floor (10 / 11 / 14 — the first moved from 8 with the T4
gate; `simulate --strict` reads byte-identical either way). The five live ground-plots are
deleted, freeing their slots; techniques already learned stay, the building is bought anew,
and building it catches its level up to what the player knows. «Наука бою» asks to build it
(`build_training_ground`, the 18th condition kind, a live read).

**2026-09-27 — combat lines say what they did, and a death shows the round that caused it**
(`d1e2ccd`, live since the 2026-09-28 22:11 restart; Swift + locale, digest unmoved). The special attacks, the burn tick and the
plain hit end in «%{enemy} втрачає N ОЗ» and name a crit in words — «Влучний у живу плоть!
… валиться на 157 ОЗ» was what EVERY archer special printed, since it always crits. A death
in a fight now shows the last round (it was dropped), «Ворогу лишалося ❤️ N/M» and, on
every death path, the list of what the forest took.

**2026-09-27 — the workshop takes armour apart, and gear lists name rows** (`df6d341`, live since the 2026-09-28 22:11 restart;
Swift + 14 locale keys per language + one tuning knob, `gear.salvageFraction` 0.5 — `tuning`
moved and nothing else did). Armour repaired down to 1/1 had nowhere to go: the trader buys no
gear, the market and the guild vault take stackables only, and one tester carried 15 spare and
dead pieces in a 75-slot bag. «Розібрати» in the workshop returns the recipe × share × max/30
(`SalvageMath`), so a 1/1 piece gives nothing but leaves. The bag's gear list and the
warehouse's gear rows now print each copy's wear and act on the ROW — [Одягнути] used to
put on whichever copy Postgres returned first.

**2026-09-27 — a number typed one tap early gets a hint** (`254967b`, live since the 2026-09-28 22:11 restart; Swift + two locale
keys per language, digest unmoved). A quantity typed before its button — on a trader card
before [🪙 Купити], on the warehouse's «Куди?» before a direction — used to throw the player
to the controller's root screen. Now a bare number with no prompt open gets a `🔢` hint
(`TGControllerBase.answerStrayNumber`, called by Estate / Capital / Guild) and the picker
repeats itself with a `❌` line; words still fall through to the re-render. Reported by the
tester Nerif on 09-11.

**2026-09-21 — the King's decrees are playable** (phase 2a, `520513e`, live since 2026-09-22).
The 👑 Палац is a `Location` inside `CapitalController` on Castle Street, which now has
four keyboard rows. It shows the ONE decree the player carries, every condition resolved
live through `RequirementLine`, what it pays, and a `✅ Доповісти Королю` button that
appears only when it is done. `KingProgress` is one row per player — a decree index and a
counter — created lazily at decree 0, so existing players start at the top and walk the
backlog one decree at a time. `KingService` answers 10 of the 17 condition kinds off live
state and takes the other 7 through `record`, hooked beside the counters that already pass
through combat, the trader, the quest payout, crafting, the expedition start and the
harvest. Locale is complete in both languages — 39 names, 39 descriptions, 17 condition
labels — and the `requireKey` rules landed with the screen that renders them. Phase 2b
landed the same day: `KingCard` is the one renderer all three screens use, 📓 Нотатник carries the open decree above the NPC jobs (read-only — the journal's own standing rule), and `registration.complete` is followed by the royal charter holding the first decree. **The King's chain is feature-complete and LIVE since the 2026-09-22 00:22 deploy** (`1faaddb`).

**2026-09-21 — the King's decree chain, content half** (`978eef7`, live since 2026-09-22). A linear spine of
**39 decrees, levels 1–25**, one open at a time, meant to tell a new player what to aim at:
32 task decrees plus 7 level steps, and the only levels carrying a step are the six that
unlock an estate tier plus the finale at 25. Shipped this session: `content/data/king.json`,
`KingDTO` (tagged-union conditions, 17 kinds, unknown kind FAILS), loader/bundle/snapshot
wiring, **schema v12 → v13**, `ContentValidator.validateKingChain` (17 rules, each with its
failing test), `roi-content spec king`, a fifth digest line `king 4326bb40aa735a50`, 19 tests
(suite 271 → 290) and `content/spec/king.md`. **Nothing is player-visible** — the palace does
not exist as a location at all, and no locale key is authored. Phase 2 (palace, progress
storage, four event hooks, journal, charter message, locale) is listed in `TODO.md`.
The two rules worth carrying: no decree pays more Vigor than the pool at its level holds
(the grant clamps), and a food reward is a NAMED item, never a "portion".

**2026-09-19 — a taken job waits for you** (`328bf88`, **live since the 2026-09-22 00:22 deploy**; Swift + locale keys
+ a data migration, so only `pm2 restart ROI` carries it). A daily job the player has TAKEN no
longer burns at the 12:00 rollover: it stays open until turned in, and that NPC offers nothing
new meanwhile. **One open job per NPC** — `QuestService.accept` refuses behind a carried one,
and every other reader leans on it: the board, `record`, the Turn in button (no day in its
callback) and the trader's "wanted for a job" warning. The owner rejected the first design (both
jobs open at once), which had needed a day in every callback, a burn countdown, an "it burned"
message and a tie-break for two same-counter jobs. A carried job reads like any other, plus
«🔒 Нове замовлення відкриється, щойно здасте це.», and is the only kind that can be dropped —
after a question whose wording differs by objective, because a counter's progress dies with the
job while a delivery's is the bag and stays. `CloseBurnedQuestJobs` closed, once, the 33
taken-but-unfinished rows (6 players) the old rule had left `accepted`, keeping per player and
NPC only the newest from today or yesterday; `QuestCarryOver.burned` holds that rule, with 8
tests including a DST-safe "day before". 271 tests, digest unmoved, no schema change.

**2026-09-19 — the innkeeper's own words, and the recipe became a surprise** (`536fbf6`,
**deployed 2026-09-19 14:21**). The six `.taught` lessons are the owner's copy now, opening with
the player's nickname and written in «ти» — the one exception to the «ви» rule, scoped to those
six lines. Three of them gender the player and are `.m`/`.f` pairs; the render site retries
through the gender overload when the plain lookup echoes the key back, which closes a trap
`LocaleIndex.has` would otherwise wave through (it counts a `.m`/`.f` pair as present). One
shared line, `quest.recipe_learned`, now sits under every lesson and replaced a per-dish tail
that had printed «готувати 🥘 Мʼясна печеня». The board and the journal stopped quoting the
recipe at all — it is the innkeeper's gift at the payout — which removed `Status.recipeUnlock`
and the `learned_recipes` read every board open used to cost.

**2026-09-17 — one sword, two names** (`bf67243`, **deployed 2026-09-19 14:21**). Reported from play with a
screenshot: the bag's button read «⚔️ Очищений меч» and the banner directly under it read
«✅ Іржавий меч — одягнено». The button passes the ROW's tier through
`ItemDisplay.nameKey(for:tier:)`; the equip and unequip banners read the catalog's base name.
Fixed, and the audit found the same shape once more where an id had already lost its tier
upstream: `GearConditionService.drainEquippedGear` returned `[String]`, so a T3 sword breaking
was announced «Іржавий меч» in the fight screen AND in the passive push. It returns
`[BrokenPiece]` (id + tier) now. Everything else that can name a laddered weapon — the gear
list, the detail card, the info toast, the profile, the Master, the workshop — already passed
the tier; the warehouse, market, vault, trade, loot and quest paths cannot hold one at all.

**2026-09-17 — a slot is asked before it is built** (`bf67243`, **deployed 2026-09-19 14:21**). Reported by the
owner as "add a confirmation when choosing what to build on a slot"; the survey found it is
not a nicety — **no code path anywhere deletes a `Plot` row or changes its type or tier**, so
the one tap on a paired picker button was permanent for the life of the account. The picker
now opens the plot's own card — rate, ceiling, both streams, lore, and a line saying it cannot
be rebuilt — with [✅ Будувати] and a Back that returns to the PICKER (the player who lands
here by mistake wants a different type, not a different screen). `estate:plot:type:` asks,
`estate:plot:build:` writes; the question kept the old callback so stale picker buttons in
chat history lead to the question rather than to an irreversible build. Three locale keys,
no migration, no content.

**2026-09-17 — one sentence, one format** (`c36822a`, **deployed 2026-09-19 14:21**; Swift + locale keys, so
`/reload` cannot carry it). The game asks "do you have enough of this?" on ten screens and
answered in four dialects: the recipe in words («2× 🥩 Сире м'ясо — маєте 3», chosen only the
day before), three upgrade screens in a fraction («1× 🪵 Соснова дошка (12/1)»), the shortage
modal in both at once, and two gate lines that called the SAME gate «Рівень маєтку» and «Тир
маєтку» two rows of code apart. `RequirementLine` (`Swift/Helpers/`) is now the single
rendering — marker, the count the recipe asks for, label, fraction in brackets (the count
rides on the item lines only; a gate has none). ⛔ retired in favour of ❌: it meant "a gate" where ❌
meant "a shortage", which no screen explained and the same tap answers. Six locale keys
removed, three plain labels added; a fraction needs no words, which is what let the two gate
labels drift in the first place. **The pre-commit review then found a live bug under it:** the
shortage modal exceeded Telegram's 200-character alert ceiling in five cases (worst 262), and
because every call site answers with `try?`, the tap produced no modal whatsoever — Cook on
the Governor's Feast, Upgrade on any estate step from T4 up. Now capped, with a wordless
`… +N` tail. Only the Ukrainian side ever overflowed; English was under by 20. `EstateController` loses 83 lines; the helper is 91, over half of them the rationale.

**2026-09-17 — a death stopped taking the class weapon** (`c36822a`, **deployed 2026-09-19 14:21** — it needed
`pm2 restart ROI`; Swift only, schema v12 stands, no digest half moved). Reported by the
owner, whose archer had no bow and no `gear.%` row at all; the Pi's 09-08 dump still held it
(`gear.simple_bow`, main_hand, 9/30), so it was destroyed between then and now. A death wiped
every non-equipped row in two places, with no exception for the one item the rest of the code
treats as bound — the warehouse answers `.notTransferable`, a trade filters `isUpgradable`,
the market and the guild vault take stackables only. Since the class weapon is granted once at
registration and no shop, recipe or ladder can produce a second, «❌ Зняти» plus one bad step
was permanent. `InventoryEntry.wipeOnDeath` is now the single implementation of what a death
takes, called by both `ExplorationController.handleDeath` and
`PassiveExpeditionService.applyDeath`. Three sibling fixes were declined and written down
instead (`TODO.md` → "Open, decided but not done"): `InventoryEntry.remove` still ignores `equipped_slot` in both its count
and its delete, which is what makes `/revoke <worn item>` take it off the body.

**2026-09-16 — the arena invite stopped outliving itself** (`b63f835`, **deployed 2026-09-17
00:10**). Reported by a tester with a screenshot. The duel invite was sent with
`_ = try? await bot.sendMessage(...)`, so its message id was discarded and nothing could ever
edit or delete it: an answered, declined or expired invite kept live buttons forever and every
tap replied «недійсний». `PendingChallenge.inviteMessageId` is now filled by
`ArenaStore.attachInvite` and `closeInvite` edits the bubble on all six closing paths, leaving
the outcome where the question was. Second, independent cause of the same report:
`ArenaStore.challenge` deleted both players' lobby entries with no path to restore them, so a
declined challenge made both invisible to every opponent list — removed, since `lobbyMembers`
already filters on `byUser` and the sweeper already ages presence out. Also: decline on a dead
invite returned in silence, `opponentLocale` was a literal `""`, and the capital's Master now
opens «Столична майстерня» so it stops sharing a word and an icon with the estate's room.
**`CapitalController.pushTradeInvite` has the identical discarded-id defect, untouched.**

**2026-09-16 — a Profile key on the trail, and a name on the sale** (`6eefe85`, **deployed
2026-09-17 00:10**). The walk keyboard's second row is `[🎒 Сумка] [👤 Профіль]`, reusing
`Commands.profile`. Adding it exposed that the profile's own buttons — `journal:`, `gear:`,
the `lb:` tabs — were answered by nobody during an expedition: returning false from a callback
handler is silence, because `Router.process` reaches `unmatched` only when
`update.message != nil`. `ExplorationController` now ends with a catch-all forward to
`MainController`, matching `CapitalController`. The market's sold notification names the
buyer; the buy board had shown the seller's nickname all along.

**2026-09-16 — the kitchen could not say no, and could not say what you had** (`5e55139`,
**deployed 2026-09-17 00:10**). Cooking with a full bag hung the button forever and ate the
ingredients: the fit check predicted in ROWS against a cap counted in UNITS, and a stackable
output whose row already existed skipped the capacity test entirely, so the drain ran and
`InventoryEntry.add` threw out of the callback. Now unit arithmetic against the post-drain
state of each store, and **a full bag routes the output to the warehouse** instead of refusing
(`.inventoryFull` → `.noRoom`, reachable only when both are full and only before any drain).
The same row arithmetic also refused crafts that did fit. Second report, not a bug: the recipe
screen printed what a dish requires and never what the player holds, so the shortage modal was
the only way to read your own pantry — both screen and craft now read
`CraftingService.stock`, two queries whatever is asked about.

**2026-09-16 — two ladders retuned, and the button the bag could not answer** (`dc5f037`,
**deployed 2026-09-17 00:10**). Farm 1/h cap 6 → **2/h cap 10** (fills in 5 h like every other
plot; pace 157–173 → **117–129 days**, taps/day 513 → 690, returning about half of the Phase 8E
cut). Bag steps 4 and 5 re-spread from +20/+5 to **+15/+15** — T5 80 → 75, T6 85 → **90** — in
both `capacities[]` (what the bag enforces) and `progression[].capacity` (what the upgrade
screen promises), which the validator cross-checks. And `turnBack` registered in
`InventoryController`: the bag draws its categories on an INLINE keyboard, so the road's reply
keyboard survives underneath while `onInventory` moves `routerName`, and the tap hit a router
with no handler for it.

**2026-09-15 — the Mine runs on one clock** (`78393aa`, **deployed 2026-09-16 00:32**). Iron was 1/hr cap 20 against
pebble's 8/hr cap 40, so the two streams sharing one `lastHarvestedAt` filled in 5 h and
20 h — and the iron cap was unreachable without wasting pebble, since iron accrues flat
whatever the cadence. Now **2/hr cap 10**: both fill in 5 h, iron per cycle doubles, and a
full Mine is exactly one iron ingot. The picker now prints the second stream from
`bonusOutput` (it was invisible — players chose the Mine knowing half of what it makes) and
the ready notification lists both. Copy: `cap` → `estate.plot.capacity_label` («єм» / "cap"),
`plot.type.<type>.gender` in uk with `.m`/`.f` on the notification (Курник read «заповнена»),
and the count rephrased into a list label instead of a bad nominative. The suffix rule is now
`Lingo.localize(_:agreeingWith:)` with `ItemDisplay` wrapping it. Validator:
`locale.plot_gender_missing` / `_invalid`, negative-tested. **And the lore stopped being dead
copy**: all five `plot.type.<t>.desc` blurbs existed in both locales and the validator
required them, but `descriptionKey` was read only for plots that produce nothing — the picker
prints every blurb now, the Mine's mentions iron, and **every claimed slot opens a card**
(name · lore · each stream against its ceiling) with the two destinations on the card itself,
so a harvest is still slot → where. `estate.plot.harvest.where_prompt` / `…button.cancel`
deleted as dead. 248 tests; digest `records` moved and nothing else.

**2026-09-15 — the depth board banks on arrival, and the forest lost its back door**
(`c9ec209`, **deployed 2026-09-16 00:32**). 🌲 Глибина counted kilometres from expeditions
nobody returned from, while
its subtitle promised «і поверталися». Both halves were deliberate — `rollStep` banked the
record the moment a step was paid for, and `User.swift` said "never decreases, not even on
death" — so the user chose which to keep. `deepestKm` is now written only by
`User.bankDepth(_:)` at the manor (`handleHomeReached`, and the passive report's surviving
branch) from `ExplorationState.maxDepthKm`, a new column raised by `moveTo(km:)`, the one
funnel every depth change goes through. `totalKmWalked` still rises per step via
`recordStep()`. The `/start` escape hatch closed on BOTH screens — walk and fight — because
banking at the door makes any free exit the cheapest way to bank a record; both re-render
instead, which is what a lost keyboard actually needed. The board was zeroed once
(`ResetDeepestKm`) on the user's call: the column changed what it measures, so old and new
values cannot share a ladder — `total_km_walked` left standing, which is the test. Two
migrations, ships with the binary. Auto-memory `project-depth-is-banked-on-arrival`.

**2026-09-15 — a bow you took off could not be mended, and a warehouse mended everything**
(`42e8818`, **deployed 2026-09-16 00:32**). A tester reported that the Master offers no repair for an item that is not
worn. Two screenshots a minute apart differ by one button: `editToMasterRepair` listed armour
from every owned row but looked the WEAPON up by its slot, so an unequipped weapon dropped
off the list with nothing said. `MasterService.repair` never had the restriction — only the
screen did. One query over `GearConditionService.durableSlots` now; the title said «Ремонт
броні» while repairing weapons and now says «Ремонт спорядження». Reading the system to
answer that turned up the larger hole: `WarehouseEntry` carried only `item_id` + `quantity`,
and since a deposit deletes the backpack row while a withdraw creates a new one, **a
round-trip was a free full repair that also restored the shaved maximum** — undoing
`repairMaxShave` and the Master's silver sink — while burning the enchant silently.
`GearState` (tier · durability · max · enchant) is now a value both tables carry, with four
new columns via `AddWarehouseGearState` defaulting to what a withdraw was already handing
back. **A migration, so it ships with the binary, not through `/reload`.** Auto-memory
`project-gear-state-travels-with-the-unit`.

**2026-09-15 — the escape has a ceiling** (`b32ac32`, **deployed 2026-09-16 00:32**). A player
pressed Flee seven times, never escaped and died. The roll is flat and per class (warrior 40
/ archer 70 / mage 90) with no level, enemy or depth input, so seven failures is 2.80% for a
warrior — one fight in 36 — against 0.022% for an archer and 0.00001% for a mage. What made
it lethal is that a failed escape is not a free round: 3 Vigor plus a `cannotMiss` counter at
HALF the player's DEF with nothing dealt back, 43–51% more damage than an ordinary counter
for a warrior and 69–77% for an archer, which is 16.3% of the bar per failure against the
level-22 elite at level 10 — death in exactly seven. Fix is a per-fight ceiling rather than a
bigger chance: `combat.json` → `flee.maxFailures` = 4, the attempt after four failures
granted without a roll for every class. Mean barely moves (warrior 2.50 → 2.31 attempts); the
tail is gone. Counter on `ExplorationState.combat_flee_fails`, roll in
`CombatMath.fleeSucceeds`, **content schema v11 → v12** (`flee` became a section) and one
migration, `AddCombatFleeFails`. 242 → 246 tests. Auto-memory `project-flee-has-a-ceiling`.

**2026-09-15 — coins on the ground** (`7469715`, **deployed 2026-09-16 00:32**). A fifth step
event paying 2 / 5 / 10 / 20 silver on the spot. NOT monster silver — a find on a STEP, with
no tie to what was killed, so `feedback-no-monster-silver` still holds. Weights 10 : 4 : 2 : 1
are `1/amount` scaled to integers, so every denomination contributes the same expected
silver; frequency 2 of 100 taken from `loot` in every row including passive. `UkrainianPlural`
moved into `ROIContent` (three noun forms, 11–14 checked first) where the tests can reach it.
Cost: the trail feeds 2% less, so km 1 went −647 → −665 Vigor.

**2026-09-14 — mob XP halved on what the database said** (`6e3c18e`, **deployed 2026-09-14
22:14**). The live rows: an archer at level 24 in 5.94 days, 386,590 XP a day, with 95–100%
of everything earned coming from kills (17 claimed jobs were 2% of the archer's total).
`mobXP.coefficient` 26.0 → 13.0 **and** every `xpReward` rebaked with it — both halves are
required, because the game reads `xpReward` from `enemies.json` and never the coefficient.
**Pace to the cap moved 83 / 79 days → 173 / 167**, which supersedes the 78–87 quoted
further down this file. Quests were untouched and the `quests` digest proves it.

**2026-09-14 — bestiary tier 1, then the whole roster** (`a0f90a8`, **deployed 2026-09-14 22:14**).
🐍 viper and 🦅 eagle added at level 1, the boar moved to level 2, the moose re-statted; the
first XP step fell from ×22.3 to ×3.4 by choosing levels and archetypes, not by touching a
stat. Then the other five were re-solved to 65–78% of their archetype contract, because tier
1 on contract revealed danger had been COLLAPSING with depth — a level-1 eagle was hitting
harder than the level-22 elite. Provisional until the gear ladder lands. The cheapest depth a
level 1–3 player can hold moved km 10 → **km 7**.

**2026-09-10 — the forest was empty on the way home.** The revisit-decay table decayed the
wrong bucket: encounters fell 40 → 20 → 0 while forage held at 45 → 45 → 25, which is
backwards — a beast wanders back onto a walked km, a stripped bush does not regrow. The walk
home is ALWAYS `priorVisits == 1` by construction, so 35% of its steps were empty-or-hurt and
a run of three dead steps ran at 37.9% per return leg. Tier 1 → `8 / 35 / 52 / 5`; the fresh
tier gave up half its roots into forage and kept its encounter weight, which `OpeningLedger`
and the `simulate` pace both read. Three consequences beyond the ask: tier 1 was also the
whole passive expedition (`freshStepCount` = 1), so passive took its own required
`passive.weights` row rather than inherit a rate that would have made unattended play denser
than active play — **schema v10 → v11**, plus a `ContentDigest` line, since an unhashed knob
is unguarded; `BalanceFormatter` stopped hardcoding the fresh tier as "the cheapest way to
find a fight" and reads the densest one, moving the pace landmark **85–93 → 78–87 days**;
and a hand-pasted pace table in `spec-economy.md`, posing as generated, went stale the
moment that pace moved with nothing able to catch it — now dated and labelled a quote.

**2026-09-10 — a full warehouse said the bag was empty.** `📦 Виклати все` refused with
«У сумці немає речей цього типу» over a bag that plainly had them: `depositAll` returned a
bare count, and a zero there means two opposite things — nothing of this category, or
plenty of it and no room. It returns `DepositAllResult` now (moved · cappedOut ·
skippedUntransferable · used · cap), so a refusal names the cap with its numbers, a partial
bulk deposit says what stayed behind, and an unequipped tiered weapon — listed on the screen
but never movable — is named instead of blamed on the bag. Two locale keys per language.

**2026-09-10 — the road can be turned around.** A trip could only be waited out. The nav
keyboard now lends the Explore slot to `↩️ Розвернутись` for as long as a trip is in flight
— Explore is refused mid-trip anyway, and a reply button sidesteps Telegram's
one-markup-per-message rule, which would otherwise force the trip messages to choose between
inline buttons and the keyboard that switches the player out of the capital's. The walk back
costs exactly what was walked (`travelSeconds` minus the time still owed to the current
destination, clamped to one crossing — from `createdAt` until 2026-09-11, which located only
a leg that began at an endpoint), turns are
symmetric, and `TravelService.turnBack` replaces the row rather than editing it so the task
asleep on the old arrival cannot land the player early. Two locale keys, no migration, no
content moved.

**2026-09-10 — resting is a place.** HP regen ran while the player walked to the capital
and while they stood in it: `HealingService` only ever checked for an `ExplorationState`
row, so the manor's bed worked from anywhere in the kingdom. `canRest` now names all three
suspensions (wilderness · road · capital) and the road needs its own check, because
`location` is not flipped until arrival. Away from the estate the clock is cleared rather
than skipped, `TravelService.start` stamps the departure, and the watchman applies the same
rule so it cannot heal — or announce — a player it should leave alone. No content moved.

**2026-09-10 part 3 — the router raced, and the edits were aimed at the wrong field.** Three
live-play symptoms (a fight starting under the walking keyboard, the capital screen with the
estate keyboard, taps producing no message) were four defects, none in game logic. The SDK
gives every update its own `Task.detached`, and `TGDispatcher` chose the router from a
`routerName` read BEFORE the previous tap transitioned — routing now happens inside
`RouterStore`'s per-user chain, on the live value, with a `[ROUTE]` warning that measures the
race. Exploration gained an in-combat guard that re-renders the fight instead of walking
(which re-asserts the combat keyboard), and every refusal notice now carries the keyboard of
the router the player is really on. `TravelService` and `PassiveExpeditionService` took
`SessionCache.peek`, the rule `RestNotificationService` already followed. Then
`Helpers/ScreenEdit.swift`: one photo-aware `editScreen` for all 20 edit call sites, since
**310 of the 807 API refusals in a day and a half of Pi log were `editMessageText` against a
caption**, each swallowed by `try?` — the warehouse list after a withdraw-N had therefore
never refreshed. All four digest halves held.

**2026-09-09 live-play polish** — five screens the first hour walks through, changed while
playing the deployed build and moving no balance number: the expedition bag prints its
occupancy, the fortune screen (and the profile) say what the drawn card actually does and
what a one-shot handed over (`AddFortuneOneShot`), every capital shop shows an item card
before the purchase question (`ItemCard`), and selling an item a taken job needs warns
first. All four digest halves held.

**2026-09-12 part 2 — leaderboards, in the journal.** Four all-time boards reached from
the quest journal: **⚔️ level · 🎖 arena honor · 🌲 deepest km · 🚶 total km walked**, as
tabs that redraw one message. The design was shaped by an audit finding: **the game stored
no cumulative counter at all**, and a depth record could never have been recovered, because
it lived only in `exploration_state.steps_deep` — a row deleted when the expedition ends. So
the two walking boards come with `deepest_km` / `total_km_walked` on `users`
(`AddWalkCounters`, plus four indexes), written in exactly one place —
`User.recordWalk(toKm:)`, from the `rollStep` funnel every kind of step shares, and from
`handleHomeReached` for the last stride. Both start at 0 for everyone: the boards begin
measuring the day they ship. Ranks tie-share on the board's own metric; the secondary sort
only orders the display. One query for the page, plus a COUNT only when the viewer is not
on it. `Leaderboard` in code, «Рейтинги» on screen —
`rating` is taken. All-time is the first period; seasons are a decided direction and must
never be built by zeroing a lifetime column. Not a content-schema bump, and all four digest
hashes held. **Deployed 2026-09-12 19:43**; the migration applied on that start and the
columns + four indexes are confirmed in the database, with no NULLs on the 5 existing rows.

**2026-09-12 — a root that looked twice as strong.** Reported from play: a level-20 archer
at 211 max HP read `перечепилися об корінь ❤️ −22 ОЗ` on the step that killed them. The root
took 11; hunger took the other 11 on the same step, and `rollStep` returned
`.trip(hpLost: tripDmg + starvationLoss)` so the screen printed the sum under the root's own
label. Both are 5% of `effectiveMaxHp` from two different knobs, so a trip while starving is
exactly double. The audit found worse: the tick was applied once and then each branch had to
remember to carry it, and of the ten exits reachable while starving only two did. A `.loot`
that found something and an `.encounterStarted` took the HP and said **nothing at all**; the
passive encounter outcomes moved the report's total but attributed none of it, and a hunger death on
an encounter step printed "the bear broke your guard after 0 rounds" about an animal that
never appeared. `rollStep` now returns a `StepResult` (event + `starvationHpLost`), hunger
gets its own line on the step screen, the death screen and before the combat hand-off, and
its own two totals in the passive report instead of an `outcomeCounts` bucket. Reporting
only — all four digest hashes byte-identical. **Deployed 2026-09-12 19:43.**

**2026-09-09 part 2** — one `Countdown` format for every timer and no hand-written duration
left in the copy; `RestNotificationService` (HP full · fortune ready · 12:00 rollover) as a
60 s watchman, because lazy regen has no observer at the moment it completes; a **3 h/day
ceiling on passive expeditions**; the warehouse cap enforced on plot harvest (the one path
that filled it unchecked) with the developer bypass removed; and **starvation charged double
on three of four step buckets** — 10 HP where the message said 5.

**Phase 10 is CLOSED (2026-09-01)** — the bestiary level re-spread applied and nothing else:
six enemies re-levelled with `xpReward` re-solved from the generator, stats deliberately
untouched, Wild Buffalo renamed to **Wild Bison / Зубр** across `en.json` / `uk.json` /
`lore.md`, and the elite's band kept stretched to km 40 because the plain N…N+9 rule opened a
nine-km hole the validator refused. Density km 1–25: **2.24 → 2.56** per km. Only `records`
and `spawns` moved. **Phase 11 is next — and it carries the whole untested surface.**

**Phase 11's one pre-playtest debt is paid (2026-09-02).** `roi-content simulate` grew an
**opening ledger** (`Modules/ROISim/OpeningLedger.swift`) that prices levels 1–3 at every
depth against the trail — the stretch the pace model has to skip, because it divides by an
estate that does not exist yet. It answers `spec-economy.md` §7 and inverts its prose: the
opening is not bankrupt, the **shallow** opening is. km 1 ends 335 Vigor short, km 4 ends
+44, km 10 ends +73 and is the deepest km still won 95% of the time; past km 11 survival
rather than Vigor is the binding constraint. New warning `opening.shallow_is_bankrupt`;
`--strict` still passes at 0 broken bands and 12 warnings. Tests 222 → 234. *(Every figure
in this paragraph has since moved twice — the roster re-solve and the XP halving. The
warning is now `opening.vigor_bankrupt`, km 1 ends −665, km 4 ends −106 and km 7 is the
deepest holdable. Read them from `roi-content spec opening -c release`, never from here.)*

**Pre-push bug pass (2026-09-07)** — four reported bugs, code and copy only; every
digest half held at the Phase 10 baseline. (1) The profile renders ONE layout — the
`1 · 2 · 3` switcher, the `pstyle:` callback and `User.profileStyle` are gone
(`RemoveProfileStyle`). (2) **HP regen now starts when the player lands home**, and stops
when an expedition begins: `HealingService` gained `beginResting` / `suspendResting`
because its tick only runs on an interaction and both ends of an expedition can happen
without one — the second half also closed a refund, where a passive run the player never
tapped through gave back its whole HP loss on the next tap. (3) The player is addressed
by their chosen `nickname`, never the Telegram name. (4) The level-up is its own message
listing every level-derived stat (`LevelUpBanner`), the estate tier-up likewise
(`EstateUpBanner`, gates centralised in `EstateTierGates`) — and the estate line that
used to ride along with the level-up was deleted, because `estateLeveledUp` could never
be true: the tier only ever moves through the paid upgrade. Locale keys 954 / 966. (5) **The player is addressed as «ви»** — 170 uk strings
converted from «ти», NPC speech included; three latent gender bugs went with it
(keys with no `.m`/`.f` that shipped masculine to everyone), and nine gendered
pairs collapsed into single keys because plural past tense is genderless, leaving
13 pairs that name the player.

**`WipeForRebalance` ran on 2026-09-02 at 22:14:41**, and three accounts played on the
rebalanced build through 04.09 (dumped to `~/RestOfIryna-backups/` before anything else
touches it). Fluent will not re-run it; deleting its `_fluent_migrations` row is what
makes it fire again. Registered last in `configure.swift`; a no-op on a fresh database. Explicit table
list rather than an FK cascade, because `tavern_game_messages` carries no foreign key, and
a self-check against `information_schema` refuses to finish while any table still holds a
row. **`scale` 60 → 1.0 landed 2026-09-09** — game time is real time, and `validate
--strict` is clean for the first time (zero errors, zero warnings). The opening ledger is
unaffected (the opening has no game-time gate); the estate pace — 78–87 days then, 157–173
after the 09-14 XP halving, **117–129 since the farm was doubled on 2026-09-16** — becomes
measurable, which compressed time never allowed.

**Phase 9 is CLOSED (2026-09-01) — all five content specs approved**
(`content/spec/spec-progression.md`, `spec-bestiary.md`, `spec-items.md`, `spec-sets.md`,
`spec-economy.md`). Every number in them is emitted by `roi-content spec`, never
typed, so a spec cannot drift from the generator it feeds. What they decided: the authored
band is levels **1–25**; an enemy of level N spawns from **km N to km N+9**; the three zone
systems are reconciled to **Гущавина 1–10 / Старий ліс 11–25 / Пуща 26–49** (applied);
**no new creatures** — the seven that exist are re-spread (levels only); the boss stays
unmembered; and nothing new unlocks between level 21 and 40, deferred on purpose.

**`spec-items.md` shrank Phase 10 to almost nothing, and the reason is measured.**
No new items are authored in the rebalance, so the spec is a FRAME: the shipped wardrobe
is three weapons that ladder 1→40, four armour pieces frozen at itemLevel 1 forever, and
three empty slots. A fully enchanted kit is **97% of the on-curve budget at level 1 and
40% at level 25** — printed by the two tables added to `roi-content spec items`. Since the
bestiary carries ~60% of its archetype contract, **the two half-strength errors have been
cancelling**, and Phase 10 was scheduled to remove exactly one. So: the weapon ladder
**generalises to a gear ladder** (the Forester set climbs the same rungs — zero new items;
`EquipmentService.nominalStats` already resolves by `itemId + tier` with no slot check),
built **after** the rebalance, and **Phase 10 does NOT regenerate the bestiary's strength**
— an amendment applied to the approved `spec-bestiary.md` §9. The two land together.
Accessories have **no class share profile** in `tuning/budget.json` and cannot be authored
until that is decided.

**`spec-sets.md` then corrected the fix it inherited.** The flat set bonus does **not** rot
today (the set never climbs, so it is a stable 23% — it rots when the ladder lands), and
`gear_multiplier` scales the wearer's **whole kit**, weapon included, so the same ×1.05
costs **8% of the members' budget at L1 and 33% at L40**: a flat bonus decays, a whole-kit
multiplier compounds, and both measure a bonus by a denominator that is not its own.
Decided: a multiplier scales the set's **own equipped members** (inert — no set uses the
case); the 25% cap is extended to multipliers; **set strength is a ladder whose top rung is
that ceiling**, independent of item level; and `set.forester` becomes the **first and
weakest rung** — one four-piece threshold at **×1.07, 29% of the ceiling**. Six-piece
thresholds are unreachable until the empty slots have items. All of it ships with the gear
ladder, after the rebalance.

Phase 8 is closed: the math moved into `ROISim` behind unchanged façades, `roi-content
simulate` measures it, and its findings were acted on (stances multiplicative, warrior
budget re-spent, monster silver removed, the last two flat lifts converted, the archetype
level floor enforced).

⚠️ **The live pass has begun but nothing was walked deliberately.** Four accounts played
2026-09-02 → 09-09 and reached L10 / estate T4, so the rebalanced formulas have been
exercised — but nobody stepped through the first hour against a checklist. Every formula
the player touches changed in Phase 5 and every item's stats in Phase 6; **`/reload` is
still untested against a real database**, and it is now the cheapest way to ship a content
edit. **The bot runs on the Raspberry Pi** under pm2 (app `ROI`, debug build, `pm2 save`
so it survives a reboot); deployment steps are in README's Deployment section, and the
rule about never restarting it without asking is in `CLAUDE.md`. Digest baseline of the working
tree: `records 9303bb274d4517d8` / `tuning 4edf65507bbb5e48` / `spawns 0cf31905171d7944` /
`quests 30de20902006e3b9` / `king e3a492be1b017e81`, content hash `be1102fc` (**schema v19**
since 2026-10-06, when the enchant became the armour's ladder, `bad142b`). The baseline before it
is the durability change's (`bf15669`): `records fefe14b940998631`, content hash
`41455b84`, schema v18. `Prompt.md` keeps both in sync, together with the baseline of every
commit still undeployed — everything since 2026-09-28: tier 2, the estate scaling, the arena,
the weapon ladder, the tarot pass, the 10-04/05 polish and the durability. **None of it is on
the Pi yet.** The Pi still runs `records 33e5c6e3259d51ba` / `tuning fe05ceaa38e03c6b` /
`spawns c9bdb57d456adc26`, content hash `490a2d4b`, schema v14, since the 2026-09-28 22:11
restart. **395 tests**. Pace is **151–167 days** to level 40, re-read 2026-10-05 and unchanged
since the estate scaling priced it in on 2026-10-03; it read 114–126 from 2026-09-18 until then (the 117–129 quoted further down this
file is a dated record of what the farm doubling did, not a current reading). `records` moved on 2026-09-15 for the Mine's iron rate and cap, the first
time that half had moved since the roster re-solve; before 2026-09-14 `tuning` had moved
three times and nothing else had moved at all — the watchman cadence and the passive daily
budget on 09-09, the exploration re-weight on 09-10, each named before the edit.

**Balance is now measurable.** `swift run roi-content simulate` rolls the real
`CombatMath` — the same code the bot calls — over levels × archetypes × classes ×
profiles × gear offsets and reports TTK, tails at p90, pace and the shipped roster
against its own archetype contract. **Level invariance holds on all 18 rows, and no
band is broken.** Phase 8C acted on what it found: every stance lift is a multiplier
of the character's own stat (the warrior's Super was charging double Vigor for a bonus
that had rotted to +5%), the warrior's budget was re-spent toward offence (days-to-cap
spread 17% → 9%), and monster silver was removed entirely. Phase 8D finished the
sweep: the last two flat lifts became multipliers (Shadow Veil dodge ×2.0, the archer's
Defend ×1.5 — both measured at +9 and +5.5 points of dodge chance at EVERY level),
every archetype row gained a required `minLevel` with elite and boss at 14, and the
simulator's default sample size went 2000 → 8000 because `--strict` was failing on
noise. **Phase 8E then removed passive Vigor regeneration entirely** — the trickle did not pause
during an expedition, so it was the reason depth had no gate. Vigor now comes only from food,
quests and levelling; the estate's plots are the income, and `FoodBudget` measures what a
tended one feeds (78–87 days to the cap after the food plots were cut to land there, down from
1,211 to 513 taps a day — then 157–173 after the 09-14 XP halving, and **117–129 at 690
taps/day since the farm went back to 2/h cap 10 on 2026-09-16**, which returned about half of
that original cut). The foraging pools left Swift for `zones.json` at the same time.
**What the report still flags:** the shipped bestiary carries ~60% of what its archetypes ask
(Phase 10's), food portions restore a flat amount against a pool that grows (deferred with
batch cooking to after the rebalance), and levels 1–3 have no estate at all (a feature).

Sections below describe the shipped FEATURE SET. Where they quote numbers (XP curves,
stat growth, enemy stats, enchant bonuses) treat `content/data/` as the truth — several
were superseded by Phases 4–6.

## What Exists (implemented and working)

### Infrastructure
- [x] Swift 6.2 project with all dependencies configured
- [x] Hummingbird HTTP server (health endpoint on :8080)
- [x] PostgreSQL integration via Fluent
- [x] Telegram Bot via long polling (swift-telegram-sdk)
- [x] HummingbirdTGClient (custom TGClientPrtcl using AsyncHTTPClient)
- [x] Environment config (.env via SwiftDotenv)
- [x] Logging (Swift Logging)

### Core Systems
- [x] Router-Controller state machine (full implementation)
- [x] RouterStore actor (thread-safe router dispatch + per-user dispatch serialization via token-keyed Task chain — prevents spam-tap races on cached User / ExplorationState)
- [x] TGDispatcher (auth + global commands + router catch-all)
- [x] Context object (bot, db, lingo, update, session, args)
- [x] Command system (Commands enum, Command class, ContentType matching)
- [x] Arguments parser (Scanner-based: words, ints, doubles, rest-of-string)
- [x] Session caching (actor-based, 5min TTL, auto-cleanup)
- [x] User model + migrations (identity, class, nickname, estate)
- [x] Authorization — **`allowed_users` table + `/link` invites** (2026-09-08). Was a hardcoded array; `AccessControl` caches the table, `InviteToken` carries an encrypted timestamp in a 16-letter `/start` payload good for 5 minutes, and `developerUsers` stays compiled in as the lockout brake. **The open door** (2026-10-07): `ROI_OPEN_ACCESS=1` in `.env` + a restart admits every account that writes (source `open`), for the public test.
- [x] Proper migration awaiting (try await migrator.prepareBatch().get())
- [x] Database connection pool graceful shutdown (defer in configure)

### Controllers
- [x] RegistrationController — lore-driven 8-step flow (steps 0–7): language → **gender (step 1)** → Artanian welcome + name → class selection → King's Oath (grants starter weapon) → wolf encounter stub → estate naming → done. Gender (`set_gender:m|f`) is picked ahead of the name prompt so every later string renders the correct uk feminitive and the estate-reveal art picks the matching gender. "Done" is `User.registrationDoneStep` (= 7), replacing the old magic `6` in CombatController/configure. First message strips any leftover reply keyboard via `ReplyKeyboardRemove`. Nickname + estate-name inputs are validated against three character allow-lists (digits / Latin / Ukrainian) with separate error toasts for too short, too long, edge whitespace, consecutive spaces, and invalid characters; single internal spaces are permitted so two-word names work.
- [x] Gender system (Phase 6.5) — `User.gender` ("m"/"f", nil=male) + `AddGender` migration + `CharacterGender` enum. Drives uk feminitives via the `Lingo.localize(_:gender:locale:)` overload (`.m`/`.f` in uk.json only; English stays neutral) across ~20 keys, and per-gender estate art `CharacterClass.journeyImageName(gender:)` → `Assets/registration/<class>_estate_<m|f>.jpg` (falls back to genderless file). Full rationale in `.memory/localization.md`.
- [x] MainController — greeting (by the player's chosen nickname), profile view (one layout since 2026-09-07), settings nav, Explore/Inventory/Estate/Capital nav buttons. Two sub-screens edit the profile bubble in place: the quest journal (`journal:open`) and the equipment sheet (`gear:open` — six slots head-to-foot then hands, filled or empty, tier-aware names, `+N` enchant, `durability/max` with ⚠️ at zero)
- [x] SettingsController — language change via inline keyboard
- [x] GlobalCommandsController — /help, /settings, /buttons from any state
- [x] ExplorationController — Phase 3.1 active-mode MVP: step → outcome narrative (nothing / loot / trip / encounter / starvation) with depth+HP+vigor status card, in-expedition bag view (scoped to consumables) with one-tap eat/use + in-place refresh, return-home button that ends ExplorationState, death flow that wipes non-equipped inventory and respawns at HP=1 (vigor preserved). Reply keyboard is [🚶 Step] [🎒 Bag] [🔙 Return] while expedition is active. Main/Inventory/Estate onExplore now call showExploration — resumes current ExplorationState (stepsDeep preserved across bag trips) or begins a fresh one at km 0.
- [x] EstateController — stub (coming-soon message + back), reserved for Phase 5
- [x] CapitalController — Phase 6.0 MVP + 6.1 Trader + 6.2 Tavern + 6.3 chat-cleanup + 6.4 Fortune Teller + economy v2 rebase. Travel-gated city hub. **Split across two streets on 2026-09-20 (live since the 2026-09-22 00:22 deploy):** the arrival square offers only `[👑 Замкова][🏘 Поділ]` + utility + 🏡, Замкова carries Базар / Ристалище / Гільдії and Поділ carries Крамар / Майстер / Шинок / Ворожка, so no screen is over four rows and each street has room for two more places. `User.capitalStreet` (+ `AddCapitalStreet`) picks one of three layouts inside a single `generateControllerKB`; `routerName` stays "capital" everywhere in town, which is why nothing else in the controller had to change. Before it: reply-keyboard nav with 6 location buttons + utility row [Inventory] [Profile] + leave row. Arrival sends the welcome photo screen (`Assets/capital/welcome.jpg` + atmospheric lore) with the capital reply-keyboard. **Trader (Phase 6.1)** is fully live: two-step UX (Menu → Buy/Sell list, edit-in-place over the merchant photo), 11 listings, per-tier pricing (1/2/3/5/10/100g sell), 2× sell:buy spread, `[💸 ×1] [✏️ N]` actions per row, custom-quantity prompt routed through `EphemeralChatState.PendingTraderTransfer` + `unmatched` text intercept. **Tavern (Phase 6.2)** also live: button-driven Menu/Dice/Darts; menu sells all 7 cooked dishes (20-200g) bypassing recipe scrolls; gambling uses `bot.sendDice` with text labels ("Ти кидаєш..." / "Шинкар кидає...") for attribution since Telegram doesn't let bots author messages as the user — wager flow is `[💰 stake]` → "Готовий?" confirm + `[🎲 Кинути]` (debit happens here, free cancel before) → bot rolls N dice (2 for 🎲, 1 for 🎯) → sleep → bot's N → sleep → result text with `[🔄 Зіграти ще раз][🔙 До шинка]`. Cross-controller guards still check `TravelState` (countdown banner) and `User.location` (explore-from-capital block, estate-from-capital triggers return trip). UK renames live: Торговець→Крамар, Гадалка→Ворожка, Таверна→Шинок. **Master (Phase 6.5, expanded 2026-05-22)** is fully live — armor shop / armor enchant / armor+weapon repair, the first real silver sink. Entry `[🛡 Buy][⚒️ Repair][✨ Improve]`. Buy sells the Forester set — the only armour source since 2026-09-28 — at 810🪙 a set since 2026-10-05 (485 before; ×5/3 with the durability 30 → 50). Durability lives on `InventoryEntry.durability`/`maxDurability` for armor (each item's own `maxDurability` since 2026-10-05 — the Forester set 50) AND the weapon (per-tier max 30/40/50/70/100/120/140/160/180 via `WeaponUpgradeCatalog.durabilityByTier`); `GearConditionService.drainEquippedGear` spends a per-fight budget (win 1 / loss 3 / flee 2, model C) across the shared armor+weapon pool (`CombatController` + `PassiveExpeditionService`). At 0: armor broken (0 stats), weapon keeps HALF (lore: King's weapon can't break) — both via `EquipmentService.contributedStats`. Repair: armor → max−1 at ≈½ buy price; weapon → full at 1🪙/point, no shave, class-flavoured buttons (Sharpen/Restring/Re-empower). Enchant scales the piece's own stats by +4% a level (Phase 6 replaced the flat +DEF and class stat), cap +5. Idempotent `backfillWeaponDurability` at startup lifts pre-existing weapons to their tier ceiling. All via `MasterService`. Inventory tap on gear opens a full HTML detail card (stats + durability + enchant); gear-row labels show only a plain `+N` enchant. Every buy/repair/enchant tap opens a confirm prompt first (`✅ Yes`/`❌ No`, restating item + cost; `master:*ok:` callbacks execute) to avoid accidental taps; list buttons are terse (buy keeps price, repair shows durability, enchant shows the level step). Capital result banners no longer carry an inline back button (`backToCapitalBannerKB` removed — the reply-keyboard is always visible). 2 stubs left (Market / Arena) reuse `renderLocation` which auto-loads `Assets/capital/<id>.jpg` if present, falls back to text.
- [x] EstateController — tree nav (Phase 5.0 scaffolding): Root (estate name + level + optional per-level artwork) → [🏠 House] drilldown with Workshop/Kitchen/Warehouse stubs / [🌾 Plot] stub; main-nav pass-through; switches between editMessageText and editMessageCaption based on whether the root rendered as text or photo.
- [x] GuildController — Phase 7.1 (Guilds, 2026-06-16). Capital `🏰 Гільдії` reply button → routerName "guild" (controller owns the keyboard, CombatController-style); membership-branched reply keyboard. **Found** (500🪙 silver sink + player-level gate 30 since 2026-10-07 (was 5); **tag left empty — game-creator-assigned via DB**, the name prompt points the player to `@TGUserName`), **invite** (leader/officer → nickname/@username prompt → push; invitee accepts/declines from the guildless-home invites list), **roster** (role-sorted, 👑/🎖/🧑), **kick / promote / demote** (officer cap 2; officers kick members only), **leave / disband** (leader must disband — no transfer yet), **item vault 🏦** (stackables only, deposit any member / withdraw leader+officers, cap 3000), **silver treasury 🪙** (deposit any / withdraw leader+officers, `Guild.treasury`). Models `Guild`/`GuildInvite`/`GuildVaultEntry` + `GuildCatalog` (memberCap 20, maxOfficers 2) + `GuildService` (typed result enums, validate-then-mutate, fire-and-forget pushes); 4 migrations. 82 guild locale keys × 2 (all neutral). Deferred: guild chat, banner-on-estate, non-aggression pacts (need territorial PvP), leadership transfer.
- [x] InventoryController — tree navigation (root → category) via inline buttons; every item is a button with item-info modal showing the lore description on tap. Action acks (eat, equip, unequip) appear as an inline `✅ ...` status line above the refreshed view; warnings (raw food, no_effect, empty category, use_unavailable) appear as Telegram modal alerts via `showAlert: true`. Eat status appends current/max pool indicator ("+15 голоду (20/100)"). No top-strip toasts.
- [x] Daily NPC quests — Phase 9.2 v1 (2026-08-23). Three quest-givers in the capital (Trader / Master / Innkeeper), 5 jobs each, **one job per NPC per game day, taken by hand** — the day decides WHICH job each NPC offers, the player decides whether to take it (2026-09-07). The offer sits on the board until accepted; `record` ticks nothing before that, and taking a job starts the count rather than backfilling the day. Still no list to pick from. **A taken job no longer burns at noon (2026-09-19, `328bf88`, live since the 2026-09-22 00:22 deploy):** it stays open until turned in and that NPC offers nothing new meanwhile — one open job per NPC, enforced by `accept` — so the queue is exactly one deep; a carried job can be dropped after a confirmation, and the one-time `CloseBurnedQuestJobs` closed the rows the old rule left marked as taken. **Bands and a reward curve (2026-09-07):** every job has a `minLevel` (trader 1/1/1/6/8 · master 1/1/1/7/10 · tavern 1/1/1/4/5 — six early forage deliveries were authored so a level-1 board still offers three) and the pool is filtered before the hash, so an unreachable job is never assigned; authored rewards were halved and are scaled at payout — silver +1.5%/level, XP on the `mobXP` exponent, Vigor on the pool. Daily silver runs 85 → 175 across the arc where it was a flat 220. `QuestCatalog.daily(npc:userId:stamp:)` derives the assignment from a stable FNV-1a hash of `userId:npc:GameDay.stamp()` (verified even 1/3 spread; every player cycles all 3 jobs within 30 days), so nothing about *which* job is stored and it survives restarts; `QuestProgress` (+ `CreateQuestProgress`, unique on user+npc+day) stores only progress + claimed, and copies `quest_id` at creation so a mid-day catalog edit can't move the goalposts. Two objective shapes: **deliver** (progress read LIVE from the bag, items consumed at turn-in which also pays out) and **counter** (`QuestService.record(...)` ticked from 5 hook sites — `CombatController.finishVictory`, `PassiveExpeditionService.finalizeAndPush` (batched per run), `CraftingService.craft` (ingot only), `TraderService.sell`, `CapitalController.runRound` (wins only, ties don't count); all `try?` so a quest write can never break a fight/craft/sale). Rewards: silver on every job + per-NPC accent (Trader = bigger silver, Master = +XP, Innkeeper = +Vigor); single `payOut` applies silver/XP/Vigor (Vigor clamped to cap, reports what actually landed) and the banner echoes the combat level-up / estate-up lines. UI: `[📜 Замовлення]` on each NPC menu → board edited in place over the NPC's own message; one action button that only appears when finishable (`✅ Здати` for deliver, `🎁 Забрати` for counter). **Journal («Нотатник»)** hangs off the *profile*, not the capital: a second keyboard row under the 1/2/3 style buttons (`journal:open`) edits the same profile bubble into a read-only digest of all three jobs (state ✅ claimed / 🎁 ready / ⏳ done/target + reward, `🕛` countdown to the 12:00 rollover via `GameDay.secondsUntilNextRollover`), `journal:back` returns. Deliberately claim-free — turn-in stays at the NPC. Reachable from every router that falls through to `MainController.onCallbackQuery` (capital, estate, guild, arena, inventory). 43 locale keys × 2 (neutral except the journal title, which is gendered намісника/-иці via the `.m`/`.f` overload). Deferred: chains, weeklies, guild co-op, fortune/arena quest-givers.

### Character System
- [x] CharacterClass enum (warrior/archer/mage) with icons
- [x] Lore-driven 6-step registration (language → welcome + name → class → King's Oath → wolves → estate naming)
- [x] Character profile display with 3 switchable visual styles
- [x] Profile style preference saved per user
- [x] Dev profile reset flag for testing (resetDevProfile in configure.swift)

### Localization
- [x] English (en.json) — 975 keys (2026-09-07)
- [x] Ukrainian (uk.json) — 987 keys (+13 gendered `.m`/`.f` variants; the player is addressed as «ви» since 2026-09-07, which left gender only on nouns)

### Services
- [x] VigorService — pure functions (drain, consume, effective-stat penalty, starvation HP loss); callers persist. **All costs read `content/data/tuning/vigor.json` since Phase 4.** Now wired into ExplorationService.rollStep (walkRoom drain on every step, combatRound drain inside autobattle, starvation HP tick per room when vigor == 0).
- [x] EquipmentService — atomic equip/unequip with slot swap, recomputes cached gear bonuses on User
- [x] LeaderboardService (2026-09-12) — the four all-time boards behind the quest journal. One query for the page (ranks derive from it locally, since a sorted page starts at the maximum), plus a COUNT only when the viewer is not on that page. Ties share a place; rank is on the board's own metric. `ArenaController`'s «Найкращі бійці» reads it too, so one ladder cannot render two ways.
- [x] WarehouseService — deposit / withdraw one unit between InventoryEntry and WarehouseEntry (skips equipped gear on deposit). **2026-09-15**: tier / durability / max / enchant ride along as `GearState`, so a round-trip no longer hands back a factory-fresh item
- [x] ExplorationService — rollStep, which since 2026-09-12 returns a **`StepResult`** (the event plus `starvationHpLost`) rather than a bare outcome, so the hunger tick can never be folded into an event's number or dropped by a branch; the `.starvationOnly` case is gone. It is also the single place a walked km is counted (`User.recordWalk(toKm:)`). Depth-aware loot pool (now `zones.json`), resolveAutobattle on top of CombatService primitives (alternating strikes via applyAttack, hit/miss/crit math, ±10% variance, safety cap 50 rounds). Phase 4.1 active CombatController will share the same applyAttack so fights resolve with identical odds in either mode. Event weights: nothing 40 / loot 30 / encounter 25 / trip 5.
- [x] **Combat model rebuilt (Phase 5C, 2026-08-30)** — damage is ABSORBED, not subtracted: `ATK × (1 − DEF/(DEF+K(L))) × levelDiff × variance`. Crit/dodge/accuracy are ratings run through curves whose denominators grow with level, so a stat percentage holds steady instead of rotting. Hit band 85 with a floor of 40. Enemies carry real crit/dodge/accuracy (they passed literal 0/0/0 before) and a level, and their stats are generated at design time from a six-row archetype table. `maxLevel` 40, proportional stat growth, power-law XP curve, Vigor pool that grows and regenerates. Numbers live in `content/data/tuning/`.
- [x] CombatService (Phase 4.1) — shared damage primitives used by both active CombatController and passive autobattle. `applyAttack(attackerATK,attackerCrit,attackerAcc,defenderDEF,defenderDodge) -> AttackOutcome (miss / hit / crit)` with clamp(70+acc-dodge, 10, 95)% hit chance, ×1.5 crit on roll vs `attackerCrit %`, ±10% variance. `chipDamage` for Defend's 30%-of-base parry-counter (no crit, always lands). Tuning constants exported (baseHitChance / critMultiplier / defendChipFraction / varianceRange) so both consumers stay in sync.

### Equipment (Phase 2.3 — done)
- [x] 2.3.1 Slot design: `EquipmentSlot` enum (8 slots), `GearStats` struct, Item gains optional slot + gearStats. Starter gear wired: rusty_sword/simple_bow/wooden_staff → mainHand; leather_vest → chest.
- [x] 2.3.2 Data layer: `equipped_slot: String?` on `inventory` + 5 cached `gear_*_bonus: Int` on `users`. Migrations `AddEquipSlotToInventory` + `AddGearBonuses`.
- [x] 2.3.3 `EquipmentService` (equip / unequip / equipped(for:) / recomputeBonuses). Registration auto-equips the class starter weapon after the King's Oath. `User.effectiveAttack/Defense/Crit/Dodge/Accuracy` now read `base + gear − vigor penalty`.
- [x] 2.3.4 Inventory UI toggle: gear rows carry a persistent per-item icon (`Item.icon` — ⚔️ / 🏹 / 🪄 / 🦺 ...) visible whether equipped or not; action button toggles between "🛡 Equip" and "❌ Unequip" (callbacks `inv:equip:<id>` / `inv:unequip:<id>`). Profile gains a "Main hand: <item>" line.

### Estate (Phase 5 — scaffolding, started out of order while Phase 3/4 are paused)
- [x] 5.0 Navigation skeleton: `User.estateLevel` computed from player level (every 5 levels → +1 tier). `EstateController` tree nav with Root → House → room stubs / Plot stub. Per-level artwork loader (`Assets/estate/level_<N>.jpg`, text-only fallback). `MainController.onEstate` now calls `showEstate` instead of the old `showStub`; `InventoryController.onEstate` pass-through updated too. Warehouse room gets a real category browser (separate `WarehouseEntry` Fluent model + `CreateWarehouse` migration), live counts per category, drill-down item list; deposit/withdraw flows still pending.
- [ ] 5.1 30×30 grid + Plot model (real tile-based land management)
- [ ] 5.2 EstateController grid view + plot management + production timers
- [ ] 5.3 Crafting (Recipe model, workshop/kitchen flows, blueprint learning) — will also raise backpack slot cap via upgrade
- [ ] 5.4 Global estate placement + adjacency

### Exploration (Phase 3 — started)
- [x] 3.0 Backpack slot cap — was flat 50 rows; now per-user `InventoryEntry.slotCap(for:User)` reading `BagCatalog.capForTier(user.bagTier)` (T1=25 → T6=90 since the 2026-09-16 re-spread; per-unit since the 2026-05-12 pivot — slots count units, not stack rows). `add` throws `inventoryFull`; `canAccept` preflight; both bypass the cap when `user.isDeveloper`. `WarehouseService.withdraw` returns typed enum so UI can show precise "backpack full" toast. `/grant` catches the error. Inventory root shows `X/Y slots`.
- [x] 3.1 Active exploration MVP — ExplorationState Fluent model (one row per active expedition, `stepsDeep` = current km, unique on user_id, deleted on return/death), EnemyCatalog code-based bestiary (5 animals across 4 tiers: wild boar / moose / buffalo + rabid lynx / wolf, with depth ranges and loot tables), ExplorationService (rollStep + autobattle stub + loot drops + vigor/starvation integration), rewritten ExplorationController with step/bag/return/death flow. Callbacks use `explore:` prefix. Pass-through on main/inventory/estate now resumes or begins an expedition instead of showing the stub.
- [x] 3.2 Return path with per-room visit decay — migration `AddExplorationReturnState` adds a `visited_rooms` TEXT column (JSON dict of km → visit count) and a dormant `returning` column (added in an earlier 3.2 design pass, now unused). `ExplorationService.rollStep` takes `priorVisits:Int` and picks a three-tier weight table via `weights(forPriorVisits:)`; the weights themselves live in `content/data/tuning/exploration.json` and are deliberately not restated here. Tier 2+ zeroes encounter and trip — the anti-farm brake. Expedition reply keyboard is `[🚶 Step fwd] [🔙 Step back]` / `[🎒 Bag]` — direction is implicit in the button. Step Back at km ≥ 2 decrements + rolls with prior visits; at km ≤ 1 it ends the expedition cleanly with no event. Each step increments the entered room's counter, so oscillating between two rooms deplete them fast (tier 2+ = bare). Three `.nothing` narrative variants (fresh / thinned / bare). /start and stray Cancel presses force-end without walking back.
- [x] Passive HP regen at the estate — `tuning/vigor.json` → `healing.regenPerMinute` of maxHp per minute (**10%** since 2026-09-09; 5% originally, 20% briefly) while the player is not on ANY expedition (active or passive) and hp < maxHp. `HealingService.tick(user:inExpedition:on:)` is called from `RouterStore.process` on every interaction (lazy compute, no background scheduler). `RouterStore` queries `ExplorationState.current` once per dispatch to derive `inExpedition`. `User.lastHpTickAt` column via `AddHpRegenTick` migration. Clock is cleared during expeditions and pinned to now at full HP, so banked regen never accumulates against future damage.
- [x] 3.3 Passive expedition MVP (test-mode) — `AddPassiveExpeditionFields` migration adds `mode` / `ends_at` / `report_json` columns; `AddPassiveRunningReport` adds the per-step `running_report_json` snapshot so passive reports stay complete across bot restarts. `PassiveExpeditionService` handles duration picker (30/60/90 units — test mode = seconds, prod = minutes), starts via Task.detached running `runLive` (live per-step loop that sleeps between steps, tracks progress via `state.stepsDeep`, and exits early on death so the report pushes immediately instead of waiting the full timer), persists the `RunningPassiveReport` snapshot (outcome counters + loot totals + HP/vigor-at-start) on every step in the same save as `stepsDeep` and restores it on resume, serializes a final `PassiveReport` JSON on the state row, pushes the completion message to the player's chat, and re-arms itself on bot restart via `rescheduleInflight` (catches up any steps that fell during downtime). ExplorationController entry shows a mode picker [🏃 Розвідка / 🏕 Експедиція] when no state is present; countdown status for inflight; report delivery + state cleanup on re-open. Daily 2h budget and early-cancel still pending. `testMode` constant on the service — flip to prod before shipping.
- [x] 3.4 Mode exclusivity — data-layer exclusivity from unique(user_id) on exploration_state. `showExploration` branches by state — tapping Explore during passive shows a "you're already on expedition, expected return MM:SS" message; during active it resumes the step view. Estate and Capital are both blocked during any expedition (governor is away). Idempotency guards on `explore:mode:*` / `explore:dur:*` callbacks prevent stale picker taps from silently overwriting an existing expedition. (A dynamic busy-label on the main keyboard was briefly tried in an earlier iteration; reverted in favor of the simpler gating-at-entry approach.)
- [x] Lingo integration with SupportedLocale enum
- [x] Interpolation support (%{full-name}, %{nickname}, %{class}, %{estate})

## What's Planned (from GDD, not yet implemented)

### Controllers Needed
- [x] ExplorationController — all of Phase 3 (3.0-3.4) landed. Still pending: dungeons (later phase), content expansion (3.5), flip testMode to prod.
- [x] CombatController — Phase 4.1 + 4.2 + 4.3.1 + 5.1 (Training Mode) landed. Active-mode encounters trigger `StepOutcome.encounterStarted(enemy)`; ExplorationController hands off to CombatController. **Reply-keyboard driven (2026-05-27 switch from inline):** main keyboard `[Attack][Defend] / [🪄 Techniques][Flee]` is a `TGReplyKeyboardMarkup` that replaces the player's keyboard for the fight (the techniques button only from level 8, the earliest unlock gate) and is restored on victory/flee/death; actions match by button text (registered per class × locale, like exploration). `[🪄 Techniques]` sends a fresh sub-keyboard listing only usable techniques (learned + uses left); unlearned/spent are hidden; `× N` shows in the message body (not the label, so text routing matches); `[🔙 Back]` returns. Legacy `callback_query` handler kept only to recover pre-switch inline buttons in chat history. Phase 4.2.1: Super stances (Bloodlust / Hawk's Eye / Arcane Resonance) with stance lifecycle on `combat_stance` + `combat_stance_rounds_left`. Phase 4.2.2: Special Attacks (Cleave / Vital Shot / Soulfire) via per-class `AttackModifiers`. Phase 4.2.3: Special Defenses (Iron Bulwark / Shadow Veil / Mirror Ward) with persistent effects on `combat_enemy_def_debuff` / `combat_player_dodge_buff` ticked via `tickDefenseEffects`. Per-fight budget on `combat_special_atk_uses` / `combat_special_def_uses` / `combat_super_uses`; `beginCombat` initialises 2/2/1, `endCombat` clears every combat-scoped column. Phase 4.3.1: class-specific Flee chances (warrior 40 / archer 70 / mage 90; mage pays +2 vigor teleport tax layered after stance multiplier) via `CombatService.fleeChance(forClass:)` + `fleeVigorExtra(forClass:)`. Stance + special mods + persistent effects all compose into the same `applyAttack` primitive. Vigor drain scales with stance multiplier (Bloodlust ×2). Class-flavoured emoji prefixes prepended in Swift (Lingo's `%{var}` parser breaks on leading UTF-16 surrogate pairs). Basic Attack/Defend unchanged from 4.1. Same controller drives the registration wolves fight at step 4 — `Registration.handleCombatEnd(won:)` on victory / defeat / flee / /start, detected via `session.registrationStep < 6`. Edit-in-place combat UX is moot since the 2026-05-27 reply-keyboard switch (every action re-sends a message with the keyboard — user prefers visible per-round logs anyway). XP-on-victory landed in Phase 5.3a. Per-enemy AI hooks, status effects (rabies), and combat log persistence moved to the new TODO.md `Future / Backlog` section.
- [~] EstateController — Phase 5.0 navigation skeleton landed (Root → House + Plot stubs); still needs 30x30 grid editor, manor rooms' real logic, crafting flows
- [x] CapitalController — Phase 6.0 + 6.1 Trader + 6.2 Tavern + 6.4 Fortune Teller + 6.5 Master + 6.5 Market + 8.3 Arena landed. All six capital locations are now live subsystems (Arena flips routerName to "arena", like the Guildhall). **2026-09-20:** they are reached through two streets rather than one flat keyboard — see the entry above.
- [x] ArenaController — Phase 8.3 "Ристалище" (live герць, 2026-07-20). Capital `⚔️ Ристалище` → routerName "arena"; hub `[⚔️ Виклик][🏆 Честь]/[🔙 Столиця]` vs live-fight `[⚔️ Атака][🛡 Оборона]/[🏳 Здатися]` reply keyboards (fight keyboard stays up the whole duel). Real-time PvP in **simultaneous rounds since 2026-10-03** (both choose blind, 15 s clock, a forced Defend for the silent fighter, three missed rounds in a row a technical defeat, the heavier blow when both fall — see the entry at the top); it alternated before, with a 45 s turn timer, auto-defend and a forfeit after 2 misses, and the challenger's first blow won 60–66% of mirror duels. `ArenaStore` actor (lobby + pending challenges + live duels + byUser busy-index; combat dice rolled inside the actor via `CombatService.resolveDuelRound` → `DuelMath` so roll+HP mutation are atomic). `ArenaService` = match validation (alive/solvent/daily-cap) + Honor ELO + settlement (stake transfer loser→winner minus 10% King's tithe = silver sink, **current**-HP carry-over, non-lethal floored at 1, W-L tally, daily counter). `ArenaProfile` model (honor/wins/losses/daily) + `CreateArenaProfiles` migration + `ArenaCatalog` (stake tiers 25/100/500, K=32, leagues Новак/Боєць/Ветеран/Чемпіон). Background sweeper in configure. 58 arena locale keys × 2 (neutral). **Shipped: lobby-challenge.** Deferred: queue auto-pairing (2nd half of the "both modes" call), ranked/unranked split, seasons + rewards, escrow-on-restart refund.
- [x] Market (Phase 6.5, 2026-05-28) — player-to-player marketplace inside CapitalController. `MarketListing` model + `CreateMarketListings` migration + `MarketCatalog` (listingFee 5 / maxActiveLots 5) + `MarketService` (create/buy/cancel, escrow-at-listing, DB-only). Stackables only. Two-level item-grouped buy board (item → lots cheapest-per-unit first → confirm), two-prompt sell (qty → price + fee), my-lots cancel, seller "sold" push notification. 37 locale keys × 2.
- [x] Trade (Phase 6.5, 2026-06-10) — synchronous player-to-player exchange (MMO trade window) via Market `[🤝 Обмін]`. In-memory only: `TradeStore` actor (lobby presence + `sessions` keyed by UUID + `byUser` busy-index, lobby/session TTL sweeper started in configure) + `TradeService` (tradeableBagItems + atomic `commit`) + `EphemeralChatState.PendingTradeInput` (silver/qty prompts). State machine `trade:*`: lobby (present, non-busy players) → invite → accept/decline cross-user push → both bags (toggle stackables via qty prompt, gear by exact `InventoryEntry` id, `[+ срібло]`) → stage-1 ready (both → `.locked`) → combined-offer → stage-2 confirm → `beginCommit` CAS → swap. **Gear transfers as the exact row (reassign `$user.id`, preserving enchant/durability/tier); bound starter weapon excluded.** Commit = validate-everything-then-mutate (remove stacks → reassign gear → add stacks → swap silver) so a mid-swap capacity throw is impossible. Restart cancels in-flight trades. New files: `Swift/Services/TradeStore.swift`, `Swift/Services/TradeService.swift`. Build clean.
  - **2026-06-15 post-playtest polish:** uk renamed Ринок→**Базар** everywhere (button + copy); fixed the `🪙 Срібло: %{silver}` Lingo interpolation bug (emoji moved to Swift, plain template); dropped the unused `від %U` from the buy-board row. Confirm flow: `mutateBuilding` now resets ONLY the editor's ready-flag (partner's «Погодити» survives your edits → 1 tap each at the selection stage). `finishTradeSuccess` posts a PERMANENT per-side trade record (gave/got + with-whom) at the bottom of chat as history (+2 keys `capital.trade.gave`/`got` → 35 × 2). Bazaar message-visibility policy: transient numeric prompts (listing qty→price, trade silver/qty) are deleted; banners + trade record + menus are kept.
- [ ] GuildController — guild management
- [x] ArenaController — live PvP duel landed (see implemented list above); queue auto-pairing + seasons still pending
- [ ] PetController — taming, pet battles, assignments

### Models Needed
- [x] Character stats (HP, Attack, Defense, Crit, Dodge, Accuracy) — on User model
- [x] Inventory system (items + quantities) — code-based Item catalog + `inventory` table with InventoryEntry; helpers for add/remove/has/list
- [x] Equipment slots (helmet, chest, legs, boots, main-hand, off-hand, accessory ×2) — `EquipmentSlot` enum + `equipped_slot` column + `EquipmentService`
- [ ] Estate model (30x30 grid, manor layout, plots)
- [x] Exploration state — ExplorationState (user_id + stepsDeep + visited_rooms JSON + mode + ends_at + report_json + running_report_json). Single table covers both modes. Per-room event snapshots for richer re-entry narration still deferred.
- [ ] Combat state (opponent, round, actions)
- [ ] Pet model (stats, species, bond, role)
- [ ] Guild model
- [ ] Market listings
- [ ] Quest/achievement tracking

### Game Systems Needed
- [x] Class selection during registration (warrior/archer/mage)
- [ ] Vigor system (drain, starvation, food)
- [ ] XP/leveling system
- [x] Exploration loop — active (3.1) + return path with visited-room decay (3.2) + passive with background scheduler + report (3.3) + mode exclusivity UI/guards (3.4) all landed. Still on deck: flip `PassiveExpeditionService.testMode` to prod, add optional daily budget + early cancel, content expansion (3.5).
- [ ] Combat engine (damage formula, round resolution)
- [ ] Estate management (grid rendering, plot upgrades, production timers)
- [ ] Crafting system (recipes, room tiers)
- [ ] NPC and player market
- [ ] Pet taming and management
- [-] Territorial warfare — **closed 2026-09-15**; it stood on the 30×30 grid removed in May (auto-memory `feedback-territorial-warfare-closed`)
- [ ] Dungeon system (instancing, party invites)
- [ ] Tutorial/onboarding quest

### Content Needed
- [x] Bestiary — 7 animals across 6 tiers in code-based EnemyCatalog. Wild family (🐗 boar km 1-10 / 🫎 moose 6-15 / 🦬 buffalo 11-20 / 🐻 wild_bear 21-30) drops raw meat + hide; rabid family (🐈‍⬛ lynx 11-20 / 🐺 wolf 16-25 / 🐻‍❄️ rabid_bear 25-35) drops hide only. Three deep-zone overlaps stack: rabid_wolf↔wild_bear at 21-25, wild_bear↔rabid_bear at 25-30. Reference doc at `content/bestiary.md`. T5+ currently only has regular mobs; the dedicated boss is reserved for Phase 3.5. Plus two non-exploration mobs (depthRange 0...0, never rolled): 🥋 training_dummy (estate sparring) and 🐕 rabid_dog (one-off registration tutorial fight, wild_boar-level stats, no loot, no XP — replaced the over-tier rabid_wolf in the first fight 2026-05-21).
- [ ] Recipe book (crafting recipes per tier)
- [ ] Class sets — **concept parked 2026-10-05, nothing approved** (`.memory/class-sets-concept.md`): one branch per class L10–40 with an off-hand, Master commissions; it is the gear ladder in class form, so it ships with the bestiary re-solve and `spec-sets.md`'s own-members multiplier
- [ ] Tuning curves (XP per level, vigor scaling, stat curves)
- [ ] Quest definitions
- [ ] Localization for all new game strings

---

*Last updated: 2026-05-28 (Phase 6.5 Market — player-to-player marketplace. New `MarketListing` model + `CreateMarketListings` migration + `MarketCatalog` (flat `listingFee = 5` silver sink + `maxActiveLots = 5`) + `MarketService` (createListing / buyListing / cancelListing, typed result enums, DB-only — no bot I/O). Stackables only (gear excluded via `Item.stackable`). **Escrow at listing**: units leave the seller's bag onto the lot, returned on cancel (fee never refunded). **Two-level item-grouped buy board** (chosen over flat list / categories after review): Level 1 one row per distinct item `<item> · lots: K · from 🪙U` → Level 2 that item's lots sorted cheapest-per-unit first `×N · 🪙total (🪙U/ea) · @nick` → confirm → buy. Buy debits buyer, credits seller, delivers items, deletes lot, pushes the seller a "sold" notification (fire-and-forget, PlotProductionService pattern). Sell = two-prompt flow quantity→price (fee shown in the price prompt) via new `PendingMarketListing` two-stage `EphemeralChatState` + `unmatched` text intercept; my-lots one-tap cancel. `CapitalController.onMarket` now calls `showMarket` (was the `renderLocation` stub); `market:*` callback block + `capital.location.market.body` de-stubbed. 37 locale keys × 2 (all neutral — no gendered words). `Assets/capital/market.jpg` not supplied yet → `sendCachedPhoto` text fallback; drop the art in later and it auto-caches. Build clean, en/uk parity. Prior: 2026-05-22 (Master/gear progression expansion — armor enchant class bonus + cap +5 non-linear curve, premium armor prices + heavier craft recipe with iron, weapon durability by tier [half-stats at 0, 1🪙/point repair, no shave], inventory gear-detail card). Prior 2026-05-21: Master capital location + armor durability as the first silver sink; gender selection + uk feminitives. Full details in `sessions.md`.*

*Headline highlights for this entry:*
- **Photo helper reworked**: `sendScenicPhoto` → `sendCachedPhoto` (`PhotoCache.swift`). Dropped the scenery-slot auto-deletion — location/lore photos now STAY in chat history (players wanted a scrollable record of visits; file_id dedup makes accumulation free). Removed `EphemeralChatState.lastSceneryPhotos`. Registration art (`kings_charter` + per-class journey) converted from direct `bot.sendPhoto(.file)` (re-uploaded every time) to `sendCachedPhoto` (file_id cached).
- **Tavern dice 24h cleanup**: Telegram forbids bots from deleting a **dice** message in a private chat until it's >24h old (anti-cheat), so a round can't be collapsed when it ends. New `TavernGameMessage` model + `CreateTavernGameMessages` migration (`tavern_game_messages`: telegram_id, message_id, created_at; no User FK). `runRound` records every round message; new `TavernCleanupService.startSweeper` (in `configure.swift`, mirrors `PlotProductionService`) runs a catch-up sweep on boot + every 30 min, deleting each message + row once it ages past 24h (`deletableAfter` = 24h + 60s). Dice stay as game history until then.
- Tried in-round / on-replay deletion first — failed silently on dice (text deleted, dice didn't) → confirmed the 24h Telegram rule. Reverted to the persistent 24h-sweep design (survives bot restarts; in-memory tracking didn't).

*Previously (2026-05-18 — Post-Phase-6.4 polish pass — currency rename, trader UX rebuild, plot harvest destination picker, combat round counter, /menu command, env-driven projectPath):*
- **Currency rename gold → silver** across the stack (in-game name `silvers` / `срібники`). New `RenameGoldToSilver` migration does the schema-level column rename via raw SQL; historical `AddGameStats` left intact. `User.silver` Swift field + 8 catalog/service identifier renames + every locale string touched. Side-rule rediscovered: a multi-UTF-16 emoji immediately adjacent to `%{var}` ALSO breaks Lingo (not just leading) — go-forward pattern is pre-built emoji+sign in Swift, kept clean placeholder-only in locale. Captured in `localization.md` with an audit one-liner.
- **Trader UX rebuild**: collapsed 2-row layout into a single button per item that opens the bulk-N prompt directly (info-modal + ×1 callbacks gone, ~50 LoC dead removed). Then added Food/Materials category split inside Buy/Sell to mirror Inventory. New flow: `Trader entry → [💰 Купити][💸 Продати] → category picker [🥩 Їжа][🪨 Матеріали] → filtered item list`. Currency display unified on `🪙 N` prefix (no more `Ns`/`Nс` suffix anywhere). 4 locale keys deleted (`silver_short`, `button.buy_one/sell_one/bulk_n`); 3 added (`cat.food`, `cat.materials`, `button.back_to_categories`).
- **`/menu` discoverable escape hatch**: registered as alias for `/buttons`. Bot startup calls `setMyCommands` twice (en + uk) so `/menu`, `/help`, `/settings` surface in Telegram's hamburger menu. Solves cross-device kb sync (player opens chat on phone with stale estate buttons while their routerName moved to capital).
- **Banner reply-kb anchor**: `postStatusBanner(_:context:replyMarkup:)` overload; all trader/tavern result banners attach a `[🔙 До столиці]` inline kb so the player never gets stuck when the trader/tavern photo bubble has scrolled out of view.
- **pstyle latent bug fix**: `EstateController.onCallbackQuery` + `InventoryController.onCallbackQuery` now forward unknown callbacks to `MainController.onCallbackQuery` instead of returning false. Cleanup of the same pattern already in place on `CapitalController`.
- **Trader tutorial hint** (one-shot): new `User.tutorialTraderHintShown: Bool` field + `AddTutorialTraderHint` migration. Hint fires on the first clean `handleHomeReached` (active expedition Step Back to km 0/1). Death/force-end paths don't trigger.
- **Plot harvest destination picker**: `PlotService.harvest(_:to:for:on:)` gains a `HarvestDestination` enum (`.bag` / `.warehouse`) + new `.bagFull(primary:bonus:free:need:)` atomic-failure case (nothing moves, plot timestamp not reset). `EstateController.handlePlotHarvest` repurposed to a picker (preview `+5 🪨, +1 🔩` + `[🎒 До сумки][📦 На склад][❌ Скасувати]`); new `handlePlotHarvestTo` handlers per destination. 7 new locale keys × 2.
- **Combat round counter**: new `combat_round: Int?` field on `ExplorationState` + `AddCombatRound` migration. `beginCombat` sets to 0; `finishRound` bumps before render so the first action shows `🌀 Раунд 1`; `endCombat` clears. Status card surfaces the line only when `> 0` (encounter intro stays clean).
- **`projectPath` env-driven**: `ProcessInfo.processInfo.environment["ROI_PROJECT_PATH"] ?? "/Users/cosmos/RestOfIryna"`. Pi deploy sets the env in systemd `Environment=` / `.zshenv`; no more merge conflicts on every host.
- **Find-narrative emoji simplification**: all 8 `exploration.find.<itemId>` keys × 2 locales now start with ✨ instead of the per-item emoji (🌲/🪨/🧱/🔩/🫐/🌰/🥔/🥚) — consistent "found something" marker. Item icon still visible in the `+N <icon> <name>` summary line below.
- **Tavern wording**: UK `gamble.button.roll_dice` "🎲 Кинути кубік" → "🎲 Кинути кубики" (player throws 2 dice; singular was wrong).

Previously: 2026-05-17 (Phase 6.4 Fortune Teller — 22 Major Arcana, 6h buff window / 24h cooldown). Third capital subsystem landed. **New `FortuneCatalog`** (22 cards covering 0_fool through 21_world, real tarot art supplied by user) + **`FortuneEffect` struct** (single struct with 14 optional fields covers stat bonuses / multipliers / one-shots / Wheel 50-50 randoms) + **`FortuneService.draw(for:on:)`** (cooldown check via `lastFortuneDrawAt` + 24h gate; gold check + 10g debit; uniform random pick; applies one-shots like gold delta/Wheel/XP/HP-Vigor restore; stamps active card + 6h buff expiry + draw timestamp). **3 new User fields** + 2 migrations (`AddFortuneFields` adds activeFortuneCardId + activeFortuneExpiresAt; `AddFortuneCooldownField` adds lastFortuneDrawAt — split after design call separated 24h cooldown from 6h buff window). **5 effect hooks**: User.effectiveAttack/Defense/Crit/Dodge/Accuracy (additive fortune bonuses), User.grantXP (multiplier), ExplorationService.rollStep (loot weight multiplier with nothing-bucket compensation so total stays at 100), VigorService.drain (composes fortune drain multiplier with stance multiplier). **UI**: `showFortune` renders 3 states (can-draw / cooldown-with-buff / cooldown-only); `[🔙 До столиці]` always present; reveal screen shows card art + name + lore meaning + buff description + one-shot deltas + 6h countdown for duration cards. **Profile fortune line** (`🔮 <Card> · HH:MM`) added to all 3 styles via concatenation pattern. **Effect mix (user request: lean toward trickster)**: 7 pure 24h buffs / 3 pure debuffs / 7 mixed (good+bad combos) / 2 positive one-shots / 2 mixed one-shots / 1 negative one-shot = 41% pure-positive, 18% pure-negative, 41% trade-off. **Capital bugfix**: `CapitalController.onCallbackQuery` now forwards unknown callbacks (pstyle, stale explore/combat) to `MainController.onCallbackQuery` instead of returning false — fixes "Unsupported content type" spam when switching profile style from capital routerName. **Reply-keyboard insurance**: inline `[🔙 До столиці]` button added to tavern/trader/fortune entry screens — Telegram clients sometimes collapse the persistent reply keyboard after long inline chains, and this gives the player a guaranteed nav exit; tapping it triggers `showCapital` → `sendWelcome` which re-attaches the reply keyboard via scenic photo's reply markup. **PhotoCache** now auto-detects MIME from extension (PNG for tarot art, JPG for scenery). **Assets**: 22 tarot card PNGs (`Assets/capital/fortune/<id>.png`) + entry portrait (`Assets/capital/fortune.jpg`) + replaced tavern.jpg. **Lore**: 132 card locale entries (22 × name/meaning/buff_desc × 2 locales) + fortune intro with in-character quote + tavern body innkeeper quote; UK "мандрівнику"→"наміснику" (4 sites), EN "traveller"→"Governor" (4 sites). Locale parity 642/642 (+82 from 561). Build clean. Previously: 2026-05-17 (Phase 6.3 chat-cleanup infra — `PhotoCache` + `sendScenicPhoto` helper). New `Swift/Helpers/PhotoCache.swift` actor caches Telegram's returned `file_id` per asset path so the second-and-later `bot.sendPhoto` for the same JPG references the server-side copy instead of re-uploading bytes. Top-level `sendScenicPhoto(assetPath:caption:parseMode:replyMarkup:toUser:bot:)` helper combines that cache with a scenery-slot cleanup — `EphemeralChatState.lastSceneryPhotos` tracks the user's most recent scenery photo message ID, and the helper deletes it before sending a new one. Result: navigating between capital/estate locations replaces the photo bubble instead of stacking duplicates, and bandwidth drops to ~0 per repeat upload. Five callsites converted: `CapitalController.showTrader` / `showTavern` / `renderLocation` / `sendWelcome` (static, used by `TravelService.pushArrival`) and `EstateController.showEstate`. CLAUDE.md updated with the new convention — `sendScenicPhoto` is the default photo path for any location backdrop; `bot.sendPhoto` direct is reserved for one-shot narrative art (registration King's Oath, future lore beats) that must stay in chat history. Build clean. Previously: 2026-05-17 (Phase 6.1 Trader + 6.2 Tavern + economy v2 rebase — three big iterations in one session). **Trader (Phase 6.1)**: `TraderCatalog` + `TraderService` + two-step UI (Menu → Buy/Sell list, edit-in-place over the merchant photo `Assets/capital/trader.jpg`). 11 listings, all packets = 1 unit post-rebase. Per-row action UI: info-label `[icon name · 🎒N · price]` (description modal via `trader:info:`) + action row `[💸 ×1] [✏️ N]` (sell) or `[💰 ×1] [✏️ N]` (buy). `[✏️ N]` opens a `EphemeralChatState.PendingTraderTransfer` flow (warehouse-style): bot prompt + cancel button + `unmatched` text intercept; invalid input keeps the prompt with error, validation failure deletes prompt + ❌ banner, success deletes + ✅ banner. Sell-All button added then removed (the `[✏️ N]` prompt covers bulk). **Tavern (Phase 6.2)**: `TavernCatalog` + `TavernService` + button-driven gambling. Menu sells all 7 cooked dishes (no scroll gate) at 20-200g. Dice + darts via `bot.sendDice` (Telegram returns 1-6) with text labels ("Ти кидаєш..." / "Шинкар кидає...") between pairs since the Bot API doesn't allow bots to author messages as the player; dice = 2 throws each side, darts = 1; wager debited only at Roll tap; result message carries `[🔄 Зіграти ще раз][🔙 До шинка]` inline buttons. **Economy v2 rebase**: anchored pebble at 1 unit = 1g (was 5 units = 1g), all tiers doubled their per-unit sell price, iron lands at 10× pebble. Final trader prices: Tier 1 (pebble/berries/nuts) 1g/2g · Tier 2 (lumber/clay) 2g/4g · Tier 3 (potato/egg/hide) 3g/6g · Tier 4 (raw_meat) 5g/10g · Tier 5 (iron) 10g/20g · ingot 100g/200g. Flat 2× sell:buy spread. Tavern food rescaled ~5×: 20/30/50/60/80/100/200g. Wager tiers 10/25/50g. **Capital welcome screen** now sent via `TravelService.pushArrival` for arrival in capital (photo + caption + capital reply-keyboard) — single message replaces the previous separate "you've arrived" line. **UK renames** mid-session: Торговець→Крамар, Гадалка→Ворожка, Таверна→Шинок (button + title + every stable banner). EN unchanged. **Inventory-from-capital bugfix**: `CapitalController.onInventory` no longer flips routerName to "inventory" (would have locked the player out of capital nav); `inv:*` callbacks forwarded from CapitalController's onCallbackQuery to InventoryController (same cross-controller pattern Main uses for explore:*/combat:*). Locale parity 561/561 (was 515). **New `TraderService`** (`sellOnePacket` / `buyOnePacket`) — typed result enums (`.success` / `.notEnoughInBag(have:need:)` / `.notEnoughGold(have:need:)` / `.inventoryFull(free:need:)` / `.unknownListing`) drive precise UI banners. Inventory drain via `InventoryEntry.remove`; gold mutated on User + `saveAndCache`. **CapitalController.onTrader** now calls `showTrader` (was `renderLocation(.trader)`). Trader UI: title + atmospheric NPC line + gold balance in body; per-item 2-row inline keyboard layout (info label `[icon name · 🎒 N]` with description modal, action row `[💸 Sell M·Yg][💰 Buy M·Zg]`). Buy/sell taps refresh in-place via `editMessageText`; status banner via `postStatusBanner`. New callback dispatch in `CapitalController.onCallbackQuery` (`trader:info:` / `trader:sell:` / `trader:buy:` prefixes). Stale-message buttons (after player travels back to estate) fall through to MainController's default callback handler which deletes the inline message — no half-applied trades possible. **8 new locale keys × 2 locales** (`capital.trader.intro`, `gold_balance`, `gold_short`, `sold`, `bought`, `not_enough_bag`, `not_enough_gold`, `bag_full`). Parity 523/523. Build clean. **Gold is now a real currency source** — combined with quest rewards (Tavern, when it lands) this closes the gold loop and gives players a reason to dump foraged surplus instead of stockpiling. Previously: 2026-05-16 (Phase 6.0 Capital MVP — travel + nav skeleton). The capital exists as a real second hub now. **New `TravelState` Fluent model** (`travel_state` table, unique per user, `destination` + `ends_at`) carries an in-flight trip; **`TravelService`** owns the background timer (Task.detached + Task.sleep, `rescheduleInflight` on bot start so trips survive restarts) and on arrival flips `User.location` + routerName + pushes a notification. **`User.location`** stored field (`AddUserLocation` migration, default "estate") tracks where the player physically is — flipped only by TravelService, never by a controller. **`testMode = true`** on TravelService (2 seconds per minute), flip to false before shipping. **CapitalController rewritten**: reply-keyboard with 6 location buttons (Market / PvP Arena / Trader / Fortune Teller / Master / Tavern) + Inventory + Profile + 🏡 Back-to-estate; each location button swaps message body (atmospheric stub) without touching the keyboard. `showCapital` branches: expedition→block, travel→countdown, at-estate→start trip, at-capital→render welcome. `beginTrip(destination:context:)` static helper handles trip-start UI uniformly across 3 entry points (Capital from main, Leave from capital, Estate from capital). **Cross-controller guards**: MainController.onEstate / onCapital / onExplore intercept via `guardedByTravel`; EstateController.showEstate adds travel + capital-location branches (Estate-from-capital triggers return trip); ExplorationController.showExploration blocks "explore-from-capital" with notice. **Travel guards**: HP > 0 AND vigor > 0; no cancel mid-trip (decided per user UX). Travel arrival message ships with the correct controller's reply-keyboard. Locale parity 515/515 (+45 keys: capital.welcome, 6× capital.button.*, 6× capital.location.*.title/body, capital.button.leave, 7× travel.*, exploration.blocked_in_capital, etc.). Build clean. Sub-controllers per location and supporting models (NPC inventory, arena matchmaking, fortune-teller blessings, master repair, tavern quests) are the next Phase 6.x patches. Previously: 2026-05-15 (Per-class basic Defend rebalance). Split the basic `[Defend]` button mechanic three ways so the fantasy matches the math. **Warrior** keeps the canonical parry — chip 30% × ATK + `2× DEF` for the round. **Archer** gets chip 15% × ATK (knife flick while melting into shadow) + flat `+30 dodge` for the round, DEF stays single — fantasy is evasion. **Mage** skips chip entirely (the barrier is passive); enemy attack rolls normally through single DEF + dodge, then the landed damage is multiplied by `0.4` (60% off) — stronger mitigation than warrior to compensate for zero return damage. New `CombatService.Defend` namespace holds the three tunables; `chipDamage` gained an `extraMultiplier` parameter (default 1.0). One new locale key per locale (`combat.defend.barrier`) for the chip-less mage line. Also swapped the archer button labels — `combat.button.defend.archer` is now `💨 Quick maneuver` (was `🌑 Hide in shadow`) and `combat.button.flee.archer` is now `🌑 Hide in shadow` (was `💨 Quick maneuver`) so the shadow theme matches escape (not evasion) and stops clashing with the `🌑 Shadow Veil` Special Defense technique. Tested at L1 and L21 — "damage prevented per Defend turn" is roughly equal across classes. Special Defense techniques (Iron Bulwark / Shadow Veil / Mirror Ward) remain the burst per-fight upgrades. Build clean. Previously: 2026-05-15 (Warehouse custom-quantity bidirectional transfer). The single-row `[name] [🎒N ⬆️] [📦M ⬇️]` warehouse layout is replaced by a 2-row card per stackable item: row 1 `[icon name · 🎒N / 📦M]` (info modal on tap), row 2 `[⬆️ +1] [⬇️ +1] [✏️ N]` — the `[✏️ N]` button opens a two-stage chat prompt: first picks direction with `[⬆️ To warehouse] [⬇️ To bag]` inline buttons, then edits in place to the matching quantity question ("How many to deposit?" / "How many to take?" — locale variants per direction). The player types a positive integer and the bot transfers that quantity per direction. New `WarehouseService.withdrawN` (`WithdrawNResult.notEnoughInWarehouse(available:)` / `.inventoryFull(free:)`) handles bag←warehouse; new `WarehouseService.depositN` (`DepositNResult.notEnoughInBag(available:)` / `.warehouseFull(free:)` / `.notTransferable`) handles bag→warehouse — both failure cases carry the limiting number so the warehouse-view banner can read "Not enough. You have N" or "Won't fit — your bag has room for K" without a follow-up query. Pending state lives in `EphemeralChatState.pendingWarehouseTransfer` (itemId + promptMessageId + warehouseMessageId + nullable Direction); `unmatched()` in EstateController peeks it before the showEstate fallback so a typed number routes to `handleWarehouseTransferNText` (only once direction is set — picker-stage text falls through). Cancel button OR successful transfer OR validation failure all clear pending; invalid input (non-numeric / ≤0) edits the prompt in place with "Enter a positive number" and keeps pending so the next message tries again. Gear (non-stackable) rows are untouched — each instance is unique, quantity doesn't apply. 14 new locale keys × 2 locales (7 `withdraw_n.*` for take-side + cancel/shared, 3 `transfer_n.*` for the direction picker, 4 `deposit_n.*` for put-side). Build clean. Previously: 2026-05-12 (Post-5.3 polish — multi-fix sweep + per-unit inventory pivot). The single-row `[name] [🎒N ⬆️] [📦M ⬇️]` warehouse layout is replaced by a 2-row card per stackable item: row 1 `[icon name · 🎒N / 📦M]` (info modal on tap), row 2 `[⬆️ +1] [⬇️ +1] [✏️ N]` — the `[✏️ N]` button opens a chat prompt ("How many do you want to take to your bag?") with an inline `[❌ Cancel]` button; the player types a positive integer and the bot transfers that quantity from storage to bag. Validation is symmetric: `WithdrawNResult.notEnoughInWarehouse(available:)` and `.inventoryFull(free:)` both carry the limiting number so the warehouse-view banner can read "Not enough. You have N" or "Won't fit — your bag has room for K" without a follow-up query. Pending state lives in `EphemeralChatState.pendingWarehouseWithdraws` (itemId + promptMessageId + warehouseMessageId); `unmatched()` in EstateController peeks it before the showEstate fallback so a typed number routes to `handleWarehouseWithdrawNText` and not back to the estate root. Cancel button OR successful transfer OR validation failure all clear pending; invalid input (non-numeric / ≤0) edits the prompt in place with "Enter a positive number" and keeps pending so the next message tries again. Gear (non-stackable) rows are untouched — each instance is unique, quantity doesn't apply. New `WarehouseService.withdrawN(itemId, quantity, for:, on:)` is the bulk companion to the existing single-unit `withdraw`. 7 new locale keys × 2 locales (`estate.warehouse.withdraw_n.*`). Build clean. Previously: 2026-05-12 (Post-5.3 polish — multi-fix sweep + per-unit inventory pivot). Multi-fix sweep before a big commit: (1) Lingo emoji-leading-template audit script (`/tmp/lingo_audit.py`) caught 11 keys × 2 locales where a leading supplementary-plane emoji (🚧, 🏰, 💰, 🔒, 💪, 📖, 📊, 🎉) broke `%{var}` interpolation; emoji moved to Swift call sites at 10 callers across `EstateController` / `CombatController` / `PassiveExpeditionService` / `InventoryController`. (2) Separate callback-HTML audit (`/tmp/callback_html_audit.py`) caught 3 keys (`combat.tech.locked`, `estate.locked.room`, `estate.plot.type_locked`) still carrying `<b>...</b>` while only reaching the user through `answerCallbackQuery(text:)` (plain-text); HTML stripped. (3) Stale combat callback fix: `ExplorationController.onCallbackQuery` now forwards `combat:*` to `CombatController`; `loadCombat` shows a clean `combat.ended` modal alert instead of redirecting to the exploration view (was disorienting because the player may have already walked back / returned home). New locale `combat.ended` × 2. (4) Exploration weight rebalance (two passes): fresh tier `nothing 20→10 / loot 40→50` (encounter & trip unchanged at 30/10); revisit tier `nothing 50→20 / loot 20→50` (matches fresh-tier loot rate now); bare tier `100/0/0/0 → 80/20/0/0` so even a depleted room has a 1-in-5 forage chance. Encounter/trip stay zero at bare — beasts learn to avoid the path. (5) **Per-unit inventory pivot**: dropped the long-running "1 row = 1 slot" convention in favor of "1 unit = 1 slot" — `bread × 50` was 1 slot, now it's 50. `InventoryEntry.slotsUsed` / `WarehouseService.slotsUsed` switched from `count` to `reduce(0){ + quantity }`. `canAccept` / `add` collapsed the stackable/non-stackable branches into a single `used + quantity <= cap` check. `WarehouseService.deposit` dropped the `needsNewRow` shortcut that used to exempt stackable merges from the cap. `depositAll` now partial-fills (10-unit row hitting a 6-unit cap dumps 6, leaves 4 behind) instead of skipping. (6) Bag capacities bumped: `BagCatalog.capacities [20,30,40,55,75] → [25,35,45,60,80,85]`, `maxTier = 5 → 6`. New T5→T6 capstone step: 25 hide + 12 iron_ingot, requires estate T7 (Lord's Holdings). New locale `bag.tier.6.name` ("Grandmaster's Pack" / "Грандмайстерський сак"). (7) Warehouse cap scaled ×4 for per-unit feel: `[50,100,150,200,300,400,500] → [200,400,600,800,1200,1600,2000]`. (8) **Developer bypass**: new `User.isDeveloper` extension — `developerUsers.contains(self.telegramId)`. Plumbed into `InventoryEntry.canAccept`/`.add` and `WarehouseService.deposit`/`.depositAll`. Counts still surface in the UI (overflow `X/Y` where X may exceed Y); inserts are not refused. (9) `EstateController.renderWarehouseRoot` call site at the warehouse drill-down switched from `entries.count` to `entries.reduce(0){ +quantity }` for the `Сховище: X/Y` header. Migration impact: zero — over-cap rows stay readable, the cap only blocks new inserts (same policy as 5.3c warehouse cap rollout). Build clean. Locale parity 470/470. Phase 5.3 series fully landed + polished; next milestone is Phase 6 (Capital — first gold sources via quests).

Previously: 2026-05-11 part 7 (Phase 5.3e — technique gates + Training Ground learn flow). Three class-bound technique slots (Special Atk / Special Def / Super, class-agnostic IDs `special_atk` / `special_def` / `super`) now gate on player level via `LearnedTechnique` Fluent model + `CreateLearnedTechniques` migration. Player-level thresholds: L8 / L11 / L14. `CombatService` gains `TechniqueKind` enum + `requiredLevel(for:)` + `initialUses(for:playerLevel:)` (1/1/1 early, bumps to 2 at L17/L20/L21) + `initialUsesForUser(_)` helper. `ExplorationState.beginCombat` takes per-fight uses as parameters; 3 call sites updated (active encounter, training dummy, registration wolves). Combat submenu Variant 2: unlearned techniques render with `🔒 <name>` (same callback); execution handlers call new `sendLockedToastIfUnlearned` first — modal alert via `combat.tech.locked` pointing the player at the Training Ground. Tapping a Training Ground plot no longer enters the dummy fight directly — it opens a screen with per-kind status (✅ learned / 📖 learnable / 🔒 locked w/ level hint) + `[📖 Learn X]` buttons (only for learnable kinds) + `[🥋 Spar]` + `[🔙 Back]`. Learn writes a `LearnedTechnique` row + refreshes with `✅ Learned X` banner; Spar reuses the existing dummy combat flow. 11 new locale keys × 2 locales (combat.tech.locked + 10 estate.training.*); parity 468/468. **Phase 5.3 series complete** — all sub-phases (a/b/c/d/e) shipped. Carried forward from 5.3d/cleanup (2026-05-11 part 5-6): Starter bag dropped 50 → 20 slots (`User.bagTier` default 1 via new `AddUserBagTier` migration). New `BagCatalog` defines 5 tiers (20/30/40/55/75 slots) with per-step hide + iron materials and estate-tier gates (T2 reqs estate T3, T3 reqs T4, T4 reqs T5, T5 reqs T6). New `BagUpgradeService.upgrade(for:on:)` mirrors `WeaponUpgradeService`: validates max-tier → estate-gate → material snapshot → drain from combined inventory+warehouse pool (inventory first) → bumps `user.bagTier` + saveAndCache. Result enum: success(newTier, newCapacity)/maxTierReached/estateLevelTooLow/missingMaterials. `InventoryEntry.slotCap` converted from `static let 50` to `static func slotCap(for: User) -> Int` reading `BagCatalog.capForTier(user.bagTier)`; all call sites updated (CraftingService, InventoryController.renderRoot, internal canAccept/add). Workshop UI gains second universal button `[🎒 Upgrade bag]` right after the weapon upgrade; detail screen mirrors the weapon flow with capacity delta line ("Tier 3 — Reinforced Backpack · 40 slots (+10)"), estate-tier gate ✅/⛔, materials with have/need, `[🧵 Sew]` confirm. Failures → modal alert; success → in-place refresh + `✅ Bag upgraded to tier N — Name · K slots` banner. Materials only — no gold cost on the bag track (gold gates the estate track). 15 new locale keys × 2 locales (5 tier names + 10 UI keys); parity 457/457. Existing players migrate at bagTier=1 (20 slots) — rows in their bag beyond the new cap stay readable; the limit only blocks new inserts. Carried forward from earlier 5.3c gold polish (2026-05-11 part 4): `EstateUpgradeStep.goldCost: Int` (default 0); T1→T2 + T2→T3 stay free (0g), T3→T4=50g, T4→T5=150g, T5→T6=400g, T6→T7=1000g. Gold drained from `User.gold` directly (NOT an inventory item — never appears in the bag or warehouse). New `UpgradeResult.insufficientGold(required, current)` case; gold gate sits between player-level check and material snapshot so a cash-short player gets a clean "💰 Not enough gold" alert instead of a noisy materials breakdown. UI line `⛔ 💰 50 gold (30/50)` rendered outside the `📜 Materials` block when goldCost > 0; ✅/⛔ marker matches the player-level gate style. Gold source = quest rewards in Phase 6+ (no mob drops); dev grants via Postico. 2 new locale keys per locale (`estate.upgrade.gold_required`, `estate.upgrade.gold_too_low`); parity 442/442. Carried forward from earlier 5.3c (2026-05-11 part 3): House drilldown now filters by `estateLevel`: T1 shows Warehouse only, T2 adds Kitchen, T3+ adds Workshop. Workshop's recipe list hides tannery recipes until T4. Plot picker hides Training Ground type until T3 (defensive modal alert on stale callbacks). `PlotService.slotsForLevel` restored from flat 5 to `[0,1,2,3,4,5,6]` indexed by tier-1 — T1 has zero slots by design (wooden hut hasn't cleared land yet); registration auto-Farm grant dropped, `PlotService.hasAnyPlot` deleted (single caller removed). `WarehouseService` gains capacity table (T1 50 → T7 500), new `slotsUsed(for:on:)` helper, new `.warehouseFull` deposit failure mode that only blocks creating new rows (stackable merges always succeed). `depositAll` tracks running usage so it doesn't blow past cap. Warehouse root UI shows `📦 Storage: X/Y slots`. **Manual estate upgrade pivot:** `User.estateLevel` converted from computed `(level-1)/3+1` to stored `@Field` column (default 1) via `AddEstateLevel` migration — replaces auto-derivation with a real progression sink. New `EstateUpgradeCatalog` defines 6 tier transitions (T1→T2 ... T6→T7), each with `requiredPlayerLevel` (4/7/10/13/16/19) + materials list scaling from ~33 units (T1→T2 onboarding) to ~313 units (T6→T7 endgame). Materials drained from combined inventory + warehouse pool (inventory first, same policy as CraftingService/WeaponUpgradeService). New `EstateUpgradeService` mirrors `WeaponUpgradeService` shape — result enum: success/maxTierReached/playerLevelTooLow/missingMaterials. EstateController gains `[🏠 Upgrade estate]` button on root (hidden at max), detail screen with current+next tier names, player-level gate (✅/⛔ marker), per-input have/need from pool, `[🏗 Upgrade]` confirm. All failures → modal alert; success → in-place refresh + `✅` banner. 7 tier names per locale (Wooden Hut → Lord's Holdings). `XPGrantResult.estateLeveledUp` is now structurally always false (XP grants no longer change estate); inert banner branches in CombatController + PassiveReport kept as forward-compat hooks for future quest-grants-estate-XP. Locale parity 440/440 (+17 keys). Carried forward from earlier 5.3a/b (2026-05-11 part 1+2): `User.statGrowthLevels = {2, 3, 5, 6, 9, 12, 15, 18}` configures which levels grant the boost (8 levels chosen to fall between estate-tier-up levels at 4/7/10/13/16/19, which already feel rewarding from structural unlocks). Each boost: +5 maxHP / +1 ATK / +1 DEF; current HP also bumps by +5 alongside maxHP so the player visibly benefits. `XPGrantResult` extended with `maxHpGained`/`attackGained`/`defenseGained` totals. Total growth L1→L21: +40 maxHP, +8 ATK, +8 DEF. `CombatController.finishVictory` appends `💪 +H maxHP +A ATK +D DEF` suffix to the level-up banner when stats grew. `PassiveReport` extended with same fields (backwards-compat Codable). Passive report's XP line refactored to 3 composable fragments (base XP / level-up segment / stat-boost segment) so each translation lives behind its own locale key; dropped orphan `exploration.passive.report.xp_with_levelup`, added `level_up.stat_boost` (shared) + `exploration.passive.report.levelup` (fragment-only). Locale parity 419/419. maxVigor stays 100 always (no growth — per design). Carried forward from 5.3a (2026-05-11 part 1): Player XP/level system is live: combat victories grant XP via new `Enemy.xpReward` field (T1=5 / T2=12 / T3=25 / T4=50 / T5=100 / T6=175 / training_dummy=0), `User.grantXP(_) -> XPGrantResult` processes level-ups in a loop and reports both `levelsGained` and whether the estate tier crossed a threshold. `User.estateLevel` formula updated to `(level-1)/3+1` (was `/5+1`) — 21 player levels now map to 7 estate tiers. XP curve uses softcap: pure doubling L1→L5 (100/200/400/800/1600), then ×1.4 (~870K total to L21). `User.maxLevel = 21` constant; at cap `xpToNextLevel` returns `Int.max` and progress bar renders "Max". `CombatController.finishVictory` appends `📊 +N XP` / `🎉 Level N!` / `🏰 Estate tier N!` banners (skipped during registration tutorial — wolves stay narrative-only). `PassiveExpeditionService` accumulates XP across the run in `RunningPassiveReport.xpEarned`, grants once at `finalizeAndPush` time, surfaces in the report via `📊 +N XP 🎉 reached Level M!`. Both `RunningPassiveReport` and final `PassiveReport` gained `xpEarned` / `levelsGained` / `newLevel` with backwards-compat custom Codable init for in-flight pre-5.3a rows. Profile (all 3 styles in MainController) gained XP visualization: Style 1 compact `📊 XP 250/400`, Style 2 text bar `📊 ████░░ 250/400`, Style 3 verbose with `🟦` emoji bar. Dead local `MainController.xpForNextLevel(_:)` (was `level * 100`) removed. 6 new locale keys × 2 locales (`profile.xp.max`, `combat.victory.xp`, `level_up.banner`, `estate_up.banner`, `exploration.passive.report.xp`, `exploration.passive.report.xp_with_levelup`); parity 418/418. **No gates yet** — Kitchen/Workshop/Plot still open from L1, plot slots still flat 5, all 9 combat techniques still available from start. Sub-phases 5.3b (stat growth on L2/3/5/6/9/12/15/18) / 5.3c (room+plot-type gates) / 5.3d (smaller starter bag + craftable upgrades) / 5.3e (technique gates + Training Ground learn flow) all queued next. Phase 5.2.2 weapon upgrade also landed (carryforward). Workshop now has a fixed `[⚔️ Upgrade weapon]` button at the top — universal because each player has exactly one upgradable weapon (their class starter, granted by the King at registration). Three weapons × 5 tiers each: Rusty Sword → Cleaned → Sharpened → Reforged → Knight's Sword (warrior); Simple Bow → Trimmed → Sinew-Strung → Composite → Hunter's Longbow (archer); Wooden Staff → Carved Staff → Crystal Staff → Arcane Staff → Archmage's Staff (mage). Stats + materials live in `WeaponUpgradeCatalog` (3×5 = 15 entries); per user request the sword's crit ramps 0/3/6/10/15 across tiers, archer adds accuracy + crit, mage adds crit + accuracy. T1 stats are intentionally identical to legacy `Item.gearStats` so existing equipped weapons see no numeric change after the migration runs — only new upgrades surface new numbers. Tier persisted on `InventoryEntry.tier` (`AddInventoryTier` migration adds `tier INT NOT NULL DEFAULT 1`); item id never changes — the weapon "grows up" in place. Estate-level gates progression (tier N requires `user.estateLevel >= N`); no skip-ahead — sequential. Materials drained from the combined inventory + warehouse pool (mirrors `CraftingService` policy). Tier-aware display names via new `ItemDisplay.nameKey(for:tier:)` helper — applied in profile main-hand line, inventory gear rows, and the upgrade detail screen so an upgraded sword reads "Sharpened Sword" instead of always "Rusty Sword". Tiered weapons cannot be deposited to warehouse (`WarehouseService.deposit` returns new `notTransferable` result; warehouse table doesn't carry a tier column). UI: detail screen renders current tier + stats / next tier preview with deltas (`+3 → +5  (↑+2) ⚔️ Attack`) / materials with have/need indicators / estate-level requirement (green or red); on confirm, `[🔨 Upgrade]` triggers `WeaponUpgradeService.upgrade` which returns a typed result enum (success / maxTierReached / estateLevelTooLow / missingMaterials / noWeaponEquipped) — every failure surfaces as a modal alert. Locale parity: 412/412 (30 weapon name+desc keys + 11 weapon.upgrade.* UI keys + 1 estate.warehouse.not_transferable key per locale). Implementation files: `Swift/Models/WeaponUpgradeCatalog.swift` (new), `Swift/Services/WeaponUpgradeService.swift` (new), `Swift/Migrations/AddInventoryTier.swift` (new), plus model/service/controller updates.

Three-piece polish landing (2026-05-06 earlier): **Per-category Warehouse "Deposit all"** — single `[📦 Deposit all]` button at the bottom of every category screen drains every unequipped row of that `ItemType` to warehouse in one shot via new `WarehouseService.depositAll(category:for:on:)`; equipped gear skipped (same rule as per-item deposit); inline `✅ Moved N items to warehouse ⬆️` banner on success, modal alert on empty bag for that type. Callback `estate:wh:depositall:<type>` matched before the existing `deposit:` / `withdraw:` handler. 3 new locale keys per locale (`estate.warehouse.button.deposit_all` + `.deposit_all.{success,nothing}`). User rejected per-row ×5/×10 batch buttons after the HTML preview showed phone-width clutter — kept the 1-unit-per-tap UX for everything else. **Dev seed: skip recipe scrolls for already-learned recipes** — `configure.swift` now builds a `skipItems` set per developer of seed entries whose `Item.teachesRecipe` recipe already lives in `LearnedRecipe`; both inventory + warehouse top-up loops `continue` past those item ids. Stops the duplicate-scroll-every-relaunch problem. **Hunger → Vigor terminology refactor** — Slavic-flavoured "Снага / Vigor" replaces the inverted "Hunger" meter naming throughout the codebase. `HungerService.swift` → `VigorService.swift` (file renamed, old deleted); `User.hunger`/`maxHunger` → `vigor`/`maxVigor` (DB column kept as `hunger` via `@Field(key: "hunger")` — no migration); `ItemEffect.restoreHunger` → `.restoreVigor`; all combat tunings (`cleaveHunger` etc.) → `*Vigor`. Locale keys renamed (`profile.hunger` → `profile.vigor`, `hunger.restored` → `vigor.restored`, `hunger.starving` → `vigor.starving`, `workshop.effect.hunger` → `workshop.effect.vigor`, `exploration.passive.report.hunger` → `vigor`); interpolation `%{hunger}` → `%{vigor}`; values "Hunger" → "Vigor", "Голод" → "Снага", "голоду" → "снаги". **Negative-state framing kept as narrative**: "😵 Starving" / "😵 Голодний" stays as the low-state indicator; `exploration.outcome.starvation` and `exploration.passive.outcome.starvation` lore unchanged; UK `forest_berries.desc` lore "втамовує голод" untouched. Locale parity: 371/371. All docs (CLAUDE.md, README.md, TODO.md, content/recipes.md, .memory bank) synced; historic session entries kept as-is.

**Superseded on 2026-09-18** — the kitchen now ships **nine** dishes on two rules (Vigor = the
trader buy-price of the recipe's inputs; HP = a quarter of it, learned dishes only), three of
them always-available (baked_potato / roasted_meat / foragers_omelette) and six taught by the
innkeeper's daily job through `recipes.json` → `unlocks`. The five `artifact.recipe.*` scrolls
the entry below describes are DELETED: nothing ever granted one, so those five recipes could
not be learned at all. Details in `content/recipes.md` and the 2026-09-18 session entry.

Previously: 2026-05-02 (Phase 5.2.1 Kitchen cooking complete. **Seven cooked dishes** — Baked Potato 1× 🥔 + 1× 🪵 → +9 vigor; Roasted Meat 1× 🥩 + 1× 🪵 → +12 vigor; Forager's Omelette (3 food + lumber) → +16/+3 HP; Hunter's Stew → +20/+5 HP; Meat Ragout → +18/+4 HP; Forest Berry Tart → +16/+6 HP; Governor's Feast (5 food + lumber) → +35/+10 HP. **Two-tier unlock model:** Baked Potato + Roasted Meat are always-available starters (in `RecipeCatalog.starterRecipeIds: Set<String>`, no DB row, no scroll); the other five are scroll-locked via `artifact.recipe.<dish_id>` artifacts. Tap a scroll in Inventory → Artifacts (`📖 Learn` button surfaces when `Item.teachesRecipe` is set) → `LearnedRecipe.add` writes a row, scroll consumed, `✅ recipe learned` banner. Kitchen UI in EstateController mirrors Workshop's two-screen flow (compact list → detail with description + `📜 Recipe` + `📊 Effects` for 🍖 Vigor / ❤️ HP + `[🍳 Cook]` / `[🔙 Back]`); same `CraftingService.craft` powers it. **Every kitchen recipe burns 1× 🪵 `mat.pine_lumber`** for the cooking fire — authenticity + soft cap on farm-cooking; lumber from Lumberyard plot or shallow-zone foraging. **Banner verb tracks the room** via `RecipeCategory.craftedAlertKey` — Workshop "Crafted ..." / "Викувано ...", Kitchen "Cooked ..." / "Приготовано ...". `RecipeCategory` helpers (`requiresLearning` / `backCallbackData` / `actionButtonKey` / `craftedAlertKey`) let Workshop and Kitchen share the renderer + handlers cleanly. `handleCraftDetail` + `handleCraft` gate kitchen recipe ids: pass-through if in `starterRecipeIds` OR in player's `LearnedRecipe` set. New persistence: `LearnedRecipe` Fluent model + `CreateLearnedRecipes` migration (user_id FK cascade, recipe_id, learned_at; unique on user_id+recipe_id). Dev seed: 5× of every cooking ingredient, 15× pine_lumber, all 5 scroll-locked recipes. Locale parity: 368/368. Phase 5.2 Workshop crafting MVP also landed. `Recipe` + `RecipeCatalog` code-based catalog with two categories — 🔥 Forge (smelting) and 🧵 Tannery (leather armor). `CraftingService.craft(...)` drains inputs from the combined inventory + warehouse pool (inventory first to free backpack slots, warehouse second) and deposits output into the inventory, with a post-drain slot accept-check so a craft never refuses spuriously when a 50/50 bag would have made room. `CraftResult` enum + `Shortage` struct power the UI's modal alerts. EstateController Workshop replaces the stub with a **two-screen flow**: outer list (compact — title + atmospheric description + one inline button per recipe, no in-body category headers) → detail screen on tap (description + `📜 Recipe` inputs + `📊 Stats` for gear outputs + `[🔨 Craft]` / `[🔙 Back]`). Successful craft refreshes the detail in place with a `✅ Crafted ...` banner appended at the **bottom** of the body (placement chosen so the banner stays visible without scrolling). Failures (missingMaterials / inventoryFull) surface as modal alerts and leave the screen unchanged. Five recipes ship: Iron Ingot (10× lump → 1× ingot) + Forester's leather set (Hood 2× / Boots 3× / Breeches 5× / Jerkin 6× hide; full suit = 16 hide → +7 DEF / +1 dodge). Placeholder `gear.leather_vest` (+2 DEF) retired into `gear.forester_jerkin` (+3 DEF) via `RenameLeatherVest` data migration — existing rows in inventory + warehouse remap in place. `WarehouseEntry.remove(...)` helper added to mirror `InventoryEntry.remove`. Dev seed bumped: `mat.hide` 1→16, `mat.iron` added at 10 (one full set + one ingot craftable on next launch). Inventory main-keyboard label and inventory header renamed `Інвентар → Сумка` (en stays "Inventory") to match the term used everywhere else in the bot. Reference doc at `content/recipes.md`. Kitchen cooking (5.2.1) + weapon-upgrade flow (5.2.2) still pending. Phase 5.1 plot system + Training Ground + iron resource overhaul landed (carryforward). Plot model + PlotCatalog + PlotService + PlotProductionService background ticker + EstateController plot drill-down + 5-type picker (Farm / Lumberyard / Mine / Coop / Training Ground). Mine bonus output: `mat.iron` (1/interval, cap 20) alongside `mat.river_pebble` primary. Harvest deposits to Warehouse (not bag). Training Ground spawns `enemy.training_dummy` with consequence-free combat (no vigor drain, no enemy counter, clean cannotMiss + DEF=0 player swings, dummy auto-revives) and routerName stays at "estate" so reply-keyboard nav stays usable; combat callbacks reach the controller via cross-controller `combat:*` forwarding. New `mat.iron_ingot` (Iron Ingot 🔳) placeholder for Phase 5.x Workshop crafting (planned recipe 10 lumps → 1 ingot). Legacy `mat.old_iron` retired and DB rows wiped via `RemoveOldIron` migration. Foraging pool refactored to weighted (`pickWeighted`) so iron sits at weight 2 vs 10 for staples. Initial farm grant at registration completion.)*

## Full rebalance (started 2026-08-29)

Every game number is being rebuilt on one model, and all content + tuning constants are moving
into `content/data/*.json` so balance changes need no recompile. Plan:
`~/.claude/plans/roi-session-primer-eventual-wirth.md`; tracker: TODO.md "Full Rebalance".

- **Phase 0 DONE** — `Modules/ROIContent` (DTOs, loader, validator, `GameData` snapshot,
  `LocaleIndex`), `Modules/ROISim` (SplitMix64 + OutcomeDigest), `Modules/roi-content` CLI,
  `Tests/ROIContentTests` (24 tests). Additive only — no existing behaviour changed, nothing
  reads the new code yet.
- **Phase 1 DONE** — `ContentExporter` + `--export-content`; `content/data/` now holds
  manifest/items/enemies/recipes/weapon_upgrades JSON (33/9/12/3). Round-trip and count/order
  checks pass; two exports byte-identical; `roi-content validate` = 0 errors, 1 truthful warning.
  Still inert — the bot runs off the Swift arrays until Phase 2.
- **Phase 2 DONE** — Item/Enemy/Recipe are façades over `Catalogs.current`; the Swift arrays are
  gone (−397 lines). `ContentBootstrap.load` runs in `configure` before the DB block. Migration
  digest identical before/after (`545017168ce60953`), verified non-vacuous by two negative tests.
  **The bot now runs off `content/data/` for items, enemies and recipes.**
- **Phase 3 DONE (12 of 12 catalogs)** — batch A weapon/bag/estate ladders, batch B
  trader/tavern/market/guild/arena, batch C master/plot/fortune/quest. **No Swift catalog array
  remains anywhere in the tree**; `content/data/` holds 16 files. `ContentExporter` and
  `--export-content` were deleted with the last array — nothing left to export. The migration
  digest gained a third half in batch C (a seeded `daily()` replay) and stands at
  **`8053216102eceff7`**; it held identical across every flip.
- **Phases 4 – 7 DONE** — tuning tables + `time.scale` (4), the new combat model (5), the item
  stat budget with rarity and sets (6), `/reload` guarded by `LiveReferenceCheck` (7). The
  per-phase detail is in the table at the top of this file; the reasoning is in
  `.memory/rebalance.md`.
- Phase 8 done — 8A (math into `ROISim`, digest held), 8B (`roi-content simulate`),
  8C (stances multiplicative, warrior budget re-spent, monster silver removed).
- Phases 9 – 11 pending: content specs, authoring, wipe + the release pass that sets
  `time.scale` to 1.0.

Key targets: maxLevel 40 · ~110 days to cap at 80% engagement · DEF as a mitigation curve
capped at 70% · gear power ceiling 1.75× common · sinks ≈85% of faucets.
