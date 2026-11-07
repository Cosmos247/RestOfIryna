//
//  InventoryController.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 19.04.2026.
//
//  Inventory viewer with tree navigation.
//
//  UI is a single message whose text and inline keyboard are edited as the player
//  drills in and out (the list → card shape since 2026-11-01, the owner's design):
//    Root view      — category buttons with counts.
//    Category view  — one button per item, «Name × N»; gear one per ROW, its wear
//                     and a ✔️ at the end of what is worn. No action buttons here.
//    Card           — the item's own screen, drawn over the list: description,
//                     what a dish restores, «🎒 У сумці: N», a taken job's ⚠️,
//                     then the actions — «🍴 Зʼїсти» and the many-portion button
//                     (`MealMath`), «🗑 Викинути 1» / «🗑 Викинути всі (N)»; for
//                     gear its stats and condition with «🛡 Одягнути» / «❌ Зняти».
//                     Gear is never thrown away: the workshop's «Розібрати» is
//                     the one place a piece is destroyed.
//  The message is sent fresh on entry.
//
//  Main-menu reply keyboard stays visible while the player is in inventory. The router
//  registers handlers for each main-nav button text so those presses navigate correctly
//  instead of re-opening inventory via unmatched().
//

import Fluent
import Foundation
@preconcurrency import Lingo
import SwiftTelegramBot

// MARK: - Inventory Controller Logic
final class InventoryController: TGControllerBase, @unchecked Sendable {
    typealias T = InventoryController

    // MARK: - Controller Lifecycle
    override public func attachHandlers(to bot: TGBot, lingo: Lingo) async {
        let router = Router(bot: bot) { router in
            router[Commands.start.command()] = onStart

            let cancelLocales = Commands.cancel.buttonsForAllLocales(lingo: lingo)
            for button in cancelLocales { router[button.text] = onCancel }

            // Main-nav pass-through: reply-keyboard clicks while in inventory should navigate.
            let exploreLocales = Commands.explore.buttonsForAllLocales(lingo: lingo)
            for button in exploreLocales { router[button.text] = onExplore }

            let estateLocales = Commands.estate.buttonsForAllLocales(lingo: lingo)
            for button in estateLocales { router[button.text] = onEstate }

            let capitalLocales = Commands.capital.buttonsForAllLocales(lingo: lingo)
            for button in capitalLocales { router[button.text] = onCapital }

            let profileLocales = Commands.profile.buttonsForAllLocales(lingo: lingo)
            for button in profileLocales { router[button.text] = onProfile }

            let settingsLocales = Commands.settings.buttonsForAllLocales(lingo: lingo)
            for button in settingsLocales { router[button.text] = onSettings }

            let inventoryLocales = Commands.inventory.buttonsForAllLocales(lingo: lingo)
            for button in inventoryLocales { router[button.text] = onRefresh }

            // Turn back belongs to the trip, not to the bag — but the bag is the
            // one screen that can be open while a trip is in flight AND leaves
            // the road's reply keyboard standing, because its categories are
            // inline. Unregistered, the tap fell to `unmatched` and re-drew the
            // bag, which reads exactly like a dead button.
            let turnBackLocales = Commands.turnBack.buttonsForAllLocales(lingo: lingo)
            for button in turnBackLocales { router[button.text] = onTurnBack }

            router.unmatched = unmatched
            router[.callback_query(data: nil)] = InventoryController.onCallbackQuery
        }
        await processRouterForEachName(router)
    }

    public func onStart(context: Context) async throws -> Bool {
        let mainController = Controllers.mainController
        try await mainController.showMainMenu(context: context)
        context.session.routerName = mainController.routerName
        try await context.session.saveAndCache(in: context.db)
        return true
    }

    private func onCancel(context: Context) async throws -> Bool {
        return try await onStart(context: context)
    }

    override func unmatched(context: Context) async throws -> Bool {
        guard try await super.unmatched(context: context) else { return false }
        // The bag renders inline only, so re-drawing it repaired nothing: give
        // the menu keyboard back instead, as the estate does. `showMainMenu`
        // asks whether a trip is in flight, which is the one time this router
        // wears Turn back. The router stays put: every button is registered here.
        try await Controllers.mainController.showMainMenu(context: context)
        return true
    }

    // MARK: - Main-nav pass-through

    private func onExplore(context: Context) async throws -> Bool {
        let ctrl = Controllers.explorationController
        try await ctrl.showExploration(context: context)
        return true
    }

    private func onEstate(context: Context) async throws -> Bool {
        try await Controllers.estateController.showEstate(context: context)
        return true
    }

    private func onCapital(context: Context) async throws -> Bool {
        try await Controllers.capitalController.showCapital(context: context)
        return true
    }

