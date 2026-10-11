# Live operations — the public test (since 2026-10-07)

The game went public on 2026-10-07 18:34: the owner posts `https://t.me/ROfIr_bot` and relays
players' questions into the session. This file is what a session needs to answer them and to
read the live game. Rules live in `CLAUDE.md`; the stories in `sessions.md`.

**Figures as of 2026-10-08 21:59:** 13 accounts in through the open door, 2 of them stopped in
registration; 2,469 forest fights since the door opened; 13 deaths among the newcomers; the best
newcomer at level 6; 6 newcomers at estate T2+; 3 accounts at 0 Vigor.

## The door

- `ROI_OPEN_ACCESS=1` is line 20 of the Pi's `.env`; boot logs
  `[ACCESS] OPEN DOOR — every account that writes is added to allowed_users`. Each newcomer logs
  `[ACCESS] admitted <id> (@user) through the open door` and sends the owner (`mitya`) one silent
  line. To close: remove the line and `pm2 restart ROI` — everyone already in keeps their
  `allowed_users` row (source `open`). `/link` works either way.
- Count: `SELECT count(*) FROM allowed_users WHERE source = 'open'`.

## Crediting zlatnyks (the owner, by hand — live since the 2026-10-11 13:21 restart)

The owner works in **DBeaver** (not Postico). After a migration DBeaver's grid can call the new columns «read-only:
No corresponding table column» (10-11, after the 13:21 restart) — most likely its navigator still
holds the table as an earlier session read it. A refresh and a reconnect did not clear it that day;
quit DBeaver (Cmd+Q) and reopen, or use the SQL editor below, which does not need the grid.
1. Open the `users` table and its Data tab, and filter to the player: `nickname = 'Володимир'`.
   Nicknames are not unique, so confirm `telegram_id`.
2. Double-click the `zlatnyks` cell and type the NEW TOTAL, not the amount added. Then Save
   (Ctrl+S), and Commit too if the connection is in manual-commit mode.
3. The profile shows «🟡 N златників» on its next draw. Within a sweep (60 s) the bot writes the
   player «🟡 Вам нараховано 100 златників. Тепер у вас 110.».

What the database and the bot do with an edit:
- A typed minus is refused by the column's CHECK.
- Lowering the number is silent: the marker resyncs, nothing is announced.
- An account still in registration is told once it is through.
- **Never edit `zlatnyks_announced`.** It is the bot's marker of what the player has been told:
  raising it swallows a notice, lowering it repeats one.
- Now that the Chancellery spends them (live 10-11 13:21), ADD rather than overwrite, in the SQL editor:
  `UPDATE users SET zlatnyks = zlatnyks + 100 WHERE telegram_id = …;`. A total typed into the grid
  would undo a spend made while the grid was open.
- **Purchases** are in `zlatnyk_purchases`: who (`telegram_id`, `nickname` as it was), what (`item_id`), the
  price, what it did (`detail`, e.g. `archer → warrior`), the balance left and when. It answers «я
  заплатив, а нічого не отримав». A class change cannot be undone by hand. Credit the zlatnyks back and
  the player changes back in the Chancellery («🟡 Канцелярія»).

## Is the bot alive?

- **The freeze signature:** `getWebhookInfo` → `pending_update_count` rising AND
  `ss -tnp | grep RestOfIryna` showing no `:443` socket, while pm2 says `online`. That is a stuck
  poll loop, not the network. Read the token from the Pi's `.env` inside the ssh command; never
  print it.
- `PollWatchdog` ends such a process after 120 s; each time leaves
  `[WATCHDOG] no getUpdates has completed for Ns` in `~/.pm2/logs/ROI-out.log`. One so far
  (2026-10-08 11:47:53, before the SDK limiter was turned off). **A new one is a freeze the
  limiter fix did not cover — read the minutes before it.**
- `gdb` thread stacks are useless for this (a suspended Swift task holds no thread); the
  2026-10-08 dump showed only idle NIO and dispatch threads.
- `StreamClosed` errors (125 by 2026-10-08) are HTTP/2-era redraw failures; harmless. The one
  stack trace in `ROI-error.log` is an old boot-time DNS failure (`api.telegram.org` did not
  resolve), which is fatal at top level; pm2 brings the bot back.
- Restarts on 2026-10-08: 10:33:56 and 10:36:18 (asked), 11:44:04 (a freeze, the same build — the
  owner had approved freeze restarts with the watchdog), 11:45:37 (`ee7437e`), 11:47:58 (the
  watchdog), 11:55:36 (`94620a4`). pm2's count reads 8.
- Restart on 2026-10-09: 01:30:47 (`de0e062`, the deploy of the 10-08/09 changes, asked). pm2's
  count reads 9. Three minutes later: no `[WATCHDOG]`, `Code: 400` at 913, three sockets to Telegram.
