# Localization

## Setup
- Lingo initialized from `Localizations/` directory with default locale "en"
- JSON files: `en.json`, `uk.json`
- Path configured in `configure.swift`: `"\(projectPath)/Localizations"`

## SupportedLocale Enum (configure.swift)
```swift
public enum SupportedLocale: String, CaseIterable, Codable, Sendable {
    case en = "en"
    case ua = "uk"  // Note: enum case is .ua, raw value is "uk"
    
    func flag() -> String {
        switch self {
        case .en: return "🇬🇧"
        case .ua: return "🇺🇦"
        }
    }
}
```

## Usage Patterns

### Basic localization
```swift
let text = lingo.localize("key", locale: session.locale)
```

### With interpolation
```swift
let text = lingo.localize("greeting.message", locale: session.locale, 
                          interpolations: ["full-name": name])
```
JSON: `"greeting.message": "Hey %{full-name}"`

### ⚠️ Lingo interpolation bug with multi-UTF-16 emoji

**Rule:** Any character that is **more than one UTF-16 code unit** placed BEFORE a `%{placeholder}` in the source string breaks that (and every subsequent) interpolation — the raw `%{name}` renders literally.

"Multi-UTF-16" covers two cases:
1. **Surrogate-pair emoji** (supplementary plane, U+10000+): 🏕 📏 🍖 🪨 💀 🥀 🥩 🔥 etc. Count as 2 UTF-16 units each.
2. **BMP character + VS16 variation selector (U+FE0F)**: ❤️ (U+2764 U+FE0F), ⚔️ (U+2694 U+FE0F), ⚠️ (U+26A0 U+FE0F). The VS16 forces colour emoji rendering but adds a second UTF-16 unit.

Single-UTF-16 BMP emoji (default emoji presentation, no VS16) are **SAFE** before placeholders. Verified safe set: ✨ ⚡ ⭐ ✅ ❌ ❎ ❗ ❕ ❓ ❔ ⏳ ⌛ ⌚ ⏰ ⏩ ⏪ ⏫ ⏬ ➕ ➖ ➗ ➰ ➿ ⛔ ⛺ ⛲ ⛪ ⛵ ⛽ ⛅ ⛄ ⚓ ⚽ ⚾ ⚪ ⚫ ⭕ ☔ ☕ ⚔ (no VS16, see caveat below).

Caveat on BMP-default chars like `⚔` / `☠` / `✂`: some have *text* presentation by default on certain platforms — on macOS the rendering can look monochrome/text-like, while iOS/Android/Web Telegram show the colour emoji. Test on target platforms if unsure; fallback is to swap to a `default_emoji_presentation` char (e.g. ⚡).

Observed failure cases:
- `"HP: %{before} → %{after} ❤️"` — works (placeholder before emoji)
- `"❤️ HP: %{before} → %{after}"` — BROKEN (BMP+VS16 before placeholder)
- `"🏕 Очікуваний час повернення: %{time}."` — BROKEN (surrogate pair before `%{time}`)
- `"⚔️ You defeated %{enemy}..."` — BROKEN (⚔ + VS16 before placeholder)
- `"⚔ You defeated %{enemy}..."` — works (⚔ WITHOUT VS16, single UTF-16)

### 🟢 Preferred pattern for decorative emoji + interpolation (GO-FORWARD RULE)

**Any localized string with `%{...}` interpolations should NOT have a leading emoji in its Lingo template.** Put the emoji in Swift code, prepended after `lingo.localize(...)` returns:

```swift
// ❌ DON'T — ⚔️ in template breaks %{enemy} / %{rounds} / %{hp} / %{hunger}
"exploration.outcome.encounter.won": "⚔️ You defeated %{enemy} in %{rounds} round(s). −%{hp} HP, −%{hunger} hunger"
let text = lingo.localize("exploration.outcome.encounter.won", locale: locale, interpolations: [...])

// ✅ DO — emoji prepended in code
"exploration.outcome.encounter.won": "You defeated %{enemy} in %{rounds} round(s). −%{hp} HP, −%{hunger} hunger"
let text = "⚔️ " + lingo.localize("exploration.outcome.encounter.won", locale: locale, interpolations: [...])
```

