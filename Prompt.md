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

### Where things stand right now (2026-09-17, two commits behind the Pi)

| | |
|---|---|
| working tree | clean |
| HEAD | **this commit** — the docs pass that recorded `c36822a` and `bf67243` |
| pushed | `origin/main` is at `b63f835`; `7050933`, `c36822a`, `bf67243` **and this commit are not pushed**. Push is user-side |
| running on the Pi | **`b63f835`** — **the tip** — schema v12, content hash `83dd8a9a`, digest `records 14d4fdd6442626ae` · `tuning 43b809a87450a3b8` · `spawns c9bdb57d456adc26` · `quests 30de20902006e3b9`, restarted **2026-09-17 00:10** |
| committed but NOT deployed | **`c36822a`** (the death wipe + the requirement-line unification) and **`bf67243`** (the plot build-confirm + the ladder names). Swift + locale keys: no migration (schema v12 stands), no content moved, and Lingo is not hot-reloaded, so `/reload` carries neither |

**A deploy is waiting, and it is the next action.** Until `pm2 restart ROI` runs, the Pi is
two commits behind: a death still destroys a class weapon left in the bag, the requirement
lines still speak four dialects, an estate slot still builds on the first tap, and one sword
still has two names. Both commits are Swift plus locale strings — no migration (schema v12
stands) and no content moved — so `/reload` carries neither. Everything older than them is
live.

The 09-17 00:10 restart itself took four commits and **no migration — schema v12 stands**,
because none of them adds a column. The Linux build ran in 66.6 s and the Pi's own
`--content-digest` matched the Mac byte for byte BEFORE the restart was ordered, which is the
order that decision has to happen in. `Code: 400` held at its 913 baseline and no
`[ROUTE]`/`[COMBAT]`/`[SCREEN]` line appeared afterwards.

**After the restart, what is waiting is a human opening the screens** — and that backlog is
now large, because six commits' worth of surfaces have never been looked at.

**Before ever claiming what is live, read it off the Pi.** On 2026-09-16 a patch note for
the testers listed three already-shipped commits as new, because every doc here said the Pi
still ran `aa18f57` while it had taken `6e3c18e` two days earlier. A deploy is the one fact
nothing writes down by itself. Four read-only commands, none of which touch the bot or the
database, are in auto-memory `feedback-ask-the-machine-not-the-record`.

### What the 09-17 deploy carried

`dc5f037` the farm and bag ladders retuned + the bag's dead Turn back button ·
`5e55139` the kitchen repair (a full bag no longer breaks a craft; the recipe screen shows
what you hold) · `6eefe85` a Profile key on the walk keyboard + the buyer's name on a sale ·
`b63f835` the arena invite stops outliving itself and stops hiding both fighters, plus the
capital's «Столична майстерня».

Three of those four came from somebody PLAYING — two from a tester — and the 09-16 deploy
before them (`78393aa` · `c9ec209` · `42e8818` · `b32ac32` · `7469715`) has **still** not been
walked. **None of either batch has been opened by a human**, which is the next action.

Each one's account — what it changed, why, and its `validate` / `simulate` / `swift test` /
digest block — is the **Commit index** at the top of `.memory/sessions.md` plus the dated
entry under it. The rules they produced are in `CLAUDE.md`; the reasons are in the
auto-memories `project-plot-streams-and-dead-lore`, `project-depth-is-banked-on-arrival`,
`project-gear-state-travels-with-the-unit`, `project-flee-has-a-ceiling`,
`feedback-no-monster-silver` (§where the line actually is).

