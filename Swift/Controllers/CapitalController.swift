//
//  CapitalController.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 19.04.2026.
//  Reworked for Phase 6.0 on 16.05.2026.
//
//  The capital is the second hub city of the kingdom. The player travels to
//  it from their estate (a two-minute trip handled by `TravelService`), and
//  once there picks between six locations — Market, PvP Arena, Trader,
//  Fortune Teller, Master, Tavern. Each is a stub for now; they'll grow
//  their own controllers as Phase 6.x lands feature by feature.
//
//  Reply-keyboard nav: the six locations + Leave Capital + Inventory /
//  Profile utility buttons take over the bottom keyboard while the player
//  is in town. Tapping a location swaps the message body without touching
//  the keyboard — so a player can hop from Tavern to Market in two taps
//  without backtracking through a root menu.
//

import Fluent
import Foundation
@preconcurrency import Lingo
import SwiftTelegramBot

// MARK: - Capital Controller

final class CapitalController: TGControllerBase, @unchecked Sendable {
    typealias T = CapitalController

    // MARK: Locations

    /// The six MVP locations. Each one renders a single localized body for
    /// now; concrete sub-screens (trader inventory, arena matchmaking, etc.)
    /// will arrive in their own Phase 6.x patches.
    enum Location: String, CaseIterable {
        case market
        case arena
        case trader
        case fortune
        case master
        case tavern

        var titleKey: String  { "capital.location.\(rawValue).title" }
        var bodyKey: String   { "capital.location.\(rawValue).body" }
        var buttonKey: String { "capital.button.\(rawValue)" }
    }

    static let leaveButtonKey = "capital.button.leave"

    // MARK: - Controller Lifecycle

    override public func attachHandlers(to bot: TGBot, lingo: Lingo) async {
        let router = Router(bot: bot) { router in
            router[Commands.start.command()] = onStart

            // Cancel keeps its standard "back to main" semantics, useful as
            // an escape hatch if the player somehow lands in capital without
            // the leave-capital button visible (shouldn't happen, but cheap
            // to keep).
            let cancelLocales = Commands.cancel.buttonsForAllLocales(lingo: lingo)
            for button in cancelLocales { router[button.text] = onCancel }

            // Utility buttons on the capital keyboard delegate straight to
            // their canonical controllers — inventory + profile are useful
            // from anywhere and don't require returning home.
            router[Commands.inventory.command()] = onInventory
            let inventoryLocales = Commands.inventory.buttonsForAllLocales(lingo: lingo)
            for button in inventoryLocales { router[button.text] = onInventory }

            router[Commands.profile.command()] = onProfile
            let profileLocales = Commands.profile.buttonsForAllLocales(lingo: lingo)
            for button in profileLocales { router[button.text] = onProfile }

            // Settings stays reachable via /settings — no button on the
            // capital keyboard (player rarely changes language mid-game).
            let settingsLocales = Commands.settings.buttonsForAllLocales(lingo: lingo)
            for button in settingsLocales { router[button.text] = onSettings }

            // Six location buttons — register the localized text for every
            // supported locale so the dispatcher matches regardless of which
            // language the player happens to have on screen.
            for locale in SupportedLocale.allCases {
                router[lingo.localize(Location.market.buttonKey,  locale: locale)] = onMarket
                router[lingo.localize(Location.arena.buttonKey,   locale: locale)] = onArena
                router[lingo.localize(Location.trader.buttonKey,  locale: locale)] = onTrader
                router[lingo.localize(Location.fortune.buttonKey, locale: locale)] = onFortune
                router[lingo.localize(Location.master.buttonKey,  locale: locale)] = onMaster
                router[lingo.localize(Location.tavern.buttonKey,  locale: locale)] = onTavern
            }

            // Leave-capital triggers the return trip back to the estate.
            for locale in SupportedLocale.allCases {
                router[lingo.localize(Self.leaveButtonKey, locale: locale)] = onLeave
            }

            // Phase 6.1 — inline-button callbacks for the trader and (later)
            // other location screens. Single dispatcher in
            // `onCallbackQuery` parses the prefix.
            router[.callback_query(data: nil)] = CapitalController.onCallbackQuery

            router.unmatched = unmatched
        }
        await processRouterForEachName(router)
    }

    // MARK: - Top-level handlers

    public func onStart(context: Context) async throws -> Bool {
        // /start always lands the player in the main hub, regardless of
        // their physical location. They can re-enter the capital from there
        // (showCapital below detects `user.location == "capital"` and skips
        // the travel timer in that case).
        let mainController = Controllers.mainController
        try await mainController.showMainMenu(context: context)
        context.session.routerName = mainController.routerName
        try await context.session.saveAndCache(in: context.db)
        return true
    }

    private func onCancel(context: Context) async throws -> Bool {
        return try await onStart(context: context)
    }

    private func onInventory(context: Context) async throws -> Bool {
        // Phase 6.1 bugfix: keep routerName at "capital" so subsequent taps
        // on capital reply-keyboard buttons (Ринок / Торговець / Шинок etc.)
        // still route to this controller. Inventory drill-down uses inline
        // `inv:*` callbacks; those are forwarded in `onCallbackQuery` below.
        // Otherwise routerName=inventory would route every capital button
        // tap to InventoryController, whose unmatched fallback re-renders
        // inventory — locking the player out of the capital nav.
        try await Controllers.inventoryController.showInventory(context: context)
        return true
    }

    private func onProfile(context: Context) async throws -> Bool {
        try await Controllers.mainController.showProfile(context: context)
        return true
    }

    private func onSettings(context: Context) async throws -> Bool {
        let controller = Controllers.settingsController
        try await controller.showSettingsMenu(context: context)
        context.session.routerName = controller.routerName
        try await context.session.saveAndCache(in: context.db)
        return true
    }

    override func unmatched(context: Context) async throws -> Bool {
        guard try await super.unmatched(context: context) else { return false }

        // Trader bulk-N prompt — incoming text is the quantity the
        // player typed in response to "Скільки X?". Consume here so we
        // don't fall through to the welcome render.
        if let text = context.update.message?.text,
           let pending = await EphemeralChatState.shared.peekPendingTraderTransfer(telegramId: context.session.telegramId) {
            try await handleTraderBulkInput(text: text, pending: pending, context: context)
            return true
        }

        // Random text falls back to re-rendering the welcome screen.
        try await renderWelcome(context: context)
        return true
    }

    // MARK: - Location handlers

    private func onMarket(context: Context)  async throws -> Bool { try await renderLocation(.market,  context: context); return true }
    private func onArena(context: Context)   async throws -> Bool { try await renderLocation(.arena,   context: context); return true }
    private func onTrader(context: Context)  async throws -> Bool { try await showTrader(context: context); return true }
    private func onFortune(context: Context) async throws -> Bool { try await showFortune(context: context); return true }
    private func onMaster(context: Context)  async throws -> Bool { try await renderLocation(.master,  context: context); return true }
    private func onTavern(context: Context)  async throws -> Bool { try await showTavern(context: context); return true }

    private func onLeave(context: Context) async throws -> Bool {
        try await startReturnTrip(context: context)
        return true
    }

    // MARK: - Public entry

    /// Single entry point called from `MainController.onCapital`. Branches:
    ///   - on expedition → "governor away" notice (estate-style block);
    ///   - on travel → countdown banner (defensive — Main should already
    ///     have guarded this);
    ///   - at estate → start the trip to the capital;
    ///   - at capital → render the welcome screen and own the routerName
    ///     transition.
    public func showCapital(context: Context) async throws {
        if try await ExplorationState.current(for: context.session, on: context.db) != nil {
            let notice = context.lingo.localize("capital.blocked_by_expedition", locale: context.session.locale)
            try await context.bot.sendMessage(
                session: context.session,
                text: notice,
                parseMode: .html,
                replyMarkup: nil
            )
            return
        }

        if let trip = try await TravelState.current(for: context.session, on: context.db) {
            try await renderTravelInProgress(context: context, trip: trip)
            return
        }

        if context.session.location == "capital" {
            // Already in town — just (re-)render the welcome and ensure the
            // routerName + capital reply-keyboard are in place.
            context.session.routerName = routerName
            try await context.session.saveAndCache(in: context.db)
            try await renderWelcome(context: context)
            return
        }

        // location == "estate" — start the trip.
        try await startTripToCapital(context: context)
    }

    // MARK: - Travel start helpers

    private func startTripToCapital(context: Context) async throws {
        try await Self.beginTrip(destination: .capital, context: context)
    }

    private func startReturnTrip(context: Context) async throws {
        try await Self.beginTrip(destination: .estate, context: context)
    }