    private func onProfile(context: Context) async throws -> Bool {
        let ctrl = Controllers.mainController
        try await ctrl.showProfile(context: context)
        context.session.routerName = ctrl.routerName
        try await context.session.saveAndCache(in: context.db)
        return true
    }

    /// Hands the trip back to `MainController`, which owns the road, and moves
    /// the router with it — the player is looking at a travel banner once this
    /// returns, not at their bag. Same shape as `onProfile` / `onSettings`.
    private func onTurnBack(context: Context) async throws -> Bool {
        let ctrl = Controllers.mainController
        let handled = try await ctrl.handleTurnBack(context: context)
        context.session.routerName = ctrl.routerName
        try await context.session.saveAndCache(in: context.db)
        return handled
    }

    private func onSettings(context: Context) async throws -> Bool {
        let ctrl = Controllers.settingsController
        try await ctrl.showSettingsMenu(context: context)
        context.session.routerName = ctrl.routerName
        try await context.session.saveAndCache(in: context.db)
        return true
    }

    private func onRefresh(context: Context) async throws -> Bool {
        try await showInventory(context: context)
        return true
    }

    // MARK: - Public entry

    public func showInventory(context: Context) async throws {
        let entries = try await InventoryEntry.list(for: context.session, on: context.db)
        let locked = try await Self.passiveRun(holding: context.session, on: context.db) != nil
        let text = renderRoot(entries: entries, session: context.session, lingo: context.lingo,
                              locale: context.session.locale, locked: locked)
        let inline = rootKeyboard(entries: entries, lingo: context.lingo, locale: context.session.locale)
        try await context.bot.sendMessage(
            session: context.session,
            text: text,
            parseMode: .html,
            replyMarkup: .inlineKeyboardMarkup(inline)
        )
    }

    override public func generateControllerKB(session: User, lingo: Lingo) -> TGReplyMarkup? {
        // Reuse main's keyboard so `/buttons` restores nav while in inventory.
        return Controllers.mainController.generateControllerKB(session: session, lingo: lingo)
    }

    // MARK: - The bag while the governor is out

    /// The passive run that has the bag right now, or nil. While the governor
    /// is out (2026-10-12) the bag is his: the player may look, and every tap
    /// that would change it or what he wears is refused — the owner's «прибери
    /// можливість людини їсти за бота», then «закрий і решту дій». The lock
    /// sits here, at the bag's buttons, and never in `VigorService`: the
    /// governor eats through it on the road. A run whose report is written is
    /// home, and the bag with it.
    static func passiveRun(holding session: User, on db: any Database) async throws -> ExplorationState? {
        guard let state = try await ExplorationState.current(for: session, on: db),
              state.isPassive, state.reportJSON == nil else { return nil }
        return state
    }

    /// The modal a refused tap answers with while `run` holds the bag — here,
    /// and on every item card's buttons in either bag (`BagCard.handle`), a
    /// stale trail-bag message included, which reaches the bag through the
    /// main router.
    static func passiveLockAlert(_ run: ExplorationState, context: Context) -> String {
        let locale = context.session.locale
        return "🏕 " + context.lingo.localize("exploration.passive.bag_locked_alert",
                                             gender: context.session.gender, locale: locale,
                                             interpolations: [
            "time": Countdown.format(run.secondsRemaining() ?? 0, lingo: context.lingo, locale: locale)
        ])
    }

    // MARK: - Rendering

    fileprivate func renderRoot(entries: [InventoryEntry], session: User, lingo: Lingo, locale: String,
                                locked: Bool = false) -> String {
        let title = lingo.localize("inventory.title", locale: locale)
        // Per-unit (2026-05-12): sum quantities across all non-equipped rows.
        let slotsUsed = entries.filter { $0.equippedSlot == nil }.reduce(0) { $0 + $1.quantity }
        let slotsLabel = lingo.localize("inventory.slots_label", locale: locale)
        let cap = InventoryEntry.slotCap(for: session)
        // «(вільно 30)» after the count (2026-11-04, the players' ask) — the
        // trail bag's header says the same, from the same reading.
        let free = lingo.localize("inventory.free", locale: locale, interpolations: [
            "free": "\(InventoryEntry.freeSlots(used: slotsUsed, for: session))"
        ])
        var header = "<b>\(title)</b>  <i>\(slotsUsed)/\(cap) \(slotsLabel) (\(free))</i>"
        // Said on the screen before a tap is refused (`passiveRun(holding:)`).
        if locked {
            header += "\n\n🏕 " + lingo.localize("exploration.passive.bag_locked", gender: session.gender, locale: locale)
        }
        if entries.isEmpty {
            return "\(header)\n\n" + lingo.localize("inventory.empty", locale: locale)
        }
        return "\(header)\n\n" + lingo.localize("inventory.choose_category", locale: locale)
    }

