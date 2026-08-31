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
   - `RegistrationController` — lore-driven onboarding (steps 0–7): language → **gender** (♂️/♀️ — drives Ukrainian feminitives + per-gender estate artwork) → Artanian welcome + name → class descriptions → King's Oath (grants class starter weapon) → rabid-dog encounter with class+gender-specific artwork → real CombatController **tutorial fight** against `enemy.rabid_dog` (wild-boar-level, no loot / no XP; only victory advances; defeat / flee / `/start` is a soft retry with full HP) → estate naming. "Done" is `User.registrationDoneStep` (= 7). First message and the post-fight estate prompt both ship `ReplyKeyboardRemove` so leftover button labels (mode picker / combat keyboard) can't be submitted as names. Nickname + estate-name inputs are validated against digits / Latin / Ukrainian Cyrillic, single internal spaces only, with five distinct error toasts (too short / too long / edge space / consecutive spaces / invalid character).
   - `MainController` — town hub / main menu with Explore / Inventory / Estate / Capital / Profile / Settings nav. The profile screen also carries the Phase 9.2 quest journal (`[📓 Нотатник]` under the 1/2/3 style buttons) — a read-only digest of today's NPC jobs that edits the same message in place.
   - `SettingsController` — language, preferences
   - `ExplorationController` — Phase 3.1/3.2/3.3. Tapping 🗺 Explore opens a **mode picker** `[🏃 Reconnaissance]` (active) / `[🏕 Expedition]` (passive) — the picker keeps the player in `MainController`'s routerName so tapping any main-menu button cleanly dismisses the picker and navigates normally (handled via the `EphemeralChatState` actor + `dismissPendingPicker` helper). **Active**: step-forward / step-back / bag / death, reply keyboard `[🚶 Step fwd] [🔙 Step back]` / `[🎒 Bag]`, three-tier visit-decay weights (fresh → reduced → bare). **Passive**: duration picker (30/60/90 units, seconds in test mode / minutes in prod), `PassiveExpeditionService` arms a Task.detached + live per-step loop, persists per-step outcome counters + loot totals on `state.running_report_json` so a bot restart resumes with the full event history, pushes a combined "🏰 back at estate" + `PassiveReport` message to the player's chat on completion (no Close button — state is auto-deleted), and exits early on death so the report lands immediately. Startup rescheduler in `configure.swift` re-arms any in-flight passive expeditions across bot restarts. Death (in either mode) wipes non-equipped inventory and respawns at HP=1 (vigor preserved).
   - `EstateController` — tree nav: Root (per-level artwork, tiers 1–3 drawn) → House (Workshop with real Phase 5.2 crafting; Kitchen with real Phase 5.2.1 cooking; Warehouse with real deposit/withdraw via `WarehouseService` — stackable types render as a 2-row card per item: an info button showing both counters (`[icon name · 🎒N / 📦M]`, tap opens a description modal) above a 3-button action row `[⬆️ +1] [⬇️ +1] [✏️ N]` where the third button opens a two-stage chat prompt — first picks direction (`[⬆️ To warehouse] [⬇️ To bag]` inline buttons), then edits in place into a quantity question; the player types a number and the bot routes through `WarehouseService.depositN` or `withdrawN` per direction (state lives in `EphemeralChatState.pendingWarehouseTransfer` with a nullable `Direction` field that nil-bumps to `.put` / `.take` on the direction tap); gear renders per physical row with a single-direction arrow since non-stackable items have no quantity to pick) / Plot. **Plot drill-down (Phase 5.1 + 2026-05-18 harvest destination picker)** lists all unlocked slots; each slot shows its production progress (e.g. `⛏ Slot 4 · Mine — 40/40 🪨 · 12/20 🔩` for the Mine plot's primary + bonus output). `[🚜 Slot N]` opens a destination picker (preview `+5 🪨, +1 🔩` + `[🎒 До сумки][📦 На склад][❌ Скасувати]`); on pick `PlotService.harvest(_:to:for:on:)` runs with the chosen `HarvestDestination`. Bag destination has atomic preflight (`InventoryEntry.slotsUsed + total <= slotCap`); on failure returns `.bagFull(primary:bonus:free:need:)` — yield stays on the plot for retry, picker stays on screen so the player can switch to warehouse with one tap. Success flashes a `✅ Slot N — yields, added to Bag 🎒 / Warehouse 📦` banner via `postStatusBanner` and refreshes the plot list. Empty plots short-circuit to the existing "nothing produced yet" toast — picker is suppressed. Empty slots show a `[➕ Slot N]` claim button that opens a 5-type picker (Farm / Lumberyard / Mine / Coop / Training Ground). The `🥋 Training Ground` plot routes a tap to a consequence-free fight against the Training Dummy (see CombatController). Successful deposits/withdraws emit a `✅ ...` status banner as a standalone message under the inline keyboard via `TGControllerBase.postStatusBanner` (the previous banner is auto-deleted so chat history carries only the latest); failures (nothing to move, backpack full) show a modal alert. **Workshop crafting (Phase 5.2)** opens a compact recipe list (one inline button per recipe, grouped by category through declaration order); tapping a recipe opens its detail screen (description + `📜 Recipe` inputs + `📊 Stats` for gear outputs + `[🔨 Craft]` / `[🔙 Back]`). Craft calls `CraftingService.craft` which drains inputs from the combined inventory + warehouse pool (inventory first to free backpack slots) and deposits the output into the inventory; success posts a `✅ Crafted ...` banner as a standalone message under the inline keyboard via `postStatusBanner`, shortages and bag-full surface as modal alerts. Five recipes ship: Iron Ingot (Forge) + Forester's Hood / Jerkin / Breeches / Boots (Tannery). **Weapon upgrade (Phase 5.2.2)** sits as a fixed `[⚔️ Upgrade weapon]` button at the top of the Workshop list — universal because every player has exactly one upgradable weapon (their class starter, granted by the King at registration). Tapping opens a dedicated detail screen showing current tier name + stats, an arrow `⤴`, the next tier preview with stat deltas, a `📜 Materials` block (with have/need indicators), and a green-or-red estate-level requirement line. Upgrade calls `WeaponUpgradeService.upgrade` which gates on `user.estateLevel >= nextTier`, drains materials from the combined inventory + warehouse pool, and bumps `InventoryEntry.tier` on the same row — item id never changes, the weapon "grows up" in place. Three weapons × 5 tiers each (Rusty Sword → Knight's Sword for warriors, Simple Bow → Hunter's Longbow for archers, Wooden Staff → Archmage's Scepter for mages); T1 stats match the legacy `Item.gearStats` so unmigrated DBs see no number change. Display names are tier-aware via `ItemDisplay.nameKey(for:tier:)` in the profile main-hand line, inventory gear rows, and the upgrade screen. Tiered weapons cannot be deposited to the warehouse (`WarehouseService.deposit` returns `notTransferable`) since the warehouse table doesn't carry a tier column. **Kitchen cooking (Phase 5.2.1)** mirrors the Workshop UI but the recipe list is gated by the union of always-available starters (`RecipeCatalog.starterRecipeIds` — Baked Potato + Roasted Meat, cookable from day one with no DB row) and the player's scroll-learned set (`LearnedRecipe` rows added via the inventory's `📖 Learn` action on `artifact.recipe.<dish_id>` scrolls). The detail screen shows a `📊 Effects` section (Vigor / HP) instead of Stats; the action button reads `🍳 Cook`, success banner reads "Cooked ..." (vs Workshop's "Crafted ..."). Every recipe also burns 1× 🪵 `mat.pine_lumber` for the cooking fire — narrative authenticity + soft farm-cooking cap. Seven dishes ship: Baked Potato / Roasted Meat (always available) + Forager's Omelette / Hunter's Stew / Meat Ragout / Forest Berry Tart / Governor's Feast (scroll-locked). **Phase 5.3c — Estate gates + manual estate upgrade:** Estate level is now a stored `User.estateLevel` field (not derived from `user.level` anymore). The Estate root carries a fixed `[🏠 Upgrade estate]` button that opens a detail screen with the current tier name, next tier preview, player-level requirement (✅/⛔), `📜 Materials` block with have/need from the combined inventory + warehouse pool, and — for T3+ transitions — a `🪙 silvers` line drained from `User.silver` (the field was renamed from `gold` on 2026-05-18, see `RenameGoldToSilver` migration). `EstateUpgradeService.upgrade` validates max-tier / player-level / silver / materials in order and surfaces every failure as a modal alert; success bumps the stored tier and refreshes the screen with a `✅ Estate raised to tier N — Name` banner. Six transitions in `EstateUpgradeCatalog` (T1→T2 … T6→T7) with player-level gates 4/7/10/13/16/19 and material costs scaling from ~33 units (cheap onramp) to ~313 units + 1000🪙 (endgame milestone). Silver has no item id (lives on the User row, not in a backpack slot) so it never appears in the inventory or warehouse. Same upgrade lets the **rooms** in the manor open in stages: T1 shows only Warehouse, Kitchen unlocks at T2, Workshop at T3, Tannery sub-category at T4. The Training Ground plot type unlocks at estate T3, before that the plot picker shows only Farm/Lumberyard/Mine/Coop. Plot slot count by tier: `[0, 1, 2, 3, 4, 5, 6]` — T1 has zero slots; the first slot opens at T2. Warehouse capacity also grows with tier — per-unit caps `[200, 400, 600, 800, 1200, 1600, 2000]` since the 2026-05-12 per-unit slot pivot (was `[50, 100, 150, 200, 300, 400, 500]` per-row). Weapons still gate on `user.estateLevel >= nextTier` for upgrades. **Phase 5.3d — Bag upgrade in Workshop**: second universal button `[🎒 Upgrade bag]` next to the weapon upgrade. Detail screen mirrors the weapon flow — current tier name + slot capacity, next tier preview with `+delta` slots, estate-tier gate (✅/⛔), `📜 Materials` block with have/need from the combined pool, `[🧵 Sew]` confirm. Six bag tiers (Linen Sack 25 → Leather Bag 35 → Reinforced Backpack 45 → Hunter's Pack 60 → Master's Knapsack 80 → Grandmaster's Pack 85) with hide + iron costs scaling per tier; T6 craft gates on estate T7 (Lord's Holdings). `BagUpgradeService` validates max-tier / estate-gate / materials and bumps `User.bagTier`. Materials only — no gold cost on the bag track. **Slots count per-unit since 2026-05-12** — every carried unit takes a slot, so `flour × 8` costs 8 of the bag's 25. Same rule applies to the warehouse. `User.isDeveloper` (Telegram id ∈ `developerUsers`) bypasses both caps entirely — counts still show in the UI, blocks are skipped. **Phase 5.3e — Training Ground learn flow**: tapping a Training Ground plot now opens a dedicated screen with per-kind technique status (✅ learned / 📖 learnable button / 🔒 locked w/ level hint) plus `[🥋 Spar]` and `[🔙 Back]`. The `[📖 Learn X]` button writes a `LearnedTechnique` row (class-agnostic `special_atk` / `special_def` / `super` IDs) and refreshes with a `✅ Learned X` banner. `[🥋 Spar]` spawns the dummy fight as before. **2026-05-18 inventory pstyle forwarding**: `EstateController.onCallbackQuery` + `InventoryController.onCallbackQuery` now forward unknown callbacks (e.g. `pstyle:` profile-style switcher tapped while in estate/inventory routerName) to `MainController.onCallbackQuery` instead of returning false — quiet handling instead of "Unsupported content type."
   - `CapitalController` — Phase 6.0 + 6.1 + 6.2 + 6.4 + 6.5 + 2026-05-18 trader rebuild. Travel-gated city hub reached from the estate via a 2-minute trip handled by `TravelService` (in-memory `TravelState` row, `Task.detached` timer, `User.location` flips on arrival, `rescheduleInflight` survives bot restarts). Reply-keyboard with 6 location buttons (Market / PvP Arena / Trader / Fortune Teller / Master / Tavern) + utility row [Inventory] [Profile] + 🏡 Back-to-estate. Welcome screen sent as photo (`Assets/capital/welcome.jpg`) + atmospheric lore caption when the trip arrives. Estate / Capital / Explore taps during travel show a countdown banner; taps from the capital onto Explore are blocked ("wilderness only borders the estate"); Estate-tap from capital starts the return trip. **Trader** UX rebuilt 2026-05-18 from 2-row info+action to a single button per item, plus Food/Materials category split inside Buy/Sell so the player drills `Trader entry [💰 Купити][💸 Продати] → category picker [🥩 Їжа][🪨 Матеріали] → filtered item list [<icon> <name> · 🪙 <price>]` (sell side adds `🎒 <qty>`). Tapping any item button opens the bulk-N "How many?" prompt directly (item descriptions intentionally not surfaced inside the trader — Inventory drill-down still has them). 11 listings from `TraderCatalog` priced per-unit at 1🪙/2🪙/3🪙/5🪙/10🪙/100🪙 sell with flat 2× sell:buy spread. Bulk prompt routed via `EphemeralChatState.PendingTraderTransfer` + `unmatched` text intercept; post-action refresh derives the category from `ItemCatalog.find(itemId)?.type` so the player stays on the same screen. **Tavern (Phase 6.2)**: button-driven Menu / Dice / Darts; menu sells all 7 cooked dishes (20-200🪙) bypassing recipe scrolls; gambling uses `bot.sendDice` with text labels between pairs since Telegram doesn't let bots author messages as the player. Wager flow: tap stake → "Готовий?" + `[🎲 Кинути кубики][❌ Скасувати]` (no silver debited yet — free cancel) → tap Roll debits + runs the sequence: player label + N dice (2 for dice, 1 for darts) → sleep 4s → house label + N dice → sleep 4s → result message with `[🔄 Зіграти ще раз][🔙 До шинка]`. Each round's messages (labels + dice + result) are recorded via `TavernCleanupService.record` and swept away once they age past 24 h — Telegram blocks deleting a private-chat dice message younger than that, so the round lingers as game history until then. **Fortune Teller (Phase 6.4)**: tarot draws of the 22 Major Arcana for a 6-hour buff. Tap pays 10🪙, draws one card uniformly, applies effects (stat additive bonuses + xp/loot/vigor-drain multipliers + one-shot silver/HP/Vigor/XP / Wheel-style 50/50 random), shows the card art (`Assets/capital/fortune/<id>.png`) with name + lore meaning + buff description + 6h countdown. Cooldown between draws is 24h (split from buff window via separate `lastFortuneDrawAt` field). UI handles 3 states: can-draw / cooldown-with-buff (active card + dual timer) / cooldown-only. Active fortune line surfaces in profile (`🔮 <Card> · HH:MM`) across all 3 profile styles. Effects compose into User.effectiveAttack/Defense/Crit/Dodge/Accuracy + User.grantXP + ExplorationService.rollStep (loot weight) + VigorService.drain (drain multiplier). Inline `[🔙 До столиці]` button always present on entry + reveal. **Master (Phase 6.5, expanded 2026-05-22)** — the game's first real silver sink. Entry `[🛡 Buy][⚒️ Repair][✨ Improve]`. **Buy** sells the Forester set ready-made at premium prices (set 485🪙 ≈4× material value, `MasterCatalog.armorForSale`) — the lazy/no-stock path; crafting it (now 40🦴 + 8🔩 iron) stays the economical one. **Durability**: armor + the main-hand weapon carry `durability`/`maxDurability` on `InventoryEntry` (`AddGearCondition` migration; armor max 30, weapon max climbs by tier 30→100 via `WeaponUpgradeCatalog.durabilityByTier`). Each fight spends a wear *budget* (win 1 / loss 3 / flee 5 — model C) point-by-point across the shared armor+weapon pool via `GearConditionService.drainEquippedGear` (active `CombatController` + passive `PassiveExpeditionService`). At 0: **armor is broken** (0 stats), the **weapon keeps half its stats** (lore: the King's weapon can't break) — both via `EquipmentService.contributedStats`. **Repair**: armor restores to (max−1) at ≈½ buy price (slow wear→rebuy); the weapon restores to full at a flat 1🪙/point with **no** max shave, under a class-flavoured button (🗡 Sharpen blade / 🏹 Restring bow / 🔮 Re-empower staff). **Enchant** (armor) adds a flat +DEF *plus* a class-identity stat (⚔️ +DEF / 🏹 +dodge / 🔮 +crit), both scaling on a non-linear point curve (`MasterCatalog.enchantBonusPoints` 1/2/3/5/8), cap raised +3→**+5**, escalating silver + hide. All run through `MasterService` (typed result enums). The repair banner reads `(cur/max)`. Every buy/repair/enchant tap first opens a **confirm prompt** (`✅ Yes` / `❌ No`, restating item + cost) to guard against accidental taps — `master:*ok:` callbacks run the action, `No` returns to the list; list buttons stay terse (buy keeps the price for comparison, repair shows durability, enchant the level step). **2026-05-21**: capital result banners no longer carry an inline `[🔙 До столиці]` button (`backToCapitalBannerKB` removed) — the persistent capital reply-keyboard is always visible, so a banner is just `✅/❌ text`. `onCallbackQuery` forwards unknown callbacks (`pstyle:`, stale `explore:` / `combat:`) to `MainController.onCallbackQuery` instead of returning false — quiet handling instead of "Unsupported content type." **Market (Phase 6.5, 2026-05-28)** — the first player-to-player feature. `onMarket` opens `showMarket` (photo + silver + active-lot count + `[🛒 Buy][🏷 Sell]` / `[📦 My lots]` / back). Listing accepts only **stackable** items (gear excluded) and **escrows** the units off the seller's bag onto a `MarketListing` row, charging a flat `MarketCatalog.listingFee` (5🪙, non-refundable — the silver sink). The buy board is **item-grouped two-level**: Level 1 one row per distinct item (`<item> · lots: K · from 🪙U`, via `MarketListing.itemSummaries` excluding own), tap → Level 2 that item's lots **cheapest-per-unit first** (`×N · 🪙total (🪙U/ea) · @nick`) → confirm → buy. Buying (`MarketService.buyListing`) debits the buyer, credits the seller, delivers the items, deletes the lot, and pushes the seller a "sold" notification (fire-and-forget, PlotProductionService pattern); a raced double-buy surfaces as "already sold". Selling is a two-prompt flow (quantity → price, fee shown in the price prompt) via `EphemeralChatState.PendingMarketListing` + `unmatched` text intercept; My-lots cancels with one tap (`cancelListing` returns the units, fee kept). `Assets/capital/market.jpg` isn't supplied yet → `sendCachedPhoto` text fallback (drop the art in later, it auto-caches). **Trade / Обмін (Phase 6.5, 2026-06-10)** — a synchronous MMO-style player-to-player exchange reached via the Market's `[🤝 Обмін]` button, driven by the in-memory `TradeStore` actor + `TradeService` atomic swap (see those files below). Flow: presence lobby → invite → accept → both bags open (toggle stackables/gear + `[🪙 Срібло]`) → stage-1 `[✅ Погодити]` → combined-offer screen → stage-2 `[✅ Підтвердити обмін]` → commit; gear travels as the exact `InventoryEntry` row (enchant/durability/tier preserved), bound starter weapon excluded. **2026-06-15 post-playtest polish:** the whole feature is the "Базар" (uk renamed Ринок→Базар); `mutateBuilding` resets only the editor's ready-flag so each player taps «Погодити» once even while the partner keeps editing; a successful trade posts a permanent per-side "gave/got + with-whom" record at the bottom of the chat as history; transient numeric input prompts delete on submit while banners + the record stay. **Guildhall (Phase 7.1):** a `🏰 Гільдії` reply button sits on the capital keyboard; tapping it flips `routerName` to `"guild"` and hands off to `GuildController` (full controller, not an inline sub-flow — see its entry above), with `guild.button.back` returning to the capital screen. The one remaining stub (Arena) auto-loads `Assets/capital/<id>.jpg` if present via `renderLocation`. Phase 8.3 added the Arena entry (hands off to `ArenaController`), and Phase 9.2 put a `[📜 Замовлення]` quest board on the Trader / Master / Innkeeper menus — one auto-assigned job per NPC per game day, turned in or claimed right there.
   - `InventoryController` — tree navigation; root shows all 5 category buttons with counts plus a fullness indicator (`X/Y slots` where `Y` reads from `User.bagTier` via `BagCatalog.capForTier`); drill-down renders each item as an inline button plus a type-specific action. Tapping a non-gear item opens a lore modal; tapping **gear** opens a full HTML **detail card** sent as its own message (Phase 6.5, 2026-05-22) — name (+tier for weapons), lore, full-condition stats (tier-aware; armor folds in the enchant + class bonus via `EquipmentService.nominalStats`), and a condition block (`Durability dur/max`, a broken/dulled warning at 0, enchant level). Food/potion consume via VigorService; gear is shown per-row (each physical unit is its own button, no `× N` aggregation) and toggles between 🛡 Equip / ❌ Unequip via EquipmentService, with a persistent per-item icon via `Item.icon`; artifact placeholder until TBD. Gear-row labels stay clean — only a plain `+N` enchant suffix (no icon); durability lives in the detail card and the Master repair screen, not crammed into the button. **Phase 5.3d + per-unit pivot (2026-05-12)** — bag slot cap is per-user, starting at 25 (T1 Linen Sack) and reaching 85 at T6 (Grandmaster's Pack) through Workshop upgrades via `BagUpgradeService`. Each carried unit takes a slot (so `hide × 6` is 6 of those slots — used to be 1 row pre-pivot). Existing rows beyond the new cap stay readable; the limit only blocks new inserts past the limit (same policy as the warehouse cap). Developer accounts (`User.isDeveloper`) bypass the cap entirely — counts still show in the UI (`60/25`), inserts are not refused. Action acknowledgments (eat, equip, unequip) post as a standalone `✅ ...` banner under the inline keyboard via `postStatusBanner` — chat carries only the latest banner since each new one deletes the previous; warnings (raw food, full backpack, empty category, etc.) appear as Telegram modal alerts the player has to dismiss with OK — neither uses the narrow top-strip toast.
   - `CombatController` — Phase 4.1 + 4.2 + 4.3.1 + 2026-05-18 round counter — turn-based PvE duel triggered when active-mode `rollStep` rolls an encounter, plus a Phase 5.1 Training Mode for the estate's Training Ground plot. The status card surfaces a `🌀 Раунд N` line once the player has taken at least one action (encounter intro stays clean) — counter lives in `ExplorationState.combatRound` (nullable Int), bumped in `finishRound` before render, cleared by `endCombat`. **Combat is reply-keyboard driven (2026-05-27 switch from inline):** the main keyboard `[Attack][Defend] / [🪄 Techniques][Flee]` is a `TGReplyKeyboardMarkup` that REPLACES the player's previous keyboard (exploration's, or none during registration) for the duration of the fight and is restored to the prior controller's keyboard on victory / flee / death. Actions are matched by button text (registered per class × locale in `attachHandlers`, like exploration's `[Step]/[Bag]`), with class-flavoured labels (warrior = Slash / Parry / Retreat; archer = Arrow / Maneuver / Hide; mage = Magic / Barrier / Teleport). Free-form text gets a one-line `combat.in_progress` nudge via `unmatched`. A legacy `callback_query` handler stays only to gracefully recover inline combat buttons lingering in chat history from before the switch. Tapping `[🪄 Techniques]` sends a fresh message with a class-flavoured sub-keyboard — Special Attack / Special Defense / Super stance — listing **only the techniques usable right now** (learned AND with uses left); a `[🔙 Back]` row returns to the main keyboard. Remaining uses (`× N`) show in the message body, not the button label (labels stay static so text routing matches). **Phase 5.3e** gates each kind behind `LearnedTechnique`; unlearned / spent techniques are simply hidden (no `🔒` button), and when none are usable the menu re-sends the main keyboard with a `combat.tech.none_available` note. The per-fight budget itself is per-user-level via `CombatService.initialUses` — 1/1/1 early, bumping to 2 at L17/L20/L21 per kind. Phase 4.2 techniques: warrior (🪓 Cleave / 🏰 Iron Bulwark / 🩸 Bloodlust), archer (🎯 Vital Shot / 🌑 Shadow Veil / 🦅 Hawk's Eye), mage (🔥 Soulfire / 🪞 Mirror Ward / ✨ Arcane Resonance). Stance + special-atk + special-def modifiers all compose into the same `CombatService.applyAttack` primitive; vigor drains scale by stance multiplier; persistent effects (Iron Bulwark armor-split next swing, Shadow Veil lingering +50 dodge) tick down via `tickDefenseEffects()`. Basic Attack (−2 vigor) runs `applyAttack` both directions; basic Defend (−1) branches by class (`CombatService.Defend` namespace): warrior chip-damages 30% × ATK and doubles effective DEF for the round (canonical parry), archer chip-damages 15% (knife flick while hiding) and gets `+30 dodge` for the round with single DEF, mage skips chip entirely and the landed enemy hit is multiplied by `0.4` (60% damage reduction) — stronger mitigation than warrior to compensate for zero return damage; Flee (−3 base) uses class-specific success chances via `CombatService.fleeChance(forClass:)` — warrior 40% / archer 70% / mage 90%, with mage paying +2 vigor for the teleport. Failure triggers a forced full-damage counter. Victory awards loot via `ExplorationService.awardEncounterDrops` and hands the player back to ExplorationController at the same km; defeat shares `handleDeath`. The same controller also drives the registration tutorial fight (rabid dog) — `Registration.handleCombatEnd(won:)` routes back into the registration flow when `session.registrationStep < User.registrationDoneStep`. **Training Mode** (entered from the Training Ground plot): clean damage on player swings (`cannotMiss = true`, enemy DEF treated as 0), no vigor drain, no enemy counter, dummy auto-revives on HP 0. Since combat now owns the reply keyboard, `handleTrainingSpar` flips `routerName` to `"combat"` (like a real fight) so the combat keyboard's text buttons reach this controller; `[Flee]` is replaced with `[🚪 Exit]` (`combat.button.training_exit`), and `onTrainingExit` restores `routerName = "estate"` plus the main reply keyboard (attached to the exit banner) before re-rendering the Plot list. **Phase 5.3a XP-on-victory landed**: `finishVictory` calls `user.grantXP(enemy.xpReward)` (per-tier table on `Enemy` — 5/12/25/50/100/175 across T1–T6, training dummy = 0) and appends `📊 +N XP` / `🎉 Level N!` / `🏰 Estate tier N!` banners to the victory message; registration tutorial fight skips the grant (still narrative-only). **Phase 5.3e**: `beginCombat` takes per-fight uses derived from the player's level via `CombatService.initialUsesForUser`, and the technique handlers defensively re-check `LearnedTechnique.has` before executing — stale callbacks for unlearned kinds get the same `combat.tech.locked` alert as the submenu buttons. Per-enemy AI hooks, status effects (rabies), and combat log persistence live in the `Future / Backlog` section of `TODO.md`.
   - `GuildController` — Phase 7.1 (Guilds). Reached from the capital's `🏰 Гільдії` reply button, which flips `routerName` to `"guild"` (this controller then owns the reply keyboard, like CombatController). Top-level nav is a membership-branched reply keyboard — guildless: `[➕ Found][📜 List]` / `[🔙 Capital]`; in-guild: `[👥 Members][🏦 Vault]` / `[🪙 Treasury][⚙️ Manage]` / `[🔙 Capital]`. Drill-downs use inline buttons + text prompts via `EphemeralChatState.PendingGuildInput`. Features: **found** (silver sink `GuildCatalog.foundCost` 500🪙 + player-level gate 5; tag left empty, the game creator assigns it manually via DB to avoid bad abbreviations — the name prompt tells the player to message `@TGUserName`), **invite** (leader/officer → nickname/@username prompt → push notice; invitee accepts/declines from the guildless home invites list), **roster** (role-sorted, 👑/🎖/🧑 badges), **kick / promote / demote** (leader manages officers+members, officers kick members only; officer cap 2), **leave / disband** (leader must disband), **item vault** (`🏦` — stackables only, deposit any member / withdraw leader+officers, `vaultUnitCap` 3000), **silver treasury** (`🪙` — deposit any member / withdraw leader+officers, the existing `Guild.treasury` field). All transactions in `GuildService` (typed result enums); cross-player notices are fire-and-forget pushes.
   - `ArenaController` — Phase 8.3 (Ристалище). Entered from the capital's `⚔️ Ристалище` button, which flips `routerName` to `"arena"` so the controller owns the reply keyboard for the duration. Real-time turn-based PvP duel: `ArenaStore` (in-memory actor holding lobby presence, pending challenges and live duels) rolls the dice inside the actor so roll and HP mutation stay atomic; `ArenaService` does the DB side (match validation, Honor ELO, stake settlement with the Crown's tithe as a silver sink). Daily fight budget resets on the `GameDay` boundary.
   - `GlobalCommandsController` — `/help`, `/settings`, `/buttons`, `/menu` (works from any state). `/menu` is registered as a discoverable alias for `/buttons` (same handler) — added 2026-05-18 alongside `bot.setMyCommands(...)` at startup so the commands surface in Telegram's hamburger menu (the ≡ button left of the input field). Discoverable escape hatch for stuck players + cross-device kb mismatch (player opens chat on phone with stale estate buttons while their routerName moved to capital).
3. **Context** — passed to every controller; holds the bot instance, DB handle, localization (Lingo), user session, and parsed command arguments.

---

## 📁 Project Structure

> **Content is data.** Since the pre-release rebalance the game's rosters live in
> `content/data/*.json`, not in Swift arrays — the `*Catalog` types are façades
> over a validated snapshot loaded at boot. See `.memory/content-pipeline.md`.

```
Modules/                          # Content pipeline (Foundation-only — no Fluent, no Telegram)
├── ROIContent/                   # DTOs · ContentLoader · ContentValidator · GameData snapshot · LocaleIndex
├── ROISim/                       # The combat/progression/budget MATHS (CombatMath · ProgressionMath · BudgetMath)
│                                 #   + EnemyGenerator · FightSimulator · the balance report · SplitMix64
└── roi-content/                  # CLI — `swift run roi-content validate [--strict]`
                                  #       `swift run -c release roi-content simulate [--strict]`

Tests/ROIContentTests/            # 222 tests; fast, since Fluent/Postgres/Telegram are out of this graph

content/data/                     # SOURCE OF TRUTH for game content
├── manifest.json                 # schemaVersion · contentVersion
├── items.json · enemies.json (+ archetypes) · recipes.json
├── rarities.json · sets.json
├── weapon_upgrades.json · bags.json · estate_upgrades.json
├── trader.json · tavern.json · market.json · guild.json · arena.json
├── master.json · plots.json · fortune.json · quests.json
└── tuning/                       # BALANCE, separate from content
    └── combat · vigor · exploration · progression · economy · time · budget
```

> **Balance lives in `content/data/tuning/`.** Hit chance, the absorption curve, the XP
> curve, Vigor costs, gear wear and every duration are data, not constants. The item stat
> budget (`budget(itemLevel, slot, rarity)`) bounds every equippable piece, and the
> validator refuses an overspend — which is what makes adding items safe rather than a
> slow power creep. `swift run RestOfIryna --content-digest` prints four live checks,
> including the design's reference character rebuilt from the budget.
>
> **`swift run -c release roi-content simulate` measures those tables.** It rolls the
> same `CombatMath` the bot calls over levels × archetypes × classes × play profiles ×
> gear offsets and reports time-to-kill, the p90 tail, pace to the level cap and the
> shipped bestiary against its own archetype contract. The digest says what moved; the
> simulator says whether the move was survivable.
>
> Dev-only `/reload` hot-swaps the bundle without a restart (`parse → validate →
> live-check → build → install`; a refusal leaves the running game untouched). Locale
> strings are the exception — those still need a restart.

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
│   │   ├── CombatController.swift        # Phase 4.1 + 4.2 turn-based PvE duel — Attack/Defend/Flee + [🪄 Techniques] submenu (Special Atk / Special Def / Super) with per-fight budget; registration rabid-dog tutorial fight
│   │   ├── EstateController.swift        # Phase 5.0 skeleton: Root → House (room stubs) / Plot stub; per-level artwork
│   │   ├── CapitalController.swift       # Phase 6.0–6.5 — travel-gated hub; Trader (buy/sell + ✏️ N) + Tavern (food + dice/darts) + Fortune Teller + Master (armor buy/repair/enchant) + Market/Базар (player-to-player listings + 🤝 Trade); 1 stub left (Arena)
│   │   ├── InventoryController.swift     # tree nav root → category; inline Use/Eat/Equip action buttons
│   │   ├── GuildController.swift         # Phase 7.1 — capital Guildhall (routerName "guild"): found/invite/roster/kick/promote/demote/leave/disband + item vault + silver treasury
│   │   └── ArenaController.swift        # Phase 8.3 — capital Arena (Ристалище), routerName "arena": lobby challenge, real-time turn-based duel, Honor ELO, daily fight budget on the GameDay boundary
│   │
│   ├── Models/                   # Fluent ORM models + catalog façades (roster data lives in content/data/*.json)
│   │   ├── User.swift
│   │   ├── Item.swift            # Item/GearStats types + ItemCatalog façade + ItemDisplay (roster in content/data/items.json; `EquipmentSlot` moved to ROIContent in rebalance Phase 8) — Phase 5.2 added the Forester's leather set; Phase 5.2.1 added 7 cooked dishes + 5 recipe scrolls + Item.teachesRecipe field
│   │   ├── Recipe.swift          # Recipe types + RecipeCatalog façade (roster in content/data/recipes.json) (RecipeCategory forge/tannery/kitchen, RecipeIngredient, RecipeOutput, Recipe, RecipeCatalog) — Phase 5.2 + 5.2.1. Phase 6.5 (2026-05-22) raised the Forester set cost + added iron (40🦴 + 8🔩 for a full suit) to track the premium Master prices
│   │   ├── LearnedRecipe.swift   # Phase 5.2.1 — Fluent model: per-user scroll-learned-recipe set (user_id, recipe_id, learned_at). has/add/allIds helpers; always-available starters live in RecipeCatalog.starterRecipeIds, not here
│   │   ├── LearnedTechnique.swift # Phase 5.3e — Fluent model: per-user known-technique set (user_id, technique_id, learned_at). IDs are class-agnostic (`special_atk` / `special_def` / `super`); player's class resolves the concrete technique in combat. has/add/allIds mirror LearnedRecipe.
│   │   ├── InventoryEntry.swift  # per-user item stacks in the backpack (DB) + helpers. Phase 6.5 added gear `durability`/`max_durability` (init stamps 30; weapons get their per-tier ceiling 30→100) + `enchant_level` (armor, cap 5) columns
│   │   ├── WarehouseEntry.swift  # per-user estate storage (separate table from inventory) + remove helper (Phase 5.2)
│   │   ├── ExplorationState.swift # one row per expedition — active or passive (user_id unique, stepsDeep, mode, ends_at, report_json, running_report_json, visited_rooms)
│   │   ├── Enemy.swift           # Enemy types + EnemyCatalog façade (roster in content/data/enemies.json) — 7 wilderness animals + 2 non-exploration mobs (training_dummy, rabid_dog tutorial fight); reference doc at content/bestiary.md
│   │   ├── Plot.swift            # Phase 5.1 — Fluent model for estate plots (user_id, slot_index, plot_type, tier, last_harvested_at, notified_full)
│   │   ├── PlotCatalog.swift     # Phase 5.1 — code-based plot type config (Farm / Lumberyard / Mine / Coop / TrainingGround), per-tier rate + cap, Mine bonus output (iron)
│   │   ├── WeaponUpgradeCatalog.swift # Phase 5.2.2 — per-weapon tier ladder (3 weapons × 5 tiers, stats + materials); ItemDisplay namespace lives in Item.swift. Phase 6.5 (2026-05-22) added `durabilityByTier` [30,40,50,70,100] + `durability(forTier:)` — weapon durability ceiling climbs with tier
│   │   ├── EstateUpgradeCatalog.swift # Phase 5.3c — estate-tier progression (6 transitions T1→T2 … T6→T7, player-level gates 4/7/10/13/16/19, materials + gold cost for T3+)
│   │   ├── BagCatalog.swift      # Phase 5.3d — bag tier ladder (6 tiers: 25/35/45/60/80/85 slots since 2026-05-12 per-unit pivot — was 5 tiers 20/30/40/55/75), estate-tier gates per step, hide + iron materials only
│   │   ├── TravelState.swift     # Phase 6.0 — Fluent model: per-user in-flight trip between estate and capital (user_id unique, destination, ends_at)
│   │   ├── TraderCatalog.swift   # Phase 6.1 + v2 economy rebase — 11 trader listings, per-unit pricing (1g/2g/3g/5g/10g/100g sell), flat 2× sell:buy spread
│   │   ├── TavernCatalog.swift   # Phase 6.2 — 7 cooked-dish prices (20-200g), shared wager tiers [10, 25, 50] for dice + darts
│   │   ├── FortuneCatalog.swift  # Phase 6.4 — 22 Major Arcana tarot cards. `FortuneEffect` struct with 14 optional fields (stat bonuses, multipliers, one-shots, Wheel random). drawPrice 10g, buffDurationSeconds 6h, cooldownSeconds 24h. assetPath(for:) → Assets/capital/fortune/<id>.png
│   │   ├── TavernGameMessage.swift # 2026-05-20 — Fluent model for the 24h tavern-clutter cleanup (telegram_id, message_id, created_at; no User FK). One row per chat message a dice/darts round leaves; TavernCleanupService deletes them once >24h old (Telegram blocks deleting private-chat dice younger than that).
│   │   ├── MasterCatalog.swift   # Phase 6.5 — the Master's shop economics (premium armor buy prices ≈4× material value, armor repair formula, weapon repair 1🪙/point, enchant steps + cap 5, `enchantBonusPoints` non-linear curve 1/2/3/5/8). Pure data; durability runtime lives in GearConditionService.
│   │   ├── MarketListing.swift   # Phase 6.5 — Fluent model: one live player-to-player lot (seller_id, item_id, quantity, price, created_at). unitPrice computed; read helpers (allActive/forSeller/forItem/find/activeCount/itemSummaries for the item-grouped board). Escrow lives on the row.
│   │   ├── MarketCatalog.swift   # Phase 6.5 — Market tuning constants: listingFee 5🪙 (flat silver sink), maxActiveLots 5 (per seller). Pure data.
│   │   ├── Guild.swift           # Phase 7.1 — Fluent model: one guild (name unique, tag [admin-assigned, may be empty], emblem, leader_id, treasury silver, motto). Read helpers: find/named(ILIKE)/all/members/memberCount/officerCount.
│   │   ├── GuildCatalog.swift    # Phase 7.1 — tuning (memberCap 20, maxOfficers 2, foundCost 500🪙, foundLevelGate 5, nameMin/Max 3/24, vaultUnitCap 3000) + GuildRole enum (leader/officer/member; canManageMembers/canWithdrawVault). Pure data.
│   │   ├── GuildInvite.swift     # Phase 7.1 — Fluent model: pending (guild, invitee, inviter) invitation. Helpers: find/forInvitee/exists/clearAll. Deleted on accept/decline.
│   │   ├── GuildVaultEntry.swift # Phase 7.1 — Fluent model: shared guild item storage (guild_id, item_id, quantity). Mirrors WarehouseEntry; stackables only. add/list/totalQuantity/totalUnits/remove.
│   │   ├── ArenaProfile.swift    # Phase 8.3 — Fluent model: one row per fighter (honor, wins, losses, fights_today + day stamp). Lazily created on first Arena visit
│   │   ├── ArenaCatalog.swift    # Phase 8.3 — Arena tuning: stake tiers, Crown's tithe %, starting Honor, ELO K-factor, league thresholds
│   │   ├── QuestCatalog.swift    # Phase 9.2 (2026-08-23) — daily-quest content: QuestNPC (trader/master/tavern), QuestCounter (beastKill/ironIngotForged/gambleWin/traderSilver), QuestObjective (.deliver/.counter), QuestReward, QuestDef, 3 jobs per NPC. `daily(npc:userId:stamp:)` assigns the day's job via a stable FNV-1a hash — derived, never stored, restart-proof
│   │   └── QuestProgress.swift   # Phase 9.2 — Fluent model: one row per (player, NPC, game day) — npc, quest_id, day_stamp, progress, claimed. Stores only progress; which job it is comes from QuestCatalog. Rows are never deleted (free history for future streaks)
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
│   │   ├── CreateTravelState.swift         # Phase 6.0 — travel_state table (user_id unique FK cascade, destination, ends_at). Presence = en route.
│   │   ├── AddFortuneFields.swift          # Phase 6.4 — adds nullable active_fortune_card_id + active_fortune_expires_at (6h buff window expiry) on users.
│   │   ├── AddFortuneCooldownField.swift   # Phase 6.4 split-fix — adds nullable last_fortune_draw_at, separating the 24h draw cooldown from the 6h buff window.
│   │   ├── RenameGoldToSilver.swift        # 2026-05-18 currency rename — raw SQL `ALTER TABLE users RENAME COLUMN gold TO silver`. In-game name became `silvers` / `срібники`; existing balances survive untouched. Reverse migration flips it back. Historical `AddGameStats` left intact (never edit history).
│   │   ├── AddTutorialTraderHint.swift     # 2026-05-18 polish — adds bool `tutorial_trader_hint_shown` (default false) on users. Flipped to true on the first clean `ExplorationController.handleHomeReached` so the one-shot "there's a Trader in the Capital" tip fires exactly once per player.
│   │   ├── AddCombatRound.swift            # 2026-05-18 — adds nullable `combat_round` (Int) to `exploration_state`. `beginCombat` sets to 0; `finishRound` bumps before render so the first action surfaces `🌀 Раунд 1` in the status card; `endCombat` clears.
│   │   ├── CreateTavernGameMessages.swift  # 2026-05-20 — tavern_game_messages table (telegram_id Int64, message_id Int, created_at; no FK — flat sweep query). Backs the 24h tavern dice cleanup.
│   │   ├── AddGender.swift                  # 2026-05-21 — nullable `gender` (string, "m"/"f") on users. Chosen at registration step 1; drives uk feminitives + per-gender estate art. Nil-safe (male); dev-reset clears it.
│   │   ├── AddGearCondition.swift            # 2026-05-21 — `durability` + `max_durability` (default 30) + `enchant_level` (default 0) on inventory. Backs the Master's repair/enchant + combat wear. Phase 6.5 expansion (2026-05-22) reuses these columns for weapons too (per-tier max, half-stats at 0); no schema change.
│   │   ├── CreateMarketListings.swift        # Phase 6.5 (2026-05-28) — `market_listings` table (seller_id FK cascade, item_id, quantity, price, created_at). Backs the player-to-player Market; lot cap enforced in MarketService, not the schema.
│   │   ├── CreateGuilds.swift                # Phase 7.1 — `guilds` table (name unique, tag, emblem, leader_id FK cascade, treasury, motto). Must run before AddUserGuildFields (FK target).
│   │   ├── AddUserGuildFields.swift          # Phase 7.1 — `guild_id` (nullable FK → guilds, setNull on disband) + `guild_role` (string) on users.
│   │   ├── CreateGuildInvites.swift          # Phase 7.1 — `guild_invites` table (guild_id, invitee_id, inviter_id FKs cascade, created_at).
│   │   ├── CreateGuildVault.swift            # Phase 7.1 — `guild_vault` table (guild_id FK cascade, item_id, quantity, created_at, updated_at). Shared stackable storage.
│   │   ├── CreateArenaProfiles.swift        # Phase 8.3 — `arena_profiles` table (user_id unique FK cascade, honor, wins, losses, fights_today, fights_day_stamp, timestamps)
│   │   └── CreateQuestProgress.swift        # Phase 9.2 (2026-08-23) — `quest_progress` table (user_id FK cascade, npc, quest_id, day_stamp, progress, claimed, timestamps). Unique on (user_id, npc, day_stamp): one job per NPC per day, enforced by the DB
│   │
│   ├── Services/                 # Domain services
│   │   ├── VigorService.swift   # drain, consume, starvation penalty, HP loss (pure)
│   │   ├── EquipmentService.swift # atomic equip/unequip, bonus recomputation. Phase 6.5: `nominalStats(of:for:)` (full-condition stats incl. armor enchant + class bonus) + `contributedStats(of:for:)` (durability-adjusted: armor broken→0, weapon at 0→half) — single source summed by `recomputeBonuses`, reused by the inventory detail card
│   │   ├── WarehouseService.swift # deposit/withdraw between inventory and warehouse
│   │   ├── ExplorationService.swift # step outcome roll + autobattle stub + loot drops
│   │   ├── HealingService.swift  # passive HP regen (5%·maxHp/min) while at estate
│   │   ├── PassiveExpeditionService.swift # passive-mode duration picker + Task.sleep scheduler + simulation + report push
│   │   ├── CombatService.swift   # Phase 4.1 + 4.2 + 4.3.1 + 5.1 — applyAttack hit/miss/crit + chipDamage; AttackModifiers / StanceModifiers; per-class special-atk/def tunings; Flee chances; trainingDummyEnemyId
│   │   ├── PlotService.swift     # Phase 5.1 + 2026-05-18 destination picker — pure plot helpers: accumulated, bonusAccumulated, harvest(to:HarvestDestination — `.bag` / `.warehouse`), claim, slotsForLevel. New `HarvestResult.bagFull(primary:bonus:free:need:)` atomic-failure case preserves the yield on the plot so the player can retry (e.g. send to warehouse).
│   │   ├── PlotProductionService.swift # Phase 5.1 — single Task.detached ticker; pushes "ready to harvest" notifications when plot caps are reached
│   │   ├── CraftingService.swift # Phase 5.2 — pure: craft(_:for:on:) drains inputs from combined inventory+warehouse pool (inventory first), deposits output into inventory; CraftResult enum + Shortage struct for the modal alert
│   │   ├── WeaponUpgradeService.swift # Phase 5.2.2 — pure: upgrade(for:on:) advances the player's equipped weapon one tier. Estate-level gate, materials drained from combined inventory+warehouse, InventoryEntry.tier bumped in place (item id never changes), EquipmentService.recomputeBonuses re-run. Result enum: success/maxTierReached/estateLevelTooLow/missingMaterials/noWeaponEquipped.
│   │   ├── EstateUpgradeService.swift # Phase 5.3c — pure: upgrade(for:on:) advances User.estateLevel one tier. Validates player-level + gold + materials, drains from combined pool. Result enum: success/maxTierReached/playerLevelTooLow/insufficientGold/missingMaterials.
│   │   ├── BagUpgradeService.swift # Phase 5.3d — pure: upgrade(for:on:) advances User.bagTier one tier. Validates estate-tier + materials, drains from combined pool. Result enum: success(newTier, newCapacity)/maxTierReached/estateLevelTooLow/missingMaterials.
│   │   ├── TravelService.swift     # Phase 6.0 — estate↔capital trip orchestrator. start() validates guards (dead/starving/onExpedition/alreadyTraveling), persists TravelState, arms Task.detached timer. On arrival flips user.location + user.routerName, deletes the row, pushes the arrival screen. rescheduleInflight() on bot startup re-arms in-flight trips.
│   │   ├── TraderService.swift     # Phase 6.1 — quantity-aware sell(qty)/buy(qty). Atomic gold + slot preflight. Typed result enums for the UI banners. Called by both ×1 and the ✏️ N prompt flow.
│   │   ├── TavernService.swift     # Phase 6.2 — buyDish (atomic, mirrors trader buy) + pure resolveWager(playerScore:houseScore:) → WagerOutcome for dice/darts outcome bookkeeping.
│   │   ├── FortuneService.swift    # Phase 6.4 — tarot draw orchestrator. draw(for:on:) → DrawResult (.success(card, oneShotApplied) / .onCooldown / .notEnoughGold). Validates 24h cooldown (lastFortuneDrawAt) + 10g gold, picks card uniformly, applies one-shots (gold/Wheel/XP/HP/Vigor) + stamps active card + 6h buff expiry + draw timestamp.
│   │   ├── GearConditionService.swift # Phase 6.5 — gear durability runtime. `drainEquippedGear(amount:)` spends a fight's wear budget point-by-point across random equipped armor + weapon (model C, shared pool via `durableSlots`); `WearEvent` victory 1 / defeat 3 / flee 5; armor `maxDurabilityStart` 30. `backfillWeaponDurability(on:)` is an idempotent startup pass lifting pre-existing weapons to their per-tier ceiling. At 0: armor broken (0 stats), weapon keeps half (in EquipmentService).
│   │   ├── MasterService.swift     # Phase 6.5 — the Master's actions: buy(itemId) / repair(entryId) / enchant(entryId), each draining User.silver (+ materials/durability). `repair` branches armor (½ buy price, shaves max−1) vs weapon (1🪙/point, no shave). Typed result enums; mirrors TraderService/WeaponUpgradeService.
│   │   ├── MarketService.swift     # Phase 6.5 (2026-05-28) — player-to-player Market, DB-only (no bot I/O). createListing (escrows units off the bag + flat listing fee) / buyListing (debit buyer, credit seller, deliver, delete lot, returns seller info for the push) / cancelListing (returns units, fee kept). Typed result enums; mirrors TraderService.
│   │   ├── TradeStore.swift        # Phase 6.5 (2026-06-10) — in-memory actor for the synchronous player-to-player Trade (Market → 🤝 Обмін): lobby presence + live sessions (keyed by UUID) + byUser busy-index, TTL sweeper. Methods return decision-snapshots (Telegram I/O stays in the controller). `mutateBuilding` resets only the editor's stage-1 ready-flag (2026-06-15). Not persisted — restart cancels in-flight trades.
│   │   ├── TradeService.swift      # Phase 6.5 (2026-06-10) — DB side of the Trade. tradeableBagItems (non-equipped, non-bound bag rows; stackables summed, gear as rows) + atomic commit (validate-everything-first, then remove stacks → reassign gear rows preserving enchant/durability/tier → add stacks → swap silver — no Fluent transaction needed).
│   │   ├── GuildService.swift      # Phase 7.1 — DB side of guilds (no bot I/O): found / leave / disband / invite / acceptInvite / declineInvite / kick / setOfficer / depositToVault / withdrawFromVault / depositSilver / withdrawSilver. Validate-then-mutate; typed result enums; findTarget resolves @username then nickname (ILIKE).
│   │   ├── TavernCleanupService.swift # 2026-05-20 — deletes tavern dice/darts clutter on a 24h delay (Telegram forbids deleting a private-chat dice message until it's >24h old). record(messageIds:telegramId:on:) persists a round's message ids; startSweeper(on:bot:) (in configure.swift, mirrors PlotProductionService) runs a Task.detached loop — catch-up sweep on boot + every 30 min — deleting each message + row once created_at passes deletableAfter (24h + 60s). Dice stay in chat as history until then.
│   │   ├── ArenaService.swift     # Phase 8.3 — DB side of the Arena: match validation, Honor ELO, stake settlement (loser→winner minus the Crown's tithe), plus the background sweeper for challenge expiry and turn timeouts
│   │   ├── ArenaStore.swift       # Phase 8.3 — in-memory actor holding lobby presence, pending challenges and live duels; combat rolls happen inside the actor so roll + HP mutation are atomic
│   │   └── QuestService.swift     # Phase 9.2 (2026-08-23) — the daily-quest loop. status(for:npc:) builds the board in one read (deliver progress counted live from the bag, counter progress from the row, day's row created lazily); record(counter:amount:) is the event tick called from combat / passive expedition / forge / trader / tavern hook sites (all best-effort); finish(npc:) turns in a deliver job (drains items, pays) or claims a finished counter job; payOut applies silver + grantXP + Vigor (clamped to cap) and returns the XPGrantResult so banners can echo level-up lines
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
│   │   ├── EphemeralChatState.swift  # in-memory actor — exploration mode-picker IDs, pending warehouse transfer-N state, pending trader transfer-N state (Phase 6.1), pending Market-listing (qty→price, Phase 6.5) + Trade-input (silver/qty, Phase 6.5) state, latest status-banner message ID per user
│   │   ├── PhotoCache.swift          # Phase 6.3 (+ 2026-05-20 rework) — `[assetPath: fileId]` cache + `sendCachedPhoto(...)` helper (file_id reuse only — no deletion). Default photo path for ALL player-visible art (location backdrops, registration/lore scenes); photos stay in chat history (players keep a scrollable record; file_id dedup makes accumulation free). Was `sendScenicPhoto` with prev-photo auto-delete until the rework dropped the deletion.
│   │   ├── DotEnv+Env.swift
│   │   └── GameDay.swift             # the shared daily-reset boundary — rolls at 12:00 Kyiv, not midnight. `GameDay.stamp(date)` is the key every daily system counts against (Arena fight budget, quest of the day)
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
│   │   └── <class>_estate_<m|f>.jpg # Rabid-dog encounter (player's first look at the estate). 6 files: warrior/archer/mage × m/f. Path from CharacterClass.journeyImageName(gender:)
│   ├── estate/                      # Per-tier estate artwork — level_<N>.jpg, N = estateLevel 1…7 (all tiers present)
│   │   └── level_1.jpg … level_7.jpg
│   └── capital/                     # Phase 6 — capital + per-location art (auto-loaded by renderLocation when present)
│       ├── welcome.jpg              # Shown on arrival in capital + on re-entry
│       ├── trader.jpg               # Crамар (Trader) screen photo
│       ├── tavern.jpg               # Шинок (Tavern) screen photo
│       ├── fortune.jpg              # Ворожка (Fortune Teller) entry photo
│       └── fortune/                 # 22 Major Arcana card portraits (0_fool.png … 21_world.png)
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

4. **Project path + Telegram username**:
   - `projectPath` is read from env (`ROI_PROJECT_PATH`) at module load with a Mac dev-path fallback. Set the env in your shell (`~/.zshenv`, systemd `Environment=`, etc.) — `.env` is loaded LATER using this very path, so the var must come from the real OS env, not from `.env`.
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

### Running Against a Remote Database

The database does not have to be local. If Postgres lives on another machine and
listens only on that machine's loopback (the usual hardened setup), point `.env`
at `127.0.0.1` and open an SSH tunnel first:

```bash
ssh -f -N -L <local-port>:localhost:<remote-port> <user>@<host>   # -f backgrounds it
```

The tunnel dies with the SSH process, so it has to be re-opened after a reboot.
Two gotchas worth knowing before you go hunting:

- **A host can run more than one Postgres.** A Docker container published on 5432
  and a native cluster on 5433 look alike from the outside; connecting to the
  wrong one fails with `role "<user>" does not exist`, not with a connection
  error. `pg_lsclusters` and `docker inspect <container> --format '{{.Config.Env}}'`
  tell you which is which.
- **Only one bot process may poll a token.** A second instance starves the first
  on `getUpdates` until the 30 s client deadline trips and the process dies with
  `HTTPClientError.deadlineExceeded` — which reads like a network fault but is
  not one. A run stopped at a debugger breakpoint still holds its poll: the
  process survives `kill -9` while the debugger traces it, so kill `debugserver`
  first. Check with `pgrep -fl RestOfIryna` before starting a new run.

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

For Ukrainian strings that address the player with a gendered word (past-tense `-в/-ла`, adjective, or намісник/-иця), use the gender-aware overload — it resolves `key.m`/`key.f` for `uk` and the plain `key` for English (no English duplication):

```swift
let text = lingo.localize("exploration.death", gender: user.gender, locale: user.locale)
```

`User.gender` ("m"/"f", nil = male) is picked at registration step 1. See `.memory/localization.md` for the full gendered-key list and the variants-vs-neutral-phrasing rule.

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

**A full pre-release rebalance is in flight** and is the only work happening right now:
the game's mathematics is being rebuilt and all content plus all tuning has moved into
`content/data/`. Phases 3–8 are done (data migration, tuning tables, the new combat
model, the item budget, hot reload, and the balance simulator that measures all of it);
Phase 9 writes the content specs that Phase 10 authors against. Progress lives in the
"Full Rebalance" section of [TODO.md](./TODO.md), the reasoning in
[`.memory/rebalance.md`](./.memory/rebalance.md).

See [**GDD.md**](./GDD.md) for systems detail and scope notes — but note it predates the
rebalance, so treat its numbers as design intent rather than what the game currently
does. `content/data/` is the truth.

---

## 🙏 Acknowledgments

- The [Hummingbird](https://github.com/hummingbird-project/hummingbird) team
- [swift-telegram-sdk](https://github.com/nerzh/swift-telegram-sdk) by @nerzh
- The Swift Server Work Group for the ecosystem

*"Rest Of Iryna" is the working title; **ROI** is the persistent brand — the letters will find new meaning as the game grows.*