This bypasses the Lingo bug entirely — Lingo sees a clean placeholder-only template, interpolation works, and Swift handles the visual decoration with any emoji (surrogate-pair, BMP+VS16, or single BMP). No audit needed, no trap for new emoji swaps.

**Applied in ROI at (2026-04-23):**
- `ExplorationController.narrateOutcome`: `.trip` → `🦵 `, `.encounterWon` → `⚔️ `, `.encounterLost` → `💀 `, `.starvationOnly` → `🥀 `
- `ExplorationController.handleDeath`: `"💀 " + lingo.localize("exploration.death", ...)`

**Updated 2026-04-25 — emoji inside interpolation values is also safe.** The Lingo bug only fires when an emoji is in the *template* before a placeholder. Emojis inside the *substituted value* are post-hoc string concatenation and don't affect placeholder discovery. So a multi-UTF-16 emoji can be packed into the value to keep emoji-as-icon next to its number:

```swift
// Template: "<b>%{hp} HP, %{hunger} голоду</b>"   ← clean, no emoji in template
"hp": "❤️ −\(hpLost)",
"hunger": "🍖 −\(hungerLost)"
// → "<b>❤️ −1 HP, 🍖 −2 голоду</b>"
```

ROI uses this for the trip / encounter.won / starvationOnly outcomes — the leading `🦵 / ⚔️ / 🥀` is still prepended in Swift after `localize(...)`, but the inline `❤️` / `🍖` ride inside the interpolation values.

**For non-interpolated keys** (plain `"🏰 Ти повертаєшся додому."` with no `%{...}`), emoji can live anywhere in the template — the bug only fires when interpolation is involved. But if you ever ADD a placeholder to an existing key that starts with a multi-UTF-16 emoji, move the emoji to the Swift call site at the same time.

### Legacy fix options (when you can't touch Swift)

If you must keep the emoji in the template for some reason:
1. Use a safe single-UTF-16 BMP emoji (see verified-safe set above).
2. Move the emoji to the END so `%{...}` is the first dynamic token.

### With SupportedLocale enum (via Lingo+Locales.swift extension)
```swift
let text = lingo.localize("key", locale: SupportedLocale.en)
```

