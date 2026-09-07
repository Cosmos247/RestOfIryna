# Session History

## Session — 2026-09-07 (pre-push bug pass: the profile, the rest clock, the name, the level-up)

### Goal
Four reported bugs before the branch is pushed. Code and copy only — no content, no
tuning, no balance. All four digest halves are byte-identical to the Phase 10 baseline
(`records ee3fa4731c5a3a27` · `tuning 3ef097038094a4d8` · `spawns eaea309f4813dfa2` ·
`quests 2e52ecdfa45276ec`), which is the proof rather than the claim.

### 1. The profile renders one layout

The character screen carried a `1 · 2 · 3` style switcher and stored the pick in
`User.profileStyle`. Only the third layout survives; the switcher, the `pstyle:`
callback, the two other render branches, the block-bar helper and the column itself are
gone (`RemoveProfileStyle`, registered before `WipeForRebalance` so the wipe stays last).

### 2. HP regeneration starts when the player gets home

Reported as "regen doesn't start until I press Estate". The cause was neither the button
nor the estate: regen is computed lazily from `User.lastHpTickAt`, `HealingService.tick`
clears that stamp for as long as an `ExplorationState` row exists, and the tick only runs
on an interaction. So the expedition ended with a nil clock, and the next tap merely
PRIMED it — every idle minute between coming home and that tap healed nothing.

Fixed at both ends of the same clock, because reading it exposed the mirror-image bug:

- **`beginResting`** — starts the clock unless it is already running (so a running clock
  never loses what it accrued). Called from RouterStore's post-dispatch check (one place
  that covers every screen path: walked home, died, closed a report — and only for users
  who WERE out, so an ordinary interaction still costs one query), from the passive
  report push, and from a travel arrival at the estate. The last two are background
  flows with no interaction to hang a tick on, which is exactly why they needed it.
- **`suspendResting`** — stops the clock when an expedition BEGINS. Without it a passive
  run the player never tapped through kept its pre-departure stamp, and the first tap
  after coming back credited up to `maxIdleMinutes` (1440) at 5%/min: **the run's whole
  HP loss refunded**. The design had always said regen pauses out on the trail; only the
  interaction-driven half was enforced.

### 3. The player is addressed by the name they chose

`showMainMenu` greeted with `firstName ?? name` — the Telegram name. It now uses
`nickname`, and the profile's fallback stopped reaching for the Telegram one too.
Registration's step-0 welcome still uses the Telegram name, correctly: no nickname
exists yet. Checked against the Bot API: `first_name` is REQUIRED, `username` and
`last_name` are optional (the SDK mirrors it — `TGUser.firstName: String`), so a missing
@username never touches any of this; the in-game nickname is written only by the name
step and cleared only by the dev reset, which resets `routerName` in the same breath.

### 4. The level-up is its own message — and so is the tier-up

It used to be a suffix on whatever granted the XP (`🎉 Level N! 💪 +H maxHP +A ATK +D DEF`),
inside a kill report or a quest payout — the easiest line to miss in the wall of text it
sat in, and it showed three of the seven stats a level actually moves.

`User.StatGrowth` now carries all seven (maxHp · maxVigor · attack · defense · accuracy ·
dodge · crit) through `XPGrantResult` and `PassiveReport`; `LevelUpBanner` prints them as
their own bubble from all four sites (combat victory, quest payout, passive report push,
report re-delivery), with `(+N)` only where a stat actually grew. Labels are the profile's
own locale keys and values are read live off the user, so the two screens cannot disagree.

**The estate line in that banner could never print.** `estateLeveledUp` compared
`estateLevel` before and after `grantXP`, which never touches it — the tier moves only
through the paid upgrade in `EstateUpgradeService`. It was a leftover of the XP→estate
design dropped on 2026-06-16, so the flag, `newEstateLevel` and both render sites went,
along with `estate_up.banner`.

What replaced it is the real event: `EstateUpBanner`, sent as its own message on a
successful upgrade — new tier, plot slots and warehouse capacity with their deltas, and
the rooms this tier opened. It had been a `postStatusBanner` toast, which the next banner
deletes, for the most expensive purchase in the game. The room gates moved into
`EstateTierGates` (kitchen 2 · workshop 3 · training ground 3 · tannery 4) because the
banner and the buttons are now two readers of the same numbers — seven literals before.

Locale keys: `level_up.stat_boost`, `exploration.passive.report.levelup` and
`estate_up.banner` deleted; `estate.upgrade.banner.slots` / `.unlocked` added. 954 / 975.

### 5. The player is addressed as «ви»

A copy pass over the whole of `uk.json`, after the four bugs: **170 strings**
moved from the familiar «ти» to the formal plural — pronouns, present tense,
imperatives, and NPC speech («Показуйте, що ремонтувати»). `en.json` is
untouched; English has no T-V distinction.

**The sweep is the part worth keeping.** Reviewing 391 candidate strings caught
most of it and missed six, all of the same shape: an imperative in the middle of
a sentence («Спершу принеси з лісу», «забери нагороду», «поглянь на вже
присяглі»). What found those was not another pass over the strings but a pass
over the *vocabulary* — every distinct word in the file ending in `-и/-й/-ь/-ись`,
537 of them, read as a list. Three sweeps in total (pronouns, 2sg present
endings, that word list), and each caught what the previous one could not.

Verified mechanically as well: placeholders and HTML tags identical in all 170
strings, no emoji ahead of a `%{}`, no button label touched (routers match those
by text), and locale parity checked in both directions.

**Three latent gender bugs died with it.** `travel.arrived.capital` ("Ти прибув"),
`arena.err.dead` ("Ти ледь живий") and `vigor.starving` ("Голодний") had no
`.m`/`.f` at all and shipped masculine to every player. Plural fixes them for
free.

**Nine gendered pairs collapsed.** Under «ви» a past tense goes plural, so
`.m`/`.f` stopped differing for nine keys — those became single keys and their
eleven call sites moved from the `gender:` overload to the plain one. Thirteen
pairs remain, every one of them because the copy names the player
(намісник/-иця, воїне/войовнице). uk went 975 → 966 keys.

### 6. The techniques button is gone until level 8

In a fight below level 8 the second keyboard row was `[🪄 Прийоми][Втекти]`, and
the menu behind that first key could only ever answer "nothing yet" — a dead key
on the busiest screen in the game. It now appears from the earliest technique
gate, read as the minimum `requiredLevel` in `tuning/combat.json` (8 / 11 / 14),
so moving a gate moves the button with it. A **level** check rather than the
learned set, because `generateControllerKB` is synchronous and has no database;
the level is also what "unlocked" means on the Training Ground. The text handler
stays registered, so a stale keyboard from chat history still gets the polite
"🔒 Немає готових прийомів" instead of "Unsupported content type".

### 7. A daily job has to be taken at the NPC

The day still decides WHICH job each NPC offers — `QuestCatalog.daily`, a stable
hash, untouched, and the `quests` digest half confirms it did not move. What
changed is that the offer now sits on the board until the player takes it:
`QuestProgress.accepted` (`AddQuestAccepted`), `QuestService.accept`, and a
`📜 Взяти замовлення` button on the board.

Two consequences worth stating, because they are the design and not an accident:

- **`record` no longer creates rows.** It used to derive the day's job and open
  a row on the first matching gameplay event, which is precisely what made a job
  auto-active. Now an absent or unaccepted row is an early exit — cheaper too,
  since most events match no NPC at all and no longer pay for a catalog
  derivation.
- **Taking a job starts the count; it does not backfill.** Five kills before
  accepting the Master's blade trial are five kills that do not count. That is
  the honest reading of "take the job", and it is what makes the choice mean
  something.

`finish` gained `.notTaken` for a stale hand-in tap, the board renders an offer
differently from a job in progress (reward yes, progress line no — a progress
line would imply a counter that is not running), and the journal shows
`📜 не взято · 🎁 <reward>` instead of `⏳ 0/5`.

### 8. The hint that tells the player the capital exists

Taking jobs by hand needs a nudge, or the counters sit at zero all day with
nothing on screen explaining why. The one-shot tutorial hint was rewritten to
lead with the job boards — one job a day each from the Trader, Master and
Innkeeper, and it starts only when taken — with selling spare loot as the
second errand. Key renamed `tutorial.trader_hint` → `tutorial.capital_hint`;
the DB column keeps its original name, since renaming it buys nothing.

**It also fires from the passive path now.** The hint had hung off
`handleHomeReached` alone — the active walk back from km 0/1 — so a player who
only ever sent the governor out on passive runs was never told the capital
existed at all. It now fires from `PassiveExpeditionService.pushReportNotification`
(the usual passive path), from `deliverPassiveReport` (the re-delivery fallback)
and from the active walk, all gated by the same one-shot flag.

**Answered while looking: jobs do refresh daily.** `QuestCatalog.daily` hashes
`userId:npc:dayStamp`, and the stamp rolls at 12:00 Kyiv, so a new game day
derives a fresh job per NPC out of a pool of three (the same one recurs about a
third of the time). Yesterday's row simply stops matching the stamp: no
carry-over of progress, no penalty, and a job taken yesterday has to be taken
again today.

### 9. Daily jobs got level bands and a reward curve

Two faults, one cause — a flat reward and an unfiltered pool.

**Three of nine jobs were impossible before level 7.** `mat.iron` is foraged only
from km 11 (the Old Wood), where a level-5 player has no business — the ledger
puts survival, not Vigor, as the binding constraint past km 11 — and the only
other source is a Mine plot, which needs an estate slot (T2, level 4). So
`trader.iron`, `master.ore` and `master.smelt` (which also needs the forge, T3 =
level 7) could be assigned to a level-1 player as their one job for the day.

**And `master.blade_trial` (kill 5 beasts, +80 XP) is 67% of a level at 1 and
0.036% at 20** — the same reward worth 1,800× more at one end of the game than
the other, for the same five minutes of work.

Fixed as: `QuestDefDTO.minLevel` filters the pool BEFORE the daily hash (trader
1/6/8 · master 1/7/10 · tavern 1/4/5, so the level-1 board is hides, five kills
and raw meat), and the authored reward is halved and then scaled at payout by
`ProgressionMath.questReward`, each currency on the curve it belongs to:

- **XP** on the `mobXP` exponent, so a job is worth the same NUMBER OF KILLS at
  every level — the invariant checks out exactly (40 base = 4 level-1 kills at
  L1, 4,156 = 4 level-20 kills at L20).
- **Vigor** on the pool it refills, so a portion stays the same share of the bar.
- **Silver** linearly, and slowly.

**The silver rate was chosen by arithmetic, not by feel.** At the 4%/level I
first wrote, the level-40 daily came to 282 against today's flat 220 — a "cut"
that raised the number at the end of the game, where `spec-economy.md` says the
surplus already is. At 1.5% the arc runs 85 → 175, under the old flat 220 at
every level, and the lifetime take lands near 12k against ~19.8k.

**The bands had a cost, and it was paid rather than argued away.** Filtering the
pool by level left each NPC with exactly ONE reachable job below level 4 — the
same three jobs every day until level 6 at the trader and 7 at the master. Six
early jobs were authored to fix it (forage deliveries out of the first zone:
5 pine lumber, 6 berries, 6 nuts, 6 river pebbles), so a level-1 board offers
three per NPC, the same variety the late game has. This is new content in a
release that had ruled new content out — taken deliberately, on the grounds that
a band without an early pool behind it is worse than no band.

The faucet after both changes: **78 → 153 silver a day** across the arc, against
a flat 220 before.

### What this one taught about the tools

**The digest had a blind spot and the change walked straight into it.** Adding
`questRewards.silverPerLevel` to `tuning/economy.json` moved nothing: the tuning
half hashes named constants, and a new one is invisible until it is added. A
balance knob outside the digest is a knob whose edits nobody can detect — so it
is hashed now, and the half moved on the next run. Worth remembering as a rule:
**a new tuning field is not covered until the digest names it.**

**Two spec blocks never reproduced from their own markers.** The verbatim check
run over all ten generated blocks found `spec-economy.md` and `spec-sets.md`
quoting two fragments of one command's output with a whole section silently
skipped between them — and `spec-sets.md` had a sentence of prose living INSIDE
the markers, which can never reproduce. Not drift in the numbers; drift in the
mechanism that is supposed to detect drift. Both blocks are contiguous excerpts
now, the prose moved below its marker, and all ten reproduce.

Validator rules gained `quest.min_level` and `quest.no_level_one_job` (a pool
whose cheapest job starts above level 1 leaves a fresh player with nothing) —
both negative-tested, and the first attempt at that test was itself wrong: it
raised a job that was not the pool's level-1 one, so the rule stayed correctly
silent.

### What the review caught, after all four already worked

- The `grantXP` doc comment was mangled by my own edit — and the parenthetical it
  mangled ("+5 maxHP / +1 ATK / +1 DEF at L2/3/5/6/9/12/15/18") described the growth
  model Phase 5B replaced, three lines above a comment saying so. Rewritten.
- `var xpLine` in the passive report stopped being mutated when the level-up left it.
- The report push could buy the player a **duplicate report**: the report send is what
  decides whether the state row survives for a retry, and a throwing banner send after
  it would skip the delete. The banner is best-effort now.
- Two `try?` results were unused (warnings) — a clean build had been hiding them behind
  an incremental one.
- The locked-room alerts still interpolated hardcoded `"2"` / `"3"` right next to the
  gates that had just been centralised.

### Worth remembering

**A lazily-computed clock is only correct if both ends are stamped.** The regen bug and
its mirror are the same defect seen from two sides: an interaction-driven tick cannot
observe a transition that happens while nobody is interacting. The fix is not a
background job — it is stamping the boundary where it happens.

**A flag that can never be true reads exactly like a feature.** `estateLeveledUp` had
been shipped, documented in README and TODO, and quoted back in a mock-up in this very
session, three months after the design that fed it was dropped. Nothing executes a
boolean that is always false.


## Session — 2026-09-02 (Phase 11 opens: the opening ledger)

### Goal
Pay the one debt the rebalance wrote itself before the playtest — `spec-economy.md`
§7's band for levels 1–3 — chosen over flipping `time.scale` or writing the wipe,
because it is the only piece that produces a prediction the playtest can then check
and it carries no live risk.

### What landed

**`Modules/ROISim/OpeningLedger.swift`** — a model file beside `FoodBudget`, for the
same reason `FoodBudget` is one: the pace section divides kills by what a tended
estate feeds, and before the first upgrade there is nothing to divide by, so those
levels were excluded and reported as `pace.levels_without_an_estate` and never
priced. The ledger prices them at every depth against the trail — walk plus fight
out, forage in — and prints one row per distinct spawn set at the shallowest km that
has it.

**The measurement inverts the spec's own conclusion.** `spec-economy.md` §2 says the
opening is Vigor-bankrupt: 79 boars, 664 Vigor of deficit against a 105 pool. Measured:

```
km  mob levels    xp/kill  vigor/kill    win%     kills     trail     spent  walk in       net  if cooked
1   1                 8.5         9.1    100%      92.2       350       837        2      -374        400
4   1,4              89.0        11.4    100%       8.9        34       101        8        40        150
10  1,4,7,10        388.4        14.9     95%       2.0         8        30       20        72         95
13  4,7,10,13       917.0        23.2     66%       0.9         3        20       26        72         80
```

The opening is not bankrupt — **the shallow opening is.** Four kilometres of walking
is worth more than the entire deficit, and the flip lands at km 4, the first depth
where anything but the boar spawns. Depth then has a measured **optimum** rather than
an open ceiling: Vigor stops binding at about km 4 and survival takes over at about
km 11 (95% win at km 10, 66% at km 13, 9% at km 20). The design's "walk deeper than
is comfortable" stopped being a claim and became a number.

### The three things that decided the answer

- **Raw meat is not income during the opening.** It restores nothing as found, and
  every recipe that turns it into a portion is a `kitchen` recipe — a room gated on
  estate tier 2, which is the level the opening ENDS at (`EstateController` line 1037).
  §3's ledger had credited the boar with 8.4 Vigor of cooked meat across a stretch
  where the oven is locked. It is printed as `if cooked` instead: 774 Vigor at km 1,
  twice the deficit, which is the size of what the gate holds back.
- **Only forage edible as found counts.** Half the km 1–10 pool is lumber and river
  pebble, and the potato deeper in needs the same locked kitchen. Counting the pool
  as food would have paid double.
- **Kills use the level-gap scaler.** 92.2 at km 1, not the flat 788 ÷ 10 = 79 — a
  level-3 player earns 8 XP from a level-1 boar, not 10, and the decay adds 17%.

Everything else is excluded and named rather than rounded away: silver (hide sells,
quests pay, the trader stocks food AND the lumber a kitchen would want), the events
the approach walk rolls on the way in, and re-entered rooms. All three push the same
direction, which is what makes the table a **floor** and not an estimate.

### The band

`opening.shallow_is_bankrupt` — a **warning**, not a broken band, and deliberately:
§7 decided to measure before retuning, so an error would fail the build on the exact
number the project agreed to look at first. It fires when the shallowest depth cannot
pay for itself while a deeper one can — when the game is solvable only by a move it
never teaches, which is precisely what a first-hour playtest walks into. Three more
rules sit beside it and stay silent on today's data (`opening.vigor_bankrupt`,
`opening.depth_does_not_pay`, `opening.no_holdable_depth`), each of them the shape the
answer would take if a retune overshot.

`--strict` still exits 0: 0 broken bands, 12 warnings (was 11). No content file was
touched, so no digest half can have moved.

### What this session is worth remembering for

**A model's exclusions are where its answer lives.** Three of them here — the locked
kitchen, the inedible half of the forage pool, the level-gap decay — and each one
moved the result by more than the whole deficit the spec was arguing about. Two of
the three were *corrections* to an approved document's prose rather than choices, and
neither was visible from the numbers beside them: §2's table was right and the
sentence under it was not, which is the same failure `spec-progression.md` §3 already
had. Printed numbers guard tables, not the prose beside them — third instance.

**Tests: 222 → 234.** The load-bearing one is the level-gap scaler, because dividing
the XP ladder by a printed reward is the obvious way to count an opening, it is the
way an approved spec counted it, and it is wrong by 17%. The selection rule is
negative-tested too: a depth the player cannot hold is not a cheaper opening, it is a
shorter one, so `best` skips the richest row when its win rate fails.

### What the audit caught, after the section already worked

Reading the finished model back found two defects, both invisible in its output:

- **A kill drop edible AS FOUND counted as nothing.** The loot loop asked "does
  this restore Vigor? then it is not the locked meat" and priced it at zero —
  so a food drop would have contributed to neither the trail column nor the
  locked one. No shipped enemy drops food, so the bug was worth exactly 0 today
  and would have been worth a whole column the day one was authored. Split into
  `killFood` (income, in the net) and `meatLocked` (printed only); every shipped
  row is byte-identical after the fix, which is the proof it was neutral.
- **`maxKm: 25` was an undocumented magic number** in a file whose premise is
  that numbers come from content — and it truncated the table before the
  wilderness ends, since the elite's band runs to km 40. Now read off the
  roster's own deepest band, which added the km 26 row the ceiling was hiding.

The second is the more interesting one: it truncated in the single direction the
table exists to answer — *is there a better depth further out?* A ceiling that
silently answers "no" to the question you built the tool to ask is worse than no
tool. Both are pinned by tests (12 in the file now).

Also caught, and worth remembering separately: the first verbatim checker for the
`<!-- generated -->` blocks reported all four as drifted, and was itself wrong —
a block may quote several tables from ONE command that are not adjacent in its
output. Compare each blank-line group, not the block as one string. Written into
`.memory/content-pipeline.md`, because a checker that cries wolf gets ignored,
which is worse than not having one.

### Then the wipe

`spec-economy.md` §2 was amended after all (the user asked to see the diff first):
an **AMENDED** notice on the heading, a *superseded* note under the 664, and a
*Measured* subsection quoting a generated block. Rather than type the table in,
the ledger got its own spec table — `roi-content spec opening` — sharing
`simulate`'s seed and sample size, so the two cannot print different numbers.
`runs`/`seed` moved to one place in `main.swift` to make that structural rather
than a coincidence.

`WipeForRebalance` followed. Two things decided it:

- **The FK cascades do not cover the schema.** Deleting `users` and letting the
  cascades run looks tidier and is wrong: `tavern_game_messages` stores a raw
  `telegram_id` and carries no foreign key at all, so it would survive untouched.
  The list is explicit, and `TRUNCATE` takes all fifteen in one statement so FK
  order between them stops mattering.
- **A list can go stale; a schema cannot.** So `prepare` asks
  `information_schema` what tables exist AFTER the truncate and refuses to finish
  while any of them holds a row. A table added later and forgotten in the list
  fails the boot instead of quietly surviving the wipe — which is the same shape
  as the opening ledger's derived depth: read the ceiling off the data, never
  write it down.

Registered LAST in `configure.swift`, with the reason in a comment: it truncates
every table the migrations above create, so anything registered after it would be
wiped before it existed. On a fresh database it is a no-op — it runs in the same
batch as the creates.

Verified statically that a wiped database is not a broken one: `User._session`
creates a row on first contact with `routerName = "registration"`, so the allowed
accounts land in registration rather than in a null state. **Not executed** — no
database was reachable (the tunnel was down), and it runs at the next bot launch.

### The finding the playtest has to check first

Written down late, and it is the most important caveat in the session. Every
number the balance report prints — TTK, win rates, the p90 tail, the opening
ledger — is measured against `ReferenceCharacter`: a class's proportional stat
line **plus a full kit of common gear**. A real level-1 player has **only the
class starter weapon**: `RegistrationController` step 3 grants and equips it,
there is no armour grant anywhere, and the first armour reachable is the Forester
set (a workshop craft — estate T3, player level 7) or the Master's armour bought
for silver.

So every fight in the opening costs more rounds and more Vigor than the report
says, and every win rate is lower. Direction certain, magnitude unmeasured.

What survives: the ledger's km-1-vs-km-4 ordering is **amplified**, not weakened —
weaker gear raises the per-kill cost equally at both depths, but km 1 needs 92
kills and km 4 needs nine. What is at risk is the load-bearing claim itself:
whether a level-1 player can beat the level-4 moose at km 4, which the sim puts at
100% *with the kit*. If that fight is not winnable in one weapon, "walk deeper
immediately" needs a different shape.

Not a defect in the ledger — a property of the report as a whole, and it predates
it. It bites hardest at level 1, where the missing kit is everything except the
weapon. Fixing it would need a slot-aware gear offset in `ReferenceCharacter`
(`gearOffset` scales item LEVEL today, not which slots are filled); not attempted,
because measuring it live comes first.

### The drift check found a hole in itself

Re-running the verbatim check across all five specs reported two blocks in
`spec-items.md` and `spec-sets.md` as drifted. They were not: every number matched,
only the ROW SELECTION differed, because those blocks were generated with explicit
`--levels` and the marker recorded only `roi-content spec items`. A marker that
under-specifies its command cannot be reproduced, so the block reads as broken
forever — the same "a checker that cries wolf gets ignored" failure as the
blank-line-group bug the day before, one level up. Markers now carry the full
command; **all 31 groups across the five specs reproduce from their own marker**.

### Then the docs were squared up

A sync pass found four stale records and one unrecorded finding (the one above).
Retired: `Prompt.md`'s "the spec is not yet amended" and its whole "one thing
still owed" passage, both overtaken the same day; "0 broken bands, 11 warnings"
(12 now); "Phases 3–10 are done / only Phase 11 remains" in `Prompt.md`,
`README.md`, `.memory/INDEX.md` and `.memory/status.md`; and a `222 tests`
baseline in `status.md`.

One was older than this session and worth naming: `spec-progression.md`'s
Phase 9 amendment still said *"the shipped moose is level 6 from km 6 worth 418
XP"* with the re-spread as a pending parenthetical — but Phase 10 landed it on
2026-09-01, so the parenthetical had become the truth and the sentence had
become false. **Third instance of the same failure**: printed tables cannot
drift, the prose beside them can, and an amendment is prose too.

### Still open

`scale` 60 → 1.0 is **deferred past the playtest at the user's call** — the first
hour runs on compressed time. That is sound for what it measures: the opening has
no game-time gate at all (no step cooldown, no estate below level 4, no Vigor
regeneration), so the ledger's km-1-vs-km-4 answer is testable as-is. What it
cannot measure that way is the estate pace, which is entirely game-time. The flip
is still the only error `validate --strict` reports and still owed before release.

Then: the live first-hour playtest, which is now the next action.


## Session — 2026-08-31 → 09-01 (Rebalance Phases 9 + 10: the five content specs, then the level re-spread)

### Goal
Close Phase 9 (content specifications, approved before anything is authored) and apply
Phase 10. Started with three of five specs unwritten; ended with Phase 10 committed and
only Phase 11 left.

### Phase 9 — the three remaining specifications

**`spec-items.md` — a FRAME, not a list.** The user ruled out new items for the rebalance
("зроби каркас для майбутнього додавання різного рівню сетів, але все це після
ребалансу"), so the document specifies the grid a future item lands on rather than the
items. Extended `roi-content spec items` with two printed tables — slot coverage and the
obtainable kit against the on-curve kit — and what they printed reset the phase plan:

- The wardrobe is **7 pieces**. Three weapons ladder itemLevel 1→40; four armour pieces are
  **frozen at itemLevel 1 forever** (only the Master's +20% enchant ever touches them);
  `off_hand` and both accessories have **no items at all**.
- A fully enchanted kit is **97% of the on-curve budget at level 1 and 40% at level 25.**
- Since the bestiary carried ~50% of its archetype contract, **the two half-strength errors
  were cancelling** — and `spec-bestiary.md` §9 had committed Phase 10 to removing exactly
  one of them. Amended that approved document in place rather than rewriting it quietly.
- **The frame that costs no content:** generalise `weapon_upgrades.json` to armour, so the
  Forester set climbs the same rungs. `EquipmentService.nominalStats` already resolves by
  `itemId + tier` **without checking the slot**, so stat resolution needs no change. User
  chose: build it *after* the rebalance, together with the regeneration.

**`spec-sets.md` — the inherited fix was wrong.** Measuring before applying showed it:

- The flat set bonus does **not** rot today (the set never climbs, so 8.4 points against 36
  is a stable 23%); it rots only when the gear ladder lands.
- **`gear_multiplier` scales the wearer's WHOLE kit**, weapon included, and the weapon is
  not a set member. The same ×1.05 costs **8% of the members' budget at L1 and 33% at L40**
  — a flat bonus decays, a whole-kit multiplier compounds, and both measure a bonus by a
  denominator that is not its own. Under that reading the largest legal multiplier falls
  ×1.15 → ×1.04: no single authored value is legal for a whole lifetime.
- Decided: a multiplier scales its **own equipped members**; the 25% cap extends to
  multipliers; **set strength is a ladder whose top rung is that ceiling**, independent of
  item level. The user then freed the Forester set's numbers and called it "the first,
  weakest set" — so it is one four-piece threshold at **×1.07, 29% of the ceiling**. An
  earlier draft proposed ~19% to preserve its strength and was wrong for a reason worth
  keeping: a ladder whose bottom rung is three-quarters of the way up is not a ladder.

**`spec-economy.md` — the finding was not about silver.** It was that the opening is
Vigor-bankrupt and an APPROVED document said otherwise: `spec-progression.md` §3 carried
"about eleven kills to reach level 4". Eleven reaches level 2. Level 4 is 788 XP = **79
boars**, ~**664 Vigor of deficit against a 105 pool**. Amended §3.

- Silver: **1,600 mandatory across the whole game** against ~19,800 from quests alone over
  ~90 days. The trader is the only real sink and using it is optional. Three shapes nobody
  chose, recorded and left alone: a uniform −50% spread on every line, a forge that adds no
  value in either direction (10 iron = 200 to buy = 1 ingot = 200; both sell for 100), and a
  tavern with **exactly a 0% house edge**.
- **`lootMultiplier` wired to QUANTITY**, per the user's call — chance is a probability and
  saturates. `quantity` is an `Int` and the multiplier a `Double`, so the fractional part
  becomes a **probability, not a rounding**: at a base quantity of 1, ×0.5/×1.0/×1.2/×1.7
  all round to 1 or 2 and six archetypes collapse into two. And the loot tables must be
  **re-normalised to a base** in the same pass — the elite's 1.80 hide is already a
  hand-written answer to "elites drop more", so the multiplier would apply it twice.

### Phase 10 — the level re-spread, and three things it moved underneath

Applied `spec-bestiary.md` §3 and nothing else. Six enemies changed `level`, `depth` and
`xpReward`; stats untouched.

- **`xpReward` had to move too.** It was exactly `round(mobXP(level))` for every enemy
  before the change and is again after — it is *solved*, not authored (`spec-bestiary` §2
  says so). Values read off `roi-content spec bestiary`, not recomputed by hand.
- **The rabid bear keeps a stretched band, km 22–40.** The plain N…N+9 rule opened a
  nine-km hole at km 32–40 where exploration rolls no encounter, and the validator refused
  the bundle (`enemy.depth_gap`). It shipped as 25–40 for that same reason.
- **The Bison rename is three files, not one.** The spec justified it with "which is what
  the Ukrainian name and the lore already say" — they did not (`uk.json` had «Дикий
  буйвіл», `lore.md` had Wild Buffalo). Decision stands on the emoji and the animal;
  the parenthetical was wrong and is corrected.
- **Side effect worth knowing:** the roster moved from **~50% to ~60% of its archetype
  contract with no stat change at all** — a lower level is a lower target. It thins the
  cancellation `spec-items.md` §3 relies on without breaking it; every affected document is
  annotated rather than rewritten.

### Tooling added (so specs quote rather than assert)
`roi-content spec` gained **`sets`** and **`economy`**; `items` gained slot coverage and the
obtainable-kit gap; `economy` prints the trader spread, every ladder priced at buy prices,
the sinks, the quest faucet, the opening ledger and the per-kill Vigor/silver return.
`GearStatsDTO.pointsSpent(at:)` moved to **`Modules/ROIContent/BudgetCurve.swift`** so the
validator's set-bonus cap and the spec tables share one exchange rate — ROIContent cannot
import ROISim, which is why it lives there and not beside `BudgetMath.spend`.

### The lesson worth carrying
**"Numbers are printed, never typed" protects tables, not the prose beside them.** Phase 9's
one real error lived in a hand-counted sentence under a correct table. During the Phase 10
audit the verbatim check caught two generated blocks the re-spread had invalidated *and* a
passage quoting a planned change as if it were already in the data — while three numbers
typed into prose by hand (223 vs 231 XP, 664 vs 662 Vigor, the moose's level) had to be
caught by re-deriving them. The opening ledger was made generated for exactly this reason.

### Verification discipline held throughout
Phase 9 moved **no digest half at all** — five specifications, three spec tables and a
validator refactor, and `records` / `tuning` / `spawns` / `quests` all stood still. Phase 10
moved **exactly the two predicted** (`records ee3fa473`, `spawns eaea309f`) and held the
other two. 222 tests, `validate --strict` clean but for the deliberate `scale = 60`,
`simulate --strict` 0 broken bands throughout.

### Commits
`bf70986` Phase 9 · `977bd0e` Phase 10.

## Session — 2026-08-23 (Phase 9.2 — daily NPC quests, v1)

### Goal
Land the first quest system. Design was settled in a quiz up front: **v1 scope = the gathering core** (Trader / Master / Innkeeper — all single-player, works with content that already exists), **cadence = dailies only**, **mechanic = auto-assignment** (user: "let the system pick from the pool you built and give each NPC one random quest per day"), **rewards = silver everywhere + per-NPC accent** (Trader → silver, Master → XP, Innkeeper → Vigor). Arena / Ворожка / Гільдія quest-givers, chains and weeklies were explicitly deferred.

### Key design call — assignment is derived, not stored
`QuestCatalog.daily(npc:userId:stamp:)` = FNV-1a over `"userId:npc:GameDay.stamp()"` mod pool size. No RNG, no assignment row, no scheduler: the same player on the same game day always resolves to the same job, and every player gets an independent roll. Hand-rolled FNV **on purpose** — Swift's `Hasher` is seeded per process, so a bot restart mid-day would have re-rolled everyone's job. Verified over 200 fake players × 30 days: 5999/5998/6003 split across the three slots, and 200/200 players saw all three jobs inside a month.

### What was done
- **New**: `Models/QuestCatalog.swift`, `Models/QuestProgress.swift`, `Migrations/CreateQuestProgress.swift`, `Services/QuestService.swift`. Migration registered in `configure.swift`.
- **Two objective shapes.** `deliver` reads progress LIVE from the bag (nothing to keep in sync; gather in any order, anywhere) and consumes items at turn-in, which pays out in the same tap. `counter` accumulates via `QuestService.record(...)`.
- **5 hook sites**, all `try?` so a quest write can never break the flow it rides on: `CombatController.finishVictory` (+1 kill; training dummies bail before this), `PassiveExpeditionService.finalizeAndPush` (whole run's kills banked at once, deaths included — same rule as the XP grant), `CraftingService.craft` (ingot output only), `TraderService.sell` (silver amount), `CapitalController.runRound` (wins only — a tie returns the stake but doesn't tick).
- **UI**: `[📜 Замовлення]` added to the trader / master / tavern menus → board edited in place over the NPC's own message (`editTraderScreen` handles photo-vs-text hosts). Exactly one action button, and only when the job is finishable — `✅ Здати` for deliver, `🎁 Забрати нагороду` for counter. Payout banner echoes the combat level-up / estate-up lines.
- **33 locale keys × 2**, all gender-neutral (imperatives + impersonal «виконано»), emoji prepended in Swift per the Lingo leading-emoji rule. uk glossary respected: `Досвіду` / `Снаги`, item names matched to the real catalog strings («шматок заліза», «юшка мисливця»).

### Follow-up in the same session — quest journal («Нотатник»)
User asked for a journal screen and placed it **in the profile**, under the 1/2/3 style buttons (screenshot). Implemented as a second keyboard row (`journal:open`) that edits the *same* profile bubble into a read-only digest of all three jobs — per-job state (✅ claimed / 🎁 ready / ⏳ done/target + reward), a `🕛` countdown to the next 12:00 rollover, and a line reminding that turn-in happens at the NPC. `journal:back` edits it back to the profile, so the player never accumulates profile screens. **Deliberately claim-free** — letting the journal pay out would turn a status screen into a remote control for the capital and make the trip to town optional. Reward wording delegates to `CapitalController.rewardPhrase` (one source, board and journal can't drift). New `GameDay.secondsUntilNextRollover(from:)` (calendar search in the Kyiv zone → DST-safe) powers the countdown. Works from every router that falls through to `MainController.onCallbackQuery` (capital / estate / guild / arena / inventory), which is how the capital-opened profile keeps working. Journal title is gendered (намісника/-иці) → `.m`/`.f` in uk.json + the gender overload; the other 9 journal keys are neutral.

### Balance note flagged to the user
`master.smelt` asks for **1** ingot, not the 3 sketched in the design pass — one ingot is already 10 raw iron (≈100🪙 of material, a full expedition). Three would be a week-long job wearing a daily's clothes. Rewards sized at ~1.5–2× the trader value of the same materials.

### Verified, and what is still owed
The migration landed: the database now reports 45/45 migrations applied and a live
`quest_progress` table (the same boot also caught the DB up on Market, Guilds, gear
condition and Arena, which had never run against it). The bot boots clean and polls
Telegram. The hash distribution was checked with a standalone script — 200 players ×
30 days spread 5999/5998/6003 across the three pool slots, and all 200 saw every job
within a month. Still owed by a real playtest: turn-in against an exactly-full bag,
the 12:00 rollover in the wild, and the counter hooks firing from a passive expedition.

### Operational lessons from getting it running (worth keeping)
- **The database is not the Docker container on the Pi.** That container belongs to a
  different project; `ArtaniaDB` lives in a *native* PostgreSQL 15 cluster bound to the
  Pi's loopback, so it needs an SSH tunnel and is invisible to a port scan. Connecting
  to the wrong Postgres fails with `role "<user>" does not exist`, not a connection
  error — that message means "right host, wrong server".
- **`HTTPClientError.deadlineExceeded` at boot was not a network fault.** A previous run
  stopped at a debugger breakpoint was still alive and still holding the token's
  `getUpdates`; the new instance starved until the 30 s client deadline tripped. The
  stopped process survives `kill -9` while the debugger traces it — kill `debugserver`
  first. Check `pgrep -fl RestOfIryna` before starting a run.
- Both failures surface as a bare `Fatal error: Error raised at top level`, which shows
  only assembly in the debugger. Wrapping the migration step and `bot.start()` so they
  report the host/port or the likely duplicate instance is still an open improvement.

### Commit hygiene
The tree held two unrelated phases at once (Arena from July, quests from today), so it
was split into six commits — GameDay, Arena, quest engine, quest hooks, quest boards,
journal — each built before it was committed. The entangled files (both locale JSONs,
`configure.swift`, `file-map.md`) were split by reconstructing intermediate file states
against a fixed base commit rather than by hand-editing hunks.

## Session — 2026-05-27 (Combat keyboard: inline → reply-keyboard)

### Goal
User wanted combat actions to **replace** the main reply keyboard for the duration of a fight (like every other controller) instead of riding as inline buttons on each round message. Two design choices settled via quiz: keep the techniques **sub-menu** structure; **hide** unavailable techniques (unlearned + spent).

### What was done (`CombatController.swift`, `EstateController.swift`, both locales + docs)
- `combatMainMarkup`/`combatInlineKeyboard` → `combatReplyKeyboardMarkup`/`combatReplyKeyboard` (`TGReplyKeyboardMarkup`, resizeKeyboard). `generateControllerKB` now returns the default (non-training) combat keyboard (was `nil`).
- `attachHandlers` registers action labels by text per `CharacterClass.allCases` × `SupportedLocale.allCases` (onAttack/onDefend/onFlee/onSpecial*/onSuper) + per-locale onTechMenu/onTechBack/onTrainingExit. Labels must stay **static** (router matches text; the old `× N` suffix would break matching and trip the default `partialMatch` "input ignored" message) — `× N` moved to the submenu message body.
- `onTechMenu` sends a fresh sub-keyboard of only usable techniques (learned AND uses>0); unlearned/spent hidden; none-usable → re-send main keyboard + `combat.tech.none_available`. `onTechBack` re-sends the status card + main keyboard. `combatTechniquesMarkup` deleted.
- `onCallbackQuery` demoted to a **legacy fallback** for inline buttons lingering in chat history (answers spinner, re-presents fight, flips routerName→combat if forwarded). `loadCombat` stale path + `sendLockedToastIfUnlearned` now send plain messages (no more modal toasts — reply keyboards have none).
- **Training:** `EstateController.handleTrainingSpar` flips `routerName` to "combat" (was "estate" — combat now owns the keyboard); `onTrainingExit` restores `routerName="estate"` + the main keyboard (attached to the exit banner) before re-rendering the plot list.
- **Locale collision fix:** `combat.button.training_exit` renamed "🔙 Back" → "🚪 Exit" (en) / "🔙 Назад" → "🚪 Вийти" (uk) so it doesn't collide by text with the techniques `combat.tech.back` ("🔙 Back"). Added `combat.tech.prompt` + `combat.tech.none_available` (both locales).
- Docs synced: README, `.memory/{status,file-map,controller-pattern,localization}.md`, TODO.

### Verified
`swift build` clean; JSON valid. **Manual Telegram run-through still owed by user** (encounter, techniques, training, registration dog fight).

## Session — 2026-05-22 (Master/gear progression expansion: enchant class bonus, premium prices + iron craft, weapon durability, inventory gear card)

### Goal
Iterative balance + depth pass on the Master (Phase 6.5), driven entirely by interactive design Q&A with the user. Four threads, all building toward one big commit.

### What was done

**Armor enchant — class-identity bonus + deeper ladder**
- On top of the flat +DEF every class gets per enchant level, enchant now grants a class-identity stat: ⚔️ warrior +DEF (doubles down), 🏹 archer +dodge, 🔮 mage +crit. Chosen scheme: "by class identity", layered ON TOP of the base DEF.
- Cap raised +3 → **+5**. Non-linear point curve `MasterCatalog.enchantBonusPoints` (per-level weights 1/1/1/2/3 → cumulative 1/2/3/5/8) — top levels worth more; drives BOTH the flat DEF and the class bonus.
- Step costs raised ("moderately higher"): 40/100/220/450/850🪙 + 4/8/15/26/42 hide.
- UI: enchant-screen hint shows the class focus; success banner shows the real per-level numbers. Keys `capital.master.enchant.focus.{class}` + `bonus.{class}` (with `%{def}`/`%{extra}`).

**Master premium prices + heavier craft recipe**
- Forester buy prices premium (×4 material value): hood 60 / boots 95 / breeches 150 / jerkin 180 (set 485🪙). Repair derives from buy price, so it scaled up automatically (user liked the resulting numbers; no wear multiplier added).
- Craft cost raised + iron added (user: "more hide + a little iron", hood stays hide-only): hood 5🦴; boots 8🦴+2🔩; breeches 12🦴+2🔩; jerkin 15🦴+4🔩 (set 40🦴+8🔩). `RecipeIngredient` already supports multiple inputs, so no silver-cost field / `CraftingService` change needed.

**Weapon durability (new)**
- `WeaponUpgradeCatalog.durabilityByTier` [30,40,50,70,100] + `durability(forTier:)`. T1=30, T5=100 (user-chosen endpoints; accelerating curve).
- Weapon joins the wear pool: `GearConditionService.weaponSlots`/`durableSlots`, `drainEquippedArmor`→`drainEquippedGear` (caller in PassiveExpeditionService updated too).
- At 0 durability the weapon keeps **half** its stats (floored) — NOT broken. Lore: it's the King's weapon, can't break. Repair restores to full at **1🪙/point** (full T1=30 … T5=100), **no** max shave (`repairMaxShave` armor-only). Branch added in `MasterService.repair` + `MasterCatalog.weaponRepairCost`.
- Upgrade refreshes durability to the new tier's full max. Idempotent startup `backfillWeaponDurability` lifts pre-existing weapons (init's flat 30) to their tier ceiling, preserving the missing amount.
- Repair UI adds the equipped weapon with a class-flavoured button: 🗡 Sharpen blade / 🏹 Restring bow / 🔮 Re-empower staff.

**Inventory gear detail card + cleanup**
- Tapping gear now opens a full HTML detail card as its own message (`InventoryController.gearDetailCard`): name+tier, lore, full-condition stats, condition block (durability, broken/dulled warning, enchant). Non-gear keeps the lore alert.
- Single source of truth: `EquipmentService.nominalStats` / `contributedStats` (recompute now sums `contributedStats`; card uses `nominalStats`).
- Gear-row labels cleaned: durability removed from the inline button (it truncated names — user feedback), enchant shown as plain `+N` (no ✨ icon).
- Repair success banner: `(max durability N)` → `(cur/max)` e.g. `(29/29)`.

**Master confirm step (accidental-tap guard)**
- Buy/repair/enchant taps no longer act immediately — they open a confirm prompt (`✅ Yes`/`❌ No`) restating item + cost. New `master:buyok:/repairok:/enchantok:` callbacks execute; `No` returns to the list. Helpers `editToMasterConfirm{Buy,Repair,Enchant}` + `masterConfirmKeyboard` + a controller-local `ownedRow`.
- With cost now on the prompt, list buttons were trimmed: repair drops the price (keeps durability), enchant drops the price (keeps the level step). Per user follow-up, the **buy** list keeps its price on the button (helps compare pieces).

### Notes
- No schema/migration change — weapon durability reuses the existing `AddGearCondition` columns.
- All design numbers (curves, prices, iron amounts, durability endpoints, dull %, button names) were settled via multiple-choice Q&A with the user.

## Session N+13 — 2026-05-18 (Currency rename gold→silver, capital polish, plot harvest picker, combat round counter)

### Goal
Post-launch polish based on live-play feedback. The previous Fortune Teller phase exposed several rough edges: in-game currency word "gold" felt off, trader UX had too many buttons per item, player got "stuck" after a buy/sell when the photo bubble scrolled away, no `/menu` discoverability, plot harvest dumped to warehouse without choice, combat lacked any sense of "how many rounds in".

### What was done

**Currency rename — gold → silver (in code) / silvers / срібники (player-facing)**
- Schema-level rename via new `RenameGoldToSilver` migration (raw SQL `ALTER TABLE users RENAME COLUMN gold TO silver`; revert reverses). Existing balances survive untouched. Historical `AddGameStats` migration left intact (never edit history).
- `User.silver` Swift field + matching `@Field(key: "silver")`. Init / dev-reset both updated.
- 8 catalog / service identifiers renamed: `EstateUpgradeStep.silverCost`, `TavernFoodListing.priceSilver`, `TraderListing.sellPacketSilver`/`buyPacketSilver`, `FortuneEffect.oneShotSilver`/`randomSilverPositive`/`randomSilverNegative`, `FortuneService.OneShotApplied.silverDelta`. Result-enum cases renamed: `TraderService.{SellResult.success.silverGained, BuyResult.success.silverSpent, BuyResult.notEnoughSilver}`, `TavernService.BuyDishResult.{success.silverSpent, notEnoughSilver}`, `FortuneService.DrawResult.notEnoughSilver`, `EstateUpgradeService.UpgradeResult.insufficientSilver`. Comments + local vars swept (`silverLabel`, `silverSuffix`, `silverOK`, `silverMark`, `totalSilver`).
- Locale keys + values: `profile.gold→profile.silver`, `capital.trader.gold_balance→silver_balance`, suffix `g`/`з` → `s`/`с` (then removed entirely, see below), narrative ("glory and gold"→"glory and silver" / "славу й срібло"; "win a few coins" → "пару срібників"; "For a few coins" → "За кілька срібників"). Fixed leftover UK `−25 gold` on Tower card.

**Trader UI: 2-row → 1-button flatten + Food/Materials category split**
- Two-step rebuild driven by live play. First pass: collapsed the 2-row layout (`[icon name · price]` info + `[💸 ×1][✏️ N]` action) into a single button per item that opens the bulk-N prompt directly. Removed `trader:info:` modal, `trader:sell:` / `trader:buy:` ×1 callbacks (~50 LoC). Buy label: `[icon name · 🪙 price]`. Sell label: `[icon name · 🎒 qty · 🪙 price]` (bag count preserved).
- Second pass: added Food/Materials category split inside Buy/Sell to mirror Inventory's "categories first" UX. Existing `editToBuyList`/`editToSellList` repurposed to render the category picker; new `editToBuyItems(category:)`/`editToSellItems(category:)` for filtered lists. Callbacks `trader:buy:food` / `trader:buy:materials` / `trader:sell:food` / `trader:sell:materials` with static `traderCategory(slug)→ItemType?` mapper (only `food`/`materials` recognised; everything else swallowed for stale-callback safety). `handleTraderBulkInput` post-action refresh derives category from `ItemCatalog.find(itemId)?.type` so the player stays on the same category after each transaction.
- 4 deleted locale keys (`silver_short`, `button.buy_one`, `button.sell_one`, `button.bulk_n`); 3 added (`cat.food`, `cat.materials`, `button.back_to_categories`).

**Currency display: 🪙 prefix everywhere, no letter suffix**
- All button labels: `🪙 N` instead of `Ns`/`Nс`. Tavern wager buttons (`🪙 10` instead of `🪙 10с`), tavern menu food labels, trader prices.
- All status banners: `sold for 🪙 50`, `Won +🪙 5`, `Lost −🪙 5`, `Wager: 🪙 10`. Fortune cards 10/16/20/21 buff_desc unified: `+🪙 30 or −🪙 15`, `−🪙 25`, `−🪙 20, +75 XP`, `+🪙 20, full HP and Vigor`.
- `silverSuffix` local var removed from 4 keyboard functions.

**Lingo emoji-adjacent-%{var} rule rediscovered + documented**
- The "leading supplementary-plane emoji breaks `%{var}` parser" rule ALSO bites when the emoji is INSIDE the template but immediately adjacent to a `%{var}`. Symptom: literal `%{silver}` rendered after the 🪙.
- Pre-build pattern adopted: locale template loses the inline emoji/sign; Swift call site passes interpolation values like `"🪙 \(silver)"`, `"+🪙 \(wager)"`, `"−🪙 \(wager)"`.
- Same rule re-confirmed twice during the session — caught `combat.round` (leading 🌀 + `%{n}`) and `estate.plot.harvest.where_prompt` (leading 🚜 + `%{slot}`/`%{yields}`) with a Python audit script. Both fixed by moving emoji into Swift call sites.
- Audit script (`python3 ... ord(v[0]) >= 0x1F000 / re.finditer(r'(.)%\{', v)`) ad-hoc, not committed.

**`/menu` command + bot menu registration**
- `/menu` registered as alias for the existing `/buttons` handler in `GlobalCommandsController` — re-attaches the current controller's reply keyboard.
- New bot-startup call in `configure.swift`: `bot.setMyCommands(...)` twice (en + uk) with `[menu, help, settings]`. Surfaces commands in Telegram's hamburger menu (the ≡ button left of the input field). Discoverable escape hatch for stuck players + cross-device kb mismatch.
- 3 new locale keys for command descriptions.

**Banner reply-keyboard anchor**
- `postStatusBanner(_:context:replyMarkup:)` gained an optional `replyMarkup:` param. Trader/tavern result banners (sold/bought/not-enough/bag-full/wager-lost-on-roll/fortune-error) now attach a `[🔙 До столиці]` inline kb via a new `backToCapitalBannerKB(lingo:locale:)` helper. Player gets a visible nav button after every action even when the trader/tavern photo bubble has scrolled out of view. Other banner callers (inventory, estate, exploration) still call the no-arg overload.

**Estate / Inventory unknown callback forwarding (pstyle latent bug fix)**
- `EstateController.onCallbackQuery` and `InventoryController.onCallbackQuery` used to `return false` for callbacks not matching their own prefix (`estate:*` / `inv:*`), which surfaced "Unsupported content type" whenever the player tapped a profile-style switcher (`pstyle:N` owned by MainController) from those routerNames. Both now forward unknown callbacks to `MainController.onCallbackQuery` — same fix already in place on `CapitalController`.
- Cross-device kb sync was already covered: every controller's `unmatched` already re-renders its own main screen when a stale text from another controller's reply kb hits the wrong routerName. `/menu` adds a manual override on top.

**Tutorial trader hint (one-shot post-first-expedition)**
- New `User.tutorialTraderHintShown: Bool` field (DB column `tutorial_trader_hint_shown`, default false) + new `AddTutorialTraderHint` migration.
- Flag flipped to true on the first clean `ExplorationController.handleHomeReached` (active-mode Step Back to home). Death and force-end paths don't trigger it.
- `User.init` defaults false; `resetDevProfile` sets true so dev iteration doesn't see hint on every reset (flip in Postico to retest).
- New locale `tutorial.trader_hint` × 2.

**Env-driven `projectPath`**
- `Swift/configure.swift`: `public let projectPath = ProcessInfo.processInfo.environment["ROI_PROJECT_PATH"] ?? "/Users/cosmos/RestOfIryna"`. Pi deploy can set the env var in systemd `Environment=` / `.zshenv` without merge conflicts. Must live in real shell env, not `.env` (`.env` is loaded later, using this very path).

**Combat round counter**
- New `combat_round: Int?` field on `ExplorationState` + `AddCombatRound` migration.
- `beginCombat` sets to 0; `finishRound` bumps before render so the first action shows "Раунд 1"; `endCombat` clears.
- Status card surfaces `🌀 Раунд N` line when `> 0` (intro/encounter card stays clean).
- 🌀 prepended in Swift (Lingo rule).

**Plot harvest destination picker**
- `PlotService.HarvestDestination` enum (`.bag` / `.warehouse`) + new parameter on `harvest(_:to:for:on:)`. `HarvestResult.success(...)` now carries the chosen destination; new `.bagFull(primary:bonus:free:need:)` case is atomic — nothing moves, plot timestamp stays put so the yield is preserved for retry.
- `EstateController.handlePlotHarvest` repurposed to a picker: shows yield preview `+5 🪨, +1 🔩` + `[🎒 До сумки][📦 На склад]` + `[❌ Скасувати]`. Empty plots short-circuit with the existing `harvest_empty` toast.
- New `handlePlotHarvestTo(destination:...)` + callbacks `estate:plot:hvbag:<slot>` / `estate:plot:hvwh:<slot>`. Cancel uses existing `estate:plot` to re-render the plot list. Bag-full surfaces as modal alert + leaves picker on screen so player can switch to warehouse with one tap.
- Bag preflight: per-unit `slotsUsed + total <= slotCap` (dev bypass via `user.isDeveloper`).
- Shared `formatYields(primary:bonus:...)` between picker preview and post-harvest banner (DRY).
- 7 new locale keys × 2 (where_prompt, button.to_bag / to_warehouse / cancel, harvested_to_bag, bag_full).

**Find-narrative emoji simplification**
- All 8 `exploration.find.<itemId>` keys × 2 locales: leading per-item emoji (🌲/🪨/🧱/🔩/🫐/🌰/🥔/🥚) replaced with ✨ — consistent "found something" marker matching the existing `loot.picked`/`loot.full` templates. Item icon still visible in the next-line `+N <icon> <name>` summary.

**Tavern wording fix**
- UK `capital.tavern.gamble.button.roll_dice`: "🎲 Кинути кубік" → "🎲 Кинути кубики" (player throws 2 dice per round, label was singular).

### Files added
- `Swift/Migrations/RenameGoldToSilver.swift` — raw-SQL column rename
- `Swift/Migrations/AddTutorialTraderHint.swift` — bool flag for one-shot trader hint
- `Swift/Migrations/AddCombatRound.swift` — nullable Int on `exploration_state` for round counter

### Files significantly touched
- `Swift/Controllers/CapitalController.swift` — trader flatten + categories, currency display, banner reply-kb anchor, fortune error banners
- `Swift/Controllers/EstateController.swift` — plot harvest picker (new handlers), pstyle forwarding
- `Swift/Controllers/CombatController.swift` — round counter
- `Swift/Controllers/ExplorationController.swift` — first-return trader hint trigger
- `Swift/Controllers/InventoryController.swift` — pstyle forwarding
- `Swift/Controllers/MainController.swift` — silver instead of gold in profile (3 styles)
- `Swift/Controllers/GlobalCommandsController.swift` — /menu alias handler
- `Swift/Helpers/TGBot+Extensions.swift` — `postStatusBanner` optional replyMarkup param
- `Swift/Models/User.swift` — silver field + tutorialTraderHintShown field
- `Swift/Models/ExplorationState.swift` — combat_round field + lifecycle hooks
- `Swift/Models/FortuneCatalog.swift` — silver field rename
- `Swift/Models/TraderCatalog.swift` / `TavernCatalog.swift` / `EstateUpgradeCatalog.swift` — silver field rename
- `Swift/Services/PlotService.swift` — HarvestDestination + new harvest signature + bagFull case
- `Swift/Services/TraderService.swift` / `TavernService.swift` / `FortuneService.swift` / `EstateUpgradeService.swift` — silver everywhere
- `Swift/configure.swift` — env projectPath, 3 new migrations, setMyCommands, resetDevProfile updates

### Build state
Build clean across all interim and final iterations.

### Design decisions (with user)
- Currency naming: EN = `silvers` (RPG-canon plural), UK = `срібники` (genitive plural `срібників` in declensions). Internal Swift identifiers renamed (full refactor + DB migration) rather than keeping `gold` as a non-destructive shim — the precedent of `User.vigor` (DB still `hunger`) was explicitly rejected for this rename because the in-game word changed meaningfully.
- Trader UI position of Food/Materials split: **inside** Buy/Sell (3 levels: trader → action → category → items), NOT in front of them.
- Banner reply-kb only on capital sub-actions: inventory/estate/exploration banners don't need it (their UX doesn't suffer from scroll-away).
- Emoji-before convention for currency: `🪙 N` on buttons, `±🪙 N` on signed status text — single visual convention everywhere.

---

## Session N+12 — 2026-05-17 (Phase 6.4 Fortune Teller — 22 Major Arcana, 6h buff / 24h cooldown)

### Goal
Land the third capital subsystem — the Ворожка (fortune teller). Player pays gold, draws one of 22 tarot Major Arcana cards (real artwork supplied by user), gets a buff or debuff for 6 hours. Cooldown between draws is 24 hours, so up to 1 draw/day. Card meaning + buff description shown under the card on reveal. Active card line surfaces in the profile.

### What was done

**Models & state**
- New `Swift/Models/FortuneCatalog.swift` — `FortuneEffect` struct (single struct with 14 optional fields covers stat bonuses, multipliers, one-shots, Wheel-style random) + `FortuneCard` (id / nameKey / meaningKey / buffDescKey / effect) + `FortuneCatalog` (22 entries, `drawPrice=10g`, `buffDurationSeconds=6h`, `cooldownSeconds=24h`).
- New `Swift/Services/FortuneService.swift` — `draw(for:on:) -> DrawResult` (success / onCooldown / notEnoughGold). Cooldown check via `lastFortuneDrawAt`; debits 10g; uniform random pick; applies one-shot effects (gold delta with min-clamp, Wheel 50/50 roll, XP via `user.grantXP`, HP/Vigor restore); stamps `activeFortuneCardId` + `activeFortuneExpiresAt` (now + 6h) + `lastFortuneDrawAt` (now). `OneShotApplied` snapshot returned for UI reveal text.
- New `Swift/Migrations/AddFortuneFields.swift` — adds `active_fortune_card_id` + `active_fortune_expires_at` to users.
- New `Swift/Migrations/AddFortuneCooldownField.swift` — adds `last_fortune_draw_at` to users (separates the 24h cooldown from the 6h buff window — added after the design call to split them; both migrations registered in `configure.swift`).
- `User.swift`: 3 new fields + init defaults + `activeFortuneEffect` computed (nil after expiry, returns the catalog effect otherwise) + `fortuneSecondsRemaining(now:)` (buff timer) + `fortuneCooldownRemaining(now:)` (draw timer).

**Effect hooks (5 sites)**
- `User.effectiveAttack/Defense/Crit/Dodge/Accuracy` — add fortune additive bonuses on top of base + gear − vigor penalty.
- `User.grantXP(_)` — multiply incoming amount by `activeFortuneEffect?.xpMultiplier ?? 1.0` before processing level-ups + stat growth.
- `ExplorationService.rollStep` — apply `lootChanceMultiplier`: shift loot weight by the multiplier, compensate from `nothing` bucket so total = 100 (encounter/trip untouched — Fool's luck doesn't summon a bear).
- `VigorService.drain(user:action:multiplier:)` — multiply stance multiplier by `vigorDrainMultiplier` so Chariot's −25% / Hanged Man's −50% / Devil's ×1.5 compose with existing stance buffs.

**UI**
- `CapitalController.showFortune` replaces `renderLocation(.fortune)`. Three render states: can-draw (price + balance + `[🔮 Тягнути карту]`), cooldown-with-buff (`Активна: <name> · ефект ще HH:MM / Нова карта через: HH:MM`), cooldown-only (`Карти втомились. Нова карта через: HH:MM`). `[🔙 До столиці]` always visible — never lets the player get stuck on the screen (e.g. zero gold).
- `renderFortuneReveal` — `sendScenicPhoto` with the drawn card's PNG + caption (🔮 + name + italic meaning + buff description + one-shot deltas like "+30 gold · balance 145" / "HP and Vigor restored" / "+75 XP" + 6h countdown for duration cards) + `[🔙 До столиці]` button.
- Callback dispatch: `fortune:draw` runs `handleFortuneDraw`; `capital:back` (renamed from `fortune:back`, aliased for backward compatibility) calls `showCapital`.
- Profile fortune line (`🔮 <Card> · HH:MM`) added to all 3 profile styles in `MainController.renderProfile`. Appears only when buff is still active (uses `fortuneSecondsRemaining`); 🔮 prepended in Swift to dodge Lingo's leading-emoji + `%{var}` parser bug.

**Bugfix: "Unsupported content type" when switching profile style from capital**
- `CapitalController.onCallbackQuery` was returning `false` for unknown callback prefixes (`pstyle:`, stale `explore:`/`combat:` from old messages), which fell through to `Router.unsupportedContentType` ("Unsupported content type."). Now forwards everything unknown to `MainController.onCallbackQuery` which handles those prefixes and has a default "delete stale inline message" branch — quiet failure instead of shouting at the player.

**Reply-keyboard insurance (Telegram client UX quirk)**
- After a chain of inline-button messages, some Telegram clients (mobile especially) collapse the persistent reply keyboard — bot can't prevent this server-side. Mitigation: inline `[🔙 До столиці]` button added to tavern entry, trader Menu screen, and fortune entry. Tap calls `showCapital` → `sendWelcome` → sends scenic photo WITH `generateControllerKB` reply-keyboard markup → re-attaches the keyboard. Acts as a manual "show keyboard" reset.
- Unified locale key: `capital.button.back_to_capital` (replaces fortune-specific `capital.fortune.button.back`).

**PhotoCache PNG support**
- `sendScenicPhoto` now auto-detects MIME from the asset path's extension (.png → image/png, otherwise image/jpeg). Tarot cards ship as PNG (preserve sharp linework), other scenery as JPG. Telegram handles both fine; passing correct MIME lets the client pick a faster decode path.

**Assets**
- 22 tarot card PNGs in `Assets/capital/fortune/<id>.png` (e.g. `0_fool.png`, `1_magician.png`, ..., `21_world.png`) — each ~3MB original; Telegram client downscales to ~200KB jpeg on display; PhotoCache reuses file_id after first upload so byte transfer is one-time.
- `Assets/capital/fortune.jpg` — entry-screen portrait of the fortune teller.
- `Assets/capital/tavern.jpg` — replaced with new artwork (innkeeper portrait variant).

**Lore (user-supplied + my designed buffs)**
- Card names + one-line meaning per card per locale (from user's dict, kept verbatim in UK). 22 × 2 × 3 keys (name / meaning / buff_desc) = 132 card locale entries.
- Fortune teller intro: full atmospheric prose from user + in-character quote ("«Сідай, наміснику. Карти знають твоє ім'я ще з ранку...»").
- Tavern body: existing atmospheric prose + new innkeeper quote ("«Заходь, наміснику! Кухоль еля чекає...»").
- UK: 4 instances "мандрівнику" → "наміснику" (Шинок + Ворожка, x2 each).
- EN: 4 instances "traveller" → "Governor" (same locations).

**Effect distribution (22 cards)**
- 7 pure 24h-window buffs (1 Magician, 3 Empress, 7 Chariot, 8 Strength, 14 Temperance, 17 Star, 19 Sun)
- 3 pure 24h-window debuffs (13 Death, 15 Devil, 18 Moon)
- 7 mixed 24h (good + bad, trickster pulls: 0 Fool, 2 Priestess, 4 Emperor, 5 Hierophant, 9 Hermit, 11 Justice, 12 Hanged Man)
- 2 positive one-shots (6 Lovers, 21 World)
- 2 mixed one-shots (10 Wheel, 20 Judgement)
- 1 negative one-shot (16 Tower)
- Outcome: 41% guaranteed-positive draws, 18% pure-bad, 41% trade-off. Tarot as cosmic balance, not casino tilted in player's favour.

### Design decisions (with user)
- **Effect duration vs cooldown**: started at 4h for both, then user said lore should say 6h. Then realised cooldown and buff should be different — bumped cooldown to 24h (one card per day, dramatic) while buff stays 6h (impactful over an active session, not a full day's lock).
- **Variant B for effect mix** (clear ladder, 3 trickster + 7 mixed) over Variant A (heavy buffs, casino-style daily blessing) and C (massive variance). User specifically asked to lean more toward debuffs/mixed.
- **One-shot vs duration handling unified into one struct** (FortuneEffect with optional fields) — cards set only their slice; UI uses `hasDurationEffect` to decide whether to render the countdown line.
- **Reply-keyboard insurance via inline Back button** (not via re-sending the keyboard on every scenic photo) — the latter would add a second message per scenery send (Telegram only allows ONE reply_markup type per message). Inline Back is cleaner and double-duty: navigation + reply-keyboard reattach on tap.
- **`capital:back` unified callback** (was `fortune:back`-specific) so trader and tavern entries reuse the same handler.
- **Profile fortune line at the bottom of every style** (1/2/3) — last line so the ephemeral "today's card" stands out from structural stats. Skipped entirely when no active buff (cooldown without buff = nothing shown).

### Files touched
- New: `Swift/Models/FortuneCatalog.swift`, `Swift/Services/FortuneService.swift`, `Swift/Migrations/AddFortuneFields.swift`, `Swift/Migrations/AddFortuneCooldownField.swift`, `Assets/capital/fortune.jpg`, 22× `Assets/capital/fortune/<id>.png`.
- Modified: `Swift/Models/User.swift` (3 fields + init + 2 computed helpers + grantXP hook + activeFortuneEffect extension), `Swift/Services/ExplorationService.swift` (loot weight multiplier hook), `Swift/Services/VigorService.swift` (effective-stat fortune hook + vigor-drain composition), `Swift/Controllers/MainController.swift` (profile fortune line), `Swift/Controllers/CapitalController.swift` (massive — showFortune + 3-state render + reveal + callback dispatch + onCallbackQuery forwarding fix + back-button insurance for trader/tavern), `Swift/Helpers/PhotoCache.swift` (PNG MIME), `Swift/configure.swift` (2 migrations + dev reset includes fortune fields), `Localizations/en.json` + `Localizations/uk.json` (+82 keys per locale: 13 UI + 22 × 3 card keys + 1 generic back-button), `Assets/capital/tavern.jpg` (replaced).

### Build / tests
- `swift build` clean.
- Locale parity 642/642 (was 561 at session start).
- Live dogfooded by user across multiple iterations — drew cards in chat, switched profile style from capital (verified bug fix), navigated tavern/trader/fortune with inline Back buttons.

### Open items / next steps
- Flip `TravelService.testMode = false` before shipping (still 2 s per minute).
- 3 capital locations still stubs: Market (player-to-player), Arena (PvP), Master (weapon repair / reforge / enchant — natural next as the gold sink that closes the loop).
- Question for later: should we add Estate / Inventory same `onCallbackQuery` forwarding fix to MainController so `pstyle:` works from estate/inventory routerName too? Not user-reported yet but probably the same latent bug.

---

## Session N+11 — 2026-05-17 (Phase 6.3 chat-cleanup infra — PhotoCache + sendScenicPhoto)

### Goal
After shipping Trader + Tavern + welcome-on-arrival, the user spotted that every navigation to a capital/estate location re-uploads the full JPEG bytes AND leaves a stale photo bubble in chat — a 20-tap test session was filling the chat with ~20 duplicate trader photos. Concern compounded by upcoming Fortune Teller which will need many images for daily blessings. Stand up the infrastructure to fix this before adding any more photo-heavy features.

### What was done
- **New `Swift/Helpers/PhotoCache.swift`** — actor with `[assetPath: fileId]` map. First-time `bot.sendPhoto` uploads the JPG bytes and Telegram returns a `file_id`; the helper grabs the largest `TGPhotoSize.fileId` from the response and caches it. Every later send for that asset uses `.fileId(cached)` instead of `.file(InputFile)` so no JPG bytes cross the wire. Cache is in-memory only (in-memory `actor`); lost on bot restart, refills naturally on next-send. file_id is a global Telegram reference so one cache serves all users.
- **`sendScenicPhoto(assetPath:caption:parseMode:replyMarkup:toUser:bot:)`** — top-level free function in the same file. Wraps the PhotoCache logic plus chat-cleanup:
  - Before sending, deletes the user's previous "scenery" photo (tracked in new `EphemeralChatState.lastSceneryPhotos`)
  - Picks file_id from cache if present, else uploads + caches the id from the response
  - Captures the new message ID into the scenery slot for the next call to clean up
  - Falls back to `bot.sendMessage(text:)` when the asset is missing entirely — same scenery-slot tracking so the fallback gets cleaned up too
- **`EphemeralChatState`** — added `lastSceneryPhotos: [Int64: Int]` + `setLastSceneryPhoto` / `takeLastSceneryPhoto` API. Single slot per user; capital + estate share it.
- **Five callsites converted** to `sendScenicPhoto`:
  - `CapitalController.showTrader` (was manual photo+text fallback)
  - `CapitalController.showTavern` (was manual photo+text fallback)
  - `CapitalController.renderLocation(_:)` (covers all 4 location stubs — Market/Arena/Fortune/Master — via the `Assets/capital/<id>.jpg` auto-loader)
  - `CapitalController.sendWelcome(toUser:bot:lingo:)` (static — called from request handlers AND from `TravelService.pushArrival` on capital arrival)
  - `EstateController.showEstate` (per-level artwork at `Assets/estate/level_<N>.jpg`)
- **CLAUDE.md updated** with new convention: `sendScenicPhoto` is the default photo path for any location backdrop going forward; direct `bot.sendPhoto` is reserved for one-shot narrative art (registration King's Oath, future lore beats) that must persist in chat history.

### Design decisions (with user)
- **Variant B chosen** over file_id-only (A) and editMessageMedia (C). User wanted both bandwidth + clutter fixed; A doesn't fix clutter, C leaves the photo at original position which feels weird after navigation. B = file_id cache + delete-before-send is the "new content arrives at bottom, previous deleted" pattern that matches natural chat flow.
- **One scenery slot per user across capital + estate**: a single `lastSceneryPhotos[telegramId]` slot. Switching capital → estate → capital deletes whichever was last. Simpler than per-location slots; players only ever care about the current scene.
- **Sub-screens (trader Buy/Sell list, tavern Menu/Wager screen) keep using `editMessageCaption`**: they don't touch the scenery slot because they reuse the existing photo message. Only top-level entries (welcome / showTrader / showTavern / showFortune / renderLocation / showEstate) consume the slot.
- **In-memory cache, no persistence**: PhotoCache is process-lifetime. Restart = re-upload-once-then-cache. Was tempting to persist file_id to DB for cross-restart durability but added complexity (migration, garbage collection on asset rename) not worth it — first re-upload per asset is cheap and players probably won't notice.
- **Registration art (`kings_charter.jpg`, `<class>_estate.jpg`) NOT converted**: those are one-shot lore beats sent once per user during onboarding; players should be able to scroll up to revisit. Direct `bot.sendPhoto` stays. Could later add a `sendCachedPhoto` variant (file_id cache without scenery cleanup) for cross-user bandwidth savings, but minor benefit for V1.
- **Fallback path** (asset missing) still tracks in the scenery slot so it gets cleaned up like any other scenery message. Otherwise text fallbacks would accumulate.

### Files touched
- New: `Swift/Helpers/PhotoCache.swift` (actor + helper)
- Modified: `Swift/Helpers/EphemeralChatState.swift` (+ lastSceneryPhotos slot), `Swift/Controllers/CapitalController.swift` (4 callsites), `Swift/Controllers/EstateController.swift` (1 callsite), `CLAUDE.md` (+ scenery photos convention), `README.md` (Helpers section entry), `.memory/file-map.md` (+ PhotoCache entry + EphemeralChatState update), `.memory/status.md` (+ Phase 6.3 line)
- 0 new locale keys, parity stays at 561/561

### Build / tests
- `swift build` clean.
- Live dogfood: pending — user will test next chat session.

### Open items / next steps
- Fortune Teller (deferred from this session, blocked on this infra) — now ready to build. Design proposal already in chat: 6 one-time blessings, 24h cooldown via `User.lastFortuneAt`, free.
- Optional: `sendCachedPhoto` variant for registration art (file_id cache without scenery cleanup) — small bandwidth win for new players (registration JPG bytes uploaded once per bot lifetime instead of once per user).
- Optional: persist PhotoCache to disk/DB for cross-restart durability. Low priority.

---

## Session N+10 — 2026-05-17 (Phase 6.1 Trader + 6.2 Tavern + economy v2 rebase)

### Goal
Fill in the first two capital locations with real subsystems and rebase the gold economy on a "1 pebble = 1 gold" anchor so the numbers stop feeling fractional. Crammed three iterations into one session because each built on the previous: Trader first, then Tavern (food + dice + darts), then a full economy re-tier, then bulk-N polish on the Trader.

### What was done

**Phase 6.1 — Crамар (Trader)**
- New `TraderCatalog` + `TraderService`. 11 listings cover every foraging/beast drop + iron + iron_ingot. Trader uses asymmetric packets `(sellPacketQty, sellPacketGold)` / `(buyPacketQty, buyPacketGold)` so cheap items could trade in 5-unit packs back when pricing was fractional. After the v2 rebase (below) every packetQty = 1.
- Initial pricing: Option B "utility-weighted" (5 tiers), then re-anchored at pebble = 1g/unit. Final per-unit table:
  - Tier 1 (1g/2g): 🪨 pebble · 🫐 berries · 🌰 nuts
  - Tier 2 (2g/4g): 🌲 lumber · 🧱 clay
  - Tier 3 (3g/6g): 🥔 potato · 🥚 duck_egg · 🦴 hide
  - Tier 4 (5g/10g): 🥩 raw_meat
  - Tier 5 (10g/20g): 🔩 iron
  - Crafted (100g/200g): 🔳 iron_ingot
  - 2× sell:buy spread is flat across the catalogue.
- `TraderService` API ended at `sell(itemId, quantity, ...)` / `buy(itemId, quantity, ...)` (`sellAll` was added then dropped — the `[✏️ N]` prompt covered the case). Typed result enums (`SellResult.success / .notEnoughInBag(have:need:) / .unknownListing`; `BuyResult.success / .notEnoughGold(have:need:) / .inventoryFull(free:need:) / .unknownListing`) drive precise UI banners. Atomic preflight: failed buy never half-applies gold debit + add.
- Trader UI is two-step:
  - Entry menu (photo + `Assets/capital/trader.jpg` + lore caption) with `[💰 Купити][💸 Продати]`
  - Buy / Sell lists edited in place (`editMessageCaption` since the host is a photo) — info-label row `[🪨 Pebble · 🎒N · 1g]` (tap opens item description modal via `trader:info:`) above an action row `[💸 ×1] [✏️ N]` (sell — extra `[💸 ×All]` button was added then removed per user feedback as "looks unneeded")
  - Sell list is filtered to items the player has any of (qty ≥ 1) so no dead-tap rows
  - `[✏️ N]` opens a `EphemeralChatState.PendingTraderTransfer` flow (warehouse-style): bot sends prompt "Скільки X купити/продати?" + `[❌ Скасувати]`, `unmatched` intercepts the next text update and parses it. Invalid input (non-numeric/≤0) edits the prompt in place with "❌ Введи додатне число" and keeps pending; validation failure (not enough / bag full / not enough gold) deletes prompt + ❌ banner + refreshes the list; success deletes prompt + ✅ banner + refreshes.
- `inv:*` callbacks forwarded from `CapitalController.onCallbackQuery` to `InventoryController` after a bugfix — entering inventory from capital previously flipped routerName to "inventory" and locked the player out of capital nav. Fix: keep routerName at "capital" + forward inventory callbacks. Same pattern as MainController's existing `explore:*`/`combat:*` forwarding.

**Phase 6.2 — Шинок (Tavern)**
- New `TavernCatalog` + `TavernService`. 7 dishes (all RecipeCatalog kitchen recipes, no scroll-gate — tavern bypasses recipe learning). Final prices (post-rebase): 20/30/50/60/80/100/200g. Tavern food sold via gold→inventory; bag-full surfaces as `❌ Сумка повна`.
- Dice + darts gambling. After two iterations (manual emoji panel — then bot-driven per user feedback "Telegram doesn't let bots author messages as the player"), settled on **button-driven bot-rolls-all** with text labels for attribution:
  - Wager tap → edit caption to "Ставка X. Готовий?" + `[🎲 Кинути кубік]` + `[❌ Скасувати]`. Gold not debited yet — Cancel before Roll is free.
  - Roll tap → debit + `runRound`: sends "Ти кидаєш..." text → bot sends N dice (2 for dice, 1 for darts) via `sendDice(emoji: "🎲"|"🎯")` (Telegram returns 1-6) → sleeps 4 s → sends "Шинкар кидає..." → bot sends N more dice → sleeps 4 s → result message with replay/back inline buttons. Per-user dispatch is serialised so the ~10 s round only blocks the playing player.
  - Outcomes: higher sum wins (+1× wager net gain), lower loses (debit kept), tie refunds. Pure helper `TavernService.resolveWager(playerScore:houseScore:)` returns `WagerOutcome (.win / .lose / .tie)`.
  - Result message buttons: `[🔄 Зіграти ще раз]` (same wager, runs another round on the same text host) + `[🔙 До шинка]` (sends fresh photo entry since text→photo edit would lose the image).
  - Wager tiers `TavernCatalog.wagerTiers = [10, 25, 50]` (post-v2-rebase; were 1/3/5 pre-rebase).
- Tavern entry photo (`Assets/capital/tavern.jpg`) + atmospheric lore "Шинок «Королівська печатка»...". Menu / Dice / Darts sub-screens all edit the SAME message caption (image persists across the whole tavern flow) via shared `editTraderScreen(messageId:isPhoto:...)` helper which picks `editMessageCaption` for photo hosts and `editMessageText` otherwise.

**Phase 6.0 polish landed in the same session**
- Capital welcome rewritten + `Assets/capital/welcome.jpg` artwork. Arrival from `TravelService.pushArrival` now sends the full welcome (photo + caption + capital reply-keyboard) instead of a separate "you've arrived" line — the screen showing up communicates the arrival.
- Trader: `Assets/capital/trader.jpg` + the full merchant lore in `capital.trader.intro` (italic-quoted closing line embedded in the template, not wrapped in Swift, so other render sites can drop it as-is).
- Tavern: `Assets/capital/tavern.jpg` + atmospheric body text. `renderLocation` now auto-loads `Assets/capital/<location-id>.jpg` for any of the 6 locations — drop a JPG in and it picks up automatically. Future market/arena/fortune/master art just needs the file.
- UK renames: Торговець → Крамар, Гадалка → Ворожка, Таверна → Шинок (button + location title + all stable banners). EN unchanged.
- Bugfix: `🐎` leading emoji + `%{remaining}` interpolation in `travel.*` templates broke Lingo's `%{var}` parser. Moved 🐎 prefix to Swift call sites in `CapitalController.renderTripStarted` and `renderTravelInProgress`. Standing convention: leading supplementary-plane emoji + %{var} = prepend emoji in Swift.

**Economy v2 rebase (mid-session pivot)**
- User: "Currently pebble sells 5-for-1g. Let me re-anchor at 1 pebble = 1g and rescale everything." Picked Option B "clear ladder" — each tier visibly doubles its sell price; iron lands at 10× pebble (was 5× under fractional pricing) to reward true rarity (weight 2 vs staples 10).
- Side effect: all packetQty values dropped to 1 (no more "must accumulate 5 to sell" friction). UI labels adapt: shows just `Xg` when packet = 1, falls back to `qty·Xg` for legacy multi-unit packets (kept for forward compat, currently unused).
- Tavern food rescaled (~5× old prices): 3/4/7/9/10/12/25 → 20/30/50/60/80/100/200g. Wagers 1/3/5 → 10/25/50g.

### Design decisions (with user)
- **Trader UX two-step (menu → buy/sell list)**: chose over single-list-with-both-buttons because the single-list version cluttered every row with redundant info. User: "After tap of Crамар, inline buttons Buy/Sell appear. Then Buy = price list, Sell = only what player has." Implemented exactly that.
- **Trader sell list filter**: only items with bag qty ≥ 1 shown. Dead rows would add visual noise without value.
- **Trader Sell-All button removed**: added per Option D (Hybrid) initially, removed when user said "looks unneeded — `[✏️ N]` covers the bulk case". Saved a button slot per row.
- **Tavern gambling = bot-rolls + labels** (not player-sends-own-dice): Telegram's Bot API doesn't allow bots to send messages on behalf of users — `sendDice` always renders left-side from the bot. User accepted this limit and went with text labels ("Ти кидаєш..." / "Шинкар кидає...") for attribution + button-driven roll for agency.
- **Tavern wager not debited until Roll button tapped**: gives players a free Cancel between wager and roll. Discovered during the iteration on the manual-dice approach.
- **Darts = 1 throw per side** (not 2): user request — "the dart command is 1 time". Reflected in `runRound` via `throwCount = emoji == "🎲" ? 2 : 1`. Score-line locale split into `.score_line_pair` (dice) and `.score_line_single` (darts).
- **Economy Variant B over C**: clear doubling ladder, iron at 10× pebble. Other variants offered: A (faithful 5× scale, tier-2/tier-1 collapsed to same price) and C (premium scale with bigger numbers, breaks pebble baseline).
- **Photo persists across all trader/tavern sub-screens**: `editMessageCaption` keeps the merchant/innkeeper face as a constant visual header for the whole interaction.

### Bugs fixed
- **Inventory-from-capital locked the player out of capital nav**: `CapitalController.onInventory` was flipping `session.routerName = "inventory"` after `showInventory`, so capital reply-keyboard taps routed to `InventoryController`'s unmatched (which re-rendered inventory). Fix: drop the routerName flip (keep it at "capital") + forward `inv:*` inline callbacks via `CapitalController.onCallbackQuery`. Same cross-controller-callback pattern that MainController already uses for `explore:*`/`combat:*`.
- **`%{remaining}` interpolation broke in 3 travel templates**: leading 🐎 surrogate-pair emoji + `%{var}` in the template. Audit caught only those 3 (the other ~22 new keys without interpolation are safe). Convention reinforced in `.memory/localization.md` (referenced from many code comments).

### Files touched
- New: `Swift/Models/TraderCatalog.swift`, `Swift/Models/TavernCatalog.swift`, `Swift/Services/TraderService.swift`, `Swift/Services/TavernService.swift`, `Assets/capital/welcome.jpg`, `Assets/capital/trader.jpg`, `Assets/capital/tavern.jpg`.
- Modified: `Swift/Controllers/CapitalController.swift` (massive — trader UI + tavern UI + gambling + bulk-N prompt flow + callback dispatch + inventory-forward bugfix). Localizations +76 keys per locale.

### Build / tests
- `swift build` clean throughout (every iteration).
- Locale parity ends at 561/561 (was 515 at session start).
- Live dogfooded by user across all 4 iterations — trader buy/sell, tavern menu/dice/darts, bulk-N prompts, ✏️ N cancel, inventory-from-capital fix.

### Open items / next steps
- Flip `TravelService.testMode = false` before shipping (still 2 s).
- 4 capital locations still stubs: Market (player marketplace), Arena (PvP), Fortune Teller (daily blessings / hint quests), Master (weapon repair / reforge / enchant). Master is the natural next addition since it's a gold sink that closes the loop (gold → upgrade-related convenience).
- Tavern stays as-is for V1 — gambling games could grow class-accuracy bonuses (archer favored at darts) and varying house edge.
- No tutorial prompt directs the player to the capital yet — currently they discover it by tapping the existing main-menu button.

---

## Session N+9 — 2026-05-16 (Phase 6.0 Capital MVP — travel + nav skeleton)

### Goal
Stand up the capital as a real second hub. Travel from estate takes 2 min (placeholder); inside the capital, six MVP locations on a reply-keyboard: Market, PvP Arena, Trader, Fortune Teller, Master, Tavern. All locations are atmospheric stubs for now — the point of this patch is the navigation skeleton + travel timer plumbing, so subsequent Phase 6.x patches can fill in one location at a time without touching infrastructure.

### What was done
- **New `TravelState` Fluent model** + `CreateTravelState` migration. One row per in-flight trip; unique per user, cascade-deletes with the user, fields `destination` ("capital" | "estate") + `ends_at`. Helpers (`current` / `begin` / `end` / `allInflight`) mirror `ExplorationState`.
- **New `TravelService`** (Task.detached + Task.sleep pattern, mirrors `PassiveExpeditionService`). `start(user, destination, ...)` validates guards (`StartFailure` enum: `dead` / `starving` / `onExpedition` / `alreadyTraveling` / `alreadyAtDestination`), persists the trip, arms the timer. On arrival: flips `user.location`, sets `user.routerName` to the matching controller (capital ctrl on arrival in capital, main ctrl on arrival at estate), deletes the trip row, pushes the arrival message with the destination's reply-keyboard. `rescheduleInflight` on bot startup re-arms every in-flight trip. `testMode = true` (2 s per minute = 2-second trip); flip before shipping.
- **New `User.location` stored field** + `AddUserLocation` migration. Default "estate". Flipped only by TravelService — never by a controller. Drives the location-aware branches in Estate / Capital / Exploration entry points.
- **CapitalController rewritten** (from stub). Reply-keyboard with 6 location buttons (4 rows × 2 cols + utility row [Inventory] [Profile] + leave row [🏡 До маєтку]). `Location` enum drives buttons + localization keys. Each location handler (`onMarket` / `onArena` / ...) calls `renderLocation(_)` — sends an atmospheric stub body with the same reply-keyboard kept intact, so hopping between locations is one tap. `showCapital(context)` is the single public entry: branches expedition→block / travel→countdown / at-estate→start trip / at-capital→render welcome. Static `beginTrip(destination:context:)` is the shared trip-start orchestrator (TravelService call + routerName flip + render + per-error banner) used by `showCapital`, `onLeave`, and `EstateController.showEstate`. Static `showTravelInProgress(context:trip:)` is the shared countdown banner used by Main / Estate / Exploration travel guards.
- **MainController updates**: `onEstate` / `onCapital` / `onExplore` all call `guardedByTravel(context:)` first → shows countdown banner + returns true if in flight. `onCapital` calls `showCapital` instead of the old `showStub`. Same for `EstateController.onCapital` + `InventoryController.onCapital`.
- **EstateController.showEstate** adds two new branches before the existing flow: travel→countdown, location=="capital"→`CapitalController.beginTrip(.estate, context:)` (return trip).
- **ExplorationController.showExploration** adds two new branches at the top: travel→countdown, location=="capital"→block with "wilderness only borders the estate" notice. Hunting from the capital is explicitly disallowed.
- **configure.swift**: registered both new migrations after `CreateLearnedTechniques`; added `TravelService.rescheduleInflight` call after `PassiveExpeditionService.rescheduleInflight`; added `user.location = "estate"` + `TravelState.end(for: user, ...)` to the resetDevProfile block.
- **45 new locale keys × 2 locales** (parity 515/515): `capital.welcome`, 6× `capital.button.{market|arena|trader|fortune|master|tavern}`, 6× `capital.location.<id>.title` + `.body`, `capital.button.leave`, `travel.to_capital.started` + `travel.to_estate.started` (interpolate `%{remaining}`), `travel.arrived.capital` + `travel.arrived.estate`, `travel.in_progress` (interpolates `%{destination}` + `%{remaining}`), `travel.destination.capital` + `.estate` (for the `%{destination}` slot), `travel.cannot_start.no_hp` + `.no_vigor`, `exploration.blocked_in_capital`.

### Design decisions (with user)
- **2-minute trip duration** is the placeholder; will tune later. `testMode = true` makes it 2 s for dogfooding.
- **No cancel** — once you've set out, you wait it out. Decided via AskUserQuestion early in the session ("чесно з точки зору гри"); avoids the "speedrun by tap-tap-tap-tap" anti-pattern.
- **Guards on start**: HP > 0 AND vigor > 0. Death + starvation both block setting out (matches the "you can't even walk to the gates" fantasy).
- **Reply-keyboard nav, not inline** for the 6 locations. User asked mid-session ("Кнопки в столиці повинні бути не інлайн кнопками, а заміняти основні"). Original plan was inline buttons; refactored before any code shipped.
- **No 6-button "drilldown" hierarchy** — each location is a peer. Tapping any location swaps the message body; the keyboard never changes. No "back to capital root" — every location button is one tap away.
- **Utility buttons** (Inventory + Profile) kept on the capital keyboard so the player isn't forced back to main for them. Settings stays reachable via `/settings` but not promoted as a button (rare action).
- **Estate / Capital / Explore taps during travel** all show the same countdown banner. Inventory / Profile / Settings keep working (no narrative reason to block them).
- **/start always lands in main** regardless of location. Player can re-enter capital from main; `showCapital` detects `location == "capital"` and skips the timer.
- **Arrival flips routerName** so the player lands in the right reply-keyboard automatically (no extra tap needed).

### Files touched
- New: `Swift/Models/TravelState.swift`, `Swift/Services/TravelService.swift`, `Swift/Migrations/AddUserLocation.swift`, `Swift/Migrations/CreateTravelState.swift`.
- Modified: `Swift/Controllers/CapitalController.swift` (full rewrite from stub), `Swift/Controllers/MainController.swift` (3 guards + onCapital wiring), `Swift/Controllers/EstateController.swift` (2 guards in showEstate + onCapital wiring), `Swift/Controllers/ExplorationController.swift` (2 guards in showExploration), `Swift/Controllers/InventoryController.swift` (onCapital wiring), `Swift/Models/User.swift` (location field + init default), `Swift/configure.swift` (migrations + rescheduler + dev reset), `Localizations/en.json` + `Localizations/uk.json` (+45 keys each).

### Build / tests
- `swift build` clean, 0 warnings, 0 errors.
- Locale parity 515/515.
- Live dogfood pending — user will test in chat next session.

### Open items / next steps
- Flip `TravelService.testMode = false` before shipping (2 min real).
- Six per-location controllers / models are the natural Phase 6.x patches (Market: player marketplace; Trader: NPC vendor with rotating inventory; Arena: PvP matchmaking; Fortune Teller: daily blessings / hint quests; Master: weapon repair + reforge / enchant; Tavern: NPC quests + party recruiting).
- Tutorial flagging "you can travel to the capital" once estate hits some tier (T2? T3?) — currently no in-game prompt directs the player there.
- Question for later: should travel cost vigor? (Currently the trip is free; only the start guard checks vigor > 0.)

---

## Session N+8 — 2026-05-15 (Per-class basic Defend rebalance)

### Goal
Basic Defend used to share one mechanic across all three classes — chip damage (30% × ATK − enemy DEF) back to the enemy + doubled effective DEF for the round. Thematically only the warrior's "Parry" actually felt like that. Archer's "Hide in shadow" parried like a knight, mage's "Magic barrier" likewise. Split the mechanic three ways so the basic Defend matches the class fantasy and the offensive-vs-defensive trade-off stays balanced ("value per Defend turn" roughly equal across classes).

### What was done
- **`CombatService.Defend` namespace** (new): `archerChipMultiplier = 0.5` (halves the warrior chip → 15% of clean hit), `archerDodgeBonus = 30` (flat dodge bonus for the round), `mageBarrierDamageFraction = 0.4` (60% damage reduction on the landed enemy hit). Constants only — no formula change, the existing `applyAttack` + `chipDamage` primitives are reused.
- **`CombatService.chipDamage`** gained an `extraMultiplier: Double = 1.0` parameter. Default keeps the warrior call site unchanged; archer passes `0.5`.
- **`CombatController.onDefend`** branches by `player.characterClass`:
  - **Warrior (unchanged)** — chip via `chipDamage(...)`, enemy attacks against `(effectiveDefense + stance) × 2`, regular dodge. Canonical parry: tags the enemy with shield, eats most of the swing.
  - **Archer** — chip via `chipDamage(..., extraMultiplier: 0.5)` (knife flick while melting into cover), enemy attacks against single DEF + `effectiveDodge + 30` extra dodge. Fantasy is evasion, not armor — enemy frequently swings at empty air.
  - **Mage** — no chip (barrier is passive); enemy attack rolls normally through single DEF + dodge, then the landed damage is multiplied by `0.4` before being applied to HP. Stronger mitigation than warrior to compensate for zero return damage.
- **Locale key (new)**: `combat.defend.barrier` — "A magic barrier shimmers around you." / "Магічний бар'єр мерехтить навколо тебе." Used by the mage branch when chip = 0 (the `combat.defend.absorbed` template requires a damage interpolation, so we render a different line for the chip-less variant).
- **Stance buffs / Shadow Veil dodge / Iron Bulwark armor-split** all still compose correctly: stance ATK feeds the chip (when classes that do chip), stance dodge adds to the archer dodge bonus, Shadow Veil's lingering dodge adds on top of everything. Armor-split is consumed by the warrior chip but not by mage's no-chip Defend — by design, the debuff is "next swing eats the DEF reduction" and the mage simply doesn't swing.

### Balance math (when hit, ignoring crit/variance)
At L1 vs boar (ATK 14):
- Warrior (DEF 12, HP 120): hit = `max(1, 14 - 24) = 1`, chip ~3 → net favorable
- Archer (DEF 8, HP 90): 68% miss rate (`70 + 0 - (8 + 30) = 32%` hit chance), full damage if hit, small chip ~1
- Mage (DEF 6, HP 80): `(14 - 6) × 0.4 = 3.2 HP` (vs 8 raw without barrier), no chip

At L1 vs rabid_bear (ATK 38):
- Warrior: `max(1, 38 - 24) = 14`, chip ~3 → soaks well
- Archer: 32% hit chance, on hit takes full 30 damage
- Mage: `(38 - 6) × 0.4 = 12.8 HP` (vs 32 raw)

Late-game (L21, warrior DEF 20 / archer DEF 16 / mage DEF 14):
- Warrior vs rabid_bear: `max(1, 38 - 40) = 1` HP — almost full block
- Archer vs rabid_bear: 32% hit chance, 22 HP on hit (~7 HP avg)
- Mage vs rabid_bear: `(38 - 14) × 0.4 = 9.6 HP`

Roughly equal "damage prevented per Defend turn" across classes; the warrior's chip is the offensive bonus that compensates for the archer's huge miss rate and the mage's bigger flat reduction. Special Defense techniques (Iron Bulwark / Shadow Veil / Mirror Ward) remain the burst per-fight upgrades.

### Archer button-label swap (Defend ↔ Flee)
The shadow theme on archer's old Defend label (`🌑 Hide in shadow` / `🌑 Сховатись у тіні`) thematically described an escape, not an evasion — and clashed with the Special Defense technique `🌑 Shadow Veil` / `🌑 Тінь лісу`. With the new mechanic emphasizing dodge for archer Defend, swapped the two basic-button labels:
- `combat.button.defend.archer`: `🌑 Hide in shadow` → `💨 Quick maneuver` (`🌑 Сховатись у тіні` → `💨 Швидкий маневр`)
- `combat.button.flee.archer`: `💨 Quick maneuver` → `🌑 Hide in shadow` (`💨 Швидкий маневр` → `🌑 Сховатись у тіні`)

Now archer reads `Loose arrow / Quick maneuver / Hide in shadow` (Attack / Defend / Flee) — evasion on Defend, vanishing on Flee. Distinct from the burst Shadow Veil technique. Pure locale change, no code touched.

### What's queued next
- Manual playtest of the per-class Defend across each class against early-game and late-game mobs. Tune the constants (`archerDodgeBonus`, `mageBarrierDamageFraction`) if any class's Defend feels objectively better/worse than the others.
- Phase 6 (Capital — first gold sources via quests) remains the next planned milestone.

## Session N+7 — 2026-05-15 (Warehouse custom-quantity bidirectional transfer)

### Goal
Replace the warehouse row layout to support transferring an arbitrary quantity in either direction (bag ↔ warehouse). Old row was a single line `[name] [🎒N ⬆️] [📦M ⬇️]` — every action moved exactly 1 unit. New row uses two lines: an info button with both counters, then `[⬆️ +1] [⬇️ +1] [✏️ N]`. The `✏️ N` button opens a two-stage prompt: first picks direction (`[⬆️ To warehouse] [⬇️ To bag]`), then edits in place into a quantity question; the player types a number and the bot validates + transfers. No presets, no multipliers — just two taps then keyboard input. Gear (non-stackable) rows are unchanged: each instance is unique, quantity doesn't apply.

### What was done
- **`EphemeralChatState`**: added a `pendingWarehouseTransfers: [Int64: PendingWarehouseTransfer]` map alongside the existing exploration picker. The struct carries `itemId`, `promptMessageId` (so we can edit/delete the prompt), `warehouseMessageId` (so we can refresh the warehouse view in place after the transfer), and a nullable `direction: Direction?` (`.put` / `.take`). Two-stage state: `direction == nil` during the direction picker, set once the player taps `[⬆️ To warehouse]` / `[⬇️ To bag]`. API: `setPendingWarehouseTransfer`, `setPendingWarehouseTransferDirection` (mutates direction on the existing entry, no-op on stale state), `peekPendingWarehouseTransfer`, `takePendingWarehouseTransfer`.
- **`WarehouseService.withdrawN(itemId, quantity, for:, on:)`** + `WithdrawNResult` (`.success` / `.notEnoughInWarehouse(available:)` / `.inventoryFull(free:)`) — bag ← warehouse direction. **`WarehouseService.depositN(itemId, quantity, for:, on:)`** + `DepositNResult` (`.success` / `.notEnoughInBag(available:)` / `.warehouseFull(free:)` / `.notTransferable`) — bag → warehouse direction, mirror of `withdrawN` flipped. Both share the same shape: every failure case carries the limiting number so the UI renders specific messages without a follow-up query. Atomic preflight (source has ≥ quantity AND destination free ≥ quantity, dev bypass via `user.isDeveloper`); on success, `Entry.remove` + `Entry.add` across the two tables. `depositN` counts only unequipped bag rows (matching single-unit `deposit` semantics) and returns `.notTransferable` for tiered weapons defensively — the `[✏️ N]` button only renders on stackable items so this shouldn't fire in practice.
- **`EstateController.warehouseCategoryKeyboard`**: stackable branch now emits 2 rows per item — row 1 is `[icon name · 🎒N / 📦M]` with the existing `estate:wh:info:<itemId>` callback (description modal); row 2 is `[⬆️ +1] [⬇️ +1] [✏️ N]` with `estate:wh:deposit:<id>` / `estate:wh:withdraw:<id>` / **`estate:wh:transferN:<id>`** (entry to the two-stage flow). Gear branch left untouched (one row per physical unit, single-direction action).
- **Four callback handlers** (after `handleWarehouseDepositAll`):
  - `handleWarehouseTransferNEntry` — sends a NEW message under the warehouse: "Where?" + `[⬆️ To warehouse] [⬇️ To bag]` on row 1, `[❌ Cancel]` on row 2. Records pending with `direction = nil`. Warehouse view untouched.
  - `handleWarehouseTransferDirection` — handles `estate:wh:transferPut:<id>` / `estate:wh:transferTake:<id>` taps. Bumps the pending entry's direction, then edits the prompt in place into the matching quantity question (`deposit_n.prompt` or `withdraw_n.prompt`) with just `[❌ Cancel]` left on the keyboard.
  - `handleWarehouseTransferNCancel` — works in either stage. Clears pending, deletes the prompt message, toast-acks "Cancelled".
  - `handleWarehouseTransferNText` — called from `unmatched()` only when `pending.direction != nil` (text in the direction-picker stage falls through to the normal showEstate fallback). Branches on direction: `.take` → `WarehouseService.withdrawN`, `.put` → `WarehouseService.depositN`. Validation errors edit the prompt in place with `withdraw_n.invalid`; success and quota-failure paths delete the prompt, refresh the warehouse view, and emit the outcome as a standalone banner via `postStatusBanner`.
- **`unmatched()` in EstateController**: peeks `EphemeralChatState` BEFORE the showEstate fallback. Only treats the text as a quantity once `pending.direction != nil` — typed text during the direction-picker stage is ignored and falls through.
- **Callback dispatch ordering in `onCallbackQuery`**: `transferN:` / `transferPut:` / `transferTake:` and `cancelN` are grouped first, before `deposit:` / `withdraw:`, to keep routing unambiguous.
- **Locale keys** (en + uk, 14 new total — 7 for take-side, 7 for put-side):
  - `estate.warehouse.withdraw_n.{prompt, invalid, not_enough, bag_full, success, cancel_button, cancelled}` — shared between both directions for the generic strings; the take-side prompt/success/failure also live here.
  - `estate.warehouse.transfer_n.{where_prompt, dir_put, dir_take}` — direction-picker UI.
  - `estate.warehouse.deposit_n.{prompt, not_enough, warehouse_full, success}` — put-side variants.
  - All `%{...}` interpolations have no leading multi-UTF-16 emoji in the template, per the Lingo bug rule; `❌` and `✅` banners are prepended in Swift at the call site. Inline button labels `⬆️ +1` / `⬇️ +1` / `✏️ N` and the row-1 info label format (`%{icon} %{name} · 🎒%{bag} / 📦%{wh}`) are composed in Swift, matching the existing pattern for `🎒 N ⬆️` button text.

### Design rationale (from a long iterative chat with the user)
Considered and rejected: global multiplier toggles (`×1 / ×10 / ×100 / All`), preset buttons in the prompt (`[1] [10] [100] [Усе]`), replacing the controller reply keyboard with `ReplyKeyboardRemove + [Cancel]` reply-kb button, splitting the third button into two (`[✏️ ⬆️ N] [✏️ ⬇️ N]`), and stacking action rows two-deep per item. The user wanted minimal screen real estate (single button on row 2), no presets ("just type the number"), an inline cancel button, and a way to deposit arbitrary quantities — which forced the two-stage prompt (direction first, then quantity) to keep the button count at three. The single-message prompt with inline `[❌ Cancel]` leaves the controller reply keyboard intact — when the player taps the message input, the device keyboard naturally covers the reply kb during typing. Functionally identical to the explicit-replacement variant, with one less message in chat.

### Mid-session UX fix — status banner placement (two iterations)
User playtested the new `❌ Не вистачає. У вас 88.` flow and reported the banner was easy to miss because it sat ABOVE the category header / item list, well above the inline buttons. First fix: moved banner to the BOTTOM of the body string across 10 sites. User playtested again and still missed it — the banner was now below the body text but STILL above the inline keyboard buttons, and on long item lists scrolled out of view. Final rule: **status banners are standalone messages, not embedded in the body at all.** Added `EphemeralChatState.lastStatusBanner` (latest banner message ID per user) and `TGControllerBase.postStatusBanner(_:context:)` helper that deletes the previous banner before sending a new one so chat history carries only the latest. Refactored 14 sites across 4 controllers: `EstateController` × 9 (handleWarehouseTransfer / handleWarehouseDepositAll / handleWarehouseWithdrawNText / plot claim+type+harvest / training learn / workshop craft / weapon upgrade / estate upgrade / bag upgrade), `InventoryController` × 3 (eat/use, learn-recipe, refreshCategory equip/unequip), `ExplorationController` × 1 (use-item from bag), `CombatController` × 1 (onTrainingExit). Workshop / weapon-upgrade / estate-upgrade / bag-upgrade banners that previously lived "at the bottom of the body" (an earlier band-aid for the same issue, see file-map entry) are now also standalone. Saved as user-level feedback memory [[feedback-status-banner-placement]] — every future action handler should call `postStatusBanner` instead of composing banners into body strings.

### Mid-session combat rebalance — enemy damage pass
User reported in playtest that even a wild boar dealt only **1 HP** of damage at the start of a journey, and the same numbers showed up later in the bestiary — i.e. enemies never threatened. Diagnosed via CombatService.applyAttack: `raw = max(1, ATK - DEF)` with ±10% variance. T1 boar ATK 5 vs L1 Warrior DEF 12 → 5−12 = −7, floored to 1; same story for almost every T1-T4 enemy vs a fresh warrior. Failed flee uses the same formula → also 1 damage, so fleeing was mechanically safe.

Two paired changes, both data tunings (no formula change — the floor stays at 1, DEF still subtracts directly on regular hits):

**1. Bestiary ATK bump** (Swift/Models/Enemy.swift) — explored two passes, reverted to the first. Pass 2 (boar 11 / moose 15 / buffalo 21 / lynx 23 / wolf 27 / bear 31 / rabid_bear 37) softened the curve asymmetrically because the original L1 mage/archer experience felt too rough on paper (boar 14 = 7-9 per hit = ~10% mage HP/turn). After playtest discussion the user chose to revert to the harder Pass 1 numbers — they want early game to feel dangerous, not safe. Final numbers (Pass 1):
| Enemy | Tier | Was | **New** |
|-------|------|-----|---------|
| wild_boar | 1 | 5 | **14** |
| wild_moose | 2 | 8 | **18** |
| wild_buffalo | 3 | 11 | **23** |
| rabid_lynx | 3 | 13 | **25** |
| rabid_wolf | 4 | 15 | **28** |
| wild_bear | 5 | 17 | **32** |
| rabid_bear | 6 | 22 | **38** |

Resulting per-hit damage profile (when hit, ignoring dodge/crit) at L1:
- Boar: Warrior 2-3 (~2% HP) / Archer 5-7 (~7%) / Mage 7-9 (~10%)
- Rabid bear: Warrior 23-29 (~22%) / Archer 27-33 (~33%) / Mage 29-35 (~40%)

Class identity preserved — warrior is genuine tank, mage glass cannon. At L21 with full stat growth (+8 DEF, +40 HP) a rabid bear still bites the warrior for ~11% per hit, so end-game enemies remain threatening but not one-shotty. Training dummy (enemy.training_dummy) intentionally untouched — ATK stays 0.

**2. Flee fail damage uses halved DEF** (CombatController.onFlee around line 500): the player's effective DEF is divided by 2 *before* the stance defenseBonus is added, modeling "you turned your back / dropped your guard." Replaces `let buffedDEF = player.effectiveDefense + mods.defenseBonus` with `let halvedDEF = player.effectiveDefense / 2; let buffedDEF = halvedDEF + mods.defenseBonus`. Concrete: L1 Warrior failing flee from a boar now eats `max(1, 14 - 6) = 8` (~7% HP) instead of the old 1; from a rabid bear, `max(1, 38 - 6) = 32` (~27% HP). Floor still 1 (formula unchanged otherwise); crit and dodge remain off for the flee-fail hit per the original spec.

No locale changes, no migrations, no UI changes — pure data + one-line formula tweak in the flee handler. Build clean.

### What's queued next
- Manual playtest of the new `✏️ N` flow once the user pulls and runs the build: bad input cases (negative, zero, non-numeric, blank), boundary conditions (exactly at storage limit, exactly at bag-free limit, dev bypass), and concurrent edits (storage drained by another tab between prompt open and number submit — service preflight catches this as `.notEnoughInWarehouse(available:)`).
- Playtest the rebalance: verify damage feels right per class (warrior tanky, archer mid, mage fragile) and that flee-fail now actually stings. If T1 boar feels too brutal for a brand-new L1 mage (~10% per hit), can soften to ATK 12. If late-game still feels easy with leveled gear, can bump T5-T6 further.
- Phase 6 (Capital — first gold sources via quests) remains the next planned milestone.

## Session N+6 — 2026-05-12 (Post-5.3 polish: bug fixes + per-unit inventory pivot)

### Goal
A "last set of fixes before a big commit" sweep, gathered from live testing of the 5.3e build. Six discrete fixes shipped in one branch.

### What was done

**1. Lingo emoji-leading-template audit + sweep.** Wrote `/tmp/lingo_audit.py` to enumerate every interpolated locale key with a leading multi-UTF-16 emoji (supplementary-plane OR BMP+VS16). Audit found 11 broken keys × 2 locales: `weapon.upgrade.estate_too_low` (🏰), `bag.upgrade.estate_too_low` (🚧), `estate.locked.room` (🔒), `estate.plot.type_locked` (🔒), `level_up.stat_boost` (💪), `combat.tech.locked` (🔒), `estate.training.kind.learnable` (📖), `estate.training.kind.locked` (🔒), `estate.training.button.learn` (📖), `exploration.passive.report.xp` (📊), `exploration.passive.report.levelup` (🎉). Stripped the leading emoji from every template; prepended in Swift at each call site (EstateController × 5 sites, CombatController × 2, PassiveExpeditionService × 3, InventoryController already clean). User reproed first via the estate-upgrade `level_too_low` alert ("потрібен %{required}-й рівень") and bag `estate_too_low` ("потрібен %{required}-й тир"); the audit caught the rest before they could fire. Script lives at `/tmp/lingo_audit.py` — re-run before any locale commit.

**2. HTML in callback-toast keys.** A separate audit (`/tmp/callback_html_audit.py`) found 3 keys still carrying `<b>...</b>` while reaching the user only through `answerCallbackQuery(text:)` (plain-text only): `combat.tech.locked`, `estate.locked.room`, `estate.plot.type_locked`. User reported the literal `<b>8-го рівня</b>` in the tech-locked modal. Stripped the tags from all three keys in both locales. Other 94 HTML-tagged keys are fine — they only reach the user through `sendMessage`/`editMessageText` with `parseMode: .html`.

**3. Stale combat callback fix.** After combat ends, the player's router flips back to "exploration", but the old combat inline message in chat scrollback still carries `combat:attack`/`defend`/`flee`/... buttons. Tapping any of them landed in the generic Router fallback ("Unsupported content type.") because `ExplorationController.onCallbackQuery` only matched `explore:*` prefixes. Two-part fix: `ExplorationController.onCallbackQuery` now forwards `combat:*` to `CombatController.onCallbackQuery` (mirrors Main/Estate/Inventory/Settings forwarding); `CombatController.loadCombat` no longer redirects to the exploration view when combat state is gone — instead it surfaces a clean `combat.ended` modal alert (`combat.ended` is a new locale key — EN: "The fight is already over. Return to the wilds when you're ready to face another beast." / UK: "Бій уже завершено. Відправляйся до нетрів, коли будеш готовий зустріти нового звіра."). Old behavior was disorienting because the player may have already walked back / returned home — the toast leaves the current screen untouched.

**4. Exploration weight rebalance (two passes).** First pass dropped fresh-tier `nothing` from 20 to 10 (loot 40 → 50), reduced-tier from 50 to 30 (loot 20 → 40), since user reported "the wilderness felt too quiet." Second pass after step-back testing showed too many "🍂 Сліди витоптані" messages in a row: reduced-tier dropped further (`nothing 30 → 20`, `loot 40 → 50`), and the bare tier (priorVisits≥2) opened up from `100/0/0/0` to `80/20/0/0` so even a depleted room has a 1-in-5 chance of forage. Encounter/trip stay zero at bare — beasts learn to avoid the path. Constants: `weightNothing/Loot/Encounter/Trip` (fresh), `weightNothingReduced/...` (revisit), `weightNothingBare/...` (bare).

**5. Plot picker confusion clarified.** User saw "Слотів зайнято: 5/1" with a Coop on slot 0 and asked why a Coop was auto-added. Read the code — `handlePlotTypeChosen` is the only `PlotService.claim` call site, and it sits behind the picker. The Coop was leftover DB data from a session predating Phase 5.3c (when slot allowance was flat 5). With estate T2 now showing only 1 slot, the rendered list shows just slot 0 and the header counts all 5 existing rows. No code change — communicated the situation to the user and recommended `DELETE FROM plots WHERE user_id=$UID` in Postico to reset.

**6. Per-unit slot accounting (big mechanical pivot).** Inventory + warehouse used to count distinct *stack rows* against the cap — `bread × 50` was 1 slot. Switched to per-unit (`flour × 8` = 8 slots), bumped all bag tiers +5, added a T6 capstone (+5 over T5), scaled the warehouse cap ×4 to keep it a meaningful buffer, and added a `User.isDeveloper` bypass.
- `User.isDeveloper`: new extension — `developerUsers.contains(self.telegramId)`. Used by inventory + warehouse cap checks; counts still surface in the UI.
- `InventoryEntry.slotsUsed`: `count` → `reduce(0){ $0 + $1.quantity }`.
- `InventoryEntry.canAccept` / `.add`: collapsed the stackable/non-stackable branches into a single `used + quantity <= cap` check, with dev-bypass at the top.
- `BagCatalog`: capacities `[20, 30, 40, 55, 75]` → `[25, 35, 45, 60, 80, 85]`. `maxTier` 5 → 6. New `BagUpgradeStep` at T5→T6: 25 hide + 12 iron_ingot, requires estate T7 (Lord's Holdings — endgame craft).
- `bag.tier.6.name`: EN "Grandmaster's Pack" / UK "Грандмайстерський сак".
- `WarehouseService.capTable`: `[50, 100, 150, 200, 300, 400, 500]` → `[200, 400, 600, 800, 1200, 1600, 2000]`.
- `WarehouseService.slotsUsed`: same `reduce(0){ + quantity }` pattern.
- `WarehouseService.deposit`: dropped the `needsNewRow` shortcut (used to skip cap check when merging into an existing stack row — incompatible with per-unit). Dev-bypass at the top.
- `WarehouseService.depositAll`: now partial-fills instead of skipping — a 10-unit hide row hitting a 6-unit free cap dumps 6 and leaves 4 behind. Dev-bypass at the top.
- `InventoryController.renderRoot` + `EstateController.renderWarehouseRoot` call site: changed inline `.count` to `reduce(0){ + quantity }` for the header `X/Y slots` display.

Migration impact: existing players keep all their items — over-cap rows stay readable, cap only blocks new inserts (same policy as 5.3c warehouse cap rollout). Recipe costs unchanged — but they now bite a lot harder against the new bag (a Forester's Jerkin needs 6 hide = 6 slots of a 25-slot bag).

**Other notes:**
- `configure.swift`: `seedDevInventory` was flipped `true → false` locally during user testing. Carrying the change in this commit since it's a one-line dev config the user set deliberately.
- Locale parity: 470/470 EN/UK after the round.
- Build: clean.
- Both audit scripts pass with 0 hits after the sweep.

### What's queued next
- User-triggered post-commit testing of the new bag/warehouse pressure. Recipe input numbers may need rebalancing if the new cap proves too tight in real play.
- Phase 6 (Capital — first gold sources via quests) is the next planned milestone now that Phase 5.3 series + this polish are landed.

## Session N+5 — 2026-05-11 part 7 (Phase 5.3e — Technique gates + Training Ground learn flow)

### What was done:
Last sub-phase of the Phase 5.3 progression series. The 9 Phase 4.2 combat techniques (3 kinds × 3 classes) were unlocked from L1 prior to this; now they gate on player level and explicit Training Ground visits.

**Architecture:**
- `CombatService.TechniqueKind` enum (specialAtk / specialDef / super; class-agnostic IDs because each class has exactly one of each, resolved via `User.characterClass`)
- `CombatService.requiredLevel(for: TechniqueKind) -> Int` — L8 / L11 / L14 thresholds
- `CombatService.initialUses(for:playerLevel:) -> Int` — per-fight budget growth: 1 → 2 at L17 (atk) / L20 (def) / L21 (super). Wraps via `initialUsesForUser(_)` helper.
- `LearnedTechnique` Fluent model + `CreateLearnedTechniques` migration (per-user, technique_id string, unique on user+id; mirrors `LearnedRecipe` shape exactly)
- `ExplorationState.beginCombat` now takes `specialAtkUses / specialDefUses / superUses` as parameters. Three call sites updated: registration wolves fight, training-dummy spawn, active-mode encounter handoff. Each derives values via `CombatService.initialUsesForUser(context.session)`.

**Combat submenu (Variant 2 — locked techniques show with 🔒):**
- Learned + uses > 0 → normal `<name> × N` button (unchanged)
- Learned + 0 uses → button hidden (unchanged — already-spent buttons hide so the menu stays compact)
- Unlearned → `🔒 <name>` button with the **same** callback as learned. Execution handlers (`onSpecialAttack`, `onSpecialDefense`, `onSuper`) call new `sendLockedToastIfUnlearned(kind:context:)` first — if `LearnedTechnique.has` returns false, the handler sends a modal alert via `combat.tech.locked` ("Visit the Training Ground at level X") and bails.
- `combatTechniquesMarkup` signature gained `learned: Set<String>` parameter; the only caller (`onTechMenu`) fetches the set once per submenu render.

**Training Ground UI (replaces direct-to-spar):**
- `handlePlotTraining` no longer jumps into the dummy fight. It now renders a Training Ground screen with three per-kind lines:
  - ✅ `<name>` — already learned
  - 📖 `<name>` — ready to learn (paired with a `[📖 Learn X]` button)
  - 🔒 `<name>` — unlocks at level Y (no button)
- Keyboard: one `[📖 Learn X]` per learnable-and-not-yet-known kind, then `[🥋 Spar]` and `[🔙 Back]`.
- `handleTrainingLearn` validates the level gate defensively (so stale callbacks fail cleanly), writes `LearnedTechnique.add`, refreshes the screen with `✅ Learned X` (or `📖 You already know X` on idempotent re-tap).
- `handleTrainingSpar` carries forward the pre-5.3e dummy-spawn logic. The `[🔙 Back]` button uses the existing `estate:plot` callback to return to plot list.
- Class-specific technique names resolved via `EstateController.techniqueNameKey(kind:class:)` — same `combat.button.special_atk.<class>` / `.special_def.<class>` / `.super.<class>` keys used by the combat submenu, so the displayed names stay consistent across the two screens.

**Locale parity 468/468** — 11 new keys × 2 locales (`combat.tech.locked` + `estate.training.{title, description, kind.{learned, learnable, locked}, button.{learn, spar, back}, banner.{learned, already_known}}`).

**Phase 5.3 series complete.** All five sub-phases (a/b/c/d/e) shipped over 2026-05-11. Phase 5.4 abandoned earlier. Phase 5 is closed; next up is Phase 6 (economy / capital / market / first gold sources via quests).

Build clean.

## Session N+4 — 2026-05-11 part 5 (Phase 5.3d craftable bag upgrades)

### What was done:
Bag now starts smaller (20 slots vs the previous flat 50) and grows via crafted upgrades at the Workshop, mirroring the weapon upgrade pattern.

**Architecture:**
- `User.bagTier: Int` (default 1) on the User row + `AddUserBagTier` migration (`bag_tier INT NOT NULL DEFAULT 1` on users).
- `BagCatalog` (`Swift/Models/BagCatalog.swift`): 5 tiers (20/30/40/55/75 slots), each `BagUpgradeStep` carries `toTier` / `capacity` / `requiredEstateLevel` / `inputs`. Estate-tier gates: T2 needs estate T3 (Workshop just unlocked), T3 needs T4, T4 needs T5, T5 needs T6. Materials are hide + iron only — no gold cost on the bag track (gold sinks live on the estate track).
- `BagUpgradeService.upgrade(for:on:)` (`Swift/Services/BagUpgradeService.swift`): mirrors `WeaponUpgradeService` shape. Validates max-tier → estate-gate → material snapshot → drains from combined inventory+warehouse pool (inventory first) → bumps `user.bagTier` + saveAndCache. Result enum: success(newTier, newCapacity)/maxTierReached/estateLevelTooLow/missingMaterials.
- `InventoryEntry.slotCap` converted from `static let = 50` to `static func slotCap(for user: User) -> Int` reading `BagCatalog.capForTier(user.bagTier)`. All call sites updated: `CraftingService` output-fits check, `InventoryController.renderRoot` (signature gained `session: User`), internal `canAccept` / `add`.

**UI:**
- Workshop keyboard gains a second universal button `[🎒 Upgrade bag]` immediately after `[⚔️ Upgrade weapon]`. Same "always visible, even at max tier" pattern — the detail screen renders the "fully upgraded" message when applicable instead of hiding the button.
- Detail screen mirrors the weapon upgrade flow. `bag.upgrade.current_header` shows "Now: tier 2 — Leather Bag · 30 slots". `bag.upgrade.next_header` shows the preview with `+delta` slots: "Tier 3 — Reinforced Backpack · 40 slots (+10)". Estate-tier gate with ✅/⛔ marker. `📜 Materials` block with have/need pulled from the combined pool. `[🧵 Sew]` confirm button.
- All failure modes → modal alert (max tier, estate too low, multi-row missing materials). Success → in-place refresh + `✅ Bag upgraded to tier N — Name · K slots` banner appended at the bottom.

**Localization:**
- 15 new keys × 2 locales:
  - 5 tier names: `bag.tier.1.name` … `5.name` (Linen Sack → Leather Bag → Reinforced Backpack → Hunter's Pack → Master's Knapsack)
  - 10 UI keys: `bag.upgrade.button` / `.button.confirm` / `.title` / `.current_header` / `.next_header` / `.estate_required` / `.recipe_header` / `.max_tier` / `.estate_too_low` / `.banner.success`
- Parity 457/457.

**Migration impact on existing players:**
- All existing players land at `bagTier = 1` (20 slots). Rows already in their bag stay (cap blocks new inserts only — same policy as the warehouse cap from 5.3c).
- Dev grants via Postico for testing higher tiers (`UPDATE users SET bag_tier = N`).

Build clean. Next: 5.3e — technique gates by player level + Learn-at-Training-Ground flow + per-fight uses growth on L17/20/21.

## Session N+3 — 2026-05-11 part 4 (Phase 5.3c gold polish)

### What was done:
Follow-up polish on the 5.3c manual estate upgrade: gold sink for T3+ transitions. User wanted gold to gate later upgrades but **not** appear in the inventory ("матеріали в сумці") since slot pressure already matters — gold stays a User-level field surfaced only in the profile.

- `EstateUpgradeStep.goldCost: Int` (default 0 for backwards-compat). Catalog: T1→T2 + T2→T3 = 0g (free onramp), T3→T4 = 50g, T4→T5 = 150g, T5→T6 = 400g, T6→T7 = 1000g. Cumulative endgame spend ~1600g.
- Gold drained directly from `User.gold` — never an item id, never a `WarehouseEntry` / `InventoryEntry` row. Designed deliberately so the bag stays uncluttered.
- New `EstateUpgradeService.UpgradeResult.insufficientGold(required, current)` case. Service order is now: max-tier → player-level → **gold** → materials → drain. Gold sits before materials so a cash-short player gets a clean "💰 Not enough gold" alert instead of a noisy materials breakdown that might look fine on its own.
- `EstateController.renderEstateUpgrade` appends a `⛔ 💰 50 gold (30/50)` line (with ✅/⛔ matching the player-level gate style) outside the `📜 Materials` block when goldCost > 0. `handleEstateUpgradeConfirm` handles the new case with a modal alert via `estate.upgrade.gold_too_low`.
- 2 new locale keys × 2 locales (`estate.upgrade.gold_required`, `estate.upgrade.gold_too_low`); parity 442/442.

**Source of gold:** quest rewards in Phase 6+ (Capital). Explicitly NOT dropped from mobs ("поки не треба додавати дроп золота з мобів"). Dev grants gold via Postico for testing.

Build clean. 5.3c is now fully landed (gates + manual upgrade + gold sink). Next: 5.3d (smaller starter bag + craftable bag upgrade in Workshop).

## Session N+2 — 2026-05-11 part 3 (Phase 5.3c — Estate gates + manual upgrade)

### What was done:
Originally scoped as just "gating": Kitchen at T2, Workshop at T3, Tannery at T4, Training Ground plot type at T3, plot slot table, warehouse cap with growth. After implementing gating but before commit, user observed the gates would trigger automatically with player level — no agency, no resource sink. Pivoted to combined commit: gates + manual estate upgrade flow.

**Gating pieces:**
- House drilldown buttons filtered by `estateLevel` (T1→Warehouse only, T2→+Kitchen, T3→+Workshop). Stale-callback defensive alerts via `estate.locked.room`.
- Workshop recipe list filters out tannery recipes when `estateLevel < 4`; also stops accidentally surfacing kitchen recipes here (was unintended pre-5.3c — `RecipeCatalog.all` contains all categories).
- Plot picker hides Training Ground type when `estateLevel < 3`. `handlePlotTypeChosen` defends with modal alert via `estate.plot.type_locked`.
- `PlotService.slotsForLevel` restored: now `[0, 1, 2, 3, 4, 5, 6]` indexed by tier-1 (was flat 5).
- Dropped registration auto-grant of Farm at slot 0 — T1 has 0 plot slots by design (wooden hut hasn't cleared land yet). `PlotService.hasAnyPlot` deleted since it had only one caller.
- `WarehouseService` capacity by tier: T1=50, T2=100, T3=150, T4=200, T5=300, T6=400, T7=500. New `slotsUsed(for:on:)` helper + `capForLevel(_)` + new `DepositResult.warehouseFull` case. Deposit gates: only blocks when creating a new row; stackable merges into existing rows always succeed. `depositAll` tracks running usage so it doesn't blow past cap.
- Warehouse root UI shows `📦 Storage: X/Y slots` capacity line.

**Pivot: manual estate upgrade (replaces auto-derivation):**
- `User.estateLevel` converted from computed `(level-1)/3+1` to stored `@Field(key: "estate_level") var estateLevel: Int` (default 1). Migration `AddEstateLevel`.
- New `EstateUpgradeCatalog` (`Swift/Models/EstateUpgradeCatalog.swift`): 6 tier transitions (T1→T2 ... T6→T7), each with `requiredPlayerLevel` (4/7/10/13/16/19) + materials list. Materials scale with tier — lumber/pebble base, iron/ingot/hide/clay scaling. T1→T2 ~33 units (cheap onramp), T6→T7 ~313 units (endgame milestone).
- New `EstateUpgradeService` (mirrors `WeaponUpgradeService` pattern): `upgrade(for:on:)` validates max-tier, player-level gate, then drains materials from combined inventory + warehouse pool (inventory first), bumps `estateLevel`, `saveAndCache`. Result enum: success/maxTierReached/playerLevelTooLow/missingMaterials.
- EstateController UI: `[🏠 Upgrade estate]` button on root (hidden at max tier). Detail screen shows current tier + name, next tier preview, player-level requirement (green/red), `📜 Materials` list with per-input have/need (combined pool). `[🏗 Upgrade]` confirm button. Every failure mode → modal alert (max tier / level too low / multi-row missing materials list). Success → in-place refresh + `✅ Estate raised to tier N — Name` banner.
- 7 tier names per locale (`estate.tier.1.name` … `.7.name`): Wooden Hut → Settler's House → Forester's Lodge → Manor → Knight's Manor → Baron's Estate → Lord's Holdings.
- `XPGrantResult.estateLeveledUp` is now structurally always false (XP grants no longer change estate); kept the field + the conditional banner branches in CombatController + PassiveReport as inert hooks for future "quest grants estate XP" possibilities. Not dead, just inactive.

**Files added:** `Swift/Migrations/AddEstateLevel.swift`, `Swift/Models/EstateUpgradeCatalog.swift`, `Swift/Services/EstateUpgradeService.swift`. Migration registered in `configure.swift`.

Locale parity 440/440 (+17 keys: 7 tier names + 10 upgrade-flow keys). Build clean.

**Carryforwards for 5.3 sub-phases:** 5.3d (smaller starter bag → craftable bag upgrades in Workshop), 5.3e (technique gates + Training Ground "Learn" flow + per-fight uses growth).

## Session N+1 — 2026-05-11 part 2 (Phase 5.3b — Stat growth on level-up)

### What was done:
Implemented stat-growth-on-level-up per the Phase 5.3 plan.

- `User.statGrowthLevels: Set<Int> = [2, 3, 5, 6, 9, 12, 15, 18]` (8 levels chosen to fall between estate-tier-up levels, avoiding L4/7/10/13/16/19 which already get structural rewards)
- `User.statGrowthMaxHp = 5`, `User.statGrowthAttack = 1`, `User.statGrowthDefense = 1` constants
- `grantXP` loop now applies the boost when reaching a configured level: `maxHp += 5`, `hp += 5` (current HP also bumps so player feels stronger immediately), `attack += 1`, `defense += 1`
- `XPGrantResult` gained `maxHpGained` / `attackGained` / `defenseGained` totals (zero when no stat-growth level was crossed)
- `CombatController.finishVictory` appends `💪 +H maxHP +A ATK +D DEF` suffix to the `🎉 Level N!` banner when stats grew this victory
- `PassiveReport` extended with `maxHpGained` / `attackGained` / `defenseGained` (backwards-compat Codable defaults to 0); `renderReport` rebuilt the XP line from 3 composable fragments — base XP / level-up segment / stat-boost segment — so each lives behind its own locale key
- Dropped now-orphan `exploration.passive.report.xp_with_levelup` key, added `exploration.passive.report.levelup` (level-up fragment alone) + shared `level_up.stat_boost` key (reused by both combat banner and passive report)
- Locale parity 419/419

Total stat growth across L1→L21: +40 maxHP / +8 ATK / +8 DEF (8 boosts × +5/+1/+1).

Build clean. No gates landed yet — those are 5.3c.

## Session N — 2026-05-11 (Phase 5.3a — XP/level base system)

### What was done:
Designed the full Phase 5.3 progression plan with the user (interactive, multi-round), then landed Phase 5.3a (the base XP/level layer) with **no gates yet** — everything is still open, only XP and levels exist.

**Design decisions captured:**
- Two-track progression: estate-tier (every 3 player levels) for structural unlocks, player-level (each level) for personal/combat unlocks
- Estate level formula: `(level - 1) / 3 + 1` (was `/5 + 1`) — 21 player levels → 7 estate tiers (T1 L1-3 / T2 L4-6 / … / T7 L19-21)
- XP curve with softcap: pure doubling L1→L5 (100/200/400/800/1600), then ×1.4 from L5+ (~870K total to L21, ~5K T6 kills)
- Per-tier XP rewards: T1=5, T2=12, T3=25, T4=50, T5=100, T6=175, training_dummy=0
- Full sub-phase split: 5.3a (base), 5.3b (stat growth on L2/3/5/6/9/12/15/18), 5.3c (room/category/plot-type gates + plot-slot table), 5.3d (smaller starter bag + craftable bag upgrades in Workshop), 5.3e (technique gates + "learn at Training Ground" flow + per-fight uses growth)
- Carved-out unlock map L1→L21 with concrete contents per level (kept in conversation log; will be referenced when implementing later sub-phases)

**Implementation (5.3a only):**
- `Enemy.xpReward: Int` field + populated all 7 enemies (5/12/25/50/100/175/0 for dummy)
- `User.maxLevel = 21`, `User.xpRequiredToReach(_)` softcap helper, `User.xpToNextLevel` computed, `User.grantXP(_) -> XPGrantResult` that processes level-ups in a loop and reports both `levelsGained` and `estateLeveledUp`
- `User.estateLevel` formula updated to `(level-1)/3+1`
- `CombatController.finishVictory` grants XP after victory drops; appends `📊 +N XP` / `🎉 Level N!` / `🏰 Estate tier N!` banners to the victory message; skips registration tutorial fight (still narrative-only) and training dummy (xpReward = 0 makes it a natural no-op)
- `PassiveExpeditionService` — `RunningPassiveReport` and `PassiveReport` gain `xpEarned` (with backwards-compat custom decoder for in-flight pre-5.3a rows). `runLive` accumulates XP from each `.encounterWon` outcome via `enemy.xpReward`. `finalizeAndPush` calls `user.grantXP(xpEarned)` and `saveAndCache` before serializing the final report. `renderReport` adds an XP line (with level-up suffix when `levelsGained > 0`)
- Profile (all 3 styles in MainController) gained an XP fragment. Style 1 (compact): `📊 XP 250/400`. Style 2 (text bar): `📊 ████░░░░░░ 250/400`. Style 3 (verbose with emoji bar): full block with emoji bar + numeric. At max level all three styles render `Max` instead of progress
- Removed dead `MainController.xpForNextLevel(_:)` (was `level * 100`); profile now reads `User.xpToNextLevel` directly
- 6 new locale keys × 2 locales: `profile.xp.max`, `combat.victory.xp`, `level_up.banner`, `estate_up.banner`, `exploration.passive.report.xp`, `exploration.passive.report.xp_with_levelup`. Locale parity 418/418

**No gates yet:** weapon-upgrade still uses estate-level (now reachable), Kitchen / Workshop / Plot all still open from L1, plot slots still flat 5, techniques still all open. Those land in 5.3b–5.3e.

**Build:** clean. Existing players (everyone at L1) keep their current open access — they only start gaining XP on the next combat / passive expedition.

## Session 1 — 2026-04-17 (Initial Setup)

### What was done:
- Full codebase analysis (all Swift files, Package.swift, localizations, .env)
- GDD.md and README.md deep review
- Online research: swift-telegram-sdk, Hummingbird 2.x, Fluent standalone, Lingo 4.x
- Created `.memory/` project-scoped memory system with index and 8 knowledge files
- Created `CLAUDE.md` — AI assistant instructions and project reference
- Created `TODO.md` — phased progress tracker with status markers
- Created `Prompt.me` — new-session compact primer

### Key findings:
- Project has solid infrastructure: routing, auth, sessions, localization all working
- Only 3 controllers implemented (Registration, Main, Settings) + GlobalCommands
- User model is minimal (no game stats, inventory, etc.)
- No game mechanics implemented yet — entire GDD is planned/future work
- Localization has ~24 keys per locale (EN + UK)
- Auth is hardcoded to 4 Telegram IDs

### Architecture assessment:
- Router-controller pattern is clean and extensible
- Session cache is well-implemented (actor, TTL, auto-cleanup)
- Code quality is high, Swift 6.2 concurrency compliance is good
- Main scaling concern: global mutable state (appState, store, sessionCache)

## Session 2 — 2026-04-18 (Registration Rework + Profile)

### What was done:
- Multi-step registration: language -> nickname (2-20 chars) -> class (warrior/archer/mage) -> estate name (2-30 chars)
- CharacterClass enum in configure.swift with icons
- User model expanded: nickname, characterClass, estateName, registrationStep, profileStyle
- Two new migrations: AddCharacterFields, AddProfileStyle
- Profile view in MainController with 3 switchable visual styles (inline buttons, message editing)
- Profile button added to main menu keyboard
- Dev profile reset flag (resetDevProfile) for testing registration flow
- Fixed: migrator calls now properly awaited (try await .get())
- Fixed: databases.shutdown() in defer to prevent ConnectionPool assertion
- Replaced dead onCancel with showCurrentStep for better UX on unexpected input during registration
- ~28 new localization keys per locale (registration flow + profile stats)

### Bugs fixed:
- ConnectionPool.shutdown() assertion on app exit — added defer with DispatchQueue.global()
- Migration not running (profile_style column missing) — changed `_ = migrator.prepareBatch()` to `try await migrator.prepareBatch().get()`
- Duplicate greeting after registration — merged completion message into showMainMenu text param

### Game stats addition (same session):
- AddGameStats migration: 13 fields (level, xp, hp, maxHp, hunger, maxHunger, attack, defense, crit, dodge, accuracy, gold, crowns)
- User.applyStartingStats(for:) method — sets class-specific stats at registration
- CharacterClass.startingStats computed property (warrior: hp120/def12, archer: atk14/crit10/acc14, mage: atk15/crit12/hp80)
- Profile rendering now reads real User fields instead of hardcoded placeholders
- XP curve: level * 100
- Dev reset updated to clear all stat fields

## Session 3 — 2026-04-19 (Main-menu navigation scaffold)

### What was done:
- Added three new Commands enum cases: `explore`, `estate`, `capital`
- Created three stub controllers: ExplorationController, EstateController, CapitalController (all identical shape — show "coming soon" + back-to-main)
- Registered new controllers in AllControllers.swift (routerNames: exploration / estate / capital)
- MainController keyboard reshaped to 3 rows: [Explore] / [Estate, Capital] / [Profile, Settings]
- MainController handlers (onExplore/onEstate/onCapital) transition user to the matching stub router
- Added 4 new localization keys per locale: commands.explore/estate/capital + stub.coming_soon (EN + UK)
- Build green (Swift 6.2, only pre-existing `crowns` unused-var warning)

### User decisions captured in project memory:
- Phase 1.2 tutorial/onboarding deferred until game lore is finalized
- Phase 1.3 main-menu character status line skipped — stats remain in Profile view only

## Session 4 — 2026-04-19 (Inventory data layer, Phase 2.1)

### What was done:
- Designed Item model as a code-based catalog (not a DB table) — `Swift/Models/Item.swift`
  - `ItemType` enum: food / material / gear / potion / recipe / artifact
  - `ItemEffect` enum with associated values: `.restoreHunger(Int)` / `.restoreHP(Int)` (extendable)
  - `Item` struct: id, nameKey, type, tier, stackable, effects
  - `ItemCatalog` with 14 seed items spanning all types, plus `find(id)` + `items(of:type)` lookup
- Created `InventoryEntry` Fluent model — one row per stack (user_id FK cascade, item_id, quantity, timestamps)
- CreateInventory migration (indexed FK, no unique constraint; non-stackable gear gets one row per unit)
- Inventory helpers as static methods: `add`, `remove` (returns false if insufficient), `has`, `totalQuantity`, `list`
- 14 new localization keys per locale for seed item display names (EN + UK)
- Build green (Swift 6.2, only pre-existing `crowns` warning)

### Architectural decisions:
- Item catalog in code (not DB): chosen for type-safe effects, compile-time safety, and because GDD expects a bounded set (~50–200 items) with diverse effect shapes. Trade-off: adding an item requires a deploy.
- Normalized `inventory` table (not JSON blob on User): needed for future market / guild vault / trade / quest-prereq queries.
- No unique constraint on (user_id, item_id): gear is non-stackable, would need per-instance rows. Stacking is enforced by helper logic instead.

### Inventory nav button + real viewer (same session):
- Added `Commands.inventory` case + main-menu keyboard reshape: row 1 is now 🗺 Explore | 🎒 Inventory
- `InventoryController` is a real read-only viewer (not a stub): loads `InventoryEntry.list()`, groups by `ItemType` with icons (🍖🪨🧪🗡📜💎), shows empty-state when bag is empty
- Added `ItemType.icon` property
- Dev command `/grant <item_id> <quantity>` registered on TGDispatcher via GlobalCommandsController — restricted to mitya only; validates item exists, uses existing `InventoryEntry.add` helper
- Dev inventory seed in configure.swift: mitya-only, idempotent (skips when inventory non-empty); controlled by `seedDevInventory` flag (default true). Seeds: bread×3, stew×1, wood×5, stone×3, heal_small×2, rusty_sword×1, recipe.stew×1
- 12 new localization keys per locale: inventory.title/empty, inventory.type.* (6), grant.usage/unknown_item/success

### Crowns removal (same session):
- Removed `crowns` field from User model, init, dev reset, MainController profile rendering
- Dropped `profile.crowns` localization key (EN + UK)
- New migration `RemoveCrownsField` drops the `crowns` column from `users` (the original AddGameStats migration is untouched — it's already applied)
- Motivation: user hasn't decided on the final premium-currency name yet; removing avoids stale references. Concept remains in GDD as "premium currency (name TBD)". When a name is picked, a new AddX migration will reintroduce the column.
- Build clean — previous pre-existing `crowns` unused-var warning is gone too

## Session 5 — 2026-04-20 (Hunger system, Phase 2.2)

### Architectural decisions:
- Stats in DB are BASE values. Effective stats (after hunger / future gear / buffs) are computed via `user.effectiveAttack` / `user.effectiveDefense` computed properties. Callers (combat, UI) read effective values. Gear bonuses (Phase 2.3) and pet buffs layer into the same extension.
- Service layer introduced in `Swift/Services/`. `HungerService` is pure — no DB writes, no actor state. Mutates user in-place when drain/consume are called; caller persists. This pattern will be reused by future services (Exploration, Combat, Crafting).
- Drain hooks are written now but not yet wired, because Exploration (room transitions) and Combat (rounds) don't exist yet. `HungerService.drain(user, action:)` is ready to be called from those when they ship.

### What was done:
- New `Swift/Services/HungerService.swift`:
  - `HungerAction` enum (walkRoom / walkRoomDoubleSpeed / combatRound / idle) with tunable cost constants (⚙️ TBD, GDD values)
  - `drain(user, action:)` and `drain(user, amount:)` — clamp to 0
  - `isStarving(user)` — hunger <= 0
  - `consume(item, user) -> ConsumeResult?` — applies `restoreHunger` / `restoreHP` effects, returns nil if fully wasted (rejects consumption)
  - `applyStarvationHPLoss(user) -> Int` — 5% max HP lost per room when starving (callers invoke per room)
  - `isConsumable(item)` — true for food / potion
  - Constants: `drainWalkRoom=2`, `drainWalkRoomDoubleSpeed=4`, `drainCombatRound=1`, `starvationStatPenalty=0.25`, `starvationHPDrainPercent=0.05`
- User extension: `effectiveAttack`, `effectiveDefense` apply `-starvationStatPenalty` when starving (clamped to min 1)
- `InventoryController` — single-message tree navigation:
  - Root view: "🎒 Inventory" + category buttons for ALL 5 item types (2 per row, e.g. `🍖 Food (4)` · `💎 Artifacts (0)`). Empty categories show count (0) and reply with a toast "You have no items in this category" on tap instead of opening an empty drill-down. No Close button — player navigates away via main's reply keyboard, which stays visible throughout the inventory session.
  - Category drill-down: every item is its own inline button (future-proofed — tapping will show per-item description). For all categories except Materials, each row is `[Item × N] [action]`; the action button label/emoji is type-specific via `ItemType.actionKey` → `inventory.action.<type>`: 🍴 Eat / 🍷 Use / 🛡 Equip / ✨ Use. Materials have no action button (they're crafting inputs, not usables).
  - Navigation edits the same message in place (editMessageText).
  - `inv:info:<id>` callback: placeholder toast "`<name> — description coming soon`" until per-item description view is built.
  - `inv:use:<id>` callback: food/potion consume via HungerService (toast with "+X hunger" / "+Y HP"); gear/artifact reply with "🚧 Not yet available" toast until their systems ship (Phase 2.3 / TBD).
  - Consume refreshes category view; auto-pops back to root when the category becomes empty.
  - Rejects consumption if item's total effect would be zero (no wasted eating).
  - Inventory router registers main-nav button-text handlers (Explore / Estate / Capital / Profile / Settings / Inventory) so main's reply keyboard clicks during inventory still navigate properly.
- `MainController.renderProfile` — shows effective ATK/DEF (respect starvation penalty); appends `😵 Starving` suffix to hunger line in all 3 styles when hunger is 0
- Dev command `/drain <amount>` in GlobalCommandsController — mitya-only; drains hunger by N (clamped); does not trigger starvation HP loss (that's a per-room effect)
- Dev command `/revoke <item_id> <quantity>` — mitya-only; symmetric counterpart to `/grant`. Uses `InventoryEntry.remove`; responds "not enough" if player has fewer than requested (nothing partially removed in that case).

## Session 6 — 2026-04-20 (Lore-driven registration — Artania narrative)

### What was done:
- Registration reworked from 4 mechanical steps into a 6-step lore flow driven by the Artanian narrative the user authored:
  - Step 0: language
  - Step 1: Artanian welcome (King's realm, Beastfever plague) + name prompt
  - Step 2: name acknowledged + class descriptions (Knight/Archer/Mage) + class selection buttons
  - Step 3: King's Oath narrative — charter granted, class-specific starter weapon bestowed; inline "🏰 Set out for the estate" button
  - Step 4: road ambush by a pack of rabid wolves (combat stub for now) + inline "⚔️ Continue" button
  - Step 5: arrival at the derelict manor — player names the estate
  - Step 6: complete, transition to main controller
- UK class name for `.warrior` renamed "Воїн" → "Лицар"; EN renamed "Warrior" → "Knight" to match medieval tone
- Added `CharacterClass.starterWeaponId`: warrior → gear.rusty_sword, archer → gear.simple_bow, mage → gear.wooden_staff
- Added two new catalog items: `gear.simple_bow`, `gear.wooden_staff`
- On class selection, `RegistrationController` grants the matching starter weapon via `InventoryEntry.add`
- King's Oath text uses `%{weapon}` interpolation — localized to "клинок/лук/посох" (UK) / "sword/bow/staff" (EN)
- Dev profile reset now wipes the user's inventory too (so the class-weapon grant starts clean on replay)
- Dev seed no longer ships `gear.rusty_sword` (registration handles class weapons instead)
- Phase 1.2 "Create tutorial/onboarding message sequence" marked done — this narrative IS the onboarding
- 10 net new localization keys per locale (96 → 106): registration.welcome, registration.name_accepted, registration.king_oath, registration.weapon.{warrior,archer,mage}, registration.to_estate, registration.journey_wolves, registration.continue, item.gear.simple_bow, item.gear.wooden_staff. Removed `registration.nickname.prompt` (replaced by `registration.welcome`).
- Rewrote class descriptions (registration.class.*.desc) in lore style: Лицар незламний щит / Лучник зірке око / Маг володар стародавніх сил
- Rewrote `registration.estate.prompt` into the plaque-naming lore text
- Rewrote `registration.complete` into a short Artanian benediction
- Build clean.

### Follow-up (same session): class-specific artwork for the wolves step
- Added three illustrations under `Assets/registration/<class>_estate.jpg` (warrior/archer/mage). Each shows the Governor approaching the derelict manor with rabid wolves closing in, art styled per class.
- `CharacterClass.journeyImageName` returns the matching filename.
- `RegistrationController.promptJourneyWolves` now reads the file and sends it via `TGSendPhotoParams` with the narrative text as caption and the Continue button as inline keyboard. Falls back to text-only if the file is missing.
- Promoted `projectPath` from a local variable inside `configure()` to a public global constant so controllers can use it for asset loading.
- Note: no file_id caching yet — each registration re-uploads the JPEG via multipart. Fine for dev; move to file_id cache (or remote URL hosting) before public launch.

### Follow-up: keep onboarding messages in chat history
- Previously the callback handler called `deleteMessage` on the source of each click, so only the opening "Welcome to Artania" and the final estate-naming prompt remained on screen. All narrative steps (class descriptions, King's Oath, wolves artwork) were erased.
- Replaced the delete with `editMessageReplyMarkup` that swaps the inline keyboard for an empty one. Text, HTML, and attached artwork stay; only the buttons disappear so they can't be re-clicked.
- This keeps the full registration arc scrollable in chat and is the groundwork for adding more class-specific artwork to other onboarding steps later.

## Session 7 — 2026-04-21 (Equipment system scaffolding, Phase 2.3.1)

### Plan
Phase 2.3 is being split into four sub-commits matching the TODO subpoints:
  - 2.3.1 — Slot design (types only, no behaviour change)
  - 2.3.2 — Data layer (inventory.equipped_slot + users.gear*Bonus columns)
  - 2.3.3 — EquipmentService + effective-stat integration + registration auto-equip
  - 2.3.4 — Inventory UI toggle + profile "Equipped" line

### Architectural choices
- Equipped state will live as a column on `InventoryEntry` (`equipped_slot: String?`), not as a separate table and not as columns on User. Rationale: gear already occupies one row per unit in inventory; marking a row "equipped to X" is the minimal diff. Unequipping is nilling the slot; the item stays in inventory.
- Gear bonuses (attack/defense/crit/dodge/accuracy) will be cached on the `User` row so combat/UI can read effective stats synchronously. Recomputed on every equip/unequip.
- Equipment UI lives inside `InventoryController` — no new controller. The existing `🛡 Equip` button on gear rows will be wired to real logic, with the label toggling to `❌ Unequip` when the row is currently equipped.

### What was done (2.3.1)
- Added `EquipmentSlot` enum (8 cases: helmet/chest/legs/boots/mainHand/offHand/accessory1/accessory2). Raw values use snake_case for the DB column.
- Added `GearStats` struct (attack/defense/crit/dodge/accuracy, each Int, default 0).
- Extended `Item` with optional `slot: EquipmentSlot?` and `gearStats: GearStats?`. Custom public init with defaults so existing non-gear catalog entries don't need changes.
- Wired stats onto the four starter gear items:
  - gear.rusty_sword → mainHand, +2 atk
  - gear.simple_bow → mainHand, +2 atk, +1 acc
  - gear.wooden_staff → mainHand, +2 atk, +1 crit
  - gear.leather_vest → chest, +2 def
- No runtime behaviour change yet — this step only introduces the type vocabulary. Build clean.

### What was done (2.3.2)
- Two new migrations:
  - `AddEquipSlotToInventory` — nullable `equipped_slot: String` column on `inventory`. When set, that inventory row is the equipped piece for the named slot (EquipmentSlot raw value, snake_case). When nil, the item is simply carried.
  - `AddGearBonuses` — five new `Int` columns on `users` (`gear_attack_bonus`, `gear_defense_bonus`, `gear_crit_bonus`, `gear_dodge_bonus`, `gear_accuracy_bonus`), all `NOT NULL DEFAULT 0` so existing rows backfill cleanly.
- `InventoryEntry.equippedSlot: String?` via `@Field`.
- `User` gains the five cached gear-bonus fields + init zero-out; dev profile reset now also zeroes them.
- `User.recomputeGearBonuses(on:)` is a zero-out stub for now — Phase 2.3.3 will sum equipped rows' GearStats through `EquipmentService`.
- Migrations registered in `configure.swift` after `RemoveCrownsField`.
- Still no runtime behaviour change — gear items can now be "marked equipped" in the DB, but nothing writes that flag yet. Build clean.

### What was done (2.3.3 — equip / unequip logic)
- New `Swift/Services/EquipmentService.swift`. Three entry points:
  - `equip(entry, for: user, on: db)` — fetches all the user's inventory rows, unequips any previous occupant of the target slot, writes the new slot on the target row, calls `recomputeBonuses`, then `user.saveAndCache(in: db)` so the session cache is refreshed. The service owns the DB writes here (unlike HungerService which is purely in-memory) because the equip operation spans multiple rows and the caller would otherwise have to reimplement the swap every time.
  - `unequip(entry, for: user, on: db)` — nils the slot, recomputes bonuses, saves user.
  - `equipped(for: user, on: db) -> [EquipmentSlot: InventoryEntry]` — current loadout, keyed by slot. Used by the profile renderer.
  - `recomputeBonuses(for: user, on: db)` — sums each equipped item's GearStats into the user's cached `gear_*_bonus` fields. Mutates user in place.
- `User.recomputeGearBonuses` stub removed — EquipmentService is the single source of truth.
- `User.effectiveAttack/Defense` now read `base + gearBonus − hunger penalty`. Added `effectiveCrit / effectiveDodge / effectiveAccuracy` (hunger doesn't penalize those per GDD — just layer in gear bonus).
- `RegistrationController` set_class callback: after granting the starter weapon via `InventoryEntry.add`, it now looks the row up and calls `EquipmentService.equip` so the King's Oath isn't a lie — the weapon is actually in hand when the King describes it.

### What was done (2.3.4 — UI)
- `InventoryController.categoryKeyboard` split into `gearRows` + `genericRows`. Gear rows:
  - Aggregated by item-id (so two Rusty Swords show as one row with count). A row is flagged "equipped" if any of the aggregated physical rows is equipped.
  - Equipped rows get a leading `📍` and the action button toggles to "❌ Unequip" with callback prefix `inv:unequip:<item_id>`.
  - Unequipped rows keep the original "🛡 Equip" label with callback prefix `inv:equip:<item_id>`.
- New callback handlers `inv:equip:` and `inv:unequip:`:
  - Equip: finds the first unequipped row of the item (via a filtered query) and hands it to `EquipmentService.equip`. Toast: "📍 Equipped: <item>".
  - Unequip: finds the equipped row and calls `EquipmentService.unequip`. Toast: "Unequipped: <item>".
  - Both re-render the gear category in place (new helper `refreshCategory(type:chatId:messageId:context:)`).
- `MainController.showProfile` is now async-aware of equipment: it loads `EquipmentService.equipped(for:)` and passes the `[EquipmentSlot: InventoryEntry]` map to `renderProfile`. All three profile styles got a new line `🗡 Main hand: <item>` (or "(empty)") between the stats block and the gold line. Effective crit/dodge/accuracy now show with gear bonuses too.
- Localization: 5 new keys per locale (`inventory.action.gear.unequip`, `equip.success`, `unequip.success`, `profile.equipped.main_hand`, `profile.equipped.empty`). Total: 111 keys per locale.
- Build clean. EN/UK parity verified (111 = 111, no key drift).

Phase 2.3 complete end-to-end: new character goes through registration → auto-equips starter weapon → King's Oath text matches inventory → profile shows effective stats (base + gear) → player can walk into inventory and swap gear with atomic slot handoff + bonus recomputation.

### Polish (same session)
- Knight's `rusty_sword` bumped from +2 to +3 ATK (knight's secondary stat is pure attack power — mirrors archer's +acc and mage's +crit).
- Per-item inventory icons added via `Item.icon: String?`, set on all four starter gear pieces: ⚔️ (rusty_sword), 🏹 (simple_bow), 🪄 (wooden_staff), 🦺 (leather_vest). `InventoryController.gearRows` prepends the icon to the row label unconditionally — the glyph is part of the item's identity and stays visible whether the item is equipped or not. Equipped state is still conveyed by the Equip/Unequip button toggle (no more 📍 pin). Distinct from `ItemType.icon`, which is the type-level glyph used in the root-category buttons.
- `registration.estate.prompt` no longer addresses the player as "Наміснику" / "Governor" — it now interpolates the nickname the player entered at step 1 ("<b>%{name}</b>, як ти назвеш свій маєток?"). `RegistrationController.promptEstateName` passes `context.session.nickname` into the localize call.
- Added `Assets/registration/kings_charter.jpg` — a single piece of artwork shown for all classes during the King's Oath step. `promptKingOath` now uses `sendPhoto` with the narrative as caption and the inline "Set out for the estate" button as reply markup (falls back to text-only if the file is missing, same pattern as the wolves encounter). Caption fits comfortably under Telegram's 1024-char limit.

## Session 8 — 2026-04-21 (Phase 5.0 — Estate navigation skeleton, Phase 3/4 paused)

### Why out of order
User asked to skip Phase 3 (Exploration) and Phase 4 (Combat) for now and start on Phase 5 (Estate). There's no hard dependency: the estate UI doesn't need exploration loot or combat drops — it needs inventory (already in place from Phase 2). Material-only flows can be tested with `/grant mat.* N` until the drop systems ship. The full grid/plot/crafting of 5.1–5.4 is deferred; this commit lays just the navigation skeleton that the rest will hang off of.

### What was done
- `User.estateLevel` is a computed property: `1 + max(0, level - 1) / 5`. Every 5 player levels bumps the estate tier by one. Not stored — always in sync with the player's level and cheap to read.
- `EstateController` rewritten from a coming-soon stub into a tree nav controller:
  - Root view — shows the estate name + current level + a short lore blurb + inline `[🏠 House] [🌾 Plot]`. If `Assets/estate/level_<N>.jpg` exists, the message is sent as a photo with that caption; otherwise falls back to plain text. User will drop in artwork as they're drawn.
  - House view — inline `[🛠 Workshop]` / `[🍳 Kitchen]` / `[📦 Warehouse]` rows, plus `[🔙 Back to estate]`. Rooms themselves are coming-soon stubs (reuse `stub.coming_soon`) with a back-to-house button.
  - Plot view — single "coming soon" stub + back-to-estate. Full tile-based plots are Phase 5.1.
  - Callback dispatch edits the same message in place. Because the root may have been sent as a photo (caption message) or as plain text, the callback handler branches on `message.getMessage()?.photo != nil` and calls either `editMessageCaption` or `editMessageText` accordingly.
  - Main-nav pass-through (Explore / Capital / Profile / Settings / Inventory / Estate re-tap) wired on the router, same pattern as InventoryController, so the persistent main reply keyboard continues to work while the player is inside Estate.
- `MainController.onEstate` now calls `estateController.showEstate` instead of the old `showStub`.
- `InventoryController.onEstate` pass-through also updated to call `showEstate`.
- No DB migration. No new controller file. No changes to existing game state.
- Locale: 11 new keys per locale → 122 total (EN/UK parity verified).
- Build clean, no warnings.

### Out of scope (future subtasks of Phase 5)
- 5.1 — Estate Fluent model, 30×30 tile grid, Plot model, grid renderer
- 5.2 — Plot management UI, production timers, resource harvesting
- 5.3 — Recipe model, Workshop/Kitchen flows, blueprint learning
- 5.4 — Global estate placement, adjacency queries, frontier rules
- Level-image assets (user will drop JPEGs into `Assets/estate/level_<N>.jpg` as they are drawn)

### Polish (same session)
- `estate.back_root` shortened from "🔙 До маєтку" / "🔙 Back to estate" to just "🔙 Назад" / "🔙 Back". The other back button (`estate.back_home` = "🔙 До дому" / "🔙 Back to the house") is kept intact — per the user's literal ask to change only the "До маєтку" buttons.
- Added the first three estate artwork files: `Assets/estate/level_1.jpg` / `level_2.jpg` / `level_3.jpg`. Root view now shows the actual painted manor for players at estate tier 1/2/3. Higher tiers still fall back to text-only until their artwork is drawn.

### Warehouse — real storage backing (same session, follow-on)
- Added `Swift/Models/WarehouseEntry.swift` — a Fluent model that mirrors InventoryEntry's shape (user_id FK cascade, item_id, quantity, timestamps) but for the estate warehouse. Separate table keeps the backpack/warehouse concerns cleanly split — equipment, consumption, and inventory helpers don't have to learn about a location column.
- Migration `CreateWarehouse` adds the `warehouse` table.
- Helpers on `WarehouseEntry`: `add` (stackable-aware), `list`, `totalQuantity`. No remove/has yet — deposit/withdraw is a later step.
- Dev profile reset now also wipes warehouse rows. The mitya dev seed block does a matching pile for warehouse (same six items as the inventory seed), same top-up + orphan-cleanup semantics.
- `EstateController` — the Warehouse room is no longer a "coming soon" stub. `estate:home:warehouse` shows a category grid with live per-type counts (🍖 Food (N), 🪨 Materials (N), 🧪 Potions (N), 🗡 Gear (N), 💎 Artifacts (N)). Clicking a category (`estate:wh:<type>`) drills down to a text list of every stored item in that category, with per-item icons. Back button returns to the warehouse root.
- 2 new locale keys: `estate.warehouse.description` (root intro), `estate.warehouse.empty` (shown when a category is empty).
- Deposit / withdraw flows and a proper `WarehouseService` are deliberately deferred — this commit just makes the warehouse legible.

### Warehouse deposit / withdraw (same session, follow-on)
- New `Swift/Services/WarehouseService.swift`: `deposit(itemId:for:on:) -> Bool` and `withdraw(itemId:for:on:) -> Bool`. Both move one unit per call. Deposit picks the first UNEQUIPPED inventory row of the item (equipped gear is not transferable). Stackable items decrement/increment quantities; non-stackable rows are deleted/created as a whole.
- `EstateController` warehouse category drill-down rewritten:
  - Computes a `WarehouseCategoryRow` array — the union of inventory + warehouse items of the requested type. Inventory counts skip equipped rows. Rows with 0 on both sides are dropped.
  - Each item renders as a 3-button row: `[🎒 Name] [N ⬆️] [M ⬇️]`. The name button is reserved for a future description view (right now it shows the shared `inventory.info.placeholder` toast). The arrow buttons dispatch `estate:wh:deposit:<id>` / `estate:wh:withdraw:<id>`.
  - After a transfer: toast with the localized result ("⬆️ moved to warehouse", "⬇️ taken from warehouse", or "nothing to deposit/withdraw"), then the category view is rebuilt in place from fresh `InventoryEntry.list` + `WarehouseEntry.list` data.
- 4 new locale keys per locale: `estate.warehouse.deposited/withdrawn/nothing_to_deposit/nothing_to_withdraw`. EN/UK parity 128/128 verified.
- Gear note: because equipped gear is excluded from the transferable inventory count, a sword currently equipped won't appear in the warehouse Gear category at all. Player has to unequip via Inventory → Gear → Unequip first, then the row appears in warehouse view with `1 ⬆️`.

### Polish: transfer button icons + Lingo leading-emoji interpolation bug
- Added inventory/warehouse emojis to the transfer buttons: `[🎒 N ⬆️]` for deposit (from backpack), `[📦 M ⬇️]` for withdraw (from storage). Visually connects the direction to the source container.
- Found and worked around a Lingo interpolation bug: `StringInterpolator` in the miroslavkovac/Lingo dependency builds its scan range from `rawString.count` (grapheme count) but NSRegularExpression interprets ranges in UTF-16 code units. Strings that start with a multi-UTF-16-unit emoji (e.g. "⬆️ %{item} ..." where ⬆️ is U+2B06 + U+FE0F = 2 UTF-16 units, 1 grapheme) get a range that's short by the extra units, which both moves the extracted match off by one char and can drop the closing `}` out of the scan range. Net effect for callers: `%{item}` stays literal in the output, so the user sees the placeholder instead of the actual item name.
- Fixed by rearranging the affected keys so `%{item}` is at the start (no multi-UTF-16 prefix): `estate.warehouse.deposited/withdrawn` and `equip.success`. Also patched `equip.success` proactively — it had the same leading 📍 issue but hadn't been hit yet because the player auto-equips the starter weapon during registration and hasn't clicked Equip manually.
- Safe prefixes for future keys with interpolation: plain ASCII or single-BMP-code-unit characters (e.g. ✅ is one UTF-16 unit and is fine). Avoid leading 📍 🎒 ⬆️ ⬇️ 📦 etc. before an interpolation placeholder, or put the placeholder first.

### Polish: per-row gear display in inventory + warehouse
- Gear is non-stackable — every unit is its own DB row. Previously the UI aggregated rows by item_id and rendered `Rusty Sword × 2` as a single button. Reworked so each gear row is its own button, with no `× N` suffix (it's always implicit 1). Two unequipped rusty swords now show as two identical button rows.
- `InventoryController.gearRows` — iterates InventoryEntry rows directly (no item_id grouping). Sort order: equipped first, then by item id. Each row renders as `[Icon Name] [🛡 Equip / ❌ Unequip]` based on its own `equippedSlot`. Callbacks stay itemId-based — server picks "first matching row" which is indistinguishable from targeting a specific one since identical gear has no per-instance state yet.
- `EstateController.warehouseCategoryKeyboard` — branches by ItemType. For gear: iterates inventory rows (skipping equipped) then warehouse rows, each rendered as `[Icon Name] [🎒 ⬆️]` or `[Icon Name] [📦 ⬇️]`. Single-direction button per row since each physical unit is either in the backpack or in storage — never both. For non-gear: unchanged aggregate with bidirectional `[🎒 N ⬆️] [📦 M ⬇️]` buttons.
- `renderWarehouseCategory` now takes `invEntries` + `whEntries` directly (dropped the pre-computed rows arg) so empty-state detection can branch on type without the caller having to know the logic.
- Both callers of the keyboard/render functions (open-category + post-transfer refresh) updated.

### Dev seed: fan out across all developerUsers
- Previously the inventory/warehouse seed was hardcoded to mitya. Now it iterates the `developerUsers` array — every account listed there gets the same starter backpack + warehouse contents at launch (same top-up + orphan-cleanup semantics as before).
- If the developer row isn't found in the users table or has a nil id, that user is simply skipped (first /start populates them).
- This means changing `developerUsers` in configure.swift is the single place to turn dev-seeding on for a new tester — no need to add a second mitya-specific hardcoded block.

## Session 9 — 2026-04-21 (Phase 3.0 — backpack slot cap, groundwork for exploration)

Starting on Phase 3 (Exploration) — skipping 3 and 4 into a hybrid exploration system per the user's design spec: two modes (active purchase-by-step, passive timed expedition), inventory = expedition bag, death wipes non-equipped inventory, 2-hour daily passive budget. This is just 3.0 — the backpack slot cap that the rest of the exploration loop depends on.

### What was done
- `InventoryEntry.slotCap = 50` constant. A "slot" is one row, regardless of that row's `quantity` (so `bread × 50` is one slot, matching typical RPG convention). Equipped gear rows don't count — they're "on the body" not in the bag.
- New helpers:
  - `slotsUsed(for:on:)` — count of non-equipped rows for a user
  - `canAccept(itemId:quantity:for:on:)` — preflight check, tells callers whether an add would fit. For stackable items with an existing row: always yes (merge). For stackable with no existing row: needs 1 free slot. For non-stackable (gear): needs N free slots for N units.
- `InventoryEntry.add` now throws `InventoryError.inventoryFull` when the cap would be exceeded.
- `WarehouseService.deposit` / `withdraw` switched from `Bool` to typed result enums (`DepositResult.success | .nothingToDeposit`, `WithdrawResult.success | .nothingToWithdraw | .inventoryFull`). Withdraw preflights inventory space before removing from warehouse so we never leak items on a half-failed transfer.
- `EstateController.handleWarehouseTransfer` now dispatches on the enum and surfaces distinct toasts per failure mode. `inventory.full` toast is shared with the `/grant` command and will be reused by exploration loot pickup later.
- `/grant` dev command catches `inventoryFull` and tells the user instead of propagating the error.
- `InventoryController.renderRoot` gains a fullness indicator next to the title: `🎒 Інвентар  3/50 слотів`. Gives the player immediate feedback before they pick up new loot.
- Dev seed wrapped in `do/catch InventoryError.inventoryFull` — on a fresh/wiped dev user it never triggers, but keeps startup robust if ever called on a populated account.
- 2 new locale keys per locale (130 total): `inventory.full`, `inventory.slots_label`.
- Build clean. EN/UK parity verified.

### Next steps
- 3.1 — ExplorationController (active mode MVP), with HungerService drain hooks finally firing, autobattle stub for encounters, death penalty wiping non-equipped inventory.
- 3.2 — return-path visited-rooms memory + depth-decay "already explored" rolls.
- 3.3 — passive timed expeditions with 2h/day budget.
- 3.4 — mode exclusivity (can't be in both at once).
- Localization changes per locale (EN + UK): added inventory.choose_category, inventory.back_root, inventory.action.food/potion/gear/artifact, inventory.info.placeholder, inventory.use.unavailable, hunger.restored, hp.restored, hunger.starving, consume.not_consumable, consume.no_effect, drain.usage, drain.success. Removed inventory.type.recipe, inventory.action.recipe, item.recipe.stew (recipe as an item type was folded away — blueprints will reappear as a separate concept in Phase 5.3 crafting).
- `ItemType.recipe` removed from the catalog/enum (only 5 types now: food, material, potion, gear, artifact). Seed replaces `recipe.stew × 1` with `artifact.shrine_coin × 1`.
- Dev inventory seed upgraded from "run once when empty" to "top-up per item + orphan cleanup": every startup cleans rows whose `item_id` is no longer in the catalog, then tops each seed entry up to its target quantity (never reduces). Rationale: after catalog changes (like removing recipes), stale DB rows linger and the old all-or-nothing seed never refills the new item. Per-item top-up also means consumed test items (e.g., eaten bread) come back on restart — handy for dev.
- Build fully green

## Session 10 — 2026-04-22 (Phase 3.1 — Active Exploration MVP)

The first playable expedition loop. Hunger finally drains, starvation actually hurts, encounters resolve, death has a cost. Designed against the dual-mode spec (active now, passive later in 3.3).

### What was done
- **Data layer**
  - `Models/ExplorationState.swift` + `Migrations/CreateExplorationState.swift` — Fluent model + migration. One row per active expedition, unique on `user_id`, `stepsDeep` tracks the current km. Presence of a row = "currently out exploring", absence = "at the estate". Helpers `current(for:on:)`, `begin(for:on:)` (deletes stale rows defensively), `end(for:on:)` (no-op if absent). Registered in configure.swift.
  - `Models/Enemy.swift` — static code-based bestiary mirroring `ItemCatalog`. `Enemy` struct (id, nameKey, tier, hp/atk/def, depthRange, lootTable, icon) + `EnemyLootDrop` (itemId, chance 0…1, quantity). MVP bestiary: rabid hare / fox / wolf — tiers 1–2, depth ranges 1–3 and 3–6. `EnemyCatalog.pickFor(kmDepth:)` filters by eligibility and picks randomly.
- **Service**
  - `Services/ExplorationService.swift` — pure-ish service with three entry points. `rollStep(for:kmDepth:on:)` drives a single forward step: drains walk-room hunger, applies a starvation HP tick if hunger is already 0, then rolls an event from the weighted bucket (nothing 40 / loot 30 / encounter 25 / trip 5). Loot pool is depth-aware (shallow forest vs medium forest). Encounter goes through the stub `resolveAutobattle` (alternating strikes, ±10% variance, safety cap 50 rounds, one hunger drained per round). Win rolls the enemy's loot table; each drop preflights inventory space with `InventoryEntry.canAccept` so full-bag drops come back as `picked: false`. `StepOutcome` enum carries every path back to the caller (nothing / loot / trip / encounterWon / encounterLost / starvationOnly).
  - Design note left in the file header: the autobattle is a Phase-4 placeholder. Phase 4's round-based `CombatController` will replace it with a real dodge/accuracy/crit-aware engine; shape of `resolveAutobattle` is kept intentionally narrow so the swap is just a function replacement.
- **Controller rewrite**
  - `Controllers/ExplorationController.swift` — replaced the stub entirely. Public entry `showExploration(context:)` resumes an existing state or begins a new one, sends a narrative + status card, and sets a dedicated reply keyboard `[🚶 Step] [🎒 Bag] [🔙 Return]`. Step handler increments `stepsDeep`, calls `ExplorationService.rollStep`, saves the user, renders the outcome narrative and an updated status card in a fresh message (scrolling narrative log). HP ≤ 0 diverts to the death flow.
  - Bag flow is scoped to consumables only — food and potions. Non-consumable types (materials/gear/artifacts) are managed back at the estate, keeping the expedition UI focused on what actually matters mid-walk (eating to avoid starvation, healing). One-tap eat/use refreshes the bag view in place via `editMessageText`; `explore:back` deletes the bag message.
  - Death: wipes every non-equipped `InventoryEntry` row directly (equipped gear survives — per design), sets `hp = 1`, leaves `hunger` as-is (per user's spec: "Hunger stays the same as at death"), ends the exploration state, and drops back to main menu with a dramatic death screen that includes the cause narrative.
  - Return (voluntary): ends the state and shows a short "you returned home" line through `MainController.showMainMenu(context:text:)`.
  - Main-nav integration: `MainController.onExplore` / `InventoryController.onExplore` / `EstateController.onExplore` now all call `showExploration` instead of the old `showStub`. Since `showExploration` sets `routerName` itself, callers no longer duplicate that — removed the pass-through `saveAndCache` block in all three callers.
- **Locale keys (EN + UK)** — ~20 new per locale: expedition keyboard buttons, started/resumed intros, depth label, every outcome narrative (nothing / loot picked / loot full / trip / encounter won / encounter lost / starvation), returned line, death screen with `%{cause}` slot, bag title/empty/back, three enemy names (rabid_hare / rabid_fox / rabid_wolf).

### Design choices to remember
- **Status card on every step**: each step posts a fresh message (not in-place edit), so the expedition reads as a scrolling narrative log. Old cards stay visible with their buttons; tapping a stale button just acts on current state, which is harmless.
- **Bag view scoped to consumables**: deliberate. Mid-expedition the player can only usefully interact with food/potions. Gear/materials/artifacts flows live back at the estate. Full-inventory management during a run was explicitly rejected as overscope for 3.1.
- **Resume on re-entry**: player can tap Explore from main menu (even after opening inventory from inside the expedition via the Bag button + stepping out). `showExploration` detects the existing `ExplorationState` row and resumes at the same `stepsDeep`. Only a deliberate 🔙 Return or death ends the expedition.
- **Event weights are placeholders**: 40/30/25/5. User flagged they will tune these later. They're class constants at the top of `ExplorationService` for easy editing.
- **Autobattle is intentionally dumb**: no dodge/accuracy/crit yet. Phase 4's real combat UI will replace `resolveAutobattle`; the `AutobattleResult` struct has the shape we'll need (playerWon, rounds, hpLost, hungerLost).

### Next steps
- 3.2 — Return-path visited-rooms memory + depth-decay "already explored" rolls.
- 3.3 — Passive timed expeditions with 2h/day budget.
- 3.4 — Mode exclusivity enforcement (active vs passive).
- Phase 4 — real combat UI replacing the autobattle stub.

## Session 11 — 2026-04-22 (Phase 3.2 — Return path with visited rooms)

The one-way expedition from 3.1 becomes a round trip: players walk back through the same rooms, which now roll events with reduced "already explored" weights.

### What was done
- **Schema** — new migration `AddExplorationReturnState` adds two nullable columns to `exploration_state`: `returning` (Bool) and `visited_rooms` (TEXT — JSON array of ints). Nullable was deliberate: existing 3.1 rows still load; the model resolves nil to `outward` + empty set. Registered in configure.swift right after `CreateExplorationState`.
- **Model** — `ExplorationState` gains `@OptionalField` for both columns plus computed wrappers that hide the Optional: `isReturning: Bool` (nil → false) and `visitedRooms: Set<Int>` (JSON encode/decode). Added `markVisited(_:)` and `isVisited(_:) -> Bool` helpers so controller code reads/writes the set declaratively.
- **Service** — `ExplorationService.rollStep` gained an `alreadyExplored: Bool = false` parameter. New parallel weight constants for the decayed table (`weightNothingDecayed 70 / weightLootDecayed 10 / weightEncounterDecayed 15 / weightTripDecayed 5`, sum = 100 — same total so the existing roll logic still works). When `alreadyExplored == true` the service uses the decayed weights; otherwise fresh. Hunger drain and starvation HP tick still fire on every step regardless of direction (walking back still costs food and a starving player still bleeds HP).
- **Controller** — biggest rework since 3.1:
  - `onStep` now dispatches to `stepOutward` or `stepReturning` based on `state.isReturning`.
  - `stepOutward` — increments stepsDeep, rolls with fresh weights, marks the reached km in `visited_rooms`. Same save-user + death-check + render flow as 3.1.
  - `stepReturning` — if `stepsDeep <= 1`, the next step is the arrival at the estate door: skip the event roll, set stepsDeep to 0, invoke `handleHomeReached` (delete state + drop to main menu with "returned" text). Otherwise decrement stepsDeep and roll with `alreadyExplored: state.isVisited(newDepth)`. Because linear return walks are always over visited km, this will always be true in practice — the `isVisited` check is kept for future partial-backtracking scenarios.
  - `onReturnHome` renamed and split:
    - `onReturnButton` — handles the Return reply-keyboard button press. At km 0 it ends the expedition immediately (nothing to walk back). At km > 0 it toggles `state.isReturning` — turning around is free (no hunger drain, no event roll). Sends a narrative + updated status card.
    - `onForceEnd` — new handler for /start and stray Cancel-button presses from other controllers' keyboards. Hard-ends the expedition without walking back, for dev escape / stuck-player cases.
  - Status card (`renderStatusCard`) signature changed from `depth: Int` to `state: ExplorationState` so it can show a "↩️ returning" suffix when the direction is reversed.
  - `narrateOutcome` gained `revisited: Bool = false` — only affects the `.nothing` case, swapping in the "grove is bare" flavor line. Other outcomes reuse the same narratives (mechanical rarity already signals decay).
- **Localization** — 4 new keys per locale (EN + UK), 155 total each: `exploration.turn_around` (outward → returning narrative), `exploration.turn_forward` (returning → outward — "you change your mind"), `exploration.direction.returning` (status-card suffix "↩️ returning" / "↩️ назад"), `exploration.outcome.nothing.revisited` (bare-grove flavor for revisited silence).

### Design decisions to remember
- **Return is mandatory** except via the /start / Cancel escape hatches. No instant-teleport home from the Return button when km > 0 — you walk. This makes deep expeditions genuinely risky: picking up 5 km worth of loot means committing to 5 km of return steps with their own hunger + starvation cost.
- **Turn-around is free** — no hunger drain, no event roll, no stepsDeep change. Just a direction flip. Keeps the UX forgiving: no punishment for scouting ahead then changing your mind.
- **Arrival step skips the roll** — the km 1 → 0 walk is a narrative beat, not a gameplay beat. No final starvation tick, no final event, just "🏰 You return home." This keeps the end-of-expedition feel clean (player wouldn't want to die from starvation on the literal doorstep).
- **Flat decay for MVP** — every revisited room uses the same reduced weights regardless of how deep or how long ago it was visited. Future refinement (3.2-polish) could make deeper rooms less decayed or add time-based regeneration, but the flat table ships now with a single pair of weight constants.
- **Visited rooms persist in JSON, not a relation** — `Set<Int>` encoded as sorted JSON array in a TEXT column. Simple, portable, no extra table, no per-room-event-snapshot storage (deferred). The model's computed `visitedRooms` var hides the encoding entirely.
- **`alreadyExplored` parameter, not two entrypoints** — `rollStep` stays a single function with a default-false parameter. Cleaner than fork-by-function for such a small branch-point.

### Next steps
- 3.3 — Passive timed expeditions. Duration picker (30m / 1h / 1.5h), first real scheduled-background task in the codebase (cron-like simulation on timer completion), report rendering.
- 3.4 — Mode exclusivity. `User.expeditionEndsAt` field + check in `MainController.onExplore`; main menu replaces [🗺 Explore] with "🕒 Out exploring — X min left" while passive is running.
- Future polish: per-room event snapshots for richer return narration; tuning decay weights; depth-proportional decay curve.

## Session 12 — 2026-04-22 (Phase 3.2 — Step Back rework with per-room visit decay)

Replaced the direction-toggle model from earlier 3.2 with an explicit Step Back button and a three-tier visit-count weight table. Simpler UX, more expressive mechanic.

### What was done
- **Keyboard redesign** — no more "Return" button. New expedition keyboard: `[🚶 Step fwd] [🔙 Step back]` on row 1, `[🎒 Bag]` on row 2. Direction is encoded in the button pressed, not in a state flag.
- **Visit counter** — `visited_rooms` changed from a `Set<Int>` (was visited y/n) to a `Dictionary<Int, Int>` (km → visit count). Same DB column (TEXT), different JSON payload (`{"1": 2, "2": 1}` instead of `[1, 2]`). Old 3.2 array-format rows fail to decode as dict and fall back to empty map — harmless since they'd just get fresh-tier rolls.
- **Model cleanup** — removed the `returningFlag` / `isReturning` computed wrappers; the `returning` column stays on the schema but isn't mapped by the model anymore. Renamed helpers: `markVisited/isVisited` → `recordVisit/visitCount`.
- **Service: three-tier weights** — `ExplorationService.rollStep` takes `priorVisits: Int` instead of `alreadyExplored: Bool`. Tier 0 (fresh, priorVisits == 0) = 40/30/25/5. Tier 1 (reduced, priorVisits == 1) = 70/10/15/5. Tier 2+ (bare, priorVisits ≥ 2) = 100/0/0/0 — only `.nothing` or `.starvationOnly` can fire. Trip hazard goes to zero at tier 2+ too, keeping the "room is picked clean" feel consistent.
- **Controller rewrite** — removed every direction-toggle code path (`onReturnButton`, `stepReturning`, `stepOutward`, `turnAround`, direction hint in status card). Replaced with `onStepForward` (always increments + rolls + records) and `onStepBack` (decrements + rolls at km ≥ 2, arrives home at km ≤ 1). Both step handlers pass `priorVisits = state.visitCount(newDepth)` to the service and call `state.recordVisit(newDepth)` after the roll. Step Back at km 0 or 1 ends the expedition cleanly with no roll.
- **Three-variant `.nothing` narrative** — `narrateOutcome` now takes `priorVisits: Int` and picks between `exploration.outcome.nothing` (fresh), `.revisited` (thinned — visit 2), `.bare` (visit 3+). Other outcomes reuse their single narrative since the mechanical depletion at tier 2+ already communicates the "picked clean" feel.
- **Locale keys** — renamed `exploration.button.return` → `exploration.button.step_back`, removed now-unused `exploration.turn_around` / `exploration.turn_forward` / `exploration.direction.returning`, added `exploration.outcome.nothing.bare`. Net change: 154 keys per locale (EN + UK).

### Why reworked
The earlier direction-toggle model conflated two orthogonal concerns — which way you walk and whether the room is depleted. Splitting them gives:
- Cleaner UX: two distinct buttons, no invisible state.
- More expressive mechanic: oscillating between two rooms burns them out in 2-3 cycles, which encourages going deeper rather than camping a single room. The three-tier table makes the second visit "still worth something" and the third+ visit "fully tapped", matching typical foraging-RPG intuitions.
- Less code: no direction flag on the model, no `isReturning` conditional branches, no turn-around narrative paths. The model now has one meaningful field (`visited_rooms`); the old `returning` column lies dormant.

### Design notes
- **km 0 and km 1 both end the expedition** on Step Back — one is "never left", the other is "walked all the way back". Same narrative key (`exploration.returned`) because the narrative distinction is minor and adding a second key wasn't worth it for MVP.
- **Record AFTER the roll** — `priorVisits` needs to be the count *before* this step, so the counter is bumped after `rollStep` returns. On failure/throw, neither the new count nor the state save persists — safe retry.
- **Dormant `returning` column** — intentional trade-off. Dropping it would require a new migration, and the column is harmless. A future cleanup pass could add `RemoveExplorationReturningField` if the schema ever gets noisy.

### Next steps
- 3.3 — Passive timed expeditions. Duration picker + scheduled simulation + report rendering.
- 3.4 — Mode exclusivity: `User.expeditionEndsAt` + main-menu busy state.
- Balance: playtest visit-decay weights; consider depth-proportional adjustments.

## Session 13 — 2026-04-22 (Weight retuning + passive estate regen)

Two small follow-ups after playtesting 3.2:

### Weight retuning
Fresh-tier had `nothing` at 40% which felt too empty — every other step was silence. Retuned:
- Fresh (priorVisits = 0): `nothing 40 / loot 30 / encounter 25 / trip 5` → **`20 / 40 / 30 / 10`**
- Reduced (priorVisits = 1): `70 / 10 / 15 / 5` → **`50 / 20 / 20 / 10`**
- Bare (priorVisits ≥ 2): unchanged at `100 / 0 / 0 / 0`

Every step now has an 80% chance of *something* on first visit (vs 60% before), still 50% on second visit, zero on third+. Trip doubled from 5 → 10 to make damage more present before encounters come out. Numbers are gameplay-driven, easy to tune later.

### Passive HP regen at the estate
First properly lazy-computed idle mechanic in the codebase. Needed:
- **Migration** `AddHpRegenTick` — adds nullable `last_hp_tick_at: Date?` column on `users`.
- **Model** `User.lastHpTickAt` via `@OptionalField`. Initialized nil; `HealingService` primes it on first damaged observation.
- **Service** `HealingService.tick(_:on:)` — pure enum namespace. Rate is `regenPerMinute = 0.05` (5% of maxHp), capped at `maxIdleMinutes = 1440` (24h) to prevent absurd offline top-ups. Returns the amount restored; caller can log / ignore. Handles four cases:
  1. `routerName == "exploration"` → clear the clock (suspend regen during expedition).
  2. `hp >= maxHp` → pin clock to now (prevents banked regen accruing against future damage).
  3. `lastHpTickAt == nil` → prime clock to now, no regen yet.
  4. Otherwise → compute `floor(maxHp · 5% · minutes)`, apply, advance clock.
  Saves via `user.saveAndCache(in: db)` inside each case that mutates, so the caller doesn't need to remember to.
- **Wire-in** `RouterStore.process` — after hydrating the user from the session cache, calls `HealingService.tick` before dispatching to the router. Every interaction goes through `RouterStore.process` already, so this is the single choke point. `HealingService.tick` is a no-op when the user is exploring or at full HP, so the overhead on those paths is just a routerName + hp compare.

### Why the pin-on-full-HP matters
Without pinning: a player at full HP with `lastHpTickAt` from Monday walks into the forest Friday, takes damage, walks home. On their next interaction, `tick` sees `lastHpTickAt` from Monday, computes four days of elapsed time (capped at 24h), and instantly refills them. Pinning at every full-HP tick bounds the banked regen window to ≈ one interaction interval.

### Design notes
- **Lazy vs scheduled**: opted for lazy compute because user interactions are sparse (text-bot cadence) and the alternative needs a background loop. Scheduled mechanics start landing in 3.3 (passive expeditions); HP regen didn't justify it alone.
- **Capped idle**: 24h cap is a soft anti-abuse measure. Also saves us from pathological clock-skew situations.
- **Routerame as proxy for "at estate"**: any non-`exploration` controller counts as "resting". Registration, settings, inventory, estate, capital — all accrue regen. Simple and matches intuition.

### Next steps (unchanged)
- 3.3 — Passive timed expeditions. Duration picker + scheduled simulation + report rendering. First real background scheduler.
- 3.4 — Mode exclusivity: `User.expeditionEndsAt` + main-menu busy state.

### Clarification (later same session)
User confirmed the two-mode split and explicitly pinned down timing:
- **Active reconnaissance (розвідка)** — fully tap-driven, no transition timer. This already matches the 3.1/3.2 implementation; GDD and game-core had carryover language from an earlier draft that implied a timer in both modes. Edited GDD §5 and `.memory/game-core.md` to scope the 5-min room transition to **passive expedition only**.
- **Passive expedition (експедиція)** — stays timer-gated (5 min prod / 10 sec test), still the Phase 3.3 target.

No code changes needed — active mode's ExplorationController already has zero time-gates. The only "tick" in the codebase now is `HealingService.tick` for passive HP regen at the estate, which is lazy-compute and doesn't gate gameplay.

## Session 14 — 2026-04-22 (Phase 3.3 — Passive expedition MVP in test mode)

First truly background-running code in the project. The passive expedition flow sits behind a new mode-picker and fires a rendered report when its Task.sleep elapses.

### What was done
- **Schema** — new migration `AddPassiveExpeditionFields` adds three nullable columns to `exploration_state`: `mode` (TEXT), `ends_at` (TIMESTAMP), `report_json` (TEXT). One table covers both active and passive runs; active rows leave all three nil.
- **Model** — `ExplorationState` gains `@OptionalField` mappings plus an `ExplorationMode` enum (active/passive), `isPassive` / `hasReadyReport` / `secondsRemaining(now:)` queries, and a `beginPassive(for:endsAt:on:)` factory alongside the existing `begin`. `allPassive(on:)` helper used by the startup rescheduler.
- **Service** — `PassiveExpeditionService`:
  - `PassiveDuration` enum (short=30 / medium=60 / long=90 *units*). `testMode: Bool = true` flag governs whether a "unit" is one second (test) or one minute (prod). Step count is `rawValue / 5` — same 6 / 12 / 18 step count in both modes, only the wall clock changes.
  - `start(for:duration:on:bot:lingo:)` creates the state row then calls `scheduleCompletion(stateId:endsAt:db:bot:lingo:)`, which spawns a `Task.detached` that sleeps until `endsAt` and invokes `completeIfDue`.
  - `completeIfDue` re-fetches the state fresh, confirms it's still passive + unreported, loads the user via `$user.load(on:)`, runs `simulate`, encodes the `PassiveReport`, saves user + state, pushes the report message, and deletes the state on successful push.
  - `simulate` runs N `ExplorationService.rollStep` calls with `priorVisits: 0` (passive treks fresh ground). Mutates the real user (hp/hunger/inventory) directly. Aggregates outcome counts + picked/dropped loot into a `PassiveReport` Codable blob. Breaks early if hp hits 0; applies the same death penalty as active mode (wipe non-equipped inventory, hp = 1).
  - `rescheduleInflight(on:bot:lingo:)` — called from `configure.swift` right after `bot.start()`. Scans all passive states; for each, either delivers immediately (endsAt already passed during downtime) or re-arms a `Task.sleep` for the remainder. Idempotent — `completeIfDue` checks `reportJSON != nil` and skips if already done.
  - `renderReport` builds the multi-line HTML message from the `PassiveReport`. Shows reached depth, HP/hunger before/after, an outcome histogram (🕊 silence × 5 · ✨ find × 3 · ⚔️ victory × 2 · …), and the loot list (with partial-drop footnote if the bag overflowed). Death path swaps the opening line.
- **Controller** — `showExploration` branches:
  1. Passive state with a ready report → deliver report + delete state + drop back to main.
  2. Passive state in flight → send countdown text; routerName stays where it is so HP regen + nav keep working.
  3. Active state → existing resume flow.
  4. No state → mode picker.
  New picker flow: `explore:mode:active` → `beginActive`; `explore:mode:passive` → edits the message to the duration picker; `explore:dur:<raw>` → `PassiveExpeditionService.start` + confirmation message + fresh main-reply-keyboard message. `explore:passive:close` dismisses the delivered report.
- **Startup rescheduler** — `configure.swift` calls `PassiveExpeditionService.rescheduleInflight(on:bot:lingo:)` right after `appState.bot.start()`. Bot restarts no longer orphan passive expeditions.
- **Locale keys (EN + UK, 27 new per locale, 180 total)** — mode picker (prompt / active / passive), duration picker (prompt / 30m / 1h / 1h30m / back), passive status (started / inflight / test_mode_hint), report rendering (title / depth / hp / hunger / events_header / loot_header / no_loot / loot_partial / death / close), and six outcome labels (nothing / loot / encounter_won / encounter_lost / trip / starvation) used in the histogram line.

### Design decisions to remember
- **Test mode toggle, not separate constants.** `testMode: Bool` flips the unit-to-seconds ratio. Same duration numbers (30/60/90), just interpreted differently. Flipping to prod is a one-line change when we're ready.
- **One expedition table, two modes.** Didn't split into a `PassiveExpedition` table because the exclusivity rule ("one expedition at a time") is naturally expressed by a single row per user. `mode` column discriminates.
- **Simulation mutates the real user.** Loot goes straight into inventory; hp/hunger change directly. Relied-upon by `HealingService.tick`: while the passive timer counts down, the player's routerName is NOT "exploration" (they're at estate), so HP regen runs normally. When the simulation fires, user's hp is whatever the regen brought them to — that's the "fresh" pool the simulation damages.
- **Delete state after successful push.** The background push pings the player's chat; on success the row is gone so `showExploration` next goes to mode picker. On push failure the row stays (with reportJSON); `showExploration` delivers on next open. Either way, the player sees the report exactly once.
- **Detached task, no cancellation handle stored.** If the player somehow triggers the same expedition twice (shouldn't happen), `completeIfDue` is idempotent — it no-ops when `reportJSON != nil`.
- **Routername convention.** Active mode still sets routerName = "exploration" because its reply keyboard needs to be distinct. Passive keeps routerName at main so the player can browse estate / inventory / profile normally during the wait, and HP regen works.
- **No 3.4 exclusivity yet.** The player *could* currently start an active mode while a passive is in flight — the mode picker doesn't check. 3.4 will add the guard (+ the "🕒 Out on expedition, X min left" main-menu indicator).

### Next steps
- Test the flow end-to-end in the bot (restart with fresh binary to pick up new migrations + code).
- 3.4 — mode exclusivity: main-menu busy state + guard on Explore entry.
- Flip `testMode` to `false` once UX is validated.
- Daily 2h budget. Early-cancel for in-flight passive.
- Phase 4 — real combat UI replacing the autobattle stub (used by both modes).

### Mini fix (same session): "governor is away" guarantees
Small but important: during passive expedition the governor is in the forest, not at the estate. Two fixes so the mental model matches:
- **HP regen pauses during passive too.** `HealingService.tick` signature changed from `(user, db)` to `(user, inExpedition, db)` — the `routerName == "exploration"` check was a proxy that only caught active mode. `RouterStore.process` now queries `ExplorationState.current` once per interaction and passes the presence as `inExpedition`. Both active and passive correctly suspend regen.
- **Estate entry blocked while any ExplorationState row exists.** `EstateController.showEstate` gained a guard at the top — if an expedition row exists, it sends `estate.blocked_by_expedition` notice and returns without transitioning routerName. Callers (MainController.onEstate, InventoryController.onEstate) were also simplified: they no longer set routerName themselves, `showEstate` owns that transition so it can abort cleanly when blocked. Added one locale key in EN + UK (total 181 per locale).

## Session 15 — 2026-04-22 (Phase 3.4 — mode exclusivity)

Final Phase 3 piece. Surfaces the expedition-in-progress state in the main reply keyboard, blocks both city screens, and closes remaining race windows around the mode picker.

### What was done
- **`User.transientInExpedition: Bool`** — non-persisted stored property on the User class. Refreshed by `RouterStore.process` on every dispatch from the same `ExplorationState.current` query that drives HealingService. Controllers read it synchronously — no extra DB round-trips.
- **Busy-label main keyboard** — `MainController.generateControllerKB` picks `commands.explore.busy` ("🕒 On expedition" / "🕒 У поході") instead of the normal label when `session.transientInExpedition == true`. Tap still routes to `onExplore` → `showExploration`, which branches to passive countdown / active resume / report delivery as before.
- **Busy label registered everywhere that passes through Explore** — MainController, EstateController, InventoryController each add a second pass of locale-iterated registrations for the busy label so a tap from inside any of those controllers still reaches `onExplore`.
- **Picker idempotency** — `explore:mode:active` / `explore:mode:passive` / `explore:dur:*` each re-check `ExplorationState.current` at the top. If a state already exists (stale picker from a previous screen, a race with the passive scheduler), the handler dismisses the inline message and redirects to `showExploration` so active progress / in-flight passive isn't silently wiped.
- **Capital blocked during expedition** — `CapitalController.showStub` got the same guard pattern as `EstateController.showEstate`: check for `ExplorationState.current`, send `capital.blocked_by_expedition` notice, bail out without changing routerName. Callers (MainController.onCapital, InventoryController.onCapital, EstateController.onCapital) simplified to trust `showStub` for the transition. `CapitalController` now imports Fluent.
- **Explicit flag resets at expedition end-paths** — `goToMainMenu` (shared helper used by home-reached, force-end, and the passive-report's close-to-main flow) now sets `transientInExpedition = false` before calling `mainCtrl.showMainMenu`. Same reset at the top of `handleDeath` and at the end of `deliverPassiveReport`. Without this, the reply keyboard in the very same response message would still show the busy label (RouterStore only refreshes on the *next* dispatch).
- **Flag set to `true` after `PassiveExpeditionService.start`** — so the main-menu keyboard sent from the duration-pick callback uses the busy label immediately.
- **Locale keys (+2 per locale, 183 total)**: `commands.explore.busy` and `capital.blocked_by_expedition`.

### Design decisions
- **Transient flag instead of async keyboards.** Making `generateControllerKB` async / db-aware was the clean alternative but touches every call site. A single cached flag read synchronously keeps existing signatures intact.
- **Static busy label, no live countdown in the keyboard.** Reply keyboards only update when a new message sends them; live countdowns would flood the chat. The label is a static "🕒 On expedition" — tapping it opens the countdown message with precise MM:SS.
- **Both rural (Estate) and urban (Capital) locations blocked.** Inventory intentionally stays accessible — the bag is a meta concept the player can always peek at, and forcing it closed during expedition would be annoying.
- **Idempotency on mutating callbacks only.** The `explore:mode:pick` back button and bag callbacks don't mutate state, so they don't need guards.

### Phase 3 closure
3.0 (slot cap) → 3.1 (active MVP) → 3.2 (visit-decay return path + passive HP regen) → 3.3 (passive expedition with background scheduler) → 3.4 (mode exclusivity / UX guards) all landed. Remaining backlog on the exploration track: flip `PassiveExpeditionService.testMode` to `false` for prod durations, 3.5 content expansion (more enemies / richer events), and eventually Phase 4's real combat UI replacing the autobattle stub.

### Post-3.4 fixes (same session)
Two bugs surfaced during playtest:
- **Close-report left "🕒 On expedition" keyboard stale.** The `explore:passive:close` callback only deleted the inline message; the reply keyboard from an earlier message still showed the busy label, and the state row (with `report_json`) lingered, so `transientInExpedition` would flip back to `true` on the next dispatch. Fixed by doing the full cleanup in the close handler — delete state if present, reset the transient flag, save, and send a fresh `MainController.showMainMenu` message so the reply keyboard rebuilds with the normal "🗺 Explore" label. `deliverPassiveReport` (the re-open path) was updated to do the same trailing main-menu send.
- **Passive death report claimed loot that was already wiped.** `applyDeath` inside `simulate` correctly wiped non-equipped inventory rows when HP hit 0, but the `PassiveReport` was still being populated with the picked/dropped list gathered during the loop. Players saw "Brought back: Berry × 3" while the DB showed an empty backpack. Fixed by zeroing `report.loot` in `simulate` when `died == true`, and updating `renderReport` to skip the loot section entirely when `report.died` (the death line at the top already communicates full loss).

### Revert: dynamic busy-label on the main keyboard
During playtest the "🕒 On expedition" reply-keyboard label didn't reliably revert after closing the passive report — Telegram only redraws reply keyboards when a fresh message carries a new `replyMarkup`, and hitting every edge case (close button, scheduler push, deliver-on-reopen, restart) was adding complexity for a feature the user deprioritized. Simplified per user's direction: the Explore button label is now static. The gating is done purely at `showExploration` entry via the passive-countdown branch — tapping Explore during an active passive run now sends the exact message the user requested: "Ти вже в експедиції. Очікуваний час прибуття: MM:SS".

Removed in this pass:
- `User.transientInExpedition` (field + all write sites in RouterStore and ExplorationController end-paths / start callback)
- Busy-label registrations in Main / Estate / Inventory attachHandlers
- `commands.explore.busy` locale key (EN + UK, back to 182 per locale)
- Dynamic branch in `MainController.generateControllerKB`

Kept (still valuable regardless of label strategy):
- Estate + Capital guards during any expedition
- Idempotency guards on mode/duration picker callbacks
- `goToMainMenu` / `deliverPassiveReport` / passive-close callback still send a fresh main menu after cleanup so the reply keyboard from an active expedition (step/back/bag) is replaced by the main reply keyboard.

### Live per-step passive simulation (same session)
User pointed out that dying on step 2 out of 18 still made them wait the full timer for the report — the earlier implementation ran all N steps at once at `endsAt` and only then pushed the result. Rewrote the scheduler:
- `scheduleCompletion` now spawns a `Task.detached` running `runLive` instead of `completeIfDue`. The one-shot `simulate()` + `completeIfDue()` helpers were deleted.
- `runLive` is a per-step loop. Each iteration: sleeps until the step's absolute fire time (`createdAt + K * stepDurationSeconds`), reloads state + user from the DB, calls `rollStep` for one km, persists `state.stepsDeep`, checks for death. On death it calls `applyDeath` (wipe non-equipped inventory, hp = 1) and jumps straight to `finalizeAndPush` — no more waiting out the remaining timer.
- Step duration is `secondsPerUnit * unitsPerStep` (5 units/step). Test mode = 5 s/step, prod = 300 s/step. Same total step count as before (6/12/18), just now spread over real time.
- Progress is tracked via `state.stepsDeep` (previously unused for passive rows). `rescheduleInflight` on bot startup just spawns a fresh runLive task per in-flight state; runLive reads `stepsDeep` to know where to resume. Any step whose scheduled fire time fell during downtime runs without sleep ("catch-up") so the expedition can't be stretched by bot outages.
- Outcome counters / loot totals are NOT persisted across restarts (Swift locals in the Task). If the bot crashes mid-simulation the final report only reflects post-restart events. Acceptable MVP tradeoff — passive expeditions are short; crashes should be rare.
- The `finalizeAndPush` helper is shared by both the normal end-of-run path and the early-death path. It writes the JSON, saves the state, and pushes the report message.

### Post-live-scheduler fixes (same session)
Three bugs surfaced while playtesting the new per-step scheduler:

1. **Stale `exploration_state` row across `resetDevProfile = true` restarts.** When dev mode wipes user fields + inventory + warehouse but leaves `exploration_state` intact, a passive row from a previous session can re-fire `deliverPassiveReport` on the next Explore tap. Fixed by adding `try await ExplorationState.end(for: user, on: db)` to the dev-reset block in `configure.swift`.

2. **Lingo interpolation fails when a surrogate-pair emoji appears BEFORE the `%{placeholder}` in the source string.** Our earlier memory note called it "leading emoji breaks interpolation" but the real rule is stricter: any multi-UTF-16 emoji *anywhere before* a `%{name}` token in the localized string prevents it from substituting. Single-UTF-16 chars (+, Cyrillic, Latin) before the placeholder are fine. Rewrote the affected passive-mode strings so placeholders precede every emoji in the string, e.g. `"Expected return in %{time}. Your governor has set off on an expedition 🏕."` instead of `"🏕 Your governor ... %{time}"`. Added the precise rule to `.memory/localization.md`.

3. **Close button on the scheduler-pushed report did nothing visible (and state wasn't cleaned up).** The scheduler pushes the report inline message while the player's `routerName` is `main` (or `inventory` / `settings` if they navigated). Tapping Close there went through that controller's `onCallbackQuery`, which didn't recognise `explore:passive:close` and fell into a generic "delete message" fallback. `ExplorationController`'s full cleanup (delete state row, send "back at the estate" greeting) never ran, so the next Explore tap hit `deliverPassiveReport` again and re-showed the report. Fixed by forwarding any `explore:`-prefixed callback from `MainController` / `InventoryController` / `SettingsController` to `ExplorationController.onCallbackQuery` at the top of their handlers. Also decoupled `showExploration`'s passive-report branch so the state row is deleted *before* the render call, preventing a future duplicate from a stuck state row.

Also renamed `deliverPassiveReport`'s signature from `(context, state: ExplorationState)` to `(context, reportJSON: String?)` — the caller now snapshots the JSON and deletes the state row first, then hands only the serialized payload to the renderer, so even a thrown exception during render leaves no state to re-deliver.

### Material catalog rework (same session)
Player-defined content pass — replaced the placeholder materials with lore-flavoured resources:
- `mat.wood` → `mat.pine_lumber` 🌲 "Pine Lumber"
- `mat.stone` → `mat.river_pebble` 🪨 "River Pebble"
- `mat.iron_ore` → `mat.old_iron` ⛓ "Old Iron"
- `mat.hide` 🟫 stays (name unchanged, icon + description added)
- NEW: `mat.clay` 🧱 "Wild Clay"

Implementation:
- `Item` struct gained `descriptionKey: String?` — optional locale key for the lore blurb shown as a modal alert (`answerCallbackQuery(text: description, showAlert: true)`) when the player taps the item's info button. Nil falls back to the existing "description coming soon" toast.
- `ItemCatalog` — replaced 3 material entries + added 1. Each now carries `icon:` (per-item emoji) and `descriptionKey:` pointing at a `.desc` locale key.
- `Item.icon` is now rendered for non-gear rows too (`InventoryController.genericRows`, `ExplorationController.renderBag`, `EstateController` warehouse) — previously only gear used it.
- Info callbacks updated in three controllers (inv / explore / estate) — unified pattern: modal alert on description present, placeholder toast otherwise.
- Migration `RenameMaterialIds` rewrites `inventory` + `warehouse` rows via `.set(\.$itemId, to: new).update()` so existing stockpiles carry forward after the rename.
- Side-effects: `ExplorationService.rollLoot` shallow/medium pools, `EnemyCatalog` rabid_wolf loot table, and `configure.swift` dev seed all updated to new IDs (plus `mat.clay` / `mat.old_iron` added to the seed).
- 6 new locale keys per locale (EN + UK): 4 new names (pine_lumber, river_pebble, clay, old_iron) + 5 descriptions (`...desc` keys for every material including existing hide). Total 189 per locale.

### Food catalog rework (same session)
Mirrors the material pass — replaced the placeholder bread/stew/roast/berry lineup with a lore-flavoured raw-food family:
- `food.berry` → `food.forest_berries` 🫐 (+15 hunger)
- NEW `food.forest_nuts` 🌰 (+20 hunger)
- NEW `food.potato` 🥔 (effects: [] — strategic ingredient, not raw-edible)
- NEW `food.duck_egg` 🥚 (+25 hunger)
- NEW `food.raw_meat` 🥩 (+30 hunger)
- Removed: `food.bread`, `food.stew`, `food.roast` (cooked variants come back via Kitchen in Phase 5.3)

Implementation:
- `ItemCatalog` food section rewritten with icon + descriptionKey per entry.
- `Item.effects` kept as `[]` for potato — conveyed through a new `consume.not_raw_edible` toast (new locale key): "You can't eat %{name} raw — it needs cooking." Both `InventoryController.inv:use` and `ExplorationController.explore:eat` now check `item.effects.isEmpty` before calling `HungerService.consume` so the player doesn't get the misleading "no effect — already fully restored" fallback.
- `ExplorationService.rollLoot` pools: shallow forages forest_berries/forest_nuts + lumber/pebble; medium adds duck_egg/raw_meat (alongside hide/old_iron/clay).
- `EnemyCatalog` rabid_hare now drops raw_meat instead of berries (semantically: meat from a kill, not foraged berries).
- `configure.swift` dev seed refreshed: forest_berries × 3, forest_nuts × 2, duck_egg × 1, raw_meat × 1, potato × 2. Bread/stew removed from seed.
- Migration `RenameFoodIds` renames berry → forest_berries in `inventory` + `warehouse`, and DELETEs bread/stew/roast rows (no replacement mapping; orphan cleanup via dev seed handles the dev side but the explicit delete covers any non-dev DB rows too). Registered right after `RenameMaterialIds`.
- 11 new locale keys per locale (EN + UK): 5 new names (forest_berries, forest_nuts, potato, duck_egg, raw_meat) + 5 descriptions + `consume.not_raw_edible` with `%{name}` interpolation. Total 196 per locale.

### Per-item foraging flavor (same session, 2026-04-23)
Active-mode loot narration upgraded from one-line-fits-all to per-item lore:
- 8 new `exploration.find.<item_id>` keys per locale — one flavor sentence per foraging item. E.g. "Ви знайшли повалену сосну 🌲, ідеально придатну для обробки." for `mat.pine_lumber`.
- `ExplorationController.narrateOutcome` `.loot` case now picks the per-item flavor when present (Lingo returns the key verbatim on miss — we detect that and fall back to the pre-existing generic `exploration.outcome.loot.picked/full` template). When found, renders `<flavor>\n<b>+N ItemName</b>` for pickups and appends `<i>Сумка повна — лишається на землі.</i>` (new `exploration.outcome.loot.bag_full` key) for full-bag drops.
- Quantity is now `Int.random(in: 1...2)` — foraged stacks come in 1s or 2s rather than always 1.
- Foraging pool tightened to match the 8-item flavor list: shallow = forest_berries / forest_nuts / pine_lumber / river_pebble; medium = potato / duck_egg / clay / old_iron. `mat.hide` and `food.raw_meat` removed from the pool — both are now exclusively enemy-kill drops (semantically consistent with their lore descriptions).
- Encounter loot (`.encounterWon` drops from enemy kill tables) still uses the plain `exploration.outcome.loot.picked/full` template since those aren't "foraging finds".
- 9 new locale keys per locale (EN + UK, 205 total).

### Bestiary expansion (same session)
Pre-combat content pass — reshaped the roster around two thematic families:
- **Wild animals** (killable + cookable): 🐗 wild_boar / 🫎 wild_moose / 🦬 wild_buffalo — drop `food.raw_meat` + `mat.hide`
- **Rabid animals** (meat inedible, only hide): 🐈‍⬛ rabid_lynx / 🐺 rabid_wolf — drop `mat.hide` only

Removed: `enemy.rabid_hare` and `enemy.rabid_fox` (not in the user's new spec). Tier distribution maps to 5-km bands:
- T1 (km 1-5): boar
- T2 (km 6-10): boar + moose
- T3 (km 11-15): moose + buffalo + lynx
- T4 (km 16-20): buffalo + lynx + wolf

Stats ordered weakest → strongest: boar (hp 18 / atk 5 / def 1) → moose (32/8/2) → buffalo (55/11/4) → lynx (45/13/2 — glass cannon) → wolf (70/15/4 — top hostile). Each animal covers one or two consecutive tiers via its `depthRange`; wolf only spawns at tier 4. `mat.old_iron` was dropped from the wolf loot table to keep rabid drops hide-only per design.

Also updated the file header comment and 4 new/renamed locale keys per locale (enemy.wild_boar / wild_moose / wild_buffalo / rabid_lynx added, rabid_hare / rabid_fox removed, wolf unchanged). Total 207 per locale.

### Exploration outcome emoji → leading position (same session, 2026-04-23)
Cosmetic pass on 5 exploration narration keys to put decorative emoji at the START without breaking Lingo interpolation. New rule refinement uncovered during the fix:

**Lingo interpolation bug extends to BMP+VS16** (variation selector U+FE0F), not just surrogate-pair emoji. ⚔️ = ⚔ (U+2694) + VS16 = 2 UTF-16 units → breaks interpolation after it. ⚔ alone = 1 UTF-16 → SAFE. Single-UTF-16 BMP emojis (✨ ⚡ ❗ ❌ ⏳ ⭐ ⛔ ⛺ etc.) can all safely lead a string with placeholders. See `.memory/localization.md` for the refined rule + verified-safe set.

Changes applied:
- `exploration.outcome.trip`: trailing 🪨 → leading ❗
- `exploration.outcome.encounter.won`: trailing ⚔️ → leading ⚔ (no VS16, single UTF-16)
- `exploration.outcome.encounter.lost`: trailing 💀 → leading ❌
- `exploration.outcome.starvation`: trailing 🥀 → leading ⏳
- `exploration.death`: mid-message 💀 → leading ❌

User confirmed ⚔ without VS16 renders as colour emoji on iOS/Android/Telegram Web; only macOS Telegram shows it text-style — acceptable tradeoff. Surrogate-pair originals (🪨 💀 🥀) had no single-UTF-16 equivalent so were swapped to thematic single-UTF-16 alternatives rather than preserved at end.

Also flipped `resetDevProfile` back to `false` in `configure.swift` (dev profile state persists across restarts again).

No locale count change (207/207). No code changes — cosmetic strings only.

### UX bug-fix pass (2026-04-23)
Cluster of six user-reported UX fixes + catalog tweaks, unified under one commit theme.

**1. Mode-picker no longer traps main-menu buttons.** Previously `showModePicker` set `routerName = "exploration"`, so tapping Profile / Estate / Capital / Inventory / Settings while the picker was visible fell through to `ExplorationController.unmatched` → re-rendered the picker. Now the picker keeps `routerName = "main"` (callbacks still reach ExplorationController via the existing `explore:*` callback forwarding in MainController.onCallbackQuery). Added `Swift/Helpers/EphemeralChatState.swift` — in-memory actor caching transient picker message IDs per user — and a `dismissPendingPicker(context:)` helper on `TGControllerBase`. Every MainController main-menu handler (`onStart`, `onSettings`, `onProfile`, `onEstate`, `onCapital`, `onInventory`) calls `dismissPendingPicker` at the top, which deletes the cached picker via `deleteMessage`. No migration — in-memory is enough since stale pickers in chat history after a bot restart just behave like a live picker if tapped (harmless).

**2. Passive expedition completion delivers as one message, no Close button, state auto-cleared.** Previously `pushReportNotification` sent the report with a `[🔙 Close]` inline button and left the state row in DB until the user tapped Close — players were forgetting to tap it, keeping Estate / Capital locked. Now the scheduler push sends a **single combined message** (home-again line + report body, no inline keyboard) and calls `ExplorationState.end` immediately on success. If either send throws, state is preserved and `deliverPassiveReport` retries on the next Explore tap. Same treatment in `deliverPassiveReport` for the controller-delivered path. The `explore:passive:close` callback handler is kept for backwards compat with any Close button in pre-fix chat history but is no longer reachable via new messages. The `exploration.passive.report.close` locale key is dead but kept (small; easier to restore a Close button later if needed).

**3. Loot lines in the report now include per-item icons.** `PassiveExpeditionService.renderReport` prepends `Item.icon` to each loot entry name — `🥔 Картопля × 3` / `🪵 Сосновий брус × 1`. Icon is prepended in Swift (not inside the `%{dropped}` Lingo template) so surrogate-pair emoji don't break interpolation. Same safety pattern is documented in `.memory/localization.md` as the go-forward rule.

**4. Redundant bare "🏰" send removed.** After starting a passive expedition (`explore:dur:*` callback), a standalone `"🏰"` message was being sent to restore the main reply keyboard. With fix #1, `routerName` stays at main during the picker + duration picker, so the reply keyboard never gets swapped and the "🏰" message was pure noise. Removed.

**5. Catalog emoji swaps + raw-meat made inedible.**
- `Item.swift` — `mat.pine_lumber` icon: 🌲 → 🪵 (processed lumber vs. the tree; 🌲 stays in the flavor text for the discovery moment).
- `ExplorationController.narrateOutcome.trip` + `exploration.passive.outcome.trip` (both locales): prefix 🪨 → 🦵 (tripping is a leg thing, not a rock thing; 🪨 stays as `river_pebble`'s icon and `material` category icon).
- `Item.swift` — `food.raw_meat.effects: []` (was `[.restoreHunger(30)]`). Raw meat now needs to be cooked in the Kitchen before it's edible, same pattern as `food.potato`. Both share the `consume.not_raw_edible` toast. Active mode's Eat button + Inventory's Use button both check `item.effects.isEmpty` before calling `HungerService.consume`. Kitchen cooking will come in Phase 5.

**6. Foraging flavor emoji moved to sentence start in all 8 `exploration.find.*` keys.** Previously emoji was at the end or mid-sentence ("Ви знайшли повалену сосну 🌲, ..."). Now it's the first character ("🌲 Ви знайшли повалену сосну, ..."). Safe because these keys have no `%{...}` interpolations. Same pattern for both locales (16 string edits total).

**7. Passive-expedition `.inflight` string rephrased.** uk "Очікуваний час повернення: %{time}" / "Очікуваний час прибуття: %{time}" (colon) → "через %{time}" (preposition). Matching en update: "Expected return: %{time}" → "Expected arrival in %{time}. Your governor is still on expedition 🏕."

**8. Leading emoji on exploration narration reverted to original surrogate-pair glyphs via code prefix.** Earlier in the session we had swapped `🪨/⚔️/💀/🥀` for safe single-UTF-16 equivalents (`❗/⚔/❌/⏳/❌`) in the JSON templates. User preferred the original colourful surrogate-pair glyphs. Final approach: Lingo template stays placeholder-first (no leading emoji), Swift prepends the original `🪨/⚔️/💀/🥀/💀` (for trip / encounter.won / encounter.lost / starvation / death) after `lingo.localize(...)`. This is the GO-FORWARD rule documented in `.memory/localization.md` — any localized string with interpolations should not have a leading emoji in its Lingo template; put decoration in Swift.

No locale count change (still 207/207). `.memory/localization.md` expanded with the go-forward rule + verified-safe single-UTF-16 BMP emoji allowlist. New file: `Swift/Helpers/EphemeralChatState.swift`.

## Session — 2026-04-25 (Friend-playtest UX bug-fix pass)

User handed the build to a friend and collected concrete UX bugs. Fixes applied across registration, exploration narration, race conditions, and the bot-startup admin notification. No new files.

**1. First registration message clears the reply keyboard.** `Registration.showLanguageSelection` now sends a tiny "👋 Welcome, <name>!" preamble with `ReplyKeyboardRemove` *before* the language picker. Telegram only accepts one `replyMarkup` per message, so the picker (with its inline buttons) is sent as a follow-up. Without this strip, players who arrived from a prior bot session with a leftover reply keyboard could tap a button label and that text was accepted as their nickname / estate name.

**2. Nickname + estate-name input validation** — shared helper on `Registration`:
```swift
private static let nameDigits      = Set("0123456789")
private static let nameLatin       = Set("abc…XYZ")
private static let nameUkrainian   = Set("АБВГҐДЕЄЖЗИІЇЙКЛМНОПРСТУФХЦЧШЩЬЮЯабвгґдеєжзиіїйклмнопрстуфхцчшщьюя")
private enum NameValidationError { case edgeSpace, consecutiveSpaces, tooShort, tooLong, invalidCharacters }
```
Order of checks: edge-whitespace (any kind) → two consecutive spaces → length → per-character allow-list (single space `' '` is permitted, anything else outside the three buckets is rejected). Five distinct locale keys per field (`registration.nickname.*` and `registration.estate.*`) → 6 new keys per locale. Also dropped the previous `.trimmingCharacters(...)` step since edge-space rejection replaces it; the raw text is stored on success. Two-word names like "Two Words" pass; trailing space, leading space, double space, emoji, punctuation, and tabs all fail with their own error toast.

**3. Em-dash + minus pair removed.** The starvation outcome string read `"… зсередини — <b>−%{hp} HP</b>"` which renders as `… зсередини — −5 HP` (em-dash followed by minus). Replaced the em-dash with a period to match the encounter.won pattern. Other strings were programmatically scanned for the same `[—–][optional<b>][−-]` adjacency — only the starvation line in each locale was affected.

**4. Encounter.won line wraps to two lines.** With enemy emoji + name + round count + HP/hunger losses on one line, the message overflowed. Inserted `\n` before the loss segment so the second line stands alone (`⚔️ Ти подолав 🐗 Дикий кабан за 2 раунд(ів).\n❤️ −1 HP, 🍖 −2 голоду`).

**5. ❤️ / 🍖 now ride inside interpolation values.** New finding: while emojis in the *template* before a `%{}` placeholder break Lingo interpolation (the surrogate-pair / VS16 bug we already documented), emojis inside the *substituted value* are safe — Lingo finishes scanning placeholders before substituting, so post-substitution emoji content can't affect placeholder discovery. Used this for `.trip`, `.encounterWon`, `.starvationOnly` outcomes — the leading `🦵 / ⚔️ / 🥀` is still prepended in Swift after `localize(...)`, but `❤️ −\(hpLost)` and `🍖 −\(hungerLost)` are passed as interpolation values so the icon sits right next to its number. Also dropped the leading `−` from the templates since the value now carries it. Updated `.memory/localization.md` with the refined rule.

**6. Per-user dispatch serialization in `RouterStore`.** Real bug seen by playtester: spam-tapping "Step Forward" rolled events at the same `stepsDeep` (duplicate loot; hunger drained only once because both dispatches saved over each other on the cached User instance). Root cause was actor reentrancy — `RouterStore.process` awaits DB calls inside `dispatch`, and during those awaits another `process` call for the same user could run concurrently. Fix: `RouterStore` now keeps `inflightByUser: [Int64: (token: UInt64, task: Task<Void, any Error>)]` and a monotonic `nextDispatchToken`. Each call:
1. Reads the previous in-flight task for that Telegram ID (if any).
2. Allocates a fresh token, builds a `Task` whose body awaits the previous task's value before invoking the actual `dispatch(...)`.
3. Stores `(token, task)` under the user ID, then awaits its own task's value.
4. On completion the entry is cleared only if our token is still latest (otherwise a later call already replaced it).

Tasks aren't reference types so identity comparison via `===` is impossible — hence the token-keyed approach. Cross-user dispatches still run concurrently; only same-user updates are serialized. Bug #8 (eggs surviving death) is a downstream symptom of the same race and resolves automatically with this fix.

**7. Bot-startup admin notification rewritten.** Old: `"📟 Bot started."` plain English, no markup. New: per-admin localized greeting (`bot.restarted` key in EN + UK with a lore wrapper — "Artania awakens…" / "Артанія прокидається…") plus a `[/start]` reply-keyboard button (`oneTimeKeyboard: true`) so the admin can re-enter the game with one tap. Locale per admin is read from the User row; if the admin hasn't registered, falls back to `uk`.

**8. ❤️ added to trip + starvation HP-loss line for symmetry with encounter.won.** Same interpolation-value pattern: `"hp": "❤️ −\(hpLost)"` for `.trip` and `.starvationOnly`, with the trailing `−` removed from the templates.

**Side changes during this session:**
- `developerUsers = [mitya, irina, maxim]` (added maxim).
- `resetDevProfile = true` (was false) — registration is now exercised end-to-end on every dev launch. CLAUDE.md "currently off" note updated.
- Locale count: 207 → 214 per locale (6 new validation keys + 1 new `bot.restarted`).

No dead code introduced. The `explore:passive:close` callback handler on `ExplorationController` remains intentionally for backwards-compat with chat history that pre-dates the auto-cleanup fix (sessions log from 2026-04-23). Build is clean (`swift build` succeeds).

## Session — 2026-04-25 (Phase 4.1 combat foundation)

User-led design discussion → agreed combat MVP scope, locked five mechanic constants, then wrote the foundation (no UI yet — controller, locale keys, and the encounterStarted hook follow next session).

**Design decisions (locked for MVP, post-MVP listed in TODO 4.2/4.3):**
1. Classes mechanically identical at MVP — identity comes from existing stat differences (warrior 10/12 atk/def, archer 14/8 with +acc, mage 15/6 with +crit) and starter-weapon `gearStats`. Class-specific Defend/Flee variations deferred.
2. Reuse existing `User.effective*` stats — no arbitrary numbers in damage formulas.
3. One Telegram message per round at MVP — edit-in-place deferred.
4. Crit/dodge/accuracy from existing User stats. Single shared `CombatService.applyAttack` hook fires for both passive autobattle and the upcoming active controller.
5. Per-enemy AI (aggression / fleeResist), rabies status, XP grant on victory — all deferred.
6. Interactive combat = active mode only. Passive `runLive` keeps using autobattle (no UI possible from a detached background task).

**Locked numbers:**
- Base hit chance: 70%, clamped to [10, 95] after `± (acc − dodge)` shift.
- Crit multiplier: ×1.5 (lands on roll vs `attackerCrit %`).
- Damage variance: ±10%.
- Attack costs −2 hunger; Defend costs −1; Flee costs −3.
- Defend doubles `effectiveDefense` for the round AND deals chip damage = 30% of a clean hit (no crit, no miss — flavour: parry-counter / shadow shot / barrier wave).
- Flee = 50% flat. Failure → enemy lands a guaranteed full-damage hit "in the back" (no dodge possible). Success → `stepsDeep -= 1`, back to exploration.
- State model: combat fields embedded in `exploration_state` (combat in v1 only happens during exploration, single-row-per-user invariant gives "no concurrent fights" for free).

**Foundation landed this session:**
- `Swift/Migrations/AddCombatFields.swift` — adds nullable `combat_enemy_id: String` + `combat_enemy_hp: Int`. Registered after `RenameFoodIds`.
- `Swift/Models/ExplorationState.swift` — two new `@OptionalField` columns + `isInCombat` / `beginCombat(enemyId:hp:)` / `endCombat()` helpers. Init nils both fields.
- `Swift/Services/CombatService.swift` (new) — `AttackOutcome { miss / hit(damage) / crit(damage) }` enum + `applyAttack` + `chipDamage`. Constants exported (`baseHitChance = 70`, `critMultiplier = 1.5`, `defendChipFraction = 0.3`, `varianceRange = 0.9...1.1`) so both consumers stay in sync.
- `Swift/Services/ExplorationService.swift` — `resolveAutobattle` rewritten to call `applyAttack` for both player and enemy strikes. Enemies don't have crit/dodge/accuracy stats yet, so they pass 0 for all three; the player gets full `effectiveCrit / effectiveAccuracy / effectiveDodge`. Side effect: passive autobattle now misses occasionally and crits occasionally — fight outcomes have more variance than before.
- `TODO.md` Phase 4.1 expanded into a detailed checklist with the locked numbers.

**Still pending (next session):**
- New `StepOutcome.encounterStarted(Enemy)` case. Active `rollStep` returns this instead of running autobattle directly. ExplorationController catches → writes combat fields → transitions `routerName = "combat"`.
- `Swift/Controllers/CombatController.swift` with Attack / Defend / Flee handlers, class-flavoured reply keyboard via `combat.button.<action>.<class>` locale keys, victory / defeat / flee end-conditions, AllControllers registry entry.
- ~30 locale keys per locale (9 button labels + ~12 narrative strings + status card line).
- Final `swift build` + locale-count parity check.

**Side change picked up this session:**
- `resetDevProfile` flipped `false → true → false` during the session — final state is `false` (dev profile state persists across restarts so combat tests survive bot restarts). CLAUDE.md "currently **on**" → "currently **off**".

No dead code introduced. The `@unchecked Sendable` notes etc. all carry over. Build is clean (`swift build` → "Build complete!"). Locale count unchanged (still 214/214 — combat keys come next session).

## Session — 2026-04-25 (Phase 4.1 combat MVP — controller + registration tutorial fight)

Built on top of last session's CombatService foundation. Wired the active-mode encounter hand-off, shipped the controller, made the registration wolves encounter a real fight you have to win to reach the estate.

**Key landings:**

1. **`StepOutcome.encounterStarted(Enemy)` — mode-aware encounter resolution.** `ExplorationService.rollStep(mode:)` gained a `mode` parameter; active mode returns `.encounterStarted` (no HP / hunger spent on the encounter yet, just the walk-room drain) and ExplorationController takes over. Passive mode keeps running `resolveAutobattle` and emits `.encounterWon` / `.encounterLost` as before — passive can't prompt the player from a `Task.detached`. `awardEncounterDrops` extracted as a public hook so CombatController's victory path mirrors the autobattle's drop step. PassiveExpeditionService's outcome switch handles `.encounterStarted` with a no-op `break` (passive never actually receives it; switch must be exhaustive).

2. **`CombatController.swift`** — new file. Reply keyboard `[Attack] [Defend] / [Flee]` with class-flavoured labels via `combat.button.<action>.<class>`. Same handler fires regardless of which class label was tapped; class is inferred from `session.characterClass` at render time. Round flow:
   - **Attack** (−2 hunger): `applyAttack(player→enemy)` then `applyAttack(enemy→player)` — full effectiveDodge on the player's incoming hit.
   - **Defend** (−1 hunger): `chipDamage` to enemy (30% of base, no crit, no miss — flavour: parry-counter / shadow shot / barrier wave); incoming hit rolls against doubled `effectiveDefense`.
   - **Flee** (−3 hunger): 50% flat. Success → clear combat fields, `stepsDeep -= 1`, hand back to ExplorationController. Fail → enemy lands a guaranteed full-damage hit "in the back" (no dodge, no crit roll), fight continues. If the forced hit kills the player, treat as defeat.
   - **Victory**: `ExplorationService.awardEncounterDrops` adds loot to inventory, send "🏆 falls" + loot lines, clear combat fields, hand back to ExplorationController at the same km. Encounter is consumed; the room's visit count was already recorded by the step that triggered it, so re-entry uses visit-decay weights.
   - **Defeat**: `ExplorationController.handleDeath(causeNarrative:)` — extracted as a static helper this session so CombatController could reuse the wipe + respawn flow without duplicating the inventory query / HP reset.

3. **HungerAction got per-action combat costs.** `combatRound` (1 hunger) is kept for passive autobattle. Three new cases — `combatAttack` (2), `combatDefend` (1), `combatFlee` (3) — power the active controller's per-tap drain.

4. **EnemyCatalog gained `find(_:String) -> Enemy?`** so CombatController can rehydrate the fight from the persisted `combat_enemy_id` between taps.

5. **Registration wolves fight (step 4 → real combat).** Replaced the stub Continue button with `[⚔️ Stand and fight]` / `[⚔️ Прийняти бій]` (`reg:fight_wolves` callback). On tap, `Registration.startWolvesFight` creates an `ExplorationState` row at km 0 with combat fields stamped against `enemy.rabid_wolf` and transitions `routerName = "combat"`. CombatController detects the registration context via `session.registrationStep < 6` and routes every end condition (victory / defeat / flee / `/start`) to `Registration.handleCombatEnd(won:)`:
   - Won → registrationStep = 5, prompt estate name.
   - Lost → full HP heal (so the player can actually retry), step stays at 4, send "🩸 you scrambled away — but the wolves still bar the path. Steel yourself and try again." preamble, re-show the wolves photo with the Fight button.
   The state row is deleted entirely on registration end (it's not a real expedition). Inventory is **not** wiped on registration defeat — this is a tutorial gate, not the standard death path.

6. **Reply-keyboard cleanup on registration transitions.** `promptEstateName` and the `wolves_retry` preamble both ship `ReplyKeyboardRemove`. Without this the combat reply keyboard (`[Рубати мечем] [Парирувати] [Відступити]`) stayed visible while the bot prompted for the estate name, and the player could submit a button label as the estate name — `validateName` would reject the emoji prefix but two-word labels like "Магічний бар'єр" would pass the digit/Latin/Cyrillic + single-space allow-list. Removing the keyboard at the source kills the vector entirely.

**Files added:** `Swift/Controllers/CombatController.swift`. **Files modified:** `Swift/Controllers/AllControllers.swift` (registry), `ExplorationController.swift` (encounter hand-off + handleDeath split into static helper), `RegistrationController.swift` (fight_wolves callback + handleCombatEnd bridge + ReplyKeyboardRemove on prompts), `Swift/Models/Enemy.swift` (find helper), `Swift/Services/ExplorationService.swift` (mode-aware rollStep + awardEncounterDrops public hook), `HungerService.swift` (3 new combat HungerAction cases), `PassiveExpeditionService.swift` (mode: .passive on rollStep call + new `.encounterStarted` switch arm), Localizations en/uk (+22 net keys: 9 buttons + 12 narratives + fight_wolves + wolves_retry, dropped the now-unused `registration.continue`).

**Locale count: 214 → 236 per locale (en/uk parity verified).** Build clean.

**Side changes during this session (config tuning, not code logic):**
- `developerUsers` reduced to `[mitya]` (was `[mitya, irina, maxim]`) — testing convenience.
- `resetDevProfile` flipped back to `true` — registration is exercised end-to-end on every dev launch while the new combat hand-off is being playtested.

**Phase 4.2 / 4.3 deferrals (carried forward in TODO.md):** class-specific Defend / Flee mechanics, edit-in-place combat UX, XP grant on victory, per-enemy AI hooks (aggression / fleeResist), status effects (rabies). All deliberate post-MVP scope.

## Session — 2026-04-27 (Combat UX polish + bot-restart keyboard fix + Phase 4.2 concept lock)

Pre-Phase 4.2 prep session: locked the design for class-specific techniques in TODO.md, then fixed two combat-adjacent UX issues that would have made it worse to land 4.2 on top of.

**Phase 4.2 concept locked (TODO.md only — no code).** Each class will get three signature techniques: an Attack, a Defense, and a Super (stance buff that boosts both ATK and DEF for 2-3 rounds). User picked the names interactively:
- Warrior — **Розкол** (Cleave) / **Залізна стіна** (Iron Bulwark) / **Кровна жага** (Bloodlust)
- Archer — **Влучний постріл** (Vital Shot) / **Тінь лісу** (Shadow Veil) / **Око сокола** (Hawk's Eye)
- Mage — **Полум'я душі** (Soulfire) / **Дзеркальний щит** (Mirror Ward) / **Магічний резонанс** (Arcane Resonance)
Plus class-specific Flee chances (knight 40 / archer 70 / mage 90 + extra mage hunger cost). Unlock-by-level wiring deferred until the leveling system lands. TODO.md Phase 4.2 section rewritten with the full checklist + shared-infrastructure notes (new `combat_stance` + `combat_stance_rounds_left` columns, ~27 locale keys, Flee tuning).

**Combat actions converted from reply keyboard → inline buttons.** Driver: the user wanted the player's "main" keyboard to stay put during combat (so they can see what they'd come back to) and to get a "you're in combat" nudge if they tap one of those buttons by mistake. Code changes:
- `CombatController.attachHandlers` no longer registers 18 per-class text labels; instead it registers `router[.callback_query(data: nil)] = T.onCallbackQuery` and the unmatched fallback.
- New `combatInlineKeyboard(session:lingo:)` builds `[⚔️ Slash][🛡 Parry] / [🏃 Retreat]` (or class-flavoured equivalent) as inline buttons with `combat:attack` / `combat:defend` / `combat:flee` callbacks. `showCombat` and `finishRound` now use it instead of the old reply keyboard.
- `generateControllerKB` returns nil — combat owns no reply keyboard, so whatever was visible before combat (exploration's `[Step fwd][Step back]/[Bag]`, or none in registration) stays put.
- New static `onCallbackQuery` dispatcher routes the three combat callbacks to existing handlers; unknown callbacks (stale Estate / Inventory inline buttons) fall through to `sendInCombatNotice`.
- New `sendInCombatNotice(context:)` sends a single line via `combat.in_progress` ("Ти зараз у бою з 🐗 Дикий кабан. Спочатку заверши сутичку.") — first iteration also re-rendered the status card + buttons but the user (correctly) flagged that as duplicate noise; trimmed back to the bare nudge. The previous combat message above still has the live inline buttons.
- `unmatched` now calls `sendInCombatNotice` instead of re-rendering combat — same one-line nudge for any text input, including taps on the previous reply keyboard.
- New locale key: `combat.in_progress` in en/uk. Locale count 236 → 237.

**Side effect — registration `ReplyKeyboardRemove` defenses are now redundant but harmless.** They were originally there because the combat reply keyboard could be typed as the estate name (combat-button labels would pass `validateName`'s digits/Latin/Cyrillic + single-space allow-list). With combat now inline, no labels can be typed. Kept the `ReplyKeyboardRemove` calls as defensive (no-op during the registration flow, which already uses ReplyKeyboardRemove globally).

**Bot-restart greeting now restores the player's normal keyboard.** Driver: user reported that on bot restart, even fully-registered players got the one-time `/start` button instead of their main 6-button keyboard. The greeting message text was also updated — removed the "Tap /start to return to the realm" tail since registered players don't need the hint.
- `configure.swift` per-user loop now does: look up User row → if `registrationStep >= 6`, find their controller via `Controllers.all.first { $0.routerName == user.routerName }`, call its `generateControllerKB`. Combat case (which returns nil) explicitly falls back to `Controllers.explorationController.generateControllerKB` since combat is always nested in an expedition. Unregistered users (no row, or step < 6) keep the one-time `[/start]` button.
- en/uk `bot.restarted` strings stripped of the `/start` hint.
- Added a CLAUDE.md / `.memory/controller-pattern.md` note that controllers can deliberately return nil from `generateControllerKB` and that callers needing a fallback should pick the parent context's keyboard explicitly.

**Side change picked up this session:** `resetDevProfile` flipped back to `false` — combat refactor playtesting wants registered state to survive across launches.

**Files modified:** `Swift/Controllers/CombatController.swift` (combat-action callbacks, removed reply-keyboard plumbing), `Swift/configure.swift` (context-aware bot-restart keyboard + resetDevProfile flip), `Localizations/en.json` + `uk.json` (combat.in_progress added; bot.restarted hint trimmed), `TODO.md` (Phase 4.2 concept lock-in checklist + footer summary), `CLAUDE.md` / `README.md` / `.memory/{file-map,status,localization,controller-pattern}.md` (doc sync). Build clean.

## Session — 2026-04-27 (Phase 4.2 class techniques — 9 techniques across all 3 classes)

Massive landing session: implemented all 9 class techniques (Super × 3, Special Attack × 3, Special Defense × 3) with shared infrastructure for stances, persistent effects, and per-fight budget. All in one session because the techniques all share the same UI surface (the `[🪄 Techniques]` submenu) and the same composition model (modifiers fold into `applyAttack`).

**Key landings (in dependency order):**

1. **4.2.1 Super stances + stance machinery.** New migration `AddCombatStanceFields` adds nullable `combat_stance: String?` + `combat_stance_rounds_left: Int?` to `exploration_state`. `ExplorationState` gets `hasActiveStance` / `beginStance(_:rounds:)` / `tickStance() -> Bool`. `CombatService` gains `StanceModifiers` struct (attackMultiplier / attackBonus / defenseBonus / critBonus / accuracyBonus / dodgeBonus / hungerMultiplier), `stanceModifiers(for:)` lookup with three IDs (`bloodlust` / `hawks_eye` / `arcane_resonance`), `stanceId(forClass:)`, `stanceActivationHunger(for:)`, `stanceDurationRounds = 3`. `HungerService.drain(_:action:multiplier:)` extended with optional multiplier so Bloodlust ×2 doesn't need new HungerAction cases. `CombatController` got 4th button `[🩸 Bloodlust]` (originally — see #2 for the redesign), `combat:super` callback, `onSuper` handler that gates on `hasActiveStance`, drains activation hunger, calls `beginStance`, and sends activate narrative. `finishRound` gained `tickStance` + class-flavoured expire narrative.

2. **UX redesign — `[🪄 Techniques]` submenu via edit-in-place.** Driver: 4th-button-as-Super clutters the keyboard once Special Atk/Def land. Refactored to a single `[🪄 Techniques]` button on the main keyboard that opens a submenu via `editMessageReplyMarkup`. New callbacks `combat:tech:menu` / `combat:tech:back`. `combatTechniquesMarkup(session:state:lingo:)` builds the submenu. New locale keys `combat.button.techniques` + `combat.tech.back`. `combatInlineKeyboard` factored into `combatMainMarkup` (returns `TGInlineKeyboardMarkup` for edit-in-place reuse) + a `TGReplyMarkup` wrapper for `sendMessage` callers.

3. **4.2.2 Special Attacks + AttackModifiers.** `CombatService.AttackModifiers` struct extends `applyAttack` with optional modifiers (`hitChanceModifier` / `defenderDEFFraction` / `critBonus` / `cannotMiss` / `flatDamageBonus`) — defaults are no-ops, existing callers unchanged. Per-class `specialAttackHunger(forClass:)`, `specialAttackModifiers(forClass:)`, `specialAttackZeroesDodge(forClass:)`. Cleave originally tuned at −15% hit + 50% DEF ignore, but the user flagged it as objectively weak (~10 expected vs Vital Shot ~23, Soulfire ~26) — bumped to −10% hit + 100% DEF ignore + 12 flat damage + 20 crit, bringing Cleave to ~22 expected (high-variance "all-in"). `onSpecialAttack` is class-dispatched; stance + special-atk modifiers compose (Bloodlust ATK boost still feeds Cleave damage).

4. **4.2.3 Special Defenses + persistent effects.** New migration `AddCombatDefenseFields` adds `combat_enemy_def_debuff: Int?` (rounds remaining where player swings ignore enemy DEF — set by Iron Bulwark) + `combat_player_dodge_buff: Int?` (rounds remaining where player gets +50 dodge — set by Shadow Veil). `ExplorationState` got `hasEnemyDefDebuff` / `hasPlayerDodgeBuff` / `applyEnemyDefDebuff(rounds:)` / `applyPlayerDodgeBuff(rounds:)` / `tickDefenseEffects()`. `CombatService.SpecialDefense` namespace with hunger costs, Iron Bulwark chip fraction (0.5), Shadow Veil dodge bonus (50), Mirror Ward reflect fraction (0.5). `onSpecialDefense` handler is class-dispatched: warrior chip + skip counter + apply armor-split, archer skip counter + apply lingering dodge, mage rolls would-be enemy hit + reflects 50% as direct damage (player takes 0). `finishRound` ticks defense effects alongside stance. `renderStatusCard` shows active-effect indicators (`combat.effect.armor_split` / `combat.effect.shadow_veil`). All other handlers (Attack/Defend/Flee/SpecialAttack) read defense effects and apply them to swings — armor-split zeroes enemy DEF, Shadow Veil adds 50 dodge to enemy counter.

5. **Lingo emoji-prefix interpolation fix.** User screenshot showed Soulfire's hit narrative rendering literal `%{enemy}` / `%{damage}` because the locale string started with 🔥 (UTF-16 surrogate pair confuses Lingo's `%{var}` parser). Same fix as the Phase 3.3 passive-report icons: stripped leading emoji from every Phase 4.2 interpolated string and added static helpers `superEmoji(for:)` / `specialAtkHitEmoji(for:)` / `specialDefEmoji(for:)` that prepend class-flavoured icons in Swift at render time. Universal `💥` for crits / `💨` for misses / `🛡` / `🌑` for status indicators handled inline. Also removed the unused `combat.special_def.archer.no_target` key during this pass.

6. **Per-fight technique budget.** Driver: techniques shouldn't be spammable. New migration `AddCombatTechniqueUses` adds nullable `combat_special_atk_uses` / `combat_special_def_uses` / `combat_super_uses`. `beginCombat(enemyId:hp:)` initialises them to 2 / 2 / 1; `endCombat` clears them. `ExplorationState` got `hasSpecialAtkUse` / `hasSpecialDefUse` / `hasSuperUse` queries + `consumeSpecialAtk` / `consumeSpecialDef` / `consumeSuper` decrement helpers. `combatTechniquesMarkup` now takes `state` and conditionally includes only buttons with uses > 0; labels carry " × N" suffix. Each handler gates on `hasX-Use` (defensive — submenu hides spent buttons but stale messages can still fire callbacks) and consumes the counter. New locale key `combat.tech.no_uses_left` + `sendNoUsesLeftToast` for the defensive case.

**Numeric tunings (final):**
- Hunger costs: Cleave 4, Vital Shot 4, Soulfire 5, Iron Bulwark 3, Shadow Veil 3, Mirror Ward 4, Bloodlust 4, Hawk's Eye 4, Arcane Resonance 5.
- Stance duration: 3 rounds for all three.
- Persistent effect duration: 1 follow-up action (Iron Bulwark / Shadow Veil set rounds = 2 to compensate for the immediate tick on the activation round).
- Per-fight budget: 2 Special Atk + 2 Special Def + 1 Super.

**Files added:** `Swift/Migrations/AddCombatStanceFields.swift`, `AddCombatDefenseFields.swift`, `AddCombatTechniqueUses.swift`. **Files modified:** `Swift/Controllers/CombatController.swift` (~330 line growth — new handlers, new submenu, emoji helpers, modifier composition), `Swift/Models/ExplorationState.swift` (~120 line growth — fields + helpers for stance, defense effects, technique uses), `Swift/Services/CombatService.swift` (~170 line growth — AttackModifiers, StanceModifiers, SpecialAttack / SpecialDefense namespaces, lookup helpers), `Swift/Services/HungerService.swift` (drain multiplier), `Swift/configure.swift` (3 new migrations registered), `Localizations/en.json` + `uk.json` (32 new keys per locale; locale count 237 → 269 after the unused archer.no_target removal). Build clean.

**Phase 4.3 carryforwards (in TODO.md):** class-specific Flee chances (knight 40% / archer 70% / mage 90% + extra mage hunger), edit-in-place per-round message UX, XP grant on victory, per-enemy AI hooks, status effects (rabies). Unlock-by-level wiring also still deferred until the leveling system lands.

## Session — 2026-04-27 (Phase 4.3.1 Flee tuning + Future/Backlog reorg)

Small follow-up to the big 4.2 commit. Two threads:

**4.3.1 Class-specific Flee chances landed.** New `CombatService.Flee` namespace (warriorChance 40 / archerChance 70 / mageChance 90 / mageHungerExtra 2) + `fleeChance(forClass:)` + `fleeHungerExtra(forClass:)`. `CombatController.onFlee` now reads the player's class once, drains base flee hunger via the existing multiplier-aware path, and layers the mage's +2 teleport tax on top (also scaled by the stance multiplier, so an Arcane-Resonance mage still pays the toll). The success roll uses per-class chance instead of the old flat 50%. Failed-flee counter logic unchanged. No locale keys touched — narrative is class-agnostic; only the odds and hunger costs differ.

**TODO.md restructure based on user feedback.**
- 4.3.1: marked landed.
- 4.3.2 (edit-in-place per-round message): deferred by user — preference is to keep all combat logs visible as separate messages.
- 4.3.3 (XP grant on victory): deferred until Phase 5.x. **Important design pivot:** XP will be re-targeted to feed estate progression directly instead of character level. `User.estateLevel`'s current derivation (every 5 player levels → +1 estate tier) will be replaced. Added a callout note under Phase 5 in TODO.md so future-me notices.
- 4.3.4 (per-enemy AI hooks), 4.3.5 (rabies status effects), 4.3.6 (combat log persistence): all moved to a new top-level `## Future / Backlog` section at the bottom of TODO.md. User will review pre-release; new ideas will accumulate there over time.

**Files modified:** `Swift/Services/CombatService.swift` (+36 lines — Flee namespace + lookups), `Swift/Controllers/CombatController.swift` (+13 lines — class lookup in onFlee + extra-hunger branch), `TODO.md` (+31 lines — Phase 4.3 section rewritten, Phase 5 XP-to-Estate note, new `Future / Backlog` section), `CLAUDE.md` / `README.md` / `.memory/{file-map,status}.md` (doc sync). Build clean. Locale parity unchanged (269/269).

## Session — 2026-04-27 (Phase 4.4 bestiary closed + callback-toast UX overhaul)

Two related themes landed in this session: bestiary expansion (closing Phase 4.4) and a chat-UX revamp around how the bot acknowledges callback taps.

**4.4 Bestiary expansion landed.**
- **wild_bear** (T5, km 21–30, HP 95 / ATK 17 / DEF 5; wild family — meat ×2 + hide ×1) added at the user's request as a regular mob, not a boss. Master-of-the-forest flavour; 🐻 icon.
- rabid_wolf range extended from 16–20 to **16–25** so the rabid family bleeds into T5; the families now share the 21–25 band.
- **rabid_bear** (T6, km 25–35, HP 120 / ATK 22 / DEF 4; rabid family — hide ×2 only) added as a deeper escalation. 🐻‍❄️ icon — "Beastfever has bleached the fur." Higher ATK, lower DEF: classic rabid trade.
- Three deep-zone overlaps now stack: rabid_wolf↔wild_bear at 21–25, wild_bear↔rabid_bear at 25–30; only rabid_bear from 31–35.
- New `content/bestiary.md` reference doc with the full roster table, tier summary, family overview, stat-scaling note, and a "how to add a new enemy" recipe.
- T5+ has only regular mobs by design; the dedicated boss is reserved for Phase 3.5 once the boss-fight mechanics are designed (the user wants to spec the boss later).
- Two new locale keys per locale (`enemy.wild_bear` / `enemy.rabid_bear` in en + uk).
- Comments in `Enemy.swift` updated to reflect the new tier map and overlapping bands.

**Callback-toast UX overhaul.** Driver: user reported the narrow top-strip banner showing literal `<b>...</b>` tags after equip/unequip — Telegram's `answerCallbackQuery(text:)` is plain text only and doesn't render HTML. Plus the user wanted a different presentation entirely so the chat doesn't feel hijacked by transient banners.
- Audited all 11 toast call sites; classified into 6 successes (data changed, view refreshes) and 5 warnings (data unchanged, action rejected).
- **Successes** (equip / unequip / eat in inventory / eat in bag / warehouse deposit / warehouse withdraw): silent `answerCallbackQuery` (no `text:`), with the message refresh prepending an inline `✅ ...` status line above the body. `InventoryController.refreshCategory(...)` gained an optional `statusLine: String?` parameter; the same pattern is inlined in EstateController warehouse and ExplorationController bag refresh paths.
- **Warnings** (raw food, no_effect, full backpack, empty category, use_unavailable, nothing-to-deposit/withdraw, item-info placeholder): `answerCallbackQuery(text:, showAlert: true)` — Telegram modal popup with an OK button. Plain text only, no HTML.
- Stripped HTML from `equip.success` and `unequip.success` locale keys (they used to have `<b>%{item}</b>` which rendered literally in the toast). The other toast-bound keys were already plain text.
- Eat-success status line now interpolates current/max pool: `hunger.restored` and `hp.restored` keys gained `%{current}` and `%{max}` placeholders alongside the existing `%{amount}`. Sample render: "✅ Лісові ягоди — +15 голоду (20/100), +2 HP (90/120)".
- Item info-button placeholders (when an item lacks a `descriptionKey`) flipped from narrow toast to modal alert for consistency with the description-bearing case (which already used showAlert: true).

**Audits run as part of the session.**
- Supplementary-plane leading-emoji check across both locale files (the Lingo `%{var}` parser bug): 64 interpolated keys total, **zero** keys with leading multi-UTF-16 emoji.
- HTML coverage check: every send/edit-message callsite that references an HTML-tagged locale key has `parseMode: .html` in scope; no inline HTML literals without parseMode either.
- These checks are now documented in `.memory/localization.md` with sample audit logic so future PRs can re-run them.

**Files modified:** `Swift/Models/Enemy.swift` (+~50 lines — wild_bear, rabid_bear, header / tier comments), `Swift/Controllers/InventoryController.swift` (refreshCategory statusLine, eat-success refactor, modal alerts), `Swift/Controllers/ExplorationController.swift` (bag eat-success statusLine + modal alerts), `Swift/Controllers/EstateController.swift` (warehouse handler split into success ↔ warning), `Localizations/en.json` + `uk.json` (+2 enemies, equip/unequip plain text, hunger/hp restored interpolations; locale count 269 → 271), `TODO.md` (4.4 closed with both bears + bestiary.md note). New file: `content/bestiary.md`. `CLAUDE.md` / `README.md` / `.memory/{file-map,status,localization}.md` doc sync. Build clean (locale parity 271/271).

## Session — 2026-04-30 (Phase 5.1 plot system + Training Ground + iron resource overhaul)

Largest single-day session of the project: full estate plot system, training ground combat mode, iron resource model, callback-toast warehouse routing for plot harvest. Roughly 5 new files, 13 modified, +680 / −47 lines.

**Plot system (Phase 5.1).**
- New `Plot` Fluent model (user_id FK, slot_index, plot_type, tier, last_harvested_at, notified_full). Production amount lazily computed from `lastHarvestedAt + ratePerSecond × elapsed`, capped — no stored accumulator, no drift.
- New `PlotCatalog` code-based config: `PlotType` enum (farm / forest / mine / coop / trainingGround), `PlotTuning` (producedItemId / ratePerInterval / capacity / optional `bonusOutput`), `PlotBonusOutput` for secondary yields. Mine carries iron as bonus output (1/interval, cap 20) alongside river_pebble (8/interval, cap 40). `testMode` flag scales rates per-minute (test) vs. per-hour (prod).
- New `PlotService` pure helpers: `accumulated` / `bonusAccumulated` lazy compute, `harvest(_:for:on:)` → `HarvestResult.success(primary:bonus:)` deposits into **WarehouseEntry** (not the bag — warehouse has no slot cap, so no `.bagFull` failure mode). `claim(slot:type:for:)` validates slot allowance via `slotsForLevel(_:)` (currently flat 5 — temporary override, the logarithmic table is preserved in code for the post-XP-to-Estate world).
- New `PlotProductionService` background ticker — single Task.detached started from `configure.swift` after `bot.start`. Wakes every 60s in test / 300s in prod, walks `Plot.allUnfull(on:)`, pushes a "🌾 ready to harvest" message when a plot's primary accumulator hits cap, flips `notified_full = true` to suppress repeats. Harvest resets the flag.
- `EstateController` Plot drill-down replaced the old stub: `renderPlotList` / `plotListKeyboard` (internal — CombatController.onTrainingExit re-uses them), three handlers (`handlePlotClaimPicker` → 5-type picker → `handlePlotTypeChosen` claims via `PlotService.claim`, `handlePlotHarvest` deposits to Warehouse, `handlePlotTraining` spawns the dummy fight). Mine plot row renders both primary + bonus inline: `⛏ Slot N · Mine — 40/40 🪨 · 12/20 🔩`.
- Initial farm grant at registration completion: `Registration.promptEstateName` calls `PlotService.claim(slot: 0, type: .farm, ...)` so a brand-new player has something already producing.

**Training Ground combat mode (Phase 5.1).**
- New `enemy.training_dummy` (HP 200, ATK 0, DEF 1, no loot, depthRange 0...0 so exploration never picks it).
- New `PlotType.trainingGround` — `PlotCatalog.tuning(for:)` returns nil (non-producing) so EstateController routes a tap to `handlePlotTraining` instead of harvest.
- `CombatController` extensions: `isTraining(_:)` helper checks `state.combatEnemyId == CombatService.trainingDummyEnemyId`; `combatMainMarkup` swaps `[Flee]` for `[🔙 Back]` (`combat:training:exit`) when training; `onTrainingExit` deletes the state row and re-renders the plot list with a `🥋 You step away` status banner. Each combat handler (`onAttack`, `onDefend`, `onSpecialAttack`, `onSpecialDefense`, `onSuper`) now skips hunger drain in training, uses the `playerSwingEnemyDEF` helper that returns 0 in training, forces `cannotMiss = true` on swing modifiers, and skips the entire enemy counter block (no `combat.enemy.{hit,crit,miss}` line). `finishVictory` reroutes to `reviveTrainingDummy` when training — resets dummy HP to full, emits a "🥋 dummy rights itself" line, keeps the player going.
- Crucially, `handlePlotTraining` does **NOT** flip `routerName` to `"combat"` — it stays at `"estate"` so the player's reply-keyboard nav (Profile / Inventory / Estate / Capital / Settings) remains usable. The combat inline-button callbacks reach `CombatController.onCallbackQuery` from any router via `combat:*` forwarding installed in MainController / InventoryController / EstateController / SettingsController. Real combat (exploration + registration) still flips routerName as before; the difference is keyed on enemy id.
- Per-fight technique budget (Special Atk + Def + Super = 2/2/1) **does** deplete in training — that's the player's whole reason to spar. Budget refreshes on `endCombat` (fired by Back tap → `state.delete`), so a quick Back + re-enter cycle resets it.

**Iron resource overhaul (Phase 5.1).**
- New `mat.iron` (Iron Lump 🔩) — raw, found rarely in foraging + Mine bonus output. Locale narrative emphasises "small, fingertip-sized nugget" since 10 are needed for crafting.
- New `mat.iron_ingot` (Iron Ingot 🔳) — placeholder for Phase 5.x Workshop crafting (planned recipe `mat.iron × 10 → mat.iron_ingot × 1`). Tier 3 material; not in any pool until the Workshop ships.
- Legacy `mat.old_iron` retired entirely: catalog entry, locale keys, foraging pool entry, and dev seed all removed. New `RemoveOldIron` migration runs `DELETE FROM inventory/warehouse WHERE item_id = 'mat.old_iron'` to wipe stale rows on next bot startup. The historical `RenameMaterialIds` migration (which created `mat.old_iron` from `mat.iron_ore` long ago) is left untouched.
- Foraging pool refactored: new `pickWeighted<T>` helper in `ExplorationService`, pool changed from `[String]` (uniform) to `[(String, Int)]` (weighted). Medium pool currently: potato / duck_egg / clay (weight 10 each) + iron (weight 2) → ~5% chance per medium-zone loot.
- Plot harvest narrative updated to say "added to Warehouse 📦" since plots no longer drop into the bag.

**UX polish in this session.**
- Forest plot renamed to "Lumberyard" / "Лісопилка" with new icon 🪚 (raw `forest` value kept for DB compat).
- Plot list title renamed: "Plots of land" / "Земельні наділи" → "Estate grounds" / "Ділянка" (per user preference).
- Plot row's full-mark `✨` removed per user request (locale `estate.plot.ready_mark` now empty).
- Slot count temporarily flat 5 (override on `slotsForLevel`) so the Training Ground is reachable for testing; logarithmic table will be restored once XP-to-Estate ships.
- Iron lump narrative emphasises smallness ("a small lump… no bigger than a thumbnail" / "не більший за ніготь") per user note that the crafting recipe assumes small lumps.
- Iron ingot icon: tried ⬛ → ⬜ → 🔳 (final, "white square in a frame" per user spec) — closest available BMP-friendly approximation to a polished metal ingot.

**Audits run.**
- Lingo supplementary-plane leading-emoji audit on all interpolated keys: 0 issues. Two new keys carrying `🚜` / `💤` had emoji moved into Swift (button label + harvest-empty toast respectively).
- Toast/callback-answer plain-text audit: 0 issues.
- HTML/parseMode coverage audit: 0 issues.
- Locale parity: 308/308.

**Files added (5):** `Swift/Models/Plot.swift`, `Swift/Models/PlotCatalog.swift`, `Swift/Services/PlotService.swift`, `Swift/Services/PlotProductionService.swift`, `Swift/Migrations/CreatePlots.swift`, `Swift/Migrations/RemoveOldIron.swift`.

**Files modified (13):** `Swift/Controllers/{Combat,Estate,Inventory,Main,Registration,Settings}Controller.swift`, `Swift/Models/{Enemy,Item}.swift`, `Swift/Services/{Combat,Exploration}Service.swift`, `Swift/configure.swift`, `Localizations/en.json` + `uk.json` (271 → 308 keys per locale).

**Phase 5.x carryforwards:** Workshop crafting (first recipe: `mat.iron × 10 → mat.iron_ingot × 1`), Kitchen cooking (raw food → cooked variants), XP-to-Estate progression model (replace `User.estateLevel = User.level / 5` derivation), unlock-by-level wiring for Phase 4.2 techniques, slot count formula switch from flat 5 back to the logarithmic table.

## Session — 2026-05-01 (Phase 5.2 Workshop crafting MVP)

**Phase 5.2 Workshop landed.** EstateController's Workshop replaces the old "coming soon" stub with a real two-screen flow:
- **Outer list** — `[🛠 Workshop]` from House opens a compact view: title + atmospheric description, with one inline button per recipe (`<icon> <name>`, e.g. `🔳 Iron Ingot` / `🪖 Forester's Hood`). No category headers in the body — recipes are visually grouped through their declaration order in `RecipeCatalog.all` (Forge first, Tannery second).
- **Detail screen** — tapping a recipe button (`craft:detail:<recipe.id>`) opens a per-recipe page: output icon + name, lore description (from `descriptionKey`), `📜 Recipe` section listing inputs as `N× <icon> <name>`, and — for gear outputs — `📊 Stats` listing only non-zero stat bonuses (Attack ⚔️ / Defense 🛡 / Crit 💥 / Dodge 💨 / Accuracy 🎯, with per-stat icons prepended in Swift to dodge the Lingo emoji-prefix bug). Keyboard is `[🔨 Craft]` + `[🔙 Back]`.
- **Craft action** — tapping `[🔨 Craft]` (`craft:<recipe.id>`) calls `CraftingService.craft`, refreshes the detail in place with a `✅ Crafted ...` banner appended **at the bottom** of the body. Banner placement was deliberately chosen — an earlier prepend-at-top design pushed the banner offscreen on long screens, so user feedback drove the move.
- **Failures** — `missingMaterials` lists each shortage as `• <icon> <name> — need N more (have/need)` in a modal alert; `inventoryFull` asks the player to free a slot. Both leave the screen unchanged.
- **Dispatch fix** — `craft:detail:` and `craft:` callbacks must be matched **before** the `estate:` prefix guard in `EstateController.onCallbackQuery`; otherwise the dispatcher returns false and Telegram surfaces "Unsupported content type." (caught and fixed during the first round of user testing).

**New code-based catalog: `Swift/Models/Recipe.swift`.** `RecipeCategory` enum (`forge` / `tannery`), `RecipeIngredient`, `RecipeOutput`, `Recipe`, `RecipeCatalog`. Five recipes ship in v1:
- 🔥 **Forge** — Iron Ingot: 10× 🔩 Iron Lump → 1× 🔳 Iron Ingot.
- 🧵 **Tannery** — Forester's leather set: Hood (2× hide → +1 DEF), Boots (3× hide → +1 DEF, +1 Dodge), Breeches (5× hide → +2 DEF), Jerkin (6× hide → +3 DEF). Full suit = 16 hide for +7 DEF / +1 dodge.

**New service: `Swift/Services/CraftingService.swift`.** Pure. `craft(_:for:on:)` drains inputs from the **combined inventory + warehouse pool** — inventory first (frees backpack slots that the gear output may need), warehouse second (bulk-storage fallback). Output always goes to inventory so the player can see and equip the new piece immediately. `CraftResult` enum (success / missingMaterials / inventoryFull / unknownRecipe / unknownItem) + `Shortage` struct. Post-drain slot accept-check: predicts how many inventory slots will be freed by the input drain so a craft never refuses spuriously when a 50/50 bag would have made room. No DB-transaction wrapping (same pattern as WarehouseService).

**Item catalog updates (`Swift/Models/Item.swift`).** Four new gear pieces (`gear.forester_hood` / `gear.forester_jerkin` / `gear.forester_breeches` / `gear.forester_boots`) with per-item icons (🪖 / 🦺 / 👖 / 🥾), descriptions, and `gearStats`. The placeholder `gear.leather_vest` (+2 DEF) was retired — no orphan rows are left because the `RenameLeatherVest` migration remaps existing inventory + warehouse rows in place.

**`WarehouseEntry.remove(...)`** helper added (mirrors `InventoryEntry.remove` semantics) so `CraftingService` can drain warehouse stockpiles cleanly.

**New migration: `Swift/Migrations/RenameLeatherVest.swift`.** Pure data migration — `UPDATE inventory/warehouse SET item_id = 'gear.forester_jerkin' WHERE item_id = 'gear.leather_vest'`. Schema unchanged. Existing rows (worn, in bag, in warehouse) carry over automatically with the new +3 DEF stats.

**Dev seed bumped (`Swift/configure.swift`).** `mat.hide` 1→16, `mat.iron` added at 10. On next launch every developer profile gets enough materials to craft one full Forester's set + one Iron Ingot for testing.

**Locale changes.** Added `workshop.*` namespace (description, category labels, detail-screen `📜 Recipe` / `📊 Stats` headers, Craft / Back button labels, stat names, alert + banner keys) plus 8 new item keys (4 names + 4 lore descriptions). Renamed `commands.inventory` and `inventory.title` from "Інвентар" → "Сумка" in `uk.json` so the term matches usage everywhere else (en stays "Inventory"). Locale parity audited: 334/334.

**UX iteration arc (driven by user feedback over multiple rounds).** Each step here was a course-correction from screenshots:
1. **Initial UI was too dense** — recipe blocks listed inputs + arrow + output + `🎒 N + 📦 M = T/need ✅|❌` per ingredient. User: "Lingo's emoji-prefix bug shows literal `%{inv}` placeholders, and the player doesn't need this calculation anyway — just pull from the bag first then warehouse silently." → removed all availability lines + the related locale key + the `availability(of:for:on:)` method on `CraftingService` + the `Availability` struct.
2. **"Unsupported content type" on every Craft tap** — `craft:` callbacks were caught inside the `guard data.hasPrefix("estate:")` block, so they never matched. Moved both `craft:detail:` and `craft:` checks above the guard. Caught during first user playtest.
3. **List view too long** — initial design had a recipe header + ingredients line per recipe inline. User: "Make it more concise; show stats per item; maybe move the details to separate screens." → refactored into the two-screen flow (compact list → detail screen with description + recipe + stats).
4. **Banner placement** — original design prepended the `✅ Crafted ...` line above the recipe list, which scrolled offscreen. User: "Add the message at the bottom — through the long menu it's not immediately visible that you crafted something." → moved banner to body bottom; with the new compact two-screen design this is also where it stays visible without scrolling.
5. **Category headers in the list view** — initial compact design still had `🔥 Forge` / `🧵 Tannery` section headers in the body. User: "Don't need them at all." → removed; recipes still group visually through the keyboard's row order.
6. **"Скрафтити" → "Створити"** — user wanted a more natural Ukrainian verb (less calque from English).
7. **"Інвентар" → "Сумка"** — user noticed the main keyboard label diverged from how the bag is referred to everywhere else; renamed.
8. **Workshop intro polish** — wrote three flowery atmospheric variants, user landed on a more grounded one ("the manor's work corner: an anvil beside the forge, a tailor's bench close by…") after a brief multi-option round.

**Reference doc.** New `content/recipes.md` with the recipe table + source-pool rules + migration history.

**Files added (4):** `Swift/Models/Recipe.swift`, `Swift/Services/CraftingService.swift`, `Swift/Migrations/RenameLeatherVest.swift`, `content/recipes.md`.

**Files modified (8):** `Swift/Controllers/EstateController.swift` (Workshop UI + dispatch + handlers), `Swift/Models/Item.swift` (Forester's set + leather_vest retirement), `Swift/Models/WarehouseEntry.swift` (remove helper), `Swift/configure.swift` (RenameLeatherVest migration registration + dev-seed bump), `Localizations/en.json` + `uk.json` (workshop.* + Forester item keys + sumka rename), `TODO.md` (Phase 5.2 progress markers + 5.2.2 weapon-upgrade entry), `.memory/file-map.md` + `.memory/status.md` (Phase 5.2 sync).

**Phase 5.x carryforwards (refreshed):** Kitchen cooking (5.2.1 — raw food → cooked variants with hunger / HP effects), weapon-upgrade flow (5.2.2 — modify existing weapon vs craft a new one), XP-to-Estate progression model (5.3 — replace `User.estateLevel = User.level / 5` derivation), unlock-by-level wiring for Phase 4.2 techniques, slot count formula switch from flat 5 back to the logarithmic table.

## Session — 2026-05-02 (Phase 5.2.1 — Kitchen cooking + recipe-learning flow)

**Phase 5.2.1 Kitchen landed.** Kitchen replaces the EstateController stub with a real cooking room. Six dishes ship, gated behind a per-user "learned recipe" set; players unlock dishes by using a recipe-scroll artifact. Two starters are auto-granted at registration so the room is never empty on day one.

**The dishes** (tuned so cooked food sits meaningfully above raw foragables but below potions on the HP side):

| Dish | Inputs | Hunger | HP | Notes |
|---|---|---|---|---|
| 🍠 Baked Potato       | 2× 🥔 potato                                                  | +20 | —   | starter (auto-learned) |
| 🍗 Roasted Meat       | 2× 🥩 raw_meat                                                 | +25 | —   | starter (auto-learned) |
| 🍳 Forager's Omelette | 2× 🥚 + 2× 🌰 + 1× 🫐                                          | +35 | +5  | scroll-locked |
| 🍲 Hunter's Stew      | 2× 🥩 + 2× 🥔 + 1× 🥚                                          | +45 | +10 | scroll-locked |
| 🥧 Forest Berry Tart  | 4× 🫐 + 2× 🌰 + 1× 🥚                                          | +35 | +12 | scroll-locked, sweet HP-skewed |
| 🍽 Governor's Feast   | 3× 🥩 + 3× 🥔 + 2× 🥚 + 2× 🫐 + 2× 🌰                          | +70 | +20 | full-pantry feast (renamed from "Royal Feast" per user) |

**New code-based catalog entries (`Swift/Models/Recipe.swift`).** Added `RecipeCategory.kitchen` as the third category alongside Forge and Tannery. Six new kitchen recipes appended to `RecipeCatalog.all`. New `RecipeCategory` helpers carry the per-category view/handler glue:
- `requiresLearning: Bool` — true for Kitchen, false for Forge/Tannery.
- `backCallbackData: String` — `estate:home:workshop` for Forge/Tannery, `estate:home:kitchen` for Kitchen.
- `actionButtonKey: String` — `workshop.detail.button.craft` vs `kitchen.detail.button.cook`.

That polymorphism let me share `renderRecipeDetail` + `recipeDetailKeyboard` + `handleCraftDetail` + `handleCraft` between Workshop and Kitchen — no parallel handler tree. New `RecipeCatalog.starterRecipeIds` lists the two recipes auto-granted at registration.

**New persistence (`Swift/Models/LearnedRecipe.swift` + `Swift/Migrations/CreateLearnedRecipes.swift`).** Per-user known-recipe set. Fluent model with `user_id` (FK cascade), `recipe_id`, `learned_at`; unique on (user_id, recipe_id). Helpers: `has(_:for:on:)`, `add(_:for:on:)` (idempotent — returns false on duplicate), `allIds(for:on:) -> Set<String>`, `ensureStarters(for:on:)` (idempotent helper that grants `RecipeCatalog.starterRecipeIds`).

**Item catalog growth (`Swift/Models/Item.swift`).** New `Item.teachesRecipe: String?` field — when set on an artifact, the inventory action button switches from "✨ Use" to "📖 Learn". Six cooked dishes added to ItemCatalog (`food.baked_potato` … `food.governors_feast`) with `restoreHunger` / `restoreHP` effects + per-item icons + lore descriptions. Six recipe scrolls added (`artifact.recipe.<dish_id>`, non-stackable, 📜 icon) — each carries its `teachesRecipe` link to the matching `recipe.<dish_id>`.

**Inventory Learn flow (`Swift/Controllers/InventoryController.swift`).** Two changes:
1. `genericRows` checks `item.teachesRecipe` per-row and overrides the action label from `inventory.action.<type>` to `inventory.action.learn` ("📖 Learn") when the field is non-nil.
2. The existing `inv:use:<itemId>` callback dispatcher branches: if `item.teachesRecipe != nil`, route to a new `handleLearnRecipe` static handler. That handler calls `LearnedRecipe.add`, deletes the scroll row on a fresh learn, and refreshes Artifacts (or pops to root if Artifacts is now empty) with an inline `✅ <Dish> — recipe learned` banner. Already-known recipes leave the scroll alone and surface a `📖 You already know this recipe.` modal alert (so duplicate scrolls become tradeable inventory once the market ships).

**Kitchen UI (`Swift/Controllers/EstateController.swift`).** New `renderKitchen` + `kitchenKeyboard` build the compact outer list — title + atmospheric description + one inline button per **learned** kitchen recipe + Back. Empty-state hint shown when nothing is learned (defensive; in practice the auto-grant means it almost never fires). The detail screen reuses Workshop's `renderRecipeDetail` — extended with a new `📊 Effects` section that lists each `ItemEffect` with a per-effect icon (🍖 Hunger / ❤️ HP), used for food outputs the way `📊 Stats` is used for gear. The `recipeDetailKeyboard` was parameterized to read its action verb and back target from `recipe.category`. Both `handleCraftDetail` and `handleCraft` enforce the learn-set on every kitchen recipe id (defense against stale callbacks left in chat after a wipe).

**Registration auto-learn (`Swift/Controllers/RegistrationController.swift`).** `promptEstateName` now calls `LearnedRecipe.ensureStarters` right next to the existing farm-plot auto-grant — same place a fresh player crosses into `registrationStep = 6`. The starter set ships with two simple dishes (Baked Potato + Roasted Meat) so cooking is reachable immediately.

**Dev seed (`Swift/configure.swift`).** Bumped cooking ingredients (5× of each — enough for one Governor's Feast plus extra). All six recipe scrolls added to the seed list. The dev-seed loop also calls `LearnedRecipe.ensureStarters` for every existing dev profile so already-registered accounts pick up the starters without needing a registration reset (the registration auto-grant only fires on a fresh registration).

**Locale changes.** Added `kitchen.*` namespace (description / empty-state / cook button / not-learned alert), extended `workshop.detail.*` with `effects` (food header) + `effect.hunger` + `effect.hp` shared between gear/food outputs, added `inventory.action.learn` + `learn.success` + `learn.already_known` for the Learn flow, added `workshop.category.kitchen` for completeness, plus 12 item names + 12 lore descriptions for the dishes and scrolls. Locale parity audited: 367/367.

**Audits.** Lingo emoji-prefix check — all interpolated keys safe (status banner builds the icon prefix in Swift, locale templates start with letters). Build clean on first try after the round of LSP staleness diagnostics that always trail new files. No dead code.

**Files added (3):** `Swift/Models/LearnedRecipe.swift`, `Swift/Migrations/CreateLearnedRecipes.swift`. (Note: `content/recipes.md` extended in-place rather than a new file.)

**Files modified (10):** `Swift/Controllers/{Estate,Inventory,Registration}Controller.swift`, `Swift/Models/{Item,Recipe}.swift`, `Swift/configure.swift`, `Localizations/en.json` + `uk.json`, `TODO.md`, `content/recipes.md`, `CLAUDE.md`, `README.md`, `Prompt.me`, `.memory/{file-map,localization,status,sessions}.md`.

**Phase 5.x carryforwards:** Weapon-upgrade flow (5.2.2 — modify existing weapon vs craft a new one), recipe scrolls as Capital quest rewards (Phase 6.x), XP-to-Estate progression model (5.3 — replace `User.estateLevel = User.level / 5` derivation), unlock-by-level wiring for Phase 4.2 techniques, slot count formula switch from flat 5 back to the logarithmic table.

### Phase 5.2.1 follow-up (same day, post-playtest tuning)

**Hunger numbers retuned ×3 deeper.** Initial Phase 5.2.1 numbers were ~70% of the original Phase 5.2.1 proposal; user feedback "ріж ще більше" cut them again to roughly half of even those. Final values:

| Item | Original (5.2.1) | Final |
|---|---|---|
| 🫐 Berries | +15 | +4 |
| 🌰 Nuts | +20 | +5 |
| 🥚 Egg | +25 | +7 |
| 🍠 Baked Potato | +20 | +9 |
| 🍗 Roasted Meat | +25 | +12 |
| 🍳 Omelette | +35 / +5 HP | +16 / +3 HP |
| 🍲 Stew | +45 / +10 HP | +20 / +5 HP |
| 🥧 Berry Tart | +35 / +12 HP | +16 / +6 HP |
| 🍽 Governor's Feast | +70 / +20 HP | +35 / +10 HP |

Drain context: typical session burns ~50-100 hunger (walk + combat). Berry refills 4% — a snack. Stew 20%. Feast 35%. Player needs to plan eating, not snack constantly.

**Starter recipes refactored.** The original 5.2.1 design auto-learned Baked Potato + Roasted Meat into `LearnedRecipe` rows at registration via a now-deleted `LearnedRecipe.ensureStarters` helper, with corresponding scroll artifacts (`artifact.recipe.baked_potato` + `artifact.recipe.roasted_meat`) that were redundant — using one would always hit the "already known" modal.

User correctly flagged this as messy: "видали рецепт печеної картоплі та смаженого мʼяса; це гравець може зробити на кухні одразу". Refactor:

- Removed both starter scrolls from `ItemCatalog` and dev seed.
- Removed the four locale keys for those scrolls (en + uk).
- Removed `LearnedRecipe.ensureStarters` and its callers in `RegistrationController.promptEstateName` + the dev seed loop.
- `RecipeCatalog.starterRecipeIds` switched from `[String]` to `Set<String>` and now serves as the canonical "always-available kitchen recipes" — no DB row needed, every player cooks these from day one.
- Kitchen UI's `kitchenKeyboard` filter became `learnedIds.union(starterRecipeIds)`.
- Both `handleCraftDetail` and `handleCraft` gates allow the call when the recipe id is in `starterRecipeIds` regardless of `LearnedRecipe` state.

Net result: same player-facing behaviour ("can cook potato/meat from day one"), but cleaner data model (no useless DB rows, no redundant scroll items, fewer locale keys, less code in the registration / dev-seed paths).

**Seventh dish added: 🥘 Meat Ragout.** User asked for an additional scroll-locked dish using meat + potato + nuts. Tuned at +18 hunger / +4 HP — sits between Forager's Omelette (+16/+3) and Hunter's Stew (+20/+5) on the heartiness scale. Recipe id `recipe.meat_ragout`, item id `food.meat_ragout`, scroll `artifact.recipe.meat_ragout`. Inputs: 2× 🥩 + 2× 🥔 + 1× 🌰. Distinct from Hunter's Stew (which uses egg) — earthy nut-and-meat profile. Locale parity bumped: 367/367.

**Carryforward to commit:** the refactor (starter cleanup + retune + Meat Ragout) is small and self-contained; it lands as a follow-up commit on top of the Phase 5.2.1 commit `8e55ef1`.

**Firewood requirement added.** Per user feedback "додай в рецепт приготування кожної страви по 1 брусу" — every kitchen recipe (including the always-available Baked Potato and Roasted Meat) now also consumes `1× mat.pine_lumber` for the cooking fire. Two reasons: narrative authenticity (cooking on flame needs firewood) and a soft cap on farm-cooking — players need lumberyard production or shallow-zone foraging to keep cooking. Dev seed pine_lumber bumped 5 → 15 so dev can cook through the catalog on first launch. CraftingService unchanged — pine_lumber drains from the same combined inventory + warehouse pool as everything else.

**Cooking banner verb split.** Kitchen success banner originally inherited `workshop.alert.crafted` ("Викувано ..." / "Crafted ..."), which read strangely for a kitchen pot ("forged a stew"). Added `RecipeCategory.craftedAlertKey` — Workshop returns `workshop.alert.crafted`, Kitchen returns the new `kitchen.alert.cooked` ("Приготовано ..." / "Cooked ..."). `EstateController.handleCraft` now reads the banner key from `recipe.category.craftedAlertKey` so the verb tracks the room.

**Starter recipe ratios fixed: 1:1.** `recipe.baked_potato` and `recipe.roasted_meat` originally consumed 2× food + 1× lumber to produce 1× cooked. User flagged the asymmetry: 1 potato should make 1 baked potato (and the lumber is already a meaningful cost). Both reduced to 1× food + 1× lumber → 1× cooked. The richer multi-ingredient dishes (Omelette / Stew / Ragout / Tart / Feast) keep their 3-5 input piles since combining many ingredients into one portion is intuitive.

**Locale parity bumped to 368/368** (one new key: `kitchen.alert.cooked` in both en + uk).

## Session — 2026-05-06 (Warehouse polish + dev seed sanity + Hunger → Vigor rename)

Three small landing pieces, one big terminology refactor, one shared commit.

### 1. Per-category "Deposit all" button on the Warehouse

User feedback: returning from a long expedition fills the bag with materials and food, and dumping it row-by-row was tedious. Withdrawing-all was rejected as an explicit request because crafting already auto-pulls from the warehouse pool — the only thing the player actually wants back from storage is **food before an expedition**, which fits the existing per-row ⬇️ buttons fine.

**Solution**: a single `[📦 Deposit all]` button per warehouse category. Sits **below** the per-item rows (above only the Back button) so it doesn't push the per-item arrows off the screen. Standard Telegram-blue styling — no green accent (rejected during the HTML preview round).

- New `WarehouseService.depositAll(category:for:on:)` — drains every unequipped `InventoryEntry` row of the given `ItemType` into `WarehouseEntry` in one shot. Equipped gear is skipped (same rule as the per-item `deposit`). Returns total units moved.
- New callback `estate:wh:depositall:<type>` matched **before** the existing `estate:wh:deposit:` / `withdraw:` handler in the dispatcher. Refreshes the category in place with a `✅ Moved N items to warehouse ⬆️` banner on success; modal alert "Nothing of this type in your bag." when nothing was movable (empty for that category, or only equipped gear).
- 3 new locale keys per locale: `estate.warehouse.button.deposit_all`, `estate.warehouse.deposit_all.success` (with `%{count}` interpolation), `estate.warehouse.deposit_all.nothing`.

User initially considered batch ×5 / ×10 buttons per row (Variant C2 in the design doc) but dropped the idea after the HTML preview showed how cluttered the layout would get on a phone-width inline keyboard. Stuck with the single deposit-all button per category.

### 2. Dev seed: skip recipe scrolls for already-learned recipes

Quality-of-life fix for the dev. The startup seed in `configure.swift` was top-up logic — every relaunch it would notice `LearnedRecipe.has(...)` had eaten the scroll and re-grant a new one. Three relaunches, three duplicate Forager's Omelette scrolls in the bag, etc.

**Fix** (`configure.swift:286-303`): before the inventory + warehouse top-up loops, build a per-developer `skipItems: Set<String>` of any seed entry whose `Item.teachesRecipe` recipe is already in the developer's `LearnedRecipe`. Both loops `continue` past those item ids. Side-effect logger line `"Dev seed: \(label) already knows \(skipItems.count) recipe(s); skipping their scrolls"` so the suppression is visible at startup.

`resetDevProfile = true` still wipes `learned_recipes` along with everything else, so a clean-slate run repopulates all scrolls — the skip only kicks in on the persistent path.

### 3. Hunger → Vigor terminology refactor (largest piece)

The "Hunger" meter was conceptually inverted: it counts up when you eat (food.restoreHunger gives +N), so calling it "hunger" is backwards — it's really a satiety meter. User picked **Снага / Vigor** (atmospheric Slavic word for vigour / vital force) over the more literal Satiety or RPG-canon Stamina because it sits well in a medieval setting and doesn't pre-claim a Stamina meter for future systems.

**Strategy**: rename Swift identifiers, locale keys, narrative text — but **keep the DB column name `hunger` / `max_hunger`** to avoid a destructive rename migration. Achieved via `@Field(key: "hunger") var vigor: Int` on the User model. No migration needed; existing data carries over with new code.

**Negative-state framing kept as-is** per user instruction: the "😵 Голодний" / "😵 Starving" indicator stays — even though the meter is named Vigor, the *low-state* is still framed as hunger (the player is hungry when their vigor is depleted). Same treatment for `exploration.outcome.starvation` ("Hunger gnaws at you. / Голод точить тебе зсередини."), `exploration.passive.outcome.starvation` ("🥀 hunger" / "🥀 голод"), and the Ukrainian `forest_berries.desc` lore line that mentions "втамовує голод". These are narrative / state-naming, not meter labels, so they don't conflict.

**Swift renames (all callsites swept)**:
- `HungerService.swift` → `VigorService.swift` (file renamed; `HungerService.swift` deleted)
- `HungerService` → `VigorService`, `HungerAction` → `VigorAction`
- `User.hunger` → `User.vigor`, `User.maxHunger` → `User.maxVigor` (DB column references via `@Field(key: "hunger")`)
- `ItemEffect.restoreHunger(Int)` → `.restoreVigor(Int)` (catalog + 11 cooked-dish call sites)
- `ConsumeResult.hungerRestored` → `.vigorRestored`
- All combat tunings: `cleaveHunger` / `vitalShotHunger` / `soulfireHunger` → `*Vigor`, same for Special Defense (`ironBulwarkHunger` etc.) and `mageHungerExtra` / `fleeHungerExtra` / `stanceActivationHunger` / `specialAttackHunger` / `specialDefenseHunger` / `hungerMultiplier`
- Method `applyHungerPenalty` (private on User extension) → `applyVigorPenalty`

**Locale changes (en + uk parity preserved)**:
- Renamed keys: `profile.hunger` → `profile.vigor`, `hunger.restored` → `vigor.restored`, `hunger.starving` → `vigor.starving`, `workshop.effect.hunger` → `workshop.effect.vigor`, `exploration.passive.report.hunger` → `vigor`
- Renamed interpolation variable in `exploration.outcome.encounter.won`: `%{hunger}` → `%{vigor}`
- Updated values where the meter is named: "Hunger"→"Vigor" / "Голод"→"Снага"; "hunger" (genitive context)→"vigor" / "голоду"→"снаги"
- `combat.super.warrior.activate` Ukrainian rewritten because "×2 голод" doesn't translate cleanly — now "снага витрачається вдвічі на N раундів"
- Kept literally: "😵 Starving" / "😵 Голодний" (as `vigor.starving` value), all `exploration.outcome.starvation` and `exploration.passive.outcome.starvation` text, `forest_berries.desc` lore (UK), the wordplay "blade hungers" inside Bloodlust's English narrative

**Replace strategy**: per-file `replace_all` for "Hunger" / "hunger" was safe because no Swift file has another word containing the substring. Only User.swift, AddGameStats.swift, AddCombatStanceFields.swift, and the new VigorService.swift retain the literal "hunger" — all in `@Field(key: "hunger")` references or comments documenting the DB-column-name preservation.

**Doc sync**: CLAUDE.md, README.md, TODO.md, content/recipes.md, and the entire .memory bank (status / architecture / file-map / game-core / localization / INDEX) all swept the same way. Historic session entries above this one **kept** as-is — they describe what was true at the time of writing.

### What I checked before commit

- `swift build` clean both after the warehouse change and after the rename pass.
- `grep -rn "hunger\|Hunger" Swift/` returns only the intentional residual (DB column names + the explanatory comments next to them). `grep -rn "Голод\|голод" Localizations/` returns only the kept narrative strings.
- Locale parity audit: 371 / 371 (3 new deposit-all keys per locale).
- No dead code: removed `HungerService.swift`; no orphan `restoreHunger` cases left.

### Files

**Added (1)**: `Swift/Services/VigorService.swift` (replaces deleted `HungerService.swift`).
**Modified (~20)**: `Swift/Controllers/{Combat,Estate,Exploration,GlobalCommands,Inventory,Main}Controller.swift`, `Swift/Migrations/AddCombatStanceFields.swift`, `Swift/Models/{Item,Recipe,User}.swift`, `Swift/Services/{Combat,Equipment,Exploration,Passive,Warehouse}Service.swift`, `Swift/configure.swift`, `Localizations/{en,uk}.json`, `CLAUDE.md`, `README.md`, `TODO.md`, `content/recipes.md`, `.memory/{INDEX,architecture,file-map,game-core,localization,status}.md`, `.memory/sessions.md` (this entry).

**Carryforwards**: nothing left over from this session — all three pieces shipped together.

## Session — 2026-05-06 part 2 (Passive expedition restart-safe reports)

User asked a sharp diagnostic question: "if the player is mid-expedition and the server restarts, what happens?". Walked through every mode (active / passive / combat / training) and surfaced one real flaw: passive expedition reports were partially incomplete after a restart because `outcomeCounts`, `lootPicked`, `lootDropped`, and the lazy `hpBefore` / `vigorBefore` lived only in the `runLive` Swift locals — restarting the bot reset those dicts to empty, and the final report only reflected events from the resumed run. Their friend's advice ("write the expedition state to DB instead of RAM") was exactly the right fix.

### Design

New nullable column `running_report_json` on `exploration_state`, holding a Codable `RunningPassiveReport` blob:

```swift
public struct RunningPassiveReport: Codable, Sendable {
    public var hpBefore: Int
    public var vigorBefore: Int
    public var outcomeCounts: [String: Int]
    public var lootPicked: [String: Int]
    public var lootDropped: [String: Int]
}
```

Lifecycle:

1. **`start()`** — right after `beginPassive`, snapshot `user.hp` + `user.vigor` and persist a `RunningPassiveReport` with empty counters. This also fixes a pre-existing edge case: the old code lazy-captured before-values on first step iteration, so a crash before the first step would have read post-restart HP/vigor as "starting" values.
2. **`runLive` first iteration** — try to decode `state.runningReportJSON`; if present, seed in-memory dicts from it. Legacy passive rows (created before the migration) skip this and fall through to the existing lazy-capture branch.
3. **`runLive` post-step** — after `recordOutcome`, build a fresh `RunningPassiveReport`, encode, set `state.runningReportJSON` and `state.stepsDeep`, single `state.save(...)`.
4. **`finalizeAndPush`** — unchanged; takes the now-complete dicts as parameters.

Cost: one extra small UPDATE per step (the `state.save()` already happened for `stepsDeep`; only the payload grows). At 1000 concurrent passives in test mode (5-second steps): ~200 UPDATEs/sec — trivial. In prod (5-min steps): ~3 UPDATEs/sec across the whole concurrent fleet.

Deliberately did NOT clear `runningReportJSON` separately — the row gets deleted at expedition end (via `pushReportNotification`'s `ExplorationState.end(...)` or via `beginPassive`'s clean-slate sweep on a fresh start), so leftover blobs can't accumulate.

### What restart now does, by mode

| Scenario | Before restart | After restart | Loss |
|---|---|---|---|
| Active expedition | (no scheduler — taps drive it) | Player taps anything → `RouterStore` sees `routerName="exploration"` → `showExploration` → `resumeActive` re-renders status card | None |
| Passive expedition | `Task.detached`-driven, in-memory dicts | `rescheduleInflight` spawns fresh runLive; first iteration reads `running_report_json` and continues with full history | None now (was: outcome counters + loot totals from the pre-crash slice) |
| Active combat / Training | Combat fields on `exploration_state`; inline buttons in chat are still tappable | Player taps inline button → `combat:*` callback → `routerName="combat"` (or `"estate"` for training) routes to CombatController | None |

### Code added

- `Swift/Migrations/AddPassiveRunningReport.swift` — pure schema add, nullable column, no backfill needed.
- `RunningPassiveReport` Codable struct + private `encodeRunningReport(_:)` / `decodeRunningReport(_:)` helpers in PassiveExpeditionService.
- `runningReportJSON` field on `ExplorationState` + `nil` initialization in the constructor.
- Restored from DB at the start of every `runLive` iteration (gated on `hasCapturedBefore` flag so it only seeds once).

### Files

**Added (1)**: `Swift/Migrations/AddPassiveRunningReport.swift`.
**Modified (3)**: `Swift/Models/ExplorationState.swift`, `Swift/Services/PassiveExpeditionService.swift`, `Swift/configure.swift`.
**Doc updates**: CLAUDE.md (ExplorationState description, migrations list, Phase 3.3 paragraph, services description), README.md (file tree under Models + Migrations, Phase 3.3 paragraph), `.memory/file-map.md` (ExplorationState row, migration list, PassiveExpeditionService description), `.memory/status.md` (Phase 3.3 line + ExplorationState fields list), `.memory/sessions.md` (this entry).

**Carryforwards**: nothing — fix is fully self-contained.

## Session — 2026-05-06 part 3 (Phase 5.2.2 weapon upgrade)

User's new design pillar: each class gets ONE weapon from the King at registration that **cannot be replaced — only upgraded**. Workshop becomes the place where iron is refined, edges are honed, and limbs are layered. Five-tier ladder per class, narrative naming (rust scrubbed → blade sharpened → spine reforged → master-tempered), gated by estate level (T2 = estate lv 2 ... T5 = estate lv 5). No skip-ahead — sequential progression.

### Stat tables (after the user's "крит з T2, більше з кожним рівнем" tweak on the sword)

| Tier | Sword (warrior) | Bow (archer) | Staff/Rod (mage) |
|---|---|---|---|
| T1 | +3 ATK | +2 ATK / +1 ACC | +2 ATK / +1 CRIT |
| T2 | +5 ATK / **+3% crit** | +4 ATK / +3 ACC | +4 ATK / +3% crit |
| T3 | +8 ATK / **+6% crit** | +6 ATK / +5 ACC / +3% crit | +6 ATK / +6% crit / +2 ACC |
| T4 | +12 ATK / **+10% crit** / +1 DEF | +9 ATK / +7 ACC / +6% crit | +9 ATK / +10% crit / +4 ACC |
| T5 | +16 ATK / **+15% crit** / +3 DEF | +12 ATK / +10 ACC / +10% crit | +12 ATK / +14% crit / +6 ACC |

T1 stats are intentionally identical to the legacy `Item.gearStats` for the three starter weapons — every existing equipped weapon survives the migration with the exact same numbers. Only T2+ adds anything new.

### Materials (per upgrade step, drained from combined inventory + warehouse pool)

Sword (iron-heavy):
- T1→T2: 3× 🪨 river_pebble (rust-scrubbing)
- T2→T3: 5× 🪨 + 2× 🔩 iron
- T3→T4: 1× 🔳 iron_ingot + 5× 🔩 iron + 3× 🪵 lumber (forge fire)
- T4→T5: 3× 🔳 + 10× 🔩 + 5× 🪵

Bow (lumber + sinew):
- T1→T2: 5× 🪵 lumber + 1× 🦴 hide (string)
- T2→T3: 5× 🪵 + 3× 🦴 (sinew)
- T3→T4: 10× 🪵 + 5× 🦴 + 1× 🔳 (arrowhead)
- T4→T5: 15× 🪵 + 8× 🦴 + 3× 🔳

Staff (rune-stone + crystal):
- T1→T2: 5× 🪵 + 3× 🪨 (rune-grinding)
- T2→T3: 5× 🪵 + 5× 🪨 + 3× 🟫 clay (crystal mount)
- T3→T4: 5× 🪵 + 8× 🪨 + 1× 🔳 (arcane wire)
- T4→T5: 8× 🪵 + 10× 🪨 + 3× 🔳 + 5× 🦴 (binding)

Per user spec: no new materials, scale within the existing 6-item palette. Each class' early tiers stay thematic (sword = stone/iron, bow = wood/sinew, staff = wood/stone), late tiers (T4-T5) pull a "foreign" material as a master-class flourish.

### Architecture decisions

User picked option **A** (single item-id + tier on InventoryEntry, dynamic stats) over option **B** (separate items per tier). Cleanest for the player perception "this is the same blade, refined" — and the data model only needs one new column instead of 15 new items. The DB column defaults to 1 so no backfill is needed; the migration is a single nullable-default ADD COLUMN.

Display names ARE tier-specific even though the item id isn't, via the new `ItemDisplay.nameKey(for:tier:)` helper: returns `<base.nameKey>.t<tier>` for items in `WeaponUpgradeCatalog`, falls through to `item.nameKey` otherwise. Same shape for descriptions. Three places use it: profile main-hand line, inventory gear rows, and the upgrade detail screen.

### Files

**Added (3)**:
- `Swift/Migrations/AddInventoryTier.swift` — `ALTER TABLE inventory ADD COLUMN tier INT NOT NULL DEFAULT 1`. Trivial, no backfill.
- `Swift/Models/WeaponUpgradeCatalog.swift` — static catalog of `[itemId: [WeaponUpgradeStep]]` with helpers `step(for:tier:)`, `stats(for:tier:)`, `maxTier(for:)`, `isUpgradable(_:)`. The single source of truth for both stats and materials.
- `Swift/Services/WeaponUpgradeService.swift` — pure service, `upgrade(for:on:) -> UpgradeResult`. Mirror of `CraftingService.craft`'s drain policy, but the output is a tier bump on the SAME row (no new inventory entry created).

**Modified (8)**:
- `Swift/Models/InventoryEntry.swift` — added `@Field(key: "tier") var tier: Int`, init to 1 in the constructor.
- `Swift/Models/Item.swift` — added `descriptionKey` to the three starter weapons (was nil) so tier-specific descriptions can compose; added `ItemDisplay` namespace at the bottom with `nameKey(for:tier:)` and `descriptionKey(for:tier:)` helpers.
- `Swift/Services/EquipmentService.swift` — `recomputeBonuses` now consults `WeaponUpgradeCatalog.stats(for:tier:)` first, falls back to `Item.gearStats`. T1 stats match the legacy values so the swap is invisible to current players.
- `Swift/Services/WarehouseService.swift` — added `notTransferable` result + check on `deposit` and skip in `depositAll` so tiered weapons can't be warehoused (the warehouse table has no tier column and would silently demote them).
- `Swift/Controllers/EstateController.swift` — workshop list adds `[⚔️ Upgrade weapon]` at the top; new `renderWeaponUpgrade` body + `weaponUpgradeKeyboard` + two callback handlers (`handleWeaponUpgradeDetail` / `handleWeaponUpgradeConfirm`). Helpers `formatStatLines` / `formatStatDeltas` render the current-tier block and the per-stat deltas. Stale-deposit `notTransferable` case wired in `handleWarehouseTransfer`.
- `Swift/Controllers/MainController.swift` — profile main-hand line now uses `ItemDisplay.nameKey(for:tier:)` so an upgraded sword reads "Sharpened Sword" instead of "Rusty Sword".
- `Swift/Controllers/InventoryController.swift` — gear rows use the tier-aware name; the info-modal handler resolves the description via `ItemDisplay.descriptionKey(for:tier:)` (queries the player's row to know which tier).
- `Swift/configure.swift` — registered `AddInventoryTier()` migration.

**Locales (en + uk parity 412/412)**:
- 30 weapon keys per locale (3 weapons × 5 tiers × 2 [name + desc])
- 11 `weapon.upgrade.*` UI keys (button label, title, no-weapon, max-tier, estate-too-low / -required, recipe-header, delta-arrow, button.confirm, banner.success)
- 1 `estate.warehouse.not_transferable` modal-alert key

### Edge cases closed

- Migration-time backwards compat: `tier` defaults to 1, T1 stats == legacy stats → existing equipped weapons see zero numerical drift.
- Tiered weapon in warehouse: now refused at the service layer (`notTransferable`). The UI surfaces a clean modal alert instead of silently downgrading on withdraw.
- Player without an equipped weapon: upgrade screen shows "no weapon" message, button hidden. Confirm callback also returns `noWeaponEquipped` if state somehow drifts.
- Player at max tier (T5): detail screen flips to "fully upgraded" body, no Upgrade button. Confirm returns `maxTierReached` if a stale callback fires.
- Skip-ahead forbidden by design: `WeaponUpgradeService.upgrade` always advances by exactly one tier, so a T1 → T5 jump-ahead is impossible without sequentially crafting through T2, T3, T4.

### Carryforwards

- **`content/weapons.md`** — was discussed as a possible reference doc, deferred. Not strictly needed yet; the catalog itself is the source of truth.
- **Dev shortcut for testing** (e.g. `/wpntier <N>`): not added. Dev can grind through normally for now; if it gets tedious during 5.x playtesting, add it as a one-line GlobalCommandsController route.
- **Pacing tuning** (estate-level mapping vs material costs): user explicitly deferred this until XP system lands. The current numbers are a starting point.

## Session — 2026-05-08 (CLAUDE.md trim)

### What was done:
- Trimmed `CLAUDE.md` from 218 → 143 lines (–34%) by collapsing two redundant blocks into pointers:
  - **Source Layout**: ~25 lines of per-file paragraphs replaced with a compact `Swift/` tree + pointer to `.memory/file-map.md` (canonical, kept in sync per session, ~27 KB of detail).
  - **Current State (as of 2026-04-23)**: ~70 lines of phase-by-phase status replaced with a one-line pointer to `.memory/status.md` (last updated 2026-05-06, strictly newer + more detailed than the CLAUDE.md block was).

### Why:
- Both blocks were duplicating content already in `.memory/`. Verified before removing: the more detailed copy lives in `.memory/`, and the CLAUDE.md text was older (2026-04-23 stamp) than the canonical sources (2026-05-06).
- `CLAUDE.md` is loaded into every session, so trimming reduces always-on context cost. Retained sections are real always-on patterns: architecture diagram, controller-add steps (incl. the register-buttons-for-all-locales footgun), key code snippets (Session access, sendMessage, callback_data 64-byte limit, Lingo), env vars, and the AI-assistant instructions block (memory rules, git workflow, code conventions).
- No code changes; pure documentation hygiene. README.md left as-is — different audience (project visitors), doesn't reference the trimmed sections.

### Decision rule for future trims:
- If a CLAUDE.md block duplicates `.memory/file-map.md` or `.memory/status.md` content, replace with a one-line pointer. Those two files are the canonical sources and are the ones kept fresh.
- If it's a pattern/snippet that doesn't drift (architecture, sendMessage signature, callback_data byte limit, locale-button footgun), keep it inline in CLAUDE.md.

## Session — 2026-05-20 (photo file_id everywhere + keep history; tavern game cleanup)

### What was done:
- **Renamed `sendScenicPhoto` → `sendCachedPhoto`** (`Swift/Helpers/PhotoCache.swift`). Dropped the scenery-slot deletion entirely — location/lore photos now **stay in chat history** (file_id cache only). Players asked to keep a scrollable record of visits (future stats). file_id dedup means a long history of repeated backdrops costs no extra storage.
- **Registration art now uses `sendCachedPhoto`** (`kings_charter.jpg` + per-class journey art) — previously direct `bot.sendPhoto(.file)` re-uploaded every time. Now file_id-cached.
- **Removed scenery slot** from `EphemeralChatState` (`lastSceneryPhotos` + setters); nothing else used it.
- **Tavern gambling self-cleanup**: `EphemeralChatState.tavernGameMessages` tracks every throwaway message of a dice/darts round (player/house labels, dice, result). New `clearTavernGameMessages(...)` in `CapitalController` deletes the prior round when a new round starts (replay/fresh roll, at top of `runRound` after silver debit) and when leaving to the tavern menu (`tavern:menu` handler). This is the ONLY photo/message flow that self-deletes now.
- Updated CLAUDE.md "Player-visible photos" section + stale comments in CapitalController/EstateController.

### Why:
- A friend's playtest showed location photos vanishing as the player navigated (old scenery-slot deletion) — looked broken and erased visit history.
- Tavern dice are pure noise that piled up on every replay → kept the per-round delete-on-replay there.

### Update — 2026-05-20 (tavern dice: 24h sweep, not in-round delete)

Correction to the entry above. Tried deleting the round's dice in-round / on-replay — **Telegram blocks it**: `deleteMessage` refuses a dice message in a private chat until it's >24h old (anti-cheat). Text (labels/result) deletes fine, dice don't → "wall of dice" persisted. User chose to keep dice as visible game history and clean up after 24h instead.

Final design:
- Reverted all immediate tavern deletion (in-round + cross-round + tavern:menu) and removed `EphemeralChatState.tavernGameMessages` + `clearTavernGameMessages`.
- New `TavernGameMessage` model + `CreateTavernGameMessages` migration (`tavern_game_messages`: telegram_id, message_id, created_at; no User FK).
- New `TavernCleanupService`: `record(...)` persists every round message id; `startSweeper(on:bot:)` (in configure.swift, mirrors PlotProductionService) runs catch-up sweep on boot + every 30 min, deleting messages + rows once `created_at` > 24h (deletableAfter = 24h + 60s).
- `runRound` collects label+dice+result ids into `roundMessageIds` and calls `TavernCleanupService.record`.

Note: dice can't be tested for deletion sooner than 24h — that's the Telegram floor, deleting earlier just errors.

## Session — 2026-05-21 (Gender selection at registration + uk feminitives)

Added player gender (male/female) chosen during registration, driving Ukrainian feminitive text and per-gender estate art. Design discussed at length before coding (placement, feminitive scope, hybrid neutralize-vs-variants split).

**Placement decision:** gender = new registration **step 1**, ahead of the name prompt (user choice), so even `registration.welcome` ("воїне/прибув") renders gendered. Step sequence renumbered 0–7 (was 0–6): 0 lang → 1 gender → 2 name → 3 class → 4 oath → 5 journey → 6 estate → 7 done. Replaced the magic `6` "done" sentinel with `User.registrationDoneStep` (4 sites in CombatController + 1 in configure).

**Data/infra:**
- `User.gender: String?` ("m"/"f", nil=male) + `AddGender` migration (nullable) + registered in configure.
- `CharacterGender` enum (configure.swift, ♂️/♀️ icons).
- `Lingo.localize(_:gender:locale:)` overload (Lingo+Locales.swift): branches on locale — `.m`/`.f` for uk, plain base key for en. **No English duplication.** Verified Lingo returns raw key + console warning on miss, so the locale-branch (not fallback-detection) is the clean design.
- dev-reset clears `gender = nil` → test profiles re-pick on the registration re-run (the only "reset" path; no player-facing reset exists).

**Art:** `CharacterClass.journeyImageName(gender:)` → `Assets/registration/<class>_estate_<m|f>.jpg` with `FileManager.fileExists` fallback to genderless `<class>_estate.jpg`. User to drop 6 files (warrior/archer/mage × m/f).

**Feminitive scope (full uk.json scan, not just the obvious 9):** ~20 keys gendered (`.m`/`.f`), 7 neutralized, 1 item-desc neutralized. The bulk beyond "намісник" was 2nd-person past-tense (`ти подолав`, `ти знайшов`…) in combat/exploration — present tense and formal `Ви + -ли` are already gender-neutral.
- **Variants (.m/.f):** registration.welcome / name_accepted / king_oath / wolves_retry / estate.prompt, estate.blocked_by_expedition, capital.blocked_by_expedition, capital.location.tavern.body, capital.trader.intro, capital.fortune.intro, exploration.outcome.trip / encounter.won, exploration.death, exploration.duration.prompt, exploration.passive.started / closed_home / report.death, combat.ended, combat.special_def.archer.activate, bot.restarted.
- **Neutralized (Cat 1):** capital.tavern.gamble.ready_prompt ("Кидаємо?"), kitchen.alert.not_learned, combat.tech.no_uses_left, combat.tech.locked, exploration.outcome.loot.picked ("Знайдено…"), travel.cannot_start.no_hp ("Рани не пускають у дорогу"), travel.cannot_start.no_vigor ("Сил на дорогу не лишилось"), item.food.governors_feast.desc (gendering one item would mean plumbing gender through the whole item-desc path).
- New: registration.gender.prompt/.m/.f (both locales).

**Call-site routing:** ~20 sites switched to the `gender:` overload. Threaded `gender:` params into `ExplorationController.narrateOutcome` and `PassiveExpeditionService.renderReport`. Special cases: tavern body gendered only for `.tavern` in `renderLocation`; `postCannotStart` got a `gendered: Bool` flag (true only for capital.blocked_by_expedition).

**Verification:** JSON valid (both locales); `swift build` green; scripted check confirms every routed key has exactly `.m`+`.f` in uk.json, no stray uk base, base intact in en.json, and no plain `localize` left on a split key.

**Word choices to confirm with user:** "воїне"→"войовнице" (welcome.f), намісник vocative→"наміснице".

Not committed (awaiting audit-and-commit prompt). Docs updated: CLAUDE.md (Localization rule), .memory/localization.md (full gendered section), status.md, file-map.md.

### Addendum — registration tutorial mob (same day, 2026-05-21)

The first registration fight was against `enemy.rabid_wolf` (tier 4, hp 70, atk 28) — far over-tier for a fresh L1 player with only a starter weapon. Added a one-off `enemy.rabid_dog` (🐕, tier 1, hp 18, atk 14, def 1 — wild_boar level), `depthRange 0...0` so exploration never rolls it (mirrors the training dummy), empty lootTable, xpReward 0. `RegistrationController.startWolvesFight` now finds `enemy.rabid_dog`. The registration branch of `CombatController.finishVictory` already grants no XP and (with the empty loot table) no loot, so the fight is purely instructional.

Narrative updated to match: the journey/retry copy now describes a single rabid dog instead of a wolf pack (uk uses feminine "скажена собака" → "вона … вискочила").

Then renamed all internal "wolves" identifiers to "dog" (separate pass): locale keys `registration.journey_dog` / `registration.fight_dog` / `registration.dog_retry` (were `*_wolves` / `wolves_retry`); funcs `Registration.startDogFight` / `promptJourneyDog`; callback `reg:fight_dog`; local var `dog`; MARK "Rabid Dog Fight Bridge". Also corrected stale step numbers in the bridge comments (journey is now step 5, victory→6, not the pre-gender-renumber 4/5) and refreshed "wolves" wording in CombatController / CombatService / configure comments. The exploration `enemy.rabid_wolf` (tier-4 wilderness mob) is untouched. Build green.

### Addendum 2 — art assets dropped in (same day, 2026-05-21)

User supplied the real artwork.
- **Per-gender journey art** (6 files) → `Assets/registration/{warrior,archer,mage}_estate_{m,f}.jpg`. Removed the old genderless `*_estate.jpg` (3 files) per user request, and simplified `promptJourneyDog` to use the gendered path directly (dropped the `FileManager.fileExists` fallback + `CharacterClass.journeyImageNameFallback`).
- **Per-tier estate art** (7 files) → `Assets/estate/level_1.jpg … level_7.jpg`, converted from the user's `Tier_1…7.png` via `sips -s format jpeg`. Covers all tiers (EstateUpgradeCatalog.maxTier = 7). EstateController loads `level_<estateLevel>.jpg` directly.

Build green.

### Addendum 3 — capital art + file_id cache rule (same day, 2026-05-21)

- Replaced the capital backdrop: user's `capital.jpeg` → `Assets/capital/welcome.jpg` (1280×853 JPEG).
- **file_id cache audit:** every player-visible image is sent via `sendCachedPhoto` (9 call sites: registration kings_charter + journey art, capital welcome/location/trader/fortune-intro/fortune-card/tavern×2, estate level art). So all new art (6 journey + 7 estate + capital) auto-registers its file_id on first send — nothing extra to wire up.
- Closed the one cache-bypass loophole: `TGBot.sendMessage(session:text:…)` had an unused optional `photo: TGFileInfo?` param that called `bot.sendPhoto` directly. Removed it (no callers ever passed it) so `sendCachedPhoto` is structurally the only photo path.
- Strengthened the CLAUDE.md "Player-visible photos" rule: every image MUST go through `sendCachedPhoto`; convenience `sendMessage` has no `photo:` param by design; restart the bot after swapping an asset file so the stale in-memory file_id drops.

Build green.

## Session — 2026-05-21 (Phase 6.5 — Master capital location + armor durability)

Built the **Master** — the capital's armor shop / repair / enchant NPC, the game's first real silver sink. Closes the economy loop (silver finally has a meaningful drain). Designed interactively via quizzes (user prefers AskUserQuestion for clarifications).

**Scope (user decisions):** Master works on **armor only** for now — weapons keep the Workshop tier ladder + a future gem-inlay phase (gems drop from rabid beasts later, nothing now). Three actions: Buy / Repair / Enchant.

**New files:**
- `Swift/Models/MasterCatalog.swift` — shop economics: `armorForSale` (Forester set, ≈2.5× resource value: hood 15 / boots 23 / breeches 38 / jerkin 45🪙), `repairCost(itemId:missing:)` (≈half buy price for a full repair), `enchantSteps` (L1 30🪙+3 hide / L2 70+6 / L3 150+10) + `enchantCap` 3.
- `Swift/Services/GearConditionService.swift` — durability runtime. `maxDurabilityStart` **30**, `repairMaxShave` 1, `armorSlots`, `WearEvent` (victory 1 / defeat 3 / flee 5). `drainEquippedArmor(amount:)` = **model C**: a fight's wear budget distributed point-by-point across random equipped armor (no synchronized set-collapse cliff), recomputes bonuses after.
- `Swift/Services/MasterService.swift` — `buy` / `repair` / `enchant`, typed result enums, all drain `User.silver` (+ materials/durability). Armor-only.
- `Swift/Migrations/AddGearCondition.swift` — `durability` + `max_durability` (default 30) + `enchant_level` (default 0) on inventory.

**Model/logic changes:**
- `InventoryEntry` gains the three columns (init defaults from `GearConditionService.maxDurabilityStart`).
- `EquipmentService.recomputeBonuses` — armor at 0 durability is **broken** (0 stats); armor `enchant_level` adds +1 DEF/level.
- Wear hooks: `CombatController` (victory/defeat/flee paths), `PassiveExpeditionService.finalizeAndPush` (won×1 + lost×3 budget for the run).
- **Repair = mechanic B**: restores to (max−1), so a piece slowly wears toward a rebuy.

**UI (CapitalController, mirrors Trader):** `showMaster` → `[🛡 Buy][⚒️ Repair][✨ Improve]` → per-item button lists (price / durability / enchant step) → `MasterService` → `✅/❌` banner + in-place refresh. Inventory gear rows now show armor condition (`✨+N` / `💥` broken / `⚙️dur/max`).

**Tuning decisions (quizzed):** broken-at-0 = 0 bonus; buy markup ×2.5; enchant cap +3; starter durability lowered 100→30 for a felt repair cadence; wear distribution = model C (point-by-point random).

**Polish:** removed the inline `[🔙 До столиці]` button from ALL capital result banners (`backToCapitalBannerKB` deleted) — the persistent reply-keyboard is always visible, so banners are now just `✅/❌ text`.

**Bug caught in playtest:** `itemLabel` interpolated `item.icon` (an Optional) directly → `Optional("🪖 ")` leaked into buttons; fixed with `.map { } ?? ""`. User asked to remember the rule (saved to auto-memory `feedback_verify_interpolation`): a clean build doesn't catch interpolation bugs — verify new player-facing strings render (no `Optional(...)`, no emoji-before-`%{}`).

**Locale:** 17 new `capital.master.*` keys (en + uk, UA glossary — ЗАХ for defense). Build clean, parity confirmed.

**Deferred:** weapon durability + gem inlay (next phase). `Assets/capital/master.jpg` not added yet (text fallback). `repairMaxShave` is the lever if the rebuy loop should be felt sooner.

## Session — 2026-06-15 (Bazaar / Market + Trade — post-playtest polish)

First playtest of the Phase 6.5 Bazaar (player-to-player Market + 🤝 Trade). All changes are polish on the already-built feature; the feature itself (MarketService/MarketListing/MarketCatalog/CreateMarketListings + TradeStore/TradeService) was uncommitted from prior sessions and ships in the same commit.

**Localization & naming:**
- uk renamed **Ринок → Базар** everywhere (main button + all copy). English kept (button "Market" / location "Bazaar").
- Fixed the `🪙 Срібло: %{silver}` trade button — classic Lingo emoji-before-`%{}` bug left the literal `%{silver}`. Moved 🪙 into Swift (`"🪙 " + lingo.localize(...)`), template plain. Applied the go-forward rule; audited all new market/trade keys (no other offenders).
- Dropped the unused `від %U` from the buy-board row (`capital.market.board_row`) — feature not wanted; removed the `from` interpolation in the controller.
- +2 keys `capital.trade.gave`/`got` ("Ви віддали:" / "Ви отримали:", plural past = gender-neutral).

**Trade confirmation flow (user quiz):** `TradeStore.mutateBuilding` now resets ONLY the editor's stage-1 ready-flag (was BOTH). The partner's «Погодити» survives your edits, so each player taps it once at the selection stage instead of re-tapping after every partner edit. Safety preserved — the locked-summary stage still re-confirms both sides, so committing a changed deal is impossible.

**Trade summary record:** new `finishTradeSuccess(sides:context:)` replaces the plain done-banner on success — posts a PERMANENT per-side record (✅ done + "Обмін із <nick>" + gave/got lists) as a fresh message at the BOTTOM of the chat (below the typed quantity), then restores the Market menu. Gives players a scrollable history of when/with-whom they traded. Cancelled/declined/timed-out stay plain banners.

**Bazaar message-visibility policy (iterated with user):** transient numeric prompts (market listing qty→price, trade silver/qty) are DELETED on submit/cancel/teardown; ✅/❌ banners, the trade record, and menu screens (edited in place) are KEPT. (Briefly tried keeping all prompts; user refined to delete the input prompts only.)

Build green after each step; both locale JSONs validate. Docs synced: README (CapitalController entry + Trade/TradeStore/TradeService in structure + EphemeralChatState), file-map (mutateBuilding note corrected, Trade UI + visibility policy, pending types), status.md, TODO.md.

## Session — 2026-06-16 (Phase 7.1 — Guilds: full v1 in the capital)

Built the Guild system end-to-end across four increments (data → controller skeleton → social → vault/treasury), driven by a design quiz up front. User chose: separate `GuildController`, 3-tier roles (leader/officer/member), v1 scope = core + shared vault.

**Data (Inc 1):** `Guild` (name unique, tag, emblem, leader, treasury, motto) + `GuildInvite` + `GuildVaultEntry` (mirrors WarehouseEntry, keyed by guild) + `GuildCatalog` (`GuildRole` enum + tuning: memberCap 20, maxOfficers 2, foundCost 500🪙, foundLevelGate 5, vaultUnitCap 3000) + `User.guild`/`guildRole` (`@OptionalParent` + field). Migrations `CreateGuilds` → `AddUserGuildFields` → `CreateGuildInvites` → `CreateGuildVault` (order matters — FK targets).

**Controller (Inc 2):** routerName "guild", entered via a new capital `🏰 Гільдії` reply button (flips routerName, CombatController-style keyboard takeover). Membership-branched reply keyboard; drill-downs inline + `EphemeralChatState.PendingGuildInput`. Found / leave / disband / roster / browse.

**Social (Inc 3):** invite by nickname/@username (`findTarget` = userName ILIKE then nickname ILIKE) + fire-and-forget push; accept/decline from the guildless-home invites list; kick (rank rules) + promote/demote (leader only, officer cap 2). Pushes to invitee/kicked/promoted/demoted.

**Vault + treasury (Inc 4 + follow-up):** item vault `🏦` (stackables ONLY — the row carries no enchant/durability, so gear is excluded; deposit any member / withdraw leader+officers; cap 3000) and silver treasury `🪙` (deposit any / withdraw leader+officers; the existing `Guild.treasury` field). User had forgotten the treasury initially; added after the vault.

**Post-build tweaks (user):** (1) capital button uk "Гільдія" → "Гільдії"; (2) invite push "Гільдхолу" → "Гільдій"; (3) **interpolation bug** — `guild.roster.title` had a leading 👥 before `%{name}` (Lingo left the literal) → moved 👥 to Swift, audited all guild keys with a script (clean). (4) **Tag is no longer auto-derived** — `found` stores an empty tag; the game creator assigns it manually via DB (Postico) to avoid bad abbreviations; the name prompt now tells the player to message `@TGUserName`; `tagSuffix()` hides ` [TAG]` while empty. Removed dead `deriveTag` + unused `tagMin/MaxLength`.

All neutral uk copy (passive: founded/left/disbanded/deposited/withdrew) — no gendered words, gender rule untouched. 82 guild locale keys × 2, parity verified. Build green throughout. Docs synced: README (GuildController prose + structure: controllers/models/migrations/services), TODO (7.1 marked, deferrals listed), status.md, file-map.md. Also carries the earlier-decided TODO note: XP→Estate redesign DROPPED.

**Deferred (7.1+):** guild chat (bot-proxied fan-out), banner-on-estate, non-aggression pacts (need territorial PvP), leadership transfer.

## Session — 2026-07-20 (Phase 8.3 — Arena "Ристалище": live PvP герць v1)

### Context
User returned after a break (migrated DB to a fresh one — operational only, no code delta; last commit was 7.1 Guildhall). Reviewed where we stopped, then chose to skip the rest of Phase 7 and jump to the Arena (Phase 8; pets stay post-release). Design settled via two AskUserQuestion quizzes: name **Ристалище** · **live** real-time turn-based герць (NOT async) · rating **Честь** (ELO) · matchmaking **queue + lobby-challenge** (both) · start HP **current** (heal before fighting) · **no** gear/vigor wear (silver stake is the only cost). Assumed + stated: non-lethal (loser floored at 1 HP, no inventory wipe), damage carries to real HP.

### What was built (v1 = lobby-challenge slice of the live engine)
New files: `ArenaCatalog.swift` (constants), `ArenaProfile.swift` + `CreateArenaProfiles.swift` (Честь/W-L/daily), `ArenaStore.swift` (in-memory actor, TradeStore-shaped: lobby + pending + duels + byUser; combat dice rolled INSIDE the actor via `CombatService.applyAttack` so roll+HP mutation are atomic; 45s turn timer, auto-defend on timeout, forfeit after 2 misses), `ArenaService.swift` (snapshot/validateMatch/honorAfter ELO K=32/settle + startSweeper), `ArenaController.swift` (routerName "arena", hub vs fight reply keyboards, challenge→stake→invite→accept→live duel, honor/leaderboard). Wired: AllControllers, CapitalController.onArena (flip routerName, like onGuild) + `arena:` callback forward, MainController `arena:` forward, configure (migration + sweeper). 58 arena locale keys × 2 (all neutral — no gendered words; templates kept emoji-free where they carry %{}, emoji ride in interpolation values / Swift prefixes per the Lingo rule). Renamed capital button/title uk → «Ристалище». Build green.

### Economy / rules as implemented
No escrow: silver only moves at `settle` (loser → winner minus 10% King's tithe = burned sink), so a bot restart mid-duel cancels with zero financial effect. Current-HP carry-over, non-lethal floor 1. Honor ELO both sides. Daily cap 20 (generous for testing). Leagues Новак/Боєць/Ветеран/Чемпіон by honor threshold.

### Deferred (next increments, same engine)
Queue auto-pairing (2nd half of the "both modes" decision — lobby-challenge shipped first), ranked/unranked split, seasons + end-of-season rewards, escrow-on-restart refund. Not committed yet — awaiting the user's audit-and-commit prompt.

## Session — 2026-08-29 (Full pre-release rebalance — design + Phase 0)

### Context
User: "гра абсолютно незбалансована", asked for a rebalance plan that must also cover adding
new items / sets / monsters in future. Audit (3 parallel explorers) found the math is broken,
not mistuned — see TODO.md "Full Rebalance" for the evidence list.

### Decisions (AskUserQuestion, two rounds)
Full data-driven · full wipe at release · 3+ months to cap · **maxLevel 40** · death stays
harsh (full bag wipe) · slow vigor regen + food · framework + levels 1–15 authored ·
**content spec approved before authoring** (user's explicit condition).

### Calibration findings that changed the design
Ran a numerical audit + Monte-Carlo. Five structural corrections to the first draft:
1. **DR denominators must be derived from the item budget curve**, not hand-picked — otherwise
   a stat's *percentage* rots while its *rating* grows (archer dodge would end at 9.7% on L40,
   below its L1 value).
2. **Growth must be proportional, not flat** — flat growth drops warrior dodge 5.3% → 1.4%.
3. **Enemy generation is design-time, not runtime** — runtime scaling nullifies every gear
   upgrade (Oblivion trap). Needs an explicit `levelDiff` damage modifier to sell "I out-gear
   this zone".
4. **The drafted boss archetype was arithmetically impossible** — fixed HP-loss over rising
   rounds made the boss hit *softer* than trash (4.5% vs 6.6% maxHP per swing).
5. **Rarity multipliers were 3× too large** — drafted 1.95/2.45 gave 2.73×/4.15× total power.
   Capped at 1.45, with enchant as +4% of the item's *own* budget per step (never flat points —
   a flat bonus is worth 267% of base DEF at L1 and 14% at L40).

Also found, unplanned: DEF-ignoring techniques become *net vigor losses* under a mitigation
curve (0.44–0.59× efficiency); `WearEvent.flee = 5` > `defeat = 3` makes fleeing cost more than
dying; passive expeditions are 53% more vigor-efficient than active (they always roll the fresh
encounter table and charge 1 vigor/round instead of 2); **taps, not vigor, bind at L40**
(390/day ⇒ 26–42 min of button-mashing, so `combatAttack = 2` must stay as the tap governor);
the harsh death penalty is a hidden ~10%-of-gross-income sink.

Cross-check that killed the naive assumption: 60 kills/day is short by 3–6× on vigor. Real
throughput is 19/day at L1 → 47/day at L40. The XP curve was re-derived from that budget:
`xpToNext(L) = max(11.4·L^3.30, 120L)`, `mobXP(L) = 26·L^1.55·archXP` → 19.4M XP, ≈110 days at
80% engagement.

### Phase 0 built (this session)
4 new SwiftPM targets under `Modules/` + `Tests/` (first test target in the project).
`ROIContent` is Foundation-only, so `swift test` runs without Fluent/Postgres/Telegram.
DTOs decode into tolerant `String` fields on purpose — the validator has to run on data the
domain types would trap on (`ClosedRange` with min > max, `Dictionary(uniqueKeysWithValues:)`
on a duplicate id). Every DTO hand-writes `init(from:)` because **Swift does not apply property
defaults for missing keys** (locked by a test).

`GameData` uses `nonisolated(unsafe)` + `NSLock`, NOT `Synchronization.Mutex` — `Mutex` is
macOS 15 and the package targets 14; a lock acquire is ~20 ns at this scale. NOT `@TaskLocal`:
task-locals don't cross `Task.detached`, and six long-lived detached tasks read catalogs.

**`@_exported import` spike passed** — `Swift/Helpers/ContentBootstrap.swift` compiles with no
import of its own, so the ~315 existing catalog call sites need zero churn in Phase 2.

Validator ships identity / enum-value / reference / localization / timeScale rules. Two locale
facts verified against the real files: 21 en keys have no plain uk form and **all 21** are
covered by `.m`/`.f` pairs (a naive parity check would emit 21 false errors); the
emoji-before-`%{}` Lingo bug has **0 occurrences** across 259/268 interpolated values — the rule
now guards against regression rather than finding existing breakage.

24 tests green; both binaries link. **Provably inert**: +26 lines in `Package.swift`, +6 in
`configure.swift` (the two re-exports), nothing else in `Swift/` touched, `ContentBootstrap`
called from nowhere.

### Also in this commit
`Prompt.me` → `Prompt.md` (user's rename, byte-identical content). The three live pointers were
repointed: `CLAUDE.md` key-documents table, `.memory/file-map.md` tree, `TODO.md` checklist. The
two mentions in this file's own history (2026-04 entries) were left alone — the file really was
called `Prompt.me` then, and rewriting a session log would make it lie.

### Phase 1 built (same session)
`ContentExporter` + `--export-content` in `entrypoint.swift` (before `configure`, so no DB or
network) and `ContentMapping` with BOTH directions — `toDomain()` written now because the
round-trip proof is meaningless unless the DTO can actually rebuild the domain value, and
Phase 2 reuses it verbatim.

Exported `content/data/` — 33 items, 9 enemies, 12 recipes, 3 ladders. **Zero normalization**:
the `0...0` depthRange sentinel on training_dummy/rabid_dog is exported as-is (normalizing it to
null would be behaviour-identical, but Phase 1 must be provably neutral, so that cleanup gets its
own commit). Declaration order preserved — `pickFor` is `filter().randomElement()`, so order
decides which enemy a seeded roll returns. `starterRecipeIds` and the ladder dictionary are
sorted, since both sources are unordered.

`generatedAt` deliberately omitted from the manifest: a timestamp would dirty every re-export and
destroy the byte-for-byte comparison. Two independent exports verified byte-identical.

**Validator findings on the real bundle: 0 errors, 6 false warnings** — the base
`item.gear.<weapon>.desc` key for the three tiered weapons. Root cause: `ItemDisplay` appends
`.t<tier>` for anything with a ladder, so the base `.desc` is never resolved and all three
legitimately lack it (only `.desc.t1…t5` exist). Fix required ladder data, so
**`weapon_upgrades.json` was pulled forward from Phase 3** — with an explicit `tier` field per
step, because the shipped catalog encodes tier as nothing but array position. New ladder rules:
tier-matches-position, no stat regression across tiers, T1 costs nothing, ladder target must be
main_hand gear, durability table at least as long as the longest ladder. Real bundle now: 0
errors, 1 warning (`timeScale 60.0` — truthful while the three testMode flags are on).
`--strict` exits 1 on it.

### Phase 1 audit — two defects found in my own verification
1. **The canonical round-trip has a blind spot.** `domain → DTO → domain → DTO → JSON` stays
   byte-stable even when the mapper never captured a field at all: both directions drop it
   consistently, so the encodings still match. Added **layer 0 (domain equivalence)** — rebuild
   the domain value from the DTO and compare field-complete fingerprints against the original.
   Proven non-vacuous by negative test: deleting `teachesRecipe` from the mapper (which would
   have silently removed all five recipe scrolls from the game) left layers 1 and 2 GREEN; only
   layer 0 went red. A second negative test (enemy loot quantity forced to 1) behaved the same
   way. **Lesson: a round-trip proves the mapping is self-consistent, not that it is complete.**
2. **Diagnostics were lost on failure.** `print` is block-buffered when stdout is a pipe, and an
   error escaping `@main` terminates without flushing — so the failure explanation vanished
   exactly when it was needed. Now `fflush(stdout)` before throwing, and the export branch
   catches, prints and `exit(1)` instead of a top-level `fatalError`. Verified: exit 1 on
   failure, 0 on success.

Independently cross-checked with a Python parse of `Item.swift` / `Enemy.swift` (no Swift mapper
code involved): all 11 item fields × 33 items and all 10 enemy fields × 9 enemies match the JSON.

37 tests green. Still inert: the bot never reads `content/data/`.

### Phase 2 built (same session) — the catalogs now read JSON
`ContentBootstrap.load` wired into `configure` after `Dotenv.configure`, before the DB block.
`DomainContent` + `Catalogs` holder added in the main target: the domain types still live in
`Swift/Models/`, so `ROIContent` can only hold DTOs, and mapping DTO→domain on every `find()`
would allocate inside combat loops. `ContentBootstrap.load` installs BOTH snapshots from one
bundle so they cannot drift. Item/Enemy/Recipe façades replace **397 lines of hardcoded arrays
with 40 lines of routing**.

**Verification layer 3 turned out NOT to need full RNG threading.** The migration changes where
catalog data comes from, not how rolls resolve — so the only place needing determinism is where
catalog data feeds a random choice: `EnemyCatalog.pickFor`. Added a seedable overload and made
the argument-free one delegate to it, so there is a single selection implementation and the
digest can never replay different logic than the game runs. Full threading through
`ExplorationService`/`CombatService` stays a Phase 8 prerequisite for the simulator.

`--content-digest` = record fingerprints (catalog order) + seeded `pickFor` replay (40 depths ×
200 draws, fixed seed). Swift-array baseline and JSON result are **identical:
`545017168ce60953`**.

Proven non-vacuous by two negative tests:
- swapping two enemies in `enemies.json` moved BOTH halves;
- dropping `?? all.first` from `pickFor` left `records` byte-identical (`732746c647e9e55c`) and
  moved `spawns` alone — a selection-logic change that record hashes structurally cannot see.

Caught while writing the digest: my first seedable `pickFor` omitted the `?? all.first` fallback,
so it measured different logic than the game runs (visible as 1000 empty draws at km 36–40). The
fallback is a real bug — past km 35 every encounter is a wild boar — but it is preserved
deliberately; fixing it belongs to Phase 5, not to a migration that must be neutral.

Also added a live façade smoke test (every recipe input/output, loot id, scroll, starter recipe
and class starter weapon resolved through `find()`), and narrowed `ContentExporter` to
Swift-backed catalogs only — re-exporting a façade would write back what was just loaded and
prove nothing.

37 tests green. Verified no `static let` anywhere reads a catalog at type-init, which would now
trap since `all` is a computed property.

### Phase 3 Batch A — weapon / bag / estate ladders
Three more catalogs became façades: `WeaponUpgradeCatalog`, `BagCatalog`,
`EstateUpgradeCatalog`. `bags.json` and `estate_upgrades.json` exported (weapon_upgrades.json
already existed from Phase 1). **386 lines of Swift arrays deleted.** `MaterialCostDTO` introduced
and `WeaponUpgradeInputDTO` aliased to it — every ladder in the game costs materials in the same
`{itemId, quantity}` shape.

**Audit found a gap in my own verification.** The digest fingerprints the DATA, but the accessor
bodies (`nextStep`, `capForTier`, `durability(forTier:)`, `stats(for:tier:)`, `isUpgradable`) were
rewritten during the flip and nothing checked them. Added an accessor replay over tiers −2…12
(deliberately including out-of-range values), then verified it properly: reverted ONLY the three
catalog files to HEAD with `git stash push -- <paths>` and re-ran the *same* digest code against
the Swift arrays. Identical: `9242a2c1501994ed`. **Lesson, again: fingerprinting data does not
verify the code that reads it.**

`nextStep` gained a bounds guard the original lacked — the original would have crashed if
`maxTier` exceeded `progression.count + 1`. Can't happen with valid data (the new contiguity rule
enforces it), and the replay confirms no observable difference.

New validator rules: tier contiguity (both ladders index `progression[toTier − 2]`, so a gap
silently hands out the wrong upgrade), ladder-capacity vs the flat `capacities` table
disagreement, capacity regression, estate level-gate regression. +5 tests, 42 total.

Independently cross-checked by parsing the pre-flip Swift arrays out of git HEAD: bag maxTier and
capacities, all 5 bag steps, all 6 estate steps, all 3 weapon ladders and `durabilityByTier` match
the JSON exactly.

Digest also extended to cover Batch B (Trader / Tavern / Market / Guild / Arena) while they are
still Swift-backed, so the baseline for that flip is already recorded. It includes a `leagueKey`
replay across honor 0…2000 and a `tithe` rounding replay, because `ArenaCatalog.leagueKey` is a
hardcoded switch that becomes a league table in JSON.

`ContentExporter` is empty again for the same reason as Phase 2 — re-exporting a façade writes
back what was just loaded. It now prints the list of catalogs still awaiting the move.

### Documentation + memory sync pass (same session)
Dead-code sweep removed 8 genuinely unreferenced symbols: `GameContent.itemsByType` (DomainContent
has its own), `ContentReport.telegramSummary`, `ContentError.notLoaded` (the holders trap with
`fatalError` instead), `GameData.isLoaded`, `Catalogs.isLoaded`, `LocaleIndex.keys(withPrefix:)`,
`ROISim.describe`, `ContentBootstrap.schemaVersion`; `ContentDigest.fingerprint` tightened back to
`private` now that the exporter no longer shares it. Digest unchanged (`9242a2c1501994ed`), 42
tests still green. Forward-looking DTO fields (`rarity`, `setId`, enemy `level`/`archetype`/
`silverReward`/`spawnWeight`) were KEPT — they are schema placeholders documented for Phases 5–6,
and having them now avoids a `schemaVersion` bump later.

Stale records found and fixed:
- `content/recipes.md` still listed the pre-2026-05-22 Forester costs (2/6/5/3 hide, "full suit 16
  hide"). Regenerated from `recipes.json`: 40 hide + 8 iron.
- `content/bestiary.md` carried a "Stat scaling" block with pre-2026-05-15 ATK values
  (18/5/1 … 120/22/4 vs the real 18/14/1 … 120/38/4) and named `rabid_wolf` as the registration
  tutorial enemy — it has been `rabid_dog` since 2026-05-21. Both regenerated from
  `enemies.json`, plus new sections for the non-rollable mobs, XP rewards, and a JSON-based
  "adding a new enemy" workflow that spells out the order-is-load-bearing and band-dilution traps.
- `CLAUDE.md`, `README.md` and `GDD.md` still described catalogs as living in code.
- `.memory/status.md` had a trailing blob mislabelled "Last updated: 2026-05-02" sitting *below*
  three newer "Previously:" entries; relabelled and a provenance note added at the top.

New knowledge files: `.memory/content-pipeline.md` (architecture, add-content workflow, migration
loop, verification layers, gotchas) and `.memory/rebalance.md` (audit evidence, locked decisions,
calibrated formulas, the five structural corrections, phase tracker). Both linked from
`.memory/INDEX.md`. `Prompt.md` fully rewritten so a fresh session resumes at Phase 3 batch B
without reading anything else first.

Auto-memory: added `project_rebalance_active`, `feedback_phase_gate_approval`,
`feedback_content_spec_before_authoring`, `feedback_verify_migration_not_just_roundtrip`; updated
`feedback_commit_protocol` for the evolved two-form audit prompt.

### Phase 3 Batch B — trader / tavern / market / guild / arena *(2026-08-29)*
Five capital institutions moved to `content/data/`. **Migration digest identical across the flip:
`9242a2c1501994ed`**, records and spawns halves both unchanged. 62 tests green (was 42).
`roi-content validate` clean; `--strict` still exits 1 on the honest `timeScale 60.0`.

The batch was not homogeneous, and that turned out to be the whole lesson. It held three
different kinds of thing, each needing a different guarantee:

- **Ordered records** (11 trader listings, 7 tavern dishes). Order is gameplay — it is the order
  the player scrolls — so nothing sorts them, in the loader or in `DomainContent`. Layer 0
  rebuilds the domain value and compares field-complete fingerprints, exactly as the ladders do.
- **Tuning scalars** (2 market + 8 guild + 11 arena). These decode as **required**, never
  `decodeIfPresent`. The ladders' optional-with-default pattern is right for a list (absent
  `inputs` = no cost) and actively wrong for a constant: a missing `memberCap` silently becoming
  20 is precisely the invisible balance drift the pipeline exists to stop. Their layer 0 is
  encode → decode → compare each decoded field against the live Swift constant, because a
  round-trip is blind to a transposed pair — `maxOfficers` written into `memberCap` encodes and
  decodes flawlessly.
- **One table that used to be control flow.** `ArenaCatalog.leagueKey` was a `switch`, so the
  table could not be read off the catalog; it had to be hand-typed into `arena.json`. That
  translation was proven rather than trusted: the exporter replayed the shipped switch against
  the new table over honor **−500…3000** and refused to write a single file on the first
  mismatch. Wider than the digest's 0…2000 on purpose — `case ..<1000` also swallowed negative
  Honor, so the table's `?? first` fallback had to be shown to swallow them identically.

Two subtleties that would have been silent behaviour changes:

- `all.first { $0.itemId == … }` returns the FIRST match, so the replacement dictionaries use
  `uniquingKeysWith: { first, _ in first }`. The reflexive `{ _, last in last }` would quietly
  change which row a duplicated id resolves to.
- The three scalar files have no array whose emptiness could mean "this fixture omitted the
  file", and a zero `maxActiveLots` has to stay a validation ERROR rather than double as an
  absence marker. So `ContentBundle` holds all five as **optionals** and `DomainContent` throws
  `ContentMappingError.incompleteBundle` on a nil, rather than booting a game whose guild cap is
  silently zero.

`GuildRole` deliberately did NOT move: it is a raw value persisted in `User.guildRole` plus
authorization predicates — code the DB schema depends on, not content a balance pass edits.

**28 new validator rules, every one negative-tested against a perturbed bundle** (16 during the build, the remaining 12 during the audit pass — the count was first written down as 18, which was wrong). The one worth
naming is `trader.arbitrage`: the shipped catalog held `sell ≤ buy` by convention alone, and a
single-digit typo would have opened an unbounded silver faucet. It is compared per unit by
cross-multiplication so unequal packet sizes stay exact. Also new: `arena.sweep_slower_than_turn`
(warning — the sweeper is what enforces `turnSeconds`, so scanning less often than the deadline
it polices makes the clock stop meaning anything), league table non-empty / strictly ascending /
no gap above the rating floor, guild officer headroom and name bounds, and league keys required in
both locales — the only locale keys the content data names outright rather than deriving from an
id.

**Digest coverage re-proven non-vacuous per file**, since a checker that has never failed proves
nothing: perturbing `guild.memberCap`, an arena league boundary, `tithePercent`, trader row order,
a tavern wager tier and `market.listingFee` each moved the digest to a distinct value. The league
boundary is the interesting one — bands are never fingerprinted as records, so only the
`leagueKey` accessor replay could have caught it.

`ContentExporter` is empty again for the fourth time, same reason as always. Its header now
carries the replay-before-flip recipe, because batch C needs it: `PlotCatalog` and `QuestCatalog`
are also behaviour-in-code rather than arrays.

### Phase 3 Batch C — master / plots / fortune / quests *(2026-08-29)*
The last four catalogs moved to `content/data/`. **Phase 3 is closed: all 12 catalogs read JSON,
no Swift array remains.** 85 tests green (was 62). 172 lines removed from the four catalogs
(49 of them data literals), net −78 after the façade code; 403 lines of JSON.

**Step 1 was real work this time.** Batch B inherited its digest coverage; batch C had none, so
the digest gained a `records` extension (22 cards × 14 effect fields, 9 jobs, 4 plot tunings, the
Master ladder and its accessor replays) **plus a third half, `quests`** — a seeded replay of
`daily()` over 200 users × 4 days × 3 NPCs. New baseline `8053216102eceff7`
(`records 04cbf2b5331ea85b` · `spawns 635cde3f65184c78` · `quests 2e52ecdfa45276ec`), captured
while the catalogs were still Swift-backed and **identical after the flip**.

Six negative tests before writing a line of DTO, each moving exactly the intended half:

| perturbation | records | quests |
|---|---|---|
| reorder two jobs in the trader pool | moved | moved |
| **drop the day from the `daily()` hash key** | **byte-identical** | **moved alone** |
| `icon(.mine)` ⛏→🪓 (a switch with no backing array) | moved | — |
| `repairCost` coefficient 0.5→0.6 (a formula) | moved | — |
| card `9_hermit` xpMultiplier 1.35→1.36 | moved | — |
| `enchantPerLevelPoints` [..2,3]→[..2,4] | moved | — |

Row 2 is the one that justifies the third half: `daily` is
`pool[stableHash("<uuid>:<npc>:<day>") % pool.count]`, so pool ORDER is the assignment. A
reordered pool hands every player a different job while leaving all nine record fingerprints
untouched.

**Two hand-translations, both proven before a byte was written.** `repairCostFraction` is the 0.5
lifted out of `MasterCatalog.repairCost`; extracting a constant from a formula is a translation,
so the exporter recomputed the whole formula from the extracted value across 6 items × missing
−5…120 — including the `?? 30` fallback, the `missing <= 0` short-circuit and the `max(1, …)`
floor that a naive re-derivation drops. And the exported pool order was replayed against
`daily()` over 200 seeded users × 4 days × 3 NPCs, with the exporter refusing to write on the
first mismatch.

**The sharpest edge in the batch was a `private static let`.** `FortuneCatalog.lookup` was
`Dictionary(uniqueKeysWithValues: all.map …)` — harmless while `all` was also a `static let`, and
a guaranteed trap the instant `all` reads the snapshot, because it would run at type-init before
`ContentBootstrap.load`. It was deleted, not moved; the dictionary lives in `DomainContent`.
The lesson for next time: grep for `static let` INSIDE the catalog, not only at its call sites.

Three more shape lessons:
- **Absence is a value.** `tuning(for: .trainingGround)` returning nil is how the estate
  controller opens a training fight instead of a harvest, so the DTO models it as an absent key
  and the fingerprint compares `<none>` explicitly.
- **A no-op default is per-field.** `FortuneEffect` omits 0 for bonuses but **1.0** for
  multipliers; one "skip falsy" rule would have written nothing for a 1.0 and decoded a card that
  zeroes the stat it scales.
- **Never iterate a catalog's Dictionary for a digest or an export.** `pools` and `t1Tunings`
  hash in an arbitrary per-process order; both had to be walked via `allCases`.

Staying in Swift on purpose: `PlotType` (persisted in `Plot.plotType`), `QuestNPC` (callback
token + locale infix), `QuestCounter` (names the four hook sites), `stableHash`, and
`weaponRepairCost` — `max(0, missing)` has no magic number to lift, and inventing a ×1 rate would
mean writing new logic during a migration. User chose "explicit magic numbers only" and
"`testMode` verbatim into `plots.json`" when asked.

**28 new validator rules, every one negative-tested.** The ones worth naming:
`master.points_short` (`enchantBonusPoints` does `prefix(min(level, count))`, so a short table
silently stops granting at the top while the UI still advertises the cap),
`master.levels_not_contiguous` (`enchantStep` looks up by level, so a gap strands the player one
short), `plot.type_missing` (a `PlotType` the file forgets is a DB row the game can load but not
describe), `fortune.unsafe_id` (the id is also a PNG filename under `Assets/`),
`fortune.half_wheel` (the wheel fires only when both sides are set, so setting one alone is an
effect that never happens), and cross-pool quest id uniqueness (`find` is a global lookup).
Plus derived locale keys for all four files — plot names/descs, the three keys per card, quest
titles/descs and board titles.

Independently cross-checked by parsing the pre-flip Swift out of git: all 4 armor rows, 5 enchant
steps, the extracted 0.5, `testMode`, all 5 icons parsed out of the `switch`, every tuning
including the mine's bonus output, `training_ground`'s absent tuning, all 22 cards with ids +
order + every set effect field, and all 3 quest pools with order, objectives and rewards.

**`ContentExporter` deleted** with the `--export-content` branch — Phase 3 is over and it had
nothing left to export. `ContentDigest` stays: it is the "confirm only the intended change" step
of the add-content workflow, not a migration leftover.

### Documentation + dead-code audit pass (same session)
Triggered by the audit-and-commit prompt after 3C landed. Three real findings, all mine:

- **187 lines of dead code.** Deleting `ContentExporter` orphaned the entire domain → DTO half of
  `ContentMapping` — 21 initialisers whose only caller was the exporter's byte-stability proof.
  Confirmed by grep (zero uses anywhere in `Swift/` outside the file itself) and by rebuilding:
  85 tests and the digest unchanged. File went 501 → 314 lines. The header now records why the
  direction existed and where to recover it.
- **`GameData` is a write-only holder.** `install` is called at boot; `GameData.current` is read
  nowhere, and the comment claiming the validator and a `/content` command read it was wrong on
  both counts — the validator runs on the `ContentBundle` before either snapshot exists, and
  there is no `/content` command. KEPT deliberately (installing both snapshots from one bundle is
  what stops them drifting, and Phase 7's hot reload is its first real reader), but the comment
  now says so instead of implying live readers.
- **Stale phase status.** `.memory/status.md` still read "Phase 3 IN PROGRESS (3 of 12)" with the
  superseded `9242a2c1501994ed` baseline.

Also corrected: the `ContentDigest` header still said "Two halves" after batch C added a third;
`ContentBootstrap`'s header still described its own wiring as future Phase 2 work; the file-map
entry for `ContentMapping` still called it bidirectional and Item/Enemy/Recipe-only.

**`Prompt.md` reoriented for a cold start on Phase 4.** The migration-loop section was replaced
with a "how content works now" summary (the loop itself lives in `content-pipeline.md`), and the
Phase 4 recon was written down as a table: **three `testMode` flags drive FIVE sites**, and they
do not share a ratio — `PlotProductionService`'s sweep is 60↔300 (**5×**) while the other four
are 60×, plus `EstateController:637` switches a locale key off the same boolean. A naive
`timeScale = 60` would speed the plot sweeper up 12× beyond current behaviour.

Language audit: every `.md` and `.memory/` file greps clean of Ukrainian PROSE — the remaining
Cyrillic is all quoted game copy (technique names, button labels, the UA glossary,
`content/lore.md`), which is the intended distinction. New auto-memory `feedback-docs-in-english`
records the rule; `project-rebalance-active` updated to say the content migration is finished and
the maths rebuild is what remains.

### Next
**Phase 4 — tuning tables + collapsing the three `testMode` flags into one `time.scale`** (its own
commit). Start from the five-site table in `Prompt.md`; the 5× sweeper is the trap.
Two smaller decisions to make first: `manifest.json` still reads `contentVersion: "phase1-export"`
(stale by three phases), and `schemaVersion` has never moved despite the bundle gaining nine
required files since v1.
User asked to confirm the start of each phase before it begins.

---

## Session — 2026-08-30 (Phase 4 — tuning tables + `time.scale`)

Phase 3 closed last session with all 12 catalogs on JSON. This session moved the
**balance numbers** — the constants the formulas consume, as opposed to the
rosters the player scrolls through. Two steps, two commits' worth of work.

### 4a — six tuning tables

`content/data/tuning/{combat,vigor,exploration,progression,economy,time}.json`.
~80 constants out of `CombatService`, `VigorService`, `HealingService`,
`ExplorationService`, `User`, `CharacterClass`, `WarehouseService`,
`GearConditionService`, `TravelService`, `PassiveExpeditionService`,
`PlotProductionService`, `TradeStore`, `TavernCleanupService` and `GameDay`.

**The digest gained a FOURTH half.** `tuning` is deliberately separate from
`records`: keeping the three catalog halves at their Phase 3 values is what turns
"Phase 4 touched only balance" from an assertion into an observation. It held —
`tuning a8b3c0fa99f86e3c` identical across the flip, catalogs byte-identical.
Negative-tested five ways, each moving `tuning` to a distinct value while the
catalog halves held: a plain scalar (`baseHitChance`), a stance modifier
reachable ONLY through an accessor replay (no backing array at all), a `Set<Int>`
member (`statGrowthLevels` — hashed sorted, since a Set iterates in
seeded-hash order), a bare-tier weight, and a `realTime` constant.

**Extracted the switch before the flip, not during it.** Batch B had to
hand-translate `ArenaCatalog.leagueKey` and prove it afterwards.
`ExplorationService`'s weight tiers were lifted into `weights(forPriorVisits:)`
while still Swift-backed, so the baseline was captured *through the accessor* and
the flip itself was a plain no-op. Cheaper and strictly safer — worth reaching
for whenever control flow is about to become a table. Its lookup had to be
**"exact match, otherwise the LAST row"**: the shipped `default:` arm swallowed
NEGATIVE visit counts, and a "greatest row at or below the query" lookup would
have handed them the fresh-room weights and quietly made re-entered rooms
generous. Replaying −2…5 is what surfaced that.

**No exporter.** It died with Phase 3, so the six files were hand-written. Safe
only because step 1 had already put every constant under the digest, so a
transcription typo could not survive step 5. Written down in
`content-pipeline.md` so the shortcut is not mistaken for the rule.

**48 validator rules, every one negative-tested.** The load-bearing ones guard
values read straight into an operation that TRAPS: an inverted `variance`
(`ClosedRange`), a non-positive `eventWeightTotal` (`Int.random`), an empty
warehouse table (subscript), a zero `maxDurabilityStart` (`MasterCatalog
.repairCost` divides by it). Plus a contiguous revisit-tier run, weights that
must sum to the total, a starter weapon that must resolve AND be main-hand, an
unknown time zone (`GameDay` falls back to UTC and moves every daily reset with
no error at all), and Telegram's 24 h delete floor.

Two warnings now fire truthfully — the audit's `flee (5) > defeat (3)` gear-wear
inversion, and the time scale. Keeping a known problem live in the tool beats
keeping it in prose.

### 4b — `testMode` → `time.scale`

The three booleans and `manifest.timeScale` are gone; `tuning/time.json` →
`scale` is the only knob, `schemaVersion` bumped to 2. **All four digest halves
identical across the collapse.**

The flags were never one scale — `PlotProductionService`'s sweep was 5× while
the other four were 60× — so the sweeper became **derived**: `max(minSeconds,
plotInterval / divisor)`. It is a DB polling cadence, not a game-time gate, so
scaling it would make database load a function of game balance; deriving it from
the interval makes "never slower than what it sweeps" hold by construction.

**Calibrating the derivation to reproduce BOTH existing values cost nothing.**
The first draft used a 30 s floor, which would have moved the dev cadence 60 → 30
and made 4b a behaviour change. A 60 s floor reproduces production
(3600/12 = 300) and test mode (floored to 60) exactly, so the collapse stayed a
verified no-op. Worth reaching for: a derivation calibrated against the values it
replaces is free to adopt.

**A hash cannot see a value the shipped configuration masks.** `intervalDivisor`
is invisible to the digest at `scale = 60` — the floor swallows every sane
divisor, and the hash is identical for 12 and for 6. Covered instead by a
two-point equivalence check printed on every digest run, which fails loudly
(`interval 3600s derives 600s, shipped value was 300s`). When a derivation has a
clamp, check the unclamped branch somewhere the hash is not looking.

`time.json` splits `gameTime` from `realTime`, and the split is load-bearing:
Telegram's 24 h dice-delete window is a PROTOCOL constant, so scaling it would
not rebalance the tavern — every delete would fail and the rows would never
clear. `EstateController`'s `/hr` vs `/min` label now reads the interval instead
of the deleted boolean.

Left at **`scale: 60`** on purpose. Phase 11 flips it to 1.0 as a one-number
change — which is exactly the property 4b was shaped to preserve.

130 tests green (was 85). Digest `893b57b06fad8068`.

### Next
**Phase 5 — the new combat model.** Mitigation instead of subtraction,
ratings→percent with denominators derived from the item budget curve,
`levelDiff`, hit floor 40, enemy archetypes generated at design time,
`maxLevel = 40` with proportional growth, technique rebuild off
`defenderDEFFraction = 0`. The numbers are already JSON; the FORMULAS are Swift,
so this is a rewrite of `CombatService` and `User`, not a retune.
Phase 5 also inherits the `pickFor` km ≥ 36 fallback and the foraging pools still
hardcoded in `rollLoot` — both belong to `zones.json`.
User asked to confirm the start of each phase before it begins.

---

## Session — 2026-08-30 part 2 (Phase 5 — the new combat model)

The first phase that changes BEHAVIOUR rather than relocating it. Four steps,
reordered mid-flight for a data dependency the plan's numbering hid.

### The reorder, and why

The plan's order was combat model → progression. But the enemy generator balances
monsters against the player's growth curve, so enemies written before the new
growth lands are fought by players who do not have it: a level-21 warrior meets
the regenerated wild bear and loses **137% of max HP**. Reversed, every
intermediate commit stays playable — new growth against old enemies is merely
easy. **Order phases by data dependency, not by the plan's numbering.**

### 5A — bestiary data

Six-archetype table in `enemies.json`; `Enemy` gains level, archetype, crit,
dodge, accuracy, silver, spawn weight. `pickFor` weighted, and the `?? all.first`
tail deleted: it answered any uncovered km with the FIRST enemy in the file, so
everything past km 35 was a wild boar — the deepest content in the game was also
its easiest. `rollEncounter` already handled nil, so the call site had been
written for the honest answer all along.

The schema handshake caught my own omission here (bumped `ContentSchema` and
forgot `manifest.json`). The mechanism that looked decorative last session
earned itself in one shot.

### 5B — progression

Proportional growth replaces +5/+1/+1 on eight chosen levels. Under flat growth a
warrior's dodge RATING rises while its PERCENT falls 5.3% → 1.4%, because the
diminishing-returns denominator grows with level and a flat rating cannot keep
up. `applyLevelDerivedStats` recomputes from (class, level) rather than
accumulating, which makes it idempotent — a missed or doubled grant self-heals —
and lets one startup backfill move old rows over.

Vigor regeneration did not exist at all before this. It is deliberately NOT
suspended during an expedition, unlike HP regen: stamina is spent on the trail,
so a trickle there is the mechanic rather than a leak.

### 5C — combat model

Absorption, rating curves, `levelDiff`, hit floor 40, `maxLevel` 40, the XP pair.

**Adding a parameter beat any grep.** Threading levels through `applyAttack` made
the compiler enumerate all nine call sites, two of which were `chipDamage` calls
that no search for `applyAttack` would have found.

**Two curve shapes needed two TYPES.** In `min(0.70, DEF/(DEF+K))` the 0.70 is a
CEILING; in `55·D/(D+K)` the 55 is a leading SCALE. I inverted one as the other
in the generator, inflating every enemy's DEF by ~80% and stretching fights far
past their target length. It was caught only because the user asked to see the
table before it was written — which is the case for showing generated data
before committing it. `MitigationCurveDTO` and `RatingCurveDTO` are now separate
types so the compiler refuses the confusion.

### 5D — techniques, flee, weights, passive, silver

All three special attacks set `defenderDEFFraction = 0`. Under subtraction that
was +50% damage; under absorption the gain is `1/(1−mitigation) − 1` — +11%
against trash for +150% Vigor, i.e. strictly worse than attacking twice, and
worst exactly where a trump card was wanted. Rebuilt onto effects whose value
does not shrink with absorption: armour break (worth MORE against armour),
guaranteed crit at ×2.0, and a burn that absorption cannot touch.

Burn ticks in `finishRound`, the shared round end — a fire that only advanced
when the mage cast again would not be a damage-over-time effect. Its damage is
frozen at cast time so a stance expiring mid-burn cannot retroactively weaken it.

`WearEvent.flee` 5 → 2 (fleeing had cost more than dying), event weights →
5/45/40/10, passive expeditions charge full Vigor and pay 70% XP / 70% silver /
100% materials (they had measured 53% MORE efficient than active play), and
monsters drop silver for the first time.

### What the audit found

**A hash only covers what it reads.** The technique rebuild moved the payload out
of `AttackModifiers` into a separate effect union the controller reads directly —
so the digest kept hashing the modifiers and stopped seeing the technique.
Doubling a burn's duration left it byte-identical. `passive`, `fullRegenHours`,
`mobXP` and `critMultiplierOverride` had all fallen out the same way. All six now
move it to distinct values. **Whenever a value moves to a new home, re-check that
the digest followed it.**

Independent cross-check: 40 enemy stats, XP and silver values re-derived from the
shipped archetype table and curves, all matching; total XP to the cap comes out
at **19,437,688** against the plan's stated 19,437,688.

### What Phase 5 could NOT verify

The design's reference character carries gear from an item budget curve that
arrives in Phase 6 and items that arrive in Phase 10 — its level-40 warrior shows
DEF 225 where the bare stat line gives 52. So the acceptance check proves the
FORMULA (published stats in → published percentages out) and says nothing about
BALANCE. Worth keeping separate before a green check gets read as "the numbers
are right".

155 tests. Digest `84b3316f44bd18c7`.

### Next
**Phase 6 — rarity and sets**, which is also what makes the balance checkable.
Still no live Telegram pass since the rebalance began, and every formula the
player touches changed here.

---

## Session — 2026-08-30 part 3 (Phase 6 — rarity, sets and the item stat budget)

The phase that makes balance checkable. Phase 5 could only prove that published
stats produce published percentages; it could say nothing about where the stats
come from, because the design's reference warrior carries DEF 225 where the bare
stat line gives 52.

### The budget

`budget(itemLevel, slot, rarity) = slotWeight · (6.0 + 1.5·itemLevel) · rarityBudget`,
with every stat an item carries being that budget SPENT at fixed exchange rates.
One number bounds a piece; because the combat denominators were derived from the
same curve, an item that respects its budget cannot move any stat's percentage.

`itemLevel` is deliberately NOT `tier`: tier is a crafting-ladder rung (1–5),
item level is the budget input (1–40). The ladders map tiers to 1/10/20/30/40,
because five rungs cover forty levels.

**Regenerating the 7 shipped items and 3 ladders dissolved the T5 asymmetry** the
plan had documented: the three top weapons now carry 198.4 / 198.5 / 198.6
points — a 0.1% spread where the warrior's had been ~15% heavier for no stated
reason.

### The acceptance check

`--content-digest` now rebuilds the design's reference character from the budget
through the class profiles. **DEF and absorption reproduce the published table
exactly** for all three classes; ATK exactly for warrior and mage. The residual
4–10% HP shortfall is not drift — it is the two accessory slots, 1.0 of slot
weight nobody has spent. Printing the gap turned "the empty slots are cheap
content" into a number.

### Decisions worth keeping

- **Decouple price from power.** Rarity multiplies budget ×1.45 at the top and
  value ×16. Tying them (the drafted 1/2.2/5/14/40) makes selling a legendary
  the biggest silver faucet in the game against an unlimited vendor.
- **Enchant is a percentage of the item's own budget.** No flat number works:
  +32 DEF is 267% of a level-1 chest and 14% of a level-40 one. Scaling the item
  also keeps its profile intact instead of bending every piece toward the
  wearer's class — the class-identity flavour moves to sets.
- **The overspend rule carries an ABSOLUTE rounding slack.** Rounding a stat can
  only add half a point of it, so the error is a fixed number of points; a
  percentage tolerance is far too tight at level 1 and far too loose at 40. It
  is doing real work: a level-1 helmet legitimately sits at 124% of a 7.5-point
  budget, entirely inside the slack four rounded stats can produce.
- **Gear needed an HP stat** (sixth cached bonus + migration). Without it the
  class armour profiles cannot be expressed at all — cloth spends 0.26 of its
  allowance on bulk — and faking it as DEF puts it on a different curve.

### What the audit caught

- **Four values had no digest coverage**: the class budget profiles and the stat
  exchange rates — both invisible, so doubling "one point buys 0.42 attack"
  would have doubled every generated weapon without moving a hash — plus the
  ladder rungs' item levels and `critMultiplierOverride`. Hashing the reference
  KIT covers the first two through the same call the printed check uses, so the
  two can never disagree. This is the second phase running where the audit's
  main find was digest coverage following a value to its new home.
- **The validator caught the author.** The first Forester set bonus I wrote was
  33% of its members' combined budget against a 25% cap. A rule that only ever
  fires on hypothetical bad content is not yet known to work.
- **A round-trip test found a real bug**: `GearStatsDTO.encode` skips zero
  values field by field and the new `hp` was never added to it, so an HP stat
  survived in memory and vanished through JSON. Exactly the Phase 1 layer-0
  failure, one field later, caught the same way.
- Three stale doc comments and three pieces of dead API removed; the rarity
  glyph was wired into the inventory, because rarity nobody can see is not a
  feature.

176 tests. Digest `f3b145f824ec150c`.

### Next
**Phase 7 — `/reload` hot swap + `LiveReferenceCheck`**, deliberately after the
full data move so there is something worth reloading. Still no live Telegram
pass since the rebalance began: every formula changed in Phase 5 and every
item's stats in Phase 6.

---

## Session — 2026-08-30 part 4 (Phase 7 — hot reload)

`/reload` and `/content` in `GlobalCommandsController`, gated on
`developerUsers`, plus the check that makes a hot swap safe at all.

### The order is the design

**parse → validate → live-check → build → install.** Everything that can fail
happens before anything is touched, and `install` is a reference store that
cannot fail. A refused reload therefore leaves the running game on exactly the
snapshot it was already serving — which is what makes this safe to run against a
bot with players mid-expedition. Nothing else about the feature matters as much.

### LiveReferenceCheck

Every other check in the pipeline asks whether a bundle is internally
consistent. This one asks whether it is consistent with the game already in
progress: drop `mat.iron` from `items.json` while four players are carrying it
and every one of their inventory rows becomes an item the game cannot name,
price, equip or sell.

**The design listed six columns; the schema has ten.** The four it missed all
fail SILENTLY, which is why they were easy to overlook and why they matter:
`learned_recipes.recipe_id` (a workshop row that renders nothing),
`exploration_state.combat_stance` (the player's Super does nothing),
`quest_progress.quest_id` (a job in progress cannot be rendered),
`users.active_fortune_card_id` (a buff they paid for evaporates). Re-derive such
a list from the schema; do not trust the plan's copy of it.

Deliberately NOT a stat check — drift under a live fight is allowed and clamped
at rehydration. It is IDENTITY that must not move.

### Split for testability

The matching lives in `ROIContent` (Foundation-only) and the queries in the main
target, which has no test host. The failure worth catching is a CATEGORY error:
item ids checked against the bestiary would report every row as dangling, or
none, and either way the rule would look like it was working. That is now a test
and it needs no database.

The database half remains untested — it needs a live run.

### Deliberately not reloaded

**Lingo.** `AppState.lingo` is a `let` captured by every controller, so new
locale strings still need a restart; `/reload` says so in its own output,
because "I reloaded and my new string is still missing" is the obvious first
confusion. Armed timers carry their deadline in the database, so a changed
duration never retroactively moves a trip already in flight.

The boot path runs the same check as a WARNING once the database is up. It
cannot refuse there: content loads before the DB block (the dev seed reads
catalogs), so by the time rows are reachable the snapshot is installed and half
of boot has read from it.

185 tests. Digest unchanged at `f3b145f824ec150c` — Phase 7 added machinery, not
content.

### Next
**Phase 8 — `CombatantStats` + the simulator.** Thread `RandomNumberGenerator`
through the combat services, add `roi-content simulate`, and lock the constants
against **p90 rather than the mean**. Still no live Telegram pass since the
rebalance began — and `/reload` itself is now among the things only a live run
can exercise.

**Phase 7 audit found two things.** First, `/reload` echoes validator output
into an HTML message and two rules legitimately contain `<=` — unescaped,
Telegram rejects the message, so the one path whose job is explaining a refusal
would have delivered nothing. Fixed with an escape helper, and the reasoning is
in the code: validator output is arbitrary developer prose, not curated locale
copy. Second, walking every `@Field` in `Swift/Models` rather than trusting the
design's list turned up four more content-id columns than the plan named; three
more (`quest_progress.npc`, `technique_id`, `character_class`) are covered
transitively or by `DomainContent` refusing an incomplete bundle, and that
reasoning is now written down in `LiveReferenceQuery` so nobody re-derives it.

---

## Session — 2026-08-30 part 5 (documentation sync + dead-code sweep)

A pass with no feature work: bring every document back in line with Phases 4–7
and remove what those phases orphaned.

### The gap that mattered

`.memory/file-map.md` is described in `CLAUDE.md` as canonical and updated per
session. It contained **none of the thirteen files added across Phases 4–7**, and
its `User.swift` annotation still described the pre-rebalance model — `maxLevel
= 21`, flat stat growth on eight chosen levels, "maxVigor stays 100 always (no
growth — per design)". A map that confidently describes a model the code no
longer has is worse than a map with a hole in it.

Fixed by adding the thirteen files with the reasoning that makes each one
non-obvious (why burn damage is frozen at cast time, why the vigor tick primes
rather than pays, why `LiveReferenceCheck` is split from its queries) and by
marking the superseded `User.swift` block explicitly rather than deleting it —
the history is still worth reading, it just needed to stop claiming to be
current.

The `Previously:` blocks in `status.md` are frozen snapshots BY DESIGN and were
left alone; `status.md` gained a live rebalance phase table above them instead.

### Dead code

`AttackModifiers.defenderDEFFraction` — Phase 5D rebuilt all three special
attacks off "ignore armour", which left the knob with no user at all, still
multiplied into every damage roll and still documented as scaling DEF "before
subtraction", which absorption removed two phases earlier. Deleted: nothing set
it, armour-piercing has a real home in `armourBreak`, and a live knob with a
lying comment is worse than no knob. Its digest entry went with it — `tuning`
moved to `ae10c071662462d6`, which is the whole change.

Also checked and clean: `enchantBonusPoints`, `statGrowthLevels`,
`ItemBudget.spent`, `RarityCatalog.glyph`, `plotTestMode`, `PlotCatalog.testMode`
— all removed at the time, none lingering.

### Documents brought current

- **`CLAUDE.md`** — the item stat budget and its two consequences (`itemLevel` is
  not `tier`; never give anything a flat bonus), and the `/reload` contract
  including the rule that a new content-id column must be added to
  `LiveReferenceQuery` or the hot swap will break it.
- **`README.md`** — untouched through four phases. Now carries `tuning/`, the
  rarity and set files, the balance-is-data note, the `/reload` line, and a
  roadmap that says the rebalance is in flight.
- **`GDD.md`** — a header warning that it predates the rebalance and its numbers
  are intent, not behaviour. It was already treated that way in conversation;
  now the document says so itself.
- **`.memory/INDEX.md`** — descriptions widened to match what the files grew
  into.
- Locale counts corrected to 957 / 978 in both `status.md` and `Prompt.md`.

185 tests, clean build. Digest `a4d825a8d728f4f8`.

---

## Session — 2026-08-30 part 6 (Phase 8A + 8B: the math moves, the simulator lands)

### 8A — one implementation, proven inert

`CombatantStats`, `CombatMath`, `ProgressionMath` and `BudgetMath` are new files in
`ROISim`; `CombatService`, `User`, `ItemBudget` and `VigorService` kept every public
signature and became façades over them. `StanceModifiers` and
`specialAttackModifiers` went down too — a technique the simulator models
differently is the same bug wearing a hat.

The proof is the digest. `a4d825a8d728f4f8` held across the whole move, and its
`tuning` half already replays `baseStats` over 3 classes × 6 levels,
`xpRequiredToReach` over 0…45 and all four curves — so this is bit-level equality,
not a smell test. Only `applyAttack`'s three random draws sit outside that net, and
they moved verbatim (order preserved: hit → variance → crit).

`EquipmentSlot` moved from `Swift/Models/Item.swift` to `ROIContent/Vocabulary.swift`.
It had been written out three times — the enum plus two string-literal lists inside
`ContentValidator` — and `BudgetMath` needed a fourth. A slot id appears in
`items.json` AND `tuning/budget.json`, so it is content vocabulary; the validator now
reads the enum.

### 8B — `roi-content simulate`

- **`EnemyGenerator`** is the discovery of the session: `enemies.json`'s archetype
  table is a GENERATOR, and inverting it reproduces every shipped enemy's DEF, crit
  and dodge to within rounding (`rabid_bear` wants 82.36 / 56.66 / 23.04 and carries
  82 / 57 / 23). Pinned by test against literal numbers.
- **`FightSimulator`** copies the round order out of `CombatController.finishRound`,
  including that Super activation is a FREE action — the controller stamps the stance
  and returns without calling `finishRound`, so the enemy gets no counter for it.
- Bands: level invariance on MEANS and two-sided (ratio AND points — p90 on integer
  HP reports quantisation as drift, which failed three rows on the first cut); the
  tail on p90; the plan's ±7% class band moved onto days-to-cap, a number the design
  actually stated, with the invented "power index" printed but never banded.

### What it says

**Level invariance holds on 18 of 18 rows** — mean HP loss spans ×1.01–×1.16 from
level 1 to 40. That is the claim the entire rebalance rests on, and it is now
measured rather than asserted. The plan's one flagged cell reproduced as well (mage
vs elite at low level: p90 90% HP, 95% wins), which is good evidence the simulator
measures the real thing.

Two findings for 8C, plus one gap:
- **classes are 17% apart** on days-to-cap: identical relative HP cost per fight, but
  warrior 4.1 rounds / 17.8 vigor per kill against mage 3.1 / 15.0 → 59 perfect days
  against 50. The warrior's armour is spent entirely equalising damage taken and buys
  no speed back, so the tank/glass-cannon trade does not exist in the numbers.
- **the shipped bestiary is half-strength against its own contract** — 64% of asked
  HP/ATK at level 1 falling to 50% by level 25. Every roster enemy is a 100% win at
  4–13% HP where the archetype asks 10–62%. Phase 10 regenerates it.
- **two of the three Supers grant flat bonuses** — the rule Phase 6 wrote for items,
  never applied to the stance table. `hawks_eye` lifts archer crit 115% at level 1 and
  21% at the cap; `bloodlust` lifts warrior attack 29% → 5% and doubles the Vigor cost
  of every action while it holds. Only the mage's ×1.5 holds its worth, which is exactly
  why techniques save the mage 30% of a fight and the warrior 5%.
- **`silverReward` has no curve anywhere.** The roster fits ≈1.7·L^1.09·silverMultiplier
  but nothing states it, so Phase 10 has nothing to generate from and the daily-silver
  check has no model. Wants an `economy.mobSilver` block.

193 tests, clean build, digest unmoved, `simulate --strict` exits 0 with 0 broken
bands and 8 warnings.

---

## Session — 2026-08-30 part 7 (Phase 8C: acting on what the simulator said)

Three decisions, taken by the user off the 8B report, and all three measured
before and after.

### Stances became multipliers (schema v8)

The audit that found this is the session's best moment: Phase 6 banned flat
bonuses on ITEMS — the same +5 is a third of a level-1 stat line and a twentieth
of a level-40 one — and nobody had ever pointed that rule at the stance table.
Two of the three Supers were flat. `hawks_eye` lifted an archer's crit **115% at
level 1 and 21% at the cap**; `bloodlust` lifted attack 29% → 5% *while charging
double Vigor for every action*. Only the mage's ×1.5 held, which is the entire
reason techniques used to save the mage 30% of a fight and the warrior 5%.

`StanceTuningDTO`'s five `*Bonus: Int` fields are gone, replaced by
`*Multiplier: Double`, all REQUIRED on decode — a defaulted 1.0 would read as
"this stance does nothing to that stat", which is the silent drift the tuning
tables exist to prevent. Shipped: bloodlust attack ×1.35 / defence ×1.15 / vigor
×1.5, hawks_eye crit ×1.60 / accuracy ×1.15 / dodge ×1.15, arcane_resonance
attack ×1.50 / defence ×1.15. The warrior's techniques now save 13–21% of a
fight instead of 5%.

The audit did not go away with the fix — it now checks the two flat rating
bonuses left standing beside the stances, and reports them every run:
`shadowVeilDodgeBonus` +50 is **238%** of a level-1 archer's dodge and 34% at the
cap; `defend.archerDodgeBonus` +30 is 143% → 20%. Same defect, not yet asked
about.

### The warrior's budget was re-spent

Weapon attack 0.72 → 0.80 (accuracy 0.14 → 0.06 — it was overshooting the 95% hit
cap by level 40 anyway), armour defence 0.82 → 0.78 into HP, base attack 10 → 12.
**Days-to-cap spread fell 17% → 9%**, inside the plan's ±7%-of-the-mean band.

Worth more than the number: the trade the design always claimed now exists. The
warrior loses 50–53% of a bar to an elite where the mage loses 65%, at 10% slower
pace rather than 18%. Before the change all three classes lost the SAME fraction
of HP per fight and the warrior was simply slower — their entire defensive
investment bought nothing measurable.

`--content-digest`'s reference-character row for the warrior was **rebased** to
653 / 126.0 / 217 / 37.1%, with the archer and mage rows deliberately left alone
so the check keeps its teeth: it still catches an accidental drift, and the two
untouched rows prove it can.

### Monster silver is gone

`enemies.silverReward`, `archetypes.silverMultiplier`,
`exploration.passive.silverMultiplier`, both award sites
(`CombatController.finishVictory`, `PassiveExpeditionService`), the running-report
and checkpoint fields, the validator's two rules and its test, and both locale
lines. Every silver faucet left is a player-facing system with a sink attached —
quests, trader, tavern, market, arena. It also closes the "`silverReward` has no
curve anywhere" gap by deleting the thing that needed one.

### Verification

**18 of 18 level-invariance rows pass; 0 broken bands.** New baseline
`583a32cb5a9d9dc7` (schema v8): `records` and `tuning` moved, **`spawns` and
`quests` did not** — no selection logic or daily assignment was touched, and the
split says so rather than asking to be believed. 192 tests (the negative-silver
rule went with its mechanic), clean build, `validate` clean but for the known
`time.scale 60` warning.

Left reported and open: the two flat dodge bonuses, the mage's 93% win rate
against an elite at level 5 (the plan's fix is a spawn-level floor, which is
content), and the bestiary carrying ~50% of what its archetypes ask (Phase 10 —
`EnemyGenerator` now exists to regenerate it).

### Follow-up — the failed-flee counter (same session)

The commit audit caught one live bug that the simulator could not: the forced
counter after a failed Flee still ran `max(1, ATK − DEF/2)`. Phase 5C replaced
subtraction with absorption everywhere else and missed this one site, and
absorption is exactly what made it harmless — DEF values grew (a level-40 warrior
carries 217 where the subtractive model expected ~30), so half of it exceeded
every enemy's attack. The "forced full-damage hit" was dealing **1 HP to every
class at every level**, 0.2–1.0% of a bar. Fleeing cost Vigor and gear wear and
nothing else, which is why the 40/70/90% per-class success rates never mattered.

Fixed by routing it through `applyAttack` with `cannotMiss = true` and a crit
RATING of 0 — the spec's "guaranteed hit, no crit roll" expressed to the curve
rather than as a branch, and no new API. Cost now: 6.1% of a bar for a warrior,
8–9% for an archer or mage, 9–14% against an elite, **the same percentage at
every level**. About two rounds' worth of damage, which is what the comment
always claimed.

Two things worth remembering from how it was found. It was found by READING THE
DIFF, not by the simulator — `FightSimulator` has no flee policy because no
design document says when a player should run, and a tool only measures the
fights you tell it to have. And the digest did not move: the flee formula was
never fingerprinted, only `fleeChance` and `fleeVigorExtra` are. A hash proves
what it covers and nothing more.

### Documentation sweep + dead-code pass (same session, before the doc commit)

A pass with no feature work: verify the two Phase 8 commits, sync every document,
and remove what the phase orphaned.

**The JSON reformat that nearly shipped.** Editing `content/data/*.json` from
Python rewrote every line — the files are written by Swift's `JSONEncoder`
(`"key" : value`, WITH the space before the colon), and `json.dumps` emits
`"key": value`. The content diff was 905 lines for two dozen real changes.
Fixed by writing a formatter that reproduces the Swift style and **proving it
byte-identical against all six originals from HEAD** before re-emitting the
modified data — the only surprise was that an empty array is `[]`, not the
`[\n\n]` the pretty-printer uses for empty objects. Diff fell to 20 insertions /
39 deletions. The digest did not move (it hashes values, not bytes); only the
bundle's raw-byte content hash did, which is exactly the expected signature of a
whitespace-only change. The rule is now written down in `content-pipeline.md`
and `Prompt.md`.

**Dead code the phase left.** Six things, split by whether the fix was to delete
or to give them a reader:

- *Given readers, because the reader was worth having:* `ROISim.version` now
  stamps the report header beside the content hash — a report pasted into a
  design doc six months later has to say which MODEL produced it, not just which
  data; `ProgressionMath.totalXP` prints "19,437,688 XP from level 1 to 40",
  which is the plan's own headline number stated by the tool that measures it;
  `Distribution.p99` joins p90 on the worst-tail line, and immediately earned its
  place — the mage's level-5 elite reads `p90 94%, p99 100%`, so the tail p90
  calls survivable is a death one fight in a hundred.
- *Deleted, because they duplicated something already exposed:*
  `Distribution.min`/`.max`, `GeneratedEnemy.targetRounds`/`.targetHPLossPercent`
  (the roster check carries its own copies straight off the archetype row),
  `Finding.Severity.note` (never constructed), and
  `ReferenceCharacter.level`/`.itemLevel`/`.maxVigor` — three stored properties
  assigned in the initialiser and read by nobody.

**Stale records found and fixed.** `.memory/file-map.md` still described
`CombatService` as owning the maths and listed `defenderDEFFraction`, a knob
deleted two sessions ago; `Item.swift`'s entry still claimed `EquipmentSlot`.
`README.md` said the simulator "lands in Phase 8" and counted 185 tests.
`content-pipeline.md` said three live checks (there are four) and described
`ROISim` as SplitMix64 only. `INDEX.md` and `status.md` still said "3–7 done".

**One real contradiction.** The original audit list — quoted in `TODO.md` and in
the auto-memory — cited "monsters drop no silver" as a MISSING faucet. Phase 8C
settled it the opposite way and deleted the mechanic, so the sentence had become
an argument against the design. Annotated in both rather than deleted: the audit
is history and worth reading, it just had to stop reading as intent.

`Prompt.md` was reoriented to open at Phase 9 with the content gaps the simulator
already named, so a fresh session starts at the work rather than at a recap. A
new auto-memory records the closed direction: never propose monster coin drops
again.

---

## Session — 2026-08-31 (Phase 8D: the last flat lifts, the archetype floor, a noisy gate — and the vigor decision)

Opened on "where did we stop", which the tracker answered with "Phase 9". The
session went the other way on purpose: the user picked the code debts the 8B
report had been printing every run, and then reopened a design decision that is
bigger than all of them.

### The two flat lifts

`shadowVeilDodgeBonus` +50 and `defend.archerDodgeBonus` +30 were the last flat
rating bonuses in the game — the same defect Phase 6 removed from items and 8C
from the stances, in the two techniques sitting beside them.

**The values were chosen on the EFFECT, not on the rating.** The report had been
stating the rot as a share of the rating ("238% at L1, 34% at the cap"), which
says a lift is broken but not what to replace it with. Converting to points of
dodge chance made the answer fall out:

| | L1 | L10 | L20 | L40 |
|---|---|---|---|---|
| Shadow Veil +50 | +16.1 pp | +9.4 | +6.4 | +4.0 |
| Shadow Veil ×2.0 | +9.0 pp | +9.4 | +9.4 | +9.4 |
| Defend +30 | +11.6 pp | +6.3 | +4.2 | +2.5 |
| Defend ×1.5 | +5.3 pp | +5.5 | +5.5 | +5.6 |

A multiplier is nearly flat in percentage points because the rating and its
denominator move together — which is the property the derived denominators were
built for, now visible on a technique rather than on a stat line. ×2.0 and ×1.5
reproduce what the flat bonus was worth around level 10, i.e. the middle of its
own decay. Both are REQUIRED on decode (schema v9): a defaulted 1.0 reads as
"this technique does nothing".

The report now MEASURES both instead of trusting them, because "a multiplier
holds by construction" is only true if the denominator keeps pace, and the curve
is the only thing that can say so. The audit that convicted the flat bonuses kept
its place and changed its unit.

### The archetype floor

`minLevel` on every archetype row, elite and boss at 14. The plan specified the
floor and nothing enforced it; the shipped roster already complies (its one elite
is level 25), so this is a lock for Phase 10's generator rather than a fix today.

Two decisions inside it worth keeping:

- **No exception for the `0...0` sentinels.** They never spawn from the
  wilderness, but they are reachable through training and scripted hooks, and a
  rule with an "unless it is unreachable" clause is a rule nobody can check.
- **The floor made the report honest.** The sweep rolls every archetype at every
  level because that is what proves level invariance — but the tail band was
  raising findings on the mage's level-1 and level-5 elites, which the validator
  now refuses to let exist. Those cells are skipped, and the worst SHIPPABLE tail
  reads `mage L20 vs elite — p90 89% HP, p99 100%, win 96.2%`.

### The gate was failing on noise

`simulate --strict` exited 1 at HEAD, on a band nobody had broken. The
mage-vs-skirmisher level-invariance row reads ×1.16 at the default 2000 fights
per cell and ×1.13 at 8000 — from the same seed. The band is a ±15% ratio of two
MEANS, so the sampling error on a cell is wide enough to cross it alone.

Raised the default to 8000. The whole sweep costs 2.6s there against 0.7s at
2000, so the 2000 was buying nothing and costing a false alarm on the one gate
`CLAUDE.md` tells every session to run after touching combat tuning.

**Worth remembering: a threshold and a sample size are one decision.** The band
was chosen in 8B and the sample size defaulted in 8B, and neither was checked
against the other.

### How the change was proven confined

At equal sample size, every fight number in the report is byte-identical before
and after. `FightSimulator` models neither Defend nor Special Defence — a policy
question no design document answers — so the two techniques 8D changed are
exactly the two the simulator does not roll. The diff is the header, the lift
audit, and four warnings that went away.

The digest agrees: `records` moved (the archetype fingerprint gained the floor)
and `tuning` moved (the two multipliers); **`spawns` and `quests` did not**.
New baseline `dfe1ff8e24605e0d`, schema v9, 201 tests.

### The vigor decision (designed, not yet built)

Raised by the user against the "depth is not gated by player level" finding: it
does not need a level gate, because a low-level player cannot AFFORD the deep
forest — and the thing that breaks that is passive Vigor regeneration, which was
never wanted.

Reading the code made the case stronger than the intent. `VigorService.regenTick`
deliberately does not pause during an expedition, and the comment argues for it —
so a player can stand at km 25, wait six hours and refill. There is no depth gate
today; there is only patience. Returning is step-by-step rather than a teleport,
so without the trickle the pool plus the carried food IS the gate, symmetrically.

Checked before agreeing:

- **The estate can replace the clock.** At 3 harvests/day a 2-slot estate yields
  ~540 Vigor/day against the regen's 525 at level 1, and a 6-slot ~1620 against
  1500 at the cap. The offline loop survives; it just has to be tended.
- **There is no soft-lock.** At 0 Vigor a step costs 5% of max HP and ATK/DEF
  drop 25% — the player crawls home and forages. The stop already exists; regen
  is what has been hiding it.
- **The pace model dies with it.** "One pool plus 4× regen" is where 50–56 days
  to the cap came from, so the simulator's pace section has to measure food
  throughput instead.
- **The tap budget is the real risk.** 60 dishes a day at level 1 and 180 at the
  cap is more taps than combat, unless the kitchen learns to batch.

Recorded as Phase 8E in `TODO.md`, and the plan's locked decision was annotated
rather than deleted — the reasoning against it is the interesting part.
`zones.json` was deliberately deferred out of 8D into it: depth gating and the
food economy are the same question, and moving the foraging pools first would
mean moving them twice.

### Audit pass before the commit (same session)

Four things the review caught, all fixed before committing.

**The report overclaimed.** The new section header said "every lift in the game
is now a multiplier of the character's own stat". It is not: **14 of the 22
fortune cards grant flat ±5/±10 ratings** for six hours (`attackBonus` and
friends), which decay across a lifetime exactly as the stances did. Narrowed the
claim to what is true — every lift a TECHNIQUE grants — and named the deck as the
largest flat-bonus site left, unaudited and deliberately unchanged: those cards
carry penalties as well as bonuses, so what they should BE is a design question
rather than a conversion.

**A tuning value was hardcoded into player copy.** `combat.effect.shadow_veil`
read "doubled dodge" / "подвоєного ухилення" — true only while the multiplier is
2.0, and `/reload` can change it under a running bot. Interpolated as
`×%{multiplier}` (formatted `%g`, so 2.0 reads "×2" and 1.5 reads "×1.5") and
checked mechanically against the Lingo rule: same placeholder set in both
locales, nothing wider than one UTF-16 unit before a placeholder.

**The schema handshake had no test**, and four version bumps have now leaned on
it — v9 renames two fields and makes a third required, so a v8 bundle decoding
`+50` into a multiplier is exactly what it is there to stop. Two tests: a
manifest-only directory with a wrong version throws `schemaMismatch`, and the
same directory with the CURRENT version gets past the guard and fails on
`items.json` instead. The second is what makes the first mean something.

**Digest coverage was proven rather than asserted.** Each new field was perturbed
alone and moved exactly one half, each to a distinct value: veil ×2.1 →
`tuning 924ff095f7971c49`, defend ×1.6 → `tuning f09d71add3e1d551`, elite floor
15 → `records b94c5e72a1a899fc`.

**A mistake worth writing down: `git checkout <path>` on UNCOMMITTED work.**
Restoring the perturbed JSON that way reverted the files to HEAD and silently
threw away the phase's own edits to them — the next digest run failed to decode,
which is the only reason it was noticed within a minute. The files were rebuilt
and the baseline `dfe1ff8e24605e0d` came back identical, which is what proves the
restore was exact. With uncommitted work in the tree, back a file up by COPY
before perturbing it; `git checkout` is not an undo for edits git has never seen.

---

## Session — 2026-08-31 part 2 (Phase 8E: Vigor stops regenerating)

The user reopened a locked decision — "slow regeneration plus food" — and it
turned out to be the one holding up the depth gate.

### The argument, which the code made better than the plan did

`stepsDeep` increments per step with no level gate, and it does not need one:
the pool plus the food in the bag decides how deep a player can walk and still
walk home, and the walk home is symmetric (returning is step-by-step, not a
teleport). But `VigorService.regenTick` deliberately did NOT pause during an
expedition — a comment argued for it in as many words — so a player could stand
at km 25, wait six hours and refill. **There was no depth gate; there was only
patience.**

Removed: `regenTick`, `regenPerMinute`, `ProgressionMath.vigorRegenPerMinute`,
the one call site in `routes.swift`, `progression.vigorPool.fullRegenHours`
(schema v10) and its validator rule, and the `last_vigor_tick_at` column
(`RemoveVigorTick`). HP regeneration is untouched — it is a different mechanic
and it DOES pause in the wilderness, because resting is something you do at home.

### The wrong number, and what it teaches

The estimate that convinced everyone — "a 2-slot estate at level 1 feeds ~540
Vigor/day against the regen's 525" — **was wrong.** It came from `PlotService`'s
file header, which described a pre-5.3c ladder ("2 / 3 / 4 / 5 / 5 / 6 / 6, +1
every 4 levels", "currently overridden to a flat 5") while the code four lines
below it read `[0, 1, 2, 3, 4, 5, 6]`. **Estate tier 1 has no plots at all**; the
first opens at T2, player level 4.

Caught only by moving the table into content so the simulator could read it —
i.e. by making the number executable. **A stale comment outlives a stale value,
because nothing runs it.** This one sat directly above the function it described
through three phases of edits to that function.

### FoodBudget: the pace model had to be rebuilt, not retuned

"A day is one full pool plus 4× regen" was a line in the report that stopped
being true the moment the trickle went. The replacement enumerates every multiset
of plot types the slots allow — 84 layouts at six slots — cooks each through any
recipe whose inputs it produces, eats the rest raw, and keeps the best. Brute
force beat argument here: with four plot types there was no need to pick a
"representative" mix, so the last hand-picked constant in the pace number is the
harvest cadence, which the report prints.

What it found, in order:

- **36–40 days against the old 51–56.** The estate at three harvests a day is
  MORE generous than the regen was. The call was to go slower than the old
  number rather than back to it — 90 days, so "3+ months" sits in the figure
  instead of in an assumption about imperfect play. Landed at **85–93** by
  cutting the food plots (farm 4/h cap 20 → 1/h cap 6, coop 2/h cap 12 → 1/h
  cap 5), leaving forest and mine alone so building materials keep their pace.
- **1,211 taps a day**, against the ~390 the plan budgeted for everything. Cutting
  the plots took it to 513, because fewer Vigor per day is fewer portions per day
  as well as fewer fights. The report prints taps/day now, not just taps-to-cap.
- **Food portions rot exactly like the stances did.** `restore_vigor` is FLAT
  against a pool that grows: the best dish is 33% of a level-1 pool and 12% of a
  level-40 one. Deferred by decision, with batch cooking, to after the rebalance —
  and wired into the report (`balance.portion_rots`) so it cannot be forgotten.
- **Levels 1–3 have no estate at all**, which is a feature: the first days are
  lived off the trail, XP there is tiny (~11 kills to reach level 4), and it
  gives the estate a reason to exist. The model excludes those levels and says
  so rather than dividing by zero.

The `pace.too_fast` band moved 45 → 72 days with the model it judges. **A band
and the model under it are one decision**, the same lesson 8D learned about a
band and its sample size.

### zones.json — the last content in Swift

The foraging pools left `ExplorationService.rollLoot` (two arrays and a nested
ternary). **Equivalence was proved by parsing the shipped arrays out of git and
replaying them against the new file for km 1–40: identical, including weights and
ORDER** — the roll walks the array subtracting weights, so a reordered pool
changes every draw while leaving each entry byte-identical.

Two deliberate differences, both stated rather than smoothed over: the
`?? "mat.pine_lumber"` fallback is gone, so a km no zone covers now finds nothing
and the validator reports the gap (the same lesson as `pickFor`'s `?? all.first`,
which made every encounter past km 35 a wild boar); and past km 40 foraging finds
nothing where it used to hand out the deep pool forever, which is what the
encounter table already does past its own horizon.

Nine validator rules, a seeded forage replay folded into the digest's `spawns`
half, and `pickWeighted` deleted as dead.

### State

222 tests, `validate` clean, `simulate --strict` exit 0, 0 broken bands. Baseline
`abbdaa0e82efb78f` (schema v10): `records`, `tuning` and `spawns` all moved —
the plot ladder and the retuned plots, `fullRegenHours` leaving, and foraging
joining the replay — while **`quests` did not**.

### Audit pass before the 8E commit (same session)

Three things the review caught.

**A real bug in the phase's own change.** `rollLoot`'s new "no zone covers this
km" path applied the starvation HP tick and then returned `.nothing` — taking HP
off the player while telling them the room was empty. The bucket ten lines above
it returns `.starvationOnly(hpLost:)` for exactly this case; the new path now
does the same. Narrow (it needs an uncovered km AND a starving player, and the
shipped file covers km 1–40) but it was wrong, and it was wrong in the direction
that hides itself.

**The greedy in `FoodBudget.cook` is exact only by luck of the bundle.** Exactly
one recipe is reachable from plot output today (`baked_potato`), so richest-first
cannot mis-spend an input. If a second becomes reachable it can under-count. Said
so in the code rather than leaving the reader to find out, and noted that the
error direction is toward a slower pace, which is the safe one.

**Phase 5B's entry in `TODO.md` still read as intent.** It described Vigor regen
as a feature "deliberately NOT suspended during an expedition" — which is now
precisely the reasoning for deleting it. Annotated rather than removed, the same
way the monster-silver line was: the history is worth reading, it just had to
stop sounding like a plan.

Digest coverage of the new data was proved by perturbation, with file COPIES
rather than `git checkout` (the lesson from the 8D audit): a forage weight 2 → 3
moves `spawns` alone, the plot-slot ladder T7 6 → 5 and a farm capacity 6 → 7
each move `records` alone, and the seven enemy spawn counts are identical to the
pre-8E run — so the `spawns` half moved because foraging joined it, not because
enemy selection shifted.

---

## Session — 2026-08-31 part 3 (Phase 9: the first two content specs)

The phase's rule is that the list gets signed off before it reaches JSON. The
first decision was about the documents themselves.

### Numbers are printed, never typed

A specification full of hand-typed numbers is a fourth transcription of the same
curves, rotting from the moment a coefficient moves. So `roi-content spec
<progression|gates|bestiary|items>` emits every table from the code that owns the
maths — `ProgressionMath` for the ladder and stat line, `EnemyGenerator` for what
an archetype asks at a level, `BudgetMath` for what a slot may spend. The spec
and the generator cannot disagree, and the command is the seed of Phase 10's
generator: the same tables, one step earlier and in a form a person can argue
with.

### spec-progression.md — the skeleton

Printing the ladder made something visible that nobody had seen laid out:
**levels 1–15 are 1.3% of the whole climb, and 30–40 are 71.5%.** The plan's
"author 1–15, generate the rest" therefore meant authoring the part every player
sees and almost none of the time they spend. Decided: **the authored band is
1–25** (12.8%), which is also where every technique and estate gate lands.

Two more decisions, both deliberate deferrals rather than fixes: **nothing new
unlocks between level 21 and 40** — a real hole, 78% of the XP with only stats
and gear in it, but what fills it is better decided after the game has been
played; and **past km 40 the deep zone continues** rather than ending in a wall,
because content will go there later. The second was applied immediately
(`zone.deepwood` to km 49) and the digest did not move, which is the correct
signature: the forage replay walks km 1–40, so extending past it is provably
inert.

The document also writes down a rule the shipped roster had always obeyed and
nobody had stated: **an enemy of level N spawns from km N to km N+9.** From the
player's side, at km K you meet levels K−9…K — so depth is the difficulty dial
and the player's hand is on it. The elite floor of level 14 becomes a *place*:
no elite before km 14.

### spec-bestiary.md — density without new content

The km rule turned the roster's shape into a number: **the first six kilometres
of the game contain one animal.** A seventeen-creature roster was drafted, nine
of them new, with the Blight thickening by ratio and a wild aurochs as the boss.

**It was turned down, and the counter-proposal is better.** No new creatures:
re-spread the seven that exist (boar 1, moose 4, bison 7, lynx 10, wolf 13, bear
16, rabid bear 22), changing levels only and leaving families, archetypes, names
and loot untouched. The spacing was SEARCHED rather than chosen — every
arrangement keeping the family ladders in order, respecting the elite floor and
actually ascending — and it wins on the two things that matter: all four common
archetypes are met by km 10, and the Blight thickens with depth in the ratio
(3:1 wild in the thicket, 3:3 in the old wood). Density 2.2 → 2.6 per km, with
the gain where it was needed: km 4–9 had one creature, now three.

Worth keeping: **no new locale keys, no new art, no new ids** — the whole
improvement is seven integers. And the roster change is NOT in the data yet;
authoring is Phase 10's job, which is what a spec phase means.

The boss stays unmembered by decision. The archetype keeps its contract (12
rounds, 130% of a bar, ×9 XP) and waits for a played game.

### The three wildernesses became one

The game described the same forest three ways: the lore's bands (1–10 / 10–20 /
20–35, from before the cap moved to 40), the enemy bands (level N → km N…N+9) and
the foraging pools (1–2 / 3–5 / 6–49, written when the map ended at km 10). None
of the three agreed with either other.

Reconciled and applied: **Гущавина 1–10 / Старий ліс 11–25 / Пуща 26–49**, in
`zones.json` and `lore.md` both, so the authored band is exactly the first two
zones and the draft band exactly the third. The cost was weighed rather than
discovered: foraged iron and clay move from km 3 to km 11, which means **the mine
plot stops being optional in the first week**. `spawns` moved and the other three
halves held, which is exactly the signature a foraging-band change should have.

### Audit pass before the Phase 9 commit (same session)

**A parsing bug in the new command.** `roi-content spec --levels 1,5 bestiary`
read "1,5" as the table name, because a flag's VALUE does not start with a dash
either. `spec` is the first command in the CLI with a positional after flags, so
nothing had needed to skip flag values before. Fixed by stepping over a flag and
its value together, and checked in both argument orders.

**Two claims from the specs were checked rather than left as assertions.** The
bestiary spec said the Blight "starves the player as well as fighting them" and
that the economy spec would have to verify it. Verified here: a wild kill returns
0.7–1.7 raw meat, which cooks to 8.4–20.4 Vigor against the ~16.8 a kill costs —
so clean game roughly pays for itself and a Blighted animal is a pure loss. Two
things fell out that the spec now records: **the boar is the exception and it is
the first thing anyone meets** (8.4 against 16.8, so the opening hours run at a
loss), and **past km 31 there is no meat at all**, which with foraging at −0.5
Vigor per fresh room makes the deepest zone a pure sink.

**A knob that does nothing.** Every archetype declares a `lootMultiplier` (elite
3.0, boss 8.0). It is mapped into the domain and fingerprinted by the digest, and
**no award site reads it** — both loot paths go through `rollLootDrops`, which
rolls each table row's own chance. An elite drops exactly what a trash mob drops.
Same shape as the `silverReward` that had no curve: a field that reads as balance
and is wired to nothing. Recorded for `spec-economy.md` to decide.

**`content/bestiary.md` was a stale reference doc** — Phase 4 combat, cap 21,
five-kilometre tiers, the boar at 18 HP against the 34 it carries. Marked
SUPERSEDED with a pointer to where each part of the truth now lives, rather than
edited or deleted: its family design (Wild drops meat and hide, Rabid hide only)
is still exactly right, and it is the second stale document this rebalance has
found sitting quietly beside working code — after `PlotService`'s header.

### Documentation and memory sweep (same session)

A pass with no feature work: make every document say what is true, and make a
fresh session able to continue without reading the transcript.

**Stale records found and fixed.** `CLAUDE.md`'s one-line description of the game
still said "manage 30x30 estates" — a design direction closed on 2026-05-18 and
recorded as closed in the auto-memory, sitting in the first paragraph a new
session reads. `README.md` still described Shadow Veil as "+50 dodge" and the
archer's Defend as "+30 dodge" (multipliers since 8D) and the XP reward as a
per-tier table of 5/12/25/50/100/175 (per-enemy data, solved from the archetype
table, since Phase 5A). `.memory/file-map.md` carried the same two flat bonuses,
described `VigorService` as if it still regenerated, and its whole `content/`
block was Phase 1 vintage — five files and the line "NOTHING READS THESE YET —
the bot still runs off the Swift arrays until Phase 2". `.memory/status.md` and
`INDEX.md` still said Phase 9 was next rather than in flight.

**The pattern is worth naming, because it is now three for three.** `PlotService`'s
header outlived its own function by three phases; `content/bestiary.md` outlived
the combat model it documented; the file-map's content block outlived the
migration it described. **A document rots silently because nothing executes it** —
which is exactly why the numbers in the Phase 9 specs are printed by
`roi-content spec` rather than typed.

**Written down where it will be found again.** `CLAUDE.md` gained the rule that
content is specified before it is authored, with the command that prints the
tables. The auto-memory gained `project-world-ladder`: the level↔km rule, the
three zones, the authored band 1–25 — the four facts every remaining spec hangs
from, each expensive to derive and none of them obvious from the code.
`Prompt.md` now opens the Phase 9 section with an explicit next action
(`spec-items.md`, then sets, then economy) so a fresh session starts at the work.

**One consistency fix in the tool**: `roi-content spec` defaulted to levels 1–15
while the approved band is 1–25. The default follows the decision now.