- Restart on 2026-10-11: 13:21:10 (`98580ce`, the deploy of the 10-10/11 changes, asked; four
  migrations). pm2's count reads 10. At 13:24: no new `[WATCHDOG]`, `Code: 400` at 913.

## What are the players doing — the activity snapshot

How to run it: write the SQL to a file in the scratchpad, `scp` it to `/tmp` on the Pi, then
`sudo -n -u postgres psql -p 5433 -d ArtaniaDB -f - < /tmp/file.sql` (the postgres user cannot read
`/home/rpi5`, so feed it on stdin). Read-only; the bot log itself records almost nothing a
player does — only `[ACCESS]`, `[ROUTE]`, `[SCREEN]` and errors.

The questions that paid off on the first evening:
- newcomers: `users WHERE created_at >= timestamptz '2026-10-07 18:34+03'` with nickname, class,
  `registration_step`, `router_name`, `location`, level, HP, Vigor, silver, `estate_level`,
  `deepest_km`, `king_progress.decree_index`, and per-user `fight_log` counts and deaths;
- who is out now: `exploration_state` (mode, `steps_deep`, `combat_enemy_id`, `updated_at`) and
  `travel_state`;
- deaths: `fight_log WHERE outcome = 'death'` with depth, enemy and `hp_start`;
- the starving: `users WHERE hunger = 0`, with their food in `inventory` AND `warehouse`.

**Reading traps, each of which cost a wrong first answer:**
- The session time zone is Europe/Kyiv: `date_trunc('day', now())` is Kyiv midnight. Use
  `timestamptz '2026-10-08 18:00+03'` literals.
- `users.max_hp` is the BASE maximum: the screen's maximum is `max_hp + gear_hp_bonus`, so
  "305/216" is not a bug.
- `users.hunger` is the Vigor column.
- `users.last_hp_tick_at` is NOT "last seen": the watchman writes it every minute for a damaged
  player at the estate. Use `fight_log.created_at` or the `[ROUTE]` lines for activity.
- `fight_log.vigor_spent = 0` means the fight was fought starving. Passive autobattles, training
  and the registration dog write no row; `fight_log` exists since 2026-09-28.
- `registration_step` 5 is the rabid dog, 6 the estate-name prompt (a plain message must answer
  it), 7 is done.
- `exploration_state.returning` is an SQL reserved word — quote it.
- `quest_progress` columns: `npc`, `quest_id`, `day_stamp`, `progress`, `claimed`, `accepted`,
  `ready_notified`.

## The first evening, what it showed (2026-10-07 18:34 → 10-08 00:13)

- **Vigor runs out on day one.** 6 of 10 newcomers sat at 0 Vigor by midnight — the measured
  `opening.shallow_is_bankrupt`, live. Four of them held 30–170 Vigor of food in the WAREHOUSE;
  food is eaten only from the bag, and 0 Vigor also refuses the road to the capital where food is
  sold. A starving step costs 5% of max HP, so two died walking out on 3–5 HP.
- **Level 1–3 players walk to km 3–10 and die there** — 5 of 10 newcomers had died at least once
  by 21:19, 7 of 10 by midnight. The eagle (km 3–7) and the fox (km 9–10) kill players who came
  in healthy; the deaths at km 1–2 were players walking out starving on 3–5 HP. The ready advice:
  stay within 2–3 km until level 3, rest at the estate below half HP, never walk out at 0 Vigor.
- One newcomer stopped at the estate-name prompt (step 6) and never returned.
- Two defects surfaced from questions: the hunger tick on the paying step and the silent full-HP
  notice — both fixed on 2026-10-08 (below).

**Wear and repair (2026-10-10).** Three read-only queries answered «ремонт занадто дорогий».
Wear points per player per day (a win 1, a flee 2, a death 3 — the per-fight budget):

```sql
SELECT f.nickname, (f.created_at AT TIME ZONE 'Europe/Kyiv')::date AS day,
       count(*) FILTER (WHERE f.outcome = 'win')   AS wins,
       count(*) FILTER (WHERE f.outcome = 'flee')  AS flees,
       count(*) FILTER (WHERE f.outcome = 'death') AS deaths,
       count(*) FILTER (WHERE f.outcome = 'win') + 2 * count(*) FILTER (WHERE f.outcome = 'flee')
         + 3 * count(*) FILTER (WHERE f.outcome = 'death') AS wear_points
FROM fight_log f WHERE f.created_at >= now() - interval '4 days'
GROUP BY 1, 2 ORDER BY wear_points DESC LIMIT 20;
```

The worn kit of those players — `max_durability` below the item's start is the shave:

