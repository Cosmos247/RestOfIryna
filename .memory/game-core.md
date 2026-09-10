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
  - Passive expedition (експедиція): time-gated — 5 min per room in production, 10 sec in test mode. Planned for Phase 3.3.
- Events (fresh tier, re-tuned 2026-05-12): nothing (10%), loot (50%), combat (30%), trip (10%). Revisit tier (priorVisits=1): 20 / 50 / 20 / 10. Bare tier (priorVisits≥2): 80 / 20 / 0 / 0 — beasts and trip hazards vanish but a 1-in-5 forage chance remains.
- Dungeons: guaranteed every 7th room, party-based, instanced
- Death: respawn in town, lose expedition loot, keep gear

### Combat
- Round-based, simultaneous resolution
- 3 buttons: Attack, Defend, Auto
- Extra row: Potions, Food, Artifacts, Spells (conditional)
- PvE: AI picks actions; PvP: 30-sec timer per round
- 5 enemy tiers (T1 hare/fox -> Boss dungeon-only)

### Vigor
- 0 to VigorMax (scales with level, ~100-300)
- Drains: room walk (2), double-speed (4), combat round (1)
- Starvation: travel time doubles, stats -25%, HP drain per room
- Food tiers: T1 (15) -> T4 (150)
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
  walked, measured from the row's `createdAt` and capped at one crossing. Turns are
  symmetric — each costs only its own leg, so oscillating converges rather than compounds.

### Estates *(grid + adjacency abandoned 2026-05-11; see Territorial Warfare below)*
- Manor: per-tier rooms (Warehouse → +Kitchen → +Workshop unlock as the estate tier grows; see Phase 5.3c for the actual gating). Workshop hosts Forge + Tannery + weapon-upgrade + bag-upgrade flows; Kitchen hosts cooking
- Plots: abstract list (no spatial layout), slot count grows with estate tier `[0,1,2,3,4,5,6]`. Types: Farm / Lumberyard / Mine / Coop / Training Ground
- Real-time production timers (PlotProductionService)
- ~~Placed in global shared grid, adjacency matters~~ — the 30×30 grid + frontier-placement + 8-neighbor design (originally Phase 5.4) is no longer planned

### Capital
- Main Square, Market (NPC + player bazaar), Quest Board, Stables, Guildhall, Arena, Chapel, Bank
- Built out so far: Trader, Tavern, Fortune Teller, Master, Market + Trade, Guildhall, Arena. Chapel / Stables / Bank remain GDD-only.

### Daily quests *(design locked 2026-08-23, v1 shipped as Phase 9.2)*
- **Scope of v1: the gathering core** — Trader, Master and Innkeeper only. All three are single-player and lean on content that already exists, so the loop works the day it ships. Arena / Fortune Teller / Guild quest-givers, story chains and weeklies were explicitly deferred.
- **Cadence: dailies only.** One job per NPC per game day, on the `GameDay` boundary (12:00 Kyiv).
- **No picking, no queue of active jobs** — the system assigns the day's job. The player never browses a list; they walk up to the NPC and either can finish it or can't. Assignment is derived from a hash of player + NPC + day, so every player gets their own roll and nothing has to be stored or scheduled.
- **Rewards: silver on every job, plus a per-NPC accent** — Trader pays more silver, Master adds XP, the Innkeeper adds Vigor. Sizing intent is ~1.5–2× what selling the same materials to the Trader would earn: worth a detour, not a replacement for play.
- **Two objective shapes.** "Hand over N items" is checked live against the bag and consumes the items on turn-in; "do X N times" is counted from gameplay events (beast kills, forge output, trader sales, tavern wins).
- The journal on the profile screen is a *status* screen only — it shows progress and the countdown to the next rollover, but rewards are always collected from the NPC who gave the job, so the trip to the capital keeps its weight.

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
