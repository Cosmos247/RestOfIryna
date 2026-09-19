# Game Core (GDD Summary)

## Premise
Medieval kingdom with rabies plague in wildlife. Players get estates, fight beasts, expand territory. Telegram bot interface (text + emoji + inline keyboards).

## Target Scale
1,000-3,000 concurrent players, shared world.

## Classes (chosen at registration, permanent)
- **Warrior** (tank-bruiser): High HP, Defense, medium Attack
- **Archer** (single-target DPS): High Attack, Crit, Accuracy
- **Mage** (burst caster): High Attack, Crit, low HP

## Core Stats (6)
Health, Defense, Attack, Crit, Dodge, Accuracy

## Core Loop
Prepare (eat/equip) -> Explore (timed room chain) -> Fight (rabid animals) -> Decide (deeper/return every 5 rooms) -> Return (bank loot, craft, upgrade)

## Key Systems

### Exploration
- Infinite linear room chain (1 room = 1 km)
- **Two modes**:
  - Active reconnaissance (розвідка): tap-driven, instant steps, no timer — the primary loop. Implemented in Phase 3.1 + 3.2.
  - Passive expedition (експедиція): time-gated and **shipped**. Three choices of 30 / 60 /
    90 authored minutes, capped at `passive.dailyBudgetMinutes` (180) per game day. The
    `testMode` flags were retired in Phase 4b; durations now come from `tuning/time.json`,
    and `scale` is 1.0, so authored minutes are real minutes.
- Events: four buckets (nothing / loot / encounter / trip) on a three-tier decay keyed on how many times THIS expedition has entered that km. **The live weights are `content/data/tuning/exploration.json` — never restated here; every copy of them in a doc has gone stale at least twice.** The shape is what matters: tier 0 is fresh ground, tier 1 is a km walked once, tier 2+ is picked clean (encounter and trip go to zero — the anti-farm brake on pacing between two km). Two consequences that are easy to miss: **the walk home is ALWAYS tier 1** by construction, since every km on it was walked once on the way out; and **tier 1 is also the whole passive expedition** (`passive.freshStepCount` = 1, so a 90-min run is 1 fresh step and 17 tier-1 steps). Re-tuned 2026-09-10 so the decay favours encounters over forage — beasts wander back onto a km you passed an hour ago, a stripped berry bush does not regrow.
- Dungeons: guaranteed every 7th room, party-based, instanced
- Death: respawn in town, lose expedition loot, keep gear

### Combat
- Round-based, simultaneous resolution
- 3 buttons: Attack, Defend, Auto
- Extra row: Potions, Food, Artifacts, Spells (conditional)
- PvE: AI picks actions; PvP: 30-sec timer per round
- 5 enemy tiers (T1 hare/fox -> Boss dungeon-only)
- **Escape — as SHIPPED, which the four bullets above are not** (2026-09-15). A flat
  per-class chance (warrior 40 / archer 70 / mage 90, `combat.json` → `flee.byClass`) with
  no level, enemy or depth input, floored by a per-fight ceiling: `flee.maxFailures` = 4, so
  the attempt after four failures is granted without a roll. The ceiling exists because a
  failed escape is not a free round — it is an unmissable hit at half armour with nothing
  dealt back, and the unbounded tail sat on the one button a player reaches for when
  already losing. Roll and ceiling are ONE rule behind `CombatService.fleeSucceeds`; the
  count lives on `ExplorationState.combatFleeFails` and is scoped to the fight. See
  `project-flee-has-a-ceiling`.

### Vigor
- 0 to VigorMax (scales with level, ~100-300)
- Drains: room walk (2), double-speed (4), combat round (1)
- Starvation: travel time doubles, stats -25%, HP drain per room
  (5% of max HP, `tuning/vigor.json` → `starvation.hpDrainPercent`). It is charged
  on EVERY step once Vigor is 0, whatever else the step rolled, and is **always
  printed on its own line** — `rollStep` carries it on `StepResult`, never inside an
  event's number. See `project-damage-sources-named-separately`.
- **Food is priced, not picked** (2026-09-18): a cooked dish restores the trader buy-price of
  its ingredients in Vigor and a quarter of that in HP, so the ladder runs 10 → 72 Vigor. Only
  berries (4), nuts (5) and a duck egg (3) are edible as found; potato and raw meat are not.
  See `project-food-is-priced-not-picked`
- **No passive Vigor regeneration at all** since Phase 8E — the pool is a stock, fed by
  food, quests and levelling, and the estate's plots are the intended income

### Rest and the road
- **HP regen happens at the estate and nowhere else** (2026-09-10).
  `HealingService.canRest` names the three states that suspend it: an `ExplorationState`
  row (in the forest), a `TravelState` row (on the road) and `location == capital`.
  Only the first was ever checked, so the manor's bed worked from anywhere in the
  kingdom. Away from the estate the clock is CLEARED, not merely skipped. Potions are
  the away-from-home heal; nothing in the capital can take a player to 0 HP (the arena
  clamps both duellists to `max(1, …)`), so refusing to heal there strands nobody.
- **A trip can be turned around** (2026-09-10). While one is in flight the nav keyboard
  lends the Explore slot to `↩️ Розвернутись`; walking back costs exactly what has been
  walked, measured as `travelSeconds − remaining` from the row's `endsAt` and capped at
  one crossing. **`createdAt` was the bug** — it locates only a leg that began at an
  endpoint, and a turn-back row is created mid-road, so a second turn-back priced a
  two-minute road at five seconds (fixed 2026-09-11). Turns are
  symmetric — each costs only its own leg, so oscillating converges rather than compounds.