### Next action: restart the Pi, then walk it. Nothing below has been looked at.
>
> **Step one is `pm2 restart ROI`** — `c36822a` and `bf67243` are built and verified but not
> on the Pi, and the four newest blocks below go live only with that restart. They are marked
> **NOT LIVE** for exactly that reason; everything under them has been live for days.
>
> **Step two is someone opening the screens.** Every defect this project has found came from
> glancing at a screen, not from running anything, so this list is the highest-yield thing
> available and it costs one session in Telegram. It is also the whole backlog, and it now
> spans three deploys.
>
> **Added 2026-09-17 part 4 — NOT LIVE until the Pi is restarted. Reported from play:**
> - **equip and unequip an upgraded weapon.** The banner must now name the row, not the
>   ladder's first rung: «✅ Очищений меч — одягнено», «✅ Знято: Очищений меч». The button
>   above it always said «Очищений меч»; the banner said «Іржавий меч».
> - **fight until a piece breaks.** The «⚠️ … зламався» line — in the fight screen and in the
>   passive expedition's push — must name the weapon at its current tier too. Armour is
>   unaffected (it has no ladder), so the piece to watch is the weapon.
>
> **Added 2026-09-17 part 3 — NOT LIVE until the Pi is restarted. From the owner:**
> - **claim an empty slot and tap a type.** It must NOT build any more: it must open that
>   type's card — icon, «Ділянка N · <тип>», the lore, the rate and ceiling of every stream
>   it has, and «⚠️ Ділянку не можна перебудувати» — with [✅ Будувати] and [🔙 Назад].
> - **tap 🔙 Назад.** It must return to the PICKER (the five types), not to the plot list.
> - **tap ✅ Будувати.** Same result as before: the plot list plus the «✅ …» banner.
> - **the Training Ground's card** (estate T3+) has no production lines at all — lore and
>   warning only. That is right: it produces nothing.
> - **an OLD picker message from before the restart** must now lead to the question too, not
>   build — the question inherited the old callback precisely for that.
>
> **Added 2026-09-17 part 2 — NOT LIVE until the Pi is restarted. Ten screens, one sentence:**
> - **open any recipe in the kitchen or the workshop.** Every ingredient must now read
>   «✅ 1× 🪵 Соснова дошка  (12/1)» — the «1×» is what the recipe asks for, the bracket is
>   what you hold against it, and «маєте N» is gone. The ✅/❌ is what you scan; the numbers
>   only matter where it is ❌.
> - **open the estate, weapon and bag upgrade screens.** The material lines must match the
>   recipe exactly, and the gate lines above them must now read «✅ Рівень гравця  (4/3)»,
>   «❌ 🪙 Срібло  (120/250)», «✅ Рівень маєтку  (3/3)». ⛔ must not appear anywhere.
> - **the bag screen used to say «Тир маєтку» where the weapon screen said «Рівень маєтку»**
>   for the very same gate. Both now read «Рівень маєтку» from one key.
> - **tap Cook / Upgrade without the materials.** The modal rows must be the same line as the
>   screen behind them — «❌ 🔩 Шматок заліза  (1/3)» — and no longer «• … треба ще 2 (1/3)».
>   All four modals (kitchen, weapon, estate, bag) share one function now, so if one of them
>   differs, that is a real bug.
> - **the two modals that used to show NOTHING at all.** Tap Готувати on 🍲 Бенкет Намісника
>   with an empty bag, and Покращити on any estate step from T4 up. Both were over
>   Telegram's 200-character alert ceiling and were silently refused; the feast must now show
>   all six rows, and the biggest estate step five rows and «… +1».
> - **check the English side too** — the three new labels are «Player level», «Silver»,
>   «Estate level», and the fraction itself needs no translation at all.
>
> **Added 2026-09-17 — NOT LIVE until the Pi is restarted. This one came from the owner's own account:**
> - **die with the class weapon in the bag.** Take the weapon off, walk out, and die on
>   purpose; a passive run that dies counts too. Everything else in the bag must be gone and
>   the weapon must still be there, unequipped — re-equip it and watch the profile's ⚔️ move.
>   Before this, one tap on «❌ Зняти» plus one death destroyed it permanently, and nothing in
>   the game grants a second one.
> - **die with spare gear in the bag.** A crafted hood, a potion, loot — all of it must still
>   be wiped. The exception is the bound weapon and nothing else, so if armour survives too,
>   the predicate is wrong.
>
> **Added 2026-09-16 part 3 — LIVE since the 09-17 00:10 deploy. The arena one came from a tester:**
> - **send a duel invite and decline it.** The bubble must lose its buttons and become
>   «🏳 Виклик від <нік> — відхилено. Ставка була 🪙 N.» Tapping it again must be impossible;
>   before this the buttons stayed live forever and every tap said «недійсний».
> - **accept one**, and **let one expire** (120 s). Same thing: «⚔️ …прийнято» and
>   «⌛ …протерміновано», no buttons. The challenger still gets their own «⌛ не відповів».
> - **then look at the opponents list.** BOTH players must be back in it within their 180 s
>   presence window — this is the other half of the report. A challenge used to delete both
>   lobby entries with nothing to restore them.
> - **a bubble from BEFORE the 00:10 restart is beyond saving** — its id was never stored,
>   so its buttons stay, and the actor's `pending` was emptied by the restart anyway. Tapping
>   gives an honest «недійсний». Only invites created after 00:10 are clean.
> - **the capital's Master** must now read «Столична майстерня, що гучніша за кузню…
>   З вашої сировини тут нічого не зроблять…», while the estate keeps «🛠 Майстерня».
>
> **Added 2026-09-16 part 2 — LIVE since 09-17 00:10, never walked:**
> - **walk into the forest and tap 👤 Профіль.** It must open over the walk screen, and the
>   step buttons must still work underneath. Then 📓 Нотатник → switch a leaderboard tab →
>   🔙 back → step forward. Every one of those taps was silent before: the profile's buttons
>   answered nothing at all on the trail, so they spun forever.
> - **sell something on the market and wait for it to sell.** The push must now name the
>   buyer: «Ваш лот продано: … Купує <нік>. Срібло зараховано.»
>
> **Added 2026-09-16 — LIVE since 09-17 00:10, never walked; two came from players:**
> - **cook with a full bag.** It must now cook and say «— сумка повна, тож на склад 📦»,
>   and the dish must really be in the warehouse. Before this the button spun forever and
>   the ingredients were eaten. The worst case to try is the one that broke: ingredients on
>   the WAREHOUSE, bag at exactly its cap, and a dish you already own a portion of.
> - **fill the warehouse too, then cook.** One modal: «🎒 Сумка і 📦 склад повні» — and
>   nothing may be consumed. Check the ingredient count is unchanged afterwards.
> - **open any recipe.** Every ingredient line must carry ✅/❌ and the number you hold,
>   counted across bag + warehouse TOGETHER. (The wording moved on in the 09-17 part 2 block
>   above — it is a fraction now, not «маєте N».) Cook once without leaving the screen: the
>   numbers must tick down in place.
> - **a recipe you cannot afford.** The ❌ lines must match what the shortage modal says if
>   you tap Cook anyway — they are the same reading now, so a disagreement is a real bug.
> - **the ladders from `dc5f037`** — a farm at 2/год, єм 10 filling in 5 h, and the bag
>   upgrade screen quoting **+15** at both of the top two steps (T6 now 90).
> - **turn back from inside the bag.** Travel to the capital, open 🎒 Сумка, tap
>   «↩️ Розвернутись». It must turn you around, not redraw the bag.
>
> **Added 2026-09-15 part 5 — LIVE since the 09-16 00:32 deploy, never walked:**
> - **claim a slot and read the Mine's line.** It must now be two lines: «Річкова галька,
>   8/год, єм 40» and «і 🔩 Шматок заліза, 2/год, єм 10» — «єм», not «cap», and «8/год»
>   with no space.
> - **let a Mine fill (5 h).** Both numbers must cap together now, `40/40 🪨 · 10/10 🔩`,
>   and the notification must name both.
> - **let a Курник fill.** It must read «Курник (слот N) заповнений» — masculine. Three of
>   the four plots are feminine, which is why this read wrong for months without anyone
>   noticing.
> - **collect 10 iron and check the forge** — a full Mine should be exactly one Залізний
>   злиток.
> - **read the plot picker.** Every type must now carry its lore under the numbers, the
>   Mine's must mention iron, and the Training Ground's blurb must have moved onto its own
>   line like everyone else's.
> - **tap a claimed slot, full and empty.** Both must open a card — «⛏ Ділянка 3 · Шахта»,
>   the lore, then each stream against its ceiling. Empty shows «💤 Ще нічого не
>   накопичилось» and only [🔙 До ділянок]; full also shows the two destinations, and
>   collecting must still land you on the plot list with the usual ✅ banner. This replaces
>   the old «Куди покласти?» screen, so it is the change most likely to be felt.
>
> **Added 2026-09-15 part 4 — LIVE since 09-16 00:32. The board IS zeroed; that is the migration, not a bug:**
> - **the depth board is empty after the deploy.** 🌲 Глибина must read «Поки порожньо» for
>   everyone — `ResetDeepestKm` zeroed it. 🚶 Шлях must be UNTOUCHED: if that one is empty
>   too, the wrong column was reset.
> - **walk out and back, then look at 🌲.** It should show the deepest km of that run, and
>   only after you are home — check it is still «порожньо» while you are standing in the
>   forest.
> - **die in the forest on purpose, deeper than your record.** The board must not move.
>   Then walk a shallow run home: it must not LOWER what you already earned either.
> - **type `/start` while walking, and again inside a fight.** Both must redraw the screen
>   you are on — not drop you at the manor. This was a free exit from any depth and is the
>   change most likely to be felt as a regression, so it is worth trying the way a stuck
>   player would.
> - **a passive run that kills nothing.** Its depth must still bank — the only save on that
>   path used to be conditional on XP.
>
> **Added 2026-09-15 part 3 — LIVE since 09-16 00:32, never walked:**
> - **take the weapon OFF, then visit the Master.** The repair line for it must still be
>   there, named by the item («Мисливський довгий лук · 0/100») rather than by the verb;
>   put it back on and the verb («🏹 Перетягнути тятиву») returns. Both must repair.
> - **take off a WORN-DOWN piece of armour** (equipped gear cannot be stored), **deposit it
>   in the warehouse and withdraw it again.** It must come back in the condition it went in
>   — same `x/y`, same `+N` enchant. Before this it came back 30/30 with the enchant gone,
>   which was a free repair and the reason to check it first on a piece you do not mind.
> - **verify the columns**, not the log line: `tier` · `durability` · `max_durability` ·
>   `enchant_level` must exist on `warehouse`.
>
> **Added 2026-09-15 — LIVE since 09-16 00:32, never walked. Walk it FIRST:**
> - **fail a flee four times on a warrior.** The fifth attempt must always work, whatever
>   the enemy. 40% means four failures happen in 13% of escapes, so this is reachable in a
>   session rather than a curiosity — tap Flee at a beast you can survive and count. The
>   player is told nothing, so what you are checking is that the fifth tap ends the fight.
> - **check the counter does NOT carry between fights.** Fail twice, escape, walk into the
>   next encounter and fail there: the second fight must start its own count from zero.
>
> **Added 2026-09-14 — LIVE since the 09-14 22:14 restart, walkable today, never walked:**
> - **km 1 and km 2.** A new character should now meet 🐍 Гадюка or 🦅 Беркут, never a
>   boar, and the boar should first appear at km 2. Check the eagle actually feels like the
>   spiky one — its contract is 28% of the bar and it measured 28% median / 47% p90 / 72%
>   p99 against a real armourless level-1 player. Two bad eagles in a row can kill.
> - **the two new mobs drop nothing.** That is deliberate, not a bug; the loot line should
>   simply be absent.
> - **a defeat message with a feminine enemy** — «🐈‍⬛ Скажена рись проламує ваш захист».
>   It read «прорвав» until now.
> - **the deep half of the forest is a different game now.** Every creature from km 7 down
>   was re-solved; the lynx gained 45% HP and the rabid bear 33%. Four accounts are
>   mid-progression around level 10 and will feel it immediately. The ledger says a level
>   1–3 character can no longer hold km 10 (88% win, was 95%) — km 7 is the new edge.
>
> **Added 2026-09-12 — live, never walked:**
> - **the four boards** — Profile → 📓 Нотатник → 🏆 Рейтинги. ⚔️ Рівень and 🎖 Честь have
>   data from the first second; 🌲 Глибина and 🚶 Шлях read "порожньо" until somebody walks,
>   because the counters started at zero (no depth record was ever stored to backfill from).
>   Walk one km and they should both come alive. Check the tabs redraw ONE message.
> - **the honor ladder on TWO screens** — the journal's 🎖 board and the Arena's own
>   «Найкращі бійці» now render from the same `LeaderboardService`. They must agree, ties
>   included; they did not before 2026-09-12.
> - **a starving step** — walk Vigor to 0. The root and the hunger tick must print on
>   SEPARATE lines now. Also check a starving step that finds loot, and one that starts a
>   fight: both used to take HP and say nothing at all.
>
> **From the older list, still never walked:**
> - **the forest on the way home** — the return leg should be noticeably more fight-heavy
>   than the walk out (8.8 fights over 17 km against 3.4 before). Walk to km 15–18 and back
>   on foot. With a full bag and low HP this is a real risk: death still wipes the bag.
> - **the road** — turn back twice in a row; the second should quote most of the crossing
>   (~`1хв 58сек`), not five seconds.
> - **the character sheet and any Forester piece** — three rating stats with no `%`, and a
>   `❤️ Здоров'я` line on armour that was invisible before.
> - **a fight lost, a flee, the trade screens**, and one run of **`/reload` + `/content`**
>   against a real database — `/reload` has still never run against one.
>
> **The API-error question is CLOSED.** `Code: 400` stood at **913** before the `editScreen`
> deploy, 913 an hour after, 913 after the 09-12 restart and **913 after the 09-16 one**. The
> only `[SCREEN]` lines in the whole log are **8 `StreamClosed` redraw failures dated
> 09-15** — HTTP/2 transport, not screen logic — and none appeared after the restart. If a
> new screen bug is ever reported, this is the cheap first look:
>
> ```
> ssh rpi5@192.168.0.203 'grep -c "^Code: 400" ~/.pm2/logs/ROI-out.log'   # baseline 913
> ssh rpi5@192.168.0.203 'grep -E "\[ROUTE\]|\[COMBAT\]|\[SCREEN\]" ~/.pm2/logs/ROI-out.log'
> ```
>
> **Deploying to the Pi:** `git push` — user-side, never you — then on the Pi
> `git pull --ff-only`, build, and **ASK before `pm2 restart ROI`**. A content or schema
> change must ship the new `content/data` and the new binary TOGETHER. Free pre-flight that
> touches neither the running bot nor the database:
> `ROI_PROJECT_PATH=/home/rpi5/RestOfIryna ./.build/debug/RestOfIryna --content-digest`.
> **After a migration, verify the TABLE, not the log line.** The two traps that cost real
> time — swiftenv's `PATH` living in `.bashrc`, and `pgrep -f` matching its own ssh command
> — are in auto-memory `project-pi-deploy-swiftenv`, `linux-build-gap`.

