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
// ❌ DON'T — ⚔️ in template breaks %{enemy} / %{rounds} / %{hp} / %{vigor}
"exploration.outcome.encounter.won": "⚔️ You defeated %{enemy} in %{rounds} round(s). −%{hp} HP, −%{vigor} vigor"
let text = lingo.localize("exploration.outcome.encounter.won", locale: locale, interpolations: [...])

// ✅ DO — emoji prepended in code
"exploration.outcome.encounter.won": "You defeated %{enemy} in %{rounds} round(s). −%{hp} HP, −%{vigor} vigor"
let text = "⚔️ " + lingo.localize("exploration.outcome.encounter.won", locale: locale, interpolations: [...])
```

This bypasses the Lingo bug entirely — Lingo sees a clean placeholder-only template, interpolation works, and Swift handles the visual decoration with any emoji (surrogate-pair, BMP+VS16, or single BMP). No audit needed, no trap for new emoji swaps.

**Applied in ROI at (2026-04-23):**
- `ExplorationController.narrateOutcome`: `.trip` → `🦵 `, `.encounterWon` → `⚔️ `, `.encounterLost` → `💀 `, `.starvationOnly` → `🥀 `
- `ExplorationController.handleDeath`: `"💀 " + lingo.localize("exploration.death", ...)`

**Updated 2026-04-25 — emoji inside interpolation values is also safe.** The Lingo bug only fires when an emoji is in the *template* before a placeholder. Emojis inside the *substituted value* are post-hoc string concatenation and don't affect placeholder discovery. So a multi-UTF-16 emoji can be packed into the value to keep emoji-as-icon next to its number:

```swift
// Template: "<b>%{hp} HP, %{vigor} снаги</b>"   ← clean, no emoji in template
"hp": "❤️ −\(hpLost)",
"vigor": "🍖 −\(vigorLost)"
// → "<b>❤️ −1 HP, 🍖 −2 снаги</b>"
```

ROI uses this for the trip / encounter.won / starvationOnly outcomes — the leading `🦵 / ⚔️ / 🥀` is still prepended in Swift after `localize(...)`, but the inline `❤️` / `🍖` ride inside the interpolation values.

**For non-interpolated keys** (plain `"🏰 Ти повертаєшся додому."` with no `%{...}`), emoji can live anywhere in the template — the bug only fires when interpolation is involved. But if you ever ADD a placeholder to an existing key that starts with a multi-UTF-16 emoji, move the emoji to the Swift call site at the same time.

**Updated 2026-05-18 — the rule covers ANY multi-UTF-16 emoji immediately adjacent to a `%{var}`, not only leading.** Rediscovered while wiring `🪙 %{silver}` into trader/tavern/fortune banners — the literal `%{silver}` rendered after the 🪙 even though the emoji wasn't at position 0.

```swift
// ❌ DON'T — 🪙 immediately before %{silver} kills the interpolation
"capital.trader.sold": "%{item} ×%{qty} — sold for 🪙 %{silver}"

// ✅ DO — pre-build the value with emoji + sign in Swift, keep template plain
"capital.trader.sold": "%{item} ×%{qty} — sold for %{silver}"
"silver": "🪙 \(silver)"            // or "+🪙 \(wager)", "−🪙 \(wager)"
```

Same trick handles signed amounts where the sign hugs the emoji-number group (`+🪙 5` / `−🪙 5`). Locale keys like `gamble.outcome_win`/`outcome_lose` lose their `+`/`−` from the template and pick it up in Swift.

**Audit script (drop in a one-liner before commit when you've touched locales):**

```bash
python3 -c "
import json, re
for path in ['Localizations/en.json','Localizations/uk.json']:
    d = json.load(open(path))
    for k, v in d.items():
        if not isinstance(v, str) or '%{' not in v: continue
        if v and ord(v[0]) >= 0x1F000:
            print(f'LEADING:  {path}  {k}')
        for m in re.finditer(r'(.)%\\{', v):
            if ord(m.group(1)) >= 0x1F000:
                print(f'ADJACENT: {path}  {k}')
                break