    /// Shared trip-start orchestrator. Handles the TravelService call,
    /// flips routerName to main (so the player sees the main reply-keyboard
    /// while waiting out the timer), renders the "you set out" message, and
    /// maps every StartFailure to a user-facing banner. Used by
    /// `showCapital`, `onLeave`, and `EstateController.showEstate` (when
    /// the player is in capital and taps Estate).
    static func beginTrip(destination: TravelDestination, context: Context) async throws {
        do {
            let state = try await TravelService.start(
                for: context.session,
                destination: destination,
                on: context.db,
                bot: context.bot,
                lingo: context.lingo
            )
            // Player is on the road — main reply-keyboard takes over so the
            // utility buttons (Profile/Inventory/Settings) are reachable.
            // Estate/Capital/Explore taps fall into MainController's travel
            // guard and show the countdown banner instead of executing.
            context.session.routerName = Controllers.mainController.routerName
            try await context.session.saveAndCache(in: context.db)
            try await Controllers.capitalController.renderTripStarted(
                context: context, destination: destination, endsAt: state.endsAt
            )
        } catch TravelService.StartFailure.dead {
            try await Controllers.capitalController.postCannotStart(context: context, key: "travel.cannot_start.no_hp")
        } catch TravelService.StartFailure.starving {
            try await Controllers.capitalController.postCannotStart(context: context, key: "travel.cannot_start.no_vigor")
        } catch TravelService.StartFailure.onExpedition {
            try await Controllers.capitalController.postCannotStart(context: context, key: "capital.blocked_by_expedition")
        } catch TravelService.StartFailure.alreadyTraveling {
            if let trip = try await TravelState.current(for: context.session, on: context.db) {
                try await Controllers.capitalController.renderTravelInProgress(context: context, trip: trip)
            }
        } catch TravelService.StartFailure.alreadyAtDestination {
            // Caller's guard should have caught this; render a neutral
            // hub view so the player isn't left without context.
            if destination == .capital {
                try await Controllers.capitalController.renderWelcome(context: context)
            } else {
                try await Controllers.mainController.showMainMenu(context: context)
            }
        }
    }

    // MARK: - Rendering

    private func renderWelcome(context: Context) async throws {
        try await Self.sendWelcome(toUser: context.session, bot: context.bot, lingo: context.lingo)
    }

    /// Send the capital welcome screen (atmospheric prose + capital reply-
    /// keyboard, with `Assets/capital/welcome.jpg` attached if present).
    /// Used both from request handlers via the instance `renderWelcome`
    /// and from `TravelService.pushArrival` on capital arrival — same
    /// message shape in both cases. Goes through `sendCachedPhoto` so
    /// the file_id cache applies (photo is kept in chat history).
    public static func sendWelcome(toUser user: User, bot: TGBot, lingo: Lingo) async throws {
        let text = lingo.localize("capital.welcome", locale: user.locale)
        let markup = Controllers.capitalController.generateControllerKB(session: user, lingo: lingo)
        _ = try await sendCachedPhoto(
            assetPath: "\(projectPath)/Assets/capital/welcome.jpg",
            caption: text,
            replyMarkup: markup,
            toUser: user,
            bot: bot
        )
    }

    private func renderLocation(_ location: Location, context: Context) async throws {
        let lingo = context.lingo
        let locale = context.session.locale
        let title = lingo.localize(location.titleKey, locale: locale)
        let body  = lingo.localize(location.bodyKey,  locale: locale)
        let text  = "<b>\(title)</b>\n\n\(body)"
        let markup = generateControllerKB(session: context.session, lingo: lingo)

        // Per-location artwork at `Assets/capital/<location-id>.jpg`.
        // `sendCachedPhoto` handles missing-file fallback (text-only)
        // AND file_id caching uniformly; photo is kept in chat history.
        _ = try await sendCachedPhoto(
            assetPath: "\(projectPath)/Assets/capital/\(location.rawValue).jpg",
            caption: text,
            replyMarkup: markup,
            toUser: context.session,
            bot: context.bot
        )
    }

    private func renderTripStarted(context: Context, destination: TravelDestination, endsAt: Date) async throws {
        let lingo = context.lingo
        let locale = context.session.locale
        let key = destination == .capital ? "travel.to_capital.started" : "travel.to_estate.started"
        let remaining = max(0, Int(endsAt.timeIntervalSinceNow.rounded()))
        // 🐎 prepended in Swift — leading supplementary-plane emoji breaks
        // Lingo's `%{var}` parser. See .memory/localization.md.
        let text = "🐎 " + lingo.localize(key, locale: locale, interpolations: [
            "remaining": TravelService.formatCountdown(remaining)
        ])
        // While en-route the player belongs to the main hub — Profile /
        // Settings / Inventory should be usable, but Estate / Capital /
        // Explore taps go through MainController's travel guard.
        let markup = Controllers.mainController.generateControllerKB(session: context.session, lingo: lingo)
        try await context.bot.sendMessage(session: context.session, text: text, parseMode: .html, replyMarkup: markup)
    }

    /// Shared countdown banner for any place that needs to tell the player
    /// "you're on the road, X:XX left". Lives here because Capital owns the
    /// trip-start UX; MainController and friends call it via the public
    /// helper below.
    private func renderTravelInProgress(context: Context, trip: TravelState) async throws {
        let lingo = context.lingo
        let locale = context.session.locale
        let destKey = trip.destination == .capital ? "travel.destination.capital" : "travel.destination.estate"
        let destLabel = lingo.localize(destKey, locale: locale)
        // 🐎 prepended in Swift — leading supplementary-plane emoji breaks
        // Lingo's `%{var}` parser. See .memory/localization.md.
        let text = "🐎 " + lingo.localize("travel.in_progress", locale: locale, interpolations: [
            "destination": destLabel,
            "remaining": TravelService.formatCountdown(trip.secondsRemaining())
        ])
        try await context.bot.sendMessage(session: context.session, text: text, parseMode: .html, replyMarkup: nil)
    }

    /// Convenience for other controllers (Main, Estate, Exploration) to
    /// emit the same countdown banner without re-implementing the lookup.
    public static func showTravelInProgress(context: Context, trip: TravelState) async throws {
        try await Controllers.capitalController.renderTravelInProgress(context: context, trip: trip)
    }

    private func postCannotStart(context: Context, key: String) async throws {
        let text = context.lingo.localize(key, locale: context.session.locale)
        try await context.bot.sendMessage(session: context.session, text: text, parseMode: .html, replyMarkup: nil)
    }

    // MARK: - Trader (Phase 6.1 — two-step UX)
    //
    // Entry screen is the "menu" — atmospheric intro, silver balance, two
    // buttons [💰 Buy] / [💸 Sell]. Each section is its own list view
    // edited in-place over the menu, with a [🔙 Back] returning to the
    // menu. Buy list shows every catalog listing; Sell list filters to
    // items the player has at least one packet of (less clutter, no
    // dead taps).
    //
    // Refresh policy: a buy refreshes the buy list (silver balance updates,
    // rows are static); a sell refreshes the sell list (a row may
    // disappear if the player no longer has packet-worth of that item).
    // Status banners ride along via `postStatusBanner`.

    func showTrader(context: Context) async throws {
        let text = renderTraderMenuBody(session: context.session, lingo: context.lingo)
        let keyboard = traderMenuKeyboard(lingo: context.lingo, locale: context.session.locale)
        _ = try await sendCachedPhoto(
            assetPath: "\(projectPath)/Assets/capital/trader.jpg",
            caption: text,
            replyMarkup: .inlineKeyboardMarkup(keyboard),
            toUser: context.session,
            bot: context.bot
        )
    }

    // MARK: Menu (entry screen)

    private func renderTraderMenuBody(session: User, lingo: Lingo) -> String {
        let locale = session.locale
        let title = lingo.localize("capital.location.trader.title", locale: locale)
        // intro carries its own inline HTML — lore prose + an italic closing
        // quote — so the renderer mustn't wrap it again.
        let intro = lingo.localize("capital.trader.intro", locale: locale)
        let silverLabel = lingo.localize("capital.trader.silver_balance", locale: locale, interpolations: [
            "silver": "\(session.silver)"
        ])
        return "<b>\(title)</b>\n\n\(intro)\n\n🪙 \(silverLabel)"
    }

    /// Single edit helper — picks editMessageCaption when the source message
    /// is a photo (the trader menu sends with `Assets/capital/trader.jpg`
    /// when available), editMessageText otherwise. All `editTo*` helpers
    /// below delegate here so the photo-vs-text decision lives in one place.
    private func editTraderScreen(messageId: Int, isPhoto: Bool, context: Context, text: String, keyboard: TGInlineKeyboardMarkup) async {
        let chatId = TGChatId.chat(context.session.telegramId)
        if isPhoto {
            _ = try? await context.bot.editMessageCaption(params: TGEditMessageCaptionParams(
                chatId: chatId,
                messageId: messageId,
                caption: text,
                parseMode: .html,
                replyMarkup: keyboard
            ))
        } else {
            _ = try? await context.bot.editMessageText(params: TGEditMessageTextParams(
                chatId: chatId,
                messageId: messageId,
                text: text,
                parseMode: .html,
                replyMarkup: keyboard
            ))
        }
    }