```sql
SELECT u.nickname, u.level, u.silver, i.item_id, i.tier,
       i.durability || '/' || i.max_durability AS dur, i.enchant_level
FROM inventory i JOIN users u ON u.id = i.user_id
WHERE i.equipped_slot IS NOT NULL
  AND (i.item_id LIKE 'gear.forester%' OR i.item_id IN ('gear.rusty_sword','gear.simple_bow','gear.wooden_staff'))
  AND u.id IN (SELECT DISTINCT user_id FROM fight_log WHERE created_at >= now() - interval '4 days')
ORDER BY u.nickname, i.item_id;
```

The share of wins that took no damage — what "wear armour only when hit" would save:

```sql
SELECT nickname, count(*) FILTER (WHERE outcome = 'win') AS wins,
       round(100.0 * count(*) FILTER (WHERE outcome = 'win' AND hp_end >= hp_start)
             / NULLIF(count(*) FILTER (WHERE outcome = 'win'), 0), 0) AS pct_untouched
FROM fight_log WHERE created_at >= now() - interval '4 days'
GROUP BY 1 HAVING count(*) >= 50 ORDER BY 2 DESC;
```

Traps: passive runs wear the kit too and write no `fight_log` row, so these numbers are a FLOOR;
`users.level` is the player's level (there is no `player_level` column on `users`).

## Day two, 22:20 — starving is how the newcomers play

- 5 accounts at 0 Vigor, four of them newcomers who had fought within the last half hour — and
  most of their fights STARVING (`fight_log.vigor_spent = 0`): DIABLO 125 of 184, Легіон 92 of
  130, Inokentiy 112 of 320, Samolan Вишневий 28 of 59.
- Food was at hand: DIABLO carried 15 berries and 3 nuts (75 Vigor) in the BAG, Samolan 5 baked
  potatoes and a berry (54); four of the five held edible food in the warehouse (32–136 Vigor).
  No screen said what «😵 Голодні» costs or where «🍴 Зʼїсти» is.
- The loop they found: walk out starving, fight at −25%, walk home, rest 10 minutes for free.
  Free rest makes Vigor optional for them — a balance question recorded, not acted on.
- Registration: Iren at step 6 (the estate name) since 10-07 18:35, an unnamed account at step 2
  (the nickname) since 10-08 00:27.
- What the owner decided the same evening (live since 2026-10-09 01:30): the hunger
  tick only on a step that BEGINS at 0 Vigor; «Ви повністю відпочили» for every rest that tops
  out, a tap's included; the road no longer refuses 0 Vigor; the forest edge explains hunger (the
  food lines built with it were removed on 10-09, the owner's word). Chosen but not built — the owner left the form unanswered: eating
  straight from the warehouse, and a hint under the estate-name prompt.

## Day four, 15:00 — the repair complaint (2026-10-10)

- Fights are far denser than the model's ≈25 a day: the busiest day of each active newcomer ran
  105–350 fights (Inokentiy 239 wins, 110 flees, 1 death on 10-09); the tester Дарина 1,181 wins on
  10-08. 4,772 forest fights since the door opened (16 deaths), 4,462 wins and 505 flees in the
  last four days.
- At the old price that was 110–840 silver of repair a day against ~78–103 from the jobs.
  Нястюшка (L8, 386 silver) had every piece at 0 with a 436 full repair. The shave showed on worn
  rows: Володимир's breeches 7/29, Дарина's set 28–34/50, Nerif's +5 jerkin 14/36.
- Decided the same evening (`7995d2a`, deployed 10-11 13:21): the armour repair halved; the shave, the cut
  maxima and the Master's screens kept. The analysis: `.memory/rebalance.md` → "The repair,
  measured on live play".
- Still unread there: `estate_level` (do players hold the estate back?) and how many wins are one
  tap.

## Player FAQ — verified answers (2026-10-07/08)

Every answer was read off the code and data, not recalled. Re-check the source after any change.