## Current Keys (~236 per locale)
- UI: yes, no, commands.start/cancel/exit/settings/language/profile/explore/estate/capital/inventory
- Settings: settings.title, settings.language.prompt
- Help: welcome, here.are.commands, help.*, how.to.*
- Registration: registration.welcome (Artanian intro), registration.nickname.too_short/too_long/edge_space/consecutive_spaces/invalid_chars (validation toasts), registration.name_accepted (greeting + class intro), registration.class.prompt/warrior/archer/mage (+ .desc for each), registration.king_oath (with %{weapon}), registration.weapon.warrior/archer/mage, registration.to_estate, registration.journey_wolves, registration.continue, registration.estate.prompt/too_short/too_long/edge_space/consecutive_spaces/invalid_chars, registration.complete
- Bot lifecycle: bot.restarted (lore-flavoured restart greeting; sent on bot startup with a `/start` reply-keyboard button)
- Combat (Phase 4.1): combat.button.<action>.<class> — 9 button labels (Attack/Defend/Flee × warrior/archer/mage). combat.encounter.intro for the round-1 framing line. combat.you.{hit,crit,miss} / combat.enemy.{hit,crit,miss} for round narration (each interpolates `%{enemy}` and `%{damage}` where applicable). combat.defend.absorbed for the parry-counter chip line. combat.flee.{success,fail} for retreat outcomes. combat.victory / combat.defeat for end-of-fight headers. registration.fight_wolves (Stand and fight button) and registration.wolves_retry (soft-retry preamble after defeat / flee at the registration tutorial fight).
- Profile: profile.level/xp/health/hunger/attack/defense/accuracy/dodge/crit/gold/estate
- Stubs: stub.coming_soon (shared placeholder for not-yet-implemented features)
- Items: item.food.*, item.mat.*, item.potion.*, item.gear.*, item.artifact.* (display names for catalog entries)
- Inventory UI: inventory.title, inventory.empty, inventory.type.food/material/potion/gear/artifact, inventory.choose_category, inventory.back_root, inventory.info.placeholder, inventory.use.unavailable, inventory.category.empty (toast for tapping an empty category), inventory.full (backpack cap toast), inventory.slots_label (for the X/50 header indicator)
- Inventory actions (per item type): inventory.action.food/potion/gear/artifact — each includes its emoji + verb ("🍴 Eat", "🍷 Use", "🛡 Equip", "✨ Use"). Gear also has `inventory.action.gear.unequip` ("❌ Unequip") used when the row is currently equipped.
- Equipment: equip.success / unequip.success toasts; profile.equipped.main_hand label; profile.equipped.empty placeholder for an empty slot
- Estate (Phase 5 scaffolding): estate.title, estate.description (placeholder lore), estate.level_label, estate.home, estate.plot (both also used as titles in drilldown), estate.home.description, estate.workshop, estate.kitchen, estate.warehouse, estate.warehouse.description, estate.warehouse.empty, estate.warehouse.deposited / withdrawn / nothing_to_deposit / nothing_to_withdraw (transfer toasts), estate.back_root, estate.back_home
- Hunger / consume: hunger.restored, hp.restored, hunger.starving, consume.not_consumable, consume.no_effect
- Exploration (Phase 3.1 + 3.2): exploration.button.step / exploration.button.step_back / exploration.button.bag (reply keyboard), exploration.started/resumed (entry intro), exploration.depth_label, exploration.outcome.loot.picked/loot.full/trip/encounter.won/encounter.lost/starvation (step narratives), exploration.returned (main-menu farewell), exploration.death (with %{cause}), exploration.bag.title/empty/back
- Exploration visit-decay variants (Phase 3.2): three `.nothing` narratives — exploration.outcome.nothing (fresh, prior visits = 0), exploration.outcome.nothing.revisited (thinned, prior visits = 1), exploration.outcome.nothing.bare (depleted, prior visits ≥ 2)
- Passive expedition (Phase 3.3): exploration.mode.prompt/active/passive (mode picker), exploration.duration.prompt/30m/1h/1h30m/back (duration picker), exploration.passive.started/inflight (confirmation + countdown, with %{time} interpolation), exploration.passive.test_mode_hint, exploration.passive.report.title/depth/hp/hunger/events_header/loot_header/no_loot/loot_partial/death/close (report rendering), exploration.passive.outcome.nothing/loot/encounter_won/encounter_lost/trip/starvation (one-word labels for outcome histogram)
- Mode exclusivity (Phase 3.4): capital.blocked_by_expedition (capital entry guard notice). The Explore keyboard label is static — gating happens at entry via showExploration's passive-countdown branch.
- Enemies: enemy.wild_boar, enemy.wild_moose, enemy.wild_buffalo, enemy.rabid_lynx, enemy.rabid_wolf (Phase 3.5 bestiary — 5 animals across 4 tiers)
- Dev commands: grant.usage/unknown_item/success, revoke.usage/unknown_item/not_enough/success, drain.usage/success (all mitya-only)
- Other: lang.name, greeting.message, keyboard.restored, not.allowed.ask.invite

## Adding a New Language
1. Create `Localizations/<code>.json` with all keys
2. Add case to `SupportedLocale` enum in `configure.swift`
3. Provide flag emoji in `flag()` method

## Multi-locale Button Registration
Controllers register button handlers for ALL locales to handle text matching regardless of user language:
```swift
let cancelLocales = Commands.cancel.buttonsForAllLocales(lingo: lingo)
for button in cancelLocales { router[button.text] = onCancel }
```