    private func traderMenuKeyboard(lingo: Lingo, locale: String) -> TGInlineKeyboardMarkup {
        let buyLabel  = lingo.localize("capital.trader.button.buy_section",  locale: locale)
        let sellLabel = lingo.localize("capital.trader.button.sell_section", locale: locale)
        // Inline Back-to-capital insurance — if the Telegram client has
        // collapsed the persistent reply keyboard after a chain of inline
        // messages, this gives the player a guaranteed exit. Tapping it
        // calls showCapital which re-attaches the reply keyboard via
        // sendWelcome.
        let backLabel = lingo.localize("capital.button.back_to_capital", locale: locale)
        return TGInlineKeyboardMarkup(inlineKeyboard: [
            [TGInlineKeyboardButton(text: buyLabel,  callbackData: "trader:buylist"),
             TGInlineKeyboardButton(text: sellLabel, callbackData: "trader:selllist")],
            [TGInlineKeyboardButton(text: backLabel, callbackData: "capital:back")]
        ])
    }

    private func editToTraderMenu(messageId: Int, isPhoto: Bool, context: Context) async throws {
        let text = renderTraderMenuBody(session: context.session, lingo: context.lingo)
        let keyboard = traderMenuKeyboard(lingo: context.lingo, locale: context.session.locale)
        await editTraderScreen(messageId: messageId, isPhoto: isPhoto, context: context, text: text, keyboard: keyboard)
    }

    // MARK: Buy — category picker

    /// Same body as the buy-item list: title + balance. Category picker has
    /// no per-row data on the screen, only the two category buttons in the
    /// keyboard.
    private func renderBuyBody(session: User, lingo: Lingo) -> String {
        let locale = session.locale
        let title = lingo.localize("capital.trader.buy_title", locale: locale)
        let silverLabel = lingo.localize("capital.trader.silver_balance", locale: locale, interpolations: [
            "silver": "\(session.silver)"
        ])
        return "<b>\(title)</b>\n\n🪙 \(silverLabel)"
    }

    /// Renders [🥩 Їжа] [🪨 Матеріали] + [🔙 До крамаря]. Mirrors the
    /// Inventory category UX so the player has the same "pick a section
    /// first" muscle memory in both screens.
    private func buyCategoryKeyboard(lingo: Lingo, locale: String) -> TGInlineKeyboardMarkup {
        let foodLabel = lingo.localize("capital.trader.cat.food", locale: locale)
        let matLabel  = lingo.localize("capital.trader.cat.materials", locale: locale)
        let back      = lingo.localize("capital.trader.button.back_to_menu", locale: locale)
        return TGInlineKeyboardMarkup(inlineKeyboard: [
            [TGInlineKeyboardButton(text: foodLabel, callbackData: "trader:buy:food"),
             TGInlineKeyboardButton(text: matLabel,  callbackData: "trader:buy:materials")],
            [TGInlineKeyboardButton(text: back, callbackData: "trader:menu")]
        ])
    }

    private func editToBuyList(messageId: Int, isPhoto: Bool, context: Context) async throws {
        let text = renderBuyBody(session: context.session, lingo: context.lingo)
        let keyboard = buyCategoryKeyboard(lingo: context.lingo, locale: context.session.locale)
        await editTraderScreen(messageId: messageId, isPhoto: isPhoto, context: context, text: text, keyboard: keyboard)
    }

    // MARK: Buy — items in category

    private func buyItemsKeyboard(category: ItemType, lingo: Lingo, locale: String) -> TGInlineKeyboardMarkup {
        var rows: [[TGInlineKeyboardButton]] = []
        for listing in TraderCatalog.all {
            guard let item = ItemCatalog.find(listing.itemId), item.type == category else { continue }
            let iconPrefix = item.icon.map { "\($0) " } ?? ""
            let name = lingo.localize(item.nameKey, locale: locale)
            // Single button per listing — tap opens the "How many?" prompt.
            // Item descriptions intentionally removed from the trader (still
            // available in the Inventory drill-down).
            let label = "\(iconPrefix)\(name) · 🪙 \(listing.buyPacketSilver)"
            rows.append([TGInlineKeyboardButton(text: label, callbackData: "trader:buyN:\(listing.itemId)")])
        }
        let back = lingo.localize("capital.trader.button.back_to_categories", locale: locale)
        rows.append([TGInlineKeyboardButton(text: back, callbackData: "trader:buylist")])
        return TGInlineKeyboardMarkup(inlineKeyboard: rows)
    }

    private func editToBuyItems(category: ItemType, messageId: Int, isPhoto: Bool, context: Context) async throws {
        let text = renderBuyBody(session: context.session, lingo: context.lingo)
        let keyboard = buyItemsKeyboard(category: category, lingo: context.lingo, locale: context.session.locale)
        await editTraderScreen(messageId: messageId, isPhoto: isPhoto, context: context, text: text, keyboard: keyboard)
    }

    // MARK: Sell — category picker

    /// Build the per-listing (item, in-bag-qty) pairs for the sell list,
    /// filtered to listings where the player has at least one full packet.
    /// Below the threshold the row would be a dead tap — better to hide it.
    private func sellableListings(for user: User, on db: any Database) async throws -> [(TraderListing, Int)] {
        guard let userId = user.id else { return [] }
        var out: [(TraderListing, Int)] = []
        for listing in TraderCatalog.all {
            let qty = try await InventoryEntry.totalQuantity(of: listing.itemId, for: userId, on: db)
            if qty >= listing.sellPacketQty {
                out.append((listing, qty))
            }
        }
        return out
    }

    private func renderSellBody(session: User, lingo: Lingo, sellable: [(TraderListing, Int)]) -> String {
        let locale = session.locale
        let title = lingo.localize("capital.trader.sell_title", locale: locale)
        let silverLabel = lingo.localize("capital.trader.silver_balance", locale: locale, interpolations: [
            "silver": "\(session.silver)"
        ])
        var body = "<b>\(title)</b>\n\n🪙 \(silverLabel)"
        if sellable.isEmpty {
            let empty = lingo.localize("capital.trader.sell_empty", locale: locale)
            body += "\n\n<i>\(empty)</i>"
        }
        return body
    }

    private func sellCategoryKeyboard(lingo: Lingo, locale: String) -> TGInlineKeyboardMarkup {
        let foodLabel = lingo.localize("capital.trader.cat.food", locale: locale)
        let matLabel  = lingo.localize("capital.trader.cat.materials", locale: locale)
        let back      = lingo.localize("capital.trader.button.back_to_menu", locale: locale)
        return TGInlineKeyboardMarkup(inlineKeyboard: [
            [TGInlineKeyboardButton(text: foodLabel, callbackData: "trader:sell:food"),
             TGInlineKeyboardButton(text: matLabel,  callbackData: "trader:sell:materials")],
            [TGInlineKeyboardButton(text: back, callbackData: "trader:menu")]
        ])
    }

    private func editToSellList(messageId: Int, isPhoto: Bool, context: Context) async throws {
        let sellable = try await sellableListings(for: context.session, on: context.db)
        let text = renderSellBody(session: context.session, lingo: context.lingo, sellable: sellable)
        let keyboard = sellCategoryKeyboard(lingo: context.lingo, locale: context.session.locale)
        await editTraderScreen(messageId: messageId, isPhoto: isPhoto, context: context, text: text, keyboard: keyboard)
    }

    // MARK: Sell — items in category

    private func sellItemsKeyboard(category: ItemType, lingo: Lingo, locale: String, sellable: [(TraderListing, Int)]) -> TGInlineKeyboardMarkup {
        var rows: [[TGInlineKeyboardButton]] = []
        for (listing, qty) in sellable {
            guard let item = ItemCatalog.find(listing.itemId), item.type == category else { continue }
            let iconPrefix = item.icon.map { "\($0) " } ?? ""
            let name = lingo.localize(item.nameKey, locale: locale)
            // Single button per listing — bag quantity stays so the player sees
            // how much they can dump without opening the prompt; tap opens the
            // "How many?" prompt directly.
            let label = "\(iconPrefix)\(name) · 🎒 \(qty) · 🪙 \(listing.sellPacketSilver)"
            rows.append([TGInlineKeyboardButton(text: label, callbackData: "trader:sellN:\(listing.itemId)")])
        }
        let back = lingo.localize("capital.trader.button.back_to_categories", locale: locale)
        rows.append([TGInlineKeyboardButton(text: back, callbackData: "trader:selllist")])
        return TGInlineKeyboardMarkup(inlineKeyboard: rows)
    }

    private func editToSellItems(category: ItemType, messageId: Int, isPhoto: Bool, context: Context) async throws {
        let sellable = try await sellableListings(for: context.session, on: context.db)
        let text = renderSellBody(session: context.session, lingo: context.lingo, sellable: sellable)
        let keyboard = sellItemsKeyboard(category: category, lingo: context.lingo, locale: context.session.locale, sellable: sellable)
        await editTraderScreen(messageId: messageId, isPhoto: isPhoto, context: context, text: text, keyboard: keyboard)
    }

    // MARK: - Trader callback dispatch