### Open, decided but not done

- **The estate calls one place three words.** «Слот» in the plot-list rows, «наділів» in the
  picker's Back button, «Ділянка» in the list title and the new slot card. The user leans to
  «ділянка»; unifying is ~6 locale keys in two files and no code. Raised 2026-09-16, left
  open on purpose rather than folded into an unrelated commit.
- **`InventoryEntry.remove` does not look at `equipped_slot`** — not when it counts
  (`totalQuantity` sums worn rows too) and not when it deletes (oldest row first, and a
  starter weapon is the oldest row an account owns). Nothing reachable in play passes a worn
  item's id to it today: the trader lists no gear, the market and the guild vault take
  stackables only, the warehouse and a trade refuse the bound weapon. But `/revoke
  gear.simple_bow 1` would take the bow straight off the body, and so would the first gear
  item ever given a trader listing. Raised 2026-09-17 beside the death fix and deliberately
  not folded into it — same shape as `feedback-fit-check-matches-the-writer`: the check
  counts something the writer does not. The bag also still offers «❌ Зняти» on the class
  weapon, left alone on purpose now that taking it off is no longer fatal.
- **`CapitalController.pushTradeInvite` discards its message id**, exactly as the arena's
  duel invite did before `b63f835`, so a trade invite keeps live buttons after the session it
  belongs to is gone. Found by the pre-commit audit on 2026-09-16 and left alone on purpose:
  the fix is mechanical but the trade flow has its own delete-vs-keep policy, so which shape
  the closed bubble takes is a design call. Auto-memory `project-close-the-bubble-you-opened`.