"
```

Run from the repo root. Zero output = clean.

### Legacy fix options (when you can't touch Swift)

If you must keep the emoji in the template for some reason:
1. Use a safe single-UTF-16 BMP emoji (see verified-safe set above).
2. Move the emoji to the END so `%{...}` is the first dynamic token.

### 🇺🇦 Ukrainian game-term glossary (no English / no loot slang)

`uk.json` values must not leave English game-stat tokens or transliterated slang. Fixed 2026-05-21 (was scattered: "vigor drain", "Vigor", "HP/XP/ATK/DEF", "лут"). Canonical UA terms:

| concept | uk (inline unit, after a number) | uk (label / status sentence) | en (unchanged) |
|---|---|---|---|
| health | `ОЗ` (e.g. `%{damage} ОЗ`, `макс. ОЗ`) | `Здоров'я` (profile/effect labels, "Повне здоров'я") | HP / maxHP |
| experience | `досвіду` (genitive: `+5 досвіду`, `+25% досвіду`) | `Досвід` (profile label) | XP |
| vigor | `снаги` / `Снага` / `виснаження снаги` (for "vigor drain") | `Снага` | Vigor |
| attack | `АТК` | `Атака` | ATK |
| defense | `ЗАХ` | `Захист` | DEF |
| loot | `здобич` / `здобичі` (e.g. "шанс здобичі") | — | loot |
| accuracy | `влучність` | `Влучність` | Accuracy |
| dodge | `ухилення` | `Ухилення` | Dodge |
| crit | `крит` | `Крит` | Crit |

The three rating stats were added 2026-09-11, after `accuracy` was found under two
names: `profile.accuracy` said «Влучність» and `workshop.stats.accuracy` said
«Точність», and the two keys feed DIFFERENT screens — the character sheet, the
level-up banner, the item card and the fortune effect against the inventory and
the workshop. Same 🎯, same number, two words, and on the fortune screen the
authored card prose contradicted the generated line directly beneath it.
«Влучність» wins: it is what the character sheet calls it and what the archer's
whole vocabulary is built on («Влучний постріл», «влучні постріли»), while
«точність» is exactness, not hitting. **`profile.*` and `workshop.stats.*` are two
key families for one set of stat names and are kept in step only by hand** — attack,
defense, crit and dodge agree today by luck rather than by anything mechanical.

Rule: English stat tokens stay only in `en.json`; never copy them into `uk.json`. Numeric units use the abbreviation (`ОЗ`/`АТК`/`ЗАХ`) except XP which the user wants spelled out (`досвіду`); vigor has no abbreviation (`Снага`/`снаги`). Labels and "fully restored" status lines use full words. Mind case agreement (`здобич` is feminine → `яку`, not `який`).

### ⚠️ Callback-toast keys must be plain text (no HTML)

`answerCallbackQuery(text:)` (both the narrow top-strip toast AND the modal `showAlert: true` popup) renders the `text:` field as **plain text only** — Telegram does not parse HTML / Markdown there. Locale keys that feed callback-answer text must therefore be HTML-free. Affected keys today: `equip.success`, `unequip.success`, `inventory.full`, `inventory.use.unavailable`, `inventory.category.empty`, `inventory.info.placeholder`, `consume.not_raw_edible`, `consume.no_effect`, `estate.warehouse.{deposited,withdrawn,nothing_to_deposit,nothing_to_withdraw}`, `vigor.restored`, `hp.restored`. If a key is shared between a sendMessage-style render (where HTML is OK) and a callback-answer (where HTML is not), prefer plain text — the few extra emoji or numeric formatting can be added in Swift before passing to sendMessage. An audit script (Python over both `.json` files) can verify all interpolated keys are emoji-free at the start AND that every send/edit-message callsite that references an HTML-tagged key has `parseMode: .html` in scope.

### With SupportedLocale enum (via Lingo+Locales.swift extension)
```swift
let text = lingo.localize("key", locale: SupportedLocale.en)
```

## 🫵 The player is addressed as «ви» (uk) — 2026-09-07

Every uk string that speaks to the player uses the **formal plural**: `ви / вас /
вам / ваш`, present tense `-єте/-ите`, imperative `-іть/-те`. 170 strings were
converted in one pass, NPC speech included ("Показуйте, що ремонтувати"). The
sweep that found the last six is the one worth repeating after any copy edit:
grep for the pronouns, for the 2sg present endings (`-єш/-иш/-ешся`), and — the
one that actually caught things — over the *vocabulary* of every word ending in
`-и/-й/-ь/-ись`, since a mid-sentence imperative ("Спершу принеси…") hides from
a line-oriented search.

It also removed three latent gender bugs in keys that never had `.m`/`.f` at all
and shipped masculine to everyone: `travel.arrived.capital` ("Ти прибув"),
`arena.err.dead` ("Ти ледь живий"), `vigor.starving` ("Голодний"). Plural fixes
them by construction.

