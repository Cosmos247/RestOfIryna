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
- 5 min per room (10 sec test mode)
- Events: nothing (30%), mushroom/herb/resource (30%), combat (30%), trip (5%), cache (5%)
- Dungeons: guaranteed every 7th room, party-based, instanced
- Death: respawn in town, lose expedition loot, keep gear

### Combat
- Round-based, simultaneous resolution
- 3 buttons: Attack, Defend, Auto
- Extra row: Potions, Food, Artifacts, Spells (conditional)
- PvE: AI picks actions; PvP: 30-sec timer per round
- 5 enemy tiers (T1 hare/fox -> Boss dungeon-only)

### Hunger
- 0 to HungerMax (scales with level, ~100-300)
- Drains: room walk (2), double-speed (4), combat round (1)
- Starvation: travel time doubles, stats -25%, HP drain per room
- Food tiers: T1 (15) -> T4 (150)

### Estates (30x30 grid)
- Manor: 7x7 center (rooms: bedroom, kitchen, workshop + unlockable)
- Plots: farm, orchard, pasture, mine, lumber yard, hunting range, garden
- Real-time production timers
- Placed in global shared grid, adjacency matters

### Capital
- Main Square, Market (NPC + player bazaar), Quest Board, Stables, Guildhall, Arena, Chapel, Bank

### Pets & Taming
- 2-5% chance on encounter -> Attempt to Cure button
- Pet stats mirror player stats + Level, Species, Bond
- Roles: combat pets, buff pets, worker pets

### Territorial Warfare
- Adjacent estates only, standard PvP combat
- 10 consecutive losses to same attacker = lose 1 border tile
- Counter resets on defender win
- Cooldown between challenges

### Economy
- Resources: raw materials, biomass, flora, currency (gold + TBD premium), rare drops
- Crafting in manor rooms (recipe-based, tier-gated)
- Market: NPC fixed prices + player free-market

### Monetization (TBD)
- F2P with a premium currency (name TBD — was "crowns" in early draft, reserved until renamed)
- Cosmetics, convenience, no exclusives