- **Six dead functions from April**, none touched since: `renderStub`,
  `backToRootKeyboard`, `backToHomeKeyboard` (EstateController), `itemNameOrId`
  (ExplorationController), `isPassiveInflight` (ExplorationState), `invalidateCache` (User).
  Found by the 09-16 sweep; deleting them is a standalone cleanup, not part of any feature.
- **The standing deferrals below** — flat food portions, the level 21–40 unlock gap, no
  estate at levels 1–3, seven `roster_off_curve` warnings and `opening.vigor_bankrupt` —
  are all reported by every `simulate` run and all deliberate.

### Where the changelog went

Every commit from 2026-09-09 onward — hash, what it did, and the pattern behind it — is the
**Commit index** at the top of `.memory/sessions.md`, with a dated narrative entry for each
below it. This file no longer carries one, on purpose: it was the third copy.

### What the rebalance settled

The authored band is **levels 1–25**, an enemy of level N spawns **km N…N+9**, the zones are
**Гущавина 1–10 / Старий ліс 11–25 / Пуща 26–49**, and **no new items or sets** ship in this
release. Vigor does not regenerate (Phase 8E) — food, quests and the estate are the only
sources, and the estate is the intended income. The wardrobe sits at ~40% of the on-curve
budget and the bestiary at 65–78% of its archetype contract; **both half-strength errors
lean the same way**, so the gear ladder and a roster re-solve ship together, afterwards.