## 👫 Gender-aware feminitives (uk) — added 2026-05-21, narrowed 2026-09-07

Ukrainian declines past-tense verbs, adjectives and the "намісник/намісниця"
noun by the player's gender. **Under «ви» only the NOUN still declines** — a past
tense goes plural ("Ви повернулися") and so does an adjective ("Ви ледь живі"),
so nine pairs collapsed into single keys and gender now survives only where the
copy names the player: намісник/намісниця, воїне/войовнице. English copy is
gender-neutral. Player gender is
chosen once at **registration step 1** (ahead of the name prompt) and stored in
`User.gender` ("m"/"f"; nil treated as male). The estate-reveal art is also
per-gender (`CharacterClass.journeyImageName(gender:)` → `<class>_estate_<m|f>.jpg`,
falls back to the genderless `<class>_estate.jpg`).

### Helper (`Lingo+Locales.swift`)
```swift
lingo.localize("some.key", gender: session.gender, locale: locale, interpolations: [...])
```
Branches on locale: for **uk** it looks up `some.key.m` / `some.key.f`; for any
other locale it short-circuits to the plain `some.key`. So **only `uk.json` gets
`.m`/`.f` variants — never duplicate the English string.**

### Contract / GO-FORWARD RULE
- A key routed through the gendered helper **MUST** have `<key>.m` AND `<key>.f`
  in `uk.json`, and the base `<key>` in `uk.json` is removed (dead — the helper
  never reads it for uk). `en.json` keeps the single neutral base `<key>`.
- When you add ANY new uk string that addresses the player, write it in «ви».
  That alone settles past tense and adjectives (both go plural). Only a gendered
  **noun** for the player — намісник/-иця, воїне/войовнице — still needs
  `.m`/`.f` + the gendered helper; otherwise phrase around it (impersonal
  "Знайдено…", passive "ще не вивчено") and use a single key.
- Missing a `.m`/`.f` for a routed key → uk shows the raw key + a Lingo console
  warning (loud, easy to catch).

### Gendered keys today (have `.m`/`.f` in uk.json) — 13 left
All of them name the player or the governor: `registration.welcome`,
`registration.name_accepted`, `registration.king_oath`, `registration.gender`,
`estate.blocked_by_expedition`, `capital.blocked_by_expedition`,
`capital.location.tavern.body`, `capital.fortune.intro`,
`exploration.duration.prompt`, `exploration.passive.started`,
`exploration.passive.report.death`, `bot.restarted`, `journal.title`.

**Collapsed on 2026-09-07** because «ви» made the two variants identical, and the
call sites moved to the plain overload: `registration.dog_retry`,
`registration.estate.prompt`, `capital.trader.intro`, `exploration.outcome.trip`,
`exploration.outcome.encounter.won`, `exploration.death`,
`exploration.passive.closed_home`, `combat.ended`,
`combat.special_def.archer.activate`.

Special-cased call sites: `capital.location.tavern.body` is routed gendered only
for the tavern in `CapitalController.renderLocation` (other locations stay
plain); `capital.blocked_by_expedition` passes `gendered: true` through
`postCannotStart` (the no-HP/no-vigor reasons there are neutral). `narrateOutcome`
/ `renderReport` take a `gender:` param threaded from the caller's session.

### Neutralized instead of gendered (Cat 1 — single uk key, no variants)
`capital.tavern.gamble.ready_prompt` ("Кидаємо?"), `kitchen.alert.not_learned`,
`combat.tech.no_uses_left`, `combat.tech.locked`,
`exploration.outcome.loot.picked` ("Знайдено…"), `travel.cannot_start.no_hp`,
`travel.cannot_start.no_vigor`, `item.food.governors_feast.desc` (gendering one
item among many would mean plumbing gender through the whole item-desc path).

### New keys
`registration.gender.prompt` / `registration.gender.m` / `registration.gender.f`
(both locales — the step-1 picker).

## 🧤 Ukrainian copy agrees with the ITEM's name too (2026-09-09)

The player's gender was never the only agreement uk needs. A sentence about a
THING agrees with that thing's noun — «лук зламав**ся**», «шкура зламала**сь**»,
«чоботи зламали**сь**» — and a single template cannot serve them. The first such
string shipped in the neuter («зламалось… воно»), which fits **none** of the
nineteen breakable items: seventeen are masculine, two are plural, and not one
is neuter.