    fileprivate func rootKeyboard(entries: [InventoryEntry], lingo: Lingo, locale: String) -> TGInlineKeyboardMarkup {
        var countsByType: [ItemType: Int] = [:]
        for entry in entries {
            guard let item = ItemCatalog.find(entry.itemId) else { continue }
            countsByType[item.type, default: 0] += entry.quantity
        }

        // Always render every category — empty ones show (0) and reply with a toast
        // on tap rather than opening an empty drill-down.
        let typeOrder: [ItemType] = [.food, .material, .potion, .gear, .artifact]
        var rows: [[TGInlineKeyboardButton]] = []
        var currentRow: [TGInlineKeyboardButton] = []

        for type in typeOrder {
            let count = countsByType[type, default: 0]
            let name = lingo.localize("inventory.type.\(type.rawValue)", locale: locale)
            let label = "\(type.icon) \(name) (\(count))"
            currentRow.append(TGInlineKeyboardButton(text: label, callbackData: "inv:cat:\(type.rawValue)"))
            if currentRow.count == 2 {
                rows.append(currentRow)
                currentRow = []
            }
        }
        if !currentRow.isEmpty { rows.append(currentRow) }

        return TGInlineKeyboardMarkup(inlineKeyboard: rows)
    }

    fileprivate func renderCategory(type: ItemType, lingo: Lingo, locale: String) -> String {
        let name = lingo.localize("inventory.type.\(type.rawValue)", locale: locale)
        return "\(type.icon) <b>\(name)</b>"
    }

    fileprivate func categoryKeyboard(type: ItemType, entries: [InventoryEntry], lingo: Lingo, locale: String) -> TGInlineKeyboardMarkup {
        let rows: [[TGInlineKeyboardButton]]
        if type == .gear {
            rows = gearRows(entries: entries, lingo: lingo, locale: locale)
        } else {
            rows = genericRows(type: type, entries: entries, lingo: lingo, locale: locale)
        }

        let backLabel = lingo.localize("inventory.back_root", locale: locale)
        return TGInlineKeyboardMarkup(inlineKeyboard: rows + [
            [TGInlineKeyboardButton(text: backLabel, callbackData: "inv:root")]
        ])
    }

    /// Gear rows — gear is non-stackable, so every unit is its own physical row
    /// (InventoryEntry), and each renders as its own button pair addressed by
    /// the ROW's id (2026-09-27). Callbacks used to carry the item id, on the
    /// reasoning that two copies were "visually identical, so indistinguishable
    /// from targeting a specific one". Wear made that false: two hoods at 1/1
    /// and 30/30 are different pieces, and [Одягнути] put on whichever one
    /// Postgres returned first. So every durable row prints its own wear, and
    /// every action names the row it acts on.
    private func gearRows(entries: [InventoryEntry], lingo: Lingo, locale: String) -> [[TGInlineKeyboardButton]] {
        let pairs: [(entry: InventoryEntry, item: Item)] = entries.compactMap { entry in
            guard let item = ItemCatalog.find(entry.itemId), item.type == .gear else { return nil }
            return (entry, item)
        }
        // Equipped rows first, then by item id, then the best-kept copy first —
        // a stable order across refreshes, so a row does not jump under the
        // player's thumb between two taps.
        let sorted = pairs.sorted { lhs, rhs in
            let lhsEquipped = lhs.entry.equippedSlot != nil
            let rhsEquipped = rhs.entry.equippedSlot != nil
            if lhsEquipped != rhsEquipped { return lhsEquipped }
            if lhs.item.id != rhs.item.id { return lhs.item.id < rhs.item.id }
            if lhs.entry.maxDurability != rhs.entry.maxDurability { return lhs.entry.maxDurability > rhs.entry.maxDurability }
            if lhs.entry.durability != rhs.entry.durability { return lhs.entry.durability > rhs.entry.durability }
            return (lhs.entry.id?.uuidString ?? "") < (rhs.entry.id?.uuidString ?? "")
        }

        // The list says what is worn (2026-11-01): the Одягнути / Зняти button
        // that used to say it moved onto the card. A ✔️ at the end of the row —
        // the owner's pick over «· на вас», 🟢, 👤 and 📍; an emoji, so no locale
        // carries it. Free in the game, unlike the green ✅ of a banner or a price.
        let wornMarker = "✔️"

        return sorted.map { pair in
            // Tier-aware name, rarity glyph above the baseline only, the
            // enchant as a plain "+N" and the row's wear (`gearRowLabel`). Wear
            // was kept out of the label on 2026-05-21 so the name would not
            // truncate; it came back on 2026-09-27 because without it two
            // copies cannot be told apart.
            var itemLabel = ItemDisplay.gearRowLabel(item: pair.item, state: pair.entry.gearState,
                                                     lingo: lingo, locale: locale)
            if pair.entry.equippedSlot != nil {
                itemLabel += " \(wornMarker)"
            }
            // The row's id; the item id only for a row that has none yet, which
            // a row read back from the database never is.
            let target = pair.entry.id?.uuidString ?? pair.item.id
            return [TGInlineKeyboardButton(text: itemLabel, callbackData: "inv:info:\(target)")]
        }
    }

