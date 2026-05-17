# Rest Of Iryna (ROI) ⚔️🐺

[![Build Status](https://img.shields.io/badge/Build-Passing-brightgreen)](https://github.com/Maxim-Lanskoy/GPTGram/actions)
[![Swift](https://img.shields.io/badge/Swift-6.2-orange)](https://github.com/swiftlang/swift/releases/tag/swift-6.2-RELEASE)
[![Hummingbird](https://img.shields.io/badge/Hummingbird-2.10-blue)](https://github.com/hummingbird-project/hummingbird)

**ROI** is a massively-multiplayer medieval text RPG for Telegram, built in Swift. Players explore a kingdom plagued by an epidemic of rabies spreading through its wildlife, expanding their personal estates, battling mad beasts, and waging territorial wars against neighbors.

> 📖 **Full game design lives in [GDD.md](./GDD.md).** This README covers the project, the stack, and how to run it.

<p align="center">[ <a href="https://docs.hummingbird.codes">Hummingbird</a> ]
  [ <a href="https://docs.vapor.codes/fluent/overview/#fluent">Fluent / PostgreSQL</a> ]
  [ <a href="https://core.telegram.org/bots/api">Telegram Bot API</a> ]
  [ <a href="https://github.com/nerzh/swift-telegram-sdk">Swift Telegram SDK</a> ]
</p>

---

## 🎮 The Game in One Paragraph

The kingdom's forests have fallen to a rabies plague. Playing a **mage**, **warrior**, or **archer**, each player claims a personal estate with a central manor, then ventures out to explore an infinite chain of wilderness rooms — finding resources, fighting rabid beasts, occasionally taming them, and diving into multi-player dungeons deep in the woods. Back home, they upgrade the manor through 7 tiers (Wooden Hut → Lord's Holdings), expand plots for farming / mining / livestock, craft gear and food at the Workshop and Kitchen, and clash with rival estates through estate-attack PvP. The capital hosts markets, quests, guilds, and a PvP arena. See [GDD.md](./GDD.md) for the full system breakdown.

---

## 🏗️ Architecture

ROI is built on a router–controller state machine. Each controller represents a "screen" — registration, main menu, exploration, combat, estate editor, market — and the router dispatches incoming Telegram updates to whichever controller the user is currently in.

```
┌─────────────────────────────────────────────────────────────┐
│                     TGBot + Dispatcher                       │
│              (stored in AppState, shared)                    │
└─────────────────────────────────────────────────────────────┘
                               │
          ┌────────────────────┼────────────────────┐
          ▼                    ▼                    ▼
┌──────────────────┐ ┌──────────────────┐ ┌──────────────────┐
│  Global Commands │ │   Router System  │ │  Session Cache   │
│ (/help /settings)│ │ (per-user state) │ │ (actor-based)    │
└──────────────────┘ └──────────────────┘ └──────────────────┘
                               │
                    ┌──────────┴──────────┐
                    ▼                     ▼
        ┌─────────────────────┐   ┌───────────────────┐
        │  Game Controllers   │   │   User Sessions   │
        │  (Explore, Combat,  │   │  (PostgreSQL +    │
        │   Estate, Market…)  │   │    cache layer)   │
        └─────────────────────┘   └───────────────────┘
```

### Router–Controller Pattern

1. **Router** — inspects each update and routes it to the right controller, based on the user's `routerName` (persisted in DB), command matching, and content type (text / callback / photo).
2. **Controllers** — each encapsulates a discrete interaction flow. Current and planned controllers:
   - `RegistrationController` — lore-driven 6-step onboarding: language → Artanian welcome + name → class descriptions → King's Oath (grants class starter weapon) → wolf encounter with class-specific artwork → real CombatController fight against `enemy.rabid_wolf` (only victory advances; defeat / flee / `/start` is a soft retry with full HP) → estate naming. First message and the post-fight estate prompt both ship `ReplyKeyboardRemove` so leftover button labels (mode picker / combat keyboard) can't be submitted as names. Nickname + estate-name inputs are validated against digits / Latin / Ukrainian Cyrillic, single internal spaces only, with five distinct error toasts (too short / too long / edge space / consecutive spaces / invalid character).
   - `MainController` — town hub / main menu with Explore / Inventory / Estate / Capital / Profile / Settings nav
   - `SettingsController` — language, preferences
   - `ExplorationController` — Phase 3.1/3.2/3.3. Tapping 🗺 Explore opens a **mode picker** `[🏃 Reconnaissance]` (active) / `[🏕 Expedition]` (passive) — the picker keeps the player in `MainController`'s routerName so tapping any main-menu button cleanly dismisses the picker and navigates normally (handled via the `EphemeralChatState` actor + `dismissPendingPicker` helper). **Active**: step-forward / step-back / bag / death, reply keyboard `[🚶 Step fwd] [🔙 Step back]` / `[🎒 Bag]`, three-tier visit-decay weights (fresh → reduced → bare). **Passive**: duration picker (30/60/90 units, seconds in test mode / minutes in prod), `PassiveExpeditionService` arms a Task.detached + live per-step loop, persists per-step outcome counters + loot totals on `state.running_report_json` so a bot restart resumes with the full event history, pushes a combined "🏰 back at estate" + `PassiveReport` message to the player's chat on completion (no Close button — state is auto-deleted), and exits early on death so the report lands immediately. Startup rescheduler in `configure.swift` re-arms any in-flight passive expeditions across bot restarts. Death (in either mode) wipes non-equipped inventory and respawns at HP=1 (vigor preserved).
   - `EstateController` — tree nav: Root (per-level artwork, tiers 1–3 drawn) → House (Workshop with real Phase 5.2 crafting; Kitchen with real Phase 5.2.1 cooking; Warehouse with real deposit/withdraw via `WarehouseService` — stackable types render as a 2-row card per item: an info button showing both counters (`[icon name · 🎒N / 📦M]`, tap opens a description modal) above a 3-button action row `[⬆️ +1] [⬇️ +1] [✏️ N]` where the third button opens a two-stage chat prompt — first picks direction (`[⬆️ To warehouse] [⬇️ To bag]` inline buttons), then edits in place into a quantity question; the player types a number and the bot routes through `WarehouseService.depositN` or `withdrawN` per direction (state lives in `EphemeralChatState.pendingWarehouseTransfer` with a nullable `Direction` field that nil-bumps to `.put` / `.take` on the direction tap); gear renders per physical row with a single-direction arrow since non-stackable items have no quantity to pick) / Plot. **Plot drill-down (Phase 5.1)** lists all unlocked slots (currently a flat 5 per player); each slot shows its production progress (e.g. `⛏ Slot 4 · Mine — 40/40 🪨 · 12/20 🔩` for the Mine plot's primary + bonus output). `[🚜 Slot N]` harvests into the Warehouse (not the bag — there's no slot cap) and flashes a `✅ Slot N — yields, added to Warehouse 📦` status banner. Empty slots show a `[➕ Slot N]` claim button that opens a 5-type picker (Farm / Lumberyard / Mine / Coop / Training Ground). The `🥋 Training Ground` plot routes a tap to a consequence-free fight against the Training Dummy (see CombatController). Successful deposits/withdraws emit a `✅ ...` status banner as a standalone message under the inline keyboard via `TGControllerBase.postStatusBanner` (the previous banner is auto-deleted so chat history carries only the latest); failures (nothing to move, backpack full) show a modal alert. **Workshop crafting (Phase 5.2)** opens a compact recipe list (one inline button per recipe, grouped by category through declaration order); tapping a recipe opens its detail screen (description + `📜 Recipe` inputs + `📊 Stats` for gear outputs + `[🔨 Craft]` / `[🔙 Back]`). Craft calls `CraftingService.craft` which drains inputs from the combined inventory + warehouse pool (inventory first to free backpack slots) and deposits the output into the inventory; success posts a `✅ Crafted ...` banner as a standalone message under the inline keyboard via `postStatusBanner`, shortages and bag-full surface as modal alerts. Five recipes ship: Iron Ingot (Forge) + Forester's Hood / Jerkin / Breeches / Boots (Tannery). **Weapon upgrade (Phase 5.2.2)** sits as a fixed `[⚔️ Upgrade weapon]` button at the top of the Workshop list — universal because every player has exactly one upgradable weapon (their class starter, granted by the King at registration). Tapping opens a dedicated detail screen showing current tier name + stats, an arrow `⤴`, the next tier preview with stat deltas, a `📜 Materials` block (with have/need indicators), and a green-or-red estate-level requirement line. Upgrade calls `WeaponUpgradeService.upgrade` which gates on `user.estateLevel >= nextTier`, drains materials from the combined inventory + warehouse pool, and bumps `InventoryEntry.tier` on the same row — item id never changes, the weapon "grows up" in place. Three weapons × 5 tiers each (Rusty Sword → Knight's Sword for warriors, Simple Bow → Hunter's Longbow for archers, Wooden Staff → Archmage's Scepter for mages); T1 stats match the legacy `Item.gearStats` so unmigrated DBs see no number change. Display names are tier-aware via `ItemDisplay.nameKey(for:tier:)` in the profile main-hand line, inventory gear rows, and the upgrade screen. Tiered weapons cannot be deposited to the warehouse (`WarehouseService.deposit` returns `notTransferable`) since the warehouse table doesn't carry a tier column. **Kitchen cooking (Phase 5.2.1)** mirrors the Workshop UI but the recipe list is gated by the union of always-available starters (`RecipeCatalog.starterRecipeIds` — Baked Potato + Roasted Meat, cookable from day one with no DB row) and the player's scroll-learned set (`LearnedRecipe` rows added via the inventory's `📖 Learn` action on `artifact.recipe.<dish_id>` scrolls). The detail screen shows a `📊 Effects` section (Vigor / HP) instead of Stats; the action button reads `🍳 Cook`, success banner reads "Cooked ..." (vs Workshop's "Crafted ..."). Every recipe also burns 1× 🪵 `mat.pine_lumber` for the cooking fire — narrative authenticity + soft farm-cooking cap. Seven dishes ship: Baked Potato / Roasted Meat (always available) + Forager's Omelette / Hunter's Stew / Meat Ragout / Forest Berry Tart / Governor's Feast (scroll-locked). **Phase 5.3c — Estate gates + manual estate upgrade:** Estate level is now a stored `User.estateLevel` field (not derived from `user.level` anymore). The Estate root carries a fixed `[🏠 Upgrade estate]` button that opens a detail screen with the current tier name, next tier preview, player-level requirement (✅/⛔), `📜 Materials` block with have/need from the combined inventory + warehouse pool, and — for T3+ transitions — a `💰 gold` line drained from `User.gold`. `EstateUpgradeService.upgrade` validates max-tier / player-level / gold / materials in order and surfaces every failure as a modal alert; success bumps the stored tier and refreshes the screen with a `✅ Estate raised to tier N — Name` banner. Six transitions in `EstateUpgradeCatalog` (T1→T2 … T6→T7) with player-level gates 4/7/10/13/16/19 and material costs scaling from ~33 units (cheap onramp) to ~313 units + 1000 gold (endgame milestone). Gold has no item id (lives on the User row, not in a backpack slot) so it never appears in the inventory or warehouse. Same upgrade lets the **rooms** in the manor open in stages: T1 shows only Warehouse, Kitchen unlocks at T2, Workshop at T3, Tannery sub-category at T4. The Training Ground plot type unlocks at estate T3, before that the plot picker shows only Farm/Lumberyard/Mine/Coop. Plot slot count by tier: `[0, 1, 2, 3, 4, 5, 6]` — T1 has zero slots; the first slot opens at T2. Warehouse capacity also grows with tier — per-unit caps `[200, 400, 600, 800, 1200, 1600, 2000]` since the 2026-05-12 per-unit slot pivot (was `[50, 100, 150, 200, 300, 400, 500]` per-row). Weapons still gate on `user.estateLevel >= nextTier` for upgrades. **Phase 5.3d — Bag upgrade in Workshop**: second universal button `[🎒 Upgrade bag]` next to the weapon upgrade. Detail screen mirrors the weapon flow — current tier name + slot capacity, next tier preview with `+delta` slots, estate-tier gate (✅/⛔), `📜 Materials` block with have/need from the combined pool, `[🧵 Sew]` confirm. Six bag tiers (Linen Sack 25 → Leather Bag 35 → Reinforced Backpack 45 → Hunter's Pack 60 → Master's Knapsack 80 → Grandmaster's Pack 85) with hide + iron costs scaling per tier; T6 craft gates on estate T7 (Lord's Holdings). `BagUpgradeService` validates max-tier / estate-gate / materials and bumps `User.bagTier`. Materials only — no gold cost on the bag track. **Slots count per-unit since 2026-05-12** — every carried unit takes a slot, so `flour × 8` costs 8 of the bag's 25. Same rule applies to the warehouse. `User.isDeveloper` (Telegram id ∈ `developerUsers`) bypasses both caps entirely — counts still show in the UI, blocks are skipped. **Phase 5.3e — Training Ground learn flow**: tapping a Training Ground plot now opens a dedicated screen with per-kind technique status (✅ learned / 📖 learnable button / 🔒 locked w/ level hint) plus `[🥋 Spar]` and `[🔙 Back]`. The `[📖 Learn X]` button writes a `LearnedTechnique` row (class-agnostic `special_atk` / `special_def` / `super` IDs) and refreshes with a `✅ Learned X` banner. `[🥋 Spar]` spawns the dummy fight as before.
   - `CapitalController` — Phase 6.0 + 6.1 + 6.2. Travel-gated city hub reached from the estate via a 2-minute trip handled by `TravelService` (in-memory `TravelState` row, `Task.detached` timer, `User.location` flips on arrival, `rescheduleInflight` survives bot restarts). Reply-keyboard with 6 location buttons (Market / PvP Arena / Trader / Fortune Teller / Master / Tavern) + utility row [Inventory] [Profile] + 🏡 Back-to-estate. Welcome screen sent as photo (`Assets/capital/welcome.jpg`) + atmospheric lore caption when the trip arrives. Estate / Capital / Explore taps during travel show a countdown banner; taps from the capital onto Explore are blocked ("wilderness only borders the estate"); Estate-tap from capital starts the return trip. **Trader (Phase 6.1)** is live as the first capital subsystem: two-step UX (Menu → Buy/Sell list, edit-in-place over the merchant photo `Assets/capital/trader.jpg`), 11 listings from `TraderCatalog` priced per-unit at 1g/2g/3g/5g/10g/100g sell with flat 2× sell:buy spread, per-row info-modal + `[💸/💰 ×1] [✏️ N]` action buttons. The `[✏️ N]` button opens a "How many?" prompt routed via `EphemeralChatState.PendingTraderTransfer` + `unmatched` text intercept; invalid input keeps the prompt with an error, validation failure deletes the prompt + error banner, success deletes + ✅ banner. **Tavern (Phase 6.2)** is live too: button-driven Menu / Dice / Darts; menu sells all 7 cooked dishes (20-200g) bypassing recipe scrolls; gambling uses `bot.sendDice` (returns 1-6 server-side, Telegram animates client-side ~3s) with text labels ("Ти кидаєш..." / "Шинкар кидає...") between pairs since Telegram doesn't let bots author messages as the player. Wager flow: tap stake → "Готовий?" + `[🎲 Кинути][❌ Скасувати]` (no gold debited yet — free cancel) → tap Roll debits + runs the sequence: player label + N dice (2 for dice, 1 for darts) → sleep 4s → house label + N dice → sleep 4s → result message with `[🔄 Зіграти ще раз][🔙 До шинка]`. Inline-button `inv:*` callbacks forwarded to `InventoryController.onCallbackQuery` so inventory drill-down works while routerName stays "capital". Other 4 stubs (Market / Arena / Fortune / Master) auto-load `Assets/capital/<id>.jpg` if present via `renderLocation`.
   - `InventoryController` — tree navigation; root shows all 5 category buttons with counts plus a fullness indicator (`X/Y slots` where `Y` reads from `User.bagTier` via `BagCatalog.capForTier`); drill-down renders each item as an inline button (info-modal with the item's lore on tap) plus a type-specific action. Food/potion consume via VigorService; gear is shown per-row (each physical unit is its own button, no `× N` aggregation) and toggles between 🛡 Equip / ❌ Unequip via EquipmentService, with a persistent per-item icon via `Item.icon`; artifact placeholder until TBD. **Phase 5.3d + per-unit pivot (2026-05-12)** — bag slot cap is per-user, starting at 25 (T1 Linen Sack) and reaching 85 at T6 (Grandmaster's Pack) through Workshop upgrades via `BagUpgradeService`. Each carried unit takes a slot (so `hide × 6` is 6 of those slots — used to be 1 row pre-pivot). Existing rows beyond the new cap stay readable; the limit only blocks new inserts past the limit (same policy as the warehouse cap). Developer accounts (`User.isDeveloper`) bypass the cap entirely — counts still show in the UI (`60/25`), inserts are not refused. Action acknowledgments (eat, equip, unequip) post as a standalone `✅ ...` banner under the inline keyboard via `postStatusBanner` — chat carries only the latest banner since each new one deletes the previous; warnings (raw food, full backpack, empty category, etc.) appear as Telegram modal alerts the player has to dismiss with OK — neither uses the narrow top-strip toast.
   - `CombatController` — Phase 4.1 + 4.2 + 4.3.1 turn-based PvE duel triggered when active-mode `rollStep` rolls an encounter, plus a Phase 5.1 Training Mode for the estate's Training Ground plot. Main keyboard is `[Attack][Defend] / [🪄 Techniques][Flee]` as inline buttons (`combat:attack/defend/flee` + `combat:tech:menu` callbacks) with class-flavoured labels (warrior = Slash / Parry / Retreat; archer = Arrow / Maneuver / Hide; mage = Magic / Barrier / Teleport). The controller owns no reply keyboard, so the player's previous one (exploration's, or none during registration) stays visible but inert; taps on it produce a one-line `combat.in_progress` nudge. Tapping `[🪄 Techniques]` edits the current message in-place to a class-flavoured submenu — Special Attack / Special Defense / Super stance — with a per-fight budget shown as " × N" suffixes. **Phase 5.3e** gates each kind behind `LearnedTechnique` and shows `🔒 <name>` for unlearned techniques (tap fires a modal alert pointing the player at the Training Ground at the required level); the budget itself is per-user-level via `CombatService.initialUses` — 1/1/1 early, bumping to 2 at L17/L20/L21 per kind. Spent learned buttons hide; locked buttons stay visible with the lock prefix. Phase 4.2 techniques: warrior (🪓 Cleave / 🏰 Iron Bulwark / 🩸 Bloodlust), archer (🎯 Vital Shot / 🌑 Shadow Veil / 🦅 Hawk's Eye), mage (🔥 Soulfire / 🪞 Mirror Ward / ✨ Arcane Resonance). Stance + special-atk + special-def modifiers all compose into the same `CombatService.applyAttack` primitive; vigor drains scale by stance multiplier; persistent effects (Iron Bulwark armor-split next swing, Shadow Veil lingering +50 dodge) tick down via `tickDefenseEffects()`. Basic Attack (−2 vigor) runs `applyAttack` both directions; basic Defend (−1) branches by class (`CombatService.Defend` namespace): warrior chip-damages 30% × ATK and doubles effective DEF for the round (canonical parry), archer chip-damages 15% (knife flick while hiding) and gets `+30 dodge` for the round with single DEF, mage skips chip entirely and the landed enemy hit is multiplied by `0.4` (60% damage reduction) — stronger mitigation than warrior to compensate for zero return damage; Flee (−3 base) uses class-specific success chances via `CombatService.fleeChance(forClass:)` — warrior 40% / archer 70% / mage 90%, with mage paying +2 vigor for the teleport. Failure triggers a forced full-damage counter. Victory awards loot via `ExplorationService.awardEncounterDrops` and hands the player back to ExplorationController at the same km; defeat shares `handleDeath`. The same controller also drives the registration wolves fight at step 4 — `Registration.handleCombatEnd(won:)` routes back into the registration flow when `session.registrationStep < 6`. **Training Mode** (entered from the Training Ground plot): clean damage on player swings (`cannotMiss = true`, enemy DEF treated as 0), no vigor drain, no enemy counter, dummy auto-revives on HP 0; `routerName` stays at `"estate"` so the reply keyboard remains usable, combat callbacks reach the controller via `combat:*` forwarding from the other controllers; `[Flee]` is replaced with `[🔙 Back]` (`combat:training:exit`) for a clean return to the Plot list. Edit-in-place combat UX is deferred (user prefers visible per-round logs). **Phase 5.3a XP-on-victory landed**: `finishVictory` calls `user.grantXP(enemy.xpReward)` (per-tier table on `Enemy` — 5/12/25/50/100/175 across T1–T6, training dummy = 0) and appends `📊 +N XP` / `🎉 Level N!` / `🏰 Estate tier N!` banners to the victory message; registration tutorial fight skips the grant (still narrative-only). **Phase 5.3e**: `beginCombat` takes per-fight uses derived from the player's level via `CombatService.initialUsesForUser`, and the technique handlers defensively re-check `LearnedTechnique.has` before executing — stale callbacks for unlearned kinds get the same `combat.tech.locked` alert as the submenu buttons. Per-enemy AI hooks, status effects (rabies), and combat log persistence live in the `Future / Backlog` section of `TODO.md`.
   - `MarketController` *(planned)* — trading with players and NPCs
   - `GlobalCommandsController` — `/help`, `/settings`, `/buttons` (works from any state)
3. **Context** — passed to every controller; holds the bot instance, DB handle, localization (Lingo), user session, and parsed command arguments.

---

## 📁 Project Structure

```
RestOfIryna/
├── Swift/
│   ├── Controllers/              # Bot controllers (game screens)
│   │   ├── AllControllers.swift
│   │   ├── MainController.swift
│   │   ├── RegistrationController.swift
│   │   ├── SettingsController.swift
│   │   ├── GlobalCommandsController.swift
│   │   ├── ExplorationController.swift   # Phase 3.1 active exploration (step/bag/return/death) — encounters now hand off to CombatController
│   │   ├── CombatController.swift        # Phase 4.1 + 4.2 turn-based PvE duel — Attack/Defend/Flee + [🪄 Techniques] submenu (Special Atk / Special Def / Super) with per-fight budget; registration wolves fight
│   │   ├── EstateController.swift        # Phase 5.0 skeleton: Root → House (room stubs) / Plot stub; per-level artwork
│   │   ├── CapitalController.swift       # Phase 6.0 + 6.1 + 6.2 — travel-gated hub; Trader (buy/sell + ✏️ N prompt) + Tavern (food menu + dice/darts gambling); 4 location stubs (Market/Arena/Fortune/Master)
│   │   └── InventoryController.swift     # tree nav root → category; inline Use/Eat/Equip action buttons
│   │
│   ├── Models/                   # Fluent ORM models + code-based catalogs
│   │   ├── User.swift
│   │   ├── Item.swift            # static item catalog (code, not DB) — Phase 5.2 added the Forester's leather set; Phase 5.2.1 added 7 cooked dishes + 5 recipe scrolls + Item.teachesRecipe field
│   │   ├── Recipe.swift          # static crafting catalog (RecipeCategory forge/tannery/kitchen, RecipeIngredient, RecipeOutput, Recipe, RecipeCatalog) — Phase 5.2 + 5.2.1
│   │   ├── LearnedRecipe.swift   # Phase 5.2.1 — Fluent model: per-user scroll-learned-recipe set (user_id, recipe_id, learned_at). has/add/allIds helpers; always-available starters live in RecipeCatalog.starterRecipeIds, not here
│   │   ├── LearnedTechnique.swift # Phase 5.3e — Fluent model: per-user known-technique set (user_id, technique_id, learned_at). IDs are class-agnostic (`special_atk` / `special_def` / `super`); player's class resolves the concrete technique in combat. has/add/allIds mirror LearnedRecipe.
│   │   ├── InventoryEntry.swift  # per-user item stacks in the backpack (DB) + helpers
│   │   ├── WarehouseEntry.swift  # per-user estate storage (separate table from inventory) + remove helper (Phase 5.2)
│   │   ├── ExplorationState.swift # one row per expedition — active or passive (user_id unique, stepsDeep, mode, ends_at, report_json, running_report_json, visited_rooms)
│   │   ├── Enemy.swift           # code-based bestiary (EnemyCatalog) — 7 wilderness animals + training_dummy; reference doc at content/bestiary.md
│   │   ├── Plot.swift            # Phase 5.1 — Fluent model for estate plots (user_id, slot_index, plot_type, tier, last_harvested_at, notified_full)
│   │   ├── PlotCatalog.swift     # Phase 5.1 — code-based plot type config (Farm / Lumberyard / Mine / Coop / TrainingGround), per-tier rate + cap, Mine bonus output (iron)
│   │   ├── WeaponUpgradeCatalog.swift # Phase 5.2.2 — per-weapon tier ladder (3 weapons × 5 tiers, stats + materials); ItemDisplay namespace lives in Item.swift
│   │   ├── EstateUpgradeCatalog.swift # Phase 5.3c — estate-tier progression (6 transitions T1→T2 … T6→T7, player-level gates 4/7/10/13/16/19, materials + gold cost for T3+)
│   │   ├── BagCatalog.swift      # Phase 5.3d — bag tier ladder (6 tiers: 25/35/45/60/80/85 slots since 2026-05-12 per-unit pivot — was 5 tiers 20/30/40/55/75), estate-tier gates per step, hide + iron materials only
│   │   ├── TravelState.swift     # Phase 6.0 — Fluent model: per-user in-flight trip between estate and capital (user_id unique, destination, ends_at)
│   │   ├── TraderCatalog.swift   # Phase 6.1 + v2 economy rebase — 11 trader listings, per-unit pricing (1g/2g/3g/5g/10g/100g sell), flat 2× sell:buy spread
│   │   └── TavernCatalog.swift   # Phase 6.2 — 7 cooked-dish prices (20-200g), shared wager tiers [10, 25, 50] for dice + darts
│   │
│   ├── Migrations/
│   │   ├── CreateUser.swift
│   │   ├── AddCharacterFields.swift
│   │   ├── AddProfileStyle.swift
│   │   ├── AddGameStats.swift
│   │   ├── CreateInventory.swift
│   │   ├── RemoveCrownsField.swift
│   │   ├── AddEquipSlotToInventory.swift
│   │   ├── AddGearBonuses.swift
│   │   ├── CreateWarehouse.swift
│   │   ├── CreateExplorationState.swift
│   │   ├── AddExplorationReturnState.swift
│   │   ├── AddHpRegenTick.swift
│   │   ├── AddPassiveExpeditionFields.swift
│   │   ├── RenameMaterialIds.swift
│   │   ├── RenameFoodIds.swift
│   │   ├── AddCombatFields.swift
│   │   ├── AddCombatStanceFields.swift     # Phase 4.2.1 — combat_stance + combat_stance_rounds_left
│   │   ├── AddCombatDefenseFields.swift    # Phase 4.2.3 — combat_enemy_def_debuff + combat_player_dodge_buff
│   │   ├── AddCombatTechniqueUses.swift    # Phase 4.2 polish — per-fight budget counters
│   │   ├── CreatePlots.swift               # Phase 5.1 — plots table (user_id, slot_index, plot_type, tier, last_harvested_at, notified_full)
│   │   ├── RemoveOldIron.swift             # Phase 5.1 — wipe legacy mat.old_iron rows from inventory + warehouse
│   │   ├── RenameLeatherVest.swift         # Phase 5.2 — remap gear.leather_vest → gear.forester_jerkin in inventory + warehouse (preserves existing rows)
│   │   ├── CreateLearnedRecipes.swift      # Phase 5.2.1 — learned_recipes table (user_id, recipe_id, learned_at; unique on user_id+recipe_id)
│   │   ├── AddPassiveRunningReport.swift   # Phase 3.3 polish — running_report_json column on exploration_state (persists per-step outcome counters + loot totals so passive reports survive bot restart)
│   │   ├── AddInventoryTier.swift          # Phase 5.2.2 — tier INT NOT NULL DEFAULT 1 column on inventory (consumed only by tiered weapons in WeaponUpgradeCatalog; T1 stats match legacy gearStats so existing equipped weapons see no numeric change)
│   │   ├── AddEstateLevel.swift            # Phase 5.3c — estate_level INT NOT NULL DEFAULT 1 column on users. Converts the previously-computed estateLevel to a stored field so manual upgrade via EstateUpgradeService can advance it
│   │   ├── AddUserBagTier.swift            # Phase 5.3d — bag_tier INT NOT NULL DEFAULT 1 column on users. Default 1 means existing players land at T1 (20 slots); they can sew bigger bags at the Workshop via BagUpgradeService
│   │   ├── CreateLearnedTechniques.swift   # Phase 5.3e — learned_techniques table (user_id, technique_id, learned_at; unique on user_id+technique_id). Mirrors CreateLearnedRecipes. Per-user known-technique set, gated behind player-level thresholds and a visit to the Training Ground plot.
│   │   ├── AddUserLocation.swift           # Phase 6.0 — location VARCHAR NOT NULL DEFAULT 'estate' column on users. Flipped only by TravelService on trip arrival.
│   │   └── CreateTravelState.swift         # Phase 6.0 — travel_state table (user_id unique FK cascade, destination, ends_at). Presence = en route.
│   │
│   ├── Services/                 # Domain services
│   │   ├── VigorService.swift   # drain, consume, starvation penalty, HP loss (pure)
│   │   ├── EquipmentService.swift # atomic equip/unequip, bonus recomputation
│   │   ├── WarehouseService.swift # deposit/withdraw between inventory and warehouse
│   │   ├── ExplorationService.swift # step outcome roll + autobattle stub + loot drops
│   │   ├── HealingService.swift  # passive HP regen (5%·maxHp/min) while at estate
│   │   ├── PassiveExpeditionService.swift # passive-mode duration picker + Task.sleep scheduler + simulation + report push
│   │   ├── CombatService.swift   # Phase 4.1 + 4.2 + 4.3.1 + 5.1 — applyAttack hit/miss/crit + chipDamage; AttackModifiers / StanceModifiers; per-class special-atk/def tunings; Flee chances; trainingDummyEnemyId
│   │   ├── PlotService.swift     # Phase 5.1 — pure plot helpers: accumulated, bonusAccumulated, harvest (deposits to Warehouse), claim, slotsForLevel
│   │   ├── PlotProductionService.swift # Phase 5.1 — single Task.detached ticker; pushes "ready to harvest" notifications when plot caps are reached
│   │   ├── CraftingService.swift # Phase 5.2 — pure: craft(_:for:on:) drains inputs from combined inventory+warehouse pool (inventory first), deposits output into inventory; CraftResult enum + Shortage struct for the modal alert
│   │   ├── WeaponUpgradeService.swift # Phase 5.2.2 — pure: upgrade(for:on:) advances the player's equipped weapon one tier. Estate-level gate, materials drained from combined inventory+warehouse, InventoryEntry.tier bumped in place (item id never changes), EquipmentService.recomputeBonuses re-run. Result enum: success/maxTierReached/estateLevelTooLow/missingMaterials/noWeaponEquipped.
│   │   ├── EstateUpgradeService.swift # Phase 5.3c — pure: upgrade(for:on:) advances User.estateLevel one tier. Validates player-level + gold + materials, drains from combined pool. Result enum: success/maxTierReached/playerLevelTooLow/insufficientGold/missingMaterials.
│   │   ├── BagUpgradeService.swift # Phase 5.3d — pure: upgrade(for:on:) advances User.bagTier one tier. Validates estate-tier + materials, drains from combined pool. Result enum: success(newTier, newCapacity)/maxTierReached/estateLevelTooLow/missingMaterials.
│   │   ├── TravelService.swift     # Phase 6.0 — estate↔capital trip orchestrator. start() validates guards (dead/starving/onExpedition/alreadyTraveling), persists TravelState, arms Task.detached timer. On arrival flips user.location + user.routerName, deletes the row, pushes the arrival screen. rescheduleInflight() on bot startup re-arms in-flight trips.
│   │   ├── TraderService.swift     # Phase 6.1 — quantity-aware sell(qty)/buy(qty). Atomic gold + slot preflight. Typed result enums for the UI banners. Called by both ×1 and the ✏️ N prompt flow.
│   │   └── TavernService.swift     # Phase 6.2 — buyDish (atomic, mirrors trader buy) + pure resolveWager(playerScore:houseScore:) → WagerOutcome for dice/darts outcome bookkeeping.
│   │
│   ├── Telegram/
│   │   ├── Router/               # Routing system
│   │   │   ├── Router.swift
│   │   │   ├── Context.swift
│   │   │   ├── Commands.swift
│   │   │   ├── ContentType.swift
│   │   │   ├── Arguments.swift
│   │   │   └── Router+Helpers.swift
│   │   └── TGBot/
│   │       ├── TGDispatcher.swift
│   │       └── HummingbirdTGClient.swift
│   │
│   ├── Helpers/
│   │   ├── TGBot+Extensions.swift
│   │   ├── SessionCache.swift
│   │   ├── Lingo+Locales.swift
│   │   ├── EphemeralChatState.swift  # in-memory actor — exploration mode-picker IDs, pending warehouse transfer-N state, pending trader transfer-N state (Phase 6.1), latest status-banner message ID per user, latest scenery photo message ID per user (Phase 6.3 chat cleanup)
│   │   ├── PhotoCache.swift          # Phase 6.3 — `[assetPath: fileId]` cache + `sendScenicPhoto(...)` helper (file_id reuse + auto-delete of the user's previous scenery photo so chat doesn't fill up with duplicate location backdrops). Default photo path for all location backdrops; direct `bot.sendPhoto` reserved for one-shot narrative art.
│   │   └── DotEnv+Env.swift
│   │
│   ├── entrypoint.swift
│   ├── configure.swift
│   └── routes.swift
│
├── Localizations/
│   ├── en.json
│   └── uk.json
│
├── Assets/
│   ├── registration/                # Artwork used during onboarding
│   │   ├── kings_charter.jpg        # Shown in the King's Oath step (all classes)
│   │   ├── warrior_estate.jpg       # Wolves encounter (warrior)
│   │   ├── archer_estate.jpg        # Wolves encounter (archer)
│   │   └── mage_estate.jpg          # Wolves encounter (mage)
│   ├── estate/                      # Per-level estate artwork (optional; added as drawn)
│   │   └── level_<N>.jpg            # e.g. level_1.jpg, level_2.jpg …
│   └── capital/                     # Phase 6 — capital + per-location art (auto-loaded by renderLocation when present)
│       ├── welcome.jpg              # Shown on arrival in capital + on re-entry
│       ├── trader.jpg               # Crамар (Trader) screen photo
│       └── tavern.jpg               # Шинок (Tavern) screen photo
│
├── Public/
│   └── favicon.ico
│
├── content/
│   ├── bestiary.md               # Per-enemy reference (stats, loot, depth, families)
│   └── recipes.md                # Phase 5.2 — Workshop recipe reference (categories, inputs, outputs, stats, source-pool rules)
│
├── GDD.md                        # Game design document — read this
├── README.md
├── Package.swift
├── Package.resolved
├── .env.example
└── .gitignore
```

---

## 🚀 Getting Started

### Prerequisites

- **Swift 6.2+** toolchain
- **Xcode 16+** (optional, for IDE support)
- **Docker** (for PostgreSQL)
- **Telegram Bot Token** from [@BotFather](https://t.me/botfather)

### Installation

1. **Clone**:
   ```bash
   git clone <repository-url>
   cd RestOfIryna
   ```

2. **Start PostgreSQL**:
   ```bash
   docker run -d \
     --name roi-postgres \
     -e POSTGRES_USER=roi \
     -e POSTGRES_PASSWORD=your-secure-password \
     -e POSTGRES_DB=roi_db \
     -p 5432:5432 \
     -v roi_pgdata:/var/lib/postgresql/data \
     postgres:16-alpine
   ```

3. **Configure environment**:
   ```bash
   cp .env.example .env
   ```
   ```env
   TELEGRAM_BOT_TOKEN=YOUR_BOT_TOKEN_HERE
   DB_HOST=localhost
   DB_PORT=5432
   DB_USER=roi
   DB_PASSWORD=your-secure-password
   DB_NAME=roi_db
   ```

4. **Update `Swift/configure.swift`**:
   - `projectPath` — your absolute project path
   - `@TGUserName` — your Telegram username in localizations

5. **Run**:
   ```bash
   swift build
   swift run
   ```

### Docker Reference

```bash
docker ps                                              # status
docker logs roi-postgres                               # logs
docker stop roi-postgres                               # stop
docker start roi-postgres                              # resume
docker exec -it roi-postgres psql -U roi -d roi_db     # psql shell
docker volume rm roi_pgdata                            # wipe data ⚠️
```

### Finding Your Telegram User ID

DM [@ForwardInfoBot](https://t.me/ForwardInfoBot) — it replies with your ID. Add it to `allowedUsers` in `configure.swift` for admin access.

---

## 💡 Development Notes

### Adding a New Controller

```swift
final class MyFeatureController: TGControllerBase {
    override func attachHandlers(to bot: TGBot, lingo: Lingo) async {
        let router = Router(bot: bot) { router in
            router["/mycommand"] = onMyCommand
            router.unmatched = unmatched
        }
        await processRouterForEachName(router)
    }

    func onMyCommand(context: Context) async throws -> Bool {
        try await context.respond("Hello from ROI!")
        return true
    }
}
```

Register in `AllControllers.swift`:
```swift
static let myFeature = MyFeatureController(routerName: "myfeature")
static let all: [TGControllerBase] = [
    registration, mainController, settingsController, myFeature
]
```

Transition into it from another controller:
```swift
context.session.routerName = "myfeature"
try await context.session.saveAndCache(in: context.db)
```

### Session Caching

```swift
let session = try await User.cachedSession(for: tgUser, db: db)  // fetch or create
try await session.saveAndCache(in: db)                            // persist + refresh cache
await session.invalidateCache()                                   // drop cache entry
```

### Keyboards

```swift
// Persistent reply keyboard (main menu, exploration nav)
let markup = TGReplyKeyboardMarkup(keyboard: [
    [TGKeyboardButton(text: "🚶 Step fwd"), TGKeyboardButton(text: "🔙 Step back")],
    [TGKeyboardButton(text: "🎒 Bag")]
], resizeKeyboard: true)

// Inline keyboard (callbacks — exploration events, estate tiles, combat actions)
let inline = TGInlineKeyboardMarkup(inlineKeyboard: [
    [TGInlineKeyboardButton(text: "Continue deeper", callbackData: "explore:continue")]
])
```

### Localization

```swift
let text = lingo.localize("welcome", locale: user.locale)
let greeting = lingo.localize("combat.hit", locale: user.locale,
                              interpolations: ["damage": damage])
```

Add a new language by creating `Localizations/<code>.json` and adding a case to `SupportedLocale` in `configure.swift`.

---

## 🔧 Configuration Reference

| Variable | Description | Required |
|----------|-------------|----------|
| `TELEGRAM_BOT_TOKEN` | Bot token from BotFather | Yes |
| `DB_HOST` | PostgreSQL host | Yes |
| `DB_PORT` | PostgreSQL port (default 5432) | No |
| `DB_USER` | PostgreSQL username | Yes |
| `DB_PASSWORD` | PostgreSQL password | Yes |
| `DB_NAME` | PostgreSQL database name | Yes |
| `PG_CONN_STR` | Full connection URL (alternative) | No |

Bot-level settings in `configure.swift`:
- `allowedUsers` — authorized IDs (remove for public access)
- `SupportedLocale` — enum of languages with flag emojis

---

## 📚 Dependencies

- **[Hummingbird](https://github.com/hummingbird-project/hummingbird)** — HTTP server (webhook / health endpoint)
- **[Fluent](https://docs.vapor.codes/fluent/overview/)** — ORM
- **[FluentPostgresDriver](https://github.com/vapor/fluent-postgres-driver)** — Postgres driver
- **[AsyncHTTPClient](https://github.com/swift-server/async-http-client)** — HTTP client for Telegram API
- **[swift-telegram-sdk](https://github.com/nerzh/swift-telegram-sdk)** — Telegram Bot API bindings
- **[swift-dotenv](https://github.com/thebarndog/swift-dotenv)** — `.env` support
- **[Lingo](https://github.com/miroslavkovac/Lingo)** — localization

---

## 🗺️ Roadmap

ROI targets **1,000–3,000 concurrent players** in a shared world. Version 1 includes the full game vision: exploration, combat (PvE + PvP), estates, territorial wars, guilds, dungeons, taming, and the capital city with arena.

See [**GDD.md**](./GDD.md) for systems detail, numeric tuning placeholders, and scope notes.

---

## 🙏 Acknowledgments

- The [Hummingbird](https://github.com/hummingbird-project/hummingbird) team
- [swift-telegram-sdk](https://github.com/nerzh/swift-telegram-sdk) by @nerzh
- The Swift Server Work Group for the ecosystem

*"Rest Of Iryna" is the working title; **ROI** is the persistent brand — the letters will find new meaning as the game grows.*