**Where the gender lives: in `uk.json`, not in `items.json`.** It is a property
of the WORD, not of the object — "лук" is masculine and "bow" has no gender at
all, and English never asks. So every item carries `item.<id>.gender` in the
Ukrainian file only: **`m` · `f` · `n` · `pl`** (33 items: 16 · 7 · 6 · 4). One
gender per item id is enough for a ladder, because a ladder keeps one noun
across its rungs.

**The helper mirrors the player-gender one.** `ItemDisplay.localize(_:agreeingWith:lingo:locale:interpolations:)`
looks up `<key>.m` / `.f` / `.n` / `.pl` for uk and the plain `<key>` for every
other locale — exactly as `Lingo.localize(_:gender:locale:)` does for
намісник/намісниця, and for the same reason: only Ukrainian needs the variants,
so English keeps one string.

**The validator stops the next one silently defaulting.** `locale.item_gender_missing`
(warning) fires when a name declares no gender — the fallback is masculine,
right for sixteen names and wrong for seventeen — and `locale.item_gender_invalid`
(error) when the value is not one of the four. Negative-tested: removing the
boots' gender names exactly the boots.

Keys using it today: `gear.broken.notice` (4 variants).

## 🗡 A weapon ladder is ONE object (2026-09-07)

The three upgradable weapons resolve their display name through
`ItemDisplay.nameKey(for:tier:)` → `item.<id>.t<tier>`, and the rungs must keep
a word in common: the player is upgrading a thing, not trading it for a
different thing, and the screens that name the weapon generically — the Master's
`capital.master.repair.weapon.<class>` ("🔮 Наснажити посох") — cannot follow a
noun that changes. The mage ladder read **патериця → посох → посох → жезл →
жезл** in uk and **Staff → Staff → Staff → Rod → Scepter** in en; both now stay
on посох / Staff.

`locale.ladder_name_drift` (warning) enforces it: some word of the first tier
name must appear inside a word of every other tier name, in every locale. The
substring test is deliberate — "Bow" survives into "Longbow", and Ukrainian
declines ("посох" → "посоха").

Where a label describes an inventory ROW rather than a shop listing, pass the
row's tier: `CapitalController.itemLabel(_:tier:lingo:locale:)`. The Master's
repair and enchant screens were showing a tier-5 weapon under its tier-1 name
while the profile and the inventory showed the real one.

## Current Keys (1002 en / 1050 uk as of 2026-09-10 — uk carries 13 player-gender `.m`/`.f` pairs, 33 `item.<id>.gender` declarations and the four-way `gear.broken.notice`; earlier: 975 / 987 on 2026-09-07 — uk has +13 from the gendered `.m`/`.f` pairs; parity checked both ways)

Capital Master (Phase 6.5): `capital.master.button.{buy,repair,enchant,back}`, `capital.master.{buy,repair,enchant}.{title,hint}` + `.repair.empty` / `.enchant.empty`, `capital.master.{bought,repaired,enchanted,max_level,missing_materials}` (17 keys; reuses `capital.location.master.{title,body}` + `capital.trader.{silver_balance,not_enough_silver,bag_full}`).

Arena (Phase 8.3): 53 keys under `arena.*` — `arena.button.*` (reply-keyboard
labels for hub and live fight), `arena.hub.*`, `arena.log.*` (per-round lines),
`arena.result.*`, `arena.honor.*`, `arena.leaderboard.*`, `arena.league.*`. All
neutral; the fight labels are matched by text, so they must stay static.

Quests + journal (Phase 9.2): 33 keys under `quest.*` and 10/11 under `journal.*`.
Quest keys split into UI (`quest.button.*`, `quest.progress`, `quest.reward*`,
`quest.done_today`, `quest.banner.paid`, `quest.not_enough`, `quest.not_complete`)
and content — `quest.<npc>.board_title` plus `quest.<id>.title` / `.desc` for the
nine jobs, all built dynamically from `QuestNPC.boardTitleKey` and
`QuestDef.titleKey` / `.descKey`, so grepping for the literal key finds nothing.
`quest.reward.xp` / `quest.reward.vigor` carry the unit words (uk: `Досвіду`,
`Снаги`) so the glossary stays in one place. Journal keys are neutral except
`journal.title`, which names the player (намісника/-иці) and therefore has
`.m`/`.f`.

