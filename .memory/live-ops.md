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
- What the owner decided the same evening (built 2026-10-08, live after the restart): the hunger
  tick only on a step that BEGINS at 0 Vigor; «Ви повністю відпочили» for every rest that tops
  out, a tap's included; the road no longer refuses 0 Vigor; the forest edge explains hunger and
  names the food in the bag. Chosen but not built — the owner left the form unanswered: eating
  straight from the warehouse, and a hint under the estate-name prompt.

## Player FAQ — verified answers (2026-10-07/08)

Every answer was read off the code and data, not recalled. Re-check the source after any change.

| Question | Answer | Source |
|---|---|---|
| HP regen at the estate | 10% of the effective max HP per real minute, so 0 → full in 10 min; ONLY at the estate (forest, road, capital: none, and the clock is cleared there); computed on the next tap or the watchman's sweep; partial minutes are kept | `tuning/vigor.json` → `healing.regenPerMinute`, `HealingService.tick` |
| The full-HP notice did not come | Until the restart after 2026-10-08 it fired only when the watchman's sweep made the fill, so a tap of the player's own filled silently. Since then every rest that tops out is announced within a minute while the player is still at the estate (a fill by food is not) | `RestNotificationService.notifyFullHp`, `RestedToFull` |
| Vigor for the road | None — only 2 real minutes; 0 HP refuses setting out, and until the restart after 2026-10-08 so did 0 Vigor (no longer); turning back costs the part walked | `TravelService.start`, `tuning/time.json` → `travelMinutes` |
| «💨 Швидкий маневр» | The archer's Defend: dodge ×1.5 for that round (DEF unchanged) and a knife for 15% of a clean hit (`defendChipFraction` 0.3 × `archerChipMultiplier` 0.5); 1 Vigor against an attack's 2. Warrior «🛡 Парирувати»: DEF ×2 + 30%; mage «🌀 Магічний бар'єр»: no chip, landed damage ×0.4 | `CombatController` defend branch, `tuning/combat.json` → `defend` |
| A broken weapon | Keeps 50% of its stats (floored; a Swift literal, not tuning); broken armour gives 0. Wear per fight: win −1, flee −2, death −3 | `EquipmentService.contributedStats`, `tuning/economy.json` → `gear.wearBudget` |
| Repair prices | Armour: price × 0.5 × missing ÷ 50, min 1 — hood 1/pt (50 full), boots 1.6 (80), breeches 2.5 (125), jerkin 3 (150), set 405; each armour repair shaves the max by 1; the enchant does not change the price. Weapon: 1 🪙 a point, no shave (30 … 180 by tier) | `MasterCatalog.repairCost`, `weaponRepairCost`, `master.json` → `repairCostFraction` |
| When the kitchen opens | Estate T2, which needs player level 4 + 20 Сосновий брус, 10 Річкова галька, 3 Шкура, no silver. Known at once: roasted meat (+14), baked potato (+10), forager's omelette (+10); six more from the innkeeper's jobs, gated on the estate tier | `EstateTierGates.kitchen`, `estate_upgrades.json`, `recipes.json` → `unlocks` |
| Raw food | Berries +4, nuts +5, duck egg +3, from the bag only; raw meat and potato are not edible raw | `items.json` effects |
| Where iron drops | Forage from km 11 (Старий ліс: 2 of 72 find weight, ≈1.3% of a fresh step), more from km 26 (2 of 32, ≈3%); never at km 1–10; no creature drops it; the Mine plot (from T2) yields 2 an hour up to 10; the trader sells at 20 🪙, buys at 10 | `zones.json`, `plots.json`, `trader.json`, `tuning/exploration.json` → `weightTiers` |
| A 40-unit lot and a 20-slot bag | Not buyable: a lot is bought whole, into the bag only (no warehouse in the capital); starter bag 25, workshop upgrades to 35/45/60/75/90; pulling a lot back needs the room too. Advice: list in lots of 10–20 | `MarketService.buyListing` |
| The developer's bag | Unlimited for `developerUsers` (Космос, 398698463) on every path into the bag; the warehouse is not exempt. So "bag full" cannot be reproduced on that account | `InventoryEntry.canAccept` / `add` |
| Guilds | Founded from level 30 for 500 🪙 since 2026-10-07; joining by invite at any level | `guild.json` |
| Hunger | 5% of max HP per step that begins at 0 Vigor, ATK and DEF −25%. Until the restart after 2026-10-08 the step that spent the last Vigor was charged too (the defect, fixed). The forest edge now says so and names the food in the bag | `ExplorationService.rollStep`, `ExplorationController.modePrompt` |

The game emblem candidates proposed on 2026-10-08 are in `content/lore.md` §14.
