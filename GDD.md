# ROI — Game Design Document

**Version:** 0.1 (initial draft)
**Status:** Design in progress — numeric values marked `⚙️ TBD` are tuning placeholders
**Target scale:** 1,000–3,000 concurrent players, shared world
**Platform:** Telegram Bot (text + emoji + inline keyboards)

> This document describes the full design intent for ROI v1. For project setup, stack, and code layout, see [README.md](./README.md). Anything marked **[v1]** ships in the first release; **[post-v1]** is backlog. Since everything in the current scope is v1, [v1] tags are mostly implicit and only called out where ambiguity might exist.

---

## Table of Contents

1. [Concept & Setting](#1-concept--setting)
2. [Core Gameplay Loop](#2-core-gameplay-loop)
3. [Character System](#3-character-system)
4. [The Hunger System](#4-the-hunger-system)
5. [Exploration](#5-exploration)
6. [Combat System](#6-combat-system)
7. [Estates & the 30×30 Grid](#7-estates--the-3030-grid)
8. [Resources, Economy & Crafting](#8-resources-economy--crafting)
9. [The Capital](#9-the-capital)
10. [Pets & Taming](#10-pets--taming)
11. [Territorial Warfare](#11-territorial-warfare)
12. [Progression](#12-progression)
13. [Social Systems](#13-social-systems)
14. [Monetization](#14-monetization)
15. [Technical Notes](#15-technical-notes)
16. [Open Design Questions](#16-open-design-questions)

---

## 1. Concept & Setting

### Premise

A medieval kingdom. Forests have always been dangerous, but now a plague of rabies is sweeping the wildlife — animals that were once shy or even docile now hunt humans on sight. The crown has neither the manpower nor the resources to contain the spread, so it has turned to a system of **landed adventurers**: each able-bodied citizen is granted an estate at the kingdom's edge and expected to defend, develop, and expand it while hunting the diseased beasts for bounty and materials.

The kingdom's capital stands at the center of the realm — a hub for trade, quests, and arena sport. The wilderness stretches outward indefinitely, and the deeper you go, the stranger and more dangerous it becomes. Somewhere around *kilometer seven* lie dungeons rich enough to be worth the journey.

### Tone

Grounded medieval fantasy with a light folk-horror undercurrent. The rabies metaphor is a quiet pillar — nature turned against civilization — but the game itself is not grim. It rewards curiosity, gradual mastery, and cooperation. Death is a setback, not a tragedy.

### Core Pillars

1. **Time-gated exploration.** The core loop is paced in real-world minutes. Players log in, set an expedition running, and come back to results. This makes ROI a fit for Telegram's interaction style and for low-attention sessions.
2. **A home worth defending.** Every player has a persistent, visible, customizable 30×30 estate. It is the anchor of their identity in the game world.
3. **Shared finite space.** Estates are placed in one global grid. Land is scarce, adjacency matters, and neighbors can be allies or threats.
4. **Battle that respects mobile.** Combat is three buttons deep by default — Attack, Defend, Auto — with depth layered in through items, spells, and pets rather than input complexity.

---

## 2. Core Gameplay Loop

At the minute-to-minute level:

1. **Prepare** — manage hunger (eat), check inventory, equip gear, set pets.
2. **Explore** — walk into the forest. Timed transitions between rooms trigger random events.
3. **Fight** — engage rabid animals encountered mid-exploration.
4. **Decide** — every 5 rooms, choose to press deeper or return home.
5. **Return** — bank loot, craft, upgrade estate, socialize.

At the session-to-session level:

6. **Upgrade** — expand manor, improve plots, unlock crafting tiers.
7. **Trade** — buy/sell at the capital or peer-to-peer.
8. **Raid** — guild dungeons, PvP arena, neighbor skirmishes.
9. **Expand** — win territorial wars, claim more tiles.

---

## 3. Character System

### Classes

Three classes, chosen at registration, unchangeable afterward (swap for premium currency `⚙️ TBD`):

| Class    | Icon | Role                                  | Stat Tilt                       |
|----------|------|---------------------------------------|---------------------------------|
| Warrior  | ⚔️   | Frontline tank-bruiser                | High HP, high Defense, medium Attack |
| Archer   | 🏹   | High-accuracy single-target damage    | High Attack, high Crit, high Accuracy |
| Mage     | 🔮   | Burst caster with utility spells      | High Attack, high Crit, low HP       |

Class differences are expressed through:
- Starting stat distribution
- Exclusive spell / skill trees
- Exclusive craftable equipment (the bowyer's bench is for archers, etc.)
- Slightly different event outcomes (a mage can identify herbs a warrior cannot)

### Stats

Six core stats, identical in name across classes:

| Stat      | Effect in combat                                               | Scales with |
|-----------|----------------------------------------------------------------|-------------|
| Health    | Hit points. Reaching 0 = defeat.                               | Level, gear, hunger |
| Defense   | Reduces incoming damage when Defend is pressed or passively `⚙️ TBD formula` | Gear, skills |
| Attack    | Base outgoing damage when Attack is pressed                    | Gear, stat points |
| Crit      | Chance to deal critical damage (×2 or `⚙️ TBD`)                | Gear |
| Dodge     | Chance to fully avoid incoming attack                          | Gear, class |
| Accuracy  | Chance to connect; reduces enemy dodge effectiveness           | Gear |

**Stat point allocation on level-up** — `⚙️ TBD`: either a fixed pool per level the player distributes, or fully gear-driven with class-fixed base stats. Leaning toward: small fixed pool (2–3 points) per level + gear on top, to give a light "build" feel without deep theorycrafting required.

### Leveling & Experience

- XP is earned from kills, dungeon completions, and exploration milestones.
- Level cap for v1: `⚙️ TBD` (suggest 30–50 to keep pacing tight).
- Each level raises max HP and max Hunger.
- Gear slots: helmet, chest, legs, boots, main-hand, off-hand, accessory ×2 `⚙️ TBD`.

### Identity

Each character has:
- A display name (defaults to Telegram name, editable once for free, then paid)
- A class
- An estate (auto-assigned on registration — see §7)
- A locale preference (EN / UK at launch)
- A guild tag (optional, post-registration)

---

## 4. The Hunger System

Hunger is the pacing meter of the entire game. It constrains how long you can stay in the forest and is the primary resource food items restore.

### Mechanics

- **Range:** 0 to `HungerMax` (scales with level — start ~100, cap ~300 `⚙️ TBD`).
- **Fully fed** at registration.
- **Drains from:** entering a new room, combat round, using the "double-speed travel" option.

### Drain rates (initial values — `⚙️ TBD`)

| Action                       | Hunger cost |
|------------------------------|-------------|
| Walk to next room (standard) | 2           |
| Walk to next room (2× speed) | 4           |
| Combat round                 | 1           |
| Idle in town                 | 0           |

### Starvation Penalty

When `hunger == 0`:
- In **passive expedition** mode, travel time between rooms **doubles** (5 min → 10 min; test mode 10 s → 20 s). Active reconnaissance has no transition timer, so this penalty doesn't apply there.
- Combat stats are reduced by `⚙️ TBD` percent (suggest −25% to Attack and Defense).
- **Health drains** each room transition while starving (suggest 5% of max HP per room).
- Food eaten while starving restores less efficiently — can add a brief "eating while starved" grace period `⚙️ TBD`.

### Food

Food items restore hunger; better food restores more and unlocks deeper exploration:

| Tier   | Example           | Restores        | Source                        |
|--------|-------------------|-----------------|-------------------------------|
| T1     | Raw berry, bread  | ~15 hunger      | Forest pickup, capital market |
| T2     | Cooked stew       | ~40 hunger      | Player craft (kitchen)        |
| T3     | Roasted game      | ~80 hunger      | Craft from rare drops         |
| T4     | Feast dish        | ~150 hunger     | Rare recipes, endgame         |

Specific recipes, ingredient lists, and cookbook progression are tracked in `content/recipes.md` (to be created).

---

## 5. Exploration

The signature loop of ROI.

### The Room Chain

Exploration is an **infinite linear chain of rooms**, measured in kilometers — **1 room = 1 km**. Starting from home (km 0), each "Continue deeper" press takes the player one km further into the woods.

Exploration has two modes with different pacing:

- **Active reconnaissance (розвідка)** — the player drives the chain manually. Step Forward / Step Back buttons resolve instantly; there is no transition timer and no real-time gating. Each tap rolls an event at the new km. This is the primary gameplay loop.
- **Passive expedition (експедиція)** — the player sets a duration (30 min / 1 h / 1.5 h planned) and the bot simulates room transitions in the background. In this mode:
  - **Transition time:** 5 minutes per room in production; 10 seconds in test mode (feature flag).
  - **Double-speed:** player can halve travel time by spending 2× hunger.

The chain does not branch in either mode. Depth is progress.

### Exploration Events

Upon arriving in a new room, one event is rolled from a weighted pool:

| Event                     | Weight `⚙️ TBD` | Effect                                            |
|---------------------------|----------------|---------------------------------------------------|
| Nothing of note           | 30%            | Flavor text only                                  |
| Found mushroom            | 10%            | +1 ingredient (rare variants at depth)            |
| Found plant / herb        | 10%            | +1 alchemy ingredient                             |
| Found resource on ground  | 10%            | +1 raw resource (wood, stone, ore at depth)       |
| Tripped on a branch       | 5%             | Small HP loss (`⚙️ TBD`, e.g., 5% max HP)         |
| Rabid animal encounter    | 30%            | Enter combat (see §6)                             |
| Cave / dungeon entrance   | See below      | Option to enter a multi-player dungeon            |
| Hidden cache / shrine     | 5%             | Rare currency or buff                             |

Event pools are depth-aware — deeper kilometers unlock rarer variants and tougher enemies. Tripping, for example, never happens in the first km but becomes non-trivial at km 5+.

### Dungeons

- **Trigger:** randomly, with guaranteed spawn every **7th room**, the player finds a cave / dungeon entrance.
- **Entry:** player may enter solo or invite friends / guildmates via an inline callback. Dungeons are instanced per party.
- **Rewards:** rare crafting materials, gear blueprints, currency, cosmetic drops, and a chance at pet-taming encounters.
- **The deeper the dungeon, the better the rewards** — a km-7 dungeon is meaningfully better than a km-2 one.

### The Return Prompt

**Every 5 rooms** (km 5, 10, 15, 20…) the player is shown:

```
You pause at the edge of a clearing.

❤️ Health: 72 / 100
🍖 Hunger: 48 / 120

[🏰 Return home] [🌲 Go deeper]
```

If they decline, the game continues and the prompt appears again at the next 5-km mark. No cooldown, no penalty for going deep — only risk.

### Death

If the player's HP reaches 0 during exploration:
- They respawn in town at 1 HP (or `⚙️ TBD` fraction of max).
- All loot collected **during that expedition** is lost.
- Equipped gear is **not** lost (but may take a small durability hit `⚙️ TBD` — we can decide later whether durability exists at all).
- No XP loss in v1.

Returning voluntarily to town preserves everything.

---

## 6. Combat System

### Design Principle

Three main buttons. Depth through items and pets, not through input complexity. Battles must be readable on a phone screen in seconds.

### Turn Model

Combat is **round-based with simultaneous resolution**. Each round:

1. Both sides choose an action.
2. Server resolves both actions together and produces a combat log.
3. The log is sent to both participants (PvP) or to the player (PvE).
4. New inline keyboards appear for the next round.

### Core Actions

Three buttons always present:

| Button      | Effect                                                                        |
|-------------|-------------------------------------------------------------------------------|
| ⚔️ Attack  | Deal damage scaled by Attack, checked against Accuracy/Dodge, may Crit        |
| 🛡 Defend   | Reduce incoming damage this round significantly (scaled by Defense)           |
| 🤖 Auto     | Engage auto-combat — the server resolves subsequent rounds automatically, alternating sensible Attack/Defend choices until the fight ends or the player presses Stop |

### Extra Action Row

A second row of inline buttons may appear conditionally, depending on what the player has available:

- 🧪 **Potions** — HP / hunger / buff potions
- 🍞 **Food** — mid-combat eating (if allowed — `⚙️ TBD`, might have a cooldown)
- 💎 **Artifacts** — one-use rare items with unique effects
- ✨ **Spells / Skills** — class-specific actives (cooldowns)

### Damage Formula (initial sketch — `⚙️ TBD`)

```
hit_roll      = clamp(Accuracy − enemy.Dodge + RNG, 5%, 95%)
if (not hit)  → "miss"
base_damage   = max(1, Attack − enemy.Defense × defend_multiplier)
is_crit       = random() < Crit
final_damage  = base_damage × (is_crit ? 2.0 : 1.0) × variance(0.9–1.1)
```

`defend_multiplier` = 2.0 when the defender pressed 🛡 Defend this round, 1.0 otherwise.

### PvE vs PvP

Mechanically identical — same action set, same round structure. Differences:

- **PvE:** opponent AI picks actions from a simple policy (aggression scaled by enemy type).
- **PvP:** both players must act within a **30-second per-round timer** (`⚙️ TBD`). Timeout = Defend. Mutual 🤖 Auto resolves immediately.

### Bestiary (current implementation)

Two thematic families across a 20-km depth span. Wild animals are killable + cookable (drop raw meat + hide). Rabid animals are dangerous but their meat is poisoned by the plague — loot tables yield hide only.

| Tier   | Animal                    | Family | Depth range | HP / ATK / DEF | Drops                 |
|--------|---------------------------|--------|-------------|----------------|-----------------------|
| T1     | 🐗 Wild Boar              | wild   | km 1–10     | 18 / 5 / 1     | raw meat + hide       |
| T2     | 🫎 Wild Moose             | wild   | km 6–15     | 32 / 8 / 2     | raw meat ×2 + hide    |
| T3     | 🦬 Wild Buffalo           | wild   | km 11–20    | 55 / 11 / 4    | raw meat ×2 + hide    |
| T3     | 🐈‍⬛ Rabid Lynx            | rabid  | km 11–20    | 45 / 13 / 2    | hide (glass cannon)   |
| T4     | 🐺 Rabid Wolf             | rabid  | km 16–20    | 70 / 15 / 4    | hide (top hostile)    |
| Boss   | (Dungeon-only named beasts) | —    | dungeon     | TBD            | Unique rewards        |

Full bestiary lives in data at `content/data/enemies.json` (`EnemyCatalog` is a façade over it). Reference doc: `content/bestiary.md`.

Full bestiary to live in `content/bestiary.md` (to be created).

---

## 7. Estates & the 30×30 Grid

Every player gets one estate on registration.

### Layout

Each estate is a **30 × 30 tile grid**. The **manor** occupies a **7 × 7 area in the center**. The remaining ~836 tiles are the **personal wilderness** — the player's own plots.

```
. . . . . . . . . . . . . . . . . . . . . . . . . . . . . .
. . . . . . . . . . . . . . . . . . . . . . . . . . . . . .
. . . . . . . . . . . . . . . . . . . . . . . . . . . . . .
… (row 11)
. . . . . . . . . . . . 🏰🏰🏰🏰🏰🏰🏰 . . . . . . . . . . .
. . . . . . . . . . . . 🏰🏰🏰🏰🏰🏰🏰 . . . . . . . . . . .
. . . . . . . . . . . . 🏰🏰🏰🏰🏰🏰🏰 . . . . . . . . . . .
. . . . . . . . . . . . 🏰🏰🏰🏰🏰🏰🏰 . . . . . . . . . . .
. . . . . . . . . . . . 🏰🏰🏰🏰🏰🏰🏰 . . . . . . . . . . .
. . . . . . . . . . . . 🏰🏰🏰🏰🏰🏰🏰 . . . . . . . . . . .
. . . . . . . . . . . . 🏰🏰🏰🏰🏰🏰🏰 . . . . . . . . . . .
… (row 19)
. . . . . . . . . . . . . . . . . . . . . . . . . . . . . .
```

The grid renders as an emoji tilemap in chat (similar to prior Vaultown / D&D-bot work).

### The Manor (7×7 interior)

The manor is itself a 2D grid — 49 cells for rooms. Starting rooms:
- Bedroom (save point)
- Kitchen (basic cooking)
- Workshop (basic crafting)

Upgrades unlock additional rooms:
- **Smithy** — weapon crafting (warriors, archers)
- **Armory bench** — armor crafting
- **Alchemy lab** — potion brewing
- **Enchanter's table** — magical gear (mages)
- **Pet pen** — houses tamed animals (see §10)
- **Trophy hall** — cosmetic showcase
- **Vault** — extra storage

Each room has **tiers** (1 → 5 `⚙️ TBD`) that gate which recipes / items it can produce.

### Plots (everything outside the manor)

Plots are bought/unlocked with resources and assigned a purpose:

| Plot type        | Produces / enables                               |
|------------------|--------------------------------------------------|
| Farm             | Vegetables, grain (cooking ingredients)          |
| Orchard          | Fruit, herbs                                     |
| Pasture          | Livestock — milk, meat, hides                    |
| Mine             | Ore, stone                                       |
| Lumber yard      | Wood                                             |
| Hunting range    | Passive small-game drops                         |
| Garden (decor)   | Cosmetic only                                    |

Each plot has its own tier and produces on a **real-time timer** (hourly → daily cycles `⚙️ TBD`). Plots can be upgraded individually.

### Estate Placement in the Global Grid

Estates are placed into a **single shared world grid** of estates. Placement rules for v1:

- New players are placed at the current frontier — the outer ring of populated estates — on a first-come basis.
- Once placed, an estate stays at that location until territorial loss (see §11).
- Neighbors are the 8 adjacent estates. Adjacency determines who can attack for territory.

**Open question:** should players be able to pay to relocate? `⚙️ TBD`, default = no for v1.

---

## 8. Resources, Economy & Crafting

### Resource Categories

- **Raw materials** — wood, stone, ore tiers (iron → steel → rare alloys)
- **Biomass** — hides, bone, meat, pelts
- **Flora** — herbs, mushrooms, flowers
- **Currency** — gold (tradable), crowns (premium, paid — see §14)
- **Rare drops** — gems, essences, artifacts

### Acquisition

| Source                  | Drops                                           |
|-------------------------|-------------------------------------------------|
| Own plots (passive)     | Category-specific on timer                      |
| Exploration pickups     | Random roll per room                            |
| Combat drops (mobs)     | Tier-based loot tables                          |
| Dungeons                | Rare and unique drops                           |
| Market (from NPCs)      | Bulk at fixed prices, sink function             |
| Market (from players)   | Free-market pricing                             |
| Quests                  | Scripted rewards                                |
| PvP arena               | Gold + cosmetic tokens                          |
| Territory wars          | Stolen tiles + raid loot                        |

### Crafting

All crafting lives in manor rooms. Each recipe has:
- Required room + tier
- Required materials
- Optional required tool / blueprint
- Output (item + quantity)
- Craft duration (real-time `⚙️ TBD`, possibly instant for low tiers)

Recipes are **learned** via:
- Default set per class at level 1
- Blueprints found in dungeons / purchased at the market
- Quest rewards

Full recipe list lives in `content/recipes.md` (to be created).

### The Market

Located in the capital. Two stalls:
- **NPC stall** — buy/sell basic goods at fixed prices (acts as a price floor).
- **Player bazaar** — listings posted by players with expiration timers and a small listing fee (gold sink).

---

## 9. The Capital

Central hub of the kingdom. Accessible via `/capital` or the main menu. Contains named locations:

| Location        | Function |
|-----------------|----------|
| 🏛 Main Square   | Hub menu, announcements, events |
| 🛒 Market        | NPC stall + player bazaar |
| 📜 Quest Board   | Daily / weekly / seasonal quests from NPCs |
| 🐎 Stables       | Fast-travel between the capital and your estate (cost in gold) |
| 🏰 Guildhall     | Create / join / manage guilds |
| ⚔️ Arena         | PvP matchmaking (1v1 launch; group modes post-v1) |
| ⛪ Chapel        | Respec / name change (paid) `⚙️ TBD` |
| 🏦 Bank          | Personal vault + inter-player transfers |

### The Arena

- **1v1 ranked** and **unranked** queues at launch.
- ELO-style matchmaking.
- Separate gear option: *arena loadouts* so PvP balance isn't dictated by PvE grind (`⚙️ TBD` — this is a big balance lever, leaning toward keeping gear-driven in v1 and revisiting).
- Rewards: gold, arena tokens (spendable on cosmetics), seasonal leaderboards.

---

## 10. Pets & Taming

Modeled on a Pokémon-style side-battler. Pets **do not fight alongside** the player in main combat — they have their own battles — but can provide **passive buffs** when assigned.

### Taming

- Rare outcome (`⚙️ TBD`, ~2–5%) on encountering a rabid animal.
- Requires the player to press a 🩹 **Attempt to Cure** button that appears instead of 🗡 Finish.
- Success chance scales with `⚙️ TBD` player level, item use (tame-kit), and pet rarity.
- On success: the animal is cured, loses its rabid state, and joins the player's pen.

### Pet Stats

Pets have their own stats mirroring the player's six — HP, Attack, Defense, Crit, Dodge, Accuracy — plus:
- Level (gained via pet-vs-pet battles and training)
- Species
- Bond (affects buff strength when assigned)

### Pet Roles

- **Combat pets** — fight in the dedicated pet-battle mode (PvE and PvP pet leagues).
- **Buff pets** — assigned to the player; provide a passive bonus (e.g., +5% crit, +10% hunger cap).
- **Worker pets** — assigned to estate plots, speeding production or adding a rare-drop chance.

Only one pet can be "active buff" at a time `⚙️ TBD`. Multiple can be housed in the pet pen.

### Pet Battles

- Separate mode, identical three-button combat UI (Attack / Defend / Auto).
- Not required for any progression — optional side activity.
- Pet leagues (ranked ladder) — `⚙️ TBD`, likely post-v1 scope if time is tight.

---

## 11. Territorial Warfare

The mechanic that makes the shared grid matter.

### Rules

- Only **adjacent estates** (8-neighbors) can initiate a territorial challenge.
- A challenge is a standard PvP combat match, but with territorial stakes.
- **10 consecutive losses to the same attacker** = the defender loses **1 tile** on the shared border, which is annexed by the attacker.
- The counter **resets** if the defender wins once, or if `⚙️ TBD` days pass without a rematch.
- A cooldown between challenges prevents grief-spamming (`⚙️ TBD`, e.g., 1 challenge per pair per hour).

### Scope of Loss

- Lost tile is a border tile, chosen by the attacker from the contested edge.
- If the lost tile contained a plot, the plot **and its buildings are transferred** to the attacker — a meaningful penalty that raises the stakes.
- Tiles with the manor footprint cannot be lost.
- `⚙️ TBD`: should there be a "reclaim window" where the defender can win the tile back at a discount?

### Alliances & Pacts

Guild members or mutually agreed pairs can form **non-aggression pacts** that disable territorial challenges between them. Managed in the Guildhall.

---

## 12. Progression

### The First Hour

1. Pick class & language.
2. Tutorial quest from an NPC — walk to km 1, fight a wild boar, come back.
3. Unlock first plot.
4. Craft first food.
5. Walk to km 3, return.
6. Buy gear at NPC stall.

### The First Day

- Reach km 5 consistently.
- Unlock 2–3 plots.
- Attempt first dungeon with a random party from the `/capital`.
- Join a guild.

### Mid-Game

- Deep exploration (km 5–10) becomes routine.
- Estate has smithy + alchemy lab.
- First tamed pet.
- Participation in territorial skirmishes.

### End-Game (v1)

- Km 7+ dungeon runs for rare blueprints.
- Arena ranked climb.
- Large-scale territory wars between guilds.
- Aesthetic estate-building, cosmetic collection.

Full tuning curves (XP required per level, gear power curve, hunger cap scaling) are tracked in `content/tuning.md` (to be created).

---

## 13. Social Systems

### Guilds

- Created in the Guildhall for a gold cost.
- Capped at `⚙️ TBD` members (suggest 20–50 for v1).
- Features:
  - Shared chat (proxied through the bot)
  - Shared guild vault
  - Guild-only dungeon invitations
  - Guild banner (cosmetic, visible on estates)
  - Non-aggression pacts

### Visiting Other Estates

- Players can request visits via a `/visit @username` command.
- The visited player gets an accept/deny prompt.
- A visit means the grid is rendered to the visitor (read-only).
- "Hostile visit" = territorial challenge, doesn't require consent, but subject to cooldown rules (§11).

### Player Trading

- Via the market (asynchronous, listing-based).
- Via direct trade (both players confirm a trade window, atomic swap).

---

## 14. Monetization

**Status:** to be decided — a detailed monetization design will come separately.

### Working direction

- Free-to-play, no hard paywalls, no pay-to-win in PvP.
- Premium currency (**crowns**) sold for real money.
- Crowns buy:
  - **Consumables** — premium potions, rare food with large hunger restore
  - **Cosmetics** — estate decor, manor skins, character skins, pet skins
  - **Rare items** — blueprints that are *also* findable in-game (no exclusivity)
  - **Convenience** — slot expansions, accelerated plot production, faster exploration cooldowns `⚙️ TBD` (careful — convenience can become pay-to-win)
- Nothing sold for crowns is unobtainable through gameplay.

Final pricing, storefront, and crown-pack tiers — pending.

---

## 15. Technical Notes

These notes connect game design to the implementation in the repo.

### State per user (DB-persisted)

- Identity (Telegram ID, name, class, locale, created_at)
- Stats (level, XP, current HP, current hunger, stat allocations)
- Inventory (items + quantities)
- Equipped gear (per slot)
- Pets (list + active buff pet)
- Estate (JSON/binary blob of the 30×30 grid + manor layout, or normalized tables — `⚙️ TBD`)
- Exploration state (current km, time of next room transition, accumulated loot not yet banked)
- Combat state (if in combat: opponent ref, round number, action history)
- Router name (see §15 below)
- Timestamps for rate-limiting, cooldowns

### Router states (controllers)

Maps to controllers from `Swift/Controllers/`:

- `registration` → `RegistrationController`
- `main` → `MainController`
- `settings` → `SettingsController`
- `explore` → `ExplorationController` *(planned)*
- `combat_pve` / `combat_pvp` → `CombatController` *(planned)*
- `estate` → `EstateController` *(planned)*
- `market` → `MarketController` *(planned)*
- `guild` → `GuildController` *(planned)*
- `arena` → `ArenaController` *(planned)*
- `pet` → `PetController` *(planned)*

### Timed actions

Exploration transitions and plot production are long-running timed events. Approach `⚙️ TBD`, options:

1. **Poll-on-interaction** — no background jobs; compute outcomes lazily when the user next interacts. Simpler, works great for plot production, borderline-acceptable for exploration (but needs push-style notifications for "you've arrived").
2. **Scheduled jobs** — background ticker that fires Telegram messages when transitions complete. Better UX, more infra.

Recommended: hybrid. Compute lazily on interaction, plus a lightweight scheduler that sends a "ping" message when an exploration room completes — so the user knows to re-engage.

### Scale considerations

1,000–3,000 concurrent players. This is modest by backend standards but non-trivial for:
- **Combat** — PvP requires matchmaking state + per-round timeouts. Redis or an in-memory actor per match is natural.
- **Territory grid** — must be queryable by coordinates, with concurrency-safe updates on tile transfers. Single-writer-per-estate keeps this simple.
- **Market** — standard async listing board with row-level locks for purchases.

### Telegram-specific constraints

- **Rate limit:** 30 messages/second global per bot; we must batch and avoid naive fan-out (e.g., guild announcements).
- **Message edits** are cheap and lookup-friendly — prefer editing the "current state" message for combat rounds rather than spamming new messages.
- **Callback data budget:** 64 bytes — use a short callback scheme (e.g., `c:a:<matchId>` for combat-attack).
- **Inline keyboards** — primary UI mechanism for combat, exploration, estate editing.

---

## 16. Open Design Questions

Consolidated list of `⚙️ TBD` items from above, ranked by how much they affect feel:

### High impact

1. **Leveling model** — fixed stat points per level, or pure gear-driven?
2. **Death penalty** — only expedition loot, or also durability / small gold loss?
3. **Hunger tuning** — how many rooms can a new player realistically walk on full hunger?
4. **Crit and Dodge ceilings** — any soft caps? Combat is unfun if either stat creeps to 90%+.
5. **Arena gear** — do arena matches use PvE gear, normalized loadouts, or separate arena-only gear?

### Medium impact

6. **Dungeon party size** — 2–4? 5? Scales with content design.
7. **Rate of tile loss** — is 10 losses/attacker fast or slow given expected PvP frequency?
8. **Taming success base rate** — 2%? 5%? Affects perceived rarity hard.
9. **Plot production timers** — hourly, 4-hour, daily cycles?
10. **Monetization placement** — which convenience features are acceptable behind crowns without crossing into pay-to-win?

### Low impact (can decide late)

11. Gear durability existence.
12. Name-change cost.
13. Guild size cap.
14. Visit-system etiquette (rate-limits, silent-decline option).
15. Leaderboards — what categories, what cadence?

---

*Last updated: initial draft. This GDD is meant to be a living document — as systems ship and playtesting reveals reality, tuning values and open questions collapse into decisions, and new questions will appear.*