    /// The gear card's buttons: what this copy can do — put on, or take off —
    /// and the way back to the list. One button for the copy's own state, so a
    /// tap flips it and the card redraws with the other.
    fileprivate static func gearCardKeyboard(row: InventoryEntry, lingo: Lingo, locale: String) -> TGInlineKeyboardMarkup {
        let target = row.id?.uuidString ?? row.itemId
        let action = row.equippedSlot != nil
            ? TGInlineKeyboardButton(text: lingo.localize("inventory.action.gear.unequip", locale: locale),
                                     callbackData: "inv:unequip:\(target)")
            : TGInlineKeyboardButton(text: lingo.localize("inventory.action.gear", locale: locale),
                                     callbackData: "inv:equip:\(target)")
        let back = TGInlineKeyboardButton(text: lingo.localize("inventory.card.back", locale: locale),
                                          callbackData: "inv:cat:\(ItemType.gear.rawValue)")
        return TGInlineKeyboardMarkup(inlineKeyboard: [[action], [back]])
    }

    // A gear row's card text is `BagCard.gearText` (2026-11-01): the warehouse's
    // gear card prints the same one.

    /// Non-gear rows (food / material / potion / artifact): one button per item,
    /// «Name × N», which opens the item's card (2026-11-01, the owner's design —
    /// «лише назви … без кнопки зʼїсти»). Every action lives on the card.
    /// `inv:info:` is the name button's old callback, so a bag message left in
    /// chat from before opens the card too; its old «🍴 Зʼїсти» buttons
    /// (`inv:use:`) still eat one portion.
    private func genericRows(type: ItemType, entries: [InventoryEntry], lingo: Lingo, locale: String) -> [[TGInlineKeyboardButton]] {
        var items: [(item: Item, quantity: Int)] = []
        for entry in entries {
            guard let item = ItemCatalog.find(entry.itemId), item.type == type else { continue }
            items.append((item, entry.quantity))
        }
        return mergeForDisplay(items).map { (item, qty) in
            let name = lingo.localize(item.nameKey, locale: locale)
            let iconPrefix = item.icon.map { "\($0) " } ?? ""
            return [TGInlineKeyboardButton(text: "\(iconPrefix)\(name) × \(qty)", callbackData: "inv:info:\(item.id)")]
        }
    }

    // The item's card and its five actions live in `BagCard` (2026-11-01), which the
    // trail bag shares; this controller keeps gear's card and the lists.

    private func mergeForDisplay(_ items: [(item: Item, quantity: Int)]) -> [(item: Item, quantity: Int)] {
        var byId: [String: (item: Item, quantity: Int)] = [:]
        for entry in items {
            if let existing = byId[entry.item.id] {
                byId[entry.item.id] = (existing.item, existing.quantity + entry.quantity)
            } else {
                byId[entry.item.id] = entry
            }
        }
        return Array(byId.values).sorted { $0.item.id < $1.item.id }
    }
}

// MARK: - Callback Queries