### Estates *(grid + adjacency abandoned 2026-05-11; see Territorial Warfare below)*
- Manor: per-tier rooms (Warehouse → +Kitchen → +Workshop unlock as the estate tier grows; see Phase 5.3c for the actual gating). Workshop hosts Forge + Tannery + weapon-upgrade + bag-upgrade flows; Kitchen hosts cooking
- Plots: abstract list (no spatial layout), slot count grows with estate tier `[0,1,2,3,4,5,6]`. Types: Farm / Lumberyard / Mine / Coop / Training Ground
- **A claim is permanent.** `PlotService` has `claim` and `harvest` and no third verb — no
  code path deletes a `Plot` row or changes its type or tier — so since 2026-09-17 the picker
  shows the chosen type's card and asks before it writes
- Real-time production timers (PlotProductionService)
- ~~Placed in global shared grid, adjacency matters~~ — the 30×30 grid + frontier-placement + 8-neighbor design (originally Phase 5.4) is no longer planned

### Capital
- Main Square, Market (NPC + player bazaar), Quest Board, Stables, Guildhall, Arena, Chapel, Bank
- Built out so far: Trader, Tavern, Fortune Teller, Master, Market + Trade, Guildhall, Arena. Chapel / Stables / Bank remain GDD-only.

### Daily quests *(design locked 2026-08-23, v1 shipped as Phase 9.2)*
- **Scope of v1: the gathering core** — Trader, Master and Innkeeper only. All three are single-player and lean on content that already exists, so the loop works the day it ships. Arena / Fortune Teller / Guild quest-givers, story chains and weeklies were explicitly deferred.
- **Cadence: dailies only.** One job per NPC per game day, on the `GameDay` boundary (12:00 Kyiv).
- **No picking, no queue of active jobs** — the system assigns the day's job. The player never browses a list; they walk up to the NPC and either can finish it or can't. Assignment is derived from a hash of player + NPC + day, so every player gets their own roll and nothing has to be stored or scheduled.
- **Rewards: silver on every job, plus a per-NPC accent** — Trader pays more silver, Master adds XP, the Innkeeper adds Vigor, and since 2026-09-18 the Innkeeper also TEACHES: finishing his job pays the lowest unearned rung of the recipe ladder (`project-npcs-teach-recipes`). A recipe is not scaled by level, because it is not a number. Sizing intent is ~1.5–2× what selling the same materials to the Trader would earn: worth a detour, not a replacement for play.
- **Two objective shapes.** "Hand over N items" is checked live against the bag and consumes the items on turn-in; "do X N times" is counted from gameplay events (beast kills, forge output, trader sales, tavern wins).
- The journal on the profile screen is a *status* screen only — it shows progress and the countdown to the next rollover, but rewards are always collected from the NPC who gave the job, so the trip to the capital keeps its weight.

### Leaderboards *(shipped 2026-09-12)*
- Four **all-time** boards behind the quest journal, as tabs redrawing one message: ⚔️ level, 🎖 arena honor, 🌲 deepest km ever, 🚶 total km walked. Read-only, like the journal itself.
- **Ties share a place** and rank is computed on the board's own metric — the secondary sort only orders the display, because a board headed «Рівень» that put two level-24 players at 1st and 2nd would show the same number twice with nothing explaining the gap.
- The two walking boards read `users.deepest_km` / `users.total_km_walked`, **the first cumulative counters this game has ever stored**. Nothing could be backfilled: a depth record lived only in `exploration_state.steps_deep`, which is deleted when the expedition ends. Both started at 0 on 2026-09-12.
- **They are written at different moments, and that is the semantics** *(2026-09-15)*. 🚶 Шлях is a tally, raised on every step including the walk home. 🌲 Глибина is banked ONLY when the player reaches the manor — from `ExplorationState.maxDepthKm`, the run's high-water mark — so an expedition nobody came back from banks nothing, which is what the subtitle «і поверталися» always promised. Every depth change goes through `ExplorationState.moveTo(km:)`. The column was zeroed once (`ResetDeepestKm`) because it changed what it measures. Auto-memory `project-depth-is-banked-on-arrival`.
- **The forest is left on foot or not at all** *(2026-09-15)*. `/start` and a stray Cancel re-render the expedition instead of ending it, and `/start` in a fight re-renders the fight — a free exit would be the cheapest way to bank a depth record, and closing it on one screen only moves it to the other.
- The 🎖 board and the Arena's own «Найкращі бійці» render from the SAME `LeaderboardService`, so the two screens cannot disagree about who is second.
- **All-time is the first period, not the only one** — seasons are a decided direction, and a seasonal board will be a second reading with its own storage, never a reset of a lifetime column. Auto-memory `project-leaderboards-will-go-seasonal`.

### Pets & Taming
- 2-5% chance on encounter -> Attempt to Cure button
- Pet stats mirror player stats + Level, Species, Bond
- Roles: combat pets, buff pets, worker pets

### Territorial Warfare *(design pivoted 2026-05-11 — adjacency-based model abandoned)*
- Original GDD plan: adjacent-estate-only PvP, 10-loss-streak loses a border tile, cooldowns between challenges. **Discarded** along with the 30×30 grid.
- Replacement: a different estate-attack PvP mechanic — design TBD. Lives in Phase 7+ as a clean-sheet effort once the rest of Phase 5/6 is solid.

### Economy
- Resources: raw materials, biomass, flora, currency (gold + TBD premium), rare drops
- Crafting in manor rooms (recipe-based, tier-gated)
- Market: NPC fixed prices + player free-market

### Monetization (TBD)
- F2P with a premium currency (name TBD — was "crowns" in early draft, reserved until renamed)
- Cosmetics, convenience, no exclusives