### Full historical list (may lag — grep the JSON for the source of truth)
- UI: yes, no, commands.start/cancel/exit/settings/language/profile/explore/estate/capital/inventory
- Settings: settings.title, settings.language.prompt
- Help: welcome, here.are.commands, help.*, how.to.*
- Registration: registration.welcome (Artanian intro), registration.nickname.too_short/too_long/edge_space/consecutive_spaces/invalid_chars (validation toasts), registration.name_accepted (greeting + class intro), registration.class.prompt/warrior/archer/mage (+ .desc for each), registration.king_oath (with %{weapon}), registration.weapon.warrior/archer/mage, registration.to_estate, registration.journey_dog, registration.estate.prompt/too_short/too_long/edge_space/consecutive_spaces/invalid_chars, registration.complete, registration.gender.prompt/m/f (step-1 picker)
- Bot lifecycle: bot.restarted (lore-flavoured restart greeting; sent on startup with the player's controller-specific reply keyboard for registered users, or a one-time `/start` button for unregistered ones — message text no longer hard-codes the `/start` hint since registered players see their normal nav)
- Combat (Phase 4.1; reply-keyboard since 2026-05-27): combat.button.<action>.<class> — 9 reply-keyboard button labels (Attack/Defend/Flee × warrior/archer/mage). Combat actions are matched by these label texts (registered per class × locale in `CombatController.attachHandlers`), so the labels must stay static — no dynamic suffix (the `× N` use counter that used to ride the inline technique labels now lives in the submenu message body). combat.encounter.intro for the round-1 framing line. combat.you.{hit,crit,miss} / combat.enemy.{hit,crit,miss} for round narration (each interpolates `%{enemy}` and `%{damage}` where applicable). combat.defend.absorbed for the parry-counter chip line. combat.flee.{success,fail} for retreat outcomes. combat.victory / combat.defeat for end-of-fight headers. combat.in_progress — one-line nudge ("you're locked in combat with X — finish the fight first") sent when the player taps anything outside the inline action buttons mid-fight. registration.fight_dog (Stand and fight button) and registration.dog_retry (soft-retry preamble after defeat / flee at the registration tutorial rabid-dog fight; uk has .m/.f variants).
- Combat (Phase 4.2): submenu opener combat.button.techniques + combat.tech.back + combat.tech.no_uses_left (defensive message for stale taps after a technique counter went to 0) + combat.tech.prompt (sub-keyboard header) + combat.tech.none_available (shown when no technique is usable — replaces the old `🔒` locked buttons; both added 2026-05-27 with the reply-keyboard switch). Super stances: combat.button.super.<class> + combat.super.<class>.activate (interpolates `%{rounds}`) + combat.super.<class>.expire + combat.super.already_active. Special Attacks: combat.button.special_atk.<class> + combat.special_atk.<class>.{hit,crit} for archer/mage, plus combat.special_atk.warrior.miss for Cleave. Special Defenses: combat.button.special_def.<class> + combat.special_def.<class>.activate, plus combat.special_def.mage.no_damage for the Mirror Ward "wouldn't have hit anyway" branch. Persistent-effect status indicators: combat.effect.armor_split / combat.effect.shadow_veil (each interpolates `%{rounds}`). All Phase 4.2 narrative strings are stored emoji-free — Lingo's `%{var}` parser breaks on leading UTF-16 surrogate pairs, so CombatController prepends class-flavoured icons (🩸/🦅/✨ Super, 🪓/🎯/🔥 Special Atk hits, 🏰/🌑/🪞 Special Def, plus universal 💥 crit / 💨 miss / 🛡 / 🌑 indicators) at render time via static helpers.
- Profile: profile.level/xp/health/vigor/attack/defense/accuracy/dodge/crit/gold/estate
- Stubs: stub.coming_soon (shared placeholder for not-yet-implemented features)
- Items: item.food.*, item.mat.*, item.potion.*, item.gear.*, item.artifact.* (display names for catalog entries)
- Inventory UI: inventory.title, inventory.empty, inventory.type.food/material/potion/gear/artifact, inventory.choose_category, inventory.back_root, inventory.info.placeholder, inventory.use.unavailable, inventory.category.empty (toast for tapping an empty category), inventory.full (backpack cap toast), inventory.slots_label (for the X/50 header indicator)
- Inventory actions (per item type): inventory.action.food/potion/gear/artifact — each includes its emoji + verb ("🍴 Eat", "🍷 Use", "🛡 Equip", "✨ Use"). Gear also has `inventory.action.gear.unequip` ("❌ Unequip") used when the row is currently equipped.
- Equipment: equip.success / unequip.success — **plain text** (no HTML, no leading emoji) since they're rendered as inline status lines in InventoryController via the refreshCategory `statusLine` parameter. profile.equipped.main_hand label; profile.equipped.empty placeholder for an empty slot.
- Estate (Phase 5 scaffolding): estate.title, estate.description (placeholder lore), estate.level_label, estate.home, estate.plot (both also used as titles in drilldown), estate.home.description, estate.workshop, estate.kitchen, estate.warehouse, estate.warehouse.description, estate.warehouse.empty, estate.warehouse.deposited / withdrawn / nothing_to_deposit / nothing_to_withdraw (transfer toasts), estate.back_root, estate.back_home
- Vigor / consume: vigor.restored / hp.restored — interpolate `%{amount}` (gain), `%{current}`, `%{max}` so eat-success status reads "+15 vigor (20/100)". vigor.starving, consume.not_consumable, consume.no_effect, consume.not_raw_edible (used as modal-alert text via showAlert: true; plain text only).
- Exploration (Phase 3.1 + 3.2): exploration.button.step / exploration.button.step_back / exploration.button.bag (reply keyboard), exploration.started/resumed (entry intro), exploration.depth_label, exploration.outcome.loot.picked/loot.full/trip/encounter.won/encounter.lost/starvation (step narratives), exploration.returned (main-menu farewell), exploration.death (with %{cause}), exploration.bag.title/empty/back
- Exploration visit-decay variants (Phase 3.2): three `.nothing` narratives — exploration.outcome.nothing (fresh, prior visits = 0), exploration.outcome.nothing.revisited (thinned, prior visits = 1), exploration.outcome.nothing.bare (depleted, prior visits ≥ 2)
- Passive expedition (Phase 3.3): exploration.mode.prompt/active/passive (mode picker), exploration.duration.prompt/30m/1h/1h30m/back (duration picker), exploration.passive.started/inflight (confirmation + countdown, with %{time} interpolation), exploration.passive.test_mode_hint, exploration.passive.report.title/depth/hp/vigor/events_header/loot_header/no_loot/loot_partial/death/close (report rendering), exploration.passive.outcome.nothing/loot/encounter_won/encounter_lost/trip/starvation (one-word labels for outcome histogram)
- Mode exclusivity (Phase 3.4): capital.blocked_by_expedition (capital entry guard notice). The Explore keyboard label is static — gating happens at entry via showExploration's passive-countdown branch.
- Enemies: enemy.wild_boar, enemy.wild_moose, enemy.wild_buffalo, enemy.rabid_lynx, enemy.rabid_wolf, enemy.wild_bear, enemy.rabid_bear (7 wilderness animals across 6 tiers; reference doc at `content/bestiary.md`) + enemy.training_dummy (Phase 5.1 sparring target — only spawned by the Training Ground plot, never by exploration).
- Iron resources (Phase 5.1): item.mat.iron (Iron Lump 🔩 — raw, gathered) + item.mat.iron_ingot (Iron Ingot 🔳 — crafted, planned Workshop recipe). The legacy `mat.old_iron` was retired and its locale keys removed; DB rows wiped via `RemoveOldIron` migration.
- Plots (Phase 5.1): plot.type.{farm,forest,mine,coop,training_ground}.{name,desc} (the 5 plot types; `forest` is locale-named "Lumberyard" / "Лісопилка" — raw value retained for DB compat). plot.ready.notification (push when a plot's primary accumulator hits cap). estate.plot.list.title ("Estate grounds" / "Ділянка"), estate.plot.list.header (slots-used line), estate.plot.row.{claimed,empty,training} row formats, estate.plot.button.{harvest,claim,train} (emoji prepended in Swift since `🚜` / `🥋` are supplementary-plane), estate.plot.picker.{header,back}, estate.plot.rate.{per_hour,per_minute}, estate.plot.alert.{slot_out_of_range,slot_taken,slot_empty,harvest_empty,claimed,harvested,harvested_multi,training_exited}, estate.plot.ready_mark (currently empty per user pref). combat.button.training_exit ("🚪 Exit" — replaces Flee in training; renamed from "🔙 Back" 2026-05-27 to avoid a reply-keyboard text collision with the techniques "🔙 Back"), combat.training.dummy_revived (auto-revive narrative).
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