    static func onCallbackQuery(context: Context) async throws -> Bool {
        guard let query = context.update.callbackQuery else { return false }
        guard let message = query.message else { return false }
        guard let data = query.data else { return false }

        // Phase 6.1 bugfix: inventory drill-down stays usable while the
        // player is in the capital. `onInventory` leaves routerName at
        // "capital" so capital reply-keyboard taps keep working; the
        // tradeoff is that `inv:*` inline callbacks also land here and
        // need to be forwarded to InventoryController explicitly.
        if data.hasPrefix("inv:") {
            return try await InventoryController.onCallbackQuery(context: context)
        }

        let ctrl = Controllers.capitalController
        // The trader entry sends as photo when `Assets/capital/trader.jpg` is
        // present, otherwise as text. All subsequent edits must match — pass
        // this flag through every editTo* helper.
        let isPhoto = (message.getMessage()?.photo) != nil

        // Trader nav — switch between Menu / Buy / Sell views in place.
        if data == "trader:menu" {
            _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id))
            try await ctrl.editToTraderMenu(messageId: message.messageId, isPhoto: isPhoto, context: context)
            return true
        }
        if data == "trader:buylist" {
            _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id))
            try await ctrl.editToBuyList(messageId: message.messageId, isPhoto: isPhoto, context: context)
            return true
        }
        if data == "trader:selllist" {
            _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id))
            try await ctrl.editToSellList(messageId: message.messageId, isPhoto: isPhoto, context: context)
            return true
        }

        // Category-filtered item lists. Categories are limited to Food and
        // Materials — that's the full surface of what the trader handles.
        if data.hasPrefix("trader:buy:") {
            let cat = String(data.dropFirst("trader:buy:".count))
            guard let category = traderCategory(from: cat) else {
                _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id))
                return true
            }
            _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id))
            try await ctrl.editToBuyItems(category: category, messageId: message.messageId, isPhoto: isPhoto, context: context)
            return true
        }
        if data.hasPrefix("trader:sell:") {
            let cat = String(data.dropFirst("trader:sell:".count))
            guard let category = traderCategory(from: cat) else {
                _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id))
                return true
            }
            _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id))
            try await ctrl.editToSellItems(category: category, messageId: message.messageId, isPhoto: isPhoto, context: context)
            return true
        }

        // Trader item taps — the single item button opens the "How many?"
        // prompt directly. Pending state is stashed in EphemeralChatState and
        // consumed by `unmatched` on the next text update.
        if data.hasPrefix("trader:sellN:") {
            let itemId = String(data.dropFirst("trader:sellN:".count))
            _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id))
            try await ctrl.openTraderBulkPrompt(direction: .sell, itemId: itemId, traderScreenMessageId: message.messageId, isPhoto: isPhoto, context: context)
            return true
        }
        if data.hasPrefix("trader:buyN:") {
            let itemId = String(data.dropFirst("trader:buyN:".count))
            _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id))
            try await ctrl.openTraderBulkPrompt(direction: .buy, itemId: itemId, traderScreenMessageId: message.messageId, isPhoto: isPhoto, context: context)
            return true
        }
        if data == "trader:cancelN" {
            _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id))
            try await ctrl.cancelTraderBulkPrompt(context: context)
            return true
        }

        // MARK: Tavern (Phase 6.2)

        // Tavern nav — switch between entry / Menu / Dice / Darts views.
        // From a photo host (the original tavern bubble) we edit caption
        // in place; from a text host (a result message during gambling
        // replay flow) editing back to the photo entry would lose the
        // image, so send a fresh tavern entry message instead and leave
        // the result in chat history.
        if data == "tavern:menu" {
            _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id))
            if isPhoto {
                try await ctrl.editToTavernEntry(messageId: message.messageId, isPhoto: true, context: context)
            } else {
                try await ctrl.showTavern(context: context)
            }
            return true
        }
        if data == "tavern:food" {
            _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id))
            try await ctrl.editToTavernMenu(messageId: message.messageId, isPhoto: isPhoto, context: context)
            return true
        }
        if data == "tavern:dice" {
            _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id))
            try await ctrl.editToTavernDice(messageId: message.messageId, isPhoto: isPhoto, context: context)
            return true
        }
        if data == "tavern:darts" {
            _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id))
            try await ctrl.editToTavernDarts(messageId: message.messageId, isPhoto: isPhoto, context: context)
            return true
        }

        // Food purchase — debit silver, deposit dish, banner + refresh.
        if data.hasPrefix("tavern:food:buy:") {
            let itemId = String(data.dropFirst("tavern:food:buy:".count))
            let result = try await TavernService.buyDish(itemId: itemId, for: context.session, on: context.db)
            _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id))
            await ctrl.postTavernBuyBanner(result: result, itemId: itemId, context: context)
            try await ctrl.editToTavernMenu(messageId: message.messageId, isPhoto: isPhoto, context: context)
            return true
        }

        // Phase 1 — wager taken. Edit to "Ready?" screen with the [Roll]
        // + [Cancel] buttons. Silver isn't debited yet — cancel here costs
        // nothing.
        if data.hasPrefix("tavern:dice:wager:") {
            _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id))
            let wagerStr = String(data.dropFirst("tavern:dice:wager:".count))
            guard let wager = Int(wagerStr) else { return true }
            try await ctrl.editToWagerConfirm(emoji: "🎲", wager: wager, messageId: message.messageId, isPhoto: isPhoto, context: context)
            return true
        }
        if data.hasPrefix("tavern:darts:wager:") {
            _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id))
            let wagerStr = String(data.dropFirst("tavern:darts:wager:".count))
            guard let wager = Int(wagerStr) else { return true }
            try await ctrl.editToWagerConfirm(emoji: "🎯", wager: wager, messageId: message.messageId, isPhoto: isPhoto, context: context)
            return true
        }

        // Phase 2 — Roll button (initial or replay). `tavern:roll:dice:N`
        // / `tavern:roll:darts:N`. Same callback for replay from the
        // text result message — isPhoto computed from message type
        // selects the host-refresh branch automatically.
        if data.hasPrefix("tavern:roll:dice:") {
            _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id))
            let wagerStr = String(data.dropFirst("tavern:roll:dice:".count))
            guard let wager = Int(wagerStr) else { return true }
            try await ctrl.runRound(emoji: "🎲", wager: wager, hostMessageId: message.messageId, isPhoto: isPhoto, context: context)
            return true
        }
        if data.hasPrefix("tavern:roll:darts:") {
            _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id))
            let wagerStr = String(data.dropFirst("tavern:roll:darts:".count))
            guard let wager = Int(wagerStr) else { return true }
            try await ctrl.runRound(emoji: "🎯", wager: wager, hostMessageId: message.messageId, isPhoto: isPhoto, context: context)
            return true
        }

        // Phase 6.4 — Fortune Teller draw + back.
        if data == "fortune:draw" {
            _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id))
            try await handleFortuneDraw(context: context)
            return true
        }
        // Universal "back to capital" — used by fortune, trader, tavern
        // entry screens. `fortune:back` kept as alias for stale messages
        // sent before the rename.
        if data == "capital:back" || data == "fortune:back" {
            _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id))
            try await ctrl.showCapital(context: context)
            return true
        }

        // Unknown callback prefixes — forward to MainController which
        // owns `pstyle:` (profile style switch) + `explore:` + `combat:`
        // and has a default "delete stale inline message" fallback.
        // Returning false here would trigger Router's
        // unsupportedContentType ("Unsupported content type.") response,
        // which is noise — old buttons on stale messages shouldn't shout
        // at the player.
        return try await MainController.onCallbackQuery(context: context)
    }

    /// `[🔙 До столиці]` inline kb attached to every trader/tavern result
    /// banner. The trader/tavern photo bubble (which carries the same back
    /// button) often scrolls out of view after a few actions; the banner is
    /// the latest visible message, so giving it its own back-out button means
    /// the player is never left without a nav point.
    private func backToCapitalBannerKB(lingo: Lingo, locale: String) -> TGReplyMarkup {
        let label = lingo.localize("capital.button.back_to_capital", locale: locale)
        return .inlineKeyboardMarkup(TGInlineKeyboardMarkup(inlineKeyboard: [[
            TGInlineKeyboardButton(text: label, callbackData: "capital:back")
        ]]))
    }

    private func postTraderResultBanner(forSell result: TraderService.SellResult, itemId: String, context: Context) async {
        let lingo = context.lingo
        let locale = context.session.locale
        let itemName = ItemCatalog.find(itemId).map { lingo.localize($0.nameKey, locale: locale) } ?? itemId
        let backKB = backToCapitalBannerKB(lingo: lingo, locale: locale)
        switch result {
        case .success(_, let qty, let silver):
            // 🪙 + amount pre-built in Swift — Lingo's `%{var}` parser breaks
            // when a supplementary-plane emoji sits next to the variable
            // inside the template, leaving the literal `%{silver}` rendered.
            let text = lingo.localize("capital.trader.sold", locale: locale, interpolations: [
                "item": itemName, "qty": "\(qty)", "silver": "🪙 \(silver)"
            ])
            await postStatusBanner("✅ \(text)", context: context, replyMarkup: backKB)
        case .notEnoughInBag(let have, let need):
            let text = lingo.localize("capital.trader.not_enough_bag", locale: locale, interpolations: [
                "item": itemName, "have": "\(have)", "need": "\(need)"
            ])
            await postStatusBanner("❌ \(text)", context: context, replyMarkup: backKB)
        case .unknownListing:
            // Stale catalogue / dev typo. Silent — banner would just confuse the player.
            break
        }
    }

    private func postTraderResultBanner(forBuy result: TraderService.BuyResult, itemId: String, context: Context) async {
        let lingo = context.lingo
        let locale = context.session.locale
        let itemName = ItemCatalog.find(itemId).map { lingo.localize($0.nameKey, locale: locale) } ?? itemId
        let backKB = backToCapitalBannerKB(lingo: lingo, locale: locale)
        switch result {
        case .success(_, let qty, let silver):
            let text = lingo.localize("capital.trader.bought", locale: locale, interpolations: [
                "item": itemName, "qty": "\(qty)", "silver": "🪙 \(silver)"
            ])
            await postStatusBanner("✅ \(text)", context: context, replyMarkup: backKB)
        case .notEnoughSilver(let have, let need):
            let text = lingo.localize("capital.trader.not_enough_silver", locale: locale, interpolations: [
                "have": "\(have)", "need": "\(need)"
            ])
            await postStatusBanner("❌ \(text)", context: context, replyMarkup: backKB)
        case .inventoryFull(let free, let need):
            let text = lingo.localize("capital.trader.bag_full", locale: locale, interpolations: [
                "free": "\(free)", "need": "\(need)"
            ])
            await postStatusBanner("❌ \(text)", context: context, replyMarkup: backKB)
        case .unknownListing:
            break
        }
    }

    // MARK: - Trader bulk-N prompt flow

    /// Send the "Скільки X?" prompt + cancel button, stash pending state
    /// so the next text update from this user is treated as the typed
    /// quantity. Direction (sell/buy) controls both the prompt wording
    /// and which TraderService method runs on submit.
    fileprivate func openTraderBulkPrompt(direction: EphemeralChatState.PendingTraderTransfer.Direction, itemId: String, traderScreenMessageId: Int, isPhoto: Bool, context: Context) async throws {
        let lingo = context.lingo
        let locale = context.session.locale
        let itemName = ItemCatalog.find(itemId).map { lingo.localize($0.nameKey, locale: locale) } ?? itemId
        let promptKey = direction == .sell ? "capital.trader.bulkN.sell_prompt" : "capital.trader.bulkN.buy_prompt"
        let promptText = lingo.localize(promptKey, locale: locale, interpolations: ["item": itemName])
        let cancelLabel = lingo.localize("capital.trader.bulkN.cancel", locale: locale)
        let kb = TGInlineKeyboardMarkup(inlineKeyboard: [[
            TGInlineKeyboardButton(text: cancelLabel, callbackData: "trader:cancelN")
        ]])

        let sent = try await context.bot.sendMessage(params: TGSendMessageParams(
            chatId: .chat(context.session.telegramId),
            text: promptText,
            parseMode: .html,
            replyMarkup: .inlineKeyboardMarkup(kb)
        ))

        await EphemeralChatState.shared.setPendingTraderTransfer(
            telegramId: context.session.telegramId,
            transfer: EphemeralChatState.PendingTraderTransfer(
                itemId: itemId,
                direction: direction,
                promptMessageId: sent.messageId,
                traderScreenMessageId: traderScreenMessageId,
                isPhoto: isPhoto
            )
        )
    }

    /// Cancel the prompt — delete the prompt message + clear pending.
    /// Trader screen left as-is (no need to refresh — the player's bag /
    /// silver didn't change).
    fileprivate func cancelTraderBulkPrompt(context: Context) async throws {
        let telegramId = context.session.telegramId
        guard let pending = await EphemeralChatState.shared.takePendingTraderTransfer(telegramId: telegramId) else { return }
        _ = try? await context.bot.deleteMessage(params: TGDeleteMessageParams(
            chatId: .chat(telegramId),
            messageId: pending.promptMessageId
        ))
    }

    /// Consume the text the player typed in response to the prompt:
    /// validate as a positive integer, then dispatch to the matching
    /// TraderService method. Invalid input edits the prompt in place and
    /// keeps pending (next text retries); validation failure clears
    /// pending + deletes prompt + refreshes the trader with an error
    /// banner; success clears pending + deletes prompt + refreshes with
    /// the standard sold/bought banner.
    fileprivate func handleTraderBulkInput(text: String, pending: EphemeralChatState.PendingTraderTransfer, context: Context) async throws {
        let lingo = context.lingo
        let locale = context.session.locale
        let telegramId = context.session.telegramId

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let quantity = Int(trimmed), quantity > 0 else {
            // Invalid — edit prompt with error, keep pending so the
            // next typed message retries.
            let itemName = ItemCatalog.find(pending.itemId).map { lingo.localize($0.nameKey, locale: locale) } ?? pending.itemId
            let promptKey = pending.direction == .sell ? "capital.trader.bulkN.sell_prompt" : "capital.trader.bulkN.buy_prompt"
            let promptText = lingo.localize(promptKey, locale: locale, interpolations: ["item": itemName])
            let invalidText = lingo.localize("capital.trader.bulkN.invalid_number", locale: locale)
            let cancelLabel = lingo.localize("capital.trader.bulkN.cancel", locale: locale)
            let kb = TGInlineKeyboardMarkup(inlineKeyboard: [[
                TGInlineKeyboardButton(text: cancelLabel, callbackData: "trader:cancelN")
            ]])
            _ = try? await context.bot.editMessageText(params: TGEditMessageTextParams(
                chatId: .chat(telegramId),
                messageId: pending.promptMessageId,
                text: "\(promptText)\n\n❌ \(invalidText)",
                parseMode: .html,
                replyMarkup: kb
            ))
            return
        }

        // Valid number — clear pending up front so a slow trade doesn't
        // race with another text input.
        _ = await EphemeralChatState.shared.takePendingTraderTransfer(telegramId: telegramId)
        _ = try? await context.bot.deleteMessage(params: TGDeleteMessageParams(
            chatId: .chat(telegramId),
            messageId: pending.promptMessageId
        ))

        // Refresh the SAME category-filtered list the player was viewing
        // when they tapped the item — derive the category from the item's
        // type so we don't have to thread it through PendingTraderTransfer.
        let refreshCategory = ItemCatalog.find(pending.itemId)?.type ?? .material

        switch pending.direction {
        case .sell:
            let result = try await TraderService.sell(itemId: pending.itemId, quantity: quantity, for: context.session, on: context.db)
            await postTraderResultBanner(forSell: result, itemId: pending.itemId, context: context)
            try await editToSellItems(category: refreshCategory, messageId: pending.traderScreenMessageId, isPhoto: pending.isPhoto, context: context)
        case .buy:
            let result = try await TraderService.buy(itemId: pending.itemId, quantity: quantity, for: context.session, on: context.db)
            await postTraderResultBanner(forBuy: result, itemId: pending.itemId, context: context)
            try await editToBuyItems(category: refreshCategory, messageId: pending.traderScreenMessageId, isPhoto: pending.isPhoto, context: context)
        }
    }

    /// Map the URL-safe category slug carried in callback data
    /// (`trader:buy:<slug>` / `trader:sell:<slug>`) back to the `ItemType`
    /// used to filter the catalog. Limited to the two categories the trader
    /// actually handles — anything else returns nil and the caller swallows.
    private static func traderCategory(from slug: String) -> ItemType? {
        switch slug {
        case "food":      return .food
        case "materials": return .material
        default:          return nil
        }
    }

    // MARK: - Fortune Teller (Phase 6.4 — tarot daily-ish draw)
    //
    // Two states: idle (no active card OR previous one has expired) and
    // active (countdown until expiry, no draw button). The same screen
    // handles both — built from the player's User state at render time.
    // Tap of `[🔮 Тягнути карту]` calls `FortuneService.draw`, then
    // either shows the reveal (new bot message with the card photo +
    // meaning + buff description) OR keeps the entry screen with an
    // error banner. The reveal message goes through `sendCachedPhoto`
    // (file_id cache); like every location photo it stays in chat so the
    // player keeps a record of past draws.

    func showFortune(context: Context) async throws {
        let text = renderFortuneEntryBody(session: context.session, lingo: context.lingo)
        let inline = fortuneEntryKeyboard(session: context.session, lingo: context.lingo)
        _ = try await sendCachedPhoto(
            assetPath: "\(projectPath)/Assets/capital/fortune.jpg",
            caption: text,
            replyMarkup: .inlineKeyboardMarkup(inline),
            toUser: context.session,
            bot: context.bot
        )
    }

    private func renderFortuneEntryBody(session: User, lingo: Lingo) -> String {
        let locale = session.locale
        let title = lingo.localize(Location.fortune.titleKey, locale: locale)
        let intro = lingo.localize("capital.fortune.intro", locale: locale)
        var lines: [String] = ["<b>\(title)</b>", "", intro, ""]

        let cooldownLeft = session.fortuneCooldownRemaining()
        let buffLeft = session.fortuneSecondsRemaining()
        let activeCard: FortuneCard? = session.activeFortuneCardId.flatMap(FortuneCatalog.find)

        if let cooldown = cooldownLeft {
            // Draw still on cooldown. Two sub-states: buff still ticking
            // (show both timers + card name) vs buff already worn off
            // (show cooldown only).
            if let buff = buffLeft, let card = activeCard {
                let cardName = lingo.localize(card.nameKey, locale: locale)
                lines.append(lingo.localize("capital.fortune.status.with_buff", locale: locale, interpolations: [
                    "card": cardName,
                    "buff_remaining": formatHM(buff),
                    "cooldown_remaining": formatHM(cooldown)
                ]))
            } else {
                lines.append(lingo.localize("capital.fortune.status.cooldown_only", locale: locale, interpolations: [
                    "remaining": formatHM(cooldown)
                ]))
            }
        } else {
            // Draw available — show price + balance.
            let priceLine = lingo.localize("capital.fortune.price", locale: locale, interpolations: [
                "price": "\(FortuneCatalog.drawPrice)"
            ])
            let silverLabel = lingo.localize("capital.trader.silver_balance", locale: locale, interpolations: [
                "silver": "\(session.silver)"
            ])
            lines.append(priceLine)
            lines.append("🪙 \(silverLabel)")
        }
        return lines.joined(separator: "\n")
    }

    private func fortuneEntryKeyboard(session: User, lingo: Lingo) -> TGInlineKeyboardMarkup {
        let locale = session.locale
        let backLabel = lingo.localize("capital.button.back_to_capital", locale: locale)
        let backRow = [TGInlineKeyboardButton(text: backLabel, callbackData: "fortune:back")]

        // No draw button while on cooldown — but the [🔙 Back] button is
        // always present so the player can never be stuck on the fortune
        // screen (e.g. zero silver, no draw available).
        if session.fortuneCooldownRemaining() != nil {
            return TGInlineKeyboardMarkup(inlineKeyboard: [backRow])
        }
        let drawLabel = lingo.localize("capital.fortune.button.draw", locale: locale)
        return TGInlineKeyboardMarkup(inlineKeyboard: [
            [TGInlineKeyboardButton(text: drawLabel, callbackData: "fortune:draw")],
            backRow
        ])
    }

    /// Format a remaining-seconds count as `HH:MM` (we never need
    /// sub-minute precision for the 4-hour fortune window).
    private func formatHM(_ seconds: Int) -> String {
        let clamped = max(0, seconds)
        let h = clamped / 3600
        let m = (clamped % 3600) / 60
        return String(format: "%02d:%02d", h, m)
    }

    /// Render the reveal screen after a successful draw. Sends a fresh
    /// photo (the card portrait) with caption: meaning + buff
    /// description + countdown (for duration cards) + one-shot deltas
    /// (for instant cards).
    private func renderFortuneReveal(
        card: FortuneCard,
        oneShot: FortuneService.OneShotApplied,
        context: Context
    ) async throws {
        let lingo = context.lingo
        let locale = context.session.locale
        let cardName = lingo.localize(card.nameKey, locale: locale)
        let meaning  = lingo.localize(card.meaningKey, locale: locale)
        let buffDesc = lingo.localize(card.buffDescKey, locale: locale)

        var lines: [String] = []
        lines.append("🔮 <b>\(cardName)</b>")
        lines.append("")
        lines.append("<i>\(meaning)</i>")
        lines.append("")
        lines.append(buffDesc)

        // One-shot deltas applied at draw time — show the concrete impact.
        // Sign + 🪙 + amount pre-built in Swift; the locale string only has
        // `%{silver}` because a supplementary-plane emoji adjacent to
        // `%{var}` breaks Lingo's parser (leaves the literal `%{silver}`).
        if oneShot.silverDelta != 0 {
            let key = oneShot.silverDelta > 0 ? "capital.fortune.applied.silver_gain" : "capital.fortune.applied.silver_loss"
            let signedSilver = oneShot.silverDelta > 0
                ? "+🪙 \(oneShot.silverDelta)"
                : "−🪙 \(abs(oneShot.silverDelta))"
            let line = lingo.localize(key, locale: locale, interpolations: [
                "silver": signedSilver,
                "balance": "\(context.session.silver)"
            ])
            lines.append("")
            lines.append(line)
        }
        if oneShot.xpGained > 0 {
            let line = lingo.localize("capital.fortune.applied.xp_gain", locale: locale, interpolations: [
                "xp": "\(oneShot.xpGained)"
            ])
            lines.append(line)
        }
        if oneShot.hpRestored || oneShot.vigorRestored {
            let key: String
            if oneShot.hpRestored && oneShot.vigorRestored { key = "capital.fortune.applied.hp_vigor" }
            else if oneShot.hpRestored                     { key = "capital.fortune.applied.hp_only"  }
            else                                            { key = "capital.fortune.applied.vigor_only" }
            lines.append(lingo.localize(key, locale: locale))
        }

        // Countdown line for duration cards.
        if card.effect.hasDurationEffect, let secondsLeft = context.session.fortuneSecondsRemaining() {
            let line = lingo.localize("capital.fortune.applied.duration", locale: locale, interpolations: [
                "remaining": formatHM(secondsLeft)
            ])
            lines.append("")
            lines.append(line)
        }

        let text = lines.joined(separator: "\n")
        let backLabel = lingo.localize("capital.button.back_to_capital", locale: locale)
        let keyboard = TGInlineKeyboardMarkup(inlineKeyboard: [[
            TGInlineKeyboardButton(text: backLabel, callbackData: "fortune:back")
        ]])
        _ = try await sendCachedPhoto(
            assetPath: FortuneCatalog.assetPath(for: card.id),
            caption: text,
            replyMarkup: .inlineKeyboardMarkup(keyboard),
            toUser: context.session,
            bot: context.bot
        )
    }

    /// Static helper — handles the `fortune:draw` callback. Lives here
    /// (vs as a member) so it can be invoked directly from the
    /// `onCallbackQuery` dispatcher.
    fileprivate static func handleFortuneDraw(context: Context) async throws {
        let ctrl = Controllers.capitalController
        let result = try await FortuneService.draw(for: context.session, on: context.db)
        switch result {
        case .success(let card, let applied):
            try await ctrl.renderFortuneReveal(card: card, oneShot: applied, context: context)
        case .onCooldown(let secondsLeft):
            let lingo = context.lingo
            let locale = context.session.locale
            let text = lingo.localize("capital.fortune.error.cooldown", locale: locale, interpolations: [
                "remaining": ctrl.formatHM(secondsLeft)
            ])
            let backKB = ctrl.backToCapitalBannerKB(lingo: lingo, locale: locale)
            await ctrl.postStatusBanner("⏳ \(text)", context: context, replyMarkup: backKB)
        case .notEnoughSilver(let have, let need):
            let lingo = context.lingo
            let locale = context.session.locale
            let text = lingo.localize("capital.fortune.error.silver", locale: locale, interpolations: [
                "have": "\(have)", "need": "\(need)"
            ])
            let backKB = ctrl.backToCapitalBannerKB(lingo: lingo, locale: locale)
            await ctrl.postStatusBanner("❌ \(text)", context: context, replyMarkup: backKB)
        }
    }

    // MARK: - Tavern (Phase 6.2 — menu + dice + darts)
    //
    // Entry screen is the existing tavern photo with caption (Royal Seal
    // lore) plus three inline buttons: [🍲 Menu] [🎲 Dice] [🎯 Darts].
    // Each sub-screen edits caption + keyboard in place (same image stays
    // throughout) and carries a [🔙 Back] returning to the entry.
    //
    // Gambling sends animated Telegram dice / dart emoji via `sendDice`,
    // reads the returned 1-6 value, and applies the silver delta. Two rolls
    // per player so a single round produces a 2-12 sum — more atmospheric
    // than a single roll. Between the player's two dice and the house's
    // two dice the runner sleeps ~4 s so the animations finish before the
    // result text lands.

    func showTavern(context: Context) async throws {
        // Same photo as `renderLocation(.tavern)` would use, but with the
        // tavern-specific inline keyboard ([🍲 Меню][🎲 Кості][🎯 Влучанка])
        // attached instead of the plain capital reply-keyboard. Goes
        // through `sendCachedPhoto` so the file_id cache applies (photo
        // kept in chat history).
        let lingo = context.lingo
        let locale = context.session.locale
        let title = lingo.localize(Location.tavern.titleKey, locale: locale)
        let body  = lingo.localize(Location.tavern.bodyKey,  locale: locale)
        let text  = "<b>\(title)</b>\n\n\(body)"
        let inline = tavernEntryKeyboard(lingo: lingo, locale: locale)
        _ = try await sendCachedPhoto(
            assetPath: "\(projectPath)/Assets/capital/tavern.jpg",
            caption: text,
            replyMarkup: .inlineKeyboardMarkup(inline),
            toUser: context.session,
            bot: context.bot
        )
    }

    // MARK: Entry-screen rendering

    private func tavernEntryKeyboard(lingo: Lingo, locale: String) -> TGInlineKeyboardMarkup {
        let menu  = lingo.localize("capital.tavern.button.menu",  locale: locale)
        let dice  = lingo.localize("capital.tavern.button.dice",  locale: locale)
        let darts = lingo.localize("capital.tavern.button.darts", locale: locale)
        // Inline Back-to-capital insurance (see traderMenuKeyboard
        // comment) — re-attaches the reply keyboard if a chain of
        // inline messages caused the client to collapse it.
        let back  = lingo.localize("capital.button.back_to_capital", locale: locale)
        return TGInlineKeyboardMarkup(inlineKeyboard: [
            [TGInlineKeyboardButton(text: menu,  callbackData: "tavern:food"),
             TGInlineKeyboardButton(text: dice,  callbackData: "tavern:dice"),
             TGInlineKeyboardButton(text: darts, callbackData: "tavern:darts")],
            [TGInlineKeyboardButton(text: back, callbackData: "capital:back")]
        ])
    }

    private func editToTavernEntry(messageId: Int, isPhoto: Bool, context: Context) async throws {
        let lingo = context.lingo
        let locale = context.session.locale
        let title = lingo.localize(Location.tavern.titleKey, locale: locale)
        let body  = lingo.localize(Location.tavern.bodyKey,  locale: locale)
        let text  = "<b>\(title)</b>\n\n\(body)"
        let keyboard = tavernEntryKeyboard(lingo: lingo, locale: locale)
        await editTraderScreen(messageId: messageId, isPhoto: isPhoto, context: context, text: text, keyboard: keyboard)
    }

    // MARK: Menu (food list)

    private func renderTavernMenuBody(session: User, lingo: Lingo) -> String {
        let locale = session.locale
        let title = lingo.localize("capital.tavern.menu_title", locale: locale)
        let silverLabel = lingo.localize("capital.trader.silver_balance", locale: locale, interpolations: [
            "silver": "\(session.silver)"
        ])
        return "<b>\(title)</b>\n\n🪙 \(silverLabel)"
    }

    private func tavernMenuKeyboard(lingo: Lingo, locale: String) -> TGInlineKeyboardMarkup {
        var rows: [[TGInlineKeyboardButton]] = []
        for listing in TavernCatalog.food {
            guard let item = ItemCatalog.find(listing.itemId) else { continue }
            let iconPrefix = item.icon.map { "\($0) " } ?? ""
            let name = lingo.localize(item.nameKey, locale: locale)
            // Format: "🥔 Baked Potato · 🪙 20". One tap = one dish.
            let label = "\(iconPrefix)\(name) · 🪙 \(listing.priceSilver)"
            rows.append([TGInlineKeyboardButton(text: label, callbackData: "tavern:food:buy:\(listing.itemId)")])
        }
        let back = lingo.localize("capital.tavern.button.back", locale: locale)
        rows.append([TGInlineKeyboardButton(text: back, callbackData: "tavern:menu")])
        return TGInlineKeyboardMarkup(inlineKeyboard: rows)
    }

    private func editToTavernMenu(messageId: Int, isPhoto: Bool, context: Context) async throws {
        let text = renderTavernMenuBody(session: context.session, lingo: context.lingo)
        let keyboard = tavernMenuKeyboard(lingo: context.lingo, locale: context.session.locale)
        await editTraderScreen(messageId: messageId, isPhoto: isPhoto, context: context, text: text, keyboard: keyboard)
    }

    // MARK: Dice / Darts wager screens

    private func renderWagerBody(session: User, lingo: Lingo, titleKey: String, subtitleKey: String) -> String {
        let locale = session.locale
        let title = lingo.localize(titleKey, locale: locale)
        let subtitle = lingo.localize(subtitleKey, locale: locale)
        let silverLabel = lingo.localize("capital.trader.silver_balance", locale: locale, interpolations: [
            "silver": "\(session.silver)"
        ])
        return "<b>\(title)</b>\n\n<i>\(subtitle)</i>\n\n🪙 \(silverLabel)"
    }

    private func wagerKeyboard(lingo: Lingo, locale: String, callbackPrefix: String) -> TGInlineKeyboardMarkup {
        var wagerRow: [TGInlineKeyboardButton] = []
        for wager in TavernCatalog.wagerTiers {
            let label = "🪙 \(wager)"
            wagerRow.append(TGInlineKeyboardButton(text: label, callbackData: "\(callbackPrefix):wager:\(wager)"))
        }
        let back = lingo.localize("capital.tavern.button.back", locale: locale)
        return TGInlineKeyboardMarkup(inlineKeyboard: [
            wagerRow,
            [TGInlineKeyboardButton(text: back, callbackData: "tavern:menu")]
        ])
    }

    private func editToTavernDice(messageId: Int, isPhoto: Bool, context: Context) async throws {
        let text = renderWagerBody(
            session: context.session, lingo: context.lingo,
            titleKey: "capital.tavern.dice_title",
            subtitleKey: "capital.tavern.dice_subtitle"
        )
        let keyboard = wagerKeyboard(lingo: context.lingo, locale: context.session.locale, callbackPrefix: "tavern:dice")
        await editTraderScreen(messageId: messageId, isPhoto: isPhoto, context: context, text: text, keyboard: keyboard)
    }

    private func editToTavernDarts(messageId: Int, isPhoto: Bool, context: Context) async throws {
        let text = renderWagerBody(
            session: context.session, lingo: context.lingo,
            titleKey: "capital.tavern.darts_title",
            subtitleKey: "capital.tavern.darts_subtitle"
        )
        let keyboard = wagerKeyboard(lingo: context.lingo, locale: context.session.locale, callbackPrefix: "tavern:darts")
        await editTraderScreen(messageId: messageId, isPhoto: isPhoto, context: context, text: text, keyboard: keyboard)
    }

    // MARK: Gambling — two-phase flow (button-driven)
    //
    // Phase 1 — wager tap → `editToWagerConfirm`: shows a "Ready?" screen
    // with [🎲 Кинути кубік] / [🎯 Кинути дротик] + [❌ Скасувати]. No silver
    // movement yet — player can back out for free.
    //
    // Phase 2 — Roll button tap → `runRound`: debits the wager, runs the
    // full bot-driven sequence (player label → player dice → sleep →
    // innkeeper label → innkeeper dice → sleep → result + replay buttons).
    // All dice are bot-sent (Telegram doesn't let bots author messages as
    // the player); the text labels between pairs are how we distinguish
    // whose roll is whose visually.
    //
    // Throw counts: dice = 2 per side (sum 2-12), darts = 1 per side
    // (value 1-6, 6 = bullseye).

    /// Phase 1 — wager taken, show the Ready/Roll confirmation. Host can
    /// be a photo (initial wager screen) or text (result message after a
    /// previous round — handled identically here, edit-in-place either way).
    func editToWagerConfirm(emoji: String, wager: Int, messageId: Int, isPhoto: Bool, context: Context) async throws {
        let lingo = context.lingo
        let locale = context.session.locale
        let gameKind = emoji == "🎲" ? "dice" : "darts"

        let titleKey = emoji == "🎲" ? "capital.tavern.dice_title" : "capital.tavern.darts_title"
        let title = lingo.localize(titleKey, locale: locale)
        // 🪙 + amount pre-built in Swift — Lingo's `%{var}` parser breaks
        // when a supplementary-plane emoji sits next to the variable.
        let wagerLine = lingo.localize("capital.tavern.gamble.wager_taken", locale: locale, interpolations: ["wager": "🪙 \(wager)"])
        let readyPrompt = lingo.localize("capital.tavern.gamble.ready_prompt", locale: locale)
        let text = "<b>\(title)</b>\n\n\(wagerLine)\n\n\(readyPrompt)"

        let rollKey = emoji == "🎲" ? "capital.tavern.gamble.button.roll_dice" : "capital.tavern.gamble.button.roll_dart"
        let rollLabel = lingo.localize(rollKey, locale: locale)
        let cancelLabel = lingo.localize("capital.tavern.gamble.button.cancel", locale: locale)
        // Cancel goes back to the matching fresh wager view (`tavern:dice` /
        // `tavern:darts` callbacks already do that on tap).
        let keyboard = TGInlineKeyboardMarkup(inlineKeyboard: [
            [TGInlineKeyboardButton(text: rollLabel, callbackData: "tavern:roll:\(gameKind):\(wager)")],
            [TGInlineKeyboardButton(text: cancelLabel, callbackData: "tavern:\(gameKind)")]
        ])

        await editTraderScreen(messageId: messageId, isPhoto: isPhoto, context: context, text: text, keyboard: keyboard)
    }

    /// Phase 2 — debit the wager and run the full bot-sent rolling
    /// sequence: player label + N dice → sleep → innkeeper label + N dice
    /// → sleep → result message with [🔄 Replay][🔙 Back] buttons. N is 2
    /// for dice, 1 for darts (per design).
    func runRound(emoji: String, wager: Int, hostMessageId: Int, isPhoto: Bool, context: Context) async throws {
        let lingo = context.lingo
        let locale = context.session.locale
        let chatId = TGChatId.chat(context.session.telegramId)

        // Silver could have changed between wager-tap and roll-tap (other
        // expense in a parallel session, etc) — re-validate.
        if context.session.silver < wager {
            let text = lingo.localize("capital.tavern.not_enough_silver", locale: locale, interpolations: [
                "have": "\(context.session.silver)", "need": "\(wager)"
            ])
            let backKB = backToCapitalBannerKB(lingo: lingo, locale: locale)
            await postStatusBanner("❌ \(text)", context: context, replyMarkup: backKB)
            return
        }

        // Debit now. From this point on the round runs to completion —
        // no cancel mid-roll. Per-user dispatch serialises so the ~10 s
        // sequence below only blocks this player.
        context.session.silver -= wager
        try await context.session.saveAndCache(in: context.db)

        let throwCount = emoji == "🎲" ? 2 : 1

        // Every message this round sprays into chat — labels, animated dice,
        // and (below) the result line. We collect their ids and hand them to
        // `TavernCleanupService` for deletion once they age past 24 h.
        // Telegram forbids bots from deleting a dice message in a private
        // chat until it's 24 h old, so the round stays visible as game
        // history and the sweep clears it the moment it becomes deletable.
        var roundMessageIds: [Int] = []

        // Player label + dice.
        let playerLabel = "\(emoji) " + lingo.localize("capital.tavern.gamble.player_throws", locale: locale)
        let playerLabelMsg = try await context.bot.sendMessage(params: TGSendMessageParams(
            chatId: chatId, text: playerLabel, parseMode: .html
        ))
        roundMessageIds.append(playerLabelMsg.messageId)
        var playerValues: [Int] = []
        for _ in 0..<throwCount {
            let dice = try await context.bot.sendDice(params: TGSendDiceParams(chatId: chatId, emoji: emoji))
            roundMessageIds.append(dice.messageId)
            playerValues.append(dice.dice?.value ?? 1)
        }
        try? await Task.sleep(nanoseconds: 4_000_000_000)

        // Innkeeper label + dice.
        let houseLabel = "\(emoji) " + lingo.localize("capital.tavern.gamble.house_throws", locale: locale)
        let houseLabelMsg = try await context.bot.sendMessage(params: TGSendMessageParams(
            chatId: chatId, text: houseLabel, parseMode: .html
        ))
        roundMessageIds.append(houseLabelMsg.messageId)
        var houseValues: [Int] = []
        for _ in 0..<throwCount {
            let dice = try await context.bot.sendDice(params: TGSendDiceParams(chatId: chatId, emoji: emoji))
            roundMessageIds.append(dice.messageId)
            houseValues.append(dice.dice?.value ?? 1)
        }
        try? await Task.sleep(nanoseconds: 4_000_000_000)

        // Resolve.
        let playerScore = playerValues.reduce(0, +)
        let houseScore = houseValues.reduce(0, +)
        let outcome = TavernService.resolveWager(playerScore: playerScore, houseScore: houseScore)
        let symbol: String
        let outcomeText: String
        switch outcome {
        case .win:
            context.session.silver += wager * 2
            try await context.session.saveAndCache(in: context.db)
            symbol = "✅"
            outcomeText = lingo.localize("capital.tavern.gamble.outcome_win", locale: locale, interpolations: ["wager": "+🪙 \(wager)"])
        case .lose:
            symbol = "❌"
            outcomeText = lingo.localize("capital.tavern.gamble.outcome_lose", locale: locale, interpolations: ["wager": "−🪙 \(wager)"])
        case .tie:
            context.session.silver += wager
            try await context.session.saveAndCache(in: context.db)
            symbol = "⚪"
            outcomeText = lingo.localize("capital.tavern.gamble.outcome_tie", locale: locale)
        }

        // Score line — different template for 2-throw (dice) vs 1-throw
        // (darts) so the readout matches the game format.
        let scoreLine: String
        if throwCount == 2 {
            scoreLine = lingo.localize("capital.tavern.gamble.score_line_pair", locale: locale, interpolations: [
                "p1": "\(playerValues[0])", "p2": "\(playerValues[1])", "psum": "\(playerScore)",
                "b1": "\(houseValues[0])", "b2": "\(houseValues[1])", "bsum": "\(houseScore)"
            ])
        } else {
            scoreLine = lingo.localize("capital.tavern.gamble.score_line_single", locale: locale, interpolations: [
                "p1": "\(playerValues[0])", "b1": "\(houseValues[0])"
            ])
        }
        // Leading emoji prepended in Swift — the score line carries
        // %{var} interpolations and Lingo's parser breaks on a leading
        // surrogate-pair emoji in the template.
        let resultText = "\(emoji) \(scoreLine)\n\(symbol) \(outcomeText) · 🪙 \(context.session.silver)"

        // Result message carries replay + back buttons.
        let replayKind = emoji == "🎲" ? "dice" : "darts"
        let replayLabel = lingo.localize("capital.tavern.gamble.button.replay", locale: locale)
        let backLabel = lingo.localize("capital.tavern.button.back", locale: locale)
        let resultKeyboard = TGInlineKeyboardMarkup(inlineKeyboard: [[
            TGInlineKeyboardButton(text: replayLabel, callbackData: "tavern:roll:\(replayKind):\(wager)"),
            TGInlineKeyboardButton(text: backLabel,   callbackData: "tavern:menu")
        ]])
        let resultMsg = try await context.bot.sendMessage(params: TGSendMessageParams(
            chatId: chatId,
            text: resultText,
            parseMode: .html,
            replyMarkup: .inlineKeyboardMarkup(resultKeyboard)
        ))
        roundMessageIds.append(resultMsg.messageId)

        // Record the whole round for the 24 h cleanup sweep. Best-effort —
        // a DB hiccup just means this round lingers a little longer.
        try? await TavernCleanupService.record(messageIds: roundMessageIds, telegramId: context.session.telegramId, on: context.db)

        // For a photo host (initial wager screen) restore the wager view
        // so the player can scroll up and pick a different stake. For a
        // text host (replay flow's previous result message) leave it
        // alone — the new result message above already owns replay/back.
        if isPhoto {
            if emoji == "🎲" {
                try await editToTavernDice(messageId: hostMessageId, isPhoto: true, context: context)
            } else {
                try await editToTavernDarts(messageId: hostMessageId, isPhoto: true, context: context)
            }
        }
    }

    // MARK: Food-purchase result banner

    private func postTavernBuyBanner(result: TavernService.BuyDishResult, itemId: String, context: Context) async {
        let lingo = context.lingo
        let locale = context.session.locale
        let itemName = ItemCatalog.find(itemId).map { lingo.localize($0.nameKey, locale: locale) } ?? itemId
        let backKB = backToCapitalBannerKB(lingo: lingo, locale: locale)
        switch result {
        case .success(_, let silver):
            let text = lingo.localize("capital.tavern.bought", locale: locale, interpolations: [
                "item": itemName, "silver": "🪙 \(silver)"
            ])
            await postStatusBanner("✅ \(text)", context: context, replyMarkup: backKB)
        case .notEnoughSilver(let have, let need):
            let text = lingo.localize("capital.tavern.not_enough_silver", locale: locale, interpolations: [
                "have": "\(have)", "need": "\(need)"
            ])
            await postStatusBanner("❌ \(text)", context: context, replyMarkup: backKB)
        case .inventoryFull(let free, _):
            let text = lingo.localize("capital.tavern.bag_full", locale: locale, interpolations: [
                "free": "\(free)"
            ])
            await postStatusBanner("❌ \(text)", context: context, replyMarkup: backKB)
        case .unknownListing:
            break
        }
    }

    // MARK: - Keyboard

    override public func generateControllerKB(session: User, lingo: Lingo) -> TGReplyMarkup? {
        let l = lingo
        let loc = session.locale
        let market  = TGKeyboardButton(text: l.localize(Location.market.buttonKey,  locale: loc))
        let arena   = TGKeyboardButton(text: l.localize(Location.arena.buttonKey,   locale: loc))
        let trader  = TGKeyboardButton(text: l.localize(Location.trader.buttonKey,  locale: loc))
        let fortune = TGKeyboardButton(text: l.localize(Location.fortune.buttonKey, locale: loc))
        let master  = TGKeyboardButton(text: l.localize(Location.master.buttonKey,  locale: loc))
        let tavern  = TGKeyboardButton(text: l.localize(Location.tavern.buttonKey,  locale: loc))
        let leave   = TGKeyboardButton(text: l.localize(Self.leaveButtonKey,        locale: loc))
        let markup = TGReplyKeyboardMarkup(keyboard: [
            [market, arena],
            [trader, fortune],
            [master, tavern],
            [Commands.inventory.button(for: session, lingo),
             Commands.profile.button(for: session, lingo)],
            [leave]
        ], resizeKeyboard: true)
        return TGReplyMarkup.replyKeyboardMarkup(markup)
    }
}