The debt Phase 9 wrote itself is paid, and its finding is now **`opening.vigor_bankrupt`**.
Read the current ledger from `roi-content spec opening -c release`, never from a doc.

The rule all five specifications run on: **numbers are printed, never typed** — and the
corollary learned the hard way, **the rule protects tables, not the prose beside them**.

Decisions, the calibrated math model, the phase tracker and the per-phase lessons:
`.memory/rebalance.md`. Auto-memory `project-world-ladder`,
`project-vigor-no-passive-regen`, `project-opening-is-vigor-bankrupt`,
`project-post-rebalance-package`, `feedback-printed-numbers-protect-tables-not-prose`.

#### Standing deferrals

Reported by every `simulate` run, all deliberate: **food portions are flat
against a pool that grows** (33% of a level-1 pool, 12% of a level-40 one),
**nothing new unlocks between level 21 and 40**, **levels 1–3 have no estate at
all**, the **seven `content.roster_off_curve` warnings** (until the regeneration
package lands), and **`opening.vigor_bankrupt`** — renamed from
`opening.shallow_is_bankrupt` when the XP halving removed the last depth that was both
survivable and profitable; a warning and not a broken band on purpose, because §7 decided
to measure before retuning. Silver is also **over-supplied** — roughly twenty
thousand spare over a lifetime against 1,600 of mandatory spend — and the fix is
more to buy, which is items, which is after the rebalance.

