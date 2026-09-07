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
                router[lingo.localize("capital.button.guild",     locale: locale)] = onGuild
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

        // Market sell prompt — incoming text is the quantity (stage 1) or the
        // lot price (stage 2) the player typed. Consume here so it doesn't
        // fall through to the welcome render.
        if let text = context.update.message?.text,
           let pending = await EphemeralChatState.shared.peekPendingMarketListing(telegramId: context.session.telegramId) {
            try await handleMarketListingInput(text: text, pending: pending, context: context)
            return true
        }

        // Trade numeric prompt — incoming text is the silver amount or the
        // quantity of a stackable to offer in a live player-to-player trade.
        if let text = context.update.message?.text,
           let pending = await EphemeralChatState.shared.peekPendingTradeInput(telegramId: context.session.telegramId) {
            try await handleTradeInput(text: text, pending: pending, context: context)
            return true
        }

        // Random text falls back to re-rendering the welcome screen.
        try await renderWelcome(context: context)
        return true
    }

    // MARK: - Location handlers

    private func onMarket(context: Context)  async throws -> Bool { try await showMarket(context: context); return true }
    private func onArena(context: Context)   async throws -> Bool { try await onArenaEnter(context: context); return true }
    private func onTrader(context: Context)  async throws -> Bool { try await showTrader(context: context); return true }
    private func onFortune(context: Context) async throws -> Bool { try await showFortune(context: context); return true }
    private func onMaster(context: Context)  async throws -> Bool { try await showMaster(context: context); return true }
    private func onTavern(context: Context)  async throws -> Bool { try await showTavern(context: context); return true }

    /// The Guildhall is a full controller, not an inline sub-flow — flip
    /// routerName to "guild" (GuildController takes over the reply keyboard) and
    /// render its home. `guild.button.back` flips routerName back to "capital".
    private func onGuild(context: Context) async throws -> Bool {
        let guild = Controllers.guildController
        context.session.routerName = guild.routerName
        try await context.session.saveAndCache(in: context.db)
        try await guild.showGuildHome(context: context)
        return true
    }

    /// The Arena (Ристалище) is a full controller too — flip routerName to
    /// "arena" (ArenaController takes over the reply keyboard) and render its
    /// hub. `arena.button.back` flips routerName back to "capital".
    private func onArenaEnter(context: Context) async throws {
        let arena = Controllers.arenaController
        context.session.routerName = arena.routerName
        try await context.session.saveAndCache(in: context.db)
        try await arena.showArenaHome(context: context)
    }

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
            let notice = context.lingo.localize("capital.blocked_by_expedition", gender: context.session.gender, locale: context.session.locale)
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
            try await Controllers.capitalController.postCannotStart(context: context, key: "capital.blocked_by_expedition", gendered: true)
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
        // Only the tavern body addresses the player with a feminitive
        // ("наміснику"); the other locations are gender-neutral, so route just
        // the tavern through the gendered helper to avoid missing `.m/.f` keys.
        let body  = location == .tavern
            ? lingo.localize(location.bodyKey, gender: context.session.gender, locale: locale)
            : lingo.localize(location.bodyKey, locale: locale)
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

    /// `gendered` routes through the feminitive helper — set it only for keys
    /// that have `.m/.f` variants in `uk.json` (e.g. the "намісник" expedition
    /// block); the no-HP / no-vigor reasons are gender-neutral.
    private func postCannotStart(context: Context, key: String, gendered: Bool = false) async throws {
        let locale = context.session.locale
        let text = gendered
            ? context.lingo.localize(key, gender: context.session.gender, locale: locale)
            : context.lingo.localize(key, locale: locale)
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
        let questLabel = lingo.localize("quest.button.open", locale: locale)
        return TGInlineKeyboardMarkup(inlineKeyboard: [
            [TGInlineKeyboardButton(text: buyLabel,  callbackData: "trader:buylist"),
             TGInlineKeyboardButton(text: sellLabel, callbackData: "trader:selllist")],
            [TGInlineKeyboardButton(text: questLabel, callbackData: "quest:board:trader")],
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

    // MARK: - Master (Phase 6.5) — armor shop / repair / enchant

    func showMaster(context: Context) async throws {
        let text = renderMasterMenuBody(session: context.session, lingo: context.lingo)
        let keyboard = masterMenuKeyboard(lingo: context.lingo, locale: context.session.locale)
        _ = try await sendCachedPhoto(
            assetPath: "\(projectPath)/Assets/capital/master.jpg",
            caption: text,
            replyMarkup: .inlineKeyboardMarkup(keyboard),
            toUser: context.session,
            bot: context.bot
        )
    }

    private func renderMasterMenuBody(session: User, lingo: Lingo) -> String {
        let locale = session.locale
        let title = lingo.localize("capital.location.master.title", locale: locale)
        let body  = lingo.localize("capital.location.master.body", locale: locale)
        let silverLabel = lingo.localize("capital.trader.silver_balance", locale: locale, interpolations: ["silver": "\(session.silver)"])
        return "<b>\(title)</b>\n\n\(body)\n\n🪙 \(silverLabel)"
    }

    private func masterMenuKeyboard(lingo: Lingo, locale: String) -> TGInlineKeyboardMarkup {
        let buy     = lingo.localize("capital.master.button.buy",     locale: locale)
        let repair  = lingo.localize("capital.master.button.repair",  locale: locale)
        let enchant = lingo.localize("capital.master.button.enchant", locale: locale)
        let back    = lingo.localize("capital.button.back_to_capital", locale: locale)
        let quest   = lingo.localize("quest.button.open", locale: locale)
        return TGInlineKeyboardMarkup(inlineKeyboard: [
            [TGInlineKeyboardButton(text: buy,     callbackData: "master:buylist")],
            [TGInlineKeyboardButton(text: repair,  callbackData: "master:repairlist"),
             TGInlineKeyboardButton(text: enchant, callbackData: "master:enchantlist")],
            [TGInlineKeyboardButton(text: quest,   callbackData: "quest:board:master")],
            [TGInlineKeyboardButton(text: back,    callbackData: "capital:back")]
        ])
    }

    private func editToMasterMenu(messageId: Int, isPhoto: Bool, context: Context) async {
        let text = renderMasterMenuBody(session: context.session, lingo: context.lingo)
        let keyboard = masterMenuKeyboard(lingo: context.lingo, locale: context.session.locale)
        await editTraderScreen(messageId: messageId, isPhoto: isPhoto, context: context, text: text, keyboard: keyboard)
    }

    /// Localized "icon name" for an item (armor isn't tiered, so the base
    /// name key is fine).
    private func itemLabel(_ itemId: String, lingo: Lingo, locale: String) -> String {
        guard let item = ItemCatalog.find(itemId) else { return itemId }
        // `item.icon` is optional — unwrap it, never interpolate the Optional
        // directly (that leaks "Optional(...)" into player-facing text).
        let iconPrefix = item.icon.map { "\($0) " } ?? ""
        return "\(iconPrefix)\(lingo.localize(item.nameKey, locale: locale))"
    }

    /// All owned armor rows (equipped or in the bag), sorted by slot.
    private func ownedArmorRows(for user: User, on db: any Database) async throws -> [InventoryEntry] {
        guard let userId = user.id else { return [] }
        let rows = try await InventoryEntry.query(on: db).filter(\.$user.$id, .equal, userId).all()
        return rows.filter {
            guard let slot = ItemCatalog.find($0.itemId)?.slot else { return false }
            return GearConditionService.armorSlots.contains(slot.rawValue)
        }.sorted { ($0.itemId, $0.id?.uuidString ?? "") < ($1.itemId, $1.id?.uuidString ?? "") }
    }

    // MARK: Buy

    private func sectionBody(_ titleKey: String, hintKey: String, session: User, lingo: Lingo, hintInterpolations: [String: String] = [:]) -> String {
        let locale = session.locale
        let title = lingo.localize(titleKey, locale: locale)
        let hint  = lingo.localize(hintKey, locale: locale, interpolations: hintInterpolations)
        let silver = lingo.localize("capital.trader.silver_balance", locale: locale, interpolations: ["silver": "\(session.silver)"])
        return "<b>\(title)</b>\n\n\(hint)\n\n🪙 \(silver)"
    }

    private func editToMasterBuy(messageId: Int, isPhoto: Bool, context: Context) async {
        let lingo = context.lingo, locale = context.session.locale
        let text = sectionBody("capital.master.buy.title", hintKey: "capital.master.buy.hint", session: context.session, lingo: lingo)
        var rows: [[TGInlineKeyboardButton]] = MasterCatalog.armorForSale.map { listing in
            // Buy list keeps the price on the button (helps compare pieces);
            // the confirm prompt still restates it before purchase.
            let label = "\(itemLabel(listing.itemId, lingo: lingo, locale: locale)) · 🪙 \(listing.priceSilver)"
            return [TGInlineKeyboardButton(text: label, callbackData: "master:buy:\(listing.itemId)")]
        }
        rows.append([TGInlineKeyboardButton(text: lingo.localize("capital.master.button.back", locale: locale), callbackData: "master:menu")])
        await editTraderScreen(messageId: messageId, isPhoto: isPhoto, context: context, text: text, keyboard: TGInlineKeyboardMarkup(inlineKeyboard: rows))
    }

    // MARK: Repair

    /// The player's currently-equipped main-hand weapon row, if any.
    private func equippedWeaponRow(for user: User, on db: any Database) async throws -> InventoryEntry? {
        guard let userId = user.id else { return nil }
        return try await InventoryEntry.query(on: db)
            .filter(\.$user.$id, .equal, userId)
            .filter(\.$equippedSlot, .equal, EquipmentSlot.mainHand.rawValue)
            .first()
    }

    /// Class-specific repair-button label for the weapon (sword/bow/staff each
    /// get a fitting verb). Unknown/nil class falls back to the warrior label.
    private static func weaponRepairLabelKey(for user: User) -> String {
        switch CharacterClass(rawValue: user.characterClass ?? "") {
        case .archer: return "capital.master.repair.weapon.archer"
        case .mage:   return "capital.master.repair.weapon.mage"
        case .warrior, nil: return "capital.master.repair.weapon.warrior"
        }
    }

    private func editToMasterRepair(messageId: Int, isPhoto: Bool, context: Context) async throws {
        let lingo = context.lingo, locale = context.session.locale
        let armor = try await ownedArmorRows(for: context.session, on: context.db)
        let needRepair = armor.filter { $0.durability < $0.maxDurability }
        let weapon = try await equippedWeaponRow(for: context.session, on: context.db)
        let weaponNeedsRepair = weapon.map { $0.durability < $0.maxDurability } == true
        let hintKey = (needRepair.isEmpty && !weaponNeedsRepair) ? "capital.master.repair.empty" : "capital.master.repair.hint"
        let text = sectionBody("capital.master.repair.title", hintKey: hintKey, session: context.session, lingo: lingo)
        // Cost is shown on the confirm prompt, so the list buttons stay clean:
        // item name + current durability only.
        var rows: [[TGInlineKeyboardButton]] = needRepair.compactMap { row -> [TGInlineKeyboardButton]? in
            guard let id = row.id else { return nil }
            let label = "\(itemLabel(row.itemId, lingo: lingo, locale: locale)) · \(row.durability)/\(row.maxDurability)"
            return [TGInlineKeyboardButton(text: label, callbackData: "master:repair:\(id.uuidString)")]
        }
        // The equipped weapon — its own class-flavoured label.
        if let weapon, weaponNeedsRepair, let id = weapon.id {
            let name = lingo.localize(Self.weaponRepairLabelKey(for: context.session), locale: locale)
            let label = "\(name) · \(weapon.durability)/\(weapon.maxDurability)"
            rows.append([TGInlineKeyboardButton(text: label, callbackData: "master:repair:\(id.uuidString)")])
        }
        rows.append([TGInlineKeyboardButton(text: lingo.localize("capital.master.button.back", locale: locale), callbackData: "master:menu")])
        await editTraderScreen(messageId: messageId, isPhoto: isPhoto, context: context, text: text, keyboard: TGInlineKeyboardMarkup(inlineKeyboard: rows))
    }

    // MARK: Enchant

    /// Localization key for the stat *focus* of the player's class, used in the
    /// enchant-screen hint (no level numbers — just which stats this class's
    /// enchant reinforces). Unknown/nil class falls back to warrior.
    private static func enchantFocusKey(for user: User) -> String {
        switch CharacterClass(rawValue: user.characterClass ?? "") {
        case .archer: return "capital.master.enchant.focus.archer"
        case .mage:   return "capital.master.enchant.focus.mage"
        case .warrior, nil: return "capital.master.enchant.focus.warrior"
        }
    }

    /// Localized phrase for what an enchant of `level` actually grants.
    ///
    /// One phrase for every class now: since Phase 6 an enchant scales the
    /// piece's OWN stats by a percentage instead of adding flat points plus a
    /// class-identity stat, so there is no longer anything class-specific to
    /// say. The three per-class keys are retired.
    private static func enchantBonusPhrase(for user: User, level: Int, lingo: Lingo) -> String {
        lingo.localize("capital.master.enchant.bonus", locale: user.locale,
                       interpolations: ["percent": "\(MasterCatalog.enchantBonusPercent(level: level))"])
    }

    private func editToMasterEnchant(messageId: Int, isPhoto: Bool, context: Context) async throws {
        let lingo = context.lingo, locale = context.session.locale
        let armor = try await ownedArmorRows(for: context.session, on: context.db)
        let enchantable = armor.filter { $0.enchantLevel < MasterCatalog.enchantCap }
        let hintKey = enchantable.isEmpty ? "capital.master.enchant.empty" : "capital.master.enchant.hint"
        let focus = lingo.localize(Self.enchantFocusKey(for: context.session), locale: locale)
        let text = sectionBody("capital.master.enchant.title", hintKey: hintKey, session: context.session, lingo: lingo, hintInterpolations: ["focus": focus])
        var rows: [[TGInlineKeyboardButton]] = enchantable.compactMap { row -> [TGInlineKeyboardButton]? in
            guard let id = row.id, let step = MasterCatalog.enchantStep(currentLevel: row.enchantLevel) else { return nil }
            // Cost is shown on the confirm prompt — list shows just the level step.
            let label = "\(itemLabel(row.itemId, lingo: lingo, locale: locale)) · +\(row.enchantLevel)→+\(step.level)"
            return [TGInlineKeyboardButton(text: label, callbackData: "master:enchant:\(id.uuidString)")]
        }
        rows.append([TGInlineKeyboardButton(text: lingo.localize("capital.master.button.back", locale: locale), callbackData: "master:menu")])
        await editTraderScreen(messageId: messageId, isPhoto: isPhoto, context: context, text: text, keyboard: TGInlineKeyboardMarkup(inlineKeyboard: rows))
    }

    // MARK: Confirm (guard against accidental taps)

    private func ownedRow(_ entryId: UUID, for user: User, on db: any Database) async throws -> InventoryEntry? {
        guard let userId = user.id else { return nil }
        return try await InventoryEntry.query(on: db)
            .filter(\.$user.$id, .equal, userId).filter(\.$id, .equal, entryId).first()
    }

    private func masterConfirmKeyboard(yes: String, no: String, lingo: Lingo, locale: String) -> TGInlineKeyboardMarkup {
        TGInlineKeyboardMarkup(inlineKeyboard: [[
            TGInlineKeyboardButton(text: lingo.localize("capital.master.confirm.yes", locale: locale), callbackData: yes),
            TGInlineKeyboardButton(text: lingo.localize("capital.master.confirm.no", locale: locale), callbackData: no)
        ]])
    }

    private func editToMasterConfirmBuy(itemId: String, messageId: Int, isPhoto: Bool, context: Context) async {
        let lingo = context.lingo, locale = context.session.locale
        guard let price = MasterCatalog.buyPrice(for: itemId) else {
            await editToMasterBuy(messageId: messageId, isPhoto: isPhoto, context: context); return
        }
        let text = lingo.localize("capital.master.confirm.buy", locale: locale, interpolations: [
            "item": itemLabel(itemId, lingo: lingo, locale: locale), "cost": "🪙 \(price)"
        ])
        let kb = masterConfirmKeyboard(yes: "master:buyok:\(itemId)", no: "master:buylist", lingo: lingo, locale: locale)
        await editTraderScreen(messageId: messageId, isPhoto: isPhoto, context: context, text: text, keyboard: kb)
    }

    private func editToMasterConfirmRepair(entryId: UUID, messageId: Int, isPhoto: Bool, context: Context) async throws {
        let lingo = context.lingo, locale = context.session.locale
        guard let row = try await ownedRow(entryId, for: context.session, on: context.db), row.durability < row.maxDurability else {
            try await editToMasterRepair(messageId: messageId, isPhoto: isPhoto, context: context); return
        }
        let missing = row.maxDurability - row.durability
        let isWeapon = ItemCatalog.find(row.itemId)?.slot.map { GearConditionService.weaponSlots.contains($0.rawValue) } == true
        let cost = isWeapon ? MasterCatalog.weaponRepairCost(missing: missing) : MasterCatalog.repairCost(itemId: row.itemId, missing: missing)
        let text = lingo.localize("capital.master.confirm.repair", locale: locale, interpolations: [
            "item": itemLabel(row.itemId, lingo: lingo, locale: locale),
            "cur": "\(row.durability)", "max": "\(row.maxDurability)", "cost": "🪙 \(cost)"
        ])
        let kb = masterConfirmKeyboard(yes: "master:repairok:\(entryId.uuidString)", no: "master:repairlist", lingo: lingo, locale: locale)
        await editTraderScreen(messageId: messageId, isPhoto: isPhoto, context: context, text: text, keyboard: kb)
    }

    private func editToMasterConfirmEnchant(entryId: UUID, messageId: Int, isPhoto: Bool, context: Context) async throws {
        let lingo = context.lingo, locale = context.session.locale
        guard let row = try await ownedRow(entryId, for: context.session, on: context.db),
              let step = MasterCatalog.enchantStep(currentLevel: row.enchantLevel) else {
            try await editToMasterEnchant(messageId: messageId, isPhoto: isPhoto, context: context); return
        }
        let hideIcon = ItemCatalog.find("mat.hide")?.icon ?? "🦴"
        let text = lingo.localize("capital.master.confirm.enchant", locale: locale, interpolations: [
            "item": itemLabel(row.itemId, lingo: lingo, locale: locale),
            "level": "\(step.level)", "cost": "🪙 \(step.silver) + \(step.materialQty)\(hideIcon)"
        ])
        let kb = masterConfirmKeyboard(yes: "master:enchantok:\(entryId.uuidString)", no: "master:enchantlist", lingo: lingo, locale: locale)
        await editTraderScreen(messageId: messageId, isPhoto: isPhoto, context: context, text: text, keyboard: kb)
    }

    // MARK: Result banners

    private func postMasterResultBanner(forBuy result: MasterService.BuyResult, context: Context) async {
        let lingo = context.lingo, locale = context.session.locale
        switch result {
        case .success(let itemId, let price):
            let name = itemLabel(itemId, lingo: lingo, locale: locale)
            let text = lingo.localize("capital.master.bought", locale: locale, interpolations: ["item": name, "silver": "🪙 \(price)"])
            await postStatusBanner("✅ \(text)", context: context)
        case .notEnoughSilver(let have, let need):
            let text = lingo.localize("capital.trader.not_enough_silver", locale: locale, interpolations: ["have": "\(have)", "need": "\(need)"])
            await postStatusBanner("❌ \(text)", context: context)
        case .inventoryFull(let free):
            let text = lingo.localize("capital.trader.bag_full", locale: locale, interpolations: ["free": "\(free)", "need": "1"])
            await postStatusBanner("❌ \(text)", context: context)
        case .unknownItem:
            break
        }
    }

    private func postMasterResultBanner(forRepair result: MasterService.RepairResult, context: Context) async {
        let lingo = context.lingo, locale = context.session.locale
        switch result {
        case .success(let itemId, let cost, let newMax):
            let name = itemLabel(itemId, lingo: lingo, locale: locale)
            let text = lingo.localize("capital.master.repaired", locale: locale, interpolations: ["item": name, "silver": "🪙 \(cost)", "cur": "\(newMax)", "max": "\(newMax)"])
            await postStatusBanner("✅ \(text)", context: context)
        case .notEnoughSilver(let have, let need):
            let text = lingo.localize("capital.trader.not_enough_silver", locale: locale, interpolations: ["have": "\(have)", "need": "\(need)"])
            await postStatusBanner("❌ \(text)", context: context)
        case .alreadyFull, .notArmor:
            break
        }
    }

    private func postMasterResultBanner(forEnchant result: MasterService.EnchantResult, context: Context) async {
        let lingo = context.lingo, locale = context.session.locale
        switch result {
        case .success(let itemId, let newLevel):
            let name = itemLabel(itemId, lingo: lingo, locale: locale)
            let bonus = Self.enchantBonusPhrase(for: context.session, level: newLevel, lingo: lingo)
            let text = lingo.localize("capital.master.enchanted", locale: locale, interpolations: ["item": name, "level": "\(newLevel)", "bonus": bonus])
            await postStatusBanner("✅ \(text)", context: context)
        case .maxLevel:
            await postStatusBanner("❌ " + lingo.localize("capital.master.max_level", locale: locale), context: context)
        case .notEnoughSilver(let have, let need):
            let text = lingo.localize("capital.trader.not_enough_silver", locale: locale, interpolations: ["have": "\(have)", "need": "\(need)"])
            await postStatusBanner("❌ \(text)", context: context)
        case .missingMaterials(let itemId, let have, let need):
            let name = itemLabel(itemId, lingo: lingo, locale: locale)
            let text = lingo.localize("capital.master.missing_materials", locale: locale, interpolations: ["item": name, "have": "\(have)", "need": "\(need)"])
            await postStatusBanner("❌ \(text)", context: context)
        case .notArmor:
            break
        }
    }

    // MARK: - Daily quests (Phase 9.2)
    //
    // Each of the three quest-giving NPCs carries a [📜 Замовлення] button on
    // its menu. The board is a single screen — one job, its progress, its
    // reward — edited in place over the NPC's own message, same as every other
    // sub-screen here. There's no picking and no journal: the system assigns
    // one job per NPC per game day (see `QuestCatalog.daily`).
    //
    // One action button, whose meaning depends on the objective: deliver jobs
    // show [✅ Здати] once the bag holds enough (turn-in consumes the items and
    // pays out in one tap), counter jobs show [🎁 Забрати] once gameplay has
    // ticked them to target. Before that there's no button at all — nothing to
    // tap, nothing to mis-tap.

    private func renderQuestBoardBody(status: QuestService.Status, npc: QuestNPC, session: User, lingo: Lingo) -> String {
        let locale = session.locale
        let title = lingo.localize(npc.boardTitleKey, locale: locale)
        let questTitle = lingo.localize(status.def.titleKey, locale: locale)
        let desc = lingo.localize(status.def.descKey, locale: locale)

        var lines = ["<b>\(title)</b>", "", "<b>\(questTitle)</b>", desc, ""]
        if status.claimed {
            // Done for today — the progress line would just restate the target.
            lines.append("✅ " + lingo.localize("quest.done_today", locale: locale))
        } else if !status.accepted {
            // An offer, not a job: a progress line here would imply the counter
            // is already running, and it is not.
            lines.append("📜 " + lingo.localize("quest.not_taken", locale: locale))
            lines.append("🎁 " + lingo.localize("quest.reward", locale: locale, interpolations: [
                "reward": Self.rewardPhrase(status.reward, lingo: lingo, locale: locale)
            ]))
        } else {
            lines.append("📊 " + lingo.localize("quest.progress", locale: locale, interpolations: [
                "done": "\(status.done)",
                "target": "\(status.target)"
            ]))
            lines.append("🎁 " + lingo.localize("quest.reward", locale: locale, interpolations: [
                "reward": Self.rewardPhrase(status.reward, lingo: lingo, locale: locale)
            ]))
        }
        return lines.joined(separator: "\n")
    }

    /// "🪙 100 · 📊 40 XP · 🍗 25 Vigor" — only the non-zero parts. Unit words
    /// come from Lingo (uk: Досвід / Снага) so the glossary stays in one place.
    static func rewardPhrase(_ reward: QuestReward, lingo: Lingo, locale: String) -> String {
        var parts: [String] = ["🪙 \(reward.silver)"]
        if reward.xp > 0 {
            parts.append("📊 \(reward.xp) " + lingo.localize("quest.reward.xp", locale: locale))
        }
        if reward.vigor > 0 {
            parts.append("🍗 \(reward.vigor) " + lingo.localize("quest.reward.vigor", locale: locale))
        }
        return parts.joined(separator: " · ")
    }

    private func questBoardKeyboard(status: QuestService.Status, npc: QuestNPC, lingo: Lingo, locale: String) -> TGInlineKeyboardMarkup {
        var rows: [[TGInlineKeyboardButton]] = []
        if !status.accepted && !status.claimed {
            rows.append([TGInlineKeyboardButton(
                text: lingo.localize("quest.button.take", locale: locale),
                callbackData: "quest:take:\(npc.rawValue)"
            )])
        }
        if status.isActionable {
            // Deliver jobs "hand in", counter jobs "collect" — same callback,
            // different word, because the player is doing a different thing.
            let labelKey: String
            if case .deliver = status.def.objective {
                labelKey = "quest.button.turn_in"
            } else {
                labelKey = "quest.button.claim"
            }
            rows.append([TGInlineKeyboardButton(
                text: lingo.localize(labelKey, locale: locale),
                callbackData: "quest:do:\(npc.rawValue)"
            )])
        }
        rows.append([TGInlineKeyboardButton(
            text: lingo.localize("quest.button.back", locale: locale),
            callbackData: npc.backCallback
        )])
        return TGInlineKeyboardMarkup(inlineKeyboard: rows)
    }

    private func editToQuestBoard(npc: QuestNPC, messageId: Int, isPhoto: Bool, context: Context) async throws {
        let status = try await QuestService.status(for: context.session, npc: npc, on: context.db)
        let text = renderQuestBoardBody(status: status, npc: npc, session: context.session, lingo: context.lingo)
        let keyboard = questBoardKeyboard(status: status, npc: npc, lingo: context.lingo, locale: context.session.locale)
        await editTraderScreen(messageId: messageId, isPhoto: isPhoto, context: context, text: text, keyboard: keyboard)
    }

    /// Turn in / claim, then re-render the board so it flips to its "done for
    /// today" state under the player's finger.
    private func handleQuestTake(npc: QuestNPC, messageId: Int, isPhoto: Bool, context: Context) async throws {
        let result = try await QuestService.accept(npc: npc, for: context.session, on: context.db)
        let lingo = context.lingo, locale = context.session.locale
        switch result {
        case .taken(let def):
            await postStatusBanner("📜 " + lingo.localize("quest.banner.taken", locale: locale, interpolations: [
                "quest": lingo.localize(def.titleKey, locale: locale)
            ]), context: context)
        case .alreadyTaken:
            break   // the board below already shows it as running
        case .alreadyClaimed:
            await postStatusBanner("❌ " + lingo.localize("quest.done_today", locale: locale), context: context)
        }
        try await editToQuestBoard(npc: npc, messageId: messageId, isPhoto: isPhoto, context: context)
    }

    private func handleQuestFinish(npc: QuestNPC, messageId: Int, isPhoto: Bool, context: Context) async throws {
        let result = try await QuestService.finish(npc: npc, for: context.session, on: context.db)
        await postQuestResultBanner(result, context: context)
        try await editToQuestBoard(npc: npc, messageId: messageId, isPhoto: isPhoto, context: context)
    }

    private func postQuestResultBanner(_ result: QuestService.FinishResult, context: Context) async {
        let lingo = context.lingo, locale = context.session.locale
        switch result {
        case .paid(let def, let payout):
            let questTitle = lingo.localize(def.titleKey, locale: locale)
            let text = "✅ " + lingo.localize("quest.banner.paid", locale: locale, interpolations: [
                "quest": questTitle,
                "reward": Self.rewardPhrase(
                    QuestReward(silver: payout.silver, xp: payout.xp, vigor: payout.vigor),
                    lingo: lingo, locale: locale
                )
            ])
            await postStatusBanner(text, context: context)
            if let xpResult = payout.xpResult, xpResult.levelsGained > 0 {
                // A plain message, not another status banner — `postStatusBanner`
                // deletes the previous one, and this must not eat the payout —
                // and best-effort, because this function cannot throw.
                _ = try? await context.bot.sendMessage(
                    session: context.session,
                    text: LevelUpBanner.text(for: context.session, newLevel: xpResult.newLevel,
                                             growth: xpResult.growth, lingo: lingo, locale: locale),
                    parseMode: .html
                )
            }
        case .notEnough(let have, let need):
            await postStatusBanner("❌ " + lingo.localize("quest.not_enough", locale: locale, interpolations: [
                "have": "\(have)", "need": "\(need)"
            ]), context: context)
        case .notComplete(let done, let need):
            await postStatusBanner("❌ " + lingo.localize("quest.not_complete", locale: locale, interpolations: [
                "done": "\(done)", "need": "\(need)"
            ]), context: context)
        case .alreadyClaimed:
            await postStatusBanner("❌ " + lingo.localize("quest.done_today", locale: locale), context: context)
        case .notTaken:
            await postStatusBanner("❌ " + lingo.localize("quest.not_taken", locale: locale), context: context)
        }
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

        // Arena invite buttons (`arena:acc:` / `arena:dec:`) can land here if the
        // challenged player stepped back into the capital before answering.
        // Forward them so accept/decline still resolves against the ArenaStore.
        if data.hasPrefix("arena:") {
            return try await ArenaController.onCallbackQuery(context: context)
        }

        let ctrl = Controllers.capitalController
        // The trader entry sends as photo when `Assets/capital/trader.jpg` is
        // present, otherwise as text. All subsequent edits must match — pass
        // this flag through every editTo* helper.
        let isPhoto = (message.getMessage()?.photo) != nil

        // MARK: Daily quests (Phase 9.2) — shared by all three quest NPCs.

        if data.hasPrefix("quest:board:") {
            let token = String(data.dropFirst("quest:board:".count))
            guard let npc = QuestNPC(rawValue: token) else {
                _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id))
                return true
            }
            _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id))
            try await ctrl.editToQuestBoard(npc: npc, messageId: message.messageId, isPhoto: isPhoto, context: context)
            return true
        }
        if data.hasPrefix("quest:take:") {
            let token = String(data.dropFirst("quest:take:".count))
            guard let npc = QuestNPC(rawValue: token) else {
                _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id))
                return true
            }
            _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id))
            try await ctrl.handleQuestTake(npc: npc, messageId: message.messageId, isPhoto: isPhoto, context: context)
            return true
        }
        if data.hasPrefix("quest:do:") {
            let token = String(data.dropFirst("quest:do:".count))
            guard let npc = QuestNPC(rawValue: token) else {
                _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id))
                return true
            }
            _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id))
            try await ctrl.handleQuestFinish(npc: npc, messageId: message.messageId, isPhoto: isPhoto, context: context)
            return true
        }

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
        // MARK: Master (Phase 6.5) — buy / repair / enchant armor
        if data == "master:menu" {
            _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id))
            await ctrl.editToMasterMenu(messageId: message.messageId, isPhoto: isPhoto, context: context)
            return true
        }
        if data == "master:buylist" {
            _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id))
            await ctrl.editToMasterBuy(messageId: message.messageId, isPhoto: isPhoto, context: context)
            return true
        }
        if data == "master:repairlist" {
            _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id))
            try await ctrl.editToMasterRepair(messageId: message.messageId, isPhoto: isPhoto, context: context)
            return true
        }
        if data == "master:enchantlist" {
            _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id))
            try await ctrl.editToMasterEnchant(messageId: message.messageId, isPhoto: isPhoto, context: context)
            return true
        }
        // Item taps open a confirm prompt first (guard against accidental
        // taps); the `*ok:` callbacks below actually run the action.
        if data.hasPrefix("master:buy:") {
            let itemId = String(data.dropFirst("master:buy:".count))
            _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id))
            await ctrl.editToMasterConfirmBuy(itemId: itemId, messageId: message.messageId, isPhoto: isPhoto, context: context)
            return true
        }
        if data.hasPrefix("master:buyok:") {
            let itemId = String(data.dropFirst("master:buyok:".count))
            _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id))
            let result = try await MasterService.buy(itemId: itemId, for: context.session, on: context.db)
            await ctrl.postMasterResultBanner(forBuy: result, context: context)
            await ctrl.editToMasterBuy(messageId: message.messageId, isPhoto: isPhoto, context: context)
            return true
        }
        if data.hasPrefix("master:repair:") {
            let idStr = String(data.dropFirst("master:repair:".count))
            _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id))
            if let id = UUID(uuidString: idStr) {
                try await ctrl.editToMasterConfirmRepair(entryId: id, messageId: message.messageId, isPhoto: isPhoto, context: context)
            }
            return true
        }
        if data.hasPrefix("master:repairok:") {
            let idStr = String(data.dropFirst("master:repairok:".count))
            _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id))
            if let id = UUID(uuidString: idStr) {
                let result = try await MasterService.repair(entryId: id, for: context.session, on: context.db)
                await ctrl.postMasterResultBanner(forRepair: result, context: context)
            }
            try await ctrl.editToMasterRepair(messageId: message.messageId, isPhoto: isPhoto, context: context)
            return true
        }
        if data.hasPrefix("master:enchant:") {
            let idStr = String(data.dropFirst("master:enchant:".count))
            _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id))
            if let id = UUID(uuidString: idStr) {
                try await ctrl.editToMasterConfirmEnchant(entryId: id, messageId: message.messageId, isPhoto: isPhoto, context: context)
            }
            return true
        }
        if data.hasPrefix("master:enchantok:") {
            let idStr = String(data.dropFirst("master:enchantok:".count))
            _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id))
            if let id = UUID(uuidString: idStr) {
                let result = try await MasterService.enchant(entryId: id, for: context.session, on: context.db)
                await ctrl.postMasterResultBanner(forEnchant: result, context: context)
            }
            try await ctrl.editToMasterEnchant(messageId: message.messageId, isPhoto: isPhoto, context: context)
            return true
        }

        // MARK: Market (Phase 6.5) — player-to-player marketplace
        if data == "market:menu" {
            _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id))
            try await ctrl.editToMarketMenu(messageId: message.messageId, isPhoto: isPhoto, context: context)
            return true
        }
        if data == "market:buyboard" {
            _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id))
            try await ctrl.editToBuyBoard(messageId: message.messageId, isPhoto: isPhoto, context: context)
            return true
        }
        if data == "market:sellpicker" {
            _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id))
            try await ctrl.editToSellPicker(messageId: message.messageId, isPhoto: isPhoto, context: context)
            return true
        }
        if data == "market:mylots" {
            _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id))
            try await ctrl.editToMyLots(messageId: message.messageId, isPhoto: isPhoto, context: context)
            return true
        }
        if data.hasPrefix("market:item:") {
            let itemId = String(data.dropFirst("market:item:".count))
            _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id))
            try await ctrl.editToItemLots(itemId: itemId, messageId: message.messageId, isPhoto: isPhoto, context: context)
            return true
        }
        // Item-lot tap opens a confirm prompt first; `buyok:` runs the purchase.
        if data.hasPrefix("market:buy:") {
            let idStr = String(data.dropFirst("market:buy:".count))
            _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id))
            if let id = UUID(uuidString: idStr) {
                try await ctrl.editToBuyConfirm(lotId: id, messageId: message.messageId, isPhoto: isPhoto, context: context)
            }
            return true
        }
        if data.hasPrefix("market:buyok:") {
            let idStr = String(data.dropFirst("market:buyok:".count))
            _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id))
            if let id = UUID(uuidString: idStr) {
                let result = try await MarketService.buyListing(id: id, buyer: context.session, on: context.db)
                await ctrl.postMarketBuyBanner(result: result, context: context)
                await ctrl.notifySellerSold(result: result, context: context)
            }
            try await ctrl.editToBuyBoard(messageId: message.messageId, isPhoto: isPhoto, context: context)
            return true
        }
        if data.hasPrefix("market:cancel:") {
            let idStr = String(data.dropFirst("market:cancel:".count))
            _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id))
            if let id = UUID(uuidString: idStr) {
                let result = try await MarketService.cancelListing(id: id, seller: context.session, on: context.db)
                await ctrl.postMarketCancelBanner(result: result, context: context)
            }
            try await ctrl.editToMyLots(messageId: message.messageId, isPhoto: isPhoto, context: context)
            return true
        }
        if data.hasPrefix("market:sell:") {
            let itemId = String(data.dropFirst("market:sell:".count))
            _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id))
            try await ctrl.openMarketSellPrompt(itemId: itemId, marketScreenMessageId: message.messageId, isPhoto: isPhoto, context: context)
            return true
        }
        if data == "market:cancelN" {
            _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id))
            try await ctrl.cancelMarketSellPrompt(context: context)
            return true
        }

        // MARK: Trade (Phase 6.5) — synchronous player-to-player exchange
        if data == "trade:lobby" {
            _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id))
            try await ctrl.showTradeLobby(messageId: message.messageId, isPhoto: isPhoto, context: context)
            return true
        }
        if data == "trade:back" {
            _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id))
            await TradeStore.shared.leaveLobby(telegramId: context.session.telegramId)
            try await ctrl.editToMarketMenu(messageId: message.messageId, isPhoto: isPhoto, context: context)
            return true
        }
        if data.hasPrefix("trade:invite:") {
            let raw = String(data.dropFirst("trade:invite:".count))
            _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id))
            if let targetTg = Int64(raw) {
                try await ctrl.handleTradeInvite(targetTelegramId: targetTg, messageId: message.messageId, isPhoto: isPhoto, context: context)
            }
            return true
        }
        if data.hasPrefix("trade:accept:") {
            let raw = String(data.dropFirst("trade:accept:".count))
            _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id))
            if let id = UUID(uuidString: raw) {
                try await ctrl.handleTradeAccept(sessionId: id, messageId: message.messageId, isPhoto: isPhoto, context: context)
            }
            return true
        }
        if data.hasPrefix("trade:decline:") {
            let raw = String(data.dropFirst("trade:decline:".count))
            _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id))
            if let id = UUID(uuidString: raw) {
                try await ctrl.handleTradeDecline(sessionId: id, context: context)
            }
            return true
        }
        if data.hasPrefix("trade:stack:") {
            let itemId = String(data.dropFirst("trade:stack:".count))
            _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id))
            try await ctrl.handleTradeStackTap(itemId: itemId, messageId: message.messageId, isPhoto: isPhoto, context: context)
            return true
        }
        if data.hasPrefix("trade:gear:") {
            let raw = String(data.dropFirst("trade:gear:".count))
            _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id))
            if let id = UUID(uuidString: raw) {
                try await ctrl.handleTradeGearTap(entryId: id, messageId: message.messageId, isPhoto: isPhoto, context: context)
            }
            return true
        }
        if data == "trade:silver" {
            _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id))
            try await ctrl.openTradeSilverPrompt(screenMessageId: message.messageId, isPhoto: isPhoto, context: context)
            return true
        }
        if data == "trade:promptcancel" {
            _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id))
            try await ctrl.cancelTradePrompt(context: context)
            return true
        }
        if data == "trade:ok" {
            _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id))
            try await ctrl.handleTradeConfirmFirst(messageId: message.messageId, isPhoto: isPhoto, context: context)
            return true
        }
        if data == "trade:final" {
            _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id))
            try await ctrl.handleTradeConfirmSecond(messageId: message.messageId, isPhoto: isPhoto, context: context)
            return true
        }
        if data == "trade:cancel" {
            _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id))
            try await ctrl.handleTradeCancel(messageId: message.messageId, isPhoto: isPhoto, context: context)
            return true
        }

        if data == "capital:back" || data == "fortune:back" {
            _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id))
            try await ctrl.showCapital(context: context)
            return true
        }

        // Unknown callback prefixes — forward to MainController which
        // owns `journal:` (the quest journal) + `explore:` + `combat:`
        // and has a default "delete stale inline message" fallback.
        // Returning false here would trigger Router's
        // unsupportedContentType ("Unsupported content type.") response,
        // which is noise — old buttons on stale messages shouldn't shout
        // at the player.
        return try await MainController.onCallbackQuery(context: context)
    }

    private func postTraderResultBanner(forSell result: TraderService.SellResult, itemId: String, context: Context) async {
        let lingo = context.lingo
        let locale = context.session.locale
        let itemName = ItemCatalog.find(itemId).map { lingo.localize($0.nameKey, locale: locale) } ?? itemId
        switch result {
        case .success(_, let qty, let silver):
            // 🪙 + amount pre-built in Swift — Lingo's `%{var}` parser breaks
            // when a supplementary-plane emoji sits next to the variable
            // inside the template, leaving the literal `%{silver}` rendered.
            let text = lingo.localize("capital.trader.sold", locale: locale, interpolations: [
                "item": itemName, "qty": "\(qty)", "silver": "🪙 \(silver)"
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
        case .success(_, let qty, let silver):
            let text = lingo.localize("capital.trader.bought", locale: locale, interpolations: [
                "item": itemName, "qty": "\(qty)", "silver": "🪙 \(silver)"
            ])
            await postStatusBanner("✅ \(text)", context: context)
        case .notEnoughSilver(let have, let need):
            let text = lingo.localize("capital.trader.not_enough_silver", locale: locale, interpolations: [
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

    // MARK: - Market (Phase 6.5 — player-to-player marketplace)
    //
    // Entry screen is the menu: lore + silver balance + active-lot count and
    // three buttons [🛒 Buy] / [🏷 Sell] / [📦 My lots]. The buy board is
    // item-grouped (Level 1 = one row per distinct item on the market, Level 2
    // = that item's lots cheapest-per-unit first). Selling is a two-prompt
    // flow (quantity → price) gated by a flat listing fee. Listing escrows the
    // units off the seller's bag; buying transfers them + the silver and pushes
    // the seller a "sold" notification; cancelling returns the units (fee kept).

    func showMarket(context: Context) async throws {
        let activeLots = try await MarketListing.activeCount(for: context.session, on: context.db)
        let text = renderMarketMenuBody(session: context.session, lingo: context.lingo, activeLots: activeLots)
        let keyboard = marketMenuKeyboard(lingo: context.lingo, locale: context.session.locale)
        _ = try await sendCachedPhoto(
            assetPath: "\(projectPath)/Assets/capital/market.jpg",
            caption: text,
            replyMarkup: .inlineKeyboardMarkup(keyboard),
            toUser: context.session,
            bot: context.bot
        )
    }

    private func renderMarketMenuBody(session: User, lingo: Lingo, activeLots: Int) -> String {
        let locale = session.locale
        let title = lingo.localize("capital.location.market.title", locale: locale)
        let body  = lingo.localize("capital.location.market.body", locale: locale)
        let silverLabel = lingo.localize("capital.trader.silver_balance", locale: locale, interpolations: ["silver": "\(session.silver)"])
        let lotsLine = lingo.localize("capital.market.lots_count", locale: locale, interpolations: [
            "count": "\(activeLots)", "max": "\(MarketCatalog.maxActiveLots)"
        ])
        return "<b>\(title)</b>\n\n\(body)\n\n🪙 \(silverLabel)\n📦 \(lotsLine)"
    }

    private func marketMenuKeyboard(lingo: Lingo, locale: String) -> TGInlineKeyboardMarkup {
        let buy     = lingo.localize("capital.market.button.buy",     locale: locale)
        let sell    = lingo.localize("capital.market.button.sell",    locale: locale)
        let myLots  = lingo.localize("capital.market.button.my_lots", locale: locale)
        let trade   = lingo.localize("capital.market.button.trade",   locale: locale)
        let back    = lingo.localize("capital.button.back_to_capital", locale: locale)
        return TGInlineKeyboardMarkup(inlineKeyboard: [
            [TGInlineKeyboardButton(text: buy,    callbackData: "market:buyboard"),
             TGInlineKeyboardButton(text: sell,   callbackData: "market:sellpicker")],
            [TGInlineKeyboardButton(text: myLots, callbackData: "market:mylots"),
             TGInlineKeyboardButton(text: trade,  callbackData: "trade:lobby")],
            [TGInlineKeyboardButton(text: back,   callbackData: "capital:back")]
        ])
    }

    private func editToMarketMenu(messageId: Int, isPhoto: Bool, context: Context) async throws {
        let activeLots = try await MarketListing.activeCount(for: context.session, on: context.db)
        let text = renderMarketMenuBody(session: context.session, lingo: context.lingo, activeLots: activeLots)
        let keyboard = marketMenuKeyboard(lingo: context.lingo, locale: context.session.locale)
        await editTraderScreen(messageId: messageId, isPhoto: isPhoto, context: context, text: text, keyboard: keyboard)
    }

    // MARK: Buy — Level 1 (item-grouped board)

    private func editToBuyBoard(messageId: Int, isPhoto: Bool, context: Context) async throws {
        let lingo = context.lingo, locale = context.session.locale
        let summaries = try await MarketListing.itemSummaries(excludingSeller: context.session.id, on: context.db)

        let title = lingo.localize("capital.market.buy_title", locale: locale)
        var body = "<b>\(title)</b>"
        if summaries.isEmpty {
            body += "\n\n<i>\(lingo.localize("capital.market.buy_empty", locale: locale))</i>"
        }

        var rows: [[TGInlineKeyboardButton]] = []
        for s in summaries {
            let name = ItemCatalog.find(s.itemId).map { item -> String in
                let icon = item.icon.map { "\($0) " } ?? ""
                return "\(icon)\(lingo.localize(item.nameKey, locale: locale))"
            } ?? s.itemId
            let label = lingo.localize("capital.market.board_row", locale: locale, interpolations: [
                "item": name, "count": "\(s.lotCount)"
            ])
            rows.append([TGInlineKeyboardButton(text: label, callbackData: "market:item:\(s.itemId)")])
        }
        let back = lingo.localize("capital.market.button.back_to_menu", locale: locale)
        rows.append([TGInlineKeyboardButton(text: back, callbackData: "market:menu")])

        await editTraderScreen(messageId: messageId, isPhoto: isPhoto, context: context, text: body, keyboard: TGInlineKeyboardMarkup(inlineKeyboard: rows))
    }

    // MARK: Buy — Level 2 (lots of one item)

    private func editToItemLots(itemId: String, messageId: Int, isPhoto: Bool, context: Context) async throws {
        let lingo = context.lingo, locale = context.session.locale
        let viewerId = context.session.id
        let lots = try await MarketListing.forItem(itemId, on: context.db).filter { $0.$seller.id != viewerId }

        // No lots left (all bought / cancelled) — bounce back to the board.
        if lots.isEmpty {
            try await editToBuyBoard(messageId: messageId, isPhoto: isPhoto, context: context)
            return
        }

        let itemName = ItemCatalog.find(itemId).map { lingo.localize($0.nameKey, locale: locale) } ?? itemId
        let title = lingo.localize("capital.market.item_lots_title", locale: locale, interpolations: ["item": itemName])
        let body = "<b>\(title)</b>"

        var rows: [[TGInlineKeyboardButton]] = []
        for lot in lots {
            guard let lotId = lot.id else { continue }
            let seller = try await User.find(lot.$seller.id, on: context.db)
            let nick = seller?.nickname ?? "—"
            let label = lingo.localize("capital.market.lot_row", locale: locale, interpolations: [
                "qty": "\(lot.quantity)", "total": "🪙 \(lot.price)", "nick": nick
            ])
            rows.append([TGInlineKeyboardButton(text: label, callbackData: "market:buy:\(lotId.uuidString)")])
        }
        let back = lingo.localize("capital.market.button.back_to_board", locale: locale)
        rows.append([TGInlineKeyboardButton(text: back, callbackData: "market:buyboard")])

        await editTraderScreen(messageId: messageId, isPhoto: isPhoto, context: context, text: body, keyboard: TGInlineKeyboardMarkup(inlineKeyboard: rows))
    }

    // MARK: Buy — confirm

    private func editToBuyConfirm(lotId: UUID, messageId: Int, isPhoto: Bool, context: Context) async throws {
        let lingo = context.lingo, locale = context.session.locale
        guard let lot = try await MarketListing.find(id: lotId, on: context.db) else {
            try await editToBuyBoard(messageId: messageId, isPhoto: isPhoto, context: context)
            return
        }
        let itemName = ItemCatalog.find(lot.itemId).map { item -> String in
            let icon = item.icon.map { "\($0) " } ?? ""
            return "\(icon)\(lingo.localize(item.nameKey, locale: locale))"
        } ?? lot.itemId
        let seller = try await User.find(lot.$seller.id, on: context.db)
        let nick = seller?.nickname ?? "—"
        let text = lingo.localize("capital.market.confirm.buy", locale: locale, interpolations: [
            "item": itemName, "qty": "\(lot.quantity)",
            "total": "🪙 \(lot.price)", "unit": "🪙 \(lot.unitPrice)", "nick": nick
        ])
        let yes = lingo.localize("capital.market.confirm.yes", locale: locale)
        let no  = lingo.localize("capital.market.confirm.no", locale: locale)
        let kb = TGInlineKeyboardMarkup(inlineKeyboard: [[
            TGInlineKeyboardButton(text: yes, callbackData: "market:buyok:\(lotId.uuidString)"),
            TGInlineKeyboardButton(text: no,  callbackData: "market:item:\(lot.itemId)")
        ]])
        await editTraderScreen(messageId: messageId, isPhoto: isPhoto, context: context, text: text, keyboard: kb)
    }

    // MARK: My lots

    private func editToMyLots(messageId: Int, isPhoto: Bool, context: Context) async throws {
        let lingo = context.lingo, locale = context.session.locale
        let lots = try await MarketListing.forSeller(context.session, on: context.db)

        let title = lingo.localize("capital.market.my_lots_title", locale: locale)
        var body = "<b>\(title)</b>"
        if lots.isEmpty {
            body += "\n\n<i>\(lingo.localize("capital.market.my_lots_empty", locale: locale))</i>"
        }

        var rows: [[TGInlineKeyboardButton]] = []
        for lot in lots {
            guard let lotId = lot.id else { continue }
            let name = ItemCatalog.find(lot.itemId).map { item -> String in
                let icon = item.icon.map { "\($0) " } ?? ""
                return "\(icon)\(lingo.localize(item.nameKey, locale: locale))"
            } ?? lot.itemId
            let label = lingo.localize("capital.market.my_lot_row", locale: locale, interpolations: [
                "item": name, "qty": "\(lot.quantity)", "total": "🪙 \(lot.price)"
            ])
            rows.append([TGInlineKeyboardButton(text: label, callbackData: "market:cancel:\(lotId.uuidString)")])
        }
        let back = lingo.localize("capital.market.button.back_to_menu", locale: locale)
        rows.append([TGInlineKeyboardButton(text: back, callbackData: "market:menu")])

        await editTraderScreen(messageId: messageId, isPhoto: isPhoto, context: context, text: body, keyboard: TGInlineKeyboardMarkup(inlineKeyboard: rows))
    }

    // MARK: Sell — item picker (bag stackables)

    /// Distinct stackable items in the bag (unequipped, qty ≥ 1) with totals.
    private func sellableBagItems(for user: User, on db: any Database) async throws -> [(itemId: String, qty: Int)] {
        let rows = try await InventoryEntry.list(for: user, on: db)
        var totals: [String: Int] = [:]
        for row in rows where row.equippedSlot == nil {
            guard let item = ItemCatalog.find(row.itemId), item.stackable else { continue }
            totals[row.itemId, default: 0] += row.quantity
        }
        return totals
            .filter { $0.value > 0 }
            .map { (itemId: $0.key, qty: $0.value) }
            .sorted { $0.itemId < $1.itemId }
    }

    private func editToSellPicker(messageId: Int, isPhoto: Bool, context: Context) async throws {
        let lingo = context.lingo, locale = context.session.locale
        let items = try await sellableBagItems(for: context.session, on: context.db)

        let title = lingo.localize("capital.market.sell_title", locale: locale)
        var body = "<b>\(title)</b>"
        if items.isEmpty {
            body += "\n\n<i>\(lingo.localize("capital.market.sell_empty", locale: locale))</i>"
        }

        var rows: [[TGInlineKeyboardButton]] = []
        for entry in items {
            let name = ItemCatalog.find(entry.itemId).map { item -> String in
                let icon = item.icon.map { "\($0) " } ?? ""
                return "\(icon)\(lingo.localize(item.nameKey, locale: locale))"
            } ?? entry.itemId
            let label = "\(name) · 🎒 \(entry.qty)"
            rows.append([TGInlineKeyboardButton(text: label, callbackData: "market:sell:\(entry.itemId)")])
        }
        let back = lingo.localize("capital.market.button.back_to_menu", locale: locale)
        rows.append([TGInlineKeyboardButton(text: back, callbackData: "market:menu")])

        await editTraderScreen(messageId: messageId, isPhoto: isPhoto, context: context, text: body, keyboard: TGInlineKeyboardMarkup(inlineKeyboard: rows))
    }

    // MARK: Sell — two-stage prompt (quantity → price)

    /// Open the "How many to list?" prompt + cancel button, stash pending state
    /// at stage `.quantity`. The next text update is consumed by
    /// `handleMarketListingInput`.
    fileprivate func openMarketSellPrompt(itemId: String, marketScreenMessageId: Int, isPhoto: Bool, context: Context) async throws {
        let lingo = context.lingo, locale = context.session.locale
        let itemName = ItemCatalog.find(itemId).map { lingo.localize($0.nameKey, locale: locale) } ?? itemId
        let promptText = lingo.localize("capital.market.sell.qty_prompt", locale: locale, interpolations: ["item": itemName])
        let cancelLabel = lingo.localize("capital.market.button.cancel", locale: locale)
        let kb = TGInlineKeyboardMarkup(inlineKeyboard: [[
            TGInlineKeyboardButton(text: cancelLabel, callbackData: "market:cancelN")
        ]])
        let sent = try await context.bot.sendMessage(params: TGSendMessageParams(
            chatId: .chat(context.session.telegramId),
            text: promptText,
            parseMode: .html,
            replyMarkup: .inlineKeyboardMarkup(kb)
        ))
        await EphemeralChatState.shared.setPendingMarketListing(
            telegramId: context.session.telegramId,
            listing: EphemeralChatState.PendingMarketListing(
                itemId: itemId,
                stage: .quantity,
                quantity: nil,
                promptMessageId: sent.messageId,
                marketScreenMessageId: marketScreenMessageId,
                isPhoto: isPhoto
            )
        )
    }

    fileprivate func cancelMarketSellPrompt(context: Context) async throws {
        // The listing prompt (qty → price) is transient input — remove it from
        // chat on cancel (player asked for this prompt type to be deletable).
        let telegramId = context.session.telegramId
        guard let pending = await EphemeralChatState.shared.takePendingMarketListing(telegramId: telegramId) else { return }
        _ = try? await context.bot.deleteMessage(params: TGDeleteMessageParams(
            chatId: .chat(telegramId),
            messageId: pending.promptMessageId
        ))
    }

    /// Re-render the active prompt in place with an optional error line, keeping
    /// pending so the next typed message retries. `stage` decides the wording.
    private func reshowMarketPrompt(pending: EphemeralChatState.PendingMarketListing, error: String?, context: Context) async {
        let lingo = context.lingo, locale = context.session.locale
        let itemName = ItemCatalog.find(pending.itemId).map { lingo.localize($0.nameKey, locale: locale) } ?? pending.itemId
        let promptText: String
        if pending.stage == .quantity {
            promptText = lingo.localize("capital.market.sell.qty_prompt", locale: locale, interpolations: ["item": itemName])
        } else {
            promptText = lingo.localize("capital.market.sell.price_prompt", locale: locale, interpolations: [
                "item": itemName, "qty": "\(pending.quantity ?? 0)", "fee": "🪙 \(MarketCatalog.listingFee)"
            ])
        }
        let cancelLabel = lingo.localize("capital.market.button.cancel", locale: locale)
        let kb = TGInlineKeyboardMarkup(inlineKeyboard: [[
            TGInlineKeyboardButton(text: cancelLabel, callbackData: "market:cancelN")
        ]])
        let full = error.map { "\(promptText)\n\n❌ \($0)" } ?? promptText
        _ = try? await context.bot.editMessageText(params: TGEditMessageTextParams(
            chatId: .chat(context.session.telegramId),
            messageId: pending.promptMessageId,
            text: full,
            parseMode: .html,
            replyMarkup: kb
        ))
    }

    fileprivate func handleMarketListingInput(text: String, pending: EphemeralChatState.PendingMarketListing, context: Context) async throws {
        let lingo = context.lingo, locale = context.session.locale
        let telegramId = context.session.telegramId
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let number = Int(trimmed), number > 0 else {
            await reshowMarketPrompt(pending: pending, error: lingo.localize("capital.market.invalid_number", locale: locale), context: context)
            return
        }

        if pending.stage == .quantity {
            // Validate against the bag before advancing to the price stage.
            guard let userId = context.session.id else { return }
            let inBag = try await InventoryEntry.totalQuantity(of: pending.itemId, for: userId, on: context.db)
            if number > inBag {
                let err = lingo.localize("capital.market.qty_too_high", locale: locale, interpolations: ["have": "\(inBag)"])
                await reshowMarketPrompt(pending: pending, error: err, context: context)
                return
            }
            await EphemeralChatState.shared.setPendingMarketListingQuantity(telegramId: telegramId, quantity: number)
            if let advanced = await EphemeralChatState.shared.peekPendingMarketListing(telegramId: telegramId) {
                await reshowMarketPrompt(pending: advanced, error: nil, context: context)
            }
            return
        }

        // Stage .price — `number` is the total lot price. Clear pending up front,
        // delete the listing prompt (transient input), create the listing,
        // refresh the menu.
        guard let quantity = pending.quantity else {
            _ = await EphemeralChatState.shared.takePendingMarketListing(telegramId: telegramId)
            return
        }
        _ = await EphemeralChatState.shared.takePendingMarketListing(telegramId: telegramId)
        _ = try? await context.bot.deleteMessage(params: TGDeleteMessageParams(
            chatId: .chat(telegramId),
            messageId: pending.promptMessageId
        ))

        let result = try await MarketService.createListing(itemId: pending.itemId, quantity: quantity, price: number, for: context.session, on: context.db)
        await postMarketCreateBanner(result: result, context: context)
        try await editToMarketMenu(messageId: pending.marketScreenMessageId, isPhoto: pending.isPhoto, context: context)
    }

    // MARK: Result banners + seller notification

    private func postMarketCreateBanner(result: MarketService.CreateResult, context: Context) async {
        let lingo = context.lingo, locale = context.session.locale
        switch result {
        case .success(let itemId, let qty, let price):
            let name = ItemCatalog.find(itemId).map { lingo.localize($0.nameKey, locale: locale) } ?? itemId
            let text = lingo.localize("capital.market.listed", locale: locale, interpolations: [
                "item": name, "qty": "\(qty)", "total": "🪙 \(price)"
            ])
            await postStatusBanner("✅ \(text)", context: context)
        case .notSellable:
            await postStatusBanner("❌ \(lingo.localize("capital.market.err.not_sellable", locale: locale))", context: context)
        case .tooManyLots(let max):
            let text = lingo.localize("capital.market.err.too_many_lots", locale: locale, interpolations: ["max": "\(max)"])
            await postStatusBanner("❌ \(text)", context: context)
        case .notEnoughInBag(let have, let need):
            let text = lingo.localize("capital.market.err.not_enough_bag", locale: locale, interpolations: ["have": "\(have)", "need": "\(need)"])
            await postStatusBanner("❌ \(text)", context: context)
        case .notEnoughSilver(_, let fee):
            let text = lingo.localize("capital.market.err.not_enough_silver_fee", locale: locale, interpolations: ["fee": "🪙 \(fee)"])
            await postStatusBanner("❌ \(text)", context: context)
        }
    }

    private func postMarketBuyBanner(result: MarketService.BuyResult, context: Context) async {
        let lingo = context.lingo, locale = context.session.locale
        switch result {
        case .success(let itemId, let qty, let price, _, _, _):
            let name = ItemCatalog.find(itemId).map { lingo.localize($0.nameKey, locale: locale) } ?? itemId
            let text = lingo.localize("capital.market.bought", locale: locale, interpolations: [
                "item": name, "qty": "\(qty)", "total": "🪙 \(price)"
            ])
            await postStatusBanner("✅ \(text)", context: context)
        case .notFound:
            await postStatusBanner("❌ \(lingo.localize("capital.market.err.lot_gone", locale: locale))", context: context)
        case .ownListing:
            await postStatusBanner("❌ \(lingo.localize("capital.market.err.own_lot", locale: locale))", context: context)
        case .notEnoughSilver(let have, let need):
            let text = lingo.localize("capital.market.err.not_enough_silver", locale: locale, interpolations: ["have": "\(have)", "need": "\(need)"])
            await postStatusBanner("❌ \(text)", context: context)
        case .inventoryFull(let free, let need):
            let text = lingo.localize("capital.market.err.bag_full", locale: locale, interpolations: ["free": "\(free)", "need": "\(need)"])
            await postStatusBanner("❌ \(text)", context: context)
        }
    }

    private func postMarketCancelBanner(result: MarketService.CancelResult, context: Context) async {
        let lingo = context.lingo, locale = context.session.locale
        switch result {
        case .success(let itemId, let qty):
            let name = ItemCatalog.find(itemId).map { lingo.localize($0.nameKey, locale: locale) } ?? itemId
            let text = lingo.localize("capital.market.canceled", locale: locale, interpolations: ["item": name, "qty": "\(qty)"])
            await postStatusBanner("✅ \(text)", context: context)
        case .notFound:
            await postStatusBanner("❌ \(lingo.localize("capital.market.err.lot_gone", locale: locale))", context: context)
        case .notOwner:
            await postStatusBanner("❌ \(lingo.localize("capital.market.err.lot_gone", locale: locale))", context: context)
        case .inventoryFull(_, let need):
            let text = lingo.localize("capital.market.err.cant_cancel_bag_full", locale: locale, interpolations: ["need": "\(need)"])
            await postStatusBanner("❌ \(text)", context: context)
        }
    }

    /// Push a "your lot sold" message straight to the seller's chat (the seller
    /// is offline / on another screen — same fire-and-forget pattern as
    /// `PlotProductionService`). Pulled from the buy result so we don't re-query.
    private func notifySellerSold(result: MarketService.BuyResult, context: Context) async {
        guard case .success(let itemId, let qty, let price, let sellerTelegramId, let sellerLocale, _) = result else { return }
        let lingo = context.lingo
        let name = ItemCatalog.find(itemId).map { lingo.localize($0.nameKey, locale: sellerLocale) } ?? itemId
        let text = lingo.localize("capital.market.sold_notification", locale: sellerLocale, interpolations: [
            "item": name, "qty": "\(qty)", "total": "🪙 \(price)"
        ])
        _ = try? await context.bot.sendMessage(params: TGSendMessageParams(
            chatId: .chat(sellerTelegramId),
            text: "💰 \(text)",
            parseMode: .html
        ))
    }

    // MARK: - Trade (Phase 6.5 — synchronous player-to-player exchange)
    //
    // Lives inside the Market. The live negotiation state is held in the
    // `TradeStore` actor; this controller only renders screens and pushes
    // cross-user messages. Both traders sit in routerName "capital", so every
    // tap from either lands in `onCallbackQuery` and is attributed to the
    // tapping `context.session`.

    /// Generic in-place edit targeting an ARBITRARY chat (the other trader's),
    /// unlike `editTraderScreen` which always targets `context.session`.
    private func editScreenFor(telegramId: Int64, messageId: Int, isPhoto: Bool, context: Context, text: String, keyboard: TGInlineKeyboardMarkup) async {
        let chatId = TGChatId.chat(telegramId)
        if isPhoto {
            _ = try? await context.bot.editMessageCaption(params: TGEditMessageCaptionParams(
                chatId: chatId, messageId: messageId, caption: text, parseMode: .html, replyMarkup: keyboard
            ))
        } else {
            _ = try? await context.bot.editMessageText(params: TGEditMessageTextParams(
                chatId: chatId, messageId: messageId, text: text, parseMode: .html, replyMarkup: keyboard
            ))
        }
    }

    private func userByTelegramId(_ tg: Int64, on db: any Database) async throws -> User? {
        try await User.query(on: db).filter(\.$telegramId, .equal, tg).first()
    }

    // MARK: Lobby

    func showTradeLobby(messageId: Int, isPhoto: Bool, context: Context) async throws {
        let me = context.session
        let lingo = context.lingo, locale = me.locale

        // Stale entry: already negotiating → re-render the live screen instead.
        if let s = await TradeStore.shared.snapshot(for: me.telegramId) {
            if s.phase == .locked { try await renderLockedSide(session: s, tg: me.telegramId, context: context) }
            else { try await renderBuildingSide(session: s, tg: me.telegramId, context: context) }
            return
        }

        await TradeStore.shared.touchLobby(telegramId: me.telegramId, nickname: me.nickname ?? "—")
        let members = await TradeStore.shared.lobbyMembers(excluding: me.telegramId)

        let title = lingo.localize("capital.trade.lobby_title", locale: locale)
        var body = "<b>\(title)</b>"
        if members.isEmpty {
            body += "\n\n<i>\(lingo.localize("capital.trade.lobby_empty", locale: locale))</i>"
        }
        var rows: [[TGInlineKeyboardButton]] = []
        for m in members {
            rows.append([TGInlineKeyboardButton(text: "🧑 \(m.nickname)", callbackData: "trade:invite:\(m.telegramId)")])
        }
        rows.append([
            TGInlineKeyboardButton(text: lingo.localize("capital.trade.refresh_btn", locale: locale), callbackData: "trade:lobby"),
            TGInlineKeyboardButton(text: lingo.localize("capital.market.button.back_to_menu", locale: locale), callbackData: "trade:back")
        ])
        await editTraderScreen(messageId: messageId, isPhoto: isPhoto, context: context, text: body, keyboard: TGInlineKeyboardMarkup(inlineKeyboard: rows))
    }

    // MARK: Invite / accept / decline

    func handleTradeInvite(targetTelegramId targetTg: Int64, messageId: Int, isPhoto: Bool, context: Context) async throws {
        let me = context.session
        let lingo = context.lingo, locale = me.locale
        guard let myId = me.id else { return }

        guard let target = try await userByTelegramId(targetTg, on: context.db), let targetId = target.id else {
            await postStatusBanner("❌ \(lingo.localize("capital.trade.err.gone", locale: locale))", context: context)
            try await showTradeLobby(messageId: messageId, isPhoto: isPhoto, context: context)
            return
        }

        let aSide = TradeStore.Side(
            telegramId: me.telegramId, userId: myId,
            nickname: me.nickname ?? "—", locale: me.locale,
            screenMessageId: messageId, isPhoto: isPhoto
        )
        let result = await TradeStore.shared.invite(
            initiator: aSide,
            targetTelegramId: targetTg, targetUserId: targetId,
            targetNickname: target.nickname ?? "—", targetLocale: target.locale
        )
        switch result {
        case .created(let session):
            // A's screen → "request sent".
            let body = "<b>\(lingo.localize("capital.trade.lobby_title", locale: locale))</b>\n\n\(lingo.localize("capital.trade.invite_sent", locale: locale))"
            let kb = TGInlineKeyboardMarkup(inlineKeyboard: [[
                TGInlineKeyboardButton(text: lingo.localize("capital.trade.cancel_btn", locale: locale), callbackData: "trade:cancel")
            ]])
            await editScreenFor(telegramId: me.telegramId, messageId: messageId, isPhoto: isPhoto, context: context, text: body, keyboard: kb)
            await pushTradeInvite(session: session, context: context)
        case .selfBusy:
            await postStatusBanner("❌ \(lingo.localize("capital.trade.err.busy_self", locale: locale))", context: context)
        case .targetBusy:
            await postStatusBanner("❌ \(lingo.localize("capital.trade.err.busy_other", locale: locale))", context: context)
            try await showTradeLobby(messageId: messageId, isPhoto: isPhoto, context: context)
        case .targetGone:
            await postStatusBanner("❌ \(lingo.localize("capital.trade.err.gone", locale: locale))", context: context)
            try await showTradeLobby(messageId: messageId, isPhoto: isPhoto, context: context)
        }
    }

    private func pushTradeInvite(session: TradeStore.TradeSession, context: Context) async {
        let lingo = context.lingo, locale = session.b.locale
        let text = lingo.localize("capital.trade.invite_push", locale: locale, interpolations: ["nick": session.a.nickname])
        let accept = lingo.localize("capital.trade.accept_btn", locale: locale)
        let decline = lingo.localize("capital.trade.decline_btn", locale: locale)
        let kb = TGInlineKeyboardMarkup(inlineKeyboard: [[
            TGInlineKeyboardButton(text: accept,  callbackData: "trade:accept:\(session.id.uuidString)"),
            TGInlineKeyboardButton(text: decline, callbackData: "trade:decline:\(session.id.uuidString)")
        ]])
        _ = try? await context.bot.sendMessage(params: TGSendMessageParams(
            chatId: .chat(session.b.telegramId), text: text, parseMode: .html,
            replyMarkup: .inlineKeyboardMarkup(kb)
        ))
    }

    func handleTradeAccept(sessionId: UUID, messageId: Int, isPhoto: Bool, context: Context) async throws {
        let result = await TradeStore.shared.accept(sessionId: sessionId, tapper: context.session.telegramId, screenMessageId: messageId, isPhoto: isPhoto)
        switch result {
        case .stale:
            await postStatusBanner("❌ \(context.lingo.localize("capital.trade.err.stale", locale: context.session.locale))", context: context)
        case .opened(let session):
            try await renderAndPushBuilding(session: session, context: context)
        }
    }

    func handleTradeDecline(sessionId: UUID, context: Context) async throws {
        guard let sides = await TradeStore.shared.decline(sessionId: sessionId, tapper: context.session.telegramId) else { return }
        await finishTradeUI(sides: sides, reasonKey: "capital.trade.declined", context: context)
    }

    // MARK: Offer edits

    func handleTradeStackTap(itemId: String, messageId: Int, isPhoto: Bool, context: Context) async throws {
        guard let session = await TradeStore.shared.snapshot(for: context.session.telegramId), session.phase == .building else { return }
        let side = session.side(for: context.session.telegramId)
        if side.offeredStacks[itemId] != nil {
            // Already offered → remove it.
            if let updated = await TradeStore.shared.toggleStack(tg: context.session.telegramId, itemId: itemId, ownedQty: 0) {
                try await renderAndPushBuilding(session: updated, context: context)
            }
        } else {
            // Not offered → ask how many.
            try await openTradeNumberPrompt(kind: .itemQty(itemId: itemId), screenMessageId: messageId, isPhoto: isPhoto, context: context)
        }
    }

    func handleTradeGearTap(entryId: UUID, messageId: Int, isPhoto: Bool, context: Context) async throws {
        guard await TradeStore.shared.snapshot(for: context.session.telegramId)?.phase == .building else { return }
        if let updated = await TradeStore.shared.toggleGear(tg: context.session.telegramId, entryId: entryId) {
            try await renderAndPushBuilding(session: updated, context: context)
        }
    }

    func openTradeSilverPrompt(screenMessageId: Int, isPhoto: Bool, context: Context) async throws {
        guard await TradeStore.shared.snapshot(for: context.session.telegramId)?.phase == .building else { return }
        try await openTradeNumberPrompt(kind: .silver, screenMessageId: screenMessageId, isPhoto: isPhoto, context: context)
    }

    private func openTradeNumberPrompt(kind: EphemeralChatState.PendingTradeInput.Kind, screenMessageId: Int, isPhoto: Bool, context: Context) async throws {
        let promptText = await tradePromptText(for: kind, context: context)
        let cancel = context.lingo.localize("capital.trade.cancel_btn", locale: context.session.locale)
        let kb = TGInlineKeyboardMarkup(inlineKeyboard: [[
            TGInlineKeyboardButton(text: cancel, callbackData: "trade:promptcancel")
        ]])
        let sent = try await context.bot.sendMessage(params: TGSendMessageParams(
            chatId: .chat(context.session.telegramId), text: promptText, parseMode: .html,
            replyMarkup: .inlineKeyboardMarkup(kb)
        ))
        await EphemeralChatState.shared.setPendingTradeInput(
            telegramId: context.session.telegramId,
            input: EphemeralChatState.PendingTradeInput(
                kind: kind, promptMessageId: sent.messageId,
                screenMessageId: screenMessageId, isPhoto: isPhoto
            )
        )
    }

    private func tradePromptText(for kind: EphemeralChatState.PendingTradeInput.Kind, context: Context) async -> String {
        let lingo = context.lingo, locale = context.session.locale
        switch kind {
        case .silver:
            return lingo.localize("capital.trade.silver_prompt", locale: locale, interpolations: ["have": "\(context.session.silver)"])
        case .itemQty(let itemId):
            let have = (try? await InventoryEntry.totalQuantity(of: itemId, for: context.session.id ?? UUID(), on: context.db)) ?? 0
            let name = ItemCatalog.find(itemId).map { lingo.localize($0.nameKey, locale: locale) } ?? itemId
            return lingo.localize("capital.trade.qty_prompt", locale: locale, interpolations: ["item": name, "have": "\(have)"])
        }
    }

    func cancelTradePrompt(context: Context) async throws {
        // The numeric prompt is transient input — remove it from chat on cancel,
        // then re-render the bag so the screen is interactive again.
        guard let pending = await EphemeralChatState.shared.takePendingTradeInput(telegramId: context.session.telegramId) else { return }
        _ = try? await context.bot.deleteMessage(params: TGDeleteMessageParams(
            chatId: .chat(context.session.telegramId), messageId: pending.promptMessageId
        ))
        if let session = await TradeStore.shared.snapshot(for: context.session.telegramId), session.phase == .building {
            try await renderBuildingSide(session: session, tg: context.session.telegramId, context: context)
        }
    }

    func handleTradeInput(text: String, pending: EphemeralChatState.PendingTradeInput, context: Context) async throws {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let n = Int(trimmed), n >= 0 else {
            let promptText = await tradePromptText(for: pending.kind, context: context)
            let cancel = context.lingo.localize("capital.trade.cancel_btn", locale: context.session.locale)
            let err = context.lingo.localize("capital.market.invalid_number", locale: context.session.locale)
            let kb = TGInlineKeyboardMarkup(inlineKeyboard: [[TGInlineKeyboardButton(text: cancel, callbackData: "trade:promptcancel")]])
            _ = try? await context.bot.editMessageText(params: TGEditMessageTextParams(
                chatId: .chat(context.session.telegramId), messageId: pending.promptMessageId,
                text: "\(promptText)\n\n❌ \(err)", parseMode: .html, replyMarkup: kb
            ))
            return
        }

        // Trade still live + building?
        guard let session = await TradeStore.shared.snapshot(for: context.session.telegramId), session.phase == .building else {
            _ = await EphemeralChatState.shared.takePendingTradeInput(telegramId: context.session.telegramId)
            _ = try? await context.bot.deleteMessage(params: TGDeleteMessageParams(chatId: .chat(context.session.telegramId), messageId: pending.promptMessageId))
            return
        }

        var updated: TradeStore.TradeSession?
        switch pending.kind {
        case .silver:
            updated = await TradeStore.shared.setSilver(tg: context.session.telegramId, amount: min(n, context.session.silver))
        case .itemQty(let itemId):
            let owned = (try? await InventoryEntry.totalQuantity(of: itemId, for: context.session.id ?? UUID(), on: context.db)) ?? 0
            updated = await TradeStore.shared.setStack(tg: context.session.telegramId, itemId: itemId, qty: n, ownedQty: owned)
        }

        _ = await EphemeralChatState.shared.takePendingTradeInput(telegramId: context.session.telegramId)
        _ = try? await context.bot.deleteMessage(params: TGDeleteMessageParams(chatId: .chat(context.session.telegramId), messageId: pending.promptMessageId))
        if let updated { try await renderAndPushBuilding(session: updated, context: context) }
    }

    // MARK: Confirmations

    func handleTradeConfirmFirst(messageId: Int, isPhoto: Bool, context: Context) async throws {
        switch await TradeStore.shared.confirmFirst(tg: context.session.telegramId) {
        case .noop: return
        case .waiting(let s): try await renderAndPushBuilding(session: s, context: context)
        case .both(let s): try await renderAndPushLocked(session: s, context: context)
        }
    }

    func handleTradeConfirmSecond(messageId: Int, isPhoto: Bool, context: Context) async throws {
        switch await TradeStore.shared.confirmSecond(tg: context.session.telegramId) {
        case .noop: return
        case .waiting(let s): try await renderAndPushLocked(session: s, context: context)
        case .both(let s):
            guard await TradeStore.shared.beginCommit(sessionId: s.id) else { return }
            let result = try await TradeService.commit(session: s, on: context.db)
            guard let sides = await TradeStore.shared.finish(sessionId: s.id) else { return }
            switch result {
            case .success:
                await finishTradeSuccess(sides: sides, context: context)
            case .failed(let reason):
                await finishTradeFailure(sides: sides, reason: reason, context: context)
            }
        }
    }

    func handleTradeCancel(messageId: Int, isPhoto: Bool, context: Context) async throws {
        guard let sides = await TradeStore.shared.cancel(tg: context.session.telegramId) else {
            // No active (or mid-commit) — just put the player back on the Market menu.
            try await editToMarketMenu(messageId: messageId, isPhoto: isPhoto, context: context)
            return
        }
        await finishTradeUI(sides: sides, reasonKey: "capital.trade.cancelled", context: context)
    }

    // MARK: Screen rendering

    private func renderAndPushBuilding(session: TradeStore.TradeSession, context: Context) async throws {
        try await renderBuildingSide(session: session, tg: session.a.telegramId, context: context)
        try await renderBuildingSide(session: session, tg: session.b.telegramId, context: context)
    }

    private func renderBuildingSide(session: TradeStore.TradeSession, tg: Int64, context: Context) async throws {
        let side = session.side(for: tg)
        guard let msgId = side.screenMessageId else { return }
        let user: User
        if tg == context.session.telegramId { user = context.session }
        else if let u = try await User.find(side.userId, on: context.db) { user = u }
        else { return }
        let (text, kb) = try await buildBuildingScreen(session: session, side: side, user: user, context: context)
        await editScreenFor(telegramId: tg, messageId: msgId, isPhoto: side.isPhoto, context: context, text: text, keyboard: kb)
    }

    private func buildBuildingScreen(session: TradeStore.TradeSession, side: TradeStore.Side, user: User, context: Context) async throws -> (String, TGInlineKeyboardMarkup) {
        let lingo = context.lingo, locale = side.locale
        let (stacks, gear) = try await TradeService.tradeableBagItems(for: user, on: context.db)

        var rows: [[TGInlineKeyboardButton]] = []
        for s in stacks {
            let item = ItemCatalog.find(s.itemId)
            let icon = item?.icon.map { "\($0) " } ?? ""
            let name = item.map { lingo.localize($0.nameKey, locale: locale) } ?? s.itemId
            let mark = side.offeredStacks[s.itemId].map { " ✅\($0)" } ?? ""
            rows.append([TGInlineKeyboardButton(text: "\(icon)\(name) ×\(s.qty)\(mark)", callbackData: "trade:stack:\(s.itemId)")])
        }
        for g in gear {
            guard let gid = g.id, let item = ItemCatalog.find(g.itemId) else { continue }
            let icon = item.icon.map { "\($0) " } ?? ""
            let name = lingo.localize(ItemDisplay.nameKey(for: item, tier: g.tier), locale: locale)
            let ench = g.enchantLevel > 0 ? " +\(g.enchantLevel)" : ""
            let mark = side.offeredGear.contains(gid) ? " ✅" : ""
            rows.append([TGInlineKeyboardButton(text: "\(icon)\(name)\(ench) (\(g.durability)/\(g.maxDurability))\(mark)", callbackData: "trade:gear:\(gid.uuidString)")])
        }
        rows.append([TGInlineKeyboardButton(
            text: "🪙 " + lingo.localize("capital.trade.add_silver_btn", locale: locale, interpolations: ["silver": "\(side.silver)"]),
            callbackData: "trade:silver"
        )])

        let cancelBtn = TGInlineKeyboardButton(text: lingo.localize("capital.trade.cancel_btn", locale: locale), callbackData: "trade:cancel")
        if side.firstConfirmed {
            rows.append([cancelBtn])
        } else {
            rows.append([
                TGInlineKeyboardButton(text: lingo.localize("capital.trade.confirm_btn", locale: locale), callbackData: "trade:ok"),
                cancelBtn
            ])
        }

        let other = session.other(for: side.telegramId)
        var body = "<b>\(lingo.localize("capital.trade.bag_title", locale: locale))</b>"
        body += "\n\n" + lingo.localize("capital.trade.with_player", locale: locale, interpolations: ["nick": other.nickname])
        if side.firstConfirmed {
            body += "\n\n✅ " + lingo.localize("capital.trade.ready_waiting", locale: locale, interpolations: ["nick": other.nickname])
        } else if other.firstConfirmed {
            body += "\n\n" + lingo.localize("capital.trade.other_ready", locale: locale, interpolations: ["nick": other.nickname])
        }
        return (body, TGInlineKeyboardMarkup(inlineKeyboard: rows))
    }

    private func renderAndPushLocked(session: TradeStore.TradeSession, context: Context) async throws {
        try await renderLockedSide(session: session, tg: session.a.telegramId, context: context)
        try await renderLockedSide(session: session, tg: session.b.telegramId, context: context)
    }

    private func renderLockedSide(session: TradeStore.TradeSession, tg: Int64, context: Context) async throws {
        let side = session.side(for: tg)
        guard let msgId = side.screenMessageId else { return }
        let (text, kb) = try await buildLockedScreen(session: session, side: side, context: context)
        await editScreenFor(telegramId: tg, messageId: msgId, isPhoto: side.isPhoto, context: context, text: text, keyboard: kb)
    }

    private func buildLockedScreen(session: TradeStore.TradeSession, side: TradeStore.Side, context: Context) async throws -> (String, TGInlineKeyboardMarkup) {
        let lingo = context.lingo, locale = side.locale
        let other = session.other(for: side.telegramId)
        let give = try await describeOffer(stacks: side.offeredStacks, gearIds: side.offeredGear, silver: side.silver, locale: locale, context: context)
        let get = try await describeOffer(stacks: other.offeredStacks, gearIds: other.offeredGear, silver: other.silver, locale: locale, context: context)

        var body = "<b>\(lingo.localize("capital.trade.combined_title", locale: locale))</b>"
        body += "\n\n<b>\(lingo.localize("capital.trade.you_give", locale: locale))</b>\n\(give)"
        body += "\n\n<b>\(lingo.localize("capital.trade.you_get", locale: locale))</b>\n\(get)"

        var rows: [[TGInlineKeyboardButton]] = []
        let cancelBtn = TGInlineKeyboardButton(text: lingo.localize("capital.trade.cancel_btn", locale: locale), callbackData: "trade:cancel")
        if side.secondConfirmed {
            body += "\n\n⏳ " + lingo.localize("capital.trade.waiting_final", locale: locale, interpolations: ["nick": other.nickname])
            rows.append([cancelBtn])
        } else {
            rows.append([
                TGInlineKeyboardButton(text: lingo.localize("capital.trade.final_btn", locale: locale), callbackData: "trade:final"),
                cancelBtn
            ])
        }
        return (body, TGInlineKeyboardMarkup(inlineKeyboard: rows))
    }

    /// Human-readable list of one side's offer (item names + silver). Loads the
    /// offered gear rows fresh so enchant/tier names render correctly.
    private func describeOffer(stacks: [String: Int], gearIds: [UUID], silver: Int, locale: String, context: Context) async throws -> String {
        let lingo = context.lingo
        var lines: [String] = []
        for (itemId, qty) in stacks.sorted(by: { $0.key < $1.key }) {
            let item = ItemCatalog.find(itemId)
            let icon = item?.icon.map { "\($0) " } ?? ""
            let name = item.map { lingo.localize($0.nameKey, locale: locale) } ?? itemId
            lines.append("\(icon)\(name) ×\(qty)")
        }
        if !gearIds.isEmpty {
            let rows = try await InventoryEntry.query(on: context.db).filter(\.$id ~~ gearIds).all()
            for g in rows {
                guard let item = ItemCatalog.find(g.itemId) else { continue }
                let icon = item.icon.map { "\($0) " } ?? ""
                let name = lingo.localize(ItemDisplay.nameKey(for: item, tier: g.tier), locale: locale)
                let ench = g.enchantLevel > 0 ? " +\(g.enchantLevel)" : ""
                lines.append("\(icon)\(name)\(ench)")
            }
        }
        if silver > 0 { lines.append("🪙 \(silver)") }
        if lines.isEmpty { lines.append(lingo.localize("capital.trade.nothing", locale: locale)) }
        return lines.joined(separator: "\n")
    }

    // MARK: Teardown UI

    /// Notify both sides with one localized banner and restore each player's
    /// Market menu in place. Used for done / cancelled / declined.
    private func finishTradeUI(sides: TradeStore.Sides, reasonKey: String, context: Context) async {
        for side in [sides.a, sides.b] {
            await pushTradeBanner(text: context.lingo.localize(reasonKey, locale: side.locale), to: side, context: context)
            await restoreMarketMenu(for: side, context: context)
        }
    }

    /// Post a permanent per-side record of the COMPLETED trade (so each player
    /// can later scroll back and see when + with whom they traded), then restore
    /// the Market menu. The record is a fresh message at the BOTTOM of the chat —
    /// below the numeric input they typed — and is kept (never deleted).
    private func finishTradeSuccess(sides: TradeStore.Sides, context: Context) async {
        let lingo = context.lingo
        for side in [sides.a, sides.b] {
            let other = side.telegramId == sides.a.telegramId ? sides.b : sides.a
            let locale = side.locale
            let give = (try? await describeOffer(stacks: side.offeredStacks, gearIds: side.offeredGear, silver: side.silver, locale: locale, context: context))
                ?? lingo.localize("capital.trade.nothing", locale: locale)
            let get = (try? await describeOffer(stacks: other.offeredStacks, gearIds: other.offeredGear, silver: other.silver, locale: locale, context: context))
                ?? lingo.localize("capital.trade.nothing", locale: locale)
            var body = "<b>\(lingo.localize("capital.trade.done", locale: locale))</b>"
            body += "\n" + lingo.localize("capital.trade.with_player", locale: locale, interpolations: ["nick": other.nickname])
            body += "\n\n<b>\(lingo.localize("capital.trade.gave", locale: locale))</b>\n\(give)"
            body += "\n\n<b>\(lingo.localize("capital.trade.got", locale: locale))</b>\n\(get)"
            await pushTradeBanner(text: body, to: side, context: context)
            await restoreMarketMenu(for: side, context: context)
        }
    }

    private func finishTradeFailure(sides: TradeStore.Sides, reason: TradeService.Reason, context: Context) async {
        let key: String
        let nick: String
        switch reason {
        case .itemGone(let n): key = "capital.trade.err.item_gone"; nick = n
        case .noSilver(let n): key = "capital.trade.err.no_silver"; nick = n
        case .bagFull(let n):  key = "capital.trade.err.bag_full";  nick = n
        }
        for side in [sides.a, sides.b] {
            let text = context.lingo.localize(key, locale: side.locale, interpolations: ["nick": nick])
            await pushTradeBanner(text: text, to: side, context: context)
            await restoreMarketMenu(for: side, context: context)
        }
    }

    private func pushTradeBanner(text: String, to side: TradeStore.Side, context: Context) async {
        _ = try? await context.bot.sendMessage(params: TGSendMessageParams(
            chatId: .chat(side.telegramId), text: text, parseMode: .html
        ))
    }

    private func restoreMarketMenu(for side: TradeStore.Side, context: Context) async {
        // Drop any dangling numeric prompt (transient input — removed from chat).
        if let pending = await EphemeralChatState.shared.takePendingTradeInput(telegramId: side.telegramId) {
            _ = try? await context.bot.deleteMessage(params: TGDeleteMessageParams(chatId: .chat(side.telegramId), messageId: pending.promptMessageId))
        }
        guard let msgId = side.screenMessageId else { return }
        let user: User?
        if side.telegramId == context.session.telegramId { user = context.session }
        else { user = try? await User.find(side.userId, on: context.db) }
        guard let user else { return }
        let activeLots = (try? await MarketListing.activeCount(for: user, on: context.db)) ?? 0
        let text = renderMarketMenuBody(session: user, lingo: context.lingo, activeLots: activeLots)
        let kb = marketMenuKeyboard(lingo: context.lingo, locale: user.locale)
        await editScreenFor(telegramId: side.telegramId, messageId: msgId, isPhoto: side.isPhoto, context: context, text: text, keyboard: kb)
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
        let intro = lingo.localize("capital.fortune.intro", gender: session.gender, locale: locale)
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
            await ctrl.postStatusBanner("⏳ \(text)", context: context)
        case .notEnoughSilver(let have, let need):
            let lingo = context.lingo
            let locale = context.session.locale
            let text = lingo.localize("capital.fortune.error.silver", locale: locale, interpolations: [
                "have": "\(have)", "need": "\(need)"
            ])
            await ctrl.postStatusBanner("❌ \(text)", context: context)
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
        let body  = lingo.localize(Location.tavern.bodyKey, gender: context.session.gender, locale: locale)
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
        let quest = lingo.localize("quest.button.open", locale: locale)
        return TGInlineKeyboardMarkup(inlineKeyboard: [
            [TGInlineKeyboardButton(text: menu,  callbackData: "tavern:food"),
             TGInlineKeyboardButton(text: dice,  callbackData: "tavern:dice"),
             TGInlineKeyboardButton(text: darts, callbackData: "tavern:darts")],
            [TGInlineKeyboardButton(text: quest, callbackData: "quest:board:tavern")],
            [TGInlineKeyboardButton(text: back, callbackData: "capital:back")]
        ])
    }

    private func editToTavernEntry(messageId: Int, isPhoto: Bool, context: Context) async throws {
        let lingo = context.lingo
        let locale = context.session.locale
        let title = lingo.localize(Location.tavern.titleKey, locale: locale)
        let body  = lingo.localize(Location.tavern.bodyKey, gender: context.session.gender, locale: locale)
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
            await postStatusBanner("❌ \(text)", context: context)
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
            // Phase 9.2 — the tavernkeeper's "Щаслива рука" job counts outright
            // wins only; a tie pays the stake back but doesn't tick.
            try? await QuestService.record(.gambleWin, for: context.session, on: context.db)
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
        switch result {
        case .success(_, let silver):
            let text = lingo.localize("capital.tavern.bought", locale: locale, interpolations: [
                "item": itemName, "silver": "🪙 \(silver)"
            ])
            await postStatusBanner("✅ \(text)", context: context)
        case .notEnoughSilver(let have, let need):
            let text = lingo.localize("capital.tavern.not_enough_silver", locale: locale, interpolations: [
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
        let guild   = TGKeyboardButton(text: l.localize("capital.button.guild",     locale: loc))
        let leave   = TGKeyboardButton(text: l.localize(Self.leaveButtonKey,        locale: loc))
        let markup = TGReplyKeyboardMarkup(keyboard: [
            [market, arena],
            [trader, fortune],
            [master, tavern],
            [guild],
            [Commands.inventory.button(for: session, lingo),
             Commands.profile.button(for: session, lingo)],
            [leave]
        ], resizeKeyboard: true)
        return TGReplyMarkup.replyKeyboardMarkup(markup)
    }
}
