# ROI Session Primer

Read this first. Then check `TODO.md` for current progress and `.memory/sessions.md` for what happened last session.

## What Is This

**Rest Of Iryna (ROI)** — a multiplayer medieval text RPG Telegram bot in Swift. Players fight rabid beasts, manage estates, trade, and wage territory wars. All interaction via text + emoji + inline keyboards.

## Stack

Swift 6.2 | Hummingbird 2.22+ (HTTP) | Fluent 4.13+ / PostgreSQL 16 | swift-telegram-sdk 4.6+ (TG Bot) | AsyncHTTPClient | Lingo 4 (i18n) | SwiftDotenv

## Architecture

Router-controller state machine. Each user has a `routerName` in DB. Updates flow: `TGUpdate -> TGDispatcher (auth) -> SessionCache -> RouterStore -> Controller[routerName]`. Controllers transition by setting `routerName` + `saveAndCache()`.

Source in `Swift/` (not `Sources/`). Controllers in `Swift/Controllers/`. Models in `Swift/Models/`. Router engine in `Swift/Telegram/Router/`.

## What Works Now

Phases 0–2 done; Phase 3 active + passive exploration shipped (mode picker, three-tier visit decay, passive scheduler with bot-restart resume); Phase 4.1+4.2+4.3.1+4.4 combat done (turn-based PvE with class-flavoured Attack/Defend/Flee + 9 class techniques + per-class flee chances + full bestiary of 7 wilderness mobs); Phase 5.0 estate skeleton + Warehouse + Phase 5.1 plot system + Phase 5.2 Workshop crafting + Phase 5.2.1 Kitchen cooking + Phase 5.2.2 weapon upgrade (5-tier ladder per class, materials drained from inventory+warehouse pool). **Phase 5.3a/b/c/d/e all landed (Phase 5 complete)**: real XP/level system (per-enemy `xpReward`, softcap curve, level-up + estate-up banners, profile XP bar) + stat growth on level-up (+5 maxHP / +1 ATK / +1 DEF at L2/3/5/6/9/12/15/18) + estate-tier gates (House rooms / Workshop categories / plot types / plot slot count / warehouse cap all gate on `User.estateLevel`) + **manual estate upgrade** (stored `User.estateLevel`, `EstateUpgradeCatalog` with 6 transitions, gold sink at T3+ from 50→1000g, `[🏠 Upgrade estate]` button on root with detail screen) + **craftable bag upgrades** (stored `User.bagTier`, `BagCatalog` 5 tiers 20→75 slots, `[🎒 Upgrade bag]` button in Workshop, hide + iron materials, estate-tier gates per step) + **technique gates** (L8/L11/L14 thresholds, `LearnedTechnique` per-user set, combat submenu shows 🔒 for unlearned kinds with locked-tap alert, Training Ground plot opens a Learn screen instead of direct sparring). **Phase 6 closed** (capital hub: travel, Trader, Tavern with dice/darts, Fortune Teller, Master with durability + enchant, player Market + synchronous Trade). **Phase 7.1** Guilds (found / roster / invites / item vault / silver treasury). **Phase 8.3** Arena — live real-time PvP duel with Honor ELO, stake settlement and a daily fight budget. **Phase 9.2** daily NPC quests — one auto-assigned job per NPC per game day for Trader / Master / Innkeeper, derived from a stable hash so nothing is scheduled or stored, plus the quest journal on the profile screen. Every daily system counts against `GameDay` (rolls at 12:00 Kyiv). EN + UK localization (956 / 977 keys). Auth still gated to 4 hardcoded TG IDs.

## What's Next

Check `TODO.md` for the live phase tracker. Phases 5, 6 and 7.1 are closed; Arena (8.3) and daily quests (9.2) shipped their first slice. Nearest open work: quest chains + weeklies and the remaining quest-givers (Fortune Teller, Arena herald, guild co-op goals) — deferred out of the quest v1; Arena queue auto-pairing + seasons; Phase 7.2 estate-attack PvP (new mechanic — the original 30×30 grid + adjacency design was abandoned 2026-05-11; replacement TBD); Phase 9.1 tuning pass and Phase 10 launch prep (webhooks, admin tools, opening auth beyond the hardcoded list).

## Key Files to Know

| File | What |
|------|------|
| `CLAUDE.md` | Full reference: architecture, patterns, conventions, git rules |
| `GDD.md` | Complete game design document |
| `TODO.md` | Implementation phases with progress markers |
| `.memory/INDEX.md` | Knowledge base index |
| `.memory/status.md` | Implemented vs planned features |
| `.memory/controller-pattern.md` | How to build controllers (code examples) |
| `Swift/configure.swift` | App bootstrap (DB, bot, lingo, hardcoded path) |
| `Swift/Controllers/AllControllers.swift` | Controller registry |
| `Swift/Helpers/TGBot+Extensions.swift` | TGControllerBase, Context.session |

## Rules

- Read `.memory/sessions.md` for context on previous work
- After significant work, update `.memory/sessions.md` and `TODO.md`
- On task completion, ask user before committing
- Commit messages: short, compact, no co-author line
- Never push — that's manual/user-side only
- New controllers follow the pattern in `.memory/controller-pattern.md`
- New localization keys go in BOTH en.json and uk.json
- Telegram callback_data max 64 bytes