#### The simulator, and what it currently says

`swift run -c release roi-content simulate` rolls the SAME `CombatMath` the bot calls, so a
report cannot drift from the game. It sweeps levels × archetypes × classes × play profiles ×
gear offsets and bands level invariance, the p90 tail, win rates, pace to the cap and the
shipped roster against its archetype contract; `--strict` exits 1 on a broken band. Default
sample size **8000 fights per cell** — 2000 crossed the invariance band on sampling noise alone.

Current state: **18 of 18 invariance rows pass, 0 broken bands, 12 warnings**, 19,437,688 XP
from level 1 to 40, **117–129 days** on a tended estate (warrior 128.7 / archer 124.0 / mage
116.6 — it was 157–173 until the farm was doubled to 2/h cap 10 on 2026-09-16, and 78–87
before the 09-14 XP halving; the band the report gates on is 72–200, and taps/day went 513 →
690 with the same edit). `EnemyGenerator` is what the
post-rebalance regeneration will lean on — run at design time and frozen, never at runtime.
What each phase taught: `.memory/rebalance.md`.

**Current digest baseline (2026-09-17, schema v12):** `records 14d4fdd6442626ae` ·
`tuning 43b809a87450a3b8` · `spawns c9bdb57d456adc26` · `quests 30de20902006e3b9` — **matched
byte for byte against the Pi's own `--content-digest` before the 00:10 restart**. The
`records` half moved twice in one sitting — the farm's rate and cap, then the bag ladder's
top two steps — and the other three did not move at all, which is the whole point of
splitting them. **This is the one place the baseline is kept** — `.memory/status.md` quotes it, and
`.memory/rebalance.md`'s figures are a Phase-11 record, not a current reading. A knob is
invisible to the digest until it is hashed — add the line in the same commit that adds the
knob (auto-memory `feedback-digest-names-constants`).