| Question | Answer | Source |
|---|---|---|
| HP regen at the estate | 10% of the effective max HP per real minute, so 0 → full in 10 min; ONLY at the estate (forest, road, capital: none, and the clock is cleared there); computed on the next tap or the watchman's sweep; partial minutes are kept | `tuning/vigor.json` → `healing.regenPerMinute`, `HealingService.tick` |
| The full-HP notice did not come | Until 2026-10-09 01:30 it fired only when the watchman's sweep made the fill, so a tap of the player's own filled silently. Since then every rest that tops out is announced within a minute while the player is still at the estate (a fill by food is not) | `RestNotificationService.notifyFullHp`, `RestedToFull` |
| Vigor for the road | None — only 2 real minutes; 0 HP refuses setting out, and until 2026-10-09 01:30 so did 0 Vigor (no longer); turning back costs the part walked | `TravelService.start`, `tuning/time.json` → `travelMinutes` |
| «💨 Швидкий маневр» | The archer's Defend: dodge ×1.5 for that round (DEF unchanged) and a knife for 15% of a clean hit (`defendChipFraction` 0.3 × `archerChipMultiplier` 0.5); 1 Vigor against an attack's 2. Warrior «🛡 Парирувати»: DEF ×2 + 30%; mage «🌀 Магічний бар'єр»: no chip, landed damage ×0.4 | `CombatController` defend branch, `tuning/combat.json` → `defend` |
| A broken weapon | Keeps 50% of its stats (floored; a Swift literal, not tuning); broken armour gives 0. Wear per fight: win −1, flee −2, death −3 | `EquipmentService.contributedStats`, `tuning/economy.json` → `gear.wearBudget` |
| Repair prices | **Halved 2026-10-10, live after the restart that ships it** (`repairCostFraction` 0.5 → 0.25): armour price × 0.25 × missing ÷ 50, min 1 — hood 0.5/pt (25 full), boots 0.8 (40), breeches 1.25 (63), jerkin 1.5 (75), set 203. Before: × 0.5 — hood 1/pt (50), boots 1.6 (80), breeches 2.5 (125), jerkin 3 (150), set 405. Each armour repair still shaves the max by 1; the enchant does not change the price. Weapon: 1 🪙 a point, no shave (30 … 180 by tier). A fight's wear is ONE budget for the whole kit, not per piece — win 1, flee 2, death 3 points, each on a random worn piece. Ready reply: «Після найближчого оновлення ремонт броні подешевшає вдвічі: жилет — 1,5 срібника за очко замість 3, повний ремонт комплекту — 203 замість 405. Порада: кожен ремонт броні зрізає 1 з максимуму, скільки б він не лагодив, тож лагодьте, коли річ уже добре зношена, а не після кожного походу.» | `MasterCatalog.repairCost`, `weaponRepairCost`, `master.json` → `repairCostFraction`, `GearConditionService.drainEquippedGear` |
| When the kitchen opens | Estate T2, which needs player level 4 + 20 Сосновий брус, 10 Річкова галька, 3 Шкура, no silver. Known at once: roasted meat (+14), baked potato (+10), forager's omelette (+10); six more from the innkeeper's jobs, gated on the estate tier | `EstateTierGates.kitchen`, `estate_upgrades.json`, `recipes.json` → `unlocks` |
| Raw food | Berries +4, nuts +5, duck egg +3, from the bag only; raw meat and potato are not edible raw | `items.json` effects |
| Where iron drops | Forage from km 11 (Старий ліс: 2 of 72 find weight, ≈1.3% of a fresh step), more from km 26 (2 of 32, ≈3%); never at km 1–10; no creature drops it; the Mine plot (from T2) yields 2 an hour up to 10; the trader sells at 20 🪙, buys at 10 | `zones.json`, `plots.json`, `trader.json`, `tuning/exploration.json` → `weightTiers` |
| A 40-unit lot and a 20-slot bag | Not buyable: a lot is bought whole, into the bag only (no warehouse in the capital); starter bag 25, workshop upgrades to 35/45/60/75/90; pulling a lot back needs the room too. Advice: list in lots of 10–20 | `MarketService.buyListing` |
| The developer's bag | Unlimited for `developerUsers` (Космос, 398698463) on every path into the bag; the warehouse is not exempt. So "bag full" cannot be reproduced on that account | `InventoryEntry.canAccept` / `add` |
| Guilds | Founded from level 30 for 500 🪙 since 2026-10-07; joining by invite at any level | `guild.json` |
| When the next tarot card comes | At the later of the drawn card's 6 hours and the next 12:00 Kyiv: drawn at 22:00 → 12:00; at 11:00 → 17:00, then the following noon. So once a game day, never two cards at once. Since 2026-10-09 01:30; a flat 24 h before | `User.fortuneAvailableAt` |
| Cancelling a tarot card *(after the restart that ships it — built 2026-10-10)* | «🕯 Відчарувати» on the fortune screen ends a running DURATION card for 30 🪙, after a question; the free card still comes at its own time. Only then «🔮 Друга карта» for 20 🪙, once, and it cannot be dispelled. A one-shot (Закохані, Колесо, Вежа, Суд, Світ) cannot be dispelled and opens no second card; nor does a card that ran out by itself. Ready reply: «У ворожки тепер можна відчарувати карту за 30 срібників — дія закінчиться одразу. Після цього можна витягнути другу карту за 20, але її вже не можна буде відчарувати. Разові карти відчарувати не можна.» | `FortuneStage`, `FortuneService.dispel` / `drawSecond`, `fortune.json` |
| Hunger | 5% of max HP per step that begins at 0 Vigor, ATK and DEF −25%. Until 2026-10-09 01:30 the step that spent the last Vigor was charged too (the defect, fixed). The forest edge now says so | `ExplorationService.rollStep`, `ExplorationController.modePrompt` |

The game emblem candidates proposed on 2026-10-08 are in `content/lore.md` §14.
