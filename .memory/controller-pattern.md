# Controller Pattern

## Creating a New Controller

### 1. Define the Controller Class

```swift
final class MyController: TGControllerBase, @unchecked Sendable {
    typealias T = MyController
    
    override public func attachHandlers(to bot: TGBot, lingo: Lingo) async {
        let router = Router(bot: bot) { router in
            // Slash commands
            router[Commands.start.command()] = onStart
            
            // Localized button text (register all locale variants)
            let cancelLocales = Commands.cancel.buttonsForAllLocales(lingo: lingo)
            for button in cancelLocales { router[button.text] = onCancel }
            
            // Custom text commands
            router["mycommand"] = onMyCommand
            
            // Callback queries
            router[.callback_query(data: nil)] = MyController.onCallbackQuery
            
            // Catch-all for unmatched input
            router.unmatched = unmatched
        }
        await processRouterForEachName(router)
    }
}
```

### 2. Register in AllControllers.swift

```swift
static let myController = MyController(routerName: "mycontroller")
static let all: [TGControllerBase] = [
    registration, mainController, settingsController, myController
]
```

### 3. Transition Between Controllers

```swift
// From any handler:
let targetController = Controllers.myController
context.session.routerName = targetController.routerName
try await context.session.saveAndCache(in: context.db)
// Optionally show the target controller's UI:
try await targetController.showSomething(context: context)
```

## Key Conventions

### Handler Signature
```swift
func handlerName(context: Context) async throws -> Bool
```
- Return `true` = update was handled
- Return `false` = not handled, try next path

### Keyboard Generation
Override `generateControllerKB(session:lingo:)` to define persistent reply keyboard.
Used by `/buttons` command to restore keyboards, and by the bot-restart notice in `configure.swift` to redraw whichever keyboard the player had before downtime.

A controller can return `nil` if it owns no reply keyboard. `CombatController` used to do this (combat was inline-button driven) but since the 2026-05-27 reply-keyboard switch it returns the combat keyboard itself: `generateControllerKB` hands back the default (non-training) `[Attack][Defend]/[🪄 Techniques][Flee]` layout — used by `/buttons` and the restart greeting — while the live round messages build the state-aware version (training swaps Flee for `[🚪 Exit]`) via `combatReplyKeyboard`. The combat keyboard replaces the player's previous one for the fight and is restored to the parent controller's keyboard on victory / flee / death.

**State-dependent keyboards are told, not asked.** `generateControllerKB` is
synchronous and has no database, so anything that depends on a row has to arrive as
a parameter — the pattern `CombatController` set (`combatReplyKeyboard(session:state:lingo:)`
swaps Flee for Exit in training) and `MainController` follows since 2026-09-10:
`mainKeyboard(session:lingo:traveling:)` lends the Explore slot to `↩️ Розвернутись`
while a trip is in flight, Explore being a dead key on the road anyway. Callers
holding the row pass true; the three async paths that can land mid-trip
(`showMainMenu`, `/menu`, the restart broadcast in `configure.swift`) query; the
`generateControllerKB` override keeps the resting layout. That last gap self-heals —
one tap on Estate or Capital re-sends the countdown banner, which knows.

**A refusal carries a keyboard.** `TGControllerBase.currentKeyboard(for:lingo:)`
returns the keyboard of the router the player is actually on, and every "you cannot
do that from here" notice sends it. A notice with no markup leaves whatever the last
message set, so a player whose keyboard has drifted keeps tapping buttons for a place
they are not in, with `/menu` the only way back. Better still, a guard re-renders the
screen that owns the state rather than only refusing: `guardInCombat` re-draws the
fight, so the mis-tap is also the tap that repairs the screen.

### Callback Queries
- Must be `static` methods (limitation of how they're registered)
- Always delete the inline keyboard message after processing
- Parse callback data with prefix matching: `data.starts(with: "prefix:")`
- Callback data budget: 64 bytes max (Telegram limit)

### Unmatched Handler
Override `unmatched(context:)`. Call `super.unmatched(context:)` first — it returns `false` for global commands (/help, /settings, /buttons) so they get handled by GlobalCommandsController instead.

### Context Properties
- `context.session` — current User (via `properties["session"]`)
- `context.bot` — TGBot instance
- `context.db` — Database handle
- `context.lingo` — Lingo localizer
- `context.update` — raw TGUpdate
- `context.message` — shortcut to TGMessage
- `context.args` — Arguments parser
- `context.privateChat` — Bool
- `context.chatId` / `context.fromId` — Int64?

### Sending Messages
```swift
// Via context (uses chatId from update)
try await context.respond("text")

// Via bot (uses session's telegramId — preferred for controller logic)
try await context.bot.sendMessage(session: context.session, text: "text", parseMode: .html, replyMarkup: markup)
```
