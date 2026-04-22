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

### With SupportedLocale enum (via Lingo+Locales.swift extension)
```swift
let text = lingo.localize("key", locale: SupportedLocale.en)
```

## Current Keys (~153 per locale)
- UI: yes, no, commands.start/cancel/exit/settings/language/profile/explore/estate/capital/inventory
- Settings: settings.title, settings.language.prompt
- Help: welcome, here.are.commands, help.*, how.to.*
- Registration: registration.welcome (Artanian intro), registration.nickname.too_short/too_long, registration.name_accepted (greeting + class intro), registration.class.prompt/warrior/archer/mage (+ .desc for each), registration.king_oath (with %{weapon}), registration.weapon.warrior/archer/mage, registration.to_estate, registration.journey_wolves, registration.continue, registration.estate.prompt/too_short/too_long, registration.complete
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
- Enemies (Phase 3.1): enemy.rabid_hare, enemy.rabid_fox, enemy.rabid_wolf
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
