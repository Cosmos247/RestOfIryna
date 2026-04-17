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
Used by `/buttons` command to restore keyboards.

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
