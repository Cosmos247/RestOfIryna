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
    private func onFortune(context: Context) async throws -> Bool { try await renderLocation(.fortune, context: context); return true }
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
    /// message shape in both cases. Goes through `sendScenicPhoto` so
    /// the file_id cache + scenery cleanup apply.
    public static func sendWelcome(toUser user: User, bot: TGBot, lingo: Lingo) async throws {
        let text = lingo.localize("capital.welcome", locale: user.locale)
        let markup = Controllers.capitalController.generateControllerKB(session: user, lingo: lingo)
        _ = try await sendScenicPhoto(
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
        // `sendScenicPhoto` handles missing-file fallback (text-only)
        // AND file_id caching AND scenery-slot cleanup uniformly.
        _ = try await sendScenicPhoto(
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
    // Entry screen is the "menu" — atmospheric intro, gold balance, two
    // buttons [💰 Buy] / [💸 Sell]. Each section is its own list view
    // edited in-place over the menu, with a [🔙 Back] returning to the
    // menu. Buy list shows every catalog listing; Sell list filters to
    // items the player has at least one packet of (less clutter, no
    // dead taps).
    //
    // Refresh policy: a buy refreshes the buy list (gold balance updates,
    // rows are static); a sell refreshes the sell list (a row may
    // disappear if the player no longer has packet-worth of that item).
    // Status banners ride along via `postStatusBanner`.

    func showTrader(context: Context) async throws {
        let text = renderTraderMenuBody(session: context.session, lingo: context.lingo)
        let keyboard = traderMenuKeyboard(lingo: context.lingo, locale: context.session.locale)
        _ = try await sendScenicPhoto(
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
        let goldLabel = lingo.localize("capital.trader.gold_balance", locale: locale, interpolations: [
            "gold": "\(session.gold)"
        ])
        return "<b>\(title)</b>\n\n\(intro)\n\n💰 \(goldLabel)"
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
        return TGInlineKeyboardMarkup(inlineKeyboard: [[
            TGInlineKeyboardButton(text: buyLabel,  callbackData: "trader:buylist"),
            TGInlineKeyboardButton(text: sellLabel, callbackData: "trader:selllist")
        ]])
    }

    private func editToTraderMenu(messageId: Int, isPhoto: Bool, context: Context) async throws {
        let text = renderTraderMenuBody(session: context.session, lingo: context.lingo)
        let keyboard = traderMenuKeyboard(lingo: context.lingo, locale: context.session.locale)
        await editTraderScreen(messageId: messageId, isPhoto: isPhoto, context: context, text: text, keyboard: keyboard)
    }

    // MARK: Buy list

    private func renderBuyBody(session: User, lingo: Lingo) -> String {
        let locale = session.locale
        let title = lingo.localize("capital.trader.buy_title", locale: locale)
        let goldLabel = lingo.localize("capital.trader.gold_balance", locale: locale, interpolations: [
            "gold": "\(session.gold)"
        ])
        return "<b>\(title)</b>\n\n💰 \(goldLabel)"
    }

    private func buyListKeyboard(lingo: Lingo, locale: String) -> TGInlineKeyboardMarkup {
        let goldSuffix = lingo.localize("capital.trader.gold_short", locale: locale)
        let oneLabel = lingo.localize("capital.trader.button.buy_one", locale: locale)
        let nLabel   = lingo.localize("capital.trader.button.bulk_n",  locale: locale)
        var rows: [[TGInlineKeyboardButton]] = []
        for listing in TraderCatalog.all {
            guard let item = ItemCatalog.find(listing.itemId) else { continue }
            let iconPrefix = item.icon.map { "\($0) " } ?? ""
            let name = lingo.localize(item.nameKey, locale: locale)
            // Row 1 — info label (tap shows item lore in a modal).
            let priceText = listing.buyPacketQty == 1
                ? "\(listing.buyPacketGold)\(goldSuffix)"
                : "\(listing.buyPacketQty)·\(listing.buyPacketGold)\(goldSuffix)"
            let infoLabel = "\(iconPrefix)\(name) · \(priceText)"
            rows.append([TGInlineKeyboardButton(text: infoLabel, callbackData: "trader:info:\(listing.itemId)")])
            // Row 2 — actions: ×1 + custom N. No All for buy (gold + slots
            // bound the upper limit, so "buy max" is ambiguous).
            rows.append([
                TGInlineKeyboardButton(text: oneLabel, callbackData: "trader:buy:\(listing.itemId)"),
                TGInlineKeyboardButton(text: nLabel,   callbackData: "trader:buyN:\(listing.itemId)")
            ])
        }
        let back = lingo.localize("capital.trader.button.back_to_menu", locale: locale)
        rows.append([TGInlineKeyboardButton(text: back, callbackData: "trader:menu")])
        return TGInlineKeyboardMarkup(inlineKeyboard: rows)
    }

    private func editToBuyList(messageId: Int, isPhoto: Bool, context: Context) async throws {
        let text = renderBuyBody(session: context.session, lingo: context.lingo)
        let keyboard = buyListKeyboard(lingo: context.lingo, locale: context.session.locale)
        await editTraderScreen(messageId: messageId, isPhoto: isPhoto, context: context, text: text, keyboard: keyboard)
    }

    // MARK: Sell list

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
        let goldLabel = lingo.localize("capital.trader.gold_balance", locale: locale, interpolations: [
            "gold": "\(session.gold)"
        ])
        var body = "<b>\(title)</b>\n\n💰 \(goldLabel)"
        if sellable.isEmpty {
            let empty = lingo.localize("capital.trader.sell_empty", locale: locale)
            body += "\n\n<i>\(empty)</i>"
        }
        return body
    }

    private func sellListKeyboard(lingo: Lingo, locale: String, sellable: [(TraderListing, Int)]) -> TGInlineKeyboardMarkup {
        let goldSuffix = lingo.localize("capital.trader.gold_short", locale: locale)
        let oneLabel = lingo.localize("capital.trader.button.sell_one", locale: locale)
        let nLabel   = lingo.localize("capital.trader.button.bulk_n",   locale: locale)
        var rows: [[TGInlineKeyboardButton]] = []
        for (listing, qty) in sellable {
            guard let item = ItemCatalog.find(listing.itemId) else { continue }
            let iconPrefix = item.icon.map { "\($0) " } ?? ""
            let name = lingo.localize(item.nameKey, locale: locale)
            // Row 1 — info label.
            let priceText = listing.sellPacketQty == 1
                ? "\(listing.sellPacketGold)\(goldSuffix)"
                : "\(listing.sellPacketQty)·\(listing.sellPacketGold)\(goldSuffix)"
            let infoLabel = "\(iconPrefix)\(name) · 🎒 \(qty) · \(priceText)"
            rows.append([TGInlineKeyboardButton(text: infoLabel, callbackData: "trader:info:\(listing.itemId)")])
            // Row 2 — actions: ×1 + custom N. (Sell-all button retired —
            // ×N with typed quantity covers the dump-everything case.)
            rows.append([
                TGInlineKeyboardButton(text: oneLabel, callbackData: "trader:sell:\(listing.itemId)"),
                TGInlineKeyboardButton(text: nLabel,   callbackData: "trader:sellN:\(listing.itemId)")
            ])
        }
        let back = lingo.localize("capital.trader.button.back_to_menu", locale: locale)
        rows.append([TGInlineKeyboardButton(text: back, callbackData: "trader:menu")])
        return TGInlineKeyboardMarkup(inlineKeyboard: rows)
    }

    private func editToSellList(messageId: Int, isPhoto: Bool, context: Context) async throws {
        let sellable = try await sellableListings(for: context.session, on: context.db)
        let text = renderSellBody(session: context.session, lingo: context.lingo, sellable: sellable)
        let keyboard = sellListKeyboard(lingo: context.lingo, locale: context.session.locale, sellable: sellable)
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

        // Trader info modal — same UX convention as the warehouse:
        // description if available, "no description yet" placeholder otherwise.
        if data.hasPrefix("trader:info:") {
            let itemId = String(data.dropFirst("trader:info:".count))
            let answer: TGAnswerCallbackQueryParams
            if let item = ItemCatalog.find(itemId), let descKey = item.descriptionKey {
                let description = context.lingo.localize(descKey, locale: context.session.locale)
                answer = TGAnswerCallbackQueryParams(callbackQueryId: query.id, text: description, showAlert: true)
            } else if let item = ItemCatalog.find(itemId) {
                let itemName = context.lingo.localize(item.nameKey, locale: context.session.locale)
                let toast = context.lingo.localize("inventory.info.placeholder", locale: context.session.locale, interpolations: ["name": itemName])
                answer = TGAnswerCallbackQueryParams(callbackQueryId: query.id, text: toast, showAlert: true)
            } else {
                answer = TGAnswerCallbackQueryParams(callbackQueryId: query.id)
            }
            _ = try? await context.bot.answerCallbackQuery(params: answer)
            return true
        }

        // Trader actions — sell/buy 1 unit, banner result, refresh.
        if data.hasPrefix("trader:sell:") {
            let itemId = String(data.dropFirst("trader:sell:".count))
            let result = try await TraderService.sell(itemId: itemId, quantity: 1, for: context.session, on: context.db)
            _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id))
            await ctrl.postTraderResultBanner(forSell: result, itemId: itemId, context: context)
            try await ctrl.editToSellList(messageId: message.messageId, isPhoto: isPhoto, context: context)
            return true
        }

        if data.hasPrefix("trader:buy:") {
            let itemId = String(data.dropFirst("trader:buy:".count))
            let result = try await TraderService.buy(itemId: itemId, quantity: 1, for: context.session, on: context.db)
            _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id))
            await ctrl.postTraderResultBanner(forBuy: result, itemId: itemId, context: context)
            try await ctrl.editToBuyList(messageId: message.messageId, isPhoto: isPhoto, context: context)
            return true
        }

        // Custom-N prompts — open the "How many?" prompt and stash
        // pending state. The next text update will be consumed in
        // `unmatched`.
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

        // Food purchase — debit gold, deposit dish, banner + refresh.
        if data.hasPrefix("tavern:food:buy:") {
            let itemId = String(data.dropFirst("tavern:food:buy:".count))
            let result = try await TavernService.buyDish(itemId: itemId, for: context.session, on: context.db)
            _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id))
            await ctrl.postTavernBuyBanner(result: result, itemId: itemId, context: context)
            try await ctrl.editToTavernMenu(messageId: message.messageId, isPhoto: isPhoto, context: context)
            return true
        }

        // Phase 1 — wager taken. Edit to "Ready?" screen with the [Roll]
        // + [Cancel] buttons. Gold isn't debited yet — cancel here costs
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

        return false
    }

    private func postTraderResultBanner(forSell result: TraderService.SellResult, itemId: String, context: Context) async {
        let lingo = context.lingo
        let locale = context.session.locale
        let itemName = ItemCatalog.find(itemId).map { lingo.localize($0.nameKey, locale: locale) } ?? itemId
        switch result {
        case .success(_, let qty, let gold):
            let text = lingo.localize("capital.trader.sold", locale: locale, interpolations: [
                "item": itemName, "qty": "\(qty)", "gold": "\(gold)"
            ])
            await postStatusBanner("✅ \(text)", context: context)
        case .notEnoughInBag(let have, let need):
            let text = lingo.localize("capital.trader.not_enough_bag", locale: locale, interpolations: [
                "item": itemName, "have": "\(have)", "need": "\(need)"
            ])
            await postStatusBanner("❌ \(text)", context: context)
        case .unknownListing:
            // Stale catalogue / dev typo. Silent — banner would just confuse the player.
            break
        }
    }

    private func postTraderResultBanner(forBuy result: TraderService.BuyResult, itemId: String, context: Context) async {
        let lingo = context.lingo
        let locale = context.session.locale
        let itemName = ItemCatalog.find(itemId).map { lingo.localize($0.nameKey, locale: locale) } ?? itemId
        switch result {
        case .success(_, let qty, let gold):
            let text = lingo.localize("capital.trader.bought", locale: locale, interpolations: [
                "item": itemName, "qty": "\(qty)", "gold": "\(gold)"
            ])
            await postStatusBanner("✅ \(text)", context: context)
        case .notEnoughGold(let have, let need):
            let text = lingo.localize("capital.trader.not_enough_gold", locale: locale, interpolations: [
                "have": "\(have)", "need": "\(need)"
            ])
            await postStatusBanner("❌ \(text)", context: context)
        case .inventoryFull(let free, let need):
            let text = lingo.localize("capital.trader.bag_full", locale: locale, interpolations: [
                "free": "\(free)", "need": "\(need)"
            ])
            await postStatusBanner("❌ \(text)", context: context)
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
    /// gold didn't change).
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

        switch pending.direction {
        case .sell:
            let result = try await TraderService.sell(itemId: pending.itemId, quantity: quantity, for: context.session, on: context.db)
            await postTraderResultBanner(forSell: result, itemId: pending.itemId, context: context)
            try await editToSellList(messageId: pending.traderScreenMessageId, isPhoto: pending.isPhoto, context: context)
        case .buy:
            let result = try await TraderService.buy(itemId: pending.itemId, quantity: quantity, for: context.session, on: context.db)
            await postTraderResultBanner(forBuy: result, itemId: pending.itemId, context: context)
            try await editToBuyList(messageId: pending.traderScreenMessageId, isPhoto: pending.isPhoto, context: context)
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
    // reads the returned 1-6 value, and applies the gold delta. Two rolls
    // per player so a single round produces a 2-12 sum — more atmospheric
    // than a single roll. Between the player's two dice and the house's
    // two dice the runner sleeps ~4 s so the animations finish before the
    // result text lands.

    func showTavern(context: Context) async throws {
        // Same photo as `renderLocation(.tavern)` would use, but with the
        // tavern-specific inline keyboard ([🍲 Меню][🎲 Кості][🎯 Влучанка])
        // attached instead of the plain capital reply-keyboard. Goes
        // through `sendScenicPhoto` so file_id cache + scenery cleanup
        // both apply.
        let lingo = context.lingo
        let locale = context.session.locale
        let title = lingo.localize(Location.tavern.titleKey, locale: locale)
        let body  = lingo.localize(Location.tavern.bodyKey,  locale: locale)
        let text  = "<b>\(title)</b>\n\n\(body)"
        let inline = tavernEntryKeyboard(lingo: lingo, locale: locale)
        _ = try await sendScenicPhoto(
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
        return TGInlineKeyboardMarkup(inlineKeyboard: [[
            TGInlineKeyboardButton(text: menu,  callbackData: "tavern:food"),
            TGInlineKeyboardButton(text: dice,  callbackData: "tavern:dice"),
            TGInlineKeyboardButton(text: darts, callbackData: "tavern:darts")
        ]])
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
        let goldLabel = lingo.localize("capital.trader.gold_balance", locale: locale, interpolations: [
            "gold": "\(session.gold)"
        ])
        return "<b>\(title)</b>\n\n💰 \(goldLabel)"
    }

    private func tavernMenuKeyboard(lingo: Lingo, locale: String) -> TGInlineKeyboardMarkup {
        let goldSuffix = lingo.localize("capital.trader.gold_short", locale: locale)
        var rows: [[TGInlineKeyboardButton]] = []
        for listing in TavernCatalog.food {
            guard let item = ItemCatalog.find(listing.itemId) else { continue }
            let iconPrefix = item.icon.map { "\($0) " } ?? ""
            let name = lingo.localize(item.nameKey, locale: locale)
            // Format: "🍠 Baked Potato · 3g". One tap = one dish.
            let label = "\(iconPrefix)\(name) · \(listing.priceGold)\(goldSuffix)"
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
        let goldLabel = lingo.localize("capital.trader.gold_balance", locale: locale, interpolations: [
            "gold": "\(session.gold)"
        ])
        return "<b>\(title)</b>\n\n<i>\(subtitle)</i>\n\n💰 \(goldLabel)"
    }

    private func wagerKeyboard(lingo: Lingo, locale: String, callbackPrefix: String) -> TGInlineKeyboardMarkup {
        let goldSuffix = lingo.localize("capital.trader.gold_short", locale: locale)
        var wagerRow: [TGInlineKeyboardButton] = []
        for wager in TavernCatalog.wagerTiers {
            let label = "💰 \(wager)\(goldSuffix)"
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
    // with [🎲 Кинути кубік] / [🎯 Кинути дротик] + [❌ Скасувати]. No gold
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
        let wagerLine = lingo.localize("capital.tavern.gamble.wager_taken", locale: locale, interpolations: ["wager": "\(wager)"])
        let readyPrompt = lingo.localize("capital.tavern.gamble.ready_prompt", locale: locale)
        let text = "<b>\(title)</b>\n\n💰 \(wagerLine)\n\n\(readyPrompt)"

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

        // Gold could have changed between wager-tap and roll-tap (other
        // expense in a parallel session, etc) — re-validate.
        if context.session.gold < wager {
            let text = lingo.localize("capital.tavern.not_enough_gold", locale: locale, interpolations: [
                "have": "\(context.session.gold)", "need": "\(wager)"
            ])
            await postStatusBanner("❌ \(text)", context: context)
            return
        }

        // Debit now. From this point on the round runs to completion —
        // no cancel mid-roll. Per-user dispatch serialises so the ~10 s
        // sequence below only blocks this player.
        context.session.gold -= wager
        try await context.session.saveAndCache(in: context.db)

        let throwCount = emoji == "🎲" ? 2 : 1

        // Player label + dice.
        let playerLabel = "\(emoji) " + lingo.localize("capital.tavern.gamble.player_throws", locale: locale)
        _ = try await context.bot.sendMessage(params: TGSendMessageParams(
            chatId: chatId, text: playerLabel, parseMode: .html
        ))
        var playerValues: [Int] = []
        for _ in 0..<throwCount {
            let dice = try await context.bot.sendDice(params: TGSendDiceParams(chatId: chatId, emoji: emoji))
            playerValues.append(dice.dice?.value ?? 1)
        }
        try? await Task.sleep(nanoseconds: 4_000_000_000)

        // Innkeeper label + dice.
        let houseLabel = "\(emoji) " + lingo.localize("capital.tavern.gamble.house_throws", locale: locale)
        _ = try await context.bot.sendMessage(params: TGSendMessageParams(
            chatId: chatId, text: houseLabel, parseMode: .html
        ))
        var houseValues: [Int] = []
        for _ in 0..<throwCount {
            let dice = try await context.bot.sendDice(params: TGSendDiceParams(chatId: chatId, emoji: emoji))
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
            context.session.gold += wager * 2
            try await context.session.saveAndCache(in: context.db)
            symbol = "✅"
            outcomeText = lingo.localize("capital.tavern.gamble.outcome_win", locale: locale, interpolations: ["wager": "\(wager)"])
        case .lose:
            symbol = "❌"
            outcomeText = lingo.localize("capital.tavern.gamble.outcome_lose", locale: locale, interpolations: ["wager": "\(wager)"])
        case .tie:
            context.session.gold += wager
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
        let resultText = "\(emoji) \(scoreLine)\n\(symbol) \(outcomeText) · 💰 \(context.session.gold)"

        // Result message carries replay + back buttons.
        let replayKind = emoji == "🎲" ? "dice" : "darts"
        let replayLabel = lingo.localize("capital.tavern.gamble.button.replay", locale: locale)
        let backLabel = lingo.localize("capital.tavern.button.back", locale: locale)
        let resultKeyboard = TGInlineKeyboardMarkup(inlineKeyboard: [[
            TGInlineKeyboardButton(text: replayLabel, callbackData: "tavern:roll:\(replayKind):\(wager)"),
            TGInlineKeyboardButton(text: backLabel,   callbackData: "tavern:menu")
        ]])
        _ = try await context.bot.sendMessage(params: TGSendMessageParams(
            chatId: chatId,
            text: resultText,
            parseMode: .html,
            replyMarkup: .inlineKeyboardMarkup(resultKeyboard)
        ))

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
        switch result {
        case .success(_, let gold):
            let text = lingo.localize("capital.tavern.bought", locale: locale, interpolations: [
                "item": itemName, "gold": "\(gold)"
            ])
            await postStatusBanner("✅ \(text)", context: context)
        case .notEnoughGold(let have, let need):
            let text = lingo.localize("capital.tavern.not_enough_gold", locale: locale, interpolations: [
                "have": "\(have)", "need": "\(need)"
            ])
            await postStatusBanner("❌ \(text)", context: context)
        case .inventoryFull(let free, _):
            let text = lingo.localize("capital.tavern.bag_full", locale: locale, interpolations: [
                "free": "\(free)"
            ])
            await postStatusBanner("❌ \(text)", context: context)
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
