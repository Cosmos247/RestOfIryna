# File Map

```
RestOfIryna/
├── .env.example                    # Environment template (TG token, DB creds)
├── .gitignore                      # Ignores .build, .env, .xcodeproj, etc.
├── .memory/                        # Project-scoped AI memory (this system)
├── Package.swift                   # SPM manifest, Swift 6.2, macOS 14+
├── GDD.md                          # Game Design Document (full v1 vision)
├── README.md                       # Project overview, arch, setup, dev notes
├── CLAUDE.md                       # AI assistant instructions & project reference
├── TODO.md                         # Phased progress tracker
├── Prompt.me                       # New-session primer
├── icon.png                        # Bot icon asset
│
├── Localizations/
│   ├── en.json                     # English strings (~308 keys)
│   └── uk.json                     # Ukrainian strings (~308 keys)
│
├── Assets/
│   ├── registration/               # Artwork for the onboarding narrative
│   │   ├── kings_charter.jpg       # Shown in the King's Oath step (same for every class)
│   │   ├── warrior_estate.jpg      # Wolves encounter step, warrior variant
│   │   ├── archer_estate.jpg       # ... archer
│   │   └── mage_estate.jpg         # ... mage
│   └── estate/                     # Per-level estate artwork (optional — empty until user adds files)
│       └── level_<N>.jpg           # e.g. level_1.jpg, level_2.jpg — filename = estate level index
│
├── Public/
│   └── favicon.ico                 # (if present)
│
├── content/                        # Reference documents (game content authoring)
│   └── bestiary.md                 # Per-enemy stats, loot, depth ranges, family overviews
│
├── PostgreSQL/                     # Docker volume mount for PG data
│
└── Swift/                          # All source code (SPM target root)
    ├── entrypoint.swift            # @main, logging setup, calls configure()
    ├── configure.swift             # App bootstrap: DB, Lingo, Bot, Hummingbird
    ├── routes.swift                # RouterStore actor + Sendable conformance + per-user dispatch serialization (token-keyed Task chain)
    │
    ├── Controllers/
    │   ├── AllControllers.swift     # Controller registry, attachAllHandlers()
    │   ├── MainController.swift    # Main hub, profile view (3 styles), Explore/Estate/Capital/Profile/Settings nav
    │   ├── RegistrationController.swift  # Multi-step: language, nickname, class, estate. First message ships ReplyKeyboardRemove. Shared validateName helper: allow-lists (digits/Latin/Ukrainian), edge-space + consecutive-space + invalid-char rejection with five distinct error toasts per field.
    │   ├── SettingsController.swift      # Language change, back navigation
    │   ├── GlobalCommandsController.swift # /help, /settings, /buttons (any state)
    │   ├── ExplorationController.swift   # Phase 3.1 active + 3.2 visit-decay return + 3.3 passive mode. Entry shows mode picker [🏃 Розвідка / 🏕 Експедиція] when no state; passive branches into countdown status (in-flight) or report delivery (completed). Active: Step Forward increments & rolls with prior visit count; Step Back decrements & rolls (km ≥ 2) or arrives home (km ≤ 1). Reply keyboard [🚶 Step fwd] [🔙 Step back] / [🎒 Bag] only during active. Inline `explore:` callbacks for bag, mode-picker, duration-picker, passive-report close. Encounters in active mode hand off to CombatController via `handOffToCombat` (stamps combat fields on state row, transitions routerName). `handleDeath(causeNarrative:)` is now a static helper so CombatController can reuse the wipe + respawn flow.
    │   ├── CombatController.swift        # Phase 4.1 + 4.2 + 4.3.1 + 5.1 turn-based PvE duel. Main keyboard is inline [Attack][Defend] / [🪄 Techniques][Flee] (combat:* callbacks) with class-flavoured labels. generateControllerKB returns nil. [🪄 Techniques] edits keyboard in-place to a submenu (Special Atk + Special Def + Super) with per-fight budget (2/2/1) and " × N" suffixes; spent buttons hide. Phase 4.3.1: per-class Flee chances (warrior 40 / archer 70 / mage 90, mage +2 hunger teleport tax). **Phase 5.1 Training Mode** (entered from the Training Ground plot): detected via `isTraining(state)` (enemy id check on `enemy.training_dummy`); `combatMainMarkup` swaps `[Flee]` for `[🔙 Back]` (`combat:training:exit`); `routerName` stays at "estate" (NOT flipped to "combat") so the player's reply keyboard remains usable; combat callbacks reach the controller via `combat:*` forwarding installed in MainController / InventoryController / EstateController / SettingsController onCallbackQuery. Player swings are clean (cannotMiss=true, enemy DEF treated as 0 via `playerSwingEnemyDEF` helper), no hunger drain, no enemy counter line, dummy auto-revives via `reviveTrainingDummy` when HP hits 0. Static emoji helpers (superEmoji / specialAtkHitEmoji / specialDefEmoji) prepend icons in Swift since Lingo's %{var} parser breaks on leading UTF-16 surrogate pairs. Registration wolves fight at step 4 routes here — Registration.handleCombatEnd(won:) on end-of-fight, detected via session.registrationStep < 6.
    │   ├── EstateController.swift        # Tree nav: Root → House (Workshop/Kitchen stubs + real Warehouse) / Plot. Per-level artwork loader. Main-nav pass-through. Warehouse deposit/withdraw success → inline `✅ ...` status line above refreshed category; failure → modal alert. **Phase 5.1 Plot drill-down**: `renderPlotList(plots:session:)` and `plotListKeyboard(...)` are `internal` (CombatController.onTrainingExit re-renders them after a Back tap). Three callback handlers: `handlePlotClaimPicker` opens a 5-type picker (Farm / Lumberyard / Mine / Coop / Training Ground), `handlePlotTypeChosen` calls `PlotService.claim(...)`, `handlePlotHarvest` calls `PlotService.harvest(...)` and deposits into Warehouse with a `✅ Slot N — yields, added to Warehouse 📦` status banner, `handlePlotTraining` spawns an `ExplorationState` row with `enemy.training_dummy` stamped on combat fields and hands off to CombatController WITHOUT flipping routerName (combat:* callbacks reach the controller via cross-controller forwarding). Mine plot's bonus output (iron alongside pebble) renders inline in the plot row: `⛏ Slot N · Mine — 40/40 🪨 · 12/20 🔩`.
    │   ├── CapitalController.swift       # STUB (Phase 6): coming-soon + back to main
    │   └── InventoryController.swift     # Tree nav: root categories → drill-down with Use buttons for food/potion. `refreshCategory(...)` accepts optional `statusLine` prepended to the rendered body. Action acks (eat, equip, unequip) → silent answerCallbackQuery + inline `✅ ...` status above refresh; warnings (raw food, no_effect, empty category, use_unavailable) and item-info placeholders → modal alert via showAlert: true. Eat status appends current/max pool ("✅ Лісові ягоди — +15 голоду (20/100)") via `hunger.restored` / `hp.restored` keys interpolating `%{current}`/`%{max}`.
    │
    ├── Models/
    │   ├── User.swift              # Fluent model: identity, class, nickname, estate, profile style, game stats
    │   ├── Item.swift              # Static item catalog: ItemType, ItemEffect, EquipmentSlot (8), GearStats, Item, ItemCatalog (code-based)
    │   ├── InventoryEntry.swift    # Fluent model: user_id, item_id, quantity, equipped_slot + add/remove/has/list/canAccept/slotsUsed helpers; 50-slot cap (equipped doesn't count)
    │   ├── WarehouseEntry.swift    # Fluent model: estate storage, separate table; add/list/totalQuantity helpers
    │   ├── ExplorationState.swift  # Fluent model: one row per active or passive expedition (user_id unique, stepsDeep, visited_rooms JSON dict, mode, ends_at, report_json + the Phase 4 combat field stack). Presence = "exploring"; begin/beginPassive/current/end/allPassive helpers; recordVisit/visitCount + visitedRooms computed wrapper; isPassive/hasReadyReport/secondsRemaining queries; isInCombat / beginCombat (initialises 2 Special Atk + 2 Special Def + 1 Super uses) / endCombat (clears every combat-scoped column); 4.2.1 stance helpers (hasActiveStance / beginStance / tickStance); 4.2.3 defense-effect helpers (hasEnemyDefDebuff / hasPlayerDodgeBuff / applyEnemyDefDebuff / applyPlayerDodgeBuff / tickDefenseEffects); per-fight budget helpers (hasSpecialAtkUse / hasSpecialDefUse / hasSuperUse / consumeSpecialAtk / consumeSpecialDef / consumeSuper). ExplorationMode enum (active / passive). The `returning` column is dormant from an earlier 3.2 design pass.
    │   ├── Enemy.swift             # Static bestiary (EnemyLootDrop + Enemy struct + EnemyCatalog). Code-based like ItemCatalog. 7 wilderness animals across 6 tiers + the special `enemy.training_dummy` (HP 200, ATK 0, DEF 1, no loot, depthRange 0...0 so exploration never picks it — only spawned by the Training Ground plot). Wild family: 🐗 boar 1-10 / 🫎 moose 6-15 / 🦬 buffalo 11-20 / 🐻 wild_bear 21-30 (meat+hide). Rabid family: 🐈‍⬛ lynx 11-20 / 🐺 wolf 16-25 / 🐻‍❄️ rabid_bear 25-35 (hide only). Three deep-zone overlaps. Reference doc at `content/bestiary.md`.
    │   ├── Plot.swift              # Phase 5.1 — Fluent model: per-user estate plot. Fields: user_id, slot_index, plot_type, tier, last_harvested_at, notified_full. Production lazily computed from lastHarvestedAt + ratePerSecond × elapsed (capped). Helpers: list(for:), find(slot:for:), allUnfull(on:) (used by background ticker).
    │   └── PlotCatalog.swift       # Phase 5.1 — code-based config: PlotType enum (farm / forest / mine / coop / trainingGround), PlotTuning (producedItemId, ratePerInterval, capacity, optional bonusOutput), PlotBonusOutput. Mine carries bonus output for mat.iron (1/interval, cap 20) alongside primary mat.river_pebble (8/interval, cap 40). `testMode` flag scales rates per-minute (test) vs. per-hour (prod). `tuning(for:)` returns nil for trainingGround so controllers route those to combat instead of harvest.
    │
    ├── Migrations/
    │   ├── CreateUser.swift        # users table: id, telegram_id, router_name, locale, names
    │   ├── AddCharacterFields.swift # nickname, character_class, estate_name, registration_step
    │   ├── AddProfileStyle.swift   # profile_style (1-3)
    │   ├── AddGameStats.swift      # level, xp, hp, max_hp, hunger, max_hunger, atk/def/crit/dodge/acc, gold (crowns originally here)
    │   ├── CreateInventory.swift   # inventory table: user_id (FK, cascade), item_id, quantity, timestamps
    │   ├── RemoveCrownsField.swift # drops crowns column; premium currency name TBD
    │   ├── AddEquipSlotToInventory.swift # nullable equipped_slot column on inventory (Phase 2.3.2)
    │   ├── AddGearBonuses.swift    # 5 cached gear_*_bonus fields on users (Phase 2.3.2)
    │   ├── CreateWarehouse.swift   # warehouse table (Phase 5 — estate storage, separate from inventory)
    │   ├── CreateExplorationState.swift # exploration_state table (Phase 3.1): per-user stepsDeep, unique on user_id, cascades on user delete
    │   ├── AddExplorationReturnState.swift # (Phase 3.2): adds `visited_rooms` TEXT (JSON dict km → visit count) and a dormant `returning` Bool to exploration_state
    │   ├── AddHpRegenTick.swift    # (Phase 3.2 polish): adds `last_hp_tick_at` nullable Date to users
    │   ├── AddPassiveExpeditionFields.swift # (Phase 3.3): adds nullable `mode`, `ends_at`, `report_json` to exploration_state
    │   ├── RenameMaterialIds.swift # Data migration: mat.wood→mat.pine_lumber, mat.stone→mat.river_pebble, mat.iron_ore→mat.old_iron (inventory + warehouse)
    │   ├── RenameFoodIds.swift    # Data migration: food.berry→food.forest_berries; bread/stew/roast rows deleted outright
    │   ├── AddCombatFields.swift  # (Phase 4.1): adds nullable `combat_enemy_id` (string) + `combat_enemy_hp` (int) to exploration_state — embeds live combat in the expedition row
    │   ├── AddCombatStanceFields.swift  # (Phase 4.2.1): adds nullable `combat_stance` + `combat_stance_rounds_left` for Super-technique stances
    │   ├── AddCombatDefenseFields.swift # (Phase 4.2.3): adds nullable `combat_enemy_def_debuff` + `combat_player_dodge_buff` rounds-remaining counters for Iron Bulwark / Shadow Veil persistent effects
    │   ├── AddCombatTechniqueUses.swift # (Phase 4.2 polish): adds per-fight budget counters `combat_special_atk_uses` (max 2), `combat_special_def_uses` (max 2), `combat_super_uses` (max 1)
    │   ├── CreatePlots.swift       # (Phase 5.1): creates `plots` table — user_id (FK cascade), slot_index, plot_type, tier, last_harvested_at, notified_full. Unique on (user_id, slot_index).
    │   └── RemoveOldIron.swift     # (Phase 5.1): data-only DELETE FROM inventory/warehouse WHERE item_id = 'mat.old_iron'. Retires the legacy item; its role (medium-tier iron-from-foraging) is now `mat.iron` (Iron Lump 🔩).
    │
    ├── Services/
    │   ├── HungerService.swift    # Pure: HungerAction enum (walkRoom / walkRoomDoubleSpeed / combatRound (passive) / combatAttack/Defend/Flee (active, costs 2/1/3) / idle), drain (with optional multiplier for stance buffs like Bloodlust ×2), consume, isStarving, applyStarvationHPLoss, starvation penalty on effective ATK/DEF (on User via extension); effective-stat extension also includes crit/dodge/accuracy + gear bonuses
    │   ├── EquipmentService.swift # equip (atomic slot swap), unequip, equipped(for:), recomputeBonuses (writes cached gear_*_bonus on User)
    │   ├── WarehouseService.swift # deposit / withdraw — moves one unit between InventoryEntry and WarehouseEntry; returns typed enum (success / nothingToTransfer / inventoryFull); deposits skip equipped rows; withdraw preflights backpack space
    │   ├── ExplorationService.swift # Phase 3.1/3.2: rollStep(mode:) with `priorVisits:Int` three-tier weight table (fresh 20/40/30/10 → reduced 50/20/20/10 → bare 100/0/0/0). Active mode returns `.encounterStarted(enemy)` so CombatController takes over; passive mode runs `resolveAutobattle` on top of `CombatService.applyAttack` and returns `.encounterWon` / `.encounterLost`. `awardEncounterDrops` is a public hook for CombatController's victory path (mirrors the autobattle's drop step). StepOutcome enum: nothing / loot / trip / encounterStarted (active hand-off) / encounterWon / encounterLost / starvationOnly.
    │   ├── HealingService.swift # Phase 3.2 polish: lazy-compute passive HP regen (5%·maxHp per minute) while player is NOT on any expedition (active or passive) and hp < maxHp. `tick(_:inExpedition:on:)` is called from RouterStore.process on every interaction — RouterStore queries ExplorationState presence to derive `inExpedition`. Pins `user.lastHpTickAt` at full HP and clears it during expedition to prevent banked regen.
    │   ├── PassiveExpeditionService.swift # Phase 3.3: passive expedition. PassiveDuration (30/60/90 units), testMode flag (seconds vs minutes), start() arms a Task.detached running runLive (live per-step loop with Task.sleep between each step + absolute-fire-time catch-up after restart). Early exit on death pushes the report immediately. Progress tracked via state.stepsDeep so restart resumes at the right step. PassiveReport Codable blob stored in exploration_state.report_json. rescheduleInflight() runs on bot startup via configure.swift.
    │   ├── CombatService.swift # Phase 4.1 + 4.2 + 4.3.1 + 5.1: shared damage primitives plus all class-technique tunings. `applyAttack(...)` with optional `AttackModifiers` (hitChanceModifier / defenderDEFFraction / critBonus / cannotMiss / flatDamageBonus); `chipDamage` for Defend's 30%-of-base parry-counter. 4.2.1 stance layer: `StanceModifiers` struct, `stanceModifiers(for:)` lookup (Bloodlust / Hawk's Eye / Arcane Resonance), `stanceId(forClass:)`, `stanceActivationHunger(for:)`, `stanceDurationRounds = 3`. 4.2.2 special-attack layer: per-class `specialAttackHunger(forClass:)`, `specialAttackModifiers(forClass:)`, `specialAttackZeroesDodge(forClass:)`. 4.2.3 special-defense layer: `SpecialDefense` namespace + chip / dodge / reflect tunings. 4.3.1 Flee tuning: `Flee` namespace (warrior 40 / archer 70 / mage 90 success %, mage `mageHungerExtra = 2`). 5.1 Training Ground identity: `trainingDummyEnemyId` constant — checked by CombatController to flip into training mode (clean damage, no hunger drain, no enemy counter, dummy auto-revives). ExplorationService.resolveAutobattle still calls into the same primitives.
    │   ├── PlotService.swift   # Phase 5.1: pure plot helpers. `accumulated(for:)` / `bonusAccumulated(for:)` lazy-compute primary + bonus yield from lastHarvestedAt + ratePerSecond × elapsed (capped). `harvest(_:for:on:)` returns `HarvestResult.success(primary:bonus:)` and deposits into `WarehouseEntry` (not the bag — warehouse has no slot cap, so no `.bagFull` failure mode). `claim(slot:type:for:on:)` validates slot allowance via `slotsForLevel(_:)` (currently flat 5 — temporary override; the logarithmic table is preserved in code for the post-XP-to-Estate world). `hasAnyPlot` used by registration to auto-grant slot 0 = Farm.
    │   └── PlotProductionService.swift # Phase 5.1: single Task.detached ticker started from configure.swift after bot.start. `tickInterval` is 60s in test mode / 300s in prod. Each tick walks `Plot.allUnfull(on:)` (plots with notified_full = false), checks if accumulator hit cap, pushes a "🌾 ready to harvest" message to the owner's chat, flips `notified_full = true` to suppress repeats. Harvest resets the flag.
    │
    ├── Telegram/
    │   ├── Router/
    │   │   ├── Router.swift        # Path-matching engine (command, content type, callback)
    │   │   ├── Context.swift       # Request context: bot, db, lingo, update, session, args
    │   │   ├── Command.swift       # Command name matcher (slash handling, case sensitivity)
    │   │   ├── Commands.swift      # Commands enum (start, cancel, exit, settings, language, profile, explore, estate, capital, inventory)
    │   │   ├── ContentType.swift   # Enum of all matchable Telegram content types
    │   │   ├── Arguments.swift     # Scanner-based argument parser (words, ints, doubles)
    │   │   └── Router+Helpers.swift # Subscript shortcuts for adding handlers
    │   │
    │   └── TGBot/
    │       ├── TGDispatcher.swift   # Main dispatcher: auth + global cmds + router catch-all
    │       └── HummingbirdTGClient.swift # TGClientPrtcl impl using AsyncHTTPClient
    │
    └── Helpers/
        ├── TGBot+Extensions.swift  # TGControllerBase (+ dismissPendingPicker), Context.session, TGMessage helpers
        ├── SessionCache.swift      # Actor-based user cache (5min TTL, auto-cleanup)
        ├── Lingo+Locales.swift     # Lingo convenience: accept SupportedLocale enum
        ├── EphemeralChatState.swift # Actor — in-memory cache of transient message IDs (mode-picker → auto-delete on navigation)
        └── DotEnv+Env.swift        # Env helper: get env vars with fallback to .env file
```