HP regen is **10% of max HP per real minute** (`tuning/vigor.json` → `healing.regenPerMinute`),
so a full rest at the estate takes 10 minutes — and **only at the estate**. `simulate --strict`
stands at 0 broken bands / 12 warnings: the sweep models fights, not the rest between them.

⚠️ **Four accounts played 2026-09-02 → 09-09** and reached L10 / estate T4, so the
rebalanced formulas have been exercised — but nobody stepped through the first hour against
a checklist, and **`/reload` has still never run against a real database**. It is now the
cheapest way to ship a content edit, so it is worth proving early. Auto-memory
`first-playtest-happened`.

### How content works now

All 13 catalogs and all seven tuning tables are façades over a snapshot installed at boot:

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
swift run roi-content spec <table>           # progression · gates · bestiary · items · sets · economy · opening
swift run RestOfIryna --content-digest       # confirm ONLY the intended change moved
swift test                                   # 248 tests, ~0.2s
```

## What Works Now (shipped game)

Registration · exploration (active + passive, three-tier visit decay, restart-safe
scheduler) · turn-based PvE combat with 9 class techniques · estate (plots, warehouse,
workshop, kitchen, weapon/bag/estate upgrades, technique gates) · capital hub (travel,
Trader, Tavern, Fortune Teller, Master, player Market, synchronous Trade) · Guilds · Arena
(live PvP duel, Honor ELO, stakes, daily budget) · daily NPC quests **taken by hand at the
NPC** + journal · **four all-time leaderboards** behind that journal, as tabs redrawing one
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
| `content/spec/` | The five approved specifications (Phase 9, closed) |

## Rules

`CLAUDE.md` is the full set and is loaded every session. The three that cost the most when
forgotten: **never push** (user-side only), **never start / restart / stop the bot without
asking** (the Mac instance is the one exception — stop it, it 409s the Pi), and **ask before
committing**. Content edits must pass `roi-content validate --strict`; balance-table edits
must also re-run `roi-content simulate --strict`.
