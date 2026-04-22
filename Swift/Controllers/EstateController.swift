//
//  EstateController.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 19.04.2026.
//
//  Estate screen — tree navigation over the manor and the plot of land.
//
//  Layout:
//    Root          — header (estate name + level) + description + artwork placeholder,
//                    two inline buttons: [🏠 House] [🌾 Plot].
//    House         — three inline buttons: [🛠 Workshop] [🍳 Kitchen] [📦 Warehouse],
//                    plus a back button to Root.
//    Workshop/Kitchen/Warehouse/Plot — stubs (coming-soon) with a back button.
//
//  Per-level artwork (Assets/estate/level_<N>.jpg) is optional for now — the code
//  tries to load it but falls back to a text-only message when missing. The user
//  will drop files in as they're drawn.
//

import Foundation
@preconcurrency import Lingo
import SwiftTelegramBot

// MARK: - Estate Controller Logic
final class EstateController: TGControllerBase, @unchecked Sendable {
    typealias T = EstateController

    // MARK: - Controller Lifecycle
    override public func attachHandlers(to bot: TGBot, lingo: Lingo) async {
        let router = Router(bot: bot) { router in
            router[Commands.start.command()] = onStart

            let cancelLocales = Commands.cancel.buttonsForAllLocales(lingo: lingo)
            for button in cancelLocales { router[button.text] = onCancel }

            // Main-nav pass-through — the main reply keyboard stays visible while the
            // player is in Estate, so presses must continue to navigate correctly.
            let exploreLocales = Commands.explore.buttonsForAllLocales(lingo: lingo)
            for button in exploreLocales { router[button.text] = onExplore }

            let capitalLocales = Commands.capital.buttonsForAllLocales(lingo: lingo)
            for button in capitalLocales { router[button.text] = onCapital }

            let profileLocales = Commands.profile.buttonsForAllLocales(lingo: lingo)
            for button in profileLocales { router[button.text] = onProfile }

            let settingsLocales = Commands.settings.buttonsForAllLocales(lingo: lingo)
            for button in settingsLocales { router[button.text] = onSettings }

            let inventoryLocales = Commands.inventory.buttonsForAllLocales(lingo: lingo)
            for button in inventoryLocales { router[button.text] = onInventory }

            let estateLocales = Commands.estate.buttonsForAllLocales(lingo: lingo)
            for button in estateLocales { router[button.text] = onRefresh }

            router.unmatched = unmatched
            router[.callback_query(data: nil)] = EstateController.onCallbackQuery
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
        try await showEstate(context: context)
        return true
    }

    // MARK: - Main-nav pass-through

    private func onExplore(context: Context) async throws -> Bool {
        let ctrl = Controllers.explorationController
        try await ctrl.showExploration(context: context)
        return true
    }

    private func onCapital(context: Context) async throws -> Bool {
        let ctrl = Controllers.capitalController
        try await ctrl.showStub(context: context)
        context.session.routerName = ctrl.routerName
        try await context.session.saveAndCache(in: context.db)
        return true
    }

    private func onProfile(context: Context) async throws -> Bool {
        let ctrl = Controllers.mainController
        try await ctrl.showProfile(context: context)
        context.session.routerName = ctrl.routerName
        try await context.session.saveAndCache(in: context.db)
        return true
    }

    private func onSettings(context: Context) async throws -> Bool {
        let ctrl = Controllers.settingsController
        try await ctrl.showSettingsMenu(context: context)
        context.session.routerName = ctrl.routerName
        try await context.session.saveAndCache(in: context.db)
        return true
    }

    private func onInventory(context: Context) async throws -> Bool {
        let ctrl = Controllers.inventoryController
        try await ctrl.showInventory(context: context)
        context.session.routerName = ctrl.routerName
        try await context.session.saveAndCache(in: context.db)
        return true
    }

    private func onRefresh(context: Context) async throws -> Bool {
        try await showEstate(context: context)
        return true
    }

    // MARK: - Public entry

    public func showEstate(context: Context) async throws {
        // Guard: estate is inaccessible while the governor is in the field.
        // Same rule for active and passive — if an ExplorationState row
        // exists, the manor is locked until the expedition ends.
        if try await ExplorationState.current(for: context.session, on: context.db) != nil {
            let notice = context.lingo.localize("estate.blocked_by_expedition", locale: context.session.locale)
            try await context.bot.sendMessage(
                session: context.session,
                text: notice,
                parseMode: .html,
                replyMarkup: nil
            )
            return
        }

        // Entering estate — own the routerName transition so callers don't
        // have to (and can't mis-transition when we bail out above).
        context.session.routerName = routerName
        try await context.session.saveAndCache(in: context.db)

        let text = renderRoot(session: context.session, lingo: context.lingo)
        let inline = rootKeyboard(lingo: context.lingo, locale: context.session.locale)

        // Try to attach per-level artwork. Optional for now — user will add JPEGs later.
        let level = context.session.estateLevel
        let imageURL = URL(fileURLWithPath: "\(projectPath)/Assets/estate/level_\(level).jpg")
        if let imageData = try? Data(contentsOf: imageURL) {
            let inputFile = TGInputFile(filename: "level_\(level).jpg", data: imageData, mimeType: "image/jpeg")
            let params = TGSendPhotoParams(
                chatId: .chat(context.session.telegramId),
                photo: .file(inputFile),
                caption: text,
                parseMode: .html,
                replyMarkup: .inlineKeyboardMarkup(inline)
            )
            _ = try await context.bot.sendPhoto(params: params)
        } else {
            try await context.bot.sendMessage(
                session: context.session,
                text: text,
                parseMode: .html,
                replyMarkup: .inlineKeyboardMarkup(inline)
            )
        }
    }

    override public func generateControllerKB(session: User, lingo: Lingo) -> TGReplyMarkup? {
        // Reuse main's reply keyboard so `/buttons` restores nav while in estate.
        return Controllers.mainController.generateControllerKB(session: session, lingo: lingo)
    }

    // MARK: - View rendering

    fileprivate func renderRoot(session: User, lingo: Lingo) -> String {
        let locale = session.locale
        let title = lingo.localize("estate.title", locale: locale)
        let estateName = session.estateName ?? "?"
        let level = session.estateLevel
        let levelLabel = lingo.localize("estate.level_label", locale: locale)
        let description = lingo.localize("estate.description", locale: locale)
        return "🏰 <b>\(title) «\(estateName)»</b>\n\(levelLabel): <b>\(level)</b>\n\n\(description)"
    }

    fileprivate func rootKeyboard(lingo: Lingo, locale: String) -> TGInlineKeyboardMarkup {
        let home = lingo.localize("estate.home", locale: locale)
        let plot = lingo.localize("estate.plot", locale: locale)
        return TGInlineKeyboardMarkup(inlineKeyboard: [[
            TGInlineKeyboardButton(text: home, callbackData: "estate:home"),
            TGInlineKeyboardButton(text: plot, callbackData: "estate:plot")
        ]])
    }

    fileprivate func renderHome(lingo: Lingo, locale: String) -> String {
        let title = lingo.localize("estate.home", locale: locale)
        let description = lingo.localize("estate.home.description", locale: locale)
        return "<b>\(title)</b>\n\n\(description)"
    }

    fileprivate func homeKeyboard(lingo: Lingo, locale: String) -> TGInlineKeyboardMarkup {
        let workshop = lingo.localize("estate.workshop", locale: locale)
        let kitchen = lingo.localize("estate.kitchen", locale: locale)
        let warehouse = lingo.localize("estate.warehouse", locale: locale)
        let back = lingo.localize("estate.back_root", locale: locale)
        return TGInlineKeyboardMarkup(inlineKeyboard: [
            [TGInlineKeyboardButton(text: workshop,  callbackData: "estate:home:workshop")],
            [TGInlineKeyboardButton(text: kitchen,   callbackData: "estate:home:kitchen")],
            [TGInlineKeyboardButton(text: warehouse, callbackData: "estate:home:warehouse")],
            [TGInlineKeyboardButton(text: back,      callbackData: "estate:root")]
        ])
    }

    /// Generic stub renderer for a not-yet-implemented location inside the estate.
    fileprivate func renderStub(titleKey: String, lingo: Lingo, locale: String) -> String {
        let title = lingo.localize(titleKey, locale: locale)
        let msg = lingo.localize("stub.coming_soon", locale: locale)
        return "<b>\(title)</b>\n\n\(msg)"
    }

    // MARK: - Warehouse views

    fileprivate func renderWarehouseRoot(lingo: Lingo, locale: String) -> String {
        let title = lingo.localize("estate.warehouse", locale: locale)
        let description = lingo.localize("estate.warehouse.description", locale: locale)
        return "<b>\(title)</b>\n\n\(description)"
    }

    /// Category grid mirroring the inventory's root layout — all five ItemType
    /// categories, each a button with a live count of what's in the warehouse.
    fileprivate func warehouseRootKeyboard(entries: [WarehouseEntry], lingo: Lingo, locale: String) -> TGInlineKeyboardMarkup {
        var countsByType: [ItemType: Int] = [:]
        for entry in entries {
            guard let item = ItemCatalog.find(entry.itemId) else { continue }
            countsByType[item.type, default: 0] += entry.quantity
        }

        let typeOrder: [ItemType] = [.food, .material, .potion, .gear, .artifact]
        var rows: [[TGInlineKeyboardButton]] = []
        var currentRow: [TGInlineKeyboardButton] = []

        for type in typeOrder {
            let count = countsByType[type, default: 0]
            let name = lingo.localize("inventory.type.\(type.rawValue)", locale: locale)
            let label = "\(type.icon) \(name) (\(count))"
            currentRow.append(TGInlineKeyboardButton(text: label, callbackData: "estate:wh:\(type.rawValue)"))
            if currentRow.count == 2 {
                rows.append(currentRow)
                currentRow = []
            }
        }
        if !currentRow.isEmpty { rows.append(currentRow) }

        let backToHouse = lingo.localize("estate.back_home", locale: locale)
        rows.append([TGInlineKeyboardButton(text: backToHouse, callbackData: "estate:home")])
        return TGInlineKeyboardMarkup(inlineKeyboard: rows)
    }

    /// Category drill-down: text header only. The real content lives in the inline
    /// keyboard. Empty-state check is type-aware because gear uses per-row display
    /// while other types use aggregate rows.
    fileprivate func renderWarehouseCategory(type: ItemType, invEntries: [InventoryEntry], whEntries: [WarehouseEntry], lingo: Lingo, locale: String) -> String {
        let warehouse = lingo.localize("estate.warehouse", locale: locale)
        let category = lingo.localize("inventory.type.\(type.rawValue)", locale: locale)
        let header = "<b>\(warehouse) / \(type.icon) \(category)</b>"

        let empty: Bool
        if type == .gear {
            let invHasGear = invEntries.contains {
                ItemCatalog.find($0.itemId)?.type == .gear && $0.equippedSlot == nil
            }
            let whHasGear = whEntries.contains {
                ItemCatalog.find($0.itemId)?.type == .gear
            }
            empty = !(invHasGear || whHasGear)
        } else {
            empty = EstateController.warehouseCategoryRows(type: type, inventory: invEntries, warehouse: whEntries).isEmpty
        }

        if empty {
            let emptyText = lingo.localize("estate.warehouse.empty", locale: locale)
            return "\(header)\n\n\(emptyText)"
        }
        return header
    }

    /// Gear (non-stackable): one button row per physical unit, single-direction action.
    /// Everything else (stackable): one aggregated row per item_id with bidirectional
    /// `🎒 N ⬆️` / `📦 M ⬇️` buttons.
    fileprivate func warehouseCategoryKeyboard(type: ItemType, invEntries: [InventoryEntry], whEntries: [WarehouseEntry], lingo: Lingo, locale: String) -> TGInlineKeyboardMarkup {
        var keyboard: [[TGInlineKeyboardButton]] = []

        if type == .gear {
            let invGear: [(entry: InventoryEntry, item: Item)] = invEntries.compactMap { entry in
                guard let item = ItemCatalog.find(entry.itemId), item.type == .gear else { return nil }
                guard entry.equippedSlot == nil else { return nil }
                return (entry, item)
            }.sorted { $0.item.id < $1.item.id }

            let whGear: [(entry: WarehouseEntry, item: Item)] = whEntries.compactMap { entry in
                guard let item = ItemCatalog.find(entry.itemId), item.type == .gear else { return nil }
                return (entry, item)
            }.sorted { $0.item.id < $1.item.id }

            for pair in invGear {
                let name = lingo.localize(pair.item.nameKey, locale: locale)
                let iconPrefix = pair.item.icon.map { "\($0) " } ?? ""
                keyboard.append([
                    TGInlineKeyboardButton(text: "\(iconPrefix)\(name)", callbackData: "estate:wh:info:\(pair.item.id)"),
                    TGInlineKeyboardButton(text: "🎒 ⬆️", callbackData: "estate:wh:deposit:\(pair.item.id)")
                ])
            }
            for pair in whGear {
                let name = lingo.localize(pair.item.nameKey, locale: locale)
                let iconPrefix = pair.item.icon.map { "\($0) " } ?? ""
                keyboard.append([
                    TGInlineKeyboardButton(text: "\(iconPrefix)\(name)", callbackData: "estate:wh:info:\(pair.item.id)"),
                    TGInlineKeyboardButton(text: "📦 ⬇️", callbackData: "estate:wh:withdraw:\(pair.item.id)")
                ])
            }
        } else {
            let rows = EstateController.warehouseCategoryRows(type: type, inventory: invEntries, warehouse: whEntries)
            for row in rows {
                let name = lingo.localize(row.item.nameKey, locale: locale)
                let iconPrefix = row.item.icon.map { "\($0) " } ?? ""
                keyboard.append([
                    TGInlineKeyboardButton(text: "\(iconPrefix)\(name)", callbackData: "estate:wh:info:\(row.item.id)"),
                    TGInlineKeyboardButton(text: "🎒 \(row.inventoryCount) ⬆️", callbackData: "estate:wh:deposit:\(row.item.id)"),
                    TGInlineKeyboardButton(text: "📦 \(row.warehouseCount) ⬇️", callbackData: "estate:wh:withdraw:\(row.item.id)")
                ])
            }
        }

        let back = lingo.localize("estate.back_root", locale: locale)
        keyboard.append([TGInlineKeyboardButton(text: back, callbackData: "estate:home:warehouse")])
        return TGInlineKeyboardMarkup(inlineKeyboard: keyboard)
    }

    /// Combine backpack + warehouse rows into a per-item-id summary. Only the
    /// requested `type` is kept. Inventory count excludes equipped rows because
    /// they can't be deposited. Items with zero on both sides are dropped.
    fileprivate static func warehouseCategoryRows(
        type: ItemType,
        inventory: [InventoryEntry],
        warehouse: [WarehouseEntry]
    ) -> [WarehouseCategoryRow] {
        var invCounts: [String: Int] = [:]
        var whCounts: [String: Int] = [:]
        var items: [String: Item] = [:]

        for row in inventory {
            guard let item = ItemCatalog.find(row.itemId), item.type == type else { continue }
            guard row.equippedSlot == nil else { continue }
            invCounts[item.id, default: 0] += row.quantity
            items[item.id] = item
        }
        for row in warehouse {
            guard let item = ItemCatalog.find(row.itemId), item.type == type else { continue }
            whCounts[item.id, default: 0] += row.quantity
            items[item.id] = item
        }

        let ids = Set(invCounts.keys).union(whCounts.keys)
        return ids.sorted().compactMap { id in
            guard let item = items[id] else { return nil }
            return WarehouseCategoryRow(
                item: item,
                inventoryCount: invCounts[id, default: 0],
                warehouseCount: whCounts[id, default: 0]
            )
        }
    }

    fileprivate func backToRootKeyboard(lingo: Lingo, locale: String) -> TGInlineKeyboardMarkup {
        let back = lingo.localize("estate.back_root", locale: locale)
        return TGInlineKeyboardMarkup(inlineKeyboard: [[
            TGInlineKeyboardButton(text: back, callbackData: "estate:root")
        ]])
    }

    fileprivate func backToHomeKeyboard(lingo: Lingo, locale: String) -> TGInlineKeyboardMarkup {
        let back = lingo.localize("estate.back_home", locale: locale)
        return TGInlineKeyboardMarkup(inlineKeyboard: [[
            TGInlineKeyboardButton(text: back, callbackData: "estate:home")
        ]])
    }
}

/// Summary row for a single item in the warehouse category drill-down.
fileprivate struct WarehouseCategoryRow {
    let item: Item
    let inventoryCount: Int
    let warehouseCount: Int
}

// MARK: - Callback Queries

extension EstateController {
    static func onCallbackQuery(context: Context) async throws -> Bool {
        guard let query = context.update.callbackQuery else { return false }
        guard let message = query.message else { return false }
        guard let data = query.data, data.hasPrefix("estate:") else { return false }

        let ctrl = Controllers.estateController
        let locale = context.session.locale

        let text: String
        let inline: TGInlineKeyboardMarkup

        // Warehouse item actions — show description placeholder, or transfer one unit.
        if data.hasPrefix("estate:wh:info:") {
            let itemId = String(data.dropFirst("estate:wh:info:".count))
            if let item = ItemCatalog.find(itemId) {
                let itemName = context.lingo.localize(item.nameKey, locale: locale)
                let toast = context.lingo.localize("inventory.info.placeholder", locale: locale, interpolations: ["name": itemName])
                _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id, text: toast, showAlert: false))
            } else {
                _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id))
            }
            return true
        }

        if data.hasPrefix("estate:wh:deposit:") || data.hasPrefix("estate:wh:withdraw:") {
            return try await handleWarehouseTransfer(data: data, query: query, message: message, context: context)
        }

        if data.hasPrefix("estate:wh:") {
            // Warehouse category drill-down (e.g. estate:wh:food).
            let typeRaw = String(data.dropFirst("estate:wh:".count))
            guard let type = ItemType(rawValue: typeRaw) else {
                _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id))
                return true
            }
            let invEntries = try await InventoryEntry.list(for: context.session, on: context.db)
            let whEntries = try await WarehouseEntry.list(for: context.session, on: context.db)
            text = ctrl.renderWarehouseCategory(type: type, invEntries: invEntries, whEntries: whEntries, lingo: context.lingo, locale: locale)
            inline = ctrl.warehouseCategoryKeyboard(type: type, invEntries: invEntries, whEntries: whEntries, lingo: context.lingo, locale: locale)
        } else {
            switch data {
            case "estate:root":
                text = ctrl.renderRoot(session: context.session, lingo: context.lingo)
                inline = ctrl.rootKeyboard(lingo: context.lingo, locale: locale)
            case "estate:home":
                text = ctrl.renderHome(lingo: context.lingo, locale: locale)
                inline = ctrl.homeKeyboard(lingo: context.lingo, locale: locale)
            case "estate:plot":
                text = ctrl.renderStub(titleKey: "estate.plot", lingo: context.lingo, locale: locale)
                inline = ctrl.backToRootKeyboard(lingo: context.lingo, locale: locale)
            case "estate:home:workshop":
                text = ctrl.renderStub(titleKey: "estate.workshop", lingo: context.lingo, locale: locale)
                inline = ctrl.backToHomeKeyboard(lingo: context.lingo, locale: locale)
            case "estate:home:kitchen":
                text = ctrl.renderStub(titleKey: "estate.kitchen", lingo: context.lingo, locale: locale)
                inline = ctrl.backToHomeKeyboard(lingo: context.lingo, locale: locale)
            case "estate:home:warehouse":
                let entries = try await WarehouseEntry.list(for: context.session, on: context.db)
                text = ctrl.renderWarehouseRoot(lingo: context.lingo, locale: locale)
                inline = ctrl.warehouseRootKeyboard(entries: entries, lingo: context.lingo, locale: locale)
            default:
                _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id))
                return true
            }
        }

        // If the source message is a photo (level artwork at root), editing the text
        // field would fail — Telegram requires editing the caption instead. Keep both
        // branches so the controller stays correct once user drops in JPEGs.
        let chatId = TGChatId.chat(message.chat.id)
        let isPhoto = (message.getMessage()?.photo) != nil
        if isPhoto {
            let params = TGEditMessageCaptionParams(
                chatId: chatId,
                messageId: message.messageId,
                caption: text,
                parseMode: .html,
                replyMarkup: inline
            )
            _ = try? await context.bot.editMessageCaption(params: params)
        } else {
            let params = TGEditMessageTextParams(
                chatId: chatId,
                messageId: message.messageId,
                text: text,
                parseMode: .html,
                replyMarkup: inline
            )
            _ = try? await context.bot.editMessageText(params: params)
        }
        _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id))
        return true
    }

    /// Perform one deposit/withdraw and refresh the current category drill-down
    /// in place. Callback data is either `estate:wh:deposit:<item_id>` or
    /// `estate:wh:withdraw:<item_id>`.
    static func handleWarehouseTransfer(
        data: String,
        query: TGCallbackQuery,
        message: TGMaybeInaccessibleMessage,
        context: Context
    ) async throws -> Bool {
        let locale = context.session.locale
        let isDeposit = data.hasPrefix("estate:wh:deposit:")
        let prefix = isDeposit ? "estate:wh:deposit:" : "estate:wh:withdraw:"
        let itemId = String(data.dropFirst(prefix.count))

        guard let item = ItemCatalog.find(itemId) else {
            _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id))
            return true
        }

        let itemName = context.lingo.localize(item.nameKey, locale: locale)
        let toastKey: String
        if isDeposit {
            let result = try await WarehouseService.deposit(itemId: itemId, for: context.session, on: context.db)
            switch result {
            case .success:           toastKey = "estate.warehouse.deposited"
            case .nothingToDeposit:  toastKey = "estate.warehouse.nothing_to_deposit"
            }
        } else {
            let result = try await WarehouseService.withdraw(itemId: itemId, for: context.session, on: context.db)
            switch result {
            case .success:           toastKey = "estate.warehouse.withdrawn"
            case .nothingToWithdraw: toastKey = "estate.warehouse.nothing_to_withdraw"
            case .inventoryFull:     toastKey = "inventory.full"
            }
        }
        let toast = context.lingo.localize(toastKey, locale: locale, interpolations: ["item": itemName])
        _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id, text: toast, showAlert: false))

        // Refresh the currently-open category in place.
        let ctrl = Controllers.estateController
        let invEntries = try await InventoryEntry.list(for: context.session, on: context.db)
        let whEntries = try await WarehouseEntry.list(for: context.session, on: context.db)
        let text = ctrl.renderWarehouseCategory(type: item.type, invEntries: invEntries, whEntries: whEntries, lingo: context.lingo, locale: locale)
        let inline = ctrl.warehouseCategoryKeyboard(type: item.type, invEntries: invEntries, whEntries: whEntries, lingo: context.lingo, locale: locale)

        let chatId = TGChatId.chat(message.chat.id)
        if message.getMessage()?.photo != nil {
            let params = TGEditMessageCaptionParams(
                chatId: chatId,
                messageId: message.messageId,
                caption: text,
                parseMode: .html,
                replyMarkup: inline
            )
            _ = try? await context.bot.editMessageCaption(params: params)
        } else {
            let params = TGEditMessageTextParams(
                chatId: chatId,
                messageId: message.messageId,
                text: text,
                parseMode: .html,
                replyMarkup: inline
            )
            _ = try? await context.bot.editMessageText(params: params)
        }
        return true
    }
}