extension InventoryController {
    static func onCallbackQuery(context: Context) async throws -> Bool {
        guard let query = context.update.callbackQuery else { return false }
        guard let message = query.message else { return false }
        guard let data = query.data else { return false }

        // Exploration callbacks (e.g. a scheduler-pushed passive report's
        // Close button) can land here if the player was viewing their bag
        // when the expedition completed. Forward to ExplorationController
        // so its full cleanup runs instead of falling through unhandled.
        if data.hasPrefix("explore:") {
            return try await ExplorationController.onCallbackQuery(context: context)
        }
        // Forward combat callbacks (Training Ground keeps routerName at the
        // pre-combat router so reply-keyboard nav stays unblocked).
        if data.hasPrefix("combat:") {
            return try await CombatController.onCallbackQuery(context: context)
        }

        let ctrl = Controllers.inventoryController
        let locale = context.session.locale

        // Back to root
        if data == "inv:root" {
            let entries = try await InventoryEntry.list(for: context.session, on: context.db)
            let locked = try await passiveRun(holding: context.session, on: context.db) != nil
            let text = ctrl.renderRoot(entries: entries, session: context.session, lingo: context.lingo,
                                       locale: locale, locked: locked)
            let inline = ctrl.rootKeyboard(entries: entries, lingo: context.lingo, locale: locale)
            await editScreen(message, text: text, replyMarkup: inline, bot: context.bot)
            _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id))
            return true
        }

        // Open category
        if data.starts(with: "inv:cat:") {
            let rawType = String(data.dropFirst("inv:cat:".count))
            guard let type = ItemType(rawValue: rawType) else {
                _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id))
                return true
            }
            let entries = try await InventoryEntry.list(for: context.session, on: context.db)

            // Empty category — reply with toast, stay on root.
            let hasItems = entries.contains { ItemCatalog.find($0.itemId)?.type == type }
            if !hasItems {
                let text = context.lingo.localize("inventory.category.empty", locale: locale)
                _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id, text: text, showAlert: true))
                return true
            }

            let text = ctrl.renderCategory(type: type, lingo: context.lingo, locale: locale)
            let inline = ctrl.categoryKeyboard(type: type, entries: entries, lingo: context.lingo, locale: locale)
            await editScreen(message, text: text, replyMarkup: inline, bot: context.bot)
            _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id))
            return true
        }

        // A gear ROW (2026-09-27): the card of that copy, not of whichever one
        // is worn — drawn over the list since 2026-11-01, with the copy's own
        // Одягнути / Зняти. A row that is gone by now redraws the list, which
        // is the screen that knows what the bag holds.
        if data.starts(with: "inv:info:"),
           let rowId = UUID(uuidString: String(data.dropFirst("inv:info:".count))) {
            _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id))
            guard let row = try await ownedRow(rowId, context: context),
                  let item = ItemCatalog.find(row.itemId) else {
                try await refreshCategory(type: .gear, message: message, context: context)
                return true
            }
            await showGearCard(row: row, item: item, message: message, context: context)
            return true
        }

        // An item's name: its card, drawn over the list (2026-11-01). It used
        // to answer with the description in a modal; the card carries the
        // description and the actions the list no longer does.
        if data.starts(with: "inv:info:") {
            let itemId = String(data.dropFirst("inv:info:".count))
            _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id))
            guard let item = ItemCatalog.find(itemId) else { return true }
            // Gear by item id — a button left in chat from before rows had ids:
            // the worn copy's card, or the first one's.
            if item.type == .gear {
                guard let userId = context.session.id else { return true }
                let rows = try await InventoryEntry.query(on: context.db)
                    .filter(\.$user.$id, .equal, userId)
                    .filter(\.$itemId, .equal, item.id)
                    .all()
                if let row = rows.first(where: { $0.equippedSlot != nil }) ?? rows.first {
                    await showGearCard(row: row, item: item, message: message, context: context)
                } else {
                    try await refreshCategory(type: .gear, message: message, context: context)
                }
                return true
            }
            try await BagCard.redraw(item, route: .bag, message: message, context: context,
                                     list: { try await bagList(after: $0, context: context) })
            return true
        }

        // The item card's six verbs — eat, eat many, throw away one, all, and
        // each question's yes — one implementation with the trail bag's.
        if BagCard.isAction(data, route: .bag) {
            return try await BagCard.handle(data, query: query, message: message, context: context,
                                            route: .bag, list: { try await bagList(after: $0, context: context) })
        }

        // The governor has the bag (2026-10-12): learning a scroll, equipping
        // and unequipping wait for him (the card's own verbs ask in `BagCard`).
        // A modal, so the screen the tap came from stays as it was. Opening a
        // card is looking, and stays open to him.
        if changingPrefixes.contains(where: { data.starts(with: $0) }),
           let run = try await passiveRun(holding: context.session, on: context.db) {
            _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(
                callbackQueryId: query.id, text: passiveLockAlert(run, context: context), showAlert: true))
            return true
        }

        // Use — food/potion consume via VigorService; recipe-scroll artifacts
        // route to the Learn flow (Phase 5.2.1); others show "not yet available"
        // until their systems ship (gear = equip Phase 2.3, generic artifact = activate TBD).
        if data.starts(with: "inv:use:") {
            let itemId = String(data.dropFirst("inv:use:".count))

            guard let item = ItemCatalog.find(itemId) else {
                _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id))
                return true
            }

            // Recipe scrolls — Learn flow.
            if let recipeId = item.teachesRecipe {
                return try await handleLearnRecipe(itemId: itemId, recipeId: recipeId, item: item, query: query, message: message, context: context)
            }

            if !VigorService.isConsumable(item) {
                let text = context.lingo.localize("inventory.use.unavailable", locale: locale)
                _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id, text: text, showAlert: true))
                return true
            }

            // Consumable type but no effects — e.g. raw potato, a cooking
            // ingredient that can't be eaten as-is.
            if item.effects.isEmpty {
                let itemName = context.lingo.localize(item.nameKey, locale: locale)
                let text = context.lingo.localize("consume.not_raw_edible", locale: locale, interpolations: ["name": itemName])
                _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id, text: text, showAlert: true))
                return true
            }

            guard try await InventoryEntry.has(itemId, user: context.session, on: context.db) else {
                _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id))
                return true
            }
            guard let result = VigorService.consume(item, user: context.session) else {
                let text = context.lingo.localize("consume.no_effect", locale: locale)
                _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id, text: text, showAlert: true))
                return true
            }
            try await InventoryEntry.remove(itemId, quantity: 1, from: context.session, on: context.db)
            try await context.session.saveAndCache(in: context.db)

            _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id))

            // The «🍴 Зʼїсти» of a bag list left in chat from before the card
            // (2026-11-01): it still eats one portion, and redraws the list.
            let statusLine = BagCard.mealBanner(item: item, eaten: 1, result: result, context: context)

            // Refresh: stay in category if items remain, else pop back to root.
            let entries = try await InventoryEntry.list(for: context.session, on: context.db)
            let stillInCategory = entries.contains { ItemCatalog.find($0.itemId)?.type == item.type }
            let refreshedBody: String
            let refreshedInline: TGInlineKeyboardMarkup
            if stillInCategory {
                refreshedBody = ctrl.renderCategory(type: item.type, lingo: context.lingo, locale: locale)
                refreshedInline = ctrl.categoryKeyboard(type: item.type, entries: entries, lingo: context.lingo, locale: locale)
            } else {
                refreshedBody = ctrl.renderRoot(entries: entries, session: context.session, lingo: context.lingo, locale: locale)
                refreshedInline = ctrl.rootKeyboard(entries: entries, lingo: context.lingo, locale: locale)
            }
            await editScreen(message, text: refreshedBody, replyMarkup: refreshedInline, bot: context.bot)
            await ctrl.postStatusBanner(statusLine, context: context)
            return true
        }

        // Equip a gear ROW (2026-09-27) — the copy the player tapped.
        if data.starts(with: "inv:equip:"),
           let rowId = UUID(uuidString: String(data.dropFirst("inv:equip:".count))) {
            _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id))
            guard let target = try await ownedRow(rowId, context: context),
                  let item = ItemCatalog.find(target.itemId), item.slot != nil else {
                // Gone, or not wearable — the list is the answer.
                try await refreshCategory(type: .gear, message: message, context: context)
                return true
            }
            // Already worn (a second tap, or a card left in chat): the card,
            // which now says «❌ Зняти», is the answer.
            guard target.equippedSlot == nil else {
                await showGearCard(row: target, item: item, message: message, context: context)
                return true
            }
            try await EquipmentService.equip(target, for: context.session, on: context.db)
            let itemName = context.lingo.localize(ItemDisplay.nameKey(for: item, tier: target.tier), locale: locale)
            let statusLine = "✅ " + context.lingo.localize("equip.success", locale: locale, interpolations: ["item": itemName])
            // The card stays, its button flipped (2026-11-01): the tap came
            // from the card, and the card is what changed.
            await showGearCard(row: target, item: item, message: message, context: context, statusLine: statusLine)
            return true
        }

        // Equip by item id — a button left in chat from before rows had ids.
        if data.starts(with: "inv:equip:") {
            let itemId = String(data.dropFirst("inv:equip:".count))
            guard let item = ItemCatalog.find(itemId), item.slot != nil,
                  let userId = context.session.id else {
                _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id))
                return true
            }
            let rows = try await InventoryEntry.query(on: context.db)
                .filter(\.$user.$id, .equal, userId)
                .filter(\.$itemId, .equal, itemId)
                .all()
            // An item-id button left in chat from before rows had ids. One
            // unworn copy is unambiguous; with several, guessing is exactly
            // the defect the row ids replaced, so the list is redrawn with a
            // button per copy instead.
            let unworn = rows.filter { $0.equippedSlot == nil }
            guard unworn.count == 1, let target = unworn.first else {
                _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id))
                if unworn.count > 1 {
                    try await refreshCategory(type: .gear, message: message, context: context)
                }
                return true
            }
            try await EquipmentService.equip(target, for: context.session, on: context.db)

            _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id))

            // The ROW's tier, not the catalog's base name: the button the player
            // just tapped says «Очищений меч» and the banner said «Іржавий меч».
            let itemName = context.lingo.localize(ItemDisplay.nameKey(for: item, tier: target.tier), locale: locale)
            let statusLine = "✅ " + context.lingo.localize("equip.success", locale: locale, interpolations: ["item": itemName])
            try await refreshCategory(type: .gear, message: message, context: context, statusLine: statusLine)
            return true
        }

        // Unequip a gear ROW (2026-09-27).
        if data.starts(with: "inv:unequip:"),
           let rowId = UUID(uuidString: String(data.dropFirst("inv:unequip:".count))) {
            _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id))
            guard let target = try await ownedRow(rowId, context: context),
                  let item = ItemCatalog.find(target.itemId) else {
                try await refreshCategory(type: .gear, message: message, context: context)
                return true
            }
            // Already off: the card, which now says «🛡 Одягнути».
            guard target.equippedSlot != nil else {
                await showGearCard(row: target, item: item, message: message, context: context)
                return true
            }
            try await EquipmentService.unequip(target, for: context.session, on: context.db)
            let itemName = context.lingo.localize(ItemDisplay.nameKey(for: item, tier: target.tier), locale: locale)
            let statusLine = "✅ " + context.lingo.localize("unequip.success", locale: locale, interpolations: ["item": itemName])
            await showGearCard(row: target, item: item, message: message, context: context, statusLine: statusLine)
            return true
        }

        // Unequip gear by item id — a button left in chat from before rows had
        // ids. Unambiguous: one slot holds one piece.
        if data.starts(with: "inv:unequip:") {
            let itemId = String(data.dropFirst("inv:unequip:".count))
            guard let item = ItemCatalog.find(itemId),
                  let userId = context.session.id else {
                _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id))
                return true
            }
            let rows = try await InventoryEntry.query(on: context.db)
                .filter(\.$user.$id, .equal, userId)
                .filter(\.$itemId, .equal, itemId)
                .all()
            guard let target = rows.first(where: { $0.equippedSlot != nil }) else {
                _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id))
                return true
            }
            try await EquipmentService.unequip(target, for: context.session, on: context.db)

            _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id))

            // Same rule as equip — the row's tier names the row.
            let itemName = context.lingo.localize(ItemDisplay.nameKey(for: item, tier: target.tier), locale: locale)
            let statusLine = "✅ " + context.lingo.localize("unequip.success", locale: locale, interpolations: ["item": itemName])
            try await refreshCategory(type: .gear, message: message, context: context, statusLine: statusLine)
            return true
        }

        // Anything that doesn't match an `inv:*` callback (e.g. `journal:`
        // opened from the profile while the player is in the inventory
        // routerName, or stale `fortune:*` insurance) is forwarded to
        // MainController, which owns those prefixes and falls back to deleting
        // truly unknown inline messages. Returning `false` here used to surface
        // "Unsupported content type." to the player.
        return try await MainController.onCallbackQuery(context: context)
    }

    /// Handle a tap on `📖 Learn` for a recipe-scroll artifact (Phase 5.2.1).
    /// On a fresh learn the scroll row is deleted and the Artifacts category
    /// is refreshed in place with a `✅ Learned: <recipe>` status line. If the
    /// player already knows the recipe, the scroll is left in the bag and a
    /// modal alert explains why nothing happened.
    private static func handleLearnRecipe(
        itemId: String,
        recipeId: String,
        item: Item,
        query: TGCallbackQuery,
        message: TGMaybeInaccessibleMessage,
        context: Context
    ) async throws -> Bool {
        let locale = context.session.locale

        // Already known → modal, leave scroll in inventory.
        if try await LearnedRecipe.has(recipeId, for: context.session, on: context.db) {
            let toast = context.lingo.localize("learn.already_known", locale: locale)
            _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id, text: toast, showAlert: true))
            return true
        }

        // Find the scroll row (non-stackable, so any matching row is fine).
        guard let userId = context.session.id else {
            _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id))
            return true
        }
        let rows = try await InventoryEntry.query(on: context.db)
            .filter(\.$user.$id, .equal, userId)
            .filter(\.$itemId, .equal, itemId)
            .all()
        guard let scrollRow = rows.first else {
            _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id))
            return true
        }

        // Add to learned set, then delete the scroll.
        _ = try await LearnedRecipe.add(recipeId, for: context.session, on: context.db)
        try await scrollRow.delete(on: context.db)

        // Build the inline status banner — show the **recipe output's**
        // name so the player sees what they just unlocked, not the scroll's
        // name (which is just "Recipe: X" anyway). Falls back to the scroll's
        // name if the recipe lookup somehow misses.
        let recipeName: String
        if let recipe = RecipeCatalog.find(recipeId),
           let outputItem = ItemCatalog.find(recipe.output.itemId) {
            recipeName = context.lingo.localize(outputItem.nameKey, locale: locale)
        } else {
            recipeName = context.lingo.localize(item.nameKey, locale: locale)
        }
        let outputIcon = RecipeCatalog.find(recipeId).flatMap { ItemCatalog.find($0.output.itemId)?.icon } ?? ""
        let statusLine = "✅ " + context.lingo.localize("learn.success", locale: locale, interpolations: [
            "icon": outputIcon,
            "name": recipeName
        ])

        _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id))

        // Refresh: stay in Artifacts if any rows remain, else pop to root.
        let entries = try await InventoryEntry.list(for: context.session, on: context.db)
        let stillInCategory = entries.contains { ItemCatalog.find($0.itemId)?.type == .artifact }
        let ctrl = Controllers.inventoryController
        if stillInCategory {
            try await refreshCategory(type: .artifact, message: message, context: context, statusLine: statusLine)
        } else {
            let body = ctrl.renderRoot(entries: entries, session: context.session, lingo: context.lingo, locale: locale)
            let inline = ctrl.rootKeyboard(entries: entries, lingo: context.lingo, locale: locale)
            await editScreen(message, text: body, replyMarkup: inline, bot: context.bot)
            await ctrl.postStatusBanner(statusLine, context: context)
        }
        return true
    }

    /// One of this player's bag rows by its id — nil when it is gone or was
    /// never theirs. Ownership is part of the lookup, not a later check: a row
    /// id arrives in callback data, which the client sends.
    private static func ownedRow(_ rowId: UUID, context: Context) async throws -> InventoryEntry? {
        guard let userId = context.session.id else { return nil }
        return try await InventoryEntry.query(on: context.db)
            .filter(\.$user.$id, .equal, userId)
            .filter(\.$id, .equal, rowId)
            .first()
    }

    /// Re-render the given category view in place after an equip/unequip.
    /// `statusLine` is published as a separate banner under the inline
    /// keyboard rather than embedded in the body — see `postStatusBanner`.
    private static func refreshCategory(type: ItemType, message: TGMaybeInaccessibleMessage, context: Context, statusLine: String? = nil) async throws {
        let ctrl = Controllers.inventoryController
        let entries = try await InventoryEntry.list(for: context.session, on: context.db)
        let body = ctrl.renderCategory(type: type, lingo: context.lingo, locale: context.session.locale)
        let inline = ctrl.categoryKeyboard(type: type, entries: entries, lingo: context.lingo, locale: context.session.locale)
        await editScreen(message, text: body, replyMarkup: inline, bot: context.bot)
        if let statusLine {
            await ctrl.postStatusBanner(statusLine, context: context)
        }
    }

    // MARK: - Gear's card and the lists (2026-11-01)

    /// The verbs the governor's lock refuses here; the item card's own five
    /// ask the same lock in `BagCard.handle`.
    private static let changingPrefixes = ["inv:use:", "inv:equip:", "inv:unequip:"]

    /// A gear row's card, drawn over the message the tap came from, with the
    /// copy's own Одягнути / Зняти; `statusLine` goes out as the banner under it.
    private static func showGearCard(row: InventoryEntry, item: Item, message: TGMaybeInaccessibleMessage,
                                     context: Context, statusLine: String? = nil) async {
        let locale = context.session.locale
        let card = BagCard.gearText(item: item, state: row.gearState, lingo: context.lingo, locale: locale)
        let markup = gearCardKeyboard(row: row, lingo: context.lingo, locale: locale)
        await editScreen(message, text: card, replyMarkup: markup, bot: context.bot)
        if let statusLine {
            await Controllers.inventoryController.postStatusBanner(statusLine, context: context)
        }
    }

    /// Where a card lands once nothing of `item` is left: the list it was
    /// opened from, or — that category emptied — the bag's root.
    private static func bagList(after item: Item, context: Context) async throws -> BagCard.Screen {
        let ctrl = Controllers.inventoryController
        let lingo = context.lingo, locale = context.session.locale
        let entries = try await InventoryEntry.list(for: context.session, on: context.db)
        if entries.contains(where: { ItemCatalog.find($0.itemId)?.type == item.type }) {
            return (ctrl.renderCategory(type: item.type, lingo: lingo, locale: locale),
                    ctrl.categoryKeyboard(type: item.type, entries: entries, lingo: lingo, locale: locale))
        }
        let locked = try await passiveRun(holding: context.session, on: context.db) != nil
        return (ctrl.renderRoot(entries: entries, session: context.session, lingo: lingo, locale: locale, locked: locked),
                ctrl.rootKeyboard(entries: entries, lingo: lingo, locale: locale))
    }
}
